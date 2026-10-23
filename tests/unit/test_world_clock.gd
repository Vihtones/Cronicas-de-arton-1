extends TestCase


func test_calendario_basico() -> void:
	var c := WorldClock.new()
	c.advance(6 * 25)  # 25 horas com ticks de 10 min
	var cal := c.calendar()
	eq(cal.day, 2, "dia")
	eq(cal.hour, 1, "hora")
	eq(cal.minute, 0, "minuto")


func test_agendamento_dispara_em_ordem() -> void:
	var c := WorldClock.new()
	c.schedule(5, "b")
	c.schedule(3, "a")
	c.schedule(100, "depois")
	var due := c.advance(10)
	eq(due.size(), 2, "dois vencidos")
	eq(due[0].key, "a", "ordem por tick")
	eq(c.advance(1).size(), 0, "não dispara de novo")


func test_round_trip() -> void:
	var c := WorldClock.new()
	c.advance(42)
	c.schedule(50, "k", {"x": 1})
	var c2 := WorldClock.new()
	c2.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	eq(c2.tick, 42, "tick")
	eq(c2.advance(10).size(), 1, "agendamento preservado")
