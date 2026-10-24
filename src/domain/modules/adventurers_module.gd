class_name AdventurersModule
extends WorldModule
## Aventureiros NPC em LOD L3 (§8): progridem por atividades plausíveis, usando a
## MESMA regra de XP do jogador (ND × 1000 / grupo, LB p.326). Sem ganhos arbitrários.
## Missões e chances: ORIGINAL_DO_JOGO.

const MISSION_CHANCE := 0.25  # por dia

var parties: Array[Dictionary] = [
	{"id": "lanternas", "name": "As Lanternas de Valkaria", "region": "valkaria", "members": [
		{"name": "Brisa", "class": "ladino", "level": 1, "xp": 0, "alive": true},
		{"name": "Torvald", "class": "guerreiro", "level": 2, "xp": 1200, "alive": true}]},
]
var history: Array[Dictionary] = []


func module_id() -> String: return "adventurers"


func party_level(p: Dictionary) -> float:
	var alive: Array = p.members.filter(func(m): return m.alive)
	if alive.is_empty(): return 0.0
	var t := 0.0
	for m in alive: t += m.level
	return t / alive.size()


func on_tick(tick: int) -> Array:
	if tick % (24 * 60 / world.clock.tick_minutes) != 0 or tick == 0:
		return []
	var out: Array = []
	var table: Dictionary = world.rules.value("progressao.xp_por_nivel")
	for p in parties:
		var alive: Array = p.members.filter(func(m): return m.alive)
		if alive.is_empty() or world.rng.stream("world").randf() > MISSION_CHANCE:
			continue
		var lvl := party_level(p)
		var nd := clampf(lvl + world.rng.stream("world").randf_range(-1.0, 1.5), 0.25, 20.0)
		var p_win := clampf(0.55 + 0.15 * (lvl - nd), 0.05, 0.95)
		var won := world.rng.stream("world").randf() < p_win
		var result := "vitoria" if won else ("derrota" if world.rng.stream("world").randf() < 0.5 else "empate")
		var mult: float = {"vitoria": 1.0, "empate": 0.5, "derrota": 0.25}[result]
		var xp_each := int(nd * 1000.0 * mult / alive.size())
		var events: Array = []
		for m in alive:
			m.xp += xp_each
			while m.xp >= int(table.get(str(m.level + 1), 999999)):
				m.level += 1
				events.append("%s subiu para o nível %d" % [m.name, m.level])
		if result == "derrota" and world.rng.stream("world").randf() < 0.2:
			var victim: Dictionary = alive[world.rng.stream("world").randi() % alive.size()]
			victim.alive = false
			events.append("%s morreu" % victim.name)
		var rec := {"party": p.id, "day": world.day_index(), "nd": snappedf(nd, 0.25), "result": result, "xp_each": xp_each, "events": events}
		history.append(rec)
		if history.size() > 60: history.pop_front()
		var news := "%s %s uma missão (ND %.1f)%s." % [p.name, {"vitoria": "venceram", "empate": "voltaram de", "derrota": "fracassaram em"}[result], nd,
			("; " + ", ".join(events)) if not events.is_empty() else ""]
		out.append(fact("DISTANT_EVENT", {"region": p.region, "event": "aventureiros_" + p.id, "news": news, "effect": {}, "day": world.day_index()}))
	return out


func to_dict() -> Dictionary: return {"parties": parties.duplicate(true), "history": history.duplicate(true)}
func from_dict(d: Dictionary) -> void:
	if d.has("parties"):
		parties.clear()
		for p in d.parties:
			for m in p.members:
				m.level = int(m.level); m.xp = int(m.xp)
			parties.append(p)
	history.clear()
	for h in d.get("history", []): history.append(h)
