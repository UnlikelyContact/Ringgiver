class_name TestCase
extends RefCounted
## Base class for sim tests. The runner (run_tests.gd) makes a fresh instance
## per test_* method and reports anything appended to `failures`.

var failures: PackedStringArray = []


func fail(msg: String) -> void:
	failures.append(msg)


func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		fail("expected true. " + msg)


func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if actual != expected:
		fail("expected %s, got %s. %s" % [str(expected), str(actual), msg])


func assert_ne(actual: Variant, other: Variant, msg := "") -> void:
	if actual == other:
		fail("expected something other than %s. %s" % [str(other), msg])


func assert_between(value: float, lo: float, hi: float, msg := "") -> void:
	if value < lo or value > hi:
		fail("expected %s in [%s, %s]. %s" % [str(value), str(lo), str(hi), msg])
