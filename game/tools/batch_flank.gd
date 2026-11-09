extends SceneTree
## Plays the playtester's tactics against each enemy doctrine on the
## prototype field (Scenario.build "equal_green", varied) and prints
## doctrine x tactic -> win/lose/draw % and mean rounds. Answers "is the
## flank attack, or standing still, still a free win?".
##
##   cd game && timeout 900 godot --headless --path . -s tools/batch_flank.gd -- [n] [seed] [doctrines] [tactics] [overrides]
##
## overrides is an optional comma list of CombatRules values to sweep,
## e.g. ai_refuse_men=0,ai_push_advantage=1.3.
##
## doctrines and tactics are optional comma lists (e.g. STEADY,CUNNING and
## flank,hold_taunt). Tactics:
##   flank       Shield wall! on round 1, wheel right a stance on rounds 2
##               and 3, Push! from round 2: the wall comes at the enemy's end.
##   hold_taunt  Shield wall!, then Hold!, taunting every third round while
##               nobody is engaged.
##   wall_push   Shield wall!, then Push! straight.
##   flank1      As flank, wheeling right one stance only (an oblique advance).
##   flank_left  As flank, wheeling left twice.

const S := CombatTypes.Shout


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 200
	var seed_in := int(args[1]) if args.size() > 1 else 1
	var doctrines: Array = ["STEADY", "AGGRESSIVE", "CUNNING"]
	if args.size() > 2:
		doctrines = Array(args[2].split(","))
	var tactics: Array = ["flank", "hold_taunt", "wall_push"]
	if args.size() > 3:
		tactics = Array(args[3].split(","))
	var overrides := {}
	if args.size() > 4:
		for kv in args[4].split(","):
			var parts := kv.split("=")
			if parts.size() == 2:
				overrides[parts[0]] = str_to_var(parts[1])
	print("%-11s %-11s %6s %6s %6s %7s" % ["doctrine", "tactic", "win%", "lose%", "draw%", "rounds"])
	for dname in doctrines:
		if not LeaderAI.Doctrine.has(dname):
			print("%-11s (no such doctrine)" % dname)
			continue
		for tactic in tactics:
			var r := run(int(LeaderAI.Doctrine[dname]), tactic, n, seed_in, overrides)
			print("%-11s %-11s %6.1f %6.1f %6.1f %7.1f" % [dname, tactic, r[0], r[1], r[2], r[3]])
	quit(0)


func in_contact(b: Battle) -> bool:
	for w in b.active(0):
		if not b.grid.adjacent_warriors(w.pos, 1).is_empty():
			return true
	return false


## How far right of our leader the enemy's men stand on average (screen x).
func _enemy_dx(b: Battle, you: Warrior) -> float:
	var sum := 0.0
	var foes := b.active(1)
	for e in foes:
		sum += BattleGrid.to_cart(Vector2(e.pos)).x - BattleGrid.to_cart(Vector2(you.pos)).x
	return sum / maxi(1, foes.size())


## [win %, lose %, draw %, mean rounds] for side 0.
func run(doctrine: int, tactic: String, n: int, seed_in: int, overrides := {}) -> Array:
	var rules := CombatRules.new()
	for k in overrides:
		rules.set(k, overrides[k])
	var wins := [0, 0, 0]
	var rounds := 0
	for i in n:
		var b: Battle = Scenario.build("equal_green", seed_in + i, rules).battle
		b.set_ai(1, LeaderAI.new(doctrine))
		while not b.is_over() and b.round < rules.max_rounds:
			var r := b.round + 1
			match tactic:
				"flank":
					if r == 1:
						b.set_shout(0, S.SHIELD_WALL)
					else:
						if r <= 3:
							var you := b.leader_of(0)
							if you != null:
								you.wheel_wall(1)
						b.set_shout(0, S.PUSH)
				"flank1", "flank_left":
					if r == 1:
						b.set_shout(0, S.SHIELD_WALL)
					else:
						if r == 2 or (r == 3 and tactic == "flank_left"):
							var you2 := b.leader_of(0)
							if you2 != null:
								you2.wheel_wall(1 if tactic == "flank1" else -1)
						b.set_shout(0, S.PUSH)
				"flank_aimed", "flank_away":
					# One stance toward (or away from) the side the enemy
					# stands off to, then on: an oblique advance at an end.
					if r == 1:
						b.set_shout(0, S.SHIELD_WALL)
					else:
						var you3 := b.leader_of(0)
						if r == 2 and you3 != null:
							var dx := _enemy_dx(b, you3)
							var right := dx >= 0.0
							if tactic == "flank_away":
								right = not right
							you3.wheel_wall(1 if right else -1)
						b.set_shout(0, S.PUSH)
				"hold_taunt":
					if r == 1:
						b.set_shout(0, S.SHIELD_WALL)
					elif r % 3 == 0 and not in_contact(b):
						b.set_shout(0, S.TAUNT)
					else:
						b.set_shout(0, S.HOLD)
				_:
					b.set_shout(0, S.SHIELD_WALL if r == 1 else S.PUSH)
			b.run_round()
		if not b.is_over():
			b.run()
		var res := b.result
		if res.winner < 0:
			wins[2] += 1
		else:
			wins[res.winner] += 1
		rounds += b.round
	return [100.0 * wins[0] / n, 100.0 * wins[1] / n, 100.0 * wins[2] / n, float(rounds) / n]
