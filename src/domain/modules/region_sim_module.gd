class_name RegionSimModule
extends WorldModule
## Regiões distantes em LOD L3 (§7): um sorteio agregado por dia, nunca simulação
## passo a passo. As notícias só chegam à vila pelo mensageiro (latência real).

var history: Array[Dictionary] = []


func module_id() -> String: return "region_sim"


func on_tick(tick: int) -> Array:
	if tick % (24 * 60 / world.clock.tick_minutes) != 0 or tick == 0:
		return []
	var out: Array = []
	for r in world.db.distant.get("regions", []):
		for ev in r.events:
			if world.rng.stream("world").randf() < float(ev.chance):
				var p := {"region": r.id, "event": ev.id, "news": ev.news, "effect": ev.effect, "day": world.day_index()}
				history.append(p)
				if history.size() > 100: history.pop_front()
				out.append(fact("DISTANT_EVENT", p))
	return out


func to_dict() -> Dictionary: return {"history": history.duplicate(true)}
func from_dict(d: Dictionary) -> void:
	history.clear()
	for h in d.get("history", []):
		history.append(h)
