class_name RngStreams
extends RefCounted
## Fluxos de RNG separados e rastreáveis (§7): combate, clima, mundo, visual.
## O fluxo "visual" nunca deve ser usado para resultados mecânicos.

const STREAMS := ["combat", "weather", "world", "visual", "conversa"]

var world_seed: int
var _rngs: Dictionary = {}


func _init(p_seed: int = 0) -> void:
	reseed(p_seed)


func reseed(p_seed: int) -> void:
	world_seed = p_seed
	for i in STREAMS.size():
		var r := RandomNumberGenerator.new()
		r.seed = hash([p_seed, STREAMS[i]])
		_rngs[STREAMS[i]] = r


func stream(name: String) -> RandomNumberGenerator:
	assert(_rngs.has(name), "Fluxo RNG desconhecido: " + name)
	return _rngs[name]


## Rola NdM no fluxo indicado. Ex.: roll("combat", 1, 20)
func roll(stream_name: String, count: int, sides: int) -> Array[int]:
	var out: Array[int] = []
	var r := stream(stream_name)
	for i in count:
		out.append(r.randi_range(1, sides))
	return out


func to_dict() -> Dictionary:
	var states := {}
	for k in _rngs:
		states[k] = str(_rngs[k].state)  # string: int64 não cabe com segurança em JSON
	return {"world_seed": str(world_seed), "states": states}


func from_dict(d: Dictionary) -> void:
	reseed(int(d.get("world_seed", "0")))
	var states: Dictionary = d.get("states", {})
	for k in states:
		if _rngs.has(k):
			_rngs[k].state = int(states[k])
