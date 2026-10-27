class_name CombatModule
extends WorldModule
const ClassFeatures := preload("res://src/domain/rules/class_features.gd")
const SpellRules := preload("res://src/domain/combat/spell_rules.gd")
const Area := preload("res://src/domain/combat/area.gd")
## Combate tático híbrido (§9). Planejamento congelado no turno, fantasma sem
## efeitos reais, rolagens só na execução, log de eventos para a apresentação.

const DETECT_AWAKE := 6
const DETECT_ASLEEP := 3
const SIGNAL_RADIUS := 12
const FLEE_DISTANCE := 10

var active := false
var sim: CombatSim
var creature_state: Dictionary = {}  # id -> {alive, present, tile, sheet(dict), woken_until}
## C20: como o jogador usa poderes com custo. Golpe de Raspão: "auto" | "nunca" (cada ataque pode sobrescrever
## com "raspao": true/false no plano). Durão: "fortes" (golpes ≥ 1/4 dos PV) | "sempre" | "nunca".
const POWER_POLICIES := {"escudo_da_fe": ["auto", "nunca"], "protecao_divina": ["auto", "nunca"], "golpe_raspao": ["auto", "nunca"], "durao": ["fortes", "sempre", "nunca"],
	"rolamento_defensivo": ["fortes", "sempre", "nunca"], "ataque_reflexo": ["auto", "nunca"],
	"ataque_poderoso": ["auto", "sempre", "nunca"], "combate_defensivo": ["nunca", "sempre"], "trespassar": ["auto", "nunca"],
	"golpe_divino": ["auto", "nunca"], "golpe_divino_extra": ["nunca", "auto"]}
const DEFAULT_POLICY := {"escudo_da_fe": "auto", "protecao_divina": "auto", "golpe_raspao": "auto", "durao": "fortes", "rolamento_defensivo": "fortes", "ataque_reflexo": "auto",
	"ataque_poderoso": "auto", "combate_defensivo": "nunca", "trespassar": "auto", "golpe_divino": "auto", "golpe_divino_extra": "nunca"}
var power_policy := DEFAULT_POLICY.duplicate()
var _cur_action: Dictionary = {}
var stance_sneak := false
var undetected_by: Dictionary = {}   # creature_id -> true (furtividade bem-sucedida nesta aproximação)
var approach_rolled: Dictionary = {} # creature_id -> true (já rolou nesta aproximação)
var enemy_faction := ""
var stats: Dictionary = {}  # desempenho do combate atual (XP dinâmica, ORIGINAL_DO_JOGO)
var log: Array = []


func module_id() -> String: return "combat"
func handled_commands() -> PackedStringArray:
	return PackedStringArray(["StartCombat", "ExecutePlan", "EndTurn", "SetStance", "SetPowerPolicy"])
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(["PLAYER_MOVED", "PLAYER_TELEPORTED", "OBJECT_DAMAGED", "BANDITS_RELOCATED", "CREATURE_DEFEATED", "PACK_GREW", "PACK_RELOCATED", "TRAVEL_AMBUSH", "ORDER_SET"])


func _ensure() -> void:
	if not creature_state.is_empty():
		return
	for id in world.db.all_creature_ids():
		var d := world.db.creature_def(id)
		var sheet := CharacterSheet.from_creature(world.rules, d.rule, id)
		sheet.name = d.name
		sheet.faction = d.faction
		sheet.is_important = bool(d.get("important", false))
		for pw in d.get("poderes", []):
			sheet.powers[str(pw)] = true
		sheet.pm_max = int(d.get("pm", 0)); sheet.pm = sheet.pm_max
		creature_state[id] = {"alive": true, "present": bool(d.get("start_present", true)), "tile": [int(d.spawn[0]), int(d.spawn[1])], "sheet": sheet.to_dict(), "woken_until": -1}


func creatures_of_faction(f: String, alive_only: bool = true) -> Array:
	_ensure()
	var out: Array = []
	for id in creature_state:
		if world.db.creature_def(id).faction == f and (not alive_only or (creature_state[id].alive and creature_state[id].present)):
			out.append(id)
	out.sort()
	return out


func creature_tile(id: String) -> Vector2i:
	var t: Array = creature_state[id].tile
	return Vector2i(int(t[0]), int(t[1]))


func is_active_creature(id: String) -> bool:
	_ensure()
	var s: Dictionary = creature_state.get(id, {})
	if s.is_empty() or not s.alive or not s.present:
		return false
	var d := world.db.creature_def(id)
	if d.has("active_hours"):
		var h := world.hour()
		var a := int(d.active_hours[0]); var b := int(d.active_hours[1])
		return (h >= a or h < b) if a > b else (h >= a and h < b)
	return true


func is_asleep(id: String) -> bool:
	var d := world.db.creature_def(id)
	if not d.has("sleeps") or int(creature_state[id].woken_until) > world.clock.tick:
		return false
	var h := world.hour()
	return h >= int(d.sleeps[0]) and h < int(d.sleeps[1])


func visible_creatures() -> Array:
	_ensure()
	var out: Array = []
	var p := world.db.world_to_tile(world.player.position)
	var zone := world.db.zone_at(p)
	for id in creature_state:
		if is_active_creature(id) and world.db.zone_at(creature_tile(id)) == zone and CombatSim.cheb(p, creature_tile(id)) <= SIGNAL_RADIUS:
			out.append(id)
	out.sort()
	return out


func creature_signals() -> Array:
	var out: Array = []
	for id in visible_creatures():
		var d := world.db.creature_def(id)
		if d.has("signal"):
			out.append({"id": id, "signal": d.signal})
	return out


# --- Comandos -----------------------------------------------------------------
func validate(cmd: GameCommand) -> PackedStringArray:
	_ensure()
	match cmd.type:
		"SetStance":
			if active: return PackedStringArray(["não durante o combate"])
		"SetPowerPolicy":
			var pw := str(cmd.payload.get("power", ""))
			if not POWER_POLICIES.has(pw): return PackedStringArray(["poder sem política: " + pw])
			if not (POWER_POLICIES[pw] as Array).has(str(cmd.payload.get("policy", ""))): return PackedStringArray(["política inválida"])
		"StartCombat":
			if active: return PackedStringArray(["combate já em andamento"])
			var ids: Array = cmd.payload.get("enemies", [])
			if ids.is_empty(): return PackedStringArray(["sem alvos"])
			var p := world.db.world_to_tile(world.player.position)
			for id in ids:
				if not creature_state.has(id) or not is_active_creature(id): return PackedStringArray(["alvo indisponível: " + str(id)])
				if CombatSim.cheb(p, creature_tile(id)) > 8: return PackedStringArray(["alvo longe demais"])
		"ExecutePlan":
			if not active: return PackedStringArray(["sem combate"])
			if sim.current_id() != "player": return PackedStringArray(["não é o seu turno"])
			var actions: Array = cmd.payload.get("actions", [])
			if actions.is_empty(): return PackedStringArray(["plano vazio"])
			var st = world.module("state")
			for act in actions:
				if act.get("type", "") == "drink" and (st == null or not st.has_item(str(act.get("item", "")))):
					return PackedStringArray(["você não tem " + str(act.get("item", ""))])
			var g := GhostPlanner.simulate(sim, "player", actions)
			if not g.valid:
				return PackedStringArray(["plano inválido: " + str(g.steps[-1].reason)])
		"EndTurn":
			if not active: return PackedStringArray(["sem combate"])
			if sim.current_id() != "player": return PackedStringArray(["não é o seu turno"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	match cmd.type:
		"SetPowerPolicy":
			power_policy[str(cmd.payload.power)] = str(cmd.payload.policy)
			if sim != null: sim.toggles = power_policy.duplicate()
			return [fact("POWER_POLICY_SET", {"power": cmd.payload.power, "policy": cmd.payload.policy}, ["player"])]
		"SetStance":
			stance_sneak = bool(cmd.payload.get("sneak", false))
			undetected_by.clear(); approach_rolled.clear()
			return [fact("STANCE_CHANGED", {"sneak": stance_sneak}, ["player"])]
		"StartCombat":
			var ids: Array = cmd.payload.enemies
			var surprised := ids.all(func(id): return undetected_by.has(id))
			return _start(_group_with(ids), surprised, false)
		"ExecutePlan":
			var out: Array = []
			var actions: Array = cmd.payload.actions
			for i in actions.size():
				var a: Dictionary = actions[i]
				var v := GhostPlanner.validate_action(sim, "player", a)
				if not v.ok:
					out.append(fact("PLAN_INTERRUPTED", {"index": i, "reason": v.reason, "remaining": actions.size() - i}, ["player"]))
					break
				out.append_array(_execute_action("player", a, v))
				_refresh_bencaos()
				var end := _check_end()
				if not end.is_empty():
					out.append_array(end)
					return out
				if a.type == "move" and _fled():
					out.append_array(_end_combat("fuga"))
					return out
			return out
		"EndTurn":
			var out: Array = []
			_zonas_fim_de_turno("player", out)
			out.append(fact("TURN_ENDED", {"actor": "player"}, ["player"]))
			sim.next_turn()
			out.append_array(_run_until_player())
			return out
	return []


# --- Encontros ------------------------------------------------------------------
func on_event(e: GameEvent) -> Array:
	_ensure()
	# ordem nova dada a um companheiro no meio da luta vale já (Arton Viva, Fase 6)
	if e.event_type == "ORDER_SET" and active and sim.combatants.has(str(e.payload.get("npc", ""))):
		sim.c(str(e.payload.npc))["order"] = str(e.payload.order)
		return []
	match e.event_type:
		"TRAVEL_AMBUSH":
			if not e.payload.get("tactical", false) or active:
				return []
			var group: Array = []
			for id in ["salteador_1", "salteador_2"]:
				if creature_state.has(id) and creature_state[id].alive:
					creature_state[id].present = true
					group.append(id)
			if group.is_empty():
				return []
			# Percepção do jogador x Furtividade dos salteadores (LB p.231): quem percebe primeiro
			var p := world.db.world_to_tile(world.player.position)
			creature_state[group[0]].tile = [p.x + 3, p.y - 1]
			if group.size() > 1: creature_state[group[1]].tile = [p.x - 2, p.y + 1]
			var mine := Checks.skill(world.player_sheet, "percepcao", 0, world.rules, world.rng, "combat")
			var theirs: int = world.rng.roll("combat", 1, 20)[0] + int(CharacterSheet.from_dict(creature_state[group[0]].sheet).skill_value("furtividade", world.rules))
			var surprised: bool = int(mine.total) < theirs
			return [fact("AMBUSH_PERCEPTION", {"player_total": mine.total, "enemy_total": theirs, "player_surprised": surprised}, ["player"])] + _start(group, false, surprised)
		"PACK_GREW":
			if creature_state.has(e.payload.creature):
				creature_state[e.payload.creature].present = true
			return []
		"PACK_RELOCATED":
			# C10: a matilha muda de toca; cada hiena mantém a posição relativa ao centro, num tile andável
			var oc := Vector2i(int(e.payload.old_center[0]), int(e.payload.old_center[1]))
			var nc := Vector2i(int(e.payload.center[0]), int(e.payload.center[1]))
			var moved: Array = []
			for id in creature_state:
				if not str(id).begins_with("hiena_") or not creature_state[id].alive:
					continue
				if active and sim.combatants.has(id):
					continue
				var sp: Array = world.db.creature_def(id).get("spawn", creature_state[id].tile)
				var t := _nearest_walkable(nc + (Vector2i(int(sp[0]), int(sp[1])) - oc))
				creature_state[id].tile = [t.x, t.y]
				moved.append(id)
			return [fact("CREATURES_MOVED", {"creatures": moved, "to": e.payload.to})] if not moved.is_empty() else []
		"BANDITS_RELOCATED":
			for id in e.payload.get("members", []):
				if creature_state.has(id): creature_state[id].present = false
			return []
		"CREATURE_DEFEATED":
			var id: String = e.payload.creature
			if creature_state.has(id) and e.payload.get("by", "") != "player":
				creature_state[id].alive = false
				creature_state[id].present = false
			return []
		"OBJECT_DAMAGED":
			if world.db.zone_at(world.db.world_to_tile(world.player.position)) == "cripta":
				# Acordados ouvem sempre; dormindo: Percepção -10 contra CD 10 (ADAPTADA).
				var heard: Array = []
				for id in creatures_of_faction("garras_de_cinza"):
					if not is_asleep(id):
						heard.append(id)
						continue
					var sh := CharacterSheet.from_dict(creature_state[id].sheet)
					if world.rng.roll("world", 1, 20)[0] + sh.skill_value("percepcao", world.rules) - 10 >= 10:
						heard.append(id)
				if heard.is_empty():
					return [fact("NOISE_UNHEARD", {"location": world.db.location_at(world.db.world_to_tile(world.player.position))})]
				for id in creatures_of_faction("garras_de_cinza"):
					creature_state[id].woken_until = world.clock.tick + 36
				if not active:
					var awake := creatures_of_faction("garras_de_cinza").filter(func(x): return is_active_creature(x))
					if not awake.is_empty():
						return [fact("NOISE_HEARD", {"by": awake})] + _start(awake, false, false)
			return []
		"PLAYER_MOVED", "PLAYER_TELEPORTED":
			if active:
				return []
			return _check_encounter()
	return []


func _group_with(ids: Array) -> Array:
	var group: Array = ids.duplicate()
	for id in ids:
		var f: String = world.db.creature_def(id).faction
		for other in creature_state:
			if not group.has(other) and world.db.creature_def(other).faction == f and is_active_creature(other) \
					and world.db.zone_at(creature_tile(other)) == world.db.zone_at(creature_tile(id)) \
					and CombatSim.cheb(creature_tile(other), creature_tile(id)) <= 10:
				group.append(other)
	group.sort()
	return group


func _check_encounter() -> Array:
	var p := world.db.world_to_tile(world.player.position)
	var zone := world.db.zone_at(p)
	var out: Array = []
	for id in creature_state:
		if not is_active_creature(id) or world.db.zone_at(creature_tile(id)) != zone:
			approach_rolled.erase(id); undetected_by.erase(id)
			continue
		var d := CombatSim.cheb(p, creature_tile(id))
		var asleep := is_asleep(id)
		var radius := DETECT_ASLEEP if asleep else DETECT_AWAKE
		if d > radius + 3:
			approach_rolled.erase(id); undetected_by.erase(id)
			continue
		if d > radius:
			continue
		if stance_sneak and d > 1:
			if approach_rolled.has(id):
				continue
			approach_rolled[id] = true
			# Teste oposto (LB p.231): Furtividade x Percepção. Dormindo: -10 (ADAPTADA).
			var group := _group_with([id])
			var best := -99
			for gid in group:
				var s := CharacterSheet.from_dict(creature_state[gid].sheet)
				best = maxi(best, s.skill_value("percepcao", world.rules) - (10 if is_asleep(gid) else 0))
			var mine := Checks.skill(world.player_sheet, "furtividade", 0, world.rules, world.rng, "world")
			var theirs: int = world.rng.roll("world", 1, 20)[0] + best
			var ok: bool = mine.total > theirs or (mine.total == theirs and mine.mod > best)
			out.append(fact("STEALTH_CHECK", {"group": group, "player_total": mine.total, "enemy_total": theirs, "success": ok}, ["player"]))
			if ok:
				for gid in group: undetected_by[gid] = true; approach_rolled[gid] = true
				continue
			return out + _start(group, false, false)
		if undetected_by.has(id) and d > 1:
			continue
		return out + _start(_group_with([id]), false, false)
	return out


func _armor_penalty() -> int:
	return int(world.rules.value("armadura.couro_batido", {}).get("penalidade", 0))


# --- Núcleo do combate --------------------------------------------------------------
func _new_sim() -> CombatSim:
	var s := CombatSim.new()
	s.rules = world.rules
	s.db = world.db
	# C16: Callables de método (não lambdas) — uma lambda capturava o módulo e criava ciclo módulo → sim → lambda → módulo.
	s.walk_fn = Callable(self, "_sim_walkable")
	s.env_fn = Callable(self, "_sim_env")
	s.toggles = power_policy.duplicate()
	return s


func _sim_walkable(t: Vector2i) -> bool:
	var objs = world.module("objects")
	return objs.walkable(t) if objs != null else world.db.static_walkable(t)


func _sim_env(t: Vector2i) -> Dictionary:
	var w = world.module("weather")
	return w.env_at(t) if w != null else {}


func _start(enemy_ids: Array, enemies_surprised: bool, player_surprised: bool) -> Array:
	var pre: Array = []
	var dlg = world.module("dialogue")
	if dlg != null and not dlg.session.is_empty():
		pre.append(fact("DIALOGUE_ENDED", {"npc": dlg.session.npc, "reason": "combate"}))
	sim = _new_sim()
	active = true
	log.clear()
	stats = {"rounds": 0, "dmg_dealt": 0, "dmg_taken": 0, "crits": 0, "tactics": {}, "adverse": {}, "pv_start": world.player_sheet.pv,
		"pv_max": world.player_sheet.pv_max, "pm_spent": 0, "went_down": false, "enemies": enemy_ids.duplicate(), "player_surprised": player_surprised,
		"enemies_surprised": enemies_surprised}
	if enemies_surprised: stats.tactics["surpresa"] = true
	if player_surprised: stats.adverse["surpreendido"] = true
	enemy_faction = world.db.creature_def(enemy_ids[0]).faction
	sim.combatants["player"] = {"id": "player", "side": "player", "tile": world.db.world_to_tile(world.player.position),
		"sheet": world.player_sheet.duplicate_sheet(), "charge_turn": -99, "damaged_round": -1, "surprised": player_surprised, "flags": []}
	for id in enemy_ids:
		creature_state[id].woken_until = world.clock.tick + 36
		sim.combatants[id] = {"id": id, "side": "enemy", "tile": creature_tile(id), "sheet": CharacterSheet.from_dict(creature_state[id].sheet),
			"charge_turn": -99, "damaged_round": -1, "surprised": enemies_surprised, "flags": []}
	# Iniciativa (LB p.231): jogador rola; inimigos fazem um teste único com o menor valor.
	var p_mod := world.player_sheet.skill_value("iniciativa", world.rules)
	var e_mod := 999
	for id in enemy_ids:
		e_mod = mini(e_mod, sim.c(id).sheet.skill_value("iniciativa", world.rules))
	var p_roll: int = 0
	var e_roll: int = 0
	for attempt in 6:
		p_roll = world.rng.roll("combat", 1, 20)[0] + p_mod
		e_roll = world.rng.roll("combat", 1, 20)[0] + e_mod
		if p_roll != e_roll or p_mod != e_mod:
			break
	var player_first := p_roll > e_roll or (p_roll == e_roll and p_mod >= e_mod)
	sim.order.clear()
	var enemies_sorted := enemy_ids.duplicate(); enemies_sorted.sort()
	if player_first:
		sim.order.append("player"); for id in enemies_sorted: sim.order.append(id)
	else:
		for id in enemies_sorted: sim.order.append(id)
		sim.order.append("player")
	sim.initiative = {"player": p_roll, "enemies": e_roll}
	for id in sim.combatants:
		if sim.c(id).surprised:
			sim.c(id).sheet.conditions.append("surpreendido")
	# companheiros (Arton Viva, Fase 6): IAs do lado do jogador, guiadas pelas ordens; logo depois do jogador na vez
	var usados: Array = [sim.c("player").tile]
	for id in enemy_ids:
		usados.append(sim.c(id).tile)
	var companheiros := _companheiros_em_luta()
	for c in companheiros:
		var t := _tile_livre_perto(sim.c("player").tile, usados)
		usados.append(t)
		sim.combatants[c.id] = {"id": c.id, "side": "player", "order": c.order, "tile": t, "sheet": c.sheet,
			"charge_turn": -99, "damaged_round": -1, "surprised": false, "flags": []}
		var pos := sim.order.find("player")
		sim.order.insert(pos + 1, c.id)
	var roster := {}
	for id in sim.combatants:
		var x: Dictionary = sim.c(id)
		roster[id] = {"name": x.sheet.name, "side": x.side, "tile": [x.tile.x, x.tile.y], "pv": x.sheet.pv, "pv_max": x.sheet.pv_max}
	var out: Array = pre + [fact("COMBAT_STARTED", {"roster": roster, "initiative": sim.initiative, "order": sim.order.duplicate(),
		"enemies_surprised": enemies_surprised, "faction": enemy_faction, "location": world.db.location_at(world.db.world_to_tile(world.player.position))}, ["player"])]
	out.append_array(_run_until_player())
	return out


## Processa turnos até ser a vez do jogador (ou o combate acabar).
func _run_until_player() -> Array:
	var out: Array = []
	for guard in 200:
		if not active:
			return out
		var id := sim.current_id()
		var start := _begin_turn(id)
		out.append_array(start.facts)
		var end := _check_end()
		if not end.is_empty():
			out.append_array(end)
			return out
		if not start.skip:
			if id == "player":
				return out
			out.append_array(_ai_turn(id))
			end = _check_end()
			if not end.is_empty():
				out.append_array(end)
				return out
		_zonas_fim_de_turno(id, out)
		out.append(fact("TURN_ENDED", {"actor": id}))
		sim.next_turn()
	push_warning("Combate: limite de iterações atingido")
	return out


## Raio da Aura Sagrada: 9m (LB p.84), com 1 quadrado = 1,5m.
const RAIO_AURA_QUADRADOS := 6


## Recalcula os efeitos de Aura Sagrada (resistência) e Égide Sagrada (Defesa) conforme as posições atuais:
## cada paladino ativo dá o próprio Carisma aos aliados do mesmo lado que estão no alcance e consciências.
func _refresh_bencaos() -> void:
	for id in sim.combatants:
		var sh: CharacterSheet = sim.c(id).sheet
		sh.remove_efeito("aura_sagrada")
		sh.remove_efeito("egide_sagrada")
		sh.remove_efeito("manto_do_cruzado")
	for h in sim.combatants:
		var hx: Dictionary = sim.c(h)
		var hs: CharacterSheet = hx.sheet
		if hs.manto_cruzado == "luz" and sim.conscious(h):
			hs.add_efeito("manto_do_cruzado", "imune", 1, "cena", "trevas")   # Manto de Luz: imunidade a dano de trevas
		if not (hs.aura_sagrada_ativa or hs.egide_ativa) or not sim.conscious(h):
			continue
		var car := hs.carisma()
		for a in sim.combatants:
			var ax: Dictionary = sim.c(a)
			if ax.side != hx.side or not sim.conscious(a):
				continue
			var d := CombatSim.cheb(hx.tile, ax.tile)
			if hs.aura_sagrada_ativa and d <= RAIO_AURA_QUADRADOS:
				ax.sheet.add_efeito("aura_sagrada", "resistencia", car, "cena")
			if hs.egide_ativa and d <= 1:
				ax.sheet.add_efeito("egide_sagrada", "defesa", car, "cena")


## Quadrado livre e transitável mais perto de `centro`, pela própria simulação (vale no planejamento também).
func _tile_livre_na_sim(centro: Vector2i, usados: Array) -> Vector2i:
	for raio in range(1, 5):
		for dx in range(-raio, raio + 1):
			for dy in range(-raio, raio + 1):
				if maxi(absi(dx), absi(dy)) != raio:
					continue
				var t := centro + Vector2i(dx, dy)
				if not usados.has(t) and sim.walk_fn.call(t):
					return t
	return centro


## Invocação (Servo Divino, Guardião Divino...): cria uma criatura do bestiário do mesmo lado do conjurador,
## logo depois dele na ordem. Dura `rodadas` rodadas (-1 = até o fim do combate); ao acabar, sai da simulação.
func invocar(caster: String, rule_id: String, rodadas: int, fonte: String) -> String:
	var cx: Dictionary = sim.c(caster)
	var usados: Array = []
	for id in sim.combatants:
		usados.append(sim.c(id).tile)
	var nova := "inv_%s_%d" % [fonte, sim.combatants.size()]
	var sh := CharacterSheet.from_creature(sim.rules, rule_id, nova)
	sim.combatants[nova] = {"id": nova, "side": cx.side, "order": "", "tile": _tile_livre_na_sim(cx.tile, usados), "sheet": sh,
		"charge_turn": -99, "damaged_round": -1, "surprised": false, "flags": []}
	sim.order.insert(sim.order.find(caster) + 1, nova)
	if rodadas != 0:
		sim.add_marca(nova, nova, fonte, "invocacao", rodadas)
	return nova


## Zonas e marcas no início do turno da criatura afetada (docs/MAGIA_COMPLEXA.md). Dano e cura por dados.
## Zona: quem está dentro dela, conforme "afeta" (todos | inimigos | aliados) em relação ao "lado" do conjurador.
func _zonas_e_marcas_inicio_de_turno(id: String, facts: Array) -> void:
	var x: Dictionary = sim.c(id)
	if not sim.conscious(id):
		return
	for z in sim.zonas.duplicate(true):
		var dados: Dictionary = z.get("dados", {})
		if not (z.tiles as Array).has(x.tile) or not dados.has("dano_inicio_turno") or not _zona_afeta(z, id):
			continue
		_efeito_magico_no_turno(id, str(dados.dano_inicio_turno), str(dados.get("conjurador", id)), str(z.fonte), facts)
	for m in sim.marcas.duplicate(true):
		if m.alvo != id or not sim.conscious(id):
			continue
		var dados_m: Dictionary = m.get("dados", {})
		var conj: String = str(dados_m.get("conjurador", id))
		if dados_m.has("dano_inicio_turno"):
			_efeito_magico_no_turno(id, str(dados_m.dano_inicio_turno), conj, str(m.fonte), facts)
		if dados_m.has("cura_inicio_turno") and sim.conscious(id):
			var s: CharacterSheet = x.sheet
			var cura := int(Dice.roll(str(dados_m.cura_inicio_turno), world.rng, "combat").total)
			s.pv = mini(s.pv_max, s.pv + cura)
			facts.append(fact("HEALED", {"actor": conj, "target": id, "amount": cura, "pv_after": s.pv, "source": str(m.fonte), "tags": ["magia", "cura"]}, [conj, id]))


func _zona_afeta(z: Dictionary, id: String) -> bool:
	var dados: Dictionary = z.get("dados", {})
	var afeta := str(dados.get("afeta", "todos"))
	if afeta == "todos":
		return true
	var lado := str(dados.get("lado", ""))
	if afeta == "inimigos":
		return sim.c(id).side != lado
	return sim.c(id).side == lado


## Fim de turno: zonas com efeito "fim_turno" (Círculo da Restauração). Criaturas vivas recuperam PV e até 1 PM
## (máximo 5 PM por dia com a magia); mortos-vivos e criaturas vulneráveis à luz perdem a mesma quantidade.
func _zonas_fim_de_turno(id: String, facts: Array) -> void:
	var x: Dictionary = sim.c(id)
	var s: CharacterSheet = x.sheet
	if s.is_dead():
		return
	for z in sim.zonas.duplicate(true):
		var dados: Dictionary = z.get("dados", {})
		if not dados.has("fim_turno") or not (z.tiles as Array).has(x.tile) or not _zona_afeta(z, id):
			continue
		var conj := str(dados.get("conjurador", id))
		var n := int(Dice.roll(str(dados.fim_turno), world.rng, "combat").total)
		if _sofre_luz(s):
			s.pm -= mini(s.pm, n)
			var tags_f: Array = ["magia", "luz"]
			tags_f.append_array(sim.apply_damage(id, n))
			facts.append(fact("ATTACK_RESOLVED", {"attacker": conj, "target": id, "weapon": str(z.fonte), "d20": 0, "mod": 0,
				"mods": [], "total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": n, "rolls": [],
				"pv_after": s.pv, "special": false, "ranged": false, "spell": true, "save": "", "saved": false, "tags": tags_f}, [conj, id]))
		else:
			s.pv = mini(s.pv_max, s.pv + n)
			facts.append(fact("HEALED", {"actor": conj, "target": id, "amount": n, "pv_after": s.pv, "source": str(z.fonte), "tags": ["magia", "cura"]}, [conj, id]))
			var usados := s.efeito_bonus("usos_circulo_restauracao")
			if usados < 5:
				s.pm = mini(s.pm_max, s.pm + 1)
				s.add_efeito("circulo_restauracao", "usos_circulo_restauracao", usados + 1, "dia")


## Criatura que sofre dano por luz: mortos-vivos e criaturas com vulnerabilidade à luz (tabela da raça).
func _sofre_luz(s: CharacterSheet) -> bool:
	return s.creature_type == "morto-vivo" or int(s.vuln.get("luz", 0)) > 0


## Dano mágico por dados (zona ou marca): aplica e registra no mesmo formato de um ataque de magia.
func _efeito_magico_no_turno(id: String, dados: String, conj: String, origem: String, facts: Array) -> void:
	var dano := int(Dice.roll(dados, world.rng, "combat").total)
	var tags: Array = ["magia"]
	tags.append_array(sim.apply_damage(id, dano))
	facts.append(fact("ATTACK_RESOLVED", {"attacker": conj, "target": id, "weapon": origem, "d20": 0, "mod": 0,
		"mods": [], "total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [],
		"pv_after": sim.c(id).sheet.pv, "special": false, "ranged": false, "spell": true, "save": "", "saved": false, "tags": tags}, [conj, id]))


## Criaturas não mortas cujo quadrado está em `tiles` (caídas também: áreas de dano as atingem).
func _criaturas_vivas_em(tiles: Array) -> Array:
	var out: Array = []
	for id in sim.combatants:
		if tiles.has(sim.c(id).tile) and not sim.c(id).sheet.is_dead():
			out.append(id)
	return out


## Aliados do conjurador (exceto ele) não mortos em `tiles`.
func _aliados_vivos_em(caster: String, tiles: Array) -> Array:
	var out: Array = []
	for id in sim.combatants:
		if id == caster:
			continue
		var X: Dictionary = sim.c(id)
		if X.side == sim.c(caster).side and tiles.has(X.tile) and not X.sheet.is_dead():
			out.append(id)
	return out


## Condição que o Sopro remove: a pedida, se ela estiver na lista e na criatura; senão a primeira da lista presente.
func _condicao_do_sopro(ts: CharacterSheet, pedida: String) -> String:
	if pedida != "" and SpellRules.SOPRO_CONDICOES.has(pedida) and ts.conditions.has(pedida):
		return pedida
	for c in SpellRules.SOPRO_CONDICOES:
		if ts.conditions.has(c):
			return c
	return ""


## Dano por tipo: imunidade zera; redução de dano por tipo (magia e raça) é descontada.
func _dano_por_tipo(ts: CharacterSheet, tipo: String, dano: int) -> int:
	if ts.efeito_bonus("imune", tipo) > 0:
		return 0
	return maxi(0, dano - ts.efeito_rd(tipo) - int(ts.dr.get(tipo, 0)))


## Manto do Cruzado no início de cada turno do conjurador (LB p.84 do 4º círculo, ver catálogo).
## Luz: 2d8 PV a você e aliados em alcance curto. Trevas: 4d8 de dano de trevas a inimigos em alcance curto;
## o conjurador cura metade do dano causado.
func _manto_inicio_de_turno(id: String, facts: Array) -> void:
	var x: Dictionary = sim.c(id)
	var s: CharacterSheet = x.sheet
	if s.manto_cruzado == "" or not sim.conscious(id):
		return
	var curto := int(world.rules.value("alcance.quadrados", {}).get("curto", 6))
	if s.manto_cruzado == "luz":
		for a in sim.combatants:
			var ax: Dictionary = sim.c(a)
			if ax.side != x.side or not sim.conscious(a) or CombatSim.cheb(x.tile, ax.tile) > curto:
				continue
			var cura := int(Dice.roll("2d8", world.rng, "combat").total)
			ax.sheet.pv = mini(ax.sheet.pv_max, ax.sheet.pv + cura)
			facts.append(fact("HEALED", {"actor": id, "target": a, "amount": cura, "pv_after": ax.sheet.pv, "source": "manto_do_cruzado", "tags": ["magia", "cura"]}, [id, a]))
		return
	var total := 0
	for a in sim.combatants:
		var ax: Dictionary = sim.c(a)
		if not sim.is_enemy(id, a) or not sim.conscious(a) or CombatSim.cheb(x.tile, ax.tile) > curto:
			continue
		var dano := int(Dice.roll("4d8", world.rng, "combat").total)
		total += dano
		var tags_t: Array = ["magia", "trevas"]
		tags_t.append_array(sim.apply_damage(a, dano))
		facts.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": a, "weapon": "Manto do Cruzado (trevas)", "d20": 0, "mod": 0,
			"mods": [], "total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [],
			"pv_after": ax.sheet.pv, "special": false, "ranged": false, "spell": true, "save": "", "saved": false, "tags": tags_t}, [id, a]))
	if total > 0:
		s.pv = mini(s.pv_max, s.pv + total / 2)
		facts.append(fact("HEALED", {"actor": id, "target": id, "amount": total / 2, "pv_after": s.pv, "source": "manto_do_cruzado", "tags": ["magia", "cura"]}, [id]))


func _begin_turn(id: String) -> Dictionary:
	_refresh_bencaos()
	var x := sim.c(id)
	var s: CharacterSheet = x.sheet
	var facts: Array = []
	s.limpar_efeitos("turno")   # efeitos "até o próximo turno" acabam quando a criatura age de novo
	s.limpar_efeitos("rodada")
	_manto_inicio_de_turno(id, facts)
	_zonas_e_marcas_inicio_de_turno(id, facts)
	if x.flags.has("fora") or s.is_dead():
		return {"skip": true, "facts": facts}
	if x.surprised:
		x.surprised = false
		s.remove_condition("surpreendido")
		facts.append(fact("TURN_SKIPPED", {"actor": id, "reason": "surpreendido"}))
		return {"skip": true, "facts": facts}
	if s.is_down():
		if not s.stable:
			# LB p.236: teste de Constituição CD 15 no início do turno.
			var r := Checks.attribute(s, "con", 15, world.rules, world.rng, "combat")
			var lost := 0
			if r.success:
				s.stable = true
			else:
				lost = int(Dice.roll("1d6", world.rng, "combat").total)
				sim.apply_damage(id, lost)
			facts.append(fact("BLEED_CHECK", {"actor": id, "check": r, "lost": lost, "pv": s.pv, "dead": s.is_dead(),
				"tags": ["morte"] if s.is_dead() else []}))
		return {"skip": true, "facts": facts}
	x.flags.erase("defensivo")   # Combate Defensivo vale "até seu próximo turno" (LB p.125)
	var extra_move := false
	if not x.flags.has("agiu"):
		x.flags.append("agiu")
		if s.has_power("reflexos_combate"):
			sim.budget.move += 1   # Reflexos de Combate (LB p.129): movimento extra no primeiro turno
			extra_move = true
	facts.append(fact("TURN_STARTED", {"actor": id, "round": sim.round_no, "extra_move": extra_move}))
	return {"skip": false, "facts": facts}


func _execute_action(id: String, a: Dictionary, v: Dictionary) -> Array:
	sim.spend(v.kind)
	var out: Array = []
	match a.type:
		"move":
			var path := GhostPlanner._tiles(a.path)
			var from: Vector2i = sim.c(id).tile
			var reactors := _reflex_watchers(id, from)
			sim.c(id).tile = v.end
			out.append(fact("COMBAT_MOVED", {"actor": id, "from": [from.x, from.y], "path": path.map(func(t): return [t.x, t.y])}, [id]))
			for r_id in reactors:
				if CombatSim.cheb(sim.c(r_id).tile, v.end) > 1:
					out.append_array(_reflex_attack(r_id, id, from))
		"charge":
			var path := GhostPlanner._tiles(a.path)
			var from: Vector2i = sim.c(id).tile
			sim.c(id).tile = v.end
			sim.c(id).charge_turn = sim.turn_counter
			out.append(fact("COMBAT_MOVED", {"actor": id, "from": [from.x, from.y], "path": path.map(func(t): return [t.x, t.y]), "charge": true}, [id]))
			_cur_action = a
			out.append_array(_resolve_attack(id, a.target, v, false))
			_cur_action = {}
		"attack":
			var special: bool = a.get("special", false)
			if special:
				sim.c(id).sheet.pm -= sim.special_tier(sim.c(id).sheet)
			var golpe_n := int(v.get("golpe_dados", 0))
			if golpe_n > 0:
				sim.c(id).sheet.pm -= 1 + golpe_n   # Golpe Divino: 2 PM + 1 PM por dado extra
			(sim.c(id).flags as Array).append("agrediu_%d" % sim.round_no)
			_cur_action = a
			var was_up: bool = not sim.c(a.target).sheet.is_down()
			out.append_array(_resolve_attack(id, a.target, v, special))
			_cur_action = {}
			if was_up and sim.c(a.target).sheet.is_down() and not bool(v.get("ranged", false)):
				out.append_array(_cleave(id, a.target, int(a.get("attack", 0))))
		"stand":
			sim.c(id).sheet.remove_condition("caido")
			out.append(fact("STOOD_UP", {"actor": id}, [id]))
		"ataque_extra":
			# Ataque Extra (LB p.66): 2 PM, ataque adicional depois de agredir, 1/rodada
			sim.c(id).sheet.pm -= int(world.rules.value("classe.guerreiro.ataque_extra").custo_pm)
			(sim.c(id).flags as Array).append("ataque_extra_%d" % sim.round_no)
			out.append(fact("POWER_USED", {"actor": id, "power": "ataque_extra", "pm_cost": 2, "pm_after": sim.c(id).sheet.pm}, [id]))
			_cur_action = a
			out.append_array(_resolve_attack(id, a.target, v, false))
			_cur_action = {}
		"impeto", "velocidade_ladina", "emboscar":
			GhostPlanner.apply_power_action(sim, id, a.type, v)
			out.append(fact("POWER_USED", {"actor": id, "power": a.type, "pm_cost": v.cost, "pm_after": sim.c(id).sheet.pm}, [id]))
		"coup":
			out.append_array(_coup(id, a.target))
		"cast":
			out.append_array(_cast(id, a, v))
		"olhar_atordoante":
			var sh_o: CharacterSheet = sim.c(id).sheet
			sh_o.pm -= 1
			sh_o.olhar_usado = true
			# Bestiário (medusa): Fort CD 19 evita; falhou, fica atordoada por 1 rodada (sem ações)
			var alvo: CharacterSheet = sim.c(a.target).sheet
			_reacao_protecao(id, a.target, out)
			var res := Checks.skill(alvo, "fortitude", 19, world.rules, world.rng, "combat")
			if res.get("success", false):
				out.append(fact("OLHAR_RESISTIDO", {"actor": id, "target": a.target, "tags": ["racial"]}, [id]))
			else:
				alvo.add_condition("atordoado", world.rules)
				out.append(fact("CONDITION_APPLIED", {"actor": id, "target": a.target, "condition": "atordoado", "tags": ["racial"]}, [id]))
		"cura_maos":
			# Cura pelas Mãos (LB p.82): 1d8+1 de PV por passo (+1d8+1 a cada passo extra); contra morto-vivo
			# causa dano de luz, com Vontade (CD = 10 + Carisma) reduzindo à metade.
			var sh_m: CharacterSheet = sim.c(id).sheet
			sh_m.pm -= int(v.cost)
			var alvo_m: String = a.get("target", id)
			var ts_m: CharacterSheet = sim.c(alvo_m).sheet
			var dados_m := 1 + int(v.get("passos", 0))
			if ts_m.creature_type == "morto-vivo":
				var sv_m := Checks.skill(ts_m, "vontade", 10 + int(sh_m.attrs["car"]), world.rules, world.rng, "combat")
				var dano_m := int(Dice.roll("%dd8+%d" % [dados_m, dados_m], world.rng, "combat").total)
				if sv_m.get("success", false):
					dano_m = maxi(1, dano_m / 2)
				out.append_array(sim.apply_damage(alvo_m, dano_m))
				out.append(fact("POWER_USED", {"actor": id, "power": "cura_pelas_maos", "target": alvo_m, "damage": dano_m, "pm_cost": v.cost, "pm_after": sh_m.pm}, [id, alvo_m]))
			else:
				var cura_m := int(Dice.roll("%dd8+%d" % [dados_m, dados_m], world.rng, "combat").total)
				ts_m.pv = mini(ts_m.pv_max, ts_m.pv + cura_m)
				if v.get("remover", false):
					for cond in ["abalado", "apavorado", "atordoado", "cego", "doente", "exausto", "fatigado", "surdo"]:
						if ts_m.conditions.has(cond):
							ts_m.remove_condition(cond)
							break
				out.append(fact("HEALED", {"actor": id, "target": alvo_m, "amount": cura_m, "pv_after": ts_m.pv, "source": "cura_pelas_maos", "tags": ["classe", "cura"]}, [id, alvo_m]))
				out.append(fact("POWER_USED", {"actor": id, "power": "cura_pelas_maos", "target": alvo_m, "pm_cost": v.cost, "pm_after": sh_m.pm}, [id]))
		"aura_sagrada":
			var sh_p: CharacterSheet = sim.c(id).sheet
			if v.ligar:
				sh_p.pm -= int(v.cost)
			sh_p.aura_sagrada_ativa = bool(v.ligar)
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "aura_sagrada", "ligada": sh_p.aura_sagrada_ativa, "pm_after": sh_p.pm, "tags": ["classe"]}, [id]))
			_refresh_bencaos()
		"egide":
			var sh_e: CharacterSheet = sim.c(id).sheet
			sh_e.pm -= int(v.cost)
			sh_e.egide_ativa = true
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "egide_sagrada", "pm_after": sh_e.pm, "tags": ["classe"]}, [id]))
			_refresh_bencaos()
		"allihanna":
			var sh_a: CharacterSheet = sim.c(id).sheet
			sh_a.pm -= 1
			sh_a.allihanna_ativa = true
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "armadura_de_allihanna", "defense": sh_a.allihanna_defense(true), "pm_after": sh_a.pm, "tags": ["racial"]}, [id]))
		"drink":
			var heal := Dice.roll(str(world.rules.value("magia.curar_ferimentos").cura), world.rng, "combat")
			var sh: CharacterSheet = sim.c(id).sheet
			sh.pv = mini(sh.pv_max, sh.pv + int(heal.total))
			out.append(fact("ITEM_LOST", {"item": a.item}, [id]))
			out.append(fact("HEALED", {"actor": id, "target": id, "amount": heal.total, "pv_after": sh.pv, "source": a.item, "tags": ["cura"]}, [id]))
	return out


## CD de resistência das magias (LB p.173) + Magia Pungente (+2, LB p.38).
func spell_dc(sh: CharacterSheet, a: Dictionary) -> int:
	var cd := 10 + sh.level / 2 + int(sh.attrs.get(sh.caster_attr, 0))
	if a.get("pungente", false) and sh.has_power("magia_pungente"):
		cd += int(world.rules.value("poder.magia_pungente").cd_bonus)
	return cd


## Arcano de Batalha (LB p.38): soma o atributo-chave na rolagem de dano da magia.
static func battle_bonus(sh: CharacterSheet) -> int:
	return maxi(0, int(sh.attrs.get(sh.caster_attr, 0))) if sh.has_power("arcano_de_batalha") else 0


## CD dos testes de lançar (C5). Retorna {} se não há teste; senão o payload da falha (ou {} se passou).
func casting_cd(sh: CharacterSheet, sp: Dictionary, cost: int) -> Dictionary:
	var conc: Dictionary = world.rules.value("magia.concentracao")
	var cd := 0
	var why := ""
	if sh.conditions.has("caido"):
		cd = int(conc.condicao_ruim.cd_base) + cost; why = "caído"
	elif world.modules.has("weather") and world.modules.weather.enabled and world.modules.weather.region.condition == "tempestade":
		cd = int(conc.condicao_ruim.cd_base) + cost; why = "tempestade"
	var arm := {}
	if str(sp.get("tipo", "")) == "arcana" and str(sh.equipment.get("armor", "")) != "":
		var ar: Dictionary = world.rules.value("magia.armadura_e_arcana")
		arm = {"skill": "misticismo", "cd": int(ar.cd_base) + cost, "mod": sh.armor_penalty(world.rules)}
	return {"concentration_cd": cd, "reason": why, "armor": arm}


func _casting_check(id: String, sh: CharacterSheet, sp: Dictionary, cost: int) -> Dictionary:
	var c := casting_cd(sh, sp, cost)
	if int(c.concentration_cd) > 0:
		var r := Checks.skill(sh, "vontade", int(c.concentration_cd), world.rules, world.rng, "combat")
		if not r.get("success", true):
			return {"caster": id, "check": "vontade", "cd": c.concentration_cd, "reason": c.reason, "d20": r.d20, "total": r.total}
	if not (c.armor as Dictionary).is_empty():
		var r2 := Checks.skill(sh, "misticismo", int(c.armor.cd), world.rules, world.rng, "combat", int(c.armor.mod))
		if not r2.get("allowed", true) or not r2.get("success", false):
			return {"caster": id, "check": "misticismo", "cd": c.armor.cd, "reason": "armadura", "d20": int(r2.get("d20", 0)), "total": int(r2.get("total", 0))}
	return {}


## Magia em combate (LB cap. 4): custo por círculo; Seta Infalível acerta sempre.
func _cast(id: String, a: Dictionary, v: Dictionary) -> Array:
	var sp: Dictionary = GhostPlanner.spell_rule(world.rules, str(a.spell))
	var sh: CharacterSheet = sim.c(id).sheet
	sh.pm -= int(v.cost)
	var out: Array = []
	# C5 — Concentração (LB p.170) e armadura (LB p.171): a falha perde a magia, mas os PM já foram gastos.
	var fail := _casting_check(id, sh, sp, int(v.cost))
	if not fail.is_empty():
		out.append(fact("SPELL_FAILED", fail, [id]))
		out.append(fact("SPELL_CAST", {"caster": id, "spell": a.spell, "pm_cost": v.cost, "pm_after": sh.pm, "failed": true}, [id]))
		return out
	match str(a.spell):
		"armadura_arcana":
			# +5 na Defesa pela cena; não acumula com o bônus de armadura (LB p.183)
			var arm: Dictionary = world.rules.value("armadura." + str(sh.equipment.get("armor", "")), {})
			sh.scene_defense = maxi(0, int(sp.defesa) - int(arm.get("defesa", 0)))
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "armadura_arcana", "defense": sh.scene_defense, "tags": ["magia"]}, [id]))
		"toque_chocante":
			var tgt: String = a.get("target", "")
			var T: CharacterSheet = sim.c(tgt).sheet
			var cd := spell_dc(sh, a)
			var metal := bool(world.rules.value("armadura." + str(T.equipment.get("armor", "")), {}).get("metal", false))
			_reacao_protecao(id, tgt, out)
			var sv := Checks.skill(T, "fortitude", cd, world.rules, world.rng, "combat", int(sp.penalidade_metal) if metal else 0)
			var r := Dice.roll(sp.dano, world.rng, "combat", 1, battle_bonus(sh))
			var dmg := int(r.total)
			if sv.get("success", false):
				dmg = maxi(1, dmg / 2)
			var tags: Array = ["magia", "impacto", "eletricidade"]
			if sv.get("success", false): tags.append("resistiu")
			tags.append_array(sim.apply_damage(tgt, dmg))
			out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tgt, "weapon": "Toque Chocante", "d20": int(sv.get("d20", 0)), "mod": int(sv.get("mod", 0)),
				"mods": [], "total": int(sv.get("total", 0)), "defense": cd, "camo_roll": 0, "hit": true, "crit": false, "damage": dmg, "rolls": r.rolls,
				"pv_after": T.pv, "special": false, "ranged": false, "spell": true, "save": "fortitude", "saved": sv.get("success", false), "tags": tags}, [id, tgt]))
		"raio_arcano":
			# Raio Arcano (LB p.39): 1d8 (+1d8 por círculo acima do 1º), alcance curto, Reflexos reduz à metade
			var tgt: String = a.get("target", (a.get("targets", [""]) as Array)[0])
			var T: CharacterSheet = sim.c(tgt).sheet
			var cd := spell_dc(sh, a)
			_reacao_protecao(id, tgt, out)
			var sv := Checks.skill(T, "reflexos", cd, world.rules, world.rng, "combat")
			var r := Dice.roll(GhostPlanner.raio_dice(sh), world.rng, "combat", 1, battle_bonus(sh))
			var dmg := int(r.total)
			if sv.get("success", false): dmg = maxi(1, dmg / 2)
			var tags: Array = ["magia", "impacto"]
			if sv.get("success", false): tags.append("resistiu")
			tags.append_array(sim.apply_damage(tgt, dmg))
			out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tgt, "weapon": "Raio Arcano", "d20": int(sv.get("d20", 0)), "mod": int(sv.get("mod", 0)),
				"mods": [], "total": int(sv.get("total", 0)), "defense": cd, "camo_roll": 0, "hit": true, "crit": false, "damage": dmg, "rolls": r.rolls,
				"pv_after": T.pv, "special": false, "ranged": true, "spell": true, "save": "reflexos", "saved": sv.get("success", false), "tags": tags}, [id, tgt]))
		"seta_infalivel":
			var targets: Array = a.get("targets", [a.get("target", "")])
			for i in int(sp.setas):
				var tgt: String = targets[i % targets.size()]
				if not sim.c(tgt).is_empty() and not sim.c(tgt).sheet.is_dead():
					var r := Dice.roll(sp.dano_por_seta, world.rng, "combat", 1, battle_bonus(sh) if i == 0 else 0)
					var tags: Array = ["magia", "impacto"]
					tags.append_array(sim.apply_damage(tgt, int(r.total)))
					out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tgt, "weapon": "Seta Infalível", "d20": 0, "mod": 0, "mods": [],
						"total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": r.total, "rolls": r.rolls,
						"pv_after": sim.c(tgt).sheet.pv, "special": false, "ranged": true, "spell": true, "tags": tags}, [id, tgt]))
		"perdicao":
			# Perdição (divina 1): alvos inimigos recebem penalidade em ataques e dano pela cena.
			var pen: int = SpellRules.penalidade_perdicao(sh, world.rules, a.get("aprimoramentos", []))
			for tg in a.get("targets", [a.get("target", id)]):
				var ts: CharacterSheet = sim.c(tg).sheet
				ts.add_efeito("magia.perdicao", "ataque", -pen, "cena")
				ts.add_efeito("magia.perdicao", "dano", -pen, "cena")
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg, "buff": "perdicao", "penalidade": -pen, "tags": ["magia"]}, [id, tg]))
		"infligir_ferimentos":
			# Infligir Ferimentos (divina 1): 2d8+2 de trevas (cura mortos-vivos); Fortitude reduz à metade.
			var apr: Array = a.get("aprimoramentos", [])
			var dc := spell_dc(sh, a)
			for tg in a.get("targets", [a.get("target", id)]):
				var ts: CharacterSheet = sim.c(tg).sheet
				var golpe_ok := true
				var golpe_dano := 0
				if apr.has(2):
					# Ataque corpo a corpo como parte da execução: se acertar, dano do ataque e a magia (sem resistência)
					var corp := ts.defense(world.rules, true)
					var arma: Dictionary = {}
					for at in sh.attacks:
						if not at.get("distancia", false):
							arma = at
							break
					golpe_ok = sh.skill_value("luta", world.rules) + world.rng.roll("combat", 1, 20)[0] >= corp
					if golpe_ok and not arma.is_empty():
						golpe_dano = int(Dice.roll(str(arma.dano), world.rng, "combat").total)
				if not golpe_ok:
					out.append(fact("SPELL_MISSED", {"caster": id, "target": tg, "spell": a.spell}, [id, tg]))
					continue
				var dado := Dice.roll("2d8+2", world.rng, "combat")
				var total := int(dado.total)
				if apr.has(1):
					total += int(Dice.roll("1d8+1", world.rng, "combat").total)
				var passou := false
				if not apr.has(2):
					_reacao_protecao(id, tg, out)
					var res := Checks.skill(ts, "fortitude", dc, world.rules, world.rng, "combat")
					passou = res.get("success", false)
				if ts.creature_type == "morto-vivo":
					ts.pv = mini(ts.pv_max, ts.pv + total)
					out.append(fact("HEALED", {"actor": id, "target": tg, "amount": total, "pv_after": ts.pv, "source": a.spell, "tags": ["magia", "cura"]}, [id, tg]))
					continue
				if passou:
					total /= 2
				var tags_d: Array = ["magia", "impacto"]
				tags_d.append_array(sim.apply_damage(tg, total + golpe_dano))
				out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": "Infligir Ferimentos", "d20": 0, "mod": 0, "mods": [],
					"total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": total + golpe_dano, "rolls": dado.rolls,
					"pv_after": ts.pv, "special": false, "ranged": false, "spell": true, "tags": tags_d}, [id, tg]))
				if apr.has(0) and not passou:
					ts.add_efeito("magia.infligir_ferimentos", "condicao", 0, "cena", "fraco")
					ts.add_condition("fraco", world.rules)
					out.append(fact("CONDITION_APPLIED", {"actor": id, "target": tg, "condition": "fraco", "tags": ["magia"]}, [id, tg]))
		"escudo_da_fe":
			# Escudo da Fé (divina 1), lançada no próprio turno (aprimoramento de execução padrão).
			for tg in a.get("targets", [a.get("target", id)]):
				_aplicar_escudo(id, tg, a.get("aprimoramentos", []), false, out)
		"protecao_divina":
			# Proteção Divina (divina 1): +2 em testes de resistência; aprimoramentos: +1, reação com +5 no próximo teste,
			# esfera de 3m e imunidade a efeitos de medo.
			var apr3: Array = a.get("aprimoramentos", [])
			var alvos3: Array = a.get("targets", [a.get("target", id)])
			if apr3.has(2):
				var centro: Vector2i = sim.c(alvos3[0]).tile
				alvos3 = []
				for other in sim.combatants:
					if not sim.is_enemy(id, other) and not sim.c(other).sheet.is_dead() and CombatSim.cheb(sim.c(other).tile, centro) <= 2:
						alvos3.append(other)
			for tg in alvos3:
				var ts3: CharacterSheet = sim.c(tg).sheet
				# (o aprimoramento 1 é de reação e não chega aqui: ver _reacao_protecao)
				ts3.add_efeito("magia.protecao_divina", "resistencia", 2 + (1 if apr3.has(0) else 0), "cena")
				if apr3.has(3):
					# +5 PM: imune a efeitos mentais e de medo (LB, Proteção Divina) — tipos da tabela de condições
					var tabela_cond: Dictionary = world.rules.value("condicoes", {})
					for cond in tabela_cond.keys():
						if not tabela_cond[cond] is Dictionary:
							continue   # "_regra" é texto, não condição
						var info_cond: Dictionary = tabela_cond[cond]
						if str(info_cond.get("tipo", "")) in ["medo", "mental"]:
							ts3.add_efeito("magia.protecao_divina", "imune", 1, "cena", str(cond))
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg, "buff": "protecao_divina", "tags": ["magia"]}, [id, tg]))
		"resistencia_a_energia":
			# Resistência a Energia (universal 1): redução de dano 10 contra um tipo de energia (aprimoramentos ajustam).
			var apr2: Array = a.get("aprimoramentos", [])
			var tipo := str(a.get("tipo_energia", "fogo"))
			var rd := 10 + (5 if apr2.has(0) else 0)
			var fim := "dia" if apr2.has(1) else "cena"
			var ate := world.day_index() + 1 if apr2.has(1) else -1
			for tg in a.get("targets", [a.get("target", id)]):
				var ts2: CharacterSheet = sim.c(tg).sheet
				if apr2.has(4):
					ts2.add_efeito("magia.resistencia_a_energia", "imune", 1, fim, tipo, ate)
				elif apr2.has(3):
					for t in SpellRules.TIPOS_ENERGIA:
						ts2.add_efeito("magia.resistencia_a_energia", "rd", rd, fim, t, ate)
				else:
					ts2.add_efeito("magia.resistencia_a_energia", "rd", rd, fim, tipo, ate)
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg, "buff": "resistencia_a_energia", "tipo": tipo, "tags": ["magia"]}, [id, tg]))
		"manto_do_cruzado":
			# Manto do Cruzado (4º círculo): sustentada até o fim do combate; a versão é a escolhida ao aprender.
			sh.manto_cruzado = sh.manto_versao
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "manto_do_cruzado", "versao": sh.manto_cruzado, "tags": ["magia"]}, [id]))
			_refresh_bencaos()
		"vestimenta_da_fe":
			# Vestimenta da Fé (LB p.216): +2 na Defesa por um dia (bônus de encanto). Aplicada ao alvo,
			# já que o jogo não tem itens encantados por instância. Aprimoramentos: +2 em resistências,
			# +1 no bônus e redução de dano 5 contra todos os tipos.
			var apr_v: Array = a.get("aprimoramentos", [])
			var ate_v := world.day_index() + 1
			for tg in a.get("targets", [a.get("target", id)]):
				var tsv: CharacterSheet = sim.c(tg).sheet
				tsv.add_efeito("magia.vestimenta_da_fe", "defesa", 2, "dia", "encanto", ate_v)
				if apr_v.has(0):
					tsv.add_efeito("magia.vestimenta_da_fe", "resistencia", 2, "dia", "encanto", ate_v)
				if apr_v.has(1):
					tsv.add_efeito("magia.vestimenta_da_fe", "defesa", 1, "dia", "encanto_extra", ate_v)
					if apr_v.has(0):
						tsv.add_efeito("magia.vestimenta_da_fe", "resistencia", 1, "dia", "encanto_extra", ate_v)
				if apr_v.has(2):
					tsv.add_efeito("magia.vestimenta_da_fe", "rd", 5, "dia", "*", ate_v)
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg, "buff": "vestimenta_da_fe", "tags": ["magia"]}, [id, tg]))
		"circulo_da_restauracao":
			# Círculo da Restauração (4º círculo): esfera de 3m no alvo por 5 rodadas. Ao fim do turno de cada criatura
			# dentro dele: 3d8+3 PV e 1 PM (4d8+4 PV com o aprimoramento). Mortos-vivos e criaturas vulneráveis à luz
			# perdem a mesma quantidade. Cada criatura recebe no máximo 5 PM por dia com esta magia.
			var apr_r: Array = a.get("aprimoramentos", [])
			var regen_r := "4d8+4" if apr_r.has(0) else "3d8+3"
			var alvo_r: String = a.get("target", id)
			sim.add_zona("circulo_restauracao_%d" % sim.zonas.size(), Area.esfera(sim.c(alvo_r).tile, Area.quadrados(3.0)), "circulo_restauracao", 5, "circulo_da_restauracao",
				{"fim_turno": regen_r, "conjurador": id, "afeta": "todos"})
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": alvo_r, "buff": "circulo_da_restauracao", "tags": ["magia"]}, [id, alvo_r]))
		"coluna_de_chamas":
			# Coluna de Chamas (3º círculo): cilindro de 3m de raio em volta do alvo; 6d6 de fogo e 6d6 de luz,
			# Reflexos reduz à metade. Aprimoramentos: +1d6 de fogo e +1d6 de luz (1 PM cada).
			var apr_cl: Array = a.get("aprimoramentos", [])
			var cd_cl := spell_dc(sh, a)
			for tg_cl in _criaturas_vivas_em(Area.esfera(sim.c(a.get("target", id)).tile, Area.quadrados(3.0))):
				var ts_cl: CharacterSheet = sim.c(tg_cl).sheet
				var fogo := int(Dice.roll("6d6", world.rng, "combat").total)
				if apr_cl.has(0):
					fogo += int(Dice.roll("1d6", world.rng, "combat").total)
				var luz := int(Dice.roll("6d6", world.rng, "combat").total)
				if apr_cl.has(1):
					luz += int(Dice.roll("1d6", world.rng, "combat").total)
				var dano_cl := _dano_por_tipo(ts_cl, "fogo", fogo) + _dano_por_tipo(ts_cl, "luz", luz)
				var sv_cl := Checks.skill(ts_cl, "reflexos", cd_cl, world.rules, world.rng, "combat")
				if sv_cl.get("success", false):
					dano_cl = dano_cl / 2
				var tags_cl: Array = ["magia", "fogo", "luz"]
				if sv_cl.get("success", false):
					tags_cl.append("resistiu")
				tags_cl.append_array(sim.apply_damage(tg_cl, dano_cl))
				out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg_cl, "weapon": "Coluna de Chamas", "d20": 0, "mod": 0,
					"mods": [], "total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": dano_cl, "rolls": [],
					"pv_after": ts_cl.pv, "special": false, "ranged": true, "spell": true, "save": "reflexos", "saved": sv_cl.get("success", false), "tags": tags_cl}, [id, tg_cl]))
		"sopro_da_salvacao":
			# Sopro da Salvação (3º círculo): cone de 9m orientado para o alvo; cura os aliados na área (não o conjurador).
			# 2d8+4 PV; aprimoramentos: +1d8+2 PV; PV negativos vão a 0 antes da cura; remove todas as condições listadas.
			var apr_s: Array = a.get("aprimoramentos", [])
			var origem_s: Vector2i = sim.c(id).tile
			var alvo_s: Vector2i = sim.c(a.get("target", id)).tile
			var cone_s: Array = Area.cone(origem_s, Vector2i(signi(alvo_s.x - origem_s.x), signi(alvo_s.y - origem_s.y)), Area.quadrados(9.0))
			for tg_s in _aliados_vivos_em(id, cone_s):
				var ts_s: CharacterSheet = sim.c(tg_s).sheet
				var cura_s := int(Dice.roll("2d8+4", world.rng, "combat").total)
				if apr_s.has(0):
					cura_s += int(Dice.roll("1d8+2", world.rng, "combat").total)
				if apr_s.has(1) and ts_s.pv < 0:
					ts_s.pv = 0
				ts_s.pv = mini(ts_s.pv_max, ts_s.pv + cura_s)
				if apr_s.has(2):
					for cond_s in SpellRules.SOPRO_CONDICOES:
						ts_s.remove_condition(cond_s)
				else:
					var escolha := _condicao_do_sopro(ts_s, str(a.get("condicao", "")))
					if escolha != "":
						ts_s.remove_condition(escolha)
				out.append(fact("HEALED", {"actor": id, "target": tg_s, "amount": cura_s, "pv_after": ts_s.pv, "source": "sopro_da_salvacao", "tags": ["magia", "cura"]}, [id, tg_s]))
		"curar_ferimentos":
			var apr_c: Array = a.get("aprimoramentos", [])
			for tgt in a.get("targets", [a.get("target", id)]):
				var ts: CharacterSheet = sim.c(tgt).sheet
				if ts.creature_type == "morto-vivo":
					# Truque (LB p.189): contra morto-vivo causa 1d8 de dano de luz; Vontade reduz à metade
					var cd_c := spell_dc(sh, a)
					var sv_c := Checks.skill(ts, "vontade", cd_c, world.rules, world.rng, "combat")
					var dano_c := int(Dice.roll("1d8", world.rng, "combat").total)
					if sv_c.get("success", false):
						dano_c = maxi(1, dano_c / 2)
					var tags_c: Array = ["magia", "luz"]
					if sv_c.get("success", false): tags_c.append("resistiu")
					tags_c.append_array(sim.apply_damage(tgt, dano_c))
					out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tgt, "weapon": "Curar Ferimentos (truque)", "d20": int(sv_c.get("d20", 0)), "mod": int(sv_c.get("mod", 0)),
						"mods": [], "total": int(sv_c.get("total", 0)), "defense": cd_c, "camo_roll": 0, "hit": true, "crit": false, "damage": dano_c, "rolls": [],
						"pv_after": ts.pv, "special": false, "ranged": false, "spell": true, "save": "vontade", "saved": sv_c.get("success", false), "tags": tags_c}, [id, tgt]))
					continue
				var cura_c := int(Dice.roll(str(sp.cura), world.rng, "combat").total)
				if apr_c.has(0):
					cura_c += int(Dice.roll("1d8+1", world.rng, "combat").total)
				ts.pv = mini(ts.pv_max, ts.pv + cura_c)
				ts.anular_magia("magia.infligir_ferimentos")   # Curar Ferimentos anula Infligir Ferimentos (LB p.189)
				if apr_c.has(1):
					for cans in ["exausto", "fatigado"]:   # uma condição de cansaço: a mais severa
						if ts.conditions.has(cans):
							ts.remove_condition(cans)
							break
				out.append(fact("HEALED", {"actor": id, "target": tgt, "amount": cura_c, "pv_after": ts.pv, "source": a.spell, "tags": ["magia", "cura"]}, [id, tgt]))
	if id == "player" and not stats.is_empty():
		stats.tactics["magia"] = true
		stats.pm_spent = int(stats.pm_spent) + int(v.cost)
		for f in out:
			if f.type == "ATTACK_RESOLVED": stats.dmg_dealt = int(stats.dmg_dealt) + int(f.payload.damage)
	out.append(fact("SPELL_CAST", {"caster": id, "spell": a.spell, "pm_cost": v.cost, "pm_after": sh.pm}, [id]))
	return out


## Aplica uma condição durante o combate e dispara o Ataque Reflexo se o alvo passar a ficar desprevenido (LB p.65).
func apply_condition(target: String, cond: String) -> Array:
	var T := sim.c(target)
	var was: bool = T.sheet.has_effective_condition(world.rules, "desprevenido")
	if not T.sheet.conditions.has(cond):
		T.sheet.conditions.append(cond)
	var out: Array = []
	if not was and T.sheet.has_effective_condition(world.rules, "desprevenido") and sim.conscious(target):
		for r_id in _reflex_watchers(target, T.tile):
			out.append_array(_reflex_attack(r_id, target, T.tile))
	return out


## Ataque Reflexo (LB p.65): quem tem o poder e está adjacente reage quando o alvo sai do alcance.
func _reflex_watchers(mover: String, from: Vector2i) -> Array:
	var out: Array = []
	for r_id in sim.combatants:
		var R := sim.c(r_id)
		if R.side == sim.c(mover).side or not sim.conscious(r_id) or not R.sheet.has_power("ataque_reflexo"):
			continue
		if R.sheet.pm < int(world.rules.value("poder.ataque_reflexo").custo_pm) or CombatSim.cheb(R.tile, from) != 1:
			continue
		if r_id == "player" and power_policy.get("ataque_reflexo", "auto") == "nunca":
			continue
		if (R.flags as Array).has("reflexo_%s_%d" % [mover, sim.round_no]):
			continue
		var melee := -1
		for i in R.sheet.attacks.size():
			if not R.sheet.attacks[i].get("distancia", false): melee = i; break
		if melee >= 0:
			out.append(r_id)
	return out


func _reflex_attack(r_id: String, target: String, at: Vector2i) -> Array:
	var R := sim.c(r_id)
	var T := sim.c(target)
	var now: Vector2i = T.tile
	T.tile = at   # o ataque acontece quando o alvo deixa o alcance
	var melee := 0
	for i in R.sheet.attacks.size():
		if not R.sheet.attacks[i].get("distancia", false): melee = i; break
	var v := sim.attack_profile(r_id, target, melee, false, false)
	var out: Array = []
	if v.get("ok", false):
		R.sheet.pm -= int(world.rules.value("poder.ataque_reflexo").custo_pm)
		(R.flags as Array).append("reflexo_%s_%d" % [target, sim.round_no])
		out.append(fact("REACTION", {"actor": r_id, "power": "ataque_reflexo", "target": target}, [r_id, target]))
		out.append_array(_resolve_attack(r_id, target, v, false))
	T.tile = now
	return out


func _nearest_walkable(t: Vector2i) -> Vector2i:
	for r in 6:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := t + Vector2i(dx, dy)
				if world.db.static_walkable(c):
					return c
	return t


func _raspao_wanted(attacker: String) -> bool:
	if attacker != "player":
		return true
	return bool(_cur_action.get("raspao", power_policy.get("golpe_raspao", "auto") == "auto"))


func _durao_wanted(target: String, dmg: int, sheet: CharacterSheet) -> bool:
	return _policy_wanted("durao", target, dmg, sheet)


func _policy_wanted(power: String, target: String, dmg: int, sheet: CharacterSheet) -> bool:
	var pol: String = power_policy.get(power, "fortes") if target == "player" else "fortes"
	match pol:
		"nunca": return false
		"sempre": return true
	return dmg >= maxi(4, sheet.pv_max / 4)


## Escudo da Fé (divina 1): +2 na Defesa (+1 com o 2º aprimoramento). Reação: dura 1 turno do alvo;
## execução padrão (aprimoramentos 0 e 3): dura a cena. 4º aprimoramento: um dia. Camuflagem (1º) e
## conexão que divide o dano (4º) também saem daqui.
func _aplicar_escudo(caster: String, tg: String, apr: Array, reacao: bool, out: Array) -> void:
	var ts: CharacterSheet = sim.c(tg).sheet
	var fim := "cena" if not reacao else "turno"
	var ate := -1
	if apr.has(4):
		fim = "dia"
		ate = world.day_index() + 1
	ts.add_efeito("magia.escudo_da_fe", "defesa", 3 if apr.has(2) else 2, fim, "", ate)
	if apr.has(1):
		ts.add_efeito("magia.escudo_da_fe", "camuflagem", 1, fim, "", ate)
	if apr.has(3):
		ts.add_efeito("magia.escudo_da_fe", "link", 1, "cena", caster, -1)
	out.append(fact("BUFF_APPLIED", {"actor": caster, "target": tg, "buff": "escudo_da_fe", "reacao": reacao, "tags": ["magia"]}, [caster, tg]))


## Reação do Escudo da Fé: quando um aliado é atacado, o jogador pode lançá-lo (1 PM, uma vez por rodada),
## por padrão automaticamente (política "escudo_da_fe"). Retorna a Defesa extra para esse ataque.
func _reacao_escudo(attacker: String, target: String, out: Array) -> int:
	if attacker == "player" or sim.is_enemy("player", target) or target == "player":
		return 0
	if str(power_policy.get("escudo_da_fe", "auto")) == "nunca":
		return 0
	var P := sim.c("player")
	if P.is_empty() or not P.sheet.spells.has("escudo_da_fe") or P.sheet.pm < 1:
		return 0
	if sim.c(target).sheet.has_efeito("magia.escudo_da_fe") or P.flags.has("escudo_%d" % sim.round_no):
		return 0
	if sim.c(target).sheet.is_dead() or CombatSim.cheb(P.tile, sim.c(target).tile) > int(world.rules.value("alcance.quadrados", {}).get("curto", 6)):
		return 0
	var apr: Array = []   # reação padrão: sem aprimoramentos (o jogador pode ligar pela tecla B no próprio turno)
	P.sheet.pm -= 1
	P.flags.append("escudo_%d" % sim.round_no)
	_aplicar_escudo("player", target, apr, true, out)
	return 2


## Proteção Divina com aprimoramento 1 (reação): quando um inimigo força um aliado a curto a fazer teste de
## resistência, o jogador reage e o aliado recebe +5 nesse teste (em vez do bônus normal). Automática pela
## política "protecao_divina"; uma vez por alvo por rodada.
func _reacao_protecao(atacante: String, alvo: String, out: Array) -> void:
	if alvo == "player" or not sim.is_enemy(atacante, alvo) or sim.is_enemy("player", alvo):
		return
	if str(power_policy.get("protecao_divina", "auto")) == "nunca":
		return
	var P := sim.c("player")
	if P.is_empty() or not P.sheet.spells.has("protecao_divina"):
		return
	var flag := "protecao_%d_%s" % [sim.round_no, alvo]
	if P.flags.has(flag) or sim.c(alvo).sheet.is_dead():
		return
	if CombatSim.cheb(P.tile, sim.c(alvo).tile) > int(world.rules.value("alcance.quadrados", {}).get("curto", 6)):
		return
	var sp := GhostPlanner.spell_rule(world.rules, "protecao_divina")
	var custo := GhostPlanner.spell_cost(world.rules, sp, {"spell": "protecao_divina", "aprimoramentos": [1]})
	if P.sheet.pm < custo:
		return
	P.sheet.pm -= custo
	P.flags.append(flag)
	sim.c(alvo).sheet.add_efeito("magia.protecao_divina", "proxima_resistencia", 5, "proxima_resistencia")
	out.append(fact("BUFF_APPLIED", {"actor": "player", "target": alvo, "buff": "protecao_divina", "tags": ["magia", "reacao"]}, ["player", alvo]))


func _resolve_attack(attacker: String, target: String, v: Dictionary, special: bool) -> Array:
	var A := sim.c(attacker)
	var T := sim.c(target)
	var atk: Dictionary = v.atk
	var pre: Array = []
	v.defense = int(v.defense) + _reacao_escudo(attacker, target, pre)   # reação de magia antes da rolagem
	var d20: int = world.rng.roll("combat", 1, 20)[0]
	var camo_roll := 0
	var camo_miss := false
	if int(v.miss_chance) > 0:
		camo_roll = world.rng.roll("combat", 1, 10)[0]
		camo_miss = camo_roll <= int(v.miss_chance) / 10
	var total := d20 + int(v.mod)
	var hit := total >= int(v.defense) and not camo_miss
	var crit := hit and d20 >= int(atk.margem)
	var dmg := 0
	var rolls: Array = []
	var tags: Array = ["ataque"]
	# Valentão (LB p.66): +2 ataque e dano contra caído/desprevenido/flanqueado/indefeso
	var bully: bool = v.mods.any(func(m): return m[0] == "valentão")
	if hit:
		var extra := int(A.sheet.attrs["for"]) if atk.get("for_no_dano", false) else 0
		if bully: extra += 2
		if v.mods.any(func(m): return m[0] == "ataque poderoso"): extra += 5   # Ataque Poderoso (LB p.124)
		extra += CombatSim.archer_bonus(A.sheet, bool(v.get("ranged", false)))   # Arqueiro (LB p.65)
		extra += A.sheet.efeito_bonus("dano")   # efeitos de magia (Bênção, Perdição)
		if A.sheet.has_power("especializacao_arma") and str(A.sheet.powers.especializacao_arma) == str(A.sheet.equipment.get("weapon", "")): extra += 2
		if not bool(v.get("ranged", false)):
			extra += ClassFeatures.furia_bonus(A.sheet)   # Fúria do bárbaro: +dano corpo a corpo
		extra += ClassFeatures.instinto_bonus(A.sheet)   # Instinto Selvagem: +dano em qualquer ataque
		if T.damaged_round == sim.round_no and Array(A.sheet.habilidades).any(func(h): return str(h).begins_with("oportunista")):
			extra += 2
		var r := Dice.roll(atk.dano, world.rng, "combat", int(atk.mult) if crit else 1, extra)
		dmg = maxi(1, int(r.total))
		var golpe_n := int(v.get("golpe_dados", 0))
		if golpe_n > 0:
			dmg += int(Dice.roll("%dd8" % golpe_n, world.rng, "combat", int(atk.mult) if crit else 1).total)   # Golpe Divino
		if not bool(v.get("ranged", false)) and A.sheet.manto_cruzado == "luz":
			dmg += int(Dice.roll("2d8", world.rng, "combat", int(atk.mult) if crit else 1).total)   # Manto do Cruzado (versão luz): +2d8 de luz
			tags.append("luz")
		rolls = r.rolls
		# Ataque Furtivo (LB p.73): 1/rodada, alvo desprevenido ou flanqueado; dados extras não multiplicam.
		var sa_key := "furtivo_%d" % sim.round_no
		if A.sheet.class_id == "ladino" and not A.flags.has(sa_key) and \
				(T.sheet.has_effective_condition(world.rules, "desprevenido") or (not v.ranged and sim.flanking(attacker, target))):
			var n_dice: int = 1 + (int(A.sheet.level) - 1) / 2
			var sa := Dice.roll("%dd6" % n_dice, world.rng, "combat")
			dmg += int(sa.total)
			rolls.append_array(sa.rolls)
			A.flags.append(sa_key)
			tags.append("furtivo")
		# Raças: redução de dano por tipo (Armadura Óssea, Resistência Elemental) e dano extra por dado (Ossos Frágeis)
		var dtype := str(atk.get("tipo", ""))
		if T.sheet.vuln.has(dtype):
			dmg += int(T.sheet.vuln[dtype]) * maxi(1, rolls.size())
		if T.sheet.dr.has(dtype):
			dmg = maxi(0, dmg - int(T.sheet.dr[dtype]))
			tags.append("reducao")
		if T.sheet.efeito_bonus("imune", dtype) > 0:
			dmg = 0   # imunidade a tipo de energia (Resistência a Energia, 4º aprimoramento)
		var rd_total: int = T.sheet.efeito_rd(dtype) + ClassFeatures.reducao_dano(T.sheet)   # magia + Redução de Dano do bárbaro (cumulativas, LB)
		if rd_total > 0:
			dmg = maxi(0, dmg - rd_total)
			tags.append("reducao")
		tags.append("impacto")
		if crit: tags.append("critico")
		# Durão (LB p.66, guerreiro 3º nível): 3 PM reduz o dano à metade — usado em golpes de 1/4 dos PV ou mais
		if T.sheet.has_power("durao") and T.sheet.pm >= 3 and _durao_wanted(target, dmg, T.sheet):
			T.sheet.pm -= 3
			dmg = maxi(1, dmg / 2)
			tags.append("durao")
		# Rolamento Defensivo (LB p.74): 2 PM reduz o dano à metade; depois o ladino fica caído
		if T.sheet.has_power("rolamento_defensivo") and T.sheet.pm >= 2 and _policy_wanted("rolamento_defensivo", target, dmg, T.sheet):
			T.sheet.pm -= 2
			dmg = maxi(1, dmg / 2)
			if not T.sheet.conditions.has("caido"): T.sheet.conditions.append("caido")
			tags.append("rolamento")
		tags.append_array(sim.apply_damage(target, dmg))
	else:
		tags.append("esquiva" if not camo_miss else "falha")
		# Golpe de Raspão (LB p.65): 1/rodada, 2 PM, metade do dano ao errar (automático se houver PM)
		var gr_key := "raspao_%d" % sim.round_no
		if A.sheet.has_power("golpe_raspao") and A.sheet.pm >= 2 and not A.flags.has(gr_key) and not camo_miss and _raspao_wanted(attacker):
			A.sheet.pm -= 2
			A.flags.append(gr_key)
			var extra2 := int(A.sheet.attrs["for"]) if atk.get("for_no_dano", false) else 0
			dmg = maxi(1, int(Dice.roll(atk.dano, world.rng, "combat", 1, extra2).total) / 2)
			tags.append("raspao")
			tags.append_array(sim.apply_damage(target, dmg))
	var out: Array = [fact("ATTACK_RESOLVED", {"attacker": attacker, "target": target, "weapon": atk.nome, "d20": d20, "mod": v.mod,
		"mods": v.mods, "total": total, "defense": v.defense, "camo_roll": camo_roll, "hit": hit, "crit": crit, "damage": dmg,
		"rolls": rolls, "pv_after": T.sheet.pv, "special": special, "ranged": v.ranged, "tags": tags}, [attacker, target])]
	if hit and attacker == "player" and T.side == "enemy":
		out.append(fact("LETHAL_DAMAGE_DEALT", {"attacker": "player", "target": target, "creature_type": world.rules.value(T.sheet.source_rule, {}).get("tipo", "")}, ["player"]))
	# Derrubar livre (Hiena, Bestiário p.120): manobra oposta x Luta do alvo (LB p.234)
	if hit and atk.has("derrubar") and not T.sheet.is_down() and not T.sheet.conditions.has("caido"):
		var mine: int = world.rng.roll("combat", 1, 20)[0] + int(atk.derrubar)
		var theirs: int = world.rng.roll("combat", 1, 20)[0] + T.sheet.skill_value("luta", world.rules)
		var ok := mine > theirs
		if ok:
			T.sheet.add_condition("caido", world.rules)
		out.append(fact("MANEUVER_RESOLVED", {"attacker": attacker, "target": target, "maneuver": "derrubar", "attacker_total": mine,
			"target_total": theirs, "success": ok, "tags": ["queda"] if ok else []}, [attacker, target]))
	if v.mods.any(func(m): return m[0] == "combate defensivo") and not A.flags.has("defensivo"):
		A.flags.append("defensivo")
	_track_attack(attacker, target, v, special, hit, crit, dmg, tags)
	log.append(out[0].payload)
	if log.size() > 60: log.pop_front()
	return pre + out


## Trespassar (LB p.129): derrubou o alvo com ataque corpo a corpo -> 1 PM por um ataque adicional
## contra outra criatura no alcance. Jogador segue a política; inimigos com o poder sempre usam.
func _cleave(id: String, fallen: String, atk_index: int) -> Array:
	var A := sim.c(id)
	if not A.sheet.has_power("trespassar") or A.sheet.pm < 1:
		return []
	if id == "player" and str(power_policy.get("trespassar", "auto")) == "nunca":
		return []
	for other in sim.combatants:
		if other == fallen or not sim.is_enemy(id, other) or not sim.conscious(other):
			continue
		var v2 := sim.attack_profile(id, other, atk_index, false, false)
		if not v2.get("ok", false):
			continue
		A.sheet.pm -= 1
		if id == "player": stats.pm_spent = int(stats.get("pm_spent", 0)) + 1
		var out: Array = [fact("POWER_USED", {"actor": id, "power": "trespassar", "target": other, "pm_cost": 1}, [id, other])]
		out.append_array(_resolve_attack(id, other, v2, false))
		return out
	return []


func _track_attack(attacker: String, target: String, v: Dictionary, special: bool, hit: bool, crit: bool, dmg: int, tags: Array) -> void:
	if stats.is_empty():
		return
	if attacker == "player":
		stats.dmg_dealt = int(stats.dmg_dealt) + dmg
		if crit: stats.crits = int(stats.crits) + 1
		for m in v.get("mods", []):
			if m[0] in ["flanqueando", "investida", "ataque especial"]:
				stats.tactics[m[0]] = true
		if tags.has("furtivo"): stats.tactics["ataque furtivo"] = true
		if special: stats.pm_spent = int(stats.pm_spent) + 1
		if int(v.get("golpe_dados", 0)) > 0: stats.pm_spent = int(stats.pm_spent) + 1 + int(v.golpe_dados)
		if int(v.get("miss_chance", 0)) > 0: stats.adverse["visibilidade"] = true
	elif target == "player":
		stats.dmg_taken = int(stats.dmg_taken) + dmg
		if sim.c("player").sheet.is_down(): stats.went_down = true
		if int(v.get("miss_chance", 0)) > 0: stats.adverse["visibilidade"] = true


func _coup(attacker: String, target: String) -> Array:
	var A := sim.c(attacker)
	var T := sim.c(target)
	var atk: Dictionary = A.sheet.attacks[0]
	var extra := int(A.sheet.attrs["for"]) if atk.get("for_no_dano", false) else 0
	var r := Dice.roll(atk.dano, world.rng, "combat", int(atk.mult), extra)
	var tags: Array = ["ataque", "impacto", "critico"]
	tags.append_array(sim.apply_damage(target, int(r.total)))
	var rule: Dictionary = world.rules.value("acao.golpe_misericordia")
	var d4: int = world.rng.roll("combat", 1, 4)[0]
	var dies := (d4 <= 1) if T.sheet.is_important else (d4 <= 3)
	if dies and not T.sheet.is_dead():
		T.sheet.pv = T.sheet.death_threshold()
		tags.append("morte")
	return [fact("COUP_DE_GRACE", {"attacker": attacker, "target": target, "damage": r.total, "d4": d4, "dies": dies or T.sheet.is_dead(),
		"rule": rule, "tags": tags}, [attacker, target])]


## IA simples e legível: aproxima e ataca; à distância se tiver arma e alcance.
func _ai_turn(id: String) -> Array:
	var out: Array = []
	var me := sim.c(id)
	var ordem := str(me.get("order", ""))
	# recuar (companheiro): ferido, afasta-se do inimigo mais próximo em vez de lutar
	if ordem == "recuar" and me.sheet.pv < me.sheet.pv_max / 2:
		return _recuar(id)
	var is_animal: bool = world.rules.value(me.sheet.source_rule, {}).get("tipo", "") == "animal"
	var target := ""
	var best := 999
	# proteger: escolhe o inimigo mais perto do jogador, não o mais perto de si
	var origem: Vector2i = sim.c("player").tile if ordem == "proteger" else me.tile
	for oid in sim.combatants:
		var o := sim.c(oid)
		if o.side == me.side or o.sheet.is_dead() or o.flags.has("fora"):
			continue
		if o.sheet.is_down() and not is_animal:
			continue  # bandidos não executam quem caiu (ORIGINAL_DO_JOGO: preferem capturar)
		var d := CombatSim.cheb(origem, o.tile)
		if d < best:
			best = d; target = oid
	if target == "":
		return out
	if me.sheet.conditions.has("caido"):
		out.append_array(_try(id, {"type": "stand"}))
	var melee := -1
	var ranged := -1
	for i in me.sheet.attacks.size():
		if me.sheet.attacks[i].get("distancia", false): ranged = i
		elif melee < 0: melee = i
	for step in 3:
		if not sim.conscious(id) or not sim.conscious(target) and not (is_animal and not sim.c(target).sheet.is_dead()):
			break
		var d := CombatSim.cheb(me.tile, sim.c(target).tile)
		if d == 1 and melee >= 0 and sim.can_spend("padrao"):
			var tgt_down: bool = sim.c(target).sheet.is_down()
			if tgt_down and sim.can_spend("completa"):
				out.append_array(_try(id, {"type": "coup", "target": target}))
			else:
				out.append_array(_try(id, {"type": "attack", "target": target, "attack": melee}))
			break
		if ranged >= 0 and d > 1 and d <= int(me.sheet.attacks[ranged].alcance_q) and sim.can_spend("padrao"):
			out.append_array(_try(id, {"type": "attack", "target": target, "attack": ranged}))
			break
		if not sim.can_spend("movimento"):
			break
		if ordem == "manter_posicao":
			break  # companheiro que mantém posição só ataca o que alcança daqui
		# C24: inimigo com Ímpeto usa o poder quando só assim alcança o alvo nesta rodada
		if me.sheet.has_power("impeto") and d - 1 > sim.speed_squares(id) and d - 1 <= sim.speed_squares(id) + 4:
			out.append_array(_try(id, {"type": "impeto"}))
		var path := sim.trim_path(id, sim.find_path(id, sim.c(target).tile), sim.speed_squares(id))
		if path.is_empty():
			break
		var r := _try(id, {"type": "move", "path": path.map(func(t): return [t.x, t.y])})
		if r.is_empty():
			break
		out.append_array(r)
	return out


## Recuo de companheiro: um passo para a casa vizinha mais longe do inimigo mais próximo.
func _recuar(id: String) -> Array:
	var me := sim.c(id)
	if not sim.can_spend("movimento"):
		return []
	var melhor: Vector2i = me.tile
	var melhor_d := _inimigo_mais_perto(me.tile, id)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var t: Vector2i = me.tile + Vector2i(dx, dy)
			if (dx == 0 and dy == 0) or not _sim_walkable(t) or sim.occupant(t, id) != "":
				continue
			var d := _inimigo_mais_perto(t, id)
			if d > melhor_d:
				melhor_d = d
				melhor = t
	if melhor == me.tile:
		return []
	return _try(id, {"type": "move", "path": [[melhor.x, melhor.y]]})


func _inimigo_mais_perto(t: Vector2i, id: String) -> int:
	var me := sim.c(id)
	var d := 99
	for oid in sim.combatants:
		var o := sim.c(oid)
		if o.side != me.side and not o.sheet.is_dead():
			d = mini(d, CombatSim.cheb(t, o.tile))
	return d


## Companheiros: fichas de combate montadas a partir do personagem (classe pela profissão), equipados.
func _companheiros_em_luta() -> Array:
	var party = world.module("party")
	if party == null:
		return []
	var busy := {}
	for c in party.contratos.values():
		for m in c.membros:
			busy[m] = true
	var out: Array = []
	var ids: Array = party.members.keys()
	ids.sort()
	for id in ids:
		# ocupado em contrato, ou ainda se recuperando de uma luta anterior, não entra
		if busy.has(id) or CharacterSheet.from_dict(party.members[id].sheet).pv <= 0:
			continue
		out.append({"id": id, "order": str(party.members[id].order), "sheet": CharacterSheet.from_dict(party.members[id].sheet)})
	return out


func _tile_livre_perto(centro: Vector2i, usados: Array) -> Vector2i:
	for raio in [1, 2, 3, 4]:
		for dx in range(-raio, raio + 1):
			for dy in range(-raio, raio + 1):
				if maxi(absi(dx), absi(dy)) != raio:
					continue
				var t := centro + Vector2i(dx, dy)
				if not usados.has(t) and _sim_walkable(t):
					return t
	return centro


func _try(id: String, a: Dictionary) -> Array:
	var v := GhostPlanner.validate_action(sim, id, a)
	if not v.ok:
		return []
	var out := _execute_action(id, a, v)
	_refresh_bencaos()
	return out


func _fled() -> bool:
	var p: Vector2i = sim.c("player").tile
	for id in sim.combatants:
		if sim.c(id).side == "enemy" and sim.conscious(id) and CombatSim.cheb(p, sim.c(id).tile) < FLEE_DISTANCE:
			return false
	return true


func _check_end() -> Array:
	if not active:
		return []
	var P := sim.c("player")
	if P.sheet.is_dead():
		return _end_combat("morte")
	var enemies_up := false
	var animals_up := false
	for id in sim.combatants:
		var x := sim.c(id)
		if x.side == "enemy" and sim.conscious(id):
			enemies_up = true
			if world.rules.value(x.sheet.source_rule, {}).get("tipo", "") == "animal":
				animals_up = true
	if not enemies_up:
		return _end_combat("vitoria")
	if P.sheet.is_down() and not animals_up:
		return _end_combat("captura")
	return []


func _end_combat(outcome: String) -> Array:
	var out: Array = []
	var loc := world.db.location_at(sim.c("player").tile)
	var P := sim.c("player")
	world.player_sheet = P.sheet
	world.player_sheet.remove_condition("surpreendido")
	world.player_sheet.scene_defense = 0   # magias de duração "cena" terminam com o combate
	world.player_sheet.limpar_efeitos("cena")
	world.player_sheet.limpar_efeitos("rodada")
	world.player_sheet.limpar_efeitos("turno")
	world.player_sheet.allihanna_ativa = false
	for id in sim.combatants:   # Aura Sagrada é sustentada até o fim do combate; Égide, até o fim da cena
		var sh_f: CharacterSheet = sim.c(id).sheet
		sh_f.aura_sagrada_ativa = false
		sh_f.egide_ativa = false
		sh_f.manto_cruzado = ""
		sh_f.pv_temp = 0
		sh_f.remove_efeito("manto_do_cruzado")
		sh_f.remove_efeito("aura_sagrada")
		sh_f.remove_efeito("egide_sagrada")
	world.player_sheet.olhar_usado = false
	world.player.position = world.db.tile_to_world(P.tile)
	for id in sim.combatants:
		if id == "player" or str(id).begins_with("inv_"):   # invocações não são criaturas do mundo nem companheiros
			continue
		var x := sim.c(id)
		if x.side == "player":
			# companheiro: não é criatura; se morreu, sai como NPC_DIED (a party reage)
			if x.sheet.is_dead():
				out.append(fact("NPC_DIED", {"npc": id, "cause": "combate"}, [id]))
			else:
				out.append(fact("COMPANION_STATE", {"npc": id, "sheet": x.sheet.to_dict()}, [id]))
			continue
		creature_state[id].sheet = x.sheet.to_dict()
		creature_state[id].tile = [x.tile.x, x.tile.y]
		if outcome == "vitoria" or x.sheet.is_dead():
			creature_state[id].alive = not x.sheet.is_dead()
			creature_state[id].present = false
			out.append(fact("CREATURE_DEFEATED", {"creature": id, "name": x.sheet.name, "by": "player", "actor": "player",
				"dead": x.sheet.is_dead(), "location": loc}, ["player"]))
			for it in world.db.creature_def(id).get("items", []):
				out.append(fact("ITEM_GAINED", {"item": it, "from": id, "location": loc}, ["player"]))
	match outcome:
		"captura":
			world.player_sheet.pv = 1
			world.player_sheet.stable = true
			out.append(fact("GOLD_CHANGED", {"delta": -int(world.player.gold), "reason": "roubado pelos captores"}))
			if enemy_faction == "garras_de_cinza":
				var cell := world.db.location_spot("cripta_cela")
				world.player.position = world.db.tile_to_world(cell + Vector2i(1, 1))
				out.append(fact("PLAYER_CAPTURED", {"by": enemy_faction, "location": "cripta_cela", "witnesses": []}, ["player"]))
			else:
				# salteadores (ORIGINAL): roubam e somem; o jogador acorda onde caiu
				out.append(fact("PLAYER_ROBBED", {"by": enemy_faction, "location": loc}, ["player"]))
				for id in sim.combatants:
					if sim.c(id).side == "enemy": creature_state[id].present = false
			for id in sim.combatants:
				if sim.c(id).side == "enemy" and sim.c(id).sheet.pv > 0:
					creature_state[id].tile = world.db.creature_def(id).spawn.duplicate()
		"morte":
			out.append(fact("PLAYER_DIED", {"location": loc, "round": sim.round_no}, ["player"]))
	var enemies: Array = sim.combatants.keys().filter(func(x): return sim.c(x).side == "enemy")
	stats.rounds = sim.round_no
	stats.pv_end = maxi(0, P.sheet.pv)
	stats.defeated = enemies.filter(func(x): return sim.c(x).sheet.is_down())
	out.append(fact("COMBAT_ENDED", {"outcome": outcome, "enemy_faction": enemy_faction, "rounds": sim.round_no, "location": loc, "enemies": enemies, "stats": stats.duplicate(true)}, ["player"]))
	active = false
	undetected_by.clear()
	approach_rolled.clear()
	return out


## Pré-visualização para a apresentação (não é comando: não muda estado).
func preview(actions: Array) -> Dictionary:
	if not active:
		return {"valid": false, "steps": []}
	return GhostPlanner.simulate(sim, "player", actions)


# --- Persistência -------------------------------------------------------------------
func to_dict() -> Dictionary:
	_ensure()
	var d := {"active": active, "creature_state": creature_state.duplicate(true), "stance_sneak": stance_sneak,
		"undetected_by": undetected_by.duplicate(), "approach_rolled": approach_rolled.duplicate(), "enemy_faction": enemy_faction,
		"power_policy": power_policy.duplicate()}
	if active:
		var cs := {}
		for id in sim.combatants:
			var x: Dictionary = sim.c(id)
			cs[id] = {"id": id, "side": x.side, "order": x.get("order", ""), "tile": [x.tile.x, x.tile.y], "sheet": x.sheet.to_dict(), "charge_turn": x.charge_turn,
				"damaged_round": x.damaged_round, "surprised": x.surprised, "flags": x.flags.duplicate()}
		d["sim"] = {"combatants": cs, "order": sim.order.duplicate(), "initiative": sim.initiative.duplicate(), "turn_idx": sim.turn_idx,
			"round_no": sim.round_no, "turn_counter": sim.turn_counter, "budget": sim.budget.duplicate(),
			"zonas": sim.zonas.duplicate(true), "marcas": sim.marcas.duplicate(true)}
	return d


func from_dict(d: Dictionary) -> void:
	creature_state = d.get("creature_state", {}).duplicate(true)
	for id in creature_state:
		creature_state[id].woken_until = int(creature_state[id].get("woken_until", -1))
	stance_sneak = bool(d.get("stance_sneak", false))
	undetected_by = d.get("undetected_by", {}).duplicate()
	approach_rolled = d.get("approach_rolled", {}).duplicate()
	enemy_faction = str(d.get("enemy_faction", ""))
	power_policy = DEFAULT_POLICY.duplicate()
	power_policy.merge(d.get("power_policy", {}), true)
	active = bool(d.get("active", false))
	if active and d.has("sim"):
		sim = _new_sim()
		var s: Dictionary = d.sim
		for id in s.combatants:
			var x: Dictionary = s.combatants[id]
			sim.combatants[id] = {"id": id, "side": x.side, "order": str(x.get("order", "")), "tile": Vector2i(int(x.tile[0]), int(x.tile[1])), "sheet": CharacterSheet.from_dict(x.sheet),
				"charge_turn": int(x.charge_turn), "damaged_round": int(x.damaged_round), "surprised": bool(x.surprised), "flags": x.flags.duplicate()}
		sim.order.clear()
		for id in s.order: sim.order.append(str(id))
		sim.initiative = s.initiative.duplicate()
		sim.turn_idx = int(s.turn_idx); sim.round_no = int(s.round_no); sim.turn_counter = int(s.turn_counter)
		sim.budget = {"std": int(s.budget.std), "move": int(s.budget.move)}
		sim.zonas = (s.get("zonas", []) as Array).duplicate(true)
		sim.marcas = (s.get("marcas", []) as Array).duplicate(true)
	else:
		active = false
