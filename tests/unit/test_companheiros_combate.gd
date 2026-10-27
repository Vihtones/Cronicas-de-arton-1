extends TestCase
## Arton Viva, Fase 6: companheiros são IAs do lado do jogador; as ordens mudam o que fazem na luta.


func _luta(p_seed: int = 5, membros: Array = ["garrick"]) -> WorldState:
	var w := WorldHelpers.world(p_seed)
	w.player.gold = 500
	WorldHelpers.put(w, 25, 57)
	for id in membros:
		WorldHelpers.cmd(w, "RecruitCompanion", {"npc_id": id, "pay": PartyModule.RECRUIT_FEE})
	w.modules.combat._start(["bandido_1"], false, false)
	return w


func _passa_turnos(w: WorldState, n: int) -> void:
	for i in n:
		var c: CombatModule = w.modules.combat
		if not c.active:
			return
		WorldHelpers.cmd(w, "EndTurn")


func test_companheiro_entra_do_lado_do_jogador_logo_depois_dele() -> void:
	var w := _luta()
	var c: CombatModule = w.modules.combat
	check(c.sim.combatants.has("garrick"), "o companheiro entra na luta")
	eq(c.sim.c("garrick").side, "player", "companheiro é do lado do jogador")
	eq(c.sim.order.find("garrick"), c.sim.order.find("player") + 1, "age logo depois do jogador")
	check(c.sim.c("garrick").sheet.pv > 0, "tem ficha de combate com PV")


func test_companheiro_em_contrato_nao_entra_na_luta() -> void:
	var w := _luta(5, ["garrick", "rosana"])
	# a luta já começou; monta outra com os dois ocupados num contrato
	var w2 := WorldHelpers.world(5)
	w2.player.gold = 500
	WorldHelpers.put(w2, 25, 57)
	for id in ["garrick", "rosana"]:
		WorldHelpers.cmd(w2, "RecruitCompanion", {"npc_id": id, "pay": PartyModule.RECRUIT_FEE})
	WorldHelpers.cmd(w2, "CreateGuild", {"name": "Martelo"})
	WorldHelpers.cmd(w2, "AcceptContract", {"contrato": "escolta_mercado"})
	w2.modules.combat._start(["bandido_1"], false, false)
	check(not w2.modules.combat.sim.combatants.has("garrick"), "quem está em contrato não luta")


func test_manter_posicao_nao_se_move() -> void:
	var w := _luta()
	WorldHelpers.cmd(w, "SetOrder", {"npc_id": "garrick", "order": "manter_posicao"})
	var c: CombatModule = w.modules.combat
	var inicio: Vector2i = c.sim.c("garrick").tile
	_passa_turnos(w, 6)
	eq(c.sim.c("garrick").tile, inicio, "com manter posição, o companheiro não sai do lugar")


func test_seguir_avanca_em_direcao_ao_inimigo() -> void:
	var w := _luta()
	var c: CombatModule = w.modules.combat
	var inicio: Vector2i = c.sim.c("garrick").tile
	_passa_turnos(w, 6)
	check(c.sim.c("garrick").tile != inicio, "com seguir, o companheiro se move na luta")


func test_companheiro_nao_vira_criatura() -> void:
	var w := _luta()
	var c: CombatModule = w.modules.combat
	_passa_turnos(w, 40)
	check(c.active == false, "a luta termina")
	check(not c.creature_state.has("garrick"), "companheiro não entra no estado de criaturas")


func test_ordens_sobrevivem_a_salvar_no_meio_da_luta() -> void:
	var w := _luta()
	var c: CombatModule = w.modules.combat
	WorldHelpers.cmd(w, "SetOrder", {"npc_id": "garrick", "order": "proteger"})
	var d: Dictionary = c.to_dict()
	var w2 := WorldHelpers.world(5)
	w2.modules.combat.from_dict(d)
	eq(str(w2.modules.combat.sim.c("garrick").order), "proteger", "a ordem persiste no meio da luta")
