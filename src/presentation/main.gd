extends Node2D
## Cena principal: monta mapa, atores, câmera, efeitos, combate e interface.
## Roteia input de exploração para comandos. Nenhuma regra mora aqui.

var world_view: WorldView
var npc_layer: NpcLayer
var player: PlayerView
var camera: CameraDirector
var fx: FxLayer
var cine: CinematicDirector
var combat_view: CombatView
var ui: UiRoot
var debug_menu: DebugMenu
var art: ArtGovernor
var vegetation: VegetationLayer
var paths: PathDressing
var buildings: BuildingLayer
var life: AmbientLife


func _ready() -> void:
	world_view = WorldView.new(); world_view.name = "Mundo"; add_child(world_view)
	paths = PathDressing.new(); paths.name = "Caminhos"; add_child(paths)
	buildings = BuildingLayer.new(); buildings.name = "Telhados"
	add_child(buildings.facade)
	var actors := Node2D.new(); actors.name = "Atores"; actors.y_sort_enabled = true; add_child(actors)
	npc_layer = NpcLayer.new(); npc_layer.name = "NPCs"; actors.add_child(npc_layer)
	npc_layer.world_view = world_view
	art = ArtGovernor.load_default()
	vegetation = VegetationLayer.new(); vegetation.name = "Vegetacao"; vegetation.governor = art; actors.add_child(vegetation)
	Game.logger.info("Arte", "governador", art.report())
	player = PlayerView.new(); player.name = "Jogador"; actors.add_child(player)
	life = AmbientLife.new(); life.name = "Figurantes"; actors.add_child(life)
	life.world_view = world_view
	add_child(buildings)
	vegetation.follow = player
	camera = CameraDirector.new(); camera.name = "Camera"; add_child(camera)
	camera.target = player
	camera.make_current()
	fx = FxLayer.new(); fx.name = "Efeitos"; add_child(fx)
	fx.build(camera)
	buildings.fx = fx
	life.fx = fx
	ActorView.fx = fx
	cine = CinematicDirector.new(); cine.name = "Cinema"; add_child(cine)
	cine.camera = camera
	cine.post = fx.post
	combat_view = CombatView.new(); combat_view.name = "Combate"; add_child(combat_view)
	combat_view.npc_layer = npc_layer; combat_view.player_view = player; combat_view.camera = camera
	combat_view.cine = cine; combat_view.fx_post = fx.post; combat_view.fx_glow = fx.glow
	ui = UiRoot.new(); ui.name = "UI"; add_child(ui)
	# menu de debug (F2) numa camada acima da interface
	var debug_layer := CanvasLayer.new()
	debug_layer.layer = 20
	add_child(debug_layer)
	debug_menu = DebugMenu.new()
	debug_menu.name = "DebugMenu"
	debug_menu.theme = ui.theme_res
	debug_layer.add_child(debug_menu)
	ui.combat_view = combat_view
	cine.started.connect(ui.set_cinematic.bind(true))
	cine.finished.connect(ui.set_cinematic.bind(false))
	combat_view.message.connect(ui.log_msg)
	ui.request_new_game.connect(_new_game)
	ui.request_load.connect(_load)
	Game.world_reloaded.connect(_on_world_reloaded)
	Game.event_published.connect(_on_event)
	Game.settings_changed.connect(fx.apply_profile)
	Game.mode_changed.connect(_on_mode)
	_set_world_visible(false)


func _set_world_visible(v: bool) -> void:
	world_view.visible = v
	paths.visible = v
	buildings.visible = v
	buildings.facade.visible = v
	life.visible = v
	vegetation.visible = v
	npc_layer.visible = v
	player.visible = v
	fx.visible = v


func _new_game(feminine: bool) -> void:
	Game.new_game(feminine)


func _load(slot: String) -> void:
	if not Game.load_game(slot):
		ui.log_msg("Nenhum salvamento válido em '%s'." % slot)


func _on_world_reloaded() -> void:
	var veg_plan := VegetationLayer.plan(Game.db, art)
	world_view.dressed = VegetationLayer.dressed_tiles(veg_plan)
	world_view.build()
	vegetation.build(Game.db, veg_plan)
	# cobre a tela enquanto chão e telhados são assados em textura (uma vez por sessão)
	ui.show_loading(true)
	_bakes_left = 2
	if not paths.baked.is_connected(_bake_done): paths.baked.connect(_bake_done)
	if not buildings.baked.is_connected(_bake_done): buildings.baked.connect(_bake_done)
	paths.build(Game.db, world_view)
	buildings.build(Game.db)
	life.rebuild()
	ui.minimap.build(Game.db)
	life.call_deferred("prefill")
	camera.set_bounds(Game.db.size)
	player.sync_from_world()
	npc_layer.rebuild()
	var in_vila: bool = Game.world.modules.travel.current_region == "vila"
	_set_world_visible(in_vila)
	ui.close_panels()
	ui.refresh_hub()
	ui.log_msg("Vila Alvorada. Hilda Brandt procura o filho desaparecido. [E] interagir · [J] diário · [Esc] menu")
	camera.reset_smoothing()


func _on_mode(_m: String) -> void:
	vegetation.set_combat(Game.mode == Game.Mode.COMBAT)
	if Game.mode == Game.Mode.TITLE:
		_set_world_visible(false)
	combat_view.clear_plan()


func _on_event(e: GameEvent) -> void:
	match e.event_type:
		"OBJECT_OPENED", "OBJECT_CLOSED", "OBJECT_BROKEN":
			world_view.refresh_object(e.payload.object)
		"PLAYER_TELEPORTED", "PLAYER_CAPTURED", "COMBAT_ENDED":
			player.call_deferred("sync_from_world")
			if e.event_type == "PLAYER_CAPTURED":
				world_view.call_deferred("refresh_object", "porta_cela")
			npc_layer.call_deferred("sync_all")
			camera.call_deferred("reset_smoothing")
		"CREATURES_MOVED":
			npc_layer.call_deferred("sync_all")
		"NPC_BORN":
			npc_layer.call_deferred("rebuild")
		"TRAVEL_ARRIVED":
			call_deferred("_on_world_reloaded")
		"DIALOGUE_CHOICE", "DIALOGUE_STARTED":
			ui.call_deferred("refresh_dialogue")


# --- Interação ------------------------------------------------------------------------------
func build_actions() -> Array:
	var out: Array = []
	var w: WorldState = Game.world
	var pt := Game.player_tile()
	var npc := npc_layer.npc_near(pt, 1)
	if npc != "":
		out.append({"label": "Conversar com " + Game.world.npc_def(npc).name, "cmd": "StartDialogue", "payload": {"npc_id": npc}})
	var objs: ObjectsModule = w.modules.objects
	for o in Game.db.all_objects():
		if not objs.is_adjacent(o.id):
			continue
		var s := objs.obj(o.id)
		match o.type:
			"door":
				if s.broken:
					continue
				if s.locked:
					out.append({"label": "Destrancar com chave (%s)" % o.name, "cmd": "UseObject", "payload": {"object_id": o.id, "action": "unlock"}})
					out.append({"label": "Abrir fechadura — Ladinagem (%s)" % o.name, "cmd": "UseObject", "payload": {"object_id": o.id, "action": "pick_lock"}})
					out.append({"label": "Arrombar a golpes (barulhento)", "cmd": "UseObject", "payload": {"object_id": o.id, "action": "break"}})
				elif s.open:
					out.append({"label": "Fechar " + o.name, "cmd": "UseObject", "payload": {"object_id": o.id, "action": "close"}})
				else:
					out.append({"label": "Abrir " + o.name, "cmd": "UseObject", "payload": {"object_id": o.id, "action": "open"}})
			"chest":
				if not s.open:
					out.append({"label": "Abrir " + o.name, "cmd": "UseObject", "payload": {"object_id": o.id, "action": "open"}})
				elif not s.contents.is_empty():
					out.append({"label": "Pegar o conteúdo", "cmd": "UseObject", "payload": {"object_id": o.id, "action": "loot"}})
			"stairs":
				out.append({"label": o.name, "cmd": "UseObject", "payload": {"object_id": o.id, "action": "use_stairs"}})
	var labels := {"examinar": "Examinar (Percepção)", "escutar": "Escutar (Percepção)", "rastrear": "Rastrear (Sobrevivência)",
		"investigar": "Investigar (Investigação)", "manipular": "Manipular"}
	for t in Game.db.all_targets():
		var tt := Vector2i(int(t.tile[0]), int(t.tile[1]))
		if maxi(absi(tt.x - pt.x), absi(tt.y - pt.y)) <= 1:
			for a in t.actions:
				out.append({"label": "%s: %s" % [t.name, labels.get(a, a)], "cmd": "InspectTarget", "payload": {"target_id": t.id, "approach": a}})
	var loc := Game.db.location_at(pt)
	for owner in Game.db.economy.get("shops", {}):
		if Game.world.npc_def(owner).get("work", "") == loc:
			for it in Game.db.economy.shops[owner]:
				out.append({"label": "Pegar escondido: %s (furto)" % Game.db.items[it].name, "cmd": "StealFromStall", "payload": {"owner": owner, "item": it}})
	var tr: TravelModule = w.modules.travel
	if tr.enabled and TravelModule.DEPARTURE_LOCS.has(loc):
		for route in tr.available_routes():
			var rd: Dictionary = TravelModule.ROUTES[route]
			out.append({"label": "Viajar: %s (%d km, ~%.1f dias)" % [str(rd.to).replace("_", " ").capitalize(), rd.km, float(rd.km) / tr.km_per_day(rd)],
				"cmd": "Travel", "payload": {"route": route}})
	var c: CombatModule = w.modules.combat
	var foes: Array = []
	for id in c.visible_creatures():
		if CombatSim.cheb(pt, c.creature_tile(id)) <= 8:
			foes.append(id)
	if not foes.is_empty():
		var surprised := foes.all(func(id): return c.undetected_by.has(id))
		out.append({"label": "Atacar" + (" de surpresa!" if surprised else ""), "cmd": "StartCombat", "payload": {"enemies": foes}})
	return out


func _unhandled_input(event: InputEvent) -> void:
	if Game.world == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if k == KEY_ESCAPE:
		if not ui.close_panels() and Game.mode in [Game.Mode.EXPLORE, Game.Mode.COMBAT, Game.Mode.DIALOGUE]:
			ui.toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_TAB and Game.mode in [Game.Mode.EXPLORE, Game.Mode.COMBAT]:
		ui.toggle_wheel()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_F3:
		ui.toggle_debug()
		return
	if k == KEY_F2:
		debug_menu.toggle()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_F5:
		ui.log_msg("Jogo salvo." if Game.save_game() == OK else "Não é possível salvar agora.")
		return
	if k == KEY_F9:
		_load("quicksave")
		return
	if Game.mode == Game.Mode.DIALOGUE:
		if k >= KEY_1 and k <= KEY_9:
			ui.dialogue_key(k - KEY_1)
		return
	if Game.mode != Game.Mode.EXPLORE:
		return
	if ui.panel_interact.visible and k >= KEY_1 and k <= KEY_9:
		ui._do_interact(k - KEY_1)
		return
	_explore_key(k)


func _explore_key(k: int) -> void:
	if Game.mode != Game.Mode.EXPLORE:
		return
	match k:
		KEY_K:
			ui.toggle_tree()
		KEY_I:
			ui.toggle_inv()
		KEY_E:
			ui.show_interact(build_actions())
		KEY_J:
			ui.toggle_journal()
		KEY_C:
			Game.send("SetStance", {"sneak": not Game.world.modules.combat.stance_sneak})
		KEY_R:
			var r := Game.send("Rest")
			if not r.accepted: ui.log_msg("✘ " + "; ".join(r.errors))
			else:
				npc_layer.sync_all()
				life.prefill()


var _bakes_left := 0


func _bake_done() -> void:
	_bakes_left -= 1
	if _bakes_left <= 0:
		ui.show_loading(false)
