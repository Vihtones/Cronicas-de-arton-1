extends CharacterBody2D
## Apresentação do jogador: lê input, move fisicamente e reporta posição ao Domínio
## via comando (com limiar, para não gerar um comando por frame).

@export var speed: float = 90.0
const REPORT_DISTANCE := 8.0
var _last_reported := Vector2.INF


func _ready() -> void:
	global_position = Game.world.player.position
	_last_reported = global_position


func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * speed
	move_and_slide()
	if global_position.distance_to(_last_reported) >= REPORT_DISTANCE or (dir == Vector2.ZERO and global_position != _last_reported):
		Game.send("MovePlayer", {"to": global_position})
		_last_reported = global_position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		Game.send("MovePlayer", {"to": global_position})
		Game.save_game()
	elif event.is_action_pressed("quick_load"):
		if Game.load_game():
			global_position = Game.world.player.position
			_last_reported = global_position
