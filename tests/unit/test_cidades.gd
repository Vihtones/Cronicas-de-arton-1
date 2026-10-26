extends TestCase
## Arton Viva, Fase 5: sucessão de liderança e decadência/recuperação da cidade, sem o jogador.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 12 * 6
	return w


func _morte(w: WorldState, id: String) -> Array:
	var ci: CitiesModule = w.modules.cities
	return ci.on_event(GameEvent.create("morte_" + id, "NPC_DIED", w.clock.tick, {"npc": id, "cause": "teste"}))


func _dia(w: WorldState, index: float) -> Array:
	var ci: CitiesModule = w.modules.cities
	var eco: EconomyModule = w.modules.economy
	for g in eco.regions.vila.stock:
		eco.regions.vila.stock[g] = int(round(float(eco.regions.vila.target[g]) * index))
	return ci.on_event(GameEvent.create("dia_%f" % index, "ECONOMY_DAY", w.clock.tick, {}))


func test_lider_morto_e_sucedido_pelo_membro_mais_velho_vivo() -> void:
	var w := _world()
	var ci: CitiesModule = w.modules.cities
	eq(ci.leader_of("guarda_vila"), "orin", "o alcaide é o líder mais velho da guarda")
	var out := _morte(w, "orin")
	eq(ci.leader_of("guarda_vila"), "elsa", "com orin morto, assume a capitã Elsa (45 anos, a mais velha viva)")
	eq(out[0].type, "LEADERSHIP_CHANGED", "a troca de liderança sai como fato")


func test_organizacao_sem_membro_vivo_fica_fragmentada() -> void:
	var w := _world()
	var ci: CitiesModule = w.modules.cities
	var out := _morte(w, "dorn")
	eq(ci.leader_of("garras_de_cinza"), "", "sem membro vivo, não há líder")
	eq(out[0].payload.status, "fragmentada", "a organização fica fragmentada, sem travar o mundo")


func test_abastecimento_baixo_por_dias_leva_a_decadencia_e_a_recuperacao() -> void:
	var w := _world()
	var ci: CitiesModule = w.modules.cities
	var fatos: Array = []
	for i in CitiesModule.DECLINE_AFTER_DAYS:
		fatos += _dia(w, 0.1)
	eq(ci.city_status, "em_decadencia", "dias seguidos de escassez derrubam a cidade")
	check(fatos.size() == 1 and fatos[0].type == "CITY_STATUS_CHANGED", "a decadência sai como fato")
	for i in 4:
		_dia(w, 1.0)
	eq(ci.city_status, "estavel", "com abastecimento bom, a cidade se recupera sem o jogador")


func test_indicadores_urbanos_refletem_o_mundo() -> void:
	var w := _world()
	var ci: CitiesModule = w.modules.cities
	var eco: EconomyModule = w.modules.economy
	var ind := ci.indicators()
	for k in ["abastecimento", "saude", "prosperidade", "estabilidade"]:
		check(ind[k] >= 0.0 and ind[k] <= 1.0, "%s fica entre 0 e 1" % k)
	eco.regions.vila.stock.remedio = 0
	eq(ci.indicators().saude, 0.0, "sem remédio, a saúde da vila cai a zero")
