class_name ActorView
extends Node2D
## Figura animada (spritesheet 3x4: parado/passo1/passo2 x baixo/esq/dir/cima).
## Pura apresentação: posição/estado vêm de eventos e projeções.
## Animação procedural inspirada em Dead Cells (CUR-011: antecipação, impacto, recuperação, peso):
## respiração parada, balanço ao andar, compressão ao arrancar e parar, golpe com antecipação e
## avanço, reação ao ser atingido (recuo, tremor, flash) e esquiva. Sombra de contato sob os pés e
## sombra projetada pelo sol de dia ou pela luz mais próxima à noite (técnica do Graveyard Keeper).

signal arrived

const DIRS := {Vector2i(0, 1): 0, Vector2i(-1, 0): 1, Vector2i(1, 0): 2, Vector2i(0, -1): 3}
static var fx: FxLayer                     # definido pela cena principal (luzes para as sombras)

var sprite: Sprite2D
var shadow_contact: Sprite2D
var shadow_cast: Sprite2D
var label: Label
var hp_bar: ColorRect
var hp_back: ColorRect
var actor_id := ""
var direction := 0
var walking := false
var down := false
var base_scale := 1.0
var quadro_k := 1.0                # tamanho do quadro em relação a 32 px (sprites antigos 1, LPC de 64 px: 2)
var _anim_t := 0.0
var _tween: Tween
var _was_walking := false
# camada procedural sobre o sprite (molas simples, sem tweens concorrentes)
var _off := Vector2.ZERO          # deslocamento do corpo (recuo, avanço)
var _off_v := Vector2.ZERO
var _sq := Vector2.ONE            # compressão/estiramento
var _sq_v := Vector2.ZERO
var _shake := 0.0
var _flash := 0.0
var _breath := randf() * TAU

static var _ellipse_tex: Texture2D


func setup(id: String, sheet_path: String, display_name: String = "") -> void:
	actor_id = id
	if _ellipse_tex == null:
		_ellipse_tex = _make_ellipse()
	shadow_contact = Sprite2D.new()
	shadow_contact.texture = _ellipse_tex
	shadow_contact.position = Vector2(0, 3)
	shadow_contact.modulate = Color(0, 0, 0, 0.38)
	add_child(shadow_contact)
	var tex: Texture2D = load(sheet_path)
	quadro_k = float(tex.get_height() / 4) / 32.0
	var pe_y := 28.0 * quadro_k                       # pés dentro do quadro (Art Bible: pivô 16,28 em 32 px)
	var deslocamento := Vector2(0, -(pe_y - 16.0 * quadro_k))
	var alto := 60.0 if quadro_k > 1.5 else 32.0      # altura da figura acima dos pés (barras e nome)
	shadow_contact.scale = Vector2.ONE * (1.0 + 0.3 * (quadro_k - 1.0))
	shadow_cast = Sprite2D.new()
	shadow_cast.texture = tex
	shadow_cast.hframes = 3
	shadow_cast.vframes = 4
	shadow_cast.offset = deslocamento
	shadow_cast.modulate = Color(0, 0, 0, 0.0)
	add_child(shadow_cast)
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.hframes = 3
	sprite.vframes = 4
	sprite.offset = deslocamento  # pivô nos pés (Art Bible: 16,28 em 32 px)
	add_child(sprite)
	if display_name != "":
		label = Label.new()
		label.text = display_name
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		label.position = Vector2(-40, -(alto + 10.0))
		label.size = Vector2(80, 10)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.visible = false
		add_child(label)
	hp_back = ColorRect.new(); hp_back.color = Color(0, 0, 0, 0.7); hp_back.size = Vector2(22, 3); hp_back.position = Vector2(-11, -alto); hp_back.visible = false
	hp_bar = ColorRect.new(); hp_bar.color = Color(0.85, 0.2, 0.2); hp_bar.size = Vector2(20, 1); hp_bar.position = Vector2(-10, -alto + 1.0); hp_bar.visible = false
	add_child(hp_back); add_child(hp_bar)


static func _make_ellipse() -> Texture2D:
	var img := Image.create(20, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 20:
			var dx := (x - 9.5) / 10.0
			var dy := (y - 3.5) / 4.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - (dx * dx + dy * dy), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## Aparência provisória por raça (RaceLook): tinta no sprite e escala a partir dos pés.
func apply_race(race: String) -> void:
	var l := RaceLook.of(race)
	sprite.self_modulate = l.tint
	base_scale = float(l.scale)
	shadow_contact.scale = Vector2.ONE * base_scale * (1.0 + 0.3 * (quadro_k - 1.0))


func show_name(v: bool) -> void:
	if label: label.visible = v


func set_hp(pv: int, pv_max: int, visible_bar: bool = true) -> void:
	hp_back.visible = visible_bar; hp_bar.visible = visible_bar
	hp_bar.size.x = 20.0 * clampf(float(pv) / maxf(1, pv_max), 0.0, 1.0)
	hp_bar.color = Color(0.85, 0.2, 0.2) if pv > 0 else Color(0.4, 0.4, 0.4)
	set_down(pv <= 0)


func set_down(v: bool) -> void:
	down = v
	sprite.rotation = PI / 2 if v else 0.0


func face_towards(target: Vector2) -> void:
	face_dir(target - position)


func face_dir(d: Vector2) -> void:
	if d.length() < 0.1:
		return
	if absf(d.x) > absf(d.y):
		direction = 2 if d.x > 0 else 1
	else:
		direction = 0 if d.y > 0 else 3


func walk_path(points: Array, speed: float = 64.0) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if points.is_empty():
		arrived.emit(); return
	walking = true
	_tween = create_tween()
	var prev := position
	for p in points:
		var dur := prev.distance_to(p) / maxf(1.0, speed)
		_tween.tween_callback(face_towards.bind(p))
		_tween.tween_property(self, "position", p, dur).set_trans(Tween.TRANS_SINE)
		prev = p
	_tween.tween_callback(func(): walking = false; arrived.emit())


func stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	walking = false


# --- Animação de combate (Dead Cells: antecipação → golpe → recuperação) -------------------------
## Antecipação: recua e comprime; depois avança esticado na direção do alvo. Retorna o tempo até o golpe.
func play_attack(toward: Vector2, heavy: bool = false) -> float:
	var d := toward.normalized()
	face_dir(d)
	_off_v = -d * (70.0 if heavy else 50.0)
	_sq = Vector2(1.12, 0.88)
	var wind := 0.07 if heavy else 0.05
	get_tree().create_timer(wind, true, false, false).timeout.connect(_strike.bind(d, heavy))
	return wind


func _strike(d: Vector2, heavy: bool) -> void:
	_off_v = d * (260.0 if heavy else 210.0)
	_sq = Vector2(0.86, 1.14)


## Reação ao ser atingido: recuo na direção do golpe, tremor, compressão e flash branco.
func play_hit(from_dir: Vector2, strength: float = 1.0, crit: bool = false) -> void:
	var d := from_dir.normalized()
	_off_v += d * (160.0 + 120.0 * strength)
	_sq = Vector2(1.18, 0.82) if crit else Vector2(1.1, 0.9)
	_shake = 3.0 * strength + (2.0 if crit else 0.0)
	if not Game.settings.reduce_flashes:
		_flash = 1.0


## Esquiva: passo lateral rápido em relação ao golpe.
func play_dodge(from_dir: Vector2) -> void:
	var side := Vector2(-from_dir.y, from_dir.x).normalized()
	if randf() < 0.5: side = -side
	_off_v += side * 220.0
	_sq = Vector2(0.92, 1.06)


## Compressão de impacto (arrancar, frear, levantar).
func squash(amount: float = 0.1) -> void:
	_sq = Vector2(1.0 + amount, 1.0 - amount)


func _process(delta: float) -> void:
	if sprite == null:
		return
	if walking:
		_anim_t += delta * 8.0
		sprite.frame = direction * 3 + 1 + (int(_anim_t) % 2)
	else:
		sprite.frame = direction * 3
	if walking != _was_walking:
		squash(0.08 if walking else 0.1)   # arrancar e frear têm peso
		_was_walking = walking
	# molas amortecidas: o corpo volta ao lugar com fluidez, sem travar
	_off_v += (-180.0 * _off - 16.0 * _off_v) * delta
	_off += _off_v * delta
	_sq_v += (-260.0 * (_sq - Vector2.ONE) - 18.0 * _sq_v) * delta
	_sq += _sq_v * delta
	if not walking:
		_breath += delta * 2.4
	var breath := 0.0 if walking or down else sin(_breath) * 0.015
	var bob := -absf(sin(_anim_t * PI)) * 1.5 if walking else 0.0
	var shake_off := Vector2.ZERO
	if _shake > 0.0:
		shake_off = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake) * 0.5)
		_shake = move_toward(_shake, 0.0, delta * 18.0)
	sprite.position = _off + shake_off + Vector2(0, bob)
	if not down:
		sprite.scale = Vector2(_sq.x, _sq.y + breath) * base_scale
	else:
		sprite.scale = Vector2.ONE * base_scale
	if _flash > 0.0:
		_flash = move_toward(_flash, 0.0, delta * 9.0)
	sprite.modulate = (Color(0.7, 0.7, 0.7) if down else Color.WHITE).lerp(Color(3, 3, 3), _flash)
	_update_shadow()


## Sombra projetada: de dia pelo sol; à noite pela luz mais forte por perto (até 150px).
func _update_shadow() -> void:
	shadow_cast.frame = sprite.frame
	shadow_cast.position = Vector2(_off.x, 2)
	if fx == null or Game.safe_mode or Game.settings.graphics == "baixo" or down:
		shadow_cast.modulate.a = 0.0
		return
	var dir: Vector2 = fx.sun_dir
	var alpha := 0.22 * (1.0 - fx.night)
	var lt: Variant = fx.strongest_light_near(global_position)
	if fx.night > 0.45 and lt != null:
		var lp: Vector2 = (lt as Node2D).global_position
		dir = (global_position - lp).normalized() * clampf(lp.distance_to(global_position) / 70.0, 0.4, 1.4)
		alpha = 0.3 * clampf(1.0 - lp.distance_to(global_position) / 150.0, 0.0, 1.0) * fx.night
	shadow_cast.modulate = Color(0, 0, 0, alpha)
	# achata e inclina a silhueta na direção oposta à luz
	shadow_cast.scale = Vector2(base_scale, -0.45 * base_scale * clampf(dir.length(), 0.4, 1.4))
	shadow_cast.skew = clampf(dir.x * 0.9, -1.1, 1.1)
