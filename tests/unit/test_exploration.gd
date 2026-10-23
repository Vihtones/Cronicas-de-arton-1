extends TestCase


func test_andar_nao_revela_nada_automaticamente() -> void:
	var w := WorldHelpers.world()
	var ex: ExplorationModule = w.modules.exploration
	var before := ex.known_facts.size()
	for t in [[42, 29], [56, 24], [72, 22], [86, 11]]:
		WorldHelpers.cmd(w, "MovePlayer", {"to": w.db.tile_to_world(Vector2i(t[0], t[1]))})
	eq(ex.known_facts.size(), before, "sem revelação automática")
	WorldHelpers.put(w, 56, 25)
	check(not ex.nearby_signals().is_empty(), "sinais perceptíveis sem rolagem")


func test_examinar_exige_proximidade() -> void:
	var w := WorldHelpers.world()
	WorldHelpers.put(w, 23, 27)
	var r := WorldHelpers.cmd(w, "InspectTarget", {"target_id": "arbusto_estrada", "approach": "examinar"})
	check(not r.accepted, "longe demais")


func test_anti_loop_exige_mudanca_material() -> void:
	var w := WorldHelpers.world(2)
	var ex: ExplorationModule = w.modules.exploration
	WorldHelpers.put(w, 38, 12)
	# força uma falha registrada
	ex.record_attempt("alvo:bau_tomas", "investigacao", false)
	var r := WorldHelpers.cmd(w, "InspectTarget", {"target_id": "bau_tomas", "approach": "investigar"})
	check(not r.accepted, "mesma abordagem bloqueada")
	var r2 := WorldHelpers.cmd(w, "InspectTarget", {"target_id": "bau_tomas", "approach": "examinar"})
	check(r2.accepted, "outra perícia permitida")
	WorldHelpers.advance_hours(w, 24)
	WorldHelpers.put(w, 38, 12)
	var r3 := WorldHelpers.cmd(w, "InspectTarget", {"target_id": "bau_tomas", "approach": "investigar"})
	check(r3.accepted, "após um dia pode tentar de novo")


func test_sucesso_revela_fato_e_registra_no_diario() -> void:
	var w := WorldHelpers.world()
	var ex: ExplorationModule = w.modules.exploration
	WorldHelpers.put(w, 56, 25)
	for i in 10:
		var r := WorldHelpers.cmd(w, "InspectTarget", {"target_id": "arbusto_estrada", "approach": "examinar"})
		if ex.knows("f_tomas_levado"): break
		WorldHelpers.advance_hours(w, 25)
		WorldHelpers.put(w, 56, 25)
	check(ex.knows("f_tomas_levado"), "CD 10 com Percepção +3 acaba passando")
	check(ex.notes.any(func(n): return n.fact == "f_tomas_levado"), "anotado no diário")


func test_hipoteses_so_usam_o_que_o_jogador_sabe() -> void:
	var w := WorldHelpers.world()
	var ex: ExplorationModule = w.modules.exploration
	var v := ex.hypothesis_view()
	for h in v:
		check(h.supporting.is_empty() and h.contradicting.is_empty(), "nada sustentado no início: " + h.id)
	w.modules.exploration.known_facts["f_tomas_levado"] = {"tick": 0}
	var fuga: Dictionary = ex.hypothesis_view().filter(func(h): return h.id == "h_fuga")[0]
	check(fuga.contradicting.has("f_tomas_levado"), "contradição aparece com a pista")
	eq(fuga.state, "aberta", "jogador decide; o jogo não marca sozinho")


func test_cada_fato_central_tem_ao_menos_dois_caminhos() -> void:
	var db := ContentDB.load_default()
	var paths := {}
	for t in db.all_targets():
		for a in t.actions:
			for f in t.actions[a].get("reveals", []):
				paths[f] = paths.get(f, 0) + 1
	for npc in db.dialogue.npcs:
		for n in db.dialogue.npcs[npc].nodes.values():
			for o in n.get("options", []):
				for e in o.get("effects", []) + o.get("test", {}).get("ok_effects", []):
					if e.has("reveal"): paths[e.reveal] = paths.get(e.reveal, 0) + 1
	for f in ["f_tomas_levado", "f_bandidos_na_ruina", "f_tomas_viu_carga"]:
		check(paths.get(f, 0) >= 2, "%s tem %d caminhos" % [f, paths.get(f, 0)])


func test_resgate_resolve_misterio() -> void:
	var w := WorldHelpers.world()
	w.modules.objects.state.porta_cela.open = true
	w.modules.objects.state.porta_cela.locked = false
	var t: Vector2i = w.modules.npcs.npc_tile("tomas")
	WorldHelpers.put(w, t.x - 1, t.y)
	var r := WorldHelpers.cmd(w, "RescueNPC", {"npc_id": "tomas"})
	check(r.accepted, "resgate aceito: %s" % str(r.errors))
	eq(w.modules.exploration.mystery_state, "resolvido", "mistério resolvido")
	eq(w.modules.npcs.npc("tomas").location, "casa_brandt", "Tomas volta para casa")


func test_bando_parte_no_prazo_e_misterio_se_perde() -> void:
	var w := WorldHelpers.world()
	WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 144 * 12 + 1})
	eq(w.modules.exploration.mystery_state, "perdido", "prazo causal do bando")
	eq(w.modules.npcs.npc("tomas").location, "desconhecido", "Tomas levado")
	eq(w.modules.combat.creatures_of_faction("garras_de_cinza").size(), 0, "cripta vazia")


func test_sem_kael_o_bando_nao_parte() -> void:
	var w := WorldHelpers.world()
	w.modules.combat.creature_state.kael.alive = false
	WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 144 * 12 + 1})
	eq(w.modules.exploration.mystery_state, "ativo", "sem líder não há partida")


func test_porta_trancada_exige_chave_ou_forca() -> void:
	var w := WorldHelpers.world()
	WorldHelpers.put(w, 34, 55)
	var r := WorldHelpers.cmd(w, "UseObject", {"object_id": "porta_cela", "action": "open"})
	check(not r.accepted, "trancada")
	r = WorldHelpers.cmd(w, "UseObject", {"object_id": "porta_cela", "action": "pick_lock"})
	check(not r.accepted, "Ladinagem só treinada")
	r = WorldHelpers.cmd(w, "UseObject", {"object_id": "porta_cela", "action": "unlock"})
	check(not r.accepted, "sem chave")
	w.modules.state.inventory["chave_cela"] = 1
	r = WorldHelpers.cmd(w, "UseObject", {"object_id": "porta_cela", "action": "unlock"})
	check(r.accepted, "com chave destranca")
	r = WorldHelpers.cmd(w, "UseObject", {"object_id": "porta_cela", "action": "open"})
	check(r.accepted, "abre")
	check(not w.modules.objects.blocks(Vector2i(35, 55)), "passagem livre")
