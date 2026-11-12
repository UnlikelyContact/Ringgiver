## AI against AI in the saga's own fights (docs/design/notes/saga-fights.md):
## for each scenario, over `n` seeds, who wins how often, how, the mean
## rounds, and what was taken. Both sides are leader AIs; the side that
## comes on is the AGGRESSIVE one. Usage:
##   godot --headless --path game -s tools/diag_saga_fights.gd -- [n] [seed] [only] [log]
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 40
	var seed_in := int(args[1]) if args.size() > 1 else 1
	var only := args[2] if args.size() > 2 else ""
	var show_log := args.size() > 3 and args[3] == "log"
	var rules := CombatRules.new()
	for name in ["plunder", "deck_board", "deck_boarded", "hall_bar", "hall_meet", "hall_wait", "fire_bar", "fire_meet", "burning", "breakout"]:
		if only != "" and only != name:
			continue
		var wins := [0, 0, 0]
		var hows := {}
		var rounds := 0
		var taken := 0
		var over := 0
		var drowned := 0
		var head_down := 0
		for i in n:
			var sc := _build(name, seed_in + i, rules)
			var b: Battle = sc.battle
			if not b._ai.has(0):
				b.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE if sc.get("we_come", false) else LeaderAI.Doctrine.STEADY))
			var r := b.run()
			wins[r.winner + 1] += 1
			var how: String = BattleResult.End.keys()[r.how]
			hows[how] = int(hows.get(how, 0)) + 1
			rounds += r.rounds
			taken += 1 if r.taken else 0
			over += r.overboard[0] + r.overboard[1]
			drowned += r.drowned[0] + r.drowned[1]
			var hl: Warrior = b.sworn_leader(1)
			if hl != null and hl.is_down():
				head_down += 1
			if show_log:
				print("--- %s seed %d: %s" % [name, seed_in + i, r.summary()])
				for line in b.log:
					print(line)
		print("%-13s n=%d  ours %2d  theirs %2d  draw %2d  mean rounds %.1f  taken %d  overboard %d drowned %d  their head down %d  %s" % [
				name, n, wins[1], wins[2], wins[0], float(rounds) / n, taken, over, drowned, head_down, str(hows)])
	quit()


static func _bands(seed_in: int, rules: CombatRules, ours_n: Array, theirs_n: Array, tier := CombatTypes.Tier.GREEN) -> Dictionary:
	var r := SimRng.new(seed_in).fork("diag-bands")
	var ours := BandFactory.make_mixed_band(r.fork("a"), 0, ours_n[0], ours_n[1], ours_n[2], CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 0, 1)
	var theirs := BandFactory.make_mixed_band(r.fork("b"), 1, theirs_n[0], theirs_n[1], theirs_n[2], tier, rules, CombatTypes.Armor.NONE, 16, 101)
	return {"ours": ours, "theirs": theirs}


static func _build(name: String, s: int, rules: CombatRules) -> Dictionary:
	match name:
		"plunder":
			var sc := Scenario.build("equal_green", s, rules, true, 12, "", {}, {"objective": Objective.Kind.PLUNDER, "attacker": 0})
			sc.we_come = true
			return sc
		"deck_board":
			var sc2 := Scenario.build_deck(s, rules, _bands(s, rules, [8, 2, 2], [8, 2, 2]), 0)
			sc2.we_come = true
			return sc2
		"deck_boarded":
			return Scenario.build_deck(s, rules, _bands(s, rules, [8, 2, 2], [8, 2, 2]), 1, LeaderAI.Doctrine.AGGRESSIVE)
		"hall_bar", "hall_meet", "hall_wait":
			return Scenario.build_hall_defence(s, rules, _bands(s, rules, [6, 2, 1], [5, 1, 0], CombatTypes.Tier.BLOODED), false, name.trim_prefix("hall_"))
		"fire_bar", "fire_meet":
			return Scenario.build_hall_defence(s, rules, _bands(s, rules, [6, 2, 1], [8, 2, 0], CombatTypes.Tier.VETERAN), true, name.trim_prefix("fire_"))
		"burning":
			return Scenario.build_hall_burning(s, rules, _bands(s, rules, [8, 2, 1], [6, 2, 0]))
		"breakout":
			var bb := _bands(s, rules, [6, 2, 1], [8, 2, 0])
			bb.leader_name = "Thorkel"
			var sc3 := Scenario.build_breakout(s, rules, bb)
			(sc3.battle as Battle).set_ai(0, LeaderAI.new(LeaderAI.Doctrine.STEADY))
			(sc3.battle as Battle).ai_breaks_out = true
			return sc3
	return {}
