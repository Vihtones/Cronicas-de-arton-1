extends TestCase
## G2 (O4): suíte curta para os módulos sem teste próprio: items, region_sim e carts.


func test_equipar_item_desconhecido_e_recusado() -> void:
	var w := WorldHelpers.world(5)
	check(not WorldHelpers.cmd(w, "Equip", {"item": "nao_existe"}).accepted, "item desconhecido não equipa")


func test_equipar_arma_emite_evento_e_troca_o_slot() -> void:
	var w := WorldHelpers.world(5)
	var item: String = ItemsModule.EQUIPPABLE.keys()[0]
	w.modules.state.inventory[item] = 1
	var r := WorldHelpers.cmd(w, "Equip", {"item": item})
	check(r.accepted, "item do inventário equipa")
	eq(WorldHelpers.events_of(r, "EQUIPPED").size(), 1, "emite EQUIPPED")


func test_regiao_guarda_historico_e_sobrevive_ao_save() -> void:
	var w := WorldHelpers.world(5)
	var m = w.modules.region_sim
	m.history.append({"day": 1, "region": "valkaria"})
	var d: Dictionary = m.to_dict()
	var novo = RegionSimModule.new()
	novo.from_dict(d)
	eq(novo.history.size(), 1, "histórico volta do save")
	eq(str(novo.history[0].region), "valkaria", "conteúdo preservado")


func test_carroca_sobrevive_ao_save() -> void:
	var w := WorldHelpers.world(5)
	var m = w.modules.carts
	m.carts.append({"id": 3, "phase": "saindo", "t": 4, "cargo": {"comida": 12}, "delivered": false})
	m._next_id = 4
	var d: Dictionary = m.to_dict()
	var novo = CartsModule.new()
	novo.from_dict(d)
	eq(novo.carts.size(), 1, "carroça volta do save")
	eq(int(novo.carts[0].t), 4, "progresso preservado")
	eq(int(novo._next_id), 4, "próximo id preservado")
	eq(int(novo.carts[0].cargo.comida), 12, "carga preservada")
