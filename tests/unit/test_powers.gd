extends TestCase
## C21: poderes de classe do LB (guerreiro p.65-66, ladino p.73-74, arcanista p.38-39) e reações.


func _w(sheet: CharacterSheet = null) -> WorldState:
	var w := WorldHelpers.world(5)
	if sheet != null:
		w.player_sheet = sheet
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1"], true, false)
	var sim: CombatSim = w.modules.combat.sim
	sim.c("player").tile = Vector2i(26, 57)
	sim.c("bandido_1").tile = Vector2i(27, 57)
	sim.budget = {"std": 1, "move": 1}
	return w


func _arc() -> CharacterSheet:
	return CharacterBuilder.build(RuleRegistry.load_default(), "humano", "arcanista", CharacterBuilder.presets("arcanista")[0], ["int", "des", "sab"])


func _ladino() -> CharacterSheet:
	return CharacterBuilder.build(RuleRegistry.load_default(), "humano", "ladino", CharacterBuilder.presets("ladino")[0], ["des", "int", "car"])


func test_prerequisitos_filtram_poderes() -> void:
	var w := WorldHelpers.world(5)
	var s := w.player_sheet
	s.pending_powers = 1
	s.attrs.sab = 0
	var prog: ProgressionModule = w.modules.progression
	check(not prog.available_powers().has("arqueiro"), "Arqueiro exige Sab 1 (LB p.65)")
	s.attrs.sab = 1
	check(prog.available_powers().has("arqueiro"), "com Sab 1, disponível")
	check(prog.available_powers().has("impeto"), "Ímpeto sem pré-requisito")


func test_impeto_aumenta_deslocamento_na_rodada() -> void:
	var w := _w()
	var c: CombatModule = w.modules.combat
	c.sim.c("player").sheet.powers["impeto"] = true
	var base := c.sim.speed_squares("player")
	var g := GhostPlanner.simulate(c.sim, "player", [{"type": "impeto"}])
	check(g.valid, "fantasma aceita Ímpeto")
	var v := GhostPlanner.validate_action(c.sim, "player", {"type": "impeto"})
	c._execute_action("player", {"type": "impeto"}, v)
	eq(c.sim.speed_squares("player"), base + 4, "+6m = +4 quadrados (LB p.66)")
	check(not GhostPlanner.validate_action(c.sim, "player", {"type": "impeto"}).ok, "1 vez por rodada")
	c.sim.round_no += 1
	eq(c.sim.speed_squares("player"), base, "só uma rodada")


func test_velocidade_ladina_e_emboscar() -> void:
	var s := _ladino()
	s.powers["velocidade_ladina"] = true
	s.powers["emboscar"] = true
	s.pm = 10
	var w := _w(s)
	var c: CombatModule = w.modules.combat
	c.sim.round_no = 1
	c._execute_action("player", {"type": "velocidade_ladina"}, GhostPlanner.validate_action(c.sim, "player", {"type": "velocidade_ladina"}))
	eq(int(c.sim.budget.move), 2, "+1 ação de movimento (LB p.74)")
	c._execute_action("player", {"type": "emboscar"}, GhostPlanner.validate_action(c.sim, "player", {"type": "emboscar"}))
	eq(int(c.sim.budget.std), 2, "+1 ação padrão na 1ª rodada (LB p.73)")
	eq(c.sim.c("player").sheet.pm, 6, "2 PM cada")
	c.sim.round_no = 2
	check(not GhostPlanner.validate_action(c.sim, "player", {"type": "emboscar"}).ok, "Emboscar não repete")


func test_arqueiro_soma_sabedoria_a_distancia() -> void:
	var s := CharacterSheet.new()
	s.level = 2; s.attrs.sab = 3
	s.powers["arqueiro"] = true
	eq(CombatSim.archer_bonus(s, true), 2, "limitado pelo nível")
	eq(CombatSim.archer_bonus(s, false), 0, "só à distância")


func test_rolamento_defensivo_reduz_e_derruba() -> void:
	var s := _ladino()
	s.powers["rolamento_defensivo"] = true
	s.pm = 10
	var w := _w(s)
	var c: CombatModule = w.modules.combat
	var used := false
	for i in 40:
		c.sim.c("player").sheet.pv = 200
		c.sim.c("player").sheet.pm = 10
		c.sim.c("player").sheet.remove_condition("caido")
		var v := c.sim.attack_profile("bandido_1", "player", 0, false, false)
		for f in c._resolve_attack("bandido_1", "player", v, false):
			if f.type == "ATTACK_RESOLVED" and (f.payload.tags as Array).has("rolamento"):
				used = true
				check(c.sim.c("player").sheet.conditions.has("caido"), "fica caído (LB p.74)")
				eq(c.sim.c("player").sheet.pm, 8, "2 PM")
	check(used, "usou em algum golpe forte")


func test_ataque_reflexo_quando_o_alvo_sai_do_alcance() -> void:
	var w := _w()
	var c: CombatModule = w.modules.combat
	c.sim.c("player").sheet.powers["ataque_reflexo"] = true
	c.sim.c("player").sheet.pm = 5
	c.sim.c("bandido_1").sheet.pv = 50
	c.sim.c("bandido_1").sheet.remove_condition("surpreendido")   # o bandido precisa poder agir
	var a := {"type": "move", "path": [[28, 57], [29, 57]]}
	var v := GhostPlanner.validate_action(c.sim, "bandido_1", a)
	check(v.ok, "movimento válido: %s" % str(v.get("reason", "")))
	var out := c._execute_action("bandido_1", a, v)
	check(out.any(func(f): return f.type == "REACTION"), "reagiu (LB p.65)")
	check(out.any(func(f): return f.type == "ATTACK_RESOLVED" and f.payload.attacker == "player"), "atacou")
	eq(c.sim.c("player").sheet.pm, 4, "1 PM")
	# uma vez por alvo a cada rodada
	c.sim.c("bandido_1").tile = Vector2i(27, 57)
	c.sim.budget = {"std": 1, "move": 1}
	var out2 := c._execute_action("bandido_1", a, GhostPlanner.validate_action(c.sim, "bandido_1", a))
	check(not out2.any(func(f): return f.type == "REACTION"), "não repete na mesma rodada")
	# política "nunca"
	c.sim.round_no += 1
	c.power_policy.ataque_reflexo = "nunca"
	c.sim.c("bandido_1").tile = Vector2i(27, 57)
	c.sim.budget = {"std": 1, "move": 1}
	var out3 := c._execute_action("bandido_1", a, GhostPlanner.validate_action(c.sim, "bandido_1", a))
	check(not out3.any(func(f): return f.type == "REACTION"), "política nunca")


func test_raio_arcano_pungente_e_arcano_de_batalha() -> void:
	var s := _arc()
	s.powers["raio_arcano"] = true
	s.powers["magia_pungente"] = true
	s.powers["arcano_de_batalha"] = true
	s.pm = 10
	var w := _w(s)
	var c: CombatModule = w.modules.combat
	c.sim.c("bandido_1").tile = Vector2i(30, 57)
	var a := {"type": "cast", "spell": "raio_arcano", "targets": ["bandido_1"], "target": "bandido_1"}
	var v := GhostPlanner.validate_action(c.sim, "player", a)
	check(v.ok, "raio a 4 quadrados (curto): %s" % str(v.get("reason", "")))
	eq(int(v.cost), 0, "Raio Arcano não custa PM (LB p.39)")
	var ap := a.duplicate(); ap["pungente"] = true
	eq(int(GhostPlanner.validate_action(c.sim, "player", ap).cost), 1, "Pungente: +1 PM")
	eq(c.spell_dc(c.sim.c("player").sheet, ap), c.spell_dc(c.sim.c("player").sheet, a) + 2, "Pungente: CD +2 (LB p.38)")
	var dmg_seen := false
	for i in 10:
		c.sim.c("bandido_1").sheet.pv = 50
		for f in c._cast("player", a, v):
			if f.type == "ATTACK_RESOLVED":
				dmg_seen = true
				check(int(f.payload.damage) >= 1, "causa dano")
				eq(f.payload.save, "reflexos", "Reflexos reduz à metade")
	check(dmg_seen, "lançou")
	c.sim.c("player").sheet.powers.erase("magia_pungente")
	check(not GhostPlanner.validate_action(c.sim, "player", ap).ok, "sem o poder, Pungente é recusada (não cobra PM à toa)")
	eq(CombatModule.battle_bonus(c.sim.c("player").sheet), int(s.attrs["int"]), "Arcano de Batalha soma Int")
	c.sim.c("bandido_1").tile = Vector2i(34, 57)
	check(not GhostPlanner.validate_action(c.sim, "player", a).ok, "fora do alcance curto")


func test_poder_magico_pm_retroativo_e_por_nivel() -> void:
	var w := WorldHelpers.world(5)
	w.player_sheet = _arc()
	var s := w.player_sheet
	s.level = 3; s.pending_powers = 1
	var pm := s.pm_max
	check(WorldHelpers.cmd(w, "ChoosePower", {"power": "poder_magico"}).accepted, "escolheu")
	eq(s.pm_max, pm + 3, "+1 PM por nível, retroativo (LB p.38)")
	var before := s.pm_max
	s.xp = 0
	w.modules.progression._level_up()
	eq(s.pm_max, before + 6 + 1, "ao subir: PM da classe + 1")


func test_sombra_soma_furtividade() -> void:
	var s := _ladino()
	var r := RuleRegistry.load_default()
	var before := s.skill_value("furtividade", r)
	s.powers["sombra"] = true
	eq(s.skill_value("furtividade", r), before + 2, "+2 (LB p.74)")


func test_c27_ataque_especial_escala_e_ataque_extra() -> void:
	var w := _w()
	var c: CombatModule = w.modules.combat
	var P: CharacterSheet = c.sim.c("player").sheet
	P.pm = 10
	P.level = 5
	eq(c.sim.special_tier(P), 2, "5º nível: +8 por 2 PM (LB p.65)")
	var prof := c.sim.attack_profile("player", "bandido_1", 0, true, false)
	check(prof.mods.any(func(m): return m[0] == "ataque especial" and int(m[1]) == 8), "+8 no fantasma")
	P.level = 6
	check(not GhostPlanner.validate_action(c.sim, "player", {"type": "ataque_extra", "target": "bandido_1"}).ok, "precisa agredir antes")
	var g := GhostPlanner.simulate(c.sim, "player", [{"type": "attack", "target": "bandido_1"}, {"type": "ataque_extra", "target": "bandido_1"}])
	check(g.valid, "agredir + Ataque Extra no mesmo turno (LB p.66)")
	P.level = 5
	check(not GhostPlanner.simulate(c.sim, "player", [{"type": "attack", "target": "bandido_1"}, {"type": "ataque_extra", "target": "bandido_1"}]).valid, "só a partir do 6º nível")


func test_c24_condicao_que_deixa_desprevenido_dispara_reflexo() -> void:
	var w := _w()
	var c: CombatModule = w.modules.combat
	c.sim.c("player").sheet.powers["ataque_reflexo"] = true
	c.sim.c("player").sheet.pm = 5
	c.sim.c("bandido_1").sheet.conditions = PackedStringArray()
	c.sim.c("bandido_1").sheet.pv = 50
	var out := c.apply_condition("bandido_1", "atordoado")
	check(out.any(func(f): return f.type == "REACTION"), "atordoado implica desprevenido: reação (LB p.65)")


func test_c24_kael_tem_poderes_e_pm() -> void:
	var w := WorldHelpers.world(5)
	var s := CharacterSheet.from_dict(w.modules.combat.creature_state.kael.sheet)
	check(s.has_power("ataque_reflexo") and s.has_power("impeto"), "Kael usa poderes de classe (LB p.322)")
	eq(s.pm, 3)


func test_sereia_nada_e_humano_nao() -> void:
	var r := RuleRegistry.load_default()
	var sereia := CharacterBuilder.build(r, "sereia", "guerreiro", CharacterBuilder.presets("guerreiro")[0], ["for", "con", "des"])
	eq(sereia.swim_m, 12.0, "sereia: natação 12m (LB p.30)")
	check(sereia.can_swim(), "sereia nada")
	var humano := CharacterBuilder.build(r, "humano", "guerreiro", CharacterBuilder.presets("guerreiro")[0], ["for", "con", "des"])
	check(not humano.can_swim(), "humano não nada por padrão")
