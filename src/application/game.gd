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


const IA_LOCAL := {"enabled": true, "endpoint": "http://127.0.0.1:8080/v1/chat/completions", "model": "local", "timeout_s": 12}


const IA_HEALTH := "http://127.0.0.1:8080/health"
const IA_PASTA := "IA local"          # pasta ao lado do executável, empacotada pelo build Windows
const IA_TENTATIVAS := 120           # 120 x 0,5 s: tempo para o modelo carregar
var _ia_pid := -1                    # servidor que o próprio jogo iniciou (-1: nenhum)


## Procura o servidor de IA local (llama.cpp em 127.0.0.1:8080). Se não estiver rodando e o pacote trouxer
## o servidor e o modelo em "IA local", o jogo o inicia sozinho e espera ele carregar.
## `done.call(bool)` diz se ligou. Grava user://ai.json.
func conectar_ia_local(done: Callable) -> void:
	_ia_sondar(done, 0)


func _ia_sondar(done: Callable, tentativa: int) -> void:
	var http := HTTPRequest.new()
	http.timeout = 2.0
	add_child(http)
	http.request_completed.connect(func(result, code, _h, _b):
		http.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			_ia_ligada(done)
		else:
			_ia_sem_resposta(done, tentativa))
	if http.request(IA_HEALTH) != OK:
		http.queue_free()
		_ia_sem_resposta(done, tentativa)


func _ia_sem_resposta(done: Callable, tentativa: int) -> void:
	if tentativa == 0 and _ia_pid <= 0:
		var embutida := _ia_embutida()
		if embutida.is_empty():
			done.call(false)
			return
		_ia_pid = OS.create_process(embutida.servidor, ["-m", embutida.modelo, "--host", "127.0.0.1", "--port", "8080", "-c", "2048", "-ngl", "99"])
		if _ia_pid <= 0:
			_ia_pid = -1
			done.call(false)
			return
	if _ia_pid > 0 and tentativa < IA_TENTATIVAS:
		get_tree().create_timer(0.5).timeout.connect(func(): _ia_sondar(done, tentativa + 1), CONNECT_ONE_SHOT)
		return
	done.call(false)


func _ia_ligada(done: Callable) -> void:
	var f := FileAccess.open("user://ai.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(IA_LOCAL))
	dialogue_provider = LlmDialogueProvider.new(IA_LOCAL, self)
	done.call(true)


## Servidor e modelo embutidos no pacote ("" se não houver): {servidor, modelo} ou {}.
func _ia_embutida() -> Dictionary:
	var pasta := OS.get_executable_path().get_base_dir().path_join(IA_PASTA)
	var servidor := pasta.path_join("llama-server.exe" if OS.get_name() == "Windows" else "llama-server")
	var modelo := pasta.path_join("modelo.gguf")
	if FileAccess.file_exists(servidor) and FileAccess.file_exists(modelo):
		return {"servidor": servidor, "modelo": modelo}
	return {}


func desligar_ia() -> void:
	_ia_encerrar()
	dialogue_provider = DialogueProvider.new()
	if FileAccess.file_exists("user://ai.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ai.json"))


## Encerra o servidor que o próprio jogo iniciou (não mexe em servidor iniciado à mão).
func _ia_encerrar() -> void:
	if _ia_pid > 0:
		OS.kill(_ia_pid)
	_ia_pid = -1


func _exit_tree() -> void:
	_ia_encerrar()


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
