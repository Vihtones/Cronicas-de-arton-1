class_name NpcNeedsModule
extends WorldModule
## Necessidades e objetivos de curto prazo dos moradores (Arton Viva, Fase 1). ORIGINAL_DO_JOGO.
## - Necessidades: fome e cansaço sobem com o tempo e caem ao comer/descansar; dinheiro é o ouro do morador.
## - Decisão: a cada hora, a necessidade mais urgente vira objetivo ("comer", "descansar") se passar do limite.
##   Sem urgência, o morador segue a agenda normal.
## - Ação: comer na taverna custa ouro e reduz a fome; descansar em casa reduz o cansaço.
## Determinístico (sem sorteio). Não decide combate nem regras de T20: só onde o morador está e o que ele consome.

const HUNGER_PER_HOUR := 0.03
const TIRED_PER_HOUR := 0.02
const HUNGRY_AT := 0.7          # a partir daqui o morador quer comer
const TIRED_AT := 0.8           # a partir daqui o morador quer descansar
const MEAL_COST := 2            # ouro de uma refeição na taverna
const MEAL_RELIEF := 0.6
const REST_RELIEF_PER_HOUR := 0.15
const STAY_PUT := ["guarda_dia", "guarda_noite"]

var state: Dictionary = {}      # id -> {hunger, tired, gold, goal}


func module_id() -> String: return "npc_needs"


func _ensure() -> void:
	if not state.is_empty():
		return
	for id in world.all_npc_ids():
		var d := world.npc_def(id)
		state[id] = {"hunger": 0.2, "tired": 0.1, "gold": int(d.get("gold", 0)), "goal": ""}


func _s(id: String) -> Dictionary:
	_ensure()
	if not state.has(id):
		state[id] = {"hunger": 0.2, "tired": 0.1, "gold": 0, "goal": ""}
	return state[id]


func hunger(id: String) -> float: return float(_s(id).hunger)
func tired(id: String) -> float: return float(_s(id).tired)
func gold(id: String) -> int: return int(_s(id).gold)
func goal(id: String) -> String: return str(_s(id).goal)


## Objetivo atual da necessidade (puro para quem consulta): "comer", "descansar" ou "".
func urgent_goal(id: String) -> String:
	var s := _s(id)
	if float(s.tired) >= TIRED_AT: return "descansar"
	if float(s.hunger) >= HUNGRY_AT: return "comer"
	return ""


func on_tick(tick: int) -> Array:
	_ensure()
	if tick % (60 / world.clock.tick_minutes) != 0:
		return []
	var npcs = world.module("npcs")
	var h := world.hour()
	for id in state:
		var s: Dictionary = state[id]
		var d := world.npc_def(id)
		if npcs == null or not npcs.npc(id).get("alive", false) or npcs.npc(id).get("captive", false):
			continue
		var loc := str(npcs.npc(id).location)
		var asleep := loc == str(d.get("home", "")) and (h < 6 or h >= 22)
		# necessidades crescem com o tempo; dormir cansa menos
		s.hunger = minf(1.0, float(s.hunger) + HUNGER_PER_HOUR)
		s.tired = minf(1.0, float(s.tired) + (0.0 if asleep else TIRED_PER_HOUR))
		if asleep:
			s.tired = maxf(0.0, float(s.tired) - REST_RELIEF_PER_HOUR)
		# decisão: a necessidade urgente vira objetivo; sem urgência, o objetivo é vazio
		s.goal = urgent_goal(id)
		# ação: chegou à taverna querendo comer, come
		if s.goal == "comer" and loc == "taverna":
			eat(id)
	return []


## Lugar que o objetivo pede agora ("" se nenhum). Usado pela agenda do morador.
func location_override(id: String, d: Dictionary) -> String:
	if not enabled or STAY_PUT.has(str(d.get("schedule", ""))):
		return ""
	var g := goal(id)
	if g == "comer":
		# só come fora se tiver ouro; sem ouro, segue a vida normal (fome vai subindo)
		return "taverna" if gold(id) >= MEAL_COST else ""
	if g == "descansar":
		return str(d.get("home", ""))
	return ""


## Ação de comer: cobra na taverna e reduz a fome. Chamado quando o morador chega à taverna.
func eat(id: String) -> void:
	var s := _s(id)
	if float(s.hunger) < 0.1:
		return
	if int(s.gold) >= MEAL_COST:
		s.gold = int(s.gold) - MEAL_COST
		s.hunger = maxf(0.0, float(s.hunger) - MEAL_RELIEF)


func to_dict() -> Dictionary:
	_ensure()
	return {"state": state.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	state = d.get("state", {}).duplicate(true)
	for id in state:
		state[id].hunger = float(state[id].hunger)
		state[id].tired = float(state[id].tired)
		state[id].gold = int(state[id].gold)
		state[id].goal = str(state[id].goal)
