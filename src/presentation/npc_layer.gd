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
	"hilda": "aldea", "ivi": "aldea", "fenna": "aldea", "berta": "aldea", "rosana": "mercadora", "mara": "mercadora", "saria": "mercadora",
	"marta": "mercadora", "hesk": "guarda", "lia": "guarda", "caio": "artesao", "gunther": "idoso",
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
		_criar_vista(id)
	sync_all()


## Aparência pelo tipo do bestiário enquanto não há arte própria: animais e monstros usam a folha da hiena,
## humanoides a do bandido; a cor separa as espécies (mortos-vivos pálidos, orcs esverdeados...).
## Silhueta própria por espécie (tools/gen_placeholder_art.py). Procurada pelo trecho do nome da regra.
const FORMA_POR_REGRA := {"lobo": "lobo", "esqueleto": "esqueleto", "zumbi": "esqueleto", "necromante": "esqueleto", "aranha": "aranha",
	"naja": "cobra", "jiboia": "cobra", "sucuri": "cobra", "cascavel": "cobra", "nagah": "cobra", "orc": "orc", "gnoll": "orc",
	"finntroll": "orc", "ogro": "ogro", "golem": "ogro"}


const TINTA := {"criatura.lobo": Color(0.75, 0.75, 0.8), "criatura.rato_gigante": Color(0.6, 0.5, 0.45), "criatura.zumbi": Color(0.7, 0.85, 0.7),
	"criatura.esqueleto": Color(1.0, 1.0, 0.9), "criatura.orc_combatente": Color(0.6, 0.85, 0.55), "criatura.orc_chefe": Color(0.5, 0.8, 0.45),
	"criatura.orc_mutante": Color(0.55, 0.7, 0.4), "criatura.glop": Color(0.4, 1.0, 0.4), "criatura.aranha_gigante": Color(0.35, 0.3, 0.35),
	"criatura.gnoll_saqueador": Color(0.9, 0.75, 0.5), "criatura.gargula": Color(0.6, 0.6, 0.62), "criatura.aparicao": Color(0.7, 0.75, 1.0, 0.7),
	"criatura.cascavel": Color(0.85, 0.7, 0.4), "criatura.ogro": Color(0.85, 0.7, 0.55), "criatura.urso_coruja": Color(0.6, 0.45, 0.3)}


func _criar_vista(id: String) -> void:
	var d := Game.db.creature_def(id)
	var r: Dictionary = Game.world.rules.value(str(d.rule), {})
	var tipo := str(r.get("tipo", "humanoide"))
	var sheet := "hiena" if str(d.rule).contains("hiena") or tipo in ["animal", "monstro"] else ("kael" if id == "kael" else "bandido")
	for forma in FORMA_POR_REGRA:
		if str(d.rule).contains(forma):
			sheet = "criatura_" + str(FORMA_POR_REGRA[forma])
			break
	var v := ActorView.new()
	v.setup(id, "res://assets/chars/%s.png" % sheet, d.name)
	if TINTA.has(str(d.rule)):
		v.sprite.self_modulate = TINTA[str(d.rule)]
	if str(r.get("tamanho", "medio")) in ["grande", "enorme"]:
		v.base_scale = 1.5
	add_child(v)
	creature_views[id] = v


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
	for id in creature_views.keys():
		if not c.creature_state.has(id):   # criatura de contrato encerrado
			creature_views[id].queue_free()
			creature_views.erase(id)
	for id in c.creature_state:
		if not creature_views.has(id) and not Game.db.creature_def(id).is_empty():
			_criar_vista(id)
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
		"NPC_RESCUED", "BANDITS_RELOCATED", "PLAYER_TELEPORTED", "CREATURE_DEFEATED", "COMBAT_ENDED", "PLAYER_CAPTURED", "QUEST_ACCEPTED", "QUEST_COMPLETED", "QUEST_ABANDONED":
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


## NPCs parados em lugares abertos não ficam congelados: dão uns passos, viram para os lados
## (apresentação; o tile do domínio continua o mesmo).
const MINGLE_PLACES := ["praca", "mercado", "campos", "ponte", "estrada_leste"]


func _mingle(v: ActorView, id: String, delta: float) -> void:
	if v.walking or not v.visible:
		return
	var t := float(v.get_meta("idle_t", randf_range(2.0, 6.0))) - delta
	if t > 0.0:
		v.set_meta("idle_t", t)
		return
	v.set_meta("idle_t", randf_range(3.0, 8.0))
	var npcs: NpcModule = Game.world.modules.npcs
	if not MINGLE_PLACES.has(str(npcs.npc(id).get("location", ""))):
		return
	var home := Game.db.tile_to_world(npcs.npc_tile(id))
	if randf() < 0.4:
		v.face_dir(Vector2.from_angle(randf() * TAU))
		return
	var goal := home + Vector2(randf_range(-14, 14), randf_range(-8, 8))
	v.walk_path([goal], 22.0)


func _process(_d: float) -> void:
	if Game.world == null:
		return
	if Game.mode == Game.Mode.EXPLORE:
		for id in npc_views:
			_mingle(npc_views[id], id, _d)
	# só o nome de quem está mais perto (em festa/feira a praça vira um amontoado de rótulos)
	var p: Vector2 = Game.world.player.position
	var best := ""
	var bd := 72.0
	for id in npc_views:
		var v: ActorView = npc_views[id]
		var d := v.position.distance_to(p)
		if v.visible and d < bd:
			bd = d; best = id
	for id in npc_views:
		(npc_views[id] as ActorView).show_name(id == best)
	if best != "":
		var act := _activity_line(best)
		(npc_views[best] as ActorView).label.text = "%s · %s" % [str(Game.world.npc_def(best).get("name", best)), act] if act != "" else str(Game.world.npc_def(best).get("name", best))
	if best != "" and bd < 56.0 and Game.mode == Game.Mode.EXPLORE:
		_bark(best)


## O morador reconhece o jogador que passa por perto (uma vez por dia): fala curta conforme registro,
## relação e hora. Pura apresentação; não cria memória nem muda reputação.
func _bark(id: String) -> void:
	var v: ActorView = npc_views[id]
	var today := Game.world.day_index()
	if int(v.get_meta("bark_day", -1)) == today or not v.visible or v.walking:
		return
	var st: Dictionary = Game.world.modules.npcs.state.get(id, {})
	if not st.get("alive", true) or st.get("captive", false):
		return
	v.set_meta("bark_day", today)
	var seed_value := ("%s|%d" % [id, today]).hash()
	var life = Game.world.module("npc_life")
	var fearful: bool = life != null and life.fear(id) >= 0.5
	var txt := "" if fearful and randf() < 0.5 else AmbientTalk.latido(Game.db.ambient, DialogueVoice.register(Game.world, id), DialogueVoice.tier(Game.world, id), seed_value)
	SpeechBubble.show(self, v, txt)


## Atividade do morador para o rótulo (ex.: "forjando"). Vazio quando não há nada a mostrar.
func _activity_line(id: String) -> String:
	var life = Game.world.module("npc_life")
	return life.activity(id) if life != null else ""
