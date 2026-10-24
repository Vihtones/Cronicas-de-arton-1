class_name FxLayer
extends Node2D
## Luz e atmosfera (Bíblia de Arte: luz natural orgânica de Octopath, luz localizada e névoa de Children of
## Morta, credibilidade de Stoneshard). Técnicas da pesquisa (docs/REFERENCIAS_VISUAIS.md):
## - ciclo de luz por quadros-chave de hora do dia, com tom azul à noite e âmbar no entardecer;
## - gradação de cor por hora (no PostProcess);
## - tochas e janelas acesas com cintilação; luzes registradas para as sombras projetadas dos atores;
## - névoa em camadas com ruído rolando; chuva com respingos no chão.
## Perfis reduzem efeitos visuais sem desligar efeitos lógicos (§12). Modo seguro desliga tudo que é caro.

## [hora, cor ambiente, tinta da gradação, saturação, contraste, vinheta]
const KEYS := [
	[0.0, Color(0.16, 0.18, 0.33), Color(0.85, 0.9, 1.15), 0.75, 1.08, 0.5],
	[4.5, Color(0.2, 0.2, 0.36), Color(0.88, 0.9, 1.12), 0.78, 1.06, 0.48],
	[6.0, Color(0.72, 0.58, 0.62), Color(1.08, 0.95, 0.95), 0.92, 1.02, 0.36],
	[8.0, Color(0.96, 0.9, 0.82), Color(1.04, 1.0, 0.94), 1.0, 1.02, 0.28],
	[12.0, Color(1.0, 1.0, 0.98), Color(1.0, 1.0, 1.0), 1.02, 1.03, 0.24],
	[16.5, Color(1.0, 0.93, 0.82), Color(1.04, 0.99, 0.93), 1.04, 1.04, 0.28],
	[18.5, Color(0.9, 0.74, 0.6), Color(1.05, 0.95, 0.88), 0.98, 1.05, 0.34],
	[20.0, Color(0.4, 0.36, 0.5), Color(0.95, 0.9, 1.06), 0.86, 1.06, 0.42],
	[24.0, Color(0.16, 0.18, 0.33), Color(0.85, 0.9, 1.15), 0.75, 1.08, 0.5],
]

const TORCHES := [[6, 53], [12, 58], [26, 52], [33, 59], [38, 54], [18, 56], [9, 12], [14, 15], [27, 11], [32, 15], [22, 26], [24, 29]]

var modulate_node: CanvasModulate
var rain: CPUParticles2D
var splash: CPUParticles2D
var fog_layer: CanvasLayer
var fog_a: TextureRect
var fog_b: TextureRect
var lights: Array[PointLight2D] = []       # tochas (sempre acesas)
var windows: Array[PointLight2D] = []      # janelas (acendem ao anoitecer)
var camera: Camera2D
var post: PostProcess
var glow: CanvasLayer          # efeitos e números que brilham por cima da escuridão (não sofrem o CanvasModulate)
var night := 0.0                           # 0 dia .. 1 noite (para sombras e janelas)
var sun_dir := Vector2(1, 0.4)             # direção da sombra do sol
var _light_tex: Texture2D
var _t := 0.0


func build(cam: Camera2D) -> void:
	camera = cam
	modulate_node = CanvasModulate.new()
	add_child(modulate_node)
	_light_tex = _radial_tex(Color(1, 0.86, 0.62))
	for t in TORCHES:
		lights.append(_make_light(Vector2(t[0] * 32 + 16, t[1] * 32 + 16), Color(1.0, 0.7, 0.4), 1.15, 2.1, "tocha"))
	for o in Game.db.all_objects():
		if str(o.get("type", "")) == "door" and Game.db.zone_at(Vector2i(int(o.tile[0]), int(o.tile[1]))) == "vila":
			var wl := _make_light(Vector2(int(o.tile[0]) * 32 + 16, int(o.tile[1]) * 32 + 4), Color(1.0, 0.76, 0.42), 0.0, 1.5, "janela")
			windows.append(wl)
	_build_rain(cam)
	_build_fog()
	glow = CanvasLayer.new()
	glow.layer = 1
	glow.follow_viewport_enabled = true
	add_child(glow)
	post = PostProcess.new()
	add_child(post)
	apply_profile()


func _radial_tex(c: Color) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(c, 1.0), Color(c, 0.45), Color(c, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128; gt.height = 128
	return gt


func _make_light(pos: Vector2, col: Color, energy: float, scale_: float, kind: String) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.texture_scale = scale_
	l.energy = energy
	l.color = col
	l.position = pos
	l.set_meta("base_energy", energy if energy > 0.0 else 0.95)
	l.set_meta("base_scale", scale_)
	l.set_meta("kind", kind)
	l.set_meta("phase", randf() * TAU)
	l.add_to_group("luz_dinamica")
	add_child(l)
	return l


func _build_rain(cam: Camera2D) -> void:
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
	rain.color = Color(0.85, 0.9, 1.0, 0.8)
	rain.z_index = 50
	rain.local_coords = false
	var drop := Image.create(2, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in 2:
			drop.set_pixel(x, y, Color(1, 1, 1, 0.2 + 0.07 * y))
	rain.texture = ImageTexture.create_from_image(drop)
	rain.emitting = false
	cam.add_child(rain)
	rain.position = Vector2(0, -200)
	# respingos no chão (credibilidade: a chuva toca o mundo)
	splash = CPUParticles2D.new()
	splash.amount = 70
	splash.lifetime = 0.25
	splash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	splash.emission_rect_extents = Vector2(330, 190)
	splash.direction = Vector2(0, -1)
	splash.spread = 70
	splash.gravity = Vector2(0, 260)
	splash.initial_velocity_min = 18
	splash.initial_velocity_max = 40
	splash.scale_amount_min = 1.0
	splash.scale_amount_max = 1.5
	splash.color = Color(0.8, 0.86, 1.0, 0.55)
	splash.local_coords = false
	splash.z_index = 4
	splash.emitting = false
	cam.add_child(splash)


func _build_fog() -> void:
	fog_layer = CanvasLayer.new()
	fog_layer.layer = 1
	add_child(fog_layer)
	for i in 2:
		var n := FastNoiseLite.new()
		n.seed = 11 + i * 7
		n.frequency = 0.012 if i == 0 else 0.02
		n.fractal_octaves = 3
		var nt := NoiseTexture2D.new()
		nt.width = 512; nt.height = 288
		nt.seamless = true
		nt.noise = n
		var tr := TextureRect.new()
		tr.texture = nt
		tr.stretch_mode = TextureRect.STRETCH_TILE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.size = Vector2(1280, 720)
		tr.position = Vector2(-320, -180)
		tr.modulate = Color(0.82, 0.84, 0.9, 0.0)
		fog_layer.add_child(tr)
		if i == 0: fog_a = tr
		else: fog_b = tr


func apply_profile() -> void:
	var prof: String = Game.settings.graphics
	var safe: bool = Game.safe_mode
	for l in lights + windows:
		l.enabled = prof != "baixo" and not safe
		l.shadow_enabled = false
	rain.amount = {"baixo": 60, "medio": 180, "alto": 320}.get(prof, 180)
	splash.amount = {"baixo": 1, "medio": 50, "alto": 90}.get(prof, 50)
	if post:
		post.apply_profile(prof, safe)


## Interpola os quadros-chave pela hora do dia.
func _key_at(hour: float) -> Array:
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if hour >= float(a[0]) and hour <= float(b[0]):
			var k := smoothstep(0.0, 1.0, (hour - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])))
			return [(a[1] as Color).lerp(b[1], k), (a[2] as Color).lerp(b[2], k), lerpf(a[3], b[3], k), lerpf(a[4], b[4], k), lerpf(a[5], b[5], k)]
	return [KEYS[0][1], KEYS[0][2], KEYS[0][3], KEYS[0][4], KEYS[0][5]]


func _process(delta: float) -> void:
	if Game.world == null:
		return
	_t += delta
	var t := Game.player_tile()
	var zone := Game.db.zone_at(t)
	var loc := Game.db.location(Game.db.location_at(t))
	var indoor: bool = loc.get("indoor", false) or zone == "cripta"
	var w: WeatherModule = Game.world.modules.weather
	var hour: float = Game.world.clock.day_fraction() * 24.0
	var k := _key_at(hour)
	var amb: Color = k[0]
	var tint: Color = k[1]
	var sat: float = k[2]
	var con: float = k[3]
	var vig: float = k[4]
	night = clampf(1.0 - amb.v * 1.15, 0.0, 1.0)
	# o sol cruza de leste a oeste; sombras mais longas no início e no fim do dia
	var sun_k := clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	sun_dir = Vector2(lerpf(1.0, -1.0, sun_k), 0.35 + 0.65 * absf(sun_k - 0.5) * 2.0)
	if zone == "cripta":
		amb = Color(0.46, 0.42, 0.52); tint = Color(0.96, 0.93, 1.04); sat = 0.86; con = 1.06; vig = 0.45
		night = 1.0
	elif w.enabled and w.region.condition in ["chuva", "tempestade"] and not indoor:
		amb = amb.darkened(0.22).lerp(Color(0.55, 0.6, 0.72), 0.15)
		sat *= 0.8; tint = tint.lerp(Color(0.9, 0.95, 1.05), 0.5); vig += 0.08
	if w.enabled and w.region.condition == "tempestade" and not indoor and fmod(_t, 7.3) < 0.08 and randf() < 0.5 and post:
		post.flash(0.35, Color(0.85, 0.9, 1.0))   # relâmpago
	modulate_node.color = amb
	if post:
		post.grade(tint, sat, con, 0.0, vig)
	# tochas cintilam; janelas acendem conforme escurece (credibilidade: a vila vive à noite)
	for l in lights:
		var ph: float = l.get_meta("phase")
		var f := 0.88 + 0.08 * sin(_t * 7.3 + ph) + 0.05 * sin(_t * 13.1 + ph * 2.0)
		l.energy = float(l.get_meta("base_energy")) * f * (0.06 + 0.94 * smoothstep(0.15, 0.7, night))
		l.texture_scale = float(l.get_meta("base_scale")) * (0.97 + 0.03 * f)
	for wl in windows:
		var ph2: float = wl.get_meta("phase")
		var target := float(wl.get_meta("base_energy")) * smoothstep(0.35, 0.75, night) * (0.95 + 0.05 * sin(_t * 3.0 + ph2))
		wl.energy = lerpf(wl.energy, target, minf(1.0, delta * 2.0))
	var raining: bool = w.is_raining() and not indoor
	rain.emitting = raining and not Game.safe_mode
	splash.emitting = raining and not Game.safe_mode and Game.settings.graphics != "baixo"
	# névoa em duas camadas que rolam em velocidades diferentes (profundidade)
	var fog_target := 0.0
	if w.enabled and w.region.condition == "neblina" and not indoor:
		fog_target = 0.42
	elif zone == "floresta" and night > 0.5:
		fog_target = 0.12   # névoa baixa de mata à noite
	elif zone == "cripta":
		fog_target = 0.0
	if Game.safe_mode:
		fog_target = 0.0
	var cam_off := camera.global_position if camera else Vector2.ZERO
	fog_a.modulate.a = lerpf(fog_a.modulate.a, fog_target, minf(1.0, delta * 1.5))
	fog_b.modulate.a = lerpf(fog_b.modulate.a, fog_target * 0.7, minf(1.0, delta * 1.5))
	fog_a.position = Vector2(-320 + fposmod(-cam_off.x * 0.15 + _t * 6.0, 512.0) - 256, -180 + fposmod(-cam_off.y * 0.15, 288.0) - 144)
	fog_b.position = Vector2(-320 + fposmod(-cam_off.x * 0.3 - _t * 10.0, 512.0) - 256, -180 + fposmod(-cam_off.y * 0.3 + _t * 2.0, 288.0) - 144)


## Luz mais próxima e forte (para a sombra projetada dos atores à noite, técnica do Graveyard Keeper).
func strongest_light_near(p: Vector2, radius: float = 150.0) -> Variant:
	var best: Variant = null
	var best_d := radius
	for l in lights + windows:
		if not l.enabled or l.energy < 0.2:
			continue
		var d := l.global_position.distance_to(p)
		if d < best_d:
			best_d = d; best = l
	return best
