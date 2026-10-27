extends TestCase
## Arton Viva, Fase 6 (correções): ficha completa, dano que persiste, descanso, caminhada até o destino do contrato.


func _grupo(p_seed: int = 5) -> WorldState:
	var w := WorldHelpers.world(p_seed)
	w.player.gold = 500
	WorldHelpers.put(w, 25, 57)
	for id in ["garrick", "rosana"]:
		WorldHelpers.cmd(w, "RecruitCompanion", {"npc_id": id, "pay": PartyModule.RECRUIT_FEE})
	WorldHelpers.cmd(w, "CreateGuild", {"name": "Martelo"})
	return w


## entrega ao grupo os fatos de estado que a luta devolve (o barramento faria isso no jogo)
func _entrega(party: PartyModule, facts: Array) -> void:
	for f in facts:
		if f.type == "COMPANION_STATE":
			party.on_event(GameEvent.create("cs", "COMPANION_STATE", 0, f.payload))


func test_ficha_do_companheiro_e_completa() -> void:
	var w := _grupo()
	var sh := CharacterSheet.from_dict(w.modules.party.members.garrick.sheet)
	eq(sh.name, "Garrick Ferro", "a ficha leva o nome do companheiro")
	check(sh.attacks.size() > 0, "a ficha tem ataques vindos do equipamento")
	check(sh.pv_max > 0, "a ficha tem PV máximos")


func test_dano_da_luta_persiste_para_a_proxima() -> void:
	var w := _grupo()
	var party: PartyModule = w.modules.party
	w.modules.combat._start(["bandido_1"], false, false)
	var c: CombatModule = w.modules.combat
	c.sim.c("garrick").sheet.pv = 3
	var out: Array = c._end_combat("vitoria")
	_entrega(party, out)
	eq(CharacterSheet.from_dict(party.members.garrick.sheet).pv, 3, "o PV de fim de luta fica salvo no grupo")
	WorldHelpers.cmd(w, "EndTurn")
	w.modules.combat._start(["bandido_1"], false, false)
	eq(w.modules.combat.sim.c("garrick").sheet.pv, 3, "a nova luta começa com o PV que sobrou")


func test_companheiro_ferido_nao_entra_na_luta_ate_se_recuperar() -> void:
	var w := _grupo()
	var party: PartyModule = w.modules.party
	var sh := CharacterSheet.from_dict(party.members.garrick.sheet)
	sh.pv = 0
	party.members.garrick.sheet = sh.to_dict()
	w.modules.combat._start(["bandido_1"], false, false)
	check(not w.modules.combat.sim.combatants.has("garrick"), "com PV zerado, o companheiro fica fora da luta")


func test_descanso_diario_recupera_pv() -> void:
	var w := _grupo()
	var party: PartyModule = w.modules.party
	var sh := CharacterSheet.from_dict(party.members.garrick.sheet)
	sh.pv = 2
	party.members.garrick.sheet = sh.to_dict()
	WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 144})
	var depois := CharacterSheet.from_dict(party.members.garrick.sheet).pv
	check(depois > 2, "um dia de descanso recupera PV (2 -> %d)" % depois)


func test_companheiro_caminha_ate_o_destino_do_contrato() -> void:
	var w := _grupo()
	var npcs = w.modules.npcs
	WorldHelpers.cmd(w, "AcceptContract", {"contrato": "escolta_mercado"})
	eq(npcs.desired_location("garrick"), "estrada_leste", "em contrato, o companheiro vai ao destino")
	WorldHelpers.cmd(w, "AdvanceTime", {"ticks": 288})
	check(npcs.desired_location("garrick") != "estrada_leste", "terminado o prazo, o companheiro volta à rotina")
