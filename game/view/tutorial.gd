class_name Tutorial
extends Node
## The burned hall taught (docs/design/notes/tutorial.md, first-fight.md):
## a director that reads the battle every round and says the one most
## useful true thing, in a banner that keeps clear of the control it names;
## that control pulses, and on the board the man or the hex it means is
## ringed and the dark's edge pulses when that is where to go.
##
## The first two things are taught in order and the other controls are shut
## while they are: who is who (read, then Go on, or Skip the fight), and the
## wall (Shield Wall, Next round). After that every control answers, and
## what the banner asks comes from the field as it stands (`advise`, a pure
## function of the battle and a little memory): Withdraw when it would work;
## To Me when a man is apart from you; Fall Back when the way to the dark is
## open; Push when one of them stands between you and the dark, and how
## many more shoves the thin place will take; a hex to tap when the wall is
## held up. It never asks for a control that is shut or disabled, and never
## says again what the last round did and came to nothing.
##
## `advise`, `evaluate`, `control`, `text`, `acknowledge` and `after_round`
## read only the Battle and the shout waiting to be given, so the tests and
## the stand-in players (tests/escape_players.gd) drive it without a
## screen. `setup(hud)` adds the banner and the outline over the HUD.

## What the banner is about. WHO and WALL come in order; the rest are read
## from the field each round (`advise`).
enum Step { WHO, WALL, PUSH, TO_ME, FALL_BACK, STEP_OUT, WITHDRAW, CARRIED, OUT }

const TEXT_WHO := "The red shields are you and your two men, the blue the jarl's men round the yard. The gold edge at the top is the dark of the trees: get there."
const TEXT_WALL := "First close up: press Shield Wall, then Next round."
const TEXT_PUSH := "They stand between you and the dark, the marked man nearest: press Push, then Next round, and drive through the thin place."
const TEXT_PUSH_ON := "Next round: keep pushing. The thin place gives after %d more."
const TEXT_PUSH_ONE := "Next round: keep pushing. One more shove and the thin place gives."
const TEXT_PUSH_PAST := "The marked man still stands in your way: Next round, and the push carries you past him."
const TEXT_PUSH_RING := "Next round: push on past the end of their ring, toward the dark."
const TEXT_STRIKE := "The marked man still stands in your way: tap him to strike him yourself, then Next round."
const TEXT_NOT_YET := "Not yet: they are still between you and the dark. Press Push, then Next round."
const TEXT_TO_ME := "%s is apart from you: press To Me, then Next round, and your men close on you."
const TEXT_TO_ME_ON := "Next round: they are coming to you."
const TEXT_FALL_BACK := "You are through. Now fall back toward the dark: press Fall Back, then Next round."
const TEXT_FALL_BACK_ON := "Next round: the wall gives ground toward the dark, shields to the men behind."
const TEXT_STEP_OUT := "The wall is held up: tap the marked hex, nearer the dark, to step there, then Next round."
const TEXT_STEP_ON := "Next round: you step toward the dark, and your men come after you."
const TEXT_STRIKE_ON := "Next round: you strike at the man you marked. Tap yourself to go with the line again."
const TEXT_STEP_ASIDE := "Next round: you step where you tapped. Tap yourself to go with the line again."
const TEXT_WITHDRAW := "None of them is at arm's length and the way is open: press Withdraw. Leaving a fight is a choice, not a defeat."
const TEXT_CARRIED := "You are down. Your men are carrying you out."

## What a round did, shown dim above the next instruction.
const SAID_WALL := "Your men close up at your shoulders: each shield now guards the man beside it."
const SAID_PUSH := "In the push the line with more shields together, and more heart, drives the other back a step."
const SAID_GAVE := "The thin place gives: they break and run before your shields."
const SAID_FALL_BACK := "A wall that gives ground in order is still a wall, and they cannot get round it."
const SAID_TO_ME := "Your men close on you, and take heart from it."
const SAID_HURT := "%s is hurt: the red marks by a man's shield are his wounds, and he takes them with him out of this fight."
const SAID_HURT_YOU := "You are hurt: the red marks by your shield are your wounds, and you take them with you out of this fight."

var step: Step = Step.WHO
var battle: Battle
## The shout waiting to be given next round (BattleView.pending_shout);
## the HUD keeps it current, tests set it.
var pending: CombatTypes.Shout = CombatTypes.Shout.NONE
## The hex your man is to step to or strike at next round (a tap on the
## board), or NO_CELL; the HUD keeps it current.
var tapped: Vector2i = BattleGrid.NO_CELL
## What the last round did, for the banner's first line.
var said := ""
## The steps shown, in order, for the tools and the tests.
var done: Array[Step] = []
## The man or hex the banner means, ringed on the board, or NO_CELL.
var point: Vector2i = BattleGrid.NO_CELL
## Whether the dark's edge is where to go now (it pulses on the board).
var goal := false

var _acked := false
var _text := ""
var _control := ""
## The banner before the last round, and whether that round brought your
## leader nearer the dark: the same words after a round that came to
## nothing are not said again.
var _last_text := ""
var _last_progress := true
var _to_me_tried := false
var _dist_seen := 99  # the leader's distance to the dark after the last round
var _hurt_said := false
var _gave_said := false
var _pushed_said := false
var _fell_back_said := false

## Where the banner stands: under the top bar and its status lines (the
## HUD measures them), or over the shout row (design pixels).
const TOP_BAR := 84.0
const BOTTOM_ROW := 82.0

var hud: Node = null
var _banner: PanelContainer
var _said_label: Label
var _text_label: Label
var _go_on: Button
var _skip: Button
var _outline: Control
var _time := 0.0
var _resize := 0  # frames left to shrink the banner to its words


# --- The logic ----------------------------------------------------------------

func start(p_battle: Battle) -> void:
	battle = p_battle
	step = Step.WHO
	_acked = false
	_dist_seen = battle.objective.leader_distance(battle) if battle.objective != null else 99
	evaluate()


## The one most useful true thing to say about `b` as it stands, as
## {step, control, text, point, goal}. `m` is the director's memory:
## acked (who is who has been read), pending (the shout waiting), tapped
## (the hex your man will step to or strike), last_text and last_progress
## (the banner before the last round, and whether that round brought the
## leader nearer the dark), to_me_tried (To Me was given and the men are
## still apart). Pure: reads the battle, changes nothing.
static func advise(b: Battle, m: Dictionary) -> Dictionary:
	var out := {"step": Step.OUT, "control": "", "text": "", "point": BattleGrid.NO_CELL, "goal": false}
	if b == null or b.is_over():
		return out
	var obj := b.objective
	var l := b.sworn_leader(0)
	var pend: CombatTypes.Shout = m.get("pending", CombatTypes.Shout.NONE)
	if l == null or not l.is_active():
		out.step = Step.CARRIED
		out.text = TEXT_CARRIED
		return out
	if b.round == 0 and not m.get("acked", false):
		out.step = Step.WHO
		out.control = "ack"
		out.text = TEXT_WHO
		out.goal = true
		return out
	if b.round == 0:
		out.step = Step.WALL
		out.control = _shout_then_next(CombatTypes.Shout.SHIELD_WALL, pend, false)
		out.text = TEXT_WALL
		return out
	var last_text: String = m.get("last_text", "")
	var stuck: bool = not m.get("last_progress", true)
	var order := b.standing_order(0)
	# Withdraw, the moment it would work.
	if b.can_withdraw(0):
		out.step = Step.WITHDRAW
		out.control = "withdraw"
		out.text = TEXT_WITHDRAW
		out.goal = true
		return out
	# A man apart from you, while they still stand between you and the dark:
	# call him in, once; if he is still apart after it, the field's next need
	# comes first. Once the way is open he comes after you on his own.
	var way_open := obj != null and obj.way_open(b)
	var apart := _apart(b, l) if not way_open else null
	if apart != null and not m.get("to_me_tried", false):
		out.step = Step.TO_ME
		out.point = apart.pos
		var asked := pend == CombatTypes.Shout.TO_ME
		out.control = "next" if asked else "shout:%d" % CombatTypes.Shout.TO_ME
		out.text = TEXT_TO_ME_ON if asked else TEXT_TO_ME % apart.display_name
		return out
	if way_open:
		out.goal = true
		var tap_to := _step_nearer(b, l)
		if m.get("tapped", BattleGrid.NO_CELL) != BattleGrid.NO_CELL:
			out.step = Step.STEP_OUT
			out.control = "next"
			out.text = _tap_text(b, l, m.tapped)
			return out
		var falling := order == CombatTypes.Shout.FALL_BACK or pend == CombatTypes.Shout.FALL_BACK
		out.step = Step.FALL_BACK
		out.control = _shout_then_next(CombatTypes.Shout.FALL_BACK, pend, order == CombatTypes.Shout.FALL_BACK)
		out.text = TEXT_FALL_BACK_ON if falling else TEXT_FALL_BACK
		if out.text == last_text and stuck and tap_to != BattleGrid.NO_CELL:
			out.step = Step.STEP_OUT
			out.control = "tap"
			out.text = TEXT_STEP_OUT
			out.point = tap_to
		return out
	# One of them between you and the dark: push through him.
	var between := _between(b, l)
	out.step = Step.PUSH
	out.point = between.pos if between != null else BattleGrid.NO_CELL
	var pushing := order == CombatTypes.Shout.PUSH or order == CombatTypes.Shout.BREAK_THEM
	if pend == CombatTypes.Shout.PUSH or (pushing and pend == CombatTypes.Shout.NONE):
		out.control = "next"
		# The thin place gives at the end of the round the band has pushed
		# `escape_give_rounds` rounds in all (Battle._first_fight_give_way).
		var left := b.rules.escape_give_rounds - b.first_fight_pushed() if obj.first_fight else 0
		# Near enough to stand in the push's way (and to give way to it).
		var in_way := between != null and BattleGrid.chebyshev(between.pos, l.pos) <= b.rules.escape_give_radius + 1
		if left > 1:
			out.text = TEXT_PUSH_ON % left
		elif left == 1:
			out.text = TEXT_PUSH_ONE
		elif in_way:
			out.text = TEXT_PUSH_PAST
		else:
			out.text = TEXT_PUSH_RING  # only the ends of their ring are ahead, off to the side
			out.point = BattleGrid.NO_CELL
			out.goal = true
		if out.text == last_text and stuck:
			# The push came to nothing last round: something else to do.
			var tap_to := _step_nearer(b, l)
			if m.get("tapped", BattleGrid.NO_CELL) != BattleGrid.NO_CELL:
				out.text = _tap_text(b, l, m.tapped)
			elif in_way and BattleGrid.chebyshev(between.pos, l.pos) == 1:
				out.control = "tap"
				out.text = TEXT_STRIKE
			elif tap_to != BattleGrid.NO_CELL:
				out.step = Step.STEP_OUT
				out.control = "tap"
				out.text = TEXT_STEP_OUT
				out.point = tap_to
		return out
	out.control = "shout:%d" % CombatTypes.Shout.PUSH
	out.text = TEXT_NOT_YET if order == CombatTypes.Shout.FALL_BACK else TEXT_PUSH
	return out


## "shout:<s>" until it is waiting (or standing, when `standing_ok`), then
## "next".
static func _shout_then_next(s: CombatTypes.Shout, pend: CombatTypes.Shout, standing_ok: bool) -> String:
	if pend == s or (standing_ok and pend == CombatTypes.Shout.NONE):
		return "next"
	return "shout:%d" % s


## The man of yours furthest apart from you, two hexes or more away with
## none of yours at his shoulder and none of theirs at arm's length, or
## null: a man alone.
static func _apart(b: Battle, l: Warrior) -> Warrior:
	var best: Warrior = null
	var best_d := 1
	for w in b.active(0):
		if w == l or w.broken:
			continue
		var d := BattleGrid.chebyshev(w.pos, l.pos)
		if d <= best_d or not b.grid.adjacent_warriors(w.pos, 1).is_empty():
			continue
		var friend := false
		for f in b.grid.adjacent_warriors(w.pos, 0):
			friend = friend or (f.is_active() and not f.broken)
		if not friend:
			best = w
			best_d = d
	return best


## The nearest of them standing between your leader and the dark (nearer
## it than he is), or null.
static func _between(b: Battle, l: Warrior) -> Warrior:
	var obj := b.objective
	var mine := obj.dark_distance(l.pos)
	var best: Warrior = null
	for w in b.active(1):
		if w.broken or obj.dark_distance(w.pos) >= mine:
			continue
		if best == null or BattleGrid.distance(w.pos, l.pos) < BattleGrid.distance(best.pos, l.pos):
			best = w
	return best


## What a tap on the board will do next round, truly said.
static func _tap_text(b: Battle, l: Warrior, cell: Vector2i) -> String:
	var occ := b.grid.occupant(cell)
	if occ != null and occ.side != l.side:
		return TEXT_STRIKE_ON
	if b.objective.dark_distance(cell) < b.objective.dark_distance(l.pos):
		return TEXT_STEP_ON
	return TEXT_STEP_ASIDE


## A free hex beside your leader nearer the dark, or NO_CELL.
static func _step_nearer(b: Battle, l: Warrior) -> Vector2i:
	var obj := b.objective
	var best := BattleGrid.NO_CELL
	var best_d := obj.dark_distance(l.pos)
	for c in b.grid.neighbors(l.pos):
		if not b.grid.is_free(c):
			continue
		var d := obj.dark_distance(c)
		if d < best_d:
			best = c
			best_d = d
	return best


## Reads the field again: the step, the control, the words, the marks.
func evaluate() -> void:
	if battle == null:
		return
	var a := advise(battle, {"acked": _acked, "pending": pending, "tapped": tapped, "last_text": _last_text,
			"last_progress": _last_progress, "to_me_tried": _to_me_tried})
	var s: Step = a.step
	if s != step and not done.has(step):
		done.append(step)
	step = s
	_control = a.control
	_text = a.text
	point = a.point
	goal = a.goal


## The control to press now, by the HUD's names ("shout:<n>", "next",
## "withdraw"), "ack" for the banner's Go on, "tap" for a hex or a man on
## the board (`point`), or "" when there is none.
func control() -> String:
	return _control


## The controls that may be pressed now: for the first steps (who is who,
## the wall, the first push) only the one asked for (and the shout already
## chosen, to take it back); afterwards every one (empty).
func allowed() -> Array[String]:
	var out: Array[String] = []
	if step == Step.WHO or step == Step.WALL or (step == Step.PUSH and battle != null and battle.first_fight_pushed() == 0):
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
	return _text


## The player has read who is who (Go on).
func acknowledge() -> void:
	_acked = true
	evaluate()


## A round has been fought: what was shouted, what it did.
func after_round() -> void:
	said = ""
	# The banner as Next round was pressed, and whether that round brought
	# the leader nearer the dark.
	_last_text = _text
	var d := battle.objective.leader_distance(battle) if battle.objective != null else 99
	_last_progress = d < _dist_seen or battle.is_over()
	_dist_seen = d
	var s := battle.last_shout(0)
	if battle.round == 1 and s == CombatTypes.Shout.SHIELD_WALL:
		said = SAID_WALL
	var l := battle.sworn_leader(0)
	if s == CombatTypes.Shout.TO_ME:
		said = SAID_TO_ME
		_to_me_tried = true
	elif l == null or not l.is_active() or _apart(battle, l) == null:
		_to_me_tried = false  # together again: a man apart later is called in afresh
	var round_log := _round_log()
	if not _pushed_said and round_log.has("push"):
		_pushed_said = true
		said = SAID_PUSH
	if not _gave_said and round_log.has("gave"):
		_gave_said = true
		said = SAID_GAVE
	if not _fell_back_said and s == CombatTypes.Shout.FALL_BACK:
		_fell_back_said = true
		said = SAID_FALL_BACK
	if not _hurt_said and not battle.is_over():
		var hurt := _first_hurt()
		if hurt != null:
			_hurt_said = true
			said = SAID_HURT_YOU if hurt.is_leader else SAID_HURT % hurt.display_name
	pending = CombatTypes.Shout.NONE
	tapped = BattleGrid.NO_CELL
	evaluate()


func _round_log() -> Dictionary:
	var out := {}
	for i in range(battle.log.size() - 1, -1, -1):
		var line := battle.log[i]
		if line.begins_with("--- round"):
			break
		if line.begins_with("push: "):
			out["push"] = true
		if line.begins_with("the ring gives way"):
			out["gave"] = true
	return out


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
	_banner = UiTheme.panel("ParchmentPanel")
	_banner.anchor_left = 0.2
	_banner.anchor_right = 0.8
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_banner)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_banner.add_child(box)
	_said_label = UiTheme.label("", "InkSmallLabel")
	_said_label.custom_minimum_size = Vector2(320, 0)
	box.add_child(_said_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_text_label = UiTheme.label("", "InkLabel")
	_text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.custom_minimum_size = Vector2(320, 0)  # never a column of letters before the anchors settle
	_text_label.add_theme_font_size_override("font_size", 18)
	row.add_child(_text_label)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buttons)
	_go_on = UiTheme.primary("Go on", Callable(), 130.0)
	_go_on.custom_minimum_size.y = UiTheme.ROW
	_go_on.pressed.connect(func() -> void:
		acknowledge()
		_show())
	buttons.add_child(_go_on)
	# A way out of the fight for anyone who wants none of it: the dice tell
	# the escape (Journey.skip_escape) and the saga goes on.
	_skip = UiTheme.quiet("Skip the fight", func() -> void:
		if hud != null and hud.has_method("skip_fight"):
			hud.skip_fight(), 130.0)
	_skip.custom_minimum_size.y = UiTheme.ROW
	buttons.add_child(_skip)
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


## The player tapped the board: his man will step to or strike at `cell`
## next round (NO_CELL: he acts with the line again).
func on_tap(cell: Vector2i) -> void:
	tapped = cell
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
## from the control it names), the outline, the marks on the board, and
## which controls answer.
func _show() -> void:
	if hud == null:
		return
	var none: Array[String] = []
	hud.allowed = allowed() if step != Step.OUT else none
	var view: Node = hud.view
	if view != null:
		view.set("guide_cell", point if step != Step.OUT else BattleGrid.NO_CELL)
		view.set("guide_goal", goal and step != Step.OUT)
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
	_skip.visible = step == Step.WHO
	# Keep clear of the control: below the top bar when it is in the shout
	# row (or is the banner's own Go on, or the board), above the shout row
	# when it is up in the top bar.
	var target := _target()
	var low: bool = want != "ack" and target != null and target.get_global_rect().get_center().y < (hud.root_control as Control).size.y / 2.0
	_banner.anchor_top = 1.0 if low else 0.0
	_banner.anchor_bottom = 1.0 if low else 0.0
	_banner.grow_vertical = Control.GROW_DIRECTION_BEGIN if low else Control.GROW_DIRECTION_END
	var top := _top_bar()
	_banner.offset_top = -BOTTOM_ROW if low else top
	_banner.offset_bottom = -BOTTOM_ROW if low else top
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
	main.top_extra = 0.0 if low else h + 6.0
	main.bottom_extra = h if low else 0.0


## Just under the HUD's top bar and strip.
func _top_bar() -> float:
	if hud != null and hud.has_method("top_height"):
		return hud.top_height() + 6.0
	return TOP_BAR


func _target() -> Control:
	var want := control()
	if want == "ack":
		return _go_on
	if hud == null or want == "" or want == "tap":
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
		if _banner.anchor_top < 0.5:
			var top := _top_bar()  # the strip may have moved under the controls
			if absf(_banner.offset_top - top) > 0.5:
				_banner.offset_top = top
				_banner.offset_bottom = top
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
