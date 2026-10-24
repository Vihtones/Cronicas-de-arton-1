class_name NpcLayer
extends Node2D
## Materializa (L0) NPCs e criaturas da zona do jogador a partir do estado L1.
## Movimento entre locais vira caminhada animada; nada aqui decide resultados.

var world_view: WorldView
var npc_views: Dictionary = {}
var creature_views: Dictionary = {}

const ARCHETYPE := {
	"elsa": "guarda", "rurik": "guarda", "tobias": "guarda", "ysolde": "sacerdote", "lucan": "sacerdote",
	"lisel": "crianca", "nina": "crianca", "davi": "crianca", "teodoro": "idoso", "joran": "idoso", "quill": "idoso", "celia": "idoso",
	"garrick": "artesao", "bento": "artesao", "otto": "artesao", "orin": "idoso", "dorn": "aldeao",
}


func _ready() -> void:
	y_sort_enabled = true
	Game.event_published.connect(_on_event)


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	npc_views.clear()
	creature_views.clear()
	for id in Game.world.all_npc_ids():
		var arche: String = ARCHETYPE.get(id, "crianca" if Game.world.npc_def(id).get("dynamic", false) else "aldeao")
		var v := ActorView.new()
		var nm: String = Game.world.npc_def(id).get("name", id)
		v.setup(id, "res://assets/chars/%s.png" % arche, nm.get_slice(" ", 0) if not nm.begins_with("Capitã") else "Elsa")
		add_child(v)
		npc_views[id] = v
	for id in Game.db.all_creature_ids():
		var d := Game.db.creature_def(id)
		var sheet := "hiena" if str(d.rule).contains("hiena") else ("kael" if id == "kael" else "bandido")
		var v := ActorView.new()
		v.setup(id, "res://assets/chars/%s.png" % sheet, d.name)
		add_child(v)
		creature_views[id] = v
	sync_all()


func _player_zone() -> String:
	return Game.db.zone_at(Game.player_tile())


func _same_layer(z: String) -> bool:
	var pz := _player_zone()
	return (z == "cripta") == (pz == "cripta")


func sync_all() -> void:
	if Game.world == null:
		return
	var npcs: NpcModule = Game.world.modules.npcs
	for id in npc_views:
		var v: ActorView = npc_views[id]
		var t: Vector2i = npcs.npc_tile(id)
		var ok: bool = npcs.is_present(id) and t.x >= 0 and _same_layer(Game.db.zone_at(t))
		v.visible = ok
		if ok:
			v.stop()
			v.position = Game.db.tile_to_world(t)
	sync_creatures()


func sync_creatures() -> void:
	var c: CombatModule = Game.world.modules.combat
	for id in creature_views:
		var v: ActorView = creature_views[id]
		var st: Dictionary = c.creature_state[id]
		var t := c.creature_tile(id)
		var show_it: bool = c.is_active_creature(id) and _same_layer(Game.db.zone_at(t))
		if c.active and c.sim.combatants.has(id):
			show_it = not c.sim.c(id).sheet.is_dead() or true
			t = c.sim.c(id).tile
			v.set_hp(c.sim.c(id).sheet.pv, c.sim.c(id).sheet.pv_max, true)
		else:
			v.hp_back.visible = false; v.hp_bar.visible = false
			v.set_down(false)
		v.visible = show_it
		v.position = Game.db.tile_to_world(t)
		v.modulate = Color(0.75, 0.75, 0.9) if (not c.active and c.is_asleep(id)) else Color.WHITE


func _on_event(e: GameEvent) -> void:
	match e.event_type:
		"NPC_MOVED":
			_walk_npc(e.payload.npc)
		"NPC_RESCUED", "BANDITS_RELOCATED", "PLAYER_TELEPORTED", "CREATURE_DEFEATED", "COMBAT_ENDED", "PLAYER_CAPTURED":
			call_deferred("sync_all")


func _walk_npc(id: String) -> void:
	var v: ActorView = npc_views.get(id)
	if v == null:
		return
	var npcs: NpcModule = Game.world.modules.npcs
	var t: Vector2i = npcs.npc_tile(id)
	if not npcs.is_present(id) or t.x < 0 or not _same_layer(Game.db.zone_at(t)):
		v.visible = false
		return
	var from := Game.db.world_to_tile(v.position)
	if not v.visible or from.distance_to(t) > 60:
		v.visible = true
		v.position = Game.db.tile_to_world(t)
		return
	var path := world_view.path_tiles(from, t)
	var pts: Array = []
	for p in path.slice(1):
		pts.append(Game.db.tile_to_world(p))
	v.walk_path(pts, 48.0)


func npc_near(tile: Vector2i, radius: int = 1) -> String:
	var best := ""
	var bd := 99
	for id in npc_views:
		var v: ActorView = npc_views[id]
		if not v.visible:
			continue
		var t := Game.db.world_to_tile(v.position)
		var d := maxi(absi(t.x - tile.x), absi(t.y - tile.y))
		if d <= radius and d < bd:
			bd = d; best = id
	return best


func _process(_d: float) -> void:
	if Game.world == null:
		return
	var p: Vector2 = Game.world.player.position
	for id in npc_views:
		var v: ActorView = npc_views[id]
		v.show_name(v.visible and v.position.distance_to(p) < 72)
