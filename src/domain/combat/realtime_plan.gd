class_name RealtimePlan
extends RefCounted
## Núcleo do combate em tempo real (reescrita em andamento; atrás de interruptor).
## - Cada ação do plano custa pontos conforme a categoria dela (kind): movimento, padrão, completa, livre.
## - Movimento custa por quadrado andado. Ação de longa execução (ritual) é um passo só, com a categoria dela.
## - Com o tempo parado (planejando), o relógio não avança. Ao executar, avança em tempo real.
## Puro: sem Node, sem SO, sem estado do combate atual.

const CUSTO_POR_KIND := {"movimento": 1, "padrao": 2, "completa": 3, "livre": 0}
const ORCAMENTO_PADRAO := 8

var orcamento: int = ORCAMENTO_PADRAO
var passos: Array = []   # cada passo: {kind, custo, ...}
var planejando: bool = false
var relogio: float = 0.0


func custo_do_kind(kind: String) -> int:
	return int(CUSTO_POR_KIND.get(kind, CUSTO_POR_KIND["padrao"]))


func custo_total() -> int:
	var total := 0
	for p in passos:
		total += int(p.custo)
	return total


## Pode adicionar o passo sem estourar o orçamento?
func pode_adicionar(passo: Dictionary) -> bool:
	return custo_total() + int(passo.custo) <= orcamento


## Adiciona um passo; devolve false se não couber no orçamento.
func adicionar(kind: String, dados: Dictionary = {}) -> bool:
	var passo := dados.duplicate()
	passo["kind"] = kind
	passo["custo"] = custo_do_kind(kind)
	if not pode_adicionar(passo):
		return false
	passos.append(passo)
	return true


## Passo de movimento de N quadrados: custa 1 ponto por quadrado.
func adicionar_movimento(quadrados: int, dados: Dictionary = {}) -> bool:
	var passo := dados.duplicate()
	passo["kind"] = "movimento"
	passo["custo"] = maxi(1, quadrados) * custo_do_kind("movimento")
	if custo_total() + int(passo.custo) > orcamento:
		return false
	passos.append(passo)
	return true


## Ritual (ação de longa execução) com tempo parado: um único passo, com a categoria dela.
func adicionar_ritual(kind: String, dados: Dictionary = {}) -> bool:
	return adicionar(kind, dados)


func limpar() -> void:
	passos.clear()


## Abre ou fecha o planejamento. Fechar deixa o plano pronto para executar.
func alternar_planejamento() -> void:
	planejando = not planejando


## Avança o relógio: parado enquanto planeja, em tempo real ao executar. Devolve o tempo que passou no mundo.
func avancar(dt: float) -> float:
	if planejando:
		return 0.0
	relogio += dt
	return dt
