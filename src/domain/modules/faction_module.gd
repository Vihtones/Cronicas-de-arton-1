class_name FactionModule
extends WorldModule
## Facções com objetivos, recursos e reações causais (§11). Tudo ORIGINAL_DO_JOGO.
## - Garras de Cinza partem no dia limite (agendado no início), levando o cativo.
## - Denunciar à Guarda com evidências agenda uma incursão (resolvida em L2).

var resources: Dictionary = {}
var scheduled: bool = false
var raid_pending: bool = false
var relocated: bool = false
var alert_level: int = 0


func module_id() -> String: return "factions"
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(["SCHEDULED_BANDITS_RELOCATE", "SCHEDULED_GUARD_RAID", "REPORT_TO_GUARD", "COMBAT_ENDED", "CREATURE_DEFEATED", "TIME_ADVANCED"])


func _ensure() -> void:
	if scheduled:
		return
	scheduled = true
	for f in world.db.npcs.get("factions", []):
		resources[f.id] = f.resources.duplicate()
		if f.has("relocate_day"):
			world.clock.schedule(int(f.relocate_day) * _ticks_per_day(), "BANDITS_RELOCATE", {"faction": f.id})


func _ticks_per_day() -> int:
	return 24 * 60 / world.clock.tick_minutes


func on_tick(_tick: int) -> Array:
	_ensure()
	return []


func bandits_alive() -> Array:
	var c = world.module("combat")
	if c == null:
		return []
	return c.creatures_of_faction("garras_de_cinza", true)


func on_event(e: GameEvent) -> Array:
	_ensure()
	match e.event_type:
		"REPORT_TO_GUARD":
			if raid_pending or relocated:
				return []
			raid_pending = true
			world.clock.schedule(world.clock.tick + _ticks_per_day() / 2, "GUARD_RAID", {})
			return [fact("GUARD_RAID_PLANNED", {"eta_ticks": _ticks_per_day() / 2})]
		"SCHEDULED_GUARD_RAID":
			raid_pending = false
			return _resolve_raid()
		"SCHEDULED_BANDITS_RELOCATE":
			return _relocate()
		"COMBAT_ENDED":
			if e.payload.get("outcome", "") == "fuga" and e.payload.get("enemy_faction", "") == "garras_de_cinza" and not relocated:
				alert_level += 1
				world.clock.schedule(world.clock.tick + _ticks_per_day(), "BANDITS_RELOCATE", {"faction": "garras_de_cinza", "reason": "alerta"})
				return [fact("FACTION_ALERTED", {"faction": "garras_de_cinza", "reason": "o forasteiro fugiu e sabe do esconderijo"})]
	return []


func _relocate() -> Array:
	if relocated:
		return []
	var alive := bandits_alive()
	var kael_alive := alive.has("kael")
	if not kael_alive:
		return []  # sem o líder, o bando não organiza a partida
	relocated = true
	return [fact("BANDITS_RELOCATED", {"faction": "garras_de_cinza", "members": alive})]


## Resolução L2: sem simular golpe a golpe; probabilidade pela força relativa.
func _resolve_raid() -> Array:
	var alive := bandits_alive()
	var witnesses := ["elsa", "rurik", "tobias"]
	if alive.is_empty() or relocated:
		return [fact("GUARD_RAID_RESOLVED", {"result": "vazio", "witnesses": witnesses})]
	var guards := int(resources.get("guarda_vila", {}).get("soldados", 3))
	var p := clampf(0.5 + 0.15 * (guards - alive.size()), 0.1, 0.95)
	var roll := world.rng.stream("world").randf()
	var out: Array = []
	if roll < p:
		for id in alive:
			out.append(fact("CREATURE_DEFEATED", {"creature": id, "name": world.db.creature_def(id).name, "by": "guarda_vila", "actor": "guarda_vila", "witnesses": witnesses}))
		var npcs = world.module("npcs")
		if npcs != null and npcs.npc("tomas").get("captive", false):
			out.append(fact("NPC_RESCUED", {"npc": "tomas", "location": "cripta_cela", "rescuer": "guarda_vila", "witnesses": witnesses + ["tomas"]}))
		out.append(fact("DIZIMO_RETURNED", {"actor": "guarda_vila", "location": "templo", "witnesses": ["ysolde", "lucan"]}))
		out.append(fact("GUARD_RAID_RESOLVED", {"result": "sucesso", "p": p, "roll": roll, "witnesses": witnesses}))
	else:
		out.append(fact("NPC_WOUNDED", {"npc": "tobias", "ticks": _ticks_per_day() * 5}))
		out.append(fact("GUARD_RAID_RESOLVED", {"result": "fracasso", "p": p, "roll": roll, "witnesses": witnesses}))
		world.clock.schedule(world.clock.tick + _ticks_per_day(), "BANDITS_RELOCATE", {"faction": "garras_de_cinza", "reason": "incursão"})
	return out


func to_dict() -> Dictionary:
	return {"resources": resources.duplicate(true), "scheduled": scheduled, "raid_pending": raid_pending, "relocated": relocated, "alert": alert_level}


func from_dict(d: Dictionary) -> void:
	resources = d.get("resources", {}).duplicate(true)
	scheduled = bool(d.get("scheduled", false))
	raid_pending = bool(d.get("raid_pending", false))
	relocated = bool(d.get("relocated", false))
	alert_level = int(d.get("alert", 0))
