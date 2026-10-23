class_name FxLayer
extends Node2D
## Dia/noite (CanvasModulate), luzes 2D com orçamento por perfil, chuva e neblina.
## Perfis reduzem efeitos visuais sem desligar efeitos lógicos (§12).

var modulate_node: CanvasModulate
var rain: CPUParticles2D
var fog: ColorRect
var fog_layer: CanvasLayer
var lights: Array[PointLight2D] = []
var camera: Camera2D
var _light_tex: Texture2D

const TORCHES := [[6, 53], [12, 58], [26, 52], [33, 59], [38, 54], [18, 56], [9, 12], [14, 15], [27, 11], [32, 15]]


func build(cam: Camera2D) -> void:
	camera = cam
	modulate_node = CanvasModulate.new()
	add_child(modulate_node)
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.85, 0.6, 1))
	g.set_color(1, Color(1, 0.85, 0.6, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128; gt.height = 128
	_light_tex = gt
	for t in TORCHES:
		var l := PointLight2D.new()
		l.texture = _light_tex
		l.texture_scale = 2.0
		l.energy = 1.1
		l.color = Color(1.0, 0.75, 0.45)
		l.position = Vector2(t[0] * 32 + 16, t[1] * 32 + 16)
		add_child(l)
		lights.append(l)
	rain = CPUParticles2D.new()
	rain.amount = 260
	rain.lifetime = 0.7
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(360, 10)
	rain.direction = Vector2(0.25, 1)
	rain.spread = 4
	rain.gravity = Vector2(60, 900)
	rain.initial_velocity_min = 260
	rain.initial_velocity_max = 340
	rain.scale_amount_min = 1.0
	rain.scale_amount_max = 1.0
	rain.color = Color(0.85, 0.9, 1.0, 0.9)
	rain.z_index = 50
	rain.local_coords = false
	var drop := Image.create(2, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in 2:
			drop.set_pixel(x, y, Color(1, 1, 1, 0.25 + 0.075 * y))
	rain.texture = ImageTexture.create_from_image(drop)
	rain.emitting = false
	cam.add_child(rain)
	rain.position = Vector2(0, -200)
	fog_layer = CanvasLayer.new()
	fog_layer.layer = 1
	add_child(fog_layer)
	fog = ColorRect.new()
	fog.color = Color(0.78, 0.8, 0.85, 0.0)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog_layer.add_child(fog)
	apply_profile()


func apply_profile() -> void:
	var prof: String = Game.settings.graphics
	for l in lights:
		l.enabled = prof != "baixo"
		l.shadow_enabled = prof == "alto"
	rain.amount = {"baixo": 60, "medio": 180, "alto": 320}.get(prof, 180)


func _process(_d: float) -> void:
	if Game.world == null:
		return
	var t := Game.player_tile()
	var zone := Game.db.zone_at(t)
	var loc := Game.db.location(Game.db.location_at(t))
	var indoor: bool = loc.get("indoor", false) or zone == "cripta"
	var w: WeatherModule = Game.world.modules.weather
	var f: float = Game.world.clock.day_fraction()
	var daylight := clampf(0.5 - 0.5 * cos(f * TAU), 0.0, 1.0)  # 0 meia-noite, 1 meio-dia
	var k := smoothstep(0.15, 0.65, daylight)
	var col := Color(0.17, 0.19, 0.34).lerp(Color(1, 1, 1), k)       # noite azulada -> dia
	if k > 0.2 and k < 0.85:
		col = col.lerp(Color(1.0, 0.72, 0.55), 0.22 * (1.0 - absf(k - 0.5) * 2.0))  # crepúsculo
	if zone == "cripta":
		col = Color(0.32, 0.3, 0.38)
	elif w.enabled and w.region.condition in ["chuva", "tempestade"]:
		col = col.darkened(0.2)
	modulate_node.color = col
	var raining: bool = w.is_raining() and not indoor
	rain.emitting = raining
	var fog_a := 0.3 if (w.enabled and w.region.condition == "neblina" and not indoor) else 0.0
	fog.color.a = lerpf(fog.color.a, fog_a, 0.05)
