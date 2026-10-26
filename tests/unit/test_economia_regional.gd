extends TestCase
## Arton Viva, Fase 4: uma rota interrompida muda a economia de forma rastreável e reversível.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 12 * 6
	return w


func _courier(w: WorldState) -> Dictionary:
	return w.db.distant.regions[0]


func _chegada(w: WorldState) -> GameEvent:
	var r := _courier(w)
	return GameEvent.create("chegada_%d" % w.clock.tick, "NPC_MOVED", w.clock.tick, {"npc": r.courier, "from": r.id, "to": "vila"})


func _fecha_rota(w: WorldState, aberta: bool) -> void:
	var eco: EconomyModule = w.modules.economy
	eco.on_event(GameEvent.create("rota_%s_%d" % [str(aberta), w.clock.tick], "DISTANT_EVENT", w.clock.tick,
		{"region": "valkaria", "event": "bloqueio_estrada", "effect": {"route": {"id": "valkaria_vila", "open": aberta}}, "news": ""}))


func test_rota_fechada_nao_entrega_carga() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	_fecha_rota(w, false)
	var antes := int(eco.regions.vila.stock.remedio)
	var out := eco.on_event(_chegada(w))
	eq(out.size(), 0, "com a rota fechada, o mensageiro não entrega")
	eq(int(eco.regions.vila.stock.remedio), antes, "estoque da vila não muda com a rota fechada")


func test_rota_reaberta_volta_a_entregar_sem_perda() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	_fecha_rota(w, false)
	eco.on_event(_chegada(w))
	var fechada := int(eco.regions.vila.stock.remedio)
	_fecha_rota(w, true)
	var out := eco.on_event(_chegada(w))
	check(out.size() > 0, "com a rota reaberta, a carga volta a chegar")
	check(int(eco.regions.vila.stock.remedio) > fechada, "a entrega reaberta repõe o estoque (%d > %d)" % [int(eco.regions.vila.stock.remedio), fechada])


func test_mudanca_de_rota_gera_fato_rastreavel() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	var out := eco.on_event(GameEvent.create("r1", "DISTANT_EVENT", 0,
		{"region": "valkaria", "effect": {"route": {"id": "valkaria_vila", "open": false}}}))
	eq(out.size(), 1, "fechar a rota gera um fato")
	eq(out[0].type, "ROUTE_CHANGED", "o fato diz que a rota mudou")
	eq(out[0].payload.open, false, "e informa que está fechada")
