extends TestCase
## Arton Viva, Fase 1: o morador identifica uma necessidade, escolhe uma ação, executa e muda seu estado.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 6 * 12
	return w


func test_fome_cresce_com_o_tempo_e_vira_objetivo() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.69, "tired": 0.0, "gold": 10, "goal": ""}
	nd.on_tick(w.clock.tick)
	eq(nd.goal("garrick"), "comer", "com fome alta, o objetivo vira comer")
	check(nd.hunger("garrick") >= 0.7, "fome continua alta (%.2f)" % nd.hunger("garrick"))


func test_comer_na_taverna_cobra_ouro_e_reduz_fome() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.9, "tired": 0.0, "gold": 5, "goal": "comer"}
	nd.eat("garrick")
	eq(nd.gold("garrick"), 5 - NpcNeedsModule.MEAL_COST, "refeição custa ouro")
	check(nd.hunger("garrick") < 0.9, "fome cai depois de comer")


func test_sem_ouro_nao_vai_a_taverna_e_fome_continua() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.9, "tired": 0.0, "gold": 0, "goal": "comer"}
	var d := w.npc_def("garrick")
	eq(nd.location_override("garrick", d), "", "sem ouro, não há lugar de refeição")
	nd.eat("garrick")
	check(nd.hunger("garrick") >= 0.9, "sem ouro, a fome não cai")


func test_cansaco_manda_descansar_em_casa() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.0, "tired": 0.9, "gold": 0, "goal": ""}
	nd.on_tick(w.clock.tick)
	eq(nd.goal("garrick"), "descansar", "cansado vira objetivo descansar")
	eq(nd.location_override("garrick", w.npc_def("garrick")), str(w.npc_def("garrick").home), "descansar = ir para casa")


func test_guarda_nao_sai_do_posto_por_necessidade() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.elsa = {"hunger": 1.0, "tired": 1.0, "gold": 50, "goal": "comer"}
	eq(nd.location_override("elsa", w.npc_def("elsa")), "", "guarda cumpre o posto mesmo com fome")


func test_sem_necessidade_nao_ha_objetivo() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.1, "tired": 0.1, "gold": 10, "goal": ""}
	nd.on_tick(w.clock.tick)
	eq(nd.goal("garrick"), "", "tranquilo, segue a agenda")


func test_objetivo_muda_o_lugar_do_morador() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	var npcs: NpcModule = w.modules.npcs
	nd.state.garrick = {"hunger": 0.95, "tired": 0.0, "gold": 10, "goal": "comer"}
	eq(npcs.desired_location("garrick"), "taverna", "com fome e ouro, a agenda passa pela taverna")


func test_necessidades_salvam_e_carregam() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.5, "tired": 0.3, "gold": 7, "goal": ""}
	var snap := w.to_snapshot()
	var w2 := WorldHelpers.world(1)
	w2.from_snapshot(snap)
	eq(w2.modules.npc_needs.gold("garrick"), 7, "ouro salvo")
	eq(w2.modules.npc_needs.hunger("garrick"), 0.5, "fome salva")


func test_utilidade_escolhe_a_necessidade_mais_forte() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.95, "tired": 0.82, "gold": 10, "goal": "", "medium": ""}
	nd.on_tick(12 * 6)
	eq(nd.goal("garrick"), "comer", "com fome maior que o cansaço, comer vence")


func test_cansaco_maior_que_fome_vence() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.72, "tired": 0.95, "gold": 10, "goal": "", "medium": ""}
	nd.on_tick(12 * 6)
	eq(nd.goal("garrick"), "descansar", "com cansaço maior que a fome, descansar vence")


func test_sem_urgencia_o_objetivo_de_medio_prazo_e_juntar_ouro() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.1, "tired": 0.1, "gold": 3, "goal": "", "medium": ""}
	nd.on_tick(12 * 6)
	eq(nd.medium_goal("garrick"), "juntar_ouro", "pouco ouro e sem urgência, junta ouro")
	eq(nd.goal("garrick"), "", "o médio prazo não vira objetivo de curto prazo")


func test_meta_de_ouro_atingida_encerra_o_objetivo_de_medio_prazo() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.1, "tired": 0.1, "gold": NpcNeedsModule.MEDIUM_TARGET_GOLD, "goal": "", "medium": "juntar_ouro"}
	nd.on_tick(12 * 6)
	eq(nd.medium_goal("garrick"), "", "com a meta batida, o objetivo de médio prazo some")


func test_trabalho_no_horario_rende_ouro_enquanto_junta() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	var npcs: NpcModule = w.modules.npcs
	var d := w.npc_def("garrick")
	npcs.state.garrick.location = str(d.work)
	w.clock.tick = 10 * 6
	nd.state.garrick = {"hunger": 0.1, "tired": 0.1, "gold": 3, "goal": "", "medium": ""}
	nd.on_tick(w.clock.tick)
	eq(nd.gold("garrick"), 3 + NpcNeedsModule.WORK_INCOME, "trabalhar às 10h rende ouro")


func test_fora_do_horario_de_trabalho_nao_rende_ouro() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	var npcs: NpcModule = w.modules.npcs
	var d := w.npc_def("garrick")
	npcs.state.garrick.location = str(d.work)
	w.clock.tick = 20 * 6
	nd.state.garrick = {"hunger": 0.1, "tired": 0.1, "gold": 3, "goal": "", "medium": ""}
	nd.on_tick(w.clock.tick)
	eq(nd.gold("garrick"), 3, "às 20h o trabalho não rende ouro")


func test_objetivo_de_medio_prazo_salva_e_carrega() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.1, "tired": 0.1, "gold": 3, "goal": "", "medium": "juntar_ouro"}
	var w2 := WorldHelpers.world(1)
	w2.from_snapshot(w.to_snapshot())
	eq(w2.modules.npc_needs.medium_goal("garrick"), "juntar_ouro", "médio prazo salvo")
