extends TestCase
## Arton Viva, Fase 9: o diário guarda a verdade histórica, por categoria, e sobrevive ao salvamento.


func _world() -> WorldState:
	return WorldHelpers.world(3)


func test_mudancas_relevantes_viram_cronica_por_categoria() -> void:
	var w := _world()
	var c: ChronicleModule = w.modules.chronicle
	c.on_event(GameEvent.create("c1", "ROUTE_CHANGED", 10, {"route": "valkaria_vila", "open": false}))
	c.on_event(GameEvent.create("c2", "LEADERSHIP_CHANGED", 11, {"faction": "guarda_vila", "from": "orin", "to": "elsa", "status": "ativa"}))
	eq(c.by_category("economia").size(), 1, "a rota fechada entra na economia")
	eq(c.by_category("guildas").size(), 1, "a troca de líder entra nas guildas e facções")
	check(c.entries[0].text.find("fechada") >= 0, "o texto diz que a rota foi fechada")


func test_cronica_sobrevive_ao_salvamento() -> void:
	var w := _world()
	var c: ChronicleModule = w.modules.chronicle
	c.on_event(GameEvent.create("c3", "TORMENTA_STAGE_CHANGED", 12, {"stage": 2, "corruption": 25.0}))
	var w2 := WorldHelpers.world(1)
	w2.from_snapshot(w.to_snapshot())
	eq(w2.modules.chronicle.entries.size(), 1, "a crônica é salva")
	eq(w2.modules.chronicle.entries[0].category, "tormenta", "com a categoria")


func test_fatos_antes_sem_consumidor_viram_registro() -> void:
	var w := _world()
	var c: ChronicleModule = w.modules.chronicle
	c.on_event(GameEvent.create("o2a", "MYSTERY_LOST", 1, {}))
	c.on_event(GameEvent.create("o2b", "FACTION_ALERTED", 2, {"faction": "garras_de_cinza"}))
	c.on_event(GameEvent.create("o2c", "STOLEN_GOODS_RECOVERED", 3, {}))
	eq(c.entries.size(), 3, "os três fatos que ninguém escutava agora ficam no diário")
	eq(c.by_category("politica").size(), 2, "pista perdida e alerta entram na política")
