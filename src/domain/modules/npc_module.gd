class_name NpcModule
extends WorldModule
## NPCs com agenda (LOD L1): local muda por hora segundo rotina, clima e estado.
## Invariantes: morto não executa tarefas; NPC nunca está em dois lugares (§7).

var state: Dictionary = {}  # id -> {location, alive, captive, age, wounded_until}


func module_id() -> String: return "npcs"
func handled_commands() -> PackedStringArray: return PackedStringArray(["RescueNPC"])
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(["NPC_RESCUED", "BANDITS_RELOCATED", "NPC_WOUNDED", "NPC_CAPTURED", "NPC_DIED", "NPC_BORN"])


func _ensure() -> void:
	if not state.is_empty():
		return
	for id in world.all_npc_ids():
		var d := world.npc_def(id)
		state[id] = {"location": d.home, "alive": true, "captive": false, "age": int(d.age), "wounded_until": -1}
	if state.has("tomas"):
		state.tomas.captive = true
		state.tomas.location = "cripta_cela"
	for id in state:
		state[id].location = desired_location(id)


func npc(id: String) -> Dictionary:
	_ensure()
	return state.get(id, {})


func is_present(id: String) -> bool:
	var s := npc(id)
	return not s.is_empty() and s.alive and s.location != "" and s.location != "desconhecido"


func npcs_at(loc_id: String) -> Array:
	_ensure()
	var out: Array = []
	for id in state:
		if state[id].alive and state[id].location == loc_id:
			out.append(id)
	out.sort()
	return out


## Tile onde o NPC está (spot do local + deslocamento estável para não empilhar).
func npc_tile(id: String) -> Vector2i:
	var s := npc(id)
	var spot := world.db.location_spot(s.get("location", ""))
	if spot.x < 0:
		return spot
	var others := npcs_at(s.location)
	var idx := others.find(id)
	var offsets := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	var cand: Vector2i = spot + offsets[idx % offsets.size()] * (1 + idx / offsets.size())
	return cand if world.db.static_walkable(cand) else spot


func desired_location(id: String) -> String:
	var s: Dictionary = state[id]
	var d := world.npc_def(id)
	if not s.alive:
		return ""
	if s.captive:
		return s.location
	if int(s.wounded_until) > world.clock.tick:
		return d.home
	if int(s.get("age", 99)) < 6:
		return d.home   # C7: crianças pequenas ficam em casa
	# necessidades (Arton Viva, Fase 1): fome e cansaço viram objetivo e mudam o caminho
	var needs = world.module("npc_needs")
	if needs != null:
		var goal_loc: String = needs.location_override(id, d)
		if goal_loc != "":
			return goal_loc
	# medo: quem presenciou violência se recolhe até acalmar (guardas ficam)
	var life = world.module("npc_life")
	if life != null:
		var scared: String = life.location_override(id, d, int(s.get("age", 99)))
		if scared != "":
			return scared
	# mensageiro entre regiões (LOD L3)
	for r in world.db.distant.get("regions", []):
		if r.get("courier", "") == id:
			var cycle := int(r.courier_cycle_days)
			if world.day_index() % cycle >= int(r.courier_present_days):
				return r.id
	var sched: Array = _schedule_table(d.schedule)
	var h := world.hour()
	var result: String = d.home
	for entry in sched:
		if h >= int(entry[0]) and h < int(entry[1]):
			if entry.size() > 3 and world.day_index() % int(entry[3]) != 0:
				continue
			result = _resolve_slot(str(entry[2]), d)
	var te = world.module("town_events")
	if te != null:
		var ov: String = te.location_override(id, d, int(s.get("age", 99)))
		if ov != "":
			if te.is_active("festa"):
				return ov   # a festa segue sob chuva fraca (tempestade a suspende)
			result = ov
	var w = world.module("weather")
	if w != null and w.is_raining() and not bool(world.db.location(result).get("indoor", false)) and result != d.home:
		var alt: String = d.work if bool(world.db.location(d.work).get("indoor", false)) else d.home
		result = alt  # ORIGINAL_DO_JOGO: chuva leva trabalhadores para dentro
	return result


func _resolve_slot(slot: String, d: Dictionary) -> String:
	match slot:
		"home": return d.home
		"work": return d.work
		_: return slot


## Tabela de agendas embutida no catálogo de NPCs (gerada por build_content.py).
func _schedule_table(name: String) -> Array:
	return world.db.npcs.get("schedule_templates", {}).get(name, [[0, 24, "home"]])


func on_tick(tick: int) -> Array:
	_ensure()
	var out: Array = []
	if tick % (60 / world.clock.tick_minutes) != 0:
		return out  # reavalia agendas de hora em hora
	for id in state:
		var to := desired_location(id)
		if to != state[id].location:
			var from: String = state[id].location
			state[id].location = to
			out.append(fact("NPC_MOVED", {"npc": id, "from": from, "to": to}, [id]))
	# envelhecimento anual (aniversário simplificado no 1º dia do ano)
	var c := world.clock.calendar()
	if c.month == 1 and c.day == 1 and c.hour == 0 and c.minute == 0 and tick > 0:
		for id in state:
			if state[id].alive:
				state[id].age += 1
	return out


func validate(cmd: GameCommand) -> PackedStringArray:
	_ensure()
	var id: String = cmd.payload.get("npc_id", "")
	var s := npc(id)
	if s.is_empty(): return PackedStringArray(["NPC inexistente"])
	if not s.alive: return PackedStringArray(["%s está morto" % world.npc_def(id).name])
	if not s.captive: return PackedStringArray(["%s não está preso" % world.npc_def(id).name])
	var t := npc_tile(id)
	var p := world.db.world_to_tile(world.player.position)
	if absi(p.x - t.x) > 1 or absi(p.y - t.y) > 1:
		return PackedStringArray(["longe demais"])
	var combat = world.module("combat")
	if combat != null and combat.active:
		return PackedStringArray(["ainda em combate"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	var id: String = cmd.payload.npc_id
	var loc: String = state[id].location
	# testemunhas capturadas no instante do fato (antes de alguém se mover)
	return [fact("NPC_RESCUED", {"npc": id, "location": loc, "rescuer": "player", "witnesses": npcs_at(loc)}, ["player", id])]


func on_event(e: GameEvent) -> Array:
	_ensure()
	match e.event_type:
		"NPC_BORN":
			var nid: String = e.payload.id
			if not state.has(nid):
				state[nid] = {"location": str(e.payload.location), "alive": true, "captive": false, "age": 0, "wounded_until": -1}
			return []
		"NPC_RESCUED":
			var id: String = e.payload.npc
			if state.has(id) and state[id].captive:
				state[id].captive = false
				state[id].location = world.npc_def(id).home
				state[id].wounded_until = world.clock.tick + 6 * 24 * 2
		"BANDITS_RELOCATED":
			for id in state:
				if state[id].captive and state[id].alive:
					state[id].location = "desconhecido"
		"NPC_DIED":
			var id: String = e.payload.npc
			if state.has(id):
				state[id].alive = false
				state[id].location = ""
		"NPC_WOUNDED":
			var id: String = e.payload.npc
			if state.has(id):
				state[id].wounded_until = world.clock.tick + int(e.payload.get("ticks", 144))
		"NPC_CAPTURED":
			var id: String = e.payload.npc
			if state.has(id):
				state[id].captive = true
				state[id].location = e.payload.location
	return []


func to_dict() -> Dictionary:
	_ensure()
	return {"state": state.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	state = d.get("state", {}).duplicate(true)
	for id in state:
		state[id].age = int(state[id].age)
		state[id].wounded_until = int(state[id].wounded_until)
