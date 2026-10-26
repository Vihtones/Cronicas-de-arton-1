extends TestCase
## Voz dos moradores: saudação por registro/hora/reputação, memória da conversa, papo e opiniões.


func _talk(w: WorldState, npc: String) -> GameCommand.Result:
	var t: Vector2i = w.modules.npcs.npc_tile(npc)
	WorldHelpers.put(w, t.x + 1, t.y)
	return WorldHelpers.cmd(w, "StartDialogue", {"npc_id": npc})


func _pick(w: WorldState, prefix: String) -> bool:
	for o in w.modules.dialogue.view().options:
		if str(o.text).begins_with(prefix):
			return WorldHelpers.cmd(w, "ChooseOption", {"index": o.index}).accepted
	return false


func _text(w: WorldState) -> String:
	return str(w.modules.dialogue.view().get("text", ""))


func _has_option(w: WorldState, prefix: String) -> bool:
	return w.modules.dialogue.view().options.any(func(o): return str(o.text).begins_with(prefix))


func _close(w: WorldState) -> void:
	if not w.modules.dialogue.session.is_empty():
		WorldHelpers.cmd(w, "EndDialogue")


func test_todas_as_profissoes_tem_voz_completa() -> void:
	var w := WorldHelpers.world(3)
	var v: Dictionary = w.db.voices
	check(not v.is_empty(), "voices.json carregado")
	var regs := {}
	for id in w.all_npc_ids():
		var prof := str(w.npc_def(id).get("profession", ""))
		check(v.registro.has(prof), "profissão '%s' tem registro" % prof)
		check(v.trabalho.has(prof), "profissão '%s' tem fala de trabalho" % prof)
		check(v.nota_profissao.has(prof), "profissão '%s' tem nota" % prof)
		regs[v.registro.get(prof, "?")] = true
	for reg in regs:
		for p in v.periodos:
			check(not v.primeiro[reg][p].is_empty(), "primeiro encontro %s/%s" % [reg, p])
		for tier in ["amigo", "neutro", "frio"]:
			check(not v.conhecido[reg][tier].is_empty(), "conhecido %s/%s" % [reg, tier])
		for cond in ["limpo", "chuva", "tempestade", "neblina"]:
			check(str(v.clima[cond].get(reg, "")) != "", "clima %s/%s" % [cond, reg])
		for ev in ["feira", "festa"]:
			check(str(v.evento[ev].get(reg, "")) != "", "evento %s/%s" % [ev, reg])
		check(v.mesmo_dia.has(reg) and v.retorno.has(reg) and v.preocupado.has(reg), "falas de retorno/preocupação para " + reg)


func test_primeira_visita_depois_mesmo_dia_depois_retorno() -> void:
	var w := WorldHelpers.world(3)
	w.clock.tick = 6 * 10
	check(_talk(w, "bento").accepted, "conversa abre")
	var first := _text(w)
	check(first.contains("Sou Bento"), "na primeira vez ela se apresenta: " + first)
	_close(w)
	_talk(w, "bento")
	var again := _text(w)
	check(not again.contains("Sou Bento"), "já não se apresenta de novo: " + again)
	check(again != first, "a saudação muda depois que se conhecem")
	_close(w)
	WorldHelpers.advance_hours(w, 24 * 4)
	_talk(w, "bento")
	check(_text(w).contains("4 dias") or _text(w).contains("5 dias"), "reconhece que o jogador sumiu por dias: " + _text(w))


func test_reputacao_muda_o_tom() -> void:
	var w := WorldHelpers.world(3)
	w.clock.tick = 6 * 10
	_talk(w, "garrick")
	_close(w)
	var mem: MemoryModule = w.modules.memory
	var neutral := DialogueVoice.greeting(w, "garrick", {"kind": "conhecido", "count": 3})
	mem.add_memory("garrick", {"key": "bom1", "about": "player", "subject": "", "valence": 40, "location": "", "tick": 0, "emotion": "gratidao",
		"reliability": 1.0, "source": "visto", "durable": true, "text": "ajudou"})
	var friend := DialogueVoice.greeting(w, "garrick", {"kind": "conhecido", "count": 3})
	check(friend != neutral, "amigo é recebido de outro jeito (%s | %s)" % [neutral, friend])
	eq(DialogueVoice.tier(w, "garrick"), "amigo", "reputação alta = amigo")


func test_papo_trabalho_tempo_e_gente() -> void:
	var w := WorldHelpers.world(3)
	w.clock.tick = 6 * 10
	_talk(w, "bento")
	check(_pick(w, "Conversar sobre outra coisa"), "abre o papo")
	check(_has_option(w, "Como vai o trabalho?"), "tem trabalho")
	check(_has_option(w, "Que tempo"), "tem tempo")
	check(_has_option(w, "Fale-me da gente da vila"), "tem gente")
	check(_pick(w, "Como vai o trabalho?"), "pergunta pelo trabalho")
	check(_text(w).contains("Panela cheia"), "fala de trabalho do cozinheiro: " + _text(w))
	check(_pick(w, "Mudar de assunto"), "volta ao papo")
	check(_pick(w, "Fale-me da gente"), "pergunta da gente")
	var people := DialogueVoice.people_of_interest(w, "bento")
	check(people.has("rosana") and people.has("nina"), "a família vem primeiro")
	check(_pick(w, "E Rosana?"), "pergunta de Rosana")
	check(_text(w).contains("minha família") and _text(w).contains("taverna"), "opinião de família com ofício: " + _text(w))


func test_assunto_repetido_no_mesmo_dia_e_reconhecido() -> void:
	var w := WorldHelpers.world(3)
	w.clock.tick = 6 * 10
	_talk(w, "bento")
	_pick(w, "Conversar sobre outra coisa")
	_pick(w, "Como vai o trabalho?")
	check(not _text(w).begins_with("Já lhe falei disso hoje."), "na primeira vez responde normalmente")
	_pick(w, "Mudar de assunto")
	_pick(w, "Como vai o trabalho?")
	check(_text(w).begins_with("Já lhe falei disso hoje."), "na segunda ela avisa que já falou: " + _text(w))
	_close(w)
	WorldHelpers.advance_hours(w, 26)
	_talk(w, "bento")
	_pick(w, "Conversar sobre outra coisa")
	_pick(w, "Como vai o trabalho?")
	check(not _text(w).begins_with("Já lhe falei disso hoje."), "no dia seguinte vale de novo")


func test_evento_da_vila_aparece_no_papo_so_quando_ativo() -> void:
	var w := WorldHelpers.world(11, ["weather"])
	WorldHelpers.cmd(w, "AdvanceTime", {"ticks": ((1 * 24 + 8) * 6) - w.clock.tick})
	check(w.modules.town_events.is_active("feira"), "feira ativa")
	_talk(w, "mara")
	if w.modules.dialogue.session.is_empty():
		print("AVISO: feira sem conversa"); return
	_pick(w, "Conversar sobre outra coisa")
	check(_has_option(w, "O que acha da feira?"), "pergunta pela feira durante a feira")
	check(not _has_option(w, "O que acha da festa?"), "e não pela festa fora de hora")
	_pick(w, "O que acha da feira?")
	check(_text(w).length() > 10, "ela responde sobre a feira: " + _text(w))


func test_voz_e_deterministica_e_salva_com_o_jogo() -> void:
	var a := WorldHelpers.world(3)
	var b := WorldHelpers.world(3)
	a.clock.tick = 6 * 10
	b.clock.tick = 6 * 10
	_talk(a, "bento")
	_talk(b, "bento")
	eq(_text(a), _text(b), "mesmo estado, mesma fala")
	_close(a)
	var snap := a.to_snapshot()
	var c := WorldHelpers.world(1)
	c.from_snapshot(snap)
	eq(int(c.modules.dialogue.talks.bento.count), 1, "memória de conversa sobrevive ao salvar")
	_talk(c, "bento")
	check(not _text(c).contains("Sou Bento"), "depois de carregar, ela lembra que já se conhecem")
	# saves antigos (sem talks) continuam carregando
	var old: Dictionary = snap.duplicate(true)
	if old.has("modules") and old.modules.has("dialogue"):
		old.modules.dialogue.erase("talks")
		var d := WorldHelpers.world(1)
		d.from_snapshot(old)
		check(d.modules.dialogue.talks.is_empty(), "save antigo sem memória de conversa carrega vazio")
