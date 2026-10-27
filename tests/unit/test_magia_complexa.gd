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
	var sim: CombatSim = _cena()[2]
	var sem := sim.step_cost(Vector2i(26, 57), Vector2i(27, 57))
	sim.add_zona("z", [Vector2i(27, 57)], "terreno_dificil", 2, "teste")
	eq(sim.step_cost(Vector2i(26, 57), Vector2i(27, 57)), sem * 2, "dentro da zona custa o dobro")
	check(sim.zona_em(Vector2i(27, 57), "terreno_dificil"), "zona marcada no quadrado")


func test_zona_expira_depois_das_rodadas_e_zona_permanente_nao() -> void:
	var sim: CombatSim = _cena()[2]
	sim.add_zona("temp", [Vector2i(3, 3)], "terreno_dificil", 2, "teste")
	sim.add_zona("perm", [Vector2i(4, 4)], "terreno_dificil", -1, "teste")
	sim._passar_rodada()
	check(sim.zona_em(Vector2i(3, 3), "terreno_dificil"), "ainda vale depois de 1 rodada")
	sim._passar_rodada()
	check(not sim.zona_em(Vector2i(3, 3), "terreno_dificil"), "sai depois de 2 rodadas")
	check(sim.zona_em(Vector2i(4, 4), "terreno_dificil"), "zona sem fim automático continua")


func test_clone_copia_zonas() -> void:
	var sim: CombatSim = _cena()[2]
	sim.add_zona("z", [Vector2i(9, 9)], "terreno_dificil", 3, "teste")
	var g := sim.clone()
	check(g.zona_em(Vector2i(9, 9), "terreno_dificil"), "o clone (usado pelo planejamento) tem a zona")
	g.remove_zona("z")
	check(sim.zona_em(Vector2i(9, 9), "terreno_dificil"), "remover no clone não mexe na simulação real")


# --- Marcas --------------------------------------------------------------------------------
func test_marca_expira_e_fica_registrada() -> void:
	var sim: CombatSim = _cena()[2]
	sim.add_marca("maldicao_x", "bandido_1", "teste", "maldicao", 1)
	check(sim.tem_marca("bandido_1", "maldicao"), "marca ativa")
	sim._passar_rodada()
	check(not sim.tem_marca("bandido_1", "maldicao"), "acabou")
	check(sim.expiradas.has("maldicao_x"), "o fim fica registrado para a apresentação")


func test_ids_em_area_pega_so_criaturas_conscientes() -> void:
	var sim: CombatSim = _cena()[2]
	eq(sim.ids_em([Vector2i(27, 57)]), ["bandido_1"], "criatura no quadrado")
	sim.c("bandido_1").sheet.pv = -20
	eq(sim.ids_em([Vector2i(27, 57)]).size(), 0, "caída não entra")


# --- Invocações ----------------------------------------------------------------------------
func test_invocacao_entra_do_lado_do_conjurador_e_expira() -> void:
	var c: CombatModule = _cena()[1]
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
	var sim: CombatSim = _cena()[2]
	sim.order = ["player", "bandido_1"]
	sim.turn_idx = 1
	sim.remove_combatant("player")
	eq(sim.turn_idx, 0, "a vez de quem agia continua a mesma")
	eq(sim.order, ["bandido_1"], "ordem sem o removido")


# --- PV temporários ------------------------------------------------------------------------
func test_pv_temporario_absorve_dano_antes_dos_pv() -> void:
	var sim: CombatSim = _cena()[2]
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
	var c: CombatModule = _cena()[1]
	c.sim.add_zona("z", [Vector2i(9, 9)], "terreno_dificil", 2, "teste")
	c.sim.add_marca("m", "bandido_1", "teste", "maldicao", 2)
	var d := c.to_dict()
	eq((d.sim.zonas as Array).size(), 1, "zona salva")
	eq((d.sim.marcas as Array).size(), 1, "marca salva")


