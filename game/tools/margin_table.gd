extends SceneTree
## Prints the opposed-roll margin distribution for a given stat gap.
##
##   godot --headless --path ring-giver/game -s tools/margin_table.gd -- [gap] [n] [seed]
##
## This is the first "balance by simulation" tool (concept.md, Tech). Use it
## to see how lethal the raw table is before absorption is layered on.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var gap := int(args[0]) if args.size() > 0 else 0
	var n := int(args[1]) if args.size() > 1 else 100000
	var seed_in := int(args[2]) if args.size() > 2 else 1
	var rng := SimRng.new(seed_in)
	var by_margin := {}
	var by_tier := [0, 0, 0, 0]
	var attacker_wins := 0
	for i in n:
		var r := OpposedRoll.resolve(rng, gap, 0)
		by_margin[r.margin] = by_margin.get(r.margin, 0) + 1
		by_tier[r.tier()] += 1
		if r.attacker_won():
			attacker_wins += 1
	print("Opposed 2d6, attacker +%d, %d exchanges, seed %d" % [gap, n, seed_in])
	print("attacker wins %5.1f%%   ties %5.1f%%   defender wins %5.1f%%" % [
		100.0 * attacker_wins / n,
		100.0 * by_tier[OpposedRoll.Tier.LOCKED] / n,
		100.0 * (n - attacker_wins - by_tier[OpposedRoll.Tier.LOCKED]) / n,
	])
	print("by tier (either side):")
	for t in 4:
		print("  %-9s %5.1f%%" % [OpposedRoll.tier_name(t), 100.0 * by_tier[t] / n])
	print("by margin:")
	var keys := by_margin.keys()
	keys.sort()
	for k in keys:
		print("  %+3d  %5.1f%%  %s" % [k, 100.0 * by_margin[k] / n, "#".repeat(int(200.0 * by_margin[k] / n))])
	quit(0)
