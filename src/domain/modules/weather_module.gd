class_name WeatherModule
extends WorldModule
## WeatherRegion (§12): muda em passos espaçados (de hora em hora) por cadeia de Markov
## no fluxo RNG "weather". Efeitos mecânicos só onde a regra existe:
## - neblina => camuflagem leve (LB p.238 cita neblina) — VERIFICADA
## - noite ao ar livre => escuridão leve => camuflagem leve (LB p.238) — VERIFICADA
## - chuva leva NPCs para dentro; chuva forte/neblina +5 na CD de percepção externa — ORIGINAL/ADAPTADA

const CONDITIONS := ["limpo", "nublado", "chuva", "tempestade", "neblina"]
## Probabilidades de transição por hora. ORIGINAL_DO_JOGO.
const TRANSITIONS := {
	"limpo": {"limpo": 0.85, "nublado": 0.12, "neblina": 0.03},
	"nublado": {"limpo": 0.2, "nublado": 0.6, "chuva": 0.17, "neblina": 0.03},
	"chuva": {"nublado": 0.25, "chuva": 0.65, "tempestade": 0.1},
	"tempestade": {"chuva": 0.5, "tempestade": 0.5},
	"neblina": {"limpo": 0.3, "neblina": 0.6, "nublado": 0.1},
}

var region := {"condition": "limpo", "temp_c": 18, "precip": 0.0, "cloud": 0.1, "wind": 0.2, "visibility": "normal", "surface": "seco"}
var wet_hours := 0


func module_id() -> String: return "weather"


func is_raining() -> bool:
	return enabled and region.condition in ["chuva", "tempestade"]


func is_night() -> bool:
	var h := world.hour()
	return h < 6 or h >= 19


func season() -> String:
	# PLACEHOLDER: estações de Arton a verificar; usa trimestres do calendário.
	var m: int = world.clock.calendar().month
	return ["verao", "outono", "inverno", "primavera"][((m - 1) / 3) % 4]


func on_tick(tick: int) -> Array:
	if tick % (60 / world.clock.tick_minutes) != 0:
		return []
	var row: Dictionary = TRANSITIONS[region.condition]
	var r := world.rng.stream("weather").randf()
	if season() == "inverno" and region.condition == "nublado":
		r *= 0.9  # inverno chove um pouco mais
	var acc := 0.0
	var next: String = region.condition
	for k in row:
		acc += float(row[k])
		if r <= acc:
			next = k
			break
	var base_temp: int = {"verao": 24, "outono": 17, "inverno": 9, "primavera": 16}[season()]
	var h := world.hour()
	region.temp_c = base_temp + (4 if h >= 11 and h <= 16 else -3 if h < 6 else 0) - (3 if next in ["chuva", "tempestade"] else 0)
	wet_hours = wet_hours + 1 if next in ["chuva", "tempestade"] else maxi(0, wet_hours - 1)
	region.surface = "lamacento" if wet_hours >= 3 else ("molhado" if wet_hours > 0 else "seco")
	region.precip = {"chuva": 0.5, "tempestade": 1.0}.get(next, 0.0)
	region.cloud = {"limpo": 0.1, "nublado": 0.7, "chuva": 0.9, "tempestade": 1.0, "neblina": 0.6}[next]
	region.wind = {"tempestade": 0.9}.get(next, 0.2)
	region.visibility = "reduzida" if next in ["neblina", "tempestade"] else "normal"
	if next != region.condition:
		var prev: String = region.condition
		region.condition = next
		return [fact("WEATHER_CHANGED", {"from": prev, "to": next, "temp_c": region.temp_c, "surface": region.surface})]
	return []


## Ambiente mecânico para combate num tile.
func env_at(t: Vector2i) -> Dictionary:
	if not enabled:
		return {}
	var zone := world.db.zone_at(t)
	var loc := world.db.location(world.db.location_at(t))
	var indoor := bool(loc.get("indoor", false)) or zone == "cripta"
	if indoor:
		return {"darkness": false, "fog": false}  # cripta iluminada por tochas do bando (ORIGINAL)
	return {"darkness": is_night(), "fog": region.condition == "neblina"}


func perception_cd_mod() -> int:
	if not enabled:
		return 0
	return 5 if region.condition in ["neblina", "tempestade"] else 0


func to_dict() -> Dictionary: return {"region": region.duplicate(), "wet_hours": wet_hours}
func from_dict(d: Dictionary) -> void:
	region = d.get("region", region).duplicate()
	wet_hours = int(d.get("wet_hours", 0))
