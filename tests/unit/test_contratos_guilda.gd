extends TestCase
## Arton Viva, Fase 6: contratos da guilda, caixa e distribuição; morte no serviço falha o contrato.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 12 * 6
	w.player.gold = 500
	return w


## dois membros recrutados (pagando a taxa) e uma guilda criada
func _com_guilda() -> WorldState:
	var w := _world()
	WorldHelpers.cmd(w, "RecruitCompanion", {"npc_id": "garrick", "pay": PartyModule.RECRUIT_FEE})
	WorldHelpers.cmd(w, "RecruitCompanion", {"npc_id": "rosana", "pay": PartyModule.RECRUIT_FEE})
	WorldHelpers.cmd(w, "CreateGuild", {"name": "Martelo"})
	return w


func test_contrato_exige_guilda() -> void:
	var w := _world()
	WorldHelpers.cmd(w, "RecruitCompanion", {"npc_id": "garrick", "pay": PartyModule.RECRUIT_FEE})
	var r := WorldHelpers.cmd(w, "AcceptContract", {"contrato": "patrulha_estrada"})
	check(not r.accepted, "sem guilda não há contrato")


func test_contrato_ocupa_membros_e_paga_no_prazo() -> void:
	var w := _com_guilda()
	var party: PartyModule = w.modules.party
	var r := WorldHelpers.cmd(w, "AcceptContract", {"contrato": "escolta_mercado"})
	check(r.accepted, "contrato aceito com dois membros livres: %s" % str(r.errors))
	var de_novo := WorldHelpers.cmd(w, "AcceptContract", {"contrato": "patrulha_estrada"})
	check(not de_novo.accepted, "membros ocupados não aceitam outro contrato")
	var loyal_antes := float(party.members.garrick.loyalty)
	WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 288})
	eq(party.caixa, 40, "o contrato de escolta paga T$ 40 ao caixa da guilda")
	check(float(party.members.garrick.loyalty) >= loyal_antes + party.CONTRACT_LOYALTY_GAIN, "quem cumpriu ganha lealdade")
	var livre := WorldHelpers.cmd(w, "AcceptContract", {"contrato": "patrulha_estrada"})
	check(livre.accepted, "depois do prazo os membros voltam a ficar livres")


func test_morte_no_servico_falha_o_contrato_sem_pagamento() -> void:
	var w := _com_guilda()
	var party: PartyModule = w.modules.party
	WorldHelpers.cmd(w, "AcceptContract", {"contrato": "escolta_mercado"})
	var out: Array = party.on_event(GameEvent.create("morte", "NPC_DIED", w.clock.tick, {"npc": "rosana"}))
	check(out.any(func(f): return f.type == "CONTRACT_FAILED"), "a morte de um membro falha o contrato")
	WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 288})
	eq(party.caixa, 0, "contrato falho não paga ao caixa")


func test_distribuicao_divide_o_caixa_entre_os_membros() -> void:
	var w := _com_guilda()
	var party: PartyModule = w.modules.party
	WorldHelpers.cmd(w, "AcceptContract", {"contrato": "escolta_mercado"})
	WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 288})
	eq(party.caixa, 40, "caixa com o pagamento do contrato")
	var loyal_antes := float(party.members.rosana.loyalty)
	var r := WorldHelpers.cmd(w, "GuildDistribute", {})
	check(r.accepted, "administração distribui o caixa: %s" % str(r.errors))
	eq(party.caixa, 0, "o caixa zera depois de dividido")
	check(float(party.members.rosana.loyalty) >= loyal_antes + party.SHARE_LOYALTY_GAIN, "quem recebe parte ganha lealdade")
	check(not WorldHelpers.cmd(w, "GuildDistribute", {}).accepted, "caixa vazio não distribui")


func test_contrato_desconhecido_e_recusado() -> void:
	var w := _com_guilda()
	check(not WorldHelpers.cmd(w, "AcceptContract", {"contrato": "nao_existe"}).accepted, "contrato desconhecido é recusado")


func test_caixa_e_contratos_sobrevivem_a_salvar() -> void:
	var w := _com_guilda()
	var party: PartyModule = w.modules.party
	WorldHelpers.cmd(w, "AcceptContract", {"contrato": "escolta_mercado"})
	WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 288})
	var d: Dictionary = party.to_dict()
	var w2 := _com_guilda()
	w2.modules.party.from_dict(d)
	eq(w2.modules.party.caixa, 40, "caixa persiste no save")
