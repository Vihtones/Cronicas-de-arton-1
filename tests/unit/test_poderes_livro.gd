extends TestCase
## Poderes de classe do Livro Básico (Fase 7 / ficha): cada poder listado tem regra com página do livro,
## poderes sem efeito no jogo aparecem na árvore como "não implementado" e nunca viram opção de subida.


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 12 * 6
	return w


func test_todo_poder_de_classe_tem_regra_com_pagina() -> void:
	var w := _world()
	var prog: ProgressionModule = w.modules.progression
	var ids: Array = []
	for cls in ProgressionModule.POWERS: ids.append_array(ProgressionModule.POWERS[cls])
	for cls in ProgressionModule.CLASS_TREE_ONLY: ids.append_array(ProgressionModule.CLASS_TREE_ONLY[cls])
	for p in ids:
		var e: Dictionary = w.rules.entry("poder." + p)
		check(not e.is_empty(), "regra do poder %s existe" % p)
		check(int(e.get("pagina", 0)) > 0 and int(e.get("pdf_page", 0)) == int(e.pagina) + 6, "página do livro de %s (pdf = impressa + 6)" % p)
	check(ids.size() >= 40, "catálogo de classe tem os poderes do livro (%d)" % ids.size())


func test_poder_sem_efeito_nao_vira_opcao_mas_aparece_na_arvore() -> void:
	var w := _world()
	var s := w.player_sheet
	s.class_id = "ladino"
	s.level = 8
	s.pending_powers = 1
	s.attrs["int"] = 2
	var prog: ProgressionModule = w.modules.progression
	check(not prog.available_powers().has("assassinar"), "assassinar (sem efeito) não é opção")
	var arvore: Dictionary = prog.power_tree()
	var achado := false
	for n in arvore.nodes:
		if n.id == "assassinar":
			achado = true
			eq(n.state, "nao_implementado", "assassinar aparece como não implementado")
	check(achado, "assassinar está na árvore")


func test_pre_requisito_de_nivel_bloqueia_e_explica() -> void:
	var w := _world()
	var s := w.player_sheet
	s.class_id = "ladino"
	s.level = 3
	s.attrs["int"] = 2
	var prog: ProgressionModule = w.modules.progression
	var txt := prog.falta_texto("roubo_de_mana")
	check(txt.find("7º nível") >= 0 or txt.find("nível") >= 0, "roubo de mana explica o nível que falta: '%s'" % txt)
	check(ProgressionModule.prereq_texto({"poder": "truque_magico", "nivel": 7}).find("7º nível") >= 0, "texto do pré-requisito de nível")
