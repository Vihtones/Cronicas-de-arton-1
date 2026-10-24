extends TestCase
## Árvore de poderes: poderes gerais do LB (p.124-131) com pré-requisitos encadeados e efeitos.


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


func test_poderes_gerais_entram_nas_opcoes_com_prerequisitos() -> void:
	var w := WorldHelpers.world(5)
	var s := w.player_sheet
	var prog: ProgressionModule = w.modules.progression
	s.attrs["for"] = 0
	check(not prog.available_powers().has("ataque_poderoso"), "Ataque Poderoso exige For 1")
	s.attrs["for"] = 1
	check(prog.available_powers().has("ataque_poderoso"), "com For 1, disponível")
	check(not prog.available_powers().has("trespassar"), "Trespassar exige Ataque Poderoso")
	s.powers["ataque_poderoso"] = true
	check(prog.available_powers().has("trespassar"), "com Ataque Poderoso, Trespassar abre")
	check(not prog.available_powers().has("quebrar_aprimorado"), "não implementado não vira opção")


func test_arvore_tem_estados_e_arestas() -> void:
	var w := WorldHelpers.world(5)
	var s := w.player_sheet
	s.attrs["for"] = 2
	s.powers["ataque_poderoso"] = true
	var tree := (w.modules.progression as ProgressionModule).power_tree()
	var by := {}
	for n in tree.nodes: by[n.id] = n
	eq(by.ataque_poderoso.state, "possui", "possui Ataque Poderoso")
	eq(by.trespassar.parent, "ataque_poderoso", "aresta Ataque Poderoso -> Trespassar")
	eq(by.trespassar.state, "disponivel", "Trespassar disponível")
	eq(by.quebrar_aprimorado.state, "nao_implementado", "marcado como não implementado")
	eq(by.esquiva.page, 125, "página do livro")
	check(by.has(s.class_id if s.class_id != "" else "guerreiro") or by.has("valentao"), "ramo da classe presente")


func test_esquiva_vitalidade_vontade_de_ferro() -> void:
	var w := WorldHelpers.world(5)
	var s := w.player_sheet
	var prog: ProgressionModule = w.modules.progression
	s.attrs.des = maxi(1, int(s.attrs.des)); s.attrs.con = maxi(1, int(s.attrs.con)); s.attrs.sab = maxi(1, int(s.attrs.sab))
	s.level = 4
	var d0 := s.defense(w.rules)
	var ref0 := s.skill_value("reflexos", w.rules)
	s.pending_powers = 3
	var pv0 := s.pv_max
	var pm0 := s.pm_max
	var fort0 := s.skill_value("fortitude", w.rules)
	var von0 := s.skill_value("vontade", w.rules)
	for p in ["esquiva", "vitalidade", "vontade_de_ferro"]:
		var r := WorldHelpers.cmd(w, "ChoosePower", {"power": p})
		check(r.accepted, "escolheu %s: %s" % [p, str(r.errors)])
	eq(s.defense(w.rules), d0 + 2, "Esquiva +2 Defesa")
	eq(s.skill_value("reflexos", w.rules), ref0 + 2, "Esquiva +2 Reflexos")
	eq(s.pv_max, pv0 + 4, "Vitalidade +1 PV por nível (nível 4)")
	eq(s.skill_value("fortitude", w.rules), fort0 + 2, "Vitalidade +2 Fortitude")
	eq(s.pm_max, pm0 + 2, "Vontade de Ferro +1 PM a cada dois níveis")
	eq(s.skill_value("vontade", w.rules), von0 + 2, "Vontade de Ferro +2 Vontade")
	var lv := prog._level_up()
	check(int(lv.payload.pv_gain) >= 1, "subiu nível")
	eq(s.level, 5, "nível 5 (ímpar: sem PM extra)")


func test_ataque_poderoso_troca_acerto_por_dano() -> void:
	var w := _w()
	var c: CombatModule = w.modules.combat
	var P: CharacterSheet = c.sim.c("player").sheet
	var before := c.sim.attack_profile("player", "bandido_1", 0, false, false)
	P.powers["ataque_poderoso"] = true
	c.sim.toggles["ataque_poderoso"] = "sempre"
	var after := c.sim.attack_profile("player", "bandido_1", 0, false, false)
	eq(int(after.mod), int(before.mod) - 2, "-2 no ataque")
	eq(float(after.avg_damage), float(before.avg_damage) + 5.0, "+5 no dano médio")
	c.sim.toggles["ataque_poderoso"] = "nunca"
	eq(int(c.sim.attack_profile("player", "bandido_1", 0, false, false).mod), int(before.mod), "desligado")


func test_combate_defensivo_da_defesa_ate_o_proximo_turno() -> void:
	var w := _w()
	var c: CombatModule = w.modules.combat
	var P: CharacterSheet = c.sim.c("player").sheet
	P.powers["combate_defensivo"] = true
	c.sim.toggles["combate_defensivo"] = "sempre"
	var prof := c.sim.attack_profile("player", "bandido_1", 0, false, false)
	check(prof.mods.any(func(m): return m[0] == "combate defensivo"), "-2 ao agredir")
	var enemy_view_before := c.sim.attack_profile("bandido_1", "player", 0, false, false)
	c._execute_action("player", {"type": "attack", "target": "bandido_1", "attack": 0}, GhostPlanner.validate_action(c.sim, "player", {"type": "attack", "target": "bandido_1", "attack": 0}))
	var enemy_view := c.sim.attack_profile("bandido_1", "player", 0, false, false)
	if not c.sim.c("bandido_1").sheet.is_down():
		eq(int(enemy_view.defense), int(enemy_view_before.defense) + 5, "+5 Defesa até o próximo turno")
	c._begin_turn("player")
	check(not c.sim.c("player").flags.has("defensivo"), "acaba no próximo turno do jogador")


func test_reflexos_de_combate_da_movimento_extra_no_primeiro_turno() -> void:
	var w := WorldHelpers.world(5)
	w.player_sheet.powers["reflexos_combate"] = true
	WorldHelpers.put(w, 25, 57)
	var c: CombatModule = w.modules.combat
	c._start(["bandido_1"], false, false)
	if c.active and c.sim.current_id() == "player":
		check(int(c.sim.budget.move) >= 2, "movimento extra no primeiro turno (%s)" % str(c.sim.budget))
	c.sim.next_turn()
	var st := c._begin_turn(c.sim.current_id())
	check(c.sim.current_id() != "player" or int(c.sim.budget.move) == 1, "só no primeiro turno")
	check(st.has("facts"), "turno começou")


func test_trespassar_ataca_outro_ao_derrubar() -> void:
	var w := WorldHelpers.world(5)
	WorldHelpers.put(w, 25, 57)
	var c: CombatModule = w.modules.combat
	c._start(["bandido_1", "bandido_2"], true, false)
	var sim: CombatSim = c.sim
	sim.c("player").tile = Vector2i(26, 57)
	sim.c("bandido_1").tile = Vector2i(27, 57)
	sim.c("bandido_2").tile = Vector2i(27, 58)
	var P: CharacterSheet = sim.c("player").sheet
	P.powers["trespassar"] = true
	P.powers["ataque_poderoso"] = true
	P.pm = 5
	sim.c("bandido_1").sheet.pv = 1
	var out := c._cleave("player", "bandido_1", 0)
	check(out.any(func(f): return f.type == "POWER_USED"), "usou Trespassar")
	check(out.any(func(f): return f.type == "ATTACK_RESOLVED" and f.payload.target == "bandido_2"), "ataque adicional contra o outro bandido")
	eq(P.pm, 4, "gastou 1 PM")
	c.power_policy["trespassar"] = "nunca"
	check(c._cleave("player", "bandido_1", 0).is_empty(), "política 'nunca' desliga")
