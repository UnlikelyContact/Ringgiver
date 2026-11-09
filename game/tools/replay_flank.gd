extends SceneTree
## Replays one fight of tools/batch_flank.gd round by round: the grid, both
## walls' stances and the log, so you can watch the enemy leader answer.
##
##   cd game && timeout 120 godot --headless --path . -s tools/replay_flank.gd -- [seed] [doctrine] [tactic]

const Flank := preload("res://tools/batch_flank.gd")
const S := CombatTypes.Shout


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_in := int(args[0]) if args.size() > 0 else 1
	var dname := args[1] if args.size() > 1 else "CUNNING"
	var tactic := args[2] if args.size() > 2 else "flank"
	var rules := CombatRules.new()
	var b: Battle = Scenario.build("equal_green", seed_in, rules).battle
	b.set_ai(1, LeaderAI.new(int(LeaderAI.Doctrine.get(dname, 0))))
	print(b.grid.describe())
	var printed := 0
	while not b.is_over() and b.round < rules.max_rounds:
		var r := b.round + 1
		match tactic:
			"flank":
				if r == 1:
					b.set_shout(0, S.SHIELD_WALL)
				else:
					if r <= 3 and b.leader_of(0) != null:
						b.leader_of(0).wheel_wall(1)
					b.set_shout(0, S.PUSH)
			"hold_taunt":
				if r == 1:
					b.set_shout(0, S.SHIELD_WALL)
				elif r % 3 == 0:
					b.set_shout(0, S.TAUNT)
				else:
					b.set_shout(0, S.HOLD)
			_:
				b.set_shout(0, S.SHIELD_WALL if r == 1 else S.PUSH)
		b.run_round()
		for i in range(printed, b.log.size()):
			print(b.log[i])
		printed = b.log.size()
		for side in 2:
			var l := b.leader_of(side)
			if l != null:
				var o := BattleGrid.to_offset(l.pos)
				print("side %d leader @%d,%d stance %s facing %d, wall %d" % [side, o.x, o.y,
						BattleGrid.AXIS_NAMES[l.wall_axis()], BattleGrid.dir_index(l.wall_facing()), b.wall_members(side).size()])
		print(_facings(b))
		print("")
	if not b.is_over():
		b.run(b.round)
	for i in range(printed, b.log.size()):
		print(b.log[i])
	print(b.result.summary())
	quit(0)


## The grid with each man drawn as his side's letter and his facing index.
func _facings(b: Battle) -> String:
	var lines := PackedStringArray()
	for row in b.grid.height:
		var s := "  " if row & 1 else ""
		for col in b.grid.width:
			var w := b.grid.occupant(BattleGrid.from_offset(col, row))
			if w == null:
				s += ".   "
			else:
				var tag := ("a" if w.side == 0 else "b") if w.broken else ("A" if w.side == 0 else "B")
				var role := "s" if w.role == CombatTypes.Role.SHIELD else ("p" if w.role == CombatTypes.Role.SPEAR else "m")
				s += "%s%s%d " % [tag, role, BattleGrid.dir_index(w.facing)]
		lines.append(s)
	return "\n".join(lines)
