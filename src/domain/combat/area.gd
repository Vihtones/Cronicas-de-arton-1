extends RefCounted
## Geometria de áreas de magia (LB p.143), em quadrados de 1,5m. Funções puras, sem estado.
## Usadas pelas magias de área, pelas zonas persistentes e pelas marcas da simulação de combate.

## Cone: 90 graus. Um quadrado está no cone se o ângulo com a direção for de até 45 graus.
const COS_CONE := 0.7


## Converte metros em quadrados (1 quadrado = 1,5m). Ex.: 9m = 6 quadrados, 30m = 20.
static func quadrados(metros: float) -> int:
	return roundi(metros / 1.5)


## Esfera (também cilindro ou cubo, vistos de cima): quadrados até `raio` do centro, inclusive o centro.
static func esfera(centro: Vector2i, raio: int) -> Array:
	var out: Array = []
	for dx in range(-raio, raio + 1):
		for dy in range(-raio, raio + 1):
			out.append(centro + Vector2i(dx, dy))
	return out


## Cone de `comprimento` quadrados a partir de `origem`, numa das 8 direções (vetor unitário). Não inclui a origem.
static func cone(origem: Vector2i, direcao: Vector2i, comprimento: int) -> Array:
	var out: Array = []
	var dir := Vector2(direcao).normalized()
	for dx in range(-comprimento, comprimento + 1):
		for dy in range(-comprimento, comprimento + 1):
			var off := Vector2i(dx, dy)
			if off == Vector2i.ZERO:
				continue
			if Vector2(off).normalized().dot(dir) >= COS_CONE:
				out.append(origem + off)
	return out


## Linha de `comprimento` quadrados a partir de `origem`, numa das 8 direções. Não inclui a origem.
static func linha(origem: Vector2i, direcao: Vector2i, comprimento: int) -> Array:
	var out: Array = []
	for k in range(1, comprimento + 1):
		out.append(origem + direcao * k)
	return out


## Quadrado de `lado` quadrados (visto de cima) com `centro` no meio (lado par: o centro fica no quadrante inferior direito).
static func quadrado(centro: Vector2i, lado: int) -> Array:
	var out: Array = []
	var ini := -(lado / 2)
	for dx in range(ini, ini + lado):
		for dy in range(ini, ini + lado):
			out.append(centro + Vector2i(dx, dy))
	return out
