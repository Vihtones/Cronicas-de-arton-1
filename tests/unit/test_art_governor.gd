extends TestCase
## Governador de Direção de Arte: só assets aprovados entram, nas zonas certas, sem mexer na colisão.


func _gov() -> ArtGovernor:
	return ArtGovernor.load_default()


func test_governador_carrega_registro_da_pasta_de_arte() -> void:
	var g := _gov()
	eq(g.direction.identidade.nome, "Beleza Marcada")
	eq(g.report().aprovados, 20, "os 20 componentes LPC Jungle aprovados")
	eq(g.report().recusados, 0)
	eq(g.direction.curadoria.totais.aprovada, 6)


func test_placeholders_nao_sao_assets_aprovados() -> void:
	var g := _gov()
	check(not g.is_buildable("tileset_base"), "placeholder não passa pelo governador")


func test_asset_sem_aprovacao_ou_creditos_e_recusado() -> void:
	var g := ArtGovernor.new()
	var d := _gov().direction.duplicate(true)
	var a := {"asset_id": "x", "estado": "approved_artistic", "aprovacao": "APR-2026-10-23-LPC-JUNGLE",
		"licenca": "CC-BY-4.0", "creditos": "", "origem": "pasta", "zonas_permitidas": ["floresta"]}
	var b := a.duplicate(); b.asset_id = "y"; b.creditos = "c.txt"; b.origem = "09_sprites_tormenta20/outputs/a.png"
	d.aprovacoes[0].assets.append_array(["x", "y"])
	g.load_from(d, {"assets": [a, b]})
	check(not g.is_buildable("x"), "CC-BY sem créditos")
	check(not g.is_buildable("y"), "acervo Tormenta20 não é promovido automaticamente")


func test_vegetacao_de_selva_nao_vai_para_a_vila() -> void:
	var g := _gov()
	check(g.assets_for("floresta.arvore", "vila").is_empty(), "AD-07")
	check(not g.assets_for("floresta.arvore", "floresta").is_empty(), "floresta tem árvores")


func test_plano_respeita_colisao_e_e_deterministico() -> void:
	var db := ContentDB.load_default()
	var g := _gov()
	var p := VegetationLayer.plan(db, g)
	check(p.size() > 100, "floresta vestida")
	eq(p, VegetationLayer.plan(db, g), "mesmo plano a cada carga")
	var trees := 0
	for e in p:
		check(db.zone_at(e.tile) in ["floresta", "estrada"], "só na floresta e na estrada que a cruza")
		check(g.is_buildable(e.asset_id), "só aprovados")
		if e.role == "floresta.chao_decorativo":
			check(db.static_walkable(e.tile), "decoração só em chão andável")
		else:
			eq(db.tile_char(e.tile), "T", "árvore/sub-bosque só sobre tile bloqueado (AD-09)")
			if e.role == "floresta.arvore":
				trees += 1
	check(trees > 20, "árvores aprovadas presentes")


func test_arvores_espacadas_deixam_respiro() -> void:
	var p := VegetationLayer.plan(ContentDB.load_default(), _gov())
	var ts: Array[Vector2i] = []
	for e in p:
		if e.role == "floresta.arvore":
			ts.append(e.tile)
	for i in ts.size():
		for j in range(i + 1, ts.size()):
			var d: Vector2i = ts[i] - ts[j]
			check(maxi(absi(d.x), absi(d.y)) > 2, "AD-11: árvores a mais de 2 tiles")


func test_trilhas_ficam_limpas() -> void:
	var db := ContentDB.load_default()
	for e in VegetationLayer.plan(db, _gov()):
		if e.role == "floresta.chao_decorativo":
			check(not VegetationLayer._near_path(db, e.tile), "AD-10")


func test_copas_nao_cobrem_trilhas() -> void:
	var db := ContentDB.load_default()
	var g := _gov()
	for e in VegetationLayer.plan(db, g):
		if e.role == "floresta.arvore":
			check(not VegetationLayer._covers_path(db, e.tile, g.assets[e.asset_id]), "AD-10 em " + str(e.tile))
