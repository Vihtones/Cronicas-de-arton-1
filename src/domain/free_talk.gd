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


## Ficha de fatos para o modelo de linguagem: só o que o morador PODE saber, sem segredos do mistério.
static func ficha(world: WorldState, npc: String, frase: String, base: String) -> Dictionary:
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
