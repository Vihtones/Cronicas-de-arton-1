extends TestCase

const SHIFT_SHORT := 3
## Arton Viva, Fase 1: o trabalho dos moradores produz mercadoria na economia da vila.
## Um turno completo no posto (SHIFT_MIN_HOURS) gera WORK_DONE com o bem da profissão; a economia soma o bem
## ao estoque; turno curto ou profissão sem bem não produz; o turno sobrevive a salvar e carregar.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 6 * 6
	return w


## Passa um expediente no posto (8h às 17h) e coleta os fatos da virada das 18h.
func _expediente(w: WorldState, npc: String, horas: int) -> Array:
	var nd: NpcNeedsModule = w.modules.npc_needs
	var npcs: NpcModule = w.modules.npcs
	var out: Array = []
	for i in range(horas):
		var h := 8 + i
		w.clock.tick = h * 6
		npcs.state[npc].location = str(w.npc_def(npc).get("work", ""))
		nd.on_tick(w.clock.tick)
	w.clock.tick = 18 * 6
	npcs.state[npc].location = str(w.npc_def(npc).get("work", ""))
	out = nd.on_tick(w.clock.tick)
	return out


## Fatos do tipo dado para um morador. on_tick percorre a vila inteira, então filtra-se pelo autor.
func _achados(facts: Array, tipo: String, npc: String) -> Array:
	return facts.filter(func(f): return f.type == tipo and str(f.payload.get("npc", "")) == npc)


func test_turno_completo_produz_o_bem_da_profissao() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.1, "tired": 0.1, "gold": 0, "goal": "", "medium": "", "long": "", "shift": 0}
	var facts := _expediente(w, "garrick", 10)
	var prod := _achados(facts, "WORK_DONE", "garrick")
	eq(prod.size(), 1, "um turno completo gera um WORK_DONE")
	if prod.size() == 1:
		eq(str(prod[0].payload.good), "ferramentas", "ferreiro produz ferramentas")
		eq(int(prod[0].payload.amount), 1, "uma unidade por turno")


func test_turno_curto_nao_produz() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.1, "tired": 0.1, "gold": 0, "goal": "", "medium": "", "long": "", "shift": 0}
	var facts := _expediente(w, "garrick", SHIFT_SHORT)
	eq(_achados(facts, "WORK_DONE", "garrick").size(), 0, "menos de %d horas no posto não produz" % NpcNeedsModule.SHIFT_MIN_HOURS)


func test_profissao_sem_bem_nao_produz() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.hilda = {"hunger": 0.1, "tired": 0.1, "gold": 0, "goal": "", "medium": "", "long": "", "shift": 0}
	var facts := _expediente(w, "hilda", 10)
	eq(_achados(facts, "WORK_DONE", "hilda").size(), 0, "fiandeira ainda não produz mercadoria")


func test_todo_bem_produzido_existe_no_estoque_da_vila() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	eco._ensure()
	var mapa: Dictionary = w.db.economy.get("producao_trabalho", {})
	check(not mapa.is_empty(), "economy.json tem producao_trabalho")
	for prof in mapa:
		if str(prof).begins_with("_"):
			continue
		check(eco.regions.vila.stock.has(str(mapa[prof])), "bem '%s' (de %s) existe no estoque da vila" % [mapa[prof], prof])


func test_economia_soma_o_bem_produzido() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	eco._ensure()
	var antes := int(eco.regions.vila.stock.ferramentas)
	eco.on_event(GameEvent.create("wd1", "WORK_DONE", 0, {"npc": "garrick", "good": "ferramentas", "amount": 1}))
	eq(int(eco.regions.vila.stock.ferramentas), antes + 1, "o turno do ferreiro soma uma ferramenta ao estoque")


func test_turno_sobrevive_a_salvar_e_carregar() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.garrick = {"hunger": 0.1, "tired": 0.1, "gold": 0, "goal": "", "medium": "", "long": "", "shift": 0}
	for i in range(4):
		w.clock.tick = (8 + i) * 6
		w.modules.npcs.state.garrick.location = "ferraria"
		nd.on_tick(w.clock.tick)
	var snap := w.to_snapshot()
	var c := WorldHelpers.world(1)
	c.from_snapshot(snap)
	eq(int(c.modules.npc_needs.state.garrick.shift), 4, "horas do turno sobrevivem ao salvar")


func test_juntando_ouro_o_almoco_fica_no_posto() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	w.clock.tick = 12 * 6  # almoço: a agenda do moleiro manda para a taverna
	nd.state.otto = {"hunger": 0.1, "tired": 0.1, "gold": 2, "goal": "", "medium": "", "long": "", "shift": 0}
	eq(w.modules.npcs.desired_location("otto"), "moinho", "sem urgência, o morador que junta ouro segue no posto")


func test_fome_no_almoco_ainda_leva_a_taverna() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	w.clock.tick = 12 * 6
	nd.state.otto = {"hunger": 0.9, "tired": 0.1, "gold": 5, "goal": "", "medium": "", "long": "", "shift": 0}
	nd.on_tick(w.clock.tick)
	eq(w.modules.npcs.desired_location("otto"), "taverna", "urgência de comer vence a utilidade do posto")


func test_meta_de_ouro_batida_volta_a_agenda_normal() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	w.clock.tick = 12 * 6
	nd.state.otto = {"hunger": 0.1, "tired": 0.1, "gold": 20, "goal": "", "medium": "", "long": "", "shift": 0}
	nd.on_tick(w.clock.tick)
	eq(w.modules.npcs.desired_location("otto"), "taverna", "sem objetivo de ouro, segue a agenda (almoço)")


func test_afeto_alto_leva_a_visita_no_tempo_livre() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	var rel = w.modules.relations
	rel.rel.garrick = {"bento": {"afeto": 60.0}}
	w.modules.npcs.state.bento.location = "casa_vasquel"
	nd.state.garrick = {"hunger": 0.1, "tired": 0.1, "gold": 0, "goal": "", "medium": "", "long": "", "shift": 0}
	eq(nd.agenda_override("garrick", w.npc_def("garrick"), "praca", 20), "casa_vasquel", "amigo em casa: vai visitar")


func test_afeto_baixo_segue_o_lazer() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	w.modules.relations.rel.garrick = {"bento": {"afeto": 10.0}}
	w.modules.npcs.state.bento.location = "casa_vasquel"
	nd.state.garrick = {"hunger": 0.1, "tired": 0.1, "gold": 0, "goal": "", "medium": "", "long": "", "shift": 0}
	eq(nd.agenda_override("garrick", w.npc_def("garrick"), "praca", 20), "praca", "afeto pequeno não vence o lazer")


func test_amigo_fora_de_casa_nao_recebe_visita() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	w.modules.relations.rel.garrick = {"bento": {"afeto": 60.0}}
	w.modules.npcs.state.bento.location = "taverna"
	nd.state.garrick = {"hunger": 0.1, "tired": 0.1, "gold": 0, "goal": "", "medium": "", "long": "", "shift": 0}
	eq(nd.agenda_override("garrick", w.npc_def("garrick"), "praca", 20), "praca", "quem não está em casa não recebe visita")


func test_ferramenta_pela_historia_do_oficio() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.gold("garrick")  # força a criação do estado
	eq(nd.owns_tools("garrick"), true, "ferreiro de 40 anos, há 24 no ofício, já tem as ferramentas")
	eq(nd.owns_tools("joran"), true, "lavrador de 60 anos tem as ferramentas")
	eq(nd.owns_tools("davi"), false, "aprendiz de 15 anos ainda não tem")
	eq(nd.owns_tools("tomas"), false, "ajudante de 17 anos (um ano no ofício) ainda não tem")


func test_aprendiz_com_ouro_vai_ao_mercado_no_tempo_livre() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.davi = {"hunger": 0.1, "tired": 0.1, "gold": 8, "goal": "", "medium": "", "long": "", "shift": 0, "tools": false}
	eq(nd.agenda_override("davi", w.npc_def("davi"), "praca", 20), nd.tool_shop_location(), "sem ferramenta e com ouro, vai ao mercado")


func test_sem_ouro_suficiente_nao_vai_ao_mercado() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.davi = {"hunger": 0.1, "tired": 0.1, "gold": 5, "goal": "", "medium": "", "long": "", "shift": 0, "tools": false}
	eq(nd.agenda_override("davi", w.npc_def("davi"), "praca", 20), "praca", "com ouro abaixo do preço, segue o lazer")


func test_compra_no_mercado_tira_ouro_e_passa_a_ter_ferramenta() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	var eco: EconomyModule = w.modules.economy
	eco._ensure()
	var estoque := int(eco.regions.vila.stock.ferramentas)
	nd.state.davi = {"hunger": 0.1, "tired": 0.1, "gold": 8, "goal": "", "medium": "", "long": "", "shift": 0, "tools": false}
	w.modules.npcs.state.davi.location = nd.tool_shop_location()
	w.clock.tick = 20 * 6
	var facts := nd.on_tick(w.clock.tick)
	var compra := facts.filter(func(f): return f.type == "TOOL_BOUGHT")
	eq(compra.size(), 1, "comprar gera TOOL_BOUGHT")
	eq(nd.gold("davi"), 0, "o ouro é gasto")
	check(nd.owns_tools("davi"), "passa a ter a ferramenta")
	for f in compra:
		eco.on_event(GameEvent.create("tb", "TOOL_BOUGHT", 0, f.payload))
	eq(int(eco.regions.vila.stock.ferramentas), estoque - 1, "a vila perde uma ferramenta do estoque")
