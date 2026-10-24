class_name ExplorationModule
extends WorldModule
## Exploração ativa e mistérios (§10). Sem Percepção automática: sinais naturais
## são descritos; testes só ocorrem quando o jogador pede uma ação.
## Anti-loop: repetir a mesma abordagem que falhou exige mudança material
## (outra perícia, mais tempo, ou valor de perícia diferente).

const RETRY_TICKS := 6 * 24  # 1 dia de jogo — ORIGINAL_DO_JOGO, configurável

var known_facts: Dictionary = {}     # fact_id -> {tick, source}
var hypotheses: Dictionary = {}      # h_id -> "aberta" | "acredito" | "descartada"
var attempts: Dictionary = {}        # "alvo|pericia" -> {tick, success, skill_value}
var mystery_state: String = "ativo"  # ativo | resolvido | perdido
var notes: Array[Dictionary] = []    # entradas do diário (texto exibido ao jogador)
var flags_seen: Dictionary = {}
var side_states: Dictionary = {}     # mistérios secundários: truth_id -> estado
var weather_affects_tests: bool = true  # ADAPTADA: neblina/chuva forte dificultam percepção ao ar livre


func module_id() -> String: return "exploration"
func handled_commands() -> PackedStringArray: return PackedStringArray(["InspectTarget", "MarkHypothesis"])
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(["FACT_REVEALED", "NPC_RESCUED", "BANDITS_RELOCATED", "PLAYER_MOVED", "PLAYER_TELEPORTED", "ITEM_GAINED",
		"SHEEP_KILLED", "CREATURE_DEFEATED"])


func _ensure() -> void:
	if not hypotheses.is_empty():
		return
	for m in world.db.mysteries:
		for h in m.get("hypotheses", {}):
			hypotheses[h] = "aberta"
		if m != world.db.mystery:
			side_states[m.truth_id] = "latente"
	for f in world.db.mystery.get("start_facts", []):
		known_facts[f] = {"tick": 0, "source": "inicio"}
		notes.append({"tick": 0, "text": world.db.mystery.facts[f], "fact": f})


func knows(f: String) -> bool:
	return known_facts.has(f)


## Sinais naturalmente perceptíveis perto do jogador — sem rolagem.
func nearby_signals(radius: int = 2) -> Array:
	var p := world.db.world_to_tile(world.player.position)
	var out: Array = []
	var st = world.module("state")
	for t in world.db.all_targets():
		if t.has("requires_flag") and (st == null or not st.has_flag(t.requires_flag)):
			continue
		var tt := Vector2i(int(t.tile[0]), int(t.tile[1]))
		if absi(tt.x - p.x) <= radius and absi(tt.y - p.y) <= radius:
			out.append({"id": t.id, "name": t.name, "signal": t.signal, "actions": t.actions.keys()})
	return out


func loop_block_reason(target_key: String, skill: String) -> String:
	var k := target_key + "|" + skill
	if not attempts.has(k):
		return ""
	var a: Dictionary = attempts[k]
	if a.success:
		return "Você já obteve o que podia dessa forma."
	var now_value := world.player_sheet.skill_value(skill, world.rules)
	if now_value != int(a.skill_value):
		return ""  # mudança material: competência diferente
	if world.clock.tick - int(a.tick) >= RETRY_TICKS:
		return ""  # mudança material: tempo e nova perspectiva
	return "Você já tentou isso desse jeito. Tente outra abordagem, volte depois ou traga ajuda."


func record_attempt(target_key: String, skill: String, success: bool) -> void:
	attempts[target_key + "|" + skill] = {"tick": world.clock.tick, "success": success,
		"skill_value": world.player_sheet.skill_value(skill, world.rules)}


func validate(cmd: GameCommand) -> PackedStringArray:
	_ensure()
	match cmd.type:
		"InspectTarget":
			var t := world.db.target_def(cmd.payload.get("target_id", ""))
			if t.is_empty(): return PackedStringArray(["nada para examinar"])
			if t.has("requires_flag") and not world.module("state").has_flag(t.requires_flag): return PackedStringArray(["nada de especial aqui"])
			var approach: String = cmd.payload.get("approach", "")
			if not t.actions.has(approach): return PackedStringArray(["abordagem não se aplica: " + approach])
			var tt := Vector2i(int(t.tile[0]), int(t.tile[1]))
			var p := world.db.world_to_tile(world.player.position)
			if absi(tt.x - p.x) > 1 or absi(tt.y - p.y) > 1:
				return PackedStringArray(["chegue mais perto"])
			var a: Dictionary = t.actions[approach]
			if not world.player_sheet.can_use_skill(a.skill, world.rules):
				return PackedStringArray(["%s é somente treinada" % a.skill])
			var why := loop_block_reason("alvo:" + t.id, a.skill)
			if why != "": return PackedStringArray([why])
			var combat = world.module("combat")
			if combat != null and combat.active: return PackedStringArray(["em combate"])
		"MarkHypothesis":
			if not hypotheses.has(cmd.payload.get("hypothesis_id", "")): return PackedStringArray(["hipótese desconhecida"])
			if not ["aberta", "acredito", "descartada"].has(cmd.payload.get("state", "")): return PackedStringArray(["estado inválido"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	match cmd.type:
		"InspectTarget":
			var t := world.db.target_def(cmd.payload.target_id)
			var a: Dictionary = t.actions[cmd.payload.approach]
			var cd := int(a.cd) + _environment_cd_mod(t)
			var ctx := "subterraneo" if world.db.zone_at(world.db.world_to_tile(world.player.position)) == "cripta" else ""
			var r := Checks.skill(world.player_sheet, a.skill, cd, world.rules, world.rng, "world", world.player_sheet.skill_value(a.skill, world.rules, ctx) - world.player_sheet.skill_value(a.skill, world.rules))
			record_attempt("alvo:" + t.id, a.skill, r.success)
			var out: Array = [fact("TARGET_INSPECTED", {"target": t.id, "approach": cmd.payload.approach, "check": r,
				"text": a.ok if r.success else a.fail}, ["player"])]
			if r.success:
				for f in a.get("reveals", []):
					out.append(fact("FACT_REVEALED", {"fact": f, "source": "alvo:" + t.id}, ["player"]))
				if a.has("flag"):
					out.append(fact("FLAG_SET", {"flag": a.flag}))
			return out
		"MarkHypothesis":
			hypotheses[cmd.payload.hypothesis_id] = cmd.payload.state
			return [fact("HYPOTHESIS_MARKED", {"hypothesis": cmd.payload.hypothesis_id, "state": cmd.payload.state}, ["player"])]
	return []


func _environment_cd_mod(t: Dictionary) -> int:
	if not weather_affects_tests:
		return 0
	var w = world.module("weather")
	var loc := world.db.location(world.db.location_at(Vector2i(int(t.tile[0]), int(t.tile[1]))))
	if w == null or bool(loc.get("indoor", false)):
		return 0
	return w.perception_cd_mod()


func on_event(e: GameEvent) -> Array:
	_ensure()
	match e.event_type:
		"FACT_REVEALED":
			var f: String = e.payload.fact
			if not known_facts.has(f) and world.db.fact_text(f) != "":
				known_facts[f] = {"tick": e.world_tick, "source": e.payload.get("source", "")}
				notes.append({"tick": e.world_tick, "text": world.db.fact_text(f), "fact": f, "mystery": world.db.mystery_of_fact(f)})
				var mid := world.db.mystery_of_fact(f)
				if side_states.get(mid, "") == "latente":
					side_states[mid] = "ativo"
		"NPC_RESCUED":
			if e.payload.npc == "tomas" and mystery_state == "ativo":
				mystery_state = "resolvido"
				return [fact("MYSTERY_RESOLVED", {"mystery": world.db.mystery.truth_id, "by": e.payload.rescuer}),
					fact("FACT_REVEALED", {"fact": "f_tomas_na_masmorra", "source": "resgate"})]
		"BANDITS_RELOCATED":
			if mystery_state == "ativo":
				mystery_state = "perdido"
				notes.append({"tick": e.world_tick, "text": "A cripta está vazia. Quem estava aqui partiu, e levou o que tinha.", "fact": ""})
				return [fact("MYSTERY_LOST", {"mystery": world.db.mystery.truth_id})]
		"PLAYER_MOVED", "PLAYER_TELEPORTED":
			var loc := world.db.location_at(world.db.world_to_tile(world.player.position))
			var npcs = world.module("npcs")
			if loc == "cripta_cela" and npcs != null and npcs.npc("tomas").get("captive", false) and not knows("f_tomas_na_masmorra"):
				return [fact("FACT_REVEALED", {"fact": "f_tomas_na_masmorra", "source": "visto"})]
		"SHEEP_KILLED":
			return [fact("FLAG_SET", {"flag": "ovelha_morta"})]
		"CREATURE_DEFEATED":
			var fauna = world.module("fauna")
			if side_states.get("m_ovelhas", "") == "ativo" and fauna != null and fauna.pack_size() == 0:
				side_states["m_ovelhas"] = "resolvido"
				return [fact("MYSTERY_RESOLVED", {"mystery": "m_ovelhas", "by": e.payload.get("by", "player")})]
		"ITEM_GAINED":
			if e.payload.item == "dizimo_lena" and not knows("f_dizimo_roubado"):
				return [fact("FACT_REVEALED", {"fact": "f_dizimo_roubado", "source": "bau"})]
	return []


## Avaliação das hipóteses só com o que o jogador sabe (nunca revela a verdade).
func hypothesis_view() -> Array:
	_ensure()
	var out: Array = []
	for m in world.db.mysteries:
		if m != world.db.mystery and side_states.get(m.truth_id, "latente") == "latente":
			continue
		for h in m.get("hypotheses", {}):
			out.append(_hview(m, h))
	return out


func _hview(m: Dictionary, h: String) -> Dictionary:
	var def: Dictionary = m.hypotheses[h]
	var sup := []
	var con := []
	for f in def.supported_by:
		if knows(f): sup.append(f)
	for f in def.contradicted_by:
		if knows(f): con.append(f)
	return {"id": h, "mystery": m.truth_id, "text": def.text, "state": hypotheses.get(h, "aberta"), "supporting": sup, "contradicting": con}


func to_dict() -> Dictionary:
	_ensure()
	return {"known_facts": known_facts.duplicate(true), "hypotheses": hypotheses.duplicate(), "attempts": attempts.duplicate(true),
		"mystery_state": mystery_state, "notes": notes.duplicate(true), "side_states": side_states.duplicate()}


func from_dict(d: Dictionary) -> void:
	known_facts = d.get("known_facts", {}).duplicate(true)
	hypotheses = d.get("hypotheses", {}).duplicate()
	attempts = d.get("attempts", {}).duplicate(true)
	mystery_state = d.get("mystery_state", "ativo")
	side_states = d.get("side_states", side_states).duplicate()
	notes.clear()
	for n in d.get("notes", []):
		notes.append(n)
