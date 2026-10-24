class_name PacingModule
extends WorldModule
## WorldPacingDirector (§7): decide QUANDO apresentar conteúdo opcional que JÁ é
## verdadeiro no estado (vinhetas). Nunca cria fatos, nunca atrasa resultados.

const MIN_GAP_TICKS := 12  # ao menos 2h entre vinhetas
var last_tick := -999
var shown: Dictionary = {}  # id -> último dia mostrado


func module_id() -> String: return "pacing"


func _here() -> String:
	return world.db.location_at(world.db.world_to_tile(world.player.position))


func candidates() -> Array:
	var npcs = world.module("npcs")
	if npcs == null:
		return []
	var loc := _here()
	var present: Array = npcs.npcs_at(loc)
	var h := world.hour()
	var out: Array = []
	if loc == "praca" and present.has("lisel") and present.has("nina"):
		out.append({"id": "criancas", "text": "Lisel e Nina disputam quem joga a pedrinha mais longe no poço."})
	if loc == "taverna" and present.has("teodoro") and present.size() >= 3 and h >= 18 and h < 21:
		out.append({"id": "teodoro", "text": "O velho Teodoro conta, pela décima vez, como enfrentou um ogro na juventude. Ninguém interrompe."})
	if loc == "mercado" and present.has("saria"):
		out.append({"id": "saria", "text": "Saria abre os fardos: ferramentas, tecidos e notícias da capital."})
	if loc == "templo" and present.has("ysolde") and (h == 6 or h == 18):
		out.append({"id": "prece", "text": "Irmã Ysolde reza em voz baixa pelos doentes da vila."})
	var lin = world.module("lineage")
	if lin != null and not lin.deaths.is_empty():
		var d: Dictionary = lin.deaths[-1]
		if world.clock.calendar().year == int(d.year) and present.has(d.get("heir", "-")):
			out.append({"id": "luto_" + str(d.npc), "text": "%s está de luto por %s." % [world.db.npc_def(d.heir).name, world.db.npc_def(d.npc).name]})
	return out


func on_tick(tick: int) -> Array:
	if tick - last_tick < MIN_GAP_TICKS:
		return []
	var combat = world.module("combat")
	if combat != null and combat.active:
		return []
	for c in candidates():
		if int(shown.get(c.id, -1)) == world.day_index():
			continue
		shown[c.id] = world.day_index()
		last_tick = tick
		return [fact("AMBIENT_VIGNETTE", {"id": c.id, "text": c.text, "location": _here()})]
	return []


func to_dict() -> Dictionary: return {"last_tick": last_tick, "shown": shown.duplicate()}
func from_dict(d: Dictionary) -> void:
	last_tick = int(d.get("last_tick", -999))
	shown = d.get("shown", {}).duplicate()
