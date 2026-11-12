extends CanvasLayer
## Shout bar, next-round and pulse controls, follow toggle, status with the
## wall count, your man's line, the log and the result panel.

var view: BattleView
var main: Node
var log_label: RichTextLabel
var status: Label
var form_btn: Button
var you_label: Label
var next_btn: Button
var follow_btn: Button
var withdraw_btn: Button
var shout_buttons := {}
var custom_buttons: Array[Button] = []
var drill_panel: UiModal
var result_panel: UiModal
var offer_panel: UiModal
var pulse_slider: HSlider
var pulse_label: Label
var _last_logged_shout := {}
## The controls by name, for the tutorial (view/tutorial.gd): "shout:<n>"
## (CombatTypes.Shout), "next", "withdraw", "form", "advance", "wheel_l",
## "wheel_r", "follow".
var controls := {}
## While the tutorial holds the player's hand, only these controls (names
## as in `controls`) can be pressed; empty when it does not.
var allowed: Array[String] = []
## The tutorial director for the burned hall, or null (any other fight).
var tutorial: Tutorial = null
var root_control: Control

const SHOUTS := [
	CombatTypes.Shout.SHIELD_WALL, CombatTypes.Shout.HOLD, CombatTypes.Shout.PUSH,
	CombatTypes.Shout.TO_ME, CombatTypes.Shout.BREAK_THEM, CombatTypes.Shout.FALL_BACK,
	CombatTypes.Shout.TAUNT,
]


## The top of the screen: the strip of the fight's numbers on the left,
## the controls on the right; on a narrow screen the strip goes under them.
var top_row: HBoxContainer
var strip: PanelContainer
var buttons_row: HBoxContainer
var _line_round: RichTextLabel
var _line_walls: RichTextLabel
var _log_panel: PanelContainer
## The strip's least width beside the controls; narrower, it goes under.
const STRIP_MIN := 380.0
const COLORS := {"gold": "dcb862", "muted": "ab9f8a", "ours": "d9776a", "theirs": "86a4d6", "text": "ece3cf", "warn": "e0b43a"}


func setup(p_view: BattleView, p_main: Node) -> void:
	view = p_view
	main = p_main
	if main != null and main.get("host") == null and main.get("fixed_seed") == true:
		UiTheme.motion = false  # a tool's run: stills of what has arrived
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.apply(root)
	add_child(root)
	root_control = root

	top_row = HBoxContainer.new()
	top_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_row.offset_left = UiTheme.EDGE
	top_row.offset_right = -UiTheme.EDGE
	top_row.offset_top = UiTheme.S2
	top_row.add_theme_constant_override("separation", UiTheme.S2)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_row)
	# The strip: the round and the task on one line, the two walls on the
	# next, and your own man's line (or what to do) under them.
	strip = UiTheme.panel("StripPanel")
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.custom_minimum_size = Vector2(STRIP_MIN, 0)
	top_row.add_child(strip)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 1)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(left)
	_line_round = _rich(16)
	left.add_child(_line_round)
	_line_walls = _rich(15)
	left.add_child(_line_walls)
	status = UiTheme.label("", "SmallLabel", false)
	status.visible = false  # the strip's words, as one line, for anyone who reads it
	left.add_child(status)
	you_label = UiTheme.label("", "SmallLabel", false)
	you_label.add_theme_color_override("font_color", Palette.UI_GOLD)
	you_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	you_label.clip_text = true
	you_label.custom_minimum_size = Vector2(200, 0)
	left.add_child(you_label)
	buttons_row = HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", UiTheme.S1)
	buttons_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	buttons_row.alignment = BoxContainer.ALIGNMENT_END
	top_row.add_child(buttons_row)
	form_btn = _tool("", 136)
	form_btn.pressed.connect(func() -> void:
		view.cycle_formation()
		for k in shout_buttons:
			(shout_buttons[k] as Button).button_pressed = (k == view.pending_shout)
		_refresh())
	buttons_row.add_child(form_btn)
	controls["form"] = form_btn
	var adv := _tool("Advance", 0)
	adv.pressed.connect(func() -> void: view.advance())
	buttons_row.add_child(adv)
	controls["advance"] = adv
	var wheel_l := _tool("Wheel L", 0)
	wheel_l.tooltip_text = "Wheel the line to the left"
	wheel_l.pressed.connect(func() -> void: view.wheel(-1))
	buttons_row.add_child(wheel_l)
	controls["wheel_l"] = wheel_l
	var wheel_r := _tool("Wheel R", 0)
	wheel_r.tooltip_text = "Wheel the line to the right"
	wheel_r.pressed.connect(func() -> void: view.wheel(1))
	buttons_row.add_child(wheel_r)
	controls["wheel_r"] = wheel_r
	withdraw_btn = _tool("Withdraw", 0)
	withdraw_btn.tooltip_text = "Lead your men off the field, out of contact: a choice, not a rout"
	withdraw_btn.pressed.connect(_on_withdraw)
	buttons_row.add_child(withdraw_btn)
	controls["withdraw"] = withdraw_btn
	follow_btn = _tool("Follow", 0)
	follow_btn.toggle_mode = true
	follow_btn.button_pressed = true
	follow_btn.tooltip_text = "Keep the men in view"
	follow_btn.toggled.connect(func(on: bool) -> void: view.follow = on)
	buttons_row.add_child(follow_btn)
	controls["follow"] = follow_btn
	pulse_label = UiTheme.label("", "KeyLabel", false)
	pulse_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pulse_label.custom_minimum_size = Vector2(70, 0)
	pulse_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buttons_row.add_child(pulse_label)
	pulse_slider = HSlider.new()
	pulse_slider.min_value = 0.0
	pulse_slider.max_value = 8.0
	pulse_slider.step = 0.5
	pulse_slider.value = view.pulse_seconds
	pulse_slider.custom_minimum_size = Vector2(110, 44)
	pulse_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pulse_slider.tooltip_text = "Turn by turn, or the rounds go by on their own every so many seconds"
	pulse_slider.value_changed.connect(func(v: float) -> void:
		view.pulse_seconds = v
		view.clock = v
		_refresh())
	buttons_row.add_child(pulse_slider)
	next_btn = UiTheme.primary("Next round", _on_next, 176.0)
	next_btn.add_theme_font_size_override("font_size", 19)
	controls["next"] = next_btn

	var stamp := UiTheme.label("build " + _build_stamp(), "KeyLabel", false)
	stamp.add_theme_font_size_override("font_size", 10)
	stamp.add_theme_color_override("font_color", Color(Palette.UI_FAINT, 0.8))
	stamp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stamp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	stamp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stamp.offset_right = -UiTheme.EDGE
	stamp.offset_bottom = -76
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stamp)
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = UiTheme.EDGE
	bottom.offset_right = -UiTheme.EDGE
	bottom.offset_top = -(UiTheme.TOUCH + UiTheme.S2)  # buttons a thumb can find on a phone (about 45 px)
	bottom.offset_bottom = -UiTheme.S2
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", UiTheme.S1)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	var customs: Array = main.get("custom_shouts") if main != null and main.get("custom_shouts") != null else []
	var wide := 104 if customs.is_empty() else 90
	for s in SHOUTS:
		var b := UiTheme.button(CombatTypes.SHOUT_NAMES[s].capitalize() + "!", Callable(), "CommandButton", Vector2(wide, UiTheme.TOUCH))
		b.toggle_mode = true
		b.pressed.connect(_on_shout.bind(s))
		bottom.add_child(b)
		shout_buttons[s] = b
		controls["shout:%d" % s] = b
	# The band's own shouts, sworn in the drill yard: a shape and an order.
	for c in customs:
		var cs: CustomShout = c
		var cb := UiTheme.button(cs.name + "!", Callable(), "CommandButton", Vector2(wide, UiTheme.TOUCH))
		cb.tooltip_text = cs.describe()
		cb.toggle_mode = true
		cb.pressed.connect(_on_custom.bind(cs, cb))
		bottom.add_child(cb)
		custom_buttons.append(cb)
	bottom.add_child(UiTheme.gap(0, UiTheme.S3))
	bottom.add_child(next_btn)

	# What happened, over the field's lower left: a dark backing, the
	# oldest lines fading out at its top.
	_log_panel = UiTheme.panel("StripPanel")
	_log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log_panel.offset_left = UiTheme.EDGE
	_log_panel.offset_top = -196
	_log_panel.offset_right = UiTheme.EDGE + 380
	_log_panel.offset_bottom = -(UiTheme.TOUCH + UiTheme.S2 * 2)
	_log_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_panel.self_modulate = Color(1, 1, 1, 0.85)
	root.add_child(_log_panel)
	log_label = RichTextLabel.new()
	log_label.scroll_following = true
	log_label.scroll_active = false
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_label.add_theme_color_override("default_color", Palette.UI_MUTED)
	log_label.add_theme_font_size_override("normal_font_size", UiTheme.SMALL)
	_log_panel.add_child(log_label)
	# The oldest lines fade into the dark at the top: a veil over them,
	# drawn once a resize.
	var veil := Control.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.draw.connect(func() -> void:
		var h := minf(34.0, veil.size.y)
		var c := Color(Palette.UI_NIGHT, 0.85)
		var none := Color(Palette.UI_NIGHT, 0.0)
		veil.draw_polygon(PackedVector2Array([Vector2(-6, -4), Vector2(veil.size.x + 6, -4), Vector2(veil.size.x + 6, h), Vector2(-6, h)]),
				PackedColorArray([c, c, none, none])))
	veil.resized.connect(veil.queue_redraw)
	_log_panel.add_child(veil)
	_log_panel.visible = false

	result_panel = UiModal.new()
	result_panel.max_width = 720.0
	root.add_child(result_panel)
	offer_panel = UiModal.new()
	offer_panel.max_width = 760.0
	offer_panel.dim = 0.35
	root.add_child(offer_panel)
	_show_offer()
	root.resized.connect(_layout_top)

	view.round_played.connect(_on_round)
	view.battle_finished.connect(_on_finished)
	view.auto_paused.connect(_on_auto_paused)
	view.paused_changed.connect(func(_p: bool) -> void: _refresh())
	view.camera_moved.connect(func() -> void: follow_btn.button_pressed = view.follow)
	# The burned hall is taught (view/tutorial.gd): the director takes the
	# player through its controls one at a time.
	var obj := view.battle.objective
	if obj != null and obj.kind == Objective.Kind.ESCAPE and main != null and main.get("teach") == true:
		tutorial = Tutorial.new()
		add_child(tutorial)
		tutorial.setup(self)
	_refresh()
	_layout_top()


func _tool(text: String, width: int) -> Button:
	var b := UiTheme.button(text, Callable(), "ToolButton", Vector2(width, 48))
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return b


func _rich(size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.clip_contents = true
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_override("bold_font", UiTheme.font("bold"))
	r.add_theme_color_override("default_color", Palette.UI_TEXT)
	return r


## The strip beside the controls when there is room, under them when not.
func _layout_top() -> void:
	if root_control == null or top_row == null:
		return
	var room := root_control.size.x - UiTheme.EDGE * 2 - UiTheme.S2
	var under := room - buttons_row.get_combined_minimum_size().x < STRIP_MIN
	var in_row := strip.get_parent() == top_row
	if under and in_row:
		top_row.remove_child(strip)
		root_control.add_child(strip)
		root_control.move_child(strip, top_row.get_index() + 1)
		strip.set_anchors_preset(Control.PRESET_TOP_LEFT)
		strip.offset_left = UiTheme.EDGE
		strip.offset_top = UiTheme.S2 + 48 + UiTheme.S1
		strip.custom_minimum_size = Vector2(minf(560.0, room), 0)
	elif not under and not in_row:
		root_control.remove_child(strip)
		top_row.add_child(strip)
		top_row.move_child(strip, 0)
		strip.custom_minimum_size = Vector2(STRIP_MIN, 0)


## The bottom of the top of the screen (the controls and the strip), in
## design pixels: the camera keeps the men below it (main.gd).
func top_height() -> float:
	if strip == null:
		return 50.0
	return strip.get_global_rect().end.y - root_control.get_global_rect().position.y if strip.is_inside_tree() else 80.0


func _on_next() -> void:
	if not _may("next"):
		return
	if view.is_manual():
		view.step()
	else:
		view.set_paused(not view.paused)
	_refresh()


func _on_shout(s: CombatTypes.Shout) -> void:
	if not _may("shout:%d" % s):
		(shout_buttons[s] as Button).button_pressed = false
		return
	view.pending_shout = CombatTypes.Shout.NONE if view.pending_shout == s else s
	view.pending_custom = null
	for k in shout_buttons:
		(shout_buttons[k] as Button).button_pressed = (k == view.pending_shout)
	for cb in custom_buttons:
		cb.button_pressed = false
	_refresh()
	view.queue_redraw()
	if tutorial != null:
		tutorial.changed()


## Whether a control may be pressed now: always, unless the tutorial is
## holding the player's hand and it is not the one it asks for.
func _may(id: String) -> bool:
	return allowed.is_empty() or allowed.has(id)


## A shout of the band's own: its shape this round, its order the next.
func _on_custom(cs: CustomShout, btn: Button) -> void:
	var on := view.pending_custom != cs
	view.pending_custom = cs if on else null
	view.pending_shout = CombatTypes.Shout.SHIELD_WALL if on else CombatTypes.Shout.NONE
	for k in shout_buttons:
		(shout_buttons[k] as Button).button_pressed = false
	for cb in custom_buttons:
		cb.button_pressed = (cb == btn and on)
	_refresh()
	view.queue_redraw()


func _on_round(lines: PackedStringArray) -> void:
	# Men thinking for themselves (Decision's reasons): kept, in their own
	# colour, at most three a round. Read from the men, so they show whether
	# or not the battle logged them (your own man's account is his line).
	const REASONS_PER_ROUND := 3
	var reasons := {}
	for w in view.battle.warriors:
		if w.is_active() and w.last_reason != "" and w != view.player:
			reasons[w.last_reason] = true
	var shown_reasons := 0
	for line in lines:
		var col := Palette.DIM
		var keep := false
		if reasons.has(line):
			reasons.erase(line)
			if shown_reasons >= REASONS_PER_ROUND:
				continue
			shown_reasons += 1
			col = Palette.TEXT
			keep = true
		elif line.contains("DOWN") or line.contains("breaks") or line.contains("flees") or line.contains("===") or line.contains("drives forward"):
			col = Palette.WARN
			keep = true
		elif line.contains("taunts the enemy") or line.contains("called a coward") or line.contains("answer with their feet") or line.contains("take it, and like it less") or line.contains("stands for it") \
				or line.contains("let them come to him") or line.contains("will not leave the ford") or line.contains("makes for the ships") or line.contains("see the hall burn"):
			col = Palette.GOLD
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
	for line in reasons:
		if shown_reasons >= REASONS_PER_ROUND:
			break
		shown_reasons += 1
		log_label.push_color(Palette.TEXT)
		log_label.add_text(line.strip_edges() + "\n")
		log_label.pop()
	_log_panel.visible = log_label.get_parsed_text().strip_edges() != ""
	while log_label.get_paragraph_count() > 7:  # six lines and the empty one after the last
		log_label.remove_paragraph(0)
	for s in shout_buttons:
		(shout_buttons[s] as Button).button_pressed = false
	view.pending_shout = CombatTypes.Shout.NONE
	if tutorial != null:
		tutorial.round_played()
	_refresh()


func _on_auto_paused(reason: String) -> void:
	_log_panel.visible = true
	log_label.push_color(Palette.GOLD)
	log_label.add_text("paused: %s\n" % reason)
	log_label.pop()
	_refresh()


## Leaving the field in order. Only out of contact: engaged, fall back first.
func _on_withdraw() -> void:
	if not _may("withdraw"):
		return
	var b := view.battle
	if b.is_over() or not b.can_withdraw(0):
		return
	if b.withdraw(0):
		_on_finished(b.result)


## The result panel's title, from the outcome ladder.
const OUTCOME_TITLES := {
	BattleResult.Outcome.ROUTED_THEM: "Victory: they are routed",
	BattleResult.Outcome.DROVE_THEM_OFF: "Victory: they draw off",
	BattleResult.Outcome.WON_THE_FIELD: "Victory",
	BattleResult.Outcome.BOTH_DREW_OFF: "Both sides draw off",
	BattleResult.Outcome.WITHDREW: "You withdrew",
	BattleResult.Outcome.DRIVEN_OFF: "Defeat: driven off",
	BattleResult.Outcome.ROUTED: "Defeat: a rout",
	BattleResult.Outcome.LOST_THE_FIELD: "Defeat",
	BattleResult.Outcome.ESCAPED: "You got out",
}


func _on_finished(result: BattleResult) -> void:
	offer_panel.visible = false
	if tutorial != null:
		tutorial.finished()
	var outcome := result.outcome(0)
	result_panel.open(OUTCOME_TITLES[outcome])
	result_panel.title_label.add_theme_color_override("font_color", _outcome_color(outcome))
	var box := result_panel.body
	var obj := view.battle.objective
	var at := ""
	if obj != null and obj.kind == Objective.Kind.ESCAPE:
		at = "You made for the dark beyond their ring."
	elif obj != null:
		at = "You %s %s." % ["came for" if obj.attacker == 0 else "stood to hold", obj.name]
	var why := _why(result)
	box.add_child(UiTheme.label(("%s " % at if at != "" else "") + "%s after %d rounds." % [why, result.rounds], "StrongLabel"))
	box.add_child(_counts(result))
	# After the fight: what it left on the band, carried to the next one.
	if main.has_method("after_fight"):
		var after: PackedStringArray = main.after_fight(result)
		if not after.is_empty():
			var p := UiTheme.panel("ParchmentPanel")
			p.add_child(UiTheme.label(" ".join(after), "InkLabel"))
			box.add_child(p)
	if main.get("host") != null:
		# A fight of the saga: back to the map.
		result_panel.add_button("Go on", func() -> void: main.host.leave_battle(), "PrimaryButton", 200.0)
		_refresh()
		return
	if main.has_method("drill") and not main.get("saga_over"):
		var yard := result_panel.add_button("Drill yard", _show_drill_yard, "", 170.0)
		yard.tooltip_text = "Drill a shape, or swear a shout of your own"
	result_panel.add_button("Fight again" if not main.get("saga_over") else "A new band", func() -> void: main.next_fight(), "PrimaryButton", 200.0)
	_refresh()


## Why the fight ended, in plain words, from the battle's last line.
func _why(r: BattleResult) -> String:
	var why := ""
	for line in r.log:
		if line.begins_with("==="):
			why = line.trim_prefix("=== ").trim_suffix(" ===").replace("side 0", "your band").replace("side 1", "their band").replace("You is", "You are").replace("You gets", "You get")
	return (why[0].to_upper() + why.substr(1)) if why != "" else "The fight is over"


## The counts, both sides, as a small table.
func _counts(r: BattleResult) -> Control:
	var well := UiTheme.panel("WellPanel")
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", UiTheme.S5)
	grid.add_theme_constant_override("v_separation", 2)
	well.add_child(grid)
	for h in ["", "Men", "Down", "Broke", "Fled", "Dead"]:
		var k := UiTheme.label(h.to_upper(), "KeyLabel", false)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if h != "" else HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(k)
	for side in 2:
		var who := UiTheme.label("Yours" if side == 0 else "Theirs", "StrongLabel", false)
		who.add_theme_color_override("font_color", Palette.UI_OURS if side == 0 else Palette.UI_THEIRS)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(who)
		for n in [r.started[side], r.downed[side], r.broken[side], r.fled[side], r.dead[side]]:
			var v := UiTheme.label(str(n), "ValueLabel", false)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if int(n) == 0:
				v.add_theme_color_override("font_color", Palette.UI_FAINT)
			grid.add_child(v)
	return well


func _outcome_color(o: int) -> Color:
	match o:
		BattleResult.Outcome.ROUTED_THEM, BattleResult.Outcome.DROVE_THEM_OFF, BattleResult.Outcome.WON_THE_FIELD:
			return Palette.UI_GOLD
		BattleResult.Outcome.DRIVEN_OFF, BattleResult.Outcome.ROUTED, BattleResult.Outcome.LOST_THE_FIELD:
			return Palette.UI_BLOOD.lightened(0.15)
		BattleResult.Outcome.ESCAPED:
			return Palette.UI_TEAL.lightened(0.2)
	return Palette.UI_TEXT


## The drill yard (concept.md, "Drill, custom formations and custom
## shouts"): the learned shapes and how well the band knows them, a turn
## of drill in one, and a shout of the band's own: a name, a shape, an
## order. Between fights; the winter is where it happens in the campaign.
func _show_drill_yard() -> void:
	result_panel.visible = false
	if drill_panel == null:
		drill_panel = UiModal.new()
		drill_panel.max_width = 820.0
		root_control.add_child(drill_panel)
	drill_panel.open("The drill yard")
	var box := drill_panel.body
	var rules: CampaignRules = main.campaign_rules
	for t in FormationTemplate.presets():
		if not t.learned:
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", UiTheme.S3)
		box.add_child(line)
		var lab := UiTheme.label("", "BodyLabel", false)
		var fam: float = main.roster.familiarity(t.name, rules)
		lab.text = "%s: the band knows it %d%%" % [t.name.capitalize(), int(round(fam * 100.0))]
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(lab)
		var drill := UiTheme.secondary("Drill it", func() -> void:
			main.drill(t.name)
			_show_drill_yard(), 130.0)
		drill.tooltip_text = "A turn in the yard: every man gains a point, to %d" % rules.drill_points_full
		line.add_child(drill)
	box.add_child(UiTheme.section("Swear a shout of your own"))
	box.add_child(UiTheme.label("A name, a shape, and the order it gives.", "SmallLabel"))
	var swear := HFlowContainer.new()
	swear.add_theme_constant_override("h_separation", UiTheme.S2)
	box.add_child(swear)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Hedgehog"
	name_edit.max_length = 12
	name_edit.custom_minimum_size = Vector2(170, UiTheme.ROW)
	var customs: Array = main.custom_shouts
	if not customs.is_empty():
		name_edit.text = (customs[0] as CustomShout).name
	swear.add_child(name_edit)
	var shape_pick := OptionButton.new()
	for t in FormationTemplate.presets():
		shape_pick.add_item(t.name)
	shape_pick.custom_minimum_size = Vector2(160, UiTheme.ROW)
	swear.add_child(shape_pick)
	var order_pick := OptionButton.new()
	var orders := [CombatTypes.Shout.HOLD, CombatTypes.Shout.PUSH, CombatTypes.Shout.BREAK_THEM, CombatTypes.Shout.FALL_BACK]
	for o in orders:
		order_pick.add_item("then " + CombatTypes.SHOUT_NAMES[o])
	order_pick.custom_minimum_size = Vector2(170, UiTheme.ROW)
	swear.add_child(order_pick)
	var swear_btn := UiTheme.secondary("Swear it", func() -> void:
		var nm := name_edit.text.strip_edges()
		if nm == "":
			nm = "Hedgehog"
		var t := FormationTemplate.presets()[shape_pick.selected]
		main.swear_shout(CustomShout.make(nm, t, orders[order_pick.selected]))
		_show_drill_yard(), 130.0)
	swear.add_child(swear_btn)
	box.add_child(UiTheme.label("Your shouts: " + (", ".join(customs.map(func(c: CustomShout) -> String: return c.describe())) if not customs.is_empty() else "none yet"), "SmallLabel"))
	drill_panel.add_button("Fight again", func() -> void: main.next_fight(), "PrimaryButton", 200.0)


## The choice before the fight (concept.md, "Picking your fights"): the
## scout's report on the band the field dealt you, and what you may do
## about it. Only on a fresh field; a fight you already chose (the river
## bank, an ambush) starts at once. The prototype has no campaign, so the
## scout is you, and whether anyone saw the other first comes from the seed.
func _show_offer() -> void:
	var b := view.battle
	if main.scenario != "equal_green" or b.round > 0:
		return
	var rules := CampaignRules.new()
	var o := FightOffer.new()
	var theirs: Array = main.get("theirs") if main.get("theirs") != null else []
	for w in theirs:
		match (w as Warrior).role:
			CombatTypes.Role.SHIELD:
				o.enemy_shields += 1
			CombatTypes.Role.SPEAR:
				o.enemy_spears += 1
			_:
				o.enemy_bows += 1
	o.enemy_size = theirs.size()
	o.enemy_leader = (theirs[0] as Warrior).display_name if not theirs.is_empty() else ""
	o.doctrine = main.get("doctrine") if main.get("doctrine") != null else LeaderAI.Doctrine.STEADY
	o.attacking = b.objective != null and b.objective.attacker == 0
	var sr := SimRng.new(main.seed_in).fork("prototype-scout")
	var wits: int = view.player.wits
	o.we_know_first = Scouting.spots_first(sr.fork("first"), rules, wits, view.player.tier)
	if not o.we_know_first and not o.attacking:
		o.they_know_first = sr.fork("caught").randf() < rules.caught_chance
	o.report = Scouting.report(sr.fork("report"), rules, wits, view.player.tier, o)
	offer_panel.open("Before the fight")
	var ground: String = main.get("field_title") if main.get("field_title") != null else ""
	var task := ""
	if b.objective != null:
		task = " " + b.objective.brief(0) + "."
	offer_panel.body.add_child(UiTheme.label("%s%s %s%s" % [(ground + ". ") if ground != "" else "", o.brief(), "You have %d men." % b.active(0).size(), task], "SagaLabel"))
	if o.they_know_first:
		offer_panel.add_button("Fight", func() -> void: main.start("ambushed", main.seed_in), "PrimaryButton", 150.0)
	for choice in o.options():
		var main_one: bool = choice == FightOffer.Choice.TAKE_THE_FIELD
		var btn := offer_panel.add_button(FightOffer.CHOICE_TITLES[choice], Callable(), "PrimaryButton" if main_one else "", 150.0)
		match choice:
			FightOffer.Choice.TAKE_THE_FIELD:
				btn.tooltip_text = "Fight as the field is dealt"
				btn.pressed.connect(func() -> void:
					offer_panel.visible = false
					_refresh())
			FightOffer.Choice.WAIT_FOR_THEM:
				btn.tooltip_text = "Fall back to the river and hold the bank: they must come through the ford"
				btn.pressed.connect(func() -> void: main.start("hold", main.seed_in))
			FightOffer.Choice.LAY_AMBUSH:
				btn.tooltip_text = "Your scout saw them first: catch them on the march"
				btn.pressed.connect(func() -> void: main.start("ambush", main.seed_in))
			FightOffer.Choice.FADE_AWAY:
				btn.tooltip_text = "No fight today: it costs standing, not blood"
				btn.pressed.connect(func() -> void:
					offer_panel.visible = false
					if b.withdraw(0):
						_on_finished(b.result))


## The short commit the web build was made from (scripts/export-web.sh
## writes it); "dev" when running from the editor or a tool.
func _build_stamp() -> String:
	return UiTheme.build_stamp()


func _refresh() -> void:
	var b := view.battle
	var mine := view.wall_count(0)
	var theirs := view.wall_count(1)
	var arms := view.arms_count(0)
	var order := b.last_shout(0)
	var their_order := b.last_shout(1)
	var arms_bits := PackedStringArray()
	var bare := view.shieldless_count(0)
	if bare > 0:
		arms_bits.append("%d shieldless" % bare)
	if arms[0] > 0:
		arms_bits.append("+%d spears" % arms[0])
	if arms[1] > 0:
		arms_bits.append("+%d bows" % arms[1])
	var calls := PackedStringArray()
	if order != CombatTypes.Shout.NONE:
		calls.append("[color=#%s]you[/color] %s" % [COLORS.muted, CombatTypes.SHOUT_NAMES[order]])
	if their_order != CombatTypes.Shout.NONE:
		calls.append("[color=#%s]they[/color] %s" % [COLORS.muted, CombatTypes.SHOUT_NAMES[their_order]])
	if b.ambushed_side == 1 and b.is_surprised(1) and b.round > 0:
		calls.append("[color=#%s]they[/color] surprised" % COLORS.muted)
	var stance: String = BattleGrid.AXIS_NAMES[view.player.wall_axis()] if view.player != null else ""
	# The strip: the round, the task and its clock, the orders; then the
	# walls, ours in madder, theirs in woad.
	var top := "[b]Round %d[/b]" % b.round
	if b.objective != null:
		var prog := b.objective.progress(b)
		if prog != "":
			top += "    [color=#%s][b]%s[/b][/color]" % [COLORS.gold, Journey._cap(prog)]
		var clock := b.objective.clock_text(b)
		if clock != "":
			top += "  [color=#%s]%s[/color]" % [COLORS.muted, clock]
	if not calls.is_empty():
		top += "    " + "  ".join(calls)
	_line_round.text = top
	arms_bits.append(stance)
	_line_walls.text = "[color=#%s][b]Our wall %d/%d[/b][/color] [color=#%s]%s[/color]    [color=#%s][b]Theirs %d/%d[/b][/color]" % [
			COLORS.ours, mine[0], mine[1], COLORS.muted, ", ".join(arms_bits), COLORS.theirs, theirs[0], theirs[1]]
	status.text = "Round %d  wall %d/%d  theirs %d/%d" % [b.round, mine[0], mine[1], theirs[0], theirs[1]]
	var known := ""
	if view.player != null and view.player.formation != null and view.player.formation.learned:
		known = " %d%%" % int(round(b.familiarity(0) * 100.0))  # how well the band knows a learned shape
	form_btn.text = "Form: " + view.formation_name() + known
	if b.round > 0 and offer_panel.visible:
		offer_panel.visible = false  # the fight is on: the choice was made
	withdraw_btn.disabled = b.is_over() or not b.can_withdraw(0)
	# The tutorial's hand on the controls: only the one it asks for.
	for id in controls:
		var c: Button = controls[id]
		if id == "withdraw":
			c.disabled = c.disabled or not _may(id)
		else:
			c.disabled = not _may(id)
	withdraw_btn.tooltip_text = "Break contact first: fall back, then withdraw" if not b.can_withdraw(0) \
			else "Lead your men off the field, out of contact: a choice, not a rout"
	var warn := ""
	if view.player.is_active() and b.round > 0 and view.wall_count(0)[0] < 2:
		warn = "   (nobody stands with you)"
	elif view.player.is_active() and b.round > 0 and view.wall_count(0)[0] < view.wall_count(0)[1]:
		warn = "   (the wall is broken: %d of %d with you)" % [view.wall_count(0)[0], view.wall_count(0)[1]]
	you_label.add_theme_color_override("font_color", Palette.WARN if warn != "" else Palette.UI_GOLD)
	var hint := "tap a cell to step or an enemy to strike; tap yourself to act with the line"
	if b.objective != null and b.round == 0:
		hint = "you: " + b.objective.brief(0)  # the task, before you act
	elif b.ambushed_side == 1 and b.round == 0:
		hint = "they are strung out: hit them before they form"
	var ground: String = main.get("field_title") if main != null and main.get("field_title") != null else ""
	if ground != "" and b.round == 0:
		hint = "%s. %s" % [ground, hint]  # the ground, before you act
	you_label.text = (("you: " + view.player_line) if view.player_line != "" else hint) + warn
	if view.is_manual():
		pulse_label.text = "TURN BY TURN"
		next_btn.text = "Next round"
	else:
		pulse_label.text = "EVERY %.1fs" % view.pulse_seconds
		next_btn.text = "Resume" if view.paused else "Pause"
	_layout_top()
