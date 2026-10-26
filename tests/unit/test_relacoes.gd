extends TestCase
## Arton Viva, Fase 2: relações com dimensões separadas e reações diferentes ao mesmo acontecimento.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 12 * 6
	return w


func _fato(who: String, about: String, valence: int, emotion: String) -> GameEvent:
	return GameEvent.create("mf_%s_%s_%d" % [who, about, valence], "MEMORY_FORMED", 0,
		{"npc": who, "about": about, "subject": "", "valence": valence, "emotion": emotion})


func test_mesmo_fato_gera_reacoes_diferentes_conforme_a_relacao_previa() -> void:
	var w := _world()
	var rl: RelationsModule = w.modules.relations
	rl.rel = {"garrick": {"player": {"confianca": 40.0, "afeto": 40.0, "familiaridade": 20.0}}}
	rl.on_event(_fato("garrick", "player", -10, "raiva"))
	rl.on_event(_fato("elsa", "player", -10, "raiva"))
	eq(rl.reaction("garrick", "player"), "amigavel", "quem já gostava do jogador continua amigável")
	eq(rl.reaction("elsa", "player"), "indiferente", "quem não o conhecia reage com indiferença")


func test_teimoso_resiste_a_mudanca() -> void:
	var w := _world()
	var rl: RelationsModule = w.modules.relations
	check(w.npc_def("otto").get("traits", []).has("teimoso"), "otto é teimoso (pré-condição)")
	rl.on_event(_fato("otto", "player", -25, "raiva"))
	# -25 * 0.5 * 0.6 = -7.5 na confiança (sem o traço seria -12.5)
	eq(rl.dims("otto", "player").confianca, -7.5, "teimoso muda a confiança com intensidade 0,6")


func test_convivencia_no_mesmo_local_cria_familiaridade() -> void:
	var w := _world()
	var rl: RelationsModule = w.modules.relations
	var npcs: NpcModule = w.modules.npcs
	npcs.state.garrick.location = "taverna"
	npcs.state.elsa.location = "taverna"
	rl.rel = {}
	rl.on_tick(w.clock.tick)
	check(rl.dims("garrick", "elsa").familiaridade >= 1.0, "dividir o local aumenta a familiaridade")


func test_relacoes_salvam_e_carregam() -> void:
	var w := _world()
	var rl: RelationsModule = w.modules.relations
	rl.rel = {"garrick": {"player": {"confianca": 12.0, "ressentimento": 5.0, "familiaridade": 4.0}}}
	var w2 := WorldHelpers.world(1)
	w2.from_snapshot(w.to_snapshot())
	eq(w2.modules.relations.dims("garrick", "player").confianca, 12.0, "confiança salva e carregada")
	eq(w2.modules.relations.reaction("garrick", "player"), "indiferente", "reação salva e carregada")


func test_saudacao_muda_com_a_relacao_do_morador() -> void:
	var w := _world()
	var rl: RelationsModule = w.modules.relations
	var visita := {"kind": "conhecido", "gap": 0, "count": 0}
	rl.rel = {"garrick": {"player": {"ressentimento": 60.0}}}
	var frase := DialogueVoice.greeting(w, "garrick", visita)
	check(frase.find("Ainda não esqueci") >= 0, "quem guarda rancor fala do rancor: " + frase)
	rl.rel = {}
	var neutra := DialogueVoice.greeting(w, "garrick", visita)
	check(neutra.find("Ainda não esqueci") < 0, "sem relação, não há a frase de rancor")
