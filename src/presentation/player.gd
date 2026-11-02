class_name PlayerView
extends CharacterBody2D
## Jogador: input -> movimento físico -> comando MovePlayer quando muda de tile.

@export var speed: float = 80.0
## Correr: segure Shift enquanto anda (não vale enquanto estiver furtivo). Só muda a velocidade na tela.
const CORRIDA := 1.8
## Movimento responsivo (Dead Cells): acelera e freia rápido, sem "patinar"; poeira ao arrancar e virar.
@export var accel: float = 900.0
@export var decel: float = 1100.0
var _last_dir := Vector2.ZERO
var view: ActorView
var _last_tile := Vector2i(-999, -999)
var input_enabled := true
## Pulo: atravessa um obstáculo baixo (água ou barranco) de um tile, até 2 tiles adiante.
const PULO_DURACAO := 0.3
var _facing := Vector2i(0, 1)
var _pulando := false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 10)
	shape.shape = rect
	shape.position = Vector2(0, 4)
	add_child(shape)
	view = ActorView.new()
	view.setup("player", "res://assets/chars/player.png")
	add_child(view)


## Direção cardeal (4 sentidos) de um vetor de movimento.
static func _cardinal(dir: Vector2) -> Vector2i:
	if absf(dir.x) >= absf(dir.y):
		return Vector2i(1 if dir.x > 0 else -1, 0)
	return Vector2i(0, 1 if dir.y > 0 else -1)


## Pode atravessar o tile: água e barranco (obstáculos baixos). Árvores, rochas e paredes não.
func _pulavel(t: Vector2i) -> bool:
	var info: Dictionary = Game.db.tile_info(t)
	return bool(info.get("water", false)) or bool(info.get("chasm", false))


## Pula sobre um obstáculo baixo à frente. Só na exploração; devolve true se pulou.
func pular() -> bool:
	if _pulando or Game.world == null or Game.mode != Game.Mode.EXPLORE or not input_enabled:
		return false
	var t := Game.db.world_to_tile(global_position)
	var meio := t + _facing
	var destino := t + _facing * 2
	if Game.db.static_walkable(meio) or not _pulavel(meio) or not Game.db.static_walkable(destino):
		return false
	_pulando = true
	velocity = Vector2.ZERO
	var alvo := Game.db.tile_to_world(destino)
	var tween := create_tween()
	tween.tween_property(self, "global_position", alvo, PULO_DURACAO)
	tween.tween_callback(func():
		_pulando = false
		_last_tile = destino
		Game.send("MovePlayer", {"to": alvo}))
	return true


func sync_from_world() -> void:
	global_position = Game.world.player.position
	_last_tile = Game.player_tile()
	view.apply_race(Game.world.player_sheet.race_id)


func _physics_process(_delta: float) -> void:
	if Game.world == null:
		return
	var dir := Vector2.ZERO
	if input_enabled and not _pulando and Game.mode == Game.Mode.EXPLORE and Game.world.modules.travel.current_region == "vila":
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var sneaking: bool = Game.world.modules.combat.stance_sneak
	var correndo := dir != Vector2.ZERO and not sneaking and Input.is_key_pressed(KEY_SHIFT)
	var target_v := dir * (speed * (0.5 if sneaking else (CORRIDA if correndo else 1.0)))
	var rate := accel if dir != Vector2.ZERO else decel
	velocity = velocity.move_toward(target_v, rate * _delta)
	if dir != Vector2.ZERO and (_last_dir == Vector2.ZERO or dir.dot(_last_dir) < 0.2 or correndo) and not sneaking:
		ImpactFx.dust(get_parent(), global_position, dir, 4)   # arrancar ou mudar de direção levanta poeira
	if dir != Vector2.ZERO:
		_facing = _cardinal(dir)
	_last_dir = dir
	move_and_slide()
	view.walking = velocity.length() > 8.0
	if dir != Vector2.ZERO:
		view.face_towards(view.position + dir * 10)
	view.modulate = Color(0.75, 0.75, 0.95, 0.85) if sneaking else Color.WHITE
	var t := Game.db.world_to_tile(global_position)
	if t != _last_tile and Game.mode == Game.Mode.EXPLORE and not _pulando:
		_last_tile = t
		Game.send("MovePlayer", {"to": global_position})
		if Game.mode != Game.Mode.EXPLORE:
			# um encontro começou: alinha ao centro do tile do combate
			global_position = Game.db.tile_to_world(t)
