class_name QuestModule
extends WorldModule
## Missões e a Guilda dos Aventureiros (ORIGINAL_DO_JOGO). O quadro da guilda (na sede) oferece contratos
## gerados de modelos em data/world/quests.json: caçar (as criaturas surgem no mundo com as fichas do LB),
## entregar um pacote e explorar um lugar. Cumprir dá ouro, XP e pontos de guilda; os pontos sobem o rank,
## e o rank libera contratos mais perigosos (ND máximo por rank). Missões de NPCs usam o mesmo formato.

var membro := false
var pontos := 0
var quadro: Array = []            # contratos oferecidos agora
var quadro_dia := -999
var ativas: Dictionary = {}       # id -> contrato com "progresso"
var feitas: Array = []            # histórico: {id, titulo, dia, ouro}
var criaturas: Dictionary = {}    # id da criatura de contrato -> definição (vai no save)
var _seq := 0


func module_id() -> String: return "quests"
func handled_commands() -> PackedStringArray: return PackedStringArray(["JoinGuild", "AcceptQuest", "AbandonQuest", "TurnInQuest"])
func subscribed_events() -> PackedStringArray: return PackedStringArray(["CREATURE_DEFEATED", "PLAYER_MOVED"])


func guilda() -> Dictionary:
	return world.db.quests.get("guilda", {})


func rank() -> Dictionary:
	var r: Dictionary = {}
	for x in guilda().get("ranks", []):
		if pontos >= int(x.pontos):
			r = x
	return r


func proximo_rank() -> Dictionary:
	for x in guilda().get("ranks", []):
		if pontos < int(x.pontos):
			return x
	return {}


func na_sede() -> bool:
	return world.db.location_at(world.db.world_to_tile(world.player.position)) == str(guilda().get("sede", "taverna"))


## Quadro renovado a cada N dias: contratos dentro do ND do rank (e um acima, marcado como arriscado).
func contratos() -> Array:
	if world.day_index() - quadro_dia >= int(guilda().get("renova_dias", 3)) or quadro.is_empty():
		_renovar_quadro()
	return quadro


func _renovar_quadro() -> void:
	quadro_dia = world.day_index()
	quadro.clear()
	var rng := world.rng.stream("world")
	var nd_max := float(rank().get("nd_max", 0.5))
	var cacas: Array = world.db.quests.get("cacas", []).filter(func(c): return _nd(str(c.rule)) <= nd_max * 2.0 + 0.01)
	var n := int(guilda().get("contratos_por_quadro", 5))
	for i in n:
		var tipo := "cacar" if i < n - 2 or cacas.is_empty() else ("entregar" if i == n - 2 else "explorar")
		if tipo == "cacar" and cacas.is_empty():
			tipo = "explorar"
		var c := {}
		match tipo:
			"cacar":
				var m: Dictionary = cacas[rng.randi() % cacas.size()]
				var zona: String = m.zonas[rng.randi() % m.zonas.size()]
				var qtd := rng.randi_range(int(m.grupo[0]), int(m.grupo[1]))
				var nd_total := _nd(str(m.rule)) * qtd + (_nd(str(m.acompanha[0])) * int(m.acompanha[1]) if m.has("acompanha") else 0.0)
				c = {"tipo": "cacar", "titulo": m.titulo, "texto": str(m.pedido) % _nome_zona(zona), "rule": m.rule, "qtd": qtd, "zona": zona,
					"acompanha": m.get("acompanha", []), "drop": m.get("drop", ""), "nd": nd_total,
					"ouro": int(round(maxf(8.0, nd_total * 40.0))), "pontos": maxi(2, int(round(nd_total * 8.0))), "risco": _nd(str(m.rule)) > nd_max}
			"entregar":
				var e: Array = world.db.quests.get("entregas", [])
				var m: Dictionary = e[rng.randi() % e.size()]
				c = {"tipo": "entregar", "titulo": m.titulo, "texto": m.pedido, "item": m.item, "para": m.para, "ouro": int(m.ouro), "pontos": int(m.pontos), "nd": 0.0}
			"explorar":
				var e: Array = world.db.quests.get("exploracoes", [])
				var m: Dictionary = e[rng.randi() % e.size()]
				c = {"tipo": "explorar", "titulo": m.titulo, "texto": m.pedido, "local": m.local, "ouro": int(m.ouro), "pontos": int(m.pontos), "nd": 0.0}
		_seq += 1
		c.id = "contrato_%d" % _seq
		if not ativas.values().any(func(a): return str(a.titulo) == str(c.titulo)):
			quadro.append(c)


func _nd(rule: String) -> float:
	return ProgressionModule.nd_value(world.rules.value(rule, {}).get("nd", "1"))


func _nome_zona(z: String) -> String:
	return {"vila": "Vila Alvorada", "estrada": "a estrada do leste", "floresta": "o Bosque Sombrio", "ruina": "as ruínas", "cripta": "a cripta",
		"serra": "a serra", "pedrabranca": "Pedrabranca"}.get(z, z)


func validate(cmd: GameCommand) -> PackedStringArray:
	var qid := str(cmd.payload.get("quest_id", ""))
	match cmd.type:
		"JoinGuild":
			if membro: return PackedStringArray(["você já é da guilda"])
			if not na_sede(): return PackedStringArray(["a inscrição é feita na sede da guilda"])
			if int(world.player.gold) < int(guilda().get("taxa", 10)): return PackedStringArray(["a taxa é T$ %d" % int(guilda().get("taxa", 10))])
		"AcceptQuest":
			if not membro: return PackedStringArray(["só membros da guilda pegam contratos"])
			if not na_sede(): return PackedStringArray(["os contratos ficam no quadro da sede"])
			if not contratos().any(func(c): return str(c.id) == qid): return PackedStringArray(["contrato não está no quadro"])
			if ativas.size() >= 4: return PackedStringArray(["no máximo 4 contratos ao mesmo tempo"])
		"AbandonQuest":
			if not ativas.has(qid): return PackedStringArray(["contrato não está ativo"])
		"TurnInQuest":
			if not ativas.has(qid): return PackedStringArray(["contrato não está ativo"])
			var a: Dictionary = ativas[qid]
			if not bool(a.progresso.get("feito", false)): return PackedStringArray(["ainda não cumprido"])
			if str(a.tipo) == "entregar":
				if world.db.location_at(world.db.world_to_tile(world.player.position)) != str(a.para): return PackedStringArray(["entregue no destino"])
			elif not na_sede():
				return PackedStringArray(["receba na sede da guilda"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	var qid := str(cmd.payload.get("quest_id", ""))
	match cmd.type:
		"JoinGuild":
			membro = true
			return [fact("GOLD_CHANGED", {"delta": -int(guilda().get("taxa", 10)), "reason": "inscrição na guilda"}),
				fact("GUILD_JOINED", {"rank": rank().get("id", "")}, ["player"])]
		"AcceptQuest":
			var c: Dictionary = contratos().filter(func(x): return str(x.id) == qid)[0]
			quadro.erase(c)
			c.progresso = {"feito": false, "mortos": 0}
			ativas[qid] = c
			var out: Array = [fact("QUEST_ACCEPTED", {"quest": qid, "titulo": c.titulo, "tipo": c.tipo}, ["player"])]
			match str(c.tipo):
				"cacar":
					c.criaturas = _invocar(c)
					c.alvo_tile = world.module("combat").creature_tile(c.criaturas[0]) if not c.criaturas.is_empty() else Vector2i(-1, -1)
					c.alvo_tile = [c.alvo_tile.x, c.alvo_tile.y]
				"entregar":
					out.append(fact("ITEM_GAINED", {"item": c.item, "from": "guilda"}, ["player"]))
					c.progresso.feito = true   # cumpre ao chegar ao destino (TurnInQuest lá)
				"explorar":
					c.alvo_tile = [world.db.location_spot(str(c.local)).x, world.db.location_spot(str(c.local)).y]
			if str(c.tipo) == "entregar":
				c.alvo_tile = [world.db.location_spot(str(c.para)).x, world.db.location_spot(str(c.para)).y]
			return out
		"AbandonQuest":
			var a: Dictionary = ativas[qid]
			ativas.erase(qid)
			_limpar_criaturas(a)
			var out_ab: Array = [fact("QUEST_ABANDONED", {"quest": qid, "titulo": a.titulo}, ["player"])]
			if str(a.tipo) == "entregar" and world.module("state").has_item(str(a.item)):
				out_ab.append(fact("ITEM_LOST", {"item": a.item}, ["player"]))
			if membro:
				pontos = maxi(0, pontos - 2)
			return out_ab
		"TurnInQuest":
			var a: Dictionary = ativas[qid]
			ativas.erase(qid)
			_limpar_criaturas(a)
			var antes := str(rank().get("id", ""))
			pontos += int(a.pontos)
			feitas.append({"id": qid, "titulo": a.titulo, "dia": world.day_index(), "ouro": int(a.ouro)})
			var out: Array = [fact("GOLD_CHANGED", {"delta": int(a.ouro), "reason": "contrato: " + str(a.titulo)}),
				fact("QUEST_COMPLETED", {"quest": qid, "titulo": a.titulo, "ouro": a.ouro, "pontos": a.pontos}, ["player"])]
			if str(a.tipo) == "entregar":
				out.append(fact("ITEM_LOST", {"item": a.item}, ["player"]))
			var prog = world.module("progression")
			if prog != null:
				out.append_array(prog.ganha_xp(int(round(maxf(50.0, float(a.nd) * 250.0))), "contrato da guilda"))
			if str(rank().get("id", "")) != antes:
				out.append(fact("GUILD_RANK_UP", {"rank": rank().get("nome", ""), "pontos": pontos}, ["player"]))
			return out
	return []


## Criaturas do contrato: definição nova no ContentDB (fichas do LB) e estado no CombatModule, juntas num ponto da zona.
func _invocar(c: Dictionary) -> Array:
	var combat = world.module("combat")
	if combat == null:
		return []
	var centro := _ponto_na_zona(str(c.zona))
	var regras: Array = []
	for i in int(c.qtd):
		regras.append(str(c.rule))
	if not (c.acompanha as Array).is_empty():
		for i in int(c.acompanha[1]):
			regras.append(str(c.acompanha[0]))
	var ids: Array = []
	var livres := _tiles_livres(centro, regras.size())
	for i in regras.size():
		var cid := "%s_c%d" % [c.id, i]
		var r: Dictionary = world.rules.value(regras[i], {})
		var d := {"id": cid, "name": str(r.get("nome", "Criatura")), "rule": regras[i], "faction": "contrato_" + str(c.id), "spawn": [livres[i].x, livres[i].y],
			"zone": c.zona, "contrato": c.id}
		if str(c.get("drop", "")) != "" and i == 0:
			d.items = [c.drop]
		criaturas[cid] = d
		world.db.add_creature(d)
		combat.registrar_criatura(cid)
		ids.append(cid)
	return ids


func _ponto_na_zona(z: String) -> Vector2i:
	var rect: Array = []
	for zz in world.db.map.get("zones", []):
		if str(zz.id) == z:
			rect = zz.rect
	var rng := world.rng.stream("world")
	var p := world.db.world_to_tile(world.player.position)
	if rect.is_empty():
		return p + Vector2i(8, 0)
	for tentativa in 200:
		var t := Vector2i(int(rect[0]) + rng.randi() % maxi(1, int(rect[2])), int(rect[1]) + rng.randi() % maxi(1, int(rect[3])))
		if _livre(t) and ((CombatSim.cheb(t, p) >= 10 and world.db.location_at(t) == "") or tentativa > 150):
			return t
	return Vector2i(int(rect[0]) + int(rect[2]) / 2, int(rect[1]) + int(rect[3]) / 2)


func _livre(t: Vector2i) -> bool:
	var obj = world.module("objects")
	return world.db.static_walkable(t) and not world.db.is_water(t) and (obj == null or obj.walkable(t))


func _tiles_livres(centro: Vector2i, n: int) -> Array:
	var out: Array = []
	for r in 6:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := centro + Vector2i(dx, dy)
				if out.size() < n and maxi(absi(dx), absi(dy)) == r and _livre(t) and not out.has(t):
					out.append(t)
	while out.size() < n:
		out.append(centro)
	return out


func _limpar_criaturas(a: Dictionary) -> void:
	var combat = world.module("combat")
	for cid in a.get("criaturas", []):
		criaturas.erase(cid)
		world.db.remove_creature(cid)
		if combat != null:
			combat.esquecer_criatura(cid)


func on_event(e: GameEvent) -> Array:
	var out: Array = []
	match e.event_type:
		"CREATURE_DEFEATED":
			for qid in ativas:
				var a: Dictionary = ativas[qid]
				if (a.get("criaturas", []) as Array).has(str(e.payload.get("creature", ""))):
					a.progresso.mortos = int(a.progresso.mortos) + 1
					if int(a.progresso.mortos) >= (a.criaturas as Array).size() and not bool(a.progresso.feito):
						a.progresso.feito = true
						out.append(fact("QUEST_OBJECTIVE_DONE", {"quest": qid, "titulo": a.titulo, "texto": "Volte à guilda para receber."}, ["player"]))
		"PLAYER_MOVED":
			var loc := world.db.location_at(world.db.world_to_tile(world.player.position))
			for qid in ativas:
				var a: Dictionary = ativas[qid]
				if str(a.tipo) == "explorar" and not bool(a.progresso.feito) and loc == str(a.local):
					a.progresso.feito = true
					out.append(fact("QUEST_OBJECTIVE_DONE", {"quest": qid, "titulo": a.titulo, "texto": "Volte à guilda para receber."}, ["player"]))
	return out


## Texto de progresso para o diário de missões.
func progresso_texto(a: Dictionary) -> String:
	match str(a.tipo):
		"cacar":
			return ("Cumprido: volte à guilda." if bool(a.progresso.feito) else "Derrotados %d de %d em %s." % [int(a.progresso.mortos), (a.get("criaturas", []) as Array).size(), _nome_zona(str(a.zona))])
		"entregar":
			return "Leve até %s e entregue lá." % str(world.db.location(str(a.para)).get("name", a.para))
		"explorar":
			return "Cumprido: volte à guilda." if bool(a.progresso.feito) else "Vá até %s." % str(world.db.location(str(a.local)).get("name", a.local))
	return ""


func to_dict() -> Dictionary:
	return {"membro": membro, "pontos": pontos, "quadro": quadro.duplicate(true), "quadro_dia": quadro_dia, "ativas": ativas.duplicate(true),
		"feitas": feitas.duplicate(true), "criaturas": criaturas.duplicate(true), "seq": _seq}


func from_dict(d: Dictionary) -> void:
	membro = bool(d.get("membro", false))
	pontos = int(d.get("pontos", 0))
	quadro = d.get("quadro", []).duplicate(true)
	quadro_dia = int(d.get("quadro_dia", -999))
	ativas = d.get("ativas", {}).duplicate(true)
	feitas = d.get("feitas", []).duplicate(true)
	_seq = int(d.get("seq", 0))
	world.db.clear_dynamic_creatures()
	criaturas = d.get("criaturas", {}).duplicate(true)
	for cid in criaturas:
		world.db.add_creature(criaturas[cid])
