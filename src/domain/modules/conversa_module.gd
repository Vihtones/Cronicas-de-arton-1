class_name ConversaModule
extends WorldModule
## Conversas entre moradores (IA, Arton Viva). Dois moradores que dividem o mesmo local e estão livres
## podem trocar uma fala curta, sorteada por tema (rotina, ofício, vila, comida). A conversa:
## - aproxima os dois (familiaridade e afeto, via RelationsModule.registrar_conversa);
## - fica guardada nos dois, para que a IA possa mencionar o que ouviram ou disseram.
## Determinístico: o sorteio vem do RNG do mundo. Nenhuma IA generativa.

const CHANCE_PER_HOUR := 0.2
const COOLDOWN_HOURS := 4
const MAX_RECENT := 3
const TEMAS := ["rotina", "oficio", "vila", "comida"]

var recent: Dictionary = {}  # npc -> [{with, tema, linha, tick}], mais recente primeiro


func module_id() -> String: return "conversa"
func subscribed_events() -> PackedStringArray: return PackedStringArray()


func on_tick(tick: int) -> Array:
	var horas: int = 60 / world.clock.tick_minutes
	if tick % horas != 0:
		return []
	var npcs = world.module("npcs")
	if npcs == null:
		return []
	var by_loc: Dictionary = {}
	for id in npcs.state:
		var s: Dictionary = npcs.state[id]
		if s.alive and not s.captive and s.location != "":
			if not by_loc.has(s.location):
				by_loc[s.location] = []
			by_loc[s.location].append(id)
	var out: Array = []
	var locs := by_loc.keys()
	locs.sort()
	for loc in locs:
		var present: Array = by_loc[loc]
		if present.size() < 2:
			continue
		present.sort()
		# no máximo uma conversa por local por hora: custo constante, mesmo com muitos moradores juntos
		var rng := world.rng.stream("conversa")
		if rng.randf() > CHANCE_PER_HOUR:
			continue
		var i := rng.randi() % present.size()
		var j := rng.randi() % (present.size() - 1)
		if j >= i:
			j += 1
		var a: String = present[i]
		var b: String = present[j]
		if _em_cooldown(a, b, tick, horas):
			continue
		out.append(_conversar(a, b, loc, tick))
	return out


## Sorteia o tema e a fala, registra os efeitos e devolve o fato.
func _conversar(a: String, b: String, loc: String, tick: int) -> Dictionary:
	var rng := world.rng.stream("conversa")
	var prof_a := str(world.npc_def(a).get("profession", ""))
	var mesma_profissao: bool = prof_a != "" and prof_a == str(world.npc_def(b).get("profession", ""))
	var tema: String = "oficio" if mesma_profissao and rng.randf() < 0.5 else TEMAS[rng.randi() % TEMAS.size()]
	var falas: Array = world.db.conversas.get("temas", {}).get(tema, [])
	var linha := ""
	if not falas.is_empty():
		linha = str(falas[rng.randi() % falas.size()]).replace("{a}", _nome(a)).replace("{b}", _nome(b))
	var rm = world.module("relations")
	if rm != null:
		rm.registrar_conversa(a, b)
	_guardar(a, b, tema, linha, tick)
	_guardar(b, a, tema, linha, tick)
	return fact("NPC_CHAT", {"a": a, "b": b, "tema": tema, "linha": linha, "location": loc}, [a, b])


func _guardar(quem: String, com: String, tema: String, linha: String, tick: int) -> void:
	var lista: Array = recent.get(quem, [])
	lista.push_front({"with": com, "tema": tema, "linha": linha, "tick": tick})
	while lista.size() > MAX_RECENT:
		lista.pop_back()
	recent[quem] = lista


func _em_cooldown(a: String, b: String, tick: int, horas: int) -> bool:
	for m in recent.get(a, []):
		if str(m.with) == b and tick - int(m.tick) < COOLDOWN_HOURS * horas:
			return true
	return false


func _nome(id: String) -> String:
	return str(world.npc_def(id).get("name", id))


## Conversas recentes de um morador, em texto curto (para a IA e para o diário).
func resumo(npc: String) -> Array:
	var out: Array = []
	for m in recent.get(npc, []):
		if str(m.linha) != "":
			out.append(str(m.linha))
	return out


func to_dict() -> Dictionary: return {"recent": recent.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	recent = {}
	var src: Dictionary = d.get("recent", {})
	for k in src:
		var lista: Array = []
		for m in src[k]:
			lista.append({"with": str(m.get("with", "")), "tema": str(m.get("tema", "")), "linha": str(m.get("linha", "")), "tick": int(m.get("tick", 0))})
		recent[str(k)] = lista
