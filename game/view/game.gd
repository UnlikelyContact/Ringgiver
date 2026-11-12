extends Node
## The game's root: the title, choosing a way of life, the summer on the
## map, and the battle screen for the fights of the saga. The skirmish
## prototype (view/main.tscn on its own) is still here behind a button.

var journey: Journey = null
var layer: CanvasLayer
var screen: Control = null
var map: MapScreen = null
var battle_node: Node = null
## Tools set these so a run is repeatable.
var fixed_seed := false
var seed_in := 7


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.BG)
	layer = CanvasLayer.new()
	add_child(layer)
	show_title()


func _swap(c: Control) -> void:
	if screen != null:
		screen.queue_free()
	screen = c
	map = null
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(c)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# --- The title -----------------------------------------------------------------

func show_title() -> void:
	_drop_battle()
	journey = null
	var root := Control.new()
	_swap(root)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	var title := _label("Ring-Giver", 54, Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _label("A saga of Norway in the days of Harald Fairhair", 16, Palette.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	box.add_child(gap)
	var begin := Button.new()
	begin.text = "Begin a saga"
	begin.custom_minimum_size = Vector2(280, 56)
	begin.add_theme_font_size_override("font_size", 20)
	begin.pressed.connect(show_origins)
	box.add_child(begin)
	var skirmish := Button.new()
	skirmish.text = "A single fight"
	skirmish.tooltip_text = "The battle on its own: a band, a field, an enemy"
	skirmish.custom_minimum_size = Vector2(280, 44)
	skirmish.pressed.connect(start_skirmish)
	box.add_child(skirmish)


# --- Where does your saga begin? --------------------------------------------------

func show_origins() -> void:
	var root := Control.new()
	_swap(root)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 16
	box.offset_right = -16
	box.offset_top = 10
	box.offset_bottom = -10
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	box.add_child(_label("Where does your saga begin? You start with little and no ship. How you live, raider or trader, law-wise man or berserk, skald or king's man, you choose as you go, in any mixture.", 15, Palette.TEXT))
	(box.get_child(0) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	box.add_child(grid)
	var group := ButtonGroup.new()
	var cards: Array[Button] = []
	for d in Origins.DEFS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = cards.is_empty()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		var men := int(d.followers)
		b.text = "%s\n\n%s\n\nYou start %s, with %d oz of silver, on foot." % [str(d.name).to_upper(), d.blurb,
				"alone" if men == 0 else ("with one man" if men == 1 else "with %d men" % men), int(d.silver)]
		b.set_meta("origin", str(d.key))
		grid.add_child(b)
		cards.append(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	row.add_child(_label("Your name:", 15, Palette.TEXT))
	var name_edit := LineEdit.new()
	name_edit.text = "Egil"
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(200, 44)
	row.add_child(name_edit)
	var go := Button.new()
	go.text = "Begin"
	go.custom_minimum_size = Vector2(200, 48)
	go.add_theme_font_size_override("font_size", 18)
	go.pressed.connect(func() -> void:
		var origin := "burned_hall"
		for c in cards:
			if c.button_pressed:
				origin = str(c.get_meta("origin"))
		var who := name_edit.text.strip_edges()
		begin_saga(origin, who if who != "" else "Egil"))
	row.add_child(go)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120, 48)
	back.pressed.connect(show_title)
	row.add_child(back)


# --- The saga -------------------------------------------------------------------

func begin_saga(origin: String, leader_name: String) -> void:
	if not fixed_seed:
		seed_in = randi_range(1, 999999)
	journey = Journey.begin(seed_in, origin, leader_name)
	show_map()


func show_map() -> void:
	_drop_battle()
	var m := MapScreen.new()
	_swap(m)
	map = m
	m.setup(journey, self)


## The map has a fight for the battle screen (Journey.fight).
func start_battle() -> void:
	if journey == null or journey.fight.is_empty():
		return
	layer.visible = false
	battle_node = preload("res://view/main.tscn").instantiate()
	battle_node.host = self
	add_child(battle_node)
	var shouts: Array = []
	for s in journey.c.band.custom_shouts:
		shouts.append(s)
	battle_node.start_hosted(journey.fight.built, shouts)


## The battle screen's fight is over: what it left behind, for its panel.
func fight_over(result: BattleResult) -> PackedStringArray:
	return journey.fight_done(result)


## Back to the map from the battle screen.
func leave_battle() -> void:
	_drop_battle()
	layer.visible = true
	if map != null:
		map.refresh()


func _drop_battle() -> void:
	if battle_node != null:
		battle_node.queue_free()
		battle_node = null
	layer.visible = true


# --- The single fight ---------------------------------------------------------------

func start_skirmish() -> void:
	if screen != null:
		screen.queue_free()
		screen = null
	map = null
	battle_node = preload("res://view/main.tscn").instantiate()
	add_child(battle_node)
