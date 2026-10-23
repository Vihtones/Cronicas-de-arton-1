extends TestCase


func test_mesmo_evento_nao_aplica_duas_vezes() -> void:
	var bus := EventBus.new()
	var count := [0]
	bus.subscribe("X", func(_e): count[0] += 1)
	var e := GameEvent.create("evt_1", "X", 0)
	check(bus.publish(e), "primeira publicação aceita")
	check(not bus.publish(e), "duplicada rejeitada")
	eq(count[0], 1, "listener chamado uma vez")


func test_curinga_recebe_todos() -> void:
	var bus := EventBus.new()
	var got: Array[String] = []
	bus.subscribe("*", func(e): got.append(e.event_type))
	bus.publish(GameEvent.create(bus.next_event_id(), "A", 0))
	bus.publish(GameEvent.create(bus.next_event_id(), "B", 0))
	eq(got, ["A", "B"] as Array[String], "ordem preservada")


func test_sem_listeners_nao_bloqueia_emissor() -> void:
	var bus := EventBus.new()
	check(bus.publish(GameEvent.create("e", "NINGUEM_OUVE", 0)), "publica sem consumidores")


func test_payload_imutavel() -> void:
	var e := GameEvent.create("e", "T", 0, {"a": 1})
	check(e.payload.is_read_only(), "payload somente leitura")
