class_name BattleView
extends Node2D
## The battle on screen: the isometric grid, a token per man, the round
## clock (manual "next round" by default, or a pulse), and the animation of
## each round's beats in order: movement, blows, the push, morale.

signal round_played(lines: PackedStringArray)
signal battle_finished(result: BattleResult)
signal auto_paused(reason: String)
signal paused_changed(is_paused: bool)
signal camera_moved()

var battle: Battle
var rules: CombatRules
var player: Warrior
var camera: Camera2D
var tokens := {}  # Warrior -> Token
## 0 means turn-based: rounds advance only on "next round".
var pulse_seconds := 0.0
var paused := true
var auto_pause := true
var follow := true
var pending_shout: CombatTypes.Shout = CombatTypes.Shout.NONE
var pending_action: Action = null
var pending_advance := false  # the wall steps forward as one next round
var clock := 0.0
var animating := false
var anim_scale := 1.0  # 0 for headless screenshots
## What happened to your man last round, for the HUD.
var player_line := ""
var _last_enemy_shout: CombatTypes.Shout = CombatTypes.Shout.NONE
var _log_seen := 0
var _by_name := {}
var _press_pos := Vector2.ZERO
var _press_cam := Vector2.ZERO
var _dragging := false
var _drag_moved := false

const MIN_ZOOM := 0.8
const MAX_ZOOM := 4.0


func setup(p_battle: Battle, p_player: Warrior, p_camera: Camera2D) -> void:
	battle = p_battle
	rules = battle.rules
	player = p_player
	camera = p_camera
	for w in battle.warriors:
		var t := Token.new()
		t.setup(w, rules, w == player)
		t.position = Iso.to_screen(w.pos)
		add_child(t)
		tokens[w] = t
		_by_name[w.display_name] = w
	clock = pulse_seconds
	queue_redraw()


func is_manual() -> bool:
	return pulse_seconds <= 0.0


## Steps your man one hex square to the wall; the line forms on where he goes.
func advance() -> void:
	if player == null or not player.is_active():
		return
	if in_wall(player) and battle.wall_members(player.side).size() >= 2:
		# In a wall, the wall goes: one test, everyone steps or nobody.
		pending_advance = not pending_advance
		pending_action = null
		queue_redraw()
		return
	var cell := player.pos + BattleGrid.advance_step(player.pos, player.wall_facing())
	if battle.grid.is_free(cell):
		pending_action = Action.move_to(cell, player.wall_facing())
		queue_redraw()


## Where each man of your wall would step on Advance (empty when not in one).
func advance_targets() -> Dictionary:
	var out := {}
	if player == null or not in_wall(player):
		return out
	for w in battle.wall_members(player.side):
		out[w] = w.pos + BattleGrid.advance_step(w.pos, player.wall_facing())
	return out


## Wheels the wall one facing (60 degrees) left or right.
func wheel(steps: int) -> void:
	if player == null:
		return
	player.line_facing = BattleGrid.rotate(player.wall_facing(), steps)
	queue_redraw()


func set_paused(p: bool) -> void:
	if paused == p:
		return
	paused = p
	paused_changed.emit(paused)
	queue_redraw()


func _process(delta: float) -> void:
	if battle == null or battle.is_over() or animating or is_manual() or paused:
		return
	clock -= delta
	if clock <= 0.0:
		step()


## Plays one round: locks the pending shout and action, runs the sim, then
## animates the beats in order.
func step() -> void:
	if battle.is_over() or animating:
		return
	var before := {}
	for w in battle.warriors:
		before[w] = w.pos
	if pending_shout != CombatTypes.Shout.NONE:
		battle.set_shout(player.side, pending_shout)
	if pending_action != null:
		battle.set_player_action(player.side, pending_action)
	if pending_advance:
		battle.request_wall_step(player.side)
	pending_action = null
	pending_advance = false
	battle.run_round()
	var lines := PackedStringArray()
	for i in range(_log_seen, battle.log.size()):
		lines.append(battle.log[i])
	_log_seen = battle.log.size()
	clock = pulse_seconds
	player_line = _player_summary(lines)
	await _animate(before, lines)
	round_played.emit(lines)
	_check_auto_pause(lines)
	if battle.is_over():
		battle_finished.emit(battle.result)


func _wait(seconds: float) -> void:
	if anim_scale > 0.0 and seconds > 0.0:
		await get_tree().create_timer(seconds * anim_scale).timeout


func _tween_to(positions: Dictionary, seconds: float) -> bool:
	var any := false
	var tween: Tween = null
	for w in positions:
		if not tokens.has(w) or w.fled:
			continue
		var t: Token = tokens[w]
		var target := Iso.to_screen(positions[w])
		if t.position.distance_to(target) < 0.5:
			continue
		any = true
		if anim_scale > 0.0:
			if tween == null:
				tween = create_tween().set_parallel(true)
			tween.tween_property(t, "position", target, seconds * anim_scale).set_trans(Tween.TRANS_SINE)
		else:
			t.position = target
	return any


func _animate(before: Dictionary, lines: PackedStringArray) -> void:
	animating = true
	var shout_now := battle.last_shout(player.side)
	for w in battle.warriors:
		var t: Token = tokens[w]
		t.heard_this_round = shout_now != CombatTypes.Shout.NONE and w.side == player.side \
				and w.heard_order == shout_now and w != player
		t.queue_redraw()
	# Beat 1: everyone steps.
	if _tween_to(battle.after_movement, 0.4):
		await _wait(0.45)
	# Beat 2: blows land one at a time; the winner lunges, the loser flashes.
	for line in lines:
		if not line.contains(" beats "):
			continue
		var parts := line.split(" beats ")
		var winner: Warrior = _by_name.get(parts[0].strip_edges(), null)
		var loser: Warrior = _by_name.get(parts[1].split(" (")[0], null)
		if loser != null and tokens.has(loser):
			var heavy := line.contains("heavy") or line.contains("DOWN")
			if winner != null and tokens.has(winner) and anim_scale > 0.0:
				var wt: Token = tokens[winner]
				var dir: Vector2 = ((tokens[loser] as Token).position - wt.position).normalized() * 8
				var tw := create_tween()
				tw.tween_property(wt, "position", wt.position + dir, 0.08 * anim_scale)
				tw.tween_property(wt, "position", wt.position, 0.12 * anim_scale)
			(tokens[loser] as Token).hit(Palette.BLOOD if heavy else Palette.BONE)
			await _wait(0.22)
	# Shoves from glancing blows.
	if _tween_to(battle.after_melee, 0.25):
		await _wait(0.3)
	# Beat 3: the push, as one heave.
	var final := {}
	for w in battle.warriors:
		final[w] = w.pos
	if _tween_to(final, 0.35):
		await _wait(0.4)
	# Beat 4: morale: breaks, the fallen, the fled.
	for w in battle.warriors:
		var t: Token = tokens[w]
		if w.is_down():
			t.down_mark = true
			t.z_index = 5
		if w.fled:
			t.visible = false
		t.queue_redraw()
	animating = false
	queue_redraw()


func _player_summary(lines: PackedStringArray) -> String:
	var out := PackedStringArray()
	for line in lines:
		if line.begins_with("You beats "):
			out.append("you struck " + line.split(" beats ")[1].replace(" the leader", ""))
		elif line.contains(" beats You "):
			out.append(line.split(" beats ")[0] + " struck you" + line.split("You")[1])
		elif line.begins_with("You is shoved") or line.begins_with("You is pressed"):
			out.append("you were pushed back")
	if out.is_empty():
		var a: Action = battle.last_actions.get(player, null)
		if a != null:
			match a.kind:
				CombatTypes.ActionKind.MOVE:
					out.append("you stepped to %s" % a.target_cell)
				CombatTypes.ActionKind.BRACE:
					out.append("you braced")
				CombatTypes.ActionKind.ATTACK:
					out.append("you struck at %s but the exchange went nowhere" % (a.target.display_name if a.target else "?"))
	if out.size() > 1:
		out = out.slice(0, 1)
	return "; ".join(out)


func _check_auto_pause(lines: PackedStringArray) -> void:
	if not auto_pause or battle.is_over() or is_manual():
		return
	var reason := ""
	for line in lines:
		if line.contains("DOWN") and _side_of_line(line) == player.side:
			reason = "one of your men is down"
		if line.contains("flees the field") and _side_of_line(line) == player.side:
			reason = "a man has fled"
	var enemy_shout := battle.last_shout(1 - player.side)
	if enemy_shout != _last_enemy_shout and enemy_shout != CombatTypes.Shout.NONE:
		reason = "the enemy leader shouts: %s" % CombatTypes.SHOUT_NAMES[enemy_shout]
	_last_enemy_shout = enemy_shout
	if player.is_active():
		for e in battle.grid.adjacent_warriors(player.pos, 1 - player.side):
			var arc := BattleGrid.arc_of(player, e.pos)
			if arc == CombatTypes.Arc.RIGHT or arc == CombatTypes.Arc.REAR:
				reason = "you are flanked"
			elif reason == "":
				reason = "an enemy is on you"
	if reason != "":
		set_paused(true)
		auto_paused.emit(reason)


func _side_of_line(line: String) -> int:
	for name in _by_name:
		if line.contains(" beats " + name):
			return (_by_name[name] as Warrior).side
	return -1


## How many of a side's men stand with a locked shield beside a friend.
## [men in the leader's wall, men standing]: the wall is the unit that
## moves as one, so this is what "wall 6/8" means.
func wall_count(side: int) -> Array[int]:
	var total := 0
	for w in battle.active(side):
		if not w.broken:
			total += 1
	return [battle.wall_members(side).size(), total]


func in_wall(w: Warrior) -> bool:
	return battle.wall_members(w.side).has(w)


func _locked_neighbours(w: Warrior) -> Array[Warrior]:
	var out: Array[Warrior] = []
	if not w.shield_usable():
		return out
	for n in battle.grid.line_neighbors(w):
		if n.shield_usable() and not n.broken:
			out.append(n)
	return out


## The muster preview: what each of our men, you included, would likely do
## if the pending shout were given now, with how surely he would hear it.
## Does not change the sim.
func preview() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var shout := pending_shout
	var leader := battle.leader_of(player.side)
	var horn := false
	for w in battle.active(player.side):
		horn = horn or w.is_horn
	for w in battle.active(player.side):
		var dist := BattleGrid.chebyshev(w.pos, leader.pos) if leader != null else 99
		var chance := 1.0
		if shout != CombatTypes.Shout.NONE and w != player:
			chance = Shouts.hear_chance(rules, dist, w.wits, horn, battle.fog)
		var saved_order := w.heard_order
		var saved_lag := w.order_lag
		if shout != CombatTypes.Shout.NONE and chance > 0.0:
			w.heard_order = shout
		var a: Action
		if w == player and pending_action != null:
			a = pending_action
		else:
			a = Decision.choose(SimRng.new(w.id * 31 + battle.round), rules, battle.grid, w, leader, battle.warriors)
		w.heard_order = saved_order
		w.order_lag = saved_lag
		out.append({"warrior": w, "action": a, "chance": chance})
	return out


# --- Input: tap to act, drag to pan, pinch or wheel to zoom ----------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		_zoom_by(event.factor)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.1)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(0.9)
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_press_cam = camera.position if camera else Vector2.ZERO
				_dragging = true
				_drag_moved = false
			else:
				if _dragging and not _drag_moved:
					_tap(get_local_mouse_position())
				_dragging = false
			return
	if event is InputEventMouseMotion and _dragging and camera != null:
		var d: Vector2 = event.position - _press_pos
		if d.length() > 12.0:
			_drag_moved = true
			follow = false
			camera.position = _press_cam - d / camera.zoom.x
			camera_moved.emit()


func _zoom_by(factor: float) -> void:
	if camera == null:
		return
	var z := clampf(camera.zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(z, z)
	camera_moved.emit()


func _tap(local: Vector2) -> void:
	if player == null or not player.is_active() or animating:
		return
	var cell := Iso.to_cell(local)
	if not battle.grid.in_bounds(cell):
		return
	if cell == player.pos:
		pending_action = null  # back to acting with the line
		pending_advance = false
		queue_redraw()
		return
	if BattleGrid.chebyshev(cell, player.pos) != 1:
		return
	if in_wall(player) and battle.wall_members(player.side).size() >= 2 \
			and cell == player.pos + BattleGrid.advance_step(player.pos, player.wall_facing()):
		pending_advance = true  # a tap ahead takes the wall forward, not the man
		pending_action = null
		queue_redraw()
		return
	pending_advance = false
	var occ := battle.grid.occupant(cell)
	if occ == null and battle.grid.is_free(cell):
		pending_action = Action.move_to(cell, player.wall_facing())  # a step does not turn the wall
	elif occ != null and occ.side != player.side and occ.is_active():
		pending_action = Action.attack(occ)
	else:
		return
	queue_redraw()


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	if battle == null:
		return
	var g := battle.grid
	for row in g.height:
		for col_i in g.width:
			var c := BattleGrid.from_offset(col_i, row)
			var col := Palette.GROUND
			if g.terrain_at(c) == CombatTypes.Terrain.MUD:
				col = Palette.MUD
			elif (col_i + row) % 2 == 0:
				col = Palette.GROUND.lightened(0.04)
			var hexa := Iso.hexagon(c, 1.0)
			draw_colored_polygon(hexa, col)
			draw_polyline(hexa + PackedVector2Array([hexa[0]]), Palette.GROUND_LINE, 1.0)
	_draw_wall_slots()
	_draw_shield_locks()
	if player != null and player.is_active():
		draw_colored_polygon(Iso.hexagon(player.pos, 3), Color(Palette.GOLD, 0.25))
		# The wall's facing: a chevron ahead of your man.
		var f := Iso.to_screen_f(Vector2(player.wall_facing())).normalized()
		var tip := Iso.to_screen(player.pos) + f * 42
		var side_v := Vector2(-f.y, f.x) * 9
		draw_polyline(PackedVector2Array([tip - f * 10 + side_v, tip, tip - f * 10 - side_v]), Palette.GOLD, 3.0)
		if not animating:
			for n in g.neighbors(player.pos):
				var occ := g.occupant(n)
				if occ == null and g.is_free(n):
					draw_polyline(Iso.hexagon(n, 4) + PackedVector2Array([Iso.hexagon(n, 4)[0]]), Color(Palette.BONE, 0.45), 1.5)
				elif occ != null and occ.side != player.side and occ.is_active():
					draw_polyline(Iso.hexagon(n, 4) + PackedVector2Array([Iso.hexagon(n, 4)[0]]), Color(Palette.BLOOD, 0.8), 2.0)
		if pending_action != null:
			var target := pending_action.target_cell
			draw_colored_polygon(Iso.hexagon(target, 5), Color(Palette.GOLD, 0.45))
		if pending_advance:
			var targets := advance_targets()
			for w in targets:
				draw_colored_polygon(Iso.hexagon(targets[w], 5), Color(Palette.GOLD, 0.3 if w != player else 0.45))
				_arrow(Iso.to_screen(w.pos), Iso.to_screen(targets[w]), Palette.GOLD, 4.0 if w == player else 3.0)
	if not animating and (paused or is_manual()):
		for p in preview():
			var w: Warrior = p.warrior
			var a: Action = p.action
			var from := Iso.to_screen(w.pos)
			var alpha: float = 0.3 + 0.7 * p.chance
			var col := Color(Palette.GOLD if w == player else Palette.BONE, alpha)
			match a.kind:
				CombatTypes.ActionKind.MOVE, CombatTypes.ActionKind.FLEE:
					_arrow(from, Iso.to_screen(a.target_cell), col, 4.0 if w == player else 3.0)
				CombatTypes.ActionKind.ATTACK:
					if a.target != null:
						_arrow(from, Iso.to_screen(a.target.pos), Color(Palette.BLOOD, alpha), 4.0 if w == player else 3.0)
						if w == player:
							draw_arc(Iso.to_screen(a.target.pos), 22, 0, TAU, 24, Palette.BLOOD, 3.0)
				CombatTypes.ActionKind.BRACE:
					draw_arc(from, 21, 0, TAU, 20, col, 2.5 if w == player else 2.0)
				_:
					pass


## Faint outlines of the line's slots while the standing order is Shield Wall.
func _draw_wall_slots() -> void:
	var order := battle.last_shout(player.side)
	if order != CombatTypes.Shout.SHIELD_WALL and pending_shout != CombatTypes.Shout.SHIELD_WALL:
		return
	var leader := battle.leader_of(player.side)
	if leader == null:
		return
	var n := battle.active(player.side).size() - 1
	for slot in Formation.line_slots(battle.grid, leader, n):
		if battle.grid.occupant(slot) == null:
			draw_polyline(Iso.hexagon(slot, 6) + PackedVector2Array([Iso.hexagon(slot, 6)[0]]), Color(Palette.BONE, 0.35), 1.5)


## A bar between neighbours whose shields are locked: the wall you can see.
func _draw_shield_locks() -> void:
	for w in battle.warriors:
		if not w.is_active() or w.broken:
			continue
		for n in _locked_neighbours(w):
			if n.id < w.id:
				continue
			var a := Iso.to_screen(w.pos)
			var b := Iso.to_screen(n.pos)
			# The leader's wall is bright; a broken-off fragment is dim.
			var whole := in_wall(w) and in_wall(n)
			var col := Palette.BONE if w.side == player.side else Palette.UNDYED.darkened(0.3)
			if not whole:
				col = col.darkened(0.45)
			draw_line(a, b, Palette.OUTLINE, 7.0)
			draw_line(a, b, col, 4.0)


func _arrow(from: Vector2, to: Vector2, col: Color, width := 3.0) -> void:
	var d := (to - from)
	if d.length() < 1.0:
		return
	var n := d.normalized()
	var start := from + n * 18
	var end := to - n * 18
	draw_line(start, end, col, width)
	var side := Vector2(-n.y, n.x) * 6
	draw_colored_polygon(PackedVector2Array([end + n * 8, end - n * 2 + side, end - n * 2 - side]), col)
