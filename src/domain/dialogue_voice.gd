class_name DialogueVoice
extends RefCounted
## Voz dos moradores: monta falas a partir do ESTADO do mundo (hora, clima, evento da vila, reputação do
## jogador, mistério, quantas vezes já conversaram) e dos textos de data/dialogue/voices.json.
## Só devolve texto: não decide testes, opções nem efeitos. Determinística: o mesmo estado dá a mesma fala,
## e a variação vem de (morador, dia, nº de conversas), sem sorteio que quebre o replay.

const TIER_FRIEND := 30.0
const TIER_COLD := -20.0


static func _v(world: WorldState) -> Dictionary:
	return world.db.voices


static func register(world: WorldState, npc: String) -> String:
	var prof := str(world.npc_def(npc).get("profession", ""))
	return str(_v(world).get("registro", {}).get(prof, "simples"))


static func period(world: WorldState) -> String:
	var h := world.hour()
	if h >= 5 and h < 12: return "manha"
	if h >= 12 and h < 18: return "tarde"
	return "noite"


## Escolha estável: depende só do morador, do dia e de um número de conversas.
static func pick(world: WorldState, npc: String, options: Array, salt: int = 0) -> String:
	if options.is_empty():
		return ""
	var h := ("%s|%d|%d" % [npc, world.day_index(), salt]).hash()
	return str(options[absi(h) % options.size()])


static func tier(world: WorldState, npc: String) -> String:
	var mem = world.module("memory")
	var rep: float = mem.reputation(npc) if mem != null else 0.0
	if rep >= TIER_FRIEND: return "amigo"
	if rep <= TIER_COLD: return "frio"
	return "neutro"


static func mystery_open(world: WorldState) -> bool:
	var ex = world.module("exploration")
	return ex != null and ex.mystery_state == "ativo"


## visit: {kind: "primeira"|"mesmo_dia"|"retorno"|"conhecido", gap: int dias, count: int}
static func greeting(world: WorldState, npc: String, visit: Dictionary) -> String:
	var v := _v(world)
	if v.is_empty():
		return "Bom dia."
	var reg := register(world, npc)
	var kind := str(visit.get("kind", "conhecido"))
	var count := int(visit.get("count", 0))
	var text := ""
	match kind:
		"primeira":
			text = pick(world, npc, v.primeiro.get(reg, {}).get(period(world), []), count)
		"mesmo_dia":
			text = pick(world, npc, v.mesmo_dia.get(reg, []), count)
		_:
			text = pick(world, npc, v.conhecido.get(reg, {}).get(tier(world, npc), []), count)
			if kind == "retorno" and int(visit.get("gap", 0)) >= 2:
				text += " " + str(v.retorno.get(reg, "")).replace("{dias}", str(int(visit.gap)))
	# a vila está inquieta: de vez em quando o morador comenta (não na repetição do mesmo dia)
	if kind != "mesmo_dia" and mystery_open(world) and absi(("%s|%d|w" % [npc, count]).hash()) % 2 == 0:
		text += " " + str(v.preocupado.get(reg, ""))
	return text.strip_edges()


static func work(world: WorldState, npc: String) -> String:
	var d := world.npc_def(npc)
	var line := str(_v(world).get("trabalho", {}).get(str(d.get("profession", "")), ""))
	return line if line != "" else "Vou levando. Um dia de cada vez."


static func weather(world: WorldState, npc: String) -> String:
	var w = world.module("weather")
	var cond: String = w.region.condition if w != null else "limpo"
	var reg := register(world, npc)
	var line := str(_v(world).get("clima", {}).get(cond, _v(world).get("clima", {}).get("limpo", {})).get(reg, ""))
	return line if line != "" else "O tempo é o que é."


static func active_event_ids(world: WorldState) -> Array:
	var te = world.module("town_events")
	return te.active_ids() if te != null else []


static func event(world: WorldState, npc: String, event_id: String) -> String:
	return str(_v(world).get("evento", {}).get(event_id, {}).get(register(world, npc), "Dia diferente na vila, não é?"))


## Moradores de quem o NPC pode falar: família, mesma facção e o resto da vila, sem repetir nem citar o próprio.
static func people_of_interest(world: WorldState, npc: String, limit: int = 5) -> Array:
	var me := world.npc_def(npc)
	var fam: Array = []
	var fac: Array = []
	var rest: Array = []
	for id in world.all_npc_ids():
		if id == npc:
			continue
		var d := world.npc_def(id)
		var st: Dictionary = world.modules.npcs.state.get(id, {})
		if not st.get("alive", true) or st.get("captive", false):
			continue
		if d.get("family", "") != "" and d.get("family", "") == me.get("family", ""):
			fam.append(id)
		elif d.get("faction") != null and d.get("faction") == me.get("faction"):
			fac.append(id)
		else:
			rest.append(id)
	var out: Array = fam + fac
	# completa com moradores variando por dia (estável dentro do dia)
	var salt := absi(("%s|%d" % [npc, world.day_index()]).hash())
	var i := 0
	while out.size() < limit and not rest.is_empty():
		out.append(rest.pop_at((salt + i * 7) % rest.size()))
		i += 1
	return out.slice(0, limit)


static func opinion(world: WorldState, npc: String, other: String) -> String:
	var v := _v(world)
	var me := world.npc_def(npc)
	var o := world.npc_def(other)
	var rel := "vila"
	if o.get("family", "") != "" and o.get("family", "") == me.get("family", ""):
		rel = "familia"
	elif o.get("faction") != null and o.get("faction") == me.get("faction"):
		rel = "faccao"
	var note := "%s %s." % [str(o.get("name", other)).split(" ")[0], v.get("nota_profissao", {}).get(str(o.get("profession", "")), "mora aqui")]
	for t in o.get("traits", []):
		if v.get("nota_traco", {}).has(t):
			note += " E %s." % v.nota_traco[t]
			break
	return str(v.get("relacao", {}).get(rel, "{nota}")).replace("{nota}", note)
