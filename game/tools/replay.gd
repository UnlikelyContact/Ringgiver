extends SceneTree
## Runs one battle and prints the grid and log round by round.
##
##   godot --headless --path ring-giver/game -s tools/replay.gd -- [scenario] [seed]

const Batch := preload("res://tools/batch_battles.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var name := args[0] if args.size() > 0 else "green_vs_veteran"
	var seed_in := int(args[1]) if args.size() > 1 else 1
	var rules := CombatRules.new()
	var b := Batch.build_battle(name, seed_in, rules)
	for side in 2:
		b.result.started[side] = b.active(side).size()
	print(b.grid.describe())
	var printed := 0
	while not b.is_over() and b.round < rules.max_rounds:
		b.run_round()
		for i in range(printed, b.log.size()):
			print(b.log[i])
		printed = b.log.size()
		print(b.grid.describe())
		print("")
	if not b.is_over():
		b.run(b.round)  # triggers the draw finish and fates
	for i in range(printed, b.log.size()):
		print(b.log[i])
	print(b.result.summary())
	quit(0)
