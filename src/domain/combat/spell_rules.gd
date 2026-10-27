extends RefCounted
## Regras de magias já completas no jogo. Só aparece para o jogador (e só pode ser escolhida) a magia
## com todos os aprimoramentos implementados. COMPLETAS guarda, por magia, os índices de aprimoramento
## (ordem do catálogo `magia.<id>.aprimoramentos`) que já têm efeito.

const COMPLETAS := {
	"perdicao": {"aprimoramentos": [0]},
	"infligir_ferimentos": {"aprimoramentos": [0, 1, 2, 3]},
	"resistencia_a_energia": {"aprimoramentos": [0, 1, 2, 3, 4]},
	"escudo_da_fe": {"aprimoramentos": [0, 1, 2, 3, 4]},
	"protecao_divina": {"aprimoramentos": [0, 1, 2, 3]},
	"curar_ferimentos": {"aprimoramentos": [0, 1, 2, 3]},
	"vestimenta_da_fe": {"aprimoramentos": [0, 1, 2]},
	"manto_do_cruzado": {"aprimoramentos": []},   # sem aprimoramentos; versão luz ou trevas escolhida ao aprender
	"coluna_de_chamas": {"aprimoramentos": [0, 1]},   # cilindro de 3m de raio em volta do alvo; +1 PM por +1d6 de fogo ou de luz
	"arma_magica": {"aprimoramentos": [0, 1, 2]},   # +1/+2 em ataque e dano; atributo-chave; dano elemental 1d6 / 2d6
	"orientacao": {"aprimoramentos": [0, 1, 2]},   # vantagem em perícia (2 dados); por atributo; por grupo; alvos escolhidos
	"bencao": {"aprimoramentos": [0, 1]},   # 1 cadáver por 1 semana (também fora de combate); +1 de bônus, repetível
	"nevoa": {"aprimoramentos": [0, 1, 2, 3, 4, 5]},   # sob a água; quem enxerga; cheiro (enjoado); ácido 2d4 / +2d4; espessa
	"lagrimas_de_wynna": {"aprimoramentos": [0, 1]},   # esfera de 6m com criaturas escolhidas (2 PM); ritual de um dia (5 PM + 1 PM)
	"guardiao_divino": {"aprimoramentos": []},   # elemental de luz com 100 pontos: cura PV e remove condições; some sem luz
	"banimento": {"aprimoramentos": [0]},   # execução de 1d3+1 rodadas; 0 PM: devolve criatura conjurada ao plano
	"aura_divina": {"aprimoramentos": [0]},   # esfera de 9m que segue o conjurador; +1 de bônus com 2 PM
	"ligacao_sombria": {"aprimoramentos": [0]},   # 1 dia; o alvo sofre o dano e as condições do conjurador; 5 PM: a ligação não acaba a 0 PV
	"colera_de_azgher": {"aprimoramentos": [0, 1, 2]},   # esfera de 6m; cega e põe em chamas quem falha; dissipa necromancia com 5 PM
	"premonicao": {"aprimoramentos": [0, 1]},   # reação de 3 PM após um teste; 10 PM: dura um dia
	"invulnerabilidade": {"aprimoramentos": [0]},   # proteção mental ou física (escolha) até o fim da cena
	"poeira_da_podridao": {"aprimoramentos": [0]},   # nuvem de 6m; dano de trevas no início do turno do conjurador; bloqueia cura
	"circulo_da_restauracao": {"aprimoramentos": [0]},   # esfera de 3m por 5 rodadas; cura no fim do turno de quem está dentro
	"sopro_da_salvacao": {"aprimoramentos": [0, 1, 2]},   # cone de 9m orientado para o alvo; cura aliados e remove condições
}
## Condições que o Sopro da Salvação pode remover (uma, ou todas no aprimoramento de 4 PM).
const SOPRO_CONDICOES := ["abalado", "atordoado", "apavorado", "alquebrado", "cego", "confuso", "debilitado", "enfeiticado", "enjoado",
	"esmorecido", "exausto", "fascinado", "fatigado", "fraco", "frustrado", "lento", "paralisado", "pasmo", "surdo"]
## Magias que são reação: o base só ocorre como reação (quando um aliado é atacado). Aprimoramentos
## que mudam a execução para ação padrão permitem lançar no próprio turno.
## Invulnerabilidade (LB p.195): condições de cada proteção. A física inclui doenças (condição "doente"); acertos críticos e
## ataques furtivos entram à parte, como tipos de imunidade.
const INVULN_MENTAL := ["abalado", "alquebrado", "apavorado", "atordoado", "confuso", "esmorecido", "fascinado", "frustrado", "pasmo"]
const INVULN_FISICA := ["atordoado", "cego", "debilitado", "doente", "enjoado", "envenenado", "exausto", "fatigado", "fraco", "lento", "ofuscado", "paralisado"]
const REACAO := ["escudo_da_fe"]
const EXECUCAO_PADRAO_APR := {"escudo_da_fe": [0, 3]}
## Aprimoramentos que trocam a execução para reação mesmo sem a magia ser reação no base (Proteção Divina +2 PM).
const REACAO_APR := {"protecao_divina": [1], "premonicao": [0]}
## Aprimoramentos que trocam o alvo por "criaturas escolhidas" (vários alvos).
const MULTI_APR := {"infligir_ferimentos": [3], "resistencia_a_energia": [2], "curar_ferimentos": [3]}
## Aprimoramentos que mudam o alcance: {magia: {índice: novo alcance}}.
const ALCANCE_APR := {"invulnerabilidade": {0: "curto"}, "infligir_ferimentos": {3: "curto"}, "resistencia_a_energia": {2: "curto"}, "escudo_da_fe": {0: "toque", 3: "toque"},
	"protecao_divina": {1: "curto"}, "curar_ferimentos": {2: "curto", 3: "curto"}}
## Aprimoramentos que se excluem entre si (mudam o mesmo efeito).
const EXCLUSIVOS := {"resistencia_a_energia": [[3, 4]]}
const TIPOS_ENERGIA := ["acido", "eletricidade", "fogo", "frio", "luz", "trevas"]


## Círculo máximo que o conjurador pode lançar. Usa a tabela de conjuração da classe (ex.: clérigo: 2º no 5º nível).
## Magia que o conjurador aprende ao subir de nível (catálogo: "aprende_a_cada_nivel"): a de maior círculo que ele já
## pode lançar, divina ou universal, completa e ainda não conhecida. Empate: ordem alfabética. "" se não há nenhuma.
static func magia_aprendida_no_nivel(sheet: CharacterSheet, rules: RuleRegistry) -> String:
	var max_c := circulo_maximo(sheet, rules)
	var ids: Array = COMPLETAS.keys()
	ids.sort()
	var best := ""
	var best_c := -1
	for sp_id in ids:
		var sp: Dictionary = rules.value("magia." + str(sp_id), {})
		if sp.is_empty() or not ["divina", "universal"].has(str(sp.get("tipo", ""))):
			continue
		var circ := int(sp.get("circulo", 0))
		if circ > max_c or circ <= best_c or sheet.spells.has(sp_id):
			continue
		best = str(sp_id)
		best_c = circ
	return best


static func circulo_maximo(sheet: CharacterSheet, rules: RuleRegistry) -> int:
	var magia: Dictionary = rules.value("classe." + sheet.class_id, {}).get("magia", {})
	var circulos: Dictionary = magia.get("circulos", {})
	if circulos.is_empty():
		return 1 + maxi(0, (sheet.level - 1) / 4)   # arcanista e demais: mesmo ritmo do raio arcano
	var best := 1
	for c in circulos:
		if sheet.level >= int(circulos[c]):
			best = maxi(best, int(c))
	return best


## Círculo exigido pelo aprimoramento, lido do texto do catálogo ("Requer 2º círculo.").
static func circulo_exigido(sp_id: String, i: int, rules: RuleRegistry) -> int:
	var lista: Array = rules.value("magia." + sp_id, {}).get("aprimoramentos", [])
	if i < 0 or i >= lista.size():
		return 99
	var m := RegEx.create_from_string("Requer (\\d)º círculo").search(str(lista[i].texto))
	return int(m.get_string(1)) if m else 1


static func multi_alvo(sp_id: String, sp: Dictionary, apr: Array) -> bool:
	if str(sp.get("alvo_tipo", "")) == "Alvos":
		return true
	for i in MULTI_APR.get(sp_id, []):
		if apr.has(i):
			return true
	return false


## Alcance efetivo com os aprimoramentos escolhidos (ex.: Infligir Ferimentos muda para curto).
static func alcance_efetivo(sp_id: String, base: String, apr: Array) -> String:
	for i in ALCANCE_APR.get(sp_id, {}):
		if apr.has(i):
			return str(ALCANCE_APR[sp_id][i])
	return base


static func aprimoramentos_disponiveis(sp_id: String) -> Array:
	return COMPLETAS.get(sp_id, {}).get("aprimoramentos", [])


static func aprimoramentos_validos(sp_id: String, idx: Array, sheet: CharacterSheet, rules: RuleRegistry) -> bool:
	if not COMPLETAS.has(sp_id):
		return idx.is_empty()
	var permitidos: Array = COMPLETAS[sp_id].aprimoramentos
	var cmax := circulo_maximo(sheet, rules)
	for i in idx:
		if not permitidos.has(int(i)) or circulo_exigido(sp_id, int(i), rules) > cmax:
			return false
	for par in EXCLUSIVOS.get(sp_id, []):
		if idx.has(par[0]) and idx.has(par[1]):
			return false
	return true


static func custo_aprimoramentos(rules: RuleRegistry, sp_id: String, idx: Array) -> int:
	var lista: Array = rules.value("magia." + sp_id, {}).get("aprimoramentos", [])
	var total := 0
	for i in idx:
		if int(i) >= 0 and int(i) < lista.size():   # índice inválido é recusado na validação, não aqui
			total += int(lista[int(i)].pm)
	return total


## Perdição (divina 1): –1 em ataques e dano; +2 PM: –1 a mais (limite = círculo máximo do conjurador).
static func penalidade_perdicao(sheet: CharacterSheet, rules: RuleRegistry, idx: Array) -> int:
	return mini(1 + idx.count(0), circulo_maximo(sheet, rules))


## Bênção (divina 1): +1 em ataques e dano; +2 PM: +1 a mais, repetível (limite = círculo máximo do conjurador).
static func bonus_bencao(sheet: CharacterSheet, rules: RuleRegistry, idx: Array) -> int:
	return mini(1 + idx.count(1), circulo_maximo(sheet, rules))


static func e_reacao(sp_id: String) -> bool:
	return REACAO.has(sp_id)


## Lançar manualmente (no próprio turno): magias de reação só com aprimoramento de execução padrão.
static func pode_lancar_no_turno(sp_id: String, apr: Array) -> bool:
	for i in REACAO_APR.get(sp_id, []):
		if apr.has(i):
			return false   # execução de reação: só dispara em resposta a um evento
	if not REACAO.has(sp_id):
		return true
	for i in EXECUCAO_PADRAO_APR.get(sp_id, []):
		if apr.has(i):
			return true
	return false


static func tipo_energia_valido(t: String) -> bool:
	return TIPOS_ENERGIA.has(t)
