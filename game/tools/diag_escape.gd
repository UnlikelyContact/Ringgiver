## The burned hall's escape over many seeds, the way the tutorial teaches
## it and the way a player who lingers or charges plays it: how often he
## gets out on his feet, the rounds, how many of the ring break, and
## whether the burners quit the field. Usage:
##   godot --headless --path game -s tools/diag_escape.gd -- [seeds]
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 30
	var te: GDScript = load("res://tests/test_escape.gd")
	for mode in ["tutorial", "skip", "nothing", "charge"]:
		var clean := 0
		var carried := 0
		var dead := 0
		var rounds := 0
		var broke := 0
		var routed := 0
		for s in range(1, n + 1):
			var j := Journey.begin(s, "burned_hall", "Egil", true)
			var b: Battle = j.fight.built.battle
			var lw: Warrior = null
			for w in j.fight.built.ours:
				if (w as Warrior).id == j.c.band.leader.id:
					lw = w
			match mode:
				"tutorial":
					var t: Node = te.follow_tutorial(b)
					t.free()
				"skip":
					while not b.is_over() and b.round < b.rules.max_rounds:
						if b.can_withdraw(0) and b.withdraw(0):
							break
						b.set_shout(0, Objective.escape_order(b, 0))
						b.run_round()
				_:
					while not b.is_over() and b.round < 40:
						if mode == "charge":
							b.set_shout(0, CombatTypes.Shout.BREAK_THEM)
						b.run_round()
			if not b.is_over():
				b.run()
			rounds += b.round
			if b.result.escaped(0) and not lw.is_down():
				clean += 1
			if lw.is_down():
				carried += 1
			for w in j.fight.built.theirs:
				if (w as Warrior).broken:
					broke += 1
			if b.result.how == BattleResult.End.ROUT and b.result.winner == 0:
				routed += 1
			var before := j.c.band.living_men().size()
			j.fight_done(b.result)
			dead += maxi(0, before - j.c.band.living_men().size())
		print("%-9s out on his feet %2d/%d  carried %2d  men dead %2d  mean rounds %.1f  burners broken %.1f a fight  burners routed %d" % [
				mode, clean, n, carried, dead, float(rounds) / n, float(broke) / n, routed])
	quit(0)
