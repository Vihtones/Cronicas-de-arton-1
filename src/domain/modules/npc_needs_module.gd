class_name NpcNeedsModule
extends WorldModule
## Necessidades e objetivos dos moradores (Arton Viva, Fase 1). ORIGINAL_DO_JOGO.
## - Necessidades: fome e cansaço sobem com o tempo e caem ao comer/descansar; dinheiro é o ouro do morador.
## - Decisão por utilidade: a cada hora, a necessidade de maior valor acima do limite vira objetivo de curto
##   prazo ("comer", "descansar"). Sem urgência, o objetivo de médio prazo ("juntar_ouro") orienta o morador,
##   e ele segue a agenda normal.
## - Ação: comer na taverna custa ouro e reduz a fome; descansar em casa reduz o cansaço; trabalhar rende ouro
##   enquanto o morador junta para a meta de médio prazo.
## Determinístico (sem sorteio). Não decide combate nem regras de T20: só onde o morador está e o que ele consome.

const HUNGER_PER_HOUR := 0.03
const TIRED_PER_HOUR := 0.02
const HUNGRY_AT := 0.7          # a partir daqui o morador quer comer
const TIRED_AT := 0.8           # a partir daqui o morador quer descansar
const MEAL_COST := 2            # ouro de uma refeição na taverna
const MEAL_RELIEF := 0.6
const REST_RELIEF_PER_HOUR := 0.15
const STAY_PUT := ["guarda_dia", "guarda_noite"]
const MEDIUM_TARGET_GOLD := 15  # médio prazo: juntar ouro até esta meta
const WORK_INCOME := 1          # ouro por hora de trabalho enquanto junta
const WORK_START := 8
const WORK_END := 18

var state: Dictionary = {}      # id -> {hunger, tired, gold, goal, medium}


func module_id() -> String: return "npc_needs"


func _ensure() -> void:
	if not state.is_empty():
		return
	for id in world.all_npc_ids():
		var d := world.npc_def(id)
		state[id] = _fresh(int(d.get("gold", 0)))


func _fresh(gold: int) -> Dictionary:
	return {"hunger": 0.2, "tired": 0.1, "gold": gold, "goal": "", "medium": ""}


func _s(id: String) -> Dictionary:
	_ensure()
	if not state.has(id):
		state[id] = _fresh(0)
	return state[id]


func hunger(id: String) -> float: return float(_s(id).hunger)
func tired(id: String) -> float: return float(_s(id).tired)
func gold(id: String) -> int: return int(_s(id).gold)
func goal(id: String) -> String: return str(_s(id).goal)
func medium_goal(id: String) -> String: return str(_s(id).medium)


## Objetivo de curto prazo por utilidade (puro para quem consulta): "comer", "descansar" ou "".
## Só entra a necessidade acima do limite; entre as duas, vence a de maior valor (empate: comer).
func urgent_goal(id: String) -> String:
	var s := _s(id)
	var hunger_ok := float(s.hunger) >= HUNGRY_AT
	var tired_ok := float(s.tired) >= TIRED_AT
	if hunger_ok and tired_ok:
		return "descansar" if float(s.tired) > float(s.hunger) else "comer"
	if tired_ok: return "descansar"
	if hunger_ok: return "comer"
	return ""


## Objetivo de médio prazo: juntar ouro enquanto o morador tiver menos que a meta.
func medium_goal_for(id: String) -> String:
	return "juntar_ouro" if gold(id) < MEDIUM_TARGET_GOLD else ""


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
		# decisão: a necessidade de maior utilidade vira objetivo de curto prazo
		s.goal = urgent_goal(id)
		# médio prazo: sem urgência, junta ouro; o trabalho rende ouro no horário
		s.medium = medium_goal_for(id)
		if s.goal == "" and s.medium == "juntar_ouro" and loc == str(d.get("work", "")) and h >= WORK_START and h < WORK_END:
			s.gold = int(s.gold) + WORK_INCOME
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
		state[id].medium = str(state[id].get("medium", ""))
