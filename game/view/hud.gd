extends CanvasLayer
## Shout bar, next-round and pulse controls, follow toggle, status with the
## wall count, your man's line, the log and the result panel.

var view: BattleView
var main: Node
var log_label: RichTextLabel
var status: Label
var you_label: Label
var next_btn: Button
var follow_btn: Button
var shout_buttons := {}
var result_panel: PanelContainer
var pulse_slider: HSlider
var pulse_label: Label
var _last_logged_shout := {}

const SHOUTS := [
	CombatTypes.Shout.SHIELD_WALL, CombatTypes.Shout.HOLD, CombatTypes.Shout.PUSH,
	CombatTypes.Shout.TO_ME, CombatTypes.Shout.BREAK_THEM, CombatTypes.Shout.FALL_BACK,
]


func setup(p_view: BattleView, p_main: Node) -> void:
	view = p_view
	main = p_main
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 10
	top.offset_right = -10
	top.offset_top = 6
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(left)
	status = Label.new()
	status.add_theme_color_override("font_color", Palette.TEXT)
	status.add_theme_font_size_override("font_size", 17)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(200, 0)
	left.add_child(status)
	you_label = Label.new()
	you_label.add_theme_color_override("font_color", Palette.GOLD)
	you_label.add_theme_font_size_override("font_size", 14)
	you_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	you_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	you_label.custom_minimum_size = Vector2(200, 0)
	left.add_child(you_label)
	var adv := Button.new()
	adv.text = "Advance"
	adv.custom_minimum_size = Vector2(92, 40)
	adv.pressed.connect(func() -> void: view.advance())
	top.add_child(adv)
	var wheel_l := Button.new()
	wheel_l.text = "Wheel L"
	wheel_l.custom_minimum_size = Vector2(84, 40)
	wheel_l.pressed.connect(func() -> void: view.wheel(-1))
	top.add_child(wheel_l)
	var wheel_r := Button.new()
	wheel_r.text = "Wheel R"
	wheel_r.custom_minimum_size = Vector2(84, 40)
	wheel_r.pressed.connect(func() -> void: view.wheel(1))
	top.add_child(wheel_r)
	follow_btn = Button.new()
	follow_btn.text = "Follow"
	follow_btn.toggle_mode = true
	follow_btn.button_pressed = true
	follow_btn.custom_minimum_size = Vector2(84, 40)
	follow_btn.toggled.connect(func(on: bool) -> void: view.follow = on)
	top.add_child(follow_btn)
	pulse_label = Label.new()
	pulse_label.add_theme_color_override("font_color", Palette.DIM)
	top.add_child(pulse_label)
	pulse_slider = HSlider.new()
	pulse_slider.min_value = 0.0
	pulse_slider.max_value = 8.0
	pulse_slider.step = 0.5
	pulse_slider.value = view.pulse_seconds
	pulse_slider.custom_minimum_size = Vector2(120, 24)
	pulse_slider.value_changed.connect(func(v: float) -> void:
		view.pulse_seconds = v
		view.clock = v
		_refresh())
	top.add_child(pulse_slider)
	next_btn = Button.new()
	next_btn.custom_minimum_size = Vector2(150, 56)
	next_btn.add_theme_font_size_override("font_size", 18)
	next_btn.pressed.connect(_on_next)

	var stamp := Label.new()
	stamp.text = "build " + _build_stamp()
	stamp.add_theme_font_size_override("font_size", 10)
	stamp.add_theme_color_override("font_color", Palette.DIM)
	stamp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stamp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	stamp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stamp.offset_right = -6
	stamp.offset_bottom = -64
	root.add_child(stamp)
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 10
	bottom.offset_right = -10
	bottom.offset_top = -62
	bottom.offset_bottom = -6
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bottom)
	for s in SHOUTS:
		var b := Button.new()
		b.text = CombatTypes.SHOUT_NAMES[s].capitalize() + "!"
		b.custom_minimum_size = Vector2(112, 52)
		b.toggle_mode = true
		b.pressed.connect(_on_shout.bind(s))
		bottom.add_child(b)
		shout_buttons[s] = b
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(16, 0)
	bottom.add_child(gap)
	bottom.add_child(next_btn)

	log_label = RichTextLabel.new()
	log_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_label.offset_left = 10
	log_label.offset_top = -170
	log_label.offset_right = 330
	log_label.offset_bottom = -66
	log_label.scroll_following = true
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_label.add_theme_color_override("default_color", Palette.DIM)
	log_label.add_theme_font_size_override("normal_font_size", 13)
	root.add_child(log_label)

	result_panel = PanelContainer.new()
	result_panel.anchor_left = 0.14
	result_panel.anchor_right = 0.86
	result_panel.anchor_top = 0.2
	result_panel.anchor_bottom = 0.8
	result_panel.visible = false
	root.add_child(result_panel)

	view.round_played.connect(_on_round)
	view.battle_finished.connect(_on_finished)
	view.auto_paused.connect(_on_auto_paused)
	view.paused_changed.connect(func(_p: bool) -> void: _refresh())
	view.camera_moved.connect(func() -> void: follow_btn.button_pressed = view.follow)
	_refresh()


func _on_next() -> void:
	if view.is_manual():
		view.step()
	else:
		view.set_paused(not view.paused)
	_refresh()


func _on_shout(s: CombatTypes.Shout) -> void:
	view.pending_shout = CombatTypes.Shout.NONE if view.pending_shout == s else s
	for k in shout_buttons:
		(shout_buttons[k] as Button).button_pressed = (k == view.pending_shout)
	_refresh()
	view.queue_redraw()


func _on_round(lines: PackedStringArray) -> void:
	for line in lines:
		var col := Palette.DIM
		var keep := false
		if line.contains("DOWN") or line.contains("breaks") or line.contains("flees") or line.contains("===") or line.contains("drives forward"):
			col = Palette.WARN
			keep = true
		elif line.contains("shouts:"):
			var who := line.split(" shouts:")[0]
			if _last_logged_shout.get(who, "") == line:
				continue
			_last_logged_shout[who] = line
			col = Palette.TEXT
			keep = true
		elif line.contains("(hit") or line.contains("(heavy"):
			keep = true
		if not keep:
			continue
		log_label.push_color(col)
		log_label.add_text(line.replace("the leader", "").strip_edges() + "\n")
		log_label.pop()
	while log_label.get_line_count() > 7:
		log_label.remove_paragraph(0)
	for s in shout_buttons:
		(shout_buttons[s] as Button).button_pressed = false
	view.pending_shout = CombatTypes.Shout.NONE
	_refresh()


func _on_auto_paused(reason: String) -> void:
	log_label.push_color(Palette.GOLD)
	log_label.add_text("paused: %s\n" % reason)
	log_label.pop()
	_refresh()


## The outcome in plain words rather than the sim's summary line.
func _result_text(r: BattleResult) -> String:
	var why := ""
	for line in r.log:
		if line.begins_with("==="):
			why = line.trim_prefix("=== ").trim_suffix(" ===").replace("side 0", "your band").replace("side 1", "their band")
	return "%s after %d rounds.\nYours: %d of %d down, %d broke, %d fled, %d dead.\nTheirs: %d of %d down, %d broke, %d fled, %d dead." % [
		(why[0].to_upper() + why.substr(1)) if why != "" else "The fight is over", r.rounds,
		r.downed[0], r.started[0], r.broken[0], r.fled[0], r.dead[0],
		r.downed[1], r.started[1], r.broken[1], r.fled[1], r.dead[1]]


func _on_finished(result: BattleResult) -> void:
	result_panel.visible = true
	for c in result_panel.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	result_panel.add_child(box)
	var title := Label.new()
	title.text = "Victory" if result.winner == 0 else ("Defeat" if result.winner == 1 else "Both sides draw off")
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = _result_text(result)
	box.add_child(body)
	var again := Button.new()
	again.text = "Fight again"
	again.custom_minimum_size = Vector2(160, 44)
	again.pressed.connect(func() -> void: main.start(main.scenario, main.seed_in + 1))
	box.add_child(again)
	_refresh()


## The short commit the web build was made from (scripts/export-web.sh
## writes it); "dev" when running from the editor or a tool.
func _build_stamp() -> String:
	if FileAccess.file_exists("res://build.txt"):
		var f := FileAccess.open("res://build.txt", FileAccess.READ)
		if f != null:
			var text := f.get_as_text().strip_edges()
			if text != "":
				return text
	return "dev"


func _refresh() -> void:
	var b := view.battle
	var mine := view.wall_count(0)
	var theirs := view.wall_count(1)
	var order := b.last_shout(0)
	var their_order := b.last_shout(1)
	status.text = "Round %d   wall %d/%d   theirs %d/%d%s%s" % [b.round, mine[0], mine[1], theirs[0], theirs[1],
			("   order: " + CombatTypes.SHOUT_NAMES[order]) if order != CombatTypes.Shout.NONE else "",
			("   they call: " + CombatTypes.SHOUT_NAMES[their_order]) if their_order != CombatTypes.Shout.NONE else ""]
	var warn := ""
	if view.player.is_active() and b.round > 0 and view.wall_count(0)[0] < 2:
		warn = "   (nobody stands with you)"
	elif view.player.is_active() and b.round > 0 and view.wall_count(0)[0] < view.wall_count(0)[1]:
		warn = "   (the wall is broken: %d of %d with you)" % [view.wall_count(0)[0], view.wall_count(0)[1]]
	you_label.text = (("you: " + view.player_line) if view.player_line != "" else "tap a cell to step or an enemy to strike; tap yourself to act with the line") + warn
	if view.is_manual():
		pulse_label.text = "turns "
		next_btn.text = "Next round"
	else:
		pulse_label.text = "pulse %.1fs " % view.pulse_seconds
		next_btn.text = "Resume" if view.paused else "Pause"
