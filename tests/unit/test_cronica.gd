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


func test_noticia_chega_pelo_canal_da_categoria() -> void:
	var w := _world()
	var c: ChronicleModule = w.modules.chronicle
	c.on_event(GameEvent.create("n1", "TORMENTA_STAGE_CHANGED", 1, {"stage": 1, "corruption": 2.0}))
	c.on_event(GameEvent.create("n2", "ROUTE_CHANGED", 2, {"route": "valkaria_vila", "open": false}))
	eq(c.news_via("mensageiro").size(), 1, "notícia da Tormenta vem pelo mensageiro")
	eq(c.news_via("mercador").size(), 1, "notícia de rota vem pelo mercador")


## Fase 9, rumores históricos: a notícia chega a quem traz notícia pelo canal e depois corre de boca em boca.
func _fechar_rota(w: WorldState) -> void:
	w._commit(GameCommand.create("rota", "player", "Teste", {}), [WorldModule.fact("ROUTE_CHANGED", {"route": "samburdia_vila", "open": false})])


func _chave_da_ultima(w: WorldState) -> String:
	return "cronica:%d" % int(w.modules.chronicle.entries.back().id)


func test_noticia_da_cronica_chega_primeiro_ao_portador_do_canal() -> void:
	var w := _world()
	var c: ChronicleModule = w.modules.chronicle
	var mem: MemoryModule = w.modules.memory
	var portadores := c.portadores("mercador")
	check(portadores.has("mara"), "a mercadora da vila traz notícia de economia")
	check(not portadores.has("kharim"), "mercador de fora da vila não recebe a notícia da vila")
	_fechar_rota(w)
	var chave := _chave_da_ultima(w)
	for id in portadores:
		check(mem.knows_fact(id, chave), "%s soube da estrada fechada" % id)
	check(not mem.knows_fact("fenna", chave), "quem não é do canal ainda não sabe")


func test_noticia_corre_de_boca_em_boca_e_so_entre_quem_esta_junto() -> void:
	var w := _world()
	var mem: MemoryModule = w.modules.memory
	_fechar_rota(w)
	var chave := _chave_da_ultima(w)
	var portadores: Array = w.modules.chronicle.portadores("mercador")
	var antes := 0
	for id in w.all_npc_ids():
		if mem.knows_fact(id, chave): antes += 1
	WorldHelpers.advance_hours(w, 48)
	var depois := 0
	var por_boato := 0
	for id in w.all_npc_ids():
		if mem.knows_fact(id, chave):
			depois += 1
			if not portadores.has(id):
				por_boato += 1
				var m: Dictionary = mem.list(id).filter(func(x): return x.key == chave)[0]
				check(str(m.source).begins_with("rumor:"), "%s ouviu de alguém, não viu" % id)
				check(float(m.reliability) < 1.0, "boato perde confiança")
	check(depois > antes, "em dois dias a notícia se espalhou (%d -> %d)" % [antes, depois])
	check(por_boato > 0, "alguém fora do canal soube por boato")


func test_jogador_ouve_a_noticia_perguntando_o_que_se_conta() -> void:
	var w := _world()
	_fechar_rota(w)
	var dm: DialogueModule = w.modules.dialogue
	var no: Dictionary = dm._dynamic_node("mara", "__rumor")
	check(str(no.text).begins_with("Chegou notícia: "), "quem trouxe conta como novidade: %s" % no.text)
	check(str(no.text).find("fechada") >= 0, "e conta o que aconteceu")


func test_noticia_sobrevive_ao_salvamento_e_morte_nao_corre_duas_vezes() -> void:
	var w := _world()
	_fechar_rota(w)
	var chave := _chave_da_ultima(w)
	var w2 := WorldHelpers.world(1)
	w2.from_snapshot(w.to_snapshot())
	check(w2.modules.memory.knows_fact("mara", chave), "a notícia continua na memória depois de carregar")
	var c: ChronicleModule = w.modules.chronicle
	c.on_event(GameEvent.create("m1", "NPC_DIED", 5, {"npc": "fenna", "cause": "velhice", "age": 80}))
	check(not w.modules.memory.knows_fact("mara", "cronica:%d" % int(c.entries.back().id)), "a morte já vira luto das testemunhas")


func test_fatos_mudos_tem_texto_legivel() -> void:
	var w := _world()
	var c: ChronicleModule = w.modules.chronicle
	c.on_event(GameEvent.create("t1", "FACTION_ALERTED", 1, {"faction": "garras_de_cinza"}))
	check(str(c.entries.back().text).find("Garras de Cinza") >= 0, "a facção aparece pelo nome: %s" % c.entries.back().text)
	c.on_event(GameEvent.create("t2", "STOLEN_GOODS_RECOVERED", 2, {"item": "dizimo_lena", "owner": "templo_lena"}))
	check(str(c.entries.back().text).find("Bolsa do dízimo") >= 0 and str(c.entries.back().text).find("Templo de Lena") >= 0, "item e dono pelo nome: %s" % c.entries.back().text)
	var n := c.entries.size()
	c.on_event(GameEvent.create("t3", "STOLEN_GOODS_RECOVERED", 3, {"item": "carta_lacrada", "owner": "guilda"}))
	eq(c.entries.size(), n, "encomenda da guilda não é furto")
