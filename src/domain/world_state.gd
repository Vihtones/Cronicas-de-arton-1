class_name WorldState
extends RefCounted
## Estado mutável do mundo. Muda somente via apply_command (comandos validados) e ticks.
## Módulos são registrados; os opcionais podem ser desligados sem impedir o boot (§5).

const SCHEMA_VERSION := 2
const CONTENT_VERSION := "0.7.0"
const MAX_DERIVED_PER_COMMIT := 4096

var revision: int = 0
var clock := WorldClock.new()
var rng := RngStreams.new(0)
var rules: RuleRegistry
var db: ContentDB                     # catálogos estáticos (mapa, NPCs, diálogos, mistérios)
var bus: EventBus
var journal: Array[Dictionary] = []   # journal compacto de eventos relevantes (§14)
const JOURNAL_MAX := 2000
var player := {"id": "player", "position": Vector2.ZERO, "region_id": "regiao_inicial", "gold": 20}
var player_sheet: CharacterSheet
var modules: Dictionary = {}          # id -> WorldModule
var _order: Array[String] = []
var _preserved: Dictionary = {}       # dados de módulos desligados (nunca apagar, §14)
var _current_cmd_id := ""

## Tipos de evento que NÃO vão para o journal (ruído de alta frequência).
const JOURNAL_SKIP := ["PLAYER_MOVED", "TIME_ADVANCED", "NPC_MOVED", "COMBAT_PREVIEW"]


func _init(p_rules: RuleRegistry = null, p_db: ContentDB = null, p_bus: EventBus = null) -> void:
	rules = p_rules if p_rules != null else RuleRegistry.load_default()
	db = p_db if p_db != null else ContentDB.new()
	bus = p_bus if p_bus != null else EventBus.new()
	player_sheet = CharacterSheet.premade_warrior(rules)


func register(m: WorldModule) -> void:
	m.world = self
	modules[m.module_id()] = m
	if not _order.has(m.module_id()):
		_order.append(m.module_id())
	if _preserved.has(m.module_id()):
		m.from_dict(_preserved[m.module_id()])
		_preserved.erase(m.module_id())


func module(id: String) -> WorldModule:
	var m: WorldModule = modules.get(id)
	return m if m != null and m.enabled else null


func set_module_enabled(id: String, on: bool) -> bool:
	var m: WorldModule = modules.get(id)
	if m == null:
		return false
	if not on and m.essential():
		return false  # essenciais exigem substituto, não remoção (§5)
	m.enabled = on
	return true


func apply_command(cmd: GameCommand, _legacy_bus: EventBus = null) -> GameCommand.Result:
	if cmd.expected_world_revision >= 0 and cmd.expected_world_revision != revision:
		return GameCommand.Result.rejected(["revisão desatualizada: esperado %d, atual %d" % [cmd.expected_world_revision, revision]], revision)
	var facts: Array = []
	if player_sheet != null and player_sheet.efeito_bonus("arvore") > 0 and not ["AdvanceTime", "SetXpMode", "SetPolicy", "SetOrder", "SetPowerPolicy"].has(cmd.type):
		return GameCommand.Result.rejected(["você é uma árvore: não pode falar nem fazer ações físicas (Controlar Madeira)"], revision)
	match cmd.type:
		"MovePlayer":
			var to = cmd.payload.get("to")
			if not (to is Vector2) or not (to as Vector2).is_finite():
				return GameCommand.Result.rejected(["posição inválida"], revision)
			player.position = to
			facts.append(WorldModule.fact("PLAYER_MOVED", {"to": [to.x, to.y]}, [cmd.actor_id]))
		"AdvanceTime":
			var n := int(cmd.payload.get("ticks", 0))
			if n <= 0 or n > 60 * 24 * 6:
				return GameCommand.Result.rejected(["ticks deve estar em 1..8640"], revision)
			facts.append_array(_advance(n))
		_:
			var handler := _handler_for(cmd.type)
			if handler == null:
				return GameCommand.Result.rejected(["comando desconhecido ou módulo desligado: " + cmd.type], revision)
			var errs := handler.validate(cmd)
			if not errs.is_empty():
				return GameCommand.Result.rejected(errs, revision)
			facts.append_array(handler.execute(cmd))
	return _commit(cmd, facts)


func _handler_for(type: String) -> WorldModule:
	for id in _order:
		var m: WorldModule = modules[id]
		if m.enabled and m.handled_commands().has(type):
			return m
	return null


## Para módulos que consomem tempo (descanso, viagens). Retorna os fatos do período.
func advance_ticks(n: int) -> Array:
	return _advance(n)


func _advance(n: int) -> Array:
	var facts: Array = []
	for i in n:
		var due := clock.advance(1)
		for s in due:
			facts.append(WorldModule.fact("SCHEDULED_" + s.key, s.data))
		for id in _order:
			var m: WorldModule = modules[id]
			if m.enabled:
				facts.append_array(m.on_tick(clock.tick))
	facts.append(WorldModule.fact("TIME_ADVANCED", {"tick": clock.tick, "calendar": clock.calendar()}))
	return facts


## Um único commit por comando: incrementa revisão, publica fatos e processa derivados.
func _commit(cmd: GameCommand, facts: Array) -> GameCommand.Result:
	revision += 1
	_current_cmd_id = cmd.command_id
	var r := GameCommand.Result.new()
	r.accepted = true
	var queue: Array = facts.duplicate()
	var derived := 0
	var dropped := 0
	while not queue.is_empty():
		var f: Dictionary = queue.pop_front()
		var e := GameEvent.create(bus.next_event_id(), f.type, clock.tick, f.get("payload", {}),
			player.region_id, cmd.command_id, PackedStringArray(f.get("actors", [])))
		r.emitted_events.append(e)
		if not JOURNAL_SKIP.has(e.event_type):
			journal.append(e.to_dict())
			if journal.size() > JOURNAL_MAX:
				journal = journal.slice(journal.size() - JOURNAL_MAX)
		for id in _order:
			var m: WorldModule = modules[id]
			if m.enabled and (m.subscribed_events().has(e.event_type) or m.subscribed_events().has("*")):
				var more: Array = m.on_event(e)
				if derived + more.size() > MAX_DERIVED_PER_COMMIT:
					dropped += more.size()
				else:
					derived += more.size()
					queue.append_array(more)
		bus.publish(e)
	if dropped > 0:
		push_warning("WorldState: limite de eventos derivados atingido (%d descartados)" % dropped)
	r.new_revision = revision
	return r


func to_snapshot() -> Dictionary:
	var mods := {}
	for id in _order:
		mods[id] = modules[id].to_dict()
	for id in _preserved:
		mods[id] = _preserved[id]
	return {
		"world_seed": rng.to_dict().world_seed,
		"world_tick": clock.tick,
		"content_version": CONTENT_VERSION,
		"schema_version": SCHEMA_VERSION,
		"revision": revision,
		"modules": {
			"clock": clock.to_dict(),
			"rng": rng.to_dict(),
			"player": {"id": player.id, "region_id": player.region_id, "position": [player.position.x, player.position.y],
				"gold": player.gold, "sheet": player_sheet.to_dict()},
			"world_modules": mods,
			"journal": journal.duplicate(true),
			"event_bus": bus.get_state(),
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
	player.region_id = str(p.get("region_id", "regiao_inicial"))
	player.gold = int(p.get("gold", 20))
	if p.has("sheet"):
		player_sheet = CharacterSheet.from_dict(p.sheet)
	var mods: Dictionary = m.get("world_modules", {})
	for id in mods:
		if modules.has(id):
			modules[id].from_dict(mods[id])
		else:
			_preserved[id] = mods[id]  # módulo ausente: preserva sem apagar
	if m.has("event_bus"):
		bus.set_state(m.event_bus)
	journal.clear()
	for j in m.get("journal", []):
		journal.append(j)


## NPCs do catálogo + NPCs dinâmicos (nascidos no jogo) e mudanças de casa (casamentos). C7/C8.
func npc_def(id: String) -> Dictionary:
	var d := db.npc_def(id)
	var lin = modules.get("lineage")
	if lin == null:
		return d
	if d.is_empty():
		return lin.dynamic_npcs.get(id, {})
	if lin.home_override.has(id):
		d = d.duplicate()
		d.home = lin.home_override[id]
		if str(d.get("work", "")) == str(db.npc_def(id).home): d.work = d.home
	return d


func all_npc_ids() -> Array:
	var ids: Array = db.all_npc_ids().duplicate()
	var lin = modules.get("lineage")
	if lin != null:
		for id in lin.dynamic_npcs:
			if not ids.has(id): ids.append(id)
	return ids


## Helpers para módulos
func hour() -> int:
	return clock.calendar().hour


func day_index() -> int:
	return clock.total_minutes() / (clock.minutes_per_hour * clock.hours_per_day)
