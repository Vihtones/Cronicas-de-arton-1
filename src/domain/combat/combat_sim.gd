class_name CombatSim
extends RefCounted
const ClassFeatures := preload("res://src/domain/rules/class_features.gd")
## Estado e regras de combate puros (LB cap. 5, p.230-239). Usado tanto pela
## execução real (com dados) quanto pelo GhostPlanner (clone, sem dados).

var rules: RuleRegistry
var db: ContentDB
var walk_fn: Callable            # (Vector2i) -> bool, inclui portas fechadas
var env_fn: Callable             # (Vector2i) -> Dictionary {darkness:bool, fog:bool}
var combatants: Dictionary = {}  # id -> {id, side, tile:Vector2i, sheet:CharacterSheet, charge_turn:int, damaged_round:int, surprised:bool, flags:Array}
var order: Array[String] = []
var initiative: Dictionary = {}
var turn_idx := 0
var round_no := 1
var turn_counter := 0
var budget := {"std": 1, "move": 1}
var toggles: Dictionary = {}   # políticas de poderes opcionais do jogador: "ataque_poderoso"/"combate_defensivo" -> auto|sempre|nunca
## Zonas persistentes no terreno (Muralha, névoa, terreno difícil): {id, tiles: Array[Vector2i], tipo, rodadas, fonte}.
## rodadas = -1 não expira sozinha; os demais contam rodadas e saem ao chegar a 0.
var zonas: Array = []
## Marcas em criaturas (maldições, vínculos, invocações): {id, alvo, fonte, tipo, rodadas}. Mesma regra de rodadas.
var marcas: Array = []
## Ids que expiraram na última passagem de rodada (a apresentação pode mostrar o fim do efeito).
var expiradas: Array = []


func clone() -> CombatSim:
	var c := CombatSim.new()
	c.rules = rules; c.db = db; c.walk_fn = walk_fn; c.env_fn = env_fn
	for id in combatants:
		var x: Dictionary = combatants[id]
		c.combatants[id] = {"id": x.id, "side": x.side, "order": x.get("order", ""), "tile": x.tile, "sheet": x.sheet.duplicate_sheet(), "charge_turn": x.charge_turn,
			"damaged_round": x.damaged_round, "surprised": x.surprised, "flags": x.flags.duplicate()}
	c.order = order.duplicate()
	c.initiative = initiative.duplicate()
	c.turn_idx = turn_idx; c.round_no = round_no; c.turn_counter = turn_counter
	c.budget = budget.duplicate()
	c.toggles = toggles.duplicate()
	c.zonas = zonas.duplicate(true)
	c.marcas = marcas.duplicate(true)
	c.expiradas = expiradas.duplicate()
	return c


func current_id() -> String:
	return order[turn_idx] if turn_idx < order.size() else ""


func c(id: String) -> Dictionary:
	return combatants.get(id, {})


func occupant(t: Vector2i, except: String = "") -> String:
	for id in combatants:
		if id != except and combatants[id].tile == t and not combatants[id].sheet.is_dead():
			return id
	return ""


func _link_de(target: String) -> String:
	for e in c(target).sheet.efeitos:
		if e.stat == "link":
			return str(e.tipo)
	return ""


static func cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func speed_squares(id: String) -> int:
	var s: CharacterSheet = c(id).sheet
	var quadrado := float(rules.value("mapa.quadrado_m", 1.5))
	var q := int(s.speed_m / quadrado)
	var eff := s.effective_conditions(rules)
	if eff.has("imovel"): return 0
	if eff.has("caido"): return 1
	if eff.has("lento"): q = maxi(1, q / 2)
	var recuo_m := s.condition_mod(rules, "deslocamento_m")   # sobrecarregado: -3m
	if recuo_m < 0:
		q = maxi(0, q + int(float(recuo_m) / quadrado))
	if (c(id).flags as Array).has("impeto_%d" % round_no):
		q += int(float(rules.value("poder.impeto").deslocamento_m) / float(rules.value("mapa.quadrado_m", 1.5)))   # Ímpeto (LB p.66)
	return q


func is_enemy(a: String, b: String) -> bool:
	return c(a).side != c(b).side


func conscious(id: String) -> bool:
	var x := c(id)
	return not x.is_empty() and not x.sheet.is_down() and not x.flags.has("fora")


## --- Orçamento de ações (LB p.233) ------------------------------------------
func can_spend(kind: String) -> bool:
	match kind:
		"padrao": return budget.std > 0
		"movimento": return budget.move > 0 or budget.std > 0
		"completa": return budget.std > 0 and budget.move > 0
		"livre": return true
	return false


func spend(kind: String) -> void:
	match kind:
		"padrao": budget.std -= 1
		"movimento":
			if budget.move > 0: budget.move -= 1
			else: budget.std -= 1
		"completa":
			budget.std = 0; budget.move = 0
	# Enjoado (LB p.394): uma única ação, padrão ou de movimento, por turno.
	if kind != "completa" and budget.get("enjoado", false):
		budget.std = 0; budget.move = 0


## --- Movimento (LB p.238) ----------------------------------------------------
func step_cost(from: Vector2i, to: Vector2i) -> int:
	var base := 2 if (from.x != to.x and from.y != to.y) else 1
	if db.is_difficult(to) or zona_em(to, "terreno_dificil"): base *= 2
	return base


func passable(t: Vector2i, mover: String) -> bool:
	if not walk_fn.call(t) and not _swims_into(t, mover) and not _flies_over(t, mover):
		return false
	var occ := occupant(t, mover)
	if occ == "":
		return true
	# pode atravessar aliado; inimigo só se caído/indefeso (LB p.238)
	return not is_enemy(mover, occ) or c(occ).sheet.is_down()


## Nadar (Heróis: deslocamento de natação igual ao base): quem nada atravessa a água sem custo extra.
func _swims_into(t: Vector2i, mover: String) -> bool:
	return db.is_water(t) and c(mover).sheet.can_swim()


## Voo sobre desnível (barranco): quem voa atravessa sem custo extra (Heróis, Voo).
func _flies_over(t: Vector2i, mover: String) -> bool:
	return db.is_chasm(t) and c(mover).sheet.can_fly()


func path_cost(mover: String, path: Array) -> Dictionary:
	var pos: Vector2i = c(mover).tile
	var total := 0
	for p in path:
		var t := Vector2i(int(p[0]), int(p[1])) if p is Array else p as Vector2i
		if cheb(pos, t) != 1:
			return {"ok": false, "reason": "caminho descontínuo"}
		if not passable(t, mover):
			return {"ok": false, "reason": "caminho bloqueado"}
		total += step_cost(pos, t)
		pos = t
	if occupant(pos, mover) != "":
		return {"ok": false, "reason": "não pode terminar num espaço ocupado"}
	return {"ok": true, "cost": total, "end": pos}


## Dijkstra limitado; retorna caminho até um tile adjacente a goal (ou o próprio goal).
func find_path(mover: String, goal: Vector2i, adjacent_ok: bool = true, max_cost: int = 60) -> Array:
	var start: Vector2i = c(mover).tile
	var dist := {start: 0}
	var prev := {}
	var open: Array = [[0, start]]
	var best: Vector2i = start
	var best_d := cheb(start, goal)
	while not open.is_empty():
		open.sort_custom(func(a, b): return a[0] < b[0])
		var cur: Array = open.pop_front()
		var t: Vector2i = cur[1]
		if (adjacent_ok and cheb(t, goal) == 1 and occupant(t, mover) == "") or t == goal:
			best = t
			break
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0: continue
				var n := t + Vector2i(dx, dy)
				if not passable(n, mover): continue
				var nd: int = dist[t] + step_cost(t, n)
				if nd > max_cost: continue
				if not dist.has(n) or nd < dist[n]:
					dist[n] = nd
					prev[n] = t
					open.append([nd, n])
					var dd := cheb(n, goal)
					if dd < best_d and occupant(n, mover) == "":
						best_d = dd
						best = n
	var path: Array = []
	var cur := best
	while cur != start and prev.has(cur):
		path.push_front(cur)
		cur = prev[cur]
	return path


## Corta um caminho para caber no deslocamento.
func trim_path(mover: String, path: Array, budget_sq: int) -> Array:
	var pos: Vector2i = c(mover).tile
	var spent := 0
	var out: Array = []
	for t in path:
		var cst := step_cost(pos, t)
		if spent + cst > budget_sq: break
		spent += cst
		out.append(t)
		pos = t
	while not out.is_empty() and occupant(out[-1], mover) != "":
		out.pop_back()
	return out


## --- Ataque (LB p.230-239) ----------------------------------------------------
func flanking(attacker: String, target: String) -> bool:
	var a: Vector2i = c(attacker).tile
	var t: Vector2i = c(target).tile
	var opposite := t + (t - a)
	var ally := occupant(opposite)
	return ally != "" and not is_enemy(attacker, ally) and conscious(ally)


func engaged_in_melee(target: String) -> bool:
	for id in combatants:
		if is_enemy(id, target) and conscious(id) and cheb(c(id).tile, c(target).tile) == 1:
			return true
	return false


func attack_profile(attacker: String, target: String, atk_index: int, special: bool, charge: bool) -> Dictionary:
	var A := c(attacker)
	var T := c(target)
	if A.is_empty() or T.is_empty():
		return {"ok": false, "reason": "alvo inválido"}
	var sheet: CharacterSheet = A.sheet
	if atk_index < 0 or atk_index >= sheet.attacks.size():
		return {"ok": false, "reason": "ataque inexistente"}
	var atk: Dictionary = sheet.attacks[atk_index]
	var dist := cheb(A.tile, T.tile)
	var ranged: bool = atk.get("distancia", false)
	var reach := int(atk.get("alcance_q", 1))
	var mods: Array = []
	if not ranged and dist > 1:
		return {"ok": false, "reason": "alvo fora do alcance corpo a corpo"}
	if ranged and dist > reach * 2:
		return {"ok": false, "reason": "alvo além do dobro do alcance"}
	if T.sheet.is_dead():
		return {"ok": false, "reason": "alvo já está morto"}
	var mod: int = int(atk.bonus_fixo) if atk.has("bonus_fixo") else sheet.skill_value(atk.get("skill", "luta"), rules)
	mods.append(["base", mod])
	var cm := sheet.condition_mod(rules, "ataque")
	if cm != 0: mods.append(["condição", cm])
	if not ranged and sheet.has_effective_condition(rules, "caido"): mods.append(["atacante caído", -5])
	if not ranged and flanking(attacker, target): mods.append(["flanqueando", int(rules.value("situacao.flanquear").bonus_ataque)])
	if charge: mods.append(["investida", int(rules.value("acao.investida").bonus_ataque)])
	if special: mods.append(["ataque especial", int(rules.value("classe.guerreiro").ataque_especial.bonus) * special_tier(sheet)])
	if sheet.has_power("valentao") and (T.sheet.has_effective_condition(rules, "caido") or T.sheet.has_effective_condition(rules, "desprevenido") \
			or T.sheet.has_effective_condition(rules, "indefeso") or (not ranged and flanking(attacker, target))):
		mods.append(["valentão", 2])  # LB p.66
	# Golpe Divino do paladino (LB p.82): corpo a corpo, 2 PM (+1 PM por dado extra), +Car no ataque e +1d8 por dado.
	var golpe_dados := 0
	var golpe_on := not ranged and ClassFeatures.golpe_divino_disponivel(sheet) and sheet.pm >= 2
	if attacker == "player" and str(toggles.get("golpe_divino", "auto")) == "nunca":
		golpe_on = false
	if golpe_on:
		var passos := 0
		if attacker == "player" and str(toggles.get("golpe_divino_extra", "nunca")) == "auto":
			passos = mini(ClassFeatures.golpe_passos_max(sheet), sheet.pm - 2)
		golpe_dados = 1 + passos
		mods.append(["golpe divino", int(sheet.attrs["car"])])
	# Ataque Poderoso (LB p.124): corpo a corpo, -2 ataque / +5 dano. "auto" usa se a chance continuar boa.
	if not ranged and sheet.has_power("ataque_poderoso") and _power_on(attacker, "ataque_poderoso", mods, T):
		mods.append(["ataque poderoso", -2])
	# Combate Defensivo (LB p.125): ao agredir, -2 nos ataques e +5 na Defesa até o próximo turno.
	if sheet.has_power("combate_defensivo") and str(toggles.get("combate_defensivo", "nunca")) == "sempre" and attacker == "player":
		mods.append(["combate defensivo", -2])
	if not ranged and ClassFeatures.furia_bonus(sheet) > 0: mods.append(["fúria", ClassFeatures.furia_bonus(sheet)])   # Fúria do bárbaro
	if sheet.efeito_bonus("ataque") != 0: mods.append(["magia", sheet.efeito_bonus("ataque")])
	if ranged and dist > reach: mods.append(["dobro do alcance", -5])
	if ranged and engaged_in_melee(target): mods.append(["alvo em corpo a corpo", -5])
	var total_mod := 0
	for m in mods: total_mod += int(m[1])
	var defense: int = T.sheet.defense(rules, not ranged)
	if T.flags.has("defensivo"): defense += 5   # Combate Defensivo
	if T.charge_turn >= 0 and T.charge_turn >= turn_counter - order.size():
		defense += int(rules.value("acao.investida").penalidade_defesa)
	var miss_chance := 0
	if ranged and T.sheet.efeito_bonus("camuflagem") > 0:
		miss_chance = int(rules.value("situacao.camuflagem_leve").falha_pct)   # Escudo da Fé (camuflagem leve)
	var env: Dictionary = env_fn.call(T.tile) if env_fn.is_valid() else {}
	var sees_dark: bool = sheet.senses.has("visao_penumbra")
	if (env.get("darkness", false) and not sees_dark) or env.get("fog", false):
		if dist > 1 or env.get("fog", false):
			miss_chance = int(rules.value("situacao.camuflagem_leve").falha_pct)
	var avg := Dice.average(atk.dano) + (int(sheet.attrs["for"]) if atk.get("for_no_dano", false) else 0) + archer_bonus(sheet, ranged)
	if mods.any(func(m): return m[0] == "ataque poderoso"): avg += 5
	avg += Dice.average("%dd8" % golpe_dados) if golpe_dados > 0 else 0.0
	var hit_p := Checks.chance(total_mod, defense) * (1.0 - miss_chance / 100.0)
	var crit_p := clampf((21 - int(atk.margem)) / 20.0, 0.0, 1.0)
	crit_p = minf(crit_p, hit_p)
	return {"ok": true, "atk": atk, "mod": total_mod, "mods": mods, "defense": defense, "ranged": ranged, "miss_chance": miss_chance,
		"hit_chance": hit_p, "crit_chance": crit_p, "avg_damage": avg, "golpe_dados": golpe_dados}


## Poder opcional ligado? Inimigos com o poder usam sempre (IA simples); o jogador segue sua política.
## "auto": só se a chance de acerto com -2 continuar >= 55%.
func _power_on(attacker: String, power: String, mods: Array, T: Dictionary) -> bool:
	var pol := str(toggles.get(power, "auto")) if attacker == "player" else "sempre"
	if pol == "nunca": return false
	if pol == "sempre": return true
	var m := 0
	for x in mods: m += int(x[1])
	return Checks.chance(m - 2, T.sheet.defense(rules, true)) >= 0.55


## Ataque Especial (LB p.65): +4 por 1 PM; a cada 4 níveis pode gastar +1 PM por +4. Usa o maior patamar pagável.
func special_tier(sheet: CharacterSheet) -> int:
	var every := int(rules.value("classe.guerreiro").ataque_especial.get("a_cada_niveis", 4))
	var max_tier := 1 + (sheet.level - 1) / every
	return clampi(sheet.pm, 1, max_tier)


## Arqueiro (LB p.65): soma Sabedoria no dano à distância, limitado pelo nível.
static func archer_bonus(sheet: CharacterSheet, ranged: bool) -> int:
	if not ranged or not sheet.has_power("arqueiro"):
		return 0
	return clampi(int(sheet.attrs.sab), 0, sheet.level)


## Aplica dano e retorna tags para a câmera (queda, morte).
func apply_damage(target: String, amount: int) -> Array:
	var T := c(target)
	var s: CharacterSheet = T.sheet
	if s.has_effective_condition(rules, "petrificado"):
		amount = maxi(0, amount - 8)   # petrificado: redução de dano 8 (LB p.394)
	var link := _link_de(target)
	if link != "" and c(link).has("sheet") and not c(link).sheet.is_dead():
		# Escudo da Fé (4º aprimoramento): metade do dano vai para o conjurador, se ele estiver a até alcance curto
		if cheb(T.tile, c(link).tile) <= int(rules.value("alcance.quadrados", {}).get("curto", 6)):
			var metade := amount / 2
			amount = amount - metade
			apply_damage(link, metade)
		else:
			s.remove_efeito_link()
	# PV temporários (Heroísmo) absorvem o dano antes dos PV
	var absorvido := mini(s.pv_temp, amount)
	s.pv_temp -= absorvido
	amount -= absorvido
	var was_down := s.is_down()
	s.pv -= amount
	T.damaged_round = round_no
	var tags: Array = []
	if s.is_down() and not was_down:
		s.stable = false
		tags.append("queda")
	if s.is_dead():
		tags.append("morte")
	return tags


func next_turn() -> void:
	# Atordoado (Olhar Atordoante) perde a própria rodada: a condição acaba ao fim do turno dela
	if combatants.has(current_id()):
		combatants[current_id()].sheet.remove_condition("atordoado")
	turn_idx += 1
	turn_counter += 1
	if turn_idx >= order.size():
		turn_idx = 0
		round_no += 1
		_passar_rodada()
		for id in combatants:
			combatants[id].sheet.sorte_usada = false   # Sorte Salvadora volta a valer a cada rodada
	budget = {"std": 1, "move": 1}


func sides_alive() -> Dictionary:
	var out := {}
	for id in combatants:
		if conscious(id):
			out[combatants[id].side] = true
	return out


## --- Zonas e marcas (magias complexas: ver docs/MAGIA_COMPLEXA.md) ----------------------
## dados: efeitos da zona. Ex.: {"dano_inicio_turno": "1d6", "afeta": "inimigos", "lado": "player", "conjurador": "player"}.
func add_zona(id: String, tiles: Array, tipo: String, rodadas: int, fonte: String, dados: Dictionary = {}) -> void:
	zonas = zonas.filter(func(z): return z.id != id)
	zonas.append({"id": id, "tiles": tiles.duplicate(), "tipo": tipo, "rodadas": rodadas, "fonte": fonte, "dados": dados.duplicate(true)})


func remove_zona(id: String) -> void:
	zonas = zonas.filter(func(z): return z.id != id)


func zona_em(t: Vector2i, tipo: String) -> bool:
	for z in zonas:
		if z.tipo == tipo and (z.tiles as Array).has(t):
			return true
	return false


## dados: efeitos da marca. Ex.: {"dano_inicio_turno": "1d4", "conjurador": "player"}.
func add_marca(id: String, alvo: String, fonte: String, tipo: String, rodadas: int, dados: Dictionary = {}) -> void:
	marcas = marcas.filter(func(m): return not (m.id == id and m.alvo == alvo))
	marcas.append({"id": id, "alvo": alvo, "fonte": fonte, "tipo": tipo, "rodadas": rodadas, "dados": dados.duplicate(true)})


## Condição com duração em rodadas: vira uma marca do tipo "condicao", que a tira quando zera. Imune não recebe.
func add_condicao(alvo: String, condicao: String, rodadas: int, fonte: String) -> bool:
	var s: CharacterSheet = c(alvo).sheet
	if s.efeito_bonus("imune", condicao) > 0:
		return false
	s.add_condition(condicao, rules)
	if rodadas > 0:
		add_marca("cond_" + condicao, alvo, fonte, "condicao", rodadas, {"condicao": condicao})
	return true


func remove_marca(id: String, alvo: String) -> void:
	marcas = marcas.filter(func(m): return not (m.id == id and m.alvo == alvo))


func tem_marca(alvo: String, tipo: String) -> bool:
	for m in marcas:
		if m.alvo == alvo and m.tipo == tipo:
			return true
	return false


## Criaturas consciências cujo quadrado está em `tiles` (para áreas de magia).
func ids_em(tiles: Array) -> Array[String]:
	var out: Array[String] = []
	for id in combatants:
		if conscious(id) and tiles.has(combatants[id].tile):
			out.append(id)
	return out


## Tira uma criatura da simulação (invocação que expira). Ajusta a vez atual se ela estava antes.
func remove_combatant(id: String) -> void:
	var i := order.find(id)
	if i >= 0:
		if i < turn_idx:
			turn_idx -= 1
		order.remove_at(i)
	combatants.erase(id)


## Passagem de rodada: conta as rodadas de zonas e marcas; invocações que acabam saem do combate.
func _passar_rodada() -> void:
	expiradas.clear()
	for z in zonas:
		if z.rodadas > 0:
			z.rodadas -= 1
	zonas = zonas.filter(func(z): return z.rodadas != 0)
	var vivas: Array = []
	for m in marcas:
		if m.rodadas > 0:
			m.rodadas -= 1
		if m.rodadas == 0:
			expiradas.append(m.id)
			if m.tipo == "condicao" and combatants.has(m.alvo):
				c(m.alvo).sheet.remove_condition(str(m.dados.condicao))   # condição de rodadas (ex.: cego da Cólera de Azgher)
			if m.tipo == "invocacao" and combatants.has(m.alvo):
				remove_combatant(m.alvo)
		else:
			vivas.append(m)
	marcas = vivas
