extends SceneTree
## Plays the prototype scenario (player side 0 vs STEADY AI) with scripted
## shout strategies and reports win rates. Answers "can the player win?".
## Varied fields carry objectives (Scenario, Objective): each strategy also
## reports how its fights ended (objective, lines breaking, drawn) and its
## win rate attacking, defending and in open fights.
##
##   godot --headless --path game -s tools/batch_player.gd -- [n] [seed] [scenario] [strategy] [band] [per-fight] [log]
##
## `band` is your band's strength in men (default 12); the enemy and the
## field are sized to it (Scenario.build). Any sixth argument prints each
## fight, a seventh its log too.

const S := CombatTypes.Shout


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 200
	var seed_in := int(args[1]) if args.size() > 1 else 1
	var scenario := args[2] if args.size() > 2 else "equal_green"
	var strats := ["none", "wall_push", "wall_hold", "wall_hold_then_push", "push_only", "break_them", "wall_hold_taunt", "wall_advance", "wall_then_nothing", "wall_every_round", "hold_only",
		"wall_push_leader_attacks", "wall_push_leader_steps", "ai_steady", "ai_aggressive",
		"attack_objective", "attack_objective_taunt"]
	if args.size() > 3 and args[3] != "all":
		strats = [args[3]]
	var band := int(args[4]) if args.size() > 4 else 12
	for strat in strats:
		run(strat, n, seed_in, scenario, args.size() > 5, band)
	quit(0)


func build(seed_in: int, scenario: String, rules: CombatRules, band := 12) -> Battle:
	return Scenario.build(scenario, seed_in, rules, true, band).battle


func in_contact(b: Battle) -> bool:
	for w in b.active(0):
		if not b.grid.adjacent_warriors(w.pos, 1).is_empty():
			return true
	return false


func run(strat: String, n: int, seed_in: int, scenario: String, per_fight := false, band := 12) -> void:
	var rules := CombatRules.new()
	var wins := [0, 0, 0]
	var rounds := 0
	var our_lost := 0
	var their_lost := 0
	var hesitations := 0
	var reasons := {}
	var ends := {"objective": 0, "lines": 0, "drawn": 0}
	var kinds := {"open": 0, "ford": 0, "ships": 0, "hall": 0}
	# role -> [fights, wins]: we attack, we defend, open field.
	var by_role := {"attack": [0, 0], "defend": [0, 0], "open": [0, 0]}
	for i in n:
		var b := build(seed_in + i, scenario, rules, band)
		var obj := b.objective
		var we_attack := obj != null and obj.attacker == 0
		if strat == "ai_steady":
			b.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.STEADY))
		elif strat == "ai_aggressive":
			b.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
		var pushed := false
		while not b.is_over() and b.round < rules.max_rounds:
			var r := b.round + 1
			match strat:
				"wall_push":
					b.set_shout(0, S.SHIELD_WALL if r == 1 else S.PUSH)
				"wall_hold":
					b.set_shout(0, S.SHIELD_WALL if r == 1 else S.HOLD)
				"wall_then_nothing":
					if r == 1:
						b.set_shout(0, S.SHIELD_WALL)
				"wall_every_round":
					b.set_shout(0, S.SHIELD_WALL)
				"hold_only":
					b.set_shout(0, S.HOLD)
				"wall_advance":
					b.set_shout(0, S.SHIELD_WALL if r == 1 else S.HOLD)
					if r > 1:
						b.request_wall_step(0)
				"wall_hold_taunt":
					if r == 1:
						b.set_shout(0, S.SHIELD_WALL)
					elif r % 3 == 0 and not in_contact(b):
						b.set_shout(0, S.TAUNT)
					else:
						b.set_shout(0, S.HOLD)
				"attack_objective", "attack_objective_taunt":
					# Shield wall, then: attacking, push every round; defending,
					# hold and jeer every third round. In an open fight the
					# first pushes and the second holds and jeers.
					var coming := we_attack or (obj == null and strat == "attack_objective")
					if r == 1:
						b.set_shout(0, S.SHIELD_WALL)
					elif coming:
						b.set_shout(0, S.PUSH)
					elif r % 3 == 0 and not in_contact(b):
						b.set_shout(0, S.TAUNT)
					else:
						b.set_shout(0, S.HOLD)
				"push_only":
					b.set_shout(0, S.PUSH)
				"break_them":
					b.set_shout(0, S.SHIELD_WALL if r == 1 else S.BREAK_THEM)
				"wall_push_leader_attacks":
					b.set_shout(0, S.SHIELD_WALL if r == 1 else S.PUSH)
					var you := b.leader_of(0)
					if you != null:
						var adj := b.grid.adjacent_warriors(you.pos, 1)
						if not adj.is_empty():
							b.set_player_action(0, Action.attack(adj[0]))
				"wall_push_leader_steps":
					b.set_shout(0, S.SHIELD_WALL if r == 1 else S.PUSH)
					var you2 := b.leader_of(0)
					if you2 != null:
						var ahead := you2.pos + BattleGrid.advance_step(you2.pos, you2.wall_facing())
						if b.grid.in_bounds(ahead) and b.grid.is_free(ahead):
							b.set_player_action(0, Action.move_to(ahead, you2.wall_facing()))
				"wall_hold_then_push":
					if r == 1:
						b.set_shout(0, S.SHIELD_WALL)
					elif in_contact(b) and not pushed:
						b.set_shout(0, S.PUSH)
						pushed = true
					elif not pushed:
						b.set_shout(0, S.HOLD)
			b.run_round()
		if not b.is_over():
			b.run()  # finishes as a draw
		var res := b.result
		if per_fight:
			print("  seed %d: %s" % [seed_in + i, res.summary()])
			if res.winner < 0:
				var where := []
				for w in b.active(0) + b.active(1):
					var o := BattleGrid.to_offset(w.pos)
					where.append("%s%s@%d,%d%s" % ["A:" if w.side == 0 else "B:", w.display_name.substr(0, 4), o.x, o.y, "!" if w.broken else ""])
				print("      " + " ".join(where) + "  order A=%s B=%s" % [CombatTypes.SHOUT_NAMES[b.standing_order(0)], CombatTypes.SHOUT_NAMES[b.standing_order(1)]])
			if OS.get_cmdline_user_args().size() > 6:
				for line in b.log:
					print("      " + line)
		if res.winner < 0:
			wins[2] += 1
		else:
			wins[res.winner] += 1
		if res.by_objective:
			ends.objective += 1
		elif res.winner < 0:
			ends.drawn += 1
		else:
			ends.lines += 1
		kinds[obj.short_name() if obj != null else "open"] += 1
		var role := "open" if obj == null else ("attack" if we_attack else "defend")
		by_role[role][0] += 1
		if res.winner == 0:
			by_role[role][1] += 1
		rounds += b.round
		our_lost += b.result.started[0] - b.active(0).size()
		their_lost += b.result.started[1] - b.active(1).size()
		for line in b.log:
			if line.contains("hesitates") and line.begins_with("You"):
				hesitations += 1
			if line.begins_with("==="):
				var why := line.trim_prefix("=== ").trim_suffix(" ===").replace("side 0", "we").replace("side 1", "they")
				reasons[why] = reasons.get(why, 0) + 1
	print("%-20s %s band %d: win %5.1f%%  lose %5.1f%%  draw %4.1f%%  rounds %4.1f  our lost %.1f  their lost %.1f  our hesitations/fight %.1f" % [
		strat, scenario, band, 100.0 * wins[0] / n, 100.0 * wins[1] / n, 100.0 * wins[2] / n, float(rounds) / n,
		float(our_lost) / n, float(their_lost) / n, float(hesitations) / n])
	var role_text := ""
	for role in by_role:
		var f: int = by_role[role][0]
		role_text += "  %s %d: win %.0f%%" % [role, f, 100.0 * by_role[role][1] / maxi(1, f)]
	print("      ended: objective %d, lines broke %d, drawn %d | fields: open %d, ford %d, ships %d, hall %d |%s" % [
		ends.objective, ends.lines, ends.drawn, kinds.open, kinds.ford, kinds.ships, kinds.hall, role_text])
	if per_fight or OS.get_cmdline_user_args().size() > 6:
		for why in reasons:
			print("      %3d  %s" % [reasons[why], why])
