extends SceneTree
## Shows the decision model at work (decision.gd): fights varied fields and
## reports, per tier, how often men chose each option and how many reasons
## (choices other than the plain default for the order) were given a fight.
##
##   godot --headless --path game -s tools/batch_decisions.gd -- [n] [seed] [mixed|plain]
##
## Each field is Scenario.build("equal_green", seed, rules); your side
## shouts Shield wall, then Push, against the varied enemy. Equal green
## bands have only green men, so by default ("mixed") every man is given a
## tier drawn from the seed (two in five green, then blooded, veteran and,
## one in ten, champion) so all four show; his stats stay as built, so
## this shows what the tiers see, not what they are worth. "plain" keeps
## the bands as built.

const S := CombatTypes.Shout
const TIER_ODDS := [0.4, 0.3, 0.2, 0.1]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 100
	var seed_in := int(args[1]) if args.size() > 1 else 1
	var mixed := not (args.size() > 2 and args[2] == "plain")
	var rules := CombatRules.new()
	var by_tier := {}  # tier -> {option -> count}
	var decided := [0, 0, 0, 0]
	var reasons_total := 0
	var reasons_tier := [0, 0, 0, 0]
	var samples := {}  # option -> a reason line
	var wins := [0, 0, 0]
	var traits := {}
	for i in n:
		var b: Battle = Scenario.build("equal_green", seed_in + i, rules).battle
		if mixed:
			var tr := SimRng.new(seed_in + i).fork("tiers")
			for w in b.warriors:
				var roll := tr.randf()
				var t := 0
				while t < 3 and roll >= TIER_ODDS[t]:
					roll -= TIER_ODDS[t]
					t += 1
				w.tier = t as CombatTypes.Tier
		for w in b.warriors:
			for p in w.personality:
				traits[p] = traits.get(p, 0) + 1
			if w.personality.is_empty():
				traits[-1] = traits.get(-1, 0) + 1
		while not b.is_over() and b.round < rules.max_rounds:
			b.set_shout(0, S.SHIELD_WALL if b.round == 0 else S.PUSH)
			b.run_round()
			for w in b.last_actions:
				if w.last_option == "":
					continue  # the player's own override, never decided
				var t := int(w.tier)
				if not by_tier.has(t):
					by_tier[t] = {}
				by_tier[t][w.last_option] = by_tier[t].get(w.last_option, 0) + 1
				decided[t] += 1
				if w.last_reason != "":
					reasons_total += 1
					reasons_tier[t] += 1
					if not samples.has(w.last_option) or (seed_in + i + b.round) % 7 == 0:
						samples[w.last_option] = w.last_reason
		if not b.is_over():
			b.run()
		wins[2 if b.result.winner < 0 else b.result.winner] += 1
	print("decisions over %d fights (%s tiers), your side Shield wall then Push: won %d lost %d drawn %d" % [
			n, "mixed" if mixed else "built", wins[0], wins[1], wins[2]])
	var trait_line := "  personalities on the field:"
	for p in traits:
		trait_line += " %s %d" % ["none" if p < 0 else CombatTypes.Personality.keys()[p].to_lower(), traits[p]]
	print(trait_line)
	var names: Array = []
	for t in by_tier:
		for o in by_tier[t]:
			if not names.has(o):
				names.append(o)
	names.sort_custom(func(a: String, c: String) -> bool: return _total(by_tier, a) > _total(by_tier, c))
	var head := "  %-16s" % "option"
	for t in 4:
		head += " %10s" % CombatTypes.TIER_NAMES[t]
	print(head)
	for o in names:
		var row := "  %-16s" % o
		for t in 4:
			var c: int = by_tier.get(t, {}).get(o, 0)
			row += " %9.2f%%" % (100.0 * c / maxi(1, decided[t]))
		print(row)
	var dec_row := "  %-16s" % "decisions"
	var why_row := "  %-16s" % "reasons"
	for t in 4:
		dec_row += " %10d" % decided[t]
		why_row += " %9.2f%%" % (100.0 * reasons_tier[t] / maxi(1, decided[t]))
	print(dec_row)
	print(why_row)
	print("  reasons logged per fight: %.1f" % (float(reasons_total) / n))
	print("  samples:")
	for o in samples:
		print("    %-16s %s" % [o, samples[o]])
	quit(0)


static func _total(by_tier: Dictionary, o: String) -> int:
	var s := 0
	for t in by_tier:
		s += by_tier[t].get(o, 0)
	return s
