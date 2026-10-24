class_name PlayerView
extends CharacterBody2D
## Jogador: input -> movimento físico -> comando MovePlayer quando muda de tile.

@export var speed: float = 80.0
var view: ActorView
var _last_tile := Vector2i(-999, -999)
var input_enabled := true


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


func sync_from_world() -> void:
	global_position = Game.world.player.position
	_last_tile = Game.player_tile()
	view.apply_race(Game.world.player_sheet.race_id)


func _physics_process(_delta: float) -> void:
	if Game.world == null:
		return
	var dir := Vector2.ZERO
	if input_enabled and Game.mode == Game.Mode.EXPLORE and Game.world.modules.travel.current_region == "vila":
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var sneaking: bool = Game.world.modules.combat.stance_sneak
	velocity = dir * (speed * (0.5 if sneaking else 1.0))
	move_and_slide()
	view.walking = dir != Vector2.ZERO
	if dir != Vector2.ZERO:
		view.face_towards(view.position + dir * 10)
	view.modulate = Color(0.75, 0.75, 0.95, 0.85) if sneaking else Color.WHITE
	var t := Game.db.world_to_tile(global_position)
	if t != _last_tile and Game.mode == Game.Mode.EXPLORE:
		_last_tile = t
		Game.send("MovePlayer", {"to": global_position})
		if Game.mode != Game.Mode.EXPLORE:
			# um encontro começou: alinha ao centro do tile do combate
			global_position = Game.db.tile_to_world(t)
