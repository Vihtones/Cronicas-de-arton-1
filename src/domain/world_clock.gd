class_name WorldClock
extends RefCounted
## Relógio canônico do mundo (Plano Mestre §7). Domínio puro: sem Node, sem SO.
## Ticks inteiros; calendário configurável. 1 tick = TICK_MINUTES minutos de jogo.
## Proporção tempo real/tempo de jogo é decisão aberta (§20.7) — fica na Apresentação.

const SCHEMA_VERSION := 1

var tick_minutes: int = 10
var minutes_per_hour: int = 60
var hours_per_day: int = 24
var days_per_month: int = 30   # PLACEHOLDER: calendário de Arton a verificar no Livro Básico
var months_per_year: int = 12

var tick: int = 0
## Eventos agendados: Array de {at_tick:int, key:String, data:Dictionary}
var _scheduled: Array[Dictionary] = []


func advance(n_ticks: int = 1) -> Array[Dictionary]:
	## Avança n ticks e devolve os agendamentos vencidos, em ordem estável.
	assert(n_ticks >= 0, "WorldClock não volta no tempo")
	tick += n_ticks
	var due: Array[Dictionary] = []
	var keep: Array[Dictionary] = []
	for s in _scheduled:
		if int(s.at_tick) <= tick:
			due.append(s)
		else:
			keep.append(s)
	_scheduled = keep
	due.sort_custom(func(a, b): return a.at_tick < b.at_tick or (a.at_tick == b.at_tick and a.key < b.key))
	return due


func schedule(at_tick: int, key: String, data: Dictionary = {}) -> void:
	_scheduled.append({"at_tick": at_tick, "key": key, "data": data})


func total_minutes() -> int:
	return tick * tick_minutes


func calendar() -> Dictionary:
	var m := total_minutes()
	var minute := m % minutes_per_hour
	var hours_total := m / minutes_per_hour
	var hour := hours_total % hours_per_day
	var days_total := hours_total / hours_per_day
	var day := days_total % days_per_month
	var months_total := days_total / days_per_month
	return {
		"year": months_total / months_per_year + 1,
		"month": months_total % months_per_year + 1,
		"day": day + 1, "hour": hour, "minute": minute,
	}


func day_fraction() -> float:
	## 0.0 = meia-noite, 0.5 = meio-dia. Usado pela Apresentação para luz.
	var c := calendar()
	return (c.hour * minutes_per_hour + c.minute) / float(minutes_per_hour * hours_per_day)


func to_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "tick": tick, "tick_minutes": tick_minutes, "scheduled": _scheduled.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	tick = int(d.get("tick", 0))
	tick_minutes = int(d.get("tick_minutes", tick_minutes))
	_scheduled.clear()
	for s in d.get("scheduled", []):
		_scheduled.append({"at_tick": int(s.at_tick), "key": str(s.key), "data": s.get("data", {})})
