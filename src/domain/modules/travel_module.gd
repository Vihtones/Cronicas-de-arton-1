class_name TravelModule
extends WorldModule
## Viagens entre regiões (LB p.270, Tabela 6-4): km/dia pelo deslocamento, metade em
## terreno difícil ou clima ruim. Rotas e distâncias são ORIGINAL_DO_JOGO.
## Ermos sem estrada usam o perigo "Jornada pelos ermos" (LB p.320).
## Encontros são causais: bando ativo na região aumenta o risco de emboscada.

const ROUTES := {
	"vila->valkaria": {"from": "vila", "to": "valkaria", "km": 90, "road": true},
	"valkaria->vila": {"from": "valkaria", "to": "vila", "km": 90, "road": true},
	"vila->ermos_norte": {"from": "vila", "to": "ermos_norte", "km": 40, "road": false, "terreno": "floresta"},
	"ermos_norte->vila": {"from": "ermos_norte", "to": "vila", "km": 40, "road": false, "terreno": "floresta"},
}
const DEPARTURE_LOCS := ["estrada_leste", "ponte"]

var current_region := "vila"     # vila | valkaria | ermos_norte
var trips: Array[Dictionary] = []


func module_id() -> String: return "travel"
func handled_commands() -> PackedStringArray: return PackedStringArray(["Travel"])


func available_routes() -> Array:
	var out: Array = []
	for k in ROUTES:
		if ROUTES[k].from == current_region:
			out.append(k)
	out.sort()
	return out


func km_per_day(route: Dictionary) -> float:
	var sh := world.player_sheet
	var speed_m := sh.speed_m + sh.efeito_bonus("deslocamento_m")   # Caminhos da Natureza: +3m
	var tab: Dictionary = world.rules.value("viagem.velocidade")
	# Tabela de viagem (LB p.270): por dia = deslocamento x 4 km; valores fora da tabela seguem a regra
	var kmd := float(tab[str(int(speed_m))].km_dia) if tab.has(str(int(speed_m))) else speed_m * 4.0
	var w = world.module("weather")
	if not route.road and sh.efeito_bonus("ignora_dificil_natural") <= 0:   # ermos: terreno difícil natural
		kmd *= float(tab.terreno_dificil_ou_clima_ruim)
	if w != null and w.region.condition in ["chuva", "tempestade", "neblina"]:
		kmd *= float(tab.terreno_dificil_ou_clima_ruim)
	return kmd


## Risco causal por dia: bando ativo na região => estrada mais perigosa. Guarda patrulhando reduz.
func ambush_risk() -> float:
	var risk := 0.05
	var combat = world.module("combat")
	if combat != null and not combat.creatures_of_faction("garras_de_cinza").is_empty():
		risk = 0.2
	if combat != null and combat.creatures_of_faction("salteadores").is_empty() and combat.creature_state.has("salteador_1") \
			and not combat.creature_state.salteador_1.alive:
		risk *= 0.5  # salteadores já derrotados
	var dom = world.module("domain")
	if dom != null and dom.owned and dom.policy.patrulha:
		risk *= 0.5  # patrulha do domínio protege a estrada
	return risk


func validate(cmd: GameCommand) -> PackedStringArray:
	var key: String = cmd.payload.get("route", "")
	if not ROUTES.has(key) or ROUTES[key].from != current_region:
		return PackedStringArray(["rota indisponível daqui"])
	var combat = world.module("combat")
	if combat != null and combat.active:
		return PackedStringArray(["em combate"])
	if current_region == "vila":
		var loc := world.db.location_at(world.db.world_to_tile(world.player.position))
		if not DEPARTURE_LOCS.has(loc):
			return PackedStringArray(["vá até a estrada leste para partir"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	var route: Dictionary = ROUTES[cmd.payload.route]
	var days := float(route.km) / km_per_day(route)
	# km/dia já embute 8h de marcha (LB p.270); o resto do dia é descanso => dias de calendário
	var hours := int(ceil(days * 24.0))
	var out: Array = [fact("TRAVEL_STARTED", {"route": cmd.payload.route, "km": route.km, "days": days}, ["player"])]
	# Emboscada TÁTICA na saída da vila (dia 1): vira combate real na estrada e a viagem não acontece.
	if current_region == "vila" and route.road and world.rng.stream("world").randf() < ambush_risk() * 1.5:
		out.append(fact("TRAVEL_AMBUSH", {"day": 1, "tactical": true, "cause": "salteadores", "pv_lost": 0, "gold_lost": 0}, ["player"]))
		trips.append({"route": cmd.payload.route, "days": 0, "events": ["emboscada tática na partida"]})
		return out
	var s := world.player_sheet
	var log := {"route": cmd.payload.route, "days": days, "events": []}
	# Jornada pelos ermos (LB p.320): testes de Sobrevivência até N sucessos ou 3 falhas
	if not route.road:
		var j: Dictionary = world.rules.value("perigo.jornada_ermos")
		# CD pelo terreno (LB p.320): planícies 15, florestas/pântanos 20, desertos/montanhas 25, Tormenta 30
		var cd := int(world.rules.value("perigo.jornada_ermos.cd", {}).get(str(route.get("terreno", "planicie")), 15))
		var ok := 0
		var fails := 0
		while ok < int(j.curta) and fails < int(j.limite_falhas):
			var r := Checks.skill(s, "sobrevivencia", cd, world.rules, world.rng, "world", s.efeito_bonus("sobrevivencia_orientar"))   # Caminhos (truque)
			if r.success: ok += 1
			else:
				fails += 1
				var loss := int(Dice.roll("2d6", world.rng, "world").total)
				s.pv = maxi(1, s.pv - loss)  # perda de vida por desgaste (não mata no protótipo)
				log.events.append("desgaste -%d PV" % loss)
		out.append(fact("JOURNEY_CHALLENGE", {"successes": ok, "failures": fails, "pv": s.pv}, ["player"]))
	var risk := ambush_risk()
	var n_days := int(ceil(days))
	for d in n_days:
		if world.rng.stream("world").randf() < risk:
			var loss := int(Dice.roll("1d6+1", world.rng, "world").total)
			var gold_lost := mini(int(world.player.gold), 5)
			s.pv = maxi(1, s.pv - loss)
			log.events.append("emboscada no dia %d" % (d + 1))
			out.append(fact("TRAVEL_AMBUSH", {"day": d + 1, "pv_lost": loss, "gold_lost": gold_lost, "cause": "garras_de_cinza" if risk > 0.1 else "salteadores"}, ["player"]))
			if gold_lost > 0:
				out.append(fact("GOLD_CHANGED", {"delta": -gold_lost, "reason": "emboscada"}))
	out.append_array(world.advance_ticks(hours * 60 / world.clock.tick_minutes))
	current_region = route.to
	world.player.region_id = route.to
	trips.append(log)
	out.append(fact("TRAVEL_ARRIVED", {"region": route.to, "hours": hours, "pv": s.pv}, ["player"]))
	if route.to == "vila":
		world.player.position = world.db.tile_to_world(world.db.location_spot("estrada_leste"))
	return out


func to_dict() -> Dictionary: return {"region": current_region, "trips": trips.duplicate(true)}
func from_dict(d: Dictionary) -> void:
	current_region = d.get("region", "vila")
	trips.clear()
	for t in d.get("trips", []):
		trips.append(t)
