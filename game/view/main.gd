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
## The enemy band and their leader's doctrine, for the scout's report.
var theirs: Array = []
var doctrine := 0
## Your band across fights (concept.md, "Picking your fights"): the roster
## the fights are drawn from, and what the last one left behind. Men die,
## mend, break and join between one "Fight again" and the next.
var roster: Band = null
var campaign_rules := CampaignRules.new()
var saga: PackedStringArray = []
var after_lines: PackedStringArray = []
var saga_over := false


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


## The roster: you and `band` - 1 sworn men, two thirds shield-bearers,
## the rest spears and bows, drawn from the campaign's recruit tables.
func make_roster(p_seed: int) -> Band:
	var r := SimRng.new(p_seed).fork("roster")
	var b := Band.new()
	var leader := Recruits.make(r.fork("leader"), campaign_rules, CampaignTypes.Origin.YOUNGER_SON, 22, "You", b.next_id())
	leader.is_leader = true
	leader.loyalty = 100
	for s in [CombatTypes.Stat.MIGHT, CombatTypes.Stat.SKILL, CombatTypes.Stat.NERVE]:
		leader.set_stat(s, leader.stat(s) + campaign_rules.leader_start_bonus)
	b.leader = leader
	b.luck = campaign_rules.luck_start
	var split := Scenario.band_split(band, CombatRules.new())
	for i in band - 1:
		var m := Recruits.random(r.fork("man:%d" % i), campaign_rules, b.next_id())
		if i == 0:
			m.is_banner = true
		elif i == 1:
			m.is_horn = true
		# The leader is the first shield; then the rest in order.
		var n := i + 1
		m.role = CombatTypes.Role.SHIELD if n < split[0] else (CombatTypes.Role.SPEAR if n < split[0] + split[1] else CombatTypes.Role.MISSILE)
		b.add_man(m)
	return b


func start(p_scenario: String, p_seed: int) -> void:
	scenario = p_scenario
	seed_in = p_seed
	for c in get_children():
		c.queue_free()
	var rules := CombatRules.new()
	if roster == null or saga_over:
		roster = make_roster(p_seed)
		saga.clear()
		saga_over = false
	var fighters := roster.fighters(campaign_rules)
	var ours: Array[Warrior] = []
	for m in fighters:
		ours.append(m.to_warrior(0, campaign_rules, rules.javelins_per_man))
	var field := Scenario.build(p_scenario, p_seed, rules, true, ours.size(), template, {"ours": ours})
	battle = field.battle
	field_name = field.field_name
	field_title = field.title
	theirs = field.theirs
	doctrine = field.doctrine
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


## What the fight left behind, applied to the roster (Aftermath): the
## lines for the result panel. Your death ends the saga; the next "Fight
## again" gathers a new band.
func after_fight(result: BattleResult) -> PackedStringArray:
	var ours: Array[Warrior] = []
	for w in battle.warriors:
		if w.side == 0:
			ours.append(w)
	var log := PackedStringArray()
	var told := Aftermath.apply(campaign_rules, roster, ours, result, SimRng.new(seed_in).fork("aftermath"), true, log)
	after_lines = told.lines
	if roster.leader != null and not roster.leader.alive:
		saga_over = true
		after_lines.append("Your saga ends here. The next fight is another man's.")
	else:
		var hurt := roster.hurt(campaign_rules).size()
		var fit := roster.fighters(campaign_rules).size()
		after_lines.append("Your band: %d men fit to fight%s." % [fit, (", %d too hurt" % hurt) if hurt > 0 else ""])
	for line in after_lines:
		saga.append(line)
	return after_lines


## The next fight: the days between mend a turn, and the field is new.
func next_fight() -> void:
	if roster != null and not saga_over:
		roster.mend(campaign_rules.mend_between_fights)
	start("equal_green", seed_in + 1)
