class_name Dice
extends RefCounted
## Expressões de dados "XdY+Z" com rolagem rastreável num fluxo RNG.


static func parse(expr: String) -> Dictionary:
	var e := expr.replace(" ", "").replace("–", "-")
	var re := RegEx.create_from_string("^(\\d*)d(\\d+)([+-]\\d+)?$")
	var m := re.search(e)
	if m == null:
		if e.is_valid_int():
			return {"count": 0, "sides": 0, "bonus": int(e)}
		return {}
	return {
		"count": int(m.get_string(1)) if m.get_string(1) != "" else 1,
		"sides": int(m.get_string(2)),
		"bonus": int(m.get_string(3)) if m.get_string(3) != "" else 0,
	}


## multiplier multiplica apenas os dados (crítico T20, LB p.230-231).
static func roll(expr: String, rng: RngStreams, stream: String, multiplier: int = 1, extra_bonus: int = 0) -> Dictionary:
	var d := parse(expr)
	assert(not d.is_empty(), "expressão de dado inválida: " + expr)
	var rolls := rng.roll(stream, d.count * multiplier, d.sides) if d.count > 0 else ([] as Array[int])
	var total: int = int(d.bonus) + extra_bonus
	for r in rolls:
		total += r
	return {"expr": expr, "rolls": rolls, "bonus": d.bonus + extra_bonus, "total": total}


## Resultado máximo (dados maximizados; o bônus soma uma vez).
static func maximo(expr: String, multiplier: int = 1) -> int:
	var d := parse(expr)
	assert(not d.is_empty(), "expressão de dado inválida: " + expr)
	return int(d.count) * multiplier * int(d.sides) + int(d.bonus)


static func average(expr: String) -> float:
	var d := parse(expr)
	return d.count * (d.sides + 1) / 2.0 + d.bonus
