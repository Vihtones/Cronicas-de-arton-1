class_name EventBus
extends RefCounted
## Barramento de eventos sem dependência de Node.
## - Listeners recebem GameEvent; exceções/erros de um não impedem os demais.
## - Deduplicação por event_id: o mesmo evento nunca é entregue duas vezes.

const DEDUP_WINDOW := 4096

var _listeners: Dictionary = {}  # event_type -> Array[Callable]; "*" = todos
var _seen_ids: Dictionary = {}
var _seen_order: Array[String] = []
var _next_seq: int = 0


func subscribe(event_type: String, listener: Callable) -> void:
	if not _listeners.has(event_type):
		_listeners[event_type] = []
	if not _listeners[event_type].has(listener):
		_listeners[event_type].append(listener)


func unsubscribe(event_type: String, listener: Callable) -> void:
	if _listeners.has(event_type):
		_listeners[event_type].erase(listener)


## Gera IDs estáveis e determinísticos (não dependem de relógio do SO).
func next_event_id(prefix: String = "evt") -> String:
	_next_seq += 1
	return "%s_%08d" % [prefix, _next_seq]


## Retorna false se o evento já havia sido publicado (duplicado).
func publish(event: GameEvent) -> bool:
	if _seen_ids.has(event.event_id):
		return false
	_seen_ids[event.event_id] = true
	_seen_order.append(event.event_id)
	if _seen_order.size() > DEDUP_WINDOW:
		_seen_ids.erase(_seen_order.pop_front())
	for key in [event.event_type, "*"]:
		if not _listeners.has(key):
			continue
		for l: Callable in _listeners[key].duplicate():
			if l.is_valid():
				l.call(event)
	return true


func get_state() -> Dictionary:
	return {"next_seq": _next_seq}


func set_state(s: Dictionary) -> void:
	_next_seq = int(s.get("next_seq", 0))
