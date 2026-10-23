extends TestCase


func test_comando_invalido_nao_altera_estado() -> void:
	var w := WorldState.new()
	var bus := EventBus.new()
	var before := JSON.stringify(w.to_snapshot())
	var r := w.apply_command(GameCommand.create("c1", "player", "MovePlayer", {"to": "lixo"}), bus)
	check(not r.accepted, "rejeitado")
	eq(JSON.stringify(w.to_snapshot()), before, "estado intacto")
	r = w.apply_command(GameCommand.create("c2", "player", "Inexistente"), bus)
	check(not r.accepted, "desconhecido rejeitado")
	eq(w.revision, 0, "revisão intacta")


func test_revisao_desatualizada_rejeitada() -> void:
	var w := WorldState.new()
	var bus := EventBus.new()
	w.apply_command(GameCommand.create("c1", "player", "AdvanceTime", {"ticks": 1}), bus)
	var r := w.apply_command(GameCommand.create("c2", "player", "AdvanceTime", {"ticks": 1}, 0), bus)
	check(not r.accepted, "revisão 0 != 1")
	eq(w.clock.tick, 1, "tick não avançou")


func test_comando_valido_emite_evento() -> void:
	var w := WorldState.new()
	var bus := EventBus.new()
	var r := w.apply_command(GameCommand.create("c1", "player", "MovePlayer", {"to": Vector2(10, 5)}), bus)
	check(r.accepted, "aceito")
	eq(r.emitted_events[0].event_type, "PLAYER_MOVED", "evento")
	eq(r.emitted_events[0].source_command_id, "c1", "rastreável ao comando")
	eq(w.player.position, Vector2(10, 5), "posição")


func test_snapshot_round_trip() -> void:
	var w := WorldState.new()
	var bus := EventBus.new()
	w.rng.reseed(555)
	w.apply_command(GameCommand.create("c1", "player", "MovePlayer", {"to": Vector2(3, 4)}), bus)
	w.apply_command(GameCommand.create("c2", "player", "AdvanceTime", {"ticks": 7}), bus)
	var s1 := JSON.stringify(w.to_snapshot())
	var w2 := WorldState.new()
	w2.from_snapshot(JSON.parse_string(s1))
	eq(JSON.stringify(w2.to_snapshot()), s1, "snapshot idêntico após round-trip")
