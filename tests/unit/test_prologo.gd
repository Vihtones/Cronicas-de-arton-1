extends TestCase
## Arton Viva, Fase 3: três começos diferentes e válidos; destino reproduzível por semente.


func _db() -> ContentDB:
	return ContentDB.load_default()


func _respostas(ocupacao: String, condicao: String, vinculo: String, comeco: String, recente: String = "nada") -> Dictionary:
	return {"onde_cresceu": "vila", "condicao": condicao, "vinculo": vinculo, "ocupacao": ocupacao, "recente": recente, "comeco": comeco}


func test_tres_comecos_sao_diferentes_e_validos() -> void:
	var db := _db()
	var a := Prologue.from_answers(_respostas("ferreiro", "trabalhador", "familia", "em_casa"))
	var b := Prologue.from_answers(_respostas("nomade", "sem_recursos", "nenhum", "acampamento"))
	var c := Prologue.from_answers(_respostas("herdeiro", "nobreza", "mentor", "estrada", "perda"))
	eq(Prologue.validate(a, db).size(), 0, "começo A é válido")
	eq(Prologue.validate(b, db).size(), 0, "começo B é válido")
	eq(Prologue.validate(c, db).size(), 0, "começo C é válido")
	check(a.gold != b.gold and b.gold != c.gold, "ouro diferente em cada começo")
	check(a.home != b.home and b.home != c.home, "moradia diferente em cada começo")
	check(b.home == "" and b.start_location == "campos", "nômade começa no acampamento, sem casa")
	eq(c.contacts, ["otto"], "herdeiro com mentor tem o contato real do mundo")


func test_divida_recente_reduz_o_ouro_inicial() -> void:
	var s := Prologue.from_answers(_respostas("ferreiro", "trabalhador", "nenhum", "em_casa", "divida"))
	eq(s.gold, 15 - Prologue.DEBT, "dívida recente tira ouro no começo")


func test_familia_resolve_para_os_moradores_da_casa() -> void:
	var db := _db()
	var s := Prologue.from_answers(_respostas("ferreiro", "trabalhador", "familia", "em_casa"))
	var familia := Prologue.resolve_contacts(s, db)
	check(familia.has("garrick") and familia.has("mara") and familia.has("davi"), "a família é quem mora em casa_ferro: " + str(familia))


func test_destino_por_semente_e_reproduzivel() -> void:
	eq(Prologue.from_seed(7), Prologue.from_seed(7), "mesma semente, mesmo começo")


func test_destino_gera_comecos_validos_e_variados() -> void:
	var db := _db()
	var moradias := {}
	for s in range(1, 61):
		var start := Prologue.from_seed(s)
		var errs := Prologue.validate(start, db)
		if not errs.is_empty():
			check(false, "semente %d inválida: %s" % [s, str(errs)])
			return
		moradias[start.home] = true
	check(moradias.size() >= 4, "as sementes variam a moradia (%d opções)" % moradias.size())


func test_comando_aplica_o_comeco_uma_vez() -> void:
	var w := WorldHelpers.world(3)
	var s := Prologue.from_answers(_respostas("ferreiro", "trabalhador", "familia", "estrada"))
	var r := WorldHelpers.cmd(w, "StartPrologue", {"start": s})
	check(r.accepted, "o comando aceita um começo válido")
	eq(w.player.gold, s.gold, "ouro do começo aplicado")
	eq(w.modules.relations.dims("garrick", "player").familiaridade, 12.0, "família começa com familiaridade")
	var de_novo := WorldHelpers.cmd(w, "StartPrologue", {"start": s})
	check(not de_novo.accepted, "o prólogo só é escolhido uma vez")


func test_comeco_leva_o_jogador_ao_lugar_do_passado() -> void:
	var w := WorldHelpers.world(3)
	var start := Prologue.from_answers({"comeco": "no_trabalho", "ocupacao": "ferreiro"})
	var r := WorldHelpers.cmd(w, "StartPrologue", {"start": start})
	check(r.accepted, "começo aceito")
	var spot: Vector2i = w.db.location_spot(str(start.start_location))
	eq(w.db.world_to_tile(w.player.position), spot, "o jogador começa no local de trabalho do ferreiro (%s)" % start.start_location)


func test_destino_decidido_por_semente_leva_ao_mesmo_lugar() -> void:
	var a := WorldHelpers.world(3)
	var b := WorldHelpers.world(3)
	var ra := WorldHelpers.cmd(a, "StartPrologue", {"start": Prologue.from_seed(42)})
	var rb := WorldHelpers.cmd(b, "StartPrologue", {"start": Prologue.from_seed(42)})
	check(ra.accepted and rb.accepted, "as duas semeadas começam")
	eq(a.player.position, b.player.position, "mesma semente, mesma posição inicial")
