class_name ReligionModule
extends WorldModule
## Fé (§11): devoção segue o panteão e as obrigações verificadas no LB.
## Sem intervenções divinas inventadas: só registra devoção e violação de obrigações.

var player_devotion := ""
var violations: Array[Dictionary] = []


func module_id() -> String: return "religion"
func subscribed_events() -> PackedStringArray: return PackedStringArray(["BECOME_DEVOTEE", "LETHAL_DAMAGE_DEALT", "RENOUNCE_DEVOTION"])


func gods() -> Array:
	return world.rules.value("panteao.nomes", [])


func on_event(e: GameEvent) -> Array:
	match e.event_type:
		"BECOME_DEVOTEE":
			var g: String = e.payload.god
			if gods().has(g):
				player_devotion = g
				world.player_sheet.devotion = g
		"RENOUNCE_DEVOTION":
			player_devotion = ""
			world.player_sheet.devotion = ""
		"LETHAL_DAMAGE_DEALT":
			# LB p.100: devotos de Lena não podem causar dano letal a criaturas vivas.
			if player_devotion == "Lena" and not ["construto", "morto-vivo"].has(e.payload.get("creature_type", "")):
				var v := {"god": "Lena", "rule": "deus.lena.obrigacao", "tick": e.world_tick, "target": e.payload.target}
				violations.append(v)
				return [fact("OBLIGATION_VIOLATED", {"god": "Lena", "actor": "player", "location": "templo", "witnesses": [], "detail": v})]
	return []


func to_dict() -> Dictionary: return {"devotion": player_devotion, "violations": violations.duplicate(true)}
func from_dict(d: Dictionary) -> void:
	player_devotion = d.get("devotion", "")
	violations.clear()
	for v in d.get("violations", []):
		violations.append(v)
