## The burned hall's escape played by first-time players of every kind
## (tests/escape_players.gd): how often each gets out on his feet, is
## carried off, how long it takes, the rounds that bring him no nearer the
## dark, the men he loses, and the rounds the banner asks for something he
## cannot usefully do. Usage:
##   godot --headless --path game -s tools/diag_first_fight.gd -- [seeds] [model,model,...] [verbose seed]
## With a third argument, prints that seed's banner round by round for each
## model named.
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 50
	var players: GDScript = load("res://tests/escape_players.gd")
	var models: Array = players.MODELS
	if args.size() > 1 and args[1] != "all":
		models = Array(args[1].split(","))
	if args.size() > 2:
		var s := int(args[2])
		for m in models:
			var r: Dictionary = players.play(m, s)
			print("== %s seed %d: out %s carried %s rounds %d idle %d bad %d lost %d" % [m, s, r.out, r.carried, r.rounds, r.idle, r.bad, r.lost])
			for line in r.texts:
				print("   " + line)
			for line in r.lines:
				print("   > " + line)
		quit(0)
		return
	for m in models:
		print(players.row(players.measure(m, n)))
	quit(0)
