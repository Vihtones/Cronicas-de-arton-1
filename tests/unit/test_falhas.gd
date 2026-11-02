extends TestCase
## Falha crítica (1 natural no ataque): tabela de consequências com efeito e texto próprios.


func _crypt() -> WorldState:
	var w := WorldHelpers.world(5)
	w.modules.combat._start(["bandido_1"], true, false)
	return w


func test_tabela_tem_seis_resultados_com_texto() -> void:
	eq(FumbleTable.OUTCOMES.size(), 6, "seis resultados, um para cada face do d6")
	var ids := {}
	for o in FumbleTable.OUTCOMES:
		check(str(o.titulo) != "" and str(o.texto) != "", "resultado %s tem título e texto" % o.id)
		ids[o.id] = true
	eq(ids.size(), 6, "ids únicos")


func test_sorteio_fica_na_tabela() -> void:
	var rng := RngStreams.new(11)
	for i in 30:
		var o := FumbleTable.pick(rng)
		check(FumbleTable.OUTCOMES.has(o), "sorteio devolve um resultado da tabela")


func test_tropeco_deixa_o_atacante_caido() -> void:
	var w := _crypt()
	var sim: CombatSim = w.modules.combat.sim
	var tropeca := FumbleTable.OUTCOMES[0]
	FumbleTable.apply(sim, "player", tropeca)
	check(sim.c("player").sheet.conditions.has("caido"), "tropeço derruba o atacante")


func test_arma_que_escapa_perde_a_acao_padrao() -> void:
	var w := _crypt()
	var sim: CombatSim = w.modules.combat.sim
	var antes: int = int(sim.budget.std)
	FumbleTable.apply(sim, "player", FumbleTable.OUTCOMES[1])
	eq(int(sim.budget.std), antes - 1, "gasta a ação padrão")
