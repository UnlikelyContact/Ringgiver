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
			kind = orng.randi_range(0, Objective.Kind.size() - 1)
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
