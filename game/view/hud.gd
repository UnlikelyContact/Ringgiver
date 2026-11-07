extends CanvasLayer
## Shout bar, pause and pulse controls, the log ticker and the result panel.

var view: BattleView
var main: Node
var log_label: RichTextLabel
var status: Label
var pause_btn: Button
var shout_buttons := {}
var result_panel: PanelContainer
var pulse_slider: HSlider
var pulse_label: Label
var _last_logged_shout := {}  # side name -> shout text, so repeats stay quiet

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

	# Top bar: status and pause.
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 8
	root.add_child(top)
	status = Label.new()
	status.add_theme_color_override("font_color", Palette.TEXT)
	status.add_theme_font_size_override("font_size", 18)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(status)
	pulse_label = Label.new()
	pulse_label.add_theme_color_override("font_color", Palette.DIM)
	top.add_child(pulse_label)
	pulse_slider = HSlider.new()
	pulse_slider.min_value = 1.0
	pulse_slider.max_value = 8.0
	pulse_slider.step = 0.5
	pulse_slider.value = view.pulse_seconds
	pulse_slider.custom_minimum_size = Vector2(140, 24)
	pulse_slider.value_changed.connect(func(v: float) -> void:
		view.pulse_seconds = v
		_refresh())
	top.add_child(pulse_slider)
	pause_btn = Button.new()
	pause_btn.custom_minimum_size = Vector2(120, 44)
	pause_btn.pressed.connect(func() -> void: view.set_paused(not view.paused))
	top.add_child(pause_btn)

	# Bottom bar: shouts.
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12
	bottom.offset_right = -12
	bottom.offset_top = -60
	bottom.offset_bottom = -8
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bottom)
	for s in SHOUTS:
		var b := Button.new()
		b.text = CombatTypes.SHOUT_NAMES[s].capitalize() + "!"
		b.custom_minimum_size = Vector2(150, 48)
		b.toggle_mode = true
		b.pressed.connect(_on_shout.bind(s))
		bottom.add_child(b)
		shout_buttons[s] = b

	# Log ticker, left side.
	log_label = RichTextLabel.new()
	log_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	log_label.offset_left = 12
	log_label.offset_top = -230
	log_label.offset_right = 420
	log_label.offset_bottom = -70
	log_label.scroll_following = true
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_label.add_theme_color_override("default_color", Palette.DIM)
	log_label.add_theme_font_size_override("normal_font_size", 14)
	root.add_child(log_label)

	# Result panel, hidden until the battle ends.
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.visible = false
	root.add_child(result_panel)

	view.round_played.connect(_on_round)
	view.battle_finished.connect(_on_finished)
	view.auto_paused.connect(_on_auto_paused)
	view.paused_changed.connect(func(_p: bool) -> void: _refresh())
	_refresh()


func _on_shout(s: CombatTypes.Shout) -> void:
	if view.pending_shout == s:
		view.pending_shout = CombatTypes.Shout.NONE
	else:
		view.pending_shout = s
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
	while log_label.get_line_count() > 9:
		log_label.remove_paragraph(0)
	# A shout is given once; the men keep it until the next one.
	for s in shout_buttons:
		(shout_buttons[s] as Button).button_pressed = false
	view.pending_shout = CombatTypes.Shout.NONE
	_refresh()


func _on_auto_paused(reason: String) -> void:
	log_label.push_color(Palette.GOLD)
	log_label.add_text("paused: %s\n" % reason)
	log_label.pop()
	_refresh()


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
	body.text = result.summary()
	box.add_child(body)
	var again := Button.new()
	again.text = "Fight again"
	again.custom_minimum_size = Vector2(160, 44)
	again.pressed.connect(func() -> void: main.start(main.scenario, main.seed_in + 1))
	box.add_child(again)
	_refresh()


func _refresh() -> void:
	var b := view.battle
	var mine := 0
	var theirs := 0
	for w in b.active(0):
		if not w.broken:
			mine += 1
	for w in b.active(1):
		if not w.broken:
			theirs += 1
	var theirs_shout := b.last_shout(1)
	status.text = "Round %d   yours %d   theirs %d%s%s" % [b.round, mine, theirs,
			("   your shout: " + CombatTypes.SHOUT_NAMES[view.pending_shout]) if view.pending_shout != CombatTypes.Shout.NONE else "",
			("   they call: " + CombatTypes.SHOUT_NAMES[theirs_shout]) if theirs_shout != CombatTypes.Shout.NONE else ""]
	pulse_label.text = "pulse %.1fs " % view.pulse_seconds
	pause_btn.text = "Resume" if view.paused else "Pause"
