class_name TestCase
extends RefCounted

var failures: PackedStringArray = PackedStringArray()


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func eq(a, b, msg: String = "") -> void:
	if a != b:
		failures.append("%s (esperado %s, obtido %s)" % [msg, str(b), str(a)])
