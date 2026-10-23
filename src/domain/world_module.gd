class_name WorldModule
extends RefCounted
## Contrato de módulo (§5): interface, eventos, versão de esquema, desativação.
## - validate() NÃO altera estado. execute() só é chamado se validate() não retornou erros.
## - execute()/on_tick()/on_event() retornam fatos como [{type, payload, actors?}].
## - on_event deve ser idempotente (o EventBus já deduplica por event_id).

## Referência fraca ao mundo: evita ciclo mundo<->módulo (vazamento de RefCounted).
var _world_ref: WeakRef
var world: WorldState:
	get: return _world_ref.get_ref() if _world_ref != null else null
	set(v): _world_ref = weakref(v) if v != null else null
var enabled: bool = true


func module_id() -> String: return "base"
func schema_version() -> int: return 1
func essential() -> bool: return false
func handled_commands() -> PackedStringArray: return PackedStringArray()
func subscribed_events() -> PackedStringArray: return PackedStringArray()

func validate(_cmd: GameCommand) -> PackedStringArray: return PackedStringArray()
func execute(_cmd: GameCommand) -> Array: return []
func on_tick(_tick: int) -> Array: return []
func on_event(_e: GameEvent) -> Array: return []

func to_dict() -> Dictionary: return {}
func from_dict(_d: Dictionary) -> void: pass


static func fact(type: String, payload: Dictionary = {}, actors: Array = []) -> Dictionary:
	return {"type": type, "payload": payload, "actors": actors}
