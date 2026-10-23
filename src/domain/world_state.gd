class_name WorldState
extends RefCounted
## Estado mutável mínimo da Fase 0. Só muda via apply_command (comandos validados).

const SCHEMA_VERSION := 1
const CONTENT_VERSION := "0.0.1"

var revision: int = 0
var clock := WorldClock.new()
var rng := RngStreams.new(0)
var player := {"id": "player", "position": Vector2.ZERO, "region_id": "vila_inicial"}


func apply_command(cmd: GameCommand, bus: EventBus) -> GameCommand.Result:
	if cmd.expected_world_revision >= 0 and cmd.expected_world_revision != revision:
		return GameCommand.Result.rejected(["revisão desatualizada: esperado %d, atual %d" % [cmd.expected_world_revision, revision]], revision)
	match cmd.type:
		"MovePlayer":
			return _move_player(cmd, bus)
		"AdvanceTime":
			return _advance_time(cmd, bus)
		_:
			return GameCommand.Result.rejected(["comando desconhecido: " + cmd.type], revision)


func _move_player(cmd: GameCommand, bus: EventBus) -> GameCommand.Result:
	var to = cmd.payload.get("to")
	if not (to is Vector2) or not (to as Vector2).is_finite():
		return GameCommand.Result.rejected(["posição inválida"], revision)
	player.position = to
	return _commit(cmd, bus, "PLAYER_MOVED", {"to": [to.x, to.y]})


func _advance_time(cmd: GameCommand, bus: EventBus) -> GameCommand.Result:
	var n := int(cmd.payload.get("ticks", 0))
	if n <= 0:
		return GameCommand.Result.rejected(["ticks deve ser > 0"], revision)
	var due := clock.advance(n)
	var r := _commit(cmd, bus, "TIME_ADVANCED", {"tick": clock.tick, "calendar": clock.calendar()})
	for s in due:
		var e := GameEvent.create(bus.next_event_id(), "SCHEDULED_" + s.key, clock.tick, s.data, player.region_id, cmd.command_id)
		r.emitted_events.append(e)
		bus.publish(e)
	return r


## Um único commit: aumenta revisão e emite o evento do fato consumado.
func _commit(cmd: GameCommand, bus: EventBus, ev_type: String, payload: Dictionary) -> GameCommand.Result:
	revision += 1
	var e := GameEvent.create(bus.next_event_id(), ev_type, clock.tick, payload, player.region_id, cmd.command_id, PackedStringArray([cmd.actor_id]))
	var r := GameCommand.Result.new()
	r.accepted = true
	r.new_revision = revision
	r.emitted_events.append(e)
	bus.publish(e)
	return r


func to_snapshot() -> Dictionary:
	return {
		"world_seed": rng.to_dict().world_seed,
		"world_tick": clock.tick,
		"content_version": CONTENT_VERSION,
		"schema_version": SCHEMA_VERSION,
		"revision": revision,
		"modules": {
			"clock": clock.to_dict(),
			"rng": rng.to_dict(),
			"player": {"id": player.id, "region_id": player.region_id, "position": [player.position.x, player.position.y]},
		},
	}


func from_snapshot(s: Dictionary) -> void:
	revision = int(s.get("revision", 0))
	var m: Dictionary = s.get("modules", {})
	clock.from_dict(m.get("clock", {}))
	rng.from_dict(m.get("rng", {}))
	var p: Dictionary = m.get("player", {})
	var pos: Array = p.get("position", [0, 0])
	player.position = Vector2(float(pos[0]), float(pos[1]))
	player.region_id = str(p.get("region_id", "vila_inicial"))
