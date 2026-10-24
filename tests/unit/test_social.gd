extends TestCase


func _rescue(w: WorldState) -> void:
	w.modules.objects.state.porta_cela.open = true
	w.modules.objects.state.porta_cela.locked = false
	var t: Vector2i = w.modules.npcs.npc_tile("tomas")
	WorldHelpers.put(w, t.x - 1, t.y)
	WorldHelpers.cmd(w, "RescueNPC", {"npc_id": "tomas"})


func test_reputacao_nao_sobe_se_ninguem_sabe() -> void:
	var w := WorldHelpers.world(21)
	var mem: MemoryModule = w.modules.memory
	eq(mem.settlement_reputation().known_by, 0, "ninguém conhece o jogador")
	_rescue(w)
	var rep := mem.settlement_reputation()
	eq(rep.known_by, 1, "só Tomas testemunhou")
	check(mem.reputation("tomas") > 0, "Tomas grato")
	eq(mem.reputation("mara"), 0.0, "mercadora não sabe")
	eq(mem.reputation("garrick"), -10.0, "ferreiro desconfia de estranhos (viés individual, não regra de raça)")


func test_rumor_espalha_com_o_tempo_e_preserva_causalidade() -> void:
	var w := WorldHelpers.world(21)
	var mem: MemoryModule = w.modules.memory
	_rescue(w)
	WorldHelpers.advance_hours(w, 24 * 4)
	var rep := mem.settlement_reputation()
	check(rep.known_by > 1, "outros souberam por rumor (%d)" % rep.known_by)
	for n in w.db.npcs.npcs:
		for m in mem.list(n.id):
			if m.key.begins_with("resgatou:player"):
				check(m.source == "testemunha" or str(m.source).begins_with("rumor:"), "toda crença tem origem")
				if str(m.source).begins_with("rumor:"):
					check(float(m.reliability) < 1.0, "rumor perde confiabilidade")


func test_rumor_nao_teleporta() -> void:
	var w := WorldHelpers.world(4)
	var mem: MemoryModule = w.modules.memory
	var npcs: NpcModule = w.modules.npcs
	mem.add_memory("garrick", {"key": "teste:x", "about": "player", "subject": "", "valence": 10, "location": "ferraria",
		"tick": 0, "emotion": "", "reliability": 1.0, "source": "testemunha", "durable": true, "text": "teste"})
	for h in 30:
		var before := {}
		for id in npcs.state: before[id] = npcs.state[id].location
		var r := WorldHelpers.advance_hours(w, 1)
		for e in WorldHelpers.events_of(r, "RUMOR_SPREAD"):
			eq(npcs.state[e.payload.from].location, npcs.state[e.payload.to].location, "mesmo local ao espalhar")


func test_npc_nunca_em_dois_lugares_e_morto_nao_age() -> void:
	var w := WorldHelpers.world(4)
	var npcs: NpcModule = w.modules.npcs
	npcs.state.garrick.alive = false
	for h in 30:
		WorldHelpers.advance_hours(w, 1)
		var seen := {}
		for loc in w.db.all_locations():
			for id in npcs.npcs_at(loc.id):
				check(not seen.has(id), "%s em dois lugares" % id)
				seen[id] = true
		check(not seen.has("garrick"), "morto não aparece")


func test_agenda_muda_local_por_hora() -> void:
	var w := WorldHelpers.world(4)
	var npcs: NpcModule = w.modules.npcs
	w.modules.weather.enabled = false
	w.clock.tick = 6 * 8 - 1
	WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 1})
	eq(npcs.npc("otto").location, "moinho", "Otto trabalha às 8h")
	WorldHelpers.advance_hours(w, 11)
	eq(npcs.npc("otto").location, "taverna", "Otto na taverna às 19h")


func test_mensageiro_traz_noticias_com_latencia() -> void:
	var w := WorldHelpers.world(8)
	var mem: MemoryModule = w.modules.memory
	var got_news_in_vila := false
	var saw_event := false
	for d in 15:
		var r := WorldHelpers.advance_hours(w, 24)
		if not WorldHelpers.events_of(r, "DISTANT_EVENT").is_empty(): saw_event = true
		for n in w.db.npcs.npcs:
			if n.id == "saria": continue
			if mem.list(n.id).any(func(m): return str(m.key).begins_with("noticia:")):
				got_news_in_vila = true
	check(saw_event, "eventos distantes acontecem")
	check(got_news_in_vila, "notícia chega à vila pela mercadora")


func test_denuncia_agenda_incursao_da_guarda() -> void:
	var w := WorldHelpers.world(30)
	var f: FactionModule = w.modules.factions
	w.modules.exploration.known_facts["f_bandidos_na_ruina"] = {"tick": 0}
	var r := w.apply_command(GameCommand.create("x", "player", "AdvanceTime", {"ticks": 1}))
	# simula efeito de diálogo
	var cmd := GameCommand.create("d", "player", "StartDialogue", {"npc_id": "elsa"})
	var e := GameEvent.create("manual", "REPORT_TO_GUARD", w.clock.tick, {})
	var out := f.on_event(e)
	check(out.any(func(x): return x.type == "GUARD_RAID_PLANNED"), "incursão planejada")
	var r2 := WorldHelpers.advance_hours(w, 13)
	check(not WorldHelpers.events_of(r2, "GUARD_RAID_RESOLVED").is_empty(), "incursão acontece ao amanhecer")
