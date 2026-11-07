extends SceneTree
## Fights many seeded battles and reports outcomes per scenario.
##
##   godot --headless --path ring-giver/game -s tools/batch_battles.gd -- [scenario|all] [n] [seed]
##
## Scenarios: green_vs_veteran, veteran_vs_green, equal_green, equal_veteran,
## mail_vs_none. This is the milestone 1 gate tool (concept.md).

const SCENARIOS := {
	"green_vs_veteran": [CombatTypes.Tier.GREEN, CombatTypes.Tier.VETERAN, CombatTypes.Armor.NONE, CombatTypes.Armor.NONE],
	"veteran_vs_green": [CombatTypes.Tier.VETERAN, CombatTypes.Tier.GREEN, CombatTypes.Armor.NONE, CombatTypes.Armor.NONE],
	"equal_green": [CombatTypes.Tier.GREEN, CombatTypes.Tier.GREEN, CombatTypes.Armor.NONE, CombatTypes.Armor.NONE],
	"equal_veteran": [CombatTypes.Tier.VETERAN, CombatTypes.Tier.VETERAN, CombatTypes.Armor.NONE, CombatTypes.Armor.NONE],
	"mail_vs_none": [CombatTypes.Tier.BLOODED, CombatTypes.Tier.BLOODED, CombatTypes.Armor.MAIL, CombatTypes.Armor.NONE],
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var which := args[0] if args.size() > 0 else "all"
	var n := int(args[1]) if args.size() > 1 else 200
	var seed_in := int(args[2]) if args.size() > 2 else 1
	var names: Array = SCENARIOS.keys() if which == "all" else [which]
	for name in names:
		if not SCENARIOS.has(name):
			print("unknown scenario %s" % name)
			continue
		run_scenario(name, n, seed_in)
	quit(0)


static func build_battle(name: String, seed_in: int, rules: CombatRules) -> Battle:
	var spec: Array = SCENARIOS[name]
	var b := Battle.new(rules, seed_in)
	var brng := SimRng.new(seed_in).fork("bands")
	var band_a := BandFactory.make_band(brng.fork("a"), 0, 8, spec[0], spec[2], 0)
	var band_b := BandFactory.make_band(brng.fork("b"), 1, 8, spec[1], spec[3], 16)
	BandFactory.deploy_column(b.grid, band_a, 5, Vector2i(1, 0), rules)
	BandFactory.deploy_column(b.grid, band_b, 10, Vector2i(-1, 0), rules)
	b.add_band(band_a)
	b.add_band(band_b)
	b.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
	b.set_ai(1, LeaderAI.new(LeaderAI.Doctrine.STEADY))
	return b


func run_scenario(name: String, n: int, seed_in: int) -> void:
	var rules := CombatRules.new()
	var wins := [0, 0, 0]  # A, B, draw
	var rounds_total := 0
	var downed := [0, 0]
	var broken := [0, 0]
	var fled := [0, 0]
	var dead := [0, 0]
	var round_hist := {}
	var exchanges := 0
	for i in n:
		var b := build_battle(name, seed_in + i, rules)
		var r := b.run()
		if r.winner < 0:
			wins[2] += 1
		else:
			wins[r.winner] += 1
		rounds_total += r.rounds
		for line in r.log:
			if line.contains(" beats "):
				exchanges += 1
		round_hist[r.rounds] = round_hist.get(r.rounds, 0) + 1
		for s in 2:
			downed[s] += r.downed[s]
			broken[s] += r.broken[s]
			fled[s] += r.fled[s]
			dead[s] += r.dead[s]
	print("== %s  (%d battles, seed %d)" % [name, n, seed_in])
	print("   A wins %5.1f%%   B wins %5.1f%%   draws %5.1f%%   mean rounds %.1f   decisive blows/battle %.1f" % [
		100.0 * wins[0] / n, 100.0 * wins[1] / n, 100.0 * wins[2] / n, float(rounds_total) / n, float(exchanges) / n])
	for s in 2:
		print("   side %s per battle: down %.2f  broken %.2f  fled %.2f  dead %.2f" % [
			"A" if s == 0 else "B", float(downed[s]) / n, float(broken[s]) / n, float(fled[s]) / n, float(dead[s]) / n])
	var keys := round_hist.keys()
	keys.sort()
	var line := "   rounds:"
	for k in keys:
		line += " %d:%d" % [k, round_hist[k]]
	print(line)
