class_name TownEventsModule
extends WorldModule
## Eventos da vila (mundo vivo): feira semanal e festa da vila. ORIGINAL_DO_JOGO (não é regra de T20).
## - Feira: a cada 7 dias, das 7h às 17h. Mascates trazem mercadoria (estoque sobe); comerciantes,
##   artesãos e viajantes vão ao mercado; a praça enche.
## - Festa de Alvorada: a cada 14 dias, das 17h à meia-noite. Quase toda a vila vai à praça; guardas
##   continuam no posto; crianças pequenas e feridos ficam em casa. Consome bebida e comida.
## Chuva forte adia a festa (fica "suspensa" enquanto chover) — a feira acontece com menos gente.
## O módulo só decide QUANDO e QUEM; a apresentação decide como mostrar (barracas, bandeirolas, multidão).

const EVENTS := {
	"feira": {"name": "Dia de Feira", "every_days": 7, "offset": 1, "from": 7, "to": 17,
		"goods": {"comida": 30, "ferramentas": 8, "remedio": 4}, "place": "mercado"},
	"festa": {"name": "Festa de Alvorada", "every_days": 14, "offset": 4, "from": 17, "to": 24,
		"goods": {"bebida": -25, "comida": -15}, "place": "praca", "rain_cancels": true},
}
## Agendas que a feira redireciona (o resto do dia segue a agenda normal).
const FAIR_GOERS := {"artesao": "mercado", "viajante": "mercado", "comerciante": "mercado", "idoso": "praca", "crianca": "praca"}
const FESTIVAL_KEEPS := ["guarda_dia", "guarda_noite"]   # guardas não largam o posto

var active: Dictionary = {}     # id -> tick de início


func module_id() -> String: return "town_events"


func is_active(id: String) -> bool:
	return enabled and active.has(id)


func active_ids() -> Array:
	return active.keys() if enabled else []


## Evento que deveria estar ocorrendo agora (antes de checar clima).
func _scheduled_now(id: String) -> bool:
	var e: Dictionary = EVENTS[id]
	var h := world.hour()
	return world.day_index() % int(e.every_days) == int(e.offset) and h >= int(e.from) and h < int(e.to)


## Dias até a próxima ocorrência (0 = hoje, ainda por vir ou acontecendo).
func days_until(id: String) -> int:
	var e: Dictionary = EVENTS[id]
	var d := world.day_index()
	var every := int(e.every_days)
	var diff := (int(e.offset) - d % every + every) % every
	if diff == 0 and world.hour() >= int(e.to):
		diff = every
	return diff


func next_event() -> Dictionary:
	var best := {}
	for id in EVENTS:
		var d := days_until(id)
		if best.is_empty() or d < int(best.days):
			best = {"id": id, "name": EVENTS[id].name, "days": d, "from": EVENTS[id].from}
	return best


func on_tick(tick: int) -> Array:
	if tick % (60 / world.clock.tick_minutes) != 0:
		return []
	var out: Array = []
	var w = world.module("weather")
	var raining: bool = w != null and w.region.condition == "tempestade"
	for id in EVENTS:
		var e: Dictionary = EVENTS[id]
		var want: bool = _scheduled_now(id) and not (e.get("rain_cancels", false) and raining)
		if want and not active.has(id):
			active[id] = tick
			out.append(fact("TOWN_EVENT_STARTED", {"event": id, "name": e.name, "place": e.place, "goods": e.get("goods", {})}))
		elif not want and active.has(id):
			active.erase(id)
			var why := "tempestade" if _scheduled_now(id) else "fim"
			out.append(fact("TOWN_EVENT_ENDED", {"event": id, "name": e.name, "reason": why}))
	return out


## Para onde um NPC vai durante um evento ("" = segue a agenda). Consultado pelo NpcModule.
func location_override(id: String, d: Dictionary, age: int) -> String:
	if not enabled or active.is_empty():
		return ""
	var sched := str(d.get("schedule", ""))
	if active.has("festa") and not FESTIVAL_KEEPS.has(sched) and age >= 6:
		return "praca"
	if active.has("feira") and FAIR_GOERS.has(sched):
		return FAIR_GOERS[sched]
	return ""


func to_dict() -> Dictionary: return {"active": active.duplicate()}
func from_dict(d: Dictionary) -> void:
	active = {}
	for k in d.get("active", {}):
		active[k] = int(d.active[k])
