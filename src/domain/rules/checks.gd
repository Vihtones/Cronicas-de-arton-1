class_name Checks
extends RefCounted
## Testes T20: 1d20 + modificador >= CD (LB p.220).
const ClassFeatures := preload("res://src/domain/rules/class_features.gd")
const Apt := preload("res://src/domain/rules/aptitudes.gd")
const RESISTANCIAS := ["fortitude", "reflexos", "vontade"]


static func skill(sheet: CharacterSheet, skill_name: String, cd: int, rules: RuleRegistry, rng: RngStreams,
		stream: String = "world", extra_mod: int = 0) -> Dictionary:
	if not sheet.can_use_skill(skill_name, rules):
		return {"allowed": false, "reason": "perícia somente treinada: " + skill_name}
	# Aptidões (Nen, fase 2): só fichas com afinidade definida usam a porcentagem da aptidão da perícia
	var chave_apt := Apt.chave_de_pericia(skill_name, sheet.oficio) if not sheet.afinidade.is_empty() else ""
	var mod := sheet.skill_value(skill_name, rules) + extra_mod + sheet.condition_skill_mod(rules, skill_name) + ClassFeatures.instinto_pericia(sheet, skill_name)
	if chave_apt != "":
		mod += sheet.bonus_aptidao(chave_apt)
	mod += sheet.efeito_bonus("testes")   # efeitos sobre todos os testes (Consagrar e Profanar em mortos-vivos)
	var eh_resistencia := skill_name in RESISTANCIAS
	if eh_resistencia:
		mod += sheet.efeito_bonus("resistencia") + sheet.efeito_bonus("proxima_resistencia")   # efeitos de magia
	# indefeso falha automaticamente em Reflexos (LB p.394)
	var falha_auto := skill_name == "reflexos" and sheet.has_condition_flag(rules, "falha_reflexos")
	var d20: int = rng.roll(stream, 1, 20)[0]
	# Orientação (LB p.193): em teste de perícia, rola dois dados e fica com o melhor. A vantagem geral é gasta
	# no próximo teste; a de atributo (aprimoramento) vale até o fim da cena para as perícias daquele atributo.
	if not eh_resistencia and not falha_auto:
		var attr_pericia := str(rules.value("pericia.tabela", {}).get(skill_name, {}).get("atributo", "")).to_lower()
		var vant_geral := sheet.efeito_bonus("vantagem_pericia") > 0
		var vant_attr := sheet.efeito_tipo_existe("vantagem_atributo", attr_pericia)
		if vant_geral or vant_attr:
			d20 = maxi(d20, rng.roll(stream, 1, 20)[0])
			if vant_geral:
				sheet.remove_efeito_stat("vantagem_pericia")
	var total := d20 + mod
	if eh_resistencia:
		sheet.limpar_efeitos("proxima_resistencia")   # "próximo teste de resistência" é gasto ao rolar
	# Premonição (magia do conjurador): uma vez por rodada, rola de novo um teste que falhou; vale a nova rolagem.
	if total < cd and not falha_auto and sheet.efeito_bonus("premonicao_uso") > 0:
		sheet.remove_efeito_stat("premonicao_uso")
		d20 = rng.roll(stream, 1, 20)[0]
		total = d20 + mod
	var sorte := false
	# Sorte Salvadora: se a resistência falha, o hynne rola de novo (1 PM, uma vez por rodada)
	if total < cd and not falha_auto and skill_name in RESISTANCIAS and sheet.can_sorte_salvadora():
		sheet.pm -= 1
		sheet.sorte_usada = true
		sorte = true
		d20 = rng.roll(stream, 1, 20)[0]
		total = d20 + mod
	var sucesso := total >= cd and not falha_auto
	if chave_apt != "":
		sheet.praticar_aptidao(chave_apt, sucesso)   # só o sucesso gera progresso
	return {"allowed": true, "skill": skill_name, "d20": d20, "mod": mod, "total": total, "cd": cd,
		"success": sucesso, "margin": total - cd, "sorte": sorte, "falha_automatica": falha_auto}


static func attribute(sheet: CharacterSheet, attr: String, cd: int, rules: RuleRegistry, rng: RngStreams, stream: String = "world") -> Dictionary:
	var d20: int = rng.roll(stream, 1, 20)[0]
	var total: int = d20 + int(sheet.attrs.get(attr, 0)) + sheet.condition_attr_mod(rules, attr) + sheet.efeito_bonus("testes")
	return {"d20": d20, "total": total, "cd": cd, "success": total >= cd}


## Probabilidade de sucesso em 1d20 + mod >= cd (para pré-visualização do fantasma).
static func chance(mod: int, cd: int) -> float:
	var need := cd - mod
	return clampf((21 - need) / 20.0, 0.0, 1.0)


## Rastrear (Sobrevivência, apenas treinado, LB p.123): CD pelo solo (macio 15, comum 20, duro 25), –5 contra grupo
## grande, +5 em visibilidade precária, +1 por dia desde a criação dos rastros. Caminhos da Natureza (aprimoramento):
## +10 para rastrear o alvo em terreno natural.
static func cd_rastrear(rules: RuleRegistry, solo: String, alvo: CharacterSheet, natural: bool, grupo: int, visibilidade_ruim: bool, dias: int) -> int:
	var r: Dictionary = rules.value("pericia.rastrear")
	var cd := int(r.cd.get(solo, r.cd.comum))
	if grupo >= int(r.grupo_grande_min):
		cd += int(r.grupo_grande)
	if visibilidade_ruim:
		cd += int(r.visibilidade_precaria)
	cd += int(r.por_dia) * maxi(0, dias)
	if natural and alvo != null:
		cd += alvo.efeito_bonus("rastro_dificil")
	return cd
