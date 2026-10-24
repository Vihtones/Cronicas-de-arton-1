class_name CrimeModule
extends WorldModule
## Crime (§11): ato real, evidência, testemunhas, conhecimento das autoridades,
## lei local, mandado, multa e resolução. Ilegal != condenado por todos.
## A autoridade só sabe quando um membro da Guarda tem a memória do crime.

var records: Array[Dictionary] = []
var _seq := 0


func module_id() -> String: return "crime"
func handled_commands() -> PackedStringArray: return PackedStringArray(["StealFromStall", "PayFine"])
func subscribed_events() -> PackedStringArray: return PackedStringArray(["OBJECT_BROKEN"])


func law(act: String) -> Dictionary:
	return world.db.laws.get("vila", {}).get(act, {})


func open_warrant() -> Dictionary:
	for r in records:
		if r.known_by_authority and not r.resolved:
			return r
	return {}


func total_fines() -> int:
	var t := 0
	for r in records:
		if r.known_by_authority and not r.resolved:
			t += int(r.fine)
	return t


func validate(cmd: GameCommand) -> PackedStringArray:
	match cmd.type:
		"StealFromStall":
			var npc: String = cmd.payload.get("owner", "")
			var shops: Dictionary = world.db.economy.get("shops", {})
			if not shops.has(npc): return PackedStringArray(["nada para pegar"])
			var item: String = cmd.payload.get("item", "")
			if not shops[npc].has(item): return PackedStringArray(["item não está à venda aqui"])
			var loc := world.db.location_at(world.db.world_to_tile(world.player.position))
			if loc != world.db.npc_def(npc).work: return PackedStringArray(["a barraca não está aqui"])
		"PayFine":
			var fines := total_fines()
			if fines <= 0: return PackedStringArray(["nenhuma multa pendente"])
			if int(world.player.gold) < fines: return PackedStringArray(["ouro insuficiente (T$ %d)" % fines])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	match cmd.type:
		"StealFromStall":
			var npc: String = cmd.payload.owner
			var item: String = cmd.payload.item
			var loc := world.db.location_at(world.db.world_to_tile(world.player.position))
			var npcs = world.module("npcs")
			var present: Array = npcs.npcs_at(loc) if npcs != null else []
			# Furtividade do jogador contra Percepção de cada presente (teste oposto).
			var mine := Checks.skill(world.player_sheet, "furtividade", 0, world.rules, world.rng, "world")
			var witnesses: Array = []
			for w in present:
				var theirs: int = world.rng.roll("world", 1, 20)[0] + 1  # PLACEHOLDER: plebeus sem ficha, Percepção +1
				if theirs >= int(mine.total):
					witnesses.append(w)
			return [fact("ITEM_GAINED", {"item": item, "from": npc}, ["player"])] + _record("furto", npc, loc, witnesses, {"item": item, "check": mine})
		"PayFine":
			var out: Array = [fact("GOLD_CHANGED", {"delta": -total_fines(), "reason": "multa"})]
			for r in records:
				if r.known_by_authority and not r.resolved:
					r.resolved = true
					out.append(fact("FINE_PAID", {"crime_id": r.id, "actor": "player", "location": world.db.location_at(world.db.world_to_tile(world.player.position))}, ["player"]))
			return out
	return []


func _record(act: String, victim: String, loc: String, witnesses: Array, extra: Dictionary) -> Array:
	_seq += 1
	var l := law(act)
	var rec := {"id": "crime_%d" % _seq, "act": act, "actor": "player", "victim": victim, "location": loc, "tick": world.clock.tick,
		"witnesses": witnesses.duplicate(), "evidence": ["item_faltando"] if act == "furto" else ["dano_visivel"],
		"known_by_authority": false, "fine": int(l.get("multa", 0)), "resolved": false, "law_status": world.db.laws.get("status", ""),
		"near": _near_npcs(loc), "investigation": 0}
	records.append(rec)
	var p := {"crime_id": rec.id, "crime": act, "actor": "player", "victim": victim, "location": loc, "witnesses": witnesses}
	p.merge(extra)
	return [fact("CRIME_COMMITTED", p, ["player"])]


func on_event(e: GameEvent) -> Array:
	if e.event_type == "OBJECT_BROKEN" and world.db.zone_at(world.db.world_to_tile(world.player.position)) == "vila":
		var owner_loc: String = e.payload.get("location", "")
		if owner_loc != "":
			var npcs = world.module("npcs")
			var present: Array = npcs.npcs_at(owner_loc) if npcs != null else []
			return _record("dano_propriedade", "", owner_loc, present, {"object": e.payload.object})
	return []


## Quem estava na mesma zona, fora do local, pode ter visto o forasteiro passar (evidência indireta).
func _near_npcs(loc: String) -> Array:
	var npcs = world.module("npcs")
	if npcs == null: return []
	var zone: String = world.db.location(loc).get("zone", "")
	var out: Array = []
	for id in npcs.state:
		var l: String = npcs.state[id].location
		if l != loc and l != "" and world.db.location(l).get("zone", "") == zone and npcs.state[id].alive:
			out.append(id)
	return out


## Investigação diária (ORIGINAL): a Guarda que sabe de um crime sem autor tenta
## identificá-lo. Teste de Investigação da capitã (PLACEHOLDER +4) contra CD 20 − 1 por pista.
func _investigate() -> Array:
	var mem = world.module("memory")
	var out: Array = []
	for r in records:
		if r.known_by_authority or r.resolved or not r.witnesses.is_empty():
			continue
		var guard_knows := false
		for g in ["elsa", "rurik", "tobias"]:
			if mem.list(g).any(func(m): return str(m.key) == "crime:desconhecido:" + str(r.id)):
				guard_knows = true
		if not guard_knows:
			continue
		var cd := 20 - mini(10, r.near.size())
		var roll: int = world.rng.roll("world", 1, 20)[0] + 4
		r.investigation = int(r.investigation) + 1
		out.append(fact("CRIME_INVESTIGATED", {"crime_id": r.id, "roll": roll, "cd": cd, "success": roll >= cd, "day": r.investigation}))
		if roll >= cd:
			r.known_by_authority = true
			out.append(fact("WARRANT_ISSUED", {"crime_id": r.id, "crime": r.act, "fine": r.fine, "by": "investigacao"}))
	return out


## A cada hora: se algum guarda lembra de um crime (testemunha ou rumor), a autoridade sabe.
func on_tick(tick: int) -> Array:
	if tick % (60 / world.clock.tick_minutes) != 0:
		return []
	var mem = world.module("memory")
	if mem == null:
		return []
	var out: Array = []
	if tick % (24 * 60 / world.clock.tick_minutes) == 0:
		out.append_array(_investigate())
	var guards: Array = []
	for n in world.db.npcs.get("npcs", []):
		if n.get("faction", "") == "guarda_vila":
			guards.append(n.id)
	for r in records:
		if r.known_by_authority or r.resolved:
			continue
		var key := "crime:player:" + str(r.victim)
		for g in guards:
			if mem.knows_fact(g, key):
				r.known_by_authority = true
				out.append(fact("WARRANT_ISSUED", {"crime_id": r.id, "crime": r.act, "fine": r.fine, "by": g}))
				break
	return out


func to_dict() -> Dictionary: return {"records": records.duplicate(true), "seq": _seq}
func from_dict(d: Dictionary) -> void:
	records.clear()
	for r in d.get("records", []):
		records.append(r)
	_seq = int(d.get("seq", 0))
