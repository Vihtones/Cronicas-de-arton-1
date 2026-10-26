class_name PrologueModule
extends WorldModule
## Prólogo Vivo (Arton Viva, Fase 3): aplica um começo validado por comando (StartPrologue), uma única vez.
## O começo vira fatos: ouro (GOLD_CHANGED), o próprio PROLOGUE_STARTED, que a memória de relações consome.
## A posição do jogador é do lado da apresentação: o fato traz o local inicial.

var started := false


func module_id() -> String: return "prologue"
func handled_commands() -> PackedStringArray: return PackedStringArray(["StartPrologue"])


func validate(cmd: GameCommand) -> PackedStringArray:
	if started:
		return PackedStringArray(["o prólogo já foi escolhido"])
	var start: Dictionary = cmd.payload.get("start", {})
	if start.is_empty():
		return PackedStringArray(["sem começo"])
	return Prologue.validate(start, world.db)


func execute(cmd: GameCommand) -> Array:
	var start: Dictionary = cmd.payload.start
	started = true
	var delta := int(start.gold) - int(world.player.gold)
	var contacts := Prologue.resolve_contacts(start, world.db)
	# o jogador começa no lugar do passado escolhido (a apresentação só reflete a posição)
	var spot: Vector2i = world.db.location_spot(str(start.start_location))
	if spot != Vector2i(-1, -1):
		world.player.position = world.db.tile_to_world(spot)
	return [
		fact("GOLD_CHANGED", {"delta": delta, "reason": "prólogo"}),
		fact("PROLOGUE_STARTED", {"start_location": start.start_location, "home": start.home, "profession": start.profession,
			"objective": start.objective, "contacts": contacts, "recent": start.recent}, ["player"]),
	]


func to_dict() -> Dictionary: return {"started": started}


func from_dict(d: Dictionary) -> void: started = bool(d.get("started", false))
