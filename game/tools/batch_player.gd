extends SceneTree
## Plays the prototype scenario (player side 0 vs STEADY AI) with scripted
## shout strategies and reports win rates. Answers "can the player win?".
##
##   godot --headless --path game -s tools/batch_player.gd -- [n] [seed] [scenario]

const S := CombatTypes.Shout


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 200
	var seed_in := int(args[1]) if args.size() > 1 else 1
	var scenario := args[2] if args.size() > 2 else "equal_green"
	var strats := ["none", "wall_push", "wall_hold", "wall_hold_then_push", "push_only", "break_them", "wall_advance", "wall_then_nothing", "wall_every_round", "hold_only",
		"wall_push_leader_attacks", "wall_push_leader_steps", "ai_steady", "ai_aggressive"]
	if args.size() > 3:
		strats = [args[3]]
	for strat in strats:
		run(strat, n, seed_in, scenario, args.size() > 4)
	quit(0)


func build(seed_in: int, scenario: String, rules: CombatRules) -> Battle:
	return Scenario.build(scenario, seed_in, rules).battle


func in_contact(b: Battle) -> bool:
	for w in b.active(0):
		if not b.grid.adjacent_warriors(w.pos, 1).is_empty():
			return true
	return false


func run(strat: String, n: int, seed_in: int, scenario: String, per_fight := false) -> void:
	var rules := CombatRules.new()
	var wins := [0, 0, 0]
	var rounds := 0
	var our_lost := 0
	var their_lost := 0
	var hesitations := 0
	var reasons := {}
	for i in n:
		var b := build(seed_in + i, scenario, rules)
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
			if OS.get_cmdline_user_args().size() > 5:
				for line in b.log:
					print("      " + line)
		if res.winner < 0:
			wins[2] += 1
		else:
			wins[res.winner] += 1
		rounds += b.round
		our_lost += 8 - b.active(0).size()
		their_lost += 8 - b.active(1).size()
		for line in b.log:
			if line.contains("hesitates") and line.begins_with("You"):
				hesitations += 1
			if line.begins_with("==="):
				var why := line.trim_prefix("=== ").trim_suffix(" ===").replace("side 0", "we").replace("side 1", "they")
				reasons[why] = reasons.get(why, 0) + 1
	print("%-20s %s: win %5.1f%%  lose %5.1f%%  draw %4.1f%%  rounds %4.1f  our lost %.1f  their lost %.1f  our hesitations/fight %.1f" % [
		strat, scenario, 100.0 * wins[0] / n, 100.0 * wins[1] / n, 100.0 * wins[2] / n, float(rounds) / n,
		float(our_lost) / n, float(their_lost) / n, float(hesitations) / n])
	if per_fight or OS.get_cmdline_user_args().size() > 5:
		for why in reasons:
			print("      %3d  %s" % [reasons[why], why])
