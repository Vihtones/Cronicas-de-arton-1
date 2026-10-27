class_name CharacterSheet
extends RefCounted
## Ficha mínima T20. Valores derivados vêm de regras do RuleRegistry.

const Apt := preload("res://src/domain/rules/aptitudes.gd")
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
var condicoes_novas: PackedStringArray = PackedStringArray()   # condições recebidas desde a última drenagem do combate
var dr: Dictionary = {}            # redução de dano por tipo (osteon, qareen, golem)
var vuln: Dictionary = {}          # dano adicional por dado, por tipo (kliren: impacto; trog: frio)
var race_skills: Dictionary = {}   # bônus de perícia da raça e do tamanho
var race_defense: int = 0          # Couro Rígido, Reptiliano, Chassi
var extra_armor_penalty: int = 0   # Chassi do golem
var arcane_path: String = ""     # arcanista: bruxo | feiticeiro | mago (LB p.37)
var scene_defense: int = 0        # bônus de magia com duração "cena" (Armadura Arcana); zera no fim da cena
var sorte_usada: bool = false        # Sorte Salvadora (hynne): uma vez por rodada; zera ao começar a rodada
var olhar_usado: bool = false          # Olhar Atordoante (medusa): uma vez por cena; zera no fim do combate
var oficio: String = ""          # subdomínio de fazer escolhido para a perícia Ofício (ex.: cozinhar)
var afinidade: Dictionary = {}   # aptidões no estilo Nen: domínio -> % (soma 100), ver aptitudes.gd
var aptidoes: Dictionary = {}    # "dominio.nome" -> {"pct": float, "pratica": int, "marco": bool}
var allihanna_ativa: bool = false  # Armadura de Allihanna (dahllan) ativa na cena; zera no fim do combate
var aura_sagrada_ativa: bool = false  # Aura Sagrada (paladino, 3º nível): sustentada; termina com o combate
var egide_ativa: bool = false         # Égide Sagrada (paladino, poder do 5º nível): até o fim da cena
var pv_temp: int = 0                 # PV temporários (Heroísmo): absorvem dano antes dos PV; zeram ao fim do combate
var manto_versao: String = "luz"       # Manto do Cruzado: versão escolhida ao aprender ("luz" | "trevas"); não muda depois
var manto_cruzado: String = ""         # versão ativa do Manto do Cruzado na cena de combate ("" = inativo)
var arcana_perdida: bool = false       # Lágrimas de Wynna (ritual): perda permanente de magias arcanas; nenhum poder mortal reverte
var powers: Dictionary = {}       # poder_id -> opção (ex.: especializacao_arma -> "espada_longa"); repetíveis viram lista
## Efeitos temporários de magias e habilidades: {id, stat, bonus, fim, tipo}. stat: ataque | dano | defesa |
## resistencia | proxima_resistencia | rd (tipo de dano) | imune (condição). fim: rodada | turno | cena | proxima_resistencia.
var efeitos: Array = []


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


## Aura Sagrada (LB p.84): paladino a partir do 3º nível.
func pode_aura_sagrada() -> bool:
	return class_id == "paladino" and level >= 3


## Égide Sagrada (LB p.84): poder escolhido no 5º nível (Bênção da Justiça).
func pode_egide_sagrada() -> bool:
	return has_power("egide_sagrada")


func carisma() -> int:
	return int(attrs.get("car", 0))


func can_swim() -> bool:
	return swim_m > 0.0


func can_fly() -> bool:
	return fly_m > 0.0


## Olhar Atordoante (medusa): ação de movimento, 1 PM, uma vez por cena.
func can_olhar_atordoante() -> bool:
	return race_id == "medusa" and pm >= 1 and not olhar_usado


## Sorte Salvadora (hynne, Bestiário): reação de 1 PM, uma vez por rodada, para rolar de novo um teste de resistência.
func can_sorte_salvadora() -> bool:
	return race_id == "hynne" and pm >= 1 and not sorte_usada


## Patamar (Heróis, Arsenal de Lisandra): iniciante 1-4, veterano 5-10, experiente 11-16, campeão 17-20.
func patamar() -> int:
	if level <= 4: return 1
	if level <= 10: return 2
	if level <= 16: return 3
	return 4


## Defesa da Armadura de Allihanna (dahllan, LB): +2 ao ativar. Com Arsenal de Lisandra soma +1 por patamar (Heróis).
func allihanna_defense(ativa: bool) -> int:
	if not ativa or race_id != "dahllan":
		return 0
	return 2 + (patamar() if has_power("arsenal_de_lisandra") else 0)


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


## Condições que vêm depois de c na escada (abalado -> apavorado; fraco -> debilitado -> inconsciente).
func _cadeia_escada(c: String, rules: RuleRegistry) -> Array:
	var cond: Dictionary = rules.value("condicoes", {})
	var out: Array = []
	var atual := str(cond.get(c, {}).get("escala_para", ""))
	while atual != "" and not out.has(atual):
		out.append(atual)
		atual = str(cond.get(atual, {}).get("escala_para", ""))
	return out


## Aplica uma condição respeitando a escada (LB p.394): ficar abalado de novo vira apavorado;
## uma condição mais severa substitui as mais leves da mesma escada; a mais leve é ignorada.
func add_condition(c: String, rules: RuleRegistry) -> void:
	if efeito_bonus("imune", c) != 0:
		return   # imunidade concedida por magia (ex.: Proteção Divina de 3º círculo)
	var cadeia := _cadeia_escada(c, rules)
	for sup in cadeia:
		if conditions.has(sup):
			return   # já sofre algo mais severo da mesma escada
	if conditions.has(c) and not cadeia.is_empty():
		remove_condition(c)
		add_condition(cadeia[0], rules)   # "ficar X novamente": passa para a seguinte
		return
	for leve in conditions.duplicate():
		if leve != c and _cadeia_escada(leve, rules).has(c):
			remove_condition(leve)
	if not conditions.has(c):
		conditions.append(c)
		condicoes_novas.append(c)   # fila para ligações de magia (Ligação Sombria); não é salva


## Adiciona um efeito temporário (troca o anterior com o mesmo id).
func add_efeito(id_efeito: String, stat: String, bonus: int, fim: String, tipo: String = "", ate: int = -1) -> void:
	efeitos = efeitos.filter(func(e): return not (e.id == id_efeito and e.stat == stat and str(e.tipo) == tipo))
	efeitos.append({"id": id_efeito, "stat": stat, "bonus": bonus, "fim": fim, "tipo": tipo, "ate": ate})


## Recupera PV, respeitando o bloqueio de cura (Poeira da Podridão). Devolve os PV recuperados de fato.
func curar(n: int) -> int:
	if n <= 0 or efeito_bonus("bloqueio_cura") > 0:
		return 0
	var antes := pv
	pv = mini(pv_max, pv + n)
	return pv - antes


## Dano de um tipo depois de imunidade (zera) e de redução por tipo (magia e raça).
func dano_por_tipo(tipo: String, dano: int) -> int:
	if efeito_bonus("imune", tipo) > 0:
		return 0
	return maxi(0, dano - efeito_rd(tipo) - int(dr.get(tipo, 0)))


## Remove os efeitos de um tipo de bônus (ex.: uso de Premonição gasto).
func remove_efeito_stat(stat: String) -> void:
	efeitos = efeitos.filter(func(e): return e.stat != stat)


func remove_efeito(id_efeito: String) -> void:
	efeitos = efeitos.filter(func(e): return e.id != id_efeito)


## Há um efeito deste tipo de bônus com este tipo (ex.: vantagem em testes de um atributo).
func efeito_tipo_existe(stat: String, tipo: String) -> bool:
	return efeitos.any(func(e): return e.stat == stat and str(e.tipo) == tipo)


func has_efeito(id_efeito: String) -> bool:
	return efeitos.any(func(e): return e.id == id_efeito)


## Anula uma magia no alvo (ex.: Curar Ferimentos anula Infligir Ferimentos): tira também as condições que ela causou.
func anular_magia(id_efeito: String) -> void:
	for e in efeitos:
		if e.id == id_efeito and e.stat == "condicao":
			remove_condition(str(e.tipo))
	remove_efeito(id_efeito)


## Conexão de magia (Escudo da Fé, 4º aprimoramento) acaba quando o alvo se afasta.
func remove_efeito_link() -> void:
	efeitos = efeitos.filter(func(e): return e.stat != "link")


## Redução de dano concedida por magia contra um tipo de dano.
func efeito_rd(tipo: String) -> int:
	var total := 0
	for e in efeitos:
		if e.stat == "rd" and (str(e.tipo) == tipo or str(e.tipo) == "*"):   # "*" = todos os tipos
			total += int(e.bonus)
	return total


## Soma dos bônus de um tipo de efeito. Para "imune" e "rd", o tipo (condição ou dano) precisa bater.
func efeito_bonus(stat: String, tipo: String = "") -> int:
	var total := 0
	for e in efeitos:
		if e.stat != stat:
			continue
		if stat in ["imune", "rd"] and str(e.tipo) != tipo:
			continue
		total += int(e.bonus)
	return total


## Remove os efeitos que terminam em um momento (rodada, turno, cena, proxima_resistencia).
func limpar_efeitos(fim: String) -> void:
	for e in efeitos:
		if e.fim == fim and e.stat == "condicao":
			remove_condition(str(e.tipo))   # condição de magia (ex.: fraco pela cena) acaba junto
	efeitos = efeitos.filter(func(e): return e.fim != fim)


## Remove um efeito pelo id e pelo momento em que termina (ex.: o ritual de Lágrimas de Wynna, que tem fim "ritual").
func remove_efeito_de(id_efeito: String, fim: String) -> void:
	efeitos = efeitos.filter(func(e): return not (e.id == id_efeito and e.fim == fim))


## Efeitos "por um dia" acabam quando o dia de término chega (ate = índice do dia em que acabam).
func limpar_dia(dia_atual: int) -> void:
	for e in efeitos:
		if e.fim == "dia" and dia_atual >= int(e.ate):
			if e.stat == "condicao":
				remove_condition(str(e.tipo))
	efeitos = efeitos.filter(func(e): return not (e.fim == "dia" and dia_atual >= int(e.ate)))


func training_bonus() -> int:
	if level >= 15: return 6
	if level >= 7: return 4
	return 2


func defense(rules: RuleRegistry, vs_melee: bool = true) -> int:
	var d := defense_fixed if defense_fixed >= 0 else defense_base + int(attrs.des)
	d += condition_mod(rules, "defesa") + scene_defense + allihanna_defense(allihanna_ativa) + (race_defense if defense_fixed < 0 else 0)
	d += efeito_bonus("defesa")
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


## Pratica uma aptidão (chave "dominio.nome"); só o sucesso gera progresso.
func praticar_aptidao(chave: String, sucesso: bool) -> void:
	var estado: Dictionary = aptidoes.get(chave, {})
	aptidoes[chave] = Apt.praticar(estado, afinidade, chave, sucesso)


## Bônus de teste da aptidão (+1 a cada 10%); 0 se a ficha não tem a aptidão.
func bonus_aptidao(chave: String) -> int:
	var estado: Dictionary = aptidoes.get(chave, {})
	return Apt.teto_balanceado(Apt.bonus(float(estado.get("pct", 0.0))), level)


## Penalidade de condições em um teste de perícia ou resistência: soma os campos
## "pericias" (todas), "pericias_atrib" (pelo atributo da perícia) e "pericias_nomes" (a perícia),
## usando o pior valor de cada campo (LB p.394).
func condition_skill_mod(rules: RuleRegistry, skill: String) -> int:
	var cond: Dictionary = rules.value("condicoes", {})
	var attr := str(rules.value("pericia.tabela", {}).get(skill, {}).get("atributo", "")).to_lower()
	var geral := 0
	var por_attr := 0
	var por_nome := 0
	for c in effective_conditions(rules):
		var info: Dictionary = cond.get(c, {})
		geral = mini(geral, int(info.get("pericias", 0)))
		var pa: Dictionary = info.get("pericias_atrib", {})
		por_attr = mini(por_attr, int(pa.get(attr, 0)))
		var pn: Dictionary = info.get("pericias_nomes", {})
		por_nome = mini(por_nome, int(pn.get(skill, 0)))
	return geral + por_attr + por_nome


## Penalidade de condições em um teste de atributo (For, Des, Con, Int, Sab, Car).
func condition_attr_mod(rules: RuleRegistry, attr: String) -> int:
	var cond: Dictionary = rules.value("condicoes", {})
	var worst := 0
	for c in effective_conditions(rules):
		var pa: Dictionary = cond.get(c, {}).get("pericias_atrib", {})
		worst = mini(worst, int(pa.get(attr, 0)))
	return worst


## Verdadeiro se alguma condição ativa tiver a marcação (ex.: "falha_reflexos" do indefeso).
func has_condition_flag(rules: RuleRegistry, flag: String) -> bool:
	var cond: Dictionary = rules.value("condicoes", {})
	for c in effective_conditions(rules):
		if cond.get(c, {}).get(flag, false):
			return true
	return false


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "level": level, "attrs": attrs.duplicate(), "trained": Array(trained),
		"flat_skills": flat_skills.duplicate(), "pv_max": pv_max, "pv": pv, "pm_max": pm_max, "pm": pm,
		"defense_base": defense_base, "defense_fixed": defense_fixed, "speed_m": speed_m,
		"attacks": attacks.duplicate(true), "conditions": Array(conditions), "senses": Array(senses), "habilidades": Array(habilidades), "stable": stable,
		"is_important": is_important, "devotion": devotion, "faction": faction, "source_rule": source_rule,
		"class_id": class_id, "race_id": race_id, "xp": xp, "spells": Array(spells), "equipment": equipment.duplicate(),
		"pending_powers": pending_powers, "caster_attr": caster_attr, "powers": powers.duplicate(true),
		"efeitos": efeitos.duplicate(true), "oficio": oficio, "afinidade": afinidade.duplicate(), "aptidoes": aptidoes.duplicate(true), "arcane_path": arcane_path, "scene_defense": scene_defense, "allihanna_ativa": allihanna_ativa, "aura_sagrada_ativa": aura_sagrada_ativa, "egide_ativa": egide_ativa, "pv_temp": pv_temp, "manto_versao": manto_versao, "arcana_perdida": arcana_perdida, "manto_cruzado": manto_cruzado, "olhar_usado": olhar_usado, "sorte_usada": sorte_usada, "size": size, "creature_type": creature_type,
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
	s.efeitos = Array(d.get("efeitos", [])).duplicate(true)
	s.afinidade = (d.get("afinidade", {}) as Dictionary).duplicate()
	s.aptidoes = (d.get("aptidoes", {}) as Dictionary).duplicate(true)
	s.oficio = str(d.get("oficio", ""))
	s.arcane_path = str(d.get("arcane_path", "")); s.scene_defense = int(d.get("scene_defense", 0)); s.allihanna_ativa = bool(d.get("allihanna_ativa", false)); s.aura_sagrada_ativa = bool(d.get("aura_sagrada_ativa", false)); s.egide_ativa = bool(d.get("egide_ativa", false)); s.pv_temp = int(d.get("pv_temp", 0)); s.manto_versao = str(d.get("manto_versao", "luz")); s.arcana_perdida = bool(d.get("arcana_perdida", false)); s.manto_cruzado = str(d.get("manto_cruzado", "")); s.sorte_usada = bool(d.get("sorte_usada", false)); s.olhar_usado = bool(d.get("olhar_usado", false))
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
