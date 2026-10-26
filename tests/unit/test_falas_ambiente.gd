extends TestCase
## Falas de ambiente: escolha por contexto (hora, clima, evento, mistério), conversas de verdade e latidos.


func _data() -> Dictionary:
	return WorldHelpers.world(3).db.ambient


func _ctx(periodo := "manha", clima := "limpo", eventos: Array = [], misterio := false) -> Dictionary:
	return {"periodo": periodo, "clima": clima, "eventos": eventos, "misterio": misterio}


func test_dados_completos_e_sem_fala_vazia() -> void:
	var d := _data()
	check(not d.is_empty(), "ambient.json carregado")
	for c in d.conversas:
		for script in c.falas:
			eq(script.size(), 4, "toda conversa tem 4 falas (alternam entre dois)")
			for l in script:
				check(str(l).length() > 3, "fala não vazia")
	for ware in ["comida", "ferramenta", "remedio", "tecido"]:
		check(not d.vendedor[ware].is_empty(), "pregões de " + ware)
	for key in ["geral", "chuva", "noite", "feira", "festa"]:
		check(not d.crianca[key].is_empty(), "crianças: " + key)
	for prop in ["saco", "vassoura", "cesto", "lenha", ""]:
		check(not d.ocupado[prop].is_empty(), "ocupados: '%s'" % prop)
	var regs: Dictionary = WorldHelpers.world(3).db.voices.trabalho
	for reg in WorldHelpers.world(3).db.voices.registro.values():
		for tier in ["amigo", "neutro", "frio"]:
			check(not d.latido[reg][tier].is_empty(), "latido %s/%s" % [reg, tier])
	check(regs.size() > 0, "voz carregada")


func test_conversa_segue_o_contexto() -> void:
	var d := _data()
	var chuva_words := ["chuva", "lama", "chuvarada"]
	var ok_chuva := true
	var vistos_misterio := 0
	for s in 40:
		var rain := " ".join(AmbientTalk.conversation(d, _ctx("tarde", "chuva"), s * 16 + 1)).to_lower()
		if not chuva_words.any(func(w): return rain.contains(w)):
			ok_chuva = false
		var mist := " ".join(AmbientTalk.conversation(d, _ctx("tarde", "limpo", [], true), s * 16 + 5)).to_lower()
		if mist.contains("moleiro") or mist.contains("torre") or mist.contains("porta") or mist.contains("vila"):
			vistos_misterio += 1
	check(ok_chuva, "na chuva a conversa (fora o sorteio de variedade) fala de chuva")
	check(vistos_misterio >= 20, "com mistério aberto a vila comenta o sumiço (%d/40)" % vistos_misterio)


func test_conversa_de_festa_so_a_noite_ou_tarde_e_feira_so_na_feira() -> void:
	var d := _data()
	var festa := " ".join(AmbientTalk.conversation(d, _ctx("noite", "limpo", ["festa"]), 5)).to_lower()
	check(festa.contains("dança") or festa.contains("tocar") or festa.contains("bebida") or festa.contains("amanhecer"), "festa: " + festa)
	var sem_evento := true
	for s in 60:
		var t := " ".join(AmbientTalk.conversation(d, _ctx("manha", "limpo"), s)).to_lower()
		if t.contains("barracas") or t.contains("amanhecer"):
			sem_evento = false
	check(sem_evento, "sem feira nem festa, ninguém comenta barracas ou dança")


func test_falas_por_tipo_e_determinismo() -> void:
	var d := _data()
	check(AmbientTalk.vendedor(d, "ferramenta", _ctx(), 1) in d.vendedor.ferramenta, "ferramenteiro apregoa ferramenta")
	check(AmbientTalk.vendedor(d, "tecido", _ctx(), 2) in d.vendedor.tecido, "tecelão apregoa tecido")
	check(AmbientTalk.ocupado(d, "lenha", 3) in d.ocupado.lenha, "quem racha lenha fala de lenha")
	var rain_kids: Dictionary = {}
	for s in 60:
		rain_kids[AmbientTalk.crianca(d, _ctx("tarde", "chuva"), s)] = true
	check(rain_kids.keys().any(func(l): return l in d.crianca.chuva), "crianças comentam a chuva")
	eq(AmbientTalk.passante(d, _ctx("noite", "tempestade"), 9), AmbientTalk.passante(d, _ctx("noite", "tempestade"), 9), "mesma semente, mesma fala")
	var tempest: Array = d.passante.tempestade + d.passante.noite
	check(AmbientTalk.passante(d, _ctx("noite", "tempestade"), 5) in tempest, "passante de noite na tempestade fala da noite ou do temporal")


func test_latido_depende_do_registro_e_da_relacao() -> void:
	var w := WorldHelpers.world(3)
	var d := w.db.ambient
	var reg := DialogueVoice.register(w, "elsa")
	eq(reg, "seco", "capitã tem registro seco")
	var amigo := AmbientTalk.latido(d, reg, "amigo", 1)
	var frio := AmbientTalk.latido(d, reg, "frio", 1)
	check(amigo in d.latido.seco.amigo and frio in d.latido.seco.frio and amigo != frio, "amigo e frio soam diferente")
	var ctx := AmbientTalk.context(w)
	check(ctx.periodo in ["manha", "tarde", "noite"] and ctx.clima != "", "contexto montado do mundo")
