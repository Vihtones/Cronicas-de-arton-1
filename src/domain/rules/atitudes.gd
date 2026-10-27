extends RefCounted
## Atitudes de NPCs e criaturas (LB p.259) e Mudar Atitude (Diplomacia, LB p.118).
## Só a atitude hostil leva a atacar; inamistoso desgosta mas não se arrisca para prejudicar.

const ORDEM := ["hostil", "inamistoso", "indiferente", "amistoso", "prestativo"]


## Atitude deslocada `n` categorias (positivo melhora), dentro da escala.
static func passo(atitude: String, n: int) -> String:
	var i := ORDEM.find(atitude)
	if i < 0:
		i = ORDEM.find("indiferente")
	return ORDEM[clampi(i + n, 0, ORDEM.size() - 1)]


## Ataca ou faz ações agressivas.
static func agressiva(atitude: String) -> bool:
	return atitude == "hostil"


## Mudar Atitude: teste de Diplomacia oposto pela Vontade do alvo. Passou: +1 categoria (+2 se por 10 ou mais).
## Falhou por 5 ou mais: –1 categoria. Devolve a nova atitude.
static func resultado_diplomacia(atitude: String, total: int, vontade: int) -> String:
	var margem := total - vontade
	if margem >= 10:
		return passo(atitude, 2)
	if margem >= 0:
		return passo(atitude, 1)
	if margem <= -5:
		return passo(atitude, -1)
	return atitude
