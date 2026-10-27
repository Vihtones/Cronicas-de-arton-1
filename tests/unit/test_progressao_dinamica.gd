extends TestCase
## Progressão dinâmica (Arton Viva, Fase 6 / ficha): XP sem teto, o que falta para cada poder, detalhes na escolha.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 12 * 6
	return w


func test_curva_de_xp_bate_com_a_tabela_e_continua_depois() -> void:
	var w := _world()
	var prog: ProgressionModule = w.modules.progression
	eq(prog.xp_do_nivel(2), 1000, "nível 2 pela tabela")
	eq(prog.xp_do_nivel(10), 45000, "nível 10 pela tabela")
	eq(prog.xp_do_nivel(11), 55000, "nível 11 pela curva (sem teto)")
	eq(prog.xp_do_nivel(12), 66000, "nível 12 pela curva (sem teto)")


func test_sobe_alem_do_nivel_10() -> void:
	var w := _world()
	var s := w.player_sheet
	var prog: ProgressionModule = w.modules.progression
	s.level = 10
	s.xp = 54999
	var out: Array = prog.ganha_xp(1, "teste")
	eq(s.level, 11, "com XP suficiente, sobe do nível 10 para o 11")
	check(out.any(func(f): return f.type == "LEVEL_UP"), "o salto gera LEVEL_UP")


func test_falta_texto_aponta_o_atributo_que_falta() -> void:
	var w := _world()
	var s := w.player_sheet
	var prog: ProgressionModule = w.modules.progression
	s.attrs["for"] = 0
	check(prog.falta_texto("ataque_poderoso").contains("FOR 1"), "sem FOR 1, o texto diz o que falta: %s" % prog.falta_texto("ataque_poderoso"))
	s.attrs["for"] = 1
	eq(prog.falta_texto("ataque_poderoso"), "", "com FOR 1, nada falta")


func test_detalhes_do_poder_chegam_a_escolha() -> void:
	var w := _world()
	var prog: ProgressionModule = w.modules.progression
	var info: Dictionary = prog.power_info("ataque_poderoso")
	check(str(info.efeito) != "", "o poder tem efeito descrito")
	eq(int(info.pagina), 124, "o poder cita a página do livro")


func test_arvore_mostra_o_que_falta_nos_bloqueados() -> void:
	var w := _world()
	var s := w.player_sheet
	var prog: ProgressionModule = w.modules.progression
	s.attrs["for"] = 0
	var bloqueado: Array = prog.power_tree().nodes.filter(func(n): return n.id == "ataque_poderoso")
	check(not bloqueado.is_empty(), "o nó existe na árvore")
	if not bloqueado.is_empty():
		eq(bloqueado[0].state, "bloqueado", "sem o atributo, o nó está bloqueado")
		check(str(bloqueado[0].falta).contains("FOR"), "o nó bloqueado diz o que falta")


func test_xp_pelo_debug_sobe_de_nivel_pelo_caminho_normal() -> void:
	var w := _world()
	w.player_sheet.xp = 0
	var r = WorldHelpers.cmd(w, "DebugSet", {"key": "xp", "value": 1000})
	check(r.accepted, "debug aceita a variável xp: %s" % str(r.errors))
	check(WorldHelpers.events_of(r, "LEVEL_UP").size() >= 1, "o XP de debug gera LEVEL_UP")
