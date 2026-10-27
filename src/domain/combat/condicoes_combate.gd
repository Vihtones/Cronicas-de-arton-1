extends RefCounted
## Efeitos de condição dentro do combate (condições do Livro Básico): início de turno (em chamas, sangramento),
## ações bloqueadas, enjoado, confuso, surdez em magias, petrificação e reações. As penalidades numéricas
## (defesa, ataque, perícias, deslocamento) continuam em CharacterSheet.condition_mod.

## Impedem qualquer ação no turno. Paralisado só permitiria ações mentais, e o combate tático não tem ações mentais.
const SEM_ACOES := ["atordoado", "fascinado", "pasmo", "paralisado", "inconsciente"]
const REDUCAO_PETRIFICADO := 8
const CHANCE_FALHA_SURDO := 20
const DIRECOES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]


## Condição que impede a criatura de agir neste turno ("" se nenhuma).
static func bloqueio_de_acoes(s: CharacterSheet, rules: RuleRegistry) -> String:
	for c in SEM_ACOES:
		if s.has_effective_condition(rules, c):
			return c
	return ""


## Reações (escudo, proteção, ataque de oportunidade, Premonição) exigem estar consciente e não inconsciente.
static func pode_reagir(s: CharacterSheet, rules: RuleRegistry) -> bool:
	return not s.is_down() and not s.has_effective_condition(rules, "inconsciente")


## Redução de dano de quem está petrificado (LB p.394).
static func reducao_petrificado(s: CharacterSheet, rules: RuleRegistry) -> int:
	return REDUCAO_PETRIFICADO if s.has_effective_condition(rules, "petrificado") else 0


## Surdo: magias lançadas falham quando o d100 dá 20 ou menos (LB p.394).
static func surdo_falha(d100: int) -> bool:
	return d100 <= CHANCE_FALHA_SURDO


## Confuso (LB p.394), 1d6 por turno: 1 move-se ao acaso; 2-3 perde o turno; 4-5 ataca a criatura adjacente;
## 6 age normalmente. Função pura para que o resultado do dado seja testável.
static func confuso_por_dado(d: int) -> String:
	match d:
		1:
			return "mover"
		2, 3:
			return "perder"
		4, 5:
			return "atacar"
	return "normal"


## Início do turno: em chamas causa 1d6 de fogo e a criatura gasta a ação padrão para apagar o fogo;
## sangramento faz teste de Constituição CD 15 (passou: para; falhou: perde 1d6 PV e continua).
static func inicio_de_turno(sim: CombatSim, id: String, rng: RngStreams, facts: Array) -> void:
	var s: CharacterSheet = sim.c(id).sheet
	if s.has_effective_condition(sim.rules, "em_chamas"):
		var dano := s.dano_por_tipo("fogo", int(Dice.roll("1d6", rng, "combat").total))
		facts.append(_dano_de_condicao(sim, id, "em chamas", dano, ["fogo", "condicao"]))
		s.remove_condition("em_chamas")
		if sim.budget.std > 0:
			sim.spend("padrao")
	if s.has_effective_condition(sim.rules, "sangrando") and not s.is_down():
		var r := Checks.attribute(s, "con", 15, sim.rules, rng, "combat")
		if r.success:
			s.remove_condition("sangrando")
		else:
			facts.append(_dano_de_condicao(sim, id, "sangramento", int(Dice.roll("1d6", rng, "combat").total), ["condicao", "sangramento"]))


## Confuso: decide o que a criatura faz neste turno. Devolve {"acao": ..., "alvo": id}; o ataque é executado pelo módulo.
static func confuso(sim: CombatSim, id: String, rng: RngStreams, facts: Array) -> Dictionary:
	if not sim.c(id).sheet.has_effective_condition(sim.rules, "confuso"):
		return {"acao": "normal"}
	var acao := confuso_por_dado(int(Dice.roll("1d6", rng, "combat").total))
	match acao:
		"mover":
			var livre := _vizinho_livre(sim, sim.c(id).tile, rng)
			if not livre.is_empty():
				var de: Vector2i = sim.c(id).tile
				sim.c(id).tile = livre[0]
				facts.append(WorldModule.fact("COMBAT_MOVED", {"actor": id, "from": [de.x, de.y], "path": [[livre[0].x, livre[0].y]]}, [id]))
			facts.append(WorldModule.fact("TURN_SKIPPED", {"actor": id, "reason": "confuso"}, [id]))
			return {"acao": "perder"}
		"atacar":
			var alvo := _adjacente_mais_proximo(sim, id)
			if alvo == "":
				facts.append(WorldModule.fact("TURN_SKIPPED", {"actor": id, "reason": "confuso"}, [id]))
				return {"acao": "perder"}
			return {"acao": "atacar", "alvo": alvo}
		"perder":
			facts.append(WorldModule.fact("TURN_SKIPPED", {"actor": id, "reason": "confuso"}, [id]))
	return {"acao": acao}


static func _dano_de_condicao(sim: CombatSim, id: String, origem: String, dano: int, tags: Array) -> Dictionary:
	var t: Array = tags.duplicate()
	t.append_array(sim.apply_damage(id, dano))
	return WorldModule.fact("ATTACK_RESOLVED", {"attacker": id, "target": id, "weapon": origem, "d20": 0, "mod": 0,
		"mods": [], "total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [],
		"pv_after": sim.c(id).sheet.pv, "special": false, "ranged": false, "spell": false, "save": "", "saved": false, "tags": t}, [id])


## Vizinho livre de `de`, escolhido ao acaso entre os oito quadrados ao redor. Lista vazia se não houver.
static func _vizinho_livre(sim: CombatSim, de: Vector2i, rng: RngStreams) -> Array:
	var inicio := int(Dice.roll("1d8", rng, "combat").total) - 1
	for i in 8:
		var t: Vector2i = de + (DIRECOES[(inicio + i) % 8] as Vector2i)
		if sim.walk_fn.is_valid() and sim.walk_fn.call(t) and not _ocupado(sim, t):
			return [t]
	return []


static func _ocupado(sim: CombatSim, t: Vector2i) -> bool:
	for other in sim.combatants:
		if sim.c(other).tile == t:
			return true
	return false


## Criatura consciente e adjacente de `id` (qualquer lado), ou "" se não houver.
static func _adjacente_mais_proximo(sim: CombatSim, id: String) -> String:
	for other in sim.combatants:
		if other != id and sim.conscious(other) and CombatSim.cheb(sim.c(other).tile, sim.c(id).tile) <= 1:
			return other
	return ""
