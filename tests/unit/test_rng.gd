extends TestCase


func test_mesma_seed_reproduz() -> void:
	var a := RngStreams.new(123)
	var b := RngStreams.new(123)
	eq(a.roll("combat", 10, 20), b.roll("combat", 10, 20), "mesma sequência")


func test_fluxo_visual_nao_altera_combate() -> void:
	var a := RngStreams.new(7)
	var b := RngStreams.new(7)
	b.roll("visual", 50, 100)
	eq(a.roll("combat", 5, 20), b.roll("combat", 5, 20), "fluxos independentes")


func test_estado_salvo_continua_sequencia() -> void:
	var a := RngStreams.new(99)
	a.roll("world", 3, 6)
	var b := RngStreams.new(0)
	b.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	eq(a.roll("world", 5, 6), b.roll("world", 5, 6), "continua após load")
