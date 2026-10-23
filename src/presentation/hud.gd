extends CanvasLayer
## HUD de depuração: data/hora do mundo e últimos eventos. Só lê projeções.

@onready var _label: Label = $Label
@onready var _tint: CanvasModulate = get_node_or_null("../DayNight")
var _last_events: Array[String] = []


func _ready() -> void:
	Game.event_published.connect(_on_event)


func _on_event(e: GameEvent) -> void:
	if e.event_type == "PLAYER_MOVED":
		return
	_last_events.push_front(e.event_type)
	_last_events = _last_events.slice(0, 4)


func _process(_d: float) -> void:
	var c := Game.world.clock.calendar()
	_label.text = "Ano %d, mês %d, dia %d — %02d:%02d  (tick %d)\nF5 salvar · F9 carregar\n%s" % [
		c.year, c.month, c.day, c.hour, c.minute, Game.world.clock.tick, "\n".join(_last_events)]
	if _tint:
		# Luz simples dia/noite: 0 à meia-noite, 1 ao meio-dia.
		var f := Game.world.clock.day_fraction()
		var light := 0.35 + 0.65 * (0.5 - 0.5 * cos(f * TAU))
		_tint.color = Color(light, light, lerp(light, 1.0, 0.25))
