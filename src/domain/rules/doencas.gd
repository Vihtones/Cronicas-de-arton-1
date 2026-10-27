extends RefCounted
## Doenças (LB p.318). Quem é exposto faz Fortitude (CD da doença); se falhar, é contaminado, sem efeito ainda. No
## início de cada dia, repete o teste: falhou, sofre o efeito daquele dia; passou, não sofre. Efeitos progressivos
## (estágios): cada falha seguida avança um estágio; quem já sofreu um efeito progressivo e passa sofre o estágio
## anterior naquele dia. Passar dois dias seguidos cura (a Maldição Pegajosa pede três). Perda de atributo é
## permanente, uma vez por doença. Condições valem pelo dia (efeito "condicao" com fim "dia").


static func regra(rules: RuleRegistry, id: String) -> Dictionary:
	return rules.value("doenca." + id, {})


static func ids(rules: RuleRegistry) -> Array:
	var out: Array = []
	for k in rules.ids_with_prefix("doenca."):
		out.append(str(k).trim_prefix("doenca."))
	return out


## Contamina `sh` com a doença. `imediato` (Rogar Maldição): já sofre o primeiro efeito, sem incubação.
## Contaminação não é cumulativa. Devolve os fatos do efeito sofrido (se houver).
static func contrair(sh: CharacterSheet, id: String, imediato: bool, rules: RuleRegistry, rng: RngStreams, stream: String, dia: int) -> Array:
	if sh.doencas.has(id) or regra(rules, id).is_empty():
		return []
	sh.doencas[id] = {"estagio": -1, "sucessos": 0, "atributo": false}
	if not imediato:
		return []
	sh.doencas[id].estagio = 0
	return _sofrer(sh, id, rules, rng, stream, dia)


## Teste do início do dia para cada doença de `sh`. Devolve uma lista de {doenca, passou, estagio, curada, efeito}.
static func teste_diario(sh: CharacterSheet, rules: RuleRegistry, rng: RngStreams, stream: String, dia: int) -> Array:
	var out: Array = []
	for id in sh.doencas.keys():
		var r := regra(rules, id)
		var d: Dictionary = sh.doencas[id]
		var passou: bool = Checks.skill(sh, "fortitude", int(r.cd), rules, rng, stream).get("success", false)
		var info := {"doenca": id, "passou": passou, "curada": false, "efeito": []}
		if passou:
			d.sucessos = int(d.sucessos) + 1
			if int(d.sucessos) >= int(r.get("cura_sucessos", 2)):
				sh.doencas.erase(id)
				info.curada = true
				out.append(info)
				continue
			d.estagio = int(d.estagio) - 1 if int(d.estagio) > 0 else -1
			if int(d.estagio) >= 0:
				info.efeito = _sofrer(sh, id, rules, rng, stream, dia)
		else:
			d.sucessos = 0
			d.estagio = mini(int(d.estagio) + 1, (r.estagios as Array).size() - 1)
			info.efeito = _sofrer(sh, id, rules, rng, stream, dia)
		info["estagio"] = int(d.estagio)
		out.append(info)
	return out


## Efeito do estágio atual: condição pelo dia, perda de PV, de 1 ponto de atributo (permanente, uma vez) ou morte.
static func _sofrer(sh: CharacterSheet, id: String, rules: RuleRegistry, rng: RngStreams, stream: String, dia: int) -> Array:
	var d: Dictionary = sh.doencas[id]
	var est: Dictionary = (regra(rules, id).estagios as Array)[int(d.estagio)]
	if est.has("condicao"):
		var c := str(est.condicao)
		if not sh.conditions.has(c):
			sh.add_condition(c, rules)
		sh.add_efeito("doenca." + id, "condicao", 1, "dia", c, dia + 1)
		return [{"condicao": c}]
	if est.has("perde_pv"):
		var n := int(Dice.roll(str(est.perde_pv), rng, stream).total)
		sh.pv -= n
		return [{"perde_pv": n}]
	if est.has("perde_atributo"):
		if bool(d.atributo):
			return []
		d.atributo = true
		var a := str(est.perde_atributo)
		sh.attrs[a] = int(sh.attrs.get(a, 0)) - 1
		return [{"perde_atributo": a}]
	if bool(est.get("morte", false)):
		sh.pv = sh.death_threshold()
		return [{"morte": true}]
	return []
