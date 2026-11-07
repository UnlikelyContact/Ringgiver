class_name BattleView
extends Node2D
## The battle on screen: the isometric grid, a token per man, the pulse
## clock that advances the simultaneous-turn sim, and the animation of each
## round's beats. Pulsed turns: real time on the surface, turns underneath
## (concept.md, Combat > Pulsed turns).

signal round_played(lines: PackedStringArray)
signal battle_finished(result: BattleResult)
signal auto_paused(reason: String)
signal paused_changed(is_paused: bool)

var battle: Battle
var rules: CombatRules
var player: Warrior
var tokens := {}  # Warrior -> Token
var pulse_seconds := 3.0
var paused := true
var auto_pause := true
var pending_shout: CombatTypes.Shout = CombatTypes.Shout.NONE
var pending_action: Action = null
var clock := 0.0
var animating := false
var anim_scale := 1.0  # 0 for headless screenshots
var _last_enemy_shout: CombatTypes.Shout = CombatTypes.Shout.NONE
var _log_seen := 0
var _by_name := {}


func setup(p_battle: Battle, p_player: Warrior) -> void:
	battle = p_battle
	rules = battle.rules
	player = p_player
	for w in battle.warriors:
		var t := Token.new()
		t.setup(w, rules, w == player)
		t.position = Iso.to_screen(w.pos)
		add_child(t)
		tokens[w] = t
		_by_name[w.display_name] = w
	clock = pulse_seconds
	queue_redraw()


func set_paused(p: bool) -> void:
	if paused == p:
		return
	paused = p
	paused_changed.emit(paused)
	queue_redraw()


func _process(delta: float) -> void:
	if paused or animating or battle == null or battle.is_over():
		return
	clock -= delta
	if clock <= 0.0:
		step()


## Plays one round: locks the pending shout and action, runs the sim, then
## animates what happened.
func step() -> void:
	if battle.is_over():
		return
	var before := {}
	for w in battle.warriors:
		before[w] = w.pos
	if pending_shout != CombatTypes.Shout.NONE:
		battle.set_shout(player.side, pending_shout)
	if pending_action != null:
		battle.set_player_action(player.side, pending_action)
	pending_action = null
	battle.run_round()
	var lines := PackedStringArray()
	for i in range(_log_seen, battle.log.size()):
		lines.append(battle.log[i])
	_log_seen = battle.log.size()
	clock = pulse_seconds
	_animate(before, lines)
	round_played.emit(lines)
	_check_auto_pause(lines)
	if battle.is_over():
		battle_finished.emit(battle.result)


func _animate(before: Dictionary, lines: PackedStringArray) -> void:
	animating = true
	var shout_now := battle.last_shout(player.side)
	var dur := 0.35 * anim_scale
	var tween := create_tween().set_parallel(true)
	var any := false
	for w in battle.warriors:
		var t: Token = tokens[w]
		t.heard_this_round = shout_now != CombatTypes.Shout.NONE and w.side == player.side \
				and w.heard_order == shout_now and w != player
		if w.pos != before[w] and not w.fled:
			any = true
			if dur > 0.0:
				tween.tween_property(t, "position", Iso.to_screen(w.pos), dur).set_trans(Tween.TRANS_SINE)
			else:
				t.position = Iso.to_screen(w.pos)
		if w.is_down():
			t.down_mark = true
			t.z_index = 5
		if w.fled:
			t.visible = false
		t.queue_redraw()
	# Blows land after the movement beat.
	for line in lines:
		if line.contains(" beats "):
			var loser_name := line.split(" beats ")[1].split(" (")[0]
			var loser: Warrior = _by_name.get(loser_name, null)
			if loser != null and tokens.has(loser):
				var heavy := line.contains("heavy") or line.contains("DOWN")
				(tokens[loser] as Token).hit(Palette.BLOOD if heavy else Palette.BONE)
	if dur > 0.0 and any:
		tween.tween_callback(func() -> void: animating = false).set_delay(dur)
	else:
		tween.kill()
		animating = false
	queue_redraw()


func _check_auto_pause(lines: PackedStringArray) -> void:
	if not auto_pause or battle.is_over():
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
		if line.begins_with(name) or line.contains(" beats " + name):
			var w: Warrior = _by_name[name]
			if line.contains(" beats " + name):
				return w.side
	return -1


## The muster preview: what each of our men would likely do if the pending
## shout were given now, with how surely he would hear it. Does not change
## the sim: order_lag and heard_order are restored.
func preview() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var shout := pending_shout
	var leader := battle.leader_of(player.side)
	var horn := false
	var banner := false
	for w in battle.active(player.side):
		horn = horn or w.is_horn
		banner = banner or w.is_banner
	for w in battle.active(player.side):
		if w == player:
			continue
		var dist := BattleGrid.chebyshev(w.pos, leader.pos) if leader != null else 99
		var chance := 1.0
		if shout != CombatTypes.Shout.NONE:
			chance = Shouts.hear_chance(rules, dist, w.wits, horn, battle.fog)
		var saved_order := w.heard_order
		var saved_lag := w.order_lag
		if shout != CombatTypes.Shout.NONE and chance > 0.0:
			w.heard_order = shout
		var a := Decision.choose(SimRng.new(w.id * 31 + battle.round), rules, battle.grid, w, leader, battle.warriors)
		w.heard_order = saved_order
		w.order_lag = saved_lag
		out.append({"warrior": w, "action": a, "chance": chance})
	return out


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	if not pressed or player == null or not player.is_active():
		return
	var cell := Iso.to_cell(get_local_mouse_position())
	if not battle.grid.in_bounds(cell) or BattleGrid.chebyshev(cell, player.pos) != 1:
		return
	var occ := battle.grid.occupant(cell)
	if occ == null and battle.grid.is_free(cell):
		pending_action = Action.move_to(cell, BattleGrid.direction_to(player.pos, cell))
	elif occ != null and occ.side != player.side and occ.is_active():
		pending_action = Action.attack(occ)
	else:
		return
	queue_redraw()
	get_viewport().set_input_as_handled()


# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	if battle == null:
		return
	var g := battle.grid
	for y in g.height:
		for x in g.width:
			var c := Vector2i(x, y)
			var col := Palette.GROUND
			if g.terrain_at(c) == CombatTypes.Terrain.MUD:
				col = Palette.MUD
			elif (x + y) % 2 == 0:
				col = Palette.GROUND.lightened(0.04)
			draw_colored_polygon(Iso.diamond(c), col)
			draw_polyline(Iso.diamond(c) + PackedVector2Array([Iso.diamond(c)[0]]), Palette.GROUND_LINE, 1.0)
	if player != null and player.is_active():
		# Your man's cell, and where you can step or strike.
		draw_colored_polygon(Iso.diamond(player.pos, 3), Color(Palette.GOLD, 0.25))
		if paused:
			for n in g.neighbors(player.pos):
				var occ := g.occupant(n)
				if occ == null and g.is_free(n):
					draw_polyline(Iso.diamond(n, 4) + PackedVector2Array([Iso.diamond(n, 4)[0]]), Color(Palette.BONE, 0.5), 1.5)
				elif occ != null and occ.side != player.side and occ.is_active():
					draw_polyline(Iso.diamond(n, 4) + PackedVector2Array([Iso.diamond(n, 4)[0]]), Color(Palette.BLOOD, 0.8), 2.0)
		if pending_action != null:
			var target := pending_action.target_cell
			draw_colored_polygon(Iso.diamond(target, 5), Color(Palette.GOLD, 0.45))
			draw_line(Iso.to_screen(player.pos), Iso.to_screen(target), Palette.GOLD, 3.0)
	if paused:
		# Muster preview: intent arrows for our men, faded by how surely they hear.
		for p in preview():
			var w: Warrior = p.warrior
			var a: Action = p.action
			var from := Iso.to_screen(w.pos)
			var alpha: float = 0.25 + 0.75 * p.chance
			var col := Color(Palette.BONE, alpha)
			match a.kind:
				CombatTypes.ActionKind.MOVE, CombatTypes.ActionKind.FLEE:
					_arrow(from, Iso.to_screen(a.target_cell), col)
				CombatTypes.ActionKind.ATTACK:
					if a.target != null:
						_arrow(from, Iso.to_screen(a.target.pos), Color(Palette.BLOOD, alpha))
				CombatTypes.ActionKind.BRACE:
					draw_arc(from, 20, 0, TAU, 20, col, 2.0)
				_:
					pass


func _arrow(from: Vector2, to: Vector2, col: Color) -> void:
	var d := (to - from)
	if d.length() < 1.0:
		return
	var n := d.normalized()
	var start := from + n * 18
	var end := to - n * 18
	draw_line(start, end, col, 3.0)
	var side := Vector2(-n.y, n.x) * 6
	draw_colored_polygon(PackedVector2Array([end + n * 8, end - n * 2 + side, end - n * 2 - side]), col)
