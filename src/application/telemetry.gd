class_name Telemetry
extends RefCounted
## Métricas de desempenho (§15): p50/p95 de frame, tempo de comando/tick, save/load.

var frame_ms: Array[float] = []
var command_ms: Array[float] = []
var save_ms: Array[float] = []
var load_ms: Array[float] = []
var events_per_command: Array[int] = []
const CAP := 3000


func push(arr: Array, v: Variant) -> void:
	arr.append(v)
	if arr.size() > CAP:
		arr.pop_front()


static func percentile(arr: Array, p: float) -> float:
	if arr.is_empty():
		return 0.0
	var s := arr.duplicate()
	s.sort()
	return float(s[clampi(int(round((s.size() - 1) * p)), 0, s.size() - 1)])


func report() -> Dictionary:
	return {
		"frame_p50_ms": percentile(frame_ms, 0.5), "frame_p95_ms": percentile(frame_ms, 0.95),
		"cmd_p50_ms": percentile(command_ms, 0.5), "cmd_p95_ms": percentile(command_ms, 0.95),
		"save_p95_ms": percentile(save_ms, 0.95), "load_p95_ms": percentile(load_ms, 0.95),
		"events_p95": percentile(events_per_command, 0.95), "samples": frame_ms.size(),
	}
