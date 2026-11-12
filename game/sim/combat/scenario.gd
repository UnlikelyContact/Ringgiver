class_name Scenario
extends RefCounted
## The prototype's skirmish: your band (twelve men unless told otherwise)
## against a band drawn from the seed, on ground drawn from it too (Field),
## so no two fields are alike. The enemy's numbers, where their line stands
## across from yours, and how their leader fights all vary,
## which is what makes a wall bend: lines that overlap unevenly leave a wing
## with nobody in front of it, and it swings in round the enemy's end.
## Tools build the same field from the same seed.

const TIERS := {
	"equal_green": [CombatTypes.Tier.GREEN, CombatTypes.Tier.GREEN],
	"green_vs_veteran": [CombatTypes.Tier.GREEN, CombatTypes.Tier.VETERAN],
	"veteran_vs_green": [CombatTypes.Tier.VETERAN, CombatTypes.Tier.GREEN],
	"equal_veteran": [CombatTypes.Tier.VETERAN, CombatTypes.Tier.VETERAN],
}


## How a band of `n` men is armed: [shields, spears, bows].
## `band_shield_share` of them shields (rounded, at least one), the rest
## split between spears and bows with spears taking the odd man: twelve
## are 8/2/2, eight 5/2/1, six 4/1/1, four 3/1/0.
static func band_split(n: int, rules: CombatRules) -> Array[int]:
	var shields := clampi(roundi(n * rules.band_shield_share), 1, maxi(1, n))
	var rest := maxi(0, n - shields)
	return [shields, (rest + 1) / 2, rest / 2]


## The field for a band of `n` men, as (width, height): `field_min_width`
## by `field_min_height` up to `field_small_band` men, `field_width` by
## `field_height` at `field_band`, straight between (and past), the height
## kept even so both lines have as many rows behind them.
static func field_size(n: int, rules: CombatRules) -> Vector2i:
	var t := maxf(0.0, float(n - rules.field_small_band) / maxf(1.0, float(rules.field_band - rules.field_small_band)))
	var w := roundi(lerpf(rules.field_min_width, rules.field_width, t))
	var h := 2 * roundi(lerpf(rules.field_min_height, rules.field_height, t) / 2.0)
	return Vector2i(maxi(w, rules.field_min_width), maxi(h, rules.field_min_height))


## Returns {battle, ours, theirs, doctrine, offset, objective, field,
## field_name, band, size}. `band` is your band's strength in men, armed by
## `band_split` (twelve: eight shields, two spears, two bows), and the field
## is `field_size(band)`. With `vary` false the enemy is as many
## shield-bearers as yours, centred, steady, and you have only shields: the
## symmetric field the batches calibrate on, with a little mud and nothing
## else (`field` null, `field_name` "flat"). A varied enemy brings your
## shields to a quarter more, and one fewer to as many spears and bows as
## you (eight to ten shields, one or two of each at twelve). Both form in ranks.
##
## A varied field usually has an objective (CombatRules.objective_chance),
## drawn from its own fork of the seed so nothing else on the field changes
## with it: the ford, the ships or the hall, with you the attacker or the
## defender by even odds. Your line always stands at the bottom facing up;
## the objective lies at the defender's end, so where it is tells who must
## come on. Then the field's template (Field) draws its ground: the
## objective's choice, or a weighted draw for an open fight; `template`
## ("meadow", "river", ...) forces one, for tools. The symmetric field
## (`vary` false) never has an objective or a template.
##
## `name` "ambush" is the fight you chose (concept.md, "Picking your
## fights"): the enemy band is on the march along a track across the
## middle of the field, in a column facing along it, every third place
## empty, and your band stands formed two rows below it with the trees at
## its back, in range to throw at once. Their leader is struck dumb for
## `ambush_surprise_rounds` and his men have lost `ambush_morale` heart.
## No objective; the enemy is drawn as for any varied fight. `build_ambush`
## does the placing. "ambushed" is the same the other way about: your band
## is the column. "hold" is the ground you chose to wait on: the river,
## your line on the bank, and the enemy must come through the ford.
##
## `bands` ({ours, theirs}: Array[Warrior], already made, the campaign's
## men) replaces the drawn bands; `band` is then yours. `pick` forces what
## the seed would draw: `objective` (Objective.Kind, or -1 for none),
## `attacker` (side), `doctrine` (LeaderAI.Doctrine).
static func build(name: String, seed_in: int, rules: CombatRules, vary := true, band := 12, template := "",
		bands := {}, pick := {}) -> Dictionary:
	if name == "ambush" or name == "ambushed":
		return build_ambush(seed_in, rules, band, bands, 1 if name == "ambush" else 0)
	if name == "hold":
		var p := pick.duplicate()
		p.objective = Objective.Kind.HOLD_GROUND
		p.attacker = 1
		return build("equal_green", seed_in, rules, true, band, "river", bands, p)
	var t: Array = TIERS.get(name, TIERS["equal_green"])
	if bands.has("ours"):
		band = (bands.ours as Array).size()
	var size := field_size(band, rules)
	var battle := Battle.new(rules, seed_in, BattleGrid.new(size.x, size.y))
	# Rows and columns relative to the field: the enemy's front three rows
	# above the middle, yours five rows below it, both about the centre column.
	var centre := size.x / 2
	var their_row := size.y / 2 - 3
	var our_row := their_row + 5
	var brng := SimRng.new(seed_in).fork("bands")
	var frng := SimRng.new(seed_in).fork("field")
	var split := band_split(band, rules)
	var their_shields: int = split[0]
	var their_spears := 0
	var their_bows := 0
	var offset := 0
	var doctrine := LeaderAI.Doctrine.STEADY
	if vary:
		# About your own strength on average, mixed differently.
		their_shields = frng.randi_range(split[0], split[0] + roundi(split[0] * rules.enemy_more_shields))
		their_spears = frng.randi_range(maxi(0, split[1] - 1), split[1])
		their_bows = frng.randi_range(maxi(0, split[2] - 1), split[2])
		offset = frng.randi_range(-3, 3)
		doctrine = LeaderAI.Doctrine.AGGRESSIVE if frng.randf() < 0.4 else LeaderAI.Doctrine.STEADY
		if frng.randf() < 0.4:
			doctrine = LeaderAI.Doctrine.CUNNING  # two fights in five: he reads your wall
	if pick.has("doctrine"):
		doctrine = pick.doctrine
	var objective: Objective = null
	if vary:
		var orng := SimRng.new(seed_in).fork("objective")
		var kind := -1
		var attacker := 0
		if pick.has("objective"):
			kind = pick.objective
			attacker = pick.get("attacker", 1)
			orng.randf()
			orng.randi_range(0, 2)
			orng.randf()
		elif orng.randf() < rules.objective_chance:
			kind = orng.randi_range(0, Objective.DRAWN_KINDS - 1)
			attacker = 0 if orng.randf() < rules.objective_player_attacks else 1
		if kind >= 0:
			objective = Objective.new(kind as Objective.Kind, attacker, seed_in, rules)
			objective.size_for_band(band, rules)
			# Whoever comes on came for a reason and in strength: an attacking
			# enemy brings more shields, a defending one fewer (two at twelve men).
			var more := roundi(rules.objective_attacker_shields * band / float(rules.field_band))
			their_shields = maxi(1, their_shields + more * (1 if attacker == 1 else -1))
	var ours: Array[Warrior] = bands.get("ours", BandFactory.make_mixed_band(brng.fork("a"), 0, split[0], split[1] if vary else 0, split[2] if vary else 0, t[0], rules, CombatTypes.Armor.NONE, 0, 1))
	var theirs: Array[Warrior] = bands.get("theirs", BandFactory.make_mixed_band(brng.fork("b"), 1, their_shields, their_spears, their_bows, t[1], rules, CombatTypes.Armor.NONE, 16, 101))
	# A little mud so the ground has texture.
	var mr := SimRng.new(seed_in).fork("mud")
	for i in 6 + (size.x - 16) / 2:
		battle.grid.set_terrain(BattleGrid.from_offset(mr.randi_range(2, size.x - 3), mr.randi_range(their_row + 1, our_row - 1)), CombatTypes.Terrain.MUD)
	# The objective's ground, then the template's, before anyone deploys.
	if objective != null:
		# The defender's end: theirs at the top (rear toward row 0), ours at
		# the bottom (rear toward the last row).
		if objective.attacker == 0:
			objective.place(battle.grid, their_row, -1, centre + offset)
		else:
			objective.place(battle.grid, our_row, 1, centre)
		battle.objective = objective
	var field: Field = null
	if vary:
		field = Field.make(battle.grid, rules, seed_in, their_row, our_row, objective, Field.kind_named(template))
	# Lines run across the screen: ours below facing north-west, theirs
	# above facing south-east, five rows apart, theirs shifted along the row.
	var formation := FormationTemplate.ranks()
	BandFactory.deploy_formation(battle.grid, ours, BattleGrid.from_offset(centre, our_row), Vector2i(0, -1), rules, formation)
	BandFactory.deploy_formation(battle.grid, theirs, BattleGrid.from_offset(centre + offset, their_row), Vector2i(0, 1), rules, FormationTemplate.ranks())
	battle.add_band(ours)
	battle.add_band(theirs)
	battle.set_ai(1, LeaderAI.new(doctrine))
	for side in 2:
		battle.result.started[side] = battle.active(side).size()
	if not bands.has("ours"):
		ours[0].display_name = "You"
	return {"battle": battle, "ours": ours, "theirs": theirs, "doctrine": doctrine, "offset": offset,
			"objective": objective, "field": field, "field_name": field.name if field != null else "flat",
			"title": field.title() if field != null else "", "band": band, "size": size}


## The holmgang: two men on a small bare field, three rows apart, the
## fight over at first blood (Battle.duel). `ours` and `theirs` are one
## man each. Returns the same dictionary as `build`, `field_name` "holmgang".
static func build_duel(seed_in: int, rules: CombatRules, ours: Array[Warrior], theirs: Array[Warrior]) -> Dictionary:
	var size := Vector2i(9, 8)
	var battle := Battle.new(rules, seed_in, BattleGrid.new(size.x, size.y))
	battle.duel = true
	var centre := size.x / 2
	BandFactory.deploy_formation(battle.grid, ours, BattleGrid.from_offset(centre, 5), Vector2i(0, -1), rules, FormationTemplate.line())
	BandFactory.deploy_formation(battle.grid, theirs, BattleGrid.from_offset(centre, 2), Vector2i(0, 1), rules, FormationTemplate.line())
	battle.add_band(ours)
	battle.add_band(theirs)
	battle.set_ai(1, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	for side in 2:
		battle.result.started[side] = battle.active(side).size()
	return {"battle": battle, "ours": ours, "theirs": theirs, "doctrine": LeaderAI.Doctrine.AGGRESSIVE, "offset": 0,
			"objective": null, "field": null, "field_name": "holmgang", "title": "Holmgang",
			"band": 1, "size": size}


## The ambush: see `build`. Returns the same dictionary, `field_name`
## "ambush", `title` "Ambush", `objective` null. `ambushed` is the side
## caught on the march: 1 (theirs, the fight you chose) or 0 (yours: you
## are the column, and your men are placed as theirs would be).
static func build_ambush(seed_in: int, rules: CombatRules, band := 12, bands := {}, ambushed := 1) -> Dictionary:
	if bands.has("ours"):
		band = (bands.ours as Array).size()
	var size := field_size(band, rules)
	var battle := Battle.new(rules, seed_in, BattleGrid.new(size.x, size.y))
	var centre := size.x / 2
	var track_row := size.y / 2 - 1
	var our_row := track_row + rules.ambush_distance
	var brng := SimRng.new(seed_in).fork("bands")
	var frng := SimRng.new(seed_in).fork("field")
	var split := band_split(band, rules)
	var their_shields := frng.randi_range(split[0], split[0] + roundi(split[0] * rules.ambush_more_shields))
	# A leader caught on the march is careful afterwards: steady or cunning,
	# never one who charges a formed wall with a column half turned about.
	var doctrine := LeaderAI.Doctrine.CUNNING if frng.randf() < 0.4 else LeaderAI.Doctrine.STEADY
	var ours: Array[Warrior] = bands.get("ours", BandFactory.make_mixed_band(brng.fork("a"), 0, split[0], split[1], split[2], CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 0, 1))
	var theirs: Array[Warrior] = bands.get("theirs", BandFactory.make_mixed_band(brng.fork("b"), 1, their_shields, split[1], split[2], CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 16, 101))
	# Who marches and who waits: the column's men and the ambushers'.
	var column: Array[Warrior] = theirs if ambushed == 1 else ours
	var hidden: Array[Warrior] = ours if ambushed == 1 else theirs
	# The ground: the wood your men come out of, two rows behind your line
	# and thicker further back, and a few trees and mud about the track.
	var tr := SimRng.new(seed_in).fork("ambush-wood")
	for row in range(our_row + 2, size.y):
		for col in size.x:
			var chance := 0.75 if row == our_row + 2 else 0.9
			if tr.randf() < chance:
				battle.grid.set_terrain(BattleGrid.from_offset(col, row), CombatTypes.Terrain.TREE)
	for i in 3:
		var c := BattleGrid.from_offset(tr.randi_range(1, size.x - 2), tr.randi_range(1, track_row - 2))
		battle.grid.set_terrain(c, CombatTypes.Terrain.TREE if tr.randf() < 0.6 else CombatTypes.Terrain.MUD)
	# Their column: the leader in the middle of the track, the rest strung
	# out either side of him in march order, every `ambush_gap_every`th
	# place empty, all facing the way they were going (east, along the row).
	var east := Vector2i(1, 0)
	var leader: Warrior = column[0]
	for w in column:
		w.reset_for_battle(rules)
		w.facing = east
	leader.line_facing = east
	leader.formation = FormationTemplate.line()
	battle.grid.place(leader, BattleGrid.from_offset(centre, track_row))
	var rest: Array[Warrior] = []
	for w in column:
		if w != leader:
			rest.append(w)
	var place := 1
	var k := 0
	while k < rest.size():
		for sgn in [1, -1]:
			if k >= rest.size():
				break
			if place % rules.ambush_gap_every == 0 and sgn == 1:
				continue  # an empty place: the column is strung out
			var col: int = centre + sgn * place
			if col < 0 or col >= size.x:
				continue
			var c := BattleGrid.from_offset(col, track_row)
			if battle.grid.is_free(c):
				battle.grid.place(rest[k], c)
				k += 1
		place += 1
		if place > size.x:
			break
	# The ambushers: formed in ranks below the track, facing up at it, out
	# of the trees.
	BandFactory.deploy_formation(battle.grid, hidden, BattleGrid.from_offset(centre, our_row), Vector2i(0, -1), rules, FormationTemplate.ranks())
	battle.add_band(ours)
	battle.add_band(theirs)
	battle.set_ai(1, LeaderAI.new(doctrine if ambushed == 1 else LeaderAI.Doctrine.AGGRESSIVE))
	battle.surprise(ambushed, rules.ambush_surprise_rounds, rules.ambush_morale)
	for side in 2:
		battle.result.started[side] = battle.active(side).size()
	if not bands.has("ours"):
		ours[0].display_name = "You"
	var what := "ambush" if ambushed == 1 else "ambushed"
	return {"battle": battle, "ours": ours, "theirs": theirs, "doctrine": doctrine, "offset": 0,
			"objective": null, "field": null, "field_name": what, "title": "Ambush" if ambushed == 1 else "Ambushed",
			"band": band, "size": size}


## The burned hall (concept.md, "Character creation": "you flee at night
## with two men, and the escape is the first fight"): every saga's first
## fight, and the one that teaches the battle (view/tutorial.gd). A small
## field at night. The hall burns along the bottom edge, its door in the
## middle of its front wall, and your leader and his men stand just
## outside it in a line, facing up the field. Up the field, beyond the
## ring of the jarl's men, is the edge of the dark: the tree line along the
## top, the objective (Objective.Kind.ESCAPE). The ring stands
## `escape_ring_distance` rows off in an arc, with the thin place straight
## ahead of the door: two men with an empty hex between them, every other
## man of the ring further round. They are watching the roof fall in and
## are taken by surprise for `escape_surprise_rounds`. Their leader stands
## at the ring's front, off the thin place, and fights it out
## (AGGRESSIVE): it is a fight to get out of, not to win. Your sworn
## leader is spared (Battle.spared): he cannot die here.
##
## `bands` {ours, theirs} replaces the drawn bands (the campaign's men);
## without it you are "You" and two men. The layout is fixed; the seed
## draws the men, the scattered trees and every die. Returns Scenario's
## dictionary, `field_name` "burned_hall", plus `gap` (the thin place's
## empty hex and the two men's) and `door`.
static func build_escape(seed_in: int, rules: CombatRules, bands := {}) -> Dictionary:
	var size := Vector2i(rules.escape_width, rules.escape_height)
	var battle := Battle.new(rules, seed_in, BattleGrid.new(size.x, size.y))
	var g := battle.grid
	var c := size.x / 2
	var door_row := size.y - 3
	var our_row := door_row - 1
	var ring_row := our_row - rules.escape_ring_distance
	var brng := SimRng.new(seed_in).fork("bands")
	var ours: Array[Warrior] = bands.get("ours", BandFactory.make_mixed_band(brng.fork("a"), 0, 3, 0, 0, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 0, 1))
	var theirs: Array[Warrior] = bands.get("theirs", BandFactory.make_mixed_band(brng.fork("b"), 1, rules.escape_enemy_shields + rules.escape_flankers,
			rules.escape_enemy_spears, 0, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 3, 101))
	if str(bands.get("leader_name", "")) != "" and not theirs.is_empty():
		theirs[0].display_name = str(bands.leader_name)
	# The hall: three rows of burning timber along the bottom, its door in
	# the middle of the front wall.
	for row in range(door_row, size.y):
		for col in range(c - 3, c + 4):
			g.set_terrain(BattleGrid.from_offset(col, row), CombatTypes.Terrain.BUILDING)
	var door := BattleGrid.from_offset(c, door_row)
	g.set_terrain(door, CombatTypes.Terrain.DOOR)
	# The dark: the wood along the top edge, its near hexes the way out, and
	# a few trees down the sides of the yard drawn from the seed.
	var tr := SimRng.new(seed_in).fork("escape-wood")
	for col in size.x:
		g.set_terrain(BattleGrid.from_offset(col, 0), CombatTypes.Terrain.TREE)
		if col <= 1 or col >= size.x - 2:
			g.set_terrain(BattleGrid.from_offset(col, 1), CombatTypes.Terrain.TREE)
	for i in 4:
		var col := tr.randi_range(0, 1) if i % 2 == 0 else tr.randi_range(size.x - 2, size.x - 1)
		g.set_terrain(BattleGrid.from_offset(col, tr.randi_range(2, ring_row - 1)), CombatTypes.Terrain.TREE)
	var objective := Objective.new(Objective.Kind.ESCAPE, 0, seed_in, rules)
	objective.place_escape(g, 1)
	battle.objective = objective
	# Your men: a line outside the door, facing up the field; a whole band
	# breaking out of its own hall (`spare` false) comes out in ranks.
	var breakout: bool = not bands.get("spare", true)
	BandFactory.deploy_formation(g, ours, BattleGrid.from_offset(c, our_row), Vector2i(0, -1), rules,
			FormationTemplate.ranks() if breakout else FormationTemplate.line())
	# The ring: the thin place first (two men either side of an empty hex
	# straight ahead of the door), their leader beside it, the rest round
	# the arc toward the hall's ends.
	var spots: Array[Vector2i] = [
		BattleGrid.from_offset(c + 4, our_row),  # their leader, by the hall's end, watching it burn
		BattleGrid.from_offset(c - 1, ring_row), BattleGrid.from_offset(c + 1, ring_row),  # the thin place
		BattleGrid.from_offset(c + 3, ring_row), BattleGrid.from_offset(c - 3, ring_row),
		BattleGrid.from_offset(c + 4, ring_row + 1), BattleGrid.from_offset(c - 4, ring_row + 1),
		BattleGrid.from_offset(c - 4, our_row),
		# The flankers: off at the yard's edges beside the burning hall,
		# rounds away from the thin place.
		BattleGrid.from_offset(0, size.y - 1), BattleGrid.from_offset(size.x - 1, size.y - 1),
		BattleGrid.from_offset(0, size.y - 2), BattleGrid.from_offset(size.x - 1, size.y - 2),
		BattleGrid.from_offset(c + 5, our_row), BattleGrid.from_offset(c - 5, our_row),
	]
	var me := BattleGrid.from_offset(c, our_row)
	var placed := 0
	var steady: Array[Warrior] = []
	for w in theirs:
		w.reset_for_battle(rules)
		var at: Vector2i = spots[placed] if placed < spots.size() else BattleGrid.NO_CELL
		if breakout:
			# A big band fills the yard: a spot taken goes to the next, and
			# past the last, the nearest free ground up the yard.
			while placed < spots.size() and not g.is_free(spots[placed]):
				placed += 1
			at = spots[placed] if placed < spots.size() else _nearest_free(g, BattleGrid.from_offset(c, ring_row - 1))
		if at == BattleGrid.NO_CELL or not g.is_free(at):
			continue
		# The picked men are steady; the two at the thin place are not.
		if placed != 1 and placed != 2:
			w.nerve = mini(10, w.nerve + rules.escape_nerve_bonus)
			steady.append(w)
		g.place(w, at)
		w.facing = BattleGrid.direction_to(at, me)
		if w.is_leader:
			w.line_facing = w.facing
			w.formation = FormationTemplate.line()
		placed += 1
	battle.add_band(ours)
	battle.add_band(theirs)
	battle.set_ai(1, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	battle.surprise(1, rules.escape_surprise_rounds, 0)
	for w in steady:
		w.morale = mini(Morale.MORALE_MAX, w.morale + rules.escape_morale_bonus)
	# The burned hall's leader cannot die there (his saga begins); a man
	# breaking out of his own burning hall later in the saga (`spare` false:
	# Scenario.build_breakout) has no such luck.
	if bands.get("spare", true):
		for w in ours:
			if w.is_leader:
				battle.spared.append(w)
		if battle.spared.is_empty() and not ours.is_empty():
			battle.spared.append(ours[0])
	for side in 2:
		battle.result.started[side] = battle.active(side).size()
	if not bands.has("ours"):
		ours[0].display_name = "You"
	var gap: Array[Vector2i] = [BattleGrid.from_offset(c, ring_row), spots[1], spots[2]]
	return {"battle": battle, "ours": ours, "theirs": theirs, "doctrine": LeaderAI.Doctrine.AGGRESSIVE, "offset": 0,
			"objective": objective, "field": null, "field_name": "burned_hall", "title": "The burned hall",
			"band": ours.size(), "size": size, "gap": gap, "door": door}


# --- The saga's fights (docs/design/notes/saga-fights.md) ----------------------

## The night ground of a hall: the field `hall_width` by `hall_height`, the
## hall's timber across the bottom three rows (nine wide, BUILDING), its
## door in the middle of the front wall (DOOR), the tree line along the top
## (the dark) and a few trees down the sides from the seed. Returns {door,
## walls: the yard's hexes along the hall (front and ends), front_row: the
## yard row before the hall, c: the middle column}.
static func _night_hall(battle: Battle, rules: CombatRules, seed_in: int, door_col := -1) -> Dictionary:
	var g := battle.grid
	var w := g.width
	var h := g.height
	var c := w / 2
	var door_row := h - 3
	for row in range(door_row, h):
		for col in range(c - 4, c + 5):
			g.set_terrain(BattleGrid.from_offset(col, row), CombatTypes.Terrain.BUILDING)
	var dc := c if door_col < 0 else door_col
	var door := BattleGrid.from_offset(dc, door_row)
	g.set_terrain(door, CombatTypes.Terrain.DOOR)
	var tr := SimRng.new(seed_in).fork("hall-wood")
	for col in w:
		g.set_terrain(BattleGrid.from_offset(col, 0), CombatTypes.Terrain.TREE)
	for i in 4:
		var col := tr.randi_range(0, 1) if i % 2 == 0 else tr.randi_range(w - 2, w - 1)
		g.set_terrain(BattleGrid.from_offset(col, tr.randi_range(2, h / 2)), CombatTypes.Terrain.TREE)
	# The yard along the hall: every hex a man can stand on beside its timber.
	var walls: Array[Vector2i] = []
	for row in range(door_row - 1, h):
		for col in w:
			var x := BattleGrid.from_offset(col, row)
			if not g.is_passable(x) or g.terrain_at(x) == CombatTypes.Terrain.DOOR:
				continue
			for n in g.neighbors(x):
				if g.terrain_at(n) == CombatTypes.Terrain.BUILDING:
					walls.append(x)
					break
	battle.night = true
	return {"door": door, "walls": walls, "front_row": door_row - 1, "c": c, "door_row": door_row}


## Your own hall, by night, when a house at feud comes for it (WinterHall,
## the winter's "spears in the snow" and "fire in the night"): your men in
## the yard before the door, the hall at their backs, the attackers coming
## down the yard out of the dark. `burning` is the fire in the night: the
## objective is the walls (Objective.Kind.FIRE: they must hold them
## `fire_rounds` rounds and the roof takes); else they mean to take the
## hall (THE_HALL: the door and the yard before it). `how` is the leader's
## choice (FightOffer): "bar" (bar the door and hold the yard: your line
## close before the door), "meet" (out, and meet them: your line up the
## yard, the walls behind it open), "wait" (your scout warned you: you lie
## in wait at the gate, and they come on strung out and surprised).
## `bands` {ours, theirs} as `build`. Returns Scenario's dictionary,
## `field_name` "hall_defence" or "hall_burning_defence", plus `door`.
static func build_hall_defence(seed_in: int, rules: CombatRules, bands := {}, burning := false, how := "bar") -> Dictionary:
	var size := Vector2i(rules.hall_width, rules.hall_height)
	var battle := Battle.new(rules, seed_in, BattleGrid.new(size.x, size.y))
	var brng := SimRng.new(seed_in).fork("bands")
	var ours: Array[Warrior] = bands.get("ours", BandFactory.make_mixed_band(brng.fork("a"), 0, 6, 2, 1, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 0, 1))
	var theirs: Array[Warrior] = bands.get("theirs", BandFactory.make_mixed_band(brng.fork("b"), 1, 8 if burning else 6, 2, 0,
			CombatTypes.Tier.BLOODED, rules, CombatTypes.Armor.NONE, 16, 101))
	var hall := _night_hall(battle, rules, seed_in)
	var c: int = hall.c
	var our_row: int = int(hall.front_row) - (2 if how == "bar" else 4)
	var their_row := our_row - rules.hall_attack_distance
	var objective := Objective.new(Objective.Kind.FIRE if burning else Objective.Kind.THE_HALL, 1, seed_in, rules)
	if burning:
		objective.place_cells(hall.walls)
	else:
		var keep: Array[Vector2i] = [hall.door]
		for n in battle.grid.neighbors(hall.door):
			if battle.grid.is_passable(n) and BattleGrid.to_offset(n).y < int(hall.door_row):
				keep.append(n)
		objective.place_cells(keep)
	battle.objective = objective
	BandFactory.deploy_formation(battle.grid, ours, BattleGrid.from_offset(c, our_row), Vector2i(0, -1), rules, FormationTemplate.ranks())
	var tr := SimRng.new(seed_in).fork("hall-attack")
	var off := tr.randi_range(-2, 2)
	if how == "wait":
		# Strung out on the way in at the gate, as a column caught on the march.
		BandFactory.deploy_formation(battle.grid, theirs, BattleGrid.from_offset(c + off, their_row + 1), Vector2i(0, 1), rules, FormationTemplate.line())
	else:
		BandFactory.deploy_formation(battle.grid, theirs, BattleGrid.from_offset(c + off, their_row), Vector2i(0, 1), rules, FormationTemplate.ranks())
	battle.add_band(ours)
	battle.add_band(theirs)
	battle.set_ai(1, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	if how == "wait":
		battle.surprise(1, rules.ambush_surprise_rounds, rules.ambush_morale)
	for side in 2:
		battle.result.started[side] = battle.active(side).size()
	if not bands.has("ours"):
		ours[0].display_name = "You"
	return {"battle": battle, "ours": ours, "theirs": theirs, "doctrine": LeaderAI.Doctrine.AGGRESSIVE, "offset": off,
			"objective": objective, "field": null, "field_name": "hall_burning_defence" if burning else "hall_defence",
			"title": "Fire in the night" if burning else "Spears in the snow", "band": ours.size(), "size": size,
			"door": hall.door}


## Out of your own burning hall: the escape (`build_escape`) as a fight of
## the saga, the ring the burners who are left, and the leader not spared:
## he can die here. `bands` {ours, theirs, leader_name}.
static func build_breakout(seed_in: int, rules: CombatRules, bands: Dictionary) -> Dictionary:
	var b := bands.duplicate()
	b.spare = false
	var built := build_escape(seed_in, rules, b)
	built.field_name = "breakout"
	built.title = "Out through the door"
	return built


## The burning of another's hall (concept.md, "Hall-burnings: attack a
## sleeping hall at night"): your men ring the hall in the dark, its
## timber alight, and the house's men inside break out through a door at
## the time and place of their own choosing: the escape the other way
## about (Objective.Kind.ESCAPE with their side the attacker), the leader
## AI's (`Battle.ai_breaks_out`). There are two doors, the great door in
## the front wall and the byre door in an end, and the seed decides which
## they come out of. They are desperate (`breakout_morale_bonus`). The
## objective for you: let none of the fighting men through, above all the
## head of the house (their sworn leader: the campaign reads whether he
## fell). `bands` {ours, theirs}. Returns Scenario's dictionary,
## `field_name` "burning", plus `door` (the one they come out of).
static func build_hall_burning(seed_in: int, rules: CombatRules, bands := {}) -> Dictionary:
	var size := Vector2i(rules.hall_width, rules.hall_height)
	var battle := Battle.new(rules, seed_in, BattleGrid.new(size.x, size.y))
	var g := battle.grid
	var brng := SimRng.new(seed_in).fork("bands")
	var ours: Array[Warrior] = bands.get("ours", BandFactory.make_mixed_band(brng.fork("a"), 0, 6, 2, 1, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 0, 1))
	var theirs: Array[Warrior] = bands.get("theirs", BandFactory.make_mixed_band(brng.fork("b"), 1, 6, 2, 0, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 16, 101))
	var hall := _night_hall(battle, rules, seed_in)
	var c: int = hall.c
	var door_row: int = hall.door_row
	var dr := SimRng.new(seed_in).fork("burning-door")
	# The byre door, in one end of the hall; which door they choose.
	var end_col := c - 5 if dr.randf() < 0.5 else c + 5
	var byre := BattleGrid.from_offset(end_col + (1 if end_col < c else -1), door_row + 1)
	g.set_terrain(byre, CombatTypes.Terrain.DOOR)
	var out_byre := dr.randf() < 0.4
	var door: Vector2i = byre if out_byre else hall.door
	var start := BattleGrid.from_offset(end_col, door_row) if out_byre else BattleGrid.from_offset(c, door_row - 1)
	var objective := Objective.new(Objective.Kind.ESCAPE, 1, seed_in, rules)
	objective.place_escape(g, 1)
	battle.objective = objective
	# Theirs: out of the smoke at the door, in a line facing up the yard.
	BandFactory.deploy_formation(g, theirs, start, Vector2i(0, -1), rules, FormationTemplate.ranks())
	for w in theirs:
		w.morale = mini(Morale.MORALE_MAX, w.morale + rules.breakout_morale_bonus)
	# Yours: the ring, an arc across the yard and down both ends of the hall.
	var ring_row := door_row - 1 - rules.escape_ring_distance
	var spots: Array[Vector2i] = []
	spots.append(BattleGrid.from_offset(c, ring_row))
	for k in range(1, 8):
		for sgn in [-1, 1]:
			var col: int = c + sgn * k * 2
			var row := ring_row if k <= 2 else ring_row + (k - 2)
			if col >= 0 and col < size.x and row < size.y:
				spots.append(BattleGrid.from_offset(col, row))
	var me := BattleGrid.from_offset(c, door_row)
	var placed := 0
	for w in ours:
		w.reset_for_battle(rules)
		var at := BattleGrid.NO_CELL
		while placed < spots.size():
			if g.is_free(spots[placed]):
				at = spots[placed]
				placed += 1
				break
			placed += 1
		if at == BattleGrid.NO_CELL:
			at = _nearest_free(g, BattleGrid.from_offset(c, ring_row - 1))
		g.place(w, at)
		w.facing = BattleGrid.direction_to(at, me)
		if w.is_leader:
			w.line_facing = w.facing
			w.formation = FormationTemplate.line()
	battle.add_band(ours)
	battle.add_band(theirs)
	battle.set_ai(1, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	battle.ai_breaks_out = true
	battle.hall_alight = true
	for side in 2:
		battle.result.started[side] = battle.active(side).size()
	if not bands.has("ours"):
		ours[0].display_name = "You"
	return {"battle": battle, "ours": ours, "theirs": theirs, "doctrine": LeaderAI.Doctrine.AGGRESSIVE, "offset": 0,
			"objective": objective, "field": null, "field_name": "burning", "title": "The burning",
			"band": ours.size(), "size": size, "door": door}


static func _nearest_free(g: BattleGrid, from: Vector2i) -> Vector2i:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var x: Vector2i = queue.pop_front()
		if g.is_free(x):
			return x
		for n in g.neighbors(x):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return from


## Two ships lashed side by side (concept.md, "Ship fights: lashed ships,
## boarding, men overboard"): theirs above, yours below, each a long
## narrow deck `deck_rows` men abreast (RAIL along both gunwales, planks
## between, the stem and stern drawn in), open sea (SEA) all round and
## between them but for two gangways where the hulls touch, at the bow and
## the waist (BRIDGE: planks, `deck_gangway` hexes wide). The walls stand along their own rails facing
## each other over the water and meet only at the gangways, so the ground
## is a few men wide there and depth tells. A man thrown back with the sea
## behind him goes over the side, and a broken man at the rail jumps
## (Battle); a ship is taken when her deck is cleared from stem to stern
## (Objective.Kind.DECK); a side with no enemy aboard may cut the lashings
## and row away (Battle.can_withdraw). `attacker` is the side that boards.
## `bands` {ours, theirs} as `build`. Returns Scenario's dictionary,
## `field_name` "deck", plus `hulls` (side -> its deck cells), `gangways`.
static func build_deck(seed_in: int, rules: CombatRules, bands := {}, attacker := 0, doctrine := LeaderAI.Doctrine.STEADY) -> Dictionary:
	var brng := SimRng.new(seed_in).fork("bands")
	var ours: Array[Warrior] = bands.get("ours", BandFactory.make_mixed_band(brng.fork("a"), 0, 8, 2, 2, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 0, 1))
	var theirs: Array[Warrior] = bands.get("theirs", BandFactory.make_mixed_band(brng.fork("b"), 1, 8, 2, 2, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 16, 101))
	var d := rules.deck_rows
	var most := maxi(ours.size(), theirs.size())
	var length := clampi(ceili(most / rules.deck_men_per_column) + 3, rules.deck_min_length, rules.deck_max_length)
	var size := Vector2i(length + 4, 2 * d + 3)
	var battle := Battle.new(rules, seed_in, BattleGrid.new(size.x, size.y))
	var g := battle.grid
	var gap := d + 1
	var hulls := {0: [], 1: []}
	for row in size.y:
		for col in size.x:
			var x := BattleGrid.from_offset(col, row)
			var side := -1
			if row >= 1 and row <= d:
				side = 1
			elif row >= gap + 1 and row <= 2 * d + 1:
				side = 0
			var outer := row == 1 or row == 2 * d + 1
			var inner := row == d or row == gap + 1
			var first := 2
			var last := 2 + length - 1
			if outer:  # the stem and stern draw in
				first += 1
				last -= 1
			if side < 0 or col < first or col > last:
				g.set_terrain(x, CombatTypes.Terrain.SEA)
				continue
			g.set_terrain(x, CombatTypes.Terrain.RAIL if outer or inner else CombatTypes.Terrain.FLAT)
			(hulls[side] as Array).append(x)
	# The gangways: planks over the water where the hulls touch, at the bow
	# and amidships, `deck_gangway` hexes each.
	var gangways: Array[Vector2i] = []
	for col in [3, 2 + length / 2]:
		for k in rules.deck_gangway:
			var x := BattleGrid.from_offset(col + k, gap)
			g.set_terrain(x, CombatTypes.Terrain.BRIDGE)
			gangways.append(x)
	var objective := Objective.new(Objective.Kind.DECK, attacker, seed_in, rules)
	objective.set_hulls(hulls)
	battle.objective = objective
	var centre := 2 + length / 2
	BandFactory.deploy_formation(g, ours, BattleGrid.from_offset(centre, gap + 1), Vector2i(0, -1), rules, FormationTemplate.ranks())
	BandFactory.deploy_formation(g, theirs, BattleGrid.from_offset(centre, d), Vector2i(0, 1), rules, FormationTemplate.ranks())
	# Anyone the formation put off his own deck goes to the nearest free
	# plank of it.
	for side in 2:
		var men: Array[Warrior] = ours if side == 0 else theirs
		var own: Array = hulls[side]
		for w in men:
			if own.has(w.pos):
				continue
			var best := BattleGrid.NO_CELL
			for x: Vector2i in own:
				if g.is_free(x) and (best == BattleGrid.NO_CELL or BattleGrid.distance(x, w.pos) < BattleGrid.distance(best, w.pos)):
					best = x
			if best != BattleGrid.NO_CELL:
				g.remove(w)
				g.place(w, best)
	battle.add_band(ours)
	battle.add_band(theirs)
	battle.set_ai(1, LeaderAI.new(doctrine))
	for side in 2:
		battle.result.started[side] = battle.active(side).size()
	if not bands.has("ours"):
		ours[0].display_name = "You"
	return {"battle": battle, "ours": ours, "theirs": theirs, "doctrine": doctrine, "offset": 0,
			"objective": objective, "field": null, "field_name": "deck", "title": "Ships lashed together",
			"band": ours.size(), "size": size, "hulls": hulls, "gangways": gangways}
