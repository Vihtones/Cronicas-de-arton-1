class_name DialogueModule
extends WorldModule
## Diálogo estruturado (§6, §8). Opções com condições sobre o estado e efeitos que
## viram fatos. A IA opcional (DialogueProvider) só reescreve o TEXTO exibido;
## opções, testes e efeitos são sempre decididos aqui.

var session: Dictionary = {}  # {npc, node, visit, repeat}
## Memória da conversa por morador: {count, last_day, seen:{nó dinâmico: dia}}. Só texto (não muda regras):
## serve para o morador reconhecer que já se falaram hoje, que o jogador voltou depois de dias e que o assunto repete.
var talks: Dictionary = {}


func module_id() -> String: return "dialogue"
func handled_commands() -> PackedStringArray: return PackedStringArray(["StartDialogue", "ChooseOption", "EndDialogue", "Say"])
func subscribed_events() -> PackedStringArray: return PackedStringArray(["DIALOGUE_ENDED"])


func on_event(e: GameEvent) -> Array:
	if e.event_type == "DIALOGUE_ENDED" and e.payload.get("reason", "") == "combate":
		session = {}
	return []


func _tree(npc: String) -> Dictionary:
	return world.db.dialogue.get("npcs", {}).get(npc, {})


func _node(npc: String, node_id: String) -> Dictionary:
	if node_id.begins_with("__"):
		return _dynamic_node(npc, node_id)
	var t := _tree(npc)
	if t.has("nodes") and t.nodes.has(node_id):
		return t.nodes[node_id]
	return world.db.dialogue.get("generic", {}).get("nodes", {}).get(node_id, {})


func _start_node(npc: String) -> String:
	var t := _tree(npc)
	for entry in t.get("entries", []):
		if _conds_ok(npc, entry.get("cond", [])):
			return entry.node
	return t.get("start", "__generic")


## Nós gerados a partir do estado (saudação, papo, rumores, opiniões). A voz vem de DialogueVoice.
func _dynamic_node(npc: String, node_id: String) -> Dictionary:
	var d := world.npc_def(npc)
	var back := {"text": "Mudar de assunto.", "next": "__papo"}
	var again := "Já lhe falei disso hoje. " if bool(session.get("repeat", false)) else ""
	var key := node_id.get_slice(":", 0)
	match key:
		"__livre":   # resposta da fala livre (texto montado em Say)
			var fim: bool = bool(session.get("livre_fim", false))
			return {"text": str(session.get("livre", "")), "options": [{"text": "Ir embora.", "next": "end"}] if fim else \
				[{"text": "Mudar de assunto.", "next": "__papo"}, {"text": "Até mais.", "next": "end"}]}
		"__generic":
			var visit: Dictionary = session.get("visit", {"kind": "conhecido", "count": 1})
			var text := DialogueVoice.greeting(world, npc, visit)
			if str(visit.get("kind", "")) == "primeira":
				text += " Sou %s, %s." % [d.name, d.profession]
			return {"text": text, "options": []}
		"__papo":
			var opts: Array = [{"text": "O que se conta por aí?", "next": "__rumor"}, {"text": "Como vai o trabalho?", "next": "__trabalho"},
				{"text": "Que tempo, não?", "next": "__tempo"}]
			for ev in DialogueVoice.active_event_ids(world):
				opts.append({"text": "O que acha da %s?" % ev, "next": "__evento:" + str(ev)})
			opts.append({"text": "Fale-me da gente da vila.", "next": "__gente"})
			opts.append({"text": "Fale um pouco de você.", "next": "__bio"})
			opts.append({"text": "Voltar.", "next": "__generic"})
			return {"text": "Sobre o que quer conversar?", "options": opts}
		"__trabalho":
			return {"text": again + DialogueVoice.work(world, npc), "options": [back]}
		"__tempo":
			return {"text": again + DialogueVoice.weather(world, npc), "options": [back]}
		"__evento":
			return {"text": again + DialogueVoice.event(world, npc, node_id.get_slice(":", 1)), "options": [back]}
		"__gente":
			var opts2: Array = []
			for id in DialogueVoice.people_of_interest(world, npc):
				opts2.append({"text": "E %s?" % str(world.npc_def(id).get("name", id)).split(" ")[0], "next": "__opiniao:" + str(id)})
			opts2.append({"text": "Voltar.", "next": "__papo"})
			return {"text": "Gente não falta por aqui. De quem quer saber?", "options": opts2}
		"__opiniao":
			return {"text": again + DialogueVoice.opinion(world, npc, node_id.get_slice(":", 1)), "options": [{"text": "E os outros?", "next": "__gente"}, back]}
		"__bio":
			return {"text": again + Biography.for_npc(d, int(world.rng.world_seed)), "options": [back]}
		"__rumor":
			var mem = world.module("memory")
			var best: Dictionary = {}
			if mem != null:
				var arr: Array = mem.list(npc).filter(func(m): return m.key != "conheceu:player" and m.about != npc)
				arr.sort_custom(func(a, b): return a.tick > b.tick)
				if not arr.is_empty(): best = arr[0]
			if best.is_empty():
				return {"text": again + "Nada de novo. A vida segue.", "options": [back]}
			var prefix := "Eu vi com estes olhos: " if best.source == "testemunha" else ("Contaram-me que " if str(best.source).begins_with("rumor") else "")
			return {"text": again + prefix + str(best.text), "options": [back]}
	return {}


func _rep(npc: String) -> float:
	var mem = world.module("memory")
	return mem.reputation(npc) if mem != null else 0.0


func _known(f: String) -> bool:
	var ex = world.module("exploration")
	return ex != null and ex.knows(f)


func _conds_ok(npc: String, conds: Array) -> bool:
	var st = world.module("state")
	for c in conds:
		for k in c:
			var v = c[k]
			match k:
				"fact": if not _known(v): return false
				"not_fact": if _known(v): return false
				"flag": if not st.has_flag(v): return false
				"not_flag": if st.has_flag(v): return false
				"item": if not st.has_item(v): return false
				"not_item": if st.has_item(v): return false
				"rep_gte": if _rep(npc) < float(v): return false
				"rep_lt": if _rep(npc) >= float(v): return false
				"gold_gte": if int(world.player.gold) < int(v): return false
				"mystery":
					var ex = world.module("exploration")
					if ex == null or ex.mystery_state != v: return false
				"captive":
					var n = world.module("npcs")
					if n == null or bool(n.npc(v).get("captive", false)) == false: return false
				"not_captive":
					var n = world.module("npcs")
					if n != null and bool(n.npc(v).get("captive", false)): return false
				"object_open":
					var o = world.module("objects")
					if o == null or not (o.obj(v).get("open", false) or o.obj(v).get("broken", false)): return false
				"warrant":
					var cr = world.module("crime")
					if cr == null or (cr.total_fines() > 0) != bool(v): return false
				"devotion":
					if world.player_sheet.devotion != str(v): return false
				"faction_member":
					if world.npc_def(npc).get("faction", "") != str(v): return false
				"shop":
					if world.db.economy.get("shops", {}).has(npc) != bool(v): return false
	return true


## Opções visíveis = do nó + genéricas aplicáveis.
func visible_options(npc: String, node_id: String) -> Array:
	var node := _node(npc, node_id)
	var out: Array = []
	var raw: Array = node.get("options", []).duplicate(true)
	if node_id == "__generic" or node.get("append_generic", false):
		raw.append_array(_tree(npc).get("topics", []))
		raw.append_array(world.db.dialogue.get("generic", {}).get("topics", []))
	for i in raw.size():
		var o: Dictionary = raw[i]
		if _conds_ok(npc, o.get("cond", [])):
			out.append(o)
	return out


func view() -> Dictionary:
	if session.is_empty():
		return {}
	var npc: String = session.npc
	var node := _node(npc, session.node)
	var opts := []
	var vis := visible_options(npc, session.node)
	for i in vis.size():
		var o: Dictionary = vis[i]
		var label: String = o.text
		if o.has("test"):
			label += "  [%s CD %d]" % [str(o.test.skill).capitalize(), int(o.test.cd)]
		opts.append({"index": i, "text": label})
	return {"npc": npc, "name": world.npc_def(npc).get("name", npc), "node": session.node, "text": node.get("text", ""), "options": opts,
		"chat": session.get("chat", []), "intent": str(session.get("intent", "")), "ficha": FreeTalk.ficha(world, npc, str(session.get("chat", [{}]).back().get("q", "")) if not (session.get("chat", []) as Array).is_empty() else "", str(node.get("text", "")))}


func validate(cmd: GameCommand) -> PackedStringArray:
	var combat = world.module("combat")
	if combat != null and combat.active:
		return PackedStringArray(["em combate"])
	match cmd.type:
		"StartDialogue":
			var id: String = cmd.payload.get("npc_id", "")
			var npcs = world.module("npcs")
			if npcs == null or npcs.npc(id).is_empty(): return PackedStringArray(["ninguém aqui"])
			if not npcs.npc(id).alive: return PackedStringArray(["não responde"])
			var magia_so = world.module("magia")
			if magia_so != null and magia_so.adormecido(id): return PackedStringArray(["está dormindo"])
			var t: Vector2i = npcs.npc_tile(id)
			var p := world.db.world_to_tile(world.player.position)
			var magia_pc = world.module("magia")
			var projetado: bool = magia_pc != null and magia_pc.projecao_ve(id)   # Projetar Consciência: fala mental com quem a projeção vê
			if CombatSim.cheb(t, p) > 2 and not projetado: return PackedStringArray(["longe demais para conversar"])
		"ChooseOption":
			if session.is_empty(): return PackedStringArray(["sem conversa"])
			var vis := visible_options(session.npc, session.node)
			var i := int(cmd.payload.get("index", -1))
			if i < 0 or i >= vis.size(): return PackedStringArray(["opção indisponível"])
			var o: Dictionary = vis[i]
			if o.has("test"):
				var ex = world.module("exploration")
				var why: String = ex.loop_block_reason(_test_key(o), o.test.skill) if ex != null else ""
				if why != "": return PackedStringArray([why])
				if not world.player_sheet.can_use_skill(o.test.skill, world.rules):
					return PackedStringArray(["%s é somente treinada" % o.test.skill])
			for e in o.get("effects", []):
				if e.has("gold") and int(e.gold) < 0 and int(world.player.gold) < -int(e.gold):
					return PackedStringArray(["ouro insuficiente"])
		"EndDialogue":
			if session.is_empty(): return PackedStringArray(["sem conversa"])
		"Say":
			if session.is_empty(): return PackedStringArray(["sem conversa"])
			var fala := str(cmd.payload.get("text", "")).strip_edges()
			if fala == "": return PackedStringArray(["diga alguma coisa"])
			if fala.length() > FreeTalk.MAX_CHARS: return PackedStringArray(["frase longa demais (até %d letras)" % FreeTalk.MAX_CHARS])
	return PackedStringArray()


func _test_key(o: Dictionary) -> String:
	return "dlg:%s:%s:%s" % [session.npc, session.node, str(o.text).sha256_text().substr(0, 8)]


func execute(cmd: GameCommand) -> Array:
	match cmd.type:
		"StartDialogue":
			var id: String = cmd.payload.npc_id
			session = {"npc": id, "node": _start_node(id), "visit": _register_visit(id), "repeat": false}
			return [fact("DIALOGUE_STARTED", {"npc": id, "node": session.node,
				"location": world.db.location_at(world.db.world_to_tile(world.player.position))}, ["player", id])]
		"EndDialogue":
			var id: String = session.npc
			session = {}
			return [fact("DIALOGUE_ENDED", {"npc": id}, ["player", id])]
		"Say":
			return _dizer(str(cmd.payload.text).strip_edges().substr(0, FreeTalk.MAX_CHARS))
		"ChooseOption":
			var vis := visible_options(session.npc, session.node)
			var o: Dictionary = vis[int(cmd.payload.index)]
			var out: Array = [fact("DIALOGUE_CHOICE", {"npc": session.npc, "node": session.node, "text": o.text}, ["player", session.npc])]
			var effects: Array = o.get("effects", []).duplicate()
			var next: String = o.get("next", session.node)
			if o.has("test"):
				var r := Checks.skill(world.player_sheet, o.test.skill, int(o.test.cd), world.rules, world.rng)
				var ex = world.module("exploration")
				if ex != null: ex.record_attempt(_test_key(o), o.test.skill, r.success)
				out.append(fact("DIALOGUE_TEST", {"npc": session.npc, "check": r}, ["player"]))
				effects.append_array(o.test.get("ok_effects" if r.success else "fail_effects", []))
				next = o.test.get("ok_next" if r.success else "fail_next", next)
			out.append_array(_apply_effects(effects))
			session["repeat"] = false
			if next.begins_with("__") and next not in ["__generic", "__papo", "__gente"]:
				if not talks.has(session.npc):
					talks[session.npc] = {"count": 1, "last_day": world.day_index(), "seen": {}}
				var seen: Dictionary = talks[session.npc].seen
				session["repeat"] = int(seen.get(next, -1)) == world.day_index()
				seen[next] = world.day_index()
			if next == "end":
				var id: String = session.npc
				session = {}
				out.append(fact("DIALOGUE_ENDED", {"npc": id}, ["player", id]))
			else:
				session.node = next
			return out
	return []


## Fala livre: entende a frase, escolhe o assunto e deixa o morador responder pelo estado do mundo.
func _dizer(frase: String) -> Array:
	var npc: String = session.npc
	var e := FreeTalk.entender(world, npc, frase)
	var intent := str(e.intent)
	var out: Array = [fact("DIALOGUE_SAID", {"npc": npc, "text": frase, "intent": intent}, ["player", npc])]
	var no := ""
	var efeitos: Array = []
	var fim := false
	var salt := int(talks.get(npc, {}).get("count", 0)) + (session.get("chat", []) as Array).size()
	match intent:
		"rumor": no = "__rumor"
		"trabalho": no = "__trabalho"
		"tempo": no = "__tempo"
		"bio": no = "__bio"
		"gente": no = "__gente"
		"evento":
			if str(e.arg) != "":
				no = "__evento:" + str(e.arg)
			else:
				session["livre"] = "Nada de especial na vila hoje."
				no = "__livre"
		"pessoa":
			if str(e.arg) == "tomas" and _conds_ok(npc, [{"fact": "f_tomas_sumiu"}, {"mystery": "ativo"}]):
				no = "g_tomas"
			else:
				no = "__opiniao:" + str(e.arg)
		"loja":
			session["livre"] = FreeTalk.resposta_direta(world, npc, e, salt)
			no = "__livre"
			if world.db.economy.get("shops", {}).has(npc):
				efeitos.append({"event": "OPEN_SHOP"})
		"multa":
			if _conds_ok(npc, [{"warrant": true}, {"faction_member": "guarda_vila"}]):
				efeitos.append({"pay_fine": true})
				no = "g_multa_paga"
			else:
				session["livre"] = FreeTalk.resposta_direta(world, npc, e, salt)
				no = "__livre"
		_:
			session["livre"] = FreeTalk.resposta_direta(world, npc, e, salt)
			no = "__livre"
			fim = intent == "despedida"
	if intent == "insulto" or intent == "ameaca":
		out.append(fact("PLAYER_INSULTED" if intent == "insulto" else "PLAYER_THREATENED", {"npc": npc, "witnesses": [npc], "actor": "player",
			"location": world.db.location_at(world.db.world_to_tile(world.player.position))}, ["player", npc]))
		fim = intent == "ameaca"
	session["livre_fim"] = fim
	out.append_array(_apply_effects(efeitos))
	session["repeat"] = false
	if no.begins_with("__") and no not in ["__generic", "__papo", "__gente", "__livre"]:
		if not talks.has(npc):
			talks[npc] = {"count": 1, "last_day": world.day_index(), "seen": {}}
		var seen: Dictionary = talks[npc].seen
		session["repeat"] = int(seen.get(no, -1)) == world.day_index()
		seen[no] = world.day_index()
	session.node = no
	var chat: Array = session.get("chat", [])
	chat.append({"q": frase, "r": str(_node(npc, no).get("text", ""))})
	session["chat"] = chat.slice(-6)
	session["intent"] = intent
	return out


func _apply_effects(effects: Array) -> Array:
	var out: Array = []
	var loc := world.db.location_at(world.db.world_to_tile(world.player.position))
	for e in effects:
		for k in e:
			var v = e[k]
			match k:
				"reveal": out.append(fact("FACT_REVEALED", {"fact": v, "source": "dialogo:" + str(session.get("npc", ""))}))
				"flag": out.append(fact("FLAG_SET", {"flag": v}))
				"give_item": out.append(fact("ITEM_GAINED", {"item": v}, ["player"]))
				"take_item": out.append(fact("ITEM_LOST", {"item": v}, ["player"]))
				"gold": out.append(fact("GOLD_CHANGED", {"delta": int(v), "reason": "dialogo"}))
				"event":
					var p: Dictionary = e.get("payload", {}).duplicate()
					p["location"] = loc
					p["actor"] = "player"
					out.append(fact(str(v), p, ["player"]))
				"pay_fine":
					var cr = world.module("crime")
					if cr != null and cr.total_fines() > 0 and int(world.player.gold) >= cr.total_fines():
						out.append_array(cr.execute(GameCommand.create("dlg_fine", "player", "PayFine")))
				"rescue":
					var n = world.module("npcs")
					if n != null:
						var c := GameCommand.create("dlg_rescue", "player", "RescueNPC", {"npc_id": v})
						if n.validate(c).is_empty():
							out.append_array(n.execute(c))
	return out


## Registra a visita (quantas vezes já falaram, se foi hoje ou depois de dias) e devolve como ela conta para a saudação.
func _register_visit(npc: String) -> Dictionary:
	var today := world.day_index()
	var t: Dictionary = talks.get(npc, {"count": 0, "last_day": today, "seen": {}})
	var kind := "conhecido"
	if int(t.count) == 0:
		kind = "primeira"
	elif int(t.last_day) == today:
		kind = "mesmo_dia"
	elif today - int(t.last_day) >= 2:
		kind = "retorno"
	var visit := {"kind": kind, "gap": today - int(t.last_day), "count": int(t.count)}
	t.count = int(t.count) + 1
	t.last_day = today
	talks[npc] = t
	return visit


func to_dict() -> Dictionary: return {"session": session.duplicate(true), "talks": talks.duplicate(true)}
func from_dict(d: Dictionary) -> void:
	session = d.get("session", {}).duplicate(true)
	talks = d.get("talks", {}).duplicate(true)
	for k in talks:   # JSON devolve números como float: normaliza para o que o código compara
		talks[k].count = int(talks[k].count)
		talks[k].last_day = int(talks[k].last_day)
		for n in talks[k].seen:
			talks[k].seen[n] = int(talks[k].seen[n])
