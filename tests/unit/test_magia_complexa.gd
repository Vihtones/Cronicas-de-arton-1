extends TestCase
## Sistemas para magias complexas (docs/MAGIA_COMPLEXA.md): áreas, zonas, marcas, invocações e PV temporários.
const Area := preload("res://src/domain/combat/area.gd")
const Atitudes := preload("res://src/domain/rules/atitudes.gd")
const SpellRules := preload("res://src/domain/combat/spell_rules.gd")


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
	sh.spells = PackedStringArray(["coluna_de_chamas", "sopro_da_salvacao", "circulo_da_restauracao", "poeira_da_podridao", "invulnerabilidade", "premonicao", "colera_de_azgher", "ligacao_sombria", "aura_divina", "banimento", "guardiao_divino", "lagrimas_de_wynna", "orientacao", "arma_magica", "nevoa", "bencao", "perdicao", "consagrar", "profanar", "curar_ferimentos", "infligir_ferimentos", "despedacar", "arma_espiritual", "manto_do_cruzado", "armamento_da_natureza", "caminhos_da_natureza", "controlar_plantas", "santuario", "comando", "acalmar_animal", "tranquilidade", "suporte_ambiental", "detectar_ameacas", "abencoar_alimentos", "criar_elementos", "luz", "escuridao", "aviso", "compreensao", "visao_mistica"])
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


# --- Ligação Sombria (4º círculo) -----------------------------------------------------------
func test_ligacao_sombria_exige_circulo_4() -> void:
	check(not GhostPlanner.validate_action(_cena_grupo(12)[2], "player", {"type": "cast", "spell": "ligacao_sombria", "target": "bandido_1", "targets": ["bandido_1"]}).ok, "nível 12 não lança magia de 4º círculo")
	check(GhostPlanner.validate_action(_cena_grupo(13)[2], "player", {"type": "cast", "spell": "ligacao_sombria", "target": "bandido_1", "targets": ["bandido_1"]}).ok, "nível 13 lança a Ligação Sombria")


func test_ligacao_sombria_criatura_que_passa_na_fortitude_nao_fica_ligada() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", 99, "cena")
	var a := {"type": "cast", "spell": "ligacao_sombria", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(not sim.c("player").sheet.has_efeito("magia.ligacao_sombria"), "quem passa na Fortitude não fica ligado")


func _ligar(m: Array) -> void:
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")   # falha na Fortitude, para a ligação
	var a := {"type": "cast", "spell": "ligacao_sombria", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))


func test_ligacao_sombria_repassa_o_dano_quando_o_alvo_falha() -> void:
	var m := _cena_grupo(13)
	_ligar(m)
	var sim: CombatSim = m[2]
	check(sim.c("player").sheet.has_efeito("magia.ligacao_sombria"), "a ligação foi criada")
	sim.apply_damage("player", 10)
	eq(sim.c("player").sheet.pv, 989, "o conjurador sofre o dano")
	eq(sim.c("bandido_1").sheet.pv, 989, "o alvo sofre o mesmo dano quando falha na Fortitude")


func test_ligacao_sombria_nao_repassa_o_dano_quando_o_alvo_passa() -> void:
	var m := _cena_grupo(13)
	_ligar(m)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", 99, "cena")
	sim.apply_damage("player", 10)
	eq(sim.c("bandido_1").sheet.pv, 999, "quem passa na Fortitude não sofre o dano")
	eq(sim.pendencias[0].passou, true, "a passagem fica registrada")


func test_ligacao_sombria_termina_quando_o_alvo_cai_a_0_pv() -> void:
	var m := _cena_grupo(13)
	_ligar(m)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.pv = 5
	sim.apply_damage("player", 10)
	check(not sim.c("player").sheet.has_efeito("magia.ligacao_sombria"), "a ligação acaba quando o alvo cai")


func test_ligacao_sombria_com_aprimoramento_nao_acaba_a_0_pv() -> void:
	var m := _cena_grupo(17)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")
	var a := {"type": "cast", "spell": "ligacao_sombria", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [0]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	sim.c("bandido_1").sheet.pv = 5
	sim.apply_damage("player", 10)
	check(sim.c("player").sheet.has_efeito("magia.ligacao_sombria"), "com o aprimoramento, a ligação continua mesmo com o alvo a 0 PV")


func test_ligacao_sombria_repassa_condicoes_quando_o_alvo_falha() -> void:
	var m := _cena_grupo(13)
	_ligar(m)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("player").sheet.add_condition("cego", m[3])
	c._propagar_ligacoes()
	check(sim.c("bandido_1").sheet.conditions.has("cego"), "o alvo recebe a condição do conjurador quando falha")


# --- Aura Divina (5º círculo) ----------------------------------------------------------------
func _conjurar_aura(m: Array, cond: String = "debilitado") -> void:
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "aura_divina", "target": "player", "targets": ["player"], "condicao": cond}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))


func test_aura_divina_exige_circulo_5() -> void:
	check(not GhostPlanner.validate_action(_cena_grupo(16)[2], "player", {"type": "cast", "spell": "aura_divina", "target": "player", "targets": ["player"]}).ok, "nível 16 não lança magia de 5º círculo")
	check(GhostPlanner.validate_action(_cena_grupo(17)[2], "player", {"type": "cast", "spell": "aura_divina", "target": "player", "targets": ["player"]}).ok, "nível 17 lança a Aura Divina")


func test_aura_divina_da_ao_conjurador_bonus_de_10_e_imunidade_a_encantamento() -> void:
	var m := _cena_grupo(17)
	var sim: CombatSim = m[2]
	_conjurar_aura(m)
	var sh: CharacterSheet = sim.c("player").sheet
	eq(sh.efeito_bonus("defesa"), 10, "o conjurador ganha +10 na Defesa")
	eq(sh.efeito_bonus("resistencia"), 10, "o conjurador ganha +10 em resistências")
	eq(sh.efeito_bonus("imune", "fascinado"), 1, "o conjurador é imune a fascinado")


func test_aura_divina_aliado_devoto_ganha_10_e_nao_devoto_ganha_5() -> void:
	var m := _cena_grupo(17)
	var sim: CombatSim = m[2]
	var c: CombatModule = m[1]
	sim.c("player").sheet.devotion = "Khalmyr"
	sim.c("bandido_1").side = "player"   # aliado dentro da esfera (27,57)
	sim.c("bandido_1").sheet.devotion = "Khalmyr"
	_conjurar_aura(m)
	c._refresh_bencaos()
	eq(sim.c("bandido_1").sheet.efeito_bonus("defesa"), 10, "aliado devoto da mesma divindade ganha +10")
	sim.c("bandido_1").sheet.devotion = "Lena"
	c._refresh_bencaos()
	eq(sim.c("bandido_1").sheet.efeito_bonus("defesa"), 5, "aliado de outra divindade ganha +5")
	eq(sim.c("bandido_1").sheet.efeito_bonus("imune", "fascinado"), 0, "não devoto não ganha imunidade")


func test_aura_divina_com_aprimoramento_soma_1_nos_bonus() -> void:
	var m := _cena_grupo(17)
	var sim: CombatSim = m[2]
	var c: CombatModule = m[1]
	var a := {"type": "cast", "spell": "aura_divina", "target": "player", "targets": ["player"], "condicao": "lento", "aprimoramentos": [0]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	eq(sim.c("player").sheet.efeito_bonus("defesa"), 11, "com o aprimoramento, o bônus de Defesa é +11")


func test_aura_divina_inimigo_que_entra_e_falha_recebe_a_condicao() -> void:
	var m := _cena_grupo(17)
	var sim: CombatSim = m[2]
	var c: CombatModule = m[1]
	_conjurar_aura(m, "debilitado")
	sim.c("bandido_1").tile = Vector2i(34, 57)   # fora da esfera (distância 8)
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")
	c._aura_divina_entrada("bandido_1", Vector2i(34, 57), [Vector2i(33, 57), Vector2i(32, 57)])
	check(sim.c("bandido_1").sheet.conditions.has("debilitado"), "quem entra e falha na Vontade fica debilitado")


func test_aura_divina_inimigo_que_entra_e_passa_nao_recebe_nada() -> void:
	var m := _cena_grupo(17)
	var sim: CombatSim = m[2]
	var c: CombatModule = m[1]
	_conjurar_aura(m, "debilitado")
	sim.c("bandido_1").tile = Vector2i(34, 57)
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", 99, "cena")
	c._aura_divina_entrada("bandido_1", Vector2i(34, 57), [Vector2i(33, 57), Vector2i(32, 57)])
	check(not sim.c("bandido_1").sheet.conditions.has("debilitado"), "quem passa na Vontade não recebe a condição")


func test_aura_divina_nao_dispara_para_quem_ja_comeca_dentro() -> void:
	var m := _cena_grupo(17)
	var sim: CombatSim = m[2]
	var c: CombatModule = m[1]
	_conjurar_aura(m, "debilitado")
	sim.c("bandido_2").sheet.add_efeito("teste", "resistencia", -50, "cena")
	var out: Array = c._aura_divina_entrada("bandido_2", Vector2i(32, 57), [Vector2i(31, 57)])
	eq(out.size(), 0, "quem já está dentro da esfera não faz o teste ao se mover lá dentro")
	check(not sim.c("bandido_2").sheet.conditions.has("debilitado"), "sem entrada, sem condição")


func test_aura_divina_acaba_quando_o_conjurador_cai() -> void:
	var m := _cena_grupo(17)
	var sim: CombatSim = m[2]
	var c: CombatModule = m[1]
	sim.c("player").sheet.devotion = "Khalmyr"
	sim.c("bandido_1").side = "player"
	sim.c("bandido_1").sheet.devotion = "Khalmyr"
	_conjurar_aura(m)
	c._refresh_bencaos()
	eq(sim.c("bandido_1").sheet.efeito_bonus("defesa"), 10, "com o conjurador de pé, o aliado recebe o bônus")
	sim.c("player").sheet.pv = 0
	c._refresh_bencaos()
	eq(sim.c("bandido_1").sheet.efeito_bonus("defesa"), 0, "com o conjurador caído, o bônus some")


# --- Banimento (3º círculo, execução de 1d3+1 rodadas) ---------------------------------------
func _banir(m: Array, alvo: String, apr: Array = []) -> void:
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "banimento", "target": alvo, "targets": [alvo], "aprimoramentos": apr}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	sim.conjurando["player"].rodadas = 0   # a execução termina: a magia fica pronta para o próximo turno do conjurador
	c._begin_turn_base("player")


func test_banimento_exige_circulo_3() -> void:
	check(not GhostPlanner.validate_action(_cena_grupo(8)[2], "player", {"type": "cast", "spell": "banimento", "target": "bandido_1", "targets": ["bandido_1"]}).ok, "nível 8 não lança magia de 3º círculo")
	check(GhostPlanner.validate_action(_cena_grupo(9)[2], "player", {"type": "cast", "spell": "banimento", "target": "bandido_1", "targets": ["bandido_1"]}).ok, "nível 9 lança o Banimento")


func test_banimento_espirito_que_falha_e_banido_da_cena() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.creature_type = "espirito"
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")
	_banir(m, "bandido_1")
	check(sim.c("bandido_1").flags.has("fora") and not sim.conscious("bandido_1"), "espírito que falha na Vontade sai da cena")


func test_banimento_morto_vivo_que_falha_cai_a_0_pv() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.creature_type = "morto-vivo"
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")
	_banir(m, "bandido_1")
	eq(sim.c("bandido_1").sheet.pv, 0, "morto-vivo que falha é reduzido a 0 PV")


func test_banimento_nativo_de_arton_nao_e_afetado() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.creature_type = "humanoide"
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")
	_banir(m, "bandido_1")
	check(sim.combatants.has("bandido_1"), "nativo de Arton continua na cena")
	check(not sim.c("bandido_1").sheet.conditions.has("enjoado"), "nativo não recebe o enjoo do Banimento")


func test_banimento_quem_passa_na_vontade_fica_enjoado() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.creature_type = "espirito"
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", 99, "cena")
	_banir(m, "bandido_1")
	check(sim.combatants.has("bandido_1"), "quem passa não é banido")
	check(sim.c("bandido_1").sheet.conditions.has("enjoado"), "quem passa fica enjoado")


func test_banimento_ser_ferido_enquanto_conjura_quebra_a_magia() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.creature_type = "espirito"
	sim.c("player").sheet.add_efeito("teste", "resistencia", -50, "cena")   # falha na concentração (CD = dano)
	var a := {"type": "cast", "spell": "banimento", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	sim.apply_damage("player", 10)
	check(not sim.conjurando.has("player"), "ferido na execução e sem concentração, a magia é perdida")
	var facts: Array = c._propagar_ligacoes()
	var falhou := false
	for f in facts:
		if f.type == "SPELL_FAILED" and str(f.payload.get("reason", "")) == "ferido_na_execucao":
			falhou = true
	check(falhou, "a perda da magia por dano é registrada")


func test_banimento_ser_ferido_com_concentracao_mantem_a_magia() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("player").sheet.add_efeito("teste", "resistencia", 99, "cena")
	var a := {"type": "cast", "spell": "banimento", "target": "bandido_1", "targets": ["bandido_1"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	sim.apply_damage("player", 10)
	check(sim.conjurando.has("player"), "com concentração, a magia continua")


func test_banimento_ocupa_a_acao_padrao_enquanto_conjura() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.conjurando["player"] = {"alvo": "bandido_1", "cd": 15, "apr": false, "rodadas": 2}
	sim.budget = {"std": 1, "move": 1}
	c._begin_turn_base("player")
	eq(sim.budget["std"], 0, "enquanto conjura, a ação padrão do turno vai para a magia")


func test_banimento_com_aprimoramento_devolve_criatura_conjurada() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var inv: String = c.invocar("player", "criatura.bandido_comum", 5, "teste")
	_banir(m, inv, [0])
	check(not sim.combatants.has(inv), "a criatura conjurada volta ao plano")


func test_banimento_aprimoramento_so_aceita_criatura_conjurada() -> void:
	var m := _cena_grupo(9)
	var a := {"type": "cast", "spell": "banimento", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [0]}
	check(not GhostPlanner.validate_action(m[2], "player", a).ok, "o aprimoramento não vale contra criatura que não foi conjurada")


func test_banimento_itens_opostos_somam_2_na_cd() -> void:
	var m := _cena_grupo(9)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var sh: CharacterSheet = sim.c("player").sheet
	var base: int = c.spell_dc(sh, {})
	var a := {"type": "cast", "spell": "banimento", "target": "bandido_1", "targets": ["bandido_1"], "itens_opostos": 2}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	eq(sim.conjurando["player"].cd, base + 4, "cada item que se opõe soma +2 na CD")


# --- Guardião Divino (4º círculo): elemental de luz com ação própria -------------------------
func _invocar_guardiao(m: Array) -> String:
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "guardiao_divino", "target": "player", "targets": ["player"]}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	for id in sim.combatants:
		if sim.c(id).flags.has("guardiao"):
			return id
	return ""


func test_guardiao_divino_exige_circulo_4() -> void:
	check(not GhostPlanner.validate_action(_cena_grupo(12)[2], "player", {"type": "cast", "spell": "guardiao_divino", "target": "player", "targets": ["player"]}).ok, "nível 12 não lança magia de 4º círculo")
	check(GhostPlanner.validate_action(_cena_grupo(13)[2], "player", {"type": "cast", "spell": "guardiao_divino", "target": "player", "targets": ["player"]}).ok, "nível 13 lança o Guardião Divino")


func test_guardiao_divino_invoca_elemental_com_100_de_luz_e_incorporeo() -> void:
	var m := _cena_grupo(13)
	var sim: CombatSim = m[2]
	var gid := _invocar_guardiao(m)
	check(gid != "", "o elemental entra na cena")
	eq(sim.c(gid).sheet.efeito_bonus("luz"), 100, "o elemental começa com 100 pontos de luz")
	check(sim.c(gid).flags.has("incorporeo"), "o elemental é incorpóreo")


func test_guardiao_divino_e_imune_a_dano() -> void:
	var m := _cena_grupo(13)
	var sim: CombatSim = m[2]
	var gid := _invocar_guardiao(m)
	var pv_antes: int = sim.c(gid).sheet.pv
	sim.apply_damage(gid, 50)
	eq(sim.c(gid).sheet.pv, pv_antes, "dano não afeta o elemental incorpóreo")


func test_guardiao_divino_cura_o_aliado_mais_ferido_gastando_luz() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var gid := _invocar_guardiao(m)
	sim.c("player").sheet.pv = 900   # faltam 99 PV (pv_max 999)
	c._turno_guardiao(gid)
	eq(sim.c("player").sheet.pv, 999, "o elemental cura 1 PV por ponto de luz")
	eq(sim.c(gid).sheet.efeito_bonus("luz"), 1, "a luz gasta é descontada: restam 1 ponto")


func test_guardiao_divino_remove_condicao_por_3_pontos() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var gid := _invocar_guardiao(m)
	sim.c("bandido_1").side = "player"   # aliado, sem PV faltando
	sim.c("bandido_1").sheet.add_condition("cego", m[3])
	c._turno_guardiao(gid)
	check(not sim.c("bandido_1").sheet.conditions.has("cego"), "o elemental remove a condição da lista")
	eq(sim.c(gid).sheet.efeito_bonus("luz"), 97, "remover uma condição custa 3 pontos de luz")


func test_guardiao_divino_voa_ate_o_aliado_distante() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var gid := _invocar_guardiao(m)
	sim.c("bandido_1").side = "player"
	sim.c("bandido_1").tile = Vector2i(40, 57)   # bem fora do alcance curto do elemental
	sim.c("bandido_1").sheet.pv = 500
	c._turno_guardiao(gid)
	check(CombatSim.cheb(sim.c(gid).tile, Vector2i(40, 57)) <= 6, "o elemental voa até alcance curto do aliado")
	eq(sim.c("bandido_1").sheet.pv, 600, "o aliado distante recebe 100 PV, o que a luz permite")
	check(sim.c("bandido_1").sheet.pv > 500, "o aliado distante recebe a cura")


func test_guardiao_divino_se_desfaz_sem_luz() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var gid := _invocar_guardiao(m)
	sim.c("player").sheet.pv = 899   # faltam 100: gasta toda a luz
	c._turno_guardiao(gid)
	eq(sim.c(gid).sheet.efeito_bonus("luz"), 0, "a luz zera")
	check(sim.c(gid).flags.has("fora") and not sim.conscious(gid), "sem luz, o elemental sai da cena")


# --- Lágrimas de Wynna (5º círculo): bloqueio de magia arcana e ritual de um dia -----------------
func _lagrimas(m: Array, apr: Array, targets: Array = []) -> void:
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var alvos := targets if not targets.is_empty() else ["bandido_1"]
	var a := {"type": "cast", "spell": "lagrimas_de_wynna", "target": "bandido_1", "targets": alvos, "aprimoramentos": apr}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))


func _ajusta_npc_do_mundo(c: CombatModule, id: String, bonus: int) -> void:
	var d := CharacterSheet.from_dict(c.creature_state[id].sheet)
	d.add_efeito("teste", "resistencia", bonus, "cena")
	c.creature_state[id].sheet = d.to_dict()


func test_lagrimas_de_wynna_exige_circulo_5() -> void:
	check(not GhostPlanner.validate_action(_cena_grupo(16)[2], "player", {"type": "cast", "spell": "lagrimas_de_wynna", "target": "bandido_1", "targets": ["bandido_1"]}).ok, "nível 16 não lança magia de 5º círculo")
	check(GhostPlanner.validate_action(_cena_grupo(17)[2], "player", {"type": "cast", "spell": "lagrimas_de_wynna", "target": "bandido_1", "targets": ["bandido_1"]}).ok, "nível 17 lança Lágrimas de Wynna")


func test_lagrimas_de_wynna_falha_bloqueia_magia_arcana_ate_o_fim_da_cena() -> void:
	var m := _cena_grupo(17)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")
	_lagrimas(m, [])
	var sh: CharacterSheet = sim.c("bandido_1").sheet
	check(sh.efeito_bonus("bloqueio_arcana") > 0, "quem falha perde magias arcanas")
	sh.limpar_efeitos("rodada")
	check(sh.efeito_bonus("bloqueio_arcana") > 0, "a falha dura até o fim da cena, não só uma rodada")


func test_lagrimas_de_wynna_passar_bloqueia_so_uma_rodada() -> void:
	var m := _cena_grupo(17)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", 99, "cena")
	_lagrimas(m, [])
	var sh: CharacterSheet = sim.c("bandido_1").sheet
	check(sh.efeito_bonus("bloqueio_arcana") > 0, "quem passa perde a habilidade por uma rodada")
	sh.limpar_efeitos("rodada")
	eq(sh.efeito_bonus("bloqueio_arcana"), 0, "passada a rodada, volta a lançar")


func test_lagrimas_de_wynna_bloqueio_recusa_magia_arcana_no_conjurador() -> void:
	var m := _cena_grupo(17)
	var sim: CombatSim = m[2]
	sim.c("player").sheet.spells.append("armadura_arcana")
	sim.c("player").sheet.add_efeito("magia.lagrimas_de_wynna", "bloqueio_arcana", 1, "cena")
	var v := GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "armadura_arcana", "target": "player", "targets": ["player"]})
	check(not v.ok and str(v.reason).find("arcanas") >= 0, "com o bloqueio, a magia arcana é recusada")


func test_lagrimas_de_wynna_ritual_de_um_dia_tira_as_arcanas_se_o_alvo_falha() -> void:
	var m := _cena_grupo(17)
	var w: WorldState = m[0]
	var sim: CombatSim = m[2]
	var c: CombatModule = m[1]
	pass
	_lagrimas(m, [1])
	var sh: CharacterSheet = sim.c("player").sheet
	for e in sh.efeitos:
		if e.id == "magia.lagrimas_de_wynna" and e.fim == "ritual":
			e.ate = w.day_index()   # o dia termina
	_ajusta_npc_do_mundo(c, "bandido_1", -50)
	var st: Dictionary = c.creature_state["bandido_1"]
	st.present = true
	st.tile = [int(sim.c("player").tile.x), int(sim.c("player").tile.y)]
	c.world.player.position = w.db.tile_to_world(sim.c("player").tile)
	c.world.player_sheet = sh   # no fim do combate, a ficha da simulação volta para o mundo
	var fatos: Array = c.processar_rituais_do_dia()
	check(CharacterSheet.from_dict(st.sheet).arcana_perdida, "o alvo que falha no fim do ritual perde as magias arcanas")
	check(not sh.efeitos.any(func(e): return e.id == "magia.lagrimas_de_wynna" and e.fim == "ritual"), "o ritual termina")
	check(fatos.size() > 0, "o resultado do ritual é registrado")


func test_lagrimas_de_wynna_ritual_que_o_alvo_passa_nao_tira_nada() -> void:
	var m := _cena_grupo(17)
	var w: WorldState = m[0]
	var sim: CombatSim = m[2]
	var c: CombatModule = m[1]
	pass
	_lagrimas(m, [1])
	for e in sim.c("player").sheet.efeitos:
		if e.id == "magia.lagrimas_de_wynna" and e.fim == "ritual":
			e.ate = w.day_index()
	_ajusta_npc_do_mundo(c, "bandido_1", 99)
	var st: Dictionary = c.creature_state["bandido_1"]
	st.present = true
	st.tile = [int(sim.c("player").tile.x), int(sim.c("player").tile.y)]
	c.world.player.position = w.db.tile_to_world(sim.c("player").tile)
	c.world.player_sheet = sim.c("player").sheet   # no fim do combate, a ficha da simulação volta para o mundo
	c.processar_rituais_do_dia()
	check(not CharacterSheet.from_dict(st.sheet).arcana_perdida, "quem passa no teste resiste")


func test_lagrimas_de_wynna_ritual_se_perde_se_o_alvo_se_afastou() -> void:
	var m := _cena_grupo(17)
	var w: WorldState = m[0]
	var sim: CombatSim = m[2]
	var c: CombatModule = m[1]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")
	_lagrimas(m, [1])
	for e in sim.c("player").sheet.efeitos:
		if e.id == "magia.lagrimas_de_wynna" and e.fim == "ritual":
			e.ate = w.day_index()
	var st: Dictionary = c.creature_state["bandido_1"]
	st.present = false
	c.world.player_sheet = sim.c("player").sheet   # no fim do combate, a ficha da simulação volta para o mundo
	c.processar_rituais_do_dia()
	check(not CharacterSheet.from_dict(st.sheet).arcana_perdida, "sem o alvo no lugar, o ritual se perde sem efeito")


# --- Orientação (1º círculo): vantagem no próximo teste de perícia ------------------------------
func _orientar(m: Array, alvos: Array, apr: Array = [], extra: Dictionary = {}) -> void:
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "orientacao", "target": alvos[0], "targets": alvos, "aprimoramentos": apr}
	for k in extra:
		a[k] = extra[k]
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))


func test_orientacao_da_vantagem_no_proximo_teste_de_pericia() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	_orientar(m, ["bandido_1"])
	check(sim.c("bandido_1").sheet.efeito_bonus("vantagem_pericia") > 0, "o alvo ganha a vantagem")


func test_orientacao_e_gasta_no_proximo_teste_de_pericia() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	_orientar(m, ["bandido_1"])
	var sh: CharacterSheet = sim.c("bandido_1").sheet
	Checks.skill(sh, "percepcao", 5, m[3], sim.rng, "combat")
	eq(sh.efeito_bonus("vantagem_pericia"), 0, "um teste de perícia gasta a vantagem")


func test_orientacao_nao_e_gasta_por_teste_de_resistencia() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	_orientar(m, ["bandido_1"])
	var sh: CharacterSheet = sim.c("bandido_1").sheet
	Checks.skill(sh, "vontade", 5, m[3], sim.rng, "combat")
	check(sh.efeito_bonus("vantagem_pericia") > 0, "teste de resistência não gasta a vantagem de perícia")


func test_orientacao_expira_na_passagem_da_rodada() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	_orientar(m, ["bandido_1"])
	sim._passar_rodada()
	eq(sim.c("bandido_1").sheet.efeito_bonus("vantagem_pericia"), 0, "sem teste, a vantagem acaba com a rodada")


func test_orientacao_de_atributo_dura_a_cena() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	_orientar(m, ["bandido_1"], [0], {"atributo": "int"})
	var sh: CharacterSheet = sim.c("bandido_1").sheet
	check(sh.efeito_tipo_existe("vantagem_atributo", "int"), "o aprimoramento vale para o atributo escolhido")
	sim._passar_rodada()
	check(sh.efeito_tipo_existe("vantagem_atributo", "int"), "o aprimoramento de atributo sobrevive à rodada")
	Checks.skill(sh, "percepcao", 5, m[3], sim.rng, "combat")
	check(sh.efeito_tipo_existe("vantagem_atributo", "int"), "o aprimoramento de atributo não é gasto por teste")


func test_orientacao_de_grupo_cobre_tres_atributos() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	_orientar(m, ["bandido_1"], [1], {"grupo": "mentais"})
	var sh: CharacterSheet = sim.c("bandido_1").sheet
	check(sh.efeito_tipo_existe("vantagem_atributo", "int") and sh.efeito_tipo_existe("vantagem_atributo", "sab") and sh.efeito_tipo_existe("vantagem_atributo", "car"), "o grupo mental vale para int, sab e car")
	check(not sh.efeito_tipo_existe("vantagem_atributo", "for"), "e não para força")


func test_orientacao_alvos_escolhidos_recebem_a_vantagem() -> void:
	var m := _cena_grupo(17)
	var sim: CombatSim = m[2]
	_orientar(m, ["bandido_1", "bandido_2"], [2])
	check(sim.c("bandido_1").sheet.efeito_bonus("vantagem_pericia") > 0 and sim.c("bandido_2").sheet.efeito_bonus("vantagem_pericia") > 0, "cada criatura escolhida ganha a vantagem")


func test_orientacao_valida_os_aprimoramentos() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "orientacao", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [0]}).ok, "aprimoramento de atributo exige um atributo")
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "orientacao", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [1]}).ok, "aprimoramento de grupo exige o grupo")
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "orientacao", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [0, 1], "atributo": "int", "grupo": "mentais"}).ok, "os dois aprimoramentos de atributo não se combinam")


# --- Arma Mágica (1º círculo): encanto da arma empunhada -----------------------------------------
## Toque exige alvo adjacente: o aliado é o bandido_1 (do lado do jogador), empunhando uma espada longa.
func _arma_magica(m: Array, apr: Array = [], extra: Dictionary = {}) -> void:
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_1").side = "player"
	sim.c("bandido_1").tile = Vector2i(27, 57)
	sim.c("bandido_1").sheet.equipment["weapon"] = "espada_longa"
	sim.c("bandido_2").tile = Vector2i(45, 57)   # longe: sem concentração por inimigo adjacente
	var a := {"type": "cast", "spell": "arma_magica", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": apr}
	for k in extra:
		a[k] = extra[k]
	var vv := GhostPlanner.validate_action(sim, "player", a)
	check(vv.ok, "a conjuração é válida: " + str(vv.get("reason", "")))
	c._cast("player", a, vv)


func test_arma_magica_da_mais_1_limitado_pelo_circulo() -> void:
	var m := _cena_grupo(1)
	_arma_magica(m)
	eq(m[2].c("bandido_1").sheet.efeito_bonus_tipo("encanto_arma", "espada_longa"), 1, "+1 no 1º círculo")


func test_arma_magica_aprimoramento_chega_a_mais_2_com_circulo_2() -> void:
	var m := _cena_grupo(5)
	_arma_magica(m, [0])
	eq(m[2].c("bandido_1").sheet.efeito_bonus_tipo("encanto_arma", "espada_longa"), 2, "+2 com o aprimoramento, circulo 2 permite")
	var m1 := _cena_grupo(1)
	_arma_magica(m1, [0])
	eq(m1[2].c("bandido_1").sheet.efeito_bonus_tipo("encanto_arma", "espada_longa"), 1, "o bônus não passa do círculo máximo")


func test_arma_magica_entra_no_perfil_de_ataque() -> void:
	var m := _cena_grupo(1)
	_arma_magica(m)
	m[2].c("bandido_2").tile = Vector2i(28, 57)   # adjacente ao aliado encantado
	var p: Dictionary = m[2].attack_profile("bandido_1", "bandido_2", 0, false, false)
	check(p.ok and (p.mods as Array).any(func(x): return x[0] == "arma mágica"), "o encanto aparece nos modificadores do ataque")


func test_arma_magica_dano_elemental_com_aprimoramento() -> void:
	var m := _cena_grupo(9)
	_arma_magica(m, [0, 1], {"elemento": "fogo"})
	var sh: CharacterSheet = m[2].c("bandido_1").sheet
	eq(m[1]._dano_elemental_arma(sh).get("tipo", ""), "fogo", "o dano elemental é do tipo escolhido")
	eq(m[1]._dano_elemental_arma(sh).get("dados", 0), 1, "1d6 no 1º aprimoramento")


func test_arma_magica_segundo_aprimoramento_faz_2d6() -> void:
	var m := _cena_grupo(9)
	_arma_magica(m, [0, 1, 2], {"elemento": "frio"})
	eq(m[1]._dano_elemental_arma(m[2].c("bandido_1").sheet).get("dados", 0), 2, "2d6 com o 2º aprimoramento")


func test_arma_magica_valida_elemento_e_ordem_dos_aprimoramentos() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").side = "player"
	sim.c("bandido_1").tile = Vector2i(27, 57)
	sim.c("bandido_1").sheet.equipment["weapon"] = "espada_longa"
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "arma_magica", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [0, 1]}).ok, "o aprimoramento elemental exige o tipo de dano")
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "arma_magica", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [2], "elemento": "fogo"}).ok, "o aprimoramento de 2d6 exige o de 1d6")
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "arma_magica", "target": "bandido_2", "targets": ["bandido_2"]}).ok, "sem arma empunhada, não há o que encantar")


func test_arma_magica_em_si_mesmo_troca_o_atributo_do_ataque() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	sim.c("player").sheet.equipment["weapon"] = "espada_longa"
	var a := {"type": "cast", "spell": "arma_magica", "target": "player", "targets": ["player"]}
	var vv := GhostPlanner.validate_action(sim, "player", a)
	check(vv.ok, "a conjuração em si mesmo é válida: " + str(vv.get("reason", "")))
	m[1]._cast("player", a, vv)
	var p: Dictionary = sim.attack_profile("player", "bandido_1", 0, false, false)
	check(p.ok and (p.mods as Array).any(func(x): return x[0] == "atributo-chave de magia"), "quem empunha a arma usa o atributo-chave de magia no ataque")


# --- Névoa (universal, 1º círculo) ---------------------------------------------------------------
func _nevoa(m: Array, apr: Array, extra: Dictionary = {}) -> void:
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var a := {"type": "cast", "spell": "nevoa", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": apr}
	a.merge(extra, true)
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(v.ok, "névoa válida: %s" % str(v.get("reason", "")))
	c._cast("player", a, v)


func test_nevoa_cria_nuvem_de_6m_pela_cena_e_o_vento_a_dispersa() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	_nevoa(m, [])
	eq(sim.zonas.size(), 1, "uma nuvem")
	eq(sim.zonas[0].rodadas, -1, "dura a cena")
	var m2 := _cena_grupo(1)
	m2[0].modules.weather.enabled = true
	m2[0].modules.weather.region.condition = "chuva"
	_nevoa(m2, [])
	eq(m2[2].zonas[0].rodadas, 4, "vento forte (chuva) dispersa em 4 rodadas")
	var m3 := _cena_grupo(1)
	m3[0].modules.weather.enabled = true
	m3[0].modules.weather.region.condition = "tempestade"
	_nevoa(m3, [])
	eq(m3[2].zonas[0].rodadas, 1, "vendaval (tempestade) dispersa em 1 rodada")


func test_nevoa_da_camuflagem_leve_adjacente_e_total_a_distancia() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	eq(sim.falha_nevoa("player", "bandido_2"), 0, "sem névoa, sem falha")
	_nevoa(m, [])
	eq(sim.falha_nevoa("player", "bandido_1"), 20, "a 1,5m: camuflagem leve (20%)")
	eq(sim.falha_nevoa("player", "bandido_2"), 50, "a partir de 3m: camuflagem total (50%)")
	eq(int(sim.attack_profile("bandido_1", "player", 0, false, false).get("miss_chance", 0)), 20, "o perfil de ataque usa a falha da névoa")


func test_nevoa_faro_reduz_a_camuflagem_total_em_alcance_curto() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	_nevoa(m, [])
	sim.c("bandido_2").sheet.senses.append("faro")
	eq(sim.falha_nevoa("bandido_2", "player"), 20, "faro: só 20% de falha em alcance curto")
	sim.c("bandido_2").tile = Vector2i(40, 57)
	eq(sim.falha_nevoa("bandido_2", "player"), 50, "além do alcance curto, total")


func test_nevoa_criaturas_escolhidas_enxergam_atraves_e_exige_2o_circulo() -> void:
	var baixo := _cena_grupo(1)
	var a := {"type": "cast", "spell": "nevoa", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [1]}
	check(not GhostPlanner.validate_action(baixo[2], "player", a).ok, "o aprimoramento de quem enxerga requer 2º círculo")
	var m := _cena_grupo(5)
	var sim: CombatSim = m[2]
	_nevoa(m, [1], {"enxergam": ["player"]})
	eq(sim.falha_nevoa("player", "bandido_2"), 0, "o escolhido enxerga através")
	eq(sim.falha_nevoa("bandido_2", "player"), 50, "quem não foi escolhido não enxerga")


func test_nevoa_nao_se_forma_sob_a_agua_sem_o_aprimoramento() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var agua := Vector2i(-1, -1)
	for y in sim.db.size.y:
		for x in sim.db.size.x:
			if agua == Vector2i(-1, -1) and sim.db.is_water(Vector2i(x, y)):
				agua = Vector2i(x, y)
	check(agua != Vector2i(-1, -1), "mapa tem água")
	var a := {"type": "cast", "spell": "nevoa", "target": "bandido_1", "targets": ["bandido_1"], "tile": agua}
	c._cast("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(not (sim.zonas[0].tiles as Array).has(agua), "sem o aprimoramento, não há névoa na água")
	var a2 := {"type": "cast", "spell": "nevoa", "target": "bandido_1", "targets": ["bandido_1"], "tile": agua, "aprimoramentos": [0]}
	c._cast("player", a2, GhostPlanner.validate_action(sim, "player", a2))
	check((sim.zonas[1].tiles as Array).has(agua), "com o aprimoramento, nuvem de tinta sob a água")


func test_nevoa_com_cheiro_deixa_enjoado_quem_falha_na_fortitude() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	_nevoa(m, [2])
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")
	sim.c("bandido_2").sheet.add_efeito("teste", "resistencia", -50, "cena")
	sim.c("bandido_2").tile = Vector2i(40, 57)
	var facts: Array = []
	c._zonas_e_marcas_inicio_de_turno("bandido_1", facts)
	c._zonas_e_marcas_inicio_de_turno("bandido_2", facts)
	check(sim.c("bandido_1").sheet.conditions.has("enjoado"), "dentro da nuvem: enjoado")
	check(not sim.c("bandido_2").sheet.conditions.has("enjoado"), "fora e sem faro: nada")
	sim.c("bandido_2").tile = Vector2i(36, 57)
	sim.c("bandido_2").sheet.senses.append("faro")
	c._zonas_e_marcas_inicio_de_turno("bandido_2", facts)
	check(sim.c("bandido_2").sheet.conditions.has("enjoado"), "com faro em alcance curto da nuvem: enjoado")


func test_nevoa_caustica_causa_acido_no_inicio_do_turno() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	_nevoa(m, [3])
	var facts: Array = []
	c._zonas_e_marcas_inicio_de_turno("bandido_1", facts)
	var perdeu: int = 999 - sim.c("bandido_1").sheet.pv
	check(perdeu >= 2 and perdeu <= 8, "2d4 de ácido (%d)" % perdeu)
	var m2 := _cena_grupo(1)
	_nevoa(m2, [3, 4])
	m2[1]._zonas_e_marcas_inicio_de_turno("bandido_1", facts)
	var perdeu2: int = 999 - m2[2].c("bandido_1").sheet.pv
	check(perdeu2 >= 4 and perdeu2 <= 16, "4d4 de ácido com o aprimoramento (%d)" % perdeu2)
	var so4 := {"type": "cast", "spell": "nevoa", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [4]}
	check(not GhostPlanner.validate_action(m2[2], "player", so4).ok, "+2d4 exige a névoa cáustica")


func test_nevoa_espessa_reduz_deslocamento_e_penaliza_ataque() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").tile = Vector2i(27, 60)
	var livre := sim.path_cost("bandido_1", [Vector2i(27, 61), Vector2i(27, 62), Vector2i(27, 63)])
	check(livre.ok and int(livre.cost) <= sim.speed_squares("bandido_1"), "sem névoa, 3 quadrados cabem")
	sim.c("bandido_1").tile = Vector2i(27, 57)
	_nevoa(m, [5])
	var dentro := sim.path_cost("bandido_1", [Vector2i(27, 58), Vector2i(27, 59), Vector2i(27, 60)])
	check(int(dentro.cost) > sim.speed_squares("bandido_1"), "na névoa espessa, 3 quadrados não cabem (3m)")
	var dois := sim.path_cost("bandido_1", [Vector2i(27, 58), Vector2i(27, 59)])
	check(int(dois.cost) <= sim.speed_squares("bandido_1"), "2 quadrados (3m) cabem")
	var prof := sim.attack_profile("bandido_1", "player", 0, false, false)
	check((prof.mods as Array).any(func(x): return x[0] == "névoa espessa" and int(x[1]) == -2), "–2 no ataque dentro da névoa espessa")


# --- Bênção (divina, 1º círculo) ------------------------------------------------------------------
func _lanca(m: Array, a: Dictionary) -> Dictionary:
	var v := GhostPlanner.validate_action(m[2], "player", a)
	if v.ok:
		m[1]._cast("player", a, v)
	return v


func test_bencao_da_mais_1_em_ataque_e_dano_aos_aliados_escolhidos() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").side = "player"
	check(_lanca(m, {"type": "cast", "spell": "bencao", "targets": ["player", "bandido_1"]}).ok, "Bênção válida em aliados")
	eq(sim.c("player").sheet.efeito_bonus("ataque"), 1, "+1 no ataque")
	eq(sim.c("bandido_1").sheet.efeito_bonus("dano"), 1, "+1 no dano do aliado")
	check(not _lanca(m, {"type": "cast", "spell": "bencao", "targets": ["bandido_2"]}).ok, "inimigo não é abençoado")


func test_bencao_aumenta_o_bonus_ate_o_circulo_maximo() -> void:
	var m5 := _cena_grupo(5)
	_lanca(m5, {"type": "cast", "spell": "bencao", "targets": ["player"], "aprimoramentos": [1, 1]})
	eq(m5[2].c("player").sheet.efeito_bonus("ataque"), 2, "nível 5 (2º círculo): bônus limitado a +2")
	var m9 := _cena_grupo(9)
	_lanca(m9, {"type": "cast", "spell": "bencao", "targets": ["player"], "aprimoramentos": [1, 1]})
	eq(m9[2].c("player").sheet.efeito_bonus("ataque"), 3, "nível 9 (3º círculo): +3")


func test_perdicao_repetida_aumenta_a_penalidade_ate_o_circulo() -> void:
	var m9 := _cena_grupo(9)
	_lanca(m9, {"type": "cast", "spell": "perdicao", "targets": ["bandido_1"], "aprimoramentos": [0, 0]})
	eq(m9[2].c("bandido_1").sheet.efeito_bonus("ataque"), -3, "dois aprimoramentos: –3")


func test_bencao_e_perdicao_se_anulam() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").side = "player"
	sim.c("bandido_1").sheet.add_efeito("magia.perdicao", "ataque", -1, "cena")
	_lanca(m, {"type": "cast", "spell": "bencao", "targets": ["bandido_1"]})
	eq(sim.c("bandido_1").sheet.efeito_bonus("ataque"), 1, "Bênção anula Perdição")
	sim.c("bandido_1").side = "inimigo"
	_lanca(m, {"type": "cast", "spell": "perdicao", "targets": ["bandido_1"]})
	eq(sim.c("bandido_1").sheet.efeito_bonus("ataque"), -1, "Perdição anula Bênção")


func test_bencao_em_cadaver_no_combate_preserva_por_uma_semana() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	var w = m[0]
	check(not _lanca(m, {"type": "cast", "spell": "bencao", "targets": ["bandido_1"], "aprimoramentos": [0]}).ok, "vivo não é cadáver")
	sim.c("bandido_1").sheet.pv = -999
	check(_lanca(m, {"type": "cast", "spell": "bencao", "targets": ["bandido_1"], "target": "bandido_1", "aprimoramentos": [0]}).ok, "cadáver é alvo")
	check(w.module("magia").cadaver_preservado("bandido_1"), "cadáver preservado")
	WorldHelpers.advance_hours(w, 24 * 7)
	check(not w.module("magia").cadaver_preservado("bandido_1"), "depois de uma semana, não mais")


func test_bencao_em_cadaver_fora_de_combate() -> void:
	var w := WorldHelpers.world(5)
	var r := RuleRegistry.load_default()
	var sh := CharacterBuilder.build(r, "humano", "clerigo", CharacterBuilder.presets("clerigo")[0], ["for", "des", "con"], "clerigo")
	sh.spells = PackedStringArray(["bencao"])
	sh.pm = 10
	w.player_sheet = sh
	var combat = w.module("combat")
	var t: Array = combat.creature_state["bandido_1"].tile
	WorldHelpers.put(w, int(t[0]) + 1, int(t[1]))
	var payload := {"spell": "bencao", "target": "bandido_1", "aprimoramentos": [0]}
	check(not WorldHelpers.cmd(w, "CastSpell", payload).accepted, "vivo não é cadáver")
	combat.creature_state["bandido_1"].alive = false
	check(not WorldHelpers.cmd(w, "CastSpell", {"spell": "bencao", "target": "bandido_1"}).accepted, "a Bênção comum só é lançada em combate")
	var res := WorldHelpers.cmd(w, "CastSpell", payload)
	check(res.accepted, "Bênção no cadáver aceita")
	eq(sh.pm, 8, "custou 1 PM + 1 PM do aprimoramento")
	check(w.module("magia").cadaver_preservado("bandido_1"), "cadáver preservado")
	WorldHelpers.put(w, int(t[0]) + 20, int(t[1]))
	check(not WorldHelpers.cmd(w, "CastSpell", payload).accepted, "fora do alcance curto")


# --- Consagrar e Profanar (divinas, 1º círculo) ---------------------------------------------------
func test_consagrar_maximiza_a_cura_de_luz_na_area() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").side = "player"
	sim.c("bandido_1").sheet.pv = 500
	sim.c("bandido_2").tile = Vector2i(45, 57)
	check(_lanca(m, {"type": "cast", "spell": "consagrar", "target": "player"}).ok, "Consagrar válida")
	m[2].next_turn()
	m[2].budget.std = 1
	_lanca(m, {"type": "cast", "spell": "curar_ferimentos", "target": "bandido_1", "targets": ["bandido_1"]})
	eq(sim.c("bandido_1").sheet.pv, 518, "Curar Ferimentos cura 18 PV (máximo de 2d8+2) na área consagrada")


func test_consagrar_penaliza_mortos_vivos_e_o_aumento_respeita_o_circulo() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	var mv: CharacterSheet = sim.c("bandido_2").sheet
	mv.creature_type = "morto-vivo"
	var def0 := mv.defense(m[3], true)
	_lanca(m, {"type": "cast", "spell": "consagrar", "target": "player", "aprimoramentos": [0, 1]})
	eq(mv.defense(m[3], true), def0 - 2, "nível 1: –2 (o aumento não passa do limite)")
	eq(mv.efeito_bonus("testes"), -2, "–2 em testes")
	var m9 := _cena_grupo(9)
	var mv9: CharacterSheet = m9[2].c("bandido_2").sheet
	mv9.creature_type = "morto-vivo"
	_lanca(m9, {"type": "cast", "spell": "consagrar", "target": "player", "aprimoramentos": [0, 1]})
	eq(mv9.efeito_bonus("testes"), -3, "nível 9: –3")
	eq(m9[2].c("bandido_1").sheet.efeito_bonus("testes"), 0, "vivos não são afetados")
	m9[2].c("bandido_2").tile = Vector2i(45, 57)
	m9[1]._refresh_bencaos()
	eq(mv9.efeito_bonus("testes"), 0, "fora da área, sem penalidade")


func test_profanar_maximiza_trevas_e_anula_consagrar() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	var w = m[0]
	_lanca(m, {"type": "cast", "spell": "consagrar", "target": "player"})
	sim.budget.std = 1
	_lanca(m, {"type": "cast", "spell": "profanar", "target": "player"})
	eq(w.module("magia").areas.size(), 1, "Profanar anula Consagrar")
	check(w.module("magia").maximiza("trevas", Vector2i(26, 57)), "trevas maximizadas")
	check(not w.module("magia").maximiza("luz", Vector2i(26, 57)), "luz já não é maximizada")
	var mv: CharacterSheet = sim.c("bandido_1").sheet
	mv.creature_type = "morto-vivo"
	mv.pv = 500
	sim.budget.std = 1
	_lanca(m, {"type": "cast", "spell": "infligir_ferimentos", "target": "bandido_1", "targets": ["bandido_1"]})
	eq(mv.pv, 518, "Infligir cura o morto-vivo no máximo (18)")


func test_profanar_da_bonus_aos_mortos_vivos() -> void:
	var m := _cena_grupo(1)
	var mv: CharacterSheet = m[2].c("bandido_2").sheet
	mv.creature_type = "morto-vivo"
	_lanca(m, {"type": "cast", "spell": "profanar", "target": "player", "aprimoramentos": [0]})
	eq(mv.efeito_bonus("defesa"), 2, "+2 na Defesa")
	eq(mv.efeito_bonus("testes"), 2, "+2 em testes")


func _mundo_clerigo(nivel: int) -> WorldState:
	var w := WorldHelpers.world(5)
	var sh := CharacterBuilder.build(w.rules, "humano", "clerigo", CharacterBuilder.presets("clerigo")[0], ["for", "des", "con"], "clerigo")
	sh.level = nivel
	sh.spells = PackedStringArray(["consagrar", "profanar", "curar_ferimentos"])
	sh.pm = 40
	w.player_sheet = sh
	return w


func test_consagrar_fora_de_combate_dura_um_dia() -> void:
	var w := _mundo_clerigo(1)
	WorldHelpers.put(w, 50, 40)
	check(WorldHelpers.cmd(w, "CastSpell", {"spell": "consagrar"}).accepted, "Consagrar fora de combate")
	check(w.module("magia").maximiza("luz", Vector2i(52, 40)), "área consagrada")
	w.player_sheet.pv = 1
	WorldHelpers.cmd(w, "CastSpell", {"spell": "curar_ferimentos"})
	eq(w.player_sheet.pv, mini(w.player_sheet.pv_max, 19), "cura maximizada fora de combate")
	WorldHelpers.advance_hours(w, 25)
	check(not w.module("magia").maximiza("luz", Vector2i(52, 40)), "depois de 1 dia, acabou")


func test_consagrar_recusada_perto_de_simbolo_de_outra_divindade() -> void:
	var w := _mundo_clerigo(1)
	WorldHelpers.put(w, 30, 13)   # Templo de Lena
	check(not WorldHelpers.cmd(w, "CastSpell", {"spell": "consagrar"}).accepted, "sem devoção a Lena, recusada")
	w.player_sheet.devotion = "Lena"
	check(WorldHelpers.cmd(w, "CastSpell", {"spell": "consagrar"}).accepted, "devoto de Lena pode")


func test_consagrar_permanente_exige_4o_circulo_ouro_e_uma_hora() -> void:
	var baixo := _mundo_clerigo(9)
	baixo.player.gold = 5000
	check(not WorldHelpers.cmd(baixo, "CastSpell", {"spell": "consagrar", "aprimoramentos": [2]}).accepted, "requer 4º círculo")
	var w := _mundo_clerigo(13)
	WorldHelpers.put(w, 50, 40)
	w.player.gold = 500
	check(not WorldHelpers.cmd(w, "CastSpell", {"spell": "consagrar", "aprimoramentos": [2]}).accepted, "sem T$ 1.000, recusada")
	w.player.gold = 1500
	var antes := w.clock.total_minutes()
	check(WorldHelpers.cmd(w, "CastSpell", {"spell": "consagrar", "aprimoramentos": [2]}).accepted, "versão permanente")
	eq(int(w.player.gold), 500, "gastou T$ 1.000")
	check(w.clock.total_minutes() - antes >= 60, "levou 1 hora")
	WorldHelpers.advance_hours(w, 24 * 30)
	check(w.module("magia").maximiza("luz", Vector2i(50, 40)), "permanente")
	var m := _cena_grupo(13)
	check(not GhostPlanner.validate_action(m[2], "player", {"type": "cast", "spell": "consagrar", "target": "player", "aprimoramentos": [2]}).ok, "em combate, não")


# --- Despedaçar (divina, 1º círculo) --------------------------------------------------------------
func test_despedacar_fere_e_atordoa_uma_vez_por_cena() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	sim.c("bandido_2").sheet.add_efeito("teste", "resistencia", -50, "cena")
	_lanca(m, {"type": "cast", "spell": "despedacar", "target": "bandido_2", "targets": ["bandido_2"]})
	var perdeu: int = 999 - sim.c("bandido_2").sheet.pv
	check(perdeu >= 3 and perdeu <= 10, "1d8+2 de impacto (%d)" % perdeu)
	check(sim.c("bandido_2").sheet.conditions.has("atordoado"), "atordoado ao falhar")
	sim.c("bandido_2").sheet.remove_condition("atordoado")
	sim.budget.std = 1
	_lanca(m, {"type": "cast", "spell": "despedacar", "target": "bandido_2", "targets": ["bandido_2"]})
	check(not sim.c("bandido_2").sheet.conditions.has("atordoado"), "só uma vez por cena")


func test_despedacar_resistido_reduz_a_metade_e_nao_atordoa() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	sim.c("bandido_2").sheet.add_efeito("teste", "resistencia", 99, "cena")
	_lanca(m, {"type": "cast", "spell": "despedacar", "target": "bandido_2", "targets": ["bandido_2"], "aprimoramentos": [0]})
	var perdeu: int = 999 - sim.c("bandido_2").sheet.pv
	check(perdeu >= 3 and perdeu <= 10, "2d8+4 pela metade (%d)" % perdeu)
	check(not sim.c("bandido_2").sheet.conditions.has("atordoado"), "não atordoa")


func test_despedacar_dobra_e_ignora_rd_em_construto() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	var ts: CharacterSheet = sim.c("bandido_2").sheet
	ts.creature_type = "construto"
	ts.dr["impacto"] = 50
	ts.add_efeito("teste", "resistencia", -50, "cena")
	_lanca(m, {"type": "cast", "spell": "despedacar", "target": "bandido_2", "targets": ["bandido_2"]})
	var perdeu: int = 999 - ts.pv
	check(perdeu >= 6 and perdeu <= 20 and perdeu % 2 == 0, "o dobro, sem RD (%d)" % perdeu)


func test_despedacar_area_atinge_todos_incluindo_o_conjurador() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	check(_lanca(m, {"type": "cast", "spell": "despedacar", "target": "player", "aprimoramentos": [5]}).ok, "versão em área")
	check(sim.c("player").sheet.pv < 999, "o conjurador está na área")
	check(sim.c("bandido_1").sheet.pv < 999, "adjacente atingido")
	eq(sim.c("bandido_2").sheet.pv, 999, "a 9m (6 quadrados), fora da esfera de 6m")


func test_despedacar_objetos_por_tamanho_fora_de_combate() -> void:
	var w := WorldHelpers.world(5)
	var sh := CharacterBuilder.build(w.rules, "humano", "clerigo", CharacterBuilder.presets("clerigo")[0], ["for", "des", "con"], "clerigo")
	sh.spells = PackedStringArray(["despedacar"])
	sh.pm = 40
	w.player_sheet = sh
	var porta := w.db.object_def("porta_taverna")
	WorldHelpers.put(w, int(porta.tile[0]), int(porta.tile[1]) + 1)
	check(not WorldHelpers.cmd(w, "CastSpell", {"spell": "despedacar", "objeto": "porta_taverna"}).accepted, "porta é Grande: Pequeno não basta")
	check(not WorldHelpers.cmd(w, "CastSpell", {"spell": "despedacar", "objeto": "porta_taverna", "aprimoramentos": [2]}).accepted, "Grande requer 3º círculo")
	sh.level = 9
	var pv0: int = w.module("objects").obj("porta_taverna").pv
	check(WorldHelpers.cmd(w, "CastSpell", {"spell": "despedacar", "objeto": "porta_taverna", "aprimoramentos": [2]}).accepted, "nível 9 quebra porta Grande")
	var perdeu: int = pv0 - int(w.module("objects").obj("porta_taverna").pv)
	check(perdeu >= 6 and perdeu <= 20, "o dobro, ignorando RD 5 (%d)" % perdeu)
	for i in 4:
		WorldHelpers.cmd(w, "CastSpell", {"spell": "despedacar", "objeto": "porta_taverna", "aprimoramentos": [2]})
	check(w.module("objects").obj("porta_taverna").broken, "a porta acaba destruída")


func test_despedacar_objeto_em_combate() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	var w = m[0]
	var porta: Dictionary = w.db.object_def("porta_taverna")
	sim.c("player").tile = Vector2i(int(porta.tile[0]), int(porta.tile[1]) + 2)
	var a := {"type": "cast", "spell": "despedacar", "objeto": "porta_taverna", "aprimoramentos": [2]}
	check(_lanca(m, a).ok, "objeto Grande em combate")
	check(int(w.module("objects").obj("porta_taverna").pv) < 20, "a porta sofre dano")
	eq(sim.c("player").sheet.pv, 999, "ninguém mais é atingido")


# --- Arma Espiritual (divina, 1º círculo) e duração sustentada ----------------------------------
func _ataque_de(m: Array, atacante: String, alvo: String) -> Array:
	var sim: CombatSim = m[2]
	return m[1]._resolve_attack(atacante, alvo, sim.attack_profile(atacante, alvo, 0, false, false), false)


func _danos_da_arma(facts: Array) -> Array:
	return facts.filter(func(f): return f.type == "ATTACK_RESOLVED" and str(f.payload.weapon) == "Arma Espiritual")


func test_arma_espiritual_exige_divindade_com_arma_preferida() -> void:
	var m := _cena_grupo(1)
	var sh: CharacterSheet = m[2].c("player").sheet
	var a := {"type": "cast", "spell": "arma_espiritual", "target": "player"}
	sh.devotion = ""
	check(not GhostPlanner.validate_action(m[2], "player", a).ok, "sem divindade, não")
	sh.devotion = "Lena"
	check(not GhostPlanner.validate_action(m[2], "player", a).ok, "Lena não tem arma preferida")
	sh.devotion = "Nimb"
	check(not GhostPlanner.validate_action(m[2], "player", a).ok, "Nimb: precisa escolher o tipo")
	check(GhostPlanner.validate_action(m[2], "player", {"type": "cast", "spell": "arma_espiritual", "target": "player", "tipo_dano": "impacto"}).ok, "Nimb com tipo escolhido")
	sh.devotion = "Khalmyr"
	check(_lanca(m, a).ok, "Khalmyr: espada longa")
	var tipo := ""
	for e in sh.efeitos:
		if e.stat == "arma_espiritual": tipo = str(e.tipo)
	eq(tipo, "corte", "espada longa causa corte")


func test_arma_espiritual_contra_ataca_uma_vez_por_rodada() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	sim.c("player").sheet.devotion = "Khalmyr"
	_lanca(m, {"type": "cast", "spell": "arma_espiritual", "target": "player"})
	var f1 := _danos_da_arma(_ataque_de(m, "bandido_1", "player"))
	eq(f1.size(), 1, "contra-ataque ao sofrer ataque corpo a corpo")
	var perdeu: int = 999 - sim.c("bandido_1").sheet.pv
	check(perdeu >= 2 and perdeu <= 12, "2d6 (%d)" % perdeu)
	eq(_danos_da_arma(_ataque_de(m, "bandido_1", "player")).size(), 0, "só uma vez por rodada")
	sim.round_no += 1
	eq(_danos_da_arma(_ataque_de(m, "bandido_1", "player")).size(), 1, "na rodada seguinte, de novo")


func test_arma_espiritual_defesa_e_dados_limitados_pelo_circulo() -> void:
	var m := _cena_grupo(1)
	var sh: CharacterSheet = m[2].c("player").sheet
	sh.devotion = "Khalmyr"
	var d0 := sh.defense(m[3], true)
	check(not GhostPlanner.validate_action(m[2], "player", {"type": "cast", "spell": "arma_espiritual", "target": "player", "aprimoramentos": [1]}).ok, "+1 a mais exige o +1 base")
	_lanca(m, {"type": "cast", "spell": "arma_espiritual", "target": "player", "aprimoramentos": [0, 1, 1, 4, 4]})
	eq(sh.defense(m[3], true), d0 + 3, "+3 na Defesa")
	eq(sh.efeito_bonus("arma_espiritual_dados"), 3, "nível 1: só +1d6 (círculo máximo 1)")


func test_arma_espiritual_sustentada_ataca_livre_e_custa_1_pm_por_turno() -> void:
	var m := _cena_grupo(5)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var sh: CharacterSheet = sim.c("player").sheet
	sh.devotion = "Khalmyr"
	_lanca(m, {"type": "cast", "spell": "arma_espiritual", "target": "player", "aprimoramentos": [2, 3]})
	check(sim.sustentadas.has("player"), "sustentada")
	var v := GhostPlanner.validate_action(sim, "player", {"type": "arma_espiritual", "target": "bandido_1"})
	check(v.ok and v.kind == "livre", "ataque livre a alvo adjacente")
	var out := c._execute_action("player", {"type": "arma_espiritual", "target": "bandido_1"}, v)
	eq(_danos_da_arma(out).size(), 1, "a arma acerta automaticamente")
	check("essencia" in _danos_da_arma(out)[0].payload.tags, "dano de essência")
	check(not GhostPlanner.validate_action(sim, "player", {"type": "arma_espiritual", "target": "bandido_1"}).ok, "uma vez por rodada")
	eq(_danos_da_arma(_ataque_de(m, "bandido_1", "player")).size(), 0, "a arma que atacou não contra-ataca")
	var pm0 := sh.pm
	c._begin_turn_base("player")
	eq(sh.pm, pm0 - 1, "1 PM no início do turno para sustentar")
	sh.pm = 0
	c._begin_turn_base("player")
	check(not sim.sustentadas.has("player"), "sem PM, a magia termina")
	eq(sh.efeito_bonus("arma_espiritual"), 0, "a arma some")


func test_arma_espiritual_duas_armas_contra_atacam_duas_vezes() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	sim.c("player").sheet.devotion = "Khalmyr"
	sim.c("bandido_2").tile = Vector2i(26, 58)
	_lanca(m, {"type": "cast", "spell": "arma_espiritual", "target": "player", "aprimoramentos": [5]})
	eq(_danos_da_arma(_ataque_de(m, "bandido_1", "player")).size(), 1, "primeira arma")
	eq(_danos_da_arma(_ataque_de(m, "bandido_2", "player")).size(), 1, "segunda arma")
	eq(_danos_da_arma(_ataque_de(m, "bandido_1", "player")).size(), 0, "só duas por rodada")


func test_arma_espiritual_some_se_o_conjurador_morrer() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	var sh: CharacterSheet = sim.c("player").sheet
	sh.devotion = "Khalmyr"
	_lanca(m, {"type": "cast", "spell": "arma_espiritual", "target": "player"})
	sh.pv = -999
	m[1]._refresh_bencaos()
	eq(sh.efeito_bonus("arma_espiritual"), 0, "dissipada")


func test_sustentada_uma_por_vez_e_manto_custa_pm() -> void:
	var m := _cena_grupo(13)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var sh: CharacterSheet = sim.c("player").sheet
	sh.devotion = "Khalmyr"
	_lanca(m, {"type": "cast", "spell": "manto_do_cruzado", "target": "player"})
	eq(str(sim.sustentadas.get("player", "")), "manto_do_cruzado", "Manto do Cruzado é sustentado")
	sim.budget.std = 1
	_lanca(m, {"type": "cast", "spell": "arma_espiritual", "target": "player", "aprimoramentos": [2]})
	eq(str(sim.sustentadas.get("player", "")), "arma_espiritual", "a nova sustentada substitui a anterior")
	eq(sh.manto_cruzado, "", "o manto terminou")
	c.power_policy["sustentar"] = "nunca"
	c._begin_turn_base("player")
	check(not sim.sustentadas.has("player"), "o jogador pode deixar de sustentar")


# --- Armamento da Natureza (divina, 1º círculo) ----------------------------------------------------
func _com_arma(m: Array, arma: String) -> CharacterSheet:
	var sh: CharacterSheet = m[2].c("player").sheet
	sh.equipment["weapon"] = arma
	CharacterBuilder.apply_equipment(m[3], sh)
	return sh


func test_passos_de_dano_seguem_a_tabela_3_2() -> void:
	var r := RuleRegistry.load_default()
	eq(CombatSim.dano_em_passos(r, "1d6", 1), "1d8", "1d6 +1 passo")
	eq(CombatSim.dano_em_passos(r, "1d6", 2), "1d10", "1d6 +2 passos")
	eq(CombatSim.dano_em_passos(r, "2d4", 1), "1d10", "2d4 conta como 1d8")
	eq(CombatSim.dano_em_passos(r, "1d4", -1), "1d3", "–1 passo")
	eq(CombatSim.dano_em_passos(r, "1d10", 3), "4d6", "+3 passos")


func test_armamento_da_natureza_so_em_arma_primitiva_ou_natural() -> void:
	var m := _cena_grupo(1)
	_com_arma(m, "espada_longa")
	check(not GhostPlanner.validate_action(m[2], "player", {"type": "cast", "spell": "armamento_da_natureza", "target": "player"}).ok, "espada longa não é primitiva")
	_com_arma(m, "clava")
	check(_lanca(m, {"type": "cast", "spell": "armamento_da_natureza", "target": "player"}).ok, "clava é primitiva (no próprio conjurador)")
	var prof: Dictionary = m[2].attack_profile("player", "bandido_1", 0, false, false)
	eq(str(prof.atk.dano), "1d8", "dano da clava sobe um passo")
	check(bool(prof.atk.get("magica", false)), "considerada mágica")


func test_armamento_da_natureza_tipo_ataque_e_passo_extra() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	_com_arma(m, "clava")
	_lanca(m, {"type": "cast", "spell": "armamento_da_natureza", "target": "player", "tipo_dano": "perfuracao", "aprimoramentos": [0, 2, 3]})
	var prof := sim.attack_profile("player", "bandido_1", 0, false, false)
	eq(str(prof.atk.tipo), "perfuracao", "tipo de dano mudado")
	eq(str(prof.atk.dano), "1d10", "dois passos")
	check((prof.mods as Array).any(func(x): return x[0] == "armamento da natureza" and int(x[1]) == 2), "+2 no ataque")


func test_armamento_da_natureza_execucao_de_movimento() -> void:
	var m := _cena_grupo(1)
	_com_arma(m, "clava")
	var v := GhostPlanner.validate_action(m[2], "player", {"type": "cast", "spell": "armamento_da_natureza", "target": "player", "aprimoramentos": [1]})
	check(v.ok and v.kind == "movimento", "ação de movimento")
	m[2].budget.std = 0
	check(GhostPlanner.validate_action(m[2], "player", {"type": "cast", "spell": "armamento_da_natureza", "target": "player", "aprimoramentos": [1]}).ok, "sem ação padrão, ainda pode")


func test_armamento_da_natureza_em_arma_natural() -> void:
	var m := _cena_grupo(1)
	var sh: CharacterSheet = m[2].c("player").sheet
	sh.equipment["weapon"] = ""
	sh.attacks = [{"nome": "Chifres", "skill": "luta", "dano": "1d6", "for_no_dano": true, "margem": 20, "mult": 2, "alcance_q": 1, "distancia": false, "tipo": "perfuracao", "natural": true}]
	check(_lanca(m, {"type": "cast", "spell": "armamento_da_natureza", "target": "player"}).ok, "arma natural")
	eq(str(m[2].attack_profile("player", "bandido_1", 0, false, false).atk.dano), "1d8", "chifres sobem um passo")


# --- Caminhos da Natureza (divina, 1º círculo) e Rastrear ----------------------------------------
func _tile_de(db, ch: String) -> Vector2i:
	for y in db.size.y:
		for x in db.size.x:
			if db.tile_char(Vector2i(x, y)) == ch:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func test_caminhos_da_natureza_desloca_mais_e_ignora_terreno_dificil_natural() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	var q0 := sim.speed_squares("player")
	var planta := _tile_de(sim.db, "c")
	var entulho := _tile_de(sim.db, "%")
	eq(sim.step_cost(planta + Vector2i(-1, 0), planta, "player"), 2, "plantação é terreno difícil")
	sim.c("bandido_1").side = "player"
	check(_lanca(m, {"type": "cast", "spell": "caminhos_da_natureza", "targets": ["player", "bandido_1"], "target": "player"}).ok, "aliados escolhidos")
	eq(sim.speed_squares("player"), q0 + 2, "+3m (2 quadrados)")
	eq(sim.step_cost(planta + Vector2i(-1, 0), planta, "player"), 1, "ignora terreno difícil natural")
	eq(sim.step_cost(entulho + Vector2i(-1, 0), entulho, "player"), 2, "entulho não é natural")
	check(not _lanca(m, {"type": "cast", "spell": "caminhos_da_natureza", "targets": ["bandido_2"], "target": "bandido_2"}).ok, "não em inimigos")


func test_caminhos_da_natureza_aprimoramentos_e_truque() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	var sh: CharacterSheet = sim.c("player").sheet
	_lanca(m, {"type": "cast", "spell": "caminhos_da_natureza", "targets": ["player"], "target": "player", "aprimoramentos": [0, 1]})
	eq(sh.efeito_bonus("deslocamento_m"), 6, "+3m a mais")
	eq(sh.efeito_bonus("rastro_dificil"), 10, "rastros mais difíceis")
	var r: RuleRegistry = m[3]
	eq(Checks.cd_rastrear(r, "comum", sh, true, 1, false, 0), 30, "CD 20 + 10 em terreno natural")
	eq(Checks.cd_rastrear(r, "duro", sh, false, 1, true, 2), 32, "fora do natural: 25 + 5 visibilidade + 2 dias")
	var m2 := _cena_grupo(1)
	var v := GhostPlanner.validate_action(m2[2], "player", {"type": "cast", "spell": "caminhos_da_natureza", "target": "player", "truque": true})
	check(v.ok and int(v.cost) == 0, "truque de 0 PM")
	m2[1]._cast("player", {"type": "cast", "spell": "caminhos_da_natureza", "target": "player", "truque": true}, v)
	eq(m2[2].c("player").sheet.efeito_bonus("sobrevivencia_orientar"), 5, "+5 para se orientar")
	eq(m2[2].c("player").sheet.efeito_bonus("deslocamento_m"), 0, "o truque não dá deslocamento")


func test_caminhos_da_natureza_fora_de_combate_acelera_a_viagem_por_um_dia() -> void:
	var w := WorldHelpers.world(5)
	var sh := CharacterBuilder.build(w.rules, "humano", "clerigo", CharacterBuilder.presets("clerigo")[0], ["for", "des", "con"], "clerigo")
	sh.spells = PackedStringArray(["caminhos_da_natureza"])
	sh.pm = 10
	w.player_sheet = sh
	var tr = w.module("travel")
	var ermo := {"km": 30, "road": false}
	var antes: float = tr.km_per_day(ermo)
	check(WorldHelpers.cmd(w, "CastSpell", {"spell": "caminhos_da_natureza"}).accepted, "lançada fora de combate")
	check(tr.km_per_day(ermo) > antes * 1.5, "12m e sem a penalidade dos ermos (%.1f -> %.1f)" % [antes, tr.km_per_day(ermo)])
	WorldHelpers.advance_hours(w, 48)
	eq(sh.efeito_bonus("deslocamento_m"), 0, "dura 1 dia")


func test_fuga_inimigo_treinado_segue_os_rastros() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var w = m[0]
	for id in ["bandido_1", "bandido_2"]:
		var s: CharacterSheet = sim.c(id).sheet
		s.trained.append("sobrevivencia")
		s.flat_skills["sobrevivencia"] = 99
	var out: Array = c._end_combat("fuga")
	check(out.any(func(f): return f.type == "PLAYER_TRACKED"), "os bandidos acham os rastros")
	var res := WorldHelpers.advance_hours(w, 1)
	var evs: Array = res.emitted_events.map(func(e): return e.event_type)
	check(evs.has("CREATURES_MOVED"), "eles chegam perto do jogador")


func test_fuga_sem_rastreador_treinado_nao_ha_perseguicao() -> void:
	var m := _cena_grupo(1)
	var out: Array = m[1]._end_combat("fuga")
	check(not out.any(func(f): return f.type == "PLAYER_TRACKED"), "sem treino em Sobrevivência, ninguém rastreia")


# --- Controlar Plantas (divina, 1º círculo) ---------------------------------------------------------
func _cena_na_plantacao(nivel: int) -> Array:
	var m := _cena_grupo(nivel)
	var sim: CombatSim = m[2]
	var planta := _tile_de(sim.db, "c")
	sim.c("player").tile = planta + Vector2i(-3, 0)
	sim.c("bandido_1").tile = planta
	sim.c("bandido_2").tile = planta + Vector2i(1, 0)
	m.append(planta)
	return m


func test_controlar_plantas_exige_vegetacao() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	var piso := _tile_de(sim.db, "_")
	sim.c("player").tile = piso
	sim.c("bandido_1").tile = piso + Vector2i(1, 0)
	var a := {"type": "cast", "spell": "controlar_plantas", "target": "bandido_1", "tile": piso + Vector2i(1, 0)}
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(not v.ok or Area.quadrado(piso + Vector2i(1, 0), 6).any(func(t): return sim.db.is_vegetation(t)), "sem vegetação na área, recusada")


func test_controlar_plantas_enreda_e_vira_terreno_dificil() -> void:
	var m := _cena_na_plantacao(1)
	var sim: CombatSim = m[2]
	var planta: Vector2i = m[4]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")
	sim.c("bandido_2").sheet.add_efeito("teste", "resistencia", 99, "cena")
	check(_lanca(m, {"type": "cast", "spell": "controlar_plantas", "target": "bandido_1", "tile": planta}).ok, "lançada na plantação")
	check(sim.c("bandido_1").sheet.conditions.has("enredado"), "quem falha fica enredado")
	check(not sim.c("bandido_2").sheet.conditions.has("enredado"), "quem passa, não")
	check(sim.zona_em(planta + Vector2i(0, 1), "terreno_dificil"), "terreno difícil mágico")
	sim.c("bandido_2").sheet.remove_efeito("teste")
	sim.c("bandido_2").sheet.add_efeito("teste", "resistencia", -50, "cena")
	m[1]._zonas_e_marcas_inicio_de_turno("bandido_2", [])
	check(sim.c("bandido_2").sheet.conditions.has("enredado"), "no início do turno, a vegetação tenta de novo")


func test_controlar_plantas_libertar_se_e_imovel() -> void:
	var m := _cena_na_plantacao(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")
	_lanca(m, {"type": "cast", "spell": "controlar_plantas", "target": "bandido_1", "tile": m[4], "aprimoramentos": [1]})
	check(sim.c("bandido_1").sheet.conditions.has("imovel"), "também imóvel")
	sim.c("bandido_1").sheet.flat_skills["acrobacia"] = 99
	sim.c("bandido_1").sheet.remove_condition("surpreendido")   # a cena começa com os bandidos surpreendidos
	var v := GhostPlanner.validate_action(sim, "bandido_1", {"type": "escapar"})
	check(v.ok, "pode tentar se libertar: %s" % str(v.get("reason", "")))
	c._execute_action("bandido_1", {"type": "escapar"}, v)
	check(not sim.c("bandido_1").sheet.conditions.has("enredado") and not sim.c("bandido_1").sheet.conditions.has("imovel"), "libertou-se")
	check(not GhostPlanner.validate_action(sim, "player", {"type": "escapar"}).ok, "quem não está preso não escapa")


func test_controlar_plantas_poda_dissipa_e_fica_no_mundo() -> void:
	var m := _cena_na_plantacao(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var w = m[0]
	var planta: Vector2i = m[4]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", -50, "cena")
	_lanca(m, {"type": "cast", "spell": "controlar_plantas", "target": "bandido_1", "tile": planta})
	sim.budget.std = 1
	_lanca(m, {"type": "cast", "spell": "controlar_plantas", "target": "bandido_1", "tile": planta, "aprimoramentos": [0]})
	check(not sim.c("bandido_1").sheet.conditions.has("enredado"), "a poda dissipa e solta")
	eq(sim.step_cost(planta + Vector2i(-1, 0), planta, "player"), 1, "plantação podada: terreno normal")
	check(w.module("magia").podas.has("%d,%d" % [planta.x, planta.y]), "a poda fica no mundo")
	c._end_combat("vitoria")
	check(w.module("magia").tiles_podados().has(planta), "na próxima cena, a vegetação continua podada")


func test_controlar_plantas_truque_e_falar_com_plantas() -> void:
	var m := _cena_na_plantacao(1)
	var out: Array = m[1]._cast("player", {"type": "cast", "spell": "controlar_plantas", "target": "bandido_1", "tile": m[4], "truque": true}, {"cost": 0})
	check(out.any(func(f): return f.type == "PLANT_ANIMATED"), "truque anima uma planta")
	var m5 := _cena_na_plantacao(5)
	var v := GhostPlanner.validate_action(m5[2], "player", {"type": "cast", "spell": "controlar_plantas", "target": "player", "aprimoramentos": [2]})
	check(v.ok, "falar com plantas: %s" % str(v.get("reason", "")))
	var out2: Array = m5[1]._cast("player", {"type": "cast", "spell": "controlar_plantas", "target": "player", "aprimoramentos": [2]}, v)
	check(out2.any(func(f): return f.type == "PLANTS_TALKED" and int(f.payload.criaturas_perto) >= 0), "as plantas respondem")


func test_controlar_plantas_ia_presa_e_imovel_tenta_se_libertar() -> void:
	var m := _cena_na_plantacao(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var b: CharacterSheet = sim.c("bandido_2").sheet
	b.remove_condition("surpreendido")
	b.add_efeito("teste", "resistencia", -50, "cena")
	sim.c("bandido_1").tile = Vector2i(1, 1)
	_lanca(m, {"type": "cast", "spell": "controlar_plantas", "target": "bandido_2", "tile": m[4], "aprimoramentos": [1]})
	sim.budget = {"std": 1, "move": 1}
	var out: Array = c._ai_turn("bandido_2")
	check(out.any(func(f): return f.type == "ESCAPE_ATTEMPT"), "a IA tenta se libertar")


# --- Santuário (divina, 1º círculo) -----------------------------------------------------------------
func _ataque_planejado(m: Array, atacante: String, alvo: String) -> Array:
	var sim: CombatSim = m[2]
	sim.budget = {"std": 1, "move": 1}
	var a := {"type": "attack", "target": alvo, "attack": 0}
	var v := GhostPlanner.validate_action(sim, atacante, a)
	return m[1]._execute_action(atacante, a, v) if v.ok else []


func test_santuario_quem_falha_nao_ataca_e_nao_tenta_de_novo() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	var b: CharacterSheet = sim.c("bandido_1").sheet
	b.remove_condition("surpreendido")
	b.add_efeito("teste", "resistencia", -50, "cena")
	check(_lanca(m, {"type": "cast", "spell": "santuario", "target": "player"}).ok, "Santuário em si mesmo (toque)")
	var out := _ataque_planejado(m, "bandido_1", "player")
	check(out.any(func(f): return f.type == "SANCTUARY_BLOCKED"), "falhou na Vontade: não consegue")
	check(not out.any(func(f): return f.type == "ATTACK_RESOLVED"), "o ataque não acontece")
	b.remove_efeito("teste")
	b.add_efeito("teste", "resistencia", 99, "cena")
	var out2 := _ataque_planejado(m, "bandido_1", "player")
	check(out2.any(func(f): return f.type == "SANCTUARY_BLOCKED" and f.payload.reason == "ja_falhou"), "não pode tentar de novo")
	check(not m[1]._pode_mirar("bandido_1", "player"), "a IA procura outro alvo")


func test_santuario_quem_passa_ataca_e_o_protegido_hostil_dissipa() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	var b: CharacterSheet = sim.c("bandido_1").sheet
	b.remove_condition("surpreendido")
	b.add_efeito("teste", "resistencia", 99, "cena")
	_lanca(m, {"type": "cast", "spell": "santuario", "target": "player"})
	check(_ataque_planejado(m, "bandido_1", "player").any(func(f): return f.type == "ATTACK_RESOLVED"), "passou: ataca")
	var out := _ataque_planejado(m, "player", "bandido_1")
	check(out.any(func(f): return f.type == "SPELL_ENDED" and f.payload.spell == "santuario"), "atacar dissipa o Santuário")
	check(m[1]._santuario_de("player").is_empty(), "sem proteção")


func test_santuario_nao_protege_de_area_sem_o_aprimoramento() -> void:
	var m := _cena_grupo(9)
	var sim: CombatSim = m[2]
	sim.c("player").sheet.add_efeito("teste", "resistencia", -50, "cena")
	sim.c("bandido_1").tile = Vector2i(28, 57)
	m[1]._cast("player", {"type": "cast", "spell": "santuario", "target": "bandido_1"}, {"cost": 0})
	var a := {"type": "cast", "spell": "despedacar", "target": "player", "aprimoramentos": [5]}
	var out: Array = m[1]._execute_action("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(sim.c("bandido_1").sheet.pv < 999, "a área atinge o protegido")
	var m2 := _cena_grupo(9)
	var sim2: CombatSim = m2[2]
	sim2.c("player").sheet.add_efeito("teste", "resistencia", -50, "cena")
	sim2.c("bandido_1").tile = Vector2i(28, 57)
	m2[1]._cast("player", {"type": "cast", "spell": "santuario", "target": "bandido_1", "aprimoramentos": [1]}, {"cost": 0})
	var out2: Array = m2[1]._execute_action("player", a, GhostPlanner.validate_action(sim2, "player", a))
	check(out2.any(func(f): return f.type == "SANCTUARY_BLOCKED"), "com o aprimoramento, quem ataca a área faz Vontade")
	eq(sim2.c("bandido_1").sheet.pv, 999, "e, falhando, não consegue")


func test_santuario_nao_inteligentes_do_tipo_nao_percebem() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	var z: CharacterSheet = sim.c("bandido_1").sheet
	z.remove_condition("surpreendido")
	z.creature_type = "morto-vivo"
	z.attrs["int"] = -5
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "santuario", "target": "player", "aprimoramentos": [0]}).ok, "precisa escolher o tipo")
	_lanca(m, {"type": "cast", "spell": "santuario", "target": "player", "aprimoramentos": [0], "tipo_criatura": "morto-vivo"})
	var out := _ataque_planejado(m, "bandido_1", "player")
	check(out.any(func(f): return f.type == "SANCTUARY_BLOCKED" and f.payload.reason == "nao_percebe"), "o zumbi não percebe o protegido")
	check(not m[1]._pode_mirar("bandido_1", "player"), "e não o escolhe como alvo")


# --- Comando (divina, 1º círculo) -------------------------------------------------------------------
func _comandar(m: Array, alvo: String, ordem: String, extra: Dictionary = {}) -> Dictionary:
	var sim: CombatSim = m[2]
	sim.c(alvo).sheet.add_efeito("teste", "resistencia", -50, "cena")
	sim.c(alvo).sheet.remove_condition("surpreendido")
	sim.c(alvo).surprised = false
	var a := {"type": "cast", "spell": "comando", "target": alvo, "targets": [alvo], "ordem": ordem}
	a.merge(extra, true)
	return _lanca(m, a)


func test_comando_so_humanoides_e_ordem_valida() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "comando", "target": "bandido_1", "targets": ["bandido_1"]}).ok, "precisa da ordem")
	sim.c("bandido_1").sheet.creature_type = "animal"
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "comando", "target": "bandido_1", "targets": ["bandido_1"], "ordem": "pare"}).ok, "animal não, sem aprimoramento")
	check(GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "comando", "target": "bandido_1", "targets": ["bandido_1"], "ordem": "pare", "aprimoramentos": [0]}).ok, "qualquer criatura com o aprimoramento")
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "comando", "targets": ["bandido_1", "bandido_2"], "ordem": "pare", "aprimoramentos": [0]}).ok, "dois alvos pedem +1 alvo")


func test_comando_pare_deixa_pasmo_uma_vez_por_cena() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	check(_comandar(m, "bandido_1", "pare").ok, "Comando: Pare")
	var r := c._begin_turn_base("bandido_1")
	check(r.skip, "pasmo: perde o turno")
	sim.c("bandido_1").sheet.remove_condition("pasmo")
	sim.budget.std = 1
	_comandar(m, "bandido_1", "pare")
	check(not c._begin_turn_base("bandido_1").skip, "Pare só uma vez por cena")


func test_comando_senta_e_largue() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	_comandar(m, "bandido_1", "senta")
	c._begin_turn_base("bandido_1")
	check(sim.c("bandido_1").sheet.conditions.has("caido"), "sentou no chão")
	sim.budget = {"std": 1, "move": 1}
	check(not GhostPlanner.validate_action(sim, "bandido_1", {"type": "stand"}).ok, "não se levanta neste turno")
	var m2 := _cena_grupo(1)
	var c2: CombatModule = m2[1]
	var sim2: CombatSim = m2[2]
	var n_atk: int = sim2.c("bandido_2").sheet.attacks.size()
	_comandar(m2, "bandido_2", "largue")
	c2._begin_turn_base("bandido_2")
	check(sim2.c("bandido_2").sheet.attacks.size() < n_atk, "largou a arma")
	sim2.budget = {"std": 1, "move": 1}
	check(not GhostPlanner.validate_action(sim2, "bandido_2", {"type": "pegar_arma"}).ok, "não pega de novo neste turno")
	sim2.turn_counter += 1
	check(GhostPlanner.validate_action(sim2, "bandido_2", {"type": "pegar_arma"}).ok, "no próximo turno, pega")
	c2._end_combat("fuga")


func test_comando_fuja_e_venha_tomam_o_turno() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	_comandar(m, "bandido_2", "fuja")
	var d0 := CombatSim.cheb(sim.c("bandido_2").tile, sim.c("player").tile)
	c._begin_turn_base("bandido_2")
	sim.budget = {"std": 1, "move": 1}
	var cmd_t: Dictionary = sim.c("bandido_2").comando_turno
	c._turno_comando("bandido_2", str(cmd_t.ordem), str(cmd_t.conj))
	check(CombatSim.cheb(sim.c("bandido_2").tile, sim.c("player").tile) > d0, "fugiu do conjurador")
	var m2 := _cena_grupo(1)
	var sim2: CombatSim = m2[2]
	_comandar(m2, "bandido_2", "venha")
	m2[1]._begin_turn_base("bandido_2")
	sim2.budget = {"std": 1, "move": 1}
	m2[1]._turno_comando("bandido_2", "venha", "player")
	eq(CombatSim.cheb(sim2.c("bandido_2").tile, sim2.c("player").tile), 1, "veio até o conjurador")


func test_comando_resistido_ou_surdo_nao_obedece() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").sheet.add_efeito("teste", "resistencia", 99, "cena")
	_lanca(m, {"type": "cast", "spell": "comando", "target": "bandido_1", "targets": ["bandido_1"], "ordem": "pare"})
	check(not sim.tem_marca("bandido_1", "comando"), "passou na Vontade")
	sim.c("bandido_2").sheet.add_condition("surdo", m[3])
	sim.budget.std = 1
	_lanca(m, {"type": "cast", "spell": "comando", "target": "bandido_2", "targets": ["bandido_2"], "ordem": "pare"})
	check(not sim.tem_marca("bandido_2", "comando"), "surdo não ouve a ordem")


# --- Atitudes, Acalmar Animal e Tranquilidade (divinas, 1º círculo) ----------------------------
func _bandido(m: Array, id: String, vontade: int) -> CharacterSheet:
	var sh: CharacterSheet = m[2].c(id).sheet
	sh.remove_condition("surpreendido")
	m[2].c(id).surprised = false
	sh.add_efeito("teste", "resistencia", vontade, "cena")
	return sh


func test_atitudes_passo_e_diplomacia() -> void:
	eq(Atitudes.passo("hostil", 1), "inamistoso", "um passo acima")
	eq(Atitudes.passo("prestativo", 3), "prestativo", "não passa do topo")
	eq(Atitudes.resultado_diplomacia("hostil", 25, 10), "indiferente", "passou por 10: duas categorias")
	eq(Atitudes.resultado_diplomacia("indiferente", 8, 10), "indiferente", "falhou por menos de 5: nada")
	eq(Atitudes.resultado_diplomacia("indiferente", 4, 10), "inamistoso", "falhou por 5: piora")


func test_tranquilidade_falha_deixa_indiferente_e_encerra_a_luta() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	_bandido(m, "bandido_1", -50)
	_bandido(m, "bandido_2", -50)
	check(_lanca(m, {"type": "cast", "spell": "tranquilidade", "targets": ["bandido_1", "bandido_2"], "target": "bandido_1", "aprimoramentos": [1]}).ok, "dois alvos")
	eq(c.atitude_de("bandido_1"), "indiferente", "indiferente")
	var fim: Array = c._check_end()
	check(fim.any(func(f): return f.type == "COMBAT_ENDED" and f.payload.outcome == "pacificado"), "sem hostis, a luta acaba")
	eq(c.atitude_fora("bandido_1"), "indiferente", "segue calmo pela cena")
	c._check_encounter()
	check(not c.active or not c.sim.combatants.has("bandido_1") or c.atitude_de("bandido_1") == "indiferente", "não volta a atacar (se outro bandido começar a luta, ele segue calmo)")


func test_tranquilidade_resistida_da_menos_2_e_hostilidade_desfaz() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var b2 := _bandido(m, "bandido_2", 99)
	_bandido(m, "bandido_1", -50)
	sim.c("bandido_2").tile = Vector2i(27, 58)
	_lanca(m, {"type": "cast", "spell": "tranquilidade", "targets": ["bandido_1"], "target": "bandido_1"})
	sim.budget.std = 1
	_lanca(m, {"type": "cast", "spell": "tranquilidade", "targets": ["bandido_2"], "target": "bandido_2"})
	eq(b2.efeito_bonus("ataque"), -2, "resistiu: –2 nos ataques")
	_ataque_planejado(m, "player", "bandido_2")
	eq(c.atitude_de("bandido_1"), "hostil", "atacar um aliado do alvo desfaz a Tranquilidade")


func test_acalmar_animal_prestativo_bonus_e_tipos() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var b := _bandido(m, "bandido_1", -50)
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "acalmar_animal", "targets": ["bandido_1"], "target": "bandido_1"}).ok, "humanoide não é animal")
	b.creature_type = "animal"
	check(_lanca(m, {"type": "cast", "spell": "acalmar_animal", "targets": ["bandido_1"], "target": "bandido_1"}).ok, "animal")
	eq(c.atitude_de("bandido_1"), "prestativo", "prestativo")
	eq(sim.c("player").sheet.efeito_bonus_tipo("diplomacia_vs", "bandido_1"), 10, "+10 em Diplomacia contra ele")
	b.creature_type = "monstro"
	b.attrs["int"] = -4
	check(SpellRules.alvo_social_valido("acalmar_animal", [1], b), "monstro de Int –4 com o aprimoramento")
	b.attrs["int"] = 2
	check(not SpellRules.alvo_social_valido("acalmar_animal", [1], b), "monstro inteligente, não")
	check(SpellRules.alvo_social_valido("acalmar_animal", [3], b), "qualquer monstro com o de 5 PM")
	_ataque_planejado(m, "player", "bandido_1")
	eq(c.atitude_de("bandido_1"), "hostil", "atacar o animal desfaz")


func test_diplomacia_e_adestramento_em_combate() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	_bandido(m, "bandido_1", -50)
	var a := {"type": "diplomacia", "target": "bandido_1"}
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(v.ok and v.kind == "completa", "mudar atitude é ação completa")
	sim.c("player").sheet.flat_skills["diplomacia"] = 60
	c._execute_action("player", a, v)
	check(c.atitude_de("bandido_1") != "hostil", "convencido (%s)" % c.atitude_de("bandido_1"))
	sim.budget = {"std": 1, "move": 1}
	check(not GhostPlanner.validate_action(sim, "player", a).ok, "uma vez por dia")
	sim.c("bandido_2").sheet.creature_type = "animal"
	check(not GhostPlanner.validate_action(sim, "player", {"type": "adestrar", "target": "bandido_2"}).ok, "Adestramento é apenas treinada")


func test_acalmar_e_mudar_atitude_fora_de_combate() -> void:
	var w := WorldHelpers.world(5)
	var sh := CharacterBuilder.build(w.rules, "humano", "clerigo", CharacterBuilder.presets("clerigo")[0], ["for", "des", "con"], "clerigo")
	sh.spells = PackedStringArray(["tranquilidade"])
	sh.pm = 10
	w.player_sheet = sh
	var combat = w.module("combat")
	var t: Array = combat.creature_state["bandido_1"].tile
	WorldHelpers.put(w, int(t[0]) + 3, int(t[1]))
	var csh := CharacterSheet.from_dict(combat.creature_state["bandido_1"].sheet)
	csh.add_efeito("teste", "resistencia", -50, "cena")
	combat.creature_state["bandido_1"].sheet = csh.to_dict()
	var r := WorldHelpers.cmd(w, "CastSpell", {"spell": "tranquilidade", "targets": ["bandido_1"]})
	check(r.accepted, "Tranquilidade fora de combate: %s" % str(r.errors))
	eq(combat.atitude_fora("bandido_1"), "indiferente", "calmo pela cena")
	WorldHelpers.advance_hours(w, 2)
	eq(combat.atitude_fora("bandido_1"), "hostil", "a cena acaba e ele volta a ser hostil")
	check(WorldHelpers.cmd(w, "ChangeAttitude", {"target": "bandido_1"}).accepted, "Diplomacia fora de combate")
	check(not WorldHelpers.cmd(w, "ChangeAttitude", {"target": "bandido_1"}).accepted, "uma vez por dia")


# --- Armadilhas (LB p.316) e Detectar Ameaças (divina, 1º círculo) ------------------------------
func _mundo_explorador(spells: Array) -> WorldState:
	var w := WorldHelpers.world(5)
	var sh := CharacterBuilder.build(w.rules, "humano", "clerigo", CharacterBuilder.presets("clerigo")[0], ["for", "des", "con"], "clerigo")
	sh.level = 5
	sh.spells = PackedStringArray(spells)
	sh.pm = 20
	sh.pv_max = 200
	sh.pv = 200
	w.player_sheet = sh
	return w


func _anda(w: WorldState, t: Vector2i) -> GameCommand.Result:
	return WorldHelpers.cmd(w, "MovePlayer", {"to": w.db.tile_to_world(t)})


func _tipos(r: GameCommand.Result) -> Array:
	return r.emitted_events.map(func(e): return e.event_type)


func test_armadilha_dispara_uma_vez_em_quem_nao_a_conhece() -> void:
	var w := _mundo_explorador([])
	w.player_sheet.add_efeito("teste", "resistencia", -50, "cena")
	WorldHelpers.put(w, 15, 56)
	var r := _anda(w, Vector2i(16, 56))
	check(_tipos(r).has("TRAP_TRIGGERED"), "a laje dispara o virote")
	check(w.player_sheet.pv < 200 and w.player_sheet.pv >= 188, "1d10+2 de perfuração (PV %d)" % w.player_sheet.pv)
	_anda(w, Vector2i(15, 56))
	check(not _tipos(_anda(w, Vector2i(16, 56))).has("TRAP_TRIGGERED"), "já disparou")


func test_armadilha_conhecida_ou_desarmada_nao_dispara() -> void:
	var w := _mundo_explorador([])
	w.module("state").flags["armadilha_corredor_vista"] = true
	WorldHelpers.put(w, 15, 56)
	check(not _tipos(_anda(w, Vector2i(16, 56))).has("TRAP_TRIGGERED"), "quem sabe dela, contorna")
	var w2 := _mundo_explorador([])
	w2.player_sheet.trained.append("ladinagem")
	w2.player_sheet.flat_skills["ladinagem"] = 99
	WorldHelpers.put(w2, 15, 56)
	var d := WorldHelpers.cmd(w2, "InspectTarget", {"target_id": "placa_pressao", "approach": "desarmar"})
	check(d.accepted, "desarmar com Ladinagem: %s" % str(d.errors))
	check(not _tipos(_anda(w2, Vector2i(16, 56))).has("TRAP_TRIGGERED"), "desarmada")


func test_detectar_ameacas_revela_a_armadilha_e_descarrega() -> void:
	var w := _mundo_explorador(["detectar_ameacas"])
	w.player_sheet.flat_skills["percepcao"] = 99
	WorldHelpers.put(w, 8, 56)
	check(WorldHelpers.cmd(w, "CastSpell", {"spell": "detectar_ameacas"}).accepted, "lançada")
	var r := _anda(w, Vector2i(9, 56))
	check(_tipos(r).has("THREAT_DETECTED"), "a armadilha a até 18m é detectada")
	check(w.module("state").has_flag("armadilha_corredor_vista"), "sabe onde ela está")
	check(w.module("magia").detectar_ativo().is_empty(), "a magia se descarrega")


func test_detectar_ameacas_aprimoramento_protege_contra_armadilhas() -> void:
	var w := _mundo_explorador(["detectar_ameacas"])
	WorldHelpers.cmd(w, "CastSpell", {"spell": "detectar_ameacas", "aprimoramentos": [1]})
	eq(w.module("magia").bonus_contra_armadilhas(), 5, "+5 contra armadilhas")
	eq(SpellRules.aura_por_nd("1/4"), "tenue", "ND 1/4: aura tênue")
	eq(SpellRules.aura_por_nd("15"), "poderosa", "ND 15: poderosa")


func test_detectar_ameacas_percebe_criatura_hostil() -> void:
	var w := _mundo_explorador(["detectar_ameacas"])
	w.player_sheet.flat_skills["percepcao"] = 99
	var combat = w.module("combat")
	var t: Array = combat.creature_state["bandido_1"].tile
	WorldHelpers.put(w, int(t[0]) + 11, int(t[1]))
	WorldHelpers.cmd(w, "CastSpell", {"spell": "detectar_ameacas", "aprimoramentos": [0, 1]})
	var out: Array = combat._check_encounter()
	var det: Array = out.filter(func(f): return f.type == "THREAT_DETECTED")
	check(not det.is_empty(), "criatura hostil detectada")
	if not det.is_empty():
		check(det[0].payload.has("aura"), "com aura e espécie")
		check(int(combat.creature_state[str(det[0].payload.creature)].get("detectado_ate", -1)) > w.clock.tick, "não vai surpreender")


# --- Perigos (LB p.318) e Suporte Ambiental (divina, 1º círculo) ---------------------------------
func test_fumaca_densa_faz_perder_o_turno_e_dano_na_segunda_falha() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var b := _bandido(m, "bandido_1", -50)
	sim.add_zona("fumaca_teste", [Vector2i(27, 57)], "fumaca", -1, "teste")
	eq(int(sim.attack_profile("player", "bandido_1", 0, false, false).get("miss_chance", 0)), 20, "camuflagem leve dentro da fumaça")
	check(c._begin_turn_base("bandido_1").skip, "tossindo: perde o turno")
	b.remove_condition("pasmo")
	var pv0 := b.pv
	c._begin_turn_base("bandido_1")
	check(b.pv < pv0, "duas falhas seguidas: perde PV")


func test_sufocamento_prende_a_respiracao_e_depois_desmaia() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var b := _bandido(m, "bandido_1", -50)
	b.attrs["con"] = 1
	sim.c("bandido_1").flags.append("submerso")
	c._begin_turn_base("bandido_1")
	c._begin_turn_base("bandido_1")
	check(not b.conditions.has("inconsciente"), "1 + Con = 2 rodadas sem problema")
	c._begin_turn_base("bandido_1")
	check(b.conditions.has("inconsciente") and b.pv < 999, "depois, falha e desmaia perdendo PV")
	sim.c("bandido_1").flags.erase("submerso")
	c._begin_turn_base("bandido_1")
	check(not b.conditions.has("inconsciente"), "voltou a respirar")


func test_suporte_ambiental_protege_de_fumaca_e_sufocamento() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var b := _bandido(m, "bandido_1", -50)
	b.attrs["con"] = 0
	check(_lanca(m, {"type": "cast", "spell": "suporte_ambiental", "target": "bandido_1", "targets": ["bandido_1"]}).ok, "toque")
	sim.add_zona("fumaca_teste", [Vector2i(27, 57)], "fumaca", -1, "teste")
	sim.c("bandido_1").flags.append("submerso")
	for i in 4:
		check(not c._begin_turn_base("bandido_1").skip, "não tosse nem se afoga")
	check(not b.conditions.has("inconsciente"), "respira na água")


func test_calor_extremo_fere_e_suporte_ambiental_imuniza() -> void:
	var w := _mundo_explorador(["suporte_ambiental"])
	var wm = w.module("weather")
	w.player_sheet.add_efeito("teste", "resistencia", -50, "cena")
	wm.region.temp_c = 65
	var out: Array = wm.perigo_clima(w.clock.tick)
	check(out.any(func(f): return f.type == "CLIMATE_DAMAGE"), "calor extremo: testes por minuto")
	var pv := w.player_sheet.pv
	eq(w.player_sheet.curar(50), 0, "o dano do clima não cura no clima")
	wm.region.temp_c = 20
	wm.perigo_clima(w.clock.tick)
	check(w.player_sheet.curar(5) > 0, "fora do clima, cura")
	wm.region.temp_c = 65
	check(WorldHelpers.cmd(w, "CastSpell", {"spell": "suporte_ambiental"}).accepted, "Suporte Ambiental")
	eq(wm.perigo_clima(w.clock.tick).size(), 0, "imune ao clima")


# --- Abençoar Alimentos (divina, 1º círculo), comida e água benta -------------------------------
func test_abencoar_alimentos_da_bonus_ao_comer_uma_vez_por_dia() -> void:
	var w := _mundo_explorador(["abencoar_alimentos"])
	w.module("state").inventory["pao"] = 3
	check(not WorldHelpers.cmd(w, "CastSpell", {"spell": "abencoar_alimentos", "item": "corda"}).accepted, "só comida ou bebida")
	check(WorldHelpers.cmd(w, "CastSpell", {"spell": "abencoar_alimentos", "item": "pao", "aprimoramentos": [0]}).accepted, "duas porções")
	check(WorldHelpers.cmd(w, "UseItem", {"item": "pao", "bonus": "pv"}).accepted, "come o pão")
	eq(w.player_sheet.pv_temp, 5, "5 PV temporários")
	var pm := w.player_sheet.pm
	WorldHelpers.cmd(w, "UseItem", {"item": "pao", "bonus": "pm"})
	eq(w.player_sheet.pm, pm, "só um bônus de alimentação por dia")
	eq(w.module("state").item_count("pao"), 1, "comeu dois")


func test_abencoar_alimentos_porcao_fora_da_cena_nao_vale_e_pm_temporario() -> void:
	var w := _mundo_explorador(["abencoar_alimentos"])
	w.module("state").inventory["cerveja"] = 2
	WorldHelpers.cmd(w, "CastSpell", {"spell": "abencoar_alimentos", "item": "cerveja"})
	var pm := w.player_sheet.pm
	WorldHelpers.cmd(w, "UseItem", {"item": "cerveja", "bonus": "pm"})
	eq(w.player_sheet.pm, pm + 1, "1 PM temporário")
	WorldHelpers.cmd(w, "CastSpell", {"spell": "abencoar_alimentos", "item": "cerveja"})
	WorldHelpers.advance_hours(w, 3)
	check(not w.module("magia").consumir_abencoado("cerveja"), "a cena acabou: a bênção passou")


func test_abencoar_alimentos_truque_purifica_e_agua_benta() -> void:
	var w := _mundo_explorador(["abencoar_alimentos"])
	w.db.items["pao_mofado"] = {"name": "Pão mofado", "price": 0, "estragado": true, "limpo": "pao"}
	w.module("state").inventory["pao_mofado"] = 1
	var pm := w.player_sheet.pm
	check(WorldHelpers.cmd(w, "CastSpell", {"spell": "abencoar_alimentos", "item": "pao_mofado", "truque": true}).accepted, "truque")
	eq(w.player_sheet.pm, pm, "truque: 0 PM")
	eq(w.module("state").item_count("pao"), 1, "o pão mofado ficou próprio")
	w.db.items.erase("pao_mofado")
	check(not WorldHelpers.cmd(w, "CastSpell", {"spell": "abencoar_alimentos", "aprimoramentos": [1]}).accepted, "água benta precisa do frasco")
	w.module("state").inventory["frasco_agua"] = 1
	w.player.gold = 10
	check(WorldHelpers.cmd(w, "CastSpell", {"spell": "abencoar_alimentos", "aprimoramentos": [1]}).accepted, "água benta")
	eq(w.module("state").item_count("agua_benta"), 1, "frasco de água benta")
	eq(int(w.player.gold), 5, "T$ 5 de pó de prata")


func test_agua_benta_fere_morto_vivo_e_nao_os_vivos() -> void:
	var m := _cena_grupo(1)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	m[0].module("state").inventory["agua_benta"] = 2
	var mv := _bandido(m, "bandido_2", -50)
	mv.creature_type = "morto-vivo"
	var a := {"type": "agua_benta", "target": "bandido_2"}
	var out: Array = c._execute_action("player", a, GhostPlanner.validate_action(sim, "player", a))
	check(999 - mv.pv >= 2 and 999 - mv.pv <= 20, "2d10 de luz (%d)" % (999 - mv.pv))
	sim.budget.std = 1
	var a2 := {"type": "agua_benta", "target": "bandido_1"}
	c._execute_action("player", a2, GhostPlanner.validate_action(sim, "player", a2))
	eq(sim.c("bandido_1").sheet.pv, 999, "inofensiva contra os vivos")


# --- Criar Elementos (divina, 1º círculo) e luz -----------------------------------------------------
func test_criar_elementos_fogo_no_quadrado_queima_e_ilumina() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	var b := _bandido(m, "bandido_2", -50)
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "criar_elementos", "target": "player"}).ok, "precisa do elemento")
	check(_lanca(m, {"type": "cast", "spell": "criar_elementos", "target": "player", "elemento": "fogo", "tiles": [[32, 57]], "aprimoramentos": [2]}).ok, "chama no quadrado")
	check(999 - b.pv >= 2 and 999 - b.pv <= 12, "2d6 de fogo (%d)" % (999 - b.pv))
	check(b.conditions.has("em_chamas"), "falhou em Reflexos: em chamas")
	check(sim.iluminado(Vector2i(33, 57)), "a chama ilumina como uma tocha")


func test_criar_elementos_chama_na_palma_e_tocha() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	_lanca(m, {"type": "cast", "spell": "criar_elementos", "target": "player", "elemento": "fogo"})
	check(sim.iluminado(Vector2i(30, 57)), "chama na palma: luz em volta do conjurador")
	var w := _mundo_explorador([])
	w.module("state").inventory["tocha"] = 1
	check(WorldHelpers.cmd(w, "UseItem", {"item": "tocha"}).accepted, "acende a tocha")
	eq(w.module("magia").luz_ativa(), 6, "tocha: 9m de raio")
	WorldHelpers.advance_hours(w, 2)
	eq(w.module("magia").luz_ativa(), 0, "dura uma cena")


func test_criar_elementos_ar_tira_fumaca_e_afasta_nevoa() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	sim.add_zona("fumaca_t", [Vector2i(27, 57), Vector2i(28, 57)], "fumaca", -1, "teste")
	sim.add_zona("nevoa_t", [Vector2i(27, 57)], "nevoa", -1, "nevoa", {})
	check(sim.falha_nevoa("player", "bandido_1") > 0, "a névoa atrapalha")
	_lanca(m, {"type": "cast", "spell": "criar_elementos", "target": "player", "elemento": "ar", "tiles": [[27, 57]]})
	check(not sim.zona_em(Vector2i(27, 57), "fumaca"), "a fumaça saiu do quadrado")
	check(sim.zona_em(Vector2i(28, 57), "fumaca"), "só do quadrado do vento")
	eq(sim.falha_nevoa("player", "bandido_1"), 0, "o vento afasta a névoa por uma rodada")


func test_criar_elementos_arremesso_e_agua() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	var b := _bandido(m, "bandido_2", -50)
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "criar_elementos", "target": "bandido_2", "targets": ["bandido_2"], "elemento": "fogo", "aprimoramentos": [1]}).ok, "fogo não se arremessa")
	_lanca(m, {"type": "cast", "spell": "criar_elementos", "target": "bandido_2", "targets": ["bandido_2"], "elemento": "terra", "aprimoramentos": [0, 1]})
	check(999 - b.pv >= 1 and 999 - b.pv <= 10, "cubo Pequeno: 2d4 +1 passo = 1d10 (%d)" % (999 - b.pv))
	var w := _mundo_explorador(["criar_elementos"])
	check(WorldHelpers.cmd(w, "CastSpell", {"spell": "criar_elementos", "elemento": "agua"}).accepted, "água fora de combate")
	eq(w.module("state").item_count("frasco_agua"), 1, "recipiente cheio de água potável")


# --- Luz e Escuridão (universais, 1º círculo) ------------------------------------------------------
func _noite(sim: CombatSim) -> void:
	sim.env_fn = func(_t: Vector2i) -> Dictionary: return {"darkness": true, "fog": false}


func test_luz_em_objeto_carregado_tira_a_camuflagem_da_noite() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	_noite(sim)
	sim.c("bandido_2").tile = Vector2i(30, 57)
	eq(int(sim.attack_profile("player", "bandido_2", 0, false, false).get("miss_chance", 0)), 0, "corpo a corpo fora de alcance: perfil vazio")
	check(not sim.iluminado(Vector2i(30, 57)), "noite sem luz")
	check(_lanca(m, {"type": "cast", "spell": "luz", "target": "player", "targets": ["player"]}).ok, "Luz no próprio objeto")
	check(sim.iluminado(Vector2i(30, 57)), "6m de raio iluminados")
	check(not sim.iluminado(Vector2i(31, 57)), "além dos 6m, escuro")


func test_escuridao_leve_total_e_luz_natural_nao_ilumina() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	sim.c("player").sheet.add_efeito("tocha", "fonte_luz", 6, "cena")
	_lanca(m, {"type": "cast", "spell": "escuridao", "target": "player", "targets": ["player"], "tile": Vector2i(32, 57), "no_chao": true})
	check(not sim.iluminado(Vector2i(32, 57)), "a tocha não ilumina as sombras")
	sim.c("bandido_1").tile = Vector2i(32, 58)
	eq(sim.falha_escuridao("player", "bandido_1"), 20, "escuridão leve: camuflagem leve")
	var m2 := _cena_grupo(1)
	var sim2: CombatSim = m2[2]
	_lanca(m2, {"type": "cast", "spell": "escuridao", "target": "player", "targets": ["player"], "tile": Vector2i(29, 57), "no_chao": true, "aprimoramentos": [1]})
	eq(sim2.falha_escuridao("player", "bandido_2"), 50, "escuridão total bloqueia a visão através dela")


func test_luz_anula_escuridao() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	_lanca(m, {"type": "cast", "spell": "escuridao", "target": "player", "targets": ["player"], "tile": Vector2i(32, 57), "no_chao": true})
	sim.budget.std = 1
	_lanca(m, {"type": "cast", "spell": "luz", "target": "player", "targets": ["player"], "tile": Vector2i(31, 57), "no_chao": true})
	eq(sim.escuridao_em(Vector2i(32, 57)), "", "a Luz dissipou a Escuridão")


func test_luz_aprimoramentos_por_tradicao_halo_e_permanente() -> void:
	var m := _cena_grupo(5)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").side = "player"
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "luz", "target": "bandido_2", "targets": ["bandido_2"], "aprimoramentos": [3]}).ok, "olhos é só para arcanos")
	check(_lanca(m, {"type": "cast", "spell": "luz", "target": "bandido_1", "targets": ["bandido_1"], "aprimoramentos": [6]}).ok, "halo é divino")
	eq(sim.c("bandido_1").sheet.efeito_bonus("pericia_diplomacia"), 10, "+10 em Diplomacia")
	eq(sim.c("bandido_1").sheet.efeito_rd("trevas"), 10, "redução de trevas 10")
	var w := _mundo_explorador(["luz"])
	w.player.gold = 60
	check(WorldHelpers.cmd(w, "CastSpell", {"spell": "luz", "aprimoramentos": [2]}).accepted, "luz permanente")
	eq(int(w.player.gold), 10, "pó de rubi")
	WorldHelpers.advance_hours(w, 72)
	eq(w.module("magia").luz_ativa(), 4, "dura para sempre")


func test_luz_solar_estabiliza_aliados_e_ofusca_inimigos() -> void:
	var m := _cena_grupo(5)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	var b2 := _bandido(m, "bandido_2", -50)
	sim.c("bandido_2").tile = Vector2i(28, 57)
	_lanca(m, {"type": "cast", "spell": "luz", "target": "player", "targets": ["player"], "aprimoramentos": [5]})
	c._begin_turn_base("bandido_2")
	check(b2.conditions.has("ofuscado"), "inimigo na luz cálida: ofuscado")
	var p: CharacterSheet = sim.c("player").sheet
	p.add_condition("sangrando", m[3])
	c._luz_solar("player", [])
	check(not p.conditions.has("sangrando"), "aliado: imune a sangrando")


func test_escuridao_nos_olhos_e_sombras_pessoais() -> void:
	var m := _cena_grupo(5)
	var sim: CombatSim = m[2]
	var b := _bandido(m, "bandido_2", -50)
	_lanca(m, {"type": "cast", "spell": "escuridao", "target": "bandido_2", "targets": ["bandido_2"], "aprimoramentos": [2]})
	check(b.conditions.has("cego"), "falhou: cego")
	sim.budget.std = 1
	_lanca(m, {"type": "cast", "spell": "escuridao", "target": "player", "targets": ["player"], "aprimoramentos": [4]})
	eq(sim.c("player").sheet.efeito_bonus("pericia_furtividade"), 10, "+10 em Furtividade")
	eq(int(sim.attack_profile("bandido_1", "player", 0, false, false).get("miss_chance", 0)), 20, "camuflagem leve das sombras")


# --- Aviso, Compreensão e Visão Mística (universais, 1º círculo) ----------------------------------
func test_aviso_alerta_da_mais_5_no_proximo_teste_e_e_acao_de_movimento() -> void:
	var m := _cena_grupo(1)
	var sim: CombatSim = m[2]
	sim.c("bandido_1").side = "player"
	var a := {"type": "cast", "spell": "aviso", "target": "bandido_1", "targets": ["bandido_1"], "modo": "alerta"}
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(v.ok and v.kind == "movimento", "execução de movimento")
	m[1]._cast("player", a, v)
	var b: CharacterSheet = sim.c("bandido_1").sheet
	var r1 := Checks.skill(b, "percepcao", 0, m[3], m[0].rng, "combat")
	var r2 := Checks.skill(b, "percepcao", 0, m[3], m[0].rng, "combat")
	eq(int(r1.mod) - int(r2.mod), 5, "+5 só no próximo teste de Percepção")
	sim.c("bandido_2").tile = Vector2i(26 + 500, 57)
	check(not GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "aviso", "target": "bandido_2", "targets": ["bandido_2"]}).ok, "750m: além do alcance longo")
	check(GhostPlanner.validate_action(sim, "player", {"type": "cast", "spell": "aviso", "target": "bandido_2", "targets": ["bandido_2"], "aprimoramentos": [0]}).ok, "x10 com o aprimoramento")


func test_aviso_fora_de_combate_mensagem_com_resposta() -> void:
	var w := _mundo_explorador(["aviso"])
	var r := WorldHelpers.cmd(w, "CastSpell", {"spell": "aviso", "targets": ["dorn"], "modo": "mensagem", "texto": "Estou indo.", "aprimoramentos": [1]})
	check(r.accepted, "mensagem telepática: %s" % str(r.errors))
	var ev: Array = r.emitted_events.filter(func(e): return e.event_type == "WARNING_SENT")
	check(not ev.is_empty() and ev[0].payload.has("resposta"), "com resposta")
	WorldHelpers.cmd(w, "CastSpell", {"spell": "aviso", "modo": "alerta"})
	eq(w.player_sheet.efeito_bonus("proxima_percepcao"), 5, "alerta em si mesmo")


func test_compreensao_ouvir_e_vasculhar_pensamentos_revela_o_que_o_npc_sabe() -> void:
	var w := _mundo_explorador(["compreensao"])
	var npcs = w.module("npcs")
	var loc: String = npcs.npc("dorn").location
	var spot := w.db.location_spot(loc)
	WorldHelpers.put(w, spot.x, spot.y)
	check(w.module("magia").fatos_que_sabe("dorn").has("f_dorn_informante"), "Dorn sabe que é informante")
	check(WorldHelpers.cmd(w, "CastSpell", {"spell": "compreensao", "targets": ["dorn"]}).accepted, "toca o Dorn")
	var ex = w.module("exploration")
	var antes: int = ex.known_facts.size()
	var r := WorldHelpers.cmd(w, "ReadThoughts", {"target": "dorn"})
	check(r.accepted, "ouvir pensamentos")
	check(ex.known_facts.size() == antes + 1 or r.emitted_events.any(func(e): return e.event_type == "SPELL_MISSED"), "um fato novo (ou ele protegeu os pensamentos)")
	var w2 := _mundo_explorador(["compreensao"])
	w2.player_sheet.flat_skills["vontade"] = 0
	var spot2 := w2.db.location_spot(w2.module("npcs").npc("dorn").location)
	WorldHelpers.put(w2, spot2.x, spot2.y)
	w2.player_sheet.attrs["sab"] = 20
	WorldHelpers.cmd(w2, "CastSpell", {"spell": "compreensao", "targets": ["dorn"], "aprimoramentos": [2]})
	check(w2.module("exploration").knows("f_dorn_informante") and w2.module("exploration").knows("f_bandidos_na_ruina"), "vasculhar: tudo o que ele sabe")


func test_visao_mistica_auras_e_analise_e_detectar_magia() -> void:
	var m := _cena_grupo(5)
	var c: CombatModule = m[1]
	var sim: CombatSim = m[2]
	_lanca(m, {"type": "cast", "spell": "bencao", "targets": ["player"], "target": "player"})
	sim.budget = {"std": 1, "move": 1}
	var out: Array = m[1]._cast("player", {"type": "cast", "spell": "visao_mistica", "target": "player", "aprimoramentos": [0]}, {"cost": 0})
	var aur: Array = out.filter(func(f): return f.type == "MAGIC_AURAS")
	check(not aur.is_empty() and (aur[0].payload.auras as Array).any(func(x): return x.get("magia", "") == "bencao"), "vê a Bênção com todas as informações")
	check(sim.c("player").sheet.efeito_bonus("visao_escuro") > 0, "visão no escuro")
	var a := {"type": "analisar_aura", "target": "bandido_1"}
	var v := GhostPlanner.validate_action(sim, "player", a)
	check(v.ok and v.kind == "movimento", "analisar é ação de movimento")
	var o2: Array = c._execute_action("player", a, v)
	check(o2.any(func(f): return f.type == "AURA_ANALYZED" and not f.payload.lanca_magias), "o bandido não lança magias")
	sim.budget = {"std": 1, "move": 1}
	check(not GhostPlanner.validate_action(sim, "player", {"type": "detectar_magia"}).ok, "Misticismo é somente treinada")
	sim.c("player").sheet.trained.append("misticismo")
	check(GhostPlanner.validate_action(sim, "player", {"type": "detectar_magia"}).ok, "treinado: ação completa")
