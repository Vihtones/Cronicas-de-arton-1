class_name FreeTalk
extends RefCounted
## Fala livre: o jogador digita e o morador responde. Aqui só se ENTENDE a frase (intenção + alvo) e se monta a
## resposta de referência a partir do estado do mundo (voz, hora, clima, memória, mapa). Não decide efeitos:
## quem aplica efeitos é o DialogueModule. Um modelo de linguagem opcional só reescreve o TEXTO depois.
## Determinística: a mesma frase no mesmo estado dá a mesma resposta (replay).

const MAX_CHARS := 200
const ORDEM := ["despedida", "ameaca", "insulto", "agradecimento", "multa", "loja", "guilda", "lugar", "ajuda", "bio", "gente", "evento", "rumor", "trabalho", "tempo", "saudacao"]


static func normalizar(t: String) -> String:
	var s := t.to_lower().strip_edges()
	var de := "áàâãäéèêëíìîïóòôõöúùûüçñ"
	var para := "aaaaaeeeeiiiiooooouuuucn"
	for i in de.length():
		s = s.replace(de[i], para[i])
	var out := ""
	for c in s:
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == " " else " "
	return " ".join(out.split(" ", false))


static func _tem(texto: String, palavras: Array) -> bool:
	var t := " " + texto + " "
	for p in palavras:
		var q := normalizar(str(p))
		if q == "":
			continue
		# palavra curta exige fronteira; radical longo (ex.: "obrigad") casa por prefixo
		if q.length() <= 4:
			if t.contains(" " + q + " "):
				return true
		elif t.contains(" " + q):
			return true
	return false


## Devolve {intent, arg, texto}. arg: id de NPC (pessoa), id de lugar (lugar) ou id de evento.
static func entender(world: WorldState, npc: String, frase: String) -> Dictionary:
	var texto := normalizar(frase)
	var out := {"intent": "desconhecido", "arg": "", "texto": texto}
	if texto == "":
		return out
	var pal: Dictionary = world.db.livre.get("palavras", {})
	# 1) intenções de alta prioridade (despedida, ameaça, insulto, agradecimento)
	for it in ["despedida", "ameaca", "insulto", "agradecimento"]:
		if _tem(texto, pal.get(it, [])):
			out.intent = it
			return out
	# 2) pessoa citada pelo nome: pergunta sobre alguém
	var pessoa := _pessoa_citada(world, npc, texto)
	var lugar := _lugar_citado(world, texto)
	if pessoa != "" and not _tem(texto, pal.get("lugar", [])):
		out.intent = "pessoa"
		out.arg = pessoa
		return out
	for it in ORDEM:
		if it in ["despedida", "ameaca", "insulto", "agradecimento"]:
			continue
		if _tem(texto, pal.get(it, [])):
			out.intent = it
			if it == "lugar":
				out.arg = lugar
			elif it == "evento":
				out.arg = _evento_citado(world, texto)
			return out
	if lugar != "":
		out.intent = "lugar"
		out.arg = lugar
	return out


static func _pessoa_citada(world: WorldState, npc: String, texto: String) -> String:
	for id in world.all_npc_ids():
		var d := world.npc_def(id)
		var nome := normalizar(str(d.get("name", id)))
		var primeiro := nome.get_slice(" ", 0)
		if id != npc and (" " + texto + " ").contains(" " + primeiro + " "):
			return id
	return ""


const SEM_PESO := ["casa", "dos", "das", "posto", "campos", "praca", "ponte", "distante", "estrada", "leste", "antiga", "frio", "velha"]


## Lugar citado: pontua as palavras significativas do nome (e o id) que aparecem na frase; vence quem somar mais letras.
static func _lugar_citado(world: WorldState, texto: String) -> String:
	var melhor := ""
	var pontos := 0
	var t := " " + texto + " "
	for l in world.db.all_locations():
		var palavras: Array = normalizar(str(l.get("name", ""))).split(" ", false)
		palavras.append(str(l.id).replace("_", " "))
		var soma := 0
		for p in palavras:
			var q := str(p)
			if q.length() >= 4 and not SEM_PESO.has(q) and t.contains(" " + q):
				soma += q.length()
		# nomes de uma palavra só ("Ferraria", "Moinho") e ids completos têm peso total
		if soma > pontos:
			pontos = soma
			melhor = str(l.id)
	return melhor


static func _evento_citado(world: WorldState, texto: String) -> String:
	var ids := DialogueVoice.active_event_ids(world)
	return str(ids[0]) if not ids.is_empty() else ""


static func _direcao(de: Vector2i, para: Vector2i) -> String:
	var d := para - de
	if absi(d.x) <= 2 and absi(d.y) <= 2:
		return "bem aqui perto"
	var ns := "ao norte" if d.y < -2 else ("ao sul" if d.y > 2 else "")
	var lo := "a leste" if d.x > 2 else ("a oeste" if d.x < -2 else "")
	if ns != "" and lo != "":
		return "%s e %s" % [ns, lo]
	return ns + lo


static func _fala(world: WorldState, npc: String, chave: String, salt: int = 0) -> String:
	var reg := DialogueVoice.register(world, npc)
	var tab: Dictionary = world.db.livre.get(chave, {})
	return DialogueVoice.pick(world, npc, tab.get(reg, tab.get("simples", [])), salt)


## Resposta de referência para intenções que não têm nó próprio no diálogo.
static func resposta_direta(world: WorldState, npc: String, e: Dictionary, salt: int) -> String:
	var L: Dictionary = world.db.livre
	match str(e.intent):
		"despedida", "saudacao", "agradecimento", "insulto", "ameaca", "ajuda", "desconhecido":
			return _fala(world, npc, str(e.intent), salt)
		"loja":
			var tem: bool = world.db.economy.get("shops", {}).has(npc)
			return _fala(world, npc, "loja" if tem else "sem_loja", salt)
		"guilda":
			var q = world.module("quests")
			if q != null and q.membro:
				return str(L.guilda_membro) % [str(q.rank().get("nome", "")), q.pontos]
			return str(L.guilda)
		"multa":
			var cr = world.module("crime")
			if cr == null or cr.total_fines() <= 0:
				return str(L.multa.sem_multa)
			return str(L.multa.nao_guarda)
		"lugar":
			if str(e.arg) == "":
				return str(L.sem_lugar)
			var p := world.db.world_to_tile(world.player.position)
			var alvo := world.db.location_spot(str(e.arg))
			var nome := str(world.db.location(str(e.arg)).get("name", e.arg))
			if world.db.location_at(p) == str(e.arg):
				return str(L.aqui) % nome
			return str(L.lugar) % [nome, _direcao(p, alvo), CombatSim.cheb(p, alvo)]
	return ""


## Conhecimento verificado para perguntas abertas (IA). Só fatos que o jogo já tem e que o jogador PODE saber:
## o lugar, as lojas, a guilda, os moradores presentes e os mistérios já descobertos. Limite de tamanho fixo.
const CONHECIMENTO_MAX := 900


static func conhecimento(world: WorldState, npc: String) -> String:
	var partes: Array = []
	var w = world.module("weather")
	partes.append("Agora: %s, tempo %s." % [DialogueVoice.period(world), w.region.condition if w != null else "limpo"])
	var npcs = world.module("npcs")
	var loc := str(npcs.npc(npc).get("location", "")) if npcs != null else ""
	if loc != "":
		partes.append("O morador está em: %s." % str(world.db.location(loc).get("name", loc)))
	var nomes_locais: Array = []
	for l in world.db.all_locations():
		if nomes_locais.size() >= 14:
			break
		nomes_locais.append(str(l.get("name", l.id)))
	partes.append("Lugares da vila e arredores: %s." % ", ".join(PackedStringArray(nomes_locais)))
	var lojas: Dictionary = world.db.economy.get("shops", {})
	var frases_lojas: Array = []
	for vend in lojas:
		if frases_lojas.size() >= 6:
			break
		var nomes_itens: Array = []
		for it in lojas[vend]:
			nomes_itens.append(str(world.db.items.get(str(it), {}).get("name", it)))
		var nv := str(world.npc_def(str(vend)).get("name", vend))
		frases_lojas.append("%s vende %s" % [nv, ", ".join(PackedStringArray(nomes_itens.slice(0, 4)))])
	partes.append("Lojas: %s." % "; ".join(PackedStringArray(frases_lojas)))
	var q = world.module("quests")
	if q != null:
		if q.membro:
			partes.append("Guilda: você é membro, rank %s, %d pontos." % [str(q.rank().get("nome", "")), int(q.pontos)])
		var titulos: Array = []
		for c in q.quadro:
			titulos.append(str(c.get("titulo", "")))
		if not titulos.is_empty():
			partes.append("Quadro da guilda: %s." % ", ".join(PackedStringArray(titulos.slice(0, 3))))
	var ex = world.module("exploration")
	if ex != null:
		var fatos: Array = []
		for f in ex.known_facts.keys():
			if fatos.size() >= 4:
				break
			var txt := world.db.fact_text(str(f))
			if txt != "":
				fatos.append(txt)
		if not fatos.is_empty():
			partes.append("Você já descobriu: %s." % " ".join(PackedStringArray(fatos)))
	if npcs != null and loc != "":
		var presentes: Array = []
		for id in npcs.npcs_at(loc):
			if presentes.size() >= 6:
				break
			presentes.append("%s (%s)" % [str(world.npc_def(id).get("name", id)), str(world.npc_def(id).get("profession", ""))])
		partes.append("Aqui agora: %s." % ", ".join(PackedStringArray(presentes)))
	var txt := " ".join(PackedStringArray(partes))
	return txt.substr(0, CONHECIMENTO_MAX)


## Convicções pessoais do morador (opiniões, não fatos): a fé e o ofício. Limite fixo.
const CONVICOES_MAX := 320


static func convicoes(world: WorldState, npc: String) -> String:
	var c: Dictionary = world.db.convicoes
	var d := world.npc_def(npc)
	var partes: Array = []
	var fe := str(d.get("devotion", ""))
	if fe != "" and c.get("devocao", {}).has(fe):
		partes.append(str(c.devocao[fe][0]))
	var prof := str(d.get("profession", ""))
	var linhas: Array = c.get("por_profissao", {}).get(prof, [])
	if not linhas.is_empty():
		partes.append(str(linhas[0]))
	if linhas.size() > 1:
		partes.append(str(linhas[1]))
	return " ".join(PackedStringArray(partes)).substr(0, CONVICOES_MAX)


## Ficha de fatos para o modelo de linguagem: só o que o morador PODE saber, sem segredos do mistério.
## Pergunta aberta (intenção desconhecida): a IA responde pelo conhecimento do mundo, não pela resposta pronta.
static func ficha(world: WorldState, npc: String, frase: String, base: String, intent: String = "") -> Dictionary:
	var d := world.npc_def(npc)
	var mem = world.module("memory")
	var lembrancas: Array = []
	if mem != null:
		var arr: Array = mem.list(npc).filter(func(m): return str(m.key) != "conheceu:player")
		arr.sort_custom(func(a, b): return a.tick > b.tick)
		for m in arr.slice(0, 3):
			lembrancas.append(str(m.text))
	var w = world.module("weather")
	return {"name": d.get("name", npc), "profession": d.get("profession", ""), "traits": d.get("traits", []),
		"register": DialogueVoice.register(world, npc), "tier": DialogueVoice.tier(world, npc), "period": DialogueVoice.period(world),
		"weather": w.region.condition if w != null else "limpo", "lembrancas": lembrancas, "frase": frase, "base": base,
		"aberta": intent == "desconhecido", "conhecimento": conhecimento(world, npc) if intent == "desconhecido" else "",
		"convicoes": convicoes(world, npc) if intent == "desconhecido" else "",
		"allowed_names": _nomes_permitidos(world)}


static func _nomes_permitidos(world: WorldState) -> Array:
	var out: Array = []
	for id in world.all_npc_ids():
		for parte in str(world.npc_def(id).get("name", "")).split(" "):
			if parte.length() > 3 and not out.has(parte):
				out.append(parte)
	for l in world.db.all_locations():
		for parte in str(l.get("name", "")).split(" "):
			if parte.length() > 3 and not out.has(parte):
				out.append(parte)
	return out
