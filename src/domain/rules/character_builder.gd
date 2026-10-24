class_name CharacterBuilder
extends RefCounted
## Criação de personagem (protótipo). Compra de pontos (LB p.17), raças Humano/Anão
## (LB p.18-20), classes Guerreiro/Ladino/Arcanista (LB p.37, 65, 73).
## Raças e classes não listadas ainda não estão implementadas (ver ROADMAP).

const RACES := ["humano", "anao"]
const CLASSES := ["guerreiro", "ladino", "arcanista"]
const WEAPON_BY_CLASS := {"guerreiro": "espada_longa", "ladino": "espada_curta", "arcanista": "adaga"}
const ARMOR_BY_CLASS := {"guerreiro": "couro_batido", "ladino": "couro_batido", "arcanista": ""}
## Perícias escolhidas por padrão (protótipo: sem tela de escolha individual ainda)
const DEFAULT_CHOICES := {
	"guerreiro": ["atletismo", "percepcao"],
	"ladino": ["furtividade", "acrobacia", "enganacao", "intuicao", "investigacao", "percepcao", "iniciativa", "atletismo"],
	"arcanista": ["conhecimento", "percepcao"],
}
const DEFAULT_SPELLS := ["seta_infalivel"]  # outras 2 magias iniciais: PENDENTE (não implementadas)


## Valida a compra de pontos. attrs_base = valores ANTES da raça.
static func validate_points(rules: RuleRegistry, attrs_base: Dictionary) -> PackedStringArray:
	var cost: Dictionary = rules.value("atributos.compra_pontos").custo
	var total := 0
	var errs := PackedStringArray()
	for k in ["for", "des", "con", "int", "sab", "car"]:
		var v := int(attrs_base.get(k, 0))
		if not cost.has(str(v)):
			errs.append("%s=%d fora da tabela (−1 a 4)" % [k, v])
			continue
		total += int(cost[str(v)])
	if total > int(rules.value("atributos.compra_pontos").pontos):
		errs.append("gastou %d de 10 pontos" % total)
	return errs


static func build(rules: RuleRegistry, p_race: String, p_class: String, attrs_base: Dictionary,
		human_picks: Array = ["for", "des", "con"], p_name: String = "Aventureiro", extra_trained: Array = []) -> CharacterSheet:
	assert(RACES.has(p_race) and CLASSES.has(p_class), "raça/classe não implementada")
	assert(validate_points(rules, attrs_base).is_empty(), "compra de pontos inválida")
	var s := CharacterSheet.new()
	s.id = "player"; s.name = p_name; s.level = 1
	s.race_id = p_race; s.class_id = p_class
	s.attrs = {}
	for k in ["for", "des", "con", "int", "sab", "car"]:
		s.attrs[k] = int(attrs_base.get(k, 0))
	var race: Dictionary = {}
	if p_race == "humano":
		for k in human_picks.slice(0, 3):
			s.attrs[k] += 1
	else:
		race = rules.value("raca." + p_race)
		for k in race.atributos:
			s.attrs[k] += int(race.atributos[k])
		s.speed_m = float(race.get("deslocamento_m", 9))
		for sense in race.get("sentidos", []):
			s.senses.append(sense)
	var c: Dictionary = rules.value("classe." + p_class)
	s.pv_max = int(c.pv_inicial) + int(s.attrs.con) + int(race.get("pv_nivel1", 0))
	s.pv = s.pv_max
	s.pm_max = int(c.pm_nivel)
	if p_class == "arcanista":
		s.caster_attr = "int"
		s.pm_max += maxi(0, int(s.attrs["int"]))
		for sp in DEFAULT_SPELLS:
			s.spells.append(sp)
	s.pm = s.pm_max
	for f in c.pericias_fixas:
		s.trained.append(str(f).get_slice("|", 0))
	for k in DEFAULT_CHOICES[p_class]:
		if not s.trained.has(k):
			s.trained.append(k)
	for k in extra_trained:  # Versátil (humano) / Inteligência
		if not s.trained.has(k):
			s.trained.append(k)
	if p_race == "humano" and extra_trained.is_empty():
		for k in ["intuicao", "furtividade", "sobrevivencia", "diplomacia"]:
			if not s.trained.has(k) and s.trained.size() < int(c.pericias_escolha) + 4:
				s.trained.append(k)
	s.equipment = {"weapon": WEAPON_BY_CLASS[p_class], "armor": ARMOR_BY_CLASS[p_class]}
	apply_equipment(rules, s)
	s.source_rule = "builder:%s_%s" % [p_race, p_class]
	return s


## Recalcula Defesa e ataques a partir do equipamento (LB cap. 3).
static func apply_equipment(rules: RuleRegistry, s: CharacterSheet) -> void:
	var arm_id: String = s.equipment.get("armor", "")
	var arm: Dictionary = rules.value("armadura." + arm_id, {}) if arm_id != "" else {}
	s.defense_base = 10 + int(arm.get("defesa", 0))
	if s.race_id != "anao":
		s.speed_m = float(rules.value("deslocamento.padrao_m", 9)) if s.race_id != "" else s.speed_m
	var w_id: String = s.equipment.get("weapon", "")
	var w: Dictionary = rules.value("arma." + w_id, {})
	s.attacks.clear()
	if not w.is_empty():
		var ranged: bool = w.get("disparo", false)
		s.attacks.append({"nome": w_id.capitalize().replace("_", " "), "skill": "pontaria" if ranged else "luta", "dano": w.dano,
			"for_no_dano": not ranged, "margem": int(w.margem), "mult": int(w.mult), "alcance_q": 20 if ranged else 1,
			"distancia": ranged, "tipo": w.tipo, "leve": w.get("leve", false)})


## Três presets de atributos (10 pontos) por classe para a tela de criação rápida.
static func presets(p_class: String) -> Array:
	match p_class:
		"guerreiro": return [{"for": 3, "des": 2, "con": 2, "int": 1, "sab": 1, "car": 0}, {"for": 4, "des": 1, "con": 2, "int": 0, "sab": 0, "car": 0}]
		"ladino": return [{"for": 0, "des": 4, "con": 1, "int": 1, "sab": 1, "car": 0}, {"for": 1, "des": 3, "con": 1, "int": 2, "sab": 0, "car": 1}]
		"arcanista": return [{"for": -1, "des": 2, "con": 1, "int": 4, "sab": 1, "car": 0}, {"for": 0, "des": 1, "con": 2, "int": 3, "sab": 1, "car": 0}]
	return []
