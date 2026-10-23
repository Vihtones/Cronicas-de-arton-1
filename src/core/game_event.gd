class_name GameEvent
extends RefCounted
## Fato consumado e imutável (Plano Mestre §6). Nunca é um pedido de ação.

const SCHEMA_VERSION := 1

var event_id: String
var event_type: String
var schema_version: int = SCHEMA_VERSION
var world_tick: int
var region_id: String
var source_command_id: String
var actor_ids: PackedStringArray
var payload: Dictionary


static func create(p_id: String, p_type: String, p_tick: int, p_payload: Dictionary = {},
		p_region: String = "", p_source_cmd: String = "", p_actors: PackedStringArray = PackedStringArray()) -> GameEvent:
	var e := GameEvent.new()
	e.event_id = p_id
	e.event_type = p_type
	e.world_tick = p_tick
	e.payload = p_payload.duplicate(true)
	e.payload.make_read_only()
	e.region_id = p_region
	e.source_command_id = p_source_cmd
	e.actor_ids = p_actors
	return e


func to_dict() -> Dictionary:
	return {
		"event_id": event_id, "event_type": event_type, "schema_version": schema_version,
		"world_tick": world_tick, "region_id": region_id, "source_command_id": source_command_id,
		"actor_ids": Array(actor_ids), "payload": payload.duplicate(true),
	}
