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
## The player tapped the board: his man will step to or strike at `cell`
## next round, or (NO_CELL) acts with the line again. The tutorial listens.
signal tapped(cell: Vector2i)

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
## A shout of the band's own to give this round (CustomShout), or null.
var pending_custom: CustomShout = null
var pending_action: Action = null
var pending_advance := false  # the wall steps forward as one next round
var clock := 0.0
var animating := false
var anim_scale := 1.0  # 0 for headless screenshots
## What happened to your man last round, for the HUD.
var player_line := ""
## The tutorial's marks on the board (view/tutorial.gd): the man or hex the
## banner means, ringed and pulsing (NO_CELL for none), and whether the
## objective's edge is where to go now (it pulses gold, with an arrow from
## your man toward it).
var guide_cell: Vector2i = BattleGrid.NO_CELL
var guide_goal := false
var _last_enemy_shout: CombatTypes.Shout = CombatTypes.Shout.NONE
var _log_seen := 0
var _by_name := {}
var _press_pos := Vector2.ZERO
var _press_cam := Vector2.ZERO
var _dragging := false
var _drag_moved := false

const MIN_ZOOM := 0.8
const MAX_ZOOM := 4.0
var _fire_time := 0.0
## The ship fight's water and timber (Scenario.build_deck), in the map's
## teal: the open sea, its wave marks and foam; the deck's planks, seams,
## the strake along the gunwale and the mast.
const SEA_DEEP := Color("244a52")
const SEA_WAVE := Color("3f6f72")
const SEA_FOAM := Color("b4d0cf")
const DECK := Color("7d5f3e")
const DECK_SEAM := Color("5e4529")
const STRAKE := Color("4a3420")


func setup(p_battle: Battle, p_player: Warrior, p_camera: Camera2D) -> void:
	battle = p_battle
	rules = battle.rules
	player = p_player
	camera = p_camera
	for w in battle.warriors:
		var t := Token.new()
		t.setup(w, rules, w == player)
		add_child(t)
		tokens[w] = t
		_by_name[w.display_name] = w
	# The walls as deployed draw closed up from the first frame.
	_compute_tighten()
	for w in tokens:
		(tokens[w] as Token).position = _spot(w, w.pos)
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
	var cell := player.pos + BattleGrid.forward(player.pos, player.wall_axis(), player.wall_facing())
	if battle.grid.is_free(cell):
		pending_action = Action.move_to(cell, player.wall_facing())
		queue_redraw()


## Where each man of your wall would step on Advance (empty when not in one).
func advance_targets() -> Dictionary:
	var out := {}
	if player == null or not in_wall(player):
		return out
	var step := BattleGrid.forward(player.pos, player.wall_axis(), player.wall_facing())
	for w in battle.wall_members(player.side):
		out[w] = w.pos + step
	return out


## Wheels the wall one stance left or right round the eight it can stand
## in: level, the two slants and plumb, facing either way.
func wheel(steps: int) -> void:
	if player == null:
		return
	player.wheel_wall(steps)
	queue_redraw()


func set_paused(p: bool) -> void:
	if paused == p:
		return
	paused = p
	paused_changed.emit(paused)
	queue_redraw()


func _process(delta: float) -> void:
	if battle != null and is_night():
		_fire_time += delta
		queue_redraw()  # the fire flickers
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
	if pending_custom != null:
		battle.call_custom(player.side, pending_custom)
		pending_custom = null
	elif pending_shout != CombatTypes.Shout.NONE:
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


## How far a man in a wall draws in toward his leader, per link of the
## chain, so locked shields overlap on the screen while the hex stays his
## slot in the rules. The wall closes up as it forms and opens as it breaks.
const WALL_TIGHTEN := 12.0
const WALL_TIGHTEN_MAX := 48.0
var _tighten := {}  # Warrior -> Vector2 pull toward the leader, recomputed each round


## Where a man is drawn: his cell, his own small jitter, and his pull into
## the wall if he stands in one.
func _spot(w: Warrior, cell: Vector2i) -> Vector2:
	var base := Iso.to_screen(cell)
	var pull: Vector2 = _tighten.get(w, Vector2.ZERO)
	var jitter := Iso.jitter(w.id) * (0.35 if pull != Vector2.ZERO else 1.0)
	return base + jitter + pull


## Recomputes every man's pull into his wall from the battle as it stands:
## breadth-first from each leader, each link draws WALL_TIGHTEN pixels
## further in, toward the leader's cell.
func _compute_tighten() -> void:
	_tighten.clear()
	for side in 2:
		var leader := battle.leader_of(side)
		if leader == null:
			continue
		var members := battle.wall_members(side)
		if members.size() < 2:
			continue
		var depth := {leader: 0}
		var queue: Array[Warrior] = [leader]
		while not queue.is_empty():
			var m: Warrior = queue.pop_front()
			for n in battle.grid.line_neighbors(m):
				if members.has(n) and not depth.has(n):
					depth[n] = depth[m] + 1
					queue.append(n)
		var centre := Iso.to_screen(leader.pos)
		var plumb := leader.wall_axis() == BattleGrid.Axis.PLUMB
		var leader_col := BattleGrid.to_offset(leader.pos).x
		var col_px := Iso.SIZE * sqrt(3.0)
		for m in members:
			if not depth.has(m) or m == leader:
				continue
			var mine := Iso.to_screen(m.pos)
			var pull := Vector2.ZERO
			if plumb:
				# A plumb line zigzags on the hexes; on the screen each man
				# stands straight in his own column (the leader's for the
				# line, one back for the second rank), never more than half
				# a cell from where his hex is drawn.
				var want_x := centre.x + (BattleGrid.to_offset(m.pos).x - leader_col) * col_px
				pull.x = clampf(want_x - mine.x, -col_px / 2.0, col_px / 2.0)
			var toward := centre - mine
			if toward.length() >= 1.0:
				pull += toward.normalized() * minf(WALL_TIGHTEN * depth[m], WALL_TIGHTEN_MAX)
			_tighten[m] = pull
		for m in members:
			if tokens.has(m):
				(tokens[m] as Token).set_locked(true)
	for w in battle.warriors:
		if tokens.has(w) and not _tighten.has(w) and not (battle.leader_of(w.side) == w and battle.wall_members(w.side).size() >= 2):
			(tokens[w] as Token).set_locked(false)


## After the beats: the walls close up or open out to where they now stand.
func _settle(seconds: float) -> void:
	_compute_tighten()
	var now := {}
	for w in battle.warriors:
		now[w] = w.pos
	if _tween_to(now, seconds):
		await _wait(seconds)


func _tween_to(positions: Dictionary, seconds: float) -> bool:
	var any := false
	var tween: Tween = null
	for w in positions:
		if not tokens.has(w) or w.fled:
			continue
		var t: Token = tokens[w]
		var target := _spot(w, positions[w])
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
	# Beat 1b: arrows and thrown spears fly.
	var shots := 0
	for line in lines:
		var shooter: Warrior = null
		var mark: Warrior = null
		if line.contains(" shoots at ") or line.contains(" throws at "):
			var sep := " shoots at " if line.contains(" shoots at ") else " throws at "
			shooter = _by_name.get(line.split(sep)[0].strip_edges(), null)
			mark = _by_name.get(line.split(sep)[1].split(":")[0].strip_edges(), null)
		elif line.contains(" shoots ") or line.contains(" spears "):
			var sep := " shoots " if line.contains(" shoots ") else " spears "
			shooter = _by_name.get(line.split(sep)[0].strip_edges(), null)
			mark = _by_name.get(line.split(sep)[1].split(" (")[0].strip_edges(), null)
		elif line.contains("'s spear sticks in "):
			shooter = _by_name.get(line.split("'s spear sticks in ")[0].strip_edges(), null)
			mark = _by_name.get(line.split("'s spear sticks in ")[1].split("'s shield")[0].strip_edges(), null)
		if shooter != null and mark != null and tokens.has(shooter) and tokens.has(mark):
			_flash_shot((tokens[shooter] as Token).position, (tokens[mark] as Token).position, line.contains("misses"))
			shots += 1
	if shots > 0:
		await _wait(0.5)
	# Beat 2: blows land one at a time; the winner lunges, the loser flashes.
	# The sound of it is a few layered clashes for the whole round.
	Audio.blows(lines)
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
	var fled := 0
	for line in lines:
		if line.contains("flees the field"):
			fled += 1
	if Audio.blow_counts(lines).z > 0:
		Audio.play("down")
	if fled >= 3 or (battle.is_over() and battle.result != null and battle.result.how == BattleResult.End.ROUT):
		Audio.play("rout", -2.0)
	var met := false
	for w in battle.warriors:
		var t: Token = tokens[w]
		if w.is_down():
			t.down_mark = true
			t.z_index = 5
		if w.fled:
			t.visible = false
		var tense := w.is_active() and not battle.grid.adjacent_warriors(w.pos, 1 - w.side).is_empty()
		met = met or tense
		t.set_tense(tense)
		t.queue_redraw()
	Audio.close(met and not battle.is_over())  # the drum quickens while the lines are met
	await _settle(0.3)
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
	# His own reason, when he chose for himself this round (it is in the log).
	if out.is_empty() and player.last_reason != "" and lines.has(player.last_reason):
		out.append(player.last_reason.replace("You ", "you ").replace("You's", "your"))
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


## [men in the leader's wall, men standing who belong in it]: bows stand
## off and are counted apart, so this is what "wall 6/8" means.
func wall_count(side: int) -> Array[int]:
	var total := 0
	for w in battle.active(side):
		if not w.broken and w.role != CombatTypes.Role.MISSILE:
			total += 1
	return [battle.wall_members(side).size(), total]


## Men standing in the front of the wall without a shield to lock: the gaps
## in it. A shieldless man relieved into the second rank is no gap.
func shieldless_count(side: int) -> int:
	var n := 0
	var leader := battle.leader_of(side)
	var ahead := leader.wall_facing() if leader != null else Vector2i(0, -1)
	for w in battle.wall_members(side):
		if w.shield_usable():
			continue
		var front := battle.grid.occupant(w.pos + ahead)
		if front != null and front.side == side and front.is_active():
			continue  # he stands behind a man; the line is closed in front of him
		n += 1
	return n


## [spearmen standing in the wall, bows still standing] for a side.
func arms_count(side: int) -> Array[int]:
	var spears := 0
	for w in battle.wall_members(side):
		if w.role == CombatTypes.Role.SPEAR:
			spears += 1
	var bows := 0
	for w in battle.active(side):
		if not w.broken and w.role == CombatTypes.Role.MISSILE:
			bows += 1
	return [spears, bows]


## The shape your band forms on "Shield wall!"; cycles the presets and
## queues the shout so the next round forms it.
func cycle_formation() -> void:
	var presets := FormationTemplate.presets()
	var cur: FormationTemplate = player.formation
	var idx := 0
	for i in presets.size():
		if cur != null and presets[i].name == cur.name:
			idx = (i + 1) % presets.size()
	player.formation = presets[idx]
	pending_shout = CombatTypes.Shout.SHIELD_WALL
	queue_redraw()


func formation_name() -> String:
	return player.formation.name if player != null and player.formation != null else "line"


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
## if the pending shout were given now, with how surely he would hear it,
## and his reason when that is not the plain default for the order
## ("" when it is). Does not change the sim.
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
		var saved_reason := w.last_reason
		var saved_option := w.last_option
		var saved_looted := w.looted
		if shout != CombatTypes.Shout.NONE and chance > 0.0:
			w.heard_order = shout
		var a: Action
		var reason := ""
		if w == player and pending_action != null:
			a = pending_action
		else:
			a = Decision.choose(SimRng.new(w.id * 31 + battle.round), rules, battle.grid, w, leader, battle.warriors)
			reason = w.last_reason
		w.heard_order = saved_order
		w.order_lag = saved_lag
		w.last_reason = saved_reason
		w.last_option = saved_option
		w.looted = saved_looted
		out.append({"warrior": w, "action": a, "chance": chance, "reason": reason})
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
	follow = false  # a pinch is the player taking the camera
	camera_moved.emit()
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
		tapped.emit(BattleGrid.NO_CELL)
		return
	if BattleGrid.chebyshev(cell, player.pos) != 1:
		return
	if in_wall(player) and battle.wall_members(player.side).size() >= 2 \
			and cell == player.pos + BattleGrid.forward(player.pos, player.wall_axis(), player.wall_facing()):
		pending_advance = true  # a tap ahead takes the wall forward, not the man
		pending_action = null
		queue_redraw()
		tapped.emit(cell)
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
	tapped.emit(cell)


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	if battle == null:
		return
	var g := battle.grid
	for row in g.height:
		for col_i in g.width:
			_draw_ground(g, BattleGrid.from_offset(col_i, row), (col_i + row) % 2 == 0)
	# Things standing on the ground second, top row first, so a tree's crown
	# overlaps the hex behind it; the men (child tokens) draw above it all.
	for row in g.height:
		for col_i in g.width:
			_draw_feature(g, BattleGrid.from_offset(col_i, row))
	if g.has_sea:
		_draw_masts()
	if is_night():
		_draw_night()
	draw_objective()
	_draw_guide()
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
			# A man thinking for himself (not the plain default for the
			# order) gets a small dot above his head: gold on our side.
			if p.reason != "":
				var at: Vector2 = (tokens[w] as Token).position if tokens.has(w) else from
				var dot := at + Vector2(-Token.R - 6, -Token.R - 16)
				draw_circle(dot, 4.5, Palette.OUTLINE)
				draw_circle(dot, 3.5, Color(Palette.GOLD, alpha))


## The burned hall is fought at night (Objective.Kind.ESCAPE), and so are
## the saga's fights at a hall (Battle.night).
func is_night() -> bool:
	return battle.night or (battle.objective != null and battle.objective.kind == Objective.Kind.ESCAPE)


## Whether the hall's roof is burning: the escape and the burning always,
## a defence once the fire has taken.
func hall_burning() -> bool:
	return battle.hall_alight or (battle.objective != null and battle.objective.kind == Objective.Kind.ESCAPE)


## Night over the ground (the men, drawn above, stay clear to read), then
## the hall burning: flames on every hex of its timber, a glow round it,
## and embers going up.
func _draw_night() -> void:
	var g := battle.grid
	var dark := Color(0.02, 0.03, 0.09, 0.5)
	var hall: Array[Vector2i] = []
	for row in g.height:
		for col_i in g.width:
			var c := BattleGrid.from_offset(col_i, row)
			draw_colored_polygon(Iso.hexagon(c, 0.0), dark)
			if g.terrain_at(c) == CombatTypes.Terrain.BUILDING:
				hall.append(c)
	if hall.is_empty():
		return
	var t := _fire_time
	var s := Iso.SIZE
	if not hall_burning():
		_draw_torches(t)
		return
	var centre := Vector2.ZERO
	for c in hall:
		centre += Iso.to_screen(c)
	centre /= hall.size()
	draw_circle(centre, s * 4.5, Color(1.0, 0.45, 0.1, 0.07 + 0.02 * sin(t * 3.0)))
	for c in hall:
		var p := Iso.to_screen(c)
		var h := absi((c.x * 73856093) ^ (c.y * 19349663))
		for k in 3:
			var ph := float((h >> (k * 3)) % 7) + k * 1.7
			var flick := 0.75 + 0.25 * sin(t * (5.0 + k) + ph)
			var base := p + Vector2((k - 1) * s * 0.42, s * 0.25)
			var hgt := s * (0.55 + 0.25 * float((h >> k) % 3) / 2.0) * flick
			var wid := s * 0.2
			draw_colored_polygon(PackedVector2Array([base + Vector2(-wid, 0), base + Vector2(0, -hgt), base + Vector2(wid, 0)]),
					Color(0.95, 0.42, 0.08, 0.9))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-wid * 0.5, 0), base + Vector2(0, -hgt * 0.6), base + Vector2(wid * 0.5, 0)]),
					Color(1.0, 0.82, 0.3, 0.95))
	for i in 18:
		var c: Vector2i = hall[(i * 7) % hall.size()]
		var p := Iso.to_screen(c)
		var rise := fmod(t * (18.0 + (i % 5) * 4.0) + i * 23.0, s * 5.0)
		var drift := sin(t * 1.3 + i) * s * 0.3
		var a := 1.0 - rise / (s * 5.0)
		draw_circle(p + Vector2(drift + (i % 3 - 1) * s * 0.3, -rise), 1.6, Color(1.0, 0.6, 0.2, a))


## One hex's ground: turf (checkered faintly), mud, slope with a faint
## hatch, water, the ford's paler water with ripples, a bridge's planks over
## water, a hall's timber, a doorway.
func _draw_ground(g: BattleGrid, c: Vector2i, light: bool) -> void:
	var t := g.terrain_at(c)
	if g.has_sea and _draw_sea(g, c, t):
		return
	var col := Palette.GROUND.lightened(0.04) if light else Palette.GROUND
	match t:
		CombatTypes.Terrain.MUD:
			col = Palette.MUD
		CombatTypes.Terrain.SLOPE:
			col = Palette.SLOPE
		CombatTypes.Terrain.WATER, CombatTypes.Terrain.BRIDGE:
			col = Palette.WATER
		CombatTypes.Terrain.FORD:
			col = Palette.FORD
		CombatTypes.Terrain.BUILDING:
			col = Palette.TIMBER
		CombatTypes.Terrain.DOOR:
			col = Palette.TIMBER.lightened(0.15)
	var hexa := Iso.hexagon(c, 1.0)
	draw_colored_polygon(hexa, col)
	draw_polyline(hexa + PackedVector2Array([hexa[0]]), Palette.GROUND_LINE, 1.0)
	var p := Iso.to_screen(c)
	var s := Iso.SIZE
	match t:
		CombatTypes.Terrain.SLOPE:
			for i in range(-2, 3):
				var o := Vector2(i * s * 0.32, 0)
				draw_line(p + o + Vector2(-s * 0.12, s * 0.28), p + o + Vector2(s * 0.12, -s * 0.28), Palette.HATCH, 1.5)
		CombatTypes.Terrain.FORD:
			for i in 2:
				var y := (i - 0.5) * s * 0.42
				draw_arc(p + Vector2(-s * 0.25, y), s * 0.2, PI * 1.1, PI * 1.9, 6, Palette.RIPPLE, 1.5)
				draw_arc(p + Vector2(s * 0.22, y + s * 0.1), s * 0.2, PI * 1.1, PI * 1.9, 6, Palette.RIPPLE, 1.5)
		CombatTypes.Terrain.BRIDGE:
			# Planks across the stream, between two rails.
			var w := s * 0.62
			draw_rect(Rect2(p + Vector2(-w, -s * 0.5), Vector2(2 * w, s)), Palette.PLANK)
			for i in 5:
				var x := -w + (i + 0.5) * (2 * w / 5.0)
				draw_line(p + Vector2(x, -s * 0.5), p + Vector2(x, s * 0.5), Palette.OUTLINE, 1.0)
			draw_line(p + Vector2(-w, -s * 0.5), p + Vector2(w, -s * 0.5), Palette.TRUNK, 3.0)
			draw_line(p + Vector2(-w, s * 0.5), p + Vector2(w, s * 0.5), Palette.TRUNK, 3.0)
		CombatTypes.Terrain.BUILDING:
			# A roof ridge across the hall's hex, and its eaves.
			draw_colored_polygon(Iso.hexagon(c, 6.0), Palette.TIMBER.lightened(0.08))
			draw_line(p + Vector2(-s * 0.8, 0), p + Vector2(s * 0.8, 0), Palette.ROOF, 4.0)
			draw_polyline(Iso.hexagon(c, 2.0) + PackedVector2Array([Iso.hexagon(c, 2.0)[0]]), Palette.OUTLINE, 2.0)
		CombatTypes.Terrain.DOOR:
			# The doorway: a lighter notch in the timber, posts either side.
			draw_rect(Rect2(p + Vector2(-s * 0.3, -s * 0.42), Vector2(s * 0.6, s * 0.84)), Palette.DOOR)
			draw_line(p + Vector2(-s * 0.36, -s * 0.46), p + Vector2(-s * 0.36, s * 0.46), Palette.OUTLINE, 3.0)
			draw_line(p + Vector2(s * 0.36, -s * 0.46), p + Vector2(s * 0.36, s * 0.46), Palette.OUTLINE, 3.0)


## What stands on a hex: a tree (dark crown, trunk dot), a rock (a grey
## lump), a fence (a brown rail along the hex, with posts).
func _draw_feature(g: BattleGrid, c: Vector2i) -> void:
	var t := g.terrain_at(c)
	var p := Iso.to_screen(c)
	var s := Iso.SIZE
	var h := (c.x * 73856093) ^ (c.y * 19349663)  # a fixed wobble per hex
	match t:
		CombatTypes.Terrain.TREE:
			var o := Vector2(float(h % 5) - 2.0, float((h / 5) % 5) - 4.0)
			draw_circle(p + o + Vector2(0, s * 0.25), s * 0.18, Color(Palette.OUTLINE, 0.35))  # its shadow
			draw_circle(p + o, s * 0.62, Palette.OUTLINE)
			draw_circle(p + o, s * 0.56, Palette.TREE)
			draw_circle(p + o + Vector2(-s * 0.15, -s * 0.15), s * 0.28, Palette.TREE_LIGHT)
			draw_circle(p + o + Vector2(0, s * 0.08), s * 0.09, Palette.TRUNK)
		CombatTypes.Terrain.ROCK:
			var pts := PackedVector2Array()
			for i in 7:
				var a := TAU * i / 7.0
				var r := s * (0.58 + 0.12 * float((h >> i) & 1))
				pts.append(p + Vector2(cos(a) * r, sin(a) * r * 0.72 - s * 0.08))
			draw_colored_polygon(pts, Palette.ROCK)
			draw_circle(p + Vector2(-s * 0.18, -s * 0.24), s * 0.18, Palette.ROCK.lightened(0.18))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Palette.OUTLINE, 2.5)
			draw_line(p + Vector2(-s * 0.05, -s * 0.12), p + Vector2(s * 0.3, s * 0.12), Palette.ROCK_DARK, 2.5)
		CombatTypes.Terrain.FENCE:
			var a := p + Vector2(-s * 0.88, 0)
			var b := p + Vector2(s * 0.88, 0)
			draw_line(a + Vector2(0, -4), b + Vector2(0, -4), Palette.OUTLINE, 5.0)
			draw_line(a + Vector2(0, -4), b + Vector2(0, -4), Palette.FENCE, 3.0)
			draw_line(a + Vector2(0, 4), b + Vector2(0, 4), Palette.FENCE, 2.0)
			for x in [-0.7, 0.0, 0.7]:
				draw_line(p + Vector2(s * x, -10), p + Vector2(s * x, 8), Palette.OUTLINE, 4.0)
				draw_line(p + Vector2(s * x, -10), p + Vector2(s * x, 8), Palette.FENCE.darkened(0.2), 2.0)


## The objective's ground, behind the tokens: each cell filled faintly and
## outlined in its colour, and its short name once, beside the patch on the
## side away from the fight.
func draw_objective() -> void:
	var obj := battle.objective
	if obj == null or obj.cells.is_empty():
		return
	var col := Palette.objective_color(obj.kind)
	var fill := 0.32
	if guide_goal:
		# Where to go now (the tutorial): the edge pulses gold.
		var pulse := 0.5 + 0.5 * sin(_fire_time * 4.0)
		col = col.lerp(Palette.GOLD, 0.6 + 0.4 * pulse)
		fill = 0.25 + 0.3 * pulse
	var left := Vector2(INF, 0)
	for c in obj.cells:
		var hexa := Iso.hexagon(c, 2.0)
		draw_colored_polygon(hexa, Color(col, fill))
		draw_polyline(hexa + PackedVector2Array([hexa[0]]), Palette.OUTLINE, 5.0)
		draw_polyline(hexa + PackedVector2Array([hexa[0]]), col, 3.0)
		var p := Iso.to_screen(c)
		if p.x < left.x:
			left = p
	var font := ThemeDB.fallback_font
	var size := 20
	var text := obj.short_name().to_upper()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	# Off the patch's left end, where the lines' wings rarely stand, so the
	# name is neither under the men nor under the HUD bars.
	var pos := Vector2(left.x - Iso.SIZE - w, left.y + size * 0.35)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Palette.OUTLINE)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## The tutorial's marks: a pulsing gold ring round the man or hex the
## banner means, and, when the objective's edge is where to go, an arrow
## from your man toward its nearest hex.
func _draw_guide() -> void:
	var pulse := 0.55 + 0.45 * sin(_fire_time * 5.0)
	if guide_cell != BattleGrid.NO_CELL and battle.grid.in_bounds(guide_cell):
		var at := Iso.to_screen(guide_cell)
		draw_arc(at, Token.R + 9.0, 0, TAU, 32, Palette.OUTLINE, 6.0)
		draw_arc(at, Token.R + 9.0, 0, TAU, 32, Color(Palette.GOLD, pulse), 3.5)
		draw_arc(at, Token.R + 15.0, 0, TAU, 32, Color(Palette.GOLD, pulse * 0.4), 2.0)
	var obj := battle.objective
	if guide_goal and obj != null and not obj.cells.is_empty() and player != null and player.is_active():
		# The nearest hex of the edge, and of those the one most nearly
		# straight ahead up the field.
		var best: Vector2i = obj.cells[0]
		var here := BattleGrid.to_offset(player.pos)
		for c in obj.cells:
			var d := BattleGrid.distance(player.pos, c)
			var bd := BattleGrid.distance(player.pos, best)
			if d < bd or (d == bd and absi(BattleGrid.to_offset(c).x - here.x) < absi(BattleGrid.to_offset(best).x - here.x)):
				best = c
		if best == player.pos:
			return
		var from := Iso.to_screen(player.pos)
		var to := Iso.to_screen(best)
		var dir := (to - from).normalized()
		var start := from + dir * (Token.R + 18.0)
		var end := to - dir * Iso.SIZE * 0.4
		if (end - start).dot(dir) > 8.0:
			_arrow(start, end, Palette.OUTLINE, 7.0)
			_arrow(start, end, Color(Palette.GOLD, 0.45 + 0.4 * pulse), 4.0)


## Faint outlines of the line's slots while the standing order is Shield Wall.
func _draw_wall_slots() -> void:
	var order := battle.last_shout(player.side)
	if order != CombatTypes.Shout.SHIELD_WALL and pending_shout != CombatTypes.Shout.SHIELD_WALL:
		return
	var leader := battle.leader_of(player.side)
	if leader == null:
		return
	var n := battle.active(player.side).size() - 1
	for slot in Formation.open_line_slots(battle.grid, leader, n):
		if battle.grid.occupant(slot) == null:
			draw_polyline(Iso.hexagon(slot, 6) + PackedVector2Array([Iso.hexagon(slot, 6)[0]]), Color(Palette.BONE, 0.35), 1.5)


## A bar between neighbours whose shields are locked: the wall you can see.
func _draw_shield_locks() -> void:
	for w in battle.warriors:
		if not w.is_active() or w.broken:
			continue
		for n in battle.grid.line_neighbors(w):
			if n.id < w.id or n.broken:
				continue
			var a := _spot(w, w.pos)
			var b := _spot(n, n.pos)
			var locked := w.shield_usable() and n.shield_usable()
			if not locked:
				# Linked but not locked: a shield is gone here. A thin dark
				# thread shows the gap in the wall.
				draw_line(a, b, Palette.OUTLINE, 3.0)
				draw_line(a, b, Palette.BLOOD.darkened(0.3), 1.5)
				continue
			# The leader's wall is bright; a broken-off fragment is dim.
			var whole := in_wall(w) and in_wall(n)
			var col := Palette.BONE if w.side == player.side else Palette.UNDYED.darkened(0.3)
			if not whole:
				col = col.darkened(0.45)
			draw_line(a, b, Palette.OUTLINE, 7.0)
			draw_line(a, b, col, 4.0)


## A missile's flight: a thin line that fades, red-tipped when it lands.
func _flash_shot(from: Vector2, to: Vector2, missed: bool) -> void:
	if anim_scale <= 0.0:
		return
	var l := Line2D.new()
	l.width = 2.0
	l.default_color = Palette.BONE if missed else Palette.BLOOD
	l.points = PackedVector2Array([from, from])
	l.z_index = 20
	add_child(l)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void: l.points = PackedVector2Array([from.lerp(to, maxf(0.0, t - 0.3)), from.lerp(to, t)]), 0.0, 1.0, 0.3 * anim_scale)
	tw.tween_property(l, "modulate:a", 0.0, 0.2 * anim_scale)
	tw.tween_callback(l.queue_free)


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


## The night before the roof takes: firelight at the doors, and a torch in
## the hand of every attacker at the walls (Objective.Kind.FIRE's cells).
func _draw_torches(t: float) -> void:
	var g := battle.grid
	var s := Iso.SIZE
	for row in g.height:
		for col_i in g.width:
			var c := BattleGrid.from_offset(col_i, row)
			if g.terrain_at(c) == CombatTypes.Terrain.DOOR:
				draw_circle(Iso.to_screen(c), s * 1.2, Color(1.0, 0.6, 0.2, 0.10 + 0.03 * sin(t * 2.0)))
	var obj := battle.objective
	if obj == null or obj.kind != Objective.Kind.FIRE:
		return
	for w in battle.active(obj.attacker):
		if not obj.has_cell(w.pos):
			continue
		var p: Vector2 = (tokens[w] as Token).position if tokens.has(w) else Iso.to_screen(w.pos)
		var base := p + Vector2(Token.R * 0.9, -Token.R * 0.6)
		var flick := 0.8 + 0.2 * sin(t * 7.0 + float(w.id))
		draw_circle(base, s * 0.9, Color(1.0, 0.5, 0.15, 0.12))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-4, 0), base + Vector2(0, -14 * flick), base + Vector2(4, 0)]), Color(0.95, 0.45, 0.1, 0.95))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-2, 0), base + Vector2(0, -8 * flick), base + Vector2(2, 0)]), Color(1.0, 0.85, 0.35, 1.0))


## The ship fight's water and planking: open sea in the map's teal with a
## wave mark or two, the deck in planks with a seam along the hull, and the
## gunwale strake along the rail on its outer side.
func _draw_sea(g: BattleGrid, c: Vector2i, t: CombatTypes.Terrain) -> bool:
	var p := Iso.to_screen(c)
	var s := Iso.SIZE
	var hexa := Iso.hexagon(c, 0.0)
	match t:
		CombatTypes.Terrain.SEA:
			draw_colored_polygon(hexa, SEA_DEEP)
			var h := absi((c.x * 73856093) ^ (c.y * 19349663))
			var o := Vector2(float(h % 7) - 3.0, float((h / 7) % 5) - 2.0) * s * 0.06
			draw_arc(p + o + Vector2(-s * 0.25, 0), s * 0.22, PI * 1.15, PI * 1.85, 6, SEA_WAVE, 2.0)
			draw_arc(p + o + Vector2(s * 0.2, s * 0.22), s * 0.18, PI * 1.15, PI * 1.85, 6, SEA_WAVE, 2.0)
			# Foam where the sea meets a hull.
			for n in g.neighbors(c):
				var nt := g.terrain_at(n)
				if nt == CombatTypes.Terrain.RAIL or nt == CombatTypes.Terrain.FLAT:
					var q := Iso.to_screen(n)
					draw_line(p.lerp(q, 0.38), p.lerp(q, 0.46), Color(SEA_FOAM, 0.55), 3.0)
			return true
		CombatTypes.Terrain.FLAT, CombatTypes.Terrain.RAIL:
			draw_colored_polygon(hexa, DECK)
			for i in range(-1, 2):
				var y := i * s * 0.36
				draw_line(p + Vector2(-s * 0.85, y), p + Vector2(s * 0.85, y), DECK_SEAM, 1.0)
			if t == CombatTypes.Terrain.RAIL:
				# The strake: a dark band along the edge that faces the water.
				for n in g.neighbors(c):
					if g.terrain_at(n) == CombatTypes.Terrain.SEA:
						var q := Iso.to_screen(n)
						var mid := p.lerp(q, 0.48)
						var across := (q - p).normalized().orthogonal() * s * 0.5
						draw_line(mid - across, mid + across, STRAKE, 5.0)
						draw_line(mid - across, mid + across, Palette.OUTLINE, 1.5)
			return true
		CombatTypes.Terrain.BRIDGE:
			# A gangway: planks over the water between the gunwales.
			draw_colored_polygon(hexa, SEA_DEEP)
			var w := s * 0.5
			draw_rect(Rect2(p + Vector2(-w, -s * 0.85), Vector2(2 * w, s * 1.7)), Palette.PLANK)
			for i in 4:
				var y := -s * 0.85 + (i + 0.5) * (s * 1.7 / 4.0)
				draw_line(p + Vector2(-w, y), p + Vector2(w, y), Palette.OUTLINE, 1.0)
			draw_line(p + Vector2(-w, -s * 0.85), p + Vector2(-w, s * 0.85), STRAKE, 2.5)
			draw_line(p + Vector2(w, -s * 0.85), p + Vector2(w, s * 0.85), STRAKE, 2.5)
			return true
	return false


## Each hull's mast, amidships on its middle row, with the yard across it
## and the sail furled along the yard.
func _draw_masts() -> void:
	var obj := battle.objective
	if obj == null or obj.hulls.is_empty():
		return
	var s := Iso.SIZE
	for side in obj.hulls:
		var cells: Array = obj.hulls[side]
		if cells.is_empty():
			continue
		var sum := Vector2.ZERO
		for c: Vector2i in cells:
			sum += Iso.to_screen(c)
		var at := sum / cells.size() + Vector2(s * 1.2, 0)
		draw_circle(at, s * 0.2, Palette.OUTLINE)
		draw_circle(at, s * 0.15, STRAKE)
		draw_line(at + Vector2(0, -s * 1.1), at + Vector2(0, s * 1.1), Palette.OUTLINE, 5.0)
		draw_line(at + Vector2(0, -s * 1.1), at + Vector2(0, s * 1.1), Color("c9b48a"), 3.0)
