class_name FaunaModule
extends WorldModule
## Criaturas com território e recursos, custo limitado (§11). Protótipo: a matilha de
## hienas do Bosque Sombrio com comida, população e toca. Fome leva a ataques às
## ovelhas de Fenna — evento causal que alimenta o 2º mistério. ORIGINAL_DO_JOGO.

const SLOTS := ["hiena_1", "hiena_2", "hiena_3", "hiena_4"]
var food := 40          # 0..100
var den := "toca_leste"
## Centros das tocas (ORIGINAL_DO_JOGO). A toca funda fica mais longe da vila, no leste do Bosque Sombrio.
const DENS := {"toca_leste": [80, 36], "toca_funda": [88, 44]}
var attacks: Array[Dictionary] = []


func module_id() -> String: return "fauna"
func subscribed_events() -> PackedStringArray: return PackedStringArray(["CREATURE_DEFEATED"])


func _alive() -> Array:
	var c = world.module("combat")
	if c == null: return []
	return SLOTS.filter(func(id): return c.creature_state.has(id) and c.creature_state[id].alive and c.creature_state[id].present)


func pack_size() -> int:
	return _alive().size()


func on_tick(tick: int) -> Array:
	if tick % (24 * 60 / world.clock.tick_minutes) != 0 or tick == 0:
		return []
	var n := pack_size()
	if n == 0:
		return []
	var w = world.module("weather")
	var season: String = w.season() if w != null else "verao"
	var hunt: bool = world.rng.stream("world").randf() < {"verao": 0.6, "outono": 0.5, "inverno": 0.3, "primavera": 0.55}[season]
	food = clampi(food + (20 if hunt else -15) - n * 3, 0, 100)
	var out: Array = []
	if food < 25 and world.rng.stream("world").randf() < 0.6:
		var rec := {"day": world.day_index(), "victim": "ovelhas de Fenna", "location": "estrada_leste"}
		attacks.append(rec)
		food = mini(100, food + 30)
		out.append(fact("SHEEP_KILLED", {"location": "estrada_leste", "owner": "fenna", "by": "hienas", "count": 1 + world.rng.stream("world").randi() % 2,
			"witnesses": []}))
	if food > 80 and n < SLOTS.size():
		var c = world.module("combat")
		for id in SLOTS:
			if c.creature_state.has(id) and not c.creature_state[id].present and c.creature_state[id].alive:
				out.append(fact("PACK_GREW", {"creature": id, "size": n + 1}))
				break
	return out


func on_event(e: GameEvent) -> Array:
	if e.event_type == "CREATURE_DEFEATED" and SLOTS.has(e.payload.creature) and pack_size() > 0 and den == "toca_leste":
		den = "toca_funda"
		return [fact("PACK_RELOCATED", {"from": "toca_leste", "to": "toca_funda", "reason": "perdeu um membro",
			"center": DENS.toca_funda, "old_center": DENS.toca_leste})]
	return []


func to_dict() -> Dictionary: return {"food": food, "den": den, "attacks": attacks.duplicate(true)}
func from_dict(d: Dictionary) -> void:
	food = int(d.get("food", 40)); den = d.get("den", "toca_leste")
	attacks.clear()
	for a in d.get("attacks", []): attacks.append(a)
