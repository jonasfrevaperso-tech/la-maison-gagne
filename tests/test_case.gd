class_name TestCase
extends RefCounted
## Base minimale des tests : chaque méthode `test_*` est exécutée par tests/run_tests.gd.

var failures: Array[String] = []
var current_test: String = ""


func before_each() -> void:
	pass


func check(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("%s : %s" % [current_test, msg if msg != "" else "assertion fausse"])


func eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) and not ((actual is int or actual is float) and (expected is int or expected is float)):
		failures.append("%s : %s attendu %s (%s), obtenu %s (%s)" % [current_test, msg, str(expected), type_string(typeof(expected)), str(actual), type_string(typeof(actual))])
		return
	if actual != expected:
		failures.append("%s : %s attendu %s, obtenu %s" % [current_test, msg, str(expected), str(actual)])


func near(actual: float, expected: float, tol: float, msg: String = "") -> void:
	if absf(actual - expected) > tol:
		failures.append("%s : %s attendu ~%f, obtenu %f" % [current_test, msg, expected, actual])
