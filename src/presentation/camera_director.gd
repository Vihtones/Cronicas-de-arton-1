class_name CameraDirector
extends Camera2D
## Câmera cinematográfica (§9): responde a tags de eventos (ataque, impacto, crítico,
## queda, morte...). Zoom e tremor são só apresentação; opções reduzem movimento.

var target: Node2D
var _shake := 0.0
var _shake_t := 0.0
var _zoom_target := Vector2.ONE
var focus_override: Variant = null
var _cine: Variant = null          # foco cinematográfico (tem prioridade)
var _cine_zoom := 1.0


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 6.0
	limit_left = 0
	limit_top = 0


func set_bounds(size_tiles: Vector2i) -> void:
	limit_right = size_tiles.x * 32
	limit_bottom = size_tiles.y * 32


func shake(strength: float, duration: float) -> void:
	if Game.settings.reduce_motion:
		return
	_shake = maxf(_shake, strength)
	_shake_t = maxf(_shake_t, duration)


func punch(z: float = 1.12, back_after: float = 0.25) -> void:
	if Game.settings.reduce_motion:
		return
	_zoom_target = Vector2(z, z)
	get_tree().create_timer(back_after).timeout.connect(func(): _zoom_target = Vector2.ONE)


## Aproximação cinematográfica (CinematicDirector). Ignora a escala de tempo para não "travar" na câmera lenta.
func cinematic(focus: Vector2, z: float) -> void:
	if Game.settings.reduce_motion:
		return
	_cine = focus
	_cine_zoom = z


func release_cinematic() -> void:
	_cine = null
	_cine_zoom = 1.0


func react(tags: Array) -> void:
	if tags.has("critico"):
		shake(5.0, 0.3); punch(1.18, 0.35)
	elif tags.has("impacto"):
		shake(2.5, 0.15)
	if tags.has("queda"):
		shake(3.0, 0.25)
	if tags.has("morte"):
		punch(1.25, 0.6)


func _process(delta: float) -> void:
	var rd := delta / maxf(0.05, Engine.time_scale)   # tempo real: a câmera não trava na câmera lenta
	if _cine is Vector2:
		global_position = global_position.lerp(_cine, minf(1.0, rd * 9.0))
		zoom = zoom.lerp(Vector2.ONE * _cine_zoom, minf(1.0, rd * 7.0))
	elif focus_override is Vector2:
		global_position = global_position.lerp(focus_override, minf(1.0, rd * 6.0))
		zoom = zoom.lerp(_zoom_target, minf(1.0, rd * 10.0))
	else:
		if target:
			global_position = target.global_position
		zoom = zoom.lerp(_zoom_target, minf(1.0, rd * 10.0))
	if _shake_t > 0.0:
		_shake_t -= rd
		offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		if _shake_t <= 0.0:
			_shake = 0.0
			offset = Vector2.ZERO
