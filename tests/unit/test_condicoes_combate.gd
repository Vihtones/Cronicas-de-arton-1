extends TestCase
## Efeitos de condição no combate (src/domain/combat/condicoes_combate.gd): início de turno, ações bloqueadas,
## enjoado, confuso, surdez, petrificação, sobrecarregado e condições com rodadas.
const CondicoesCombate := preload("res://src/domain/combat/condicoes_combate.gd")


func _cena() -> Array:
	var r := RuleRegistry.load_default()
	var sh := CharacterBuilder.build(r, "humano", "clerigo", CharacterBuilder.presets("clerigo")[0], ["for", "des", "con"], "clerigo")
	sh.level = 9
	sh.equipment["armor"] = ""
	var w := WorldHelpers.world(5)
	w.player_sheet = sh
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1", "bandido_2"], false, false)
	var c: CombatModule = w.modules.combat
	var sim: CombatSim = c.sim
	sim.c("player").tile = Vector2i(10, 57)
	sim.c("bandido_1").tile = Vector2i(27, 57)
	sim.c("bandido_2").tile = Vector2i(40, 57)
	sim.walk_fn = func(_t: Vector2i) -> bool: return true
	for id in ["player", "bandido_1", "bandido_2"]:
		var s: CharacterSheet = sim.c(id).sheet
		s.pv_max = 999
		s.pv = 999
		s.pm_max = 99
		s.pm = 99
	return [w, c, sim, r]


# --- Início de turno -------------------------------------------------------------------------
func test_em_chamas_causa_fogo_no_inicio_do_turno_e_gasta_a_acao_padrao_para_apagar() -> void:
	var m := _cena()
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var r: RuleRegistry = m[3]
	sim.c("bandido_1").sheet.add_condition("em_chamas", r)
	c._begin_turn("bandido_1")
	check(sim.c("bandido_1").sheet.pv < 999, "em chamas causa dano no início do turno")
	check(not sim.c("bandido_1").sheet.conditions.has("em_chamas"), "a ação padrão apaga o fogo")
	eq(sim.budget.std, 0, "apagar o fogo gasta a ação padrão")


func test_sangrando_passa_no_teste_de_constituicao_e_para() -> void:
	var m := _cena()
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var r: RuleRegistry = m[3]
	var s: CharacterSheet = sim.c("bandido_1").sheet
	s.attrs["con"] = 99
	s.add_condition("sangrando", r)
	c._begin_turn("bandido_1")
	check(not s.conditions.has("sangrando"), "passou na Constituição: o sangramento para")
	eq(s.pv, 999, "sem dano quando passa")


func test_sangrando_falha_no_teste_e_perde_pv_e_continua() -> void:
	var m := _cena()
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var r: RuleRegistry = m[3]
	var s: CharacterSheet = sim.c("bandido_1").sheet
	s.attrs["con"] = -99
	s.add_condition("sangrando", r)
	c._begin_turn("bandido_1")
	check(s.pv < 999, "falhou na Constituição: perde PV")
	check(s.conditions.has("sangrando"), "continua sangrando")


# --- Ações bloqueadas ------------------------------------------------------------------------
func test_atordoado_perde_o_turno_sem_acao() -> void:
	var m := _cena()
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var r: RuleRegistry = m[3]
	sim.c("bandido_1").sheet.add_condition("atordoado", r)
	var res: Dictionary = c._begin_turn("bandido_1")
	check(res.skip, "atordoado não age")
	check(not res.facts.is_empty() and res.facts[-1].type == "TURN_SKIPPED", "registra o turno perdido")


func test_inconsciente_nao_reage() -> void:
	var m := _cena()
	var r: RuleRegistry = m[3]
	var s: CharacterSheet = m[2].c("player").sheet
	check(CondicoesCombate.pode_reagir(s, r), "consciente pode reagir")
	s.add_condition("inconsciente", r)
	check(not CondicoesCombate.pode_reagir(s, r), "inconsciente não reage")


# --- Enjoado ---------------------------------------------------------------------------------
func test_enjoado_tem_uma_unica_acao_por_turno() -> void:
	var m := _cena()
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var r: RuleRegistry = m[3]
	sim.c("player").sheet.add_condition("enjoado", r)
	c._begin_turn("player")
	check(sim.budget.get("enjoado", false), "turno marcado como enjoado")
	sim.spend("padrao")
	eq(sim.budget.move, 0, "depois da ação padrão, não sobra movimento")
	eq(sim.budget.std, 0, "e não sobra outra ação padrão")


# --- Confuso e surdez (funções puras) -------------------------------------------------------
func test_confuso_segue_a_tabela_do_dado() -> void:
	eq(CondicoesCombate.confuso_por_dado(1), "mover", "1: movimento ao acaso")
	eq(CondicoesCombate.confuso_por_dado(2), "perder", "2: perde o turno")
	eq(CondicoesCombate.confuso_por_dado(3), "perder", "3: perde o turno")
	eq(CondicoesCombate.confuso_por_dado(4), "atacar", "4: ataca a criatura adjacente")
	eq(CondicoesCombate.confuso_por_dado(5), "atacar", "5: ataca a criatura adjacente")
	eq(CondicoesCombate.confuso_por_dado(6), "normal", "6: age normalmente")


func test_surdo_falha_em_20_por_cento() -> void:
	check(CondicoesCombate.surdo_falha(1), "1 falha")
	check(CondicoesCombate.surdo_falha(20), "20 falha")
	check(not CondicoesCombate.surdo_falha(21), "21 não falha")


# --- Dano e deslocamento ---------------------------------------------------------------------
func test_petrificado_reduz_8_de_todo_dano() -> void:
	var m := _cena()
	var sim: CombatSim = m[2]
	var r: RuleRegistry = m[3]
	sim.c("bandido_1").sheet.add_condition("petrificado", r)
	sim.apply_damage("bandido_1", 20)
	eq(sim.c("bandido_1").sheet.pv, 999 - 12, "20 de dano viram 12")


func test_sobrecarregado_reduz_2_quadrados_de_deslocamento() -> void:
	var m := _cena()
	var sim: CombatSim = m[2]
	var r: RuleRegistry = m[3]
	var base := sim.speed_squares("bandido_1")
	sim.c("bandido_1").sheet.add_condition("sobrecarregado", r)
	eq(base - sim.speed_squares("bandido_1"), 2, "sobrecarregado tira 3m, que são 2 quadrados")


# --- Condições com rodadas -------------------------------------------------------------------
func test_condicao_com_rodadas_acaba_quando_as_rodadas_passam() -> void:
	var m := _cena()
	var sim: CombatSim = m[2]
	check(sim.add_condicao("bandido_1", "cego", 1, "teste"), "cego é aplicado")
	check(sim.c("bandido_1").sheet.conditions.has("cego"), "cego presente")
	sim._passar_rodada()
	check(not sim.c("bandido_1").sheet.conditions.has("cego"), "cego acaba quando a rodada passa")


func test_condicao_nao_e_aplicada_a_imune() -> void:
	var m := _cena()
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("teste", "imune", 1, "cena", "cego")
	check(not sim.add_condicao("bandido_1", "cego", 2, "teste"), "imune não recebe a condição")
	check(not sim.c("bandido_1").sheet.conditions.has("cego"), "e não fica com ela")


func test_criatura_sem_condicao_age_normalmente() -> void:
	var m := _cena()
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var res: Dictionary = c._begin_turn("bandido_2")
	check(not res.skip, "criatura sem condição age normalmente")
