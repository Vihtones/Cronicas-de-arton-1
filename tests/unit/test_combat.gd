extends TestCase


func _crypt_fight(p_seed: int = 5, enemies: Array = ["bandido_1"]) -> WorldState:
	var w := WorldHelpers.world(p_seed)
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(enemies, false, false)
	# garante que é a vez do jogador
	return w


func test_fantasma_nao_muda_estado() -> void:
	var w := _crypt_fight()
	var before := WorldHelpers.snap(w)
	var c: CombatModule = w.modules.combat
	var p: Vector2i = c.sim.c("player").tile
	var plan := [{"type": "move", "path": [[p.x + 1, p.y]]}, {"type": "attack", "target": "bandido_1"}]
	var g := c.preview(plan)
	check(g.has("steps"), "preview gerado")
	eq(WorldHelpers.snap(w), before, "snapshot idêntico após projeção fantasma")


func test_acao_invalida_nao_consome_recursos() -> void:
	var w := _crypt_fight()
	var c: CombatModule = w.modules.combat
	if c.sim.current_id() != "player":
		return
	var rev := w.revision
	var budget := c.sim.budget.duplicate()
	var pm: int = c.sim.c("player").sheet.pm
	var r := WorldHelpers.cmd(w, "ExecutePlan", {"actions": [{"type": "attack", "target": "bandido_2", "special": true}]})
	check(not r.accepted, "ataque fora de alcance rejeitado")
	eq(w.revision, rev, "revisão intacta")
	eq(c.sim.budget, budget, "orçamento intacto")
	eq(c.sim.c("player").sheet.pm, pm, "PM intactos")


func test_mesma_seed_reproduz_combate() -> void:
	var logs := []
	for i in 2:
		var w := _crypt_fight(42, ["bandido_1", "bandido_2", "kael"])
		var c: CombatModule = w.modules.combat
		var out := []
		for turn in 6:
			if not c.active: break
			if c.sim.current_id() != "player": break
			var me: Vector2i = c.sim.c("player").tile
			var target := ""
			for id in c.sim.combatants:
				if id != "player" and c.sim.conscious(id):
					target = id; break
			var path := c.sim.trim_path("player", c.sim.find_path("player", c.sim.c(target).tile), c.sim.speed_squares("player"))
			var plan := []
			if not path.is_empty(): plan.append({"type": "move", "path": path.map(func(t): return [t.x, t.y])})
			var g := c.preview(plan + [{"type": "attack", "target": target}])
			if g.valid: plan.append({"type": "attack", "target": target})
			if not plan.is_empty():
				var r := WorldHelpers.cmd(w, "ExecutePlan", {"actions": plan})
				for e in r.emitted_events: out.append([e.event_type, e.payload.get("d20", -1), e.payload.get("damage", -1)])
			if c.active:
				var r2 := WorldHelpers.cmd(w, "EndTurn")
				for e in r2.emitted_events: out.append([e.event_type, e.payload.get("d20", -1), e.payload.get("damage", -1)])
		logs.append(out)
	check(logs[0].size() > 3, "houve eventos de combate")
	eq(JSON.stringify(logs[0]), JSON.stringify(logs[1]), "replay idêntico com mesma seed")


func test_iniciativa_inimigos_um_unico_teste() -> void:
	var w := _crypt_fight(9, ["bandido_1", "bandido_2", "kael"])
	var c: CombatModule = w.modules.combat
	check(c.sim.initiative.has("enemies") and c.sim.initiative.has("player"), "um valor para o jogador e um para os inimigos")
	eq(c.sim.order.size(), 4, "quatro combatentes")


func test_flanquear_da_mais_dois() -> void:
	var w := _crypt_fight(3, ["bandido_1", "bandido_2"])
	var sim: CombatSim = w.modules.combat.sim
	sim.c("bandido_1").tile = Vector2i(28, 56)
	sim.c("player").tile = Vector2i(27, 56)
	sim.c("bandido_2").tile = Vector2i(26, 56)
	var prof := sim.attack_profile("bandido_1", "player", 0, false, false)
	check(prof.mods.any(func(m): return m[0] == "flanqueando" and m[1] == 2), "flanco +2 (LB p.239)")


func test_diagonal_custa_dobro_e_terreno_dificil() -> void:
	var w := _crypt_fight()
	var sim: CombatSim = w.modules.combat.sim
	eq(sim.step_cost(Vector2i(10, 55), Vector2i(11, 56)), 2, "diagonal = 2 quadrados")
	eq(sim.step_cost(Vector2i(26, 53), Vector2i(27, 53)), 2, "entulho = terreno difícil x2")
	eq(sim.speed_squares("player"), 6, "9m = 6 quadrados")


func test_nadar_atravessa_rio_so_quem_nada() -> void:
	var w := _crypt_fight()
	var sim: CombatSim = w.modules.combat.sim
	var agua := _primeira_agua(sim.db)
	check(agua != Vector2i(-1, -1), "mapa tem rio")
	check(not sim.passable(agua, "player"), "sem natação, o rio bloqueia (LB p.238)")
	sim.c("player").sheet.swim_m = 9.0
	check(sim.passable(agua, "player"), "com natação, atravessa o rio (Heróis: natação = base)")


func test_barranco_so_quem_voa_atravessa_e_ponte_passa_a_pe() -> void:
	var w := _crypt_fight()
	var sim: CombatSim = w.modules.combat.sim
	check(not sim.passable(Vector2i(60, 5), "player"), "barranco bloqueia a pé")
	check(sim.passable(Vector2i(60, 9), "player"), "ponte é passagem a pé")
	sim.c("player").sheet.fly_m = 9.0
	check(sim.passable(Vector2i(60, 5), "player"), "voo atravessa o barranco (Heróis, Voo)")


func test_superficie_inteira_alcancavel_a_pe() -> void:
	var w := _crypt_fight()
	var sim: CombatSim = w.modules.combat.sim
	var start := Vector2i(23, 27)
	var seen := {start: true}
	var fila: Array[Vector2i] = [start]
	while not fila.is_empty():
		var t: Vector2i = fila.pop_back()
		for n in [t + Vector2i.RIGHT, t + Vector2i.LEFT, t + Vector2i.DOWN, t + Vector2i.UP]:
			if not seen.has(n) and n.y < 49 and sim.db.static_walkable(n):
				seen[n] = true
				fila.append(n)
	var falta := 0
	for y in range(49):
		for x in range(sim.db.size.x):
			var t := Vector2i(x, y)
			if sim.db.static_walkable(t) and not seen.has(t):
				falta += 1
	eq(falta, 0, "todo chão da superfície liga ao início (bolsões abertos em build_content)")


func test_armadura_de_allihanna_custa_pm_da_defesa_e_nao_ativa_duas_vezes() -> void:
	var w := _crypt_fight()
	var sim: CombatSim = w.modules.combat.sim
	var P := sim.c("player")
	P.sheet.race_id = "dahllan"
	P.sheet.pm = 3
	var antes: int = P.sheet.defense(sim.rules)
	check(GhostPlanner.validate_action(sim, "player", {"type": "allihanna"}).ok, "dahllan ativa a armadura")
	w.modules.combat._execute_action("player", {"type": "allihanna"}, {"ok": true, "kind": "movimento", "cost": 0})
	eq(P.sheet.pm, 2, "custa 1 PM")
	eq(P.sheet.defense(sim.rules) - antes, 2, "+2 de Defesa (LB, dahllan)")
	check(not GhostPlanner.validate_action(sim, "player", {"type": "allihanna"}).ok, "não ativa duas vezes na cena")


func _primeira_agua(db) -> Vector2i:
	for y in db.size.y:
		for x in db.size.x:
			if db.is_water(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func test_investida_exige_linha_reta() -> void:
	var w := _crypt_fight()
	var c: CombatModule = w.modules.combat
	var sim: CombatSim = c.sim
	sim.c("player").tile = Vector2i(14, 56)
	sim.c("bandido_1").tile = Vector2i(19, 56)
	var ok := GhostPlanner.validate_action(sim, "player", {"type": "charge", "target": "bandido_1", "path": [[15, 56], [16, 56], [17, 56], [18, 56]]})
	check(ok.ok, "investida reta válida: %s" % str(ok.get("reason", "")))
	var bad := GhostPlanner.validate_action(sim, "player", {"type": "charge", "target": "bandido_1", "path": [[15, 56], [16, 57], [17, 56], [18, 56]]})
	check(not bad.ok, "investida torta inválida")


func test_derrota_para_bandidos_vira_captura() -> void:
	var w := _crypt_fight(5, ["bandido_1"])
	var c: CombatModule = w.modules.combat
	c.sim.c("player").sheet.pv = 0
	c.sim.c("player").sheet.stable = true
	var out := c._check_end()
	check(out.any(func(f): return f.type == "PLAYER_CAPTURED"), "capturado")
	eq(w.db.location_at(w.db.world_to_tile(w.player.position)), "cripta_cela", "acorda na cela")
	check(not c.active, "combate encerrado")


func test_morte_quando_pv_abaixo_do_limite() -> void:
	var w := _crypt_fight(5, ["bandido_1"])
	var c: CombatModule = w.modules.combat
	c.sim.apply_damage("player", 40)
	var out := c._check_end()
	check(out.any(func(f): return f.type == "PLAYER_DIED"), "morte permanente sem proteção narrativa")


func test_sangramento_testa_constituicao() -> void:
	var w := _crypt_fight(5, ["bandido_1"])
	var c: CombatModule = w.modules.combat
	c.sim.c("bandido_1").sheet.pv = -2
	c.sim.c("bandido_1").sheet.stable = false
	var r := c._begin_turn("bandido_1")
	check(r.skip, "caído não age")
	check(r.facts.any(func(f): return f.type == "BLEED_CHECK"), "teste de Con CD 15 (LB p.236)")


func test_vitoria_da_chave_do_kael() -> void:
	var w := _crypt_fight(5, ["kael"])
	var c: CombatModule = w.modules.combat
	c.sim.c("kael").sheet.pv = -20
	var out := c._check_end()
	var facts := out.map(func(f): return f.type)
	check(facts.has("CREATURE_DEFEATED"), "derrotado")
	check(out.any(func(f): return f.type == "ITEM_GAINED" and f.payload.item == "chave_cela"), "chave obtida")


func test_encontro_dispara_por_proximidade_e_furtividade_rola_uma_vez() -> void:
	var w := WorldHelpers.world(13)
	w.clock.tick = 6 * 14  # 14h: bandidos acordados
	WorldHelpers.put(w, 8, 55)
	WorldHelpers.cmd(w, "SetStance", {"sneak": true})
	WorldHelpers.put(w, 22, 56)
	var r := WorldHelpers.cmd(w, "MovePlayer", {"to": w.db.tile_to_world(Vector2i(22, 56))})
	var checks := WorldHelpers.events_of(r, "STEALTH_CHECK")
	eq(checks.size(), 1, "um teste oposto na aproximação")
	var r2 := WorldHelpers.cmd(w, "MovePlayer", {"to": w.db.tile_to_world(Vector2i(22, 57))})
	eq(WorldHelpers.events_of(r2, "STEALTH_CHECK").size(), 0, "não rola de novo a cada passo")


func test_barulho_de_madrugada_pode_nao_acordar_quem_dorme() -> void:
	var woke := 0
	var slept := 0
	for s in range(20):
		var w := WorldHelpers.world(100 + s)
		w.clock.tick = 6 * 3  # 3h: todos dormem
		WorldHelpers.put(w, 34, 55)
		var r := WorldHelpers.cmd(w, "UseObject", {"object_id": "porta_cela", "action": "break"})
		if w.modules.combat.active: woke += 1
		else: slept += 1
	check(slept > woke, "na maioria das vezes ninguém acorda (%d dormiram, %d acordaram)" % [slept, woke])
	check(woke + slept == 20, "sempre um desfecho")
