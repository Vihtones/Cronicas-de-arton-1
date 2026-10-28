class_name NpcNeedsModule
extends WorldModule
## Necessidades e objetivos dos moradores (Arton Viva, Fase 1). ORIGINAL_DO_JOGO.
## - Necessidades: fome e cansaço sobem com o tempo e caem ao comer/descansar; dinheiro é o ouro do morador.
## - Decisão por utilidade: a cada hora, a necessidade de maior valor acima do limite vira objetivo de curto
##   prazo ("comer", "descansar"). Sem urgência, o objetivo de médio prazo ("juntar_ouro") orienta o morador,
##   e ele segue a agenda normal.
## - Ação: comer na taverna custa ouro e reduz a fome; descansar em casa reduz o cansaço; trabalhar rende ouro
##   enquanto o morador junta para a meta de médio prazo, e cada turno cumprido (WORK_DONE) produz o bem da
##   profissão, que a economia da vila recebe.
## Determinístico (sem sorteio). Não decide combate nem regras de T20: só onde o morador está e o que ele consome.

const HUNGER_PER_HOUR := 0.03
const TIRED_PER_HOUR := 0.02
const HUNGRY_AT := 0.7          # a partir daqui o morador quer comer
const TIRED_AT := 0.8           # a partir daqui o morador quer descansar
const MEAL_COST := 2            # ouro de uma refeição na taverna
const SHORTAGE_MEAL_MULT := 2   # na falta de comida, a refeição na taverna custa o dobro (Fase 4)
const MEAL_RELIEF := 0.6
const REST_RELIEF_PER_HOUR := 0.15
const STAY_PUT := ["guarda_dia", "guarda_noite"]
const MEDIUM_TARGET_GOLD := 15  # médio prazo: juntar ouro até esta meta
const WORK_INCOME := 1          # ouro por hora de trabalho enquanto junta
const WORK_START := 8
const WORK_END := 18
const LONG_TARGET_GOLD := 40    # longo prazo: depois de juntar, abrir o próprio negócio
const VISIT_MIN_AFFECTION := 30.0  # afeto acima disso (de 100) vence o lazer da agenda e leva à visita
const SHIFT_MIN_HOURS := 6      # horas no posto para cumprir o turno e produzir o bem da profissão
const DESPENSA_MAX := 3         # refeições guardadas por casa (Fase 1: compras de moradores)
const DESPENSA_INICIAL := 0     # casas começam sem comida guardada: o morador precisa comprar
const COMIDA_DE_CASA := "pao"   # o que a família compra para guardar em casa

var state: Dictionary = {}      # id -> {hunger, tired, gold, goal, medium, long, shift}
var despensa: Dictionary = {}   # casa (id do local) -> refeições guardadas


func module_id() -> String: return "npc_needs"


func _ensure() -> void:
	if not state.is_empty():
		return
	for id in world.all_npc_ids():
		var d := world.npc_def(id)
		state[id] = _fresh(int(d.get("gold", 0)))
		state[id].tools = _history_tools(d)


func _fresh(gold: int) -> Dictionary:
	return {"hunger": 0.2, "tired": 0.1, "gold": gold, "goal": "", "medium": "", "long": "", "shift": 0, "tools": true}


## Ferramenta de ofício pela história: quem exerce a profissão e começou há anos o bastante já tem a sua.
## Quem não tem (aprendiz, ajudante recente) precisa comprar. Profissão sem ferramenta própria: tem por padrão.
func _history_tools(d: Dictionary) -> bool:
	var r := _tool_rule()
	var profs: Array = r.get("profissoes", [])
	if not profs.has(str(d.get("profession", ""))):
		return true
	var anos := int(d.get("age", 0)) - int(r.get("idade_inicio_oficio", 16))
	return anos >= int(r.get("anos_para_ter", 2))


func _tool_rule() -> Dictionary:
	return world.db.economy.get("ferramenta_de_oficio", {})


## Preço da refeição: dobra enquanto a vila está em falta de comida (crise de escassez, Fase 4).
func meal_cost() -> int:
	var eco = world.module("economy")
	var em_falta: bool = eco != null and bool(eco.shortage.get("comida", false))
	return MEAL_COST * SHORTAGE_MEAL_MULT if em_falta else MEAL_COST


func owns_tools(id: String) -> bool:
	return bool(_s(id).get("tools", true))


func tool_shop_location() -> String:
	return str(world.npc_def(str(_tool_rule().get("vendedor", ""))).get("work", ""))


func tool_price() -> int:
	return int(world.db.items.get(str(_tool_rule().get("item", "")), {}).get("price", 0))


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
func long_goal(id: String) -> String: return str(_s(id).long)


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


## Objetivo de longo prazo: abrir negócio, a partir de a meta de médio prazo ser batida.
## Fica ativo até o ouro bater a meta de longo prazo; depois, o morador segue a vida normal.
func long_goal_for(id: String) -> String:
	var current := str(_s(id).get("long", ""))
	if current == "abrir_negocio" and gold(id) >= LONG_TARGET_GOLD:
		return "concluido"
	if current == "abrir_negocio" or current == "concluido":
		return current
	return "abrir_negocio" if gold(id) >= MEDIUM_TARGET_GOLD else ""


func on_tick(tick: int) -> Array:
	_ensure()
	var out: Array = []
	if tick % (60 / world.clock.tick_minutes) != 0:
		return out
	var npcs = world.module("npcs")
	var h := world.hour()
	var ids := state.keys()
	ids.sort()  # ordem estável: eventos saem sempre na mesma sequência, com ou sem salvamento
	for id in ids:
		var s: Dictionary = state[id]
		var d := world.npc_def(id)
		if npcs == null or not npcs.npc(id).get("alive", false) or npcs.npc(id).get("captive", false):
			continue
		var loc := str(npcs.npc(id).location)
		var asleep := loc == str(d.get("home", "")) and (h < 6 or h >= 22)
		# necessidades crescem com o tempo; dormir cansa menos
		s.hunger = snappedf(minf(1.0, float(s.hunger) + HUNGER_PER_HOUR), 0.0001)
		s.tired = snappedf(minf(1.0, float(s.tired) + (0.0 if asleep else TIRED_PER_HOUR)), 0.0001)
		if asleep:
			s.tired = maxf(0.0, float(s.tired) - REST_RELIEF_PER_HOUR)
		# decisão: a necessidade de maior utilidade vira objetivo de curto prazo
		s.goal = urgent_goal(id)
		# médio prazo: sem urgência, junta ouro; o trabalho rende ouro no horário
		s.medium = medium_goal_for(id)
		s.long = long_goal_for(id)
		var at_work := loc == str(d.get("work", "")) and h >= WORK_START and h < WORK_END
		if s.goal == "" and s.medium == "juntar_ouro" and at_work:
			s.gold = int(s.gold) + WORK_INCOME
		# turno: conta as horas no posto; ao fim do expediente, um turno cumprido produz o bem da profissão
		if at_work:
			s.shift = int(s.get("shift", 0)) + 1
		if h == WORK_END:
			if int(s.get("shift", 0)) >= SHIFT_MIN_HOURS:
				var good := work_good(id)
				if good != "":
					out.append(fact("WORK_DONE", {"npc": id, "good": good, "amount": 1}, [id]))
			s.shift = 0
		# família: criança com fome e sem ouro recebe a refeição de um adulto da família que possa pagar
		if s.goal == "comer" and float(s.hunger) >= HUNGRY_AT and int(s.gold) < meal_cost():
			var payer := family_payer(id)
			if payer != "":
				var ps := _s(payer)
				ps.gold = int(ps.gold) - meal_cost()
				s.gold = int(s.gold) + meal_cost()
				out.append(fact("FAMILY_SUPPORT", {"from": payer, "to": id, "amount": meal_cost()}, [payer, id]))
		# ferramenta de ofício: quem não tem (pela história) compra no mercado, no tempo livre, com ouro
		if not at_work and not bool(s.get("tools", true)) and loc == tool_shop_location() and int(s.gold) >= tool_price():
			s.gold = int(s.gold) - tool_price()
			s.tools = true
			out.append(fact("TOOL_BOUGHT", {"npc": id, "price": tool_price()}, [id]))
		# despensa: no tempo livre, quem tem ouro compra comida para a casa onde há vendedor de pão
		var home := str(d.get("home", ""))
		if not at_work and despensa_de(home) < DESPENSA_MAX:
			var vend := _vendedor_de_pao(loc)
			if vend != "":
				var preco := _preco_de_compra(vend)
				if int(s.gold) >= preco:
					s.gold = int(s.gold) - preco
					despensa[home] = despensa_de(home) + 1
					out.append(fact("FOOD_BOUGHT", {"npc": id, "home": home, "price": preco, "vendor": vend, "regiao": _regiao_do_vendedor(vend)}, [id]))
		# comer em casa: com refeição guardada, a fome cai sem pagar taverna
		if s.goal == "comer" and loc == home and despensa_de(home) > 0 and float(s.hunger) >= 0.1:
			despensa[home] = despensa_de(home) - 1
			s.hunger = snappedf(maxf(0.0, float(s.hunger) - MEAL_RELIEF), 0.0001)
			out.append(fact("MEAL_AT_HOME", {"npc": id, "home": home}, [id]))
		# ação: chegou à taverna querendo comer, come; a refeição paga vira fato da economia
		if s.goal == "comer" and loc == taverna_do_morador(id) and eat(id):
			out.append(fact("MEAL_SERVED", {"npc": id, "cost": meal_cost(), "regiao": _regiao_da_taverna(id)}, [id]))
	return out


## Utilidade para a agenda (Arton Viva, Fase 1): num horário de trabalho, sem urgência e juntando ouro, o
## morador prefere o posto a um lugar de lazer previsto (almoço, pausa). Necessidades urgentes não passam por
## aqui: comer e descansar seguem depois, em location_override. Devolve o lugar escolhido.
func agenda_override(id: String, d: Dictionary, planned: String, h: int) -> String:
	if not enabled or STAY_PUT.has(str(d.get("schedule", ""))):
		return planned
	var work := str(d.get("work", ""))
	var home := str(d.get("home", ""))
	if planned == work or goal(id) != "":
		return planned
	if h >= WORK_START and h < WORK_END and medium_goal_for(id) == "juntar_ouro":
		return work
	# sem ferramenta própria e com ouro para ela: vai ao mercado no tempo livre
	if not owns_tools(id) and gold(id) >= tool_price() and tool_shop_location() != "":
		return tool_shop_location()
	if planned == home:
		return planned
	# tempo livre: visita quem gosta do morador e está em casa (Fase 1, utilidade da agenda)
	var visit := visit_target(id, d)
	if visit != "":
		return str(world.npc_def(visit).get("home", planned))
	return planned


## Morador de outra casa que o morador visitaria agora: o de maior afeto acima do limite, e que está em casa.
## "" se ninguém. Puro para quem consulta.
func visit_target(id: String, d: Dictionary) -> String:
	var relmod = world.module("relations")
	var npcs = world.module("npcs")
	if relmod == null or npcs == null:
		return ""
	# Só percorre quem o morador já conhece (afeto > 0). Limiar > 0, então pares sem dados nunca valem.
	# Empate de afeto: vence quem vem primeiro em all_npc_ids (igual à varredura completa de antes).
	var best := ""
	var best_affection := VISIT_MIN_AFFECTION
	var casa := str(d.get("home", ""))
	var conhecidos: Dictionary = relmod.rel.get(id, {})
	for other in conhecidos:
		var afeto := float(conhecidos[other].get("afeto", 0.0))
		if afeto <= VISIT_MIN_AFFECTION:
			continue
		if other == id or not npcs.state.has(other) or world.npc_def(other).is_empty():
			continue  # o jogador e ids fora do catálogo de moradores não entram
		var od := world.npc_def(other)
		if str(od.get("home", "")) == casa:
			continue  # mesma casa: não é visita
		var st: Dictionary = npcs.state.get(other, {})
		if not st.get("alive", true) or st.get("captive", false):
			continue
		if str(npcs.npc(other).location) != str(od.get("home", "")):
			continue  # só visita quem está em casa
		if afeto > best_affection or (afeto == best_affection and best != "" and _ordem(other) < _ordem(best)):
			best_affection = afeto
			best = other
	return best


var _ordem_cache: Dictionary = {}


## Posição do morador na ordem do catálogo (desempate estável de visitas).
func _ordem(id: String) -> int:
	if _ordem_cache.is_empty():
		var i := 0
		for nid in world.all_npc_ids():
			_ordem_cache[nid] = i
			i += 1
	return int(_ordem_cache.get(id, 1 << 30))


## Família: quem paga a refeição de uma criança sem ouro. Só adulto da mesma família, vivo e fora de cativeiro,
## com ouro para pagar e sobrar reserva (duas refeições). "" se ninguém pode.
func family_payer(id: String) -> String:
	var d := world.npc_def(id)
	var fam := str(d.get("family", ""))
	if str(d.get("profession", "")) != "criança" or fam == "":
		return ""
	var npcs = world.module("npcs")
	var best := ""
	var best_gold := meal_cost() * 2
	for other in world.all_npc_ids():
		if other == id:
			continue
		var od := world.npc_def(other)
		if str(od.get("family", "")) != fam or str(od.get("profession", "")) == "criança":
			continue
		var st: Dictionary = npcs.state.get(other, {}) if npcs != null else {}
		if not st.get("alive", true) or st.get("captive", false):
			continue
		if int(_s(other).gold) >= best_gold:
			best_gold = int(_s(other).gold)
			best = other
	return best


## Taverna onde o morador come: a da própria região (Fronteira e Pedra Branca não atravessam a vila para comer).
const TAVERNA_POR_ZONA := {"brejo": "taberna_sapo", "deserto": "pousada_camelo", "rocha": "taverna_picareta", "pedrabranca": "estalagem", "horizonte": "estalagem_horizonte", "vale_sul": "taverna_vale"}


## Região cuja comida a refeição consome: a da taverna do morador (vila por padrão).
func _regiao_da_taverna(id: String) -> String:
	var z := str(world.db.location(str(world.npc_def(id).get("home", ""))).get("zone", ""))
	return str(world.db.economy.get("regioes_por_zona", {}).get(z, "vila"))


func taverna_do_morador(id: String) -> String:
	var z := str(world.db.location(str(world.npc_def(id).get("home", ""))).get("zone", ""))
	return str(TAVERNA_POR_ZONA.get(z, "taverna"))


## Bem que a profissão do morador produz num turno completo ("" se não produz nada). Vem de economy.json.
func work_good(id: String) -> String:
	var prof := str(world.npc_def(id).get("profession", ""))
	return str(world.db.economy.get("producao_trabalho", {}).get(prof, ""))


## Lugar que o objetivo pede agora ("" se nenhum). Usado pela agenda do morador.
func location_override(id: String, d: Dictionary) -> String:
	if not enabled or STAY_PUT.has(str(d.get("schedule", ""))):
		return ""
	var g := goal(id)
	if g == "comer":
		# com comida guardada, come em casa; senão, só come fora se tiver ouro (sem ouro, a fome sobe)
		if despensa_de(str(d.get("home", ""))) > 0:
			return str(d.get("home", ""))
		return taverna_do_morador(id) if gold(id) >= meal_cost() else ""
	if g == "descansar":
		return str(d.get("home", ""))
	return ""


## Ação de comer: cobra na taverna e reduz a fome. Chamado quando o morador chega à taverna.
## Devolve true só se a refeição foi paga.
func eat(id: String) -> bool:
	var s := _s(id)
	if float(s.hunger) < 0.1 or int(s.gold) < meal_cost():
		return false
	s.gold = int(s.gold) - meal_cost()
	s.hunger = snappedf(maxf(0.0, float(s.hunger) - MEAL_RELIEF), 0.0001)
	return true


## Refeições guardadas numa casa (começa com DESPENSA_INICIAL).
func despensa_de(home: String) -> int:
	return int(despensa.get(home, DESPENSA_INICIAL))


## Vendedor de pão que trabalha neste local ("" se nenhum). Tabela montada uma vez (o catálogo não muda).
var _vendedores_pao: Dictionary = {}
var _vendedores_montados := false


func _vendedor_de_pao(loc: String) -> String:
	if not _vendedores_montados:
		_vendedores_montados = true
		var lojas: Dictionary = world.db.economy.get("shops", {})
		for vend in lojas:
			if (lojas[vend] as Array).has(COMIDA_DE_CASA):
				var l := str(world.npc_def(str(vend)).get("work", ""))
				if l != "" and not _vendedores_pao.has(l):
					_vendedores_pao[l] = str(vend)
	return str(_vendedores_pao.get(loc, ""))


func _preco_de_compra(vend: String) -> int:
	var eco = world.module("economy")
	if eco == null:
		return 0
	return int(eco.price(COMIDA_DE_CASA, eco.regiao_da_loja(vend), vend))


func _regiao_do_vendedor(vend: String) -> String:
	var eco = world.module("economy")
	return str(eco.regiao_da_loja(vend)) if eco != null else "vila"


func to_dict() -> Dictionary:
	_ensure()
	return {"state": state.duplicate(true), "despensa": despensa.duplicate()}


func from_dict(d: Dictionary) -> void:
	despensa = {}
	for k in d.get("despensa", {}):
		despensa[str(k)] = int(d.despensa[k])
	state = d.get("state", {}).duplicate(true)
	for id in state:
		state[id].hunger = float(state[id].hunger)
		state[id].tired = float(state[id].tired)
		state[id].gold = int(state[id].gold)
		state[id].goal = str(state[id].goal)
		state[id].medium = str(state[id].get("medium", ""))
		state[id].long = str(state[id].get("long", ""))
		state[id].shift = int(state[id].get("shift", 0))
		if state[id].has("tools"):
			state[id].tools = bool(state[id].tools)
