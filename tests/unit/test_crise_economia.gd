extends TestCase
## Arton Viva, Fase 4: crise de escassez explícita, com recuperação pela própria produção e registro no diário.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 12 * 6
	w.modules.economy._ensure()
	return w


func _dia(w: WorldState, k: int) -> Array:
	return w.modules.economy.on_tick(144 * k)


func _achados(facts: Array, tipo: String) -> Array:
	return facts.filter(func(f): return f.type == tipo and str(f.payload.get("good", "")) == "comida")


func test_falta_comeca_uma_vez() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	eco.regions.vila.stock.comida = 10
	eq(_achados(_dia(w, 1), "SHORTAGE_STARTED").size(), 1, "estoque baixo começa a falta de comida")
	eq(_achados(_dia(w, 2), "SHORTAGE_STARTED").size(), 0, "a falta não é anunciada de novo a cada dia")
	check(bool(eco.shortage.get("comida", false)), "a vila fica marcada em falta")


func test_falta_termina_sozinha_pela_producao() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	eco.regions.vila.stock.comida = 10
	var acabou := -1
	for k in range(1, 200):
		var achados := _achados(_dia(w, k), "SHORTAGE_ENDED")
		if not achados.is_empty():
			acabou = k
			break
	check(acabou > 0, "a produção da vila recupera o estoque sem o jogador (dia %d)" % acabou)
	check(int(eco.regions.vila.stock.comida) >= int(0.7 * float(eco.regions.vila.target.comida)), "ao terminar, o estoque está acima de 70% da meta")
	check(not bool(eco.shortage.get("comida", false)), "a vila sai da falta")


func test_histerese_nao_oscila() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	eco.regions.vila.stock.comida = 10
	_dia(w, 1)
	# estoque na faixa entre 30% e 70% da meta: continua em falta (não termina antes de 70%)
	eco.regions.vila.stock.comida = 60
	eq(_achados(_dia(w, 2), "SHORTAGE_ENDED").size(), 0, "entre 30% e 70% da meta, a falta continua")
	check(bool(eco.shortage.get("comida", false)), "ainda em falta na faixa intermediária")


func test_falta_sobrevive_a_salvar_e_carregar() -> void:
	var w := _world()
	w.modules.economy.regions.vila.stock.comida = 10
	_dia(w, 1)
	var snap := w.to_snapshot()
	var c := WorldHelpers.world(1)
	c.from_snapshot(snap)
	check(bool(c.modules.economy.shortage.get("comida", false)), "a falta de comida sobrevive ao salvamento")


func test_diario_registra_a_falta() -> void:
	var w := _world()
	var cr = w.modules.chronicle
	cr.on_event(GameEvent.create("sh1", "SHORTAGE_STARTED", 72, {"good": "comida", "stock": 10, "target": 120}))
	var achou := false
	for e in cr.entries:
		if str(e.text).contains("Está faltando comida"):
			achou = true
	check(achou, "o diário conta que está faltando comida na vila")


func test_refeicao_custa_o_dobro_na_falta_de_comida() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	var nd: NpcNeedsModule = w.modules.npc_needs
	eq(nd.meal_cost(), NpcNeedsModule.MEAL_COST, "sem falta, a refeição custa o preço normal")
	eco.shortage.comida = true
	eq(nd.meal_cost(), NpcNeedsModule.MEAL_COST * NpcNeedsModule.SHORTAGE_MEAL_MULT, "na falta, a refeição custa o dobro")


func test_morador_sem_ouro_para_a_refeicao_na_falta_fica_sem_comer() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	var nd: NpcNeedsModule = w.modules.npc_needs
	var ouro := NpcNeedsModule.MEAL_COST + 1  # dá para pagar o preço normal, não o da falta
	nd.state.garrick = {"hunger": 0.9, "tired": 0.1, "gold": ouro, "goal": "comer", "medium": "", "long": "", "shift": 0}
	eq(nd.location_override("garrick", w.npc_def("garrick")), "taverna", "sem falta, vai comer na taverna")
	eco.shortage.comida = true
	eq(nd.location_override("garrick", w.npc_def("garrick")), "", "na falta, sem o preço dobrado, não vai comer")
	var antes := nd.hunger("garrick")
	nd.on_tick(w.clock.tick)
	check(nd.hunger("garrick") > antes, "a fome continua subindo sem dinheiro para a refeição")
