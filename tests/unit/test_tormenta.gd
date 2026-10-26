extends TestCase
## Arton Viva, Fase 7: a Tormenta só avança com incidente sobrenatural, e a contenção depende da Guarda.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 12 * 6
	return w


func _dia(w: WorldState, n: int = 1) -> Array:
	var t: TormentaModule = w.modules.tormenta
	var out: Array = []
	for i in n:
		w.clock.tick += 24 * 6
		out += t.on_event(GameEvent.create("dia_%d" % w.clock.tick, "TIME_ADVANCED", w.clock.tick, {"tick": w.clock.tick}))
	return out


func test_pobreza_e_vulnerabilidade_nao_geram_tormenta() -> void:
	var w := _world()
	var t: TormentaModule = w.modules.tormenta
	_dia(w, 10)
	eq(t.stage, 0, "sem incidente sobrenatural, o mundo fica estável")
	eq(t.corruption, 0.0, "nenhuma corrupção sem causa sobrenatural")


func test_incidente_sobe_a_pressao_e_a_corrupcao_avanca_por_estagios() -> void:
	var w := _world()
	var t: TormentaModule = w.modules.tormenta
	t.on_event(GameEvent.create("inc1", "MAGIC_INCIDENT", w.clock.tick, {"pressure": 40}))
	var fatos := _dia(w, 6)
	check(t.corruption > 0.0, "o incidente deixa corrupção")
	check(t.stage >= 1, "o estágio sobe com a corrupção acumulada (estágio %d)" % t.stage)
	check(fatos.size() > 0, "as mudanças de estágio saem como fatos")


func test_contencao_reduz_pressao_e_gasta_soldados() -> void:
	var w := _world()
	var t: TormentaModule = w.modules.tormenta
	var f = w.modules.factions
	t.on_event(GameEvent.create("inc2", "MAGIC_INCIDENT", w.clock.tick, {"pressure": 40}))
	var antes := int(f.resources.guarda_vila.soldados)
	var r := WorldHelpers.cmd(w, "ContainTormenta", {})
	check(r.accepted, "a Guarda pode conter a pressão")
	eq(int(f.resources.guarda_vila.soldados), antes - TormentaModule.CONTAIN_COST, "conter gasta soldados")
	check(t.pressure < 40.0, "a pressão cai com a contenção")


func test_sem_pressao_nao_ha_o_que_conter() -> void:
	var w := _world()
	var r := WorldHelpers.cmd(w, "ContainTormenta", {})
	check(not r.accepted, "sem pressão, não há contenção")


func test_crise_tira_comida_da_vila() -> void:
	var w := _world()
	var t: TormentaModule = w.modules.tormenta
	var eco: EconomyModule = w.modules.economy
	t.stage = 3
	var antes := int(eco.regions.vila.stock.comida)
	eco.on_event(GameEvent.create("tdia", "TORMENTA_DAY", w.clock.tick, {"stage": 3}))
	check(int(eco.regions.vila.stock.comida) < antes, "em crise, a comida da vila diminui")
