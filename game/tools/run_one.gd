## Runs the tests of one or more files (names under tests/, without .gd):
##   godot --headless --path game -s tools/run_one.gd -- test_trade_road [test_world_life ...]
extends SceneTree


func _init() -> void:
	var failed := 0
	var total := 0
	for name in OS.get_cmdline_user_args():
		var script: GDScript = load("res://tests/%s.gd" % name)
		if script == null or not script.can_instantiate():
			print("  FAIL could not load %s" % name)
			failed += 1
			continue
		for m in script.get_script_method_list():
			if not m.name.begins_with("test_"):
				continue
			total += 1
			var t0 := Time.get_ticks_msec()
			var inst: TestCase = script.new()
			inst.call(m.name)
			if inst.failures.is_empty():
				print("  ok   %s::%s (%d ms)" % [name, m.name, Time.get_ticks_msec() - t0])
			else:
				failed += 1
				print("  FAIL %s::%s" % [name, m.name])
				for f in inst.failures:
					print("         " + f)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
