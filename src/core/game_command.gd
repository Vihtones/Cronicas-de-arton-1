class_name GameCommand
extends RefCounted
## Pedido de mudança de estado (Plano Mestre §6). Validado antes de aplicar.

var command_id: String
var actor_id: String
var type: String
var payload: Dictionary
var expected_world_revision: int = -1  # -1 = não verificar


static func create(p_id: String, p_actor: String, p_type: String, p_payload: Dictionary = {}, p_rev: int = -1) -> GameCommand:
	var c := GameCommand.new()
	c.command_id = p_id
	c.actor_id = p_actor
	c.type = p_type
	c.payload = p_payload
	c.expected_world_revision = p_rev
	return c


class Result:
	extends RefCounted
	var accepted: bool = false
	var errors: PackedStringArray = PackedStringArray()
	var emitted_events: Array[GameEvent] = []
	var new_revision: int = -1

	static func rejected(errs: PackedStringArray, rev: int) -> Result:
		var r := Result.new()
		r.errors = errs
		r.new_revision = rev
		return r
