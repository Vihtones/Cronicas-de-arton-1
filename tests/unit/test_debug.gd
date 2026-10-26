extends TestCase
## Menu de debug (F2): comandos de teleporte e ajuste passam pelo domínio e são validados.


func test_teleporte_para_local_existente() -> void:
	var w := WorldHelpers.world(3)
	var loc := str(w.db.all_locations()[0].id)
	var r := WorldHelpers.cmd(w, "DebugTeleport", {"location": loc})
	check(r.accepted, "teleporte para local existente é aceito")
	eq(w.db.world_to_tile(w.player.position), w.db.location_spot(loc), "o jogador fica no local")


func test_teleporte_para_local_inexistente_e_recusado() -> void:
	var w := WorldHelpers.world(3)
	check(not WorldHelpers.cmd(w, "DebugTeleport", {"location": "nao_existe"}).accepted, "local inexistente é recusado")


func test_hora_ajustada_e_validada() -> void:
	var w := WorldHelpers.world(3)
	check(WorldHelpers.cmd(w, "DebugSet", {"key": "hour", "value": 22}).accepted, "hora 22 é aceita")
	eq(w.hour(), 22, "o relógio vai para 22h")
	check(not WorldHelpers.cmd(w, "DebugSet", {"key": "hour", "value": 99}).accepted, "hora 99 é recusada")


func test_variavel_desconhecida_e_recusada() -> void:
	var w := WorldHelpers.world(3)
	check(not WorldHelpers.cmd(w, "DebugSet", {"key": "xpto", "value": 1}).accepted, "variável inexistente é recusada")


func test_ajusta_ouro_e_estoque() -> void:
	var w := WorldHelpers.world(3)
	WorldHelpers.cmd(w, "DebugSet", {"key": "gold", "value": 123})
	eq(w.player.gold, 123, "ouro do jogador ajustado")
	WorldHelpers.cmd(w, "DebugSet", {"key": "stock", "good": "comida", "value": 7})
	eq(int(w.modules.economy.regions.vila.stock.comida), 7, "estoque da vila ajustado")
