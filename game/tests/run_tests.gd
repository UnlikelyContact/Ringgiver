extends SceneTree
## Minimal headless test runner with no addon dependency.
##
##   godot --headless --path ring-giver/game -s tests/run_tests.gd
##
## Discovers tests/**/test_*.gd, instantiates each (they extend TestCase),
## calls every method whose name starts with test_, and exits 1 on failure.

const TEST_ROOT := "res://tests"


func _init() -> void:
	var files := _collect(TEST_ROOT)
	files.sort()
	var total := 0
	var failed := 0
	for path in files:
		var script: GDScript = load(path)
		if script == null:
			print("  FAIL could not load %s" % path)
			failed += 1
			continue
		for m in script.get_script_method_list():
			if not m.name.begins_with("test_"):
				continue
			total += 1
			var inst: TestCase = script.new()
			inst.call(m.name)
			var label := "%s::%s" % [path.trim_prefix(TEST_ROOT + "/"), m.name]
			if inst.failures.is_empty():
				print("  ok   " + label)
			else:
				failed += 1
				print("  FAIL " + label)
				for f in inst.failures:
					print("         " + f)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)


func _collect(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path + "/" + name
		if dir.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_collect(full))
		elif name.begins_with("test_") and name.ends_with(".gd") and name != "test_case.gd":
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out
