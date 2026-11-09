class_name Scenario
extends RefCounted
## The prototype's skirmish: your band of eight against a band drawn from
## the seed, so no two fields are alike. The enemy's numbers, where their
## line stands across from yours, and how their leader fights all vary,
## which is what makes a wall bend: lines that overlap unevenly leave a wing
## with nobody in front of it, and it swings in round the enemy's end.
## Tools build the same field from the same seed.

const TIERS := {
	"equal_green": [CombatTypes.Tier.GREEN, CombatTypes.Tier.GREEN],
	"green_vs_veteran": [CombatTypes.Tier.GREEN, CombatTypes.Tier.VETERAN],
	"veteran_vs_green": [CombatTypes.Tier.VETERAN, CombatTypes.Tier.GREEN],
	"equal_veteran": [CombatTypes.Tier.VETERAN, CombatTypes.Tier.VETERAN],
}


## Returns {battle, ours, theirs, doctrine, offset, objective}. With `vary` false the
## enemy is eight shield-bearers, centred, steady: the symmetric field the
## batches calibrate on. Your band is eight shield-bearers, two spearmen
## and two bowmen; a varied enemy brings eight to ten shields, one or two
## spears and one or two bows. Both form in ranks.
##
## A varied field usually has an objective (CombatRules.objective_chance),
## drawn from its own fork of the seed so nothing else on the field changes
## with it: the ford, the ships or the hall, with you the attacker or the
## defender by even odds. Your line always stands at the bottom facing up;
## the objective lies at the defender's end, so where it is tells who must
## come on. The symmetric field (`vary` false) never has one.
static func build(name: String, seed_in: int, rules: CombatRules, vary := true) -> Dictionary:
	var t: Array = TIERS.get(name, TIERS["equal_green"])
	var battle := Battle.new(rules, seed_in, BattleGrid.new(rules.field_width, rules.field_height))
	# Rows and columns relative to the field: the enemy's front three rows
	# above the middle, yours five rows below it, both about the centre column.
	var centre := rules.field_width / 2
	var their_row := rules.field_height / 2 - 3
	var our_row := their_row + 5
	var brng := SimRng.new(seed_in).fork("bands")
	var frng := SimRng.new(seed_in).fork("field")
	var their_shields := 8
	var their_spears := 0
	var their_bows := 0
	var offset := 0
	var doctrine := LeaderAI.Doctrine.STEADY
	if vary:
		# About your own strength on average (twelve men), mixed differently.
		their_shields = frng.randi_range(8, 10)
		their_spears = frng.randi_range(1, 2)
		their_bows = frng.randi_range(1, 2)
		offset = frng.randi_range(-3, 3)
		doctrine = LeaderAI.Doctrine.AGGRESSIVE if frng.randf() < 0.4 else LeaderAI.Doctrine.STEADY
		if frng.randf() < 0.4:
			doctrine = LeaderAI.Doctrine.CUNNING  # two fights in five: he reads your wall
	var objective: Objective = null
	if vary:
		var orng := SimRng.new(seed_in).fork("objective")
		if orng.randf() < rules.objective_chance:
			var kind: Objective.Kind = orng.randi_range(0, Objective.Kind.size() - 1) as Objective.Kind
			var attacker := 0 if orng.randf() < rules.objective_player_attacks else 1
			objective = Objective.new(kind, attacker, seed_in, rules)
			# Whoever comes on came for a reason and in strength: an attacking
			# enemy brings more shields, a defending one fewer.
			their_shields += rules.objective_attacker_shields * (1 if attacker == 1 else -1)
	var ours := BandFactory.make_mixed_band(brng.fork("a"), 0, 8, 2 if vary else 0, 2 if vary else 0, t[0], rules, CombatTypes.Armor.NONE, 0, 1)
	var theirs := BandFactory.make_mixed_band(brng.fork("b"), 1, their_shields, their_spears, their_bows, t[1], rules, CombatTypes.Armor.NONE, 16, 101)
	# A little mud so the ground has texture.
	var mr := SimRng.new(seed_in).fork("mud")
	for i in 6 + (rules.field_width - 16) / 2:
		battle.grid.set_terrain(BattleGrid.from_offset(mr.randi_range(2, rules.field_width - 3), mr.randi_range(their_row + 1, our_row - 1)), CombatTypes.Terrain.MUD)
	# Lines run across the screen: ours below facing north-west, theirs
	# above facing south-east, five rows apart, theirs shifted along the row.
	var template := FormationTemplate.ranks()
	BandFactory.deploy_formation(battle.grid, ours, BattleGrid.from_offset(centre, our_row), Vector2i(0, -1), rules, template)
	BandFactory.deploy_formation(battle.grid, theirs, BattleGrid.from_offset(centre + offset, their_row), Vector2i(0, 1), rules, FormationTemplate.ranks())
	if objective != null:
		# The defender's end: theirs at the top (rear toward row 0), ours at
		# the bottom (rear toward the last row).
		if objective.attacker == 0:
			objective.place(battle.grid, their_row, -1, centre + offset)
		else:
			objective.place(battle.grid, our_row, 1, centre)
		battle.objective = objective
	battle.add_band(ours)
	battle.add_band(theirs)
	battle.set_ai(1, LeaderAI.new(doctrine))
	for side in 2:
		battle.result.started[side] = battle.active(side).size()
	ours[0].display_name = "You"
	return {"battle": battle, "ours": ours, "theirs": theirs, "doctrine": doctrine, "offset": offset, "objective": objective}
