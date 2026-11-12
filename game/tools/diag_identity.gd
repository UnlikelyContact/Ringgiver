## A fingerprint of ordinary fights, to show a change to the combat code
## leaves them as they were: every seed of the varied field, the hold, the
## ambush both ways and the burned hall's escape, fought out by the leader
## AIs, with the hash of each fight's whole log and its result. Run it
## before and after a change and compare the two outputs. Usage:
##   godot --headless --path game -s tools/diag_identity.gd -- [n] [seed]
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 20
	var seed_in := int(args[1]) if args.size() > 1 else 1
	var rules := CombatRules.new()
	var all := ""
	for name in ["mixed", "hold", "ambush", "ambushed", "escape"]:
		var h := ""
		for i in n:
			var sc: Dictionary
			if name == "escape":
				sc = Scenario.build_escape(seed_in + i, rules)
				(sc.battle as Battle).set_ai(0, LeaderAI.new(LeaderAI.Doctrine.STEADY))
			else:
				sc = Scenario.build(name, seed_in + i, rules, true, 12)
				(sc.battle as Battle).set_ai(0, LeaderAI.new(LeaderAI.Doctrine.STEADY))
			var b: Battle = sc.battle
			var r := b.run()
			h += "%d:%s:%d|" % [i, r.summary(), "\n".join(b.log).hash()]
		print("%-9s %d fights  %s" % [name, n, str(h.hash())])
		all += h
	print("ALL %s" % str(all.hash()))
	quit()
