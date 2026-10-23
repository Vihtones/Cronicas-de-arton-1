class_name DialogueModule
extends WorldModule
## Diálogo estruturado (§6, §8). Opções com condições sobre o estado e efeitos que
## viram fatos. A IA opcional (DialogueProvider) só reescreve o TEXTO exibido;
## opções, testes e efeitos são sempre decididos aqui.

var session: Dictionary = {}  # {npc, node}


func module_id() -> String: return "dialogue"
func handled_commands() -> PackedStringArray: return PackedStringArray(["StartDialogue", "ChooseOption", "EndDialogue"])
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


## Nós gerados a partir do estado (rumores, saudação genérica).
func _dynamic_node(npc: String, node_id: String) -> Dictionary:
	var d := world.db.npc_def(npc)
	match node_id:
		"__generic":
			var rep := _rep(npc)
			var greet := "Bom dia." if world.hour() < 12 else ("Boa tarde." if world.hour() < 18 else "Boa noite.")
			if rep >= 30: greet = "Ah, é você! Sempre bem-vindo."
			elif rep <= -20: greet = "...O que você quer?"
			return {"text": "%s Sou %s, %s." % [greet, d.name, d.profession], "options": []}
		"__rumor":
			var mem = world.module("memory")
			var best: Dictionary = {}
			if mem != null:
				var arr: Array = mem.list(npc).filter(func(m): return m.key != "conheceu:player" and m.about != npc)
				arr.sort_custom(func(a, b): return a.tick > b.tick)
				if not arr.is_empty(): best = arr[0]
			if best.is_empty():
				return {"text": "Nada de novo. A vida segue.", "options": [{"text": "Entendo.", "next": "__generic"}]}
			var prefix := "Eu vi com estes olhos: " if best.source == "testemunha" else ("Contaram-me que " if str(best.source).begins_with("rumor") else "")
			return {"text": prefix + str(best.text), "options": [{"text": "Interessante.", "next": "__generic"}]}
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
					if world.db.npc_def(npc).get("faction", "") != str(v): return false
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
	return {"npc": npc, "name": world.db.npc_def(npc).get("name", npc), "node": session.node, "text": node.get("text", ""), "options": opts}


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
			var t: Vector2i = npcs.npc_tile(id)
			var p := world.db.world_to_tile(world.player.position)
			if CombatSim.cheb(t, p) > 2: return PackedStringArray(["longe demais para conversar"])
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
	return PackedStringArray()


func _test_key(o: Dictionary) -> String:
	return "dlg:%s:%s:%s" % [session.npc, session.node, str(o.text).sha256_text().substr(0, 8)]


func execute(cmd: GameCommand) -> Array:
	match cmd.type:
		"StartDialogue":
			var id: String = cmd.payload.npc_id
			session = {"npc": id, "node": _start_node(id)}
			return [fact("DIALOGUE_STARTED", {"npc": id, "node": session.node,
				"location": world.db.location_at(world.db.world_to_tile(world.player.position))}, ["player", id])]
		"EndDialogue":
			var id: String = session.npc
			session = {}
			return [fact("DIALOGUE_ENDED", {"npc": id}, ["player", id])]
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
			if next == "end":
				var id: String = session.npc
				session = {}
				out.append(fact("DIALOGUE_ENDED", {"npc": id}, ["player", id]))
			else:
				session.node = next
			return out
	return []


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


func to_dict() -> Dictionary: return {"session": session.duplicate()}
func from_dict(d: Dictionary) -> void: session = d.get("session", {}).duplicate()
