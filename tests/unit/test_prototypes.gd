extends TestCase
## Uma "build" funcional por mecânica: cada protótipo sobe e demonstra a mecânica.


func _w(id: String, p_seed: int = 7) -> WorldState:
	var w := WorldHelpers.world(p_seed)
	Prototypes.apply(id, w)
	return w


func _fight(w: WorldState, prefer_spell: bool = false) -> void:
	var c: CombatModule = w.modules.combat
	for turn in 40:
		if not c.active or c.sim.current_id() != "player":
			break
		var target := ""
		var bd := 999
		for id in c.sim.combatants:
			if id != "player" and c.sim.conscious(id):
				var d := CombatSim.cheb(c.sim.c("player").tile, c.sim.c(id).tile)
				if d < bd: bd = d; target = id
		if target == "":
			break
		var plan := []
		var cast := {"type": "cast", "spell": "seta_infalivel", "targets": [target]}
		if prefer_spell and c.preview([cast]).valid:
			plan = [cast]
		else:
			if bd > 1:
				var path := c.sim.trim_path("player", c.sim.find_path("player", c.sim.c(target).tile), c.sim.speed_squares("player"))
				if not path.is_empty(): plan.append({"type": "move", "path": path.map(func(t): return [t.x, t.y])})
			var atk := {"type": "attack", "target": target}
			if c.preview(plan + [atk]).valid: plan.append(atk)
		if not plan.is_empty():
			WorldHelpers.cmd(w, "ExecutePlan", {"actions": plan})
		if c.active:
			WorldHelpers.cmd(w, "EndTurn")


func test_todos_os_prototipos_sobem_e_avancam_um_dia() -> void:
	for id in Prototypes.ids():
		var w := WorldHelpers.world(3)
		var info := Prototypes.apply(id, w)
		check(info.intro != "", "intro de " + id)
		if w.player_sheet.is_dead():
			continue
		var c: CombatModule = w.modules.combat
		var r := WorldHelpers.advance_hours(w, 1) if not c.active else WorldHelpers.cmd(w, "EndTurn")
		check(r.accepted or c.active, "%s avança: %s" % [id, str(r.errors)])


func test_criacao_de_personagem_segue_o_livro() -> void:
	var r := RuleRegistry.load_default()
	check(not CharacterBuilder.validate_points(r, {"for": 4, "des": 4, "con": 0, "int": 0, "sab": 0, "car": 0}).is_empty(), "14 pontos rejeitado")
	for cls in CharacterBuilder.CLASSES:
		for pre in CharacterBuilder.presets(cls):
			check(CharacterBuilder.validate_points(r, pre).is_empty(), "preset %s válido: %s" % [cls, str(pre)])
	var a := CharacterBuilder.build(r, "anao", "arcanista", CharacterBuilder.presets("arcanista")[0])
	eq(a.pv_max, 8 + 3 + 3, "Arcanista anão: 8 + Con 3 (1+2) + Duro como Pedra 3")
	eq(a.pm_max, 6 + 4, "6 PM + Int 4")
	eq(a.speed_m, 6.0, "anão 6m")
	check(a.spells.has("seta_infalivel"), "conhece Seta Infalível")
	var l := CharacterBuilder.build(r, "humano", "ladino", CharacterBuilder.presets("ladino")[0], ["des", "int", "car"])
	eq(l.pv_max, 12 + 1, "Ladino: 12 + Con 1")
	check(l.trained.has("ladinagem") and l.trained.has("reflexos"), "perícias fixas")
	eq(l.attrs.des, 5, "+1 humano em Des")


func test_magia_seta_infalivel_acerta_sempre_e_gasta_pm() -> void:
	var w := _w("magia")
	WorldHelpers.cmd(w, "MovePlayer", {"to": w.db.tile_to_world(Vector2i(21, 56))})
	var c: CombatModule = w.modules.combat
	check(c.active, "bandidos detectam a arcanista")
	if not c.active: return
	for i in 10:
		if c.sim.current_id() == "player": break
		WorldHelpers.cmd(w, "EndTurn")
	var pm: int = c.sim.c("player").sheet.pm
	if not c.active: return
	var target := ""
	var bd := 99
	for id in c.sim.combatants:
		if id != "player" and c.sim.conscious(id) and CombatSim.cheb(c.sim.c(id).tile, c.sim.c("player").tile) < bd:
			bd = CombatSim.cheb(c.sim.c(id).tile, c.sim.c("player").tile); target = id
	var r := WorldHelpers.cmd(w, "ExecutePlan", {"actions": [{"type": "cast", "spell": "seta_infalivel", "targets": [target]}]})
	check(r.accepted, "lançou: %s" % str(r.errors))
	var hits := WorldHelpers.events_of(r, "ATTACK_RESOLVED").filter(func(e): return e.payload.get("spell", false))
	eq(hits.size(), 2, "duas setas (LB p.206)")
	check(hits.all(func(e): return e.payload.hit), "acertam automaticamente")
	if c.active:
		eq(c.sim.c("player").sheet.pm, pm - 1, "1 PM (1º círculo, LB p.170)")


func test_ladino_causa_ataque_furtivo_em_alvo_surpreendido() -> void:
	var found := false
	for s in [1, 2, 3, 4, 5, 6, 7, 8]:
		var w := _w("ladino", s)
		var c: CombatModule = w.modules.combat
		WorldHelpers.cmd(w, "MovePlayer", {"to": w.db.tile_to_world(Vector2i(24, 56))})
		if c.active or c.undetected_by.is_empty():
			continue
		WorldHelpers.cmd(w, "StartCombat", {"enemies": c.undetected_by.keys()})
		for i in 6:
			if c.sim.current_id() == "player": break
			WorldHelpers.cmd(w, "EndTurn")
		var tgt := ""
		for id in c.sim.combatants:
			if id != "player" and c.sim.c(id).sheet.has_effective_condition(w.rules, "desprevenido"): tgt = id
		if tgt == "": continue
		var path := c.sim.trim_path("player", c.sim.find_path("player", c.sim.c(tgt).tile), c.sim.speed_squares("player"))
		var plan := []
		if not path.is_empty(): plan.append({"type": "move", "path": path.map(func(t): return [t.x, t.y])})
		plan.append({"type": "attack", "target": tgt})
		var r := WorldHelpers.cmd(w, "ExecutePlan", {"actions": plan})
		for e in WorldHelpers.events_of(r, "ATTACK_RESOLVED"):
			if e.payload.tags.has("furtivo"): found = true
		if found: break
	check(found, "Ataque Furtivo aplicado em alvo desprevenido (LB p.73)")


func test_progressao_hiena_da_mil_xp_e_sobe_nivel() -> void:
	var w := _w("progressao")
	var prog: ProgressionModule = w.modules.progression
	eq(prog.xp_for(ProgressionModule.nd_value("1")), 1000, "ND 1 = 1.000 XP (LB p.326)")
	eq(prog.xp_for(ProgressionModule.nd_value("1/4")), 250, "ND 1/4 = 250")
	var out := prog.on_event(GameEvent.create("x", "CREATURE_DEFEATED", 0, {"creature": "hiena_1", "by": "player", "name": "Hiena"}))
	check(out.any(func(f): return f.type == "LEVEL_UP"), "sobe para o 2º nível")
	eq(w.player_sheet.level, 2, "nível 2")
	eq(w.player_sheet.pv_max, 23 + 5 + 3, "+5 + Con por nível (guerreiro)")
	eq(w.player_sheet.pending_powers, 1, "poder de classe pendente para escolha")


func test_equipamento_compra_e_equipa_com_vendedor_desconfiado() -> void:
	var w := _w("equipamento")
	var eco: EconomyModule = w.modules.economy
	check(eco.price("cota_malha", "vila", "garrick") > eco.price("cota_malha", "vila", "mara"), "Garrick cobra mais de estranhos")
	var r := WorldHelpers.cmd(w, "Buy", {"npc_id": "garrick", "item": "cota_malha"})
	check(r.accepted, "comprou: %s" % str(r.errors))
	r = WorldHelpers.cmd(w, "Equip", {"item": "cota_malha"})
	check(r.accepted, "equipou")
	eq(w.player_sheet.defense(w.rules), 10 + 3 + 6, "Defesa com cota de malha (+6, LB p.153)")
	check(w.modules.state.has_item("couro_batido"), "armadura antiga volta ao inventário")


func test_viagem_leva_dias_e_chega_a_valkaria() -> void:
	var w := _w("viagem")
	var tr: TravelModule = w.modules.travel
	var t0 := w.clock.tick
	var r := WorldHelpers.cmd(w, "Travel", {"route": "vila->valkaria"})
	check(r.accepted, "partiu: %s" % str(r.errors))
	eq(tr.current_region, "valkaria", "chegou")
	check(w.clock.tick - t0 >= 6 * 8 * 2, "90 km a 36 km/dia (LB p.270) leva mais de 2 dias de marcha")
	r = WorldHelpers.cmd(w, "Travel", {"route": "valkaria->vila"})
	check(r.accepted and tr.current_region == "vila", "voltou")


func test_dominio_gira_semana_e_delegacao_ajusta() -> void:
	var w := _w("dominio")
	var dom: DomainModule = w.modules.domain
	check(dom.owned, "domínio concedido")
	WorldHelpers.cmd(w, "SetPolicy", {"key": "imposto", "value": "alto"})
	for i in 3:
		WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 7 * 144})
	check(dom.reports.size() >= 3, "relatórios semanais")
	check(dom.morale < 60, "imposto alto derruba o moral")
	WorldHelpers.cmd(w, "Delegate", {"on": true})
	for i in 4:
		WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 7 * 144})
	eq(dom.policy.imposto, "baixo", "conselheiro reduz imposto com moral baixo")


func test_geracoes_morte_por_velhice_e_heranca() -> void:
	var w := _w("geracoes")
	var r := WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 12})
	check(not WorldHelpers.events_of(r, "NPC_DIED").is_empty(), "Teodoro morre ao completar a longevidade (LB p.108)")
	check(not w.modules.npcs.npc("teodoro").alive, "não aparece mais")
	eq(w.modules.lineage.inheritance.get("teodoro", ""), "elsa", "herança para o parente vivo mais velho")
	check(w.modules.memory.knows_fact("elsa", "luto:teodoro:teodoro"), "família lembra do luto")


func test_herdeiro_assume_no_mesmo_mundo() -> void:
	var w := _w("herdeiro")
	check(w.player_sheet.is_dead(), "herói morto")
	w.modules.memory.add_memory("hilda", {"key": "resgatou:player:tomas", "about": "player", "subject": "tomas", "valence": 40, "location": "x",
		"tick": 0, "emotion": "", "reliability": 1.0, "source": "testemunha", "durable": true, "text": "x"})
	var r := WorldHelpers.cmd(w, "ContinueAsHeir")
	check(r.accepted, "sucessão aceita")
	check(not w.player_sheet.is_dead(), "herdeiro vivo")
	eq(w.player.gold, 20, "metade do ouro")
	eq(w.modules.memory.reputation("hilda"), 0.0, "a gratidão era pelo herói anterior, não pelo herdeiro")


func test_fauna_faminta_ataca_ovelhas_e_abre_misterio() -> void:
	var w := _w("fauna")
	var killed := false
	for d in 6:
		var r := WorldHelpers.advance_hours(w, 24)
		if not WorldHelpers.events_of(r, "SHEEP_KILLED").is_empty(): killed = true; break
	check(killed, "matilha faminta ataca o rebanho")
	check(w.modules.state.has_flag("ovelha_morta"), "carcaça visível")
	check(w.modules.memory.list("fenna").any(func(m): return m.about == "lobos"), "Fenna culpa lobos (interpretação errada)")
	WorldHelpers.put(w, 58, 27)
	w.clock.tick = (w.clock.tick / 144 + 1) * 144 + 6 * 10
	var ex: ExplorationModule = w.modules.exploration
	for i in 3:
		WorldHelpers.cmd(w, "InspectTarget", {"target_id": "carcaca_ovelha", "approach": "examinar"})
		WorldHelpers.cmd(w, "InspectTarget", {"target_id": "carcaca_ovelha", "approach": "rastrear"})
		if ex.knows("f_marcas_hiena"): break
		WorldHelpers.advance_hours(w, 25)
		WorldHelpers.put(w, 58, 27)
	check(ex.knows("f_ovelhas_mortas"), "2º mistério aberto")
	check(ex.hypothesis_view().any(func(h): return h.mystery == "m_ovelhas"), "hipóteses do 2º mistério no diário")


func test_fe_khalmyr_proibe_recusar_ajuda_e_allihanna_metal() -> void:
	var w := _w("fe")
	var rel: ReligionModule = w.modules.religion
	rel.on_event(GameEvent.create("a", "BECOME_DEVOTEE", 0, {"god": "Khalmyr"}))
	var out := rel.on_event(GameEvent.create("b", "REFUSED_HELP", 0, {"npc": "hilda"}))
	check(out.any(func(f): return f.type == "OBLIGATION_VIOLATED"), "Khalmyr: recusar ajuda viola (LB p.99)")
	rel.on_event(GameEvent.create("c", "BECOME_DEVOTEE", 0, {"god": "Allihanna"}))
	check(rel.forbids_armor("cota_malha") != "", "Allihanna: sem metal (LB p.97)")
	eq(rel.forbids_armor("couro_batido"), "", "couro é permitido")


func test_investigacao_identifica_ladrao_sem_testemunhas() -> void:
	var w := _w("investigacao")
	var cr: CrimeModule = w.modules.crime
	eq(cr.records.size(), 1, "furto registrado")
	check(cr.records[0].witnesses.is_empty(), "sem testemunhas de madrugada")
	var investigated := false
	for d in 25:
		var r := WorldHelpers.advance_hours(w, 24)
		if not WorldHelpers.events_of(r, "CRIME_INVESTIGATED").is_empty(): investigated = true
		if cr.records[0].known_by_authority: break
	check(investigated, "a Guarda investigou depois de saber pelo rumor")


func test_economia_mensageira_entrega_e_preco_cai() -> void:
	var w := WorldHelpers.world(7)
	Prototypes.apply("economia", w)
	var eco: EconomyModule = w.modules.economy
	w.clock.tick = 4 * 144 + 23 * 6
	var npcs: NpcModule = w.modules.npcs
	npcs.state.saria.location = "valkaria"
	var before := eco.price("corda")
	var delivered := false
	for h in 3:
		var r := WorldHelpers.advance_hours(w, 1)
		if not WorldHelpers.events_of(r, "TRADE_DELIVERED").is_empty(): delivered = true
	check(delivered, "Saria trouxe mercadoria de Valkaria")
	check(eco.price("corda") <= before, "preço não sobe com mais estoque")


func test_ia_local_muda_so_o_texto() -> void:
	var p := LocalEchoProvider.new()
	var t := p.verbalize("elsa", "Fale rápido.", {"profession": "capitã da guarda"})
	check(t.ends_with("Fale rápido."), "conteúdo preservado")
	check(t != "Fale rápido.", "tom alterado")


func test_aventureiros_npc_progridem_pelas_regras_e_ritmo_mostra_vinheta() -> void:
	var w := _w("aventureiros")
	var adv: AdventurersModule = w.modules.adventurers
	check(not adv.history.is_empty(), "missões aconteceram em 30 dias")
	for h in adv.history:
		var mult: float = {"vitoria": 1.0, "empate": 0.5, "derrota": 0.25}[h.result]
		check(h.xp_each <= int(float(h.nd) * 1000.0 * mult) + 1, "XP nunca acima da regra do LB")
	var pac: PacingModule = w.modules.pacing
	w.clock.tick = (w.clock.tick / 144) * 144 + 6 * 8
	var npcs: NpcModule = w.modules.npcs
	for id in npcs.state: npcs.state[id].location = npcs.desired_location(id)
	WorldHelpers.put(w, 23, 27)
	var c := pac.candidates()
	check(c.all(func(x): return x.has("text")), "vinhetas só com condições reais")


func test_biografia_deterministica_e_coerente() -> void:
	var db := ContentDB.load_default()
	var b1 := Biography.for_npc(db.npc_def("teodoro"), 7)
	eq(Biography.for_npc(db.npc_def("teodoro"), 7), b1, "determinística")
	check(b1.begins_with("Teodoro"), "começa pelo nome")
	check(not Biography.for_npc(db.npc_def("nina"), 7).contains("trabalha"), "criança de 9 anos não tem profissão adulta")
