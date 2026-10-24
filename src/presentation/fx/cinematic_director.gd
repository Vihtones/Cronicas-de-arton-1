class_name CinematicDirector
extends CanvasLayer
## Momentos cinematográficos do combate (pedido do usuário; Bíblia: combate tático legível, luz emocional).
## Lê o resultado JÁ decidido pelo domínio e decide se o momento merece destaque. Nunca altera resultados.
## Gatilhos (jogador E inimigos):
##   crítico · falha no 20 natural do alvo · abate · 1 natural ("falha crítica") · aposta arriscada que deu
##   certo (fantasma previa < 35% de acerto) · plano "garantido" que deu errado (fantasma previa ≥ 80%)
##   · magia que derruba o alvo.
## Sequência: barras de cinema entram → câmera aproxima → retrato do atacante (antecipação) → golpe em
## câmera lenta → retrato do alvo com a reação e a legenda → tudo volta. Pulável com clique/tecla.
## "Reduzir movimento": sem zoom nem câmera lenta (ficam retratos e legenda). Velocidade instantânea: nada.

signal finished
signal started

var camera: CameraDirector
var post: PostProcess
var bar_top: ColorRect
var bar_bottom: ColorRect
var left: Portrait
var right: Portrait
var caption: Label
var sub_caption: Label
var expectations: Dictionary = {}   # alvo -> chance de acerto prevista pelo fantasma (último plano confirmado)
var _last_moment_turn := -99
var _turn := 0
var running := false
var _skip := false


func _ready() -> void:
	layer = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	bar_top = _bar(); bar_bottom = _bar()
	left = Portrait.new(); right = Portrait.new()
	for pt in [left, right]:
		pt.size = Vector2(72, 72)
		pt.modulate.a = 0.0
		add_child(pt)
	caption = _label(22, Color(1.0, 0.86, 0.45))
	sub_caption = _label(10, Color(0.92, 0.9, 0.86))
	_layout()


func _bar() -> ColorRect:
	var b := ColorRect.new()
	b.color = Color(0, 0, 0, 1)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.size = Vector2(640, 0)
	add_child(b)
	return b


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(640, 30)
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _layout() -> void:
	bar_top.position = Vector2.ZERO
	bar_bottom.position = Vector2(0, 360)
	left.position = Vector2(-80, 236)
	right.position = Vector2(648, 236)
	caption.position = Vector2(0, 150)
	sub_caption.position = Vector2(0, 178)


func new_turn() -> void:
	_turn += 1


## Avalia um ATTACK_RESOLVED / COUP_DE_GRACE. Retorna {} ou o momento a encenar.
func evaluate(p: Dictionary, sim: CombatSim) -> Dictionary:
	if float(Game.settings.combat_speed) <= 0.0:
		return {}
	var attacker: String = p.get("attacker", "")
	var target: String = p.get("target", "")
	var hit: bool = p.get("hit", true)
	var crit: bool = p.get("crit", false)
	var d20 := int(p.get("d20", 0))
	var killed := int(p.get("pv_after", 1)) <= 0
	var exp_hit: float = float(expectations.get(target, -1.0)) if attacker == "player" else -1.0
	var m := {}
	if crit and hit:
		m = {"caption": "CRÍTICO!", "sub": _sub(p), "a": "furioso", "t": "dor", "zoom": 1.9, "slow": 0.55, "chroma": 1.0}
	elif killed and sim and sim.combatants.has(target):
		m = {"caption": "ABATIDO!" if target != "player" else "VOCÊ CAI!", "sub": _sub(p), "a": "determinado", "t": "dor", "zoom": 1.7, "slow": 0.45, "chroma": 0.6}
	elif d20 == 1 and not p.get("spell", false):
		m = {"caption": "FALHA CRÍTICA", "sub": "%s tropeça no golpe." % Narrator._name(attacker), "a": "surpreso", "t": "alegria", "zoom": 1.5, "slow": 0.3, "chroma": 0.0}
	elif attacker == "player" and hit and exp_hit >= 0.0 and exp_hit < 0.35:
		m = {"caption": "CONTRA AS PROBABILIDADES!", "sub": "O plano arriscado (%d%%) deu certo." % int(exp_hit * 100), "a": "alegria", "t": "surpreso", "zoom": 1.6, "slow": 0.4, "chroma": 0.3}
	elif attacker == "player" and not hit and exp_hit >= 0.8:
		m = {"caption": "ESCAPOU!", "sub": "Nem o golpe \"certo\" (%d%%) acertou." % int(exp_hit * 100), "a": "surpreso", "t": "determinado", "zoom": 1.5, "slow": 0.3, "chroma": 0.0}
	elif target == "player" and not hit and d20 >= 15:
		m = {"caption": "POR UM FIO!", "sub": "%s quase acerta." % Narrator._name(attacker), "a": "furioso", "t": "medo", "zoom": 1.5, "slow": 0.3, "chroma": 0.0}
	if m.is_empty():
		return {}
	# não cansar: no máximo um momento comum por turno; crítico e abate sempre passam
	if not (crit or killed) and _last_moment_turn == _turn:
		return {}
	_last_moment_turn = _turn
	m["attacker"] = attacker
	m["target"] = target
	return m


func _sub(p: Dictionary) -> String:
	if p.get("spell", false):
		return "%s: %d de dano" % [p.get("weapon", "magia"), int(p.get("damage", 0))]
	return "%s · %d de dano" % [str(p.get("weapon", "")), int(p.get("damage", 0))]


func _race_of(id: String) -> String:
	if id == "player":
		return Game.world.player_sheet.race_id
	return "humano"


## Primeira metade: aproxima e mostra o atacante (antecipação). A segunda metade é reaction().
func begin(m: Dictionary, a_pos: Vector2, t_pos: Vector2) -> void:
	running = true
	_skip = false
	started.emit()
	var motion: bool = not Game.settings.reduce_motion and not Game.safe_mode
	left.set_actor(m.attacker, _race_of(m.attacker), m.attacker != "player")
	left.set_expression("determinado" if m.a != "surpreso" else "concentrado")
	right.set_actor(m.target, _race_of(m.target), m.target != "player")
	right.set_expression("neutro")
	var tw: Tween = create_tween().set_parallel(true).set_speed_scale(1.0 / maxf(0.05, Engine.time_scale))
	tw.tween_property(bar_top, "size:y", 40.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(bar_bottom, "position:y", 320.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(bar_bottom, "size:y", 40.0, 0.18)
	tw.tween_property(left, "position:x", 12.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(left, "modulate:a", 1.0, 0.15)
	if motion and camera:
		camera.cinematic((a_pos + t_pos) / 2.0, float(m.zoom))
	if post:
		var vp := get_viewport().get_visible_rect().size
		post.set_focus(Vector2(0.5, 0.5), 0.16)
		post.boost_blur(1.4 if motion else 0.6)
		if float(m.get("chroma", 0.0)) > 0.0:
			post.aberration(float(m.chroma))
	await _real_wait(0.32)
	if motion:
		Engine.time_scale = clampf(1.0 - float(m.slow), 0.25, 1.0)


## Segunda metade: reação do alvo, legenda e retorno.
func reaction(m: Dictionary) -> void:
	right.set_expression(m.t)
	left.set_expression(m.a)
	caption.text = m.caption
	sub_caption.text = m.sub
	caption.scale = Vector2.ONE * 1.4
	caption.pivot_offset = caption.size / 2.0
	var tw: Tween = create_tween().set_parallel(true).set_speed_scale(1.0 / maxf(0.05, Engine.time_scale))
	tw.tween_property(right, "position:x", 556.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(right, "modulate:a", 1.0, 0.15)
	tw.tween_property(caption, "modulate:a", 1.0, 0.12)
	tw.tween_property(caption, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sub_caption, "modulate:a", 1.0, 0.2).set_delay(0.1)
	await _real_wait(0.75)
	Engine.time_scale = 1.0
	await end()


func end() -> void:
	Engine.time_scale = 1.0
	if camera:
		camera.release_cinematic()
	if post:
		post.boost_blur(0.0)
		post.set_focus(Vector2(0.5, 0.5), 0.32)
	var tw: Tween = create_tween().set_parallel(true).set_speed_scale(1.0 / maxf(0.05, Engine.time_scale))
	tw.tween_property(bar_top, "size:y", 0.0, 0.2)
	tw.tween_property(bar_bottom, "position:y", 360.0, 0.2)
	tw.tween_property(bar_bottom, "size:y", 0.0, 0.2)
	tw.tween_property(left, "position:x", -80.0, 0.2)
	tw.tween_property(right, "position:x", 648.0, 0.2)
	for n in [left, right, caption, sub_caption]:
		tw.tween_property(n, "modulate:a", 0.0, 0.18)
	await tw.finished
	running = false
	finished.emit()


func skip() -> void:
	_skip = true
	Engine.time_scale = 1.0


func _real_wait(sec: float) -> void:
	if _skip:
		return
	await get_tree().create_timer(sec, true, false, true).timeout
