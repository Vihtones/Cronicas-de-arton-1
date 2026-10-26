extends TestCase
## Arton Viva, Fase 6: party com consentimento, ordens, perda por morte e guilda.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 12 * 6
	w.player.gold = 100
	return w


func _confia(w: WorldState, id: String) -> void:
	var rl: RelationsModule = w.modules.relations
	rl.rel[id] = {"player": {"confianca": 40.0, "familiaridade": 30.0, "afeto": 30.0}}


func test_recruta_quem_confia_no_jogador() -> void:
	var w := _world()
	_confia(w, "garrick")
	var r := WorldHelpers.cmd(w, "RecruitCompanion", {"npc_id": "garrick", "pay": 0})
	check(r.accepted, "quem confia e conhece o jogador aceita se juntar")
	check(w.modules.party.members.has("garrick"), "o recrutado entra na party")


func test_sem_confianca_so_com_pagamento_que_cubra_o_risco() -> void:
	var w := _world()
	var sem := WorldHelpers.cmd(w, "RecruitCompanion", {"npc_id": "garrick", "pay": 0})
	check(not sem.accepted, "sem confiança e sem pagamento, recusa")
	var paga := WorldHelpers.cmd(w, "RecruitCompanion", {"npc_id": "garrick", "pay": PartyModule.RECRUIT_FEE})
	check(paga.accepted, "com pagamento que cobre o risco, aceita")
	eq(w.player.gold, 100 - PartyModule.RECRUIT_FEE, "o pagamento sai do ouro do jogador")


func test_reputacao_sozinha_nao_recruta() -> void:
	var w := _world()
	var rl: RelationsModule = w.modules.relations
	rl.rel["garrick"] = {"player": {"respeito": 90.0, "admiracao": 90.0}}
	var r := WorldHelpers.cmd(w, "RecruitCompanion", {"npc_id": "garrick", "pay": 0})
	check(not r.accepted, "admiração e respeito altos não substituem consentimento")


func test_membro_que_morre_sai_da_party() -> void:
	var w := _world()
	_confia(w, "garrick")
	WorldHelpers.cmd(w, "RecruitCompanion", {"npc_id": "garrick", "pay": 0})
	var pm: PartyModule = w.modules.party
	var out := pm.on_event(GameEvent.create("m1", "NPC_DIED", w.clock.tick, {"npc": "garrick"}))
	check(not pm.members.has("garrick"), "quem morre sai da party")
	eq(out[0].type, "PARTY_LOST", "a perda sai como fato")


func test_ordem_so_para_membro() -> void:
	var w := _world()
	var sem := WorldHelpers.cmd(w, "SetOrder", {"npc_id": "garrick", "order": "proteger"})
	check(not sem.accepted, "não dá ordem a quem não está na party")
	_confia(w, "garrick")
	WorldHelpers.cmd(w, "RecruitCompanion", {"npc_id": "garrick", "pay": 0})
	var ok := WorldHelpers.cmd(w, "SetOrder", {"npc_id": "garrick", "order": "proteger"})
	check(ok.accepted, "membro da party recebe ordem")
	eq(w.modules.party.members.garrick.order, "proteger", "a ordem fica guardada")


func test_guilda_exige_dois_membros_e_ouro() -> void:
	var w := _world()
	_confia(w, "garrick")
	WorldHelpers.cmd(w, "RecruitCompanion", {"npc_id": "garrick", "pay": 0})
	check(not WorldHelpers.cmd(w, "CreateGuild", {"name": "Martelo"}).accepted, "um membro não basta para guilda")
	_confia(w, "elsa")
	WorldHelpers.cmd(w, "RecruitCompanion", {"npc_id": "elsa", "pay": 0})
	var r := WorldHelpers.cmd(w, "CreateGuild", {"name": "Martelo"})
	check(r.accepted, "dois membros e ouro criam a guilda")
	eq(w.modules.party.guild.name, "Martelo", "a guilda leva o nome escolhido")
	check(not WorldHelpers.cmd(w, "CreateGuild", {"name": "Outra"}).accepted, "a guilda é criada uma única vez")
