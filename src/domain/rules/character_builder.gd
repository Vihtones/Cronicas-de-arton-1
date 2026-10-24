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
## Magias arcanas de 1º círculo implementadas (LB cap. 4). O Mago começa com 4 (LB p.37), mas só há 3 prontas: PENDENTE.
const ARCANE_SPELLS := ["seta_infalivel", "armadura_arcana", "toque_chocante"]
const ARCANE_PATHS := ["bruxo", "feiticeiro", "mago"]


## Lista de perícias da classe (LB p.37, 65, 73).
static func class_list(rules: RuleRegistry, p_class: String) -> Array:
	if p_class == "guerreiro":
		return rules.value("classe.guerreiro").lista
	return rules.value("classe.%s.lista" % p_class, [])


## Quantas perícias livres a criação pede (LB p.114): da classe + Int (qualquer) + Versátil (humano, qualquer).
static func skill_slots(rules: RuleRegistry, p_class: String, p_race: String, attrs_final: Dictionary) -> Dictionary:
	return {"classe": int(rules.value("classe." + p_class).pericias_escolha),
		"livres": maxi(0, int(attrs_final.get("int", 0))) + (int(rules.value("pericias.escolha").versatil_humano) if p_race == "humano" else 0)}


## Valida a escolha: class_picks vêm da lista da classe; free_picks de qualquer perícia; sem repetir as fixas.
static func validate_skills(rules: RuleRegistry, p_class: String, p_race: String, attrs_final: Dictionary,
		class_picks: Array, free_picks: Array) -> PackedStringArray:
	var errs := PackedStringArray()
	var slots := skill_slots(rules, p_class, p_race, attrs_final)
	var lst := class_list(rules, p_class)
	var fixed: Array = []
	for f in rules.value("classe." + p_class).pericias_fixas:
		fixed.append(str(f).get_slice("|", 0))
	if class_picks.size() != slots.classe:
		errs.append("escolha %d perícias da classe (tem %d)" % [slots.classe, class_picks.size()])
	if free_picks.size() > slots.livres:
		errs.append("no máximo %d perícias livres" % slots.livres)
	var seen := {}
	var table: Dictionary = rules.value("pericia.tabela", {})
	for k in class_picks + free_picks:
		if seen.has(k) or fixed.has(k): errs.append("perícia repetida: " + str(k))
		seen[k] = true
		if not table.has(k): errs.append("perícia desconhecida: " + str(k))
	for k in class_picks:
		if not lst.has(k): errs.append("%s não é da lista da classe" % k)
	return errs


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
		human_picks: Array = ["for", "des", "con"], p_name: String = "Aventureiro", extra_trained: Array = [],
		class_picks: Array = [], p_path: String = "bruxo", p_spells: Array = []) -> CharacterSheet:
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
		# Caminho do Arcanista (LB p.37): define o atributo-chave; o PM soma esse atributo.
		var path: String = p_path if ARCANE_PATHS.has(p_path) else "bruxo"
		s.arcane_path = path
		s.caster_attr = str(rules.value("classe.arcanista.caminho")[path].atributo)
		s.pm_max += maxi(0, int(s.attrs[s.caster_attr]))
		var want := int(c.magias_iniciais) + int(rules.value("classe.arcanista.caminho")[path].get("magias_iniciais_extra", 0))
		var chosen: Array = p_spells if not p_spells.is_empty() else ARCANE_SPELLS
		for sp in chosen:
			if ARCANE_SPELLS.has(sp) and not s.spells.has(sp) and s.spells.size() < want:
				s.spells.append(sp)
	s.pm = s.pm_max
	for f in c.pericias_fixas:
		s.trained.append(str(f).get_slice("|", 0))
	for k in (class_picks if not class_picks.is_empty() else DEFAULT_CHOICES[p_class]):
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


## Monta a partir do dicionário da tela de criação / sucessão. Escolhas inválidas de perícia caem no padrão.
static func build_from(rules: RuleRegistry, b: Dictionary) -> CharacterSheet:
	var cls: String = b["class"]
	var picks: Array = b.get("human_picks", ["for", "des", "con"])
	var cp: Array = b.get("class_picks", [])
	var fp: Array = b.get("free_picks", [])
	if not cp.is_empty():
		var probe := build(rules, b.race, cls, b.attrs, picks)
		if not validate_skills(rules, cls, b.race, probe.attrs, cp, fp).is_empty():
			cp = []; fp = []
	return build(rules, b.race, cls, b.attrs, picks, b.get("name", "Aventureiro"), fp, cp, b.get("path", "bruxo"), b.get("spells", []))


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
			"for_no_dano": not ranged, "margem": int(w.margem), "mult": int(w.mult),
			"alcance_q": int(rules.value("alcance.quadrados", {}).get(str(w.get("alcance", "medio")), 20)) if ranged else 1,
			"distancia": ranged, "tipo": w.tipo, "leve": w.get("leve", false)})


## Três presets de atributos (10 pontos) por classe para a tela de criação rápida.
static func presets(p_class: String) -> Array:
	match p_class:
		"guerreiro": return [{"for": 3, "des": 2, "con": 2, "int": 1, "sab": 1, "car": 0}, {"for": 4, "des": 1, "con": 2, "int": 0, "sab": 0, "car": 0}]
		"ladino": return [{"for": 0, "des": 4, "con": 1, "int": 1, "sab": 1, "car": 0}, {"for": 1, "des": 3, "con": 1, "int": 2, "sab": 0, "car": 1}]
		"arcanista": return [{"for": -1, "des": 2, "con": 1, "int": 4, "sab": 1, "car": 0}, {"for": 0, "des": 1, "con": 2, "int": 3, "sab": 1, "car": 0}]
	return []
