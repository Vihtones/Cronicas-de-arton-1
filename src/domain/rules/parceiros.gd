extends RefCounted
## Parceiros (LB p.260): NPCs que ajudam um personagem com um bônus, sem turno nem ações próprias. O bônus depende do
## tipo e do poder (iniciante, veterano, mestre). Limite: 1 parceiro até o 4º nível, 2 do 5º ao 16º, 3 a partir do
## 17º; além do limite, o parceiro não dá benefício. Os bônus fixos viram efeitos "parceiro.<id>" (fim "parceiro") na
## ficha de quem é ajudado; os de uma vez por rodada são consultados no combate (dano_corpo, ataque_extra).

const NIVEIS := ["iniciante", "veterano", "mestre"]


static func tipo(rules: RuleRegistry, t: String) -> Dictionary:
	return rules.value("parceiro.tipos", {}).get(t, {})


static func limite(nivel: int) -> int:
	return 1 if nivel <= 4 else (2 if nivel <= 16 else 3)


## Erro de validação de um parceiro novo ("" se válido).
static func validar(rules: RuleRegistry, p: Dictionary) -> String:
	var t := tipo(rules, str(p.get("tipo", "")))
	if t.is_empty() or not bool(t.get("implementado", false)):
		return "tipo de parceiro indisponível"
	if not NIVEIS.has(str(p.get("nivel", ""))):
		return "poder do parceiro inválido"
	if str(p.tipo) == "ajudante":
		var n: int = int((t.pericias[str(p.nivel)] as Array)[0])
		var pers: Array = p.get("pericias", [])
		if pers.size() != n:
			return "escolha %d perícias para o ajudante" % n
		for x in pers:
			if (t.proibidas as Array).has(str(x)) or pers.count(x) > 1 or not rules.value("pericia.tabela", {}).has(str(x)):
				return "perícia inválida para o ajudante"
	return ""


## Reaplica na ficha os bônus fixos dos parceiros ativos (só os primeiros, até o limite do nível).
static func aplicar(sh: CharacterSheet, lista: Array, rules: RuleRegistry) -> void:
	for e in sh.efeitos.duplicate(true):
		if str(e.id).begins_with("parceiro."):
			sh.remove_efeito(str(e.id))
	var n := 0
	for p in lista:
		if n >= limite(sh.level):
			break
		n += 1
		_aplicar_um(sh, p, rules)
		if p.has("extra"):   # Despertar Consciência num parceiro mestre: bônus de outro tipo, iniciante
			_aplicar_um(sh, {"id": str(p.id) + "_extra", "tipo": str(p.extra.tipo), "nivel": "iniciante", "pericias": p.extra.get("pericias", [])}, rules)


static func _aplicar_um(sh: CharacterSheet, p: Dictionary, rules: RuleRegistry) -> void:
	var t := tipo(rules, str(p.tipo))
	var nv := str(p.nivel)
	var eid := "parceiro." + str(p.id)
	if str(p.get("fonte", "")) == "servo_morto_vivo":
		sh.add_efeito(eid, "servo_sacrificio", 1, "parceiro")   # pode ser sacrificado para evitar um dano
	match str(p.tipo):
		"ajudante":
			var bonus: int = int((t.pericias[nv] as Array)[1])
			for x in p.get("pericias", []):
				sh.add_efeito(eid, "pericia_" + str(x), bonus, "parceiro")
		"combatente":
			sh.add_efeito(eid, "ataque", int(t.ataque[nv]), "parceiro")
			if nv == "mestre":
				sh.add_efeito(eid, "parceiro_ataque_extra", 1, "parceiro")
		"fortao":
			sh.add_efeito(eid, "parceiro_dano_corpo", 1, "parceiro", str(t.dano_corpo[nv]))
		"guardiao":
			sh.add_efeito(eid, "defesa", int(t.defesa[nv]), "parceiro")
			if nv == "mestre":
				sh.add_efeito(eid, "resistencia", int(t.resistencia_mestre), "parceiro")
		"perseguidor":
			for x in t.pericias:
				sh.add_efeito(eid, "pericia_" + str(x), int(t.pericias[x]), "parceiro")
			for pw in t.poderes.get(nv, []):
				sh.add_efeito(eid, "poder_temp", 1, "parceiro", str(pw))
		"montaria":
			sh.add_efeito(eid, "montaria", 1, "parceiro", str(p.get("especie", "")) + "|" + nv)
		"adepto":
			sh.add_efeito(eid, "parceiro_adepto", int(t.circulo_max[nv]), "parceiro")
		"assassino":
			sh.add_efeito(eid, "parceiro_furtivo", int(t.furtivo[nv]), "parceiro")
			if bool(t.flanco[nv]):
				sh.add_efeito(eid, "parceiro_flanco", 1, "parceiro")
		"atirador":
			sh.add_efeito(eid, "parceiro_dano_distancia", 1, "parceiro", str(t.dano_distancia[nv]))
		"destruidor":
			sh.add_efeito(eid, "parceiro_destruidor", int(t.pm[nv]), "parceiro", nv)
		"magivocador":
			sh.add_efeito(eid, "parceiro_magia_dados", int(t.dados[nv]), "parceiro")
			if int(t.cd[nv]) > 0:
				sh.add_efeito(eid, "cd_magias", int(t.cd[nv]), "parceiro")
		"medico":
			sh.add_efeito(eid, "parceiro_medico", int(t.pm[nv]), "parceiro", nv)
		"vigilante":
			for x in t.pericias:
				sh.add_efeito(eid, "pericia_" + str(x), int(t.pericias[x]), "parceiro")
			for pw in t.poderes.get(nv, []):
				sh.add_efeito(eid, "poder_temp", 1, "parceiro", str(pw))


## Dado extra de dano à distância uma vez por rodada (Atirador): "" se não há.
static func dano_distancia(sh: CharacterSheet) -> String:
	for e in sh.efeitos:
		if e.stat == "parceiro_dano_distancia":
			return str(e.tipo)
	return ""


## Nível do parceiro de um tipo com ação própria (destruidor, médico): "" se não há.
static func nivel_acao(sh: CharacterSheet, stat: String) -> String:
	for e in sh.efeitos:
		if e.stat == stat:
			return str(e.tipo)
	return ""


## Dado extra de dano corpo a corpo uma vez por rodada (Fortão): "" se não há.
static func dano_corpo(sh: CharacterSheet) -> String:
	for e in sh.efeitos:
		if e.stat == "parceiro_dano_corpo":
			return str(e.tipo)
	return ""
