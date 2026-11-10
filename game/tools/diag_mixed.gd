## Per-fight diagnostics on varied fields: what the field was, who attacked,
## what the enemy brought, and how the fight ended. Usage:
##   godot --headless --path game -s tools/diag_mixed.gd -- [n] [seed] [strategy]
extends SceneTree

const S := CombatTypes.Shout

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 100
	var seed_in := int(args[1]) if args.size() > 1 else 11
	var strat := args[2] if args.size() > 2 else "wall_push"
	var rules := CombatRules.new()
	var only := ""  # kind=ford: only fights of that kind; role=attack: only that role
	var role := ""
	var logging := false
	for a in args.slice(3):
		if a == "log":
			logging = true
		elif a.begins_with("kind="):
			only = a.substr(5)
		elif a.begins_with("role="):
			role = a.substr(5)
		elif a.begins_with("edge="):
			rules.objective_attacker_shields = int(a.substr(5))
		elif a.begins_with("more="):
			rules.enemy_more_shields = float(a.substr(5))
		elif a.begins_with("ford_frac="):
			rules.objective_ford_fraction = float(a.substr(10))
		elif a.begins_with("ford_rounds="):
			rules.objective_ford_rounds = int(a.substr(12))
	var wins := 0
	var fights := 0
	for i in n:
		var sc := Scenario.build("mixed", seed_in + i, rules, true, 12)
		var b: Battle = sc.battle
		var obj: Objective = sc.objective
		var we_attack := obj != null and obj.attacker == 0
		var kind := "open" if obj == null else (obj.short_name() if obj.has_method("short_name") else str(obj.kind))
		if only != "" and kind != only:
			continue
		if role == "attack" and not we_attack:
			continue
		if role == "defend" and (obj == null or we_attack):
			continue
		while not b.is_over() and b.round < rules.max_rounds:
			var r := b.round + 1
			if r == 1:
				b.set_shout(0, S.SHIELD_WALL)
			elif strat == "wall_hold" or (strat == "attack_objective" and not we_attack and obj != null):
				b.set_shout(0, S.HOLD)
			else:
				b.set_shout(0, S.PUSH)
			b.run_round()
			if logging:
				print("    --- after round %d ---" % b.round)
				dump(b, obj)
				for w in b.active(0):
					print("    %s at %s ford=%s opt=%s why=%s" % [w.display_name, BattleGrid.to_offset(w.pos), b.grid.in_ford(w.pos), w.last_option, w.last_reason])
		if not b.is_over():
			b.run()
		var res := b.result
		var last := ""
		for j in range(b.log.size() - 1, maxi(0, b.log.size() - 6), -1):
			var l: String = b.log[j]
			if l.contains("wins") or l.contains("breaks") or l.contains("stall") or l.contains("leaves") or l.contains("falls") or l.contains("rout") or l.contains("hold") or l.contains("taken") or l.contains("time"):
				last = l
				break
		fights += 1
		if res.winner == 0:
			wins += 1
		if logging:
			for l in b.log:
				print("    " + l)
			dump(b, obj)
		print("seed %d %-9s %-6s %-7s enemy %d/%d/%d %-10s -> %s r%d lost %d/%d obj=%s | %s" % [
			seed_in + i, sc.field_name, kind, "attack" if we_attack else ("defend" if obj != null else "open"),
			sc.theirs.size(), 0, 0, LeaderAI.Doctrine.keys()[sc.doctrine],
			"WIN" if res.winner == 0 else ("LOSS" if res.winner == 1 else "DRAW"), b.round,
			res.started[0] - b.active(0).size(), res.started[1] - b.active(1).size(), str(res.by_objective), last])
	print("TOTAL %d fights, %d wins (%d%%)" % [fights, wins, 0 if fights == 0 else 100 * wins / fights])
	quit(0)


func dump(b: Battle, obj: Objective) -> void:
	for row in b.grid.height:
		var line := ""
		for col in b.grid.width:
			var c := BattleGrid.from_offset(col, row)
			var o := b.grid.occupant(c)
			var t := b.grid.terrain_at(c)
			var ch := "."
			if t == CombatTypes.Terrain.WATER: ch = "~"
			elif t == CombatTypes.Terrain.FORD: ch = "="
			elif t == CombatTypes.Terrain.BRIDGE: ch = "#"
			elif t == CombatTypes.Terrain.MUD: ch = ","
			elif t == CombatTypes.Terrain.TREE: ch = "T"
			elif t == CombatTypes.Terrain.ROCK: ch = "R"
			elif t == CombatTypes.Terrain.FENCE: ch = "f"
			elif t == CombatTypes.Terrain.BUILDING: ch = "W"
			elif t == CombatTypes.Terrain.DOOR: ch = "D"
			elif t == CombatTypes.Terrain.SLOPE: ch = "/"
			if o != null and o.is_active():
				ch = ("a" if o.side == 0 else "b") if not obj or not obj.has_cell(c) else ("A" if o.side == 0 else "B")
			line += (" " if row % 2 == 1 else "") + ch + " "
		print("    %2d %s" % [row, line])

