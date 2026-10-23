class_name CameraDirector
extends Camera2D
## Câmera cinematográfica (§9): responde a tags de eventos (ataque, impacto, crítico,
## queda, morte...). Zoom e tremor são só apresentação; opções reduzem movimento.

var target: Node2D
var _shake := 0.0
var _shake_t := 0.0
var _zoom_target := Vector2.ONE
var focus_override: Variant = null


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
	if focus_override is Vector2:
		global_position = global_position.lerp(focus_override, minf(1.0, delta * 6.0))
	elif target:
		global_position = target.global_position
	zoom = zoom.lerp(_zoom_target, minf(1.0, delta * 10.0))
	if _shake_t > 0.0:
		_shake_t -= delta
		offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		if _shake_t <= 0.0:
			_shake = 0.0
			offset = Vector2.ZERO
