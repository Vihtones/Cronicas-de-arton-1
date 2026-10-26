extends TestCase
## Arton Viva, Fase 2 (sociedade): a família sustenta as crianças; a reputação de um grupo muda o preço de
## todos os seus vendedores (consequência por grupo, não por indivíduo).


func _world() -> WorldState:
	var w := WorldHelpers.world(3)
	w.clock.tick = 8 * 6
	return w


func _memoria(w: WorldState, npc: String, valence: int) -> void:
	w.modules.memory.add_memory(npc, {"key": "fato_%s_%d" % [npc, valence], "about": "player", "subject": "",
		"valence": valence, "location": "", "tick": 0, "emotion": "raiva" if valence < 0 else "gratidao",
		"reliability": 1.0, "source": "visto", "durable": true, "text": "ato do jogador"})


func test_crianca_sem_ouro_recebe_refeicao_da_familia() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.lisel = {"hunger": 0.9, "tired": 0.1, "gold": 0, "goal": "", "medium": "", "long": "", "shift": 0}
	nd.state.otto = {"hunger": 0.1, "tired": 0.1, "gold": 10, "goal": "", "medium": "", "long": "", "shift": 0}
	var facts := nd.on_tick(w.clock.tick)
	var apoio := facts.filter(func(f): return f.type == "FAMILY_SUPPORT")
	eq(apoio.size(), 1, "criança com fome e sem ouro gera FAMILY_SUPPORT")
	if apoio.size() == 1:
		eq(str(apoio[0].payload.to), "lisel", "o apoio vai para a criança")
	check(nd.gold("lisel") >= NpcNeedsModule.MEAL_COST, "a criança fica com ouro para a refeição")
	eq(nd.gold("otto"), 10 - NpcNeedsModule.MEAL_COST, "o adulto paga do próprio ouro")


func test_adulto_sem_reserva_nao_paga_a_refeicao() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.lisel = {"hunger": 0.9, "tired": 0.1, "gold": 0, "goal": "", "medium": "", "long": "", "shift": 0}
	nd.state.otto = {"hunger": 0.1, "tired": 0.1, "gold": 2, "goal": "", "medium": "", "long": "", "shift": 0}
	nd.state.hilda = {"hunger": 0.1, "tired": 0.1, "gold": 3, "goal": "", "medium": "", "long": "", "shift": 0}
	eq(nd.family_payer("lisel"), "", "adultos com pouco ouro não pagam (sem reserva)")


func test_crianca_com_ouro_paga_a_propria_refeicao() -> void:
	var w := _world()
	var nd: NpcNeedsModule = w.modules.npc_needs
	nd.state.lisel = {"hunger": 0.9, "tired": 0.1, "gold": 5, "goal": "", "medium": "", "long": "", "shift": 0}
	var facts := nd.on_tick(w.clock.tick)
	check(not facts.any(func(f): return f.type == "FAMILY_SUPPORT"), "com ouro próprio, não pede à família")


func test_reputacao_do_grupo_muda_o_preco_de_todos_os_vendedores() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	var base := eco.price("pocao_cura", "vila", "ysolde")
	_memoria(w, "ysolde", -60)
	_memoria(w, "lucan", -60)
	check(eco.price("pocao_cura", "vila", "ysolde") > base, "o templo hostil cobra mais (ysolde): %d > %d" % [eco.price("pocao_cura", "vila", "ysolde"), base])


func test_grupo_amigo_faz_desconto() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	var base := eco.price("pocao_cura", "vila", "ysolde")
	_memoria(w, "ysolde", 60)
	_memoria(w, "lucan", 60)
	check(eco.price("pocao_cura", "vila", "ysolde") < base, "o templo amigo faz desconto")


func test_vendedor_de_outro_grupo_nao_e_afetado() -> void:
	var w := _world()
	var eco: EconomyModule = w.modules.economy
	var base := eco.price("pao", "vila", "rosana")
	_memoria(w, "ysolde", -60)
	_memoria(w, "lucan", -60)
	eq(eco.price("pao", "vila", "rosana"), base, "a taverneira (sem facção) segue o preço normal")
