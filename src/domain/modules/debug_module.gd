class_name DebugModule
extends WorldModule
## Menu de debug (desenvolvimento): teleporte e ajuste de variáveis do mundo. Não é conteúdo do jogo.
## Tudo passa por comando validado, como o resto do jogo: o menu só envia comandos. Sem estado próprio.

const VARS := ["gold", "hour", "treasury", "npc_gold", "npc_hunger", "npc_tired", "npc_location", "stock", "weather"]


func module_id() -> String: return "debug"
func handled_commands() -> PackedStringArray: return PackedStringArray(["DebugTeleport", "DebugSet"])


func validate(cmd: GameCommand) -> PackedStringArray:
	if cmd.type == "DebugTeleport":
		var p: Dictionary = cmd.payload
		if p.has("location") and world.db.location(str(p.location)).is_empty():
			return PackedStringArray(["local desconhecido: %s" % p.location])
		if p.has("npc") and world.npc_def(str(p.npc)).is_empty():
			return PackedStringArray(["morador desconhecido: %s" % p.npc])
		if not p.has("location") and not p.has("npc"):
			return PackedStringArray(["nada para onde teleportar"])
		return PackedStringArray()
	var key := str(cmd.payload.get("key", ""))
	if not VARS.has(key):
		return PackedStringArray(["variável de debug desconhecida: %s" % key])
	var v: Variant = cmd.payload.get("value")
	match key:
		"gold", "treasury":
			if int(v) < 0: return PackedStringArray(["valor negativo"])
		"hour":
			if int(v) < 0 or int(v) > 23: return PackedStringArray(["hora fora de 0 a 23"])
		"npc_gold", "npc_hunger", "npc_tired", "npc_location":
			if world.npc_def(str(cmd.payload.get("npc", ""))).is_empty():
				return PackedStringArray(["morador desconhecido"])
			if key == "npc_location" and world.db.location(str(v)).is_empty():
				return PackedStringArray(["local desconhecido: %s" % v])
		"stock":
			var good := str(cmd.payload.get("good", ""))
			world.modules.economy._ensure()
			if not world.modules.economy.regions.vila.stock.has(good):
				return PackedStringArray(["bem desconhecido: %s" % good])
			if int(v) < 0: return PackedStringArray(["valor negativo"])
		"weather":
			if not WeatherModule.TRANSITIONS.has(str(v)):
				return PackedStringArray(["clima desconhecido: %s" % v])
	return PackedStringArray()


func execute(cmd: GameCommand) -> Array:
	if cmd.type == "DebugTeleport":
		return _teleport(cmd.payload)
	return _ajustar(str(cmd.payload.key), cmd.payload)


func _teleport(p: Dictionary) -> Array:
	var tile := Vector2i(-1, -1)
	if p.has("location"):
		tile = world.db.location_spot(str(p.location))
	elif p.has("npc"):
		tile = world.modules.npcs.npc_tile(str(p.npc)) + Vector2i(1, 0)
	if tile != Vector2i(-1, -1):
		world.player.position = world.db.tile_to_world(tile)
	return []


func _ajustar(key: String, p: Dictionary) -> Array:
	var v: Variant = p.get("value")
	match key:
		"gold":
			world.player.gold = int(v)
		"treasury":
			world.modules.economy.treasury = int(v)
		"hour":
			var dia := int(world.clock.tick / (24 * 60 / world.clock.tick_minutes))
			world.clock.tick = dia * (24 * 60 / world.clock.tick_minutes) + int(v) * (60 / world.clock.tick_minutes)
		"npc_gold":
			world.modules.npc_needs.gold(str(p.npc))
			world.modules.npc_needs.state[str(p.npc)].gold = int(v)
		"npc_hunger":
			world.modules.npc_needs.gold(str(p.npc))
			world.modules.npc_needs.state[str(p.npc)].hunger = clampf(float(v), 0.0, 1.0)
		"npc_tired":
			world.modules.npc_needs.gold(str(p.npc))
			world.modules.npc_needs.state[str(p.npc)].tired = clampf(float(v), 0.0, 1.0)
		"npc_location":
			world.modules.npcs.state[str(p.npc)].location = str(v)
		"stock":
			world.modules.economy._ensure()
			world.modules.economy.regions.vila.stock[str(p.good)] = int(v)
		"weather":
			world.modules.weather.region.condition = str(v)
	return []
