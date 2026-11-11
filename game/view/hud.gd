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
var result_panel: PanelContainer
var offer_panel: PanelContainer
var pulse_slider: HSlider
var pulse_label: Label
var _last_logged_shout := {}

const SHOUTS := [
	CombatTypes.Shout.SHIELD_WALL, CombatTypes.Shout.HOLD, CombatTypes.Shout.PUSH,
	CombatTypes.Shout.TO_ME, CombatTypes.Shout.BREAK_THEM, CombatTypes.Shout.FALL_BACK,
	CombatTypes.Shout.TAUNT,
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
	status.add_theme_font_size_override("font_size", 15)
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
	form_btn = Button.new()
	form_btn.custom_minimum_size = Vector2(110, 40)
	form_btn.pressed.connect(func() -> void:
		view.cycle_formation()
		for k in shout_buttons:
			(shout_buttons[k] as Button).button_pressed = (k == view.pending_shout)
		_refresh())
	top.add_child(form_btn)
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
	withdraw_btn = Button.new()
	withdraw_btn.text = "Withdraw"
	withdraw_btn.tooltip_text = "Lead your men off the field, out of contact: a choice, not a rout"
	withdraw_btn.custom_minimum_size = Vector2(92, 40)
	withdraw_btn.pressed.connect(_on_withdraw)
	top.add_child(withdraw_btn)
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
		b.custom_minimum_size = Vector2(100, 52)
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
	offer_panel = PanelContainer.new()
	offer_panel.anchor_left = 0.12
	offer_panel.anchor_right = 0.88
	offer_panel.anchor_top = 0.16
	offer_panel.anchor_bottom = 0.84
	offer_panel.visible = false
	root.add_child(offer_panel)
	_show_offer()

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
	var at := ""
	var obj := view.battle.objective
	if obj != null:
		at = "You %s %s.\n" % ["came for" if obj.attacker == 0 else "stood to hold", obj.name]
	return at + "%s after %d rounds.\nYours: %d of %d down, %d broke, %d fled, %d dead.\nTheirs: %d of %d down, %d broke, %d fled, %d dead." % [
		(why[0].to_upper() + why.substr(1)) if why != "" else "The fight is over", r.rounds,
		r.downed[0], r.started[0], r.broken[0], r.fled[0], r.dead[0],
		r.downed[1], r.started[1], r.broken[1], r.fled[1], r.dead[1]]


## Leaving the field in order. Only out of contact: engaged, fall back first.
func _on_withdraw() -> void:
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
}


func _on_finished(result: BattleResult) -> void:
	offer_panel.visible = false
	result_panel.visible = true
	for c in result_panel.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	result_panel.add_child(box)
	var title := Label.new()
	title.text = OUTCOME_TITLES[result.outcome(0)]
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = _result_text(result)
	box.add_child(body)
	# After the fight: what it left on the band, carried to the next one.
	if main.has_method("after_fight"):
		var after: PackedStringArray = main.after_fight(result)
		if not after.is_empty():
			var after_label := Label.new()
			after_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			after_label.add_theme_color_override("font_color", Palette.DIM)
			after_label.text = " ".join(after)
			box.add_child(after_label)
	var again := Button.new()
	again.text = "Fight again" if not main.get("saga_over") else "A new band"
	again.custom_minimum_size = Vector2(160, 44)
	again.pressed.connect(func() -> void: main.next_fight())
	box.add_child(again)
	_refresh()


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
	offer_panel.visible = true
	for c in offer_panel.get_children():
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	offer_panel.add_child(box)
	var title := Label.new()
	title.text = "Before the fight"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var ground: String = main.get("field_title") if main.get("field_title") != null else ""
	var task := ""
	if b.objective != null:
		task = " " + b.objective.brief(0) + "."
	body.text = "%s%s %s%s" % [(ground + ". ") if ground != "" else "", o.brief(), "You have %d men." % b.active(0).size(), task]
	box.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	if o.they_know_first:
		var caught := Button.new()
		caught.text = "Fight"
		caught.custom_minimum_size = Vector2(150, 44)
		caught.pressed.connect(func() -> void: main.start("ambushed", main.seed_in))
		row.add_child(caught)
	for choice in o.options():
		var btn := Button.new()
		btn.text = FightOffer.CHOICE_TITLES[choice]
		btn.custom_minimum_size = Vector2(150, 44)
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
		row.add_child(btn)


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
	var arms := view.arms_count(0)
	var order := b.last_shout(0)
	var their_order := b.last_shout(1)
	var arms_text := ""
	var bare := view.shieldless_count(0)
	if bare > 0:
		arms_text += " (%d shieldless)" % bare
	if arms[0] > 0:
		arms_text += " +%d spears" % arms[0]
	if arms[1] > 0:
		arms_text += " +%d bows" % arms[1]
	var calls := ""
	if order != CombatTypes.Shout.NONE:
		calls += "  you: " + CombatTypes.SHOUT_NAMES[order]
	if their_order != CombatTypes.Shout.NONE:
		calls += "  they: " + CombatTypes.SHOUT_NAMES[their_order]
	if b.ambushed_side == 1 and b.is_surprised(1) and b.round > 0:
		calls += "  they: surprised"
	var stance: String = BattleGrid.AXIS_NAMES[view.player.wall_axis()] if view.player != null else ""
	var round_text := "Round %d" % b.round
	if b.objective != null:
		round_text = "Round %d  %s  %s" % [b.round, b.objective.progress(b), b.objective.clock_text(b)]
	status.text = "%s  wall %d/%d%s (%s)  theirs %d/%d%s" % [round_text, mine[0], mine[1], arms_text, stance, theirs[0], theirs[1], calls]
	form_btn.text = "Form: " + view.formation_name()
	if b.round > 0 and offer_panel.visible:
		offer_panel.visible = false  # the fight is on: the choice was made
	withdraw_btn.disabled = b.is_over() or not b.can_withdraw(0)
	withdraw_btn.tooltip_text = "Break contact first: fall back, then withdraw" if not b.can_withdraw(0) \
			else "Lead your men off the field, out of contact: a choice, not a rout"
	var warn := ""
	if view.player.is_active() and b.round > 0 and view.wall_count(0)[0] < 2:
		warn = "   (nobody stands with you)"
	elif view.player.is_active() and b.round > 0 and view.wall_count(0)[0] < view.wall_count(0)[1]:
		warn = "   (the wall is broken: %d of %d with you)" % [view.wall_count(0)[0], view.wall_count(0)[1]]
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
		pulse_label.text = "turns "
		next_btn.text = "Next round"
	else:
		pulse_label.text = "pulse %.1fs " % view.pulse_seconds
		next_btn.text = "Resume" if view.paused else "Pause"
