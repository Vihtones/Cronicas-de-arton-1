extends Node
## Autoload "Game": composição da aplicação. NÃO contém regras — liga Domínio
## (WorldState + módulos), Infraestrutura (saves, IA) e expõe comandos à Apresentação.

signal event_published(event: GameEvent)
signal world_reloaded
signal mode_changed(mode: String)
signal settings_changed

enum Mode { TITLE, EXPLORE, DIALOGUE, COMBAT, MENU, GAMEOVER }

var logger := GameLogger.new()
var telemetry := Telemetry.new()
var saves := JsonSaveRepository.new()
var rules: RuleRegistry
var db: ContentDB
var world: WorldState
var dialogue_provider: DialogueProvider
var mode: Mode = Mode.TITLE
var safe_mode := false
var _cmd_seq := 0
var _accum := 0.0
var _last_autosave_tick := 0

## Configurações do jogador (persistidas em user://settings.json)
var settings := {
	"graphics": "medio",          # baixo | medio | alto
	"combat_speed": 1.0,          # 1.0, 2.0, 0.0 (instantâneo)
	"reduce_motion": false,
	"reduce_flashes": false,
	"seconds_per_tick": 2.0,      # PLACEHOLDER §20.7: 2s reais = 10 min de jogo
	"disabled_modules": [],
	"combate_acao": true,         # lutas pequenas em tempo real (mirar e clicar, turno com relógio)
	"acao_segundos": 4.0,        # tempo do turno do jogador no modo ação
}
const SETTINGS_PATH := "user://settings.json"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	# Modo seguro (D1): "Jogar (modo seguro).bat" passa -- --modo-seguro. Gráficos mínimos e 30 FPS.
	if OS.get_cmdline_user_args().has("--modo-seguro"):
		safe_mode = true
		settings.graphics = "baixo"
		settings.reduce_flashes = true
		Engine.max_fps = 30
	rules = RuleRegistry.load_default()
	db = ContentDB.load_default()
	if not rules.errors.is_empty():
		logger.error("Rules", "erros no catálogo", {"errors": Array(rules.errors)})
	var ai := LlmDialogueProvider.load_config()
	dialogue_provider = LlmDialogueProvider.new(ai, self) if ai.get("enabled", false) else DialogueProvider.new()
	logger.info("Game", "boot", {"content_version": WorldState.CONTENT_VERSION, "rules": rules.size(),
		"pendentes": rules.unverified_ids().size(), "ia": dialogue_provider.provider_id(),
		"gpu": RenderingServer.get_video_adapter_name(), "modo_seguro": safe_mode})
	if OS.get_cmdline_user_args().has("--autoteste"):
		call_deferred("_self_test")


## Autoteste do executável (usado para verificar o build exportado): novo jogo, 2 dias, salvar, carregar.
func _self_test() -> void:
	new_game(false, 7)
	var r := send("AdvanceTime", {"ticks": 288})
	var ok_save := save_game("autoteste") == OK
	var ok_load := load_game("autoteste")
	print("AUTOTESTE regras=%d npcs=%d avancou=%s save=%s load=%s versao=%s" % [rules.size(), world.all_npc_ids().size(),
		r.accepted, ok_save, ok_load, WorldState.CONTENT_VERSION])
	get_tree().quit(0 if r.accepted and ok_save and ok_load else 1)


func new_game(feminine: bool = false, p_seed: int = -1) -> void:
	var s := p_seed if p_seed >= 0 else int(Time.get_unix_time_from_system()) % 1000000
	world = WorldFactory.create(s, settings.disabled_modules, rules, db)
	_wire()
	if feminine:
		world.modules.state.flags["personagem_feminina"] = true
		world.player_sheet.name = "Aventureira"
	_cmd_seq = 0
	_last_autosave_tick = 0
	mode = Mode.TITLE
	set_mode(Mode.EXPLORE)
	world_reloaded.emit()
	logger.info("Game", "novo jogo", {"seed": s})


## Novo jogo com ficha montada pela criação de personagem.
func new_game_with_build(build: Dictionary, feminine: bool) -> void:
	new_game(feminine)
	world.player_sheet = CharacterBuilder.build_from(rules, build)
	world_reloaded.emit()


## Laboratório: novo mundo (seed fixa) configurado pelo cenário do protótipo.
## Começo do prólogo (questionário ou "Deixar o Destino Decidir"): o jogador vai para o lugar do passado
## escolhido e a cena é recarregada para refletir a posição.
func start_prologue(start: Dictionary) -> GameCommand.Result:
	var r := send("StartPrologue", {"start": start})
	if r.accepted:
		world_reloaded.emit()
	return r


## "Deixar o Destino Decidir": a mesma semente gera sempre o mesmo começo (Prologue.from_seed).
func start_prologue_from_seed(p_seed: int) -> GameCommand.Result:
	return start_prologue(Prologue.from_seed(p_seed))


func start_prototype(id: String) -> Dictionary:
	new_game(false, 7)
	var info := Prototypes.apply(id, world)
	for k in info.get("settings", {}):
		settings[k] = info.settings[k]
	if info.get("provider", "") == "eco_local":
		dialogue_provider = LocalEchoProvider.new()
	if world.player_sheet.is_dead():
		set_mode(Mode.GAMEOVER)
	world_reloaded.emit()
	return info


func _wire() -> void:
	world.bus.subscribe("*", func(e: GameEvent): event_published.emit(e))


func has_world() -> bool:
	return world != null


func set_mode(m: Mode) -> void:
	if mode == m:
		return
	mode = m
	mode_changed.emit(mode_name())


func mode_name() -> String:
	return Mode.keys()[mode].to_lower()


func _process(delta: float) -> void:
	telemetry.push(telemetry.frame_ms, delta * 1000.0)
	if world == null or mode != Mode.EXPLORE:
		return
	# Render usa delta; simulação avança em passos fixos e inteiros.
	_accum += delta
	var spt: float = maxf(0.05, float(settings.seconds_per_tick))
	while _accum >= spt:
		_accum -= spt
		send("AdvanceTime", {"ticks": 1})
		if mode != Mode.EXPLORE:
			break
	if world.clock.tick - _last_autosave_tick >= 36:  # a cada 6h de jogo
		_last_autosave_tick = world.clock.tick
		save_game("auto")


func send(type: String, payload: Dictionary = {}, actor: String = "player") -> GameCommand.Result:
	if world == null:
		return GameCommand.Result.rejected(["sem mundo"], -1)
	_cmd_seq += 1
	var cmd := GameCommand.create("cmd_%08d" % _cmd_seq, actor, type, payload)
	var t0 := Time.get_ticks_usec()
	var r := world.apply_command(cmd)
	telemetry.push(telemetry.command_ms, (Time.get_ticks_usec() - t0) / 1000.0)
	telemetry.push(telemetry.events_per_command, r.emitted_events.size())
	if not r.accepted and type != "AdvanceTime":
		logger.debug("Game", "comando rejeitado", {"type": type, "errors": Array(r.errors)})
	_update_mode_from_events(r)
	return r


func _update_mode_from_events(r: GameCommand.Result) -> void:
	for e in r.emitted_events:
		match e.event_type:
			"COMBAT_STARTED": set_mode(Mode.COMBAT)
			"COMBAT_ENDED":
				if e.payload.outcome != "morte": set_mode(Mode.EXPLORE)
			"PLAYER_DIED": set_mode(Mode.GAMEOVER)
			"DIALOGUE_STARTED": set_mode(Mode.DIALOGUE)
			"DIALOGUE_ENDED":
				if mode == Mode.DIALOGUE: set_mode(Mode.EXPLORE)


func save_game(slot: String = "quicksave") -> Error:
	if world == null or mode == Mode.GAMEOVER:
		return ERR_UNAVAILABLE
	var t0 := Time.get_ticks_usec()
	var snap := world.to_snapshot()
	snap["modules"]["app"] = {"cmd_seq": _cmd_seq}
	var err := saves.save(slot, snap)
	telemetry.push(telemetry.save_ms, (Time.get_ticks_usec() - t0) / 1000.0)
	logger.info("Persistence", "save", {"slot": slot, "ok": err == OK})
	return err


func has_save(slot: String) -> bool:
	return FileAccess.file_exists(saves.base_dir.path_join(slot + ".json")) or FileAccess.file_exists(saves.base_dir.path_join(slot + ".json.bak"))


func load_game(slot: String = "quicksave") -> bool:
	var t0 := Time.get_ticks_usec()
	var res := saves.load_slot(slot)
	if res.is_empty():
		logger.warn("Persistence", "nenhum save válido", {"slot": slot})
		return false
	world = WorldFactory.create(0, settings.disabled_modules, rules, db)
	world.from_snapshot(res.data)
	_wire()
	_cmd_seq = int(res.data.modules.get("app", {}).get("cmd_seq", 0))
	_last_autosave_tick = world.clock.tick
	telemetry.push(telemetry.load_ms, (Time.get_ticks_usec() - t0) / 1000.0)
	mode = Mode.TITLE
	var dlg_open: bool = not world.modules.dialogue.session.is_empty()
	set_mode(Mode.COMBAT if world.modules.combat.active else (Mode.DIALOGUE if dlg_open else Mode.EXPLORE))
	world_reloaded.emit()
	logger.info("Persistence", "load", {"slot": slot, "backup": res.recovered_from_backup})
	return true


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if d is Dictionary:
			for k in d:
				settings[k] = d[k]


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "  "))
	settings_changed.emit()


## Atalhos de leitura (projeções) para a Apresentação
func m(id: String) -> WorldModule:
	return world.module(id) if world != null else null


func player_tile() -> Vector2i:
	return db.world_to_tile(world.player.position)
