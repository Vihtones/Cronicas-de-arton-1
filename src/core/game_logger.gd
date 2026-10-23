class_name GameLogger
extends RefCounted
## Logger estruturado com níveis e buffer em memória (para telemetria/depuração).

enum Level { DEBUG, INFO, WARN, ERROR }

const MAX_BUFFER := 500

var min_level: Level = Level.INFO
var echo_to_console: bool = true
var buffer: Array[Dictionary] = []


func log_msg(level: Level, module: String, message: String, data: Dictionary = {}) -> void:
	if level < min_level:
		return
	var entry := {"level": Level.keys()[level], "module": module, "msg": message, "data": data}
	buffer.append(entry)
	if buffer.size() > MAX_BUFFER:
		buffer.pop_front()
	if echo_to_console:
		var line := "[%s][%s] %s %s" % [entry.level, module, message, JSON.stringify(data) if not data.is_empty() else ""]
		if level >= Level.ERROR:
			push_error(line)
		elif level == Level.WARN:
			push_warning(line)
		else:
			print(line)


func debug(m: String, msg: String, d: Dictionary = {}) -> void: log_msg(Level.DEBUG, m, msg, d)
func info(m: String, msg: String, d: Dictionary = {}) -> void: log_msg(Level.INFO, m, msg, d)
func warn(m: String, msg: String, d: Dictionary = {}) -> void: log_msg(Level.WARN, m, msg, d)
func error(m: String, msg: String, d: Dictionary = {}) -> void: log_msg(Level.ERROR, m, msg, d)
