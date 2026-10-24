class_name NpcStats
extends RefCounted
## Fichas de ameaça de NPC (LB p.322, Tabela 7-2): valores finais pelo ND, sem calcular atributos.
## Perícias focadas usam o primeiro valor da tabela; as demais, o segundo.


static func row(rules: RuleRegistry, npc_def: Dictionary) -> Dictionary:
	var f: Dictionary = npc_def.get("ficha", {})
	if f.is_empty():
		return {}
	return rules.value("npc.estatisticas", {}).get(str(f.get("nd", "1/2")), {})


## Bônus de perícia do NPC, ou o valor de reserva quando ele não tem ficha.
static func skill(rules: RuleRegistry, npc_def: Dictionary, p_skill: String, fallback: int = 0) -> int:
	var r := row(rules, npc_def)
	if r.is_empty():
		return fallback
	var focused: bool = (npc_def.ficha.get("foco", []) as Array).has(p_skill)
	return int(r.pericias[0]) if focused else int(r.pericias[1])
