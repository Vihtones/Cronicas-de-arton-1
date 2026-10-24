class_name WorldHelpers
extends RefCounted
## Utilidades de teste: cria mundo e posiciona o jogador.

static var _rules: RuleRegistry
static var _db: ContentDB


static func world(p_seed: int = 7, disabled: Array = []) -> WorldState:
	if _rules == null:
		_rules = RuleRegistry.load_default()
		_db = ContentDB.load_default()
	return WorldFactory.create(p_seed, disabled, _rules, _db)


static func put(w: WorldState, x: int, y: int) -> void:
	w.player.position = w.db.tile_to_world(Vector2i(x, y))


static func cmd(w: WorldState, type: String, payload: Dictionary = {}) -> GameCommand.Result:
	return w.apply_command(GameCommand.create("t_%d" % w.revision, "player", type, payload))


static func events_of(r: GameCommand.Result, type: String) -> Array:
	return r.emitted_events.filter(func(e): return e.event_type == type)


static func advance_hours(w: WorldState, h: int) -> GameCommand.Result:
	return cmd(w, "AdvanceTime", {"ticks": h * 6})


static func snap(w: WorldState) -> String:
	return norm(w.to_snapshot())


## Texto canônico de um dado: JSON não distingue 1 de 1.0, e a Godot 4.7 escreve 1.0 onde a 4.3
## escrevia 1. Converte todo número para float antes de comparar (mesmo valor = mesmo texto).
static func norm(v: Variant) -> String:
	return JSON.stringify(_floats(JSON.parse_string(JSON.stringify(v))), "", true)


static func _floats(v: Variant) -> Variant:
	if v is Dictionary:
		var d := {}
		for k in v: d[k] = _floats(v[k])
		return d
	if v is Array:
		return (v as Array).map(func(x): return _floats(x))
	if v is int:
		return float(v)
	return v
