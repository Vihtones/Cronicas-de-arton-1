class_name CartsModule
extends WorldModule
## Carroças de entrega (mundo vivo). ORIGINAL_DO_JOGO (não é regra de T20).
## Cada carroça nasce na estrada leste, chega ao mercado da vila, descarrega (a carga entra no estoque
## da vila) e volta pela mesma estrada. A carga é a mercadoria que mais falta na vila no momento da saída.
## Só o domínio decide QUANDO nasce, O QUE leva e QUANDO chega; a apresentação só desenha a posição.

const SPAWN_EVERY_TICKS := 18          # ~ a cada 3 horas do jogo, entre 6h e 19h
const TRAVEL_TICKS := 18               # ~3 horas de estrada até o mercado
const UNLOAD_TICKS := 6                # ~1 hora descarregando
const MAX_CARTS := 2
const LOAD_PER_CART := 12              # unidades por entrega (limitado pelo que falta)

var carts: Array = []                  # {id, phase: chegando|descarregando|saindo, t, cargo: {good: qty}, delivered: bool}
var _next_id := 1
var _next_spawn := 0


func module_id() -> String: return "carts"
func subscribed_events() -> PackedStringArray: return PackedStringArray(["TIME_ADVANCED"])


func _eco() -> EconomyModule:
	return world.module("economy") as EconomyModule


## Mercadoria que mais falta na vila (ou {} se nada falta).
func _deficit_cargo() -> Dictionary:
	var eco := _eco()
	if eco == null:
		return {}
	eco._ensure()
	var vila: Dictionary = eco.regions.get("vila", {})
	var best := ""
	var best_gap := 0
	for g in vila.get("stock", {}):
		var gap := int(vila.get("target", {}).get(g, 0)) - int(vila.stock[g])
		if gap > best_gap:
			best_gap = gap; best = g
	if best == "":
		return {}
	return {best: mini(LOAD_PER_CART, best_gap)}


func on_tick(tick: int) -> Array:
	var out: Array = []
	var h := world.hour()
	# nascimento: só de dia, e nunca mais de MAX_CARTS na estrada
	if tick >= _next_spawn and h >= 6 and h < 19 and carts.size() < MAX_CARTS and not _is_raining():
		_next_spawn = tick + SPAWN_EVERY_TICKS * int(world.rng.roll("world", 1, 2)[0] + 1) / 2
		var cargo := _deficit_cargo()
		carts.append({"id": "carroca_%d" % _next_id, "phase": "chegando", "t": 0, "cargo": cargo, "delivered": false})
		_next_id += 1
	var keep: Array = []
	for c in carts:
		c.t = int(c.t) + 1
		match c.phase:
			"chegando":
				if c.t >= TRAVEL_TICKS:
					c.phase = "descarregando"; c.t = 0
					if not c.cargo.is_empty() and not c.delivered:
						c.delivered = true
						out.append(fact("CART_DELIVERED", {"cart": c.id, "goods": c.cargo.duplicate()}))
			"descarregando":
				if c.t >= UNLOAD_TICKS:
					c.phase = "saindo"; c.t = 0
			"saindo":
				if c.t >= TRAVEL_TICKS:
					continue   # a carroça saiu de vista
		keep.append(c)
	carts = keep
	return out


func _is_raining() -> bool:
	var w = world.module("weather")
	return w != null and w.is_raining()


## Progresso na estrada, 0..1, para a apresentação: 0 = na estrada leste, 1 = no mercado.
func position_of(c: Dictionary) -> float:
	match c.phase:
		"chegando": return float(c.t) / float(TRAVEL_TICKS)
		"descarregando": return 1.0
		"saindo": return 1.0 - float(c.t) / float(TRAVEL_TICKS)
	return 0.0


func to_dict() -> Dictionary: return {"carts": carts.duplicate(true), "next_id": _next_id, "next_spawn": _next_spawn}
func from_dict(d: Dictionary) -> void:
	carts = d.get("carts", []).duplicate(true)
	_next_id = int(d.get("next_id", 1))
	_next_spawn = int(d.get("next_spawn", 0))
	for c in carts:
		c.t = int(c.t)
		c.delivered = bool(c.delivered)
