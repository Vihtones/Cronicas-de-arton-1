extends TestCase
## Sistemas para magias complexas (docs/MAGIA_COMPLEXA.md): áreas, zonas, marcas, invocações e PV temporários.
const Area := preload("res://src/domain/combat/area.gd")


func _cena() -> Array:
	var r := RuleRegistry.load_default()
	var sh := CharacterBuilder.build(r, "humano", "clerigo", CharacterBuilder.presets("clerigo")[0], ["for", "des", "con"], "clerigo")
	sh.level = 13
	var w := WorldHelpers.world(5)
	w.player_sheet = sh
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1"], true, false)
	var c: CombatModule = w.modules.combat
	var sim: CombatSim = c.sim
	sim.c("player").tile = Vector2i(26, 57)
	sim.c("bandido_1").tile = Vector2i(27, 57)
	sim.walk_fn = func(_t: Vector2i) -> bool: return true   # mundo de teste sem mapa: tudo transitável
	return [w, c, sim]


# --- Áreas -------------------------------------------------------------------------------
func test_metros_viram_quadrados() -> void:
	eq(Area.quadrados(9.0), 6, "cone de 9m = 6 quadrados")
	eq(Area.quadrados(6.0), 4, "esfera de 6m de raio = 4 quadrados")
	eq(Area.quadrados(30.0), 20, "linha de 30m = 20 quadrados")


func test_esfera_inclui_o_centro_e_tem_tamanho_certo() -> void:
	var e: Array = Area.esfera(Vector2i(5, 5), 1)
	eq(e.size(), 9, "raio 1: 3x3")
	check(e.has(Vector2i(5, 5)), "inclui o centro")
	check(not Area.esfera(Vector2i(5, 5), 1).has(Vector2i(7, 5)), "não passa do raio")


func test_cone_vai_para_frente_e_nao_para_tras() -> void:
	var c: Array = Area.cone(Vector2i(5, 5), Vector2i(1, 0), 3)
	check(c.has(Vector2i(6, 5)), "quadrado da frente")
	check(c.has(Vector2i(8, 3)), "borda do cone (33 graus) entra")
	check(c.has(Vector2i(7, 7)), "45 graus entra")
	check(not c.has(Vector2i(4, 5)), "atrás não entra")
	check(not c.has(Vector2i(5, 6)), "lateral (90 graus) não entra")
	check(not c.has(Vector2i(5, 5)), "a origem não entra")
	check(not c.has(Vector2i(9, 5)), "não passa do comprimento")


func test_linha_segue_a_direcao() -> void:
	eq(Area.linha(Vector2i(0, 0), Vector2i(0, 1), 4), [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)], "linha para baixo")


# --- Zonas ---------------------------------------------------------------------------------
func test_zona_de_terreno_dificil_dobra_o_custo_do_passo() -> void:
	var r := _cena()
	var sim: CombatSim = r[2]
	var sem := sim.step_cost(Vector2i(26, 57), Vector2i(27, 57))
	sim.add_zona("z", [Vector2i(27, 57)], "terreno_dificil", 2, "teste")
	eq(sim.step_cost(Vector2i(26, 57), Vector2i(27, 57)), sem * 2, "dentro da zona custa o dobro")
	check(sim.zona_em(Vector2i(27, 57), "terreno_dificil"), "zona marcada no quadrado")


func test_zona_expira_depois_das_rodadas_e_zona_permanente_nao() -> void:
	var r := _cena()
	var sim: CombatSim = r[2]
	sim.add_zona("temp", [Vector2i(3, 3)], "terreno_dificil", 2, "teste")
	sim.add_zona("perm", [Vector2i(4, 4)], "terreno_dificil", -1, "teste")
	sim._passar_rodada()
	check(sim.zona_em(Vector2i(3, 3), "terreno_dificil"), "ainda vale depois de 1 rodada")
	sim._passar_rodada()
	check(not sim.zona_em(Vector2i(3, 3), "terreno_dificil"), "sai depois de 2 rodadas")
	check(sim.zona_em(Vector2i(4, 4), "terreno_dificil"), "zona sem fim automático continua")


func test_clone_copia_zonas() -> void:
	var r := _cena()
	var sim: CombatSim = r[2]
	sim.add_zona("z", [Vector2i(9, 9)], "terreno_dificil", 3, "teste")
	var g := sim.clone()
	check(g.zona_em(Vector2i(9, 9), "terreno_dificil"), "o clone (usado pelo planejamento) tem a zona")
	g.remove_zona("z")
	check(sim.zona_em(Vector2i(9, 9), "terreno_dificil"), "remover no clone não mexe na simulação real")


# --- Marcas --------------------------------------------------------------------------------
func test_marca_expira_e_fica_registrada() -> void:
	var r := _cena()
	var sim: CombatSim = r[2]
	sim.add_marca("maldicao_x", "bandido_1", "teste", "maldicao", 1)
	check(sim.tem_marca("bandido_1", "maldicao"), "marca ativa")
	sim._passar_rodada()
	check(not sim.tem_marca("bandido_1", "maldicao"), "acabou")
	check(sim.expiradas.has("maldicao_x"), "o fim fica registrado para a apresentação")


func test_ids_em_area_pega_so_criaturas_conscientes() -> void:
	var r := _cena()
	var sim: CombatSim = r[2]
	eq(sim.ids_em([Vector2i(27, 57)]), ["bandido_1"], "criatura no quadrado")
	sim.c("bandido_1").sheet.pv = -20
	eq(sim.ids_em([Vector2i(27, 57)]).size(), 0, "caída não entra")


# --- Invocações ----------------------------------------------------------------------------
func test_invocacao_entra_do_lado_do_conjurador_e_expira() -> void:
	var r := _cena()
	var c: CombatModule = r[1]
	var sim: CombatSim = c.sim
	var nova := c.invocar("player", "criatura.hiena", 2, "servo")
	check(sim.combatants.has(nova), "criatura criada na simulação")
	eq(sim.c(nova).side, "player", "do mesmo lado do conjurador")
	eq(sim.order[sim.order.find("player") + 1], nova, "logo depois do conjurador na ordem")
	check(sim.c(nova).tile != sim.c("player").tile, "não cai em cima do conjurador")
	sim._passar_rodada()
	check(sim.combatants.has(nova), "ainda está na cena depois de 1 rodada")
	sim._passar_rodada()
	check(not sim.combatants.has(nova), "sai da simulação ao acabar")
	check(not sim.order.has(nova), "sai da ordem de combate")


func test_remover_criatura_antes_da_vez_atual_ajusta_a_vez() -> void:
	var r := _cena()
	var sim: CombatSim = r[2]
	sim.order = ["player", "bandido_1"]
	sim.turn_idx = 1
	sim.remove_combatant("player")
	eq(sim.turn_idx, 0, "a vez de quem agia continua a mesma")
	eq(sim.order, ["bandido_1"], "ordem sem o removido")


# --- PV temporários ------------------------------------------------------------------------
func test_pv_temporario_absorve_dano_antes_dos_pv() -> void:
	var r := _cena()
	var sim: CombatSim = r[2]
	var sh: CharacterSheet = sim.c("player").sheet
	sh.pv = 20
	sh.pv_temp = 10
	sim.apply_damage("player", 6)
	eq(sh.pv, 20, "PV não mudam enquanto há temporários")
	eq(sh.pv_temp, 4, "restam 4 de PV temporário")
	sim.apply_damage("player", 8)
	eq(sh.pv_temp, 0, "temporários acabam")
	eq(sh.pv, 16, "o resto do dano vai para os PV")


func test_pv_temporario_sobrevive_ao_salvar() -> void:
	var sh := CharacterSheet.new()
	sh.pv_temp = 40
	eq(CharacterSheet.from_dict(sh.to_dict()).pv_temp, 40, "pv_temp no save")


func test_zonas_e_marcas_vao_para_o_save_da_simulacao() -> void:
	var r := _cena()
	var c: CombatModule = r[1]
	c.sim.add_zona("z", [Vector2i(9, 9)], "terreno_dificil", 2, "teste")
	c.sim.add_marca("m", "bandido_1", "teste", "maldicao", 2)
	var d := c.to_dict()
	eq((d.sim.zonas as Array).size(), 1, "zona salva")
	eq((d.sim.marcas as Array).size(), 1, "marca salva")




# --- Efeitos no início do turno (zonas e marcas) ----------------------------------------
func test_zona_com_dano_ataca_inimigos_que_comecam_o_turno_dentro_dela() -> void:
	var r := _cena()
	var c: CombatModule = r[1]
	var sim: CombatSim = r[2]
	var inimigo: CharacterSheet = sim.c("bandido_1").sheet
	inimigo.pv = 50
	sim.add_zona("fogo_x", [Vector2i(27, 57)], "fogo", 3, "magia.teste",
		{"dano_inicio_turno": "2d6", "afeta": "inimigos", "lado": "player", "conjurador": "player"})
	c._begin_turn("bandido_1")
	check(inimigo.pv < 50, "inimigo dentro da zona leva o dano (pv %d)" % inimigo.pv)


func test_zona_so_afeta_quem_o_filtro_manda() -> void:
	var r := _cena()
	var c: CombatModule = r[1]
	var sim: CombatSim = r[2]
	var P: CharacterSheet = sim.c("player").sheet
	P.pv = 30
	sim.add_zona("fogo_y", [Vector2i(26, 57)], "fogo", 3, "magia.teste",
		{"dano_inicio_turno": "2d6", "afeta": "inimigos", "lado": "player", "conjurador": "player"})
	c._begin_turn("player")
	eq(P.pv, 30, "o conjurador, do lado da zona, não é atingido por uma zona que pega só inimigos")


func test_zona_sem_dano_nao_faz_nada() -> void:
	var r := _cena()
	var c: CombatModule = r[1]
	var sim: CombatSim = r[2]
	var inimigo: CharacterSheet = sim.c("bandido_1").sheet
	inimigo.pv = 50
	sim.add_zona("neblina", [Vector2i(27, 57)], "neblina", 3, "magia.teste")
	c._begin_turn("bandido_1")
	eq(inimigo.pv, 50, "zona sem dados de dano não causa dano")


func test_marca_de_cura_e_dano_agem_no_inicio_do_turno_do_alvo() -> void:
	var r := _cena()
	var c: CombatModule = r[1]
	var sim: CombatSim = r[2]
	var inimigo: CharacterSheet = sim.c("bandido_1").sheet
	inimigo.pv = 1
	sim.add_marca("regen", "bandido_1", "magia.teste", "bencao", 3, {"cura_inicio_turno": "2d8"})
	c._begin_turn("bandido_1")
	check(inimigo.pv > 1, "marca de cura recupera PV (pv %d)" % inimigo.pv)
	inimigo.pv = 50
	sim.add_marca("sombra", "bandido_1", "magia.teste", "maldicao", 3, {"dano_inicio_turno": "1d4", "conjurador": "player"})
	c._begin_turn("bandido_1")
	check(inimigo.pv < 50, "marca de dano tira PV (pv %d)" % inimigo.pv)


func test_marca_que_expirou_nao_age() -> void:
	var r := _cena()
	var c: CombatModule = r[1]
	var sim: CombatSim = r[2]
	var inimigo: CharacterSheet = sim.c("bandido_1").sheet
	inimigo.pv = 50
	sim.add_marca("sombra2", "bandido_1", "magia.teste", "maldicao", 1, {"dano_inicio_turno": "1d4", "conjurador": "player"})
	sim._passar_rodada()
	c._begin_turn("bandido_1")
	eq(inimigo.pv, 50, "expirada, a marca não causa mais dano")


# --- Coluna de Chamas e Sopro da Salvação (3º círculo, ambos com área) --------------------
func _cena_grupo(nivel: int) -> Array:
	var r := RuleRegistry.load_default()
	var sh := CharacterBuilder.build(r, "humano", "clerigo", CharacterBuilder.presets("clerigo")[0], ["for", "des", "con"], "clerigo")
	sh.level = nivel
	sh.spells = PackedStringArray(["coluna_de_chamas", "sopro_da_salvacao", "circulo_da_restauracao", "poeira_da_podridao", "invulnerabilidade", "premonicao", "colera_de_azgher"])
	sh.equipment["armor"] = ""
	var w := WorldHelpers.world(5)
	w.player_sheet = sh
	WorldHelpers.put(w, 25, 57)
	w.modules.combat._start(["bandido_1", "bandido_2"], true, false)
	var c: CombatModule = w.modules.combat
	var sim: CombatSim = c.sim
	sim.c("player").tile = Vector2i(26, 57)
	sim.c("bandido_1").tile = Vector2i(27, 57)
	sim.c("bandido_2").tile = Vector2i(32, 57)
	sim.walk_fn = func(_t: Vector2i) -> bool: return true
	for id in ["player", "bandido_1", "bandido_2"]:
		var s: CharacterSheet = sim.c(id).sheet
		s.pv_max = 999
		s.pv = 999
	sim.c("player").sheet.pm = 99
	return [w, c, sim, r]


func test_coluna_so_exige_circulo_3_e_clerigo_de_nivel_5() -> void:
	var baixo := _cena_grupo(4)
	var v_baixo := GhostPlanner.validate_action(baixo[2], "player", {"type": "cast", "spell": "coluna_de_chamas", "target": "bandido_1", "targets": ["bandido_1"]})
	check(not v_baixo.ok, "clérigo de nível 4 não lança magia de 3º círculo")
	var alto := _cena_grupo(9)
	var v_alto := GhostPlanner.validate_action(alto[2], "player", {"type": "cast", "spell": "coluna_de_chamas", "target": "bandido_1", "targets": ["bandido_1"]})
	check(v_alto.ok, "clérigo de nível 9 lança a Coluna de Chamas")


func test_coluna_aprimoramentos_custam_1_pm_cada() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	var base := GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "coluna_de_chamas", "target": "bandido_1", "targets": ["bandido_1"]})
	var com := GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "coluna_de_chamas", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [0, 1]})
	check(base.ok and com.ok, "coluna com e sem aprimoramentos é válida")
	eq(com.cost, base.cost + 2, "dois aprimoramentos somam 2 PM")


func test_coluna_atinge_quem_esta_no_raio_e_poupa_quem_esta_fora() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "coluna_de_chamas", "target": "bandido_1", "targets": ["bandido_1"]}
	var v := GhostPlanner.validate_action(sim, "player", a)
	c._cast("player", a, v)
	check(sim.c("bandido_1").sheet.pv < 999, "alvo no centro leva dano")
	check(sim.c("player").sheet.pv < 999, "conjurador na área também leva dano (livro: criaturas livres na área)")
	eq(sim.c("bandido_2").sheet.pv, 999, "criatura a 5 quadrados, fora do raio de 3m, fica intocada")


func test_coluna_emite_um_resultado_de_salvamento_por_alvo() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "coluna_de_chamas", "target": "bandido_1", "targets": ["bandido_1"]}
	var fx: Array = c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	var alvos: Array = []
	for f in fx:
		if f.type == "ATTACK_RESOLVED" and f.payload.get("weapon", "") == "Coluna de Chamas":
			alvos.append(f.payload.target)
			check(f.payload.has("saved") and f.payload.save == "reflexos", "resultado informa o teste de Reflexos")
	check(alvos.has("bandido_1") and alvos.has("player"), "um resultado por criatura atingida")
	check(not alvos.has("bandido_2"), "criatura fora da área não aparece no resultado")


func test_sopro_so_custa_pm_pelos_aprimoramentos_escolhidos() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	var base := GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "sopro_da_salvacao", "target": "bandido_2", "targets": ["bandido_2"]})
	var tudo := GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "sopro_da_salvacao", "target": "bandido_2", "targets": ["bandido_2"], "aprimoramentos": [0, 1, 2]})
	check(base.ok and tudo.ok, "sopro com e sem aprimoramentos é válido")
	eq(tudo.cost, base.cost + 2 + 4 + 4, "aprimoramentos custam 2, 4 e 4 PM")


func test_sopro_cura_aliados_no_cone_e_nao_curas_inimigos_nem_o_conjurador() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_2").tile = Vector2i(30, 57)          # dentro do cone de 9m
	sim.c("bandido_2")["side"] = "player"                # vira aliado
	sim.c("bandido_2").sheet.pv = 10
	sim.c("bandido_1").sheet.pv = 10                     # inimigo no mesmo cone: não é curado
	sim.c("player").sheet.pv = 500
	var a := {"type": "cast", "spell": "sopro_da_salvacao", "target": "bandido_2", "targets": ["bandido_2"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(sim.c("bandido_2").sheet.pv >= 16, "aliado no cone recebe no mínimo 2d8+4 (6 PV) sobre 10")
	eq(sim.c("bandido_1").sheet.pv, 10, "inimigo na área não é curado")
	eq(sim.c("player").sheet.pv, 500, "o conjurador não é curado pelo próprio sopro")


func test_sopro_remove_so_a_condicao_escolhida_sem_aprimoramento() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_2").tile = Vector2i(30, 57)
	sim.c("bandido_2")["side"] = "player"
	var ts: CharacterSheet = sim.c("bandido_2").sheet
	ts.conditions.append("cego")
	ts.conditions.append("confuso")
	var a := {"type": "cast", "spell": "sopro_da_salvacao", "target": "bandido_2", "targets": ["bandido_2"], "condicao": "cego"}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(not ts.conditions.has("cego"), "a condição escolhida (cego) é removida")
	check(ts.conditions.has("confuso"), "sem aprimoramento, as outras condições permanecem")


func test_sopro_com_aprimoramento_3_remove_todas_as_condicoes() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_2").tile = Vector2i(30, 57)
	sim.c("bandido_2")["side"] = "player"
	var ts: CharacterSheet = sim.c("bandido_2").sheet
	ts.conditions.append("cego")
	ts.conditions.append("confuso")
	ts.conditions.append("lento")
	var a := {"type": "cast", "spell": "sopro_da_salvacao", "target": "bandido_2", "targets": ["bandido_2"], "aprimoramentos": [2]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(not ts.conditions.has("cego") and not ts.conditions.has("confuso") and not ts.conditions.has("lento"), "todas as condições listadas são removidas")
	check(ts.conditions.has("surpreendido"), "condição fora da lista (surpreendido, do início do combate) permanece")


func test_sopro_com_aprimoramento_2_leva_pv_negativos_a_zero_antes_da_cura() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_2").tile = Vector2i(30, 57)
	sim.c("bandido_2")["side"] = "player"
	sim.c("bandido_2").sheet.pv = -5
	var a := {"type": "cast", "spell": "sopro_da_salvacao", "target": "bandido_2", "targets": ["bandido_2"], "aprimoramentos": [1]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(sim.c("bandido_2").sheet.pv >= 6, "PV negativos vão a 0 e só então recebem a cura (mínimo 6)")


# --- Círculo da Restauração (4º círculo) ---------------------------------------------------
func test_circulo_da_restauracao_exige_circulo_4_e_nivel_13() -> void:
	var m12 := _cena_grupo(12)
	check(not GhostPlanner.validate_action(m12[2], "player", {"type": "cast", "spell": "circulo_da_restauracao", "target": "bandido_1", "targets": ["bandido_1"]}).ok, "clérigo de nível 12 não lança magia de 4º círculo")
	var m13 := _cena_grupo(13)
	check(GhostPlanner.validate_action(m13[2], "player", {"type": "cast", "spell": "circulo_da_restauracao", "target": "bandido_1", "targets": ["bandido_1"]}).ok, "clérigo de nível 13 lança o Círculo da Restauração")


func test_circulo_da_restauracao_cria_esfera_de_3m_por_5_rodadas() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "circulo_da_restauracao", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	eq(sim.zonas.size(), 1, "uma zona criada")
	eq(sim.zonas[0].rodadas, 5, "dura 5 rodadas")
	eq((sim.zonas[0].tiles as Array).size(), Area.esfera(Vector2i(27, 57), Area.quadrados(3.0)).size(), "área é a esfera de 3m em volta do alvo")


func test_circulo_da_restauracao_cura_e_da_1_pm_no_fim_do_turno_de_quem_esta_dentro() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "circulo_da_restauracao", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	var ts: CharacterSheet = sim.c("bandido_1").sheet
	ts.pv = 10
	ts.pm_max = 99
	ts.pm = 0
	var facts: Array = []
	c._zonas_fim_de_turno("bandido_1", facts)
	check(ts.pv >= 16, "criatura dentro recupera no mínimo 3d8+3 (6 PV)")
	eq(ts.pm, 1, "recebe 1 PM")
	sim.c("player").tile = Vector2i(10, 57)   # fora da esfera (raio 2 em volta de 27,57)
	var fora: CharacterSheet = sim.c("player").sheet
	fora.pv = 10
	c._zonas_fim_de_turno("player", facts)
	eq(fora.pv, 10, "criatura fora da esfera não é curada")


func test_circulo_da_restauracao_limita_pm_a_5_por_dia() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "circulo_da_restauracao", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	var ts: CharacterSheet = sim.c("bandido_1").sheet
	ts.pm_max = 99
	ts.pm = 0
	var facts: Array = []
	for i in 7:
		c._zonas_fim_de_turno("bandido_1", facts)
	eq(ts.pm, 5, "máximo de 5 PM por dia com a magia")


func test_circulo_da_restauracao_faz_mortos_vivos_perderem_pv_e_pm_na_mesma_quantidade() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "circulo_da_restauracao", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	var ts: CharacterSheet = sim.c("bandido_1").sheet
	ts.creature_type = "morto-vivo"
	ts.pm_max = 99
	ts.pm = 99
	var pv_antes := ts.pv
	c._zonas_fim_de_turno("bandido_1", [])
	eq(pv_antes - ts.pv, 99 - ts.pm, "mortos-vivos perdem a mesma quantidade de PV e de PM")
	check(ts.pv < pv_antes, "perdem PV")


# --- Poeira da Podridão (3º círculo) ---------------------------------------------------------
func test_poeira_da_podridao_cria_nuvem_de_6m_pela_cena() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "poeira_da_podridao", "target": "bandido_1", "targets": ["bandido_1"]}
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(v.ok, "poeira é válida contra bandido_1 (alcance médio)")
	c._cast("player", a, v)
	eq(sim.zonas.size(), 1, "uma nuvem criada")
	eq(sim.zonas[0].rodadas, -1, "dura a cena (sem contagem de rodadas)")
	eq((sim.zonas[0].tiles as Array).size(), Area.esfera(Vector2i(27, 57), Area.quadrados(6.0)).size(), "área é a nuvem de 6m de raio")


func test_poeira_da_podridao_fere_quem_esta_na_nuvem_e_nao_quem_esta_fora() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_2").tile = Vector2i(40, 57)          # fora dos 6m
	var a := {"type": "cast", "spell": "poeira_da_podridao", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(sim.c("bandido_1").sheet.pv < 999, "criatura na nuvem sofre dano")
	eq(sim.c("bandido_2").sheet.pv, 999, "criatura fora da nuvem fica intocada")


func test_poeira_da_podridao_falha_no_teste_bloqueia_a_cura_por_uma_rodada() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var ts: CharacterSheet = sim.c("bandido_1").sheet
	ts.add_efeito("teste_fraco", "resistencia", -50, "cena")   # Fortitude sempre falha
	var a := {"type": "cast", "spell": "poeira_da_podridao", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(ts.efeito_bonus("bloqueio_cura") > 0, "quem falhou fica com bloqueio de cura")
	eq(ts.curar(10), 0, "sem recuperar PV enquanto o bloqueio dura")
	c._begin_turn("bandido_1")
	eq(ts.efeito_bonus("bloqueio_cura"), 0, "o bloqueio acaba no início do próprio turno")


func test_poeira_da_podridao_atinge_de_novo_no_inicio_do_turno_do_conjurador() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "poeira_da_podridao", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	var antes: int = sim.c("bandido_1").sheet.pv
	c._nuvens_do_conjurador("player", [])
	check(sim.c("bandido_1").sheet.pv < antes, "dano de novo no início do turno do conjurador")


func test_poeira_da_podridao_aprimoramento_custa_2_pm() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	var base := GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "poeira_da_podridao", "target": "bandido_1", "targets": ["bandido_1"]})
	var com := GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "poeira_da_podridao", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [0]})
	eq(com.cost, base.cost + 2, "+1d8+4 de dano custa 2 PM")


func test_curar_respeita_o_limite_da_ficha_e_devolve_o_que_foi_recuperado() -> void:
	var m := _cena_grupo(9)
	var ts: CharacterSheet = m[2].c("bandido_1").sheet
	ts.pv_max = 20
	ts.pv = 15
	eq(ts.curar(10), 5, "cura até o máximo e devolve só o que foi recuperado")
	eq(ts.pv, 20, "não passa do máximo")


# --- Invulnerabilidade (5º círculo) ---------------------------------------------------------
func test_invulnerabilidade_exige_circulo_5_e_nivel_17() -> void:
	var m16 := _cena_grupo(16)
	check(not GhostPlanner.validate_action(m16[2], "player", {"type": "cast", "spell": "invulnerabilidade"}).ok, "clérigo de nível 16 não lança magia de 5º círculo")
	var m17 := _cena_grupo(17)
	check(GhostPlanner.validate_action(m17[2], "player", {"type": "cast", "spell": "invulnerabilidade"}).ok, "clérigo de nível 17 lança a Invulnerabilidade")


func test_invulnerabilidade_mental_bloqueia_so_condicoes_mentais() -> void:
	var m := _cena_grupo(17)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var r: RuleRegistry = m[3]
	var ts: CharacterSheet = sim.c("player").sheet
	c._cast("player", {"type": "cast", "spell": "invulnerabilidade", "modo": "mental"}, {"ok": true, "cost": 0})
	ts.add_condition("fascinado", r)
	check(not ts.conditions.has("fascinado"), "bloqueia condição mental (fascinado)")
	ts.add_condition("cego", r)
	check(ts.conditions.has("cego"), "a proteção mental não bloqueia condição física (cego)")
	eq(ts.efeito_bonus("imune", "critico"), 0, "a proteção mental não dá imunidade a acertos críticos")


func test_invulnerabilidade_fisica_bloqueia_condicoes_doencas_criticos_e_furtivos() -> void:
	var m := _cena_grupo(17)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var r: RuleRegistry = m[3]
	var ts: CharacterSheet = sim.c("player").sheet
	c._cast("player", {"type": "cast", "spell": "invulnerabilidade", "modo": "fisica"}, {"ok": true, "cost": 0})
	ts.add_condition("envenenado", r)
	check(not ts.conditions.has("envenenado"), "bloqueia condição física (envenenado)")
	ts.add_condition("doente", r)
	check(not ts.conditions.has("doente"), "bloqueia doenças (condição doente)")
	ts.add_condition("confuso", r)
	check(ts.conditions.has("confuso"), "a proteção física não bloqueia condição mental (confuso)")
	check(ts.efeito_bonus("imune", "critico") > 0, "imune a acertos críticos")
	check(ts.efeito_bonus("imune", "furtivo") > 0, "imune a ataques furtivos")


func test_invulnerabilidade_aprimoramento_aceita_outro_alvo_a_curto_alcance() -> void:
	var m := _cena_grupo(17)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").tile = Vector2i(27, 57)
	sim.c("bandido_2").tile = Vector2i(40, 57)   # 14 quadrados: fora do curto (6)
	check(GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "invulnerabilidade", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [0]}).ok, "com o aprimoramento, a magia vai para outra criatura a curto alcance")
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "invulnerabilidade", "target": "bandido_2", "targets": ["bandido_2"], "aprimoramentos": [0]}).ok, "fora do alcance curto, é recusada")


# --- Premonição (4º círculo) ----------------------------------------------------------------
func test_premonicao_exige_circulo_4_e_nivel_13() -> void:
	check(not GhostPlanner.validate_action(_cena_grupo(12)[2], "player", {"type": "cast", "spell": "premonicao"}).ok, "clérigo de nível 12 não lança magia de 4º círculo")
	check(GhostPlanner.validate_action(_cena_grupo(13)[2], "player", {"type": "cast", "spell": "premonicao"}).ok, "clérigo de nível 13 lança a Premonição")


func test_premonicao_reacao_nao_pode_ser_lancada_como_acao() -> void:
	var sim: CombatSim = _cena_grupo(13)[2]
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "premonicao", "aprimoramentos": [0]}).ok, "o aprimoramento de reação não é lançado no próprio turno")


func test_premonicao_rola_de_novo_um_teste_que_falhou_uma_vez_por_rodada() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var r: RuleRegistry = m[3]
	var ts: CharacterSheet = sim.c("player").sheet
	c._cast("player", {"type": "cast", "spell": "premonicao"}, {"ok": true, "cost": 0})
	check(ts.efeito_bonus("premonicao_uso") == 1, "uso disponível na rodada após lançar")
	ts.add_efeito("teste", "resistencia", -50, "cena")   # o teste sempre falha, então a rerrolagem é usada
	Checks.skill(ts, "vontade", 10, r, m[0].rng, "combat")
	eq(ts.efeito_bonus("premonicao_uso"), 0, "o primeiro teste que falhou gasta o uso")
	Checks.skill(ts, "vontade", 10, r, m[0].rng, "combat")
	eq(ts.efeito_bonus("premonicao_uso"), 0, "o segundo teste da rodada não rola de novo")
	c._begin_turn("player")
	eq(ts.efeito_bonus("premonicao_uso"), 1, "o uso volta no próximo turno do conjurador")


func test_premonicao_aliado_que_falhou_e_rerolado_pela_reacao() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_2").tile = Vector2i(28, 57)
	sim.c("bandido_2")["side"] = "player"
	var pm_antes: int = sim.c("player").sheet.pm
	var sv := {"success": false, "total": 3, "cd": 15, "mod": 0, "skill": "fortitude"}
	var nova: Dictionary = c._pos_teste("bandido_2", sv, 15, [])
	check(sim.c("player").sheet.pm < pm_antes, "a reação custa PM")
	check(nova.has("d20"), "aliado que falhou tem uma nova rolagem aceita")


func test_premonicao_inimigo_que_passou_pode_ser_empurrado_se_nao_negar() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")   # Vontade falha: não nega
	var sv := {"success": true, "total": 20, "cd": 10, "mod": 0, "skill": "fortitude"}
	var nova: Dictionary = c._pos_teste("bandido_1", sv, 10, [])
	check(nova.has("d20"), "inimigo que passou é rerolado quando não nega a magia")


func test_premonicao_inimigo_que_nega_com_vontade_nao_e_rerolado() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", 99, "cena")   # Vontade passa: nega
	var sv := {"success": true, "total": 20, "cd": 10, "mod": 0, "skill": "fortitude"}
	var nova: Dictionary = c._pos_teste("bandido_1", sv, 10, [])
	check(not nova.has("d20"), "inimigo que nega com Vontade mantém o resultado original")


func test_premonicao_politica_nunca_desliga_a_reacao() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	c.power_policy["premonicao_reacao"] = "nunca"
	sim.c("bandido_2").tile = Vector2i(28, 57)
	sim.c("bandido_2")["side"] = "player"
	var pm_antes: int = sim.c("player").sheet.pm
	c._pos_teste("bandido_2", {"success": false, "total": 3, "cd": 15, "mod": 0, "skill": "fortitude"}, 15, [])
	eq(sim.c("player").sheet.pm, pm_antes, "com a política em nunca, nada é gasto")


# --- Cólera de Azgher (4º círculo) ---------------------------------------------------------
func test_colera_exige_circulo_4_e_dissipacao_exige_nivel_17() -> void:
	check(not GhostPlanner.validate_action(_cena_grupo(12)[2], "player", {"type": "cast", "spell": "colera_de_azgher", "target": "bandido_1", "targets": ["bandido_1"]}).ok, "nível 12 não lança magia de 4º círculo")
	var m13 := _cena_grupo(13)
	check(GhostPlanner.validate_action(m13[2], "player", {"type": "cast", "spell": "colera_de_azgher", "target": "bandido_1", "targets": ["bandido_1"]}).ok, "nível 13 lança a Cólera")
	check(not GhostPlanner.validate_action(m13[2], "player", {"type": "cast", "spell": "colera_de_azgher", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [2]}).ok, "a dissipação exige 5º círculo")
	check(GhostPlanner.validate_action(_cena_grupo(17)[2], "player", {"type": "cast", "spell": "colera_de_azgher", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [2]}).ok, "nível 17 lança a dissipação")


func test_colera_falha_cega_e_poe_em_chamas() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")   # Reflexos falha
	var a := {"type": "cast", "spell": "colera_de_azgher", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(sim.c("bandido_1").sheet.conditions.has("cego"), "quem falha fica cego")
	check(sim.c("bandido_1").sheet.conditions.has("em_chamas"), "quem falha fica em chamas")
	check(sim.c("bandido_1").sheet.pv < 999, "e sofre dano")


func test_colera_passou_no_teste_nao_fica_cega_nem_em_chamas() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", 99, "cena")   # Reflexos passa
	var a := {"type": "cast", "spell": "colera_de_azgher", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(not sim.c("bandido_1").sheet.conditions.has("cego"), "quem passa não fica cego")
	check(not sim.c("bandido_1").sheet.conditions.has("em_chamas"), "nem em chamas")


func test_colera_aprimoramento_de_area_alcanca_mais_longe() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_2").tile = Vector2i(34, 57)   # a 7 quadrados de bandido_1: fora dos 6m, dentro dos 12m
	var a := {"type": "cast", "spell": "colera_de_azgher", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	eq(sim.c("bandido_2").sheet.pv, 999, "sem o aprimoramento, a área de 6m não alcança")
	var b := {"type": "cast", "spell": "colera_de_azgher", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [1]}
	c._cast("player", b, GhostPlanner.validate_action(sim, "player", b))
	check(sim.c("bandido_2").sheet.pv < 999, "com +6m de raio, alcança a criatura a 7 quadrados")


func test_colera_dissipa_so_a_necromancia_da_area() -> void:
	var m := _cena_grupo(17)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var ts: CharacterSheet = sim.c("bandido_1").sheet
	ts.add_efeito("magia.perdicao", "ataque", -1, "cena")         # Necromancia
	ts.add_efeito("magia.escudo_da_fe", "defesa", 2, "cena")       # Abjuração
	var a := {"type": "cast", "spell": "colera_de_azgher", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [2]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(not ts.has_efeito("magia.perdicao"), "a magia de necromancia da área é dissipada")
	check(ts.has_efeito("magia.escudo_da_fe"), "magia de outra escola permanece")
