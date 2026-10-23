extends TestCase
## Crime, economia, clima, fé, diálogo, persistência e módulos opcionais.


func test_furto_com_testemunha_gera_mandado_e_multa_resolve() -> void:
	var w := WorldHelpers.world(17)
	w.modules.weather.enabled = false
	w.clock.tick = 6 * 9
	var npcs: NpcModule = w.modules.npcs
	for id in npcs.state: npcs.state[id].location = npcs.desired_location(id)
	WorldHelpers.put(w, 17, 21)
	var cr: CrimeModule = w.modules.crime
	var r := WorldHelpers.cmd(w, "StealFromStall", {"owner": "mara", "item": "corda"})
	check(r.accepted, "furto executado: %s" % str(r.errors))
	eq(cr.records.size(), 1, "crime registrado")
	check(not cr.records[0].known_by_authority, "autoridade ainda não sabe")
	# força testemunha guarda presente para checar propagação
	w.modules.memory.add_memory("tobias", {"key": "crime:player:mara", "about": "player", "subject": "mara", "valence": -25,
		"location": "mercado", "tick": w.clock.tick, "emotion": "raiva", "reliability": 1.0, "source": "testemunha", "durable": true, "text": "x"})
	var r2 := WorldHelpers.advance_hours(w, 1)
	check(cr.records[0].known_by_authority, "guarda soube => mandado")
	check(not WorldHelpers.events_of(r2, "WARRANT_ISSUED").is_empty(), "evento de mandado")
	w.player.gold = 50
	var r3 := WorldHelpers.cmd(w, "PayFine")
	check(r3.accepted, "pagou")
	check(cr.records[0].resolved, "resolvido")


func test_precos_tem_limites_e_compra_reduz_estoque() -> void:
	var w := WorldHelpers.world()
	var eco: EconomyModule = w.modules.economy
	eco._ensure()
	eco.regions.vila.stock.comida = 1
	check(eco.price("pao") <= 3, "teto de preço")
	eco.regions.vila.stock.comida = 100000
	check(eco.price("pao") >= 1, "piso de preço")


func test_clima_deterministico_e_desligavel() -> void:
	var a := WorldHelpers.world(77)
	var b := WorldHelpers.world(77)
	WorldHelpers.advance_hours(a, 48)
	WorldHelpers.advance_hours(b, 48)
	eq(a.modules.weather.region, b.modules.weather.region, "mesma seed => mesmo clima")
	var c := WorldHelpers.world(77, ["weather"])
	check(c.modules.weather.env_at(Vector2i(23, 27)).is_empty(), "desligado => neutro")
	check(not c.modules.weather.is_raining(), "desligado não chove")


func test_noite_ao_ar_livre_da_camuflagem_leve() -> void:
	var w := WorldHelpers.world()
	w.clock.tick = 6 * 22
	var env: Dictionary = w.modules.weather.env_at(Vector2i(70, 34))
	check(env.darkness, "escuridão leve à noite (LB p.238)")
	check(not w.modules.weather.env_at(Vector2i(29, 55)).darkness, "cripta iluminada")


func test_lena_proibe_dano_letal() -> void:
	var w := WorldHelpers.world()
	var rel: ReligionModule = w.modules.religion
	rel.on_event(GameEvent.create("a", "BECOME_DEVOTEE", 0, {"god": "Lena"}))
	eq(w.player_sheet.devotion, "Lena", "devota")
	var out := rel.on_event(GameEvent.create("b", "LETHAL_DAMAGE_DEALT", 0, {"target": "hiena_1", "creature_type": "animal"}))
	check(out.any(func(f): return f.type == "OBLIGATION_VIOLATED"), "violação registrada (LB p.100)")


func test_dialogo_condicoes_e_teste_com_anti_loop() -> void:
	var w := WorldHelpers.world(3)
	var npcs: NpcModule = w.modules.npcs
	var t: Vector2i = npcs.npc_tile("dorn")
	WorldHelpers.put(w, t.x + 1, t.y)
	var r := WorldHelpers.cmd(w, "StartDialogue", {"npc_id": "dorn"})
	check(r.accepted, "conversa iniciada: %s" % str(r.errors))
	var dlg: DialogueModule = w.modules.dialogue
	var v := dlg.view()
	var idx := -1
	for o in v.options:
		if str(o.text).begins_with("O que sabe sobre Tomas"): idx = o.index
	check(idx >= 0, "tópico sobre Tomas visível (sabe f_tomas_sumiu)")
	WorldHelpers.cmd(w, "ChooseOption", {"index": idx})
	eq(dlg.session.node, "nega", "Dorn nega")
	var hidden: bool = dlg.view().options.any(func(o): return str(o.text).begins_with("Fale a verdade"))
	check(not hidden, "intimidação só aparece após perceber a mentira")


func test_salvar_carregar_preserva_mundo_inteiro_e_continua_igual() -> void:
	var w := WorldHelpers.world(55)
	WorldHelpers.advance_hours(w, 30)
	WorldHelpers.put(w, 56, 25)
	WorldHelpers.cmd(w, "InspectTarget", {"target_id": "arbusto_estrada", "approach": "examinar"})
	var repo := JsonSaveRepository.new("user://test_saves_full")
	eq(repo.save("s", w.to_snapshot()), OK, "save")
	var w2 := WorldHelpers.world(1)
	w2.from_snapshot(repo.load_slot("s").data)
	eq(WorldHelpers.snap(w2), WorldHelpers.snap(w), "snapshot idêntico após load")
	WorldHelpers.advance_hours(w, 20)
	WorldHelpers.advance_hours(w2, 20)
	eq(WorldHelpers.snap(w2).sha256_text(), WorldHelpers.snap(w).sha256_text(), "simulação continua idêntica após load")


func test_migracao_de_save_v1() -> void:
	var repo := JsonSaveRepository.new("user://test_saves_mig")
	var v1 := {"world_seed": "5", "world_tick": 12, "content_version": "0.0.1", "schema_version": 1, "revision": 3,
		"modules": {"clock": {"schema_version": 1, "tick": 12, "tick_minutes": 10, "scheduled": []}, "rng": {"world_seed": "5", "states": {}},
		"player": {"id": "player", "region_id": "vila_inicial", "position": [10, 20]}}}
	var f := FileAccess.open("user://test_saves_mig/old.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"header": {"format": JsonSaveRepository.FORMAT, "schema_version": 1, "checksum": JsonSaveRepository.checksum(v1)}, "data": v1}))
	f.close()
	var got := repo.load_slot("old")
	check(not got.is_empty(), "save antigo carregou")
	eq(int(got.data.schema_version), 2, "migrado para v2")
	check(got.data.modules.has("world_modules"), "campo novo criado")
	var w := WorldHelpers.world(1)
	w.from_snapshot(got.data)
	eq(w.clock.tick, 12, "tick preservado")


func test_modulos_opcionais_desligados_nao_impedem_boot() -> void:
	for id in WorldFactory.OPTIONAL:
		var w := WorldHelpers.world(9, [id])
		var r := WorldHelpers.advance_hours(w, 24)
		check(r.accepted, "boot e 1 dia sem %s" % id)
	var all := WorldHelpers.world(9, WorldFactory.OPTIONAL)
	check(WorldHelpers.advance_hours(all, 24).accepted, "todos opcionais desligados")
	check(not all.set_module_enabled("state", false), "essencial não pode ser desligado")


func test_dados_de_modulo_ausente_sao_preservados() -> void:
	var w := WorldHelpers.world(9)
	var s := w.to_snapshot()
	s.modules.world_modules["modulo_futuro"] = {"x": 1}
	var w2 := WorldHelpers.world(9)
	w2.from_snapshot(s)
	check(w2.to_snapshot().modules.world_modules.has("modulo_futuro"), "dados não são apagados silenciosamente")


func test_descanso_recupera_pelo_livro() -> void:
	var w := WorldHelpers.world(9)
	w.player_sheet.pv = 5
	WorldHelpers.put(w, 11, 13)
	w.player.gold = 5
	var r := WorldHelpers.cmd(w, "Rest")
	check(r.accepted, "descansou: %s" % str(r.errors))
	eq(w.player_sheet.pv, 6, "normal: recupera nível (1) — LB p.106")
	eq(w.player.gold, 4, "pagou a taverna")


func test_llm_fallback_e_validacao() -> void:
	var p := LlmDialogueProvider.new({"enabled": true, "max_calls": 2})
	var got := [""]
	p.transport_override = func(_prompt): return ""
	p.verbalize_async("otto", "Olá.", {}, func(t): got[0] = t)
	eq(got[0], "Olá.", "falha => texto estruturado")
	p.transport_override = func(_prompt): return "Olá, eu sou Zarathustra de Valkaria."
	p.verbalize_async("otto", "Bom dia.", {"allowed_names": []}, func(t): got[0] = t)
	eq(got[0], "Bom dia.", "nomes inventados => rejeitado")
	p.transport_override = func(_prompt): return "Bom dia pra você."
	p.verbalize_async("otto", "Bom dia!", {}, func(t): got[0] = t)
	eq(got[0], "Bom dia!", "orçamento de chamadas esgotado => fallback")
	eq(p.audit.size(), 2, "auditoria registra as chamadas")
	var off := LlmDialogueProvider.new({"enabled": false})
	off.verbalize_async("x", "Oi.", {}, func(t): got[0] = t)
	eq(got[0], "Oi.", "IA desligada não impede nada")
