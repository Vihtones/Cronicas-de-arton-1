class_name CombatModule
extends WorldModule
const Doencas := preload("res://src/domain/rules/doencas.gd")
const Parceiros := preload("res://src/domain/rules/parceiros.gd")
const ClassFeatures := preload("res://src/domain/rules/class_features.gd")
const SpellRules := preload("res://src/domain/combat/spell_rules.gd")
const Area := preload("res://src/domain/combat/area.gd")
const CondicoesCombate := preload("res://src/domain/combat/condicoes_combate.gd")
const Atitudes := preload("res://src/domain/rules/atitudes.gd")
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
const CONDICOES_SEGUNDA_CHANCE := ["abalado", "apavorado", "alquebrado", "atordoado", "cego", "confuso", "debilitado", "enjoado", "envenenado", "esmorecido", "exausto", "fascinado", "fatigado", "fraco", "frustrado", "lento", "ofuscado", "paralisado", "pasmo", "surdo"]
const POWER_POLICIES := {"premonicao_reacao": ["auto", "nunca"], "escudo_da_fe": ["auto", "nunca"], "protecao_divina": ["auto", "nunca"], "golpe_raspao": ["auto", "nunca"], "durao": ["fortes", "sempre", "nunca"],
	"rolamento_defensivo": ["fortes", "sempre", "nunca"], "ataque_reflexo": ["auto", "nunca"],
	"ataque_poderoso": ["auto", "sempre", "nunca"], "combate_defensivo": ["nunca", "sempre"], "trespassar": ["auto", "nunca"],
	"golpe_divino": ["auto", "nunca"], "golpe_divino_extra": ["nunca", "auto"], "arma_espiritual": ["auto", "nunca"], "sustentar": ["auto", "nunca"], "armadura_arcana": ["auto", "nunca"]}
const DEFAULT_POLICY := {"premonicao_reacao": "auto", "escudo_da_fe": "auto", "protecao_divina": "auto", "golpe_raspao": "auto", "durao": "fortes", "rolamento_defensivo": "fortes", "ataque_reflexo": "auto",
	"ataque_poderoso": "auto", "combate_defensivo": "nunca", "trespassar": "auto", "golpe_divino": "auto", "golpe_divino_extra": "nunca",
	"arma_espiritual": "auto", "sustentar": "auto", "armadura_arcana": "auto"}
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
	return PackedStringArray(["StartCombat", "ExecutePlan", "EndTurn", "SetStance", "SetPowerPolicy", "ChangeAttitude"])
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(["PLAYER_MOVED", "PLAYER_TELEPORTED", "OBJECT_DAMAGED", "BANDITS_RELOCATED", "CREATURE_DEFEATED", "PACK_GREW", "PACK_RELOCATED", "TRAVEL_AMBUSH", "ORDER_SET", "SCHEDULED_PURSUIT"])


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
		"ChangeAttitude":
			# Fora de combate: Diplomacia (Mudar Atitude, um minuto) ou Adestramento (Acalmar Animal, CD 25).
			if active: return PackedStringArray(["em combate: use as ações de combate"])
			var alvo_ca := str(cmd.payload.get("target", ""))
			if not creature_state.has(alvo_ca) or not is_active_creature(alvo_ca): return PackedStringArray(["ninguém para convencer"])
			if CombatSim.cheb(world.db.world_to_tile(world.player.position), creature_tile(alvo_ca)) > ALCANCE_CURTO_QUADRADOS:
				return PackedStringArray(["longe demais"])
			var pericia_ca := str(cmd.payload.get("skill", "diplomacia"))
			if pericia_ca == "diplomacia" and int(creature_state[alvo_ca].get("diplomacia_dia", -1)) == world.day_index():
				return PackedStringArray(["já tentou mudar a atitude dele hoje"])
			if pericia_ca == "adestramento":
				if not world.player_sheet.can_use_skill("adestramento", world.rules): return PackedStringArray(["Adestramento é apenas treinada"])
				if CharacterSheet.from_dict(creature_state[alvo_ca].sheet).creature_type != "animal": return PackedStringArray(["escolha um animal"])
			elif pericia_ca != "diplomacia":
				return PackedStringArray(["perícia inválida"])
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
				if act.get("type", "") == "agua_benta" and (st == null or not st.has_item("agua_benta")):
					return PackedStringArray(["você não tem água benta"])
				if act.get("type", "") == "cast" and act.get("spell", "") == "luz" and (act.get("aprimoramentos", []) as Array).has(2) and int(world.player.gold) < 50:
					return PackedStringArray(["faltam T$ 50 de pó de rubi"])
				if act.get("type", "") == "cast" and act.get("spell", "") == "oracao":
					var custo_or := GhostPlanner.spell_cost(world.rules, GhostPlanner.spell_rule(world.rules, "oracao"), act)
					if int(world.player.gold) < 20 * custo_or:
						return PackedStringArray(["faltam T$ %d em incensos e oferendas" % (20 * custo_or)])
				if act.get("type", "") == "cast" and act.get("spell", "") == "miasma_mefitico" and act.get("truque", false) and int(world.player.gold) < SpellRules.PO_DE_ONIX:
					return PackedStringArray(["faltam T$ %d de pó de ônix" % SpellRules.PO_DE_ONIX])
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
		"ChangeAttitude":
			var alvo_e := str(cmd.payload.target)
			var st_e: Dictionary = creature_state[alvo_e]
			var csh := CharacterSheet.from_dict(st_e.sheet)
			var antes := atitude_fora(alvo_e)
			var novo := antes
			var res := {}
			if str(cmd.payload.get("skill", "diplomacia")) == "adestramento":
				res = Checks.skill(world.player_sheet, "adestramento", 25, world.rules, world.rng, "world", world.player_sheet.efeito_bonus_tipo("adestramento_vs", alvo_e))
				if res.get("success", false) and not Atitudes.ORDEM.slice(2).has(antes):
					novo = "indiferente"
			else:
				res = Checks.skill(world.player_sheet, "diplomacia", 0, world.rules, world.rng, "world", world.player_sheet.efeito_bonus_tipo("diplomacia_vs", alvo_e))
				var von := Checks.skill(csh, "vontade", 0, world.rules, world.rng, "world")
				novo = Atitudes.resultado_diplomacia(antes, int(res.total), int(von.total))
				st_e.diplomacia_dia = world.day_index()
			st_e.atitude = novo
			st_e.erase("atitude_temp")
			return [fact("ATTITUDE_CHANGED", {"actor": "player", "target": alvo_e, "from": antes, "to": novo, "check": res}, ["player", alvo_e])]
		"SetStance":
			stance_sneak = bool(cmd.payload.get("sneak", false))
			undetected_by.clear(); approach_rolled.clear()
			return [fact("STANCE_CHANGED", {"sneak": stance_sneak}, ["player"])]
		"StartCombat":
			var ids: Array = cmd.payload.enemies
			var surprised := ids.all(func(id): return undetected_by.has(id))
			for id in ids:   # atacar quem foi acalmado por magia desfaz a magia (Acalmar Animal, Tranquilidade)
				if creature_state.has(id):
					creature_state[id].erase("atitude_temp")
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
			_enxames_fim_de_turno("player", out)
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
			var magia_sil = world.module("magia")
			if magia_sil != null and magia_sil.silencio_ativo():
				return [fact("NOISE_UNHEARD", {"location": world.db.location_at(world.db.world_to_tile(world.player.position)), "reason": "silencio"})]
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
		"SCHEDULED_PURSUIT":
			return _perseguir(e.payload)
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
	var out: Array = _detectar_criaturas(p, zone)
	for id in creature_state:
		if not is_active_creature(id) or world.db.zone_at(creature_tile(id)) != zone:
			approach_rolled.erase(id); undetected_by.erase(id)
			continue
		if not Atitudes.agressiva(atitude_fora(id)):
			continue   # acalmado ou não hostil: não ataca
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
	s.rng = world.rng
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
	if player_surprised and enemy_ids.any(func(e): return int(creature_state.get(e, {}).get("detectado_ate", -1)) > world.clock.tick):
		player_surprised = false   # Detectar Ameaças (aprimoramento): não é surpreendido por quem detectou
	var dlg = world.module("dialogue")
	if dlg != null and not dlg.session.is_empty():
		pre.append(fact("DIALOGUE_ENDED", {"npc": dlg.session.npc, "reason": "combate"}))
	sim = _new_sim()
	sim.dia = world.day_index()
	var magia_p = world.module("magia")
	if magia_p != null and magia_p.luz_ativa() > 0:
		world.player_sheet.add_efeito("luz_carregada", "fonte_luz", magia_p.luz_ativa(), "cena")   # tocha acesa ou chama
	if magia_p != null and not magia_p.escuridao_ativa().is_empty():
		var esc_c: Dictionary = magia_p.escuridao_ativa()
		world.player_sheet.add_efeito("magia.escuridao", "fonte_escuridao", int(esc_c.raio), "cena", "total" if bool(esc_c.total) else "leve")
	if magia_p != null and not magia_p.podas.is_empty():
		sim.add_zona("poda_mundo", magia_p.tiles_podados(), "poda", -1, "controlar_plantas")   # vegetação podada antes
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
			"charge_turn": -99, "damaged_round": -1, "surprised": enemies_surprised, "flags": [], "atitude": str(creature_state[id].get("atitude", "hostil")),
			"diplomacia_dia": int(creature_state[id].get("diplomacia_dia", -1))}
		var temp: Dictionary = creature_state[id].get("atitude_temp", {})
		if not temp.is_empty() and int(temp.ate) > world.clock.tick:
			_pacificar("player", id, str(temp.valor), "acalmado")   # ainda acalmado por magia nesta cena
		var pen_t: Dictionary = creature_state[id].get("penalidade_temp", {})
		if not pen_t.is_empty() and int(pen_t.ate) > world.clock.tick:
			sim.c(id).sheet.add_efeito("magia.tranquilidade", "ataque", int(pen_t.ataque), "cena")   # Tranquilidade resistida
	# Iniciativa (LB p.231): jogador rola; inimigos fazem um teste único com o menor valor.
	var p_mod := world.player_sheet.skill_value("iniciativa", world.rules) + world.player_sheet.efeito_bonus("proxima_iniciativa")
	world.player_sheet.remove_efeito_stat("proxima_iniciativa")   # Aviso (alerta): +5 no próximo teste de Iniciativa
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
		if not start.skip and sim.c(id).has("comando_turno"):
			var cmd_t: Dictionary = sim.c(id).comando_turno
			sim.c(id).erase("comando_turno")
			out.append_array(_turno_comando(id, str(cmd_t.ordem), str(cmd_t.conj)))   # Comando: Fuja / Venha
		elif not start.skip:
			if id == "player":
				return out
			if sim.c(id).flags.has("guardiao"):
				out.append_array(_turno_guardiao(id))
			elif sim.c(id).flags.has("capanga"):
				pass   # mortos-vivos conjurados só agem por ordem do conjurador
			elif sim.c(id).side == "enemy" and not Atitudes.agressiva(atitude_de(id)):
				out.append(fact("TURN_SKIPPED", {"actor": id, "reason": "atitude", "atitude": atitude_de(id)}))
			else:
				out.append_array(_ai_turn(id))
			end = _check_end()
			if not end.is_empty():
				out.append_array(end)
				return out
		_zonas_fim_de_turno(id, out)
		_enxames_fim_de_turno(id, out)
		out.append(fact("TURN_ENDED", {"actor": id}))
		sim.next_turn()
	push_warning("Combate: limite de iterações atingido")
	return out


## Raio da Aura Sagrada: 9m (LB p.84), com 1 quadrado = 1,5m.
const RAIO_AURA_QUADRADOS := 6


## Raio da Aura Divina: 9m (LB p.182), com 1 quadrado = 1,5m. Condições que a aura pode impor (a escolha do conjurador).
const RAIO_AURA_DIVINA_QUADRADOS := 6
const ALCANCE_CURTO_QUADRADOS := 6   # alcance curto: 9m
const LUZ_GUARDIAO := 100            # pontos de luz do Guardião Divino (LB p.194)
const CONDICOES_GUARDIAO := ["abalado", "apavorado", "alquebrado", "atordoado", "cego", "confuso", "debilitado", "enjoado",
	"esmorecido", "exausto", "fascinado", "fatigado", "fraco", "frustrado", "ofuscado", "pasmo", "sangrando", "surdo", "vulneravel"]
const CONDICOES_AURA_DIVINA := ["esmorecido", "debilitado", "lento"]


## Recalcula os efeitos de Aura Sagrada (resistência) e Égide Sagrada (Defesa) conforme as posições atuais:
## cada paladino ativo dá o próprio Carisma aos aliados do mesmo lado que estão no alcance e consciências.
## Oração: quem está no alcance de um orante recebe o bônus (aliados) ou a penalidade (inimigos) em testes e dano.
func _refresh_oracao() -> void:
	for cid in sim.combatants:
		sim.c(cid).sheet.remove_efeito("magia.oracao")
	for orante in sim.combatants:
		var d: Dictionary = sim.c(orante).get("oracao", {})
		if d.is_empty():
			continue
		for cid in sim.combatants:
			if CombatSim.cheb(sim.c(orante).tile, sim.c(cid).tile) > int(d.alcance):
				continue
			var v := int(d.bonus) if not sim.is_enemy(orante, cid) else -int(d.penalidade)
			var s: CharacterSheet = sim.c(cid).sheet
			s.add_efeito("magia.oracao", "testes", v, "cena", "oracao_" + orante)
			s.add_efeito("magia.oracao", "dano", v, "cena", "oracao_" + orante)


## Silêncio: quem está na área (não a versão que só contém o som) fica surdo enquanto estiver lá.
## Círculo da Justiça: penalidades de quem está numa área (cada um resiste uma vez por círculo; ver SpellsModule).
func _refresh_justica() -> void:
	var magia_j = world.module("magia")
	if magia_j == null:
		return
	for cid in sim.combatants:
		magia_j.aplicar_justica(cid, sim.c(cid).sheet, sim.c(cid).tile)


func _refresh_silencio() -> void:
	for cid in sim.combatants:
		var s: CharacterSheet = sim.c(cid).sheet
		var dentro := sim.silenciado(sim.c(cid).tile)
		if dentro and not s.conditions.has("surdo"):
			s.add_condition("surdo", world.rules)
			s.add_efeito("magia.silencio_surdo", "condicao", 1, "cena", "surdo")
		elif not dentro and s.has_efeito("magia.silencio_surdo"):
			s.anular_magia("magia.silencio_surdo")


## Purificação (aprimoramento de 7 PM): dissipa os efeitos prejudiciais das escolas indicadas no alvo.
func _dissipar_prejudiciais(alvo: String, escolas: Array, out: Array) -> void:
	var s: CharacterSheet = sim.c(alvo).sheet
	for e in s.efeitos.duplicate(true):
		var eid := str(e.id)
		if eid.begins_with("magia.") and escolas.has(_escola_de(eid.trim_prefix("magia."))) and (int(e.bonus) < 0 or ["condicao", "bloqueio_cura", "bloqueio_arcana", "ligacao"].has(str(e.stat))):
			s.anular_magia(eid)
			out.append(fact("SPELL_ENDED", {"spell": eid.trim_prefix("magia."), "target": alvo, "reason": "purificacao"}, [alvo]))
	for m in sim.marcas.duplicate(true):
		if m.alvo == alvo and escolas.has(_escola_de(str(m.fonte))) and m.tipo in ["condicao", "comando", "atitude"]:
			if m.tipo == "condicao":
				s.remove_condition(str(m.dados.get("condicao", "")))
			sim.remove_marca(str(m.id), alvo)
			out.append(fact("SPELL_ENDED", {"spell": str(m.fonte), "target": alvo, "reason": "purificacao"}, [alvo]))


## Raio Solar (divina 2): linha de 30m a partir de você. 4d8 de luz (4d12 em mortos-vivos) e ofuscado por 1 rodada;
## Reflexos: metade e sem ofuscar. Aprimoramentos: +1d8 (+1d12) no dano ou cura (repetível); vivos escolhidos curam
## 4d8 em vez do dano; quem falha fica cego por 1d4 rodadas. Truque: facho de luz pela cena (ilumina a linha; a direção
## muda com ação livre, uma vez por rodada).
func _raio_solar(id: String, a: Dictionary) -> Array:
	var out: Array = []
	var sh: CharacterSheet = sim.c(id).sheet
	var apr: Array = a.get("aprimoramentos", [])
	var origem: Vector2i = sim.c(id).tile
	var alvo_t: Vector2i = a.get("tile", sim.c(a.get("target", id)).tile) if sim.combatants.has(a.get("target", id)) else a.get("tile", origem)
	var dir := Vector2i(signi(alvo_t.x - origem.x), signi(alvo_t.y - origem.y))
	if dir == Vector2i.ZERO:
		dir = Vector2i(1, 0)
	var linha := Area.linha(origem, dir, Area.quadrados(30.0))
	if a.get("truque", false):
		sim.add_zona("facho_%s" % id, linha, "luz", -1, "raio_solar", {"conjurador": id, "magica": true, "facho": true})
		out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "facho_de_luz", "tags": ["magia", "luz"]}, [id]))
		return out
	var cd := spell_dc(sh, a)
	var curados: Array = []
	if apr.has(1):
		curados = a.get("curar", sim.combatants.keys().filter(func(x): return not sim.is_enemy(id, x)))   # padrão: os aliados
	for tg in _criaturas_vivas_em(linha):
		if tg == id:
			continue
		var ts: CharacterSheet = sim.c(tg).sheet
		var mv := ts.creature_type == "morto-vivo"
		var faces := 12 if mv else 8
		var expr := "%dd%d" % [4 + apr.count(0), faces]
		if curados.has(tg) and not mv:
			var cura := ts.curar(_dados_energia("%dd8" % (4 + apr.count(0)), "luz", sim.c(tg).tile))
			out.append(fact("HEALED", {"actor": id, "target": tg, "amount": cura, "pv_after": ts.pv, "source": "raio_solar", "tags": ["magia", "cura"]}, [id, tg]))
			continue
		var passou := _resiste(tg, "reflexos", cd, out)
		var dano := _dados_energia(expr, "luz", sim.c(tg).tile)
		if passou:
			dano /= 2
		dano = _dano_por_tipo(ts, "luz", dano)
		var tags: Array = ["magia", "luz"]
		tags.append_array(sim.apply_damage(tg, dano))
		if not passou:
			sim.add_condicao(tg, "ofuscado", 1, "raio_solar")
			if apr.has(2):
				sim.add_condicao(tg, "cego", int(Dice.roll("1d4", world.rng, "combat").total), "raio_solar")
		out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": "Raio Solar", "d20": 0, "mod": 0, "mods": [], "total": 0,
			"defense": cd, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [], "pv_after": ts.pv, "special": false,
			"ranged": true, "spell": true, "save": "reflexos", "saved": passou, "tags": tags}, [id, tg]))
	return out


func _refresh_bencaos() -> void:
	for id_ae in sim.combatants:   # Arma Espiritual se dissipa se o conjurador morrer
		var s_ae: CharacterSheet = sim.c(id_ae).sheet
		if s_ae.is_dead() and s_ae.has_efeito("magia.arma_espiritual"):
			s_ae.remove_efeito("magia.arma_espiritual")
			sim.sustentadas.erase(id_ae)
	_refresh_aura_divina()
	_refresh_areas_sagradas()
	_refresh_oracao()
	_refresh_silencio()
	_refresh_justica()
	_refresh_tempestade()
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


## Aura Divina (5º círculo): sustentada pelo conjurador e segue a posição dele. Você e os aliados devotos da mesma
## divindade (e você, sempre) ganham +10 na Defesa e em resistências e são imunes a fascinado e enfeitiçado; os outros
## aliados ganham +5. Aprimoramento: +1 em todos esses bônus.
func _refresh_aura_divina() -> void:
	for id in sim.combatants:
		sim.c(id).sheet.remove_efeito("aura_divina")
	for h in sim.combatants:
		var hx: Dictionary = sim.c(h)
		var hs: CharacterSheet = hx.sheet
		if not hs.has_efeito("magia.aura_divina") or not sim.conscious(h):
			continue
		var apr := hs.efeito_bonus("aprimoramento")
		for a in sim.combatants:
			var ax: Dictionary = sim.c(a)
			if ax.side != hx.side or not sim.conscious(a):
				continue
			if CombatSim.cheb(hx.tile, ax.tile) > RAIO_AURA_DIVINA_QUADRADOS:
				continue
			var devoto: bool = a == h or (hs.devotion != "" and ax.sheet.devotion == hs.devotion)
			if devoto:
				ax.sheet.add_efeito("aura_divina", "defesa", 10 + apr, "cena")
				ax.sheet.add_efeito("aura_divina", "resistencia", 10 + apr, "cena")
				ax.sheet.add_efeito("aura_divina", "imune", 1, "cena", "fascinado")
				ax.sheet.add_efeito("aura_divina", "imune", 1, "cena", "enfeiticado")
			else:
				ax.sheet.add_efeito("aura_divina", "defesa", 5 + apr, "cena")
				ax.sheet.add_efeito("aura_divina", "resistencia", 5 + apr, "cena")


## Entrada na Aura Divina: quando uma criatura do outro lado passa de fora para dentro da área durante o movimento,
## faz Vontade (CD da aura); se falhar, recebe a condição escolhida pelo conjurador até o fim da cena.
## Quem já começa dentro da área não dispara o teste.
func _aura_divina_entrada(mover: String, from: Vector2i, path: Array) -> Array:
	var out: Array = []
	var mx: Dictionary = sim.c(mover)
	for h in sim.combatants:
		var hx: Dictionary = sim.c(h)
		var hs: CharacterSheet = hx.sheet
		if hx.side == mx.side or not hs.has_efeito("magia.aura_divina") or not sim.conscious(h) or not sim.conscious(mover):
			continue
		var centro: Vector2i = hx.tile
		var entrou := false
		var prev := from
		for t in path:
			var t_v: Vector2i = t
			if CombatSim.cheb(centro, t_v) <= RAIO_AURA_DIVINA_QUADRADOS and CombatSim.cheb(centro, prev) > RAIO_AURA_DIVINA_QUADRADOS:
				entrou = true
				break
			prev = t_v
		if not entrou:
			continue
		var cd := hs.efeito_bonus("cd")
		var cond := _condicao_aura(hs)
		var sv := Checks.skill(mx.sheet, "vontade", cd, world.rules, world.rng, "combat")
		sv = _pos_teste(mover, sv, cd, out)
		if sv.get("success", false):
			out.append(fact("SPELL_MISSED", {"caster": h, "target": mover, "spell": "aura_divina"}, [h, mover]))
		else:
			sim.add_condicao(mover, cond, 999, "aura_divina")   # 999 rodadas: a condição dura até o fim da cena
			out.append(fact("BUFF_APPLIED", {"actor": h, "target": mover, "buff": "aura_divina", "condicao": cond, "tags": ["magia"]}, [h, mover]))
	return out


func _condicao_aura(hs: CharacterSheet) -> String:
	for e in hs.efeitos:
		if e.id == "magia.aura_divina" and e.stat == "condicao":
			return str(e.tipo)
	return "esmorecido"


## Guardião Divino: no próprio turno, o elemental voa (18m) até o aliado mais ferido, se preciso, e gasta luz:
## 1 ponto por PV curado, 3 pontos por condição da lista removida. Quando a luz acaba, sai da cena.
func _turno_guardiao(id: String) -> Array:
	var out: Array = []
	var me: Dictionary = sim.c(id)
	var luz := _luz_guardiao(id)
	var aliados: Array = []
	for a in sim.combatants:
		if a != id and sim.c(a).side == me.side and sim.conscious(a):
			aliados.append(a)
	var alvo := ""
	var pior := 0
	for a in aliados:
		var falta := int(sim.c(a).sheet.pv_max) - int(sim.c(a).sheet.pv)
		if falta > pior:
			pior = falta
			alvo = a
	if alvo == "":
		for a in aliados:
			if not _condicoes_do_guardiao(sim.c(a).sheet).is_empty() and luz >= 3:
				alvo = a
				break
	if alvo == "":
		return out
	if CombatSim.cheb(me.tile, sim.c(alvo).tile) > ALCANCE_CURTO_QUADRADOS:
		var de: Vector2i = me.tile
		var para := _tile_voo(de, sim.c(alvo).tile)
		if para != de:
			me.tile = para
			out.append(fact("COMBAT_MOVED", {"actor": id, "from": [de.x, de.y], "path": [[para.x, para.y]], "flying": true}, [id]))
	for a in aliados:
		if CombatSim.cheb(me.tile, sim.c(a).tile) > ALCANCE_CURTO_QUADRADOS:
			continue
		var sh: CharacterSheet = sim.c(a).sheet
		var falta_a := int(sh.pv_max) - int(sh.pv)
		if falta_a > 0 and luz > 0:
			var gasto := mini(falta_a, luz)
			var curado := sh.curar(gasto)
			luz -= gasto
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": a, "buff": "guardiao_divino", "cura": curado, "luz_restante": luz, "tags": ["magia"]}, [id, a]))
		for cond in _condicoes_do_guardiao(sh):
			if luz < 3:
				break
			sh.remove_condition(cond)
			luz -= 3
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": a, "buff": "guardiao_divino", "condicao_removida": cond, "luz_restante": luz, "tags": ["magia"]}, [id, a]))
	me.sheet.add_efeito("magia.guardiao_divino", "luz", luz, "cena")
	if luz <= 0:
		me.flags.append("fora")   # sem luz, o elemental se desfaz
		out.append(fact("BUFF_APPLIED", {"actor": id, "buff": "guardiao_divino", "efeito": "encerrado", "tags": ["magia"]}, [id]))
	return out


func _luz_guardiao(id: String) -> int:
	return sim.c(id).sheet.efeito_bonus("luz")


func _condicoes_do_guardiao(sh: CharacterSheet) -> Array:
	var r: Array = []
	for cond in CONDICOES_GUARDIAO:
		if sh.conditions.has(cond):
			r.append(cond)
	return r


## Quadrado livre a até 12 quadrados (18m de voo) de `origem` e a alcance curto de `alvo`, o mais perto possível de `origem`.
func _tile_voo(origem: Vector2i, alvo: Vector2i) -> Vector2i:
	var melhor := origem
	var melhor_d := 999
	for dx in range(-12, 13):
		for dy in range(-12, 13):
			var t := origem + Vector2i(dx, dy)
			if CombatSim.cheb(t, alvo) > ALCANCE_CURTO_QUADRADOS or not sim.walk_fn.call(t):
				continue
			var ocupado := false
			for oid in sim.combatants:
				if sim.c(oid).tile == t and sim.conscious(oid):
					ocupado = true
					break
			if ocupado:
				continue
			var d := CombatSim.cheb(t, origem)
			if d < melhor_d:
				melhor_d = d
				melhor = t
	return melhor


## Ritual de Lágrimas de Wynna (um dia): o efeito fica na ficha do conjurador até o dia seguinte. Na virada do dia,
## se o alvo ainda está no mesmo lugar, faz Vontade; falha perde as magias arcanas para sempre. Se o alvo se afastou,
## o ritual se perde sem efeito. Quem passa resiste e pode ser alvo de novo.
func processar_rituais_do_dia() -> Array:
	var out: Array = []
	var ps: CharacterSheet = world.player_sheet
	if ps == null:
		return out
	var dia := world.day_index()
	for e in ps.efeitos.duplicate(true):
		if e.id != "magia.lagrimas_de_wynna" or e.fim != "ritual" or dia < int(e.ate):
			continue
		var npc := str(e.tipo)
		ps.remove_efeito_de("magia.lagrimas_de_wynna", "ritual")
		var estado_npc: Dictionary = creature_state.get(npc, {})
		if estado_npc.is_empty() or not bool(estado_npc.get("present", false)) or not _mesmo_lugar_do_jogador(estado_npc):
			out.append(fact("SPELL_MISSED", {"caster": "player", "target": npc, "spell": "lagrimas_de_wynna", "reason": "alvo se afastou"}, ["player", npc]))
			continue
		var nsh := CharacterSheet.from_dict(estado_npc.sheet)
		var sv := Checks.skill(nsh, "vontade", int(e.bonus), world.rules, world.rng, "world")
		if not sv.get("success", false):
			nsh.arcana_perdida = true
		estado_npc.sheet = nsh.to_dict()
		out.append(fact("BUFF_APPLIED", {"actor": "player", "target": npc, "buff": "lagrimas_de_wynna", "passou": sv.get("success", false), "arcana_perdida": not sv.get("success", false), "tags": ["magia"]}, ["player", npc]))
	return out


func _mesmo_lugar_do_jogador(estado_npc: Dictionary) -> bool:
	var t: Array = estado_npc.get("tile", [])
	if t.size() < 2:
		return false
	var onde := world.db.location_at(world.db.world_to_tile(world.player.position))
	return onde == world.db.location_at(Vector2i(int(t[0]), int(t[1])))


## Fim da execução do Banimento (no início do turno do conjurador): alvo fora de alcance ou já fora da cena não é afetado.
## Criatura de outro mundo (espírito) faz Vontade ou é banida; morto-vivo faz Vontade ou cai a 0 PV; quem passa fica
## enjoado por 1d4 rodadas. Nativo de Arton não é afetado. Com o aprimoramento, a criatura conjurada volta ao plano.
func _resolver_conjuracao(id: String, facts: Array) -> void:
	if not sim.conjurando.has(id) or int(sim.conjurando[id].rodadas) > 0:
		return
	var cj: Dictionary = sim.conjurando[id]
	sim.conjurando.erase(id)
	if not sim.conscious(id):
		return
	var alvo := str(cj.alvo)
	if not sim.combatants.has(alvo) or not sim.conscious(alvo):
		facts.append(fact("SPELL_MISSED", {"caster": id, "target": alvo, "spell": "banimento", "reason": "fora da cena"}, [id, alvo]))
		return
	if CombatSim.cheb(sim.c(id).tile, sim.c(alvo).tile) > ALCANCE_CURTO_QUADRADOS:
		facts.append(fact("SPELL_MISSED", {"caster": id, "target": alvo, "spell": "banimento", "reason": "fora de alcance"}, [id, alvo]))
		return
	var alv: CharacterSheet = sim.c(alvo).sheet
	var cd := int(cj.cd)
	if bool(cj.apr):
		if alvo.begins_with("inv_"):
			sim.remove_combatant(alvo)
			facts.append(fact("BUFF_APPLIED", {"actor": id, "target": alvo, "buff": "banimento", "efeito": "devolvida_ao_plano", "tags": ["magia"]}, [id, alvo]))
		else:
			facts.append(fact("SPELL_MISSED", {"caster": id, "target": alvo, "spell": "banimento", "reason": "não é criatura conjurada"}, [id, alvo]))
		return
	var planar := alv.creature_type == "espirito"
	var morta := alv.creature_type == "morto-vivo"
	if not planar and not morta:
		facts.append(fact("SPELL_MISSED", {"caster": id, "target": alvo, "spell": "banimento", "reason": "nativo de Arton"}, [id, alvo]))
		return
	var sv := Checks.skill(alv, "vontade", cd, world.rules, world.rng, "combat")
	sv = _pos_teste(alvo, sv, cd, facts)
	if sv.get("success", false):
		sim.add_condicao(alvo, "enjoado", int(Dice.roll("1d4", world.rng, "combat").total), "banimento")
		facts.append(fact("SPELL_MISSED", {"caster": id, "target": alvo, "spell": "banimento", "reason": "resistiu"}, [id, alvo]))
		return
	if morta:
		sim.apply_damage(alvo, alv.pv + alv.pv_temp)   # conexão com as energias negativas rompida: 0 PV
		facts.append(fact("BUFF_APPLIED", {"actor": id, "target": alvo, "buff": "banimento", "efeito": "destruido", "tags": ["magia"]}, [id, alvo]))
	else:
		sim.c(alvo).flags.append("fora")   # de volta ao mundo de origem: fica fora da cena (não age nem é alvo)
		facts.append(fact("BUFF_APPLIED", {"actor": id, "target": alvo, "buff": "banimento", "efeito": "banido", "tags": ["magia"]}, [id, alvo]))


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
func invocar(caster: String, rule_id: String, rodadas: int, fonte: String, centro: Vector2i = Vector2i(-9999, -9999)) -> String:
	var cx: Dictionary = sim.c(caster)
	var usados: Array = []
	for id in sim.combatants:
		usados.append(sim.c(id).tile)
	var nova := "inv_%s_%d" % [fonte, sim.combatants.size()]
	var sh := CharacterSheet.from_creature(sim.rules, rule_id, nova)
	sim.combatants[nova] = {"id": nova, "side": cx.side, "order": "", "tile": _tile_livre_na_sim(cx.tile if centro.x == -9999 else centro, usados), "sheet": sh,
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
		if str(z.tipo) == "controlar_plantas" and (z.tiles as Array).has(x.tile) and sim.conscious(id):
			_enredar_plantas(id, z, facts)   # a vegetação tenta enredar de novo
		if bool(dados.get("cheiro", false)) and sim.conscious(id) and _sente_cheiro(id, z):
			# Névoa (aprimoramento de 2 PM): quem está dentro, ou tem faro em alcance curto, faz Fortitude ou fica enjoado.
			var cd_ch := int(dados.get("cd", 10))
			var sv_ch := Checks.skill(x.sheet, "fortitude", cd_ch, world.rules, world.rng, "combat")
			sv_ch = _pos_teste(id, sv_ch, cd_ch, facts)
			if not sv_ch.get("success", false) and sim.add_condicao(id, "enjoado", 1, str(z.fonte)):
				facts.append(fact("BUFF_APPLIED", {"actor": str(dados.get("conjurador", id)), "target": id, "buff": "enjoado", "tags": ["magia", "condicao"]},
					[str(dados.get("conjurador", id)), id]))
		if not (z.tiles as Array).has(x.tile) or not dados.has("dano_inicio_turno") or not _zona_afeta(z, id) or not sim.conscious(id):
			continue
		_efeito_magico_no_turno(id, str(dados.dano_inicio_turno), str(dados.get("conjurador", id)), str(z.fonte), facts, str(dados.get("tipo_dano", "")))
	for m in sim.marcas.duplicate(true):
		if m.alvo != id or not sim.conscious(id):
			continue
		var dados_m: Dictionary = m.get("dados", {})
		var conj: String = str(dados_m.get("conjurador", id))
		if m.tipo == "esquentar" and str(x.sheet.equipment.get("weapon" if str(dados_m.get("objeto", "")) == "arma" else "armor", "")) == "":
			sim.remove_marca(str(m.id), id)   # largou o objeto que esquentava
			continue
		if dados_m.has("dano_inicio_turno"):
			_efeito_magico_no_turno(id, str(dados_m.dano_inicio_turno), conj, str(m.fonte), facts, str(dados_m.get("tipo_dano", "")))
		if dados_m.has("cura_inicio_turno") and sim.conscious(id):
			var s: CharacterSheet = x.sheet
			var cura := int(Dice.roll(str(dados_m.cura_inicio_turno), world.rng, "combat").total)
			cura = s.curar(cura)
			facts.append(fact("HEALED", {"actor": conj, "target": id, "amount": cura, "pv_after": s.pv, "source": str(m.fonte), "tags": ["magia", "cura"]}, [conj, id]))


## Cheiro da Névoa: dentro da nuvem, ou com faro a até alcance curto de algum quadrado dela.
func _sente_cheiro(id: String, z: Dictionary) -> bool:
	var t: Vector2i = sim.c(id).tile
	if (z.tiles as Array).has(t):
		return true
	if not sim.c(id).sheet.senses.has("faro") or sim.c(id).sheet.efeito_bonus("sem_faro") > 0:
		return false
	for zt in z.tiles:
		if CombatSim.cheb(t, zt) <= ALCANCE_CURTO_QUADRADOS:
			return true
	return false


## Vento no local do combate (LB, clima): chuva traz vento forte e tempestade, vendaval. "" sem vento.
func _vento() -> String:
	if not world.modules.has("weather") or not world.modules.weather.enabled:
		return ""
	match str(world.modules.weather.region.condition):
		"chuva": return "forte"
		"tempestade": return "vendaval"
	return ""


func _zona_afeta(z: Dictionary, id: String) -> bool:
	var dados: Dictionary = z.get("dados", {})
	var afeta := str(dados.get("afeta", "todos"))
	if afeta == "todos":
		return true
	var lado := str(dados.get("lado", ""))
	if afeta == "inimigos":
		return sim.c(id).side != lado
	return sim.c(id).side == lado


## Dissipação por escola: encerra as magias ativas da escola (efeitos das criaturas, zonas e marcas) que estão na área.
## Invocações de magia da escola saem do combate.
func _dissipar_na_area(tiles: Array, escola: String, out: Array) -> void:
	for id in sim.combatants:
		if not tiles.has(sim.c(id).tile):
			continue
		var s: CharacterSheet = sim.c(id).sheet
		for e in s.efeitos.duplicate(true):
			if str(e.id).begins_with("magia.") and _escola_de(str(e.id).trim_prefix("magia.")) == escola.to_lower():
				s.anular_magia(str(e.id))
	sim.zonas = sim.zonas.filter(func(z): return not (_escola_de(str(z.fonte)) == escola.to_lower() and _alguma_em(z.tiles, tiles)))
	for m in sim.marcas.duplicate(true):
		if _escola_de(str(m.fonte)) == escola.to_lower() and tiles.has(sim.c(m.alvo).tile):
			if m.tipo == "invocacao":
				sim.remove_combatant(m.alvo)
			else:
				sim.remove_marca(m.id, m.alvo)
	out.append(fact("BUFF_APPLIED", {"actor": "player", "target": "area", "buff": "dissipacao_" + escola.to_lower(), "tags": ["magia"]}, []))


## Escola de uma magia do catálogo, em minúsculas ("" se não for magia conhecida).
func _escola_de(sp_id: String) -> String:
	return str(world.rules.value("magia." + sp_id, {}).get("escola", "")).to_lower()


func _alguma_em(tiles_a: Array, tiles_b: Array) -> bool:
	for t in tiles_a:
		if tiles_b.has(t):
			return true
	return false


## Início do turno do conjurador: as nuvens dele afetam quem está dentro.
func _nuvens_do_conjurador(id: String, facts: Array) -> void:
	for z in sim.zonas.duplicate(true):
		var dados: Dictionary = z.get("dados", {})
		if dados.has("dano_turno") and str(dados.get("conjurador", "")) == id:
			_aplicar_nuvem(z, facts)


## Reação Premonição (3 PM, aprimoramento de reação): logo após um teste de resistência, o conjurador força nova rolagem.
## Aliados: só quando falharam. Inimigos (involuntários) têm Vontade para negar; sem negar, se tiverem passado, a nova rolagem vale.
func _pos_teste(alvo: String, sv: Dictionary, cd: int, out: Array) -> Dictionary:
	if sim.c("player").has("sheet") and not CondicoesCombate.pode_reagir(sim.c("player").sheet, world.rules):
		return sv
	if str(power_policy.get("premonicao_reacao", "auto")) == "nunca":
		return sv
	var P := sim.c("player")
	if P.is_empty() or not P.sheet.spells.has("premonicao") or sim.c(alvo).sheet.is_dead():
		return sv
	var flag := "premonicao_%d" % sim.round_no
	if P.flags.has(flag) or CombatSim.cheb(P.tile, sim.c(alvo).tile) > int(world.rules.value("alcance.quadrados", {}).get("curto", 6)):
		return sv
	var inimigo := sim.is_enemy("player", alvo)
	if inimigo and not sv.get("success", false):
		return sv   # inimigo que já falhou não precisa de empurrão
	if not inimigo and sv.get("success", false):
		return sv   # aliado que passou não precisa de nova rolagem
	var sp := GhostPlanner.spell_rule(world.rules, "premonicao")
	var custo := GhostPlanner.spell_cost(world.rules, sp, {"spell": "premonicao", "aprimoramentos": [0]})
	if P.sheet.pm < custo:
		return sv
	P.sheet.pm -= custo
	P.flags.append(flag)
	if inimigo:
		var dc := spell_dc(P.sheet, {"spell": "premonicao"})
		var negou := Checks.skill(sim.c(alvo).sheet, "vontade", dc, world.rules, world.rng, "combat")
		if negou.get("success", false):
			out.append(fact("REACTION", {"actor": "player", "power": "premonicao", "target": alvo, "negado": true}, ["player", alvo]))
			return sv
	var d: int = int(world.rng.roll("combat", 1, 20)[0])
	var mod := int(sv.get("mod", 0))
	var total := d + mod
	out.append(fact("REACTION", {"actor": "player", "power": "premonicao", "target": alvo, "reroll": true, "d20": d, "total": total}, ["player", alvo]))
	return {"allowed": true, "skill": sv.get("skill", ""), "d20": d, "mod": mod, "total": total, "cd": cd,
		"success": total >= cd, "margin": total - cd, "sorte": false, "falha_automatica": false}


## Nuvem (Poeira da Podridão): cada criatura viva dentro faz Fortitude; sofre o dano de trevas (metade no teste)
## e quem falha fica sem recuperar PV por uma rodada.
func _aplicar_nuvem(z: Dictionary, facts: Array) -> void:
	var dados: Dictionary = z.get("dados", {})
	var conj := str(dados.get("conjurador", ""))
	for tg in _criaturas_vivas_em(z.tiles):
		var ts: CharacterSheet = sim.c(tg).sheet
		var sv := Checks.skill(ts, "fortitude", int(dados.get("cd", 10)), world.rules, world.rng, "combat")
		sv = _pos_teste(tg, sv, int(dados.get("cd", 10)), facts)
		var passou: bool = sv.get("success", false)
		var dano := _dados_energia(str(dados.get("dano_turno", "2d8+8")), "trevas", sim.c(tg).tile)
		if passou:
			dano = dano / 2
		dano = _dano_por_tipo(ts, "trevas", dano)
		if not passou:
			ts.add_efeito("magia.poeira_da_podridao", "bloqueio_cura", 1, "rodada")
		var tags: Array = ["magia", "trevas"]
		if passou:
			tags.append("resistiu")
		tags.append_array(sim.apply_damage(tg, dano))
		facts.append(fact("ATTACK_RESOLVED", {"attacker": conj, "target": tg, "weapon": "Poeira da Podridão", "d20": 0, "mod": 0,
			"mods": [], "total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [],
			"pv_after": ts.pv, "special": false, "ranged": true, "spell": true, "save": "fortitude", "saved": passou, "tags": tags}, [conj, tg]))


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
		var n := _dados_energia(str(dados.fim_turno), "luz", x.tile)
		if _sofre_luz(s):
			s.pm -= mini(s.pm, n)
			var tags_f: Array = ["magia", "luz"]
			tags_f.append_array(sim.apply_damage(id, n))
			facts.append(fact("ATTACK_RESOLVED", {"attacker": conj, "target": id, "weapon": str(z.fonte), "d20": 0, "mod": 0,
				"mods": [], "total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": n, "rolls": [],
				"pv_after": s.pv, "special": false, "ranged": false, "spell": true, "save": "", "saved": false, "tags": tags_f}, [conj, id]))
		else:
			n = s.curar(n)
			facts.append(fact("HEALED", {"actor": conj, "target": id, "amount": n, "pv_after": s.pv, "source": str(z.fonte), "tags": ["magia", "cura"]}, [conj, id]))
			var usados := s.efeito_bonus("usos_circulo_restauracao")
			if usados < 5:
				s.pm = mini(s.pm_max, s.pm + 1)
				s.add_efeito("circulo_restauracao", "usos_circulo_restauracao", usados + 1, "dia")


## Criatura que sofre dano por luz: mortos-vivos e criaturas com vulnerabilidade à luz (tabela da raça).
func _sofre_luz(s: CharacterSheet) -> bool:
	return s.creature_type == "morto-vivo" or int(s.vuln.get("luz", 0)) > 0


## Dano mágico por dados (zona ou marca): aplica e registra no mesmo formato de um ataque de magia.
func _efeito_magico_no_turno(id: String, dados: String, conj: String, origem: String, facts: Array, tipo: String = "") -> void:
	var dano := _dados_energia(dados, tipo, sim.c(id).tile)
	var tags: Array = ["magia"]
	if tipo != "":
		dano = _dano_por_tipo(sim.c(id).sheet, tipo, dano)
		tags.append(tipo)
	tags.append_array(sim.apply_damage(id, dano))
	facts.append(fact("ATTACK_RESOLVED", {"attacker": conj, "target": id, "weapon": origem, "d20": 0, "mod": 0,
		"mods": [], "total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [],
		"pv_after": sim.c(id).sheet.pv, "special": false, "ranged": false, "spell": true, "save": "", "saved": false, "tags": tags}, [conj, id]))


## Comando no início do turno de quem obedece: Pare (pasmo, uma vez por cena), Senta (caído, sem se levantar neste
## turno), Largue (solta o que segura; só pega de novo no próximo turno). Fuja e Venha tomam o turno (_turno_comando).
## Marca da Obediência no início do turno do alvo: Vontade contra a CD gravada; passou, a marca se dissipa e ele age
## normalmente; falhou, obedece a ordem neste turno (e sofre 3d6 de dano psíquico com o aprimoramento).
func _marca_obediencia(id: String, facts: Array) -> Dictionary:
	var s: CharacterSheet = sim.c(id).sheet
	var marca := {}
	for e in s.efeitos:
		if e.stat == "marca_obediencia":
			marca = e
	if marca.is_empty():
		return {}
	if _resiste(id, "vontade", int(marca.bonus), facts):
		s.anular_magia("magia.marca_da_obediencia")
		facts.append(fact("SPELL_ENDED", {"spell": "marca_da_obediencia", "target": id, "reason": "resistiu"}, [id]))
		return {}
	if s.efeito_bonus("marca_dano") > 0:
		var dano := _dano_por_tipo(s, "psiquico", int(Dice.roll("3d6", world.rng, "combat").total))
		sim.apply_damage(id, dano)
		facts.append(fact("HAZARD", {"actor": id, "hazard": "marca_da_obediencia", "damage": dano, "pv_after": s.pv, "tags": ["magia", "psiquico"]}, [id]))
	facts.append(fact("COMMAND_OBEYED", {"actor": id, "ordem": str(marca.tipo), "caster": str(marca.get("conj", ""))}, [id]))
	return {"ordem": "marca_" + str(marca.tipo), "conj": str(marca.get("conj", ""))}


func _obedecer_comando(id: String, facts: Array) -> Dictionary:
	var m := {}
	for mk in sim.marcas:
		if mk.alvo == id and mk.tipo == "comando":
			m = mk
	if m.is_empty():
		return {}
	var ordem := str(m.dados.ordem)
	var x: Dictionary = sim.c(id)
	var s: CharacterSheet = x.sheet
	sim.remove_marca("comando", id)
	match ordem:
		"pare":
			if not x.flags.has("comando_pare"):
				x.flags.append("comando_pare")   # apenas uma vez por cena
				sim.add_condicao(id, "pasmo", 1, "comando")
		"senta":
			s.add_condition("caido", world.rules)
			x.flags.append("comando_senta_%d" % sim.turn_counter)   # não se levanta até o próximo turno
		"largue":
			_largar_arma(id)
	facts.append(fact("COMMAND_OBEYED", {"actor": id, "ordem": ordem, "caster": str(m.dados.conjurador)}, [id]))
	return {"ordem": ordem, "conj": str(m.dados.conjurador)}


## Largue: a arma empunhada (e os ataques com ela) fica no chão do quadrado. Armas naturais ficam.
func _largar_arma(id: String) -> void:
	var x: Dictionary = sim.c(id)
	var s: CharacterSheet = x.sheet
	var largados: Array = s.attacks.filter(func(at): return not bool(at.get("natural", false)))
	if largados.is_empty():
		return
	x["arma_no_chao"] = {"arma": str(s.equipment.get("weapon", "")), "ataques": largados.duplicate(true), "tile": [x.tile.x, x.tile.y], "turno": sim.turn_counter}
	s.attacks = s.attacks.filter(func(at): return bool(at.get("natural", false)))
	s.equipment["weapon"] = ""


func _devolver_arma(id: String) -> void:
	var x: Dictionary = sim.c(id)
	var chao: Dictionary = x.get("arma_no_chao", {})
	if chao.is_empty():
		return
	var s: CharacterSheet = x.sheet
	s.equipment["weapon"] = str(chao.arma)
	var ataques: Array = (chao.ataques as Array).duplicate(true)
	ataques.append_array(s.attacks)
	s.attacks = ataques
	x.erase("arma_no_chao")


## Fuja / Venha: o turno inteiro (todas as ações) afastando-se do conjurador ou indo até ele.
func _turno_comando(id: String, ordem: String, conj: String) -> Array:
	var out: Array = []
	if ordem.begins_with("marca_"):
		if ordem != "marca_siga" or not sim.combatants.has(conj):
			sim.budget.std = 0   # Marca da Obediência: não ataque / fique — o turno inteiro é gasto obedecendo
			return out
		ordem = "venha"   # siga-me: vai até o conjurador
	for i in 2:
		if not sim.can_spend("movimento"):
			break
		var me: Dictionary = sim.c(id)
		var alvo: Vector2i = sim.c(conj).tile
		var caminho: Array = []
		var pos: Vector2i = me.tile
		for passo in sim.speed_squares(id):
			var melhor := pos
			var melhor_d := CombatSim.cheb(pos, alvo)
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var t: Vector2i = pos + Vector2i(dx, dy)
					if (dx == 0 and dy == 0) or caminho.has(t) or not sim.passable(t, id) or sim.occupant(t, id) != "":
						continue
					var d := CombatSim.cheb(t, alvo)
					if (ordem == "fuja" and d > melhor_d) or (ordem == "venha" and d < melhor_d and d >= 1):
						melhor = t
						melhor_d = d
			if melhor == pos:
				break
			caminho.append(melhor)
			pos = melhor
		if caminho.is_empty():
			break
		var trecho := sim.trim_path(id, caminho, sim.speed_squares(id))
		if trecho.is_empty():
			break
		out.append_array(_try(id, {"type": "move", "path": trecho.map(func(t): return [t.x, t.y])}))
	sim.budget.std = 0   # usa todas as ações
	return out


## Detectar Ameaças (SpellsModule): criatura hostil a até 18m faz o jogador testar Percepção (CD 10 + Furtividade
## dela). Passou: sabe origem, direção e distância (e raça e aura, com o aprimoramento); falhou: só que há perigo.
## A magia se descarrega. Com o aprimoramento de 2 PM, quem foi detectado não o surpreende.
func _detectar_criaturas(p: Vector2i, zone: String) -> Array:
	var magia = world.module("magia")
	if magia == null or magia.detectar_ativo().is_empty():
		return []
	var apr: Array = magia.detectar_ativo().apr
	for id in creature_state:
		if not is_active_creature(id) or world.db.zone_at(creature_tile(id)) != zone or not Atitudes.agressiva(atitude_fora(id)):
			continue
		var t := creature_tile(id)
		var d := CombatSim.cheb(p, t)
		if d > int(magia.RAIO_DETECTAR):
			continue
		var csh := CharacterSheet.from_dict(creature_state[id].sheet)
		var r := Checks.skill(world.player_sheet, "percepcao", 10 + csh.skill_value("furtividade", world.rules), world.rules, world.rng, "world")
		magia.descarregar_detectar()
		if not r.get("success", false):
			return [fact("THREAT_SENSED", {"kind": "criatura", "check": r}, ["player"])]
		var info := {"kind": "criatura", "creature": id, "distance": d, "direction": [signi(t.x - p.x), signi(t.y - p.y)], "check": r}
		if apr.has(0):
			var regra: Dictionary = world.rules.value(csh.source_rule, {})
			info["especie"] = str(regra.get("nome", csh.name))
			info["aura"] = SpellRules.aura_por_nd(str(regra.get("nd", "1")))
		if apr.has(1):
			creature_state[id].detectado_ate = world.clock.tick + TICKS_CENA
		return [fact("THREAT_DETECTED", info, ["player"])]
	return []


## --- Atitudes (LB p.259) --------------------------------------------------------------------------
const TICKS_CENA := 6   # uma cena fora de combate dura cerca de uma hora (ORIGINAL_DO_JOGO)


func _marca_atitude(id: String) -> Dictionary:
	for m in sim.marcas:
		if m.alvo == id and m.tipo == "atitude":
			return m
	return {}


## Atitude da criatura em relação ao grupo do jogador: a de magia (marca) vale sobre a natural.
func atitude_de(id: String) -> String:
	var m := _marca_atitude(id)
	if not m.is_empty():
		return str(m.dados.valor)
	return str(sim.c(id).get("atitude", "hostil")) if sim.c(id).side == "enemy" else "prestativo"


## Atitude fora de combate (para começar encontros): a de magia ainda na cena, ou a natural.
func atitude_fora(id: String) -> String:
	var st_a: Dictionary = creature_state.get(id, {})
	var t: Dictionary = st_a.get("atitude_temp", {})
	if not t.is_empty() and int(t.ate) > world.clock.tick:
		return str(t.valor)
	return str(st_a.get("atitude", "hostil"))


## Acalmar Animal: ação hostil do conjurador ou de aliados dele contra o alvo dissipa. Tranquilidade: ação hostil de
## qualquer um contra o alvo ou os aliados dele dissipa. O alvo volta à atitude de antes.
func _atitude_quebra(id: String, a: Dictionary, out: Array) -> void:
	var alvos := _alvos_hostis(id, a)
	alvos.append_array(_criaturas_vivas_em(_area_hostil(id, a)))
	if alvos.is_empty():
		return
	for m in sim.marcas.duplicate(true):
		if m.tipo != "atitude" or not sim.combatants.has(m.alvo):
			continue
		var quebra := false
		for tg in alvos:
			if str(m.fonte) == "tranquilidade":
				quebra = quebra or tg == m.alvo or (sim.c(tg).side == sim.c(m.alvo).side)
			else:
				quebra = quebra or (tg == m.alvo and not sim.is_enemy(id, str(m.dados.conjurador)))
		if quebra:
			sim.remove_marca(str(m.id), m.alvo)
			out.append(fact("SPELL_ENDED", {"caster": str(m.dados.conjurador), "spell": str(m.fonte), "target": m.alvo, "reason": "acao_hostil"}, [m.alvo]))


## Mudar Atitude (Diplomacia, LB p.118): oposto pela Vontade do alvo; uma vez por dia por alvo. `mod`: –10 em combate.
func _mudar_atitude(id: String, alvo: String, mod: int) -> Array:
	var A: Dictionary = sim.c(id)
	var T: Dictionary = sim.c(alvo)
	var r := Checks.skill(A.sheet, "diplomacia", 0, world.rules, world.rng, "combat", mod + A.sheet.efeito_bonus_tipo("diplomacia_vs", alvo))
	var von := Checks.skill(T.sheet, "vontade", 0, world.rules, world.rng, "combat")
	T["diplomacia_dia"] = sim.dia
	var antes := str(T.get("atitude", "hostil"))
	T["atitude"] = Atitudes.resultado_diplomacia(antes, int(r.total), int(von.total))
	return [fact("ATTITUDE_CHANGED", {"actor": id, "target": alvo, "from": antes, "to": T.atitude, "total": r.total, "vontade": von.total}, [id, alvo])]


## Adestramento, Acalmar Animal (LB p.115): CD 25; o animal deixa de ser agressivo (indiferente).
func _acalmar_pela_pericia(id: String, alvo: String) -> Array:
	var A: Dictionary = sim.c(id)
	var r := Checks.skill(A.sheet, "adestramento", 25, world.rules, world.rng, "combat", A.sheet.efeito_bonus_tipo("adestramento_vs", alvo))
	var antes := str(sim.c(alvo).get("atitude", "hostil"))
	if r.get("success", false) and not Atitudes.ORDEM.slice(2).has(antes):
		sim.c(alvo)["atitude"] = "indiferente"
	return [fact("ATTITUDE_CHANGED", {"actor": id, "target": alvo, "from": antes, "to": str(sim.c(alvo).get("atitude", antes)), "check": r, "skill": "adestramento"}, [id, alvo])]


## Fora de combate (SpellsModule): a criatura fica com a atitude `valor` por `ticks` (a cena).
func acalmar_fora(id: String, valor: String, ticks: int) -> void:
	if creature_state.has(id):
		creature_state[id].atitude_temp = {"valor": valor, "ate": world.clock.tick + ticks}


## Fora de combate: Tranquilidade resistida deixa –2 nos ataques pela cena.
func penalizar_fora(id: String, ataque: int, ticks: int) -> void:
	if creature_state.has(id):
		creature_state[id].penalidade_temp = {"ataque": ataque, "ate": world.clock.tick + ticks}


## Acalmar Animal e Tranquilidade: a atitude muda por magia pela cena.
func _pacificar(conj: String, alvo: String, valor: String, fonte: String) -> void:
	sim.add_marca(fonte + "_atitude", alvo, fonte, "atitude", -1, {"valor": valor, "conjurador": conj})


## Santuário: marca do alvo protegido ({} se não tem).
func _santuario_de(alvo: String) -> Dictionary:
	for m in sim.marcas:
		if m.alvo == alvo and m.tipo == "santuario":
			return m
	return {}


## Alvos diretos de uma ação hostil (ataques, Olhar, Arma Espiritual; magia com alvo inimigo).
func _alvos_hostis(id: String, a: Dictionary) -> Array:
	match str(a.get("type", "")):
		"attack", "charge", "coup", "olhar_atordoante", "arma_espiritual":
			return [str(a.get("target", ""))]
		"cast":
			var out: Array = []
			for tg in a.get("targets", [a.get("target", id)]):
				if sim.combatants.has(tg) and sim.is_enemy(id, tg):
					out.append(tg)
			return out
	return []


## Área das magias de área ofensivas (para o Santuário com proteção contra área). [] se a magia não é de área.
func _area_hostil(id: String, a: Dictionary) -> Array:
	if str(a.get("type", "")) != "cast":
		return []
	var apr: Array = a.get("aprimoramentos", [])
	var alvo_t: Vector2i = sim.c(a.get("target", id)).tile if sim.combatants.has(a.get("target", id)) else sim.c(id).tile
	match str(a.get("spell", "")):
		"coluna_de_chamas": return Area.esfera(alvo_t, Area.quadrados(3.0))
		"poeira_da_podridao": return Area.esfera(alvo_t, Area.quadrados(6.0))
		"colera_de_azgher": return Area.esfera(alvo_t, Area.quadrados(12.0 if apr.has(1) else 6.0))
		"despedacar": return Area.esfera(sim.c(id).tile, Area.quadrados(6.0)) if apr.has(5) else []
		"nevoa": return Area.esfera(a.get("tile", alvo_t), Area.quadrados(6.0)) if apr.has(2) or apr.has(3) else []
		"controlar_plantas":
			return Area.quadrado(a.get("tile", alvo_t), Area.quadrados(9.0)) if not a.get("truque", false) and not apr.has(0) and not apr.has(2) else []
	return []


## Santuário: o atacante que não percebe o alvo (aprimoramento) ou já falhou não consegue; senão faz Vontade.
## Na área (aprimoramento de 9 PM): falhou, só tenta de novo se o alvo sair da área.
func _santuario_impede(id: String, a: Dictionary, out: Array) -> bool:
	var checar: Array = []
	for tg in _alvos_hostis(id, a):
		if tg != id and not _santuario_de(tg).is_empty():
			checar.append([tg, false])
	var area := _area_hostil(id, a)
	for tg in _criaturas_vivas_em(area):
		var m := _santuario_de(tg)
		if tg != id and not m.is_empty() and bool(m.dados.area) and not checar.any(func(x): return x[0] == tg):
			checar.append([tg, true])
	for par in checar:
		var tg: String = par[0]
		var em_area: bool = par[1]
		var m := _santuario_de(tg)
		var dados: Dictionary = m.dados
		if not _percebe(id, tg):
			out.append(fact("SANCTUARY_BLOCKED", {"actor": id, "target": tg, "reason": "nao_percebe"}, [id, tg]))
			return true
		if (dados.falharam as Array).has(id):
			out.append(fact("SANCTUARY_BLOCKED", {"actor": id, "target": tg, "reason": "ja_falhou"}, [id, tg]))
			return true
		var fa: Dictionary = dados.falhas_area
		if em_area and fa.has(id) and str(fa[id]) == "%d,%d" % [sim.c(tg).tile.x, sim.c(tg).tile.y]:
			out.append(fact("SANCTUARY_BLOCKED", {"actor": id, "target": tg, "reason": "ja_falhou"}, [id, tg]))
			return true
		var sv := Checks.skill(sim.c(id).sheet, "vontade", int(dados.cd), world.rules, world.rng, "combat")
		sv = _pos_teste(id, sv, int(dados.cd), out)
		if not sv.get("success", false):
			if em_area:
				fa[id] = "%d,%d" % [sim.c(tg).tile.x, sim.c(tg).tile.y]
			else:
				(dados.falharam as Array).append(id)
			out.append(fact("SANCTUARY_BLOCKED", {"actor": id, "target": tg, "reason": "vontade", "check": sv}, [id, tg]))
			return true
	return false


## Santuário, aprimoramento: criaturas não inteligentes (Int –4 ou menos) do tipo escolhido não percebem o alvo.
func _percebe(observador: String, alvo: String) -> bool:
	var m := _santuario_de(alvo)
	if m.is_empty() or str(m.dados.get("tipo_criatura", "")) == "":
		return true
	var s: CharacterSheet = sim.c(observador).sheet
	return not (s.creature_type == str(m.dados.tipo_criatura) and int(s.attrs.get("int", 0)) <= -4)


## O protegido que faz ação hostil (incluindo magia de área ofensiva) dissipa o Santuário. Cura e suporte, não.
func _santuario_quebra(id: String, a: Dictionary, out: Array) -> void:
	if _santuario_de(id).is_empty():
		return
	if _alvos_hostis(id, a).is_empty() and _area_hostil(id, a).is_empty():
		return
	sim.remove_marca("santuario", id)
	out.append(fact("SPELL_ENDED", {"caster": id, "spell": "santuario", "reason": "acao_hostil"}, [id]))


## A IA não mira quem não percebe nem quem já não consegue atacar (Santuário).
func _pode_mirar(id: String, alvo: String) -> bool:
	var m := _santuario_de(alvo)
	if m.is_empty():
		return true
	return _percebe(id, alvo) and not (m.dados.falharam as Array).has(id)


## Controlar Plantas: Reflexos ou fica enredado (e imóvel, com o aprimoramento) enquanto não se libertar.
func _enredar_plantas(tg: String, z: Dictionary, out: Array) -> void:
	if not _marca_presa(tg).is_empty():
		return
	var dados: Dictionary = z.get("dados", {})
	var cd := int(dados.get("cd", 10))
	var sv := Checks.skill(sim.c(tg).sheet, "reflexos", cd, world.rules, world.rng, "combat")
	sv = _pos_teste(tg, sv, cd, out)
	if sv.get("success", false):
		return
	var conds: Array = ["enredado"]
	if bool(dados.get("imovel", false)):
		conds.append("imovel")
	var postas: Array = []
	for cnd in conds:
		if sim.add_condicao(tg, cnd, -1, "controlar_plantas"):
			postas.append(cnd)
	if postas.is_empty():
		return
	sim.add_marca("presa_" + str(z.id), tg, "controlar_plantas", "preso", -1, {"cd": cd, "condicoes": postas, "zona": z.id})
	out.append(fact("BUFF_APPLIED", {"actor": str(dados.get("conjurador", "")), "target": tg, "buff": "enredado", "tags": ["magia", "condicao"]},
		[str(dados.get("conjurador", "")), tg]))


func _marca_presa(id: String) -> Dictionary:
	for m in sim.marcas:
		if m.alvo == id and m.tipo == "preso":
			return m
	return {}


func _soltar(id: String, m: Dictionary) -> void:
	for cnd in m.dados.get("condicoes", []):
		sim.c(id).sheet.remove_condition(str(cnd))
	sim.remove_marca(str(m.id), id)


## Poda (Controlar Plantas, aprimoramento de 1 PM, instantânea): a vegetação da área diminui; terreno difícil vira
## normal e não há camuflagem. Dissipa a versão normal que se sobreponha. A mudança fica no mundo (SpellsModule).
func _podar(area: Array, out: Array) -> void:
	for z in sim.zonas.duplicate(true):
		if str(z.fonte) == "controlar_plantas" and str(z.tipo) == "controlar_plantas" and _alguma_em(z.tiles, area):
			for m in sim.marcas.duplicate(true):
				if m.tipo == "preso" and str(m.dados.get("zona", "")) == str(z.id) and sim.combatants.has(m.alvo):
					_soltar(m.alvo, m)
			sim.remove_zona(str(z.id))
			sim.remove_zona(str(z.id) + "_dificil")
	var podadas: Array = area.filter(func(t): return world.db.is_vegetation(t))
	sim.add_zona("poda_%d" % sim.zonas.size(), podadas, "poda", -1, "controlar_plantas")
	var magia_m = world.module("magia")
	if magia_m != null:
		magia_m.podar(podadas)
	out.append(fact("PLANTS_PRUNED", {"tiles": podadas.size()}, []))


## Arma Espiritual: 2d6 (+1d6 por aprimoramento) do tipo da arma, automaticamente, em `alvo`.
func _golpe_arma_espiritual(dono: String, alvo: String, out: Array) -> void:
	var s: CharacterSheet = sim.c(dono).sheet
	var tipo := ""
	for e in s.efeitos:
		if e.stat == "arma_espiritual":
			tipo = str(e.tipo)
	var ts: CharacterSheet = sim.c(alvo).sheet
	var dano := int(Dice.roll("%dd6" % int(s.efeito_bonus("arma_espiritual_dados")), world.rng, "combat").total)
	dano = _dano_por_tipo(ts, tipo, dano)
	var tags: Array = ["magia", tipo]
	tags.append_array(sim.apply_damage(alvo, dano))
	out.append(fact("ATTACK_RESOLVED", {"attacker": dono, "target": alvo, "weapon": "Arma Espiritual", "d20": 0, "mod": 0,
		"mods": [], "total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [],
		"pv_after": ts.pv, "special": false, "ranged": false, "spell": true, "save": "", "saved": false, "tags": tags}, [dono, alvo]))


## Reação da Arma Espiritual: o alvo de um ataque corpo a corpo contra-ataca com uma arma livre (política
## "arma_espiritual", automática para o jogador).
func _reacao_arma_espiritual(atacante: String, alvo: String, ranged: bool, out: Array) -> void:
	if ranged or sim.c(alvo).is_empty() or sim.c(alvo).sheet.efeito_bonus("arma_espiritual") <= 0:
		return
	if not sim.is_enemy(atacante, alvo) or sim.c(alvo).sheet.is_dead() or sim.c(atacante).sheet.is_dead():
		return
	if not CondicoesCombate.pode_reagir(sim.c(alvo).sheet, world.rules):
		return
	if alvo == "player" and str(power_policy.get("arma_espiritual", "auto")) == "nunca":
		return
	var i := sim.arma_espiritual_livre(alvo)
	if i < 0:
		return
	(sim.c(alvo).flags as Array).append("ae_r%d_%d" % [sim.round_no, i])
	_golpe_arma_espiritual(alvo, atacante, out)


## Luz e Escuridão (universais 1). Ver o cabeçalho de cada ramo; Luz anula Escuridão e Escuridão anula Luz.
func _luz_ou_escuridao(id: String, a: Dictionary) -> Array:
	var out: Array = []
	var sh: CharacterSheet = sim.c(id).sheet
	var apr: Array = a.get("aprimoramentos", [])
	var luz: bool = str(a.spell) == "luz"
	var cd := spell_dc(sh, a)
	var alvo: String = a.get("target", "")
	var alvo_c: bool = sim.combatants.has(alvo) and not a.get("no_chao", false)
	var dur := "permanente" if luz and apr.has(2) else ("dia" if (luz and apr.has(1)) or (not luz and apr.has(3)) else "cena")
	var ate := world.day_index() + 1 if dur == "dia" else -1
	if dur == "permanente" and id == "player":
		out.append(fact("GOLD_CHANGED", {"delta": -50, "reason": "pó de rubi"}))
	# versões em criatura
	if luz and apr.has(3):
		# arcana: nos olhos do alvo; ofuscado pela cena (não afeta cegos). Vontade anula.
		var ts3: CharacterSheet = sim.c(alvo).sheet
		if not ts3.has_effective_condition(world.rules, "cego") and not _resiste(alvo, "vontade", cd, out):
			sim.add_condicao(alvo, "ofuscado", 0, "luz")
		return out
	if luz and apr.has(6):
		# divina: halo de luz no alvo tocado: +10 em Diplomacia e redução de trevas 10.
		var ts6: CharacterSheet = sim.c(alvo).sheet
		ts6.add_efeito("magia.luz", "pericia_diplomacia", 10, "cena")
		ts6.add_efeito("magia.luz", "rd", 10, "cena", "trevas")
		out.append(fact("BUFF_APPLIED", {"actor": id, "target": alvo, "buff": "halo_de_luz", "tags": ["magia"]}, [id, alvo]))
		return out
	if not luz and apr.has(2):
		# nos olhos do alvo: Fortitude parcial; cego pela cena ou, se passar, por 1 rodada.
		var passou := _resiste(alvo, "fortitude", cd, out)
		sim.add_condicao(alvo, "cego", 1 if passou else 0, "escuridao")
		return out
	if not luz and apr.has(4):
		# pessoal: coberto de sombras, +10 em Furtividade e camuflagem leve.
		sh.add_efeito("magia.escuridao", "pericia_furtividade", 10, "cena")
		sh.add_efeito("magia.escuridao", "camuflagem_sombras", 1, "cena")
		out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "sombras", "tags": ["magia"]}, [id]))
		return out
	if luz and apr.has(4):
		# arcana: 4 globos (alcance longo), cada um ilumina como tocha; quem divide o espaço com um fica ofuscado e visível.
		var i := 0
		for q in a.get("tiles", []).slice(0, 4):
			var tq := Vector2i(int(q[0]), int(q[1])) if q is Array else q as Vector2i
			sim.add_zona("globo_%s_%d" % [id, i], [tq], "globo_luz", -1, "luz", {"conjurador": id})
			sim.add_zona("globo_%s_%d_luz" % [id, i], Area.esfera(tq, Area.quadrados(9.0)), "luz", -1, "luz", {"conjurador": id, "magica": true})
			i += 1
		_anular_oposta(true, Area.esfera(sim.c(id).tile, 0), out)
		return out
	var raio := Area.quadrados(6.0 + (3.0 * apr.count(0) if luz else 1.5 * apr.count(0)))
	if alvo_c:
		# objeto carregado por uma criatura (involuntária: Vontade anula)
		if sim.is_enemy(id, alvo) and _resiste(alvo, "vontade", cd, out):
			return out
		var ts: CharacterSheet = sim.c(alvo).sheet
		if luz:
			ts.add_efeito("magia.luz", "fonte_luz", raio, dur, "magica", ate)
			if apr.has(5):
				ts.add_efeito("magia.luz", "fonte_luz_solar", raio, dur, id, ate)
		else:
			ts.add_efeito("magia.escuridao", "fonte_escuridao", raio, dur, "total" if apr.has(1) else "leve", ate)
		_anular_oposta(luz, Area.esfera(sim.c(alvo).tile, raio), out)
	else:
		var centro: Vector2i = a.get("tile", sim.c(id).tile)
		var tiles := Area.esfera(centro, raio)
		if luz:
			sim.add_zona("luz_%d" % sim.zonas.size(), tiles, "luz", -1, "luz", {"conjurador": id, "magica": true, "solar": apr.has(5)})
		else:
			sim.add_zona("escuridao_%d" % sim.zonas.size(), tiles, "escuridao", -1, "escuridao", {"conjurador": id, "total": apr.has(1)})
		_anular_oposta(luz, tiles, out)
	out.append(fact("BUFF_APPLIED", {"actor": id, "target": alvo, "buff": str(a.spell), "tags": ["magia"]}, [id]))
	return out


## Auras mágicas na cena a até `raio` quadrados: efeitos de magia nas criaturas, zonas e marcas de magia. Sem
## `completo`, só presença e intensidade (Misticismo); com, também a magia e onde está (Visão Mística).
func auras_na_cena(centro: Vector2i, raio: int, completo: bool) -> Array:
	var out: Array = []
	var vistos := {}
	for cid in sim.combatants:
		if CombatSim.cheb(sim.c(cid).tile, centro) > raio:
			continue
		for e in sim.c(cid).sheet.efeitos:
			var eid := str(e.id)
			if eid.begins_with("magia.") and not vistos.has(cid + eid):
				vistos[cid + eid] = true
				out.append(_aura(eid.substr(6), cid, sim.c(cid).tile, completo))
	for z in sim.zonas:
		var sp := str(z.fonte)
		if world.rules.value("magia." + sp, {}).is_empty() or not (z.tiles as Array).any(func(t): return CombatSim.cheb(t, centro) <= raio):
			continue
		if not vistos.has(str(z.id)):
			vistos[str(z.id)] = true
			out.append(_aura(sp, "", (z.tiles as Array)[0] if not (z.tiles as Array).is_empty() else centro, completo))
	var magia = world.module("magia")
	if magia != null:
		out.append_array(magia.auras_no_mundo(centro, raio, completo))
	return out


func _aura(sp: String, cid: String, t: Vector2i, completo: bool) -> Dictionary:
	var circ := int(world.rules.value("magia." + sp, {}).get("circulo", 1))
	var a := {"intensidade": SpellRules.aura_por_circulo(circ)}
	if completo:
		a["magia"] = sp
		a["escola"] = str(world.rules.value("magia." + sp, {}).get("escola", ""))
		a["onde"] = [t.x, t.y]
		if cid != "":
			a["criatura"] = cid
	return a


## Compreensão: o que a criatura sabe (os fatos que o diálogo dela pode revelar). Ouvir pensamentos revela um fato
## ainda desconhecido; vasculhar revela todos.
func _revelar_pensamentos(alvo: String, todos: bool) -> Array:
	var magia = world.module("magia")
	var fatos: Array = magia.fatos_que_sabe(alvo) if magia != null else []
	var ex = world.module("exploration")
	var out: Array = []
	for f in fatos:
		if ex != null and ex.knows(f):
			continue
		out.append(fact("FACT_REVEALED", {"fact": f, "source": "pensamentos:" + alvo}, ["player"]))
		if not todos:
			break
	if out.is_empty():
		out.append(fact("THOUGHTS_READ", {"target": alvo, "nada_novo": true}, ["player"]))
	return out


## Teste de resistência com a reação de Premonição; devolve se passou.
## Controlar Madeira (divina 2, LB p.187): alcance médio, cena. Fortalecer: armas +1 passo de dano; escudos +2 na Defesa;
## objetos +5 RD e PV dobrados. Modelar: a arma de madeira vira outra; porta ou baú se molda e abre; parede de madeira
## ganha uma passagem. Repelir: ataques da arma contra você falham; porta ou baú se abre e destranca. Retorcer: arma
## com –5 nos ataques; escudo sem bônus; porta emperrada (Força CD 25). Involuntário: Vontade anula (objeto dele).
## Aprimoramentos: árvore Grande por um dia (atacado, dissipa); vegetação afiada num quadrado de 9m (terreno difícil e
## 1d6 de corte por quadrado percorrido); Enorme; Colossal.
func _controlar_madeira(id: String, a: Dictionary) -> Array:
	var out: Array = []
	var sh: CharacterSheet = sim.c(id).sheet
	var apr: Array = a.get("aprimoramentos", [])
	var dia := world.day_index()
	if apr.has(0):
		sh.add_efeito("magia.controlar_madeira_arvore", "arvore", 1, "dia", "", dia + 1)
		sh.add_efeito("magia.controlar_madeira_arvore", "sobrevivencia_disfarce", 30, "dia", "", dia + 1)
		out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "arvore", "tags": ["magia"]}, [id]))
		return out
	if apr.has(1):
		var centro: Vector2i = a.get("tile", sim.c(id).tile)
		var area := Area.quadrado(centro, Area.quadrados(9.0)).filter(func(t): return world.db.is_vegetation(t))
		sim.add_zona("madeira_afiada_" + id, area, "madeira_afiada", -1, "controlar_madeira", {"conjurador": id})
		sim.add_zona("madeira_afiada_dificil_" + id, area, "terreno_dificil", -1, "controlar_madeira", {"conjurador": id})
		out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "madeira_afiada", "tags": ["magia", "area"]}, [id]))
		return out
	var ef := str(a.get("efeito", ""))
	var objs = world.module("objects")
	match str(a.get("alvo", "")):
		"objeto":
			var oid := str(a.object_id)
			if objs == null:
				return out
			match ef:
				"fortalecer": out.append_array(objs.fortalecer(oid, dia + 1))
				"retorcer": out.append_array(objs.retorcer(oid))
				"repelir", "modelar":
					out.append_array(objs.repelir(oid))
		"parede":
			if objs != null:
				out.append_array(objs.abrir_passagem(a.tile))
		_:
			var tg: String = a.get("target", id)
			var T: CharacterSheet = sim.c(tg).sheet
			if sim.is_enemy(id, tg) and _resiste(tg, "vontade", spell_dc(sh, a), out):
				out.append(fact("SPELL_MISSED", {"caster": id, "target": tg, "spell": "controlar_madeira", "saved": true}, [id, tg]))
				return out
			SpellRules.aplicar_madeira_equip(world.rules, ef, str(a.alvo), T, id, str(a.get("forma", "")))
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg, "buff": "controlar_madeira_" + ef, "tags": ["magia"]}, [id, tg]))
	return out


## Vegetação afiada: 1d6 de corte por quadrado percorrido dentro da área (por cada quadrado em que a criatura entra).
func _dano_vegetacao_afiada(id: String, caminho: Array) -> Array:
	var out: Array = []
	for t in caminho:
		if sim.zona_em(t, "madeira_afiada") and sim.c(id) != null and not sim.c(id).sheet.is_dead():
			out.append_array(_dano_de_energia(str(_conjurador_da_zona(t, "madeira_afiada")), id, "1d6", 0, "", "corte", "Vegetação afiada"))
	return out


func _conjurador_da_zona(t: Vector2i, tipo: String) -> String:
	for z in sim.zonas:
		if str(z.tipo) == tipo and (z.tiles as Array).has(t):
			return str(z.get("dados", {}).get("conjurador", ""))
	return ""


## Tempestade Divina (divina 2): cilindro de 15m de raio em alcance longo, sustentado, só ao ar livre. Vendaval:
## ataques à distância de dentro ou contra quem está dentro sofrem –5, chamas se apagam e névoas se dissipam. Clima
## opcional: chuva (–5 em Percepção), neve (chuva e terreno difícil), granizo (chuva e 1 de impacto no início dos turnos).
## Aprimoramentos: raios (ação padrão, uma vez por rodada, 3d8 de eletricidade, Reflexos metade); +1d8 nos raios
## (repetível); chuva grossa (Médios ou menores ficam lentos; voadores fazem Atletismo por rodada ou caem); granizo
## 2d6; neve com 2d6 de frio no início dos turnos; cilindro de 90m.
const TAMANHOS_LENTOS_CHUVA := ["minusculo", "pequeno", "medio"]


func _tempestade(id: String, a: Dictionary) -> Array:
	var out: Array = []
	var sh: CharacterSheet = sim.c(id).sheet
	var apr: Array = a.get("aprimoramentos", [])
	var clima := str(a.get("clima", ""))
	var area := Area.esfera(a.get("tile", sim.c(id).tile), Area.quadrados(90.0 if apr.has(5) else 15.0))
	var dados := {"conjurador": id, "clima": clima, "cd": spell_dc(sh, a), "raios": (3 + apr.count(1)) if apr.has(0) else 0, "grossa": apr.has(2)}
	if clima == "granizo":
		dados["dano_inicio_turno"] = "2d6" if apr.has(3) else "1"
		dados["tipo_dano"] = "impacto"
	elif clima == "neve" and apr.has(4):
		dados["dano_inicio_turno"] = "2d6"
		dados["tipo_dano"] = "frio"
	sim.add_zona("tempestade_" + id, area, "tempestade", -1, "tempestade_divina", dados)
	if clima == "neve":
		sim.add_zona("tempestade_neve_" + id, area, "terreno_dificil", -1, "tempestade_divina", {"conjurador": id})
	for z in sim.zonas.duplicate(true):   # o vendaval dissipa as névoas
		if str(z.fonte) == "nevoa" and _alguma_em(z.tiles, area):
			sim.remove_zona(str(z.id))
			out.append(fact("SPELL_ENDED", {"spell": "nevoa", "reason": "vendaval"}, []))
	_iniciar_sustentada(id, "tempestade_divina", out)
	_refresh_tempestade()
	out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "tempestade_divina", "clima": clima, "tags": ["magia", "area"]}, [id]))
	return out


## Tempestade: apaga as chamas na área e aplica chuva (–5 em Percepção) e chuva grossa (lentos) a quem está nela.
func _refresh_tempestade() -> void:
	for cid in sim.combatants:
		sim.c(cid).sheet.anular_magia("magia.tempestade_area")
	for z in sim.zonas.duplicate(true):
		if str(z.tipo) != "tempestade":
			continue
		for zz in sim.zonas.duplicate(true):
			var cz: Array = zz.get("dados", {}).get("centro", [])
			if bool(zz.get("dados", {}).get("chama", false)) and cz.size() == 2 and (z.tiles as Array).has(Vector2i(int(cz[0]), int(cz[1]))):
				sim.remove_zona(str(zz.id))
		for cid in sim.ids_em(z.tiles):
			var s: CharacterSheet = sim.c(cid).sheet
			var ref := sim.chama_em(sim.c(cid).tile)
			if ref.begins_with("portador:") or ref.begins_with("em_chamas:"):
				_apagar_chama(ref)
			if str(z.dados.clima) != "":
				s.add_efeito("magia.tempestade_area", "pericia_percepcao", -5, "cena")
			if bool(z.dados.grossa) and TAMANHOS_LENTOS_CHUVA.has(s.size) and not s.conditions.has("lento"):
				s.add_condition("lento", world.rules)
				s.add_efeito("magia.tempestade_area", "condicao", 1, "cena", "lento")


## Chuva grossa: no início do turno de quem voa na tempestade, Atletismo (CD da magia) ou cai ao solo (1d6 de impacto
## da queda; Acrobacia CD 15 evita o dano) e fica caído.
func _voo_na_tempestade(id: String, facts: Array) -> void:
	var x: Dictionary = sim.c(id)
	if not x.sheet.can_fly() or x.sheet.is_down():
		return
	for z in sim.zonas:
		if str(z.tipo) == "tempestade" and bool(z.dados.grossa) and (z.tiles as Array).has(x.tile):
			if _resiste(id, "atletismo", int(z.dados.cd), facts):
				return
			var dano := 0 if _resiste(id, "acrobacia", 15, facts) else int(Dice.roll("1d6", world.rng, "combat").total)
			var tags: Array = ["queda"]
			tags.append_array(sim.apply_damage(id, dano))
			x.sheet.add_condition("caido", world.rules)
			facts.append(fact("HAZARD", {"actor": id, "hazard": "queda_tempestade", "damage": dano, "pv_after": x.sheet.pv, "tags": tags}, [id]))
			return


## Rogar Maldição (divina 2): 1 criatura em alcance curto, sustentada; Fortitude anula. Efeitos à escolha (+1 por
## aprimoramento de 3 PM): debilidade (esmorecido; não se comunica nem lança magias), doença (instantânea: contrai e já
## sofre o primeiro efeito, ver doencas.gd), fraqueza (debilitado e lento), isolamento (perde um sentido: visão, cego;
## audição, surdo; olfato ou paladar, sem faro; tato, caído e sem se levantar). Aprimoramento de 7 PM (4º): permanente,
## Fortitude parcial (passou: sofre a maldição por 1 rodada).
func _rogar_maldicao(id: String, a: Dictionary) -> Array:
	var out: Array = []
	var sh: CharacterSheet = sim.c(id).sheet
	var apr: Array = a.get("aprimoramentos", [])
	var tg: String = a.get("target", "")
	var T: CharacterSheet = sim.c(tg).sheet
	var passou := _resiste(tg, "fortitude", spell_dc(sh, a), out)
	if passou and not apr.has(1):
		out.append(fact("SPELL_MISSED", {"caster": id, "target": tg, "spell": "rogar_maldicao", "saved": true}, [id, tg]))
		return out
	var efeito := "magia.rogar_maldicao_" + id
	var fim := "permanente" if apr.has(1) and not passou else "cena"
	var conds: Array = []
	var extras: Array = []
	for ef in a.get("efeitos", []):
		match str(ef):
			"debilidade":
				conds.append("esmorecido")
				extras.append_array(["bloqueio_magias", "bloqueio_fala"])
			"fraqueza":
				conds.append_array(["debilitado", "lento"])
			"isolamento":
				match str(a.get("sentido", "")):
					"visao": conds.append("cego")
					"audicao": conds.append("surdo")
					"olfato", "paladar": extras.append("sem_faro")
					"tato":
						conds.append("caido")
						extras.append("nao_levanta")
			"doenca":
				for r in Doencas.contrair(T, str(a.get("doenca", "")), true, world.rules, world.rng, "combat", world.day_index()):
					out.append(fact("DISEASE_CONTRACTED", {"actor": id, "target": tg, "doenca": str(a.get("doenca", "")), "efeito": r, "pv_after": T.pv}, [id, tg]))
	for c in conds:
		if T.efeito_bonus("imune", c) <= 0:
			T.add_condition(c, world.rules)
			T.add_efeito(efeito, "condicao", 1, fim, c)
	for x in extras:
		T.add_efeito(efeito, x, 1, fim)
	if passou:
		sim.add_marca("maldicao_%s" % id, tg, "rogar_maldicao", "efeito", 1, {"efeito": efeito})
	elif fim != "permanente" and not (conds.is_empty() and extras.is_empty()):
		_iniciar_sustentada(id, "rogar_maldicao", out)
	out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg, "buff": "rogar_maldicao", "efeitos": a.get("efeitos", []), "permanente": fim == "permanente",
		"tags": ["magia", "maldicao"]}, [id, tg]))
	return out


## Enxame de Pestes (divina 2): enxame Médio num quadrado em alcance médio, sustentado; não ocupa espaço. No fim dos
## turnos do conjurador, 2d12 de corte em quem está no quadrado (Fortitude reduz à metade). Ação de movimento
## ("mover_enxame") leva o enxame 12m. Aprimoramentos: +1d12 (repetível); criaturas maiores (Reflexos, 3d12 de corte,
## impacto ou perfuração); +1 enxame (3º, repetível, em quadrados diferentes); criaturas elementais (Reflexos, 5d12 de
## ácido, eletricidade, fogo ou frio, 4º).
const DANO_ENXAME_MAIOR := ["corte", "impacto", "perfuracao"]
const DANO_ENXAME_ELEMENTAL := ["acido", "eletricidade", "fogo", "frio"]


func _enxame(id: String, a: Dictionary) -> Array:
	var out: Array = []
	var sh: CharacterSheet = sim.c(id).sheet
	var apr: Array = a.get("aprimoramentos", [])
	var base := 5 if apr.has(3) else (3 if apr.has(1) else 2)
	var tipo := "corte"
	if apr.has(3):
		tipo = str(a.get("tipo_dano", "fogo"))
	elif apr.has(1):
		tipo = str(a.get("tipo_dano", "corte"))
	var res := "reflexos" if apr.has(1) or apr.has(3) else "fortitude"
	var quadrados: Array = a.get("tiles", [a.get("tile", sim.c(id).tile)])
	for z in sim.zonas.duplicate(true):
		if str(z.fonte) == "enxame_de_pestes" and str(z.dados.conjurador) == id:
			sim.remove_zona(str(z.id))
	for i in quadrados.size():
		var q = quadrados[i]
		var t: Vector2i = q if q is Vector2i else Vector2i(int(q[0]), int(q[1]))
		sim.add_zona("enxame_%s_%d" % [id, i], [t], "enxame", -1, "enxame_de_pestes",
			{"conjurador": id, "dados": "%dd12" % (base + apr.count(0)), "tipo_dano": tipo, "resistencia": res, "cd": spell_dc(sh, a)})
	_iniciar_sustentada(id, "enxame_de_pestes", out)
	out.append(fact("SPELL_EFFECT", {"caster": id, "spell": "enxame_de_pestes", "efeito": "conjurar", "enxames": quadrados.size()}, [id]))
	return out


## Fim do turno do conjurador: cada enxame dele fere quem está no seu quadrado.
func _enxames_fim_de_turno(id: String, facts: Array) -> void:
	for z in sim.zonas.duplicate(true):
		if str(z.fonte) != "enxame_de_pestes" or str(z.dados.conjurador) != id:
			continue
		for tg in _criaturas_vivas_em(z.tiles):
			var T: CharacterSheet = sim.c(tg).sheet
			var dano := _dados_energia(str(z.dados.dados), str(z.dados.tipo_dano), sim.c(tg).tile)
			var passou := _resiste(tg, str(z.dados.resistencia), int(z.dados.cd), facts)
			if passou:
				dano = dano / 2
			dano = _dano_por_tipo(T, str(z.dados.tipo_dano), dano)
			var tags: Array = ["magia", str(z.dados.tipo_dano)]
			if passou:
				tags.append("resistiu")
			tags.append_array(sim.apply_damage(tg, dano))
			facts.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": "Enxame de Pestes", "d20": 0, "mod": 0, "mods": [], "total": 0,
				"defense": int(z.dados.cd), "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [], "pv_after": T.pv, "special": false,
				"ranged": true, "spell": true, "save": str(z.dados.resistencia), "saved": passou, "tags": tags}, [id, tg]))


## Miasma Mefítico (divina 2): nuvem de 6m de raio em alcance médio; 5d6 de ácido e enjoado por 1 rodada, Fortitude
## reduz à metade e evita o enjoo. Aprimoramentos: +1d6 (repetível); dano de trevas. Truque (pó de ônix, T$ 10): toque
## numa criatura com 0 PV ou menos; Fortitude anula — falhou, morre e o conjurador tem +2 na CD das magias por um dia;
## passou, fica imune ao truque por um dia.
func _miasma(id: String, a: Dictionary) -> Array:
	var out: Array = []
	var sh: CharacterSheet = sim.c(id).sheet
	var cd := spell_dc(sh, a)
	if a.get("truque", false):
		var tg: String = a.get("target", "")
		var T: CharacterSheet = sim.c(tg).sheet
		if id == "player":
			out.append(fact("GOLD_CHANGED", {"delta": -SpellRules.PO_DE_ONIX, "reason": "pó de ônix do Miasma"}))
		if _resiste(tg, "fortitude", cd, out):
			T.add_efeito("magia.miasma_mefitico", "imune", 1, "dia", "miasma_truque", world.day_index() + 1)
			out.append(fact("SPELL_MISSED", {"caster": id, "target": tg, "spell": "miasma_mefitico", "saved": true}, [id, tg]))
			return out
		var tags: Array = ["magia", "trevas"]
		tags.append_array(sim.apply_damage(tg, maxi(0, T.pv - T.death_threshold())))
		sh.remove_efeito("magia.miasma_mefitico_cd")
		sh.add_efeito("magia.miasma_mefitico_cd", "cd_magias", 2, "dia", "", world.day_index() + 1)
		out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": "Miasma Mefítico", "d20": 0, "mod": 0, "mods": [], "total": 0,
			"defense": cd, "camo_roll": 0, "hit": true, "crit": false, "damage": 0, "rolls": [], "pv_after": T.pv, "special": false,
			"ranged": false, "spell": true, "save": "fortitude", "saved": false, "tags": tags}, [id, tg]))
		return out
	var apr: Array = a.get("aprimoramentos", [])
	var tipo := "trevas" if apr.has(1) else "acido"
	var centro: Vector2i = a.get("tile", sim.c(a.get("target", id)).tile)
	for tg in _criaturas_vivas_em(Area.esfera(centro, Area.quadrados(6.0))):
		var T: CharacterSheet = sim.c(tg).sheet
		var dano := _dados_energia("%dd6" % (5 + apr.count(0)), tipo, sim.c(tg).tile)
		var passou := _resiste(tg, "fortitude", cd, out)
		if passou:
			dano = dano / 2
		dano = _dano_por_tipo(T, tipo, dano)
		var tags: Array = ["magia", tipo]
		if passou:
			tags.append("resistiu")
		tags.append_array(sim.apply_damage(tg, dano))
		if not passou and sim.add_condicao(tg, "enjoado", 1, "miasma_mefitico"):
			tags.append("enjoado")
		out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": "Miasma Mefítico", "d20": 0, "mod": 0, "mods": [], "total": 0,
			"defense": cd, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [], "pv_after": T.pv, "special": false,
			"ranged": true, "spell": true, "save": "fortitude", "saved": passou, "tags": tags}, [id, tg]))
	return out


## Controlar Fogo (divina 2, LB p.186): alcance curto, pela cena. Chamejar: armas escolhidas causam +1d6 de fogo
## (também armas naturais e ataques desarmados). Esquentar: um objeto que alguém segura ou veste causa 1d6 de fogo por
## rodada a ele (ação completa "resfriar" cancela). Extinguir: apaga uma chama e deixa uma nuvem de fumaça de 3m
## (camuflagem leve). Modelar: a chama se move 9m por rodada (ação livre "mover_chama"), 2d6 de fogo em quem ela
## atravessa (uma vez por rodada cada). Aprimoramentos: labaredas (sustentada; ação de movimento "labareda", 4d6,
## Reflexos reduz à metade); +1d6 (exceto chamejar); criatura de fogo (Fortitude parcial: 0 PV ou 5d6).
func _controlar_fogo(id: String, a: Dictionary) -> Array:
	var out: Array = []
	var sh: CharacterSheet = sim.c(id).sheet
	var apr: Array = a.get("aprimoramentos", [])
	var mais := apr.count(1)
	var cd := spell_dc(sh, a)
	if apr.has(2):
		var tg: String = a.get("target", "")
		if _resiste(tg, "fortitude", cd, out):
			out.append_array(_dano_de_fogo(id, tg, "%dd6" % (5 + mais), 0, "", "Controlar Fogo"))
		else:
			var T: CharacterSheet = sim.c(tg).sheet
			var tags: Array = ["magia", "fogo"]
			tags.append_array(sim.apply_damage(tg, maxi(0, T.pv)))
			out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": "Controlar Fogo", "d20": 0, "mod": 0, "mods": [], "total": 0,
				"defense": cd, "camo_roll": 0, "hit": true, "crit": false, "damage": 0, "rolls": [], "pv_after": T.pv, "special": false,
				"ranged": true, "spell": true, "save": "fortitude", "saved": false, "tags": tags}, [id, tg]))
		return out
	var ef := "labaredas" if apr.has(0) else str(a.get("efeito", ""))
	match ef:
		"chamejar":
			for tg in a.get("targets", [a.get("target", "")]):
				var ts: CharacterSheet = sim.c(tg).sheet
				ts.add_efeito("magia.controlar_fogo", "dano_elemental", 1, "cena", str(ts.equipment.get("weapon", "")) + "|fogo")
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg, "buff": "chamejar", "tags": ["magia", "fogo"]}, [id, tg]))
		"esquentar":
			var tg_e: String = a.get("target", "")
			sim.add_marca("esquentar_%s" % id, tg_e, "controlar_fogo", "esquentar", -1, {"dano_inicio_turno": "%dd6" % (1 + mais), "tipo_dano": "fogo",
				"conjurador": id, "objeto": str(a.get("objeto", "arma"))})
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg_e, "buff": "esquentar", "tags": ["magia", "fogo"]}, [id, tg_e]))
		"extinguir":
			var t: Vector2i = a.tile
			_apagar_chama(sim.chama_em(t))
			sim.add_zona("fumaca_leve_%d" % sim.zonas.size(), Area.esfera(t, Area.quadrados(3.0)), "fumaca_leve", -1, "controlar_fogo")
			out.append(fact("SPELL_EFFECT", {"caster": id, "spell": "controlar_fogo", "efeito": "extinguir", "tile": [t.x, t.y]}, [id]))
		"modelar":
			var t2: Vector2i = a.tile
			_apagar_chama(sim.chama_em(t2))
			sim.add_zona("chama_modelada_%s" % id, Area.esfera(t2, Area.quadrados(9.0)), "luz", -1, "controlar_fogo",
				{"chama": true, "centro": [t2.x, t2.y], "conjurador": id, "dados": "%dd6" % (2 + mais)})
			out.append(fact("SPELL_EFFECT", {"caster": id, "spell": "controlar_fogo", "efeito": "modelar", "tile": [t2.x, t2.y]}, [id]))
		"labaredas":
			var ref := sim.chama_em(a.tile)
			sim.add_marca("labaredas_%s" % id, id, "controlar_fogo", "labaredas", -1, {"chama": ref, "dados": 4 + mais, "cd": cd})
			_iniciar_sustentada(id, "controlar_fogo", out)
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "labaredas", "tags": ["magia", "fogo"]}, [id]))
	return out


## Tira a chama de onde está (zona de fogo, tocha ou chama na palma, criatura em chamas).
func _apagar_chama(ref: String) -> void:
	var cid := ref.get_slice(":", 1)
	if ref.begins_with("zona:"):
		sim.remove_zona(cid)
	elif ref.begins_with("portador:"):
		for e in sim.c(cid).sheet.efeitos.duplicate(true):
			if e.stat == "fonte_luz" and CombatSim.CHAMAS_CARREGADAS.has(str(e.id)):
				sim.c(cid).sheet.remove_efeito(str(e.id))
	elif ref.begins_with("em_chamas:"):
		sim.c(cid).sheet.remove_condition("em_chamas")


## Modelar: a chama vai até `para`; quem está no caminho (ou no destino) sofre o dano, uma vez por rodada.
func _mover_chama(id: String, para: Vector2i) -> Array:
	var out: Array = []
	var z: Dictionary = sim.zonas.filter(func(zz): return str(zz.id) == "chama_modelada_" + id)[0]
	var de := Vector2i(int(z.dados.centro[0]), int(z.dados.centro[1]))
	var caminho: Array = CombatSim.tiles_entre(de, para)
	caminho.append(para)
	var dados := str(z.dados.dados)
	sim.add_zona(str(z.id), Area.esfera(para, Area.quadrados(9.0)), "luz", -1, "controlar_fogo",
		{"chama": true, "centro": [para.x, para.y], "conjurador": id, "dados": dados})
	for t in caminho:
		var tg := sim.occupant(t)
		if tg == "" or tg == id or (sim.c(tg).flags as Array).has("chama_queimou_%d" % sim.round_no):
			continue
		(sim.c(tg).flags as Array).append("chama_queimou_%d" % sim.round_no)
		out.append_array(_dano_de_fogo(id, tg, dados, 0, "", "Controlar Fogo"))
	return out


## Dano de fogo de magia num alvo; com `pericia`, o teste reduz à metade.
func _dano_de_fogo(id: String, tg: String, dados: String, cd: int, pericia: String, nome: String) -> Array:
	return _dano_de_energia(id, tg, dados, cd, pericia, "fogo", nome)


## Dano de magia de um tipo num alvo; com `pericia`, o teste reduz à metade.
func _dano_de_energia(id: String, tg: String, dados: String, cd: int, pericia: String, tipo: String, nome: String) -> Array:
	var out: Array = []
	var T: CharacterSheet = sim.c(tg).sheet
	var dano := _dados_energia(dados, tipo, sim.c(tg).tile)
	var passou := false
	if pericia != "":
		passou = _resiste(tg, pericia, cd, out)
		if passou:
			dano = dano / 2
	dano = _dano_por_tipo(T, tipo, dano)
	var tags: Array = ["magia", tipo]
	if passou: tags.append("resistiu")
	tags.append_array(sim.apply_damage(tg, dano))
	out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": nome, "d20": 0, "mod": 0, "mods": [], "total": 0,
		"defense": cd, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [], "pv_after": T.pv, "special": false,
		"ranged": true, "spell": true, "save": pericia, "saved": passou, "tags": tags}, [id, tg]))
	return out


## Condição: posição e status de cada alvo da magia que o conjurador acompanha (morto ou fora do plano: some).
func status_conhecidos(id: String) -> Array:
	var out: Array = []
	var C := sim.c(id)
	if C.is_empty():
		return out
	for e in C.sheet.efeitos:
		var tg := str(e.tipo)
		if e.stat == "condicao" and sim.combatants.has(tg) and not sim.c(tg).sheet.is_dead():
			out.append(SpellRules.status_de(tg, sim.c(tg).sheet, sim.c(tg).tile))
	return out


## Soco de Arsenal (divina 2, LB p.206): 4d6 + Força de impacto em alcance médio e empurrão de 3m para longe do
## conjurador; Fortitude reduz à metade e evita o empurrão. Aprimoramentos: pessoal, pela cena o alcance natural
## corpo a corpo aumenta 3m (1 PM); +1d6 (2 PM, repetível); +3m de empurrão (4 PM, repetível); dano de essência (5 PM).
func _soco_de_arsenal(id: String, a: Dictionary) -> Array:
	var out: Array = []
	var sh: CharacterSheet = sim.c(id).sheet
	var apr: Array = a.get("aprimoramentos", [])
	if apr.has(0):
		sh.add_efeito("magia.soco_de_arsenal", "alcance_corpo", Area.quadrados(3.0), "cena")
		out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "soco_de_arsenal", "tags": ["magia"]}, [id]))
		return out
	var tgt: String = a.get("target", "")
	var T: CharacterSheet = sim.c(tgt).sheet
	var cd := spell_dc(sh, a)
	var sv := Checks.skill(T, "fortitude", cd, world.rules, world.rng, "combat")
	sv = _pos_teste(tgt, sv, cd, out)
	var passou: bool = sv.get("success", false)
	var r := Dice.roll("%dd6" % (4 + apr.count(1)), world.rng, "combat", 1, int(sh.attrs["for"]) + battle_bonus(sh))
	var tipo := "essencia" if apr.has(3) else "impacto"
	var dmg := maxi(0, int(r.total))
	if passou:
		dmg = maxi(1, dmg / 2)
	dmg = _dano_por_tipo(T, tipo, dmg)
	var tags: Array = ["magia", tipo]
	if passou: tags.append("resistiu")
	tags.append_array(sim.apply_damage(tgt, dmg))
	out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tgt, "weapon": "Soco de Arsenal", "d20": int(sv.get("d20", 0)), "mod": int(sv.get("mod", 0)),
		"mods": [], "total": int(sv.get("total", 0)), "defense": cd, "camo_roll": 0, "hit": true, "crit": false, "damage": dmg, "rolls": r.rolls,
		"pv_after": T.pv, "special": false, "ranged": true, "spell": true, "save": "fortitude", "saved": passou, "tags": tags}, [id, tgt]))
	if not passou and not T.is_dead():
		var from: Vector2i = sim.c(tgt).tile
		var caminho := sim.empurrar(tgt, sim.c(id).tile, Area.quadrados(3.0) * (1 + apr.count(2)))
		if not caminho.is_empty():
			out.append(fact("COMBAT_MOVED", {"actor": tgt, "from": [from.x, from.y], "path": caminho.map(func(t): return [t.x, t.y]), "forced": true}, [tgt]))
	return out


## Imunidade a condições de certos tipos (Heroísmo: medo; Proteção Divina: medo e mental) pela duração da magia.
func _imune_condicoes(ts: CharacterSheet, id_magia: String, tipos: Array, fim: String) -> void:
	var tabela: Dictionary = world.rules.value("condicoes", {})
	for cond in tabela.keys():
		if not tabela[cond] is Dictionary:
			continue   # "_regra" é texto, não condição
		if tipos.has(str((tabela[cond] as Dictionary).get("tipo", ""))):
			ts.add_efeito(id_magia, "imune", 1, fim, str(cond))


## Inimigo de maior ND do conjurador (Heroísmo). "" se não há inimigos na cena.
func _inimigo_de_maior_nd(id: String) -> String:
	var melhor := ""
	var nd_melhor := -1.0
	for x in sim.combatants:
		if not sim.is_enemy(id, x) or sim.c(x).sheet.is_dead():
			continue
		var nd_x := ProgressionModule.nd_value(world.rules.value(sim.c(x).sheet.source_rule, {}).get("nd", "0"))
		if nd_x > nd_melhor:
			nd_melhor = nd_x
			melhor = x
	return melhor


## Próximo tamanho (Potência Divina): uma categoria acima, até Colossal.
static func _tamanho_acima(tam: String) -> String:
	var ordem := ["minusculo", "pequeno", "medio", "grande", "enorme", "colossal"]
	var i := ordem.find(tam)
	return ordem[mini(i + 1, ordem.size() - 1)] if i >= 0 else tam


## Sp (id sem "magia.") de um efeito ou fonte de zona/marca, se for magia do catálogo; "" caso contrário.
func _sp_de_fonte(eid: String) -> String:
	if not eid.begins_with("magia."):
		return ""
	var sp := eid.trim_prefix("magia.")
	if sp.begins_with("rogar_maldicao_"):
		return "rogar_maldicao"
	return sp if not world.rules.value("magia." + sp, {}).is_empty() else ""


func _circulo_ate(sp: String, circ_max: int) -> bool:
	return int(world.rules.value("magia." + sp, {}).get("circulo", 99)) <= circ_max


## Remove, sem teste, magias de um tipo que estão na área (Dispersar anula Anular a Luz e vice-versa).
func _remover_magia_sem_teste(sp: String, tiles: Array, out: Array) -> void:
	for cid in sim.combatants:
		if tiles.has(sim.c(cid).tile) and sim.c(cid).sheet.has_efeito("magia." + sp):
			sim.c(cid).sheet.anular_magia("magia." + sp)
			out.append(fact("SPELL_ENDED", {"spell": sp, "target": cid, "reason": "anulada"}, [cid]))
	for z in sim.zonas.duplicate(true):
		if str(z.fonte) == sp and _alguma_em(z.tiles, tiles):
			sim.remove_zona(str(z.id))
	for m in sim.marcas.duplicate(true):
		if str(m.fonte) == sp and tiles.has(sim.c(m.alvo).tile):
			sim.remove_marca(str(m.id), str(m.alvo))


## Dissipação (Dispersar / Anular a Luz): cada magia de até `circ_max` na área faz um teste de Religião do conjurador
## contra a CD da própria magia (CD de quem a lançou, se ainda estiver na cena; senão a de quem dissipa).
func _dispersar_magias(caster: String, tiles: Array, circ_max: int, out: Array) -> void:
	var csh: CharacterSheet = sim.c(caster).sheet
	for cand in _candidatos_dissipar(tiles, circ_max):
		var cd := _cd_da_magia(csh, cand)
		var r := Checks.skill(csh, "religiao", cd, world.rules, world.rng, "combat")
		if not r.get("success", false):
			continue
		_encerrar_magia_dissipada(cand, out)
		out.append(fact("SPELL_ENDED", {"caster": caster, "spell": cand.sp, "reason": "dissipada", "cd": cd, "d20": int(r.get("d20", 0)), "total": int(r.get("total", 0))}, [caster]))


## Dissipar Magia (universal 2): um teste de Misticismo; dissipa as magias com CD igual ou menor que o resultado.
## `auto` (disjunção, 5º círculo): todas as magias da área caem, sem teste.
func _dissipar_magia(caster: String, tiles: Array, auto: bool, out: Array) -> void:
	var csh: CharacterSheet = sim.c(caster).sheet
	var total := 0
	if not auto:
		var r := Checks.skill(csh, "misticismo", 0, world.rules, world.rng, "combat")
		total = int(r.get("total", 0))
	for cand in _candidatos_dissipar(tiles, 99):
		var cd := _cd_da_magia(csh, cand)
		if not auto and total < cd:
			continue
		_encerrar_magia_dissipada(cand, out)
		out.append(fact("SPELL_ENDED", {"caster": caster, "spell": cand.sp, "reason": "dissipada", "cd": cd, "total": total}, [caster]))


## CD da magia candidata: a de quem a lançou, se ainda está na cena; senão a de quem dissipa.
func _cd_da_magia(csh: CharacterSheet, cand: Dictionary) -> int:
	var conj_sh: CharacterSheet = sim.c(cand.conj).sheet if sim.combatants.has(cand.conj) else csh
	return spell_dc(conj_sh, {"spell": cand.sp})


## Magias ativas (efeitos, zonas e marcas) de até `circ_max` dentro dos tiles.
func _candidatos_dissipar(tiles: Array, circ_max: int) -> Array:
	var candidatos: Array = []
	var vistos := {}
	for cid in sim.combatants:
		if not tiles.has(sim.c(cid).tile):
			continue
		for e in sim.c(cid).sheet.efeitos.duplicate(true):
			var sp := _sp_de_fonte(str(e.id))
			if sp == "" or not _circulo_ate(sp, circ_max) or vistos.has(sp + "@" + cid):
				continue
			vistos[sp + "@" + cid] = true
			candidatos.append({"sp": sp, "kind": "efeito", "id": "", "alvo": cid, "conj": str(e.get("conj", ""))})
	for z in sim.zonas.duplicate(true):
		var sp_z := _sp_de_fonte("magia." + str(z.fonte))
		if sp_z != "" and _circulo_ate(sp_z, circ_max) and _alguma_em(z.tiles, tiles):
			candidatos.append({"sp": sp_z, "kind": "zona", "id": str(z.id), "alvo": "", "conj": str((z.get("dados", {}) as Dictionary).get("conjurador", ""))})
	for m in sim.marcas.duplicate(true):
		var sp_m := _sp_de_fonte("magia." + str(m.fonte))
		if sp_m != "" and _circulo_ate(sp_m, circ_max) and tiles.has(sim.c(m.alvo).tile):
			candidatos.append({"sp": sp_m, "kind": "marca", "id": str(m.id), "alvo": str(m.alvo), "conj": str((m.get("dados", {}) as Dictionary).get("conjurador", ""))})
	return candidatos


func _encerrar_magia_dissipada(cand: Dictionary, out: Array) -> void:
	match str(cand.kind):
		"efeito":
			var dono := str(cand.conj) if str(cand.conj) != "" else str(cand.alvo)
			if str(sim.sustentadas.get(dono, "")) == str(cand.sp):
				_encerrar_sustentada(dono, out)
			sim.c(str(cand.alvo)).sheet.anular_magia("magia." + str(cand.sp))
		"zona":
			sim.remove_zona(str(cand.id))
		"marca":
			sim.remove_marca(str(cand.id), str(cand.alvo))


## Efeitos da Fúria do Panteão sobre os inimigos na nuvem. Nevasca: 10d6 de frio (Fortitude metade) e neve (terreno difícil).
## Raios: até 6 inimigos, 10d8 de eletricidade (Reflexos metade). Siroco: 10d6 metade corte, metade fogo, e sangrando
## (Fortitude metade e evita), derrete a neve. Trovões: 10d6 de impacto e desprevenido 1 rodada (Fortitude metade e evita).
func _efeito_furia(id: String, efeito: String, escolhidos: Array) -> Array:
	var out: Array = []
	(sim.c(id).flags as Array).append("furia_%d" % sim.round_no)
	var zona: Dictionary = sim.zonas.filter(func(z): return str(z.id) == "furia_" + id)[0]
	var cd := int(zona.dados.cd)
	var alvos: Array = []
	for x in sim.combatants:
		if sim.is_enemy(id, x) and not sim.c(x).sheet.is_dead() and (zona.tiles as Array).has(sim.c(x).tile):
			alvos.append(x)
	match efeito:
		"nevasca":
			for tg in alvos:
				out.append_array(_dano_de_energia(id, tg, "10d6", cd, "fortitude", "frio", "Nevasca"))
			sim.remove_zona("furia_neve_" + id)
			sim.add_zona("furia_neve_" + id, zona.tiles, "terreno_dificil", -1, "furia_do_panteao", {"conjurador": id})
		"raios":
			var lista: Array = escolhidos.filter(func(x): return alvos.has(x)) if not escolhidos.is_empty() else alvos
			for tg in lista.slice(0, 6):
				out.append_array(_dano_de_energia(id, tg, "10d8", cd, "reflexos", "eletricidade", "Raios"))
		"siroco":
			sim.remove_zona("furia_neve_" + id)
			for tg in alvos:
				var ts: CharacterSheet = sim.c(tg).sheet
				var passou := _resiste(tg, "fortitude", cd, out)
				var total := int(Dice.roll("10d6", world.rng, "combat").total)
				if passou:
					total = total / 2
				var corte := _dano_por_tipo(ts, "corte", total / 2)
				var fogo := _dano_por_tipo(ts, "fogo", total - total / 2)
				var tags: Array = ["magia", "corte", "fogo"]
				tags.append_array(sim.apply_damage(tg, corte + fogo))
				if not passou:
					sim.add_condicao(tg, "sangrando", 0, "furia_do_panteao")
				out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": "Siroco", "d20": 0, "mod": 0, "mods": [], "total": 0, "defense": cd, "camo_roll": 0,
					"hit": true, "crit": false, "damage": corte + fogo, "rolls": [], "pv_after": ts.pv, "special": false, "ranged": true, "spell": true, "save": "fortitude", "saved": passou, "tags": tags}, [id, tg]))
		"trovoes":
			for tg in alvos:
				var ts_t: CharacterSheet = sim.c(tg).sheet
				var passou_t := _resiste(tg, "fortitude", cd, out)
				var dano_t := int(Dice.roll("10d6", world.rng, "combat").total)
				if passou_t:
					dano_t = dano_t / 2
				dano_t = _dano_por_tipo(ts_t, "impacto", dano_t)
				var tags_t: Array = ["magia", "impacto"]
				tags_t.append_array(sim.apply_damage(tg, dano_t))
				if not passou_t:
					sim.add_condicao(tg, "desprevenido", 1, "furia_do_panteao")
				out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": "Trovões", "d20": 0, "mod": 0, "mods": [], "total": 0, "defense": cd, "camo_roll": 0,
					"hit": true, "crit": false, "damage": dano_t, "rolls": [], "pv_after": ts_t.pv, "special": false, "ranged": true, "spell": true, "save": "fortitude", "saved": passou_t, "tags": tags_t}, [id, tg]))
	return out


## Mortos-vivos conjurados (Conjurar Mortos-Vivos) ainda de pé que obedecem a `dono`.
func _capangas_de(dono: String) -> Array:
	var r: Array = []
	for cid in sim.combatants:
		if (sim.c(cid).flags as Array).has("capanga_de_" + dono) and not sim.c(cid).sheet.is_dead():
			r.append(cid)
	return r


## Imunidades dos capangas: atordoamento, cansaço, doença, encantamento, paralisia, veneno, frio.
func _imunidades_capanga(sh: CharacterSheet) -> void:
	for cond in ["atordoado", "exausto", "fatigado", "doente", "enfeiticado", "fascinado", "paralisado", "envenenado"]:
		sh.add_efeito("capanga", "imune", 1, "cena", cond)
	for tipo in ["frio", "veneno"]:
		sh.add_efeito("capanga", "imune", 1, "cena", tipo)


## Golpe de um morto-vivo conjurado: fere um inimigo adjacente (o preferido, se estiver ao lado). Esqueleto 1d6+2 de trevas;
## carniçal 1d8+3, perda de 1d8 PV por veneno e Fortitude ou paralisado 1 rodada (imune por um dia); sombra 2d10 e
## Fortitude ou perde 1d4 PM (só vivos). A CD é a do conjurador.
func _golpe_capanga(dono: String, cid: String, preferido: String) -> Array:
	var out: Array = []
	var alvo := ""
	for x in sim.combatants:
		if sim.is_enemy(cid, x) and not sim.c(x).sheet.is_dead() and CombatSim.cheb(sim.c(cid).tile, sim.c(x).tile) <= 1:
			if alvo == "" or x == preferido:
				alvo = x
	if alvo == "":
		return out
	var tipo_cp := str(sim.c(cid).sheet.source_rule)
	var expr := "1d6+2"
	if tipo_cp.ends_with("carnical_capanga"):
		expr = "1d8+3"
	elif tipo_cp.ends_with("sombra_capanga"):
		expr = "2d10"
	var ts: CharacterSheet = sim.c(alvo).sheet
	var r := Dice.roll(expr, world.rng, "combat", 1)
	var dano := _dano_por_tipo(ts, "trevas", int(r.total))
	var tags: Array = ["magia", "trevas"]
	tags.append_array(sim.apply_damage(alvo, dano))
	out.append(fact("ATTACK_RESOLVED", {"attacker": cid, "target": alvo, "weapon": str(sim.c(cid).sheet.name), "d20": 0, "mod": 0, "mods": [], "total": 0,
		"defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": r.rolls, "pv_after": ts.pv, "special": false, "ranged": false,
		"spell": true, "tags": tags}, [dono, alvo]))
	var cd := spell_dc(sim.c(dono).sheet, {"spell": "conjurar_mortos_vivos"})
	if tipo_cp.ends_with("carnical_capanga") and not ts.is_dead():
		var perda := int(Dice.roll("1d8", world.rng, "combat").total)
		ts.pv -= perda
		ts.pv_perdido_veneno += perda
		if ts.efeito_bonus("imune_carnical") == 0:
			if _resiste(alvo, "fortitude", cd, out):
				ts.add_efeito("carnical", "imune_carnical", 1, "dia", "", world.day_index() + 1)   # passou: imune por um dia
			else:
				sim.add_condicao(alvo, "paralisado", 1, "carnical")
	elif tipo_cp.ends_with("sombra_capanga") and ts.creature_type != "morto-vivo" and ts.creature_type != "construto" and not ts.is_dead():
		if not _resiste(alvo, "fortitude", cd, out):
			ts.pm = maxi(0, ts.pm - int(Dice.roll("1d4", world.rng, "combat").total))
	return out


func _resiste(alvo: String, pericia: String, cd: int, out: Array) -> bool:
	var sv := Checks.skill(sim.c(alvo).sheet, pericia, cd, world.rules, world.rng, "combat")
	sv = _pos_teste(alvo, sv, cd, out)
	return sv.get("success", false)


## Luz anula Escuridão (e vice-versa): a magia oposta que se sobrepõe à área nova se dissipa.
func _anular_oposta(luz: bool, area: Array, out: Array) -> void:
	var tipo_z := "escuridao" if luz else "luz"
	for z in sim.zonas.duplicate(true):
		if str(z.tipo) == tipo_z and str(z.fonte) == tipo_z and _alguma_em(z.tiles, area):
			sim.remove_zona(str(z.id))
			out.append(fact("SPELL_ENDED", {"spell": tipo_z, "reason": "anulada"}, []))
	var stat := "fonte_escuridao" if luz else "fonte_luz"
	for cid in sim.combatants:
		var s: CharacterSheet = sim.c(cid).sheet
		for e in s.efeitos.duplicate():
			if e.stat == stat and str(e.id) == "magia." + tipo_z and _alguma_em(Area.esfera(sim.c(cid).tile, int(e.bonus)), area):
				s.remove_efeito("magia." + tipo_z)
				out.append(fact("SPELL_ENDED", {"spell": tipo_z, "target": cid, "reason": "anulada"}, [cid]))
				break


## Luz cálida (aprimoramento divino) no início do turno: aliados do conjurador na luz estabilizam e ficam imunes a
## sangrando; inimigos ficam ofuscados (e quem tem sensibilidade a luz sofre como sob o sol).
func _luz_solar(id: String, facts: Array) -> void:
	var x: Dictionary = sim.c(id)
	var conj := ""
	for z in sim.zonas:
		if str(z.tipo) == "luz" and bool(z.get("dados", {}).get("solar", false)) and (z.tiles as Array).has(x.tile):
			conj = str(z.dados.conjurador)
	for cid in sim.combatants:
		for e in sim.c(cid).sheet.efeitos:
			if e.stat == "fonte_luz_solar" and CombatSim.cheb(sim.c(cid).tile, x.tile) <= int(e.bonus) and sim.c(cid).sheet.efeito_bonus("fonte_oculta") <= 0:
				conj = str(e.tipo)
	if conj == "" or not sim.combatants.has(conj):
		return
	var s: CharacterSheet = x.sheet
	if not sim.is_enemy(conj, id):
		s.add_efeito("magia.luz", "imune", 1, "rodada", "sangrando")
		s.remove_condition("sangrando")
		if s.is_down():
			s.stable = true
	else:
		sim.add_condicao(id, "ofuscado", 1, "luz")
		facts.append(fact("BUFF_APPLIED", {"actor": conj, "target": id, "buff": "ofuscado", "tags": ["magia", "luz"]}, [conj, id]))


func _criar_elementos(id: String, a: Dictionary) -> Array:
	var out: Array = []
	var sh: CharacterSheet = sim.c(id).sheet
	var apr: Array = a.get("aprimoramentos", [])
	var el := str(a.get("elemento", "fogo"))
	var tiles: Array = []
	for q in a.get("tiles", []):
		tiles.append(Vector2i(int(q[0]), int(q[1])) if q is Array else q as Vector2i)
	var cd := spell_dc(sh, a)
	if apr.has(1):
		# arremesso: 2d4 de impacto, um passo a mais por categoria de tamanho acima de Minúsculo
		var dano_expr := CombatSim.dano_em_passos(world.rules, "2d4", apr.count(0))
		for tg in a.get("targets", [a.get("target", "")]):
			if not sim.combatants.has(tg):
				continue
			var ts: CharacterSheet = sim.c(tg).sheet
			var sv := Checks.skill(ts, "reflexos", cd, world.rules, world.rng, "combat")
			sv = _pos_teste(tg, sv, cd, out)
			var dano := int(Dice.roll(dano_expr, world.rng, "combat").total)
			if sv.get("success", false):
				dano /= 2
			dano = _dano_por_tipo(ts, "impacto", dano)
			var tags: Array = ["magia", "impacto"]
			tags.append_array(sim.apply_damage(tg, dano))
			out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": "Criar Elementos", "d20": 0, "mod": 0, "mods": [], "total": 0,
				"defense": cd, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [], "pv_after": ts.pv, "special": false,
				"ranged": true, "spell": true, "save": "reflexos", "saved": sv.get("success", false), "tags": tags}, [id, tg]))
		if a.has("objeto"):
			var objs = world.module("objects")
			if objs != null:
				out.append_array(objs.danificar(str(a.objeto), int(Dice.roll(dano_expr, world.rng, "combat").total), false, "criar_elementos"))
		return out
	match el:
		"agua":
			out.append(fact("ITEM_GAINED", {"item": "frasco_agua", "from": "criar_elementos"}, [id]))
		"terra":
			out.append(fact("ELEMENT_CREATED", {"caster": id, "elemento": "terra"}, [id]))
		"ar":
			for t in tiles:
				for z in sim.zonas:
					if str(z.tipo) == "fumaca":
						z.tiles = (z.tiles as Array).filter(func(x): return x != t)   # o vento purifica gás e fumaça
			sim.add_zona("vento_%d" % sim.zonas.size(), tiles, "vento", 1, "criar_elementos")
			out.append(fact("ELEMENT_CREATED", {"caster": id, "elemento": "ar", "tiles": tiles.size()}, [id]))
		"fogo":
			if tiles.is_empty():
				sh.add_efeito("magia.criar_elementos", "fonte_luz", Area.quadrados(9.0), "cena")   # chama na palma: como uma tocha
				out.append(fact("ELEMENT_CREATED", {"caster": id, "elemento": "fogo", "mao": true}, [id]))
				return out
			var dados := "%dd6" % (1 + apr.count(2))
			for t in tiles:
				sim.add_zona("chama_%d" % sim.zonas.size(), Area.esfera(t, Area.quadrados(9.0)), "luz", -1, "criar_elementos", {"chama": true, "centro": [t.x, t.y]})
				var tg := sim.occupant(t)
				if tg != "":
					var ts: CharacterSheet = sim.c(tg).sheet
					var dano := _dano_por_tipo(ts, "fogo", int(Dice.roll(dados, world.rng, "combat").total))
					var sv := Checks.skill(ts, "reflexos", cd, world.rules, world.rng, "combat")
					sv = _pos_teste(tg, sv, cd, out)
					var tags: Array = ["magia", "fogo"]
					tags.append_array(sim.apply_damage(tg, dano))
					if not sv.get("success", false):
						sim.add_condicao(tg, "em_chamas", 0, "criar_elementos")
						tags.append("em_chamas")
					out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": "Criar Elementos", "d20": 0, "mod": 0, "mods": [], "total": 0,
						"defense": cd, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [], "pv_after": ts.pv, "special": false,
						"ranged": true, "spell": true, "save": "reflexos", "saved": sv.get("success", false), "tags": tags}, [id, tg]))
				var obj := world.db.object_at(t)
				if obj != "":
					var objs_f = world.module("objects")
					if objs_f != null:
						out.append_array(objs_f.danificar(obj, int(Dice.roll(dados, world.rng, "combat").total), false, "criar_elementos"))
	return out


func _toque_chocante(id: String, tgt: String, expr: String, bonus: int, com_ataque: bool, cd: int, sp: Dictionary) -> Array:
	var out: Array = []
	var T: CharacterSheet = sim.c(tgt).sheet
	var sh: CharacterSheet = sim.c(id).sheet
	var passou := false
	var dano_ataque := 0
	var sv := {}
	if com_ataque:
		# ataque corpo a corpo como parte da execução, contra a Defesa do alvo
		var corpo := {}
		for at in sh.attacks:
			if not bool(at.get("distancia", false)):
				corpo = at
				break
		var d20: int = world.rng.roll("combat", 1, 20)[0]
		if d20 + sh.skill_value("luta", world.rules) < T.defense(world.rules, true):
			out.append(fact("SPELL_MISSED", {"caster": id, "target": tgt, "spell": "toque_chocante"}, [id, tgt]))
			return out
		if not corpo.is_empty():
			dano_ataque = _dano_por_tipo(T, str(corpo.get("tipo", "impacto")), int(Dice.roll(str(corpo.dano), world.rng, "combat", 1, int(sh.attrs["for"]) if corpo.get("for_no_dano", false) else 0).total))
	else:
		var metal := bool(world.rules.value("armadura." + str(T.equipment.get("armor", "")), {}).get("metal", false))
		_reacao_protecao(id, tgt, out)
		sv = Checks.skill(T, "fortitude", cd, world.rules, world.rng, "combat", int(sp.penalidade_metal) if metal else 0)
		sv = _pos_teste(tgt, sv, cd, out)
		passou = sv.get("success", false)
	var r := Dice.roll(expr, world.rng, "combat", 1, bonus)
	var dmg := int(r.total)
	if passou:
		dmg = maxi(1, dmg / 2)
	dmg = _dano_por_tipo(T, "eletricidade", dmg) + dano_ataque
	var tags: Array = ["magia", "eletricidade"]
	if passou: tags.append("resistiu")
	tags.append_array(sim.apply_damage(tgt, dmg))
	out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tgt, "weapon": "Toque Chocante", "d20": int(sv.get("d20", 0)), "mod": int(sv.get("mod", 0)),
		"mods": [], "total": int(sv.get("total", 0)), "defense": cd, "camo_roll": 0, "hit": true, "crit": false, "damage": dmg, "rolls": r.rolls,
		"pv_after": T.pv, "special": false, "ranged": false, "spell": true, "save": "" if com_ataque else "fortitude", "saved": passou, "tags": tags}, [id, tgt]))
	return out


## Armadura Arcana em reação (aprimoramento de 1 PM): quem conhece a magia, ao sofrer um ataque, gasta o custo
## (2 PM) e ganha +5 na Defesa contra esse ataque. Política "armadura_arcana"; uma vez por rodada.
func _reacao_armadura_arcana(attacker: String, target: String, out: Array) -> int:
	var T: Dictionary = sim.c(target)
	if T.is_empty() or not T.sheet.spells.has("armadura_arcana") or not sim.is_enemy(attacker, target):
		return 0
	if not CondicoesCombate.pode_reagir(T.sheet, world.rules) or (target == "player" and str(power_policy.get("armadura_arcana", "auto")) == "nunca"):
		return 0
	var flag := "armadura_reacao_%d" % sim.round_no
	var sp := GhostPlanner.spell_rule(world.rules, "armadura_arcana")
	var custo := GhostPlanner.spell_cost(world.rules, sp, {"spell": "armadura_arcana", "aprimoramentos": [0]})
	if T.flags.has(flag) or T.sheet.pm < custo:
		return 0
	T.sheet.pm -= custo
	T.flags.append(flag)
	out.append(fact("REACTION", {"actor": target, "power": "armadura_arcana", "defense": 5, "pm_after": T.sheet.pm}, [target]))
	return 5


## Despedaçar numa criatura (ver _cast).
func _despedacar_criatura(id: String, tg: String, expr: String, cd: int, out: Array) -> void:
	var T: Dictionary = sim.c(tg)
	var ts: CharacterSheet = T.sheet
	var construto := ts.creature_type == "construto"
	var sv := Checks.skill(ts, "fortitude", cd, world.rules, world.rng, "combat")
	sv = _pos_teste(tg, sv, cd, out)
	var passou: bool = sv.get("success", false)
	var dano := int(Dice.roll(expr, world.rng, "combat").total)
	if construto:
		dano *= 2
	if passou:
		dano /= 2
	if construto:
		dano = 0 if ts.efeito_bonus("imune", "impacto") > 0 else dano   # ignora RD
	else:
		dano = _dano_por_tipo(ts, "impacto", dano)
	var tags: Array = ["magia", "impacto"]
	if passou:
		tags.append("resistiu")
	tags.append_array(sim.apply_damage(tg, dano))
	if not passou and not (T.flags as Array).has("despedacar_atordoado") and sim.add_condicao(tg, "atordoado", 1, "despedacar"):
		(T.flags as Array).append("despedacar_atordoado")   # apenas uma vez por cena
		tags.append("atordoado")
	out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": "Despedaçar", "d20": int(sv.get("d20", 0)), "mod": int(sv.get("mod", 0)),
		"mods": [], "total": int(sv.get("total", 0)), "defense": cd, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [],
		"pv_after": ts.pv, "special": false, "ranged": true, "spell": true, "save": "fortitude", "saved": passou, "tags": tags}, [id, tg]))


## Objetos quebráveis (não destruídos) com quadrado em `tiles` e tamanho até o índice `tam_max` de SpellRules.TAMANHOS.
func _objetos_quebraveis_em(tiles: Array, tam_max: int) -> Array:
	var out: Array = []
	var objs_m = world.module("objects")
	if objs_m == null:
		return out
	for o in world.db.all_objects():
		if not o.has("break") or bool(objs_m.obj(str(o.id)).get("broken", false)):
			continue
		var t := Vector2i(int(o.tile[0]), int(o.tile[1]))
		var tam := SpellRules.tamanho_indice(str(o["break"].get("tamanho", "")))
		if tiles.has(t) and tam >= 0 and tam <= tam_max:
			out.append(str(o.id))
	return out


## Perigos no início do turno (LB p.318). Fumaça densa (zona "fumaca"): Fortitude (CD 10 +1 por teste anterior) ou perde
## o turno tossindo; duas falhas seguidas, –1d6 PV. Sufocamento (flag "submerso", sem respirar água): prende a
## respiração por 1 + Con rodadas; depois Fortitude (CD 15 +1 por teste anterior) ou cai inconsciente e perde 1d6 PV
## por rodada até respirar. Suporte Ambiental protege dos dois.
func _perigos_inicio_de_turno(id: String, facts: Array) -> void:
	var x: Dictionary = sim.c(id)
	var s: CharacterSheet = x.sheet
	if s.is_dead():
		return
	if sim.zona_em(x.tile, "fumaca") and s.efeito_bonus("imune_fumaca") <= 0 and s.creature_type != "morto-vivo":
		var n := int(x.get("testes_fumaca", 0))
		var r := Checks.skill(s, "fortitude", 10 + n, world.rules, world.rng, "combat")
		x["testes_fumaca"] = n + 1
		if r.get("success", false):
			x["falhas_fumaca"] = 0
		else:
			x["falhas_fumaca"] = int(x.get("falhas_fumaca", 0)) + 1
			sim.add_condicao(id, "pasmo", 1, "fumaca")   # perde o turno engasgando
			if int(x.falhas_fumaca) >= 2:
				s.pv -= int(Dice.roll("1d6", world.rng, "combat").total)
			facts.append(fact("HAZARD", {"actor": id, "hazard": "fumaca", "check": r, "pv_after": s.pv}, [id]))
	elif x.has("testes_fumaca") and not sim.zona_em(x.tile, "fumaca"):
		x.erase("testes_fumaca")
		x.erase("falhas_fumaca")
	if x.flags.has("submerso") and s.efeito_bonus("respira_agua") <= 0 and s.creature_type != "morto-vivo":
		var rodadas := int(x.get("folego", 0)) + 1
		x["folego"] = rodadas
		if rodadas > 1 + int(s.attrs.get("con", 0)):
			var nf := int(x.get("testes_sufoco", 0))
			var rs := Checks.skill(s, "fortitude", 15 + nf, world.rules, world.rng, "combat")
			x["testes_sufoco"] = nf + 1
			if not rs.get("success", false) or s.conditions.has("inconsciente"):
				s.add_condition("inconsciente", world.rules)
				s.pv -= int(Dice.roll("1d6", world.rng, "combat").total)
				facts.append(fact("HAZARD", {"actor": id, "hazard": "sufocamento", "check": rs, "pv_after": s.pv}, [id]))
	elif not x.flags.has("submerso") and x.has("folego"):
		x.erase("folego")
		x.erase("testes_sufoco")
		if s.conditions.has("inconsciente") and s.pv > 0:
			s.remove_condition("inconsciente")   # voltou a respirar


## Fuga: os inimigos que restam tentam seguir os rastros do jogador (Rastrear, Sobrevivência apenas treinado,
## LB p.123). Se algum conseguir, o grupo o alcança pouco depois (perseguição, ORIGINAL_DO_JOGO).
const TICKS_PERSEGUICAO := 3
func _tentar_rastrear() -> Array:
	var P := sim.c("player")
	var tile: Vector2i = P.tile
	var natural := world.db.is_natural(tile)
	var w = world.module("weather")
	var clima: bool = w != null and w.enabled
	var ruim: bool = clima and (w.is_night() or ["chuva", "tempestade", "neblina"].has(str(w.region.condition)))
	var solo := world.db.solo(tile)
	if clima and natural and ["lamacento", "neve"].has(str(w.region.get("surface", ""))):
		solo = "macio"
	var grupo := 0
	var perseguidores: Array = []
	for id in sim.combatants:
		if sim.c(id).side == "player":
			grupo += 1
		elif sim.conscious(id) and not str(id).begins_with("inv_") and not sim.c(id).flags.has("fora"):
			perseguidores.append(id)
	if perseguidores.is_empty():
		return []
	var cd := Checks.cd_rastrear(world.rules, solo, P.sheet, natural, grupo, ruim, 0)
	var achou := ""
	for id in perseguidores:
		var sh_r: CharacterSheet = sim.c(id).sheet
		if not sh_r.trained.has("sobrevivencia") and not sh_r.flat_skills.has("sobrevivencia"):
			continue   # rastrear é apenas treinado (fichas de criatura listam as perícias treinadas)
		var r := Checks.skill(sh_r, "sobrevivencia", cd, world.rules, world.rng, "world")
		if r.get("success", false):
			achou = id
			break
	if achou == "":
		return [fact("TRACKING_FAILED", {"by": perseguidores, "cd": cd}, ["player"])]
	world.clock.schedule(world.clock.tick + TICKS_PERSEGUICAO, "PURSUIT", {"creatures": perseguidores, "region": str(world.player.region_id)})
	return [fact("PLAYER_TRACKED", {"by": perseguidores, "tracker": achou, "cd": cd}, ["player"])]


## Perseguição: quem seguiu os rastros chega perto do jogador (na mesma região) e o encontro acontece normalmente.
func _perseguir(payload: Dictionary) -> Array:
	if active or str(world.player.region_id) != str(payload.get("region", "")):
		return []
	var p := world.db.world_to_tile(world.player.position)
	var chegaram: Array = []
	var i := 0
	for id in payload.get("creatures", []):
		if not creature_state.has(id) or not creature_state[id].alive:
			continue
		var t := _nearest_walkable(p + Vector2i(2 + i % 2, i / 2 - 1))
		creature_state[id].tile = [t.x, t.y]
		creature_state[id].present = true
		chegaram.append(id)
		i += 1
	if chegaram.is_empty():
		return []
	return [fact("CREATURES_MOVED", {"creatures": chegaram, "reason": "perseguicao"})] + _check_encounter()


## Duração sustentada (LB p.227): 1 PM como ação livre no início de cada turno do conjurador; se não pagar (sem PM,
## sem poder agir ou por escolha, política "sustentar" = "nunca"), a magia termina. Uma magia sustentada por vez.
func _sustentar(id: String, facts: Array) -> void:
	if not sim.sustentadas.has(id):
		return
	var x: Dictionary = sim.c(id)
	var s: CharacterSheet = x.sheet
	var pode: bool = not s.is_down() and not x.flags.has("fora") and not x.surprised and CondicoesCombate.bloqueio_de_acoes(s, world.rules) == ""
	var quer: bool = id != "player" or str(power_policy.get("sustentar", "auto")) != "nunca"
	if pode and quer and s.pm >= 1:
		s.pm -= 1
		facts.append(fact("SPELL_SUSTAINED", {"caster": id, "spell": str(sim.sustentadas[id]), "pm_after": s.pm}, [id]))
		return
	_encerrar_sustentada(id, facts)


## Começa uma magia sustentada; a anterior do mesmo conjurador termina.
func _iniciar_sustentada(id: String, sp_id: String, facts: Array) -> void:
	if sim.sustentadas.has(id) and str(sim.sustentadas[id]) != sp_id:
		_encerrar_sustentada(id, facts)
	sim.sustentadas[id] = sp_id


func _encerrar_sustentada(id: String, facts: Array) -> void:
	if not sim.sustentadas.has(id):
		return
	var sp_id := str(sim.sustentadas[id])
	sim.sustentadas.erase(id)
	var s: CharacterSheet = sim.c(id).sheet
	match sp_id:
		"manto_do_cruzado":
			s.manto_cruzado = ""
		"arma_espiritual":
			s.remove_efeito("magia.arma_espiritual")
		"oracao":
			sim.c(id).erase("oracao")
		"rogar_maldicao":
			for cid in sim.combatants:
				sim.c(cid).sheet.anular_magia("magia.rogar_maldicao_" + id)
		"controlar_madeira":
			sim.remove_zona("madeira_afiada_" + id)
			sim.remove_zona("madeira_afiada_dificil_" + id)
		"tempestade_divina":
			sim.remove_zona("tempestade_" + id)
			sim.remove_zona("tempestade_neve_" + id)
			_refresh_tempestade()
		"enxame_de_pestes":
			for z in sim.zonas.duplicate(true):
				if str(z.fonte) == "enxame_de_pestes" and str(z.dados.conjurador) == id:
					sim.remove_zona(str(z.id))
		"controlar_fogo":
			for m in sim.marcas.duplicate(true):
				if m.alvo == id and m.tipo == "labaredas":
					sim.remove_marca(str(m.id), id)
		"furia_do_panteao":
			sim.remove_zona("furia_" + id)
			sim.remove_zona("furia_neve_" + id)
		"conjurar_mortos_vivos":
			for cid in sim.combatants.keys():
				if (sim.c(cid).flags as Array).has("capanga_de_" + id):
					sim.remove_combatant(cid)   # os mortos-vivos desaparecem com a magia
		"potencia_divina":
			for cid in sim.combatants:
				sim.c(cid).sheet.remove_efeito("magia.potencia_divina")   # tamanho e Força voltam ao normal (ficha)
		"silencio":
			sim.remove_zona("silencio_%s" % id)
			for cid in sim.combatants:
				sim.c(cid).sheet.remove_efeito("magia.silencio")
	_refresh_bencaos()
	facts.append(fact("SPELL_ENDED", {"caster": id, "spell": sp_id, "reason": "sustentada"}, [id]))


## Consagrar e Profanar (SpellsModule): na área consagrada, dados de luz (cura e dano) saem no máximo; na
## profanada, os de trevas. Fora delas, rolagem normal. `mult` multiplica os dados (crítico).
func _dados_energia(expr: String, tipo: String, tile: Vector2i, mult: int = 1) -> int:
	var magia_m = world.module("magia")
	if magia_m != null and magia_m.maximiza(tipo, tile):
		return Dice.maximo(expr, mult)
	return int(Dice.roll(expr, world.rng, "combat", mult).total)


## Consagrar e Profanar: mortos-vivos na área recebem o modificador da área na Defesa e em todos os testes.
func _refresh_areas_sagradas() -> void:
	var magia_m = world.module("magia")
	for cid in sim.combatants:
		var s: CharacterSheet = sim.c(cid).sheet
		s.remove_efeito("magia.area_sagrada")
		if magia_m == null or s.creature_type != "morto-vivo":
			continue
		var mod: int = magia_m.mod_morto_vivo_em(sim.c(cid).tile)
		if mod != 0:
			s.add_efeito("magia.area_sagrada", "defesa", mod, "cena")
			s.add_efeito("magia.area_sagrada", "testes", mod, "cena")


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
	return ts.dano_por_tipo(tipo, dano)


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
			var cura := _dados_energia("2d8", "luz", ax.tile)
			cura = ax.sheet.curar(cura)
			facts.append(fact("HEALED", {"actor": id, "target": a, "amount": cura, "pv_after": ax.sheet.pv, "source": "manto_do_cruzado", "tags": ["magia", "cura"]}, [id, a]))
		return
	var total := 0
	for a in sim.combatants:
		var ax: Dictionary = sim.c(a)
		if not sim.is_enemy(id, a) or not sim.conscious(a) or CombatSim.cheb(x.tile, ax.tile) > curto:
			continue
		var dano := _dados_energia("4d8", "trevas", ax.tile)
		total += dano
		var tags_t: Array = ["magia", "trevas"]
		tags_t.append_array(sim.apply_damage(a, dano))
		facts.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": a, "weapon": "Manto do Cruzado (trevas)", "d20": 0, "mod": 0,
			"mods": [], "total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": dano, "rolls": [],
			"pv_after": ax.sheet.pv, "special": false, "ranged": false, "spell": true, "save": "", "saved": false, "tags": tags_t}, [id, a]))
	if total > 0:
		var metade_m := s.curar(total / 2)
		facts.append(fact("HEALED", {"actor": id, "target": id, "amount": metade_m, "pv_after": s.pv, "source": "manto_do_cruzado", "tags": ["magia", "cura"]}, [id]))


func _begin_turn(id: String) -> Dictionary:
	var r := _begin_turn_base(id)
	r.facts.append_array(_propagar_ligacoes())
	return r


func _begin_turn_base(id: String) -> Dictionary:
	_refresh_bencaos()
	var x := sim.c(id)
	var s: CharacterSheet = x.sheet
	var facts: Array = []
	s.limpar_efeitos("turno")   # efeitos "até o próximo turno" acabam quando a criatura age de novo
	s.limpar_efeitos("rodada")
	_sustentar(id, facts)
	var libertou := false
	if s.efeito_bonus("imobilizar_cd") > 0 and _resiste(id, "vontade", s.efeito_bonus("imobilizar_cd"), facts):
		s.anular_magia("magia.imobilizar")   # Imobilizar: gasta a ação completa num novo teste e, passando, se liberta
		facts.append(fact("SPELL_ENDED", {"spell": "imobilizar", "target": id, "reason": "resistiu"}, [id]))
		libertou = true
	var marca_turno := _marca_obediencia(id, facts)
	var ordem_cmd := _obedecer_comando(id, facts)
	if ["fuja", "venha"].has(str(ordem_cmd.get("ordem", ""))) and sim.combatants.has(str(ordem_cmd.conj)):
		x["comando_turno"] = ordem_cmd
	elif not marca_turno.is_empty():
		x["comando_turno"] = marca_turno
	for f_ae in (x.flags as Array).duplicate():
		if str(f_ae).begins_with("ae_atk_"):
			(x.flags as Array).erase(f_ae)   # Arma Espiritual: a arma que atacou volta a poder contra-atacar
	_manto_inicio_de_turno(id, facts)
	_nuvens_do_conjurador(id, facts)
	if s.has_efeito("magia.premonicao"):
		s.add_efeito("magia.premonicao", "premonicao_uso", 1, "rodada")   # uma vez por rodada, a cada turno do conjurador
	_zonas_e_marcas_inicio_de_turno(id, facts)
	_voo_na_tempestade(id, facts)
	_perigos_inicio_de_turno(id, facts)
	_luz_solar(id, facts)
	_resolver_conjuracao(id, facts)
	if x.flags.has("fora") or s.is_dead() or libertou:
		return {"skip": true, "facts": facts}
	CondicoesCombate.inicio_de_turno(sim, id, world.rng, facts)   # em chamas e sangramento
	if s.is_dead():
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
	# Ações bloqueadas (atordoado, fascinado, pasmo, paralisado): o turno passa sem ação.
	var bloqueio := CondicoesCombate.bloqueio_de_acoes(s, world.rules)
	if bloqueio != "":
		facts.append(fact("TURN_SKIPPED", {"actor": id, "reason": bloqueio}))
		return {"skip": true, "facts": facts}
	# Confuso (1d6): pode perder o turno, andar ao acaso ou atacar a criatura adjacente.
	var conf := CondicoesCombate.confuso(sim, id, world.rng, facts)
	if conf.acao == "atacar":
		var v_c := GhostPlanner.validate_action(sim, id, {"type": "attack", "target": conf.alvo, "attack": 0})
		if v_c.ok:
			facts.append_array(_resolve_attack(id, conf.alvo, v_c, false))
		return {"skip": true, "facts": facts}
	if conf.acao == "perder":
		return {"skip": true, "facts": facts}
	# Enjoado: uma única ação, padrão ou de movimento, por turno (ver CombatSim.spend).
	if s.has_effective_condition(world.rules, "enjoado"):
		sim.budget["enjoado"] = true
	x.flags.erase("defensivo")   # Combate Defensivo vale "até seu próximo turno" (LB p.125)
	if sim.conjurando.has(id) and int(sim.conjurando[id].rodadas) > 0:
		sim.budget["std"] = 0   # conjurando: a ação padrão vai para a execução da magia
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
	if _santuario_impede(id, a, out):
		return out   # Santuário: não consegue e perde a ação
	_santuario_quebra(id, a, out)
	_atitude_quebra(id, a, out)
	match a.type:
		"move":
			var path := GhostPlanner._tiles(a.path)
			var from: Vector2i = sim.c(id).tile
			var reactors := _reflex_watchers(id, from)
			sim.c(id).tile = v.end
			out.append(fact("COMBAT_MOVED", {"actor": id, "from": [from.x, from.y], "path": path.map(func(t): return [t.x, t.y])}, [id]))
			out.append_array(_dano_vegetacao_afiada(id, path))
			out.append_array(_aura_divina_entrada(id, from, path))
			for r_id in reactors:
				if CombatSim.cheb(sim.c(r_id).tile, v.end) > 1:
					out.append_array(_reflex_attack(r_id, id, from))
		"charge":
			var path := GhostPlanner._tiles(a.path)
			var from: Vector2i = sim.c(id).tile
			sim.c(id).tile = v.end
			sim.c(id).charge_turn = sim.turn_counter
			out.append(fact("COMBAT_MOVED", {"actor": id, "from": [from.x, from.y], "path": path.map(func(t): return [t.x, t.y]), "charge": true}, [id]))
			out.append_array(_aura_divina_entrada(id, from, path))
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
		"ataque_parceiro":
			sim.c(id).sheet.pm -= 5
			(sim.c(id).flags as Array).append("ataque_parceiro_%d" % sim.round_no)
			out.append(fact("POWER_USED", {"actor": id, "power": "ataque_parceiro", "pm_cost": 5, "pm_after": sim.c(id).sheet.pm}, [id]))
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
			res = _pos_teste(a.target, res, 19, out)
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
				sv_m = _pos_teste(alvo_m, sv_m, 10 + int(sh_m.attrs["car"]), out)
				var dano_m := _dados_energia("%dd8+%d" % [dados_m, dados_m], "luz", sim.c(alvo_m).tile)
				if sv_m.get("success", false):
					dano_m = maxi(1, dano_m / 2)
				out.append_array(sim.apply_damage(alvo_m, dano_m))
				out.append(fact("POWER_USED", {"actor": id, "power": "cura_pelas_maos", "target": alvo_m, "damage": dano_m, "pm_cost": v.cost, "pm_after": sh_m.pm}, [id, alvo_m]))
			else:
				var cura_m := _dados_energia("%dd8+%d" % [dados_m, dados_m], "luz", sim.c(alvo_m).tile)
				cura_m = ts_m.curar(cura_m)
				if v.get("remover", false):
					for cond in ["abalado", "apavorado", "atordoado", "cego", "doente", "exausto", "fatigado", "surdo"]:
						if ts_m.conditions.has(cond):
							ts_m.remove_condition(cond)
							break
				out.append(fact("HEALED", {"actor": id, "target": alvo_m, "amount": cura_m, "pv_after": ts_m.pv, "source": "cura_pelas_maos", "tags": ["classe", "cura"]}, [id, alvo_m]))
				out.append(fact("POWER_USED", {"actor": id, "power": "cura_pelas_maos", "target": alvo_m, "pm_cost": v.cost, "pm_after": sh_m.pm}, [id]))
		"diplomacia":
			out.append_array(_mudar_atitude(id, str(a.target), -10))
		"adestrar":
			out.append_array(_acalmar_pela_pericia(id, str(a.target)))
		"pegar_arma":
			var X: Dictionary = sim.c(id)
			var chao_p: Dictionary = X.arma_no_chao
			_devolver_arma(id)
			out.append(fact("ITEM_PICKED", {"actor": id, "item": chao_p.get("arma", "")}, [id]))
		"escapar":
			# Libertar-se (Controlar Plantas): Acrobacia ou Atletismo, a melhor, contra a CD do efeito.
			var sh_x: CharacterSheet = sim.c(id).sheet
			var marca_x: Dictionary = _marca_presa(id)
			var pericia_x := "acrobacia" if sh_x.skill_value("acrobacia", world.rules) >= sh_x.skill_value("atletismo", world.rules) else "atletismo"
			var r_x := Checks.skill(sh_x, pericia_x, int(marca_x.dados.cd), world.rules, world.rng, "combat")
			if r_x.get("success", false):
				_soltar(id, marca_x)
			out.append(fact("ESCAPE_ATTEMPT", {"actor": id, "skill": pericia_x, "check": r_x, "success": r_x.get("success", false)}, [id]))
		"ouvir_pensamentos":
			# Compreensão: ação de movimento, ouvir o que uma criatura tocada pensa (Vontade de involuntário evita).
			var alvo_op := str(a.target)
			var cd_op := spell_dc(sim.c(id).sheet, {"spell": "compreensao"})
			if sim.is_enemy(id, alvo_op) and _resiste(alvo_op, "vontade", cd_op, out):
				out.append(fact("SPELL_MISSED", {"caster": id, "target": alvo_op, "spell": "compreensao", "saved": true}, [id, alvo_op]))
			else:
				out.append_array(_revelar_pensamentos(alvo_op, false))
		"analisar_aura":
			# Visão Mística: ação de movimento; a criatura lança magias? e a aura da magia de círculo mais alto.
			var ts_aa: CharacterSheet = sim.c(str(a.target)).sheet
			var circ_aa := SpellRules.circulo_maximo(ts_aa, world.rules) if not ts_aa.spells.is_empty() else 0
			out.append(fact("AURA_ANALYZED", {"actor": id, "target": a.target, "lanca_magias": circ_aa > 0, "aura": SpellRules.aura_por_circulo(circ_aa) if circ_aa > 0 else ""}, [id, str(a.target)]))
		"detectar_magia":
			# Misticismo, Detectar Magia (LB p.121): ação completa, CD 15; presença e intensidade das auras em alcance curto.
			var r_dm := Checks.skill(sim.c(id).sheet, "misticismo", 15, world.rules, world.rng, "combat")
			var auras_dm: Array = auras_na_cena(sim.c(id).tile, ALCANCE_CURTO_QUADRADOS, false) if r_dm.get("success", false) else []
			out.append(fact("MAGIC_DETECTED", {"actor": id, "check": r_dm, "auras": auras_dm}, [id]))
		"raio_tempestade":
			(sim.c(id).flags as Array).append("raio_tempestade_%d" % sim.round_no)
			var zt: Dictionary = sim.zonas.filter(func(z): return str(z.id) == "tempestade_" + id)[0]
			out.append_array(_dano_de_energia(id, str(a.target), "%dd8" % int(zt.dados.raios), int(zt.dados.cd), "reflexos", "eletricidade", "Tempestade Divina"))
		"mover_enxame":
			var para_e: Vector2i = a.tile
			var zid_e := "enxame_%s_%d" % [id, int(a.get("enxame", 0))]
			for z in sim.zonas:
				if str(z.id) == zid_e:
					z.tiles = [para_e]
			out.append(fact("SPELL_EFFECT", {"caster": id, "spell": "enxame_de_pestes", "efeito": "mover", "tile": [para_e.x, para_e.y]}, [id]))
		"furia":
			out.append_array(_efeito_furia(id, str(a.efeito), a.get("targets", [])))
		"mover_mortos":
			for cid in _capangas_de(id):
				var de_mv: Vector2i = sim.c(cid).tile
				var caminho_mv := sim.trim_path(cid, sim.find_path(cid, a.tile, true, 60), Area.quadrados(9.0))
				if not caminho_mv.is_empty():
					sim.c(cid).tile = caminho_mv[-1]
					out.append(fact("COMBAT_MOVED", {"actor": cid, "from": [de_mv.x, de_mv.y], "path": caminho_mv.map(func(t): return [t.x, t.y])}, [cid]))
		"atacar_mortos":
			for cid in _capangas_de(id):
				out.append_array(_golpe_capanga(id, cid, str(a.get("target", ""))))
		"resfriar":
			for m in sim.marcas.duplicate(true):
				if m.alvo == id and m.tipo == "esquentar":
					sim.remove_marca(str(m.id), id)
			out.append(fact("SPELL_ENDED", {"spell": "controlar_fogo", "target": id, "reason": "resfriado"}, [id]))
		"mover_chama":
			(sim.c(id).flags as Array).append("chama_%d" % sim.round_no)
			out.append_array(_mover_chama(id, a.get("tile", sim.c(id).tile)))
		"labareda":
			var ml: Dictionary = sim.marcas.filter(func(m): return m.alvo == id and m.tipo == "labaredas")[0]
			out.append_array(_dano_de_fogo(id, str(a.target), "%dd6" % int(ml.dados.dados), int(ml.dados.cd), "reflexos", "Labareda"))
		"mover_facho":
			# Raio Solar (truque): uma vez por rodada, ação livre, o facho muda de direção.
			(sim.c(id).flags as Array).append("facho_%d" % sim.round_no)
			var alvo_f := Vector2i(int(a.tile[0]), int(a.tile[1])) if a.tile is Array else a.tile as Vector2i
			var orig_f: Vector2i = sim.c(id).tile
			var dir_f := Vector2i(signi(alvo_f.x - orig_f.x), signi(alvo_f.y - orig_f.y))
			sim.add_zona("facho_%s" % id, Area.linha(orig_f, dir_f if dir_f != Vector2i.ZERO else Vector2i(1, 0), Area.quadrados(30.0)), "luz", -1, "raio_solar",
				{"conjurador": id, "magica": true, "facho": true})
			out.append(fact("LIGHT_MOVED", {"actor": id}, [id]))
		"mover_globos":
			# Luz (globos, aprimoramento arcano): uma vez por rodada, ação livre, os globos vão a outros quadrados.
			(sim.c(id).flags as Array).append("globos_%d" % sim.round_no)
			var novos: Array = a.get("tiles", [])
			var i_g := 0
			for z in sim.zonas.duplicate(true):
				if str(z.tipo) == "globo_luz" and str(z.get("dados", {}).get("conjurador", "")) == id and i_g < novos.size():
					var tg_g := Vector2i(int(novos[i_g][0]), int(novos[i_g][1]))
					sim.add_zona(str(z.id), [tg_g], "globo_luz", -1, "luz", z.dados)
					sim.add_zona(str(z.id) + "_luz", Area.esfera(tg_g, Area.quadrados(9.0)), "luz", -1, "luz", {"conjurador": id, "magica": true})
					i_g += 1
			out.append(fact("GLOBES_MOVED", {"actor": id, "count": i_g}, [id]))
		"guardar_fonte":
			# Guardar (ou revelar) o objeto que emite Luz ou Escuridão: ação de movimento.
			var sh_g: CharacterSheet = sim.c(id).sheet
			if sh_g.efeito_bonus("fonte_oculta") > 0:
				sh_g.remove_efeito_stat("fonte_oculta")
			else:
				sh_g.add_efeito("fonte_oculta", "fonte_oculta", 1, "cena")
			out.append(fact("LIGHT_TOGGLED", {"actor": id, "oculta": sh_g.efeito_bonus("fonte_oculta") > 0}, [id]))
		"arma_espiritual":
			var i_ae := sim.arma_espiritual_livre(id)
			(sim.c(id).flags as Array).append("ae_atk_%d" % i_ae)
			(sim.c(id).flags as Array).append("ae_r%d_%d" % [sim.round_no, i_ae])
			_golpe_arma_espiritual(id, str(a.target), out)
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
		"agua_benta":
			# Inofensiva para quem não é morto-vivo nem abissal.
			var T_ab: Dictionary = sim.c(str(a.target))
			var ts_ab: CharacterSheet = T_ab.sheet
			out.append(fact("ITEM_LOST", {"item": "agua_benta"}, [id]))
			if ts_ab.creature_type == "morto-vivo" or Array(ts_ab.habilidades).has("abissal"):
				var cd_ab: int = 10 + sim.c(id).sheet.level / 2 + int(sim.c(id).sheet.attrs.get("sab", 0))
				var sv_ab := Checks.skill(ts_ab, "reflexos", cd_ab, world.rules, world.rng, "combat")
				var dano_ab := _dados_energia("2d10", "luz", T_ab.tile)
				if sv_ab.get("success", false):
					dano_ab /= 2
				dano_ab = _dano_por_tipo(ts_ab, "luz", dano_ab)
				var tags_ab: Array = ["item", "luz"]
				tags_ab.append_array(sim.apply_damage(str(a.target), dano_ab))
				out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": a.target, "weapon": "Água benta", "d20": 0, "mod": 0, "mods": [], "total": 0,
					"defense": cd_ab, "camo_roll": 0, "hit": true, "crit": false, "damage": dano_ab, "rolls": [], "pv_after": ts_ab.pv, "special": false,
					"ranged": true, "save": "reflexos", "saved": sv_ab.get("success", false), "tags": tags_ab}, [id, str(a.target)]))
		"drink":
			var heal := {"total": _dados_energia(str(world.rules.value("magia.curar_ferimentos").cura), "luz", sim.c(id).tile)}
			var sh: CharacterSheet = sim.c(id).sheet
			var curado_i := sh.curar(int(heal.total))
			out.append(fact("ITEM_LOST", {"item": a.item}, [id]))
			out.append(fact("HEALED", {"actor": id, "target": id, "amount": curado_i, "pv_after": sh.pv, "source": a.item, "tags": ["cura"]}, [id]))
	return out


## CD de resistência das magias (LB p.173) + Magia Pungente (+2, LB p.38).
func spell_dc(sh: CharacterSheet, a: Dictionary) -> int:
	var cd := 10 + sh.level / 2 + int(sh.attrs.get(sh.caster_attr, 0))
	if a.get("pungente", false) and sh.has_power("magia_pungente"):
		cd += int(world.rules.value("poder.magia_pungente").cd_bonus)
	return cd + sh.efeito_bonus("cd_magias")   # Miasma Mefítico (truque): +2 por um dia


## Arcano de Batalha (LB p.38): soma o atributo-chave na rolagem de dano da magia.
static func battle_bonus(sh: CharacterSheet) -> int:
	return maxi(0, int(sh.attrs.get(sh.caster_attr, 0))) if sh.has_power("arcano_de_batalha") else 0


func _ficha_em_zona(sh: CharacterSheet, tipo: String) -> bool:
	for cid in sim.combatants:
		if sim.c(cid).sheet == sh:
			return sim.zona_em(sim.c(cid).tile, tipo)
	return false


## CD dos testes de lançar (C5). Retorna {} se não há teste; senão o payload da falha (ou {} se passou).
func casting_cd(sh: CharacterSheet, sp: Dictionary, cost: int) -> Dictionary:
	var conc: Dictionary = world.rules.value("magia.concentracao")
	var cd := 0
	var why := ""
	if sh.conditions.has("caido"):
		cd = int(conc.condicao_ruim.cd_base) + cost; why = "caído"
	elif _ficha_em_zona(sh, "furia"):
		cd = int(conc.condicao_ruim.cd_base) + cost; why = "fúria do panteão"
	elif world.modules.has("weather") and world.modules.weather.enabled and world.modules.weather.region.condition == "tempestade":
		cd = int(conc.condicao_ruim.cd_base) + cost; why = "tempestade"
	var arm := {}
	if str(sp.get("tipo", "")) == "arcana" and str(sh.equipment.get("armor", "")) != "":
		var ar: Dictionary = world.rules.value("magia.armadura_e_arcana")
		arm = {"skill": "misticismo", "cd": int(ar.cd_base) + cost, "mod": sh.armor_penalty(world.rules)}
	return {"concentration_cd": cd, "reason": why, "armor": arm}


func _casting_check(id: String, sh: CharacterSheet, sp: Dictionary, cost: int) -> Dictionary:
	# Surdo (LB p.394): 20% de falha ao lançar magia.
	if sh.has_effective_condition(world.rules, "surdo") and CondicoesCombate.surdo_falha(int(world.rng.roll("combat", 1, 100)[0])):
		return {"caster": id, "check": "surdez", "cd": 0, "reason": "surdo", "d20": 0, "total": 0}
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
			# Armadura Arcana (arcana 1, LB p.183): +5 na Defesa pela cena; acumula com magias, não com armadura.
			# Aprimoramentos: reação (_reacao_armadura_arcana); +1 (2 PM, repetível); um dia (2 PM, 3º círculo).
			var apr_aa: Array = a.get("aprimoramentos", [])
			var arm: Dictionary = world.rules.value("armadura." + str(sh.equipment.get("armor", "")), {})
			var bonus_aa := maxi(0, int(sp.defesa) + apr_aa.count(1) - int(arm.get("defesa", 0)))
			if apr_aa.has(2):
				sh.add_efeito("magia.armadura_arcana", "defesa", bonus_aa, "dia", "", world.day_index() + 1)
			else:
				sh.scene_defense = bonus_aa
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "armadura_arcana", "defense": bonus_aa, "tags": ["magia"]}, [id]))
		"toque_chocante":
			# Toque Chocante (arcana 1, LB p.209): 2d8+2 de eletricidade; Fortitude reduz à metade (–5 com armadura de metal).
			# Aprimoramentos: +1d8+1 (1 PM, repetível); sem resistência, com ataque corpo a corpo como parte da execução
			# (acertou: dano do ataque e da magia) (2 PM); esfera de 6m a partir de você (2 PM; não o afeta).
			var apr_tc: Array = a.get("aprimoramentos", [])
			var expr_tc := "%dd8+%d" % [2 + apr_tc.count(0), 2 + apr_tc.count(0)]
			var alvos_tc: Array = [a.get("target", "")]
			if apr_tc.has(2):
				alvos_tc = _criaturas_vivas_em(Area.esfera(sim.c(id).tile, Area.quadrados(6.0))).filter(func(x): return x != id)
			var bonus_tc := battle_bonus(sh)   # Arcano de Batalha: uma vez por magia
			for tgt in alvos_tc:
				out.append_array(_toque_chocante(id, str(tgt), expr_tc, bonus_tc, apr_tc.has(1), spell_dc(sh, a), sp))
				bonus_tc = 0
		"raio_arcano":
			# Raio Arcano (LB p.39): 1d8 (+1d8 por círculo acima do 1º), alcance curto, Reflexos reduz à metade
			var tgt: String = a.get("target", (a.get("targets", [""]) as Array)[0])
			var T: CharacterSheet = sim.c(tgt).sheet
			var cd := spell_dc(sh, a)
			_reacao_protecao(id, tgt, out)
			var sv := Checks.skill(T, "reflexos", cd, world.rules, world.rng, "combat")
			sv = _pos_teste(tgt, sv, cd, out)
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
			# Seta Infalível de Talude (arcana 1, LB p.205): duas setas de 1d4+1 de essência, sem teste, divididas entre os
			# alvos escolhidos. Aprimoramentos: lanças de 1d8+1 (2º); três, cinco (2º) ou dez (4º) setas; vale o maior.
			# Arcano de Batalha soma uma vez.
			var apr_si: Array = a.get("aprimoramentos", [])
			var n_si := 10 if apr_si.has(3) else (5 if apr_si.has(2) else (3 if apr_si.has(1) else int(sp.setas)))
			var dado_si := "1d8+1" if apr_si.has(0) else str(sp.dano_por_seta)
			var alvos_si: Array = a.get("targets", [a.get("target", "")])
			for i_si in n_si:
				var tgt: String = alvos_si[i_si % alvos_si.size()]
				if sim.c(tgt).is_empty() or sim.c(tgt).sheet.is_dead():
					continue
				var r := Dice.roll(dado_si, world.rng, "combat", 1, battle_bonus(sh) if i_si == 0 else 0)
				var dano_si := _dano_por_tipo(sim.c(tgt).sheet, "essencia", int(r.total))
				var tags: Array = ["magia", "essencia"]
				tags.append_array(sim.apply_damage(tgt, dano_si))
				out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tgt, "weapon": "Seta Infalível", "d20": 0, "mod": 0, "mods": [],
					"total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": dano_si, "rolls": r.rolls,
					"pv_after": sim.c(tgt).sheet.pv, "special": false, "ranged": true, "spell": true, "tags": tags}, [id, tgt]))
		"luz", "escuridao":
			out.append_array(_luz_ou_escuridao(id, a))
		"fisico_divino", "mente_divina":
			# Físico Divino / Mente Divina (divinas 2): +2 no atributo escolhido pela cena (sem PV, PM ou perícias novas).
			# Aprimoramentos: curto e criaturas escolhidas; +2 nos três (3º); +4 no escolhido (4º); +4 nos três (5º).
			var bon_fd := SpellRules.bonus_atributos(str(a.spell), a.get("aprimoramentos", []), str(a.get("atributo", "")))
			for tg_fd in a.get("targets", [a.get("target", id)]):
				var ts_fd: CharacterSheet = sim.c(tg_fd).sheet
				ts_fd.remove_efeito("magia." + str(a.spell))
				for at_fd in bon_fd:
					ts_fd.add_efeito("magia." + str(a.spell), "atributo", int(bon_fd[at_fd]), "cena", at_fd)
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg_fd, "buff": str(a.spell), "atributos": bon_fd, "tags": ["magia"]}, [id, tg_fd]))
		"oracao":
			# Oração (divina 2): sustentada (cena com aprimoramento de 4º). Você e aliados no alcance: +2 em testes de perícia e
			# dano; inimigos: –2. Cumulativo. Material: T$ 20 por PM gasto. Aprimoramentos: +1 bônus e –1 penalidade
			# (repetíveis, até o círculo máximo); alcance médio (3º). Ver _refresh_oracao.
			var apr_or: Array = a.get("aprimoramentos", [])
			var circ_or := SpellRules.circulo_maximo(sh, world.rules)
			var dados_or := {"bonus": mini(2 + apr_or.count(0), maxi(2, circ_or)), "penalidade": mini(2 + apr_or.count(1), maxi(2, circ_or)),
				"alcance": int(world.rules.value("alcance.quadrados", {}).get("medio" if apr_or.has(2) else "curto", 6))}
			sim.c(id)["oracao"] = dados_or
			if id == "player":
				out.append(fact("GOLD_CHANGED", {"delta": -20 * int(v.get("cost", 0)), "reason": "oferendas da Oração"}))
			if not apr_or.has(3):
				_iniciar_sustentada(id, "oracao", out)
			_refresh_oracao()
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "oracao", "tags": ["magia"]}, [id]))
		"purificacao":
			# Purificação (divina 2): toque; remove uma condição da lista (todas, com aprimoramento). Aprimoramentos: PV perdidos
			# por veneno; soltar item amaldiçoado; dissipar efeitos prejudiciais de encantamento, necromancia e transmutação (3º).
			var apr_pu: Array = a.get("aprimoramentos", [])
			var tg_pu: String = a.get("target", id)
			var ts_pu: CharacterSheet = sim.c(tg_pu).sheet
			var removidas: Array = []
			for cnd in SpellRules.CONDICOES_PURIFICACAO:
				if ts_pu.conditions.has(cnd) and (apr_pu.has(1) or removidas.is_empty()) and (str(a.get("condicao", "")) == "" or str(a.condicao) == cnd or apr_pu.has(1)):
					ts_pu.remove_condition(cnd)
					for m_pu in sim.marcas.duplicate(true):
						if m_pu.alvo == tg_pu and m_pu.tipo == "condicao" and str(m_pu.dados.get("condicao", "")) == cnd:
							sim.remove_marca(str(m_pu.id), tg_pu)
					removidas.append(cnd)
			if apr_pu.has(0) and ts_pu.pv_perdido_veneno > 0:
				ts_pu.pv = mini(ts_pu.pv_max, ts_pu.pv + ts_pu.pv_perdido_veneno)
				ts_pu.pv_perdido_veneno = 0
			if apr_pu.has(2):
				out.append(fact("CURSED_ITEM_RELEASED", {"target": tg_pu}, [tg_pu]))   # pode soltar; a maldição do item fica
			if apr_pu.has(3):
				_dissipar_prejudiciais(tg_pu, ["encantamento", "necromancia", "transmutação"], out)
			out.append(fact("CONDITIONS_REMOVED", {"actor": id, "target": tg_pu, "conditions": removidas}, [id, tg_pu]))
		"raio_solar":
			out.append_array(_raio_solar(id, a))
		"soco_de_arsenal":
			out.append_array(_soco_de_arsenal(id, a))
		"controlar_fogo":
			out.append_array(_controlar_fogo(id, a))
		"miasma_mefitico":
			out.append_array(_miasma(id, a))
		"enxame_de_pestes":
			out.append_array(_enxame(id, a))
		"rogar_maldicao":
			out.append_array(_rogar_maldicao(id, a))
		"tempestade_divina":
			out.append_array(_tempestade(id, a))
		"controlar_madeira":
			out.append_array(_controlar_madeira(id, a))
		"aliado_animal":
			var magia_aa = world.module("magia")
			if id == "player" and magia_aa != null and magia_aa.validar_aliado_animal(a, sh) == "":
				out.append_array(magia_aa.aliado_animal(a, sh))
		"augurio":
			# Augúrio (divina 2): ação completa; o presságio sobre entrar num lugar (SpellsModule.augurio).
			var magia_au = world.module("magia")
			if magia_au != null and magia_au.validar_augurio(a) == "":
				out.append_array(magia_au.augurio(a))
		"circulo_da_justica":
			# Círculo da Justiça (divina 2): esfera de 9m num ponto em alcance curto, por um dia (SpellsModule). Quem está
			# dentro sofre –10 em Acrobacia, Enganação, Furtividade e Ladinagem e não mente; Vontade: –5 e pode mentir.
			# Aprimoramentos: pessoal, pela cena, vê o invisível em alcance curto; –10/–20 (4º); permanente (fora de combate).
			var apr_cj: Array = a.get("aprimoramentos", [])
			if apr_cj.has(0):
				sh.add_efeito("magia.circulo_da_justica", "ve_invisivel", 1, "cena")
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "circulo_da_justica", "tags": ["magia"]}, [id]))
			else:
				var magia_cj = world.module("magia")
				if magia_cj != null:
					magia_cj.criar_justica(a.get("tile", sim.c(id).tile), spell_dc(sh, a), apr_cj)
				_refresh_justica()
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "circulo_da_justica", "tags": ["magia", "area"]}, [id]))
		"condicao":
			# Condição (divina 2): até 5 criaturas em alcance curto (+1 por aprimoramento), pela cena (um dia com
			# aprimoramento): o conjurador sabe posição e status delas a qualquer distância (status_conhecidos).
			var apr_cd: Array = a.get("aprimoramentos", [])
			for tg_cd in a.get("targets", [a.get("target", "")]):
				sh.add_efeito("magia.condicao", "condicao", 1, "dia" if apr_cd.has(1) else "cena", str(tg_cd), world.day_index() + 1 if apr_cd.has(1) else -1)
			out.append(fact("CREATURE_STATUS", {"caster": id, "status": status_conhecidos(id)}, [id]))
		"voz_divina":
			# Voz Divina (divina 2): pessoal, pela cena; conversa com criaturas de qualquer tipo (Mudar Atitude passa a valer
			# para elas). Aprimoramentos: um cadáver responde (uma vez por corpo); falar com plantas e rochas.
			var apr_vd: Array = a.get("aprimoramentos", [])
			var magia_vd = world.module("magia")
			if apr_vd.has(0):
				if magia_vd != null and magia_vd.interrogados.has(str(a.get("target", ""))):
					out.append(fact("SPELL_MISSED", {"caster": id, "target": a.get("target", ""), "spell": "voz_divina", "reason": "ja_respondeu"}, [id]))
				elif magia_vd != null:
					out.append_array(magia_vd.interrogar_cadaver(str(a.get("target", ""))))
			else:
				sh.add_efeito("magia.voz_divina", "voz_divina", 1, "cena")
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "voz_divina", "tags": ["magia"]}, [id]))
				if apr_vd.has(1) and magia_vd != null:
					out.append(magia_vd.falar_com_plantas(sim.c(id).tile, true))
		"silencio":
			# Silêncio (divina 2): esfera de 6m em alcance médio, sustentada; quem está dentro fica surdo e não lança magias.
			# Aprimoramentos: objeto que emana 3m (Vontade de involuntário); cena, e o som só não sai da área.
			var apr_si2: Array = a.get("aprimoramentos", [])
			if apr_si2.has(0):
				var tg_s: String = a.get("target", id)
				if sim.is_enemy(id, tg_s) and _resiste(tg_s, "vontade", spell_dc(sh, a), out):
					return out
				sim.c(tg_s).sheet.add_efeito("magia.silencio", "fonte_silencio", Area.quadrados(3.0), "cena" if apr_si2.has(1) else "sustentada", "so_contem" if apr_si2.has(1) else "")
			else:
				var centro_si: Vector2i = a.get("tile", sim.c(a.get("target", id)).tile)
				sim.add_zona("silencio_%s" % id, Area.esfera(centro_si, Area.quadrados(6.0)), "silencio", -1, "silencio", {"conjurador": id, "so_contem": apr_si2.has(1)})
			if not apr_si2.has(1):
				_iniciar_sustentada(id, "silencio", out)
			_refresh_silencio()
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "silencio", "tags": ["magia"]}, [id]))
		"aviso":
			# Aviso (universal 1): alcance longo (x10 por aprimoramento), sem precisar ver. Alerta: +5 no próximo teste de
			# Iniciativa e de Percepção até o fim da próxima cena. Mensagem (25 palavras; resposta com aprimoramento) e
			# Localização (pela cena com aprimoramento) são informação. +1 alvo por aprimoramento de 3 PM.
			var modo_av := str(a.get("modo", "alerta"))
			for tg_av in a.get("targets", [a.get("target", id)]):
				if modo_av == "alerta":
					SpellRules.aplicar_alerta(sim.c(tg_av).sheet)
				out.append(fact("WARNING_SENT", {"caster": id, "target": tg_av, "modo": modo_av, "texto": str(a.get("texto", "")).substr(0, 200),
					"resposta": (a.get("aprimoramentos", []) as Array).has(1), "cena": (a.get("aprimoramentos", []) as Array).has(2)}, [id, tg_av]))
		"compreensao":
			# Compreensão (universal 1): toque (curto com aprimoramento; criaturas escolhidas com outro). Entende e se comunica;
			# com animal, percebe os sentimentos (a atitude). Ação de movimento: ouvir os pensamentos (Vontade de involuntário).
			# Vasculhar (2º): extrai informações (Vontade anula). Pessoal (3º): todos os idiomas.
			var apr_co: Array = a.get("aprimoramentos", [])
			if apr_co.has(3):
				sh.add_efeito("magia.compreensao", "todos_idiomas", 1, "cena")
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "compreensao_idiomas", "tags": ["magia"]}, [id]))
			else:
				for tg_co in a.get("targets", [a.get("target", "")]):
					sh.add_efeito("magia.compreensao", "compreende", 1, "cena", tg_co)
					var info_co := {"caster": id, "target": tg_co}
					if sim.c(tg_co).sheet.creature_type == "animal":
						info_co["sentimento"] = atitude_de(tg_co)
					out.append(fact("UNDERSTANDING", info_co, [id, tg_co]))
					if apr_co.has(2) and not _resiste(tg_co, "vontade", spell_dc(sh, a), out):
						out.append_array(_revelar_pensamentos(tg_co, true))
		"visao_mistica":
			# Visão Mística (universal 1): pessoal, pela cena (um dia com aprimoramento). Enxerga auras mágicas em alcance
			# médio com todas as informações; ação de movimento para saber se uma criatura lança magias e a aura da magia
			# mais alta. Aprimoramentos: visão no escuro; um dia; ver o invisível.
			var apr_vm: Array = a.get("aprimoramentos", [])
			var dur_vm := "dia" if apr_vm.has(1) else "cena"
			var ate_vm := world.day_index() + 1 if dur_vm == "dia" else -1
			sh.add_efeito("magia.visao_mistica", "visao_mistica", 1, dur_vm, "", ate_vm)
			if apr_vm.has(0):
				sh.add_efeito("magia.visao_mistica", "visao_escuro", 1, dur_vm, "", ate_vm)
			if apr_vm.has(2):
				sh.add_efeito("magia.visao_mistica", "ve_invisivel", 1, dur_vm, "", ate_vm)
			out.append(fact("MAGIC_AURAS", {"caster": id, "auras": auras_na_cena(sim.c(id).tile, int(world.rules.value("alcance.quadrados", {}).get("medio", 20)), true)}, [id]))
		"criar_elementos":
			# Criar Elementos (divina 1): porção real de um elemento (LB p.187). Água: enche um recipiente (item frasco com
			# água). Ar: vento num quadrado: tira fumaça e afasta a névoa por uma rodada. Fogo: chama que ilumina como uma
			# tocha, na palma ("mao") ou num quadrado (1d6 de fogo em quem estiver nele; Reflexos ou em chamas). Terra: cubo
			# ou objeto simples. Aprimoramentos: +1 passo de quantidade (+1 quadrado para ar e fogo); arremesso de água ou
			# terra em 1 criatura ou objeto (2d4 de impacto, +1 passo por categoria acima de Minúsculo; Reflexos reduz à
			# metade); +1d6 no dano de cada chama.
			out.append_array(_criar_elementos(id, a))
		"abencoar_alimentos":
			# Abençoar Alimentos (divina 1): age sobre o inventário (SpellsModule.abencoar).
			var magia_ab = world.module("magia")
			if magia_ab != null:
				out.append_array(magia_ab.abencoar(a))
		"suporte_ambiental":
			# Suporte Ambiental (divina 1): toque (curto e criaturas escolhidas com o aprimoramento), 1 dia. Imune a calor
			# e frio extremos, respira na água (e o que respira água, no ar) e não sufoca em fumaça densa.
			for tg_sa in a.get("targets", [a.get("target", id)]):
				SpellRules.aplicar_suporte(sim.c(tg_sa).sheet, world.day_index() + 1)
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg_sa, "buff": "suporte_ambiental", "tags": ["magia"]}, [id, tg_sa]))
		"detectar_ameacas":
			# Detectar Ameaças (divina 1): pessoal, pela cena ou até descarregar (SpellsModule; vale ao explorar).
			var magia_d = world.module("magia")
			if magia_d != null:
				magia_d.ativar_detectar(a.get("aprimoramentos", []))
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "detectar_ameacas", "tags": ["magia"]}, [id]))
		"acalmar_animal", "tranquilidade":
			# Acalmar Animal (divina 1): Vontade anula (+5 se hostil ou em combate); o alvo fica prestativo pela cena e o
			# conjurador recebe +10 em Adestramento e Diplomacia contra ele. Tranquilidade (divina 1): Vontade parcial;
			# falhou, fica indiferente e não ataca; passou, –2 nos ataques. Ação hostil desfaz (_atitude_quebra).
			var cd_t := spell_dc(sh, a)
			var acalmar: bool = a.spell == "acalmar_animal"
			for tg_t in a.get("targets", [a.get("target", "")]):
				var ts_t: CharacterSheet = sim.c(tg_t).sheet
				var sv_t := Checks.skill(ts_t, "vontade", cd_t, world.rules, world.rng, "combat", 5 if acalmar else 0)
				sv_t = _pos_teste(tg_t, sv_t, cd_t, out)
				if sv_t.get("success", false):
					if not acalmar:
						ts_t.add_efeito("magia.tranquilidade", "ataque", -2, "cena")
					out.append(fact("SPELL_MISSED", {"caster": id, "target": tg_t, "spell": a.spell, "saved": true}, [id, tg_t]))
					continue
				_pacificar(id, tg_t, "prestativo" if acalmar else "indiferente", str(a.spell))
				if acalmar:
					sh.add_efeito("magia.acalmar_animal", "diplomacia_vs", 10, "cena", tg_t)
					sh.add_efeito("magia.acalmar_animal", "adestramento_vs", 10, "cena", tg_t)
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg_t, "buff": str(a.spell), "atitude": atitude_de(tg_t), "tags": ["magia"]}, [id, tg_t]))
		"comando":
			# Comando (divina 1): ordem irresistível a humanoides (qualquer criatura com o aprimoramento de 1 PM) que ouçam;
			# +1 alvo por aprimoramento de 2 PM. Vontade anula; quem falha obedece no próprio turno (_obedecer_comando).
			var ordem_c := str(a.get("ordem", "pare"))
			var cd_c := spell_dc(sh, a)
			for tg_c in a.get("targets", [a.get("target", "")]):
				var ts_c: CharacterSheet = sim.c(tg_c).sheet
				if ts_c.has_effective_condition(world.rules, "surdo"):
					out.append(fact("SPELL_MISSED", {"caster": id, "target": tg_c, "spell": "comando", "reason": "nao_ouve"}, [id, tg_c]))
					continue
				var sv_c := Checks.skill(ts_c, "vontade", cd_c, world.rules, world.rng, "combat")
				sv_c = _pos_teste(tg_c, sv_c, cd_c, out)
				if sv_c.get("success", false):
					out.append(fact("SPELL_MISSED", {"caster": id, "target": tg_c, "spell": "comando", "saved": true}, [id, tg_c]))
					continue
				sim.add_marca("comando", tg_c, "comando", "comando", -1, {"ordem": ordem_c, "conjurador": id})
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg_c, "buff": "comando", "ordem": ordem_c, "tags": ["magia"]}, [id, tg_c]))
		"santuario":
			# Santuário (divina 1): toque, pela cena. Quem tentar ação hostil contra o alvo faz Vontade; se falhar, não
			# consegue, perde a ação e não tenta de novo (_santuario_impede). Não protege de área. O alvo que fizer ação
			# hostil dissipa a magia (_santuario_quebra). Aprimoramentos: criaturas não inteligentes (Int –4 ou menos) do
			# tipo escolhido (animal, construto ou morto-vivo) não percebem o alvo (1 PM); também protege de área (9 PM).
			var apr_sa: Array = a.get("aprimoramentos", [])
			var alvo_sa: String = a.get("target", id)
			sim.add_marca("santuario", alvo_sa, "santuario", "santuario", -1, {"cd": spell_dc(sh, a), "conjurador": id, "falharam": [],
				"area": apr_sa.has(1), "tipo_criatura": str(a.get("tipo_criatura", "")) if apr_sa.has(0) else "", "falhas_area": {}})
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": alvo_sa, "buff": "santuario", "tags": ["magia"]}, [id, alvo_sa]))
		"controlar_plantas":
			# Controlar Plantas (divina 1): quadrado de 9m de lado com vegetação, pela cena. Quem falha em Reflexos fica
			# enredado (libertar-se: ação padrão e Acrobacia ou Atletismo, ação "escapar"); a área vira terreno difícil e,
			# no início de cada turno, tenta enredar de novo quem está nela. Truque: anima 1 planta, sem dano nem efeito
			# na concentração. Aprimoramentos: poda (instantânea, terreno normal, dissipa a versão normal); também imóvel;
			# falar com plantas (pessoal, pela cena; ver SpellsModule).
			var apr_cp: Array = a.get("aprimoramentos", [])
			var centro_cp: Vector2i = a.get("tile", sim.c(a.get("target", id)).tile)
			var area_cp := Area.quadrado(centro_cp, Area.quadrados(9.0))
			if a.get("truque", false):
				out.append(fact("PLANT_ANIMATED", {"caster": id, "tile": [centro_cp.x, centro_cp.y]}, [id]))
			elif apr_cp.has(2):
				var magia_cp = world.module("magia")
				if magia_cp != null:
					out.append(magia_cp.falar_com_plantas(sim.c(id).tile))
			elif apr_cp.has(0):
				_podar(area_cp, out)
			else:
				var zid := "controlar_plantas_%d" % sim.zonas.size()
				sim.add_zona(zid, area_cp, "controlar_plantas", -1, "controlar_plantas", {"conjurador": id, "cd": spell_dc(sh, a), "imovel": apr_cp.has(1)})
				sim.add_zona(zid + "_dificil", area_cp, "terreno_dificil", -1, "controlar_plantas", {"zona": zid})
				for tg_cp in _criaturas_vivas_em(area_cp):
					_enredar_plantas(tg_cp, sim.zonas[sim.zonas.size() - 2], out)
		"caminhos_da_natureza":
			# Caminhos da Natureza (divina 1): criaturas escolhidas em alcance curto, por 1 dia (SpellRules.aplicar_caminhos).
			var truque_cn: bool = a.get("truque", false)
			var alvos_cn: Array = [id] if truque_cn else a.get("targets", [a.get("target", id)])
			for tg_cn in alvos_cn:
				SpellRules.aplicar_caminhos(sim.c(tg_cn).sheet, a.get("aprimoramentos", []), truque_cn, world.day_index() + 1)
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg_cn, "buff": "caminhos_da_natureza", "tags": ["magia"]}, [id, tg_cn]))
		"armamento_da_natureza":
			# Armamento da Natureza (divina 1): arma primitiva, natural ou desarmado do alvo (toque) tem o dano aumentado
			# em um passo e é considerada mágica, pela cena; pode mudar o tipo de dano (corte, impacto, perfuração).
			# Aprimoramentos: +1 no ataque (1 PM); execução de movimento (2 PM); +1 a mais no ataque (3 PM, repetível);
			# mais um passo de dano (5 PM, repetível).
			var apr_an: Array = a.get("aprimoramentos", [])
			var alvo_an: String = a.get("target", id)
			var ts_an: CharacterSheet = sim.c(alvo_an).sheet
			var nome_an := str(SpellRules.armamento_ataque(world.rules, ts_an, str(a.get("arma", ""))).nome)
			ts_an.remove_efeito("magia.armamento_da_natureza")
			ts_an.add_efeito("magia.armamento_da_natureza", "armamento_passos", 1 + apr_an.count(3), "cena", nome_an)
			if apr_an.has(0):
				ts_an.add_efeito("magia.armamento_da_natureza", "armamento_ataque", 1 + apr_an.count(2), "cena", nome_an)
			if a.has("tipo_dano"):
				ts_an.add_efeito("magia.armamento_da_natureza", "armamento_tipo", 1, "cena", nome_an + "|" + str(a.tipo_dano))
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": alvo_an, "buff": "armamento_da_natureza", "arma": nome_an, "tags": ["magia"]}, [id, alvo_an]))
		"arma_espiritual":
			# Arma Espiritual (divina 1): a arma preferida da divindade flutua ao lado do conjurador pela cena. Uma vez por
			# rodada, como reação a um ataque corpo a corpo sofrido, causa 2d6 do tipo da arma no atacante
			# (_reacao_arma_espiritual). Some se o conjurador morrer. Aprimoramentos: +1 na Defesa (1 PM), +1 a mais
			# (2 PM, repetível); sustentada com ataque livre a um alvo adjacente (2 PM, 2º círculo); dano de essência
			# (2 PM, 2º círculo); +1d6 (2 PM, até o círculo máximo); duas armas (5 PM, 3º círculo).
			var apr_ae: Array = a.get("aprimoramentos", [])
			var tipo_ae := "essencia" if apr_ae.has(3) else SpellRules.arma_espiritual_tipo(world.rules, str(sh.devotion), str(a.get("tipo_dano", "")))
			var dur_ae := "sustentada" if apr_ae.has(2) else "cena"
			sh.remove_efeito("magia.arma_espiritual")
			sh.add_efeito("magia.arma_espiritual", "arma_espiritual", 2 if apr_ae.has(5) else 1, dur_ae, tipo_ae)
			sh.add_efeito("magia.arma_espiritual", "arma_espiritual_dados", 2 + mini(apr_ae.count(4), SpellRules.circulo_maximo(sh, world.rules)), dur_ae)
			if apr_ae.has(0):
				sh.add_efeito("magia.arma_espiritual", "defesa", 1 + apr_ae.count(1), dur_ae)
			if apr_ae.has(2):
				sh.add_efeito("magia.arma_espiritual", "arma_espiritual_ataque", 1, dur_ae)
				_iniciar_sustentada(id, "arma_espiritual", out)
			for f_ae in (sim.c(id).flags as Array).duplicate():
				if str(f_ae).begins_with("ae_"):
					(sim.c(id).flags as Array).erase(f_ae)
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "arma_espiritual", "tipo": tipo_ae, "tags": ["magia"]}, [id]))
		"despedacar":
			# Despedaçar (divina 1): som agudo. Criatura: 1d8+2 de impacto e atordoada por uma rodada (uma vez por cena);
			# Fortitude reduz à metade e evita o atordoamento. Construto ou objeto mundano: o dobro, ignorando RD.
			# Aprimoramentos: +1d8+2 (2 PM, repetível); objeto Médio, Grande, Enorme ou Colossal; alcance pessoal com
			# esfera de 6m (todas as criaturas, incluindo você, e objetos mundanos na área).
			var apr_d: Array = a.get("aprimoramentos", [])
			var expr_d := SpellRules.despedacar_dano(apr_d)
			var cd_d := spell_dc(sh, a)
			var criaturas_d: Array = []
			var objetos_d: Array = []
			if apr_d.has(5):
				var area_d := Area.esfera(sim.c(id).tile, Area.quadrados(6.0))
				criaturas_d = _criaturas_vivas_em(area_d).filter(func(x): return x != id)   # área de alcance pessoal só afeta você se disser (LB p.225)
				objetos_d = _objetos_quebraveis_em(area_d, SpellRules.despedacar_tamanho_max(apr_d))
			else:
				criaturas_d = a.get("targets", []) if a.has("objeto") else a.get("targets", [a.get("target", id)])
				if a.has("objeto"):
					objetos_d = [str(a.objeto)]
			for tg_d in criaturas_d:
				_despedacar_criatura(id, tg_d, expr_d, cd_d, out)
			var objs_m = world.module("objects")
			for ob_d in objetos_d:
				if objs_m != null:
					out.append_array(objs_m.danificar(ob_d, 2 * int(Dice.roll(expr_d, world.rng, "combat").total), true, "despedacar"))
		"consagrar", "profanar":
			# Consagrar / Profanar (divina 1): esfera de 9m de raio em volta do conjurador por 1 dia (SpellsModule).
			var magia_c = world.module("magia")
			if magia_c != null:
				magia_c.criar_area(str(a.spell), sim.c(id).tile, a.get("aprimoramentos", []), sh, id)
			_refresh_areas_sagradas()
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": str(a.spell), "tags": ["magia", "area"]}, [id]))
		"bencao":
			# Bênção (divina 1): aliados escolhidos em alcance curto recebem +1 em ataques e dano pela cena (+1 por
			# aprimoramento de 2 PM, até o círculo máximo). Anula Perdição. Aprimoramento de 1 PM: 1 cadáver por 1 semana
			# (não se decompõe nem vira morto-vivo; ver SpellsModule).
			var apr_b: Array = a.get("aprimoramentos", [])
			if apr_b.has(0):
				var corpo: String = a.get("target", "")
				var magia_m = world.module("magia")
				if magia_m != null:
					magia_m.preservar_cadaver(corpo, 7)
				out.append(fact("CORPSE_PRESERVED", {"caster": id, "target": corpo}, [id]))
			else:
				var bon: int = SpellRules.bonus_bencao(sh, world.rules, apr_b)
				for tg_b in a.get("targets", [a.get("target", id)]):
					var ts_b: CharacterSheet = sim.c(tg_b).sheet
					if ts_b.has_efeito("magia.perdicao"):
						ts_b.remove_efeito("magia.perdicao")   # Bênção anula Perdição
					ts_b.add_efeito("magia.bencao", "ataque", bon, "cena")
					ts_b.add_efeito("magia.bencao", "dano", bon, "cena")
					out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg_b, "buff": "bencao", "bonus": bon, "tags": ["magia"]}, [id, tg_b]))
		"perdicao":
			# Perdição (divina 1): alvos inimigos recebem penalidade em ataques e dano pela cena.
			var pen: int = SpellRules.penalidade_perdicao(sh, world.rules, a.get("aprimoramentos", []))
			for tg in a.get("targets", [a.get("target", id)]):
				var ts: CharacterSheet = sim.c(tg).sheet
				if ts.has_efeito("magia.bencao"):
					ts.remove_efeito("magia.bencao")   # Perdição anula Bênção
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
				var total := _dados_energia("2d8+2", "trevas", sim.c(tg).tile)
				if apr.has(1):
					total += _dados_energia("1d8+1", "trevas", sim.c(tg).tile)
				var passou := false
				if not apr.has(2):
					_reacao_protecao(id, tg, out)
					var res := Checks.skill(ts, "fortitude", dc, world.rules, world.rng, "combat")
					res = _pos_teste(tg, res, dc, out)
					passou = res.get("success", false)
				if ts.creature_type == "morto-vivo":
					total = ts.curar(total)
					out.append(fact("HEALED", {"actor": id, "target": tg, "amount": total, "pv_after": ts.pv, "source": a.spell, "tags": ["magia", "cura"]}, [id, tg]))
					continue
				if passou:
					total /= 2
				var tags_d: Array = ["magia", "impacto"]
				tags_d.append_array(sim.apply_damage(tg, total + golpe_dano))
				out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": "Infligir Ferimentos", "d20": 0, "mod": 0, "mods": [],
					"total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": total + golpe_dano, "rolls": [],
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
					_imune_condicoes(ts3, "magia.protecao_divina", ["medo", "mental"], "cena")
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
		"heroismo":
			# Heroísmo (divina 3): alvo imune a medo, 40 PV temporários e +4 (+6) em ataque e dano contra o inimigo de maior ND.
			var apr_hr: Array = a.get("aprimoramentos", [])
			var bonus_hr := 6 if apr_hr.has(0) else 4
			var alvo_hr := _inimigo_de_maior_nd(id)
			for tg in a.get("targets", [a.get("target", id)]):
				var ts_hr: CharacterSheet = sim.c(tg).sheet
				ts_hr.pv_temp = maxi(ts_hr.pv_temp, 40)
				_imune_condicoes(ts_hr, "magia.heroismo", ["medo"], "cena")
				if alvo_hr != "":
					ts_hr.add_efeito("magia.heroismo", "ataque_vs", bonus_hr, "cena", alvo_hr, -1, id)
					ts_hr.add_efeito("magia.heroismo", "dano_vs", bonus_hr, "cena", alvo_hr, -1, id)
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg, "buff": "heroismo", "tags": ["magia"]}, [id, tg]))
		"protecao_contra_magia":
			# Proteção contra Magia (divina 3): +5 em testes de resistência (+10). Com imunidade (aprimoramentos 2 e 3),
			# o alvo fica imune a uma ou duas escolas de magia, em vez do bônus.
			var apr_pc: Array = a.get("aprimoramentos", [])
			for tg in a.get("targets", [a.get("target", id)]):
				var ts_pc: CharacterSheet = sim.c(tg).sheet
				if apr_pc.has(1) or apr_pc.has(2):
					for esc in a.get("escolas", []):
						ts_pc.add_efeito("magia.protecao_contra_magia", "imune_escola", 1, "cena", str(esc).to_lower(), -1, id)
				else:
					ts_pc.add_efeito("magia.protecao_contra_magia", "resistencia", 10 if apr_pc.has(0) else 5, "cena", "", -1, id)
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg, "buff": "protecao_contra_magia", "tags": ["magia"]}, [id, tg]))
		"potencia_divina":
			# Potência Divina (divina 3): sustentada. Força +4 (+1), RD 10 (+5) e um categoria de tamanho acima.
			# Com toque (aprimoramento 3), vale para 1 aliado devoto da mesma divindade (senão a magia falha).
			var apr_pd: Array = a.get("aprimoramentos", [])
			var alvos_pd: Array = [id]
			if apr_pd.has(2):
				alvos_pd = [a.get("target", id)]
				if str(sh.devotion) != str(sim.c(alvos_pd[0]).sheet.devotion):
					out.append(fact("SPELL_FAILED", {"caster": id, "check": "devocao", "cd": 0, "reason": "devocao", "d20": 0, "total": 0}, [id]))
					out.append(fact("SPELL_CAST", {"caster": id, "spell": a.spell, "pm_cost": v.cost, "pm_after": sh.pm, "failed": true}, [id]))
					return out
			_iniciar_sustentada(id, "potencia_divina", out)
			for tg in alvos_pd:
				var ts_pd: CharacterSheet = sim.c(tg).sheet
				var tam_original := ts_pd.size
				ts_pd.add_efeito("magia.potencia_divina", "atributo", 4 + (1 if apr_pd.has(0) else 0), "cena", "for", -1, id)
				ts_pd.add_efeito("magia.potencia_divina", "rd", 10 + (5 if apr_pd.has(1) else 0), "cena", "*", -1, id)
				ts_pd.add_efeito("magia.potencia_divina", "tamanho", 0, "cena", tam_original, -1, id)
				ts_pd.size = _tamanho_acima(tam_original)
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg, "buff": "potencia_divina", "tags": ["magia"]}, [id, tg]))
		"dispersar_as_trevas":
			# Dispersar as Trevas (divina 3): dissipa magias até o 3º círculo (4º, 5º) na esfera de 6m (Religião contra a CD
			# de cada uma). Aliados +4 (+1) em testes de resistência e RD 10 até o fim da cena; inimigos cegos 1d4 rodadas
			# (uma vez por cena). Com alvo único (aprimoramento 1): alcance curto, aliado imune a efeitos de trevas.
			var apr_dt: Array = a.get("aprimoramentos", [])
			var tiles_dt: Array = Area.esfera(sim.c(id).tile, Area.quadrados(6.0))
			if apr_dt.has(1):
				tiles_dt = [sim.c(a.get("target", id)).tile]
			var circ_dt := 5 if apr_dt.has(3) else (4 if apr_dt.has(2) else 3)
			_remover_magia_sem_teste("anular_a_luz", tiles_dt, out)   # Dispersar anula Anular a Luz (instantâneo)
			_dispersar_magias(id, tiles_dt, circ_dt, out)
			for cid in sim.combatants.duplicate():
				if not tiles_dt.has(sim.c(cid).tile) or sim.c(cid).sheet.is_dead():
					continue
				var ts_dt: CharacterSheet = sim.c(cid).sheet
				if sim.is_enemy(id, cid):
					if ts_dt.efeito_bonus("cegueira_usada") == 0:
						sim.add_condicao(cid, "cego", int(Dice.roll("1d4", world.rng, "combat").total), "dispersar_as_trevas")
						ts_dt.add_efeito("magia.dispersar_as_trevas", "cegueira_usada", 1, "cena", "", -1, id)
				else:
					ts_dt.add_efeito("magia.dispersar_as_trevas", "resistencia", 4 + (1 if apr_dt.has(0) else 0), "cena", "", -1, id)
					ts_dt.add_efeito("magia.dispersar_as_trevas", "rd", 10, "cena", "*", -1, id)
					if apr_dt.has(1):
						ts_dt.add_efeito("magia.dispersar_as_trevas", "imune", 1, "cena", "trevas", -1, id)
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "dispersar_as_trevas", "tags": ["magia"]}, [id]))
		"anular_a_luz":
			# Anular a Luz (divina 3): dissipa magias até o 3º círculo (4º, 5º) na esfera de 6m (Religião contra a CD de cada
			# uma). Aliados +4 (+1) na Defesa até o fim da cena; inimigos enjoados 1d4 rodadas (uma vez por cena).
			var apr_al: Array = a.get("aprimoramentos", [])
			var tiles_al: Array = Area.esfera(sim.c(id).tile, Area.quadrados(6.0))
			var circ_al := 5 if apr_al.has(2) else (4 if apr_al.has(1) else 3)
			_remover_magia_sem_teste("dispersar_as_trevas", tiles_al, out)   # Anular anula Dispersar as Trevas
			_dispersar_magias(id, tiles_al, circ_al, out)
			for cid in sim.combatants.duplicate():
				if not tiles_al.has(sim.c(cid).tile) or sim.c(cid).sheet.is_dead():
					continue
				var ts_al: CharacterSheet = sim.c(cid).sheet
				if sim.is_enemy(id, cid):
					if ts_al.efeito_bonus("enjoo_usado") == 0:
						sim.add_condicao(cid, "enjoado", int(Dice.roll("1d4", world.rng, "combat").total), "anular_a_luz")
						ts_al.add_efeito("magia.anular_a_luz", "enjoo_usado", 1, "cena", "", -1, id)
				else:
					ts_al.add_efeito("magia.anular_a_luz", "defesa", 4 + (1 if apr_al.has(0) else 0), "cena", "", -1, id)
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "anular_a_luz", "tags": ["magia"]}, [id]))
		"libertacao":
			# Libertação (universal 4): imune a efeitos de movimento e a condições que prendem; ignora terreno difícil (custo_meio)
			# e empurrões. Aprimoramentos: anda na água; escolhe 20 em Atletismo; em Acrobacia (também sem treino); até 5 alvos;
			# Aprisionamento (magia que o jogo ainda não tem).
			var apr_lb: Array = a.get("aprimoramentos", [])
			for tg in a.get("targets", [a.get("target", id)]):
				var ts_lb: CharacterSheet = sim.c(tg).sheet
				ts_lb.add_efeito("magia.libertacao", "libertacao", 1, "cena", "", -1, id)
				for cond_lb in ["agarrado", "enredado", "imovel", "lento", "paralisado"]:
					ts_lb.add_efeito("magia.libertacao", "imune", 1, "cena", cond_lb, -1, id)
					ts_lb.remove_condition(cond_lb)
				if apr_lb.has(0):
					ts_lb.add_efeito("magia.libertacao", "anda_na_agua", 1, "cena", "", -1, id)
				if apr_lb.has(1):
					ts_lb.add_efeito("magia.libertacao", "escolher_20", 1, "cena", "atletismo", -1, id)
				if apr_lb.has(2):
					ts_lb.add_efeito("magia.libertacao", "escolher_20", 1, "cena", "acrobacia", -1, id)
					ts_lb.add_efeito("magia.libertacao", "sem_treino", 1, "cena", "acrobacia", -1, id)
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg, "buff": "libertacao", "tags": ["magia"]}, [id, tg]))
		"marca_da_obediencia":
			# Marca da Obediência (universal 2): Vontade anula. A marca fica na ficha (dura a cena, ou um dia com o aprimoramento) e,
			# a cada rodada, o alvo faz Vontade (`_begin_turn_base`): passou, a marca se dissipa; falhou, gasta o turno obedecendo
			# (e sofre 3d6 de dano psíquico com o outro aprimoramento).
			var apr_mo: Array = a.get("aprimoramentos", [])
			var tg_mo: String = a.get("target", "")
			var cd_mo := spell_dc(sh, a)
			if _resiste(tg_mo, "vontade", cd_mo, out):
				out.append(fact("SPELL_MISSED", {"caster": id, "target": tg_mo, "spell": "marca_da_obediencia", "reason": "resistiu"}, [id, tg_mo]))
			else:
				var ts_mo: CharacterSheet = sim.c(tg_mo).sheet
				var fim_mo := "dia" if apr_mo.has(0) else "cena"
				var ate_mo := world.day_index() + 1 if apr_mo.has(0) else -1
				ts_mo.add_efeito("magia.marca_da_obediencia", "marca_obediencia", cd_mo, fim_mo, str(a.ordem), ate_mo, id)
				if apr_mo.has(1):
					ts_mo.add_efeito("magia.marca_da_obediencia", "marca_dano", 1, fim_mo, "", ate_mo, id)
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg_mo, "buff": "marca_da_obediencia", "ordem": str(a.ordem), "tags": ["magia"]}, [id, tg_mo]))
		"visao_da_verdade":
			# Visão da Verdade (universal 4): vê através de camuflagem e escuridão (efeito "visao_verdade", lido em falha_nevoa e
			# falha_escuridao); +10 em Percepção; +10 em Intuição; paredes finas translúcidas (efeito marcado: o jogo ainda não tem
			# linha de visão por paredes). Ilusões e transmutações: o jogo ainda não tem disfarces nem formas alteradas para revelar.
			var apr_vv: Array = a.get("aprimoramentos", [])
			var alvo_vv: String = a.get("target", id) if apr_vv.has(0) else id
			var ts_vv: CharacterSheet = sim.c(alvo_vv).sheet
			ts_vv.add_efeito("magia.visao_da_verdade", "visao_verdade", 1, "cena", "", -1, id)
			if apr_vv.has(1):
				ts_vv.add_efeito("magia.visao_da_verdade", "pericia_percepcao", 10, "cena", "", -1, id)
			if apr_vv.has(2):
				ts_vv.add_efeito("magia.visao_da_verdade", "pericia_intuicao", 10, "cena", "", -1, id)
			if apr_vv.has(3):
				ts_vv.add_efeito("magia.visao_da_verdade", "ve_paredes", 1, "cena", "", -1, id)
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": alvo_vv, "buff": "visao_da_verdade", "tags": ["magia"]}, [id, alvo_vv]))
		"furia_do_panteao":
			# Fúria do Panteão (divina 5): nuvem de 90m sustentada. Sem ataques à distância, condição terrível para lançar magia,
			# visibilidade reduzida para os inimigos. A cada turno, uma ordem de movimento (`furia`): nevasca, raios, siroco, trovões.
			var area_fp: Array = Area.esfera(a.get("tile", sim.c(id).tile), Area.quadrados(45.0))
			sim.add_zona("furia_" + id, area_fp, "furia", -1, "furia_do_panteao", {"conjurador": id, "cd": spell_dc(sh, a)})
			_iniciar_sustentada(id, "furia_do_panteao", out)
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "furia_do_panteao", "tags": ["magia", "area"]}, [id]))
		"toque_da_morte":
			# Toque da Morte (universal 5): 10d8+10 de trevas. Abaixo da metade dos PV, Fortitude: falhou, PV a –10; passou, dano normal.
			# Aprimoramentos: raio (curto); raios em todos os inimigos em alcance curto.
			var apr_tm: Array = a.get("aprimoramentos", [])
			var alvos_tm: Array = a.get("targets", [a.get("target", id)])
			if apr_tm.has(1):
				alvos_tm = sim.combatants.keys().filter(func(x): return sim.is_enemy(id, x) and not sim.c(x).sheet.is_dead() and CombatSim.cheb(sim.c(id).tile, sim.c(x).tile) <= ALCANCE_CURTO_QUADRADOS)
			for tg in alvos_tm:
				var ts_tm: CharacterSheet = sim.c(tg).sheet
				var cd_tm := spell_dc(sh, a)
				var fraco_tm: bool = ts_tm.pv * 2 < ts_tm.pv_max
				var morreu_tm := false
				if fraco_tm and not _resiste(tg, "fortitude", cd_tm, out):
					ts_tm.pv = mini(ts_tm.pv, -10)
					morreu_tm = true
				var r_tm := Dice.roll("10d8+10", world.rng, "combat", 1, battle_bonus(sh))
				var dano_tm := 0 if morreu_tm else _dano_por_tipo(ts_tm, "trevas", int(r_tm.total))
				var tags_tm: Array = ["magia", "trevas"]
				tags_tm.append_array(sim.apply_damage(tg, dano_tm))
				out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg, "weapon": "Toque da Morte", "d20": 0, "mod": 0, "mods": [], "total": 0, "defense": cd_tm,
					"camo_roll": 0, "hit": true, "crit": false, "damage": dano_tm, "rolls": r_tm.rolls, "pv_after": ts_tm.pv, "special": false, "ranged": apr_tm.has(0) or apr_tm.has(1),
					"spell": true, "tags": tags_tm}, [id, tg]))
		"palavra_primordial":
			# Palavra Primordial (universal 5): atordoar (1d4+1 rodadas, uma vez por cena; se resistir, desprevenido 1d4), cegar (resistiu:
			# ofuscado 1d4) ou matar (Vontade e, com mais da metade dos PV, também Fortitude; resistiu: 10d8 PV e sangrando).
			var tg_pp: String = a.target
			var ts_pp: CharacterSheet = sim.c(tg_pp).sheet
			var cd_pp := spell_dc(sh, a)
			var passou_pp := _resiste(tg_pp, "vontade", cd_pp, out)
			match str(a.efeito):
				"atordoar":
					if passou_pp or ts_pp.efeito_bonus("palavra_atordoou") > 0:
						sim.add_condicao(tg_pp, "desprevenido", int(Dice.roll("1d4", world.rng, "combat").total), "palavra_primordial")
					else:
						sim.add_condicao(tg_pp, "atordoado", int(Dice.roll("1d4+1", world.rng, "combat").total), "palavra_primordial")
						ts_pp.add_efeito("magia.palavra_primordial", "palavra_atordoou", 1, "cena", "", -1, id)
				"cegar":
					if passou_pp:
						sim.add_condicao(tg_pp, "ofuscado", int(Dice.roll("1d4", world.rng, "combat").total), "palavra_primordial")
					else:
						ts_pp.add_efeito("magia.palavra_primordial", "condicao", 0, "cena", "cego", -1, id)
						ts_pp.add_condition("cego", world.rules)
				"matar":
					var sobrevive := passou_pp
					if not sobrevive and ts_pp.pv * 2 > ts_pp.pv_max:
						sobrevive = _resiste(tg_pp, "fortitude", cd_pp, out)   # mais da metade dos PV: segundo teste
					if sobrevive:
						sim.apply_damage(tg_pp, int(Dice.roll("10d8", world.rng, "combat").total))
						sim.add_condicao(tg_pp, "sangrando", 0, "palavra_primordial")
					else:
						ts_pp.pv = mini(ts_pp.pv, ts_pp.death_threshold())
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg_pp, "buff": "palavra_primordial", "efeito": str(a.efeito), "tags": ["magia"]}, [id, tg_pp]))
		"segunda_chance":
			# Segunda Chance (divina 5): cura 200 PV (+20) e várias condições; até 5 alvos; ou quem morreu há até uma rodada.
			# Mortos-vivos sofrem a luz como dano (Vontade reduz à metade).
			var apr_sc: Array = a.get("aprimoramentos", [])
			for tg in a.get("targets", [a.get("target", id)]):
				var ts_sc: CharacterSheet = sim.c(tg).sheet
				var total_sc := 200 + 20 * apr_sc.count(0)
				if ts_sc.creature_type == "morto-vivo":
					var cd_sc := spell_dc(sh, a)
					var dano_sc := _dano_por_tipo(ts_sc, "luz", total_sc)
					if _resiste(tg, "vontade", cd_sc, out):
						dano_sc = maxi(1, dano_sc / 2)
					sim.apply_damage(tg, dano_sc)
					continue
				var cura_sc := ts_sc.curar(total_sc)
				for e_sc in ts_sc.efeitos.duplicate(true):
					if e_sc.stat == "condicao" and CONDICOES_SEGUNDA_CHANCE.has(str(e_sc.tipo)):
						ts_sc.anular_magia(str(e_sc.id))
				for cond_sc in CONDICOES_SEGUNDA_CHANCE:
					ts_sc.remove_condition(cond_sc)
				out.append(fact("HEALED", {"actor": id, "target": tg, "amount": cura_sc, "pv_after": ts_sc.pv, "source": "segunda_chance"}, [id, tg]))
		"imobilizar":
			# Imobilizar (universal 3): Vontade; falhou, paralisado; passou, lento. A cada rodada o alvo gasta a ação completa
			# num novo teste (`_begin_turn_base`) e, se passar, se liberta.
			var cd_im := spell_dc(sh, a)
			for tg in a.get("targets", [a.get("target", id)]):
				var ts_im: CharacterSheet = sim.c(tg).sheet
				var cond_im := "lento" if _resiste(tg, "vontade", cd_im, out) else "paralisado"
				if ts_im.efeito_bonus("imune", cond_im) > 0:
					continue
				ts_im.add_efeito("magia.imobilizar", "condicao", 0, "cena", cond_im, -1, id)
				ts_im.add_condition(cond_im, world.rules)
				ts_im.add_efeito("magia.imobilizar", "imobilizar_cd", cd_im, "cena", "", -1, id)
				out.append(fact("CONDITION_APPLIED", {"actor": id, "target": tg, "condition": cond_im, "tags": ["magia"]}, [id, tg]))
		"pele_de_pedra":
			# Pele de Pedra (universal 3): RD 5 (10 de aço); toque; um dia. Estátua (4º círculo): Fortitude anula; 1d4 rodadas, ou
			# permanente (5º). A estátua é o estado "petrificado" (RD 8).
			var apr_pp: Array = a.get("aprimoramentos", [])
			var alvo_pp: String = a.get("target", id) if (apr_pp.has(0) or apr_pp.has(3) or apr_pp.has(4)) else id
			var ts_pp: CharacterSheet = sim.c(alvo_pp).sheet
			if apr_pp.has(3) or apr_pp.has(4):
				if _resiste(alvo_pp, "fortitude", spell_dc(sh, a), out):
					out.append(fact("SPELL_MISSED", {"caster": id, "target": alvo_pp, "spell": "pele_de_pedra", "reason": "resistiu"}, [id, alvo_pp]))
				elif apr_pp.has(4):
					ts_pp.add_efeito("magia.pele_de_pedra", "condicao", 0, "permanente", "petrificado", -1, id)
					ts_pp.add_condition("petrificado", world.rules)
					out.append(fact("CONDITION_APPLIED", {"actor": id, "target": alvo_pp, "condition": "petrificado", "tags": ["magia"]}, [id, alvo_pp]))
				else:
					sim.add_condicao(alvo_pp, "petrificado", int(Dice.roll("1d4", world.rng, "combat").total), "pele_de_pedra")
					out.append(fact("CONDITION_APPLIED", {"actor": id, "target": alvo_pp, "condition": "petrificado", "tags": ["magia"]}, [id, alvo_pp]))
			else:
				ts_pp.add_efeito("magia.pele_de_pedra", "rd", 10 if apr_pp.has(2) else 5, "dia" if apr_pp.has(1) else "cena", "*", world.day_index() + 1 if apr_pp.has(1) else -1, id)
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": alvo_pp, "buff": "pele_de_pedra", "tags": ["magia"]}, [id, alvo_pp]))
		"conjurar_mortos_vivos":
			# Conjurar Mortos-Vivos (universal 2): sustentada; 6 esqueletos (+1 por aprimoramento), carniçais (3º círculo) ou
			# sombras (4º). Não agem sozinhos: ordens "mover_mortos" (movimento) e "atacar_mortos" (padrão).
			var apr_cm: Array = a.get("aprimoramentos", [])
			var regra_cm := "criatura.sombra_capanga" if apr_cm.has(2) else ("criatura.carnical_capanga" if apr_cm.has(1) else "criatura.esqueleto_capanga")
			_iniciar_sustentada(id, "conjurar_mortos_vivos", out)
			var centro_cm: Vector2i = a.get("tile", sim.c(id).tile)
			for i in range(6 + apr_cm.count(0)):
				var morto := invocar(id, regra_cm, -1, "mortos_vivos", centro_cm)
				sim.c(morto).flags.append("capanga")
				sim.c(morto).flags.append("capanga_de_" + id)
				if apr_cm.has(2):
					sim.c(morto).flags.append("incorporeo")
				_imunidades_capanga(sim.c(morto).sheet)
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "conjurar_mortos_vivos", "quantidade": 6 + apr_cm.count(0), "tags": ["magia"]}, [id]))
		"dissipar_magia":
			# Dissipar Magia (universal 2): teste de Misticismo; dissipa magias com CD igual ou menor. Aprimoramento (5º círculo):
			# disjunção numa esfera de 9m, tudo cai sem teste. (O jogo ainda não tem itens mágicos permanentes além dos encantos
			# de magia, que são efeitos e caem junto.)
			var apr_dm: Array = a.get("aprimoramentos", [])
			var area_dm: bool = apr_dm.has(0) or bool(a.get("no_chao", false)) or bool(a.get("area", false))
			var centro_dm: Vector2i = a.get("tile", sim.c(id).tile) if area_dm else sim.c(a.get("target", id)).tile
			var tiles_dm: Array = [centro_dm]
			if area_dm:
				tiles_dm = Area.esfera(centro_dm, Area.quadrados(9.0 if apr_dm.has(0) else 3.0))
			_dissipar_magia(id, tiles_dm, apr_dm.has(0), out)
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "dissipar_magia", "tags": ["magia"]}, [id]))
		"manto_do_cruzado":
			# Manto do Cruzado (4º círculo): sustentada (1 PM por turno, _sustentar); a versão é a escolhida ao aprender.
			_iniciar_sustentada(id, "manto_do_cruzado", out)
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
		"colera_de_azgher":
			# Cólera de Azgher (4º círculo): esfera de 6m (6m a mais com o aprimoramento) no alvo. Reflexos reduz à metade.
			# Quem falha fica cego por 1d4 rodadas e em chamas. 10d6 de fogo (10d8 contra mortos-vivos; +2d6/+2d8 com o aprimoramento).
			# Aprimoramento de 5 PM: dissipa todas as magias de necromancia ativas na área.
			var apr_cz: Array = a.get("aprimoramentos", [])
			var raio_cz := 6.0 + (6.0 if apr_cz.has(1) else 0.0)
			var tiles_cz: Array = Area.esfera(sim.c(a.get("target", id)).tile, Area.quadrados(raio_cz))
			var cd_cz := spell_dc(sh, a)
			for tg_cz in _criaturas_vivas_em(tiles_cz):
				var ts_cz: CharacterSheet = sim.c(tg_cz).sheet
				var faces_cz := 8 if ts_cz.creature_type == "morto-vivo" else 6
				var dano_cz := int(Dice.roll("%dd%d" % [10 + (2 if apr_cz.has(0) else 0), faces_cz], world.rng, "combat").total)
				var sv_cz := Checks.skill(ts_cz, "reflexos", cd_cz, world.rules, world.rng, "combat")
				sv_cz = _pos_teste(tg_cz, sv_cz, cd_cz, out)
				var passou_cz: bool = sv_cz.get("success", false)
				if passou_cz:
					dano_cz = dano_cz / 2
				else:
					sim.add_condicao(tg_cz, "cego", int(Dice.roll("1d4", world.rng, "combat").total), "colera_de_azgher")
					sim.add_condicao(tg_cz, "em_chamas", 0, "colera_de_azgher")   # sem rodadas: dura até apagar o fogo
				dano_cz = _dano_por_tipo(ts_cz, "fogo", dano_cz)
				var tags_cz: Array = ["magia", "fogo"]
				if passou_cz:
					tags_cz.append("resistiu")
				tags_cz.append_array(sim.apply_damage(tg_cz, dano_cz))
				out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tg_cz, "weapon": "Cólera de Azgher", "d20": 0, "mod": 0,
					"mods": [], "total": 0, "defense": 0, "camo_roll": 0, "hit": true, "crit": false, "damage": dano_cz, "rolls": [],
					"pv_after": ts_cz.pv, "special": false, "ranged": true, "spell": true, "save": "reflexos", "saved": passou_cz, "tags": tags_cz}, [id, tg_cz]))
			if apr_cz.has(2):
				_dissipar_na_area(tiles_cz, "Necromancia", out)
		"guardiao_divino":
			# Guardião Divino (4º círculo): invoca um elemental de luz (Pequeno, incorpóreo, 100 pontos de luz). Ele age
			# uma vez por rodada no próprio turno (`_turno_guardiao`) e termina quando a luz acaba.
			var guardiao := invocar(id, "criatura.elemental_de_luz", -1, "guardiao_divino")
			sim.c(guardiao).flags.append("guardiao")
			sim.c(guardiao).flags.append("incorporeo")
			sim.c(guardiao).sheet.add_efeito("magia.guardiao_divino", "luz", LUZ_GUARDIAO, "cena")
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": guardiao, "buff": "guardiao_divino", "luz": LUZ_GUARDIAO, "tags": ["magia"]}, [id, guardiao]))
		"arma_magica":
			# Arma Mágica (1º círculo): a arma empunhada do alvo recebe +1 em ataque e dano (+2 com o 1º aprimoramento,
			# limitado pelo círculo máximo que você lança). Quem a empunha e é o conjurador usa o atributo-chave de magia
			# no ataque. Aprimoramento 1 (2 PM): dano extra de 1d6 do tipo escolhido; 2 (3 PM): 2d6. Não empilha.
			var alvo_am: String = str(a.get("target", id))
			var sh_am: CharacterSheet = sim.c(alvo_am).sheet
			var arma_am := str(sh_am.equipment.get("weapon", ""))
			var apr_am: Array = a.get("aprimoramentos", [])
			sh_am.remove_efeito("magia.arma_magica")   # não empilha consigo; outras magias de dano (Chamejar) ficam
			var bonus_am := mini(2 if apr_am.has(0) else 1, SpellRules.circulo_maximo(sh, world.rules))
			sh_am.add_efeito("magia.arma_magica", "encanto_arma", bonus_am, "cena", arma_am)
			if alvo_am == id:
				sh_am.add_efeito("magia.arma_magica", "atributo_arma", 1, "cena", arma_am)
			if apr_am.has(1):
				var dados_am := 2 if apr_am.has(2) else 1
				sh_am.add_efeito("magia.arma_magica", "dano_elemental", dados_am, "cena", arma_am + "|" + str(a.get("elemento", "fogo")))
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": alvo_am, "buff": "arma_magica", "arma": arma_am, "bonus": bonus_am, "tags": ["magia"]}, [id, alvo_am]))
		"orientacao":
			# Orientação (1º círculo): próximo teste de perícia com dois dados (melhor). Aprimoramento 0 (2 PM): dura a
			# cena e vale para as perícias de um atributo. Aprimoramento 1 (5 PM): o mesmo para um grupo de atributos
			# (físicos ou mentais). Aprimoramento 2 (5 PM): alvos escolhidos.
			var apr_o: Array = a.get("aprimoramentos", [])
			var alvos_o: Array = [str(a.get("target", id))]
			if apr_o.has(2):
				alvos_o = []
				for tg in a.get("targets", []):
					if sim.combatants.has(tg):
						alvos_o.append(str(tg))
			var grupo_o: Array = ["for", "des", "con"] if str(a.get("grupo", "")) == "fisicos" else ["int", "sab", "car"]
			for tg in alvos_o:
				var sh_o: CharacterSheet = sim.c(tg).sheet
				if apr_o.has(0):
					sh_o.add_efeito("magia.orientacao", "vantagem_atributo", 1, "cena", str(a.get("atributo", "")))
				elif apr_o.has(1):
					for attr in grupo_o:
						sh_o.add_efeito("magia.orientacao", "vantagem_atributo", 1, "cena", attr)
				else:
					sh_o.add_efeito("magia.orientacao", "vantagem_pericia", 1, "rodada_orientacao")
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg, "buff": "orientacao", "tags": ["magia"]}, [id, tg]))
		"lagrimas_de_wynna":
			# Lágrimas de Wynna (5º círculo): alvo faz Vontade; falha, perde magias arcanas até o fim da cena; passou,
			# perde por uma rodada. Aprimoramento 1 (2 PM): esfera de 6m com as criaturas escolhidas. Aprimoramento 2
			# (5 PM + 1 PM): ritual de um dia com o alvo em alcance curto (`processar_rituais_do_dia`).
			var cd_lw := spell_dc(sh, a)
			var apr_lw: Array = a.get("aprimoramentos", [])
			if apr_lw.has(1):
				sh.add_efeito("magia.lagrimas_de_wynna", "ritual", cd_lw, "ritual", str(a.get("target", "")), world.day_index() + 1)
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": a.get("target", ""), "buff": "lagrimas_ritual", "tags": ["magia"]}, [id]))
			else:
				var alvos_lw: Array = [str(a.get("target", ""))]
				if apr_lw.has(0):
					var centro_lw: Vector2i = sim.c(str(a.get("target", ""))).tile
					alvos_lw = []
					for tg in a.get("targets", []):
						if tg != id and sim.combatants.has(tg) and sim.ids_em(Area.esfera(centro_lw, Area.quadrados(6.0))).has(tg):
							alvos_lw.append(tg)
				for tg in alvos_lw:
					var sv_lw := Checks.skill(sim.c(tg).sheet, "vontade", cd_lw, world.rules, world.rng, "combat")
					sv_lw = _pos_teste(tg, sv_lw, cd_lw, out)
					if sv_lw.get("success", false):
						sim.c(tg).sheet.add_efeito("magia.lagrimas_de_wynna", "bloqueio_arcana", 1, "rodada")
					else:
						sim.c(tg).sheet.add_efeito("magia.lagrimas_de_wynna", "bloqueio_arcana", 1, "cena")
					out.append(fact("BUFF_APPLIED", {"actor": id, "target": tg, "buff": "lagrimas_de_wynna", "passou": sv_lw.get("success", false), "tags": ["magia"]}, [id, tg]))
		"banimento":
			# Banimento (3º círculo): execução de 1d3+1 rodadas (`_resolver_conjuracao`). Concentração: ser ferido enquanto
			# conjura exige Vontade com CD igual ao dano. Itens que se opõem ao alvo somam +2 na CD (`itens_opostos`).
			var cd_b := spell_dc(sh, a) + 2 * int(a.get("itens_opostos", 0))
			var rodadas_b := int(Dice.roll("1d3+1", world.rng, "combat").total)
			sim.conjurando[id] = {"alvo": a.get("target", ""), "cd": cd_b, "apr": a.get("aprimoramentos", []).has(0), "rodadas": rodadas_b}
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": a.get("target", ""), "buff": "banimento_conjurando", "rodadas": rodadas_b, "tags": ["magia"]}, [id]))
		"aura_divina":
			# Aura Divina (5º círculo): esfera de 9m que segue você pela cena (ver `_refresh_aura_divina`). A CD guarda
			# a da magia; a condição (esmorecido, debilitado ou lento) é a escolha do conjurador, aplicada a quem entra.
			var cond_ad := str(a.get("condicao", "esmorecido"))
			if not CONDICOES_AURA_DIVINA.has(cond_ad):
				cond_ad = "esmorecido"
			sh.add_efeito("magia.aura_divina", "cd", spell_dc(sh, a), "cena")
			sh.add_efeito("magia.aura_divina", "aprimoramento", 1 if a.get("aprimoramentos", []).has(0) else 0, "cena")
			sh.add_efeito("magia.aura_divina", "condicao", 0, "cena", cond_ad)
			_refresh_bencaos()
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "aura_divina", "tags": ["magia"]}, [id]))
		"ligacao_sombria":
			# Ligação Sombria (4º círculo): o alvo faz Fortitude; se falhar, fica ligado a você por um dia. Enquanto a ligação
			# durar, o dano e as condições que você sofrer também atingem o alvo (ele faz Fortitude; falha, sofre igual).
			# A ligação acaba se o alvo cair a 0 PV, exceto com o aprimoramento de 5 PM.
			var alvo_ls: String = a.get("target", id)
			var cd_ls := spell_dc(sh, a)
			var sv_ls := Checks.skill(sim.c(alvo_ls).sheet, "fortitude", cd_ls, world.rules, world.rng, "combat")
			sv_ls = _pos_teste(alvo_ls, sv_ls, cd_ls, out)
			if sv_ls.get("success", false):
				out.append(fact("SPELL_MISSED", {"caster": id, "target": alvo_ls, "spell": a.spell}, [id, alvo_ls]))
			else:
				sh.add_efeito("magia.ligacao_sombria", "ligacao", cd_ls, "dia", alvo_ls)
				if a.get("aprimoramentos", []).has(0):
					sh.add_efeito("magia.ligacao_sombria", "ligacao_perene", 1, "dia")
				out.append(fact("BUFF_APPLIED", {"actor": id, "target": alvo_ls, "buff": "ligacao_sombria", "tags": ["magia"]}, [id, alvo_ls]))
		"nevoa":
			# Névoa (universal, 1º círculo): nuvem de 6m de raio no ponto escolhido, pela cena; obscurece a visão
			# (CombatSim.falha_nevoa). Vento forte a dispersa em 4 rodadas, vendaval em 1. Não se forma sob a água.
			# Aprimoramentos: 0 funciona sob a água (1 PM); 1 criaturas escolhidas enxergam através (2 PM, 2º círculo);
			# 2 cheiro, Fortitude ou enjoado (2 PM); 3 ácido 2d4 no início dos turnos (2 PM); 4 +2d4 de ácido (3 PM);
			# 5 espessa: deslocamento 3m e –2 em ataque e dano (5 PM).
			var apr_nv: Array = a.get("aprimoramentos", [])
			var centro_nv: Vector2i = a.get("tile", sim.c(a.get("target", id)).tile)
			var tiles_nv: Array = []
			for t_nv in Area.esfera(centro_nv, Area.quadrados(6.0)):
				if apr_nv.has(0) or not world.db.is_water(t_nv):
					tiles_nv.append(t_nv)
			var vento_nv := _vento()
			var rodadas_nv := 4 if vento_nv == "forte" else (1 if vento_nv == "vendaval" else -1)
			var dados_nv := {"conjurador": id, "cd": spell_dc(sh, a), "afeta": "todos", "lado": sim.c(id).side}
			if apr_nv.has(1):
				var esc: Array = a.get("enxergam", [])
				if esc.is_empty():
					for e_id in sim.combatants:
						if not sim.is_enemy(id, e_id) and CombatSim.cheb(sim.c(id).tile, sim.c(e_id).tile) <= ALCANCE_CURTO_QUADRADOS:
							esc.append(e_id)
				dados_nv["enxergam"] = esc
			if apr_nv.has(2):
				dados_nv["cheiro"] = true
			if apr_nv.has(3):
				dados_nv["dano_inicio_turno"] = "4d4" if apr_nv.has(4) else "2d4"
				dados_nv["tipo_dano"] = "acido"
			if apr_nv.has(5):
				dados_nv["espessa"] = true
			sim.add_zona("nevoa_%d" % sim.zonas.size(), tiles_nv, "nevoa", rodadas_nv, "nevoa", dados_nv)
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "nevoa", "tags": ["magia", "zona"]}, [id]))
		"poeira_da_podridao":
			# Poeira da Podridão (3º círculo): nuvem de 6m de raio no alvo, pela cena. Ao lançar e no início de cada turno do
			# conjurador, quem está na nuvem faz Fortitude: 2d8+8 de trevas (metade no teste). Quem falha não recupera PV
			# por uma rodada. Aprimoramento: +1d8+4 de dano (2 PM).
			var apr_p: Array = a.get("aprimoramentos", [])
			var dano_p := "3d8+12" if apr_p.has(0) else "2d8+8"
			var centro_p: Vector2i = sim.c(a.get("target", id)).tile
			sim.add_zona("poeira_da_podridao_%d" % sim.zonas.size(), Area.esfera(centro_p, Area.quadrados(6.0)), "poeira_da_podridao", -1, "poeira_da_podridao",
				{"conjurador": id, "dano_turno": dano_p, "cd": spell_dc(sh, a), "afeta": "todos"})
			_aplicar_nuvem(sim.zonas[sim.zonas.size() - 1], out)
		"premonicao":
			# Premonição (4º círculo): pela cena, uma vez por rodada, rola de novo um teste próprio que falhou (ver Checks.skill).
			# O aprimoramento de 10 PM dura um dia. O de 3 PM é reação, tratada em _pos_teste.
			var dur_pr := "dia" if a.get("aprimoramentos", []).has(1) else "cena"
			sh.add_efeito("magia.premonicao", "premonicao", 1, dur_pr)
			sh.add_efeito("magia.premonicao", "premonicao_uso", 1, "rodada")
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": id, "buff": "premonicao", "tags": ["magia"]}, [id]))
		"invulnerabilidade":
			# Invulnerabilidade (5º círculo): até o fim da cena, imune à proteção escolhida: mental (condições mentais, e os
			# efeitos de encantamento e ilusão, que chegam ao jogo como essas condições) ou física (condições físicas, doenças,
			# acertos críticos e ataques furtivos). Aprimoramento: alcance curto e outra criatura como alvo.
			var alvo_i: String = a.get("target", id)
			var modo_i := str(a.get("modo", "mental"))
			var ts_i: CharacterSheet = sim.c(alvo_i).sheet
			for cond_i in (SpellRules.INVULN_FISICA if modo_i == "fisica" else SpellRules.INVULN_MENTAL):
				ts_i.add_efeito("magia.invulnerabilidade", "imune", 1, "cena", str(cond_i))
			if modo_i == "fisica":
				ts_i.add_efeito("magia.invulnerabilidade", "imune", 1, "cena", "critico")
				ts_i.add_efeito("magia.invulnerabilidade", "imune", 1, "cena", "furtivo")
			out.append(fact("BUFF_APPLIED", {"actor": id, "target": alvo_i, "buff": "invulnerabilidade", "tags": ["magia"]}, [id, alvo_i]))
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
				var luz := _dados_energia("6d6", "luz", sim.c(tg_cl).tile)
				if apr_cl.has(1):
					luz += _dados_energia("1d6", "luz", sim.c(tg_cl).tile)
				var dano_cl := _dano_por_tipo(ts_cl, "fogo", fogo) + _dano_por_tipo(ts_cl, "luz", luz)
				var sv_cl := Checks.skill(ts_cl, "reflexos", cd_cl, world.rules, world.rng, "combat")
				sv_cl = _pos_teste(tg_cl, sv_cl, cd_cl, out)
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
				var cura_s := _dados_energia("2d8+4", "luz", sim.c(tg_s).tile)
				if apr_s.has(0):
					cura_s += _dados_energia("1d8+2", "luz", sim.c(tg_s).tile)
				if apr_s.has(1) and ts_s.pv < 0:
					ts_s.pv = 0
				cura_s = ts_s.curar(cura_s)
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
					# Mortos-vivos sofrem dano de efeitos mágicos de cura de luz (Ameaças p.13): Vontade reduz à metade.
					# Truque (0 PM, LB p.189): 1d8 de dano de luz em vez da cura.
					var cd_c := spell_dc(sh, a)
					var sv_c := Checks.skill(ts, "vontade", cd_c, world.rules, world.rng, "combat")
					sv_c = _pos_teste(tgt, sv_c, cd_c, out)
					var dano_c := 0
					if a.get("truque", false):
						dano_c = _dados_energia("1d8", "luz", sim.c(tgt).tile)
					else:
						dano_c = _dados_energia(str(sp.cura), "luz", sim.c(tgt).tile)
						if apr_c.has(0):
							dano_c += _dados_energia("1d8+1", "luz", sim.c(tgt).tile)
					if sv_c.get("success", false):
						dano_c = maxi(1, dano_c / 2)
					var tags_c: Array = ["magia", "luz"]
					if sv_c.get("success", false): tags_c.append("resistiu")
					tags_c.append_array(sim.apply_damage(tgt, dano_c))
					out.append(fact("ATTACK_RESOLVED", {"attacker": id, "target": tgt, "weapon": "Curar Ferimentos (truque)" if a.get("truque", false) else "Curar Ferimentos", "d20": int(sv_c.get("d20", 0)), "mod": int(sv_c.get("mod", 0)),
						"mods": [], "total": int(sv_c.get("total", 0)), "defense": cd_c, "camo_roll": 0, "hit": true, "crit": false, "damage": dano_c, "rolls": [],
						"pv_after": ts.pv, "special": false, "ranged": false, "spell": true, "save": "vontade", "saved": sv_c.get("success", false), "tags": tags_c}, [id, tgt]))
					continue
				var cura_c := _dados_energia(str(sp.cura), "luz", sim.c(tgt).tile)
				if apr_c.has(0):
					cura_c += _dados_energia("1d8+1", "luz", sim.c(tgt).tile)
				cura_c = ts.curar(cura_c)
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
		if not CondicoesCombate.pode_reagir(R.sheet, world.rules):
			continue
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
	if sim.c("player").has("sheet") and not CondicoesCombate.pode_reagir(sim.c("player").sheet, world.rules):
		return 0
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
	if sim.c("player").has("sheet") and not CondicoesCombate.pode_reagir(sim.c("player").sheet, world.rules):
		return
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


## Dano elemental da Arma Mágica (aprimoramento): dados de 1d6 (2d6 com o 2º aprimoramento) do tipo escolhido.
## Dados de dano de energia na arma empunhada (Arma Mágica, Controlar Fogo: Chamejar); efeitos de magias diferentes somam.
func _dano_elemental_arma(sh: CharacterSheet) -> Array:
	var arma := str(sh.equipment.get("weapon", ""))
	var out: Array = []
	for e in sh.efeitos:
		if e.stat == "dano_elemental" and str(e.tipo).begins_with(arma + "|"):
			out.append({"tipo": str(e.tipo).get_slice("|", 1), "dados": int(e.bonus)})
	return out


func _resolve_attack(attacker: String, target: String, v: Dictionary, special: bool) -> Array:
	var A := sim.c(attacker)
	var T := sim.c(target)
	var atk: Dictionary = v.atk
	var pre: Array = []
	v.defense = int(v.defense) + _reacao_escudo(attacker, target, pre)   # reação de magia antes da rolagem
	v.defense = int(v.defense) + _reacao_armadura_arcana(attacker, target, pre)
	var d20: int = world.rng.roll("combat", 1, 20)[0]
	var camo_roll := 0
	var camo_miss := false
	if int(v.miss_chance) > 0:
		camo_roll = world.rng.roll("combat", 1, 10)[0]
		camo_miss = camo_roll <= int(v.miss_chance) / 10
		if camo_miss and A.sheet.has_power("sentidos_agucados"):   # Sentidos Aguçados: rola de novo a chance de falha
			camo_roll = world.rng.roll("combat", 1, 10)[0]
			camo_miss = camo_roll <= int(v.miss_chance) / 10
	var total := d20 + int(v.mod)
	var repelido: bool = A.sheet.efeito_bonus_tipo("repele_arma", target) > 0   # Controlar Madeira (repelir)
	var hit := total >= int(v.defense) and not camo_miss and not repelido
	var imune_critico: bool = int(T.sheet.efeito_bonus("imune", "critico")) > 0   # Invulnerabilidade (física)
	var crit: bool = hit and d20 >= int(atk.margem) and not imune_critico
	var dmg := 0
	var rolls: Array = []
	var tags: Array = ["ataque"]
	# Valentão (LB p.66): +2 ataque e dano contra caído/desprevenido/flanqueado/indefeso
	var bully: bool = v.mods.any(func(m): return m[0] == "valentão")
	if hit:
		var extra := int(A.sheet.attrs["for"]) if atk.get("for_no_dano", false) else 0
		if bully: extra += 2
		if v.mods.any(func(m): return m[0] == "ataque poderoso"): extra += 5   # Ataque Poderoso (LB p.124)
		if v.mods.any(func(m): return m[0] == "névoa espessa"): extra -= 2   # Névoa espessa: –2 no dano
		extra += CombatSim.archer_bonus(A.sheet, bool(v.get("ranged", false)))   # Arqueiro (LB p.65)
		extra += A.sheet.efeito_bonus("dano")   # efeitos de magia (Bênção, Perdição)
		extra += A.sheet.efeito_bonus_tipo("dano_vs", target)   # Heroísmo: contra o inimigo de maior ND
		if A.sheet.has_power("especializacao_arma") and str(A.sheet.powers.especializacao_arma) == str(A.sheet.equipment.get("weapon", "")): extra += 2
		if not bool(v.get("ranged", false)):
			extra += ClassFeatures.furia_bonus(A.sheet)   # Fúria do bárbaro: +dano corpo a corpo
		extra += ClassFeatures.instinto_bonus(A.sheet)   # Instinto Selvagem: +dano em qualquer ataque
		if T.damaged_round == sim.round_no and Array(A.sheet.habilidades).any(func(h): return str(h).begins_with("oportunista")):
			extra += 2
		var r := Dice.roll(atk.dano, world.rng, "combat", int(atk.mult) if crit else 1, extra)
		dmg = maxi(1, int(r.total))
		for elem in _dano_elemental_arma(A.sheet):
			var rd := Dice.roll("%dd6" % int(elem.dados), world.rng, "combat", int(atk.mult) if crit else 1)
			var dano_el: int = T.sheet.dano_por_tipo(str(elem.tipo), int(rd.total))
			dmg += dano_el
			tags.append(str(elem.tipo))
		var dado_parceiro := Parceiros.dano_corpo(A.sheet)
		if dado_parceiro != "" and not bool(v.get("ranged", false)) and not (A.flags as Array).has("parceiro_dano_%d" % sim.round_no):
			(A.flags as Array).append("parceiro_dano_%d" % sim.round_no)   # Fortão: uma vez por rodada
			dmg += int(Dice.roll(dado_parceiro, world.rng, "combat").total)
			tags.append("parceiro")
		var golpe_n := int(v.get("golpe_dados", 0))
		if golpe_n > 0:
			dmg += int(Dice.roll("%dd8" % golpe_n, world.rng, "combat", int(atk.mult) if crit else 1).total)   # Golpe Divino
		if not bool(v.get("ranged", false)) and A.sheet.manto_cruzado == "luz":
			dmg += _dados_energia("2d8", "luz", T.tile, int(atk.mult) if crit else 1)   # Manto do Cruzado (versão luz): +2d8 de luz
			tags.append("luz")
		rolls = r.rolls
		# Ataque Furtivo (LB p.73): 1/rodada, alvo desprevenido ou flanqueado; dados extras não multiplicam.
		var sa_key := "furtivo_%d" % sim.round_no
		if A.sheet.class_id == "ladino" and not A.flags.has(sa_key) and int(T.sheet.efeito_bonus("imune", "furtivo")) <= 0 and \
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
	_reacao_arma_espiritual(attacker, target, bool(v.get("ranged", false)), out)   # contra-ataque ao sofrer ataque corpo a corpo
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
		if o.side == me.side or o.sheet.is_dead() or o.flags.has("fora") or not _pode_mirar(id, oid):
			continue
		if o.sheet.is_down() and not is_animal:
			continue  # bandidos não executam quem caiu (ORIGINAL_DO_JOGO: preferem capturar)
		var d := CombatSim.cheb(origem, o.tile)
		if d < best:
			best = d; target = oid
	if target == "":
		return out
	# largou a arma (Comando): vai até ela e a pega
	if me.has("arma_no_chao"):
		var chao_ai: Dictionary = me.arma_no_chao
		var tc_ai := Vector2i(int(chao_ai.tile[0]), int(chao_ai.tile[1]))
		if CombatSim.cheb(me.tile, tc_ai) > 1:
			var cam_ai := sim.trim_path(id, sim.find_path(id, tc_ai), sim.speed_squares(id))
			if not cam_ai.is_empty():
				out.append_array(_try(id, {"type": "move", "path": cam_ai.map(func(t): return [t.x, t.y])}))
		out.append_array(_try(id, {"type": "pegar_arma"}))
	# preso e imóvel (Controlar Plantas) longe do alvo: tenta se libertar
	if best > 1 and not _marca_presa(id).is_empty() and me.sheet.has_effective_condition(world.rules, "imovel"):
		out.append_array(_try(id, {"type": "escapar"}))
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
	out.append_array(_propagar_ligacoes())
	return out


## Ligação Sombria: condições novas do conjurador passam ao alvo da ligação (ele faz Fortitude; falha, sofre a condição).
## Também registra os danos repassados pelo simulador. Drena a fila a cada ação e a cada início de turno.
func _propagar_ligacoes() -> Array:
	var out: Array = []
	for conj in sim.combatants:
		var s: CharacterSheet = sim.c(conj).sheet
		var novas := s.condicoes_novas.duplicate()
		s.condicoes_novas = PackedStringArray()
		if novas.is_empty():
			continue
		var lig := sim.ligacao_de(conj)
		if lig.is_empty() or not sim.combatants.has(lig.alvo):
			continue
		for cond in novas:
			var sv := Checks.skill(sim.c(lig.alvo).sheet, "fortitude", int(lig.cd), world.rules, world.rng, "combat")
			var passou: bool = sv.get("success", false)
			if not passou:
				sim.c(lig.alvo).sheet.add_condition(str(cond), world.rules)
			out.append(fact("BUFF_APPLIED", {"actor": conj, "target": lig.alvo, "buff": "ligacao_sombria", "condicao": str(cond), "passou": passou, "tags": ["magia"]}, [conj, lig.alvo]))
	for p in sim.pendencias:
		if p.tipo == "concentracao":
			if not p.passou:
				out.append(fact("SPELL_FAILED", {"caster": p.conj, "check": "vontade", "cd": p.valor, "reason": "ferido_na_execucao", "d20": 0, "total": 0}, [p.conj]))
			continue
		out.append(fact("BUFF_APPLIED", {"actor": p.conj, "target": p.alvo, "buff": "ligacao_sombria", "dano": p.valor, "passou": p.passou, "tags": ["magia"]}, [p.conj, p.alvo]))
	sim.pendencias.clear()
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
	var pacificos := false
	for id in sim.combatants:
		var x := sim.c(id)
		if x.side == "enemy" and sim.conscious(id):
			if not Atitudes.agressiva(atitude_de(id)):
				pacificos = true   # acalmado (Acalmar Animal, Tranquilidade, Diplomacia): não luta
				continue
			enemies_up = true
			if world.rules.value(x.sheet.source_rule, {}).get("tipo", "") == "animal":
				animals_up = true
	if not enemies_up:
		return _end_combat("pacificado" if pacificos else "vitoria")
	if P.sheet.is_down() and not animals_up:
		return _end_combat("captura")
	return []


func _end_combat(outcome: String) -> Array:
	var out: Array = []
	for m in sim.marcas.duplicate(true):   # presos por efeitos da cena (Controlar Plantas) ficam livres com o fim da cena
		if m.tipo == "preso" and sim.combatants.has(m.alvo):
			_soltar(m.alvo, m)
	for cid in sim.combatants:   # armas largadas (Comando) são recolhidas depois da luta
		_devolver_arma(cid)
	var loc := world.db.location_at(sim.c("player").tile)
	var P := sim.c("player")
	world.player_sheet = P.sheet
	world.player_sheet.remove_condition("surpreendido")
	world.player_sheet.scene_defense = 0   # magias de duração "cena" terminam com o combate
	world.player_sheet.limpar_efeitos("cena")
	world.player_sheet.limpar_efeitos("sustentada")   # sustentadas não passam do combate
	world.player_sheet.limpar_efeitos("rodada")
	world.player_sheet.limpar_efeitos("rodada_orientacao")
	world.player_sheet.limpar_efeitos("turno")
	world.player_sheet.allihanna_ativa = false
	for m in sim.marcas:   # condições impostas pela Aura Divina duram só a cena
		var cond_m := str(m.dados.get("condicao", ""))
		if str(m.fonte) == "aura_divina" and cond_m != "" and sim.combatants.has(m.alvo):
			sim.c(m.alvo).sheet.remove_condition(cond_m)
	for id in sim.combatants:   # Aura Sagrada é sustentada até o fim do combate; Égide, até o fim da cena
		var sh_f: CharacterSheet = sim.c(id).sheet
		sh_f.remove_efeito("magia.aura_divina")
		sh_f.remove_efeito("aura_divina")
		sh_f.aura_sagrada_ativa = false
		sh_f.egide_ativa = false
		sh_f.manto_cruzado = ""
		var resto_pv: int = mini(sh_f.pv_temp, sh_f.efeito_bonus("pv_temp_alimento"))   # bônus de alimentação dura o dia
		if sh_f.has_efeito("alimentacao") and sh_f.efeito_tipo_existe("pv_temp_alimento", ""):
			for e_al in sh_f.efeitos:
				if e_al.stat == "pv_temp_alimento":
					e_al.bonus = resto_pv
		sh_f.pv_temp = resto_pv
		sh_f.remove_efeito("manto_do_cruzado")
		sh_f.remove_efeito("aura_sagrada")
		sh_f.remove_efeito("egide_sagrada")
	world.player_sheet.olhar_usado = false
	world.player.position = world.db.tile_to_world(P.tile)
	for id in sim.combatants:
		if id == "player" or str(id).begins_with("inv_"):   # invocações não são criaturas do mundo nem companheiros
			continue
		var x := sim.c(id)
		if x.flags.has("fora"):   # banido por Banimento: volta ao mundo de origem, sem contar como derrota
			creature_state[id].sheet = x.sheet.to_dict()
			creature_state[id].present = false
			continue
		if x.side == "player":
			# companheiro: não é criatura; se morreu, sai como NPC_DIED (a party reage)
			if x.sheet.is_dead():
				out.append(fact("NPC_DIED", {"npc": id, "cause": "combate"}, [id]))
			else:
				out.append(fact("COMPANION_STATE", {"npc": id, "sheet": x.sheet.to_dict()}, [id]))
			continue
		creature_state[id].sheet = x.sheet.to_dict()
		creature_state[id].tile = [x.tile.x, x.tile.y]
		creature_state[id].atitude = str(x.get("atitude", "hostil"))   # Diplomacia muda de verdade
		creature_state[id].diplomacia_dia = int(x.get("diplomacia_dia", -1))
		var magica := _marca_atitude(id)
		if not magica.is_empty() and not x.sheet.is_dead():   # acalmado por magia: dura a cena
			creature_state[id].atitude_temp = {"valor": str(magica.dados.valor), "ate": world.clock.tick + TICKS_CENA}
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
		"fuga":
			out.append_array(_tentar_rastrear())
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
			"zonas": sim.zonas.duplicate(true), "marcas": sim.marcas.duplicate(true), "conjurando": sim.conjurando.duplicate(true),
			"sustentadas": sim.sustentadas.duplicate(true)}
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
		sim.conjurando = (s.get("conjurando", {}) as Dictionary).duplicate(true)
		sim.sustentadas = (s.get("sustentadas", {}) as Dictionary).duplicate(true)
	else:
		active = false
