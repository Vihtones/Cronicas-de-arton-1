extends Node
## Autoload "Game": composição da aplicação. NÃO concentra regras — só liga
## Domínio (WorldState), Infraestrutura (repositório) e expõe comandos à Apresentação.

signal event_published(event: GameEvent)

var logger := GameLogger.new()
var bus := EventBus.new()
var world := WorldState.new()
var saves := JsonSaveRepository.new()
var _cmd_seq := 0

## Segundos reais por tick. PLACEHOLDER: decisão aberta §20.7 (definir em playtest).
@export var seconds_per_tick: float = 1.0
var _accum := 0.0


func _ready() -> void:
	world.rng.reseed(20261023)
	bus.subscribe("*", func(e: GameEvent): event_published.emit(e))
	logger.info("Game", "boot", {"content_version": WorldState.CONTENT_VERSION})


func _process(delta: float) -> void:
	# Render usa delta; simulação avança em passos fixos.
	_accum += delta
	while _accum >= seconds_per_tick:
		_accum -= seconds_per_tick
		send("AdvanceTime", {"ticks": 1})


func send(type: String, payload: Dictionary = {}, actor: String = "player") -> GameCommand.Result:
	_cmd_seq += 1
	var cmd := GameCommand.create("cmd_%08d" % _cmd_seq, actor, type, payload)
	var r := world.apply_command(cmd, bus)
	if not r.accepted:
		logger.warn("Game", "comando rejeitado", {"type": type, "errors": Array(r.errors)})
	return r


func save_game(slot: String = "quicksave") -> Error:
	var snap := world.to_snapshot()
	snap["modules"]["event_bus"] = bus.get_state()
	snap["modules"]["app"] = {"cmd_seq": _cmd_seq}
	var err := saves.save(slot, snap)
	logger.info("Persistence", "save", {"slot": slot, "ok": err == OK})
	return err


func load_game(slot: String = "quicksave") -> bool:
	var res := saves.load_slot(slot)
	if res.is_empty():
		logger.warn("Persistence", "nenhum save válido", {"slot": slot})
		return false
	world.from_snapshot(res.data)
	bus.set_state(res.data.modules.get("event_bus", {}))
	_cmd_seq = int(res.data.modules.get("app", {}).get("cmd_seq", 0))
	logger.info("Persistence", "load", {"slot": slot, "backup": res.recovered_from_backup})
	return true
