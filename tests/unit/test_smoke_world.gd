extends TestCase


func test_mundo_completo_inicializa_e_avanca_um_dia() -> void:
	var w := WorldFactory.create(1)
	check(w.rules.errors.is_empty(), "regras sem erro: %s" % str(w.rules.errors))
	check(w.db.npcs.npcs.size() == 67, "67 NPCs (33 da vila e Pedra Branca, 26 da Fronteira do Leste, 8 do Horizonte e do Vale)")
	var r := w.apply_command(GameCommand.create("c1", "player", "AdvanceTime", {"ticks": 144}))
	check(r.accepted, "avançou: %s" % str(r.errors))
	eq(w.clock.tick, 144, "tick")


func test_pedra_branca_estalagem_cobra_o_pernoite_e_moradores_existem() -> void:
	var w := WorldHelpers.world(7)
	check(w.db.location("estalagem").has("rect"), "estalagem existe no mapa")
	check(w.npc_def("berta").get("home", "") == "estalagem", "Berta mora na estalagem")
	var spot: Vector2i = w.db.location_spot("estalagem")
	WorldHelpers.put(w, spot.x, spot.y)
	var ouro: int = int(w.player.gold)
	var r := WorldHelpers.cmd(w, "Rest")
	check(r.accepted, "descansar na estalagem")
	eq(int(w.player.gold), ouro - 1, "pernoite custa 1 T$")


func test_marta_vende_no_entreposto() -> void:
	var w := WorldHelpers.world(7)
	check(w.db.economy.shops.has("marta") and w.db.economy.shops.has("berta"), "lojas de Pedra Branca no catálogo")
	w.clock.tick = 6 * 10   # 10h: Marta está no entreposto
	w.advance_ticks(1)
	var spot: Vector2i = w.db.location_spot("entreposto")
	WorldHelpers.put(w, spot.x, spot.y)
	w.player.gold = 50
	var r := WorldHelpers.cmd(w, "Buy", {"npc_id": "marta", "item": "tocha"})
	check(r.accepted, "comprar tocha de Marta (%s)" % str(r.errors))
