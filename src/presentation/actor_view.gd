class_name ActorView
extends Node2D
## Figura animada (spritesheet 3x4: parado/passo1/passo2 x baixo/esq/dir/cima).
## Pura apresentação: posição/estado vêm de eventos e projeções.

signal arrived

const DIRS := {Vector2i(0, 1): 0, Vector2i(-1, 0): 1, Vector2i(1, 0): 2, Vector2i(0, -1): 3}
var sprite: Sprite2D
var label: Label
var hp_bar: ColorRect
var hp_back: ColorRect
var actor_id := ""
var direction := 0
var walking := false
var _anim_t := 0.0
var _tween: Tween
var down := false


func setup(id: String, sheet_path: String, display_name: String = "") -> void:
	actor_id = id
	sprite = Sprite2D.new()
	sprite.texture = load(sheet_path)
	sprite.hframes = 3
	sprite.vframes = 4
	sprite.offset = Vector2(0, -12)  # pivô nos pés (Art Bible: 16,28)
	add_child(sprite)
	if display_name != "":
		label = Label.new()
		label.text = display_name
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		label.position = Vector2(-40, -42)
		label.size = Vector2(80, 10)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.visible = false
		add_child(label)
	hp_back = ColorRect.new(); hp_back.color = Color(0, 0, 0, 0.7); hp_back.size = Vector2(22, 3); hp_back.position = Vector2(-11, -32); hp_back.visible = false
	hp_bar = ColorRect.new(); hp_bar.color = Color(0.85, 0.2, 0.2); hp_bar.size = Vector2(20, 1); hp_bar.position = Vector2(-10, -31); hp_bar.visible = false
	add_child(hp_back); add_child(hp_bar)


## Aparência provisória por raça (RaceLook): tinta no sprite e escala a partir dos pés.
func apply_race(race: String) -> void:
	var l := RaceLook.of(race)
	sprite.self_modulate = l.tint
	sprite.scale = Vector2.ONE * float(l.scale)


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
	sprite.modulate = Color(0.7, 0.7, 0.7) if v else Color.WHITE


func face_towards(target: Vector2) -> void:
	var d := target - position
	if d.length() < 0.1:
		return
	if absf(d.x) > absf(d.y):
		direction = 2 if d.x > 0 else 1
	else:
		direction = 0 if d.y > 0 else 3


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
		_tween.tween_property(self, "position", p, dur)
		prev = p
	_tween.tween_callback(func(): walking = false; arrived.emit())


func stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	walking = false


func _process(delta: float) -> void:
	if sprite == null:
		return
	if walking:
		_anim_t += delta * 8.0
		sprite.frame = direction * 3 + 1 + (int(_anim_t) % 2)
	else:
		sprite.frame = direction * 3
