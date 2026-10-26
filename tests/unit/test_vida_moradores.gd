extends TestCase
## Vida dos moradores: atividade, humor (medo/alegria), recolhimento e persistência.


func test_morte_na_vila_assusta_vizinhos_e_familia() -> void:
	var w := WorldHelpers.world(3)
	var life: NpcLifeModule = w.modules.npc_life
	var mara := "mara"
	life.on_event(GameEvent.create("d1", "NPC_DIED", 0, {"npc": "garrick", "location": "ferraria"}))
	# o ferreiro morreu: a família (aprendiz) e quem está na ferraria passam a ter medo
	check(life.fear("davi") > 0.0, "aprendiz (família do ferreiro) recebe medo: %.2f" % life.fear("davi"))
	check(life.fear(mara) <= 1.0, "medo nunca passa de 1")
	eq(life.fear("unknown_id"), 0.0, "quem não existe não tem medo")


func test_medo_chega_a_recolher_e_passa_com_o_tempo() -> void:
	var w := WorldHelpers.world(3)
	var life: NpcLifeModule = w.modules.npc_life
	w.clock.tick = 6 * 12
	# o aprendiz (família do ferreiro) passa a ter medo alto
	life.mood["davi"] = {"fear": 0.9, "joy": 0.0}
	var d := w.npc_def("davi")
	var ov := life.location_override("davi", d, int(d.age))
	eq(ov, str(d.home), "com medo alto, o morador vai para casa")
	life.mood["davi"].fear = 0.0
	eq(life.location_override("davi", d, int(d.age)), "", "sem medo, segue a rotina")
	# guardas não se recolhem nunca
	life.mood["elsa"] = {"fear": 1.0, "joy": 0.0}
	eq(life.location_override("elsa", w.npc_def("elsa"), 45), "", "guarda fica no posto mesmo com medo")


func test_medo_diminui_por_hora() -> void:
	var w := WorldHelpers.world(3)
	var life: NpcLifeModule = w.modules.npc_life
	life.mood["davi"] = {"fear": 0.8, "joy": 0.0}
	for i in 12:
		life.on_tick(w.clock.tick + i * 6)
	check(life.fear("davi") < 0.8, "medo cai com o tempo (%.2f)" % life.fear("davi"))
	check(life.fear("davi") >= 0.0, "nunca negativo")


func test_atividade_descreve_o_que_o_morador_faz() -> void:
	var w := WorldHelpers.world(3)
	var life: NpcLifeModule = w.modules.npc_life
	w.clock.tick = 6 * 12
	var npcs: NpcModule = w.modules.npcs
	var a := life.activity("garrick")
	check(a != "", "ferreiro tem atividade: " + a)
	npcs.state["garrick"].captive = true
	eq(life.activity("garrick"), "preso", "preso aparece como preso")
	npcs.state["garrick"].captive = false
	npcs.state["garrick"].alive = false
	eq(life.activity("garrick"), "", "morto não tem atividade")


func test_festa_muda_atividades_e_humor() -> void:
	var w := WorldHelpers.world(3)
	var life: NpcLifeModule = w.modules.npc_life
	w.clock.tick = 6 * 24 * 4 + 6 * 18
	life.on_event(GameEvent.create("f", "TOWN_EVENT_STARTED", 0, {"event": "festa"}))
	check(life.joy("bento") > 0.0 or life.joy("rosana") > 0.0, "festa anima os moradores")


func test_persistencia_do_humor() -> void:
	var w := WorldHelpers.world(3)
	var life: NpcLifeModule = w.modules.npc_life
	life.mood["davi"] = {"fear": 0.4, "joy": 0.1}
	var snap := w.to_snapshot()
	var w2 := WorldHelpers.world(1)
	w2.from_snapshot(snap)
	eq(w2.modules.npc_life.mood.davi.fear, 0.4, "medo salvo e recarregado")
	var old: Dictionary = snap.duplicate(true)
	if old.modules.has("world_modules"):
		old.modules.world_modules.erase("npc_life")
	var w3 := WorldHelpers.world(1)
	w3.from_snapshot(old)
	check(w3.modules.npc_life.mood.is_empty(), "save antigo sem humor carrega vazio")


func test_atividade_aparece_para_o_rotulo_e_medo_muda_a_fala() -> void:
	var w := WorldHelpers.world(3)
	var life: NpcLifeModule = w.modules.npc_life
	w.clock.tick = 6 * 12
	check(life.activity("garrick") != "", "ferreiro tem atividade para o rótulo")
	life.mood["davi"] = {"fear": 0.9, "joy": 0.0}
	eq(life.activity("davi"), "assustado, em casa", "aprendiz assustado: atividade explica o recolhimento")
