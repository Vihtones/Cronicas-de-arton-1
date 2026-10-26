extends TestCase
## Arton Viva, vertical slice "O futuro do aprendiz" (§23). Ciclo completo na vila existente:
## o aprendiz junta ouro e quer abrir oficina; a rota de ferramentas é cortada (preço sobe); o jogador
## protege a rota (reabre); o aprendiz reage à ajuda conforme a relação; a história é registrada;
## tudo sobrevive a salvar e carregar.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 8 * 6
	return w


func _trabalha_um_dia(w: WorldState) -> void:
	var nd: NpcNeedsModule = w.modules.npc_needs
	var npcs: NpcModule = w.modules.npcs
	for h in range(8, 18):
		w.clock.tick = h * 6
		npcs.state.davi.location = "ferraria"
		nd.on_tick(w.clock.tick)


## Entrega os fatos de um módulo aos ouvintes, como o barramento faria.
func _entrega(w: WorldState, facts: Array) -> void:
	for f in facts:
		var e := GameEvent.create("f_%s_%d" % [f.type, w.clock.tick], f.type, w.clock.tick, f.payload)
		w.modules.chronicle.on_event(e)


func test_aprendiz_junta_ouro_e_passa_a_querer_abrir_oficina() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.davi = {"hunger": 0.1, "tired": 0.1, "gold": 2, "goal": "", "medium": "", "long": ""}
	_trabalha_um_dia(w)
	_trabalha_um_dia(w)
	eq(nd.medium_goal("davi"), "", "com a meta de médio prazo batida, o objetivo de médio prazo some")
	eq(nd.long_goal("davi"), "abrir_negocio", "o aprendiz passa a querer abrir a oficina")


func test_corte_de_rota_encarece_as_ferramentas() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	var espada := "espada_curta"
	var antes := eco.price(espada)
	eco.on_event(GameEvent.create("corte", "DISTANT_EVENT", w.clock.tick, {"region": "valkaria", "effect": {"route": {"id": "valkaria_vila", "open": false}}}))
	for g in eco.regions.vila.stock:
		if g == "ferramentas":
			eco.regions.vila.stock[g] = 5
	check(eco.price(espada) > antes, "com a rota cortada e as ferramentas em falta, a espada sobe de preço (%d > %d)" % [eco.price(espada), antes])


func test_jogador_protege_a_rota_e_a_historia_registra() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	var cr: ChronicleModule = w.modules.chronicle
	_entrega(w, eco.on_event(GameEvent.create("corte", "DISTANT_EVENT", w.clock.tick, {"region": "valkaria", "effect": {"route": {"id": "valkaria_vila", "open": false}}})))
	_entrega(w, eco.on_event(GameEvent.create("protecao", "DISTANT_EVENT", w.clock.tick, {"region": "valkaria", "effect": {"route": {"id": "valkaria_vila", "open": true}}})))
	check(eco._route_open("valkaria"), "com a rota protegida, ela volta a abrir")
	eq(cr.by_category("economia").size(), 2, "a história guarda o corte e a reabertura")


func test_ajuda_do_jogador_muda_a_reacao_do_aprendiz() -> void:
	var w := _world()
	var rl: RelationsModule = w.modules.relations
	eq(rl.reaction("davi", "player"), "indiferente", "antes da ajuda, o aprendiz é indiferente")
	for i in 3:
		rl.on_event(GameEvent.create("ajuda%d" % i, "MEMORY_FORMED", w.clock.tick,
			{"npc": "davi", "about": "player", "subject": "davi", "valence": 20, "emotion": "gratidao"}))
	check(rl.reaction("davi", "player") != "indiferente", "depois de ajudado, o aprendiz reage diferente (%s)" % rl.reaction("davi", "player"))


func test_o_ciclo_sobrevive_a_salvar_e_carregar() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.davi = {"hunger": 0.1, "tired": 0.1, "gold": 2, "goal": "", "medium": "", "long": ""}
	_trabalha_um_dia(w)
	WorldHelpers.cmd(w, "SetHomebrew", {"id": "companheiros", "on": true})
	var w2 := WorldHelpers.world(1)
	w2.from_snapshot(w.to_snapshot())
	eq(WorldHelpers.snap(w2), WorldHelpers.snap(w), "o estado do ciclo é idêntico após o carregamento")
	WorldHelpers.advance_hours(w, 12)
	WorldHelpers.advance_hours(w2, 12)
	eq(WorldHelpers.snap(w2), WorldHelpers.snap(w), "e a simulação segue igual depois do carregamento")
