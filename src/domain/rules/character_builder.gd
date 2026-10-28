class_name CharacterBuilder
extends RefCounted
## Criação de personagem (protótipo). Compra de pontos (LB p.17), raças Humano/Anão
## (LB p.18-20), classes Guerreiro/Ladino/Arcanista (LB p.37, 65, 73).
## Raças e classes não listadas ainda não estão implementadas (ver ROADMAP).

## Todas as raças jogáveis do Livro Básico (LB p.18-31). Suraggel aparece como aggelus e sulfure.
const RACES := ["humano", "anao", "dahllan", "elfo", "goblin", "lefou", "minotauro", "qareen", "golem", "hynne", "kliren",
	"medusa", "osteon", "sereia", "silfide", "aggelus", "sulfure", "trog"]
const RACE_NAMES := {"humano": "Humano", "anao": "Anão", "dahllan": "Dahllan", "elfo": "Elfo", "goblin": "Goblin", "lefou": "Lefou",
	"minotauro": "Minotauro", "qareen": "Qareen", "golem": "Golem", "hynne": "Hynne", "kliren": "Kliren", "medusa": "Medusa",
	"osteon": "Osteon", "sereia": "Sereia/Tritão", "silfide": "Sílfide", "aggelus": "Aggelus", "sulfure": "Sulfure", "trog": "Trog"}
## Raças com "+1 em três atributos diferentes" (com exceção e penalidade): humano, lefou, osteon, sereia.
const FREE_ATTR_RACES := ["humano", "lefou", "osteon", "sereia"]
## Deformidade do lefou: +2 em duas perícias à escolha. Padrão provisório até haver tela de escolha.
const LEFOU_DEFAULT := ["intimidacao", "sobrevivencia"]
## Classes jogáveis na criação. Primeira leva: classes sem magia própria (bárbaro, paladino, nobre, bucaneiro,
## cavaleiro, caçador, inventor). Segunda leva: clérigo, com Curar Ferimentos (única magia divina implementada).
## O kit de equipamento é provisório, escolhido entre armas/armaduras já no catálogo.
## Bardo, druida e treinador ficam para depois (exigem magias de bardo/druida e mascotes, que ainda não existem).
const CLASSES := ["guerreiro", "ladino", "arcanista", "barbaro", "paladino", "nobre", "bucaneiro", "cavaleiro", "cacador", "inventor", "clerigo"]
const CLASS_NAMES := {"guerreiro": "Guerreiro", "ladino": "Ladino", "arcanista": "Arcanista", "barbaro": "Bárbaro",
	"paladino": "Paladino", "nobre": "Nobre", "bucaneiro": "Bucaneiro", "cavaleiro": "Cavaleiro", "cacador": "Caçador", "inventor": "Inventor", "clerigo": "Clérigo"}
const WEAPON_BY_CLASS := {"guerreiro": "espada_longa", "ladino": "espada_curta", "arcanista": "adaga",
	"barbaro": "machado_batalha", "paladino": "espada_longa", "nobre": "espada_curta", "bucaneiro": "espada_curta",
	"cavaleiro": "espada_longa", "cacador": "arco_curto", "inventor": "funda", "clerigo": "clava"}
const ARMOR_BY_CLASS := {"guerreiro": "couro_batido", "ladino": "couro_batido", "arcanista": "",
	"barbaro": "gibao_peles", "paladino": "cota_malha", "nobre": "couro_batido", "bucaneiro": "couro_batido",
	"cavaleiro": "cota_malha", "cacador": "couro_batido", "inventor": "couro_batido", "clerigo": "cota_malha"}
## Perícias escolhidas por padrão (protótipo: sem tela de escolha individual ainda)
const DEFAULT_CHOICES := {
	"guerreiro": ["atletismo", "percepcao"],
	"ladino": ["furtividade", "acrobacia", "enganacao", "intuicao", "investigacao", "percepcao", "iniciativa", "atletismo"],
	"arcanista": ["conhecimento", "percepcao"],
}
## Magias arcanas de 1º círculo implementadas (LB cap. 4). O Mago começa com 4 (LB p.37), mas só há 3 prontas: PENDENTE.
const ARCANE_SPELLS := ["seta_infalivel", "armadura_arcana", "toque_chocante"]
const ARCANE_PATHS := ["bruxo", "feiticeiro", "mago"]
const SpellRules := preload("res://src/domain/combat/spell_rules.gd")


## Magias de 1º círculo que a classe pode escolher na criação: arcanas (arcanista) ou divinas (clérigo), mais
## as universais, e só as que estão completas no jogo (SpellRules.COMPLETAS).
static func magias_iniciais_possiveis(rules: RuleRegistry, p_class: String) -> Array:
	var tipo := "arcana" if p_class == "arcanista" else ("divina" if p_class == "clerigo" else "")
	if tipo == "":
		return []
	var out: Array = []
	for sp in SpellRules.COMPLETAS:
		var m: Dictionary = rules.value("magia." + str(sp), {})
		if int(m.get("circulo", 0)) == 1 and str(m.get("tipo", "")) in [tipo, "universal"]:
			out.append(str(sp))
	out.sort()
	return out


static func magias_iniciais_qtd(rules: RuleRegistry, p_class: String, p_path: String) -> int:
	if p_class == "arcanista":
		var path: String = p_path if ARCANE_PATHS.has(p_path) else "bruxo"
		return int(rules.value("classe.arcanista").magias_iniciais) + int(rules.value("classe.arcanista.caminho")[path].get("magias_iniciais_extra", 0))
	return 3 if p_class == "clerigo" else 0


## Lista de perícias da classe (LB p.37, 65, 73).
static func class_list(rules: RuleRegistry, p_class: String) -> Array:
	var sub: Array = rules.value("classe.%s.lista" % p_class, [])   # ladino/arcanista: lista em sub-entrada
	if not sub.is_empty():
		return sub
	return rules.value("classe." + p_class, {}).get("lista", [])   # demais: lista dentro da própria classe


## Perícia fixa com alternativa ("luta|pontaria"): usa a primeira opção.
static func fixed_skills(rules: RuleRegistry, p_class: String) -> Array:
	var out: Array = []
	for f in rules.value("classe." + p_class).pericias_fixas:
		out.append(str(f).get_slice("|", 0))
	return out


## Perícias escolhidas quando o jogador não escolhe: as primeiras da lista da classe, sem repetir as fixas.
static func _default_choices(rules: RuleRegistry, p_class: String) -> Array:
	if DEFAULT_CHOICES.has(p_class):
		return DEFAULT_CHOICES[p_class]
	var fixed := fixed_skills(rules, p_class)
	var need := int(rules.value("classe." + p_class).pericias_escolha)
	var out: Array = []
	for k in class_list(rules, p_class):
		if out.size() >= need:
			break
		if not fixed.has(k) and not out.has(k):
			out.append(k)
	return out


## Quantas perícias livres a criação pede (LB p.114): da classe + Int (qualquer) + Versátil (humano, qualquer).
static func skill_slots(rules: RuleRegistry, p_class: String, p_race: String, attrs_final: Dictionary) -> Dictionary:
	return {"classe": int(rules.value("classe." + p_class).pericias_escolha),
		"livres": maxi(0, int(attrs_final.get("int", 0))) + (int(rules.value("pericias.escolha").versatil_humano) if p_race == "humano" else 0)
			+ int(rules.value("raca." + p_race, {}).get("pericia_extra", 0))}


## Escolhas de "+1 em três atributos": remove a exceção da raça e completa até três.
static func free_attr_picks(rules: RuleRegistry, p_race: String, picks: Array) -> Array:
	var ex: Array = [] if p_race == "humano" else rules.value("raca." + p_race).atributos_livres.excecao
	var out: Array = []
	for k in picks + ["for", "des", "con", "int", "sab", "car"]:
		if not ex.has(k) and not out.has(k):
			out.append(k)
		if out.size() == 3:
			break
	return out


## Valida a escolha: class_picks vêm da lista da classe; free_picks de qualquer perícia; sem repetir as fixas.
static func validate_skills(rules: RuleRegistry, p_class: String, p_race: String, attrs_final: Dictionary,
		class_picks: Array, free_picks: Array) -> PackedStringArray:
	var errs := PackedStringArray()
	var slots := skill_slots(rules, p_class, p_race, attrs_final)
	var lst := class_list(rules, p_class)
	var fixed := fixed_skills(rules, p_class)
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
	var race: Dictionary = {} if p_race == "humano" else rules.value("raca." + p_race)
	if FREE_ATTR_RACES.has(p_race):
		for k in free_attr_picks(rules, p_race, human_picks):
			s.attrs[k] += 1
		if p_race != "humano":
			for k in race.atributos_livres.penalidade:
				s.attrs[k] += int(race.atributos_livres.penalidade[k])
	else:
		for k in race.atributos:
			s.attrs[k] += int(race.atributos[k])
	_apply_race(rules, s, race)
	var c: Dictionary = rules.value("classe." + p_class)
	s.pv_max = int(c.pv_inicial) + int(s.attrs.con) + int(race.get("pv_nivel1", 0))
	s.pv = s.pv_max
	s.pm_max = int(c.pm_nivel) + int(race.get("pm_por_nivel", 0))
	if p_class == "arcanista":
		# Caminho do Arcanista (LB p.37): define o atributo-chave; o PM soma esse atributo.
		var path: String = p_path if ARCANE_PATHS.has(p_path) else "bruxo"
		s.arcane_path = path
		s.caster_attr = str(rules.value("classe.arcanista.caminho")[path].atributo)
		s.pm_max += maxi(0, int(s.attrs[s.caster_attr]))
		var want := int(c.magias_iniciais) + int(rules.value("classe.arcanista.caminho")[path].get("magias_iniciais_extra", 0))
		var podem := magias_iniciais_possiveis(rules, "arcanista")
		for sp in (p_spells if not p_spells.is_empty() else []) + ARCANE_SPELLS + podem:
			if podem.has(sp) and not s.spells.has(sp) and s.spells.size() < want:
				s.spells.append(sp)
	if p_class == "clerigo":
		# Clérigo: conjura com Sabedoria. Só Curar Ferimentos está implementada (ver ROADMAP).
		s.caster_attr = "sab"
		var podem_c := magias_iniciais_possiveis(rules, "clerigo")
		for sp in p_spells + ["curar_ferimentos", "perdicao", "infligir_ferimentos"]:   # 3 magias iniciais (escolhidas ou as padrão)
			if podem_c.has(sp) and not s.spells.has(sp) and s.spells.size() < 3:
				s.spells.append(sp)
	s.pm = s.pm_max
	for f in c.pericias_fixas:
		s.trained.append(str(f).get_slice("|", 0))
	for k in (class_picks if not class_picks.is_empty() else _default_choices(rules, p_class)):
		if not s.trained.has(k):
			s.trained.append(k)
	for k in extra_trained:  # Versátil (humano) / Inteligência
		if not s.trained.has(k):
			s.trained.append(k)
	if p_race == "qareen" and not s.spells.has(str(race.magia_inata)):
		s.spells.append(str(race.magia_inata))   # Tatuagem Mística (LB p.26): magia de 1º círculo com Carisma
		if s.caster_attr == "": s.caster_attr = "car"
	if p_race == "humano" and extra_trained.is_empty():
		for k in ["intuicao", "furtividade", "sobrevivencia", "diplomacia"]:
			if not s.trained.has(k) and s.trained.size() < int(c.pericias_escolha) + 4:
				s.trained.append(k)
	s.equipment = {"weapon": WEAPON_BY_CLASS[p_class], "armor": ARMOR_BY_CLASS[p_class]}
	apply_equipment(rules, s)
	s.source_rule = "builder:%s_%s" % [p_race, p_class]
	return s


## Características da raça que não são atributos (LB p.19-31). O que não tem sistema ainda fica em "pendente" na regra.
static func _apply_race(rules: RuleRegistry, s: CharacterSheet, race: Dictionary) -> void:
	s.speed_m = float(race.get("deslocamento_m", 9))
	s.swim_m = float(race.get("natacao_m", 0))
	for sense in race.get("sentidos", []):
		if not s.senses.has(sense): s.senses.append(sense)
	s.size = str(race.get("tamanho", "medio"))
	s.creature_type = str(race.get("tipo", "humanoide"))
	s.race_defense = int(race.get("defesa", 0))
	s.extra_armor_penalty = int(race.get("penalidade_armadura_extra", 0))
	s.race_skills = {}
	for k in race.get("pericias", {}):
		s.race_skills[k] = int(race.pericias[k])
	var sz: Dictionary = rules.value("tamanho.modificadores", {}).get(s.size, {})
	if int(sz.get("furtividade", 0)) != 0:
		s.race_skills["furtividade"] = int(s.race_skills.get("furtividade", 0)) + int(sz.furtividade)
	if s.race_id == "kliren":
		s.race_skills["oficio"] = int(s.race_skills.get("oficio", 0)) + int(race.pericias_oficio)
	if s.race_id == "lefou":
		for k in LEFOU_DEFAULT:
			s.race_skills[k] = int(s.race_skills.get(k, 0)) + int(race.deformidade_pericias)
	s.dr = race.get("rd", {}).duplicate()
	if race.has("rd_escolha"):
		s.dr[str(race.rd_escolha.padrao)] = int(race.rd_escolha.valor)
	if race.has("imunidade_elemental_padrao"):
		s.dr[str(race.imunidade_elemental_padrao)] = 999   # Fonte Elemental do golem: imune ao tipo
	s.vuln = race.get("vulneravel", {}).duplicate()
	if race.has("ossos_frageis"):
		s.vuln["impacto"] = int(race.ossos_frageis)


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
	if s.race_id != "":
		var rc: Dictionary = {} if s.race_id == "humano" else rules.value("raca." + s.race_id, {})
		s.speed_m = float(rc.get("deslocamento_m", rules.value("deslocamento.padrao_m", 9)))
	var w_id: String = s.equipment.get("weapon", "")
	var w: Dictionary = rules.value("arma." + w_id, {})
	s.attacks.clear()
	if not w.is_empty():
		var ranged: bool = w.get("disparo", false)
		s.attacks.append({"nome": w_id.capitalize().replace("_", " "), "skill": "pontaria" if ranged else "luta", "dano": w.dano,
			"for_no_dano": (not ranged) or bool(w.get("soma_for", false)), "margem": int(w.margem), "mult": int(w.mult),
			"alcance_q": int(rules.value("alcance.quadrados", {}).get(str(w.get("alcance", "medio")), 20)) if ranged else 1,
			"distancia": ranged, "tipo": w.tipo, "leve": w.get("leve", false), "arma_id": w_id})
	# Arma natural da raça (Chifres do minotauro, Mordida do trog — LB p.25, 31)
	var rn: Dictionary = {} if s.race_id in ["", "humano"] else rules.value("raca." + s.race_id, {}).get("arma_natural", {})
	if not rn.is_empty():
		s.attacks.append({"nome": rn.nome, "skill": "luta", "dano": rn.dano, "for_no_dano": true, "margem": 20, "mult": int(rn.mult),
			"alcance_q": 1, "distancia": false, "tipo": rn.tipo, "leve": true, "natural": true})


## Três presets de atributos (10 pontos) por classe para a tela de criação rápida.
static func presets(p_class: String) -> Array:
	match p_class:
		"guerreiro": return [{"for": 3, "des": 2, "con": 2, "int": 1, "sab": 1, "car": 0}, {"for": 4, "des": 1, "con": 2, "int": 0, "sab": 0, "car": 0}]
		"ladino": return [{"for": 0, "des": 4, "con": 1, "int": 1, "sab": 1, "car": 0}, {"for": 1, "des": 3, "con": 1, "int": 2, "sab": 0, "car": 1}]
		"arcanista": return [{"for": -1, "des": 2, "con": 1, "int": 4, "sab": 1, "car": 0}, {"for": 0, "des": 1, "con": 2, "int": 3, "sab": 1, "car": 0}]
		"barbaro": return [{"for": 3, "des": 1, "con": 3, "int": 0, "sab": 1, "car": 0}, {"for": 3, "des": 0, "con": 3, "int": 0, "sab": 1, "car": 1}]
		"paladino": return [{"for": 2, "des": 0, "con": 2, "int": 1, "sab": 1, "car": 3}, {"for": 1, "des": 1, "con": 2, "int": 1, "sab": 1, "car": 3}]
		"nobre": return [{"for": 0, "des": 1, "con": 0, "int": 1, "sab": 1, "car": 4}, {"for": 1, "des": 1, "con": 1, "int": 2, "sab": 1, "car": 3}]
		"bucaneiro": return [{"for": 2, "des": 3, "con": 2, "int": 1, "sab": 1, "car": 0}, {"for": 2, "des": 3, "con": 1, "int": 1, "sab": 1, "car": 1}]
		"cavaleiro": return [{"for": 3, "des": 1, "con": 2, "int": 1, "sab": 1, "car": 1}, {"for": 3, "des": 0, "con": 2, "int": 1, "sab": 1, "car": 1}]
		"cacador": return [{"for": 1, "des": 3, "con": 2, "int": 0, "sab": 2, "car": 0}, {"for": 1, "des": 3, "con": 1, "int": 1, "sab": 2, "car": 0}]
		"clerigo": return [{"for": 0, "des": 0, "con": 2, "int": 1, "sab": 4, "car": 0}, {"for": 1, "des": 0, "con": 3, "int": 0, "sab": 3, "car": 0}]
		"inventor": return [{"for": 1, "des": 1, "con": 2, "int": 3, "sab": 1, "car": 0}, {"for": 0, "des": 1, "con": 2, "int": 3, "sab": 1, "car": 1}]
	return []
