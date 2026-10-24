class_name CombatModule
extends WorldModule
## Combate tático híbrido (§9). Planejamento congelado no turno, fantasma sem
## efeitos reais, rolagens só na execução, log de eventos para a apresentação.

const DETECT_AWAKE := 6
const DETECT_ASLEEP := 3
const SIGNAL_RADIUS := 12
const FLEE_DISTANCE := 10

var active := false
var sim: CombatSim
var creature_state: Dictionary = {}  # id -> {alive, present, tile, sheet(dict), woken_until}
var stance_sneak := false
var undetected_by: Dictionary = {}   # creature_id -> true (furtividade bem-sucedida nesta aproximação)
var approach_rolled: Dictionary = {} # creature_id -> true (já rolou nesta aproximação)
var enemy_faction := ""
var stats: Dictionary = {}  # desempenho do combate atual (XP dinâmica, ORIGINAL_DO_JOGO)
var log: Array = []


func module_id() -> String: return "combat"
func handled_commands() -> PackedStringArray:
	return PackedStringArray(["StartCombat", "ExecutePlan", "EndTurn", "SetStance"])
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(["PLAYER_MOVED", "PLAYER_TELEPORTED", "OBJECT_DAMAGED", "BANDITS_RELOCATED", "CREATURE_DEFEATED", "PACK_GREW", "TRAVEL_AMBUSH"])


func _ensure() -> void:
	if not creature_state.is_empty():
		return
	for id in world.db.all_creature_ids():
		var d := world.db.creature_def(id)
		var sheet := CharacterSheet.from_creature(world.rules, d.rule, id)
		sheet.name = d.name
		sheet.faction = d.faction
		sheet.is_important = bool(d.get("important", false))
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
				var end := _check_end()
				if not end.is_empty():
					out.append_array(end)
					return out
				if a.type == "move" and _fled():
					out.append_array(_end_combat("fuga"))
					return out
			return out
		"EndTurn":
			var out: Array = [fact("TURN_ENDED", {"actor": "player"}, ["player"])]
			sim.next_turn()
			out.append_array(_run_until_player())
			return out
	return []


# --- Encontros ------------------------------------------------------------------
func on_event(e: GameEvent) -> Array:
	_ensure()
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
	var objs = world.module("objects")
	s.walk_fn = func(t: Vector2i) -> bool: return objs.walkable(t) if objs != null else world.db.static_walkable(t)
	var w = world.module("weather")
	s.env_fn = func(t: Vector2i) -> Dictionary: return w.env_at(t) if w != null else {}
	return s


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
		out.append(fact("TURN_ENDED", {"actor": id}))
		sim.next_turn()
	push_warning("Combate: limite de iterações atingido")
	return out


func _begin_turn(id: String) -> Dictionary:
	var x := sim.c(id)
	var s: CharacterSheet = x.sheet
	var facts: Array = []
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
			var r := Checks.attribute(s, "con", 15, world.rng, "combat")
			var lost := 0
			if r.success:
				s.stable = true
			else:
				lost = int(Dice.roll("1d6", world.rng, "combat").total)
				sim.apply_damage(id, lost)
			facts.append(fact("BLEED_CHECK", {"actor": id, "check": r, "lost": lost, "pv": s.pv, "dead": s.is_dead(),
				"tags": ["morte"] if s.is_dead() else []}))
		return {"skip": true, "facts": facts}
	facts.append(fact("TURN_STARTED", {"actor": id, "round": sim.round_no}))
	return {"skip": false, "facts": facts}


func _execute_action(id: String, a: Dictionary, v: Dictionary) -> Array:
	sim.spend(v.kind)
	var out: Array = []
	match a.type:
		"move":
			var path := GhostPlanner._tiles(a.path)
			var from: Vector2i = sim.c(id).tile
			sim.c(id).tile = v.end
			out.append(fact("COMBAT_MOVED", {"actor": id, "from": [from.x, from.y], "path": path.map(func(t): return [t.x, t.y])}, [id]))
		"charge":
			var path := GhostPlanner._tiles(a.path)
			var from: Vector2i = sim.c(id).tile
			sim.c(id).tile = v.end
			sim.c(id).charge_turn = sim.turn_counter
			out.append(fact("COMBAT_MOVED", {"actor": id, "from": [from.x, from.y], "path": path.map(func(t): return [t.x, t.y]), "charge": true}, [id]))
			out.append_array(_resolve_attack(id, a.target, v, false))
		"attack":
			var special: bool = a.get("special", false)
			if special:
				sim.c(id).sheet.pm -= 1
			out.append_array(_resolve_attack(id, a.target, v, special))
		"stand":
			sim.c(id).sheet.remove_condition("caido")
			out.append(fact("STOOD_UP", {"actor": id}, [id]))
		"coup":
			out.append_array(_coup(id, a.target))
		"cast":
			out.append_array(_cast(id, a, v))
		"drink":
			var heal := Dice.roll(str(world.rules.value("magia.curar_ferimentos").cura), world.rng, "combat")
			var sh: CharacterSheet = sim.c(id).sheet
			sh.pv = mini(sh.pv_max, sh.pv + int(heal.total))
			out.append(fact("ITEM_LOST", {"item": a.item}, [id]))
			out.append(fact("HEALED", {"actor": id, "target": id, "amount": heal.total, "pv_after": sh.pv, "source": a.item, "tags": ["cura"]}, [id]))
	return out


## Magia em combate (LB cap. 4): custo por círculo; Seta Infalível acerta sempre.
func _cast(id: String, a: Dictionary, v: Dictionary) -> Array:
	var sp: Dictionary = world.rules.value("magia." + str(a.spell))
	var sh: CharacterSheet = sim.c(id).sheet
	sh.pm -= int(v.cost)
	var out: Array = []
	match str(a.spell):
		"seta_infalivel":
			var targets: Array = a.get("targets", [a.get("target", "")])
			for i in int(sp.setas):
				var tgt: String = targets[i % targets.size()]
				if not sim.c(tgt).is_empty() and not sim.c(tgt).sheet.is_dead():
					var r := Dice.roll(sp.dano_por_seta, world.rng, "combat")
					var tags: Array = ["magia", "impacto"]
					tags.append_array(sim.apply_damage(tgt, int(r.total)))
					out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tgt, "weapon": "Seta Infalível", "d20": 0, "mod": 0, "mods": [],
						"total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": r.total, "rolls": r.rolls,
						"pv_after": sim.c(tgt).sheet.pv, "special": false, "ranged": true, "spell": true, "tags": tags}, [id, tgt]))
		"curar_ferimentos":
			var tgt: String = a.get("target", id)
			var r := Dice.roll(sp.cura, world.rng, "combat")
			var ts: CharacterSheet = sim.c(tgt).sheet
			ts.pv = mini(ts.pv_max, ts.pv + int(r.total))
			out.append(fact("HEALED", {"actor": id, "target": tgt, "amount": r.total, "pv_after": ts.pv, "source": a.spell, "tags": ["magia", "cura"]}, [id, tgt]))
	if id == "player" and not stats.is_empty():
		stats.tactics["magia"] = true
		stats.pm_spent = int(stats.pm_spent) + int(v.cost)
		for f in out:
			if f.type == "ATTACK_RESOLVED": stats.dmg_dealt = int(stats.dmg_dealt) + int(f.payload.damage)
	out.append(fact("SPELL_CAST", {"caster": id, "spell": a.spell, "pm_cost": v.cost, "pm_after": sh.pm}, [id]))
	return out


func _resolve_attack(attacker: String, target: String, v: Dictionary, special: bool) -> Array:
	var A := sim.c(attacker)
	var T := sim.c(target)
	var atk: Dictionary = v.atk
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
		if A.sheet.has_power("especializacao_arma") and str(A.sheet.powers.especializacao_arma) == str(A.sheet.equipment.get("weapon", "")): extra += 2
		if T.damaged_round == sim.round_no and Array(A.sheet.habilidades).any(func(h): return str(h).begins_with("oportunista")):
			extra += 2
		var r := Dice.roll(atk.dano, world.rng, "combat", int(atk.mult) if crit else 1, extra)
		dmg = maxi(1, int(r.total))
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
		tags.append("impacto")
		if crit: tags.append("critico")
		# Durão (LB p.66, guerreiro 3º nível): 3 PM reduz o dano à metade — usado em golpes de 1/4 dos PV ou mais
		if T.sheet.has_power("durao") and T.sheet.pm >= 3 and dmg >= maxi(4, T.sheet.pv_max / 4):
			T.sheet.pm -= 3
			dmg = maxi(1, dmg / 2)
			tags.append("durao")
		tags.append_array(sim.apply_damage(target, dmg))
	else:
		tags.append("esquiva" if not camo_miss else "falha")
		# Golpe de Raspão (LB p.65): 1/rodada, 2 PM, metade do dano ao errar (automático se houver PM)
		var gr_key := "raspao_%d" % sim.round_no
		if A.sheet.has_power("golpe_raspao") and A.sheet.pm >= 2 and not A.flags.has(gr_key) and not camo_miss:
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
			T.sheet.add_condition("caido")
		out.append(fact("MANEUVER_RESOLVED", {"attacker": attacker, "target": target, "maneuver": "derrubar", "attacker_total": mine,
			"target_total": theirs, "success": ok, "tags": ["queda"] if ok else []}, [attacker, target]))
	_track_attack(attacker, target, v, special, hit, crit, dmg, tags)
	log.append(out[0].payload)
	if log.size() > 60: log.pop_front()
	return out


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
	var is_animal: bool = world.rules.value(me.sheet.source_rule, {}).get("tipo", "") == "animal"
	var target := ""
	var best := 999
	for oid in sim.combatants:
		var o := sim.c(oid)
		if o.side == me.side or o.sheet.is_dead() or o.flags.has("fora"):
			continue
		if o.sheet.is_down() and not is_animal:
			continue  # bandidos não executam quem caiu (ORIGINAL_DO_JOGO: preferem capturar)
		var d := CombatSim.cheb(me.tile, o.tile)
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
		var path := sim.trim_path(id, sim.find_path(id, sim.c(target).tile), sim.speed_squares(id))
		if path.is_empty():
			break
		var r := _try(id, {"type": "move", "path": path.map(func(t): return [t.x, t.y])})
		if r.is_empty():
			break
		out.append_array(r)
	return out


func _try(id: String, a: Dictionary) -> Array:
	var v := GhostPlanner.validate_action(sim, id, a)
	if not v.ok:
		return []
	return _execute_action(id, a, v)


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
	world.player.position = world.db.tile_to_world(P.tile)
	for id in sim.combatants:
		if id == "player":
			continue
		var x := sim.c(id)
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
					if id != "player": creature_state[id].present = false
			for id in sim.combatants:
				if id != "player" and sim.c(id).sheet.pv > 0:
					creature_state[id].tile = world.db.creature_def(id).spawn.duplicate()
		"morte":
			out.append(fact("PLAYER_DIED", {"location": loc, "round": sim.round_no}, ["player"]))
	var enemies: Array = sim.combatants.keys().filter(func(x): return x != "player")
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
		"undetected_by": undetected_by.duplicate(), "approach_rolled": approach_rolled.duplicate(), "enemy_faction": enemy_faction}
	if active:
		var cs := {}
		for id in sim.combatants:
			var x: Dictionary = sim.c(id)
			cs[id] = {"id": id, "side": x.side, "tile": [x.tile.x, x.tile.y], "sheet": x.sheet.to_dict(), "charge_turn": x.charge_turn,
				"damaged_round": x.damaged_round, "surprised": x.surprised, "flags": x.flags.duplicate()}
		d["sim"] = {"combatants": cs, "order": sim.order.duplicate(), "initiative": sim.initiative.duplicate(), "turn_idx": sim.turn_idx,
			"round_no": sim.round_no, "turn_counter": sim.turn_counter, "budget": sim.budget.duplicate()}
	return d


func from_dict(d: Dictionary) -> void:
	creature_state = d.get("creature_state", {}).duplicate(true)
	for id in creature_state:
		creature_state[id].woken_until = int(creature_state[id].get("woken_until", -1))
	stance_sneak = bool(d.get("stance_sneak", false))
	undetected_by = d.get("undetected_by", {}).duplicate()
	approach_rolled = d.get("approach_rolled", {}).duplicate()
	enemy_faction = str(d.get("enemy_faction", ""))
	active = bool(d.get("active", false))
	if active and d.has("sim"):
		sim = _new_sim()
		var s: Dictionary = d.sim
		for id in s.combatants:
			var x: Dictionary = s.combatants[id]
			sim.combatants[id] = {"id": id, "side": x.side, "tile": Vector2i(int(x.tile[0]), int(x.tile[1])), "sheet": CharacterSheet.from_dict(x.sheet),
				"charge_turn": int(x.charge_turn), "damaged_round": int(x.damaged_round), "surprised": bool(x.surprised), "flags": x.flags.duplicate()}
		sim.order.clear()
		for id in s.order: sim.order.append(str(id))
		sim.initiative = s.initiative.duplicate()
		sim.turn_idx = int(s.turn_idx); sim.round_no = int(s.round_no); sim.turn_counter = int(s.turn_counter)
		sim.budget = {"std": int(s.budget.std), "move": int(s.budget.move)}
	else:
		active = false
