extends TestCase
## G2 (O3): um teste para cada comando que não tinha cobertura (UseItem, CastSpell, GrantDomain, MarkHypothesis).


func test_usar_pocao_cura_e_consome_o_item() -> void:
	var w := WorldHelpers.world(5)
	w.modules.state.inventory["pocao_cura"] = 1
	w.player_sheet.pv_max = 20
	w.player_sheet.pv = 1
	var r := WorldHelpers.cmd(w, "UseItem", {"item": "pocao_cura"})
	check(r.accepted, "poção aceita fora de combate")
	check(w.player_sheet.pv > 1, "poção cura PV")
	eq(w.modules.state.item_count("pocao_cura"), 0, "poção é consumida")
	check(not WorldHelpers.cmd(w, "UseItem", {"item": "pocao_cura"}).accepted, "sem poção, recusa")


func test_lancar_magia_de_cura_gasta_pm_e_cura() -> void:
	var w := WorldHelpers.world(5)
	w.player_sheet.spells = PackedStringArray(["curar_ferimentos"])
	w.player_sheet.pm = 5
	w.player_sheet.pv_max = 20
	w.player_sheet.pv = 1
	var r := WorldHelpers.cmd(w, "CastSpell", {"spell": "curar_ferimentos"})
	check(r.accepted, "magia de cura conhecida é aceita")
	eq(w.player_sheet.pm, 4, "custa 1 PM (1º círculo)")
	check(w.player_sheet.pv > 1, "cura PV")
	check(not WorldHelpers.cmd(w, "CastSpell", {"spell": "bola_de_fogo"}).accepted, "magia não conhecida é recusada")


func test_concedir_dominio_registra_fato() -> void:
	var w := WorldHelpers.world(5)
	var r := WorldHelpers.cmd(w, "GrantDomain", {"by": "orin"})
	check(r.accepted, "concessão aceita")
	eq(WorldHelpers.events_of(r, "GRANT_DOMAIN").size(), 1, "emite GRANT_DOMAIN")


func test_marcar_hipotese_guarda_o_estado() -> void:
	var w := WorldHelpers.world(5)
	var ex = w.modules.exploration
	ex._ensure()
	var h: String = ex.hypotheses.keys()[0]
	check(WorldHelpers.cmd(w, "MarkHypothesis", {"hypothesis_id": h, "state": "acredito"}).accepted, "marca como acredito")
	eq(ex.hypotheses[h], "acredito", "estado guardado")
	check(not WorldHelpers.cmd(w, "MarkHypothesis", {"hypothesis_id": h, "state": "talvez"}).accepted, "estado inválido é recusado")
	check(not WorldHelpers.cmd(w, "MarkHypothesis", {"hypothesis_id": "nao_existe", "state": "aberta"}).accepted, "hipótese desconhecida é recusada")
