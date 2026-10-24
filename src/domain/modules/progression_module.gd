class_name ProgressionModule
extends WorldModule
## Progressão (LB p.35 e p.326): XP = ND × 1000 / personagens; empate rende metade,
## derrota rende um quarto; desafio com ND 5+ abaixo do nível não rende XP.
## Subir de nível: PV e PM pela classe; poderes de classe ficam PENDENTES (escolha futura).

const MYSTERY_ND := 1.0  # ORIGINAL_DO_JOGO: "XP alternativo" (LB p.326) por mistério resolvido

var log: Array[Dictionary] = []


func module_id() -> String: return "progression"
func subscribed_events() -> PackedStringArray:
	return PackedStringArray(["CREATURE_DEFEATED", "COMBAT_ENDED", "MYSTERY_RESOLVED", "XP_AWARDED"])


static func nd_value(nd) -> float:
	var s := str(nd)
	if s.contains("/"):
		return float(s.get_slice("/", 0)) / float(s.get_slice("/", 1))
	return float(s)


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


func on_event(e: GameEvent) -> Array:
	match e.event_type:
		"CREATURE_DEFEATED":
			if e.payload.get("by", "") != "player":
				return []
			var rule_id: String = world.db.creature_def(e.payload.creature).get("rule", "")
			var nd := nd_value(world.rules.value(rule_id, {}).get("nd", "0"))
			return _award(xp_for(nd), "derrotou " + str(e.payload.get("name", "")))
		"COMBAT_ENDED":
			# Empate (fuga) e derrota (captura) rendem XP parcial pelos inimigos enfrentados.
			var outcome: String = e.payload.outcome
			if outcome in ["fuga", "captura"]:
				var total := 0.0
				for id in e.payload.get("enemies", []):
					total += nd_value(world.rules.value(world.db.creature_def(id).get("rule", ""), {}).get("nd", "0"))
				return _award(xp_for(total, "empate" if outcome == "fuga" else "derrota"), outcome)
		"MYSTERY_RESOLVED":
			if e.payload.get("by", "") == "player":
				return _award(xp_for(MYSTERY_ND), "mistério resolvido")
	return []


func _award(amount: int, reason: String) -> Array:
	if amount <= 0:
		return []
	var s := world.player_sheet
	s.xp += amount
	log.append({"tick": world.clock.tick, "xp": amount, "reason": reason})
	var out: Array = [fact("XP_GAINED", {"amount": amount, "total": s.xp, "reason": reason}, ["player"])]
	while s.xp >= xp_to_next():
		out.append(_level_up())
	return out


func _level_up() -> Dictionary:
	var s := world.player_sheet
	var c: Dictionary = world.rules.value("classe." + (s.class_id if s.class_id != "" else "guerreiro"))
	s.level += 1
	var pv_gain := int(c.pv_nivel) + int(s.attrs.con)
	if s.race_id == "anao":
		pv_gain += int(world.rules.value("raca.anao").pv_por_nivel)
	var pm_gain := int(c.pm_nivel)
	s.pv_max += pv_gain
	s.pv += pv_gain
	s.pm_max += pm_gain
	s.pm += pm_gain
	s.pending_powers += 1
	return fact("LEVEL_UP", {"level": s.level, "pv_gain": pv_gain, "pm_gain": pm_gain, "pending_powers": s.pending_powers}, ["player"])


func to_dict() -> Dictionary: return {"log": log.duplicate(true)}
func from_dict(d: Dictionary) -> void:
	log.clear()
	for l in d.get("log", []):
		log.append(l)
