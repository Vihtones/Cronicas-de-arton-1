class_name ProgressionModule
extends WorldModule
## Progressão. Dois modos:
## - "livro": XP = ND × 1000 / personagens; empate ½, derrota ¼; ND 5+ abaixo do nível = 0 (LB p.326).
## - "dinamica" (padrão, ORIGINAL_DO_JOGO): mesma base do livro × multiplicador de
##   desempenho e circunstâncias do combate, com retorno decrescente por repetição,
##   XP de aprendizado (testes difíceis) e de evasão. A conta é sempre mostrada ao jogador.
## Subida de nível: PV/PM pela classe e escolha de poder (ChoosePower).

const MYSTERY_ND := 1.0
const MULT_MIN := 0.5
const MULT_MAX := 2.0
const NOVELTY_DECAY := 0.25       # cada vitória anterior sobre o mesmo tipo reduz 25%...
const NOVELTY_FLOOR := 0.4        # ...até 40% da base
const LEARN_XP_PER_CD := 20       # (CD - 10) × 20 XP por teste difícil bem-sucedido, uma vez por alvo/abordagem
const LEARN_MIN_CD := 15

var mode := "dinamica"
var log: Array[Dictionary] = []
var kills_by_rule: Dictionary = {}   # regra da criatura -> vitórias anteriores
var learned: Dictionary = {}         # chave de teste -> true
var evaded: Dictionary = {}          # grupo -> true

const POWERS := {
	"guerreiro": ["especializacao_arma", "valentao", "golpe_raspao", "ataque_reflexo", "impeto", "arqueiro", "aumento_atributo"],
	"ladino": ["gatuno", "truque_magico", "emboscar", "velocidade_ladina", "rolamento_defensivo", "sombra", "aumento_atributo"],
	"arcanista": ["arcano_de_batalha", "magia_pungente", "poder_magico", "raio_arcano", "aumento_atributo"],
}


func module_id() -> String: return "progression"
func handled_commands() -> PackedStringArray: return PackedStringArray(["ChoosePower", "SetXpMode"])
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(["CREATURE_DEFEATED", "COMBAT_ENDED", "MYSTERY_RESOLVED", "TARGET_INSPECTED", "DIALOGUE_TEST", "STEALTH_CHECK"])


static func nd_value(nd) -> float:
	var s := str(nd)
	if s.contains("/"):
		return float(s.get_slice("/", 0)) / float(s.get_slice("/", 1))
	return float(s)


func _nd_of(creature: String) -> float:
	return nd_value(world.rules.value(world.db.creature_def(creature).get("rule", ""), {}).get("nd", "0"))


func xp_for(nd: float, result: String = "vitoria", party: int = 1) -> int:
	var rule: Dictionary = world.rules.value("progressao.xp_desafio")
	if nd <= world.player_sheet.level - int(rule.irrelevante_se_nd_menor_que_nivel_menos):
		return 0
	var mult := 1.0
	if result == "empate": mult = float(rule.empate)
	elif result == "derrota": mult = float(rule.derrota)
	return int(nd * 1000.0 * mult / maxi(1, party))


func xp_to_next() -> int:
	var t: Dictionary = world.rules.value("progressao.xp_por_nivel")
	return int(t.get(str(world.player_sheet.level + 1), 999999))


## Multiplicador dinâmico a partir das estatísticas do combate. Retorna {mult, breakdown}.
func combat_multiplier(stats: Dictionary, outcome: String) -> Dictionary:
	var lines: Array = []
	var bonus := 0.0
	var enemies: Array = stats.get("enemies", [])
	var n := enemies.size()
	if n > 1:
		var b := minf(0.3, 0.1 * (n - 1))
		bonus += b; lines.append(["desvantagem numérica (%d inimigos)" % n, b])
	var nd_total := 0.0
	for id in enemies: nd_total += _nd_of(id)
	var lvl := world.player_sheet.level
	if nd_total > lvl:
		var b := minf(0.45, 0.15 * (nd_total - lvl))
		bonus += b; lines.append(["desafio acima do nível (ND %.2g vs nível %d)" % [nd_total, lvl], b])
	for k in stats.get("adverse", {}):
		bonus += 0.1; lines.append(["circunstância adversa: " + str(k), 0.1])
	if stats.get("went_down", false) and outcome == "vitoria":
		bonus += 0.15; lines.append(["virou o jogo depois de cair", 0.15])
	var tactics: Array = stats.get("tactics", {}).keys()
	if not tactics.is_empty():
		var b := minf(0.2, 0.05 * tactics.size())
		bonus += b; lines.append(["táticas: " + ", ".join(tactics), b])
	if outcome == "vitoria":
		var pv_max := maxi(1, int(stats.get("pv_max", 1)))
		if int(stats.get("dmg_taken", 0)) <= pv_max / 4:
			bonus += 0.1; lines.append(["quase sem ferimentos", 0.1])
		elif int(stats.get("pv_end", pv_max)) <= pv_max / 4:
			bonus += 0.1; lines.append(["por um fio", 0.1])
		if int(stats.get("rounds", 99)) <= n + 1:
			bonus += 0.1; lines.append(["vitória rápida (%d rodadas)" % int(stats.get("rounds", 0)), 0.1])
	var mult := clampf(1.0 + bonus, MULT_MIN, MULT_MAX)
	return {"mult": mult, "breakdown": lines}


func novelty(rule_id: String) -> float:
	return maxf(NOVELTY_FLOOR, 1.0 - NOVELTY_DECAY * int(kills_by_rule.get(rule_id, 0)))


func on_event(e: GameEvent) -> Array:
	match e.event_type:
		"CREATURE_DEFEATED":
			if mode == "livro" and e.payload.get("by", "") == "player":
				return _award(xp_for(_nd_of(e.payload.creature)), "derrotou " + str(e.payload.get("name", "")), [])
		"COMBAT_ENDED":
			return _combat_xp(e.payload)
		"MYSTERY_RESOLVED":
			if e.payload.get("by", "") == "player":
				var base := xp_for(MYSTERY_ND)
				if mode == "dinamica":
					var ex = world.module("exploration")
					var right := 0
					var wrong := 0
					if ex != null:
						for h in ex.hypothesis_view():
							if h.mystery != e.payload.mystery: continue
							if h.state == "acredito" and h.contradicting.is_empty() and not h.supporting.is_empty(): right += 1
							elif h.state == "acredito" and not h.contradicting.is_empty(): wrong += 1
					var m := clampf(1.0 + 0.15 * right - 0.1 * wrong, MULT_MIN, MULT_MAX)
					return _award(int(base * m), "mistério resolvido", [["hipóteses certas: %d, erradas: %d" % [right, wrong], m - 1.0]])
				return _award(base, "mistério resolvido", [])
		"TARGET_INSPECTED", "DIALOGUE_TEST":
			if mode != "dinamica":
				return []
			var c: Dictionary = e.payload.get("check", {})
			if not c.get("success", false) or int(c.get("cd", 0)) < LEARN_MIN_CD:
				return []
			var key := "%s|%s|%s" % [e.payload.get("target", e.payload.get("npc", "")), e.payload.get("approach", ""), c.get("skill", "")]
			if learned.has(key):
				return []
			learned[key] = true
			return _award((int(c.cd) - 10) * LEARN_XP_PER_CD, "aprendizado: %s CD %d" % [c.get("skill", ""), int(c.cd)], [])
		"STEALTH_CHECK":
			if mode != "dinamica" or not e.payload.get("success", false):
				return []
			var key := ",".join(e.payload.group)
			if evaded.has(key):
				return []
			evaded[key] = true
			var nd := 0.0
			for id in e.payload.group: nd += _nd_of(id)
			return _award(int(xp_for(nd) * 0.25), "passou despercebido", [])
	return []


func _combat_xp(p: Dictionary) -> Array:
	var outcome: String = p.get("outcome", "")
	if outcome == "morte":
		return []
	var stats: Dictionary = p.get("stats", {})
	var result: String = {"vitoria": "vitoria", "fuga": "empate", "captura": "derrota"}.get(outcome, "vitoria")
	if mode == "livro":
		if outcome in ["fuga", "captura"]:
			var total := 0.0
			for id in p.get("enemies", []): total += _nd_of(id)
			return _award(xp_for(total, result), outcome, [])
		return []
	# dinâmica: base do livro por inimigo (com novidade) × multiplicador de desempenho
	var base := 0.0
	var lines: Array = []
	for id in p.get("enemies", []):
		var rule_id: String = world.db.creature_def(id).get("rule", "")
		var x := float(xp_for(_nd_of(id), result))
		var nov := novelty(rule_id) if outcome == "vitoria" else 1.0
		if nov < 1.0:
			lines.append(["repetição: %s (×%.2f)" % [world.db.creature_def(id).name, nov], 0.0])
		base += x * nov
	if outcome == "vitoria":
		for id in p.get("enemies", []):
			var rule_id: String = world.db.creature_def(id).get("rule", "")
			kills_by_rule[rule_id] = int(kills_by_rule.get(rule_id, 0)) + 1
	var cm := combat_multiplier(stats, outcome)
	lines.append_array(cm.breakdown)
	return _award(int(round(base * cm.mult)), "combate (%s, ×%.2f)" % [outcome, cm.mult], lines,
		{"combat": true, "outcome": outcome, "base": int(round(base)), "mult": cm.mult})


func _award(amount: int, reason: String, breakdown: Array, extra: Dictionary = {}) -> Array:
	if amount <= 0:
		return []
	var s := world.player_sheet
	s.xp += amount
	log.append({"tick": world.clock.tick, "xp": amount, "reason": reason, "breakdown": breakdown})
	if log.size() > 200: log.pop_front()
	var payload := {"amount": amount, "total": s.xp, "reason": reason, "breakdown": breakdown, "mode": mode,
		"next": xp_to_next(), "level": s.level}
	payload.merge(extra)
	var out: Array = [fact("XP_GAINED", payload, ["player"])]
	while s.xp >= xp_to_next():
		out.append(_level_up())
	return out


func _level_up() -> Dictionary:
	var s := world.player_sheet
	var c: Dictionary = world.rules.value("classe." + (s.class_id if s.class_id != "" else "guerreiro"))
	s.level += 1
	var pv_gain := int(c.pv_nivel) + int(s.attrs.con)
	var race: Dictionary = {} if s.race_id in ["", "humano"] else world.rules.value("raca." + s.race_id, {})
	pv_gain += int(race.get("pv_por_nivel", 0))
	var pm_gain := int(c.pm_nivel) + (1 if s.has_power("poder_magico") else 0) + int(race.get("pm_por_nivel", 0))
	s.pv_max += pv_gain
	s.pv += pv_gain
	s.pm_max += pm_gain
	s.pm += pm_gain
	if s.class_id == "guerreiro" and s.level == 3:
		s.powers["durao"] = true  # habilidade de classe no 3º nível (LB p.66)
	s.pending_powers += 1
	return fact("LEVEL_UP", {"level": s.level, "pv_gain": pv_gain, "pm_gain": pm_gain, "pending_powers": s.pending_powers,
		"options": available_powers()}, ["player"])


func available_powers() -> Array:
	var s := world.player_sheet
	var out: Array = []
	for p in POWERS.get(s.class_id if s.class_id != "" else "guerreiro", []):
		if p == "truque_magico" and int(s.attrs["int"]) < 1: continue
		if not prereq_ok(s, p): continue
		if p != "aumento_atributo" and p != "especializacao_arma" and s.powers.has(p): continue
		out.append(p)
	return out


## Pré-requisitos do livro registrados na regra do poder (atributo mínimo, perícia treinada).
func prereq_ok(s: CharacterSheet, p: String) -> bool:
	var pre: Dictionary = world.rules.value("poder." + p, {}).get("prereq", {})
	for k in pre:
		if k == "treinado":
			if not s.trained.has(str(pre[k])): return false
		elif int(s.attrs.get(k, 0)) < int(pre[k]):
			return false
	return true


func validate(cmd: GameCommand) -> PackedStringArray:
	if cmd.type == "SetXpMode":
		return PackedStringArray() if cmd.payload.get("mode", "") in ["livro", "dinamica"] else PackedStringArray(["modo inválido"])
	var s := world.player_sheet
	if s.pending_powers <= 0: return PackedStringArray(["nenhum poder a escolher"])
	var p: String = cmd.payload.get("power", "")
	if not available_powers().has(p): return PackedStringArray(["poder indisponível: " + p])
	if p == "aumento_atributo" and not ["for", "des", "con", "int", "sab", "car"].has(cmd.payload.get("option", "")):
		return PackedStringArray(["escolha um atributo"])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	if cmd.type == "SetXpMode":
		mode = cmd.payload.mode
		return [fact("XP_MODE_SET", {"mode": mode}, ["player"])]
	var s := world.player_sheet
	var p: String = cmd.payload.power
	var opt: String = str(cmd.payload.get("option", ""))
	match p:
		"especializacao_arma":
			s.powers[p] = opt if opt != "" else str(s.equipment.get("weapon", ""))
		"aumento_atributo":
			s.attrs[opt] = int(s.attrs[opt]) + 1
			if opt == "con":
				s.pv_max += s.level; s.pv += s.level  # Con retroativa (LB p.17)
			s.powers["aumento_atributo_%s_%d" % [opt, s.level]] = true
		"poder_magico":
			# +1 PM por nível de arcanista, retroativo (LB p.38)
			s.powers[p] = true
			s.pm_max += s.level; s.pm += s.level
		"truque_magico":
			s.powers[p] = "seta_infalivel"
			if not s.spells.has("seta_infalivel"): s.spells.append("seta_infalivel")
		_:
			s.powers[p] = true
	s.pending_powers -= 1
	return [fact("POWER_CHOSEN", {"power": p, "option": opt, "rule": "poder." + p}, ["player"])]


func to_dict() -> Dictionary:
	return {"log": log.duplicate(true), "mode": mode, "kills_by_rule": kills_by_rule.duplicate(), "learned": learned.duplicate(), "evaded": evaded.duplicate()}


func from_dict(d: Dictionary) -> void:
	log.clear()
	for l in d.get("log", []):
		log.append(l)
	mode = d.get("mode", "dinamica")
	kills_by_rule = {}
	for k in d.get("kills_by_rule", {}): kills_by_rule[k] = int(d.kills_by_rule[k])
	learned = d.get("learned", {}).duplicate()
	evaded = d.get("evaded", {}).duplicate()
