extends TestCase
## Gates do vertical slice jogados só por comandos (sem atalhos internos).


func _talk(w: WorldState, npc: String, choose_prefixes: Array) -> void:
	var t: Vector2i = w.modules.npcs.npc_tile(npc)
	WorldHelpers.put(w, t.x, t.y + 1 if w.db.static_walkable(t + Vector2i(0, 1)) else t.y)
	var r := WorldHelpers.cmd(w, "StartDialogue", {"npc_id": npc})
	if not r.accepted:
		return
	for pref in choose_prefixes:
		var v: Dictionary = w.modules.dialogue.view()
		if v.is_empty(): break
		for o in v.options:
			if str(o.text).begins_with(pref):
				WorldHelpers.cmd(w, "ChooseOption", {"index": o.index})
				break
	if not w.modules.dialogue.session.is_empty():
		WorldHelpers.cmd(w, "EndDialogue")


func _inspect_until(w: WorldState, target: String, approaches: Array, fact_id: String, max_days: int = 6) -> bool:
	var ex: ExplorationModule = w.modules.exploration
	var t := w.db.target_def(target)
	for d in max_days:
		for a in approaches:
			WorldHelpers.put(w, int(t.tile[0]), int(t.tile[1]) + 1)
			if w.modules.combat.active: return ex.knows(fact_id)
			WorldHelpers.cmd(w, "InspectTarget", {"target_id": target, "approach": a})
			if ex.knows(fact_id): return true
		WorldHelpers.advance_hours(w, 25)
	return ex.knows(fact_id)


func test_rota_investigativa_ate_a_incursao_da_guarda() -> void:
	var w := WorldHelpers.world(1001)
	w.clock.tick = 6 * 9
	WorldHelpers.advance_hours(w, 1)
	_talk(w, "hilda", ["Vou procurar"])
	check(w.modules.state.has_flag("aceitou_busca"), "aceitou a busca")
	var ok := _inspect_until(w, "arbusto_estrada", ["examinar"], "f_tomas_levado")
	check(ok, "achou o retalho")
	# de dia, a trilha antiga (as hienas só saem à noite)
	w.clock.tick = (w.clock.tick / 144 + 1) * 144 + 6 * 9
	ok = _inspect_until(w, "trilha_marcas", ["rastrear", "examinar"], "f_bandidos_na_ruina")
	check(ok, "descobriu a cripta pela trilha")
	w.clock.tick = (w.clock.tick / 144) * 144 + 6 * 10
	WorldHelpers.advance_hours(w, 1)
	_talk(w, "elsa", ["Há bandidos"])
	check(w.modules.state.has_flag("guarda_avisada"), "denunciou à capitã")
	var resolved := false
	for h in 30:
		var r := WorldHelpers.advance_hours(w, 1)
		if not WorldHelpers.events_of(r, "GUARD_RAID_RESOLVED").is_empty():
			resolved = true
			break
	check(resolved, "incursão aconteceu")
	var st: String = w.modules.exploration.mystery_state
	check(st in ["resolvido", "ativo"], "estado coerente: " + st)
	if st == "resolvido":
		check(w.modules.memory.reputation("tomas", "guarda_vila") > 0, "crédito vai para a Guarda, não para o jogador")


func _fight(w: WorldState) -> String:
	var c: CombatModule = w.modules.combat
	for turn in 40:
		if not c.active:
			break
		if c.sim.current_id() != "player":
			break
		var target := ""
		var bd := 999
		for id in c.sim.combatants:
			if id != "player" and c.sim.conscious(id):
				var d := CombatSim.cheb(c.sim.c("player").tile, c.sim.c(id).tile)
				if d < bd: bd = d; target = id
		if target == "":
			break
		var plan := []
		if bd > 1:
			var path := c.sim.trim_path("player", c.sim.find_path("player", c.sim.c(target).tile), c.sim.speed_squares("player"))
			if not path.is_empty(): plan.append({"type": "move", "path": path.map(func(t): return [t.x, t.y])})
		var atk := {"type": "attack", "target": target, "special": c.sim.c("player").sheet.pm > 0}
		if c.preview(plan + [atk]).valid: plan.append(atk)
		if not plan.is_empty():
			WorldHelpers.cmd(w, "ExecutePlan", {"actions": plan})
		if c.active:
			WorldHelpers.cmd(w, "EndTurn")
	return "ativo" if c.active else "fim"


func test_rota_de_combate_e_coerente_em_varias_seeds() -> void:
	var outcomes := {}
	for s in [11, 22, 33, 44, 55, 66]:
		var w := WorldHelpers.world(s)
		w.clock.tick = 6 * 14
		WorldHelpers.put(w, 86, 10)
		WorldHelpers.cmd(w, "UseObject", {"object_id": "escada_ruina", "action": "use_stairs"})
		WorldHelpers.cmd(w, "MovePlayer", {"to": w.db.tile_to_world(Vector2i(20, 56))})
		if not w.modules.combat.active:
			WorldHelpers.cmd(w, "MovePlayer", {"to": w.db.tile_to_world(Vector2i(24, 56))})
		check(w.modules.combat.active, "seed %d: bandidos acordados detectam" % s)
		_fight(w)
		check(not w.modules.combat.active, "seed %d: combate terminou" % s)
		var out := ""
		for j in w.journal:
			if j.event_type == "COMBAT_ENDED": out = j.payload.outcome
		outcomes[out] = outcomes.get(out, 0) + 1
		match out:
			"vitoria":
				check(w.modules.state.has_item("chave_cela"), "seed %d: chave do Kael" % s)
				WorldHelpers.put(w, 34, 55)
				check(WorldHelpers.cmd(w, "UseObject", {"object_id": "porta_cela", "action": "unlock"}).accepted, "destranca")
				check(WorldHelpers.cmd(w, "UseObject", {"object_id": "porta_cela", "action": "open"}).accepted, "abre")
				var t: Vector2i = w.modules.npcs.npc_tile("tomas")
				WorldHelpers.put(w, t.x - 1, t.y)
				check(WorldHelpers.cmd(w, "RescueNPC", {"npc_id": "tomas"}).accepted, "resgata")
				eq(w.modules.exploration.mystery_state, "resolvido", "resolvido")
			"captura":
				eq(w.db.location_at(w.db.world_to_tile(w.player.position)), "cripta_cela", "seed %d: preso na cela" % s)
				eq(w.player.gold, 0, "roubado")
				check(w.player_sheet.pv >= 1, "vivo")
			"morte":
				check(w.player_sheet.is_dead(), "morte coerente")
			_:
				check(false, "seed %d: desfecho inesperado '%s'" % [s, out])
	check(outcomes.size() >= 1, "desfechos: %s" % str(outcomes))
	print("    desfechos do combate por seed: ", outcomes)


func test_sessao_longa_estavel_e_salvavel() -> void:
	var w := WorldHelpers.world(2026)
	var spots := [[23, 27], [17, 21], [11, 13], [30, 15], [40, 29], [45, 26], [60, 26], [34, 41]]
	var t0 := Time.get_ticks_msec()
	for i in 450:  # ~15 min reais a 2s/tick
		if i % 15 == 0:
			var sp: Array = spots[(i / 15) % spots.size()]
			WorldHelpers.cmd(w, "MovePlayer", {"to": w.db.tile_to_world(Vector2i(sp[0], sp[1]))})
		if w.modules.combat.active:
			_fight(w)
		var r := WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 1})
		if w.modules.combat.active: continue
		check(r.accepted or w.modules.combat.active, "tick %d" % i)
	var elapsed := Time.get_ticks_msec() - t0
	check(elapsed < 20000, "450 ticks em %d ms" % elapsed)
	var repo := JsonSaveRepository.new("user://test_saves_long")
	eq(repo.save("s", w.to_snapshot()), OK, "save")
	var w2 := WorldHelpers.world(1)
	w2.from_snapshot(repo.load_slot("s").data)
	eq(WorldHelpers.snap(w2).sha256_text(), WorldHelpers.snap(w).sha256_text(), "reinício preserva estado")
	print("    sessão: %d ticks em %d ms; journal %d eventos" % [450, elapsed, w.journal.size()])
