class_name CharacterSheet
extends RefCounted
## Ficha mínima T20. Valores derivados vêm de regras do RuleRegistry.

var id: String
var name: String
var level: int = 1
var attrs := {"for": 0, "des": 0, "con": 0, "int": 0, "sab": 0, "car": 0}
var trained: PackedStringArray = PackedStringArray()
var flat_skills: Dictionary = {}  # criaturas: valores prontos do bloco de estatísticas
var pv_max: int = 1
var pv: int = 1
var pm_max: int = 0
var pm: int = 0
var defense_base: int = 10        # 10 + armadura/escudo (sem Des) ou valor fixo de criatura
var defense_fixed: int = -1       # se >= 0, Defesa total do bloco (criaturas)
var speed_m: float = 9.0
var fly_m: float = 0.0             # deslocamento de voo (0 = não voa; atravessa desníveis)
var swim_m: float = 0.0           # deslocamento de natação (0 = não nada; Heróis: natação = base)
var attacks: Array[Dictionary] = []
var conditions: PackedStringArray = PackedStringArray()
var senses: PackedStringArray = PackedStringArray()
var habilidades: PackedStringArray = PackedStringArray()
var stable: bool = true
var is_important: bool = true     # golpe de misericórdia: 25% vs 75%
var devotion: String = ""
var faction: String = ""
var source_rule: String = ""
var class_id: String = ""
var race_id: String = ""
var xp: int = 0
var spells: PackedStringArray = PackedStringArray()
var equipment := {"weapon": "", "armor": ""}
var pending_powers: int = 0
var caster_attr: String = ""
var size: String = "medio"         # LB p.107 (Tabela 1-21)
var creature_type: String = "humanoide"
var dr: Dictionary = {}            # redução de dano por tipo (osteon, qareen, golem)
var vuln: Dictionary = {}          # dano adicional por dado, por tipo (kliren: impacto; trog: frio)
var race_skills: Dictionary = {}   # bônus de perícia da raça e do tamanho
var race_defense: int = 0          # Couro Rígido, Reptiliano, Chassi
var extra_armor_penalty: int = 0   # Chassi do golem
var arcane_path: String = ""     # arcanista: bruxo | feiticeiro | mago (LB p.37)
var scene_defense: int = 0        # bônus de magia com duração "cena" (Armadura Arcana); zera no fim da cena
var powers: Dictionary = {}       # poder_id -> opção (ex.: especializacao_arma -> "espada_longa"); repetíveis viram lista


func skill_value(skill: String, rules: RuleRegistry, context: String = "") -> int:
	if flat_skills.has(skill):
		return int(flat_skills[skill])
	var race_bonus := 0
	if context == "subterraneo" and race_id != "":
		race_bonus = int(rules.value("raca." + race_id, {}).get("bonus_subterraneo", {}).get(skill, 0))
	var table: Dictionary = rules.value("pericia.tabela", {})
	var info: Dictionary = table.get(skill, {"atributo": "Sab"})
	var attr_key: String = str(info.atributo).to_lower()
	var v: int = level / 2 + int(attrs.get(attr_key, 0))
	if trained.has(skill):
		v += training_bonus()
	if bool(info.get("armadura", false)):
		v += armor_penalty(rules)  # LB p.115: penalidade de armadura nas perícias marcadas
	v += int(race_skills.get(skill, 0))
	if skill == "atletismo" and race_id == "hynne":
		v += maxi(0, int(attrs.des) - int(attrs["for"]))   # Pequeno e Rechonchudo: Des no lugar de For (LB p.28)
	if skill == "furtividade" and race_id == "trog" and str(equipment.get("armor", "")) == "":
		v += 5   # Reptiliano (LB p.31)
	if skill == "atletismo" and powers.has("gatuno"):
		v += 2
	if skill == "furtividade" and powers.has("sombra"):
		v += 2   # Sombra (LB p.74)
	# Poderes gerais (LB p.125-131)
	if skill == "reflexos" and powers.has("esquiva"): v += 2
	if skill == "fortitude" and powers.has("vitalidade"): v += 2
	if skill == "vontade" and powers.has("vontade_de_ferro"): v += 2
	if skill == "iniciativa" and powers.has("saque_rapido"): v += 2
	return v + race_bonus


func armor_penalty(rules: RuleRegistry) -> int:
	var arm: String = equipment.get("armor", "")
	return (int(rules.value("armadura." + arm, {}).get("penalidade", 0)) if arm != "" else 0) + extra_armor_penalty


func has_power(p: String) -> bool:
	return powers.has(p)


func can_swim() -> bool:
	return swim_m > 0.0


func can_fly() -> bool:
	return fly_m > 0.0


func can_use_skill(skill: String, rules: RuleRegistry) -> bool:
	if flat_skills.has(skill):
		return true
	var info: Dictionary = rules.value("pericia.tabela", {}).get(skill, {})
	return not info.get("somente_treinada", false) or trained.has(skill)


func remove_condition(c: String) -> void:
	var i := conditions.find(c)
	while i >= 0:
		conditions.remove_at(i)
		i = conditions.find(c)


func add_condition(c: String) -> void:
	if not conditions.has(c):
		conditions.append(c)


func training_bonus() -> int:
	if level >= 15: return 6
	if level >= 7: return 4
	return 2


func defense(rules: RuleRegistry, vs_melee: bool = true) -> int:
	var d := defense_fixed if defense_fixed >= 0 else defense_base + int(attrs.des)
	d += condition_mod(rules, "defesa") + scene_defense + (race_defense if defense_fixed < 0 else 0)
	if powers.has("esquiva"): d += 2   # Esquiva (LB p.125)
	if has_effective_condition(rules, "caido"):
		d += -5 if vs_melee else 5
	return d


func death_threshold() -> int:
	return mini(-10, -(pv_max / 2))


func is_dead() -> bool:
	return pv <= death_threshold()


func is_down() -> bool:
	return pv <= 0


func can_act(rules: RuleRegistry) -> bool:
	if is_down():
		return false
	var cond: Dictionary = rules.value("condicoes", {})
	for c in effective_conditions(rules):
		if cond.get(c, {}).get("sem_acoes", false):
			return false
	return true


## Expande condições implicadas (ex.: inconsciente -> indefeso -> desprevenido).
func effective_conditions(rules: RuleRegistry) -> PackedStringArray:
	var cond: Dictionary = rules.value("condicoes", {})
	var out := PackedStringArray()
	var stack: Array = Array(conditions)
	if is_down():
		stack.append("inconsciente")
	while not stack.is_empty():
		var c: String = stack.pop_back()
		if out.has(c):
			continue
		out.append(c)
		for imp in cond.get(c, {}).get("implica", []):
			stack.append(imp)
	return out


func has_effective_condition(rules: RuleRegistry, c: String) -> bool:
	return effective_conditions(rules).has(c)


## Soma o pior modificador por campo (condições iguais não acumulam, LB p.394).
func condition_mod(rules: RuleRegistry, field: String) -> int:
	var cond: Dictionary = rules.value("condicoes", {})
	var worst := 0
	for c in effective_conditions(rules):
		var v = cond.get(c, {}).get(field, 0)
		if v is float or v is int:
			worst = mini(worst, int(v))
	return worst


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "level": level, "attrs": attrs.duplicate(), "trained": Array(trained),
		"flat_skills": flat_skills.duplicate(), "pv_max": pv_max, "pv": pv, "pm_max": pm_max, "pm": pm,
		"defense_base": defense_base, "defense_fixed": defense_fixed, "speed_m": speed_m,
		"attacks": attacks.duplicate(true), "conditions": Array(conditions), "senses": Array(senses), "habilidades": Array(habilidades), "stable": stable,
		"is_important": is_important, "devotion": devotion, "faction": faction, "source_rule": source_rule,
		"class_id": class_id, "race_id": race_id, "xp": xp, "spells": Array(spells), "equipment": equipment.duplicate(),
		"pending_powers": pending_powers, "caster_attr": caster_attr, "powers": powers.duplicate(true),
		"arcane_path": arcane_path, "scene_defense": scene_defense, "size": size, "creature_type": creature_type,
		"dr": dr.duplicate(), "vuln": vuln.duplicate(), "race_skills": race_skills.duplicate(), "race_defense": race_defense,
		"extra_armor_penalty": extra_armor_penalty,
	}


static func from_dict(d: Dictionary) -> CharacterSheet:
	var s := CharacterSheet.new()
	s.id = d.id; s.name = d.name; s.level = int(d.level)
	for k in d.attrs: s.attrs[k] = int(d.attrs[k])
	s.trained = PackedStringArray(d.trained)
	s.flat_skills = d.get("flat_skills", {})
	s.pv_max = int(d.pv_max); s.pv = int(d.pv); s.pm_max = int(d.pm_max); s.pm = int(d.pm)
	s.defense_base = int(d.defense_base); s.defense_fixed = int(d.defense_fixed); s.speed_m = float(d.speed_m)
	s.attacks.clear()
	for a in d.attacks: s.attacks.append(_int_fields(a))
	s.conditions = PackedStringArray(d.conditions); s.stable = bool(d.stable)
	s.senses = PackedStringArray(d.get("senses", []))
	s.habilidades = PackedStringArray(d.get("habilidades", []))
	s.is_important = bool(d.get("is_important", true)); s.devotion = str(d.get("devotion", ""))
	s.faction = str(d.get("faction", "")); s.source_rule = str(d.get("source_rule", ""))
	s.class_id = str(d.get("class_id", "")); s.race_id = str(d.get("race_id", "")); s.xp = int(d.get("xp", 0))
	s.spells = PackedStringArray(d.get("spells", []))
	s.equipment = d.get("equipment", {"weapon": "", "armor": ""}).duplicate()
	s.pending_powers = int(d.get("pending_powers", 0)); s.caster_attr = str(d.get("caster_attr", ""))
	s.powers = d.get("powers", {}).duplicate(true)
	s.arcane_path = str(d.get("arcane_path", "")); s.scene_defense = int(d.get("scene_defense", 0))
	s.size = str(d.get("size", "medio")); s.creature_type = str(d.get("creature_type", "humanoide"))
	s.dr = d.get("dr", {}).duplicate(); s.vuln = d.get("vuln", {}).duplicate(); s.race_skills = d.get("race_skills", {}).duplicate()
	s.race_defense = int(d.get("race_defense", 0)); s.extra_armor_penalty = int(d.get("extra_armor_penalty", 0))
	return s


func duplicate_sheet() -> CharacterSheet:
	return CharacterSheet.from_dict(JSON.parse_string(JSON.stringify(to_dict())))


## Guerreiro humano 1º nível montado com as regras do LB (build ORIGINAL_DO_JOGO).
static func premade_warrior(rules: RuleRegistry, p_id: String = "player", p_name: String = "Aventureiro") -> CharacterSheet:
	var s := CharacterSheet.new()
	s.id = p_id; s.name = p_name; s.level = 1
	# 10 pontos: For 3(4) Des 2(2) Con 2(2) Int 1(1) Sab 1(1) Car 0 ; Humano +1 For/Des/Con
	s.attrs = {"for": 4, "des": 3, "con": 3, "int": 1, "sab": 1, "car": 0}
	var g: Dictionary = rules.value("classe.guerreiro")
	s.pv_max = int(g.pv_inicial) + s.attrs.con
	s.pv = s.pv_max
	s.pm_max = int(g.pm_nivel) * s.level
	s.pm = s.pm_max
	# Luta, Fortitude (fixas); Atletismo, Percepção (classe); Investigação (Int 1); Intuição, Furtividade (Versátil)
	s.trained = PackedStringArray(["luta", "fortitude", "atletismo", "percepcao", "investigacao", "intuicao", "furtividade"])
	var arm: Dictionary = rules.value("armadura.couro_batido")
	s.defense_base = 10 + int(arm.defesa)
	s.speed_m = float(rules.value("deslocamento.padrao_m", 9))
	var w: Dictionary = rules.value("arma.espada_longa")
	s.attacks.append({"nome": "Espada longa", "skill": "luta", "dano": w.dano, "for_no_dano": true,
		"margem": int(w.margem), "mult": int(w.mult), "alcance_q": 1, "tipo": w.tipo})
	s.source_rule = "ORIGINAL_DO_JOGO:premade_guerreiro_humano"
	s.class_id = "guerreiro"; s.race_id = "humano"
	s.equipment = {"weapon": "espada_longa", "armor": "couro_batido"}
	return s


static func from_creature(rules: RuleRegistry, rule_id: String, p_id: String) -> CharacterSheet:
	var c: Dictionary = rules.value(rule_id)
	assert(c != null, "criatura inexistente: " + rule_id)
	var s := CharacterSheet.new()
	s.id = p_id; s.name = c.nome; s.level = 1
	for k in c.atributos: s.attrs[k] = int(c.atributos[k])
	s.flat_skills = {"iniciativa": c.iniciativa, "percepcao": c.percepcao, "fortitude": c.fort, "reflexos": c.ref, "vontade": c.von}
	for k in c.get("pericias", {}): s.flat_skills[k] = c.pericias[k]
	s.pv_max = int(c.pv); s.pv = s.pv_max
	s.defense_fixed = int(c.defesa)
	s.speed_m = float(c.deslocamento_m)
	for a in c.ataques:
		var atk := {"nome": a.nome, "bonus_fixo": int(a.bonus), "dano": a.dano, "for_no_dano": false,
			"margem": int(a.margem), "mult": int(a.mult), "alcance_q": int(a.alcance_q), "distancia": a.get("distancia", false)}
		if a.has("derrubar"): atk["derrubar"] = int(a.derrubar)
		s.attacks.append(atk)
	s.is_important = false
	s.senses = PackedStringArray(c.get("sentidos", []))
	s.habilidades = PackedStringArray(c.get("habilidades", []))
	s.source_rule = rule_id
	return s


## JSON devolve números como float; na Godot 4.7 isso aparece no salvamento (19 vira 19.0).
## Campos inteiros dos ataques voltam a int para o jogo carregado ser idêntico ao salvo.
const _ATTACK_INT_KEYS := ["margem", "mult", "alcance_q", "bonus_fixo", "derrubar"]


static func _int_fields(a: Dictionary) -> Dictionary:
	var out := a.duplicate(true)
	for k in _ATTACK_INT_KEYS:
		if out.has(k) and out[k] is float:
			out[k] = int(out[k])
	return out
