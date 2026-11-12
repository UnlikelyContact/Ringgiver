## Named lieutenants in an even fight (docs/design/notes/battles-2.md):
## our band of twelve (8 shields, 2 spears, 2 bows) against as many,
## green, on the varied open field, leader AI against leader AI. Each row
## gives our two lieutenants one word (or none: no wings at all), and
## "chosen" the word a sensible leader would give for the enemy before him
## (Wing.sensible_word). The tempers row variant gives both men a
## temper instead of plain. Usage:
##   godot --headless --path game -s tools/diag_wings.gd -- [n] [seed] [temper] [enemy_wings] [log|-] [attack|defend|both]
## temper: plain (default), rash, steady, cunning; enemy_wings: 1 gives the
## enemy named men too (their own words, by doctrine).
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 40
	var seed_in := int(args[1]) if args.size() > 1 else 1
	var temper_key := args[2] if args.size() > 2 else "plain"
	var enemy_wings := args.size() > 3 and args[3] == "1"
	var show_log := args.size() > 4 and args[4] == "log"
	# Who comes on: "attack" (ours aggressive, theirs as drawn), "defend"
	# (ours steady, theirs aggressive), "both" (both aggressive).
	var stance := args[5] if args.size() > 5 else "attack"
	var temper: int = Wing.TEMPER_NAMES.find(temper_key) if temper_key != "plain" else Wing.Temper.PLAIN
	if temper < 0:
		temper = Wing.Temper.PLAIN
	var rules := CombatRules.new()
	var rows := [["none", -1], ["named, no word", Wing.Word.NONE], ["hold the line", Wing.Word.HOLD_LINE], ["press", Wing.Word.PRESS],
			["fall back", Wing.Word.FALL_BACK], ["round the flank", Wing.Word.ROUND_FLANK],
			["guard the archers", Wing.Word.GUARD_ARCHERS], ["chosen", -2]]
	var only := args[6] if args.size() > 6 else ""
	for row in rows:
		if only != "" and not str(row[0]).begins_with(only):
			continue
		var wins := [0, 0, 0]
		var rounds := 0
		var lt_down := 0
		var acted := 0
		var ours_dead := 0
		for i in n:
			var s := seed_in + i
			var sc := build(s, rules, stance)
			var b: Battle = sc.battle
			var word: int = row[1]
			if word == -2:
				word = Wing.sensible_word(int(sc.doctrine), stance != "defend", temper)
			if word >= 0:
				var lts := lieutenants(b, 0, 2)
				var tempers := [temper, temper]
				Wing.form(b, 0, lts, [word, word], tempers)
			if enemy_wings:
				var elts := lieutenants(b, 1, 2)
				var et := []
				var ew := []
				for w in elts:
					var t := Wing.temper_of(w.personality, PackedStringArray(), w.wits)
					et.append(t)
					ew.append(Wing.doctrine_word(int(sc.doctrine), t))
				Wing.form(b, 1, elts, ew, et)
			var r := b.run()
			wins[r.winner + 1] += 1
			rounds += r.rounds
			ours_dead += r.dead[0]
			for wing in b.wings:
				if wing.side != 0:
					continue
				if wing.leaderless:
					lt_down += 1
				if wing.acted_round >= 0:
					acted += 1
			if show_log:
				print("--- %s seed %d: %s" % [row[0], s, r.summary()])
				for line in b.log:
					if not line.begins_with("actions"):
						print(line)
		print("%-18s n=%d  ours %2d  theirs %2d  draw %2d  win %3d%%  mean rounds %.1f  our dead %.2f  lieutenants acted %d fell %d" % [
				row[0], n, wins[1], wins[2], wins[0], roundi(100.0 * wins[1] / n), float(rounds) / n, float(ours_dead) / n, acted, lt_down])
	quit()


## Two even bands of twelve green men on the varied open field.
static func build(s: int, rules: CombatRules, stance := "attack") -> Dictionary:
	var r := SimRng.new(s).fork("diag-wings")
	var ours := BandFactory.make_mixed_band(r.fork("a"), 0, 8, 2, 2, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 0, 1)
	var theirs := BandFactory.make_mixed_band(r.fork("b"), 1, 8, 2, 2, CombatTypes.Tier.GREEN, rules, CombatTypes.Armor.NONE, 16, 101)
	var sc := Scenario.build("equal_green", s, rules, true, 12, "", {"ours": ours, "theirs": theirs}, {"objective": -1})
	var b: Battle = sc.battle
	b.set_ai(0, LeaderAI.new(LeaderAI.Doctrine.STEADY if stance == "defend" else LeaderAI.Doctrine.AGGRESSIVE))
	if stance != "attack":
		b.set_ai(1, LeaderAI.new(LeaderAI.Doctrine.AGGRESSIVE))
		sc.doctrine = LeaderAI.Doctrine.AGGRESSIVE
	return sc


## The side's `k` likeliest lieutenants: shield or spear men, not the
## leader, the steadiest first (nerve and wits, then id).
static func lieutenants(b: Battle, side: int, k: int) -> Array[Warrior]:
	var pool := []
	for w in b.side_warriors(side):
		if w.is_leader or w.role == CombatTypes.Role.MISSILE:
			continue
		pool.append([-(w.nerve + w.wits), w.id, w])
	pool.sort()
	var out: Array[Warrior] = []
	for i in mini(k, pool.size()):
		out.append(pool[i][2])
	return out
