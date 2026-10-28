extends TestCase
## IA: moradores conversam entre si quando dividem o mesmo local (fala sorteada, efeito nas relações, memória).


func _dois_moradores(w: WorldState) -> Array:
	var npcs = w.modules.npcs
	var ids: Array = []
	for id in npcs.state:
		if npcs.state[id].alive and not npcs.state[id].captive:
			ids.append(id)
		if ids.size() == 2:
			break
	return ids


func _horas(w: WorldState, n: int) -> void:
	var horas: int = 60 / w.clock.tick_minutes
	for k in range(1, n + 1):
		w.modules.conversa.on_tick(horas * k)


func test_dois_moradores_no_mesmo_local_conversam_e_se_aproximam() -> void:
	var w := WorldHelpers.world(3)
	var ids := _dois_moradores(w)
	var a: String = ids[0]
	var b: String = ids[1]
	w.modules.npcs.state[a].location = "praca"
	w.modules.npcs.state[b].location = "praca"
	_horas(w, 30)
	check(w.modules.conversa.resumo(a).size() > 0, "%s ouviu ou falou alguma coisa" % a)
	check(float(w.modules.relations.dims(a, b).familiaridade) > 0.0, "a conversa aproximou os dois")


func test_conversa_fica_guardada_com_limite_e_cooldown() -> void:
	var w := WorldHelpers.world(3)
	var ids := _dois_moradores(w)
	w.modules.npcs.state[ids[0]].location = "praca"
	w.modules.npcs.state[ids[1]].location = "praca"
	_horas(w, 40)
	check(w.modules.conversa.recent[ids[0]].size() <= ConversaModule.MAX_RECENT, "guarda no máximo %d conversas" % ConversaModule.MAX_RECENT)
	var horas: int = 60 / w.clock.tick_minutes
	var ultima: int = int(w.modules.conversa.recent[ids[0]][0].tick)
	check(w.modules.conversa._em_cooldown(ids[0], ids[1], ultima + horas, horas), "não repete logo em seguida")
	check(not w.modules.conversa._em_cooldown(ids[0], ids[1], ultima + ConversaModule.COOLDOWN_HOURS * horas + 1, horas), "depois do cooldown pode voltar a conversar")


func test_morador_sozinho_nao_conversa() -> void:
	var w := WorldHelpers.world(3)
	var ids := _dois_moradores(w)
	for id in w.modules.npcs.state:
		w.modules.npcs.state[id].location = "longe_daqui_%s" % id
	_horas(w, 30)
	check(w.modules.conversa.recent.is_empty(), "sem companhia no local, ninguém conversa")
	check(ids.size() == 2, "havia dois moradores de referência")
