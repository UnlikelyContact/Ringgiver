extends Node2D
## The prototype's root: builds a skirmish from the sim's band factory, the
## camera, the battle view and the HUD.

var view: BattleView
var camera: Camera2D
var battle: Battle
var player: Warrior
var hud: CanvasLayer
var scenario := "equal_green"
var seed_in := 7
## Tools set this so a run is repeatable; a player gets a fresh field each load.
var fixed_seed := false
## Your band's strength in men; the enemy and the field are sized to it.
var band := 12
## Forces the field's template ("meadow", "river", ...); empty: the seed's.
var template := ""
## The field's template name as built ("meadow", ...), for the HUD.
var field_name := ""
var field_title := ""


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.BG)
	if not fixed_seed:
		seed_in = randi_range(1, 99999)
	start(scenario, seed_in)


const HUD_TOP := 46.0  # the top bar, in design pixels
const HUD_BOTTOM := 66.0  # the shout row
const EDGE_MARGIN := 40.0  # world pixels kept clear round the outermost men


## The box round every man standing and the field's objective, if it has
## one: [min, max] in world pixels.
func _men_bounds() -> Array[Vector2]:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for w in battle.warriors:
		if w.is_active() and not w.broken:  # men running for the edge are leaving the fight
			var p := Iso.to_screen(w.pos)
			lo = lo.min(p)
			hi = hi.max(p)
	if battle.objective != null and lo.x != INF:
		for c in battle.objective.cells:
			var p := Iso.to_screen(c)
			lo = lo.min(p)
			hi = hi.max(p)
	if lo.x == INF:
		return [Vector2.ZERO, Vector2.ZERO]
	return [lo, hi]


## The zoom that fits every man between the top bar and the shout row, no
## closer than the default and no further than the view allows.
func fit_zoom() -> float:
	var b := _men_bounds()
	var size := get_viewport_rect().size
	var band := size.y - HUD_TOP - HUD_BOTTOM
	var span_y: float = b[1].y - b[0].y + 2.0 * EDGE_MARGIN
	var span_x: float = b[1].x - b[0].x + 2.0 * EDGE_MARGIN
	var z := minf(band / maxf(1.0, span_y), size.x / maxf(1.0, span_x))
	return clampf(z, BattleView.MIN_ZOOM, 2.0)


## Where the camera looks: the middle of everyone standing, set so that the
## middle sits in the clear band between the top bar and the shout row.
func focus_point(zoom: float) -> Vector2:
	var b := _men_bounds()
	var centre: Vector2 = (b[0] + b[1]) / 2.0
	return centre + Vector2(0, (HUD_BOTTOM - HUD_TOP) / 2.0 / zoom)


func _process(delta: float) -> void:
	if camera != null and battle != null and view != null and view.follow:
		var k := minf(1.0, delta * 3.0)
		var z := lerpf(camera.zoom.x, fit_zoom(), k)
		camera.zoom = Vector2(z, z)
		camera.position = camera.position.lerp(focus_point(z), k)


func start(p_scenario: String, p_seed: int) -> void:
	scenario = p_scenario
	seed_in = p_seed
	for c in get_children():
		c.queue_free()
	var rules := CombatRules.new()
	var field := Scenario.build(p_scenario, p_seed, rules, true, band, template)
	battle = field.battle
	field_name = field.field_name
	field_title = (field.field as Field).title() if field.field != null else ""
	var ours: Array[Warrior] = field.ours
	player = ours[0]

	camera = Camera2D.new()
	camera.zoom = Vector2(2.0, 2.0)
	add_child(camera)
	camera.make_current()
	view = BattleView.new()
	add_child(view)
	view.setup(battle, player, camera)
	var z0 := fit_zoom()
	camera.zoom = Vector2(z0, z0)
	camera.position = focus_point(z0)
	hud = preload("res://view/hud.gd").new()
	add_child(hud)
	hud.setup(view, self)
