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


func _ready() -> void:
	RenderingServer.set_default_clear_color(Palette.BG)
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
	return centre + Vector2(0, -10)


func _process(delta: float) -> void:
	if camera != null and battle != null and view != null and view.follow:
		camera.position = camera.position.lerp(focus_point(), minf(1.0, delta * 3.0))


func start(p_scenario: String, p_seed: int) -> void:
	for c in get_children():
		c.queue_free()
	var rules := CombatRules.new()
	battle = Battle.new(rules, p_seed)
	var brng := SimRng.new(p_seed).fork("bands")
	var tiers := {
		"equal_green": [CombatTypes.Tier.GREEN, CombatTypes.Tier.GREEN],
		"green_vs_veteran": [CombatTypes.Tier.GREEN, CombatTypes.Tier.VETERAN],
		"veteran_vs_green": [CombatTypes.Tier.VETERAN, CombatTypes.Tier.GREEN],
		"equal_veteran": [CombatTypes.Tier.VETERAN, CombatTypes.Tier.VETERAN],
	}
	var t: Array = tiers.get(p_scenario, tiers["equal_green"])
	var ours := BandFactory.make_band(brng.fork("a"), 0, 8, t[0], CombatTypes.Armor.NONE, 0, 1)
	var theirs := BandFactory.make_band(brng.fork("b"), 1, 8, t[1], CombatTypes.Armor.NONE, 16, 101)
	# A little mud so the ground has texture.
	var mr := SimRng.new(p_seed).fork("mud")
	for i in 6:
		battle.grid.set_terrain(BattleGrid.from_offset(mr.randi_range(6, 9), mr.randi_range(1, 10)), CombatTypes.Terrain.MUD)
	BandFactory.deploy_column(battle.grid, ours, 5, Vector2i(1, 0), rules)
	BandFactory.deploy_column(battle.grid, theirs, 10, Vector2i(-1, 0), rules)
	battle.add_band(ours)
	battle.add_band(theirs)
	battle.set_ai(1, LeaderAI.new(LeaderAI.Doctrine.STEADY))
	for side in 2:
		battle.result.started[side] = battle.active(side).size()
	player = ours[0]
	player.display_name = "You"

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
