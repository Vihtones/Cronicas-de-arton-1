extends TestCase
## Arton Viva, Fase 8: homebrews são opcionais, identificáveis e não se somam em conflito.


func _world() -> WorldState:
	return WorldHelpers.world(3)


func test_padrao_e_o_jogo_t20_basico() -> void:
	var w := _world()
	var hb: HomebrewModule = w.modules.homebrew
	for id in HomebrewModule.RULES:
		check(not hb.is_on(id), "%s começa desligado" % id)


func test_ligar_uma_regra_registra_versao_e_fato() -> void:
	var w := _world()
	var r := WorldHelpers.cmd(w, "SetHomebrew", {"id": "interacao_combate", "on": true})
	check(r.accepted, "uma regra opcional pode ser ligada")
	check(w.modules.homebrew.is_on("interacao_combate"), "a regra fica ligada")
	eq(WorldHelpers.events_of(r, "HOMEBREW_SET")[0].payload.version, "1.0", "o fato traz a versão da regra")


func test_party_tatica_e_parceiro_t20_nao_se_somam() -> void:
	var w := _world()
	WorldHelpers.cmd(w, "SetHomebrew", {"id": "parceiro_t20", "on": true})
	var r := WorldHelpers.cmd(w, "SetHomebrew", {"id": "party_tatica", "on": true})
	check(not r.accepted, "não liga Party Tática com Parceiro T20 ligado")
	check(r.errors.size() > 0, "a recusa explica o conflito")


func test_regra_com_dependencia_pede_a_dependencia() -> void:
	var w := _world()
	var r := WorldHelpers.cmd(w, "SetHomebrew", {"id": "party_tatica", "on": true})
	check(not r.accepted, "Party Tática depende de companheiros")
	WorldHelpers.cmd(w, "SetHomebrew", {"id": "companheiros", "on": true})
	var r2 := WorldHelpers.cmd(w, "SetHomebrew", {"id": "party_tatica", "on": true})
	check(r2.accepted, "com a dependência ligada, a Party Tática liga")


func test_desligar_nao_apaga_o_jogo_e_salva() -> void:
	var w := _world()
	WorldHelpers.cmd(w, "SetHomebrew", {"id": "vida_social", "on": true})
	var w2 := WorldHelpers.world(1)
	w2.from_snapshot(w.to_snapshot())
	check(w2.modules.homebrew.is_on("vida_social"), "homebrew ligado sobrevive ao salvamento")
	WorldHelpers.cmd(w2, "SetHomebrew", {"id": "vida_social", "on": false})
	check(not w2.modules.homebrew.is_on("vida_social"), "desligar devolve à regra básica")
