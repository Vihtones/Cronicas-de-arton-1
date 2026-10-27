class_name GhostPlanner
extends RefCounted
const SpellRules := preload("res://src/domain/combat/spell_rules.gd")
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
			if special and A.sheet.class_id != "guerreiro" and not A.sheet.source_rule.contains("guerreiro"): return {"ok": false, "reason": "sem Ataque Especial"}
			var prof := sim.attack_profile(actor, a.get("target", ""), int(a.get("attack", 0)), special, false)
			if not prof.ok: return prof
			if not sim.is_enemy(actor, a.target): return {"ok": false, "reason": "não é inimigo"}
			prof["kind"] = "padrao"
			return prof
		"ataque_extra":
			var ae: Dictionary = sim.rules.value("classe.guerreiro.ataque_extra")
			if A.sheet.class_id != "guerreiro" or A.sheet.level < int(ae.nivel): return {"ok": false, "reason": "Ataque Extra é do guerreiro de 6º nível"}
			if not (A.flags as Array).has("agrediu_%d" % sim.round_no): return {"ok": false, "reason": "use primeiro a ação agredir"}
			if (A.flags as Array).has("ataque_extra_%d" % sim.round_no): return {"ok": false, "reason": "uma vez por rodada"}
			if A.sheet.pm < int(ae.custo_pm): return {"ok": false, "reason": "PM insuficiente (2)"}
			var prof2 := sim.attack_profile(actor, a.get("target", ""), int(a.get("attack", 0)), false, false)
			if not prof2.ok: return prof2
			if not sim.is_enemy(actor, a.target): return {"ok": false, "reason": "não é inimigo"}
			prof2["kind"] = "livre"
			return prof2
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
		"cast":
			if not sim.can_spend("padrao"): return {"ok": false, "reason": "lançar magia exige ação padrão"}
			var sp_id: String = a.get("spell", "")
			var sp := spell_rule(sim.rules, sp_id)
			if sp_id == "raio_arcano":
				if not A.sheet.has_power("raio_arcano"): return {"ok": false, "reason": "poder Raio Arcano não adquirido"}
			elif not A.sheet.spells.has(sp_id): return {"ok": false, "reason": "magia não conhecida"}
			if sp.is_empty(): return {"ok": false, "reason": "magia sem regra"}
			if a.get("pungente", false) and not A.sheet.has_power("magia_pungente"):
				return {"ok": false, "reason": "você não tem Magia Pungente"}
			var cost := spell_cost(sim.rules, sp, a)
			if A.sheet.pm < cost: return {"ok": false, "reason": "PM insuficiente (%d)" % cost}
			var targets: Array = a.get("targets", [a.get("target", actor)])
			var apr: Array = a.get("aprimoramentos", [])
			if not SpellRules.pode_lancar_no_turno(sp_id, apr):
				if sp_id == "protecao_divina":
					return {"ok": false, "reason": "com o aprimoramento de reação, Proteção Divina age quando um aliado vai fazer teste de resistência"}
				return {"ok": false, "reason": "Escudo da Fé é reação: age quando um aliado é atacado (ou escolha execução padrão)"}
			if not SpellRules.aprimoramentos_validos(sp_id, apr, A.sheet, sim.rules):
				return {"ok": false, "reason": "aprimoramento não disponível para essa magia"}
			if sp_id == "resistencia_a_energia" and not SpellRules.tipo_energia_valido(str(a.get("tipo_energia", "fogo"))):
				return {"ok": false, "reason": "tipo de energia inválido"}
			if sp_id == "protecao_divina":
				for tg in targets:
					if sim.is_enemy(actor, tg):
						return {"ok": false, "reason": "Proteção Divina só protege aliados"}
			if sp_id == "perdicao":
				for tg in targets:
					if tg == actor or not sim.is_enemy(actor, tg):
						return {"ok": false, "reason": "Perdição só afeta inimigos"}
			var alc := SpellRules.alcance_efetivo(sp_id, str(sp.alcance), apr)
			if alc == "pessoal": targets = [actor]
			var reach := int(sim.rules.value("alcance.quadrados", {}).get(alc, 1))  # LB p.143 (toque/pessoal = 1)
			if alc == "toque":
				for tg in targets:
					if tg == actor: return {"ok": false, "reason": "escolha um alvo adjacente"}
			for tg in targets:
				var T := sim.c(tg)
				if T.is_empty(): return {"ok": false, "reason": "alvo inválido"}
				if CombatSim.cheb(A.tile, T.tile) > reach: return {"ok": false, "reason": "fora do alcance da magia"}
			var avg := 0.0
			if sp.has("dano_por_seta"): avg = Dice.average(sp.dano_por_seta) * int(sp.setas)
			elif sp.has("dano"): avg = Dice.average(raio_dice(A.sheet) if sp_id == "raio_arcano" else str(sp.dano)) * 0.75   # resistência reduz à metade: média aproximada
			if avg > 0.0 and A.sheet.has_power("arcano_de_batalha"): avg += maxi(0, int(A.sheet.attrs.get(A.sheet.caster_attr, 0)))
			return {"ok": true, "kind": "padrao", "cost": cost, "hit_chance": 1.0, "crit_chance": 0.0, "avg_damage": avg, "mods": [], "defense": 0, "miss_chance": 0, "ranged": true}
		"drink":
			if not sim.can_spend("padrao"): return {"ok": false, "reason": "beber poção exige ação padrão (LB p.234)"}
			if str(a.get("item", "")) == "": return {"ok": false, "reason": "sem item"}
			return {"ok": true, "kind": "padrao"}
		"olhar_atordoante":
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "sem ação de movimento disponível"}
			if not A.sheet.can_olhar_atordoante(): return {"ok": false, "reason": "só medusa, com PM, uma vez por cena"}
			var T := sim.c(a.get("target", ""))
			if T.is_empty() or not sim.is_enemy(actor, a.target) or not sim.conscious(a.target): return {"ok": false, "reason": "alvo inválido"}
			if CombatSim.cheb(A.tile, T.tile) > int(sim.rules.value("alcance.quadrados", {}).get("curto", 6)): return {"ok": false, "reason": "fora do alcance curto"}
			return {"ok": true, "kind": "movimento", "cost": 1}
		"allihanna":
			if not sim.can_spend("movimento"): return {"ok": false, "reason": "sem ação de movimento disponível"}
			if A.sheet.race_id != "dahllan": return {"ok": false, "reason": "só dahllan tem Armadura de Allihanna"}
			if A.sheet.allihanna_ativa: return {"ok": false, "reason": "já ativa nesta cena"}
			if A.sheet.pm < 1: return {"ok": false, "reason": "PM insuficiente"}
			return {"ok": true, "kind": "movimento", "cost": 0}
		"impeto", "velocidade_ladina", "emboscar":
			return validate_power_action(sim, actor, t)
	return {"ok": false, "reason": "ação desconhecida: " + t}


## Poderes ativados como ação livre (LB p.66, 73-74). Custo em PM, limite por rodada.
static func validate_power_action(sim: CombatSim, actor: String, t: String) -> Dictionary:
	var A := sim.c(actor)
	if not A.sheet.has_power(t): return {"ok": false, "reason": "poder não adquirido"}
	var cost := int(sim.rules.value("poder." + t).custo_pm)
	if A.sheet.pm < cost: return {"ok": false, "reason": "PM insuficiente (%d)" % cost}
	var key := "%s_%d" % [t, sim.round_no]
	if (A.flags as Array).has(key) or (t == "emboscar" and (A.flags as Array).has("emboscar_usado")):
		return {"ok": false, "reason": "já usado nesta rodada" if t != "emboscar" else "Emboscar só na primeira rodada do combate"}
	if t == "emboscar" and sim.round_no != 1: return {"ok": false, "reason": "Emboscar só na primeira rodada do combate"}
	return {"ok": true, "kind": "livre", "cost": cost, "flag": key}


## Aplica o efeito de um poder livre no simulador (usado pelo fantasma e pela execução real).
static func apply_power_action(sim: CombatSim, actor: String, t: String, v: Dictionary) -> void:
	var A := sim.c(actor)
	A.sheet.pm -= int(v.cost)
	(A.flags as Array).append(v.flag)
	match t:
		"velocidade_ladina": sim.budget.move += 1
		"emboscar":
			sim.budget.std += 1
			(A.flags as Array).append("emboscar_usado")


## Raio Arcano é um poder que "conta como magia" (LB p.39): regra própria, sem custo de círculo.
static func spell_rule(rules: RuleRegistry, sp_id: String) -> Dictionary:
	if sp_id == "raio_arcano":
		var r: Dictionary = rules.value("poder.raio_arcano", {}).duplicate()
		r["tipo"] = "arcana"; r["circulo"] = 0
		return r
	return rules.value("magia." + sp_id, {})


static func spell_cost(rules: RuleRegistry, sp: Dictionary, a: Dictionary) -> int:
	var base := 0 if int(sp.get("circulo", 1)) == 0 else int(rules.value("magia.custo_por_circulo")[str(int(sp.circulo))])
	if a.get("pungente", false):
		base += int(rules.value("poder.magia_pungente").custo_pm)
	base += SpellRules.custo_aprimoramentos(rules, str(a.get("spell", "")), a.get("aprimoramentos", []))
	return base


## 1d8, +1d8 por círculo acima do 1º que o arcanista pode lançar (2º no 5º nível, 3º no 9º...).
static func raio_dice(sheet: CharacterSheet) -> String:
	var circles := 1 + maxi(0, (sheet.level - 1) / 4)
	return "%dd8" % circles


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
			"cast":
				step["hit_chance"] = 1.0; step["crit_chance"] = 0.0; step["avg_damage"] = v.avg_damage; step["mods"] = []; step["pm_cost"] = v.cost
				g.c(actor).sheet.pm -= int(v.cost)
			"attack", "ataque_extra":
				(g.c(actor).flags as Array).append("agrediu_%d" % g.round_no)
				if a.type == "ataque_extra":
					(g.c(actor).flags as Array).append("ataque_extra_%d" % g.round_no)
					g.c(actor).sheet.pm -= 2
				step["hit_chance"] = v.hit_chance; step["crit_chance"] = v.crit_chance; step["avg_damage"] = v.avg_damage
				step["mods"] = v.mods; step["defense"] = v.defense; step["miss_chance"] = v.miss_chance
			"stand":
				g.c(actor).sheet.remove_condition("caido")
			"impeto", "velocidade_ladina", "emboscar":
				apply_power_action(g, actor, a.type, v)
				step["pm_cost"] = v.cost
		g.spend(v.kind)
		steps.append(step)
	return {"valid": valid, "steps": steps, "budget_after": g.budget.duplicate(), "end_tile": g.c(actor).tile}
