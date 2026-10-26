class_name MemoryModule
extends WorldModule
## Memória estruturada, rumores e reputação (§8, §11).
## - Só testemunhas presentes registram o fato; outros só sabem por rumor.
## - Rumores só passam entre NPCs no MESMO local (não teleportam), com perda de confiabilidade.
## - Reputação é a soma do que cada NPC acredita; ninguém sabe => reputação zero.

const RECENT_CAP := 16
const DURABLE_CAP := 24
const SHARE_CHANCE := 0.35
const RELIABILITY_DECAY := 0.8
const MIN_RELIABILITY := 0.2

var memories: Dictionary = {}  # npc_id -> Array[Dictionary]
var _seq := 0

## evento -> {fact, valence, emotion, durable}
const EVENT_MEMORY := {
	"NPC_RESCUED": {"fact": "resgatou", "valence": 40, "emotion": "gratidao", "durable": true},
	"DIZIMO_RETURNED": {"fact": "devolveu_dizimo", "valence": 30, "emotion": "alivio", "durable": true},
	"CRIME_COMMITTED": {"fact": "crime", "valence": -25, "emotion": "raiva", "durable": true},
	"CREATURE_DEFEATED": {"fact": "derrotou", "valence": 5, "emotion": "respeito", "durable": false},
	"OBLIGATION_VIOLATED": {"fact": "violou_obrigacao", "valence": -15, "emotion": "decepcao", "durable": false},
	"PLAYER_CAPTURED": {"fact": "capturou_forasteiro", "valence": 0, "emotion": "desprezo", "durable": false},
	"FINE_PAID": {"fact": "pagou_multa", "valence": 10, "emotion": "neutro", "durable": false},
	"DOMAIN_UNREST": {"fact": "impostos_altos", "valence": -15, "emotion": "raiva", "durable": false},
	"NPC_DIED": {"fact": "luto", "valence": 0, "emotion": "tristeza", "durable": true},
	"NPC_BORN": {"fact": "nascimento", "valence": 0, "emotion": "alegria", "durable": true},
	"NPC_MARRIED": {"fact": "casamento", "valence": 0, "emotion": "alegria", "durable": true},
}


func module_id() -> String: return "memory"
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(EVENT_MEMORY.keys() + ["DISTANT_EVENT", "DIALOGUE_STARTED", "MYSTERY_RESOLVED", "NPC_RESCUED_BY_OTHER", "HERO_SUCCEEDED", "SHEEP_KILLED"])


func list(npc_id: String) -> Array:
	return memories.get(npc_id, [])


func knows_fact(npc_id: String, fact_key: String) -> bool:
	for m in list(npc_id):
		if m.key == fact_key:
			return true
	return false


func _witnesses(e: GameEvent) -> Array:
	if e.payload.has("witnesses"):
		return e.payload.witnesses
	var npcs = world.module("npcs")
	if npcs == null or not e.payload.has("location"):
		return []
	return npcs.npcs_at(e.payload.location)


func add_memory(npc_id: String, m: Dictionary) -> void:
	if not memories.has(npc_id):
		memories[npc_id] = []
	var arr: Array = memories[npc_id]
	for existing in arr:
		if existing.key == m.key:
			existing.reliability = maxf(float(existing.reliability), float(m.reliability))
			return
	_seq += 1
	m["id"] = "mem_%d" % _seq
	arr.append(m)
	_trim(arr)


func _trim(arr: Array) -> void:
	var durable := arr.filter(func(x): return x.durable)
	var recent := arr.filter(func(x): return not x.durable)
	durable.sort_custom(func(a, b): return a.tick > b.tick)
	recent.sort_custom(func(a, b): return a.tick > b.tick)
	arr.clear()
	arr.append_array(durable.slice(0, DURABLE_CAP))
	arr.append_array(recent.slice(0, RECENT_CAP))


func on_event(e: GameEvent) -> Array:
	if e.event_type == "DISTANT_EVENT":
		var npcs = world.module("npcs")
		for r in world.db.distant.get("regions", []):
			if r.id == e.payload.region and npcs != null and npcs.npc(r.courier).get("location", "") == r.id:
				add_memory(r.courier, {"key": "noticia:" + e.payload.event + ":" + str(e.world_tick / 144), "about": e.payload.region,
					"subject": "", "valence": 0, "location": r.id, "tick": e.world_tick, "emotion": "neutro",
					"reliability": 1.0, "source": "visto", "durable": false, "text": e.payload.news})
		return []
	if e.event_type == "DIALOGUE_STARTED":
		var id: String = e.payload.npc
		if not knows_fact(id, "conheceu:player"):
			add_memory(id, {"key": "conheceu:player", "about": "player", "subject": "", "valence": 1, "location": e.payload.get("location", ""),
				"tick": e.world_tick, "emotion": "curiosidade", "reliability": 1.0, "source": "visto", "durable": false,
				"text": "Conheci o forasteiro."})
		return []
	if e.event_type == "HERO_SUCCEEDED":
		# o herdeiro é outra pessoa: lembranças do herói anterior não passam para ele
		for id in memories:
			for m in memories[id]:
				if m.about == "player":
					m.about = e.payload.previous
		return []
	if e.event_type == "SHEEP_KILLED":
		# Fenna interpreta errado (NPCs não são oniscientes): culpa lobos.
		add_memory("fenna", {"key": "ovelhas_mortas:%d" % e.world_tick, "about": "lobos", "subject": "fenna", "valence": 0, "location": e.payload.location,
			"tick": e.world_tick, "emotion": "medo", "reliability": 0.6, "source": "evidencia", "durable": true,
			"text": "Lobos mataram minhas ovelhas na estrada leste! Ouvi uivos... acho."})
		return []
	if not EVENT_MEMORY.has(e.event_type):
		return []
	var spec: Dictionary = EVENT_MEMORY[e.event_type]
	var actor: String = e.payload.get("rescuer", e.payload.get("actor", e.actor_ids[0] if e.actor_ids.size() > 0 else ""))
	var subject: String = e.payload.get("npc", e.payload.get("victim", ""))
	var key := "%s:%s:%s" % [spec.fact, actor, subject]
	var text := _describe(e.event_type, actor, subject, e.payload)
	var out: Array = []
	for w in _witnesses(e):
		if w == actor:
			continue
		var val := int(spec.valence)
		if w == subject and spec.valence > 0:
			val *= 2
		add_memory(w, {"key": key, "about": actor, "subject": subject, "valence": val, "location": e.payload.get("location", ""),
			"tick": e.world_tick, "emotion": spec.emotion, "reliability": 1.0, "source": "testemunha", "durable": spec.durable, "text": text})
		# a relação do morador com o ator muda por este fato (RelationsModule)
		out.append(fact("MEMORY_FORMED", {"npc": w, "about": actor, "subject": subject, "valence": val, "emotion": spec.emotion}, [w]))
	# vítima de crime sem testemunhas: sabe que algo aconteceu, não sabe quem
	if e.event_type == "CRIME_COMMITTED" and e.payload.get("victim", "") != "" and not _witnesses(e).has(e.payload.victim):
		add_memory(e.payload.victim, {"key": "crime:desconhecido:" + str(e.payload.get("crime_id", "")), "about": "desconhecido", "subject": e.payload.victim,
			"valence": 0, "location": e.payload.get("location", ""), "tick": e.world_tick, "emotion": "raiva", "reliability": 1.0,
			"source": "evidencia", "durable": true, "text": "Alguém me roubou. Não sei quem."})
	return out


func _describe(type: String, actor: String, subject: String, p: Dictionary) -> String:
	var who := "o forasteiro" if actor == "player" else _name(actor)
	match type:
		"NPC_RESCUED": return "%s tirou %s da cripta." % [who.capitalize(), _name(subject)]
		"DIZIMO_RETURNED": return "%s devolveu o dízimo de Lena." % who.capitalize()
		"CRIME_COMMITTED": return "%s cometeu %s." % [who.capitalize(), str(p.get("crime", "um crime"))]
		"CREATURE_DEFEATED": return "%s derrotou %s." % [who.capitalize(), str(p.get("name", "uma ameaça"))]
		"OBLIGATION_VIOLATED": return "%s desonrou os votos a %s." % [who.capitalize(), str(p.get("god", ""))]
		"NPC_DIED": return "%s morreu." % _name(subject)
		"NPC_BORN": return "Nasceu %s, filho de %s." % [str(p.get("name", "uma criança")), " e ".join((p.get("parents", []) as Array).map(func(x): return _name(x)))]
		"NPC_MARRIED": return "%s e %s se casaram." % [_name(str(p.a)), _name(str(p.b))]
		"DOMAIN_UNREST": return "Os impostos do moinho estão pesados demais."
		"FINE_PAID": return "%s pagou sua multa." % who.capitalize()
	return type


func _name(id: String) -> String:
	if id == "player": return "o forasteiro"
	if id == "guarda_vila": return "a Guarda"
	var d := world.npc_def(id)
	return d.get("name", id)


const FORGET_TICKS := 30 * 144  # memórias não duráveis somem após 30 dias (ORIGINAL)


## Propagação de rumores de hora em hora entre NPCs co-localizados.
func on_tick(tick: int) -> Array:
	if tick % (60 / world.clock.tick_minutes) != 0:
		return []
	if tick % 144 == 0:
		for id in memories:
			memories[id] = memories[id].filter(func(m): return m.durable or tick - int(m.get("origin_tick", m.tick)) < FORGET_TICKS or m.key == "conheceu:player")
	var npcs = world.module("npcs")
	if npcs == null:
		return []
	var by_loc: Dictionary = {}
	for id in npcs.state:
		var s: Dictionary = npcs.state[id]
		if s.alive and not s.captive and s.location != "":
			if not by_loc.has(s.location): by_loc[s.location] = []
			by_loc[s.location].append(id)
	var out: Array = []
	var locs := by_loc.keys()
	locs.sort()
	for loc in locs:
		var present: Array = by_loc[loc]
		present.sort()
		if present.size() < 2:
			continue
		for speaker in present:
			var shareable := list(speaker).filter(func(m): return m.reliability >= MIN_RELIABILITY and m.key != "conheceu:player")
			if shareable.is_empty():
				continue
			# conta o assunto mais relevante que ALGUÉM presente ainda não sabe (evita repetir o mesmo para sempre)
			shareable = shareable.filter(func(mm): return present.any(func(l): return l != speaker and not knows_fact(l, mm.key)))
			if shareable.is_empty():
				continue
			shareable.sort_custom(func(a, b): return _salience(a, tick) > _salience(b, tick))
			var m: Dictionary = shareable[0]
			for listener in present:
				if listener == speaker or knows_fact(listener, m.key):
					continue
				if world.rng.stream("world").randf() > SHARE_CHANCE:
					continue
				var copy := m.duplicate(true)
				copy.erase("id")
				copy.reliability = float(m.reliability) * RELIABILITY_DECAY
				copy.source = "rumor:" + speaker
				copy["origin_tick"] = int(m.get("origin_tick", m.tick))  # data do fato original (esquecimento)
				copy.tick = tick
				copy.location = loc
				# NPC mentiroso pode distorcer (NPCs não são oniscientes nem sempre honestos)
				if world.npc_def(speaker).get("traits", []).has("mentiroso") and world.rng.stream("world").randf() < 0.3:
					copy.valence = -int(copy.valence)
					copy.text = "(distorcido) " + str(copy.text)
					copy.reliability *= 0.5
				if world.npc_def(listener).get("family", "") != "" and world.npc_def(listener).family == world.npc_def(str(copy.subject)).get("family", "-") and int(copy.valence) > 0:
					copy.valence = int(copy.valence) * 2
				add_memory(listener, copy)
				out.append(fact("RUMOR_SPREAD", {"from": speaker, "to": listener, "key": m.key, "location": loc}))
	return out


func _salience(m: Dictionary, now: int) -> float:
	var age_days := float(now - int(m.tick)) / 144.0
	return absi(int(m.valence)) + (10.0 if m.durable else 0.0) + 8.0 / (1.0 + age_days)


## Reputação do jogador para um NPC: soma das crenças sobre ele.
func reputation(npc_id: String, about: String = "player") -> float:
	var total := bias(npc_id, about)
	for m in list(npc_id):
		if m.about == about:
			total += float(m.valence) * float(m.reliability)
	return total


## Preconceito é propriedade INDIVIDUAL (traço), não regra de raça (§11). Some com convivência.
func bias(npc_id: String, about: String) -> float:
	if about != "player":
		return 0.0
	var traits: Array = world.npc_def(npc_id).get("traits", [])
	if traits.has("desconfia_de_estrangeiros"):
		var known := list(npc_id).filter(func(m): return m.about == about).size()
		return -10.0 if known < 3 else 0.0
	return 0.0


func faction_reputation(faction_id: String, about: String = "player") -> Dictionary:
	var members: Array = []
	for n in world.db.npcs.get("npcs", []):
		if n.get("faction", "") == faction_id:
			members.append(n.id)
	var known := 0
	var total := 0.0
	for id in members:
		var r := reputation(id, about)
		var has_any := list(id).any(func(m): return m.about == about)
		if has_any:
			known += 1
			total += r
	return {"value": total / maxf(1, known), "known_by": known, "members": members.size()}


func settlement_reputation(about: String = "player") -> Dictionary:
	var known := 0
	var total := 0.0
	for n in world.db.npcs.get("npcs", []):
		if list(n.id).any(func(m): return m.about == about):
			known += 1
			total += reputation(n.id, about)
	return {"value": total, "known_by": known}


func to_dict() -> Dictionary: return {"memories": memories.duplicate(true), "seq": _seq}
func from_dict(d: Dictionary) -> void:
	memories = d.get("memories", {}).duplicate(true)
	_seq = int(d.get("seq", 0))
	for id in memories:
		for m in memories[id]:
			m.valence = int(m.valence); m.tick = int(m.tick)
