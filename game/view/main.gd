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


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.BG)
	if not fixed_seed:
		seed_in = randi_range(1, 99999)
	start(scenario, seed_in)


## Where the camera looks: between the two bands, leaning toward your man.
func focus_point() -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for w in battle.warriors:
		if w.is_active():
			sum += Iso.to_screen(w.pos)
			n += 1
	var centre := sum / maxf(1.0, n)
	if player != null and player.is_active():
		centre = centre.lerp(Iso.to_screen(player.pos), 0.4)
	return centre + Vector2(0, -60)


func _process(delta: float) -> void:
	if camera != null and battle != null and view != null and view.follow:
		camera.position = camera.position.lerp(focus_point(), minf(1.0, delta * 3.0))


func start(p_scenario: String, p_seed: int) -> void:
	scenario = p_scenario
	seed_in = p_seed
	for c in get_children():
		c.queue_free()
	var rules := CombatRules.new()
	var field := Scenario.build(p_scenario, p_seed, rules)
	battle = field.battle
	var ours: Array[Warrior] = field.ours
	player = ours[0]

	camera = Camera2D.new()
	camera.zoom = Vector2(2.0, 2.0)
	add_child(camera)
	camera.make_current()
	view = BattleView.new()
	add_child(view)
	view.setup(battle, player, camera)
	camera.position = focus_point()
	hud = preload("res://view/hud.gd").new()
	add_child(hud)
	hud.setup(view, self)
