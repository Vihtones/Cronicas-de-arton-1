extends TestCase
## Núcleo do combate em tempo real: custo por categoria, orçamento e relógio parado no planejamento.


func test_custo_por_categoria_segue_a_decisao() -> void:
	var p := RealtimePlan.new()
	eq(p.custo_do_kind("movimento"), 1, "andar custa 1 por quadrado")
	eq(p.custo_do_kind("padrao"), 2, "ação padrão custa 2")
	eq(p.custo_do_kind("completa"), 3, "ação completa custa 3")
	eq(p.custo_do_kind("livre"), 0, "ação livre não custa")


func test_movimento_cobra_por_quadrado() -> void:
	var p := RealtimePlan.new()
	check(p.adicionar_movimento(3), "andar 3 quadrados cabe no orçamento")
	eq(p.custo_total(), 3, "3 quadrados custam 3 pontos")


func test_orcamento_nao_deixa_estourar() -> void:
	var p := RealtimePlan.new()
	check(p.adicionar("completa"), "primeira completa cabe")
	check(p.adicionar("padrao"), "padrão cabe (5 de 8)")
	check(p.adicionar("padrao"), "segunda padrão cabe (7 de 8)")
	check(not p.adicionar("padrao"), "terceira padrão estoura (9 de 8): recusada")
	eq(p.custo_total(), 7, "o plano não passou do orçamento")


func test_ritual_e_um_passo_so_com_a_categoria_dela() -> void:
	var p := RealtimePlan.new()
	check(p.adicionar_ritual("completa", {"magia": "terremoto"}), "ritual cabe")
	eq(p.passos.size(), 1, "ritual vira um único passo")
	eq(p.custo_total(), 3, "custa a categoria dela (completa)")


func test_tempo_parado_durante_o_planejamento() -> void:
	var p := RealtimePlan.new()
	p.alternar_planejamento()
	eq(p.avancar(5.0), 0.0, "com o tempo parado o mundo não avança")
	eq(p.relogio, 0.0, "o relógio não anda")
	p.alternar_planejamento()
	eq(p.avancar(2.0), 2.0, "ao executar, o tempo anda em tempo real")
	eq(p.relogio, 2.0, "o relógio andou")


func test_limpar_zera_o_plano_sem_mexer_no_orcamento() -> void:
	var p := RealtimePlan.new()
	p.adicionar("padrao")
	p.limpar()
	eq(p.custo_total(), 0, "limpar zera o custo")
	eq(p.orcamento, RealtimePlan.ORCAMENTO_PADRAO, "orçamento continua o padrão")
