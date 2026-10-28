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

var region := {"condition": "limpo", "temp_c": 18, "precip": 0.0, "cloud": 0.1, "wind": 0.2, "visibility": "normal", "surface": "seco",
	"intensity": 0.0, "wind_dir": 200.0}
## Intensidade da precipitação/neblina sobe e desce aos poucos (frentes chegam e passam em ~40 min),
## para o clima mudar DURANTE a exploração e não de um quadro para o outro. ORIGINAL_DO_JOGO.
const RAMP_PER_TICK := 0.25
const TARGET_INTENSITY := {"limpo": 0.0, "nublado": 0.0, "chuva": 0.6, "tempestade": 1.0, "neblina": 0.8}
var wet_hours := 0
var forcado := {}   # Controlar o Clima: {condicao, ate_tick}; o clima fica fixo até lá


func module_id() -> String: return "weather"


## Controlar o Clima: o clima passa a `condicao` agora e fica fixo por `horas` horas. Devolve o clima anterior.
func forcar(condicao: String, horas: int) -> String:
	var antes: String = region.condition
	forcado = {"condicao": condicao, "ate_tick": world.clock.tick + horas * 60 / world.clock.tick_minutes}
	region.condition = condicao
	return antes


func is_raining() -> bool:
	return enabled and region.condition in ["chuva", "tempestade"]


func is_night() -> bool:
	var h := world.hour()
	return h < 6 or h >= 19


func season() -> String:
	# PLACEHOLDER: estações de Arton a verificar; usa trimestres do calendário.
	var m: int = world.clock.calendar().month
	return ["verao", "outono", "inverno", "primavera"][((m - 1) / 3) % 4]


## Calor e Frio (LB p.318): acima de 50 °C ou abaixo de –10 °C, Fortitude por dia (CD 15 +1 por teste anterior);
## acima de 60 °C ou abaixo de –20 °C, por minuto. Falhou: 1d6 de fogo ou frio, que só cura fora do clima.
## Suporte Ambiental (imune ao clima) e imunidade ao tipo de dano protegem.
var testes_clima := 0
var ultimo_dia_clima := -1


func perigo_clima(tick: int) -> Array:
	var s: CharacterSheet = world.player_sheet
	if s == null:
		return []
	var t := int(region.temp_c)
	var tipo := "fogo" if t > 50 else ("frio" if t < -10 else "")
	if tipo == "":
		testes_clima = 0
		s.remove_efeito("clima")   # fora do clima, o dano volta a ser curável
		return []
	if s.efeito_bonus("imune_clima") > 0:
		return []
	var extremo := t > 60 or t < -20
	var n := world.clock.tick_minutes if extremo else 0
	if not extremo and world.day_index() != ultimo_dia_clima:
		n = 1
		ultimo_dia_clima = world.day_index()
	var out: Array = []
	for i in n:
		var r := Checks.skill(s, "fortitude", 15 + testes_clima, world.rules, world.rng, "world")
		testes_clima += 1
		if not r.get("success", false):
			var dano := s.dano_por_tipo(tipo, int(Dice.roll("1d6", world.rng, "world").total))
			s.pv -= dano
			s.add_efeito("clima", "dano_clima", s.efeito_bonus("dano_clima") + dano, "clima")
			out.append(fact("CLIMATE_DAMAGE", {"tipo": tipo, "damage": dano, "pv_after": s.pv, "temp_c": t}, ["player"]))
	return out


func on_tick(tick: int) -> Array:
	var tgt: float = TARGET_INTENSITY.get(region.condition, 0.0)
	region.intensity = move_toward(float(region.get("intensity", tgt)), tgt, RAMP_PER_TICK)
	var clima_out := perigo_clima(tick)
	if tick % (60 / world.clock.tick_minutes) != 0:
		return clima_out
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
	if not forcado.is_empty():
		if world.clock.tick >= int(forcado.ate_tick):
			forcado = {}
		else:
			next = str(forcado.condicao)
	var base_temp: int = {"verao": 24, "outono": 17, "inverno": 9, "primavera": 16}[season()]
	var h := world.hour()
	region.temp_c = base_temp + (4 if h >= 11 and h <= 16 else -3 if h < 6 else 0) - (3 if next in ["chuva", "tempestade"] else 0)
	wet_hours = wet_hours + 1 if next in ["chuva", "tempestade"] else maxi(0, wet_hours - 1)
	region.surface = "lamacento" if wet_hours >= 3 else ("molhado" if wet_hours > 0 else "seco")
	region.precip = {"chuva": 0.5, "tempestade": 1.0}.get(next, 0.0)
	region.cloud = {"limpo": 0.1, "nublado": 0.7, "chuva": 0.9, "tempestade": 1.0, "neblina": 0.6}[next]
	region.wind = {"tempestade": 0.9, "chuva": 0.45, "nublado": 0.35}.get(next, 0.2)
	region.wind_dir = fposmod(float(region.get("wind_dir", 200.0)) + world.rng.stream("weather").randf_range(-25.0, 25.0), 360.0)
	region.visibility = "reduzida" if next in ["neblina", "tempestade"] else "normal"
	if next != region.condition:
		var prev: String = region.condition
		region.condition = next
		return clima_out + [fact("WEATHER_CHANGED", {"from": prev, "to": next, "temp_c": region.temp_c, "surface": region.surface})]
	return clima_out


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


func to_dict() -> Dictionary: return {"region": region.duplicate(), "wet_hours": wet_hours, "testes_clima": testes_clima, "ultimo_dia_clima": ultimo_dia_clima, "forcado": forcado.duplicate()}
func from_dict(d: Dictionary) -> void:
	var base := region.duplicate()
	region = d.get("region", region).duplicate()
	for k in base:
		if not region.has(k): region[k] = base[k]   # saves antigos
	wet_hours = int(d.get("wet_hours", 0))
	testes_clima = int(d.get("testes_clima", 0))
	ultimo_dia_clima = int(d.get("ultimo_dia_clima", -1))
	forcado = (d.get("forcado", {}) as Dictionary).duplicate()
