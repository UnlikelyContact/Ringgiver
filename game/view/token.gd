class_name Token
extends Node2D
## One man on the grid, drawn as a chunky token in the decided look: the
## shield face is his identity (device and colour), with the four readouts
## the concept asks for (wounded, winded, wavering, heard you) drawn as marks.

var warrior: Warrior
var rules: CombatRules
var is_player := false
var heard_this_round := false
var device := 0  # 0 quarters, 1 pinwheel, 2 serpent stripe, 3 plain
var device_color := Palette.BONE
var flash := 0.0  # hit flash timer
var flash_color := Palette.BLOOD
var down_mark := false
## Idle motion: a man shifts his weight, sets his shield, breathes. Each man
## has his own rhythm; a man with an enemy at arm's length is tenser.
var _phase := 0.0
var _sway := Vector2.ZERO
var _tense := false
var _locked := false  # in a wall: a bigger shield set tight, and less sway

const R := 15.0


func setup(w: Warrior, p_rules: CombatRules, player := false) -> void:
	warrior = w
	rules = p_rules
	is_player = player
	device = (w.id * 7) % 4
	device_color = [Palette.BONE, Palette.UNDYED, Palette.GOLD, Palette.BONE][(w.id * 3) % 4]
	z_index = 10
	_phase = fmod(w.id * 2.399, TAU)


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta)
	if warrior == null or down_mark or not visible:
		return
	# Sway: slow and small at rest, quicker and a little wider when tense.
	var speed := 3.2 if _tense else 1.4
	var amp := (1.6 if _tense else 1.0) * (0.6 if _locked else 1.0)
	_phase += delta * speed
	var s := Vector2(sin(_phase) * amp, sin(_phase * 1.7 + 0.8) * amp * 0.6)
	if (s - _sway).length() > 0.15 or flash > 0.0:
		_sway = s
		queue_redraw()


func set_tense(t: bool) -> void:
	_tense = t


func set_locked(l: bool) -> void:
	if l != _locked:
		_locked = l
		queue_redraw()


func hit(color: Color) -> void:
	flash = 0.35
	flash_color = color
	queue_redraw()


func _draw() -> void:
	if warrior == null:
		return
	if down_mark:
		_draw_down()
		return
	var side := Palette.side_color(warrior.side)
	# Ground shadow stays put; the man sways above it.
	draw_circle(Vector2(0, 6), R * 0.9, Color(0, 0, 0, 0.25))
	draw_set_transform(_sway, 0.0, Vector2.ONE * (1.22 if _locked else 1.0))
	var f := Iso.to_screen_f(Vector2(warrior.facing)).normalized()
	var tip := f * (R + 9)
	var side_v := Vector2(-f.y, f.x) * 5
	draw_colored_polygon(PackedVector2Array([tip, f * R * 0.7 + side_v, f * R * 0.7 - side_v]), Palette.BONE if is_player else Palette.UNDYED)
	# Head above the shield rim.
	draw_circle(Vector2(0, -R - 6), 7, Palette.OUTLINE)
	draw_circle(Vector2(0, -R - 6), 5.5, Palette.IRON if warrior.helmet else Palette.WALNUT)
	# Shield: outline, face, device, rim, boss.
	draw_circle(Vector2.ZERO, R + 2, Palette.OUTLINE)
	if warrior.shield_usable():
		draw_circle(Vector2.ZERO, R, side)
		_draw_device(side)
		draw_arc(Vector2.ZERO, R - 1, 0, TAU, 32, Palette.IRON, 2.0)
		draw_circle(Vector2.ZERO, 4, Palette.IRON)
		draw_circle(Vector2.ZERO, 2, Palette.OUTLINE)
		if warrior.has_shield and warrior.shield_hp < rules.shield_hp:
			# Splinters: a crack per lost point.
			for i in rules.shield_hp - warrior.shield_hp:
				var a := 0.9 + i * 1.7
				draw_line(Vector2(cos(a), sin(a)) * 4, Vector2(cos(a + 0.3), sin(a + 0.3)) * (R - 2), Palette.OUTLINE, 2.0)
	else:
		# No shield: a bare tunic disc, weapon shown as a bar.
		draw_circle(Vector2.ZERO, R, side.darkened(0.35))
		draw_line(Vector2(-R, 4), Vector2(R, -4), Palette.IRON, 3.0)
	# Arms: a spearman's shaft across the shield, a bowman's bow at his side,
	# and a tick on the rim for each throwing spear still in hand.
	if warrior.role == CombatTypes.Role.SPEAR:
		var sh := f * (R + 14)
		draw_line(-f * (R + 4), sh, Palette.WALNUT, 3.0)
		draw_line(sh, sh + f * 6, Palette.IRON, 3.0)
	elif warrior.role == CombatTypes.Role.MISSILE:
		var bside := Vector2(-f.y, f.x) * (R + 2)
		draw_arc(bside, 9, atan2(f.y, f.x) - 1.3, atan2(f.y, f.x) + 1.3, 10, Palette.WALNUT, 2.5)
		var ends := [bside + Vector2(cos(atan2(f.y, f.x) - 1.3), sin(atan2(f.y, f.x) - 1.3)) * 9, bside + Vector2(cos(atan2(f.y, f.x) + 1.3), sin(atan2(f.y, f.x) + 1.3)) * 9]
		draw_line(ends[0], ends[1], Palette.BONE, 1.0)
	for j in warrior.javelins:
		var a := -PI / 2 + 0.35 * (j - 0.5 * (warrior.javelins - 1))
		var p := Vector2(cos(a), sin(a)) * (R + 3)
		draw_line(p, p + Vector2(cos(a), sin(a)) * 5, Palette.IRON, 2.0)
	if warrior.armor == CombatTypes.Armor.MAIL:
		draw_arc(Vector2.ZERO, R + 1, 0, TAU, 32, Palette.IRON, 2.0)
	if warrior.is_leader:
		draw_arc(Vector2.ZERO, R + 4, 0, TAU, 32, Palette.GOLD, 2.0)
	if is_player:
		draw_arc(Vector2.ZERO, R + 7, 0, TAU, 32, Palette.BONE, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(-12, -R - 18), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.BONE)
	if warrior.is_banner:
		draw_line(Vector2(R - 2, -R), Vector2(R - 2, -R - 22), Palette.WALNUT, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(R - 2, -R - 22), Vector2(R + 12, -R - 18), Vector2(R - 2, -R - 13)]), side)
	# Readouts.
	_draw_readouts()
	if flash > 0.0:
		draw_circle(Vector2.ZERO, R + 6, Color(flash_color, flash * 1.6))


func _draw_device(side: Color) -> void:
	match device:
		0:
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(0, -R), Vector2(R, 0)]), device_color)
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(0, R), Vector2(-R, 0)]), device_color)
		1:
			for k in 3:
				var a := k * TAU / 3.0
				draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(cos(a), sin(a)) * R, Vector2(cos(a + 0.9), sin(a + 0.9)) * R]), device_color)
		2:
			draw_line(Vector2(-R + 3, 5), Vector2(R - 3, -5), device_color, 5.0)
			draw_circle(Vector2(R - 5, -5), 3, device_color)
		_:
			pass


func _draw_readouts() -> void:
	var y := R + 5
	# Wounded: red pips, one per wound step.
	for i in int(warrior.wound):
		draw_rect(Rect2(-10 + i * 7, y, 5, 5), Palette.BLOOD)
		draw_rect(Rect2(-10 + i * 7, y, 5, 5), Palette.OUTLINE, false, 1.0)
	# Winded: a pale breath mark when breath is low.
	if warrior.fatigue_penalty(rules) > 0:
		draw_circle(Vector2(R + 8, -2), 4, Palette.BREATH)
		draw_circle(Vector2(R + 8, -2), 4, Palette.OUTLINE, false, 1.0)
	# Wavering: a warning ring when morale is at or near the break threshold.
	if warrior.broken:
		draw_arc(Vector2.ZERO, R + 7, 0, TAU, 24, Palette.WARN, 3.0)
		draw_line(Vector2(-6, -R - 16), Vector2(6, -R - 26), Palette.WARN, 3.0)
	elif warrior.morale <= rules.morale_break_threshold + 1:
		draw_arc(Vector2.ZERO, R + 7, 0, TAU, 24, Color(Palette.WARN, 0.8), 2.0)
	# Heard you: a green dot by the head when he took this round's shout.
	if heard_this_round:
		draw_circle(Vector2(-R - 6, -R - 4), 4, Palette.HEARD)
		draw_circle(Vector2(-R - 6, -R - 4), 4, Palette.OUTLINE, false, 1.0)


func _draw_down() -> void:
	var side := Palette.side_color(warrior.side)
	draw_circle(Vector2(0, 4), R * 0.9, Color(0, 0, 0, 0.2))
	draw_line(Vector2(-R, -6), Vector2(R, 6), Palette.OUTLINE, 6.0)
	draw_line(Vector2(-R, 6), Vector2(R, -6), Palette.OUTLINE, 6.0)
	draw_line(Vector2(-R, -6), Vector2(R, 6), side.darkened(0.3), 3.0)
	draw_line(Vector2(-R, 6), Vector2(R, -6), side.darkened(0.3), 3.0)
