class_name BattleHints
extends Node
## The battle's hints on the battle screen (docs/design/notes/first-fight.md):
## after the burned hall, each control and matter of a fight is named once,
## the first time it bears on a real fight (Hints.battle_due), on a slip of
## parchment that stands in the half of the screen away from the control it
## names, with that control ringed in gold. Go on puts it away for the saga
## (Hints.seen, kept with the map's hints). A fight that runs on its own
## waits while a hint is up. The words and the conditions are Hints'.

var hints: Hints
var hud: Node
var showing := ""

var _card: PanelContainer
var _text: Label
var _outline: Control
var _time := 0.0


## Puts the card on `p_hud` (view/hud.gd) and looks at the fight.
func setup(p_hints: Hints, p_hud: Node) -> void:
	hints = p_hints
	hud = p_hud
	var root: Control = hud.root_control
	_outline = Control.new()
	_outline.set_anchors_preset(Control.PRESET_FULL_RECT)
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.draw.connect(_draw_outline)
	_card = UiTheme.panel("ParchmentPanel")
	_card.visible = false
	root.add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.S3)
	_card.add_child(row)
	_text = UiTheme.label("", "InkLabel")
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_text.custom_minimum_size = Vector2(300, 0)
	row.add_child(_text)
	var ok := UiTheme.button("Go on", func() -> void:
		dismiss()
		check(), "PrimaryButton", Vector2(110, UiTheme.ROW))
	ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ok)
	root.add_child(_outline)
	check()


## The hint on the card is read.
func dismiss() -> void:
	if showing != "":
		hints.seen[showing] = true
	showing = ""
	_card.visible = false
	_outline.queue_redraw()
	_keep_clear()


## Shows the next hint whose time has come, if none is up.
func check() -> void:
	if hud == null or hints == null:
		return
	var b: Battle = hud.view.battle
	if showing == "":
		showing = hints.next_battle_hint(b)
	if showing == "" or b.is_over():
		_card.visible = false
		_outline.queue_redraw()
		_keep_clear()
		return
	_text.text = Hints.battle_text(showing)
	_place()
	_card.visible = true
	if not hud.view.is_manual():
		hud.view.set_paused(true)  # a fight that runs on its own waits for the reading


## The card stands in the half of the screen away from the control it
## names: under the top bar for a shout or the board, over the shout row
## for a control up in the top bar.
func _place() -> void:
	var root: Control = hud.root_control
	var target := _target()
	var low: bool = target != null and target.get_global_rect().get_center().y < root.size.y / 2.0
	_card.anchor_left = 0.0
	_card.anchor_right = 0.0
	_card.anchor_top = 1.0 if low else 0.0
	_card.anchor_bottom = 1.0 if low else 0.0
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN if low else Control.GROW_DIRECTION_END
	var top: float = hud.top_height() + 8.0 if hud.has_method("top_height") else 90.0
	_card.offset_left = UiTheme.EDGE
	_card.offset_right = UiTheme.EDGE + minf(560.0, root.size.x * 0.6)
	_card.offset_top = -(UiTheme.TOUCH + UiTheme.S2 * 3) if low else top
	_card.offset_bottom = _card.offset_top
	_card.size = Vector2(_card.size.x, 0.0)


func _target() -> Control:
	var id := Hints.battle_control(showing)
	if id == "":
		return null
	if id == "pulse":
		return hud.pulse_slider
	return hud.controls.get(id, null)


func _process(delta: float) -> void:
	if _card == null or not _card.visible:
		return
	_time += delta
	_card.size = Vector2(_card.size.x, 0.0)
	_outline.queue_redraw()
	_keep_clear()


## Tells the battle screen how much of it the card takes, so the camera
## keeps every man clear of it (main.gd, top_extra / bottom_extra).
func _keep_clear() -> void:
	var main: Node = hud.main if hud != null else null
	if main == null or main.get("top_extra") == null:
		return
	var h := _card.size.y + 10.0 if _card.visible else 0.0
	var low := _card.anchor_top > 0.5
	main.top_extra = 0.0 if low else h
	main.bottom_extra = h if low else 0.0


func _draw_outline() -> void:
	if showing == "" or not _card.visible:
		return
	var t := _target()
	if t == null or not t.is_visible_in_tree():
		return
	var r := t.get_global_rect()
	r.position -= _outline.get_global_rect().position
	var pulse := 0.55 + 0.45 * sin(_time * 5.0)
	_outline.draw_rect(r.grow(4.0), Color(Palette.GOLD, pulse), false, 3.0)
	_outline.draw_rect(r.grow(8.0), Color(Palette.GOLD, pulse * 0.35), false, 2.0)
