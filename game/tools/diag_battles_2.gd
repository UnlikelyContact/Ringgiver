## AI against AI in battles-2's fights (docs/design/notes/battles-2.md).
##   godot --headless --path game -s tools/diag_battles_2.gd -- [n] [seed] [what] [log]
## what: "strand" (the strandhogg by band size and greed: head driven,
## got away, men lost), "sector" (a great battle's sector, on the decks
## and ashore, by the line's lean), or "all".
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 40
	var seed_in := int(args[1]) if args.size() > 1 else 1
	var what := args[2] if args.size() > 2 else "all"
	var show_log := args.size() > 3 and args[3] == "log"
	var rules := CombatRules.new()
	if what == "strand" or what == "all":
		for band in [3, 5, 8, 12]:
			for greed in [0.3, 0.6, 1.0]:
				_strand(n, seed_in, rules, band, greed, show_log)
	if what == "sector" or what == "all":
		for ground in ["deck", "shore"]:
			for edge in [0.3, 0.5, 0.7]:
				_sector(n, seed_in, rules, ground, edge, show_log)
	quit()


## A district of farmstead strength: two green herders, four parties of three.
static func _strand(n: int, seed_in: int, rules: CombatRules, band: int, greed: float, show_log: bool) -> void:
	var got := 0
	var head := 0
	var lost := 0
	var routed := 0
	var rounds := 0
	var dead := 0
	for i in n:
		var s := seed_in + i
		var r := SimRng.new(s).fork("diag-strand")
		var split := Scenario.band_split(band, rules)
		var ours := BandFactory.make_mixed_band(r.fork("a"), 0, split[0], split[1], split[2], CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 0, 1)
		var sc := Scenario.build_strandhogg(s, rules, {"ours": ours}, band, greed)
		var b: Battle = sc.battle
		b.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
		var res := b.run()
		rounds += res.rounds
		dead += res.dead[0]
		lost += res.downed[0] + res.fled[0]
		if res.winner == 0:
			got += 1
			head += res.cattle
		if res.how == BattleResult.End.ROUT and res.winner == 1:
			routed += 1
		if show_log:
			print("--- strand band %d greed %.1f seed %d: %s, %d head" % [band, greed, s, res.summary(), res.cattle])
			for line in b.log:
				if not line.begins_with("actions"):
					print(line)
	print("strandhogg band %2d greed %.1f  n=%d  away %2d  head %.1f a raid (%.1f when away)  routed %d  men down or run %.2f  dead %.2f  rounds %.1f" % [
			band, greed, n, got, float(head) / n, float(head) / maxf(1.0, got), routed, float(lost) / n, float(dead) / n, float(rounds) / n])


## Twelve of ours against twelve blooded, the band's side coming on.
static func _sector(n: int, seed_in: int, rules: CombatRules, ground: String, edge: float, show_log: bool) -> void:
	var days := [0, 0, 0]
	var held := 0
	var rounds := 0
	var broke := 0
	var won_n := 0
	for i in n:
		var s := seed_in + i
		var r := SimRng.new(s).fork("diag-sector")
		var ours := BandFactory.make_mixed_band(r.fork("a"), 0, 8, 2, 2, CombatTypes.Tier.BLOODED, rules, CombatTypes.Armor.NONE, 0, 1)
		var theirs := BandFactory.make_mixed_band(r.fork("b"), 1, 8, 2, 2, CombatTypes.Tier.BLOODED, rules, CombatTypes.Armor.NONE, 16, 101)
		var p := {"ground": ground, "attacker": 0, "edge": edge, "battle_name": "the fjord", "banner": 1,
				"doctrine": LeaderAI.Doctrine.AGGRESSIVE}
		var sc := Scenario.build_sector(s, rules, {"ours": ours, "theirs": theirs}, p)
		var b: Battle = sc.battle
		b.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
		var res := b.run()
		days[res.winner + 1] += 1
		rounds += res.rounds
		var sec: Sector = b.sector
		for nb in sec.neighbours:
			if int(nb.state) == -2:
				broke += 1
			elif int(nb.state) == 2:
				won_n += 1
		# The band's own part held: more of ours standing than of theirs.
		if sec.own_share(b) > 0.0:
			held += 1
		if show_log:
			print("--- sector %s edge %.1f seed %d: %s" % [ground, edge, s, res.summary()])
			for line in b.log:
				if not line.begins_with("actions"):
					print(line)
	print("sector %-5s edge %.1f  n=%d  day ours %2d theirs %2d none %2d  band's part held %2d  neighbours broke %d won %d  rounds %.1f" % [
			ground, edge, n, days[1], days[2], days[0], held, broke, won_n, float(rounds) / n])
