extends TestCase


func test_mundo_completo_inicializa_e_avanca_um_dia() -> void:
	var w := WorldFactory.create(1)
	check(w.rules.errors.is_empty(), "regras sem erro: %s" % str(w.rules.errors))
	check(w.db.npcs.npcs.size() == 25, "25 NPCs")
	var r := w.apply_command(GameCommand.create("c1", "player", "AdvanceTime", {"ticks": 144}))
	check(r.accepted, "avançou: %s" % str(r.errors))
	eq(w.clock.tick, 144, "tick")
