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
