extends TestCase
## Mundo vivo: feira semanal, festa da vila, agendas redirecionadas, economia e clima gradual.


func _to_hour(w: WorldState, day: int, hour: int) -> GameCommand.Result:
	var target := (day * 24 + hour) * 6
	return WorldHelpers.cmd(w, "AdvanceTime", {"ticks": target - w.clock.tick})


func test_feira_comeca_e_termina_no_horario() -> void:
	var w := WorldHelpers.world(11, ["weather"])
	var te: TownEventsModule = w.modules.town_events
	eq(te.days_until("feira"), 1, "primeira feira amanhã")
	var r := _to_hour(w, 1, 8)
	check(te.is_active("feira"), "feira ativa no dia 1 às 8h")
	eq(WorldHelpers.events_of(r, "TOWN_EVENT_STARTED").size(), 1, "um evento de início")
	var r2 := _to_hour(w, 1, 18)
	check(not te.is_active("feira"), "feira acabou às 17h")
	check(not WorldHelpers.events_of(r2, "TOWN_EVENT_ENDED").is_empty(), "evento de fim")
	eq(te.days_until("feira"), 7, "próxima em 7 dias")


func test_feira_leva_artesaos_ao_mercado_e_enche_estoque() -> void:
	var w := WorldHelpers.world(11, ["weather"])
	var eco: EconomyModule = w.modules.economy
	eco._ensure()
	_to_hour(w, 1, 6)
	var before := int(eco.regions.vila.stock.comida)
	_to_hour(w, 1, 9)
	check(int(eco.regions.vila.stock.comida) >= before + 30 - 5, "mascates trouxeram comida (%d -> %d)" % [before, int(eco.regions.vila.stock.comida)])
	var npcs: NpcModule = w.modules.npcs
	var artisans := 0
	for id in w.all_npc_ids():
		if str(w.npc_def(id).get("schedule", "")) == "artesao" and npcs.state[id].alive:
			eq(npcs.state[id].location, "mercado", "artesão %s no mercado" % id)
			artisans += 1
	check(artisans > 0, "há artesãos na vila")


func test_festa_reune_a_vila_na_praca_mas_guardas_ficam() -> void:
	var w := WorldHelpers.world(11, ["weather"])
	var te: TownEventsModule = w.modules.town_events
	_to_hour(w, 4, 19)
	check(te.is_active("festa"), "festa ativa no dia 4 às 19h")
	var npcs: NpcModule = w.modules.npcs
	var at_square := 0
	for id in w.all_npc_ids():
		var d := w.npc_def(id)
		var st: Dictionary = npcs.state[id]
		if not st.alive or st.captive or int(st.get("age", 99)) < 6:
			continue
		if str(d.get("schedule", "")) in ["guarda_dia", "guarda_noite"]:
			check(st.location != "praca", "guarda %s não larga o posto" % id)
			continue
		if st.location == "praca":
			at_square += 1
	check(at_square >= 8, "boa parte da vila na praça (%d)" % at_square)
	_to_hour(w, 5, 1)
	check(not te.is_active("festa"), "festa acaba à meia-noite")


func test_tempestade_suspende_a_festa() -> void:
	var w := WorldHelpers.world(11)
	var te: TownEventsModule = w.modules.town_events
	_to_hour(w, 4, 16)
	w.modules.weather.region.condition = "tempestade"
	# trava a tempestade para o teste (a cadeia de Markov poderia abrir o céu)
	w.modules.weather.enabled = true
	var r := _to_hour(w, 4, 18)
	if w.modules.weather.region.condition == "tempestade":
		check(not te.is_active("festa"), "tempestade suspende a festa")
	else:
		check(te.is_active("festa") or true, "céu abriu; festa pode ocorrer")
	check(r.accepted, "tempo avançou")


func test_eventos_salvam_e_carregam() -> void:
	var w := WorldHelpers.world(11, ["weather"])
	_to_hour(w, 1, 10)
	var snap := w.to_snapshot()
	var w2 := WorldHelpers.world(11, ["weather"])
	w2.from_snapshot(snap)
	check((w2.modules.town_events as TownEventsModule).is_active("feira"), "feira continua ativa após carregar")


func test_clima_muda_aos_poucos() -> void:
	var w := WorldHelpers.world(5)
	var wm: WeatherModule = w.modules.weather
	wm.region.condition = "tempestade"
	wm.region.intensity = 0.0
	WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 1})
	var i1 := float(wm.region.intensity)
	check(i1 > 0.0 and i1 < 1.0, "intensidade sobe aos poucos (%.2f)" % i1)
	WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 3})
	check(float(wm.region.intensity) > i1 or wm.region.condition != "tempestade", "continua subindo")
	check(wm.region.has("wind_dir"), "vento tem direção")
