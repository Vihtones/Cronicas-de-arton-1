extends TestCase
## Arton Viva, Fase 4: a segunda rota (Sambúrdia) traz remédio sem depender da rota de Valkaria.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 12 * 6
	return w


func _sambur(w: WorldState) -> Dictionary:
	for r in w.db.distant.regions:
		if r.id == "samburdia":
			return r
	return {}


func _chegada(w: WorldState, de: String, mensageiro: String) -> GameEvent:
	return GameEvent.create("chegada_%s_%d" % [de, w.clock.tick], "NPC_MOVED", w.clock.tick, {"npc": mensageiro, "from": de, "to": "vila"})


func _rota(w: WorldState, id: String, aberta: bool) -> void:
	var eco: EconomyModule = w.modules.economy
	eco.on_event(GameEvent.create("rota_%s_%s" % [id, str(aberta)], "DISTANT_EVENT", w.clock.tick,
		{"region": "samburdia", "event": "estrada", "effect": {"route": {"id": id, "open": aberta}}, "news": ""}))


func test_rotas_vem_dos_dados() -> void:
	var eco: EconomyModule = _world().modules.economy
	eco._ensure()
	check(eco.routes.has("samburdia_vila"), "rota de Sambúrdia carregada de economy.json")
	check(eco.routes.has("valkaria_vila"), "rota de Valkaria continua presente")
	eq(eco.routes.samburdia_vila.from, "samburdia", "rota parte de Sambúrdia")


func test_mensageiro_de_samburdia_traz_remedio() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	var r := _sambur(w)
	check(not r.is_empty(), "Sambúrdia existe em distant.json")
	eco.regions.vila.stock.remedio = 0
	var antes_vila := int(eco.regions.vila.stock.remedio)
	var antes_sam := int(eco.regions.samburdia.stock.remedio)
	var out := eco.on_event(_chegada(w, r.id, r.courier))
	check(out.size() == 1 and out[0].type == "TRADE_DELIVERED", "chegada entrega carga")
	check(int(eco.regions.vila.stock.remedio) > antes_vila, "vila recebe remédio")
	eq(int(eco.regions.samburdia.stock.remedio), antes_sam - (int(eco.regions.vila.stock.remedio) - antes_vila), "remédio sai de Sambúrdia sem criar nem perder")


func test_rota_de_samburdia_fechada_nao_entrega_e_nao_afeta_valkaria() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	var r := _sambur(w)
	_rota(w, "samburdia_vila", false)
	eq(eco.routes.samburdia_vila.open, false, "rota de Sambúrdia fechada")
	eq(eco.routes.valkaria_vila.open, true, "rota de Valkaria segue aberta")
	eco.regions.vila.stock.remedio = 0
	var out := eco.on_event(_chegada(w, r.id, r.courier))
	eq(out.size(), 0, "com a rota fechada, o mensageiro não entrega")


func test_rota_fechada_sobrevive_a_salvar_e_carregar() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	_rota(w, "samburdia_vila", false)
	var d := eco.to_dict()
	var w2 := _world()
	var eco2: EconomyModule = w2.modules.economy
	eco2.from_dict(d)
	eq(eco2.routes.samburdia_vila.open, false, "estado da rota persiste no save")


func test_cronica_registra_rota_com_nome_e_entrega() -> void:
	var w := _world()
	var r := _sambur(w)
	var eco: EconomyModule = w.modules.economy
	var cronica: ChronicleModule = w.modules.chronicle
	for f in eco.on_event(GameEvent.create("fecha_cronica", "DISTANT_EVENT", w.clock.tick,
			{"region": "samburdia", "event": "estrada", "effect": {"route": {"id": "samburdia_vila", "open": false}}, "news": ""})):
		cronica.on_event(GameEvent.create("f_%s" % f.type, f.type, w.clock.tick, f.payload))
	var textos: Array = cronica.entries.map(func(e): return e.text)
	check(textos.any(func(t): return str(t).contains("estrada de Sambúrdia foi fechada")), "a crônica diz o nome da estrada fechada")
	eco.regions.vila.stock.comida = 0
	_rota(w, "samburdia_vila", true)
	var fato: Array = eco.on_event(_chegada(w, r.id, r.courier))
	for f in fato:
		cronica.on_event(GameEvent.create("f_%s" % f.type, f.type, w.clock.tick, f.payload))
	var textos2: Array = cronica.entries.map(func(e): return e.text)
	check(textos2.any(func(t): return str(t).contains("Tarso Pedrada trouxe mercadoria de fora")), "a crônica registra a entrega do mensageiro")


func test_madeira_vem_de_samburdia_quando_a_vila_fica_sem() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	var r := _sambur(w)
	eco._ensure()
	eco.regions.vila.stock.madeira = 0
	var sam_antes := int(eco.regions.samburdia.stock.madeira)
	var out: Array = eco.on_event(_chegada(w, r.id, r.courier))
	check(out.size() == 1 and out[0].type == "TRADE_DELIVERED", "a chegada traz carga")
	var carga: Dictionary = out[0].payload.goods if out.size() == 1 else {}
	check(carga.has("madeira") and int(carga.madeira) > 0, "a carga inclui madeira: %s" % str(carga))
	eq(int(eco.regions.samburdia.stock.madeira), sam_antes - int(carga.get("madeira", 0)), "madeira sai de Sambúrdia na mesma quantidade")
	check(int(eco.regions.vila.stock.madeira) > 0, "a vila recebe madeira")
	eq(eco.GOOD_NAMES.get("madeira", ""), "madeira", "madeira tem nome de exibição")


func test_resumo_das_rotas_segue_a_chegada_do_mensageiro() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	var resumo: Array = eco.route_summary()
	var sam: Dictionary = {}
	for rota in resumo:
		if rota.id == "samburdia_vila":
			sam = rota
	check(not sam.is_empty(), "resumo traz a rota de Sambúrdia")
	eq(sam.mensageiro, "Tarso Pedrada", "resumo traz o nome do mensageiro")
	var pos: int = w.day_index() % 6
	eq(bool(sam.na_vila), pos < 2, "na vila quando dia % 6 < 2 (dia %d)" % w.day_index())
	check(int(sam.dias) >= 1, "dias até sair ou chegar são positivos")
	eq(bool(sam.aberta), true, "rota começa aberta")
