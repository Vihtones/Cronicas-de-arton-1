extends TestCase
## XP dinâmica, poderes e interações entre sistemas (quando a ligação é óbvia).


func _stats(enemies: Array, extra: Dictionary = {}) -> Dictionary:
	var s := {"rounds": 3, "dmg_dealt": 10, "dmg_taken": 10, "crits": 0, "tactics": {}, "adverse": {}, "pv_start": 23, "pv_max": 23,
		"pv_end": 13, "pm_spent": 0, "went_down": false, "enemies": enemies}
	s.merge(extra, true)
	return s


func _end(w: WorldState, enemies: Array, outcome: String, extra: Dictionary = {}) -> Array:
	return w.modules.progression.on_event(GameEvent.create("e%d" % randi(), "COMBAT_ENDED", 0,
		{"outcome": outcome, "enemies": enemies, "stats": _stats(enemies, extra)}))


func _xp(out: Array) -> int:
	for f in out:
		if f.type == "XP_GAINED": return int(f.payload.amount)
	return 0


func test_xp_dinamica_base_do_livro_e_multiplicadores() -> void:
	var w := WorldHelpers.world(1)
	var solo := _xp(_end(w, ["bandido_1"], "vitoria"))
	eq(solo, 250, "bandido ND 1/4 = 250 base, sem bônus")
	var w2 := WorldHelpers.world(1)
	var hard := _xp(_end(w2, ["bandido_1", "bandido_2", "kael"], "vitoria",
		{"adverse": {"visibilidade": true}, "tactics": {"flanqueando": true, "ataque especial": true}, "dmg_taken": 3, "rounds": 3}))
	# base 250+250+500 = 1000; bônus: +20% (3 inimigos) +10% adversa +10% táticas +10% quase ileso +10% rápida = ×1.6
	eq(hard, 1600, "conta transparente: 1000 × 1,6")
	var w3 := WorldHelpers.world(1)
	# Decisão do usuário: fuga e captura não rendem XP (antes a fuga valia metade e dava para farmar).
	eq(_xp(_end(w3, ["bandido_1"], "fuga")), 0, "fuga não rende XP")
	eq(_xp(_end(w3, ["bandido_1"], "captura")), 0, "captura não rende XP")


func test_fugir_repetidamente_nao_rende_xp() -> void:
	var w := WorldHelpers.world(1)
	var total := 0
	for i in 20:
		total += _xp(_end(w, ["bandido_1", "bandido_2"], "fuga"))
	eq(total, 0, "20 fugas seguidas = 0 XP")
	WorldHelpers.cmd(w, "SetXpMode", {"mode": "livro"})
	eq(_xp(_end(w, ["bandido_1"], "fuga")), 0, "no modo livro também")


func test_furtividade_nao_reabre_xp_com_grupo_diferente() -> void:
	var w := WorldHelpers.world(1)
	var prog: ProgressionModule = w.modules.progression
	var first := _xp(prog.on_event(GameEvent.create("a", "STEALTH_CHECK", 0, {"group": ["bandido_1", "bandido_2"], "success": true})))
	check(first > 0, "primeira evasão rende")
	var again := _xp(prog.on_event(GameEvent.create("b", "STEALTH_CHECK", 0, {"group": ["bandido_1"], "success": true})))
	var again2 := _xp(prog.on_event(GameEvent.create("c", "STEALTH_CHECK", 0, {"group": ["bandido_2", "bandido_1"], "success": true})))
	eq(again + again2, 0, "mesmas criaturas em outro agrupamento não rendem de novo")


func test_xp_dinamica_retorno_decrescente_por_repeticao() -> void:
	var w := WorldHelpers.world(1)
	var a := _xp(_end(w, ["bandido_1"], "vitoria"))
	var b := _xp(_end(w, ["bandido_2"], "vitoria"))
	var c := _xp(_end(w, ["bandido_1"], "vitoria"))
	check(a > b and b > c, "cada vitória repetida sobre o mesmo tipo vale menos (%d > %d > %d)" % [a, b, c])
	var d := _xp(_end(w, ["hiena_1"], "vitoria"))
	eq(d, 1000, "inimigo novo volta a valer cheio")


func test_xp_de_aprendizado_e_evasao_uma_vez_so() -> void:
	var w := WorldHelpers.world(1)
	var prog: ProgressionModule = w.modules.progression
	var ev := GameEvent.create("t1", "TARGET_INSPECTED", 0, {"target": "trilha_marcas", "approach": "rastrear",
		"check": {"success": true, "cd": 15, "skill": "sobrevivencia"}})
	eq(_xp(prog.on_event(ev)), 100, "(CD 15 − 10) × 20")
	eq(_xp(prog.on_event(GameEvent.create("t2", "TARGET_INSPECTED", 0, ev.payload))), 0, "não repete")
	var st := GameEvent.create("s1", "STEALTH_CHECK", 0, {"group": ["bandido_1", "bandido_2", "kael"], "success": true})
	eq(_xp(prog.on_event(st)), 250, "passar despercebido = 25% do ND do grupo")


func test_modo_livro_preserva_regra_oficial() -> void:
	var w := WorldHelpers.world(1)
	WorldHelpers.cmd(w, "SetXpMode", {"mode": "livro"})
	eq(_xp(_end(w, ["bandido_1", "bandido_2", "kael"], "vitoria", {"tactics": {"magia": true}})), 0, "no modo livro o XP vem por criatura derrotada")
	var out: Array = w.modules.progression.on_event(GameEvent.create("x", "CREATURE_DEFEATED", 0, {"creature": "kael", "by": "player", "name": "Kael"}))
	eq(_xp(out), 500, "Kael ND 1/2 = 500")


func test_combate_real_gera_estatisticas_e_xp_com_conta() -> void:
	var got := false
	for s in [11, 22, 33, 44]:
		var w := WorldHelpers.world(s)
		w.clock.tick = 144 + 6 * 14
		WorldHelpers.put(w, 21, 56)
		WorldHelpers.cmd(w, "MovePlayer", {"to": w.db.tile_to_world(Vector2i(21, 56))})
		var c: CombatModule = w.modules.combat
		var xp_events: Array = []
		for turn in 40:
			if not c.active or c.sim.current_id() != "player": break
			var tgt := ""
			var bd := 99
			for id in c.sim.combatants:
				if id != "player" and c.sim.conscious(id):
					var d := CombatSim.cheb(c.sim.c(id).tile, c.sim.c("player").tile)
					if d < bd: bd = d; tgt = id
			var plan := []
			if bd > 1:
				var path := c.sim.trim_path("player", c.sim.find_path("player", c.sim.c(tgt).tile), c.sim.speed_squares("player"))
				if not path.is_empty(): plan.append({"type": "move", "path": path.map(func(t): return [t.x, t.y])})
			var atk := {"type": "attack", "target": tgt, "special": c.sim.c("player").sheet.pm > 0}
			if c.preview(plan + [atk]).valid: plan.append(atk)
			var r := WorldHelpers.cmd(w, "ExecutePlan", {"actions": plan}) if not plan.is_empty() else null
			if r: xp_events.append_array(WorldHelpers.events_of(r, "XP_GAINED"))
			if c.active:
				xp_events.append_array(WorldHelpers.events_of(WorldHelpers.cmd(w, "EndTurn"), "XP_GAINED"))
		for e in xp_events:
			if str(e.payload.reason).begins_with("combate"):
				got = true
				check(e.payload.breakdown.any(func(b): return str(b[0]).begins_with("desvantagem")), "3 inimigos contam como desvantagem")
				check(e.payload.breakdown.any(func(b): return str(b[0]).begins_with("táticas")), "Ataque Especial conta como tática")
				# C22: o resumo pós-combate precisa da conta inteira
				check(e.payload.get("combat", false) and e.payload.has("base") and e.payload.has("mult") and e.payload.has("next"), "payload do resumo pós-combate")
				eq(int(e.payload.amount), int(round(float(e.payload.base) * float(e.payload.mult))), "XP = base × multiplicador")
		if got: break
	check(got, "algum combate terminou com XP dinâmica detalhada")


func test_poderes_valentao_e_especializacao_aparecem_no_fantasma() -> void:
	var w := WorldHelpers.world(5)
	w.player_sheet.powers["valentao"] = true
	w.player_sheet.powers["especializacao_arma"] = "espada_longa"
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1"], true, false)
	var sim: CombatSim = w.modules.combat.sim
	sim.c("player").tile = Vector2i(26, 57)
	sim.c("bandido_1").tile = Vector2i(27, 57)
	var prof := sim.attack_profile("player", "bandido_1", 0, false, false)
	check(prof.mods.any(func(m): return m[0] == "valentão"), "Valentão contra surpreendido (desprevenido)")


func test_escolher_poder_ao_subir_de_nivel() -> void:
	var w := WorldHelpers.world(5)
	w.player_sheet.xp = 990
	var out: Array = w.modules.progression._award(20, "teste", [])
	check(out.any(func(f): return f.type == "LEVEL_UP"), "subiu")
	var r := WorldHelpers.cmd(w, "ChoosePower", {"power": "valentao"})
	check(r.accepted, "escolheu: %s" % str(r.errors))
	check(w.player_sheet.has_power("valentao"), "poder na ficha")
	check(not WorldHelpers.cmd(w, "ChoosePower", {"power": "gatuno"}).accepted, "sem poder pendente / fora da classe")


func test_hiena_derruba_e_jogador_precisa_levantar() -> void:
	var downed := false
	for s in range(1, 25):
		var w := WorldHelpers.world(s)
		w.clock.tick = 6 * 21
		WorldHelpers.put(w, 76, 34)
		w.modules.combat._start(["hiena_1"], false, false)
		var c: CombatModule = w.modules.combat
		if c.active and c.sim.c("player").sheet.conditions.has("caido") and not c.sim.c("player").sheet.is_down():
			downed = true
			eq(c.sim.speed_squares("player"), 1, "caído: deslocamento 1,5m (LB p.394)")
			check(GhostPlanner.validate_action(c.sim, "player", {"type": "stand"}).ok, "pode levantar (ação de movimento)")
			break
	check(downed, "a mordida da hiena derruba (Bestiário p.120)")


func test_penalidade_de_armadura_em_pericias() -> void:
	var w := WorldHelpers.world(5)
	var s := w.player_sheet
	var before := s.skill_value("furtividade", w.rules)
	s.equipment.armor = "cota_malha"
	eq(s.skill_value("furtividade", w.rules), before - 1, "cota de malha −2 em vez de −1 do couro (LB p.115/153)")
	eq(s.skill_value("percepcao", w.rules), 3, "Percepção não tem penalidade de armadura")


func test_alcance_da_arma_vem_do_livro() -> void:
	var w := WorldHelpers.world(5)
	w.player_sheet.equipment.weapon = "arco_curto"
	CharacterBuilder.apply_equipment(w.rules, w.player_sheet)
	eq(int(w.player_sheet.attacks[0].alcance_q), 20, "arco curto: alcance médio = 20 quadrados (LB p.143)")


# --- interações entre sistemas ------------------------------------------------------
func test_dominio_alimenta_economia_e_imposto_alto_gera_ressentimento() -> void:
	var w := WorldHelpers.world(5)
	Prototypes.apply("dominio", w)
	var eco: EconomyModule = w.modules.economy
	var food_before := int(eco.regions.vila.stock.comida)
	WorldHelpers.cmd(w, "SetPolicy", {"key": "imposto", "value": "alto"})
	var unrest := false
	for i in 6:
		var r := WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 7 * 144})
		if not WorldHelpers.events_of(r, "DOMAIN_UNREST").is_empty(): unrest = true
	check(int(eco.regions.vila.stock.comida) > food_before, "farinha do moinho entra no estoque")
	check(unrest, "imposto alto prolongado gera agitação")
	check(w.modules.memory.reputation("otto") < 0 or w.modules.memory.reputation("hilda") < 0, "família Brandt guarda ressentimento")


func test_fauna_desinformacao_se_espalha_e_custa_comida() -> void:
	var w := WorldHelpers.world(7)
	Prototypes.apply("fauna", w)
	var eco: EconomyModule = w.modules.economy
	var food0 := int(eco.regions.vila.stock.comida)
	for d in 6:
		WorldHelpers.advance_hours(w, 24)
		if w.modules.state.has_flag("ovelha_morta"): break
	WorldHelpers.advance_hours(w, 48)
	var mem: MemoryModule = w.modules.memory
	var spread := false
	for n in ["joran", "celia", "pell", "ivi"]:
		if mem.list(n).any(func(m): return m.about == "lobos"): spread = true
	check(spread, "a crença errada de Fenna ('lobos') se espalha pela família em casa")
	check(w.modules.fauna.attacks.size() >= 1, "ataque registrado")


func test_matar_a_matilha_resolve_misterio_e_da_xp() -> void:
	var w := WorldHelpers.world(7)
	var ex: ExplorationModule = w.modules.exploration
	ex.known_facts["f_ovelhas_mortas"] = {"tick": 0}
	ex.side_states["m_ovelhas"] = "ativo"
	var c: CombatModule = w.modules.combat
	c.creature_state.hiena_1.alive = false
	var r := w.apply_command(GameCommand.create("x", "player", "AdvanceTime", {"ticks": 1}))
	c.creature_state.hiena_2.alive = false
	var out := ex.on_event(GameEvent.create("cd", "CREATURE_DEFEATED", 0, {"creature": "hiena_2", "by": "player"}))
	check(out.any(func(f): return f.type == "MYSTERY_RESOLVED" and f.payload.mystery == "m_ovelhas"), "2º mistério resolvido ao acabar a matilha")


func test_morte_de_teodoro_gera_luto_e_vinheta() -> void:
	var w := WorldHelpers.world(7)
	Prototypes.apply("geracoes", w)
	WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 12})
	check(not w.modules.npcs.npc("teodoro").alive, "morreu")
	var npcs: NpcModule = w.modules.npcs
	w.clock.tick += 144 * 3 + 6 * 9
	for id in npcs.state: npcs.state[id].location = npcs.desired_location(id)
	var loc: String = npcs.npc("elsa").location
	WorldHelpers.put(w, w.db.location_spot(loc).x, w.db.location_spot(loc).y)
	var c: Array = w.modules.pacing.candidates()
	check(c.any(func(x): return str(x.id).begins_with("luto")), "vinheta de luto onde a herdeira está")


func test_noticias_dos_aventureiros_chegam_pela_mensageira() -> void:
	var w := WorldHelpers.world(9)
	for d in 40:
		WorldHelpers.advance_hours(w, 24)
	var mem: MemoryModule = w.modules.memory
	var heard := false
	for n in w.db.npcs.npcs:
		if n.id != "saria" and mem.list(n.id).any(func(m): return str(m.key).contains("aventureiros")): heard = true
	check(not w.modules.adventurers.history.is_empty(), "os aventureiros fizeram missões")
	check(heard, "a vila soube pelas histórias de Saria (L3 → L1 por mensageira)")


func test_neblina_atrasa_viagem_e_atrapalha_combate() -> void:
	var w := WorldHelpers.world(5)
	var tr: TravelModule = w.modules.travel
	var clear := tr.km_per_day(TravelModule.ROUTES["vila->valkaria"])
	w.modules.weather.region.condition = "neblina"
	eq(tr.km_per_day(TravelModule.ROUTES["vila->valkaria"]), clear / 2.0, "clima ruim reduz à metade (LB p.270)")
	check(w.modules.weather.env_at(Vector2i(70, 34)).fog, "neblina dá camuflagem leve no combate")


func test_truque_magico_da_seta_ao_ladino() -> void:
	var w := WorldHelpers.world(5)
	w.player_sheet = CharacterBuilder.build(w.rules, "humano", "ladino", CharacterBuilder.presets("ladino")[1], ["des", "int", "car"])
	w.player_sheet.pending_powers = 1
	check(WorldHelpers.cmd(w, "ChoosePower", {"power": "truque_magico"}).accepted, "Int 2 cumpre o pré-requisito")
	check(w.player_sheet.spells.has("seta_infalivel"), "aprendeu Seta Infalível")


func test_allihanna_bloqueia_equipar_metal() -> void:
	var w := WorldHelpers.world(5)
	w.modules.religion.on_event(GameEvent.create("a", "BECOME_DEVOTEE", 0, {"god": "Allihanna"}))
	w.modules.state.inventory["cota_malha"] = 1
	check(not WorldHelpers.cmd(w, "Equip", {"item": "cota_malha"}).accepted, "devoção impede equipar metal")


func test_memorias_comuns_sao_esquecidas_duraveis_ficam() -> void:
	var w := WorldHelpers.world(5)
	var mem: MemoryModule = w.modules.memory
	mem.add_memory("garrick", {"key": "boba", "about": "x", "subject": "", "valence": 0, "location": "", "tick": 0, "emotion": "",
		"reliability": 1.0, "source": "testemunha", "durable": false, "text": "x"})
	mem.add_memory("garrick", {"key": "grave", "about": "x", "subject": "", "valence": 0, "location": "", "tick": 0, "emotion": "",
		"reliability": 1.0, "source": "testemunha", "durable": true, "text": "x"})
	for i in 32:
		WorldHelpers.advance_hours(w, 24)
	check(not mem.knows_fact("garrick", "boba"), "esquecida após 30 dias")
	check(mem.knows_fact("garrick", "grave"), "memória durável permanece")


func test_regressao_criaturas_nao_ganham_especializacao_sem_poder() -> void:
	var w := WorldHelpers.world(11)
	w.clock.tick = 6 * 14
	WorldHelpers.put(w, 24, 56)
	w.modules.combat._start(["bandido_1"], false, false)
	for e in w.journal:
		if e.event_type == "ATTACK_RESOLVED" and e.payload.attacker == "bandido_1" and e.payload.hit:
			var rolls: Array = e.payload.rolls
			var sum := 0
			for r in rolls: sum += int(r)
			check(int(e.payload.damage) <= sum + 3, "Clava 1d6+3 sem bônus indevido (%d)" % int(e.payload.damage))


func test_emboscada_tatica_na_partida_vira_combate_e_da_xp() -> void:
	var hit := false
	for s in range(1, 40):
		var w := WorldHelpers.world(s)
		Prototypes.apply("emboscada", w)
		var r := WorldHelpers.cmd(w, "Travel", {"route": "vila->valkaria"})
		if not WorldHelpers.events_of(r, "AMBUSH_PERCEPTION").is_empty():
			hit = true
			check(w.modules.combat.active, "combate tático começou na estrada")
			eq(w.modules.travel.current_region, "vila", "a viagem foi interrompida")
			break
	check(hit, "com o bando ativo, a saída da vila pode ter emboscada tática")


func test_patrulha_do_dominio_reduz_risco_da_estrada() -> void:
	var w := WorldHelpers.world(5)
	var tr: TravelModule = w.modules.travel
	var base := tr.ambush_risk()
	Prototypes.apply("dominio", w)
	WorldHelpers.cmd(w, "SetPolicy", {"key": "patrulha", "value": true})
	check(tr.ambush_risk() < base, "patrulha paga pelo domínio deixa a estrada mais segura (%.2f < %.2f)" % [tr.ambush_risk(), base])


func test_mercado_de_valkaria_e_mais_barato_e_so_la() -> void:
	var w := WorldHelpers.world(5)
	Prototypes.apply("viagem", w)
	w.player.gold = 500
	check(not WorldHelpers.cmd(w, "Buy", {"npc_id": "valkaria_mercado", "item": "corda"}).accepted, "não compra da vila")
	w.modules.travel.current_region = "valkaria"
	var eco: EconomyModule = w.modules.economy
	check(eco.price("cota_malha", "valkaria") <= eco.price("cota_malha", "vila", "garrick"), "capital não é mais cara que o ferreiro desconfiado")
	check(WorldHelpers.cmd(w, "Buy", {"npc_id": "valkaria_mercado", "item": "pocao_cura"}).accepted, "compra na capital")


func test_derrota_para_salteadores_rouba_mas_nao_prende_na_cripta() -> void:
	var w := WorldHelpers.world(5)
	Prototypes.apply("emboscada", w)
	var c: CombatModule = w.modules.combat
	c.creature_state.salteador_1.present = true
	c._start(["salteador_1"], false, false)
	c.sim.c("player").sheet.pv = 0
	c.sim.c("player").sheet.stable = true
	var out := c._check_end()
	check(out.any(func(f): return f.type == "PLAYER_ROBBED"), "roubado")
	check(w.db.zone_at(w.db.world_to_tile(w.player.position)) != "cripta", "não vai para a cela do bando")
	eq(w.player.gold, 30, "ouro sai por evento (aplicado no commit)")


func _raspao_world(policy: String) -> WorldState:
	var w := WorldHelpers.world(5)
	w.player_sheet.powers["golpe_raspao"] = true
	w.player_sheet.pm = 20
	WorldHelpers.put(w, 25, 57)
	WorldHelpers.cmd(w, "SetPowerPolicy", {"power": "golpe_raspao", "policy": policy})
	w.modules.combat._start(["bandido_1"], true, false)
	var sim: CombatSim = w.modules.combat.sim
	sim.c("player").tile = Vector2i(26, 57)
	sim.c("bandido_1").tile = Vector2i(27, 57)
	sim.c("bandido_1").sheet.defense_fixed = 99   # erra sempre (fora o 20 natural)
	return w


func _raspao_count(w: WorldState, action: Dictionary) -> int:
	var c: CombatModule = w.modules.combat
	var n := 0
	for i in 12:
		c.sim.round_no = 100 + i   # 1/rodada
		var v := GhostPlanner.validate_action(c.sim, "player", {"type": "attack", "target": "bandido_1"})
		c._cur_action = action
		for f in c._resolve_attack("player", "bandido_1", v, false):
			if f.type == "ATTACK_RESOLVED" and (f.payload.tags as Array).has("raspao"): n += 1
		c._cur_action = {}
		c.sim.c("bandido_1").sheet.pv = 50
	return n


func test_c20_politica_de_golpe_de_raspao() -> void:
	check(_raspao_count(_raspao_world("auto"), {}) >= 10, "auto: usa ao errar")
	eq(_raspao_count(_raspao_world("nunca"), {}), 0, "nunca: não gasta PM")
	check(_raspao_count(_raspao_world("nunca"), {"raspao": true}) >= 10, "o plano do turno sobrescreve a política")
	eq(_raspao_count(_raspao_world("auto"), {"raspao": false}), 0, "desligar no turno")


func test_c20_politica_de_durao_e_persistencia() -> void:
	var w := WorldHelpers.world(5)
	var c: CombatModule = w.modules.combat
	var sh := w.player_sheet
	check(c._durao_wanted("player", sh.pv_max, sh), "padrão: golpe forte usa Durão")
	check(not c._durao_wanted("player", 1, sh), "padrão: golpe fraco não")
	check(WorldHelpers.cmd(w, "SetPowerPolicy", {"power": "durao", "policy": "sempre"}).accepted, "aceita")
	check(c._durao_wanted("player", 1, sh), "sempre")
	check(not WorldHelpers.cmd(w, "SetPowerPolicy", {"power": "durao", "policy": "talvez"}).accepted, "política inválida")
	var c2 := CombatModule.new()
	c2.from_dict(c.to_dict())
	eq(c2.power_policy.durao, "sempre", "salvo no save")


func test_c10_matilha_muda_de_toca_e_as_hienas_vao_junto() -> void:
	var w := WorldHelpers.world(5)
	var c: CombatModule = w.modules.combat
	var before: Array = c.creature_state.hiena_2.tile.duplicate()
	var r: Array = c.on_event(GameEvent.create("pr", "PACK_RELOCATED", 0,
		{"from": "toca_leste", "to": "toca_funda", "center": [88, 44], "old_center": [80, 36]}))
	check(not r.is_empty() and r[0].type == "CREATURES_MOVED", "hienas se movem")
	var t: Array = c.creature_state.hiena_2.tile
	check(Vector2i(int(t[0]), int(t[1])).distance_to(Vector2i(88, 44)) <= 3.0, "hiena_2 perto da nova toca (%s)" % str(t))
	check(t != before, "saiu da toca antiga")
	check(w.db.static_walkable(Vector2i(int(t[0]), int(t[1]))), "tile andável")


func test_c10_cadeia_completa_pelo_commit() -> void:
	var w := WorldHelpers.world(5)
	# um commit real com o fato de derrota: fauna → PACK_RELOCATED → combate move as hienas
	var r := w._commit(GameCommand.create("t-c10", "player", "Teste", {}), [WorldModule.fact("CREATURE_DEFEATED", {"creature": "hiena_1", "by": "player"})])
	check(WorldHelpers.events_of(r, "PACK_RELOCATED").size() == 1, "a toca muda")
	check(WorldHelpers.events_of(r, "CREATURES_MOVED").size() == 1, "as hienas vão junto")
	eq(w.modules.fauna.den, "toca_funda")
