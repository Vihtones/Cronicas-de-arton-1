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
## Segurança e moradia (Arton Viva, Fase 5). Constantes de design, não de simulação de cidade real.
const GUARDS_IDEAL := 5          # guardas para segurança plena (4 hoje: 0,8 de base)
const HOME_CAPACITY := 4         # moradores por casa sem aperto
const CRIME_PENALTY := 0.1       # cada crime recente tira isso da segurança
const CRIME_PENALTY_MAX := 0.5
const MAX_RECENT_CRIMES := 10

var leaders: Dictionary = {}     # faction_id -> npc_id ("" se fragmentada)
var supply_days_low: int = 0      # dias seguidos com abastecimento baixo
var city_status: String = "estavel"  # estavel | em_decadencia
var initialized := false
var built: Dictionary = {}      # construção -> quantas a vila já fez
var recent_crimes: int = 0       # crimes cometidos pelo jogador nos últimos dias (decai por dia)


func module_id() -> String: return "cities"
func handled_commands() -> PackedStringArray: return PackedStringArray(["Build"])
func subscribed_events() -> PackedStringArray: return PackedStringArray(["NPC_DIED", "ECONOMY_DAY", "CRIME_COMMITTED", "BUILDING_DONE"])


func validate(cmd: GameCommand) -> PackedStringArray:
	var id := str(cmd.payload.get("id", ""))
	var defs: Dictionary = world.db.economy.get("construcoes", {})
	if not defs.has(id):
		return PackedStringArray(["não existe essa construção"])
	var eco = world.module("economy")
	if eco == null or int(eco.treasury) < int(defs[id].custo):
		return PackedStringArray(["falta ouro no tesouro da vila"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	var id := str(cmd.payload.id)
	var d: Dictionary = world.db.economy.construcoes[id]
	return [fact("BUILDING_DONE", {"id": id, "custo": int(d.custo), "efeito": d.get("efeito", {})})]


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


## Indicadores urbanos da vila (0 a 1), derivados do estado do mundo. Não são guardados: são leitura.
func indicators() -> Dictionary:
	var eco = world.module("economy")
	var npcs = world.module("npcs")
	var saude := 1.0
	var prosperidade := 0.0
	if eco != null:
		var r: Dictionary = eco.regions.vila
		var meta := float(r.target.get("remedio", 1))
		saude = minf(1.0, float(r.stock.get("remedio", 0)) / maxf(1.0, meta))
	var n := 0
	var ouro := 0.0
	var needs = world.module("npc_needs")
	if needs != null and npcs != null:
		for id in needs.state:
			if npcs.npc(id).get("alive", false):
				ouro += float(needs.gold(id))
				n += 1
	if n > 0:
		prosperidade = minf(1.0, ouro / float(n) / 30.0)
	var abast := supply_index()
	var guardas := 0
	for id in world.db.all_npc_ids():
		if str(world.db.npc_def(id).get("faction", "")) == "guarda_vila" and npcs != null and npcs.npc(id).get("alive", true):
			guardas += 1
	var seg_base := minf(1.0, float(guardas + _efeito_total("guardas")) / float(GUARDS_IDEAL))
	var penalidade := minf(CRIME_PENALTY_MAX, CRIME_PENALTY * recent_crimes)
	var seguranca := clampf(seg_base - penalidade, 0.0, 1.0)
	var moradia := _moradia()
	var influencia := clampf(0.4 * abast + 0.3 * seguranca + 0.3 * prosperidade, 0.0, 1.0)
	return {"abastecimento": snappedf(abast, 0.01), "saude": snappedf(saude, 0.01),
		"prosperidade": snappedf(prosperidade, 0.01), "estabilidade": 0.0 if city_status == "em_decadencia" else 1.0,
		"seguranca": snappedf(seguranca, 0.01), "moradia": snappedf(moradia, 0.01), "influencia": snappedf(influencia, 0.01)}


## Soma de um efeito de todas as construções feitas (ex.: "guardas", "vagas").
func _efeito_total(chave: String) -> int:
	var defs: Dictionary = world.db.economy.get("construcoes", {})
	var total := 0
	for id in built:
		total += int(defs.get(id, {}).get("efeito", {}).get(chave, 0)) * int(built[id])
	return total


## Moradia (0 a 1): moradores acima da capacidade de cada casa, menos as vagas abertas por construção.
func _moradia() -> float:
	var npcs = world.module("npcs")
	var por_casa := {}
	var vivos := 0
	for id in world.db.all_npc_ids():
		if npcs != null and not npcs.npc(id).get("alive", true):
			continue
		vivos += 1
		var casa := str(world.db.npc_def(id).get("home", ""))
		por_casa[casa] = int(por_casa.get(casa, 0)) + 1
	var aperto := 0
	for casa in por_casa:
		aperto += maxi(0, int(por_casa[casa]) - HOME_CAPACITY)
	var excesso := maxi(0, aperto - _efeito_total("vagas"))
	return clampf(1.0 - float(excesso) / float(maxi(1, vivos)), 0.0, 1.0)


func on_event(e: GameEvent) -> Array:
	_ensure()
	if e.event_type == "NPC_DIED":
		return _succeed(str(e.payload.get("npc", "")))
	if e.event_type == "ECONOMY_DAY":
		return _daily(supply_index())
	if e.event_type == "CRIME_COMMITTED":
		recent_crimes = mini(MAX_RECENT_CRIMES, recent_crimes + 1)
	if e.event_type == "BUILDING_DONE":
		var id := str(e.payload.get("id", ""))
		built[id] = int(built.get(id, 0)) + 1
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
	recent_crimes = maxi(0, recent_crimes - 1)
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
	return {"leaders": leaders.duplicate(true), "supply_days_low": supply_days_low, "city_status": city_status, "initialized": true, "built": built.duplicate(true), "recent_crimes": recent_crimes}


func from_dict(d: Dictionary) -> void:
	leaders = d.get("leaders", {}).duplicate(true)
	supply_days_low = int(d.get("supply_days_low", 0))
	city_status = str(d.get("city_status", "estavel"))
	initialized = bool(d.get("initialized", false))
	built = d.get("built", {}).duplicate(true)
	recent_crimes = int(d.get("recent_crimes", 0))
