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


## Returns {battle, ours, theirs, doctrine, offset}. With `vary` false the
## enemy is eight shield-bearers, centred, steady: the symmetric field the
## batches calibrate on. Your band is eight shield-bearers, two spearmen
## and two bowmen; a varied enemy brings eight to ten shields, one or two
## spears and one or two bows. Both form in ranks.
static func build(name: String, seed_in: int, rules: CombatRules, vary := true) -> Dictionary:
	var t: Array = TIERS.get(name, TIERS["equal_green"])
	var battle := Battle.new(rules, seed_in)
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
	var ours := BandFactory.make_mixed_band(brng.fork("a"), 0, 8, 2 if vary else 0, 2 if vary else 0, t[0], rules, CombatTypes.Armor.NONE, 0, 1)
	var theirs := BandFactory.make_mixed_band(brng.fork("b"), 1, their_shields, their_spears, their_bows, t[1], rules, CombatTypes.Armor.NONE, 16, 101)
	# A little mud so the ground has texture.
	var mr := SimRng.new(seed_in).fork("mud")
	for i in 6:
		battle.grid.set_terrain(BattleGrid.from_offset(mr.randi_range(2, 13), mr.randi_range(4, 7)), CombatTypes.Terrain.MUD)
	# Lines run across the screen: ours below facing north-west, theirs
	# above facing south-east, five rows apart, theirs shifted along the row.
	var template := FormationTemplate.ranks()
	BandFactory.deploy_formation(battle.grid, ours, BattleGrid.from_offset(8, 8), Vector2i(0, -1), rules, template)
	BandFactory.deploy_formation(battle.grid, theirs, BattleGrid.from_offset(8 + offset, 3), Vector2i(0, 1), rules, FormationTemplate.ranks())
	battle.add_band(ours)
	battle.add_band(theirs)
	battle.set_ai(1, LeaderAI.new(doctrine))
	for side in 2:
		battle.result.started[side] = battle.active(side).size()
	ours[0].display_name = "You"
	return {"battle": battle, "ours": ours, "theirs": theirs, "doctrine": doctrine, "offset": offset}
