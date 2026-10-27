extends TestCase
## Arton Viva, Fase 5: a vila constrói com o próprio tesouro; segurança, moradia e influência reagem.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 12 * 6
	return w


func _build(w: WorldState, id: String):
	return w.apply_command(GameCommand.create("build_%s_%d" % [id, w.clock.tick], "player", "Build", {"id": id}))


func test_construir_sem_ouro_e_recusado() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	eco.treasury = 0
	var r = _build(w, "celeiro")
	check(not r.accepted, "sem ouro no tesouro, a construção é recusada")
	eq(w.modules.cities.built.get("celeiro", 0), 0, "nada foi construído")


func test_celeiro_cobra_do_tesouro_e_aumenta_a_producao() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	eco._ensure()
	eco.treasury = 300
	var prod_antes := int(eco.regions.vila.production.comida)
	var r = _build(w, "celeiro")
	check(r.accepted, "celeiro aceito com ouro: %s" % str(r.errors))
	eq(eco.treasury, 300 - 120, "o tesouro paga o custo do celeiro")
	eq(int(eco.regions.vila.production.comida), prod_antes + 6, "o celeiro soma 6 de comida por dia")
	eq(w.modules.cities.built.get("celeiro", 0), 1, "a cidade registra o celeiro")


func test_guarita_sobe_a_seguranca() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	eco.treasury = 300
	var cid = w.modules.cities
	var antes: float = cid.indicators().seguranca
	_build(w, "guarita")
	var depois: float = cid.indicators().seguranca
	check(depois > antes, "a guarita sobe a segurança (%.2f -> %.2f)" % [antes, depois])
	check(absf((depois - antes) - 0.2) < 0.02, "um guarda a mais vale 1/5 da segurança plena")


func test_casa_abre_vagas_e_a_moradia_sobe() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	eco.treasury = 300
	var cid = w.modules.cities
	var antes: float = cid.indicators().moradia
	check(antes < 1.0, "a casa de Aldren (5 moradores) está apertada: %.2f" % antes)
	_build(w, "casa")
	eq(cid.indicators().moradia, 1.0, "uma casa nova abre vagas e tira o aperto")


func test_crime_reduz_seguranca_e_decai_com_o_tempo() -> void:
	var w := _world()
	var cid = w.modules.cities
	var antes: float = cid.indicators().seguranca
	cid.on_event(GameEvent.create("crime_1", "CRIME_COMMITTED", w.clock.tick, {}))
	var depois: float = cid.indicators().seguranca
	check(depois < antes, "crime recente tira segurança (%.2f -> %.2f)" % [antes, depois])
	cid.on_event(GameEvent.create("dia_1", "ECONOMY_DAY", w.clock.tick, {"vila": {}, "treasury": 0}))
	eq(cid.recent_crimes, 0, "o crime sai da memória da cidade depois de um dia")
	check(absf(cid.indicators().seguranca - antes) < 0.01, "a segurança volta ao normal")


func test_influencia_fica_entre_zero_e_um() -> void:
	var w := _world()
	var v: float = w.modules.cities.indicators().influencia
	check(v >= 0.0 and v <= 1.0, "influência em 0 a 1: %.2f" % v)


func test_construcoes_sobrevivem_a_salvar_e_carregar() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	eco.treasury = 300
	_build(w, "celeiro")
	var d: Dictionary = w.modules.cities.to_dict()
	var w2 := _world()
	w2.modules.cities.from_dict(d)
	eq(w2.modules.cities.built.get("celeiro", 0), 1, "celeiro persiste no save")
