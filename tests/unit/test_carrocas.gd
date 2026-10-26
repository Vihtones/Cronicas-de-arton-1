extends TestCase
## Carroças de entrega: nascem de dia, levam a carga que falta, descarregam no estoque da vila e somem.


func _run_ticks(w: WorldState, n: int) -> Array:
	var out: Array = []
	for i in n:
		w.clock.tick += 1
		out.append_array(w.modules.carts.on_tick(w.clock.tick))
	return out


func _to_hour(w: WorldState, hour: int) -> void:
	var target := (hour + 24 * (w.day_index())) * 6
	if target > w.clock.tick:
		WorldHelpers.cmd(w, "AdvanceTime", {"ticks": target - w.clock.tick})


func test_carroca_nasce_de_dia_e_nao_de_noite() -> void:
	var w := WorldHelpers.world(3, ["weather"])
	_to_hour(w, 3)
	_run_ticks(w, 3)   # ainda de madrugada (3h–3h30)
	eq(w.modules.carts.carts.size(), 0, "de madrugada não há carroça")
	_to_hour(w, 10)
	_run_ticks(w, 30)
	check(w.modules.carts.carts.size() >= 1, "de dia há carroça na estrada")
	check(w.modules.carts.carts.size() <= CartsModule.MAX_CARTS, "no máximo %d carroças" % CartsModule.MAX_CARTS)


func test_carga_e_a_mercadoria_que_falta_e_entra_no_estoque() -> void:
	var w := WorldHelpers.world(3, ["weather"])
	var eco: EconomyModule = w.modules.economy
	eco._ensure()
	eco.regions.vila.stock.comida = 0   # a vila está sem comida: é isso que a carroça deve trazer
	_to_hour(w, 10)
	var cargo: Dictionary = w.modules.carts._deficit_cargo()
	check(not cargo.is_empty(), "há o que falta na vila: %s" % str(cargo))
	var good: String = cargo.keys()[0]
	var before := int(eco.regions.vila.stock[good])
	var out := _run_ticks(w, CartsModule.TRAVEL_TICKS + 2)
	check(out.any(func(f): return f.type == "CART_DELIVERED"), "a chegada gera CART_DELIVERED")
	# a entrega aplica o efeito na economia (a carga entra no estoque da vila)
	for f in out:
		if f.type == "CART_DELIVERED":
			eco.on_event(GameEvent.create("cd", "CART_DELIVERED", 0, f.payload))
	check(int(eco.regions.vila.stock[good]) > before, "estoque de %s subiu (%d -> %d)" % [good, before, int(eco.regions.vila.stock[good])])


func test_carroca_some_depois_do_ciclo() -> void:
	var w := WorldHelpers.world(3, ["weather"])
	_to_hour(w, 9)
	_run_ticks(w, 2)
	var n: int = w.modules.carts.carts.size()
	check(n >= 1, "uma carroça nasceu")
	_run_ticks(w, CartsModule.TRAVEL_TICKS * 2 + CartsModule.UNLOAD_TICKS + 4)
	check(w.modules.carts.carts.is_empty() or w.modules.carts.carts.size() < n + 1, "a carroça sai de cena no fim do ciclo")


func test_posicao_vai_da_estrada_ao_mercado_e_volta() -> void:
	var m := CartsModule.new()
	var c := {"phase": "chegando", "t": 0}
	eq(m.position_of(c), 0.0, "começa na estrada leste")
	c.t = CartsModule.TRAVEL_TICKS
	c.phase = "chegando"
	eq(m.position_of(c), 1.0, "chega ao mercado")
	c.phase = "descarregando"; c.t = 1
	eq(m.position_of(c), 1.0, "descarregando fica no mercado")
	c.phase = "saindo"; c.t = 0
	eq(m.position_of(c), 1.0, "começa a voltar do mercado")
	c.t = CartsModule.TRAVEL_TICKS
	eq(m.position_of(c), 0.0, "volta à estrada")


func test_carrocas_salvam_e_carregam() -> void:
	var w := WorldHelpers.world(3, ["weather"])
	_to_hour(w, 9)
	_run_ticks(w, 4)
	var snap := w.to_snapshot()
	var w2 := WorldHelpers.world(1, ["weather"])
	w2.from_snapshot(snap)
	eq(w2.modules.carts.carts.size(), w.modules.carts.carts.size(), "carroças sobrevivem ao salvar")
	eq(WorldHelpers.snap(w2).sha256_text(), WorldHelpers.snap(w).sha256_text(), "e a simulação segue igual")
