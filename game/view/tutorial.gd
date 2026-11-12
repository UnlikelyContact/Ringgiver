class_name Tutorial
extends Node
## The burned hall taught (docs/design/notes/tutorial.md): a director that
## takes the player through the battle's controls once each, in the order
## a real fight needs them, driven by the battle as it stands and never by
## a clock. One short instruction at a time in a banner that keeps clear of
## the control it names; that control pulses; for the first steps the
## others cannot be pressed. When the player has done it, a line says what
## it did and the next step comes.
##
## The steps: who is who (read, then Go on); the wall (Shield Wall, Next
## round); the push at the thin place in their ring (Push, then Next round
## until the way to the dark is open); a man hurt (read, whenever the first
## of yours is hurt); falling back toward the dark with the shields to the
## men coming after (Fall Back, Next round); slipping away out of contact
## (Withdraw); out.
##
## The logic (`evaluate`, `control`, `text`, `acknowledge`, `round_played`)
## reads only the Battle and the shout waiting to be given, so the tests
## drive it without a screen (tests/test_escape.gd). `setup(hud)` adds the
## banner and the pulsing outline over the HUD.

enum Step { WHO, WALL, PUSH, HURT, FALL_BACK, WITHDRAW, OUT }

## What the banner says at each step, one sentence each. PUSH, FALL_BACK
## and WITHDRAW have a second form once the order is given (`_AFTER`).
const TEXTS := {
	Step.WHO: "The red shields are you and your two men, the blue are the jarl's men round the yard, and the line at the top counts the men standing in each wall.",
	Step.WALL: "Three men shoulder to shoulder are worth more than three apart: press Shield Wall, then Next round.",
	Step.PUSH: "Their ring is thin straight ahead, two men with a gap between them: press Push, then Next round.",
	Step.HURT: "%s: the red marks by a man's shield are his wounds, and he takes them with him out of this fight.",
	Step.FALL_BACK: "You are through, and they are closing behind you: press Fall Back, then Next round, and your men give ground toward the trees with their shields to them.",
	Step.WITHDRAW: "None of them is at arm's length and the way is open: press Withdraw, for leaving a fight is a choice and not a defeat.",
	Step.OUT: "",
}
## The wound step when the first hurt is your own.
const HURT_YOU := "You are hurt: the red marks by your shield are your wounds, and you take them with you out of this fight."
const _AFTER := {
	Step.PUSH: "Press Next round, and again: your wall goes on pushing until it is through their ring.",
	Step.FALL_BACK: "Press Next round, and again: the wall gives ground a step at a time.",
	Step.WITHDRAW: "They are still at arm's length: press Next round and keep falling back.",
}
## The line that says what a step did, once it is done.
const DONE := {
	Step.WALL: "Your men close up at your shoulders: each shield now guards the man beside it.",
	Step.FALL_BACK: "A wall that gives ground in order is still a wall, and they cannot get round it.",
}
## Said the first round the lines push against each other.
const PUSH_SAID := "In the push the line with more shields together, and more heart, drives the other back a step."
## The push step gives way to falling back after this many rounds of
## pushing even if the ring holds: the lesson is not to be stuck on.
const PUSH_ROUNDS_MAX := 6

var step: Step = Step.WHO
var battle: Battle
## The shout waiting to be given next round (BattleView.pending_shout);
## the HUD keeps it current, tests set it.
var pending: CombatTypes.Shout = CombatTypes.Shout.NONE
## What the last step did, for the banner's first line.
var said := ""
## The steps done, in order, for the tools and the tests.
var done: Array[Step] = []

var _shouted := {}  # Shout -> true once a round has been fought under it
var _push_from := -1  # the round the first push was fought
var _hurt_shown := false
var _hurt_name := ""
var _resume: Step = Step.PUSH
var _pushed_said := false

## Where the banner stands: under the top bar and its status lines, or
## over the shout row (design pixels).
const TOP_BAR := 68.0
const BOTTOM_ROW := 80.0

var hud: Node = null
var _banner: PanelContainer
var _said_label: Label
var _text_label: Label
var _go_on: Button
var _outline: Control
var _time := 0.0
var _resize := 0  # frames left to shrink the banner to its words


# --- The logic ----------------------------------------------------------------

func start(p_battle: Battle) -> void:
	battle = p_battle
	step = Step.WHO
	evaluate()


## Moves on from whatever step is done, as far as the next that is not.
func evaluate() -> void:
	if battle == null:
		return
	var guard := 0
	while guard < 8:
		guard += 1
		var was := step
		_next_step()
		if step == was:
			return


func _next_step() -> void:
	if battle.is_over():
		_to(Step.OUT)
		return
	match step:
		Step.WALL:
			if _shouted.has(CombatTypes.Shout.SHIELD_WALL):
				_to(Step.PUSH)
		Step.PUSH:
			if _shouted.has(CombatTypes.Shout.PUSH) and (_way_open() or battle.round - _push_from >= PUSH_ROUNDS_MAX):
				_to(Step.FALL_BACK)
		Step.FALL_BACK:
			if _shouted.has(CombatTypes.Shout.FALL_BACK):
				_to(Step.WITHDRAW)


func _to(s: Step) -> void:
	if s == step:
		return
	if not done.has(step):
		done.append(step)
	if DONE.has(step):
		said = DONE[step]
	step = s


func _way_open() -> bool:
	return battle.objective != null and battle.objective.way_open(battle)


## The control to press now, by the HUD's names ("shout:<n>", "next",
## "withdraw"), "ack" for the banner's Go on, or "" when there is none.
func control() -> String:
	match step:
		Step.WHO, Step.HURT:
			return "ack"
		Step.WALL:
			return _shout_then_next(CombatTypes.Shout.SHIELD_WALL)
		Step.PUSH:
			return _shout_then_next(CombatTypes.Shout.PUSH)
		Step.FALL_BACK:
			return _shout_then_next(CombatTypes.Shout.FALL_BACK)
		Step.WITHDRAW:
			return "withdraw" if battle.can_withdraw(0) else "next"
	return ""


func _shout_then_next(s: CombatTypes.Shout) -> String:
	if _shouted.has(s) or pending == s:
		return "next"
	return "shout:%d" % s


## The controls that may be pressed now: for the first steps only the one
## asked for (and the shout already chosen, to take it back); afterwards
## every one (empty).
func allowed() -> Array[String]:
	var out: Array[String] = []
	if step == Step.WALL or step == Step.PUSH or step == Step.WHO:
		var want := control()
		if want != "ack" and want != "":
			out.append(want)
		if want == "next" and pending != CombatTypes.Shout.NONE:
			out.append("shout:%d" % pending)
		if out.is_empty():
			out.append("none")  # reading: nothing on the field to press yet
	return out


## The instruction for the banner.
func text() -> String:
	match step:
		Step.HURT:
			return HURT_YOU if _hurt_name == "" else TEXTS[Step.HURT] % _hurt_name
		Step.PUSH, Step.FALL_BACK:
			return _AFTER[step] if _shouted.has(_order_of(step)) else TEXTS[step]
		Step.WITHDRAW:
			return TEXTS[step] if battle.can_withdraw(0) else _AFTER[step]
	return TEXTS[step]


func _order_of(s: Step) -> CombatTypes.Shout:
	return CombatTypes.Shout.PUSH if s == Step.PUSH else CombatTypes.Shout.FALL_BACK


## The player has read a step that asks only that (Go on).
func acknowledge() -> void:
	if step == Step.WHO:
		_to(Step.WALL)
	elif step == Step.HURT:
		_to(_resume)
	evaluate()


## A round has been fought: what was shouted, what it did.
func after_round() -> void:
	if step == Step.HURT:
		_to(_resume)  # read or not, the fight has moved on
	var s := battle.last_shout(0)
	if s != CombatTypes.Shout.NONE:
		if s == CombatTypes.Shout.PUSH and _push_from < 0:
			_push_from = battle.round
		_shouted[s] = true
	pending = CombatTypes.Shout.NONE
	if not _pushed_said and _pushed_this_round():
		_pushed_said = true
		said = PUSH_SAID
	evaluate()
	# The first man of yours hurt, between rounds, once: read it, then on.
	if not _hurt_shown and not battle.is_over() and (step == Step.PUSH or step == Step.FALL_BACK or step == Step.WITHDRAW):
		var hurt := _first_hurt()
		if hurt != null:
			_hurt_shown = true
			_hurt_name = "" if hurt.is_leader else "%s is hurt" % hurt.display_name
			_resume = step
			step = Step.HURT


func _pushed_this_round() -> bool:
	for i in range(battle.log.size() - 1, -1, -1):
		var line := battle.log[i]
		if line.begins_with("--- round"):
			return false
		if line.begins_with("push: "):
			return true
	return false


func _first_hurt() -> Warrior:
	for w in battle.side_warriors(0):
		if w.wound != CombatTypes.Wound.UNHURT:
			return w
	return null


# --- On the screen ------------------------------------------------------------

## Builds the banner and the outline over `p_hud` (view/hud.gd) and starts.
func setup(p_hud: Node) -> void:
	hud = p_hud
	var root: Control = hud.root_control
	_outline = Control.new()
	_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.draw.connect(_draw_outline)
	_banner = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.07, 0.93)
	sb.border_color = Color(Palette.GOLD, 0.7)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	_banner.add_theme_stylebox_override("panel", sb)
	_banner.anchor_left = 0.2
	_banner.anchor_right = 0.8
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_banner)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_banner.add_child(box)
	_said_label = Label.new()
	_said_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said_label.add_theme_font_size_override("font_size", 14)
	_said_label.add_theme_color_override("font_color", Palette.DIM)
	_said_label.custom_minimum_size = Vector2(320, 0)
	box.add_child(_said_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.custom_minimum_size = Vector2(320, 0)  # never a column of letters before the anchors settle
	_text_label.add_theme_font_size_override("font_size", 17)
	_text_label.add_theme_color_override("font_color", Palette.TEXT)
	row.add_child(_text_label)
	_go_on = Button.new()
	_go_on.text = "Go on"
	_go_on.custom_minimum_size = Vector2(110, 48)
	_go_on.add_theme_font_size_override("font_size", 17)
	_go_on.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_go_on.pressed.connect(func() -> void:
		acknowledge()
		_show())
	row.add_child(_go_on)
	# The first fight shows only what it teaches: the wheel, the step and
	# the pulse are for later fights.
	for id in ["advance", "wheel_l", "wheel_r"]:
		(hud.controls[id] as Control).visible = false
	hud.pulse_slider.visible = false
	hud.pulse_label.visible = false
	root.add_child(_outline)  # over the banner, so its own Go on can be ringed
	start(hud.view.battle)
	_show()


## The view's pending shout changed (a shout button was pressed).
func changed() -> void:
	pending = hud.view.pending_shout if hud != null else pending
	evaluate()
	_show()


## The HUD's round is played and animated.
func round_played() -> void:
	after_round()
	_show()


## The fight is over; the result panel takes over.
func finished() -> void:
	evaluate()
	_show()


## Puts the step on the screen: the banner's words, where it stands (away
## from the control it names), the outline, and which controls answer.
func _show() -> void:
	if hud == null:
		return
	var none: Array[String] = []
	hud.allowed = allowed() if step != Step.OUT else none
	if step == Step.OUT:
		_banner.visible = false
		_outline.queue_redraw()
		hud._refresh()
		return
	_banner.visible = true
	_said_label.text = said
	_said_label.visible = said != ""
	_text_label.text = text()
	var want := control()
	_go_on.visible = want == "ack"
	# Keep clear of the control: below the top bar when it is in the shout
	# row (or is the banner's own Go on), above the shout row when it is up
	# in the top bar.
	var target := _target()
	var low: bool = want != "ack" and target != null and target.get_global_rect().get_center().y < (hud.root_control as Control).size.y / 2.0
	_banner.anchor_top = 1.0 if low else 0.0
	_banner.anchor_bottom = 1.0 if low else 0.0
	_banner.grow_vertical = Control.GROW_DIRECTION_BEGIN if low else Control.GROW_DIRECTION_END
	_banner.offset_top = -BOTTOM_ROW if low else TOP_BAR
	_banner.offset_bottom = -BOTTOM_ROW if low else TOP_BAR
	_banner.offset_left = 0.0
	_banner.offset_right = 0.0
	_resize = 3  # shrink to the words over the next frames, as the wrap settles
	hud._refresh()
	_outline.queue_redraw()
	_keep_clear(low)


## Tells the battle screen how much of it the banner takes, so the camera
## keeps every man clear of it (main.gd, top_extra / bottom_extra).
func _keep_clear(low: bool) -> void:
	var main: Node = hud.main if hud != null else null
	if main == null or main.get("top_extra") == null:
		return
	var h := _banner.size.y + 8.0 if _banner.visible else 0.0
	main.top_extra = 0.0 if low else maxf(0.0, h + TOP_BAR - 50.0)
	main.bottom_extra = h if low else 0.0


func _target() -> Control:
	var want := control()
	if want == "ack":
		return _go_on
	if hud == null or want == "":
		return null
	return hud.controls.get(want, null)


func _process(delta: float) -> void:
	if _outline == null:
		return
	_time += delta
	_outline.queue_redraw()
	if _resize > 0:
		_resize -= 1
		_banner.size = Vector2(_banner.size.x, 0.0)
	if _banner.visible:
		_keep_clear(_banner.anchor_top > 0.5)


func _draw_outline() -> void:
	if step == Step.OUT:
		return
	var t := _target()
	if t == null or not t.is_visible_in_tree():
		return
	var r := t.get_global_rect()
	r.position -= _outline.get_global_rect().position
	var pulse := 0.55 + 0.45 * sin(_time * 5.0)
	var col := Color(Palette.GOLD, pulse)
	_outline.draw_rect(r.grow(4.0), col, false, 3.0)
	_outline.draw_rect(r.grow(8.0), Color(Palette.GOLD, pulse * 0.35), false, 2.0)
