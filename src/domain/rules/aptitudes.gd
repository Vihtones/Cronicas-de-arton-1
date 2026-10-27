extends RefCounted
## Aptidões no estilo Nen (docs/PLANO_APTIDOES.md, fase 1): afinidade natural por domínio, distância em passos
## entre domínios, progresso em porcentagem com retornos decrescentes, nomeação ao passar do limiar e teto de
## 80% que só sobe com marco narrativo. Funções puras: não guardam estado; a ficha guarda os dados.

const DOMINIOS := ["fazer", "lutar", "criar", "cuidar", "conhecer", "comunicar", "sobreviver"]
## Vizinhança dos domínios: a distância entre dois domínios é o número de passos no grafo.
const VIZINHOS := {
	"fazer": ["criar", "lutar", "sobreviver"],
	"criar": ["fazer", "conhecer"],
	"conhecer": ["criar", "comunicar"],
	"comunicar": ["conhecer", "cuidar"],
	"cuidar": ["comunicar", "sobreviver"],
	"sobreviver": ["cuidar", "lutar", "fazer"],
	"lutar": ["sobreviver", "fazer"],
}
const GANHO_BASE := 2.0          # pontos de % por uso bem-sucedido, antes dos fatores
const FATOR_DISTANCIA := 0.75    # cada passo do domínio principal multiplica o ganho por este valor
const LIMIAR_NOME := 25.0        # acima disto a aptidão vira skill nomeada na ficha
const TETO_SEM_MARCO := 80.0     # sem marco narrativo, a aptidão para aqui
const TETO := 100.0
const CUSTO_XP_BASE := 5         # XP para aprender uma aptidão nova, multiplicado por (distância + 1)


## Domínio de cada perícia do Livro Básico: a aptidão de uma perícia é "dominio.pericia".
const DOMINIO_DE_PERICIA := {
	"acrobacia": "sobreviver", "adestramento": "cuidar", "atletismo": "lutar", "atuacao": "criar",
	"cavalgar": "sobreviver", "conhecimento": "conhecer", "cura": "cuidar", "diplomacia": "comunicar",
	"enganacao": "comunicar", "fortitude": "cuidar", "furtividade": "sobreviver", "guerra": "lutar",
	"iniciativa": "sobreviver", "intimidacao": "comunicar", "intuicao": "comunicar", "investigacao": "conhecer",
	"jogatina": "comunicar", "ladinagem": "fazer", "luta": "lutar", "misticismo": "conhecer", "nobreza": "comunicar",
	"oficio": "fazer", "percepcao": "conhecer", "pilotagem": "sobreviver", "pontaria": "lutar", "reflexos": "sobreviver",
	"religiao": "cuidar", "sobrevivencia": "sobreviver", "vontade": "cuidar",
}


## Subdomínios: a parte específica de um domínio (ex.: fazer → cozinhar, forjar). "geral" é o padrão.
const SUBDOMINIOS := {
	"fazer": ["geral", "cozinhar", "forjar", "pescar", "construir", "costurar", "destrancar"],
	"lutar": ["geral", "combate_corpo", "combate_distancia", "tatica", "forca"],
	"criar": ["geral", "arte", "escrita", "musica"],
	"cuidar": ["geral", "curar", "resistir", "domar", "rezar"],
	"conhecer": ["geral", "saber", "magia", "investigar", "perceber"],
	"comunicar": ["geral", "persuadir", "enganar", "intimidar", "ler_pessoas", "protocolo", "apostar"],
	"sobreviver": ["geral", "acrobatismo", "cavalgar", "furtar", "reagir", "sobrevivencia", "pilotar"],
}
## Subdomínio de cada perícia. A perícia "oficio" usa o ofício escolhido pelo jogador (ver chave_de_pericia).
const SUBDOMINIO_DE_PERICIA := {
	"acrobacia": "acrobatismo", "adestramento": "domar", "atletismo": "forca", "atuacao": "arte",
	"cavalgar": "cavalgar", "conhecimento": "saber", "cura": "curar", "diplomacia": "persuadir",
	"enganacao": "enganar", "fortitude": "resistir", "furtividade": "furtar", "guerra": "tatica",
	"iniciativa": "reagir", "intimidacao": "intimidar", "intuicao": "ler_pessoas", "investigacao": "investigar",
	"jogatina": "apostar", "ladinagem": "destrancar", "luta": "combate_corpo", "misticismo": "magia",
	"nobreza": "protocolo", "percepcao": "perceber", "pilotagem": "pilotar", "pontaria": "combate_distancia",
	"reflexos": "reagir", "religiao": "rezar", "sobrevivencia": "sobrevivencia", "vontade": "resistir",
}


static func subdominio_valido(dominio: String, subdominio: String) -> bool:
	return SUBDOMINIOS.has(dominio) and (subdominio as String) in SUBDOMINIOS[dominio]


## Chave da aptidão ligada a uma perícia: "dominio.subdominio", ou "" se a perícia não tem domínio.
## Oficio usa o ofício escolhido (ex.: "cozinhar" → fazer.cozinhar); sem ofício válido, fazer.geral.
static func chave_de_pericia(pericia: String, oficio: String = "") -> String:
	var dom: String = DOMINIO_DE_PERICIA.get(pericia, "")
	if dom == "":
		return ""
	var sub: String = SUBDOMINIO_DE_PERICIA.get(pericia, "geral")
	if pericia == "oficio":
		sub = oficio if subdominio_valido(dom, oficio) else "geral"
	return dom + "." + sub


## Balanceamento com o Tormenta 20 (docs/BALANCEAMENTO_APTIDOES.md): o bônus de uma aptidão não passa do
## que um personagem treinado tem na T20 no mesmo nível (metade do nível + 2 do treinamento).
static func teto_balanceado(bonus_bruto: int, nivel: int) -> int:
	return mini(bonus_bruto, nivel / 2 + 2)


## Passos entre dois domínios (busca em largura). -1 se algum não existir.
static func distancia(a: String, b: String) -> int:
	if not VIZINHOS.has(a) or not VIZINHOS.has(b):
		return -1
	if a == b:
		return 0
	var visitados := {a: 0}
	var fila: Array = [a]
	while not fila.is_empty():
		var atual: String = fila.pop_front()
		for v in VIZINHOS[atual]:
			if not visitados.has(v):
				visitados[v] = int(visitados[atual]) + 1
				if v == b:
					return int(visitados[v])
				fila.append(v)
	return -1


## Mensagem de erro se a afinidade não for válida (vazia string = válida): domínios conhecidos e soma 100%.
static func erro_afinidade(aff: Dictionary) -> String:
	var soma := 0
	for d in aff:
		if not DOMINIOS.has(str(d)):
			return "domínio desconhecido: " + str(d)
		var v = aff[d]
		if not (v is int or v is float) or float(v) < 0.0:
			return "valor inválido em " + str(d)
		soma += int(v)
	if soma != 100:
		return "a afinidade deve somar 100 (soma " + str(soma) + ")"
	return ""


## Domínio de maior afinidade (empate: ordem de DOMINIOS). "" se a afinidade estiver vazia.
static func afinidade_principal(aff: Dictionary) -> String:
	var melhor := ""
	var melhor_v := -1.0
	for d in DOMINIOS:
		var v := float(aff.get(d, 0))
		if v > melhor_v:
			melhor_v = v
			melhor = d
	return melhor if melhor_v > 0.0 else ""


## Ganho de % por uso bem-sucedido. Diminui com a distância do domínio principal, com o progresso atual
## (retornos decrescentes perto do teto) e sobe com a afinidade natural no próprio domínio.
static func ganho(aff: Dictionary, dominio: String, pct: float) -> float:
	var principal := afinidade_principal(aff)
	var d := distancia(principal, dominio)
	if d < 0:
		d = 0
	var fator_afinidade := 0.5 + float(aff.get(dominio, 0)) / 100.0   # 0.5 a 1.5
	return GANHO_BASE * pow(FATOR_DISTANCIA, d) * fator_afinidade * maxf(0.05, 1.0 - pct / 100.0)


## Registra um uso da aptidão. Só o sucesso gera progresso (plano: "cada uso bem-sucedido gera ganho").
## estado = {"pct": float, "pratica": int, "marco": bool}. Devolve um novo dicionário.
static func praticar(estado: Dictionary, aff: Dictionary, chave: String, sucesso: bool) -> Dictionary:
	var e := {"pct": float(estado.get("pct", 0.0)), "pratica": int(estado.get("pratica", 0)), "marco": bool(estado.get("marco", false))}
	if not sucesso:
		return e
	var dom := chave.get_slice(".", 0)
	var teto := TETO if e.marco else TETO_SEM_MARCO
	e.pct = minf(teto, float(e.pct) + ganho(aff, dom, float(e.pct)))
	e.pratica = int(e.pratica) + 1
	return e


## Bônus de teste pela porcentagem: +1 a cada 10%.
static func bonus(pct: float) -> int:
	return int(pct / 10.0)


static func nomeada(pct: float) -> bool:
	return pct >= LIMIAR_NOME


## XP para aprender uma aptidão no domínio dado: sobe com a distância do domínio principal.
static func custo_aprender(aff: Dictionary, dominio: String) -> int:
	var d := distancia(afinidade_principal(aff), dominio)
	if d < 0:
		d = 0
	return CUSTO_XP_BASE * (d + 1)
