class_name AmbientTalk
extends RefCounted
## Escolha das falas de ambiente (balões dos figurantes e latidos dos moradores) a partir do CONTEXTO da vila.
## Puro e testável: recebe o dicionário de data/dialogue/ambient.json e um contexto, devolve texto.
## ctx = {periodo: manha|tarde|noite, clima: limpo|chuva|tempestade|neblina, eventos: Array, misterio: bool}


static func context(world: WorldState) -> Dictionary:
	var w = world.module("weather")
	return {"periodo": DialogueVoice.period(world), "clima": w.region.condition if w != null else "limpo",
		"eventos": DialogueVoice.active_event_ids(world), "misterio": DialogueVoice.mystery_open(world)}


static func _priority(c: Dictionary) -> int:
	return int(c.get("prioridade", (c.quando as Dictionary).size()))


static func _matches(q: Dictionary, ctx: Dictionary) -> bool:
	if q.has("clima") and not q.clima.has(ctx.clima): return false
	if q.has("periodo") and not q.periodo.has(ctx.periodo): return false
	if q.has("misterio") and bool(q.misterio) != bool(ctx.misterio): return false
	if q.has("evento"):
		var any := false
		for e in q.evento:
			if ctx.eventos.has(e): any = true
		if not any: return false
	return true


## Um diálogo de 4 falas (alternam entre dois figurantes) adequado ao contexto. Temas específicos têm preferência
## sobre o genérico (que só entra quando nada mais serve ou, às vezes, para variar).
static func conversation(data: Dictionary, ctx: Dictionary, seed_value: int) -> Array:
	var specific: Array = []
	var generic: Array = []
	for c in data.get("conversas", []):
		if (c.quando as Dictionary).is_empty():
			generic.append(c)
		elif _matches(c.quando, ctx):
			specific.append(c)
	# o tema de maior prioridade vence (padrão: o mais específico; mistério e eventos da vila têm prioridade 3)
	var best := 0
	for c in specific:
		best = maxi(best, _priority(c))
	specific = specific.filter(func(c): return _priority(c) == best)
	var pool: Array = specific
	if pool.is_empty() or absi(seed_value) % 4 == 0:
		pool = generic if not generic.is_empty() else specific
	if pool.is_empty():
		return []
	var theme: Dictionary = pool[absi(seed_value / 4) % pool.size()]
	var scripts: Array = theme.falas
	return scripts[absi(seed_value / 16) % scripts.size()]


static func vendedor(data: Dictionary, ware: String, ctx: Dictionary, seed_value: int) -> String:
	var arr: Array = data.get("vendedor_noite", []) if ctx.periodo == "tarde" and absi(seed_value) % 5 == 0 else data.get("vendedor", {}).get(ware, [])
	return str(arr[absi(seed_value) % arr.size()]) if not arr.is_empty() else ""


static func crianca(data: Dictionary, ctx: Dictionary, seed_value: int) -> String:
	var k: Dictionary = data.get("crianca", {})
	var keys: Array = ["geral", "geral"]
	if ctx.clima in ["chuva", "tempestade"]: keys.append("chuva")
	if ctx.periodo == "noite": keys.append("noite")
	for e in ctx.eventos: keys.append(e)
	var arr: Array = k.get(keys[absi(seed_value) % keys.size()], k.get("geral", []))
	return str(arr[absi(seed_value / 7) % arr.size()]) if not arr.is_empty() else ""


static func danca(data: Dictionary, seed_value: int) -> String:
	var arr: Array = data.get("danca", [])
	return str(arr[absi(seed_value) % arr.size()]) if not arr.is_empty() else ""


static func ocupado(data: Dictionary, prop: String, seed_value: int) -> String:
	var d: Dictionary = data.get("ocupado", {})
	var arr: Array = d.get(prop, d.get("", []))
	return str(arr[absi(seed_value) % arr.size()]) if not arr.is_empty() else ""


static func passante(data: Dictionary, ctx: Dictionary, seed_value: int) -> String:
	var p: Dictionary = data.get("passante", {})
	var keys: Array = [ctx.periodo]
	if ctx.clima != "limpo": keys.append(ctx.clima)
	if ctx.misterio: keys.append("misterio")
	for e in ctx.eventos: keys.append(e)
	var arr: Array = p.get(keys[absi(seed_value) % keys.size()], p.get(ctx.periodo, []))
	return str(arr[absi(seed_value / 7) % arr.size()]) if not arr.is_empty() else ""


static func latido(data: Dictionary, reg: String, tier: String, seed_value: int) -> String:
	var arr: Array = data.get("latido", {}).get(reg, {}).get(tier, [])
	return str(arr[absi(seed_value) % arr.size()]) if not arr.is_empty() else ""
