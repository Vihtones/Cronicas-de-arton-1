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
