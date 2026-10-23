class_name GhostPlanner
extends RefCounted
## Projeção fantasma (§9): recebe o estado (somente leitura), clona e simula o plano
## sem dados. Mostra custos, alcance, chance de acerto e onde o plano fica inválido.
## Regra crítica: nunca altera o CombatSim original.


## Validação compartilhada por fantasma e execução real.
static func validate_action(sim: CombatSim, actor: String, a: Dictionary) -> Dictionary:
	var A := sim.c(actor)
	if A.is_empty() or not sim.conscious(actor):
		return {"ok": false, "reason": "não pode agir"}
	if not A.sheet.can_act(sim.rules):
		return {"ok": false, "reason": "condição impede ações"}
	var t: String = a.get("type", "")
	match t:
		"move":
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "sem ação de movimento disponível"}
			var path: Array = _tiles(a.get("path", []))
			if path.is_empty(): return {"ok": false, "reason": "caminho vazio"}
			var pc := sim.path_cost(actor, path)
			if not pc.ok: return pc
			var sp := sim.speed_squares(actor)
			if int(pc.cost) > sp: return {"ok": false, "reason": "custa %d quadrados; deslocamento %d" % [pc.cost, sp]}
			return {"ok": true, "kind": "movimento", "cost": pc.cost, "end": pc.end}
		"attack":
			if not sim.can_spend("padrao"): return {"ok": false, "reason": "ação padrão já usada"}
			var special: bool = a.get("special", false)
			if special and A.sheet.pm < 1: return {"ok": false, "reason": "PM insuficiente para Ataque Especial"}
			if special and not A.sheet.source_rule.contains("guerreiro"): return {"ok": false, "reason": "sem Ataque Especial"}
			var prof := sim.attack_profile(actor, a.get("target", ""), int(a.get("attack", 0)), special, false)
			if not prof.ok: return prof
			if not sim.is_enemy(actor, a.target): return {"ok": false, "reason": "não é inimigo"}
			prof["kind"] = "padrao"
			return prof
		"charge":
			if not sim.can_spend("completa"): return {"ok": false, "reason": "investida exige ação completa"}
			if A.sheet.has_effective_condition(sim.rules, "lento"): return {"ok": false, "reason": "lento não pode fazer investida"}
			var path: Array = _tiles(a.get("path", []))
			if path.size() < 2: return {"ok": false, "reason": "investida exige ao menos 3m"}
			var dir: Vector2i = path[0] - A.tile
			var pos: Vector2i = A.tile
			for p in path:
				if p - pos != dir: return {"ok": false, "reason": "investida exige linha reta"}
				if sim.db.is_difficult(p): return {"ok": false, "reason": "investida proibida em terreno difícil"}
				pos = p
			var pc := sim.path_cost(actor, path)
			if not pc.ok: return pc
			if int(pc.cost) > sim.speed_squares(actor) * 2: return {"ok": false, "reason": "além do dobro do deslocamento"}
			var target: String = a.get("target", "")
			if sim.c(target).is_empty() or CombatSim.cheb(pc.end, sim.c(target).tile) != 1:
				return {"ok": false, "reason": "investida deve terminar adjacente ao alvo"}
			var probe := sim.clone()
			probe.c(actor).tile = pc.end
			var prof := probe.attack_profile(actor, target, int(a.get("attack", 0)), false, true)
			if not prof.ok: return prof
			if prof.ranged: return {"ok": false, "reason": "investida é corpo a corpo"}
			prof["kind"] = "completa"; prof["end"] = pc.end; prof["cost"] = pc.cost
			return prof
		"stand":
			if not A.sheet.conditions.has("caido"): return {"ok": false, "reason": "não está caído"}
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "sem ação de movimento"}
			return {"ok": true, "kind": "movimento"}
		"coup":
			if not sim.can_spend("completa"): return {"ok": false, "reason": "golpe de misericórdia exige ação completa"}
			var target: String = a.get("target", "")
			var T := sim.c(target)
			if T.is_empty() or CombatSim.cheb(A.tile, T.tile) != 1: return {"ok": false, "reason": "alvo não adjacente"}
			if not T.sheet.has_effective_condition(sim.rules, "indefeso"): return {"ok": false, "reason": "alvo não está indefeso"}
			if T.sheet.is_dead(): return {"ok": false, "reason": "alvo já morto"}
			return {"ok": true, "kind": "completa"}
	return {"ok": false, "reason": "ação desconhecida: " + t}


static func _tiles(path: Array) -> Array:
	var out: Array = []
	for p in path:
		out.append(Vector2i(int(p[0]), int(p[1])) if p is Array else p)
	return out


static func simulate(sim: CombatSim, actor: String, actions: Array) -> Dictionary:
	var g := sim.clone()
	var steps: Array = []
	var valid := true
	for a in actions:
		var v := validate_action(g, actor, a)
		if not v.ok:
			steps.append({"action": a, "ok": false, "reason": v.reason})
			valid = false
			break
		var step := {"action": a, "ok": true, "kind": v.kind}
		match a.type:
			"move":
				step["from"] = g.c(actor).tile
				g.c(actor).tile = v.end
				step["to"] = v.end
				step["cost"] = v.cost
			"charge":
				step["from"] = g.c(actor).tile
				g.c(actor).tile = v.end
				step["to"] = v.end
				step["hit_chance"] = v.hit_chance; step["crit_chance"] = v.crit_chance; step["avg_damage"] = v.avg_damage; step["mods"] = v.mods
			"attack":
				step["hit_chance"] = v.hit_chance; step["crit_chance"] = v.crit_chance; step["avg_damage"] = v.avg_damage
				step["mods"] = v.mods; step["defense"] = v.defense; step["miss_chance"] = v.miss_chance
			"stand":
				g.c(actor).sheet.remove_condition("caido")
		g.spend(v.kind)
		steps.append(step)
	return {"valid": valid, "steps": steps, "budget_after": g.budget.duplicate(), "end_tile": g.c(actor).tile}
