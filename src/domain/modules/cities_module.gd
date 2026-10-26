class_name CitiesModule
extends WorldModule
## Cidades e organizações (Arton Viva, Fase 5). ORIGINAL_DO_JOGO.
## - Abastecimento da vila: média de quanto cada mercadoria está perto da meta (economia). Dias seguidos
##   com abastecimento baixo levam a cidade a decadência; dias bons a recuperação. Nada disso exige o jogador.
## - Sucessão: a organização (facção) tem um líder. Quando ele morre, assume o membro vivo mais velho.
##   Sem membro vivo, a organização fica fragmentada. Nenhuma função vira insubstituível.
## Determinístico. Mudanças saem como fatos (LEADERSHIP_CHANGED, CITY_STATUS_CHANGED).

const LOW_SUPPLY := 0.35
const GOOD_SUPPLY := 0.6
const DECLINE_AFTER_DAYS := 3

var leaders: Dictionary = {}     # faction_id -> npc_id ("" se fragmentada)
var supply_days_low: int = 0      # dias seguidos com abastecimento baixo
var city_status: String = "estavel"  # estavel | em_decadencia
var initialized := false


func module_id() -> String: return "cities"
func subscribed_events() -> PackedStringArray: return PackedStringArray(["NPC_DIED", "ECONOMY_DAY"])


func _ensure() -> void:
	if initialized:
		return
	initialized = true
	for f in world.db.npcs.get("factions", []):
		var best := ""
		var best_age := -1
		for id in world.db.all_npc_ids():
			var d := world.db.npc_def(id)
			if str(d.get("faction", "")) == str(f.id) and int(d.get("age", 0)) > best_age:
				best = id
				best_age = int(d.get("age", 0))
		leaders[str(f.id)] = best


func leader_of(faction_id: String) -> String:
	_ensure()
	return str(leaders.get(faction_id, ""))


## Abastecimento da vila (0 a 1): média de estoque sobre meta, cada mercadoria limitada a 1.
func supply_index() -> float:
	var eco = world.module("economy")
	if eco == null:
		return 1.0
	var r: Dictionary = eco.regions.vila
	var soma := 0.0
	var n := 0
	for g in r.target:
		var meta := float(r.target[g])
		if meta <= 0.0:
			continue
		soma += minf(1.0, float(r.stock.get(g, 0)) / meta)
		n += 1
	return soma / float(maxi(1, n))


func on_event(e: GameEvent) -> Array:
	_ensure()
	if e.event_type == "NPC_DIED":
		return _succeed(str(e.payload.get("npc", "")))
	if e.event_type == "ECONOMY_DAY":
		return _daily(supply_index())
	return []


func _succeed(dead: String) -> Array:
	var out: Array = []
	var npcs = world.module("npcs")
	for f in world.db.npcs.get("factions", []):
		var fid := str(f.id)
		if leaders.get(fid, "") != dead:
			continue
		var best := ""
		var best_age := -1
		for id in world.db.all_npc_ids():
			var d := world.db.npc_def(id)
			if id == dead or str(d.get("faction", "")) != fid:
				continue
			if npcs != null and not npcs.npc(id).get("alive", true):
				continue
			if int(d.get("age", 0)) > best_age:
				best = id
				best_age = int(d.get("age", 0))
		leaders[fid] = best
		out.append(fact("LEADERSHIP_CHANGED", {"faction": fid, "from": dead, "to": best,
			"status": "ativa" if best != "" else "fragmentada"}))
	return out


func _daily(index: float) -> Array:
	if index < LOW_SUPPLY:
		supply_days_low += 1
	else:
		supply_days_low = maxi(0, supply_days_low - 1) if index < GOOD_SUPPLY else 0
	var novo := "em_decadencia" if supply_days_low >= DECLINE_AFTER_DAYS else "estavel"
	if novo == city_status:
		return []
	city_status = novo
	return [fact("CITY_STATUS_CHANGED", {"city": "vila", "status": novo, "supply": snappedf(index, 0.01)})]


func to_dict() -> Dictionary:
	_ensure()
	return {"leaders": leaders.duplicate(true), "supply_days_low": supply_days_low, "city_status": city_status, "initialized": true}


func from_dict(d: Dictionary) -> void:
	leaders = d.get("leaders", {}).duplicate(true)
	supply_days_low = int(d.get("supply_days_low", 0))
	city_status = str(d.get("city_status", "estavel"))
	initialized = bool(d.get("initialized", false))
