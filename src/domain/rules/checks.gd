class_name Checks
extends RefCounted
## Testes T20: 1d20 + modificador >= CD (LB p.220).


static func skill(sheet: CharacterSheet, skill_name: String, cd: int, rules: RuleRegistry, rng: RngStreams,
		stream: String = "world", extra_mod: int = 0) -> Dictionary:
	if not sheet.can_use_skill(skill_name, rules):
		return {"allowed": false, "reason": "perícia somente treinada: " + skill_name}
	var mod := sheet.skill_value(skill_name, rules) + extra_mod + sheet.condition_mod(rules, "pericias")
	var d20: int = rng.roll(stream, 1, 20)[0]
	var total := d20 + mod
	return {"allowed": true, "skill": skill_name, "d20": d20, "mod": mod, "total": total, "cd": cd,
		"success": total >= cd, "margin": total - cd}


static func attribute(sheet: CharacterSheet, attr: String, cd: int, rng: RngStreams, stream: String = "world") -> Dictionary:
	var d20: int = rng.roll(stream, 1, 20)[0]
	var total: int = d20 + int(sheet.attrs.get(attr, 0))
	return {"d20": d20, "total": total, "cd": cd, "success": total >= cd}


## Probabilidade de sucesso em 1d20 + mod >= cd (para pré-visualização do fantasma).
static func chance(mod: int, cd: int) -> float:
	var need := cd - mod
	return clampf((21 - need) / 20.0, 0.0, 1.0)
