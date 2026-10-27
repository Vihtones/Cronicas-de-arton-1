class_name Checks
extends RefCounted
## Testes T20: 1d20 + modificador >= CD (LB p.220).
const ClassFeatures := preload("res://src/domain/rules/class_features.gd")
const RESISTANCIAS := ["fortitude", "reflexos", "vontade"]


static func skill(sheet: CharacterSheet, skill_name: String, cd: int, rules: RuleRegistry, rng: RngStreams,
		stream: String = "world", extra_mod: int = 0) -> Dictionary:
	if not sheet.can_use_skill(skill_name, rules):
		return {"allowed": false, "reason": "perícia somente treinada: " + skill_name}
	var mod := sheet.skill_value(skill_name, rules) + extra_mod + sheet.condition_skill_mod(rules, skill_name) + ClassFeatures.instinto_pericia(sheet, skill_name)
	var eh_resistencia := skill_name in RESISTANCIAS
	if eh_resistencia:
		mod += sheet.efeito_bonus("resistencia") + sheet.efeito_bonus("proxima_resistencia")   # efeitos de magia
	# indefeso falha automaticamente em Reflexos (LB p.394)
	var falha_auto := skill_name == "reflexos" and sheet.has_condition_flag(rules, "falha_reflexos")
	var d20: int = rng.roll(stream, 1, 20)[0]
	var total := d20 + mod
	if eh_resistencia:
		sheet.limpar_efeitos("proxima_resistencia")   # "próximo teste de resistência" é gasto ao rolar
	var sorte := false
	# Sorte Salvadora: se a resistência falha, o hynne rola de novo (1 PM, uma vez por rodada)
	if total < cd and not falha_auto and skill_name in RESISTANCIAS and sheet.can_sorte_salvadora():
		sheet.pm -= 1
		sheet.sorte_usada = true
		sorte = true
		d20 = rng.roll(stream, 1, 20)[0]
		total = d20 + mod
	var sucesso := total >= cd and not falha_auto
	return {"allowed": true, "skill": skill_name, "d20": d20, "mod": mod, "total": total, "cd": cd,
		"success": sucesso, "margin": total - cd, "sorte": sorte, "falha_automatica": falha_auto}


static func attribute(sheet: CharacterSheet, attr: String, cd: int, rules: RuleRegistry, rng: RngStreams, stream: String = "world") -> Dictionary:
	var d20: int = rng.roll(stream, 1, 20)[0]
	var total: int = d20 + int(sheet.attrs.get(attr, 0)) + sheet.condition_attr_mod(rules, attr)
	return {"d20": d20, "total": total, "cd": cd, "success": total >= cd}


## Probabilidade de sucesso em 1d20 + mod >= cd (para pré-visualização do fantasma).
static func chance(mod: int, cd: int) -> float:
	var need := cd - mod
	return clampf((21 - need) / 20.0, 0.0, 1.0)
