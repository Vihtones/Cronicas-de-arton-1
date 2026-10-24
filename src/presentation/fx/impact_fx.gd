class_name ImpactFx
extends RefCounted
## Efeitos de combate procedurais (sistema de teste: as texturas finais entram depois, pelo governador).
## Referências (docs/REFERENCIAS_VISUAIS.md): o peso vem da SOMA de efeitos (Dead Cells), o inimigo
## reage a todo golpe (guia de "juice"), o erro é mais discreto que o acerto, a magia tem flash de luz.
## Tudo é desenhado com Line2D, Polygon2D e CPUParticles2D com texturas geradas — sem arte externa.

static var _dot: Texture2D
static var _soft: Texture2D


static func _tex_dot() -> Texture2D:
	if _dot == null:
		var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_dot = ImageTexture.create_from_image(img)
	return _dot


static func _tex_soft() -> Texture2D:
	if _soft == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		for y in 8:
			for x in 8:
				var d := Vector2(x - 3.5, y - 3.5).length() / 4.0
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
		_soft = ImageTexture.create_from_image(img)
	return _soft


## Acesso ao autoload sem depender dele na compilação (ferramentas de captura carregam esta classe antes).
static func _g() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Game")


static func _enabled() -> bool:
	return not _g().safe_mode


## Rastro do golpe "cortando o ar": arco afinando nas pontas, branco-azulado, some rápido.
## kind: corte (arco largo), perfuracao (estocada reta), impacto (arco curto e grosso).
static func slash_trail(parent: Node, from: Vector2, to: Vector2, kind: String = "corte", hit: bool = true, crit: bool = false) -> void:
	if not _enabled():
		return
	var d := (to - from)
	var dir := d.normalized()
	var n := Vector2(-dir.y, dir.x)
	var line := Line2D.new()
	line.z_index = 30
	line.texture_mode = Line2D.LINE_TEXTURE_NONE
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.05)); curve.add_point(Vector2(0.55, 1.0)); curve.add_point(Vector2(1, 0.1))
	line.width_curve = curve
	var g := Gradient.new()
	var core := Color(1.0, 0.95, 0.8) if crit else Color(0.92, 0.97, 1.0)
	g.colors = PackedColorArray([Color(core, 0.0), Color(core, 0.95), Color(0.6, 0.8, 1.0, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	line.gradient = g
	var center := from + d * 0.62
	var pts := PackedVector2Array()
	match kind:
		"perfuracao":
			line.width = 5.0
			for i in 9:
				pts.append(from + dir * (6.0 + d.length() * 0.85 * float(i) / 8.0))
		"impacto":
			line.width = 10.0
			for i in 9:
				var a := lerpf(-0.9, 0.9, float(i) / 8.0)
				pts.append(center + (n * cos(a) * 11.0 + dir * sin(a) * 5.0))
		_:
			line.width = 9.0 if not crit else 13.0
			for i in 15:
				var a := lerpf(-1.4, 1.4, float(i) / 14.0)
				pts.append(center + (n * sin(a) * 24.0 - dir * (1.0 - cos(a)) * 11.0))
	line.points = pts
	parent.add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.22 if hit else 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(line, "position", dir * 6.0, 0.22)
	tw.tween_callback(line.queue_free)
	if not hit:
		# "vento" do golpe que errou: duas linhas finas seguindo adiante
		for k in 2:
			var w := Line2D.new()
			w.z_index = 29
			w.width = 1.0
			w.default_color = Color(0.85, 0.92, 1.0, 0.6)
			var off := n * (6.0 if k == 0 else -6.0)
			w.points = PackedVector2Array([to + off - dir * 8.0, to + off + dir * 14.0])
			parent.add_child(w)
			var tw2 := w.create_tween()
			tw2.tween_property(w, "position", dir * 14.0, 0.25)
			tw2.parallel().tween_property(w, "modulate:a", 0.0, 0.25)
			tw2.tween_callback(w.queue_free)


## Explosão de impacto no alvo: faíscas (metal), poeira (impacto), gotas escuras (corte), anel de choque.
static func impact_burst(parent: Node, at: Vector2, dir: Vector2, kind: String = "corte", crit: bool = false, strength: float = 1.0) -> void:
	if not _enabled():
		return
	var p := CPUParticles2D.new()
	p.z_index = 31
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int((14 if crit else 8) * clampf(strength, 0.6, 2.0))
	p.lifetime = 0.35
	p.texture = _tex_dot()
	p.direction = dir.normalized()
	p.spread = 55.0 if kind != "impacto" else 85.0
	p.initial_velocity_min = 60.0 * strength
	p.initial_velocity_max = 150.0 * strength
	p.damping_min = 120.0; p.damping_max = 220.0
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 0.5; p.scale_amount_max = 1.1
	match kind:
		"impacto":
			p.color = Color(0.82, 0.72, 0.58, 0.9)   # poeira
			p.gravity = Vector2(0, 40)
		"perfuracao", "corte":
			p.color = Color(0.55, 0.08, 0.08, 0.95) if not crit else Color(0.7, 0.1, 0.08)
		"magia":
			p.color = Color(0.65, 0.7, 1.0)
			p.gravity = Vector2.ZERO
		_:
			p.color = Color(1.0, 0.85, 0.5)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	p.position = at
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	# faíscas brancas curtas no ponto de contato
	var sp := CPUParticles2D.new()
	sp.z_index = 32
	sp.one_shot = true; sp.explosiveness = 1.0
	sp.amount = 6 if not crit else 12
	sp.lifetime = 0.16
	sp.texture = _tex_dot()
	sp.spread = 180.0
	sp.initial_velocity_min = 90.0; sp.initial_velocity_max = 200.0
	sp.scale_amount_min = 0.4; sp.scale_amount_max = 0.8
	sp.color = Color(1.0, 0.97, 0.85)
	sp.position = at
	parent.add_child(sp)
	sp.emitting = true
	sp.finished.connect(sp.queue_free)
	shockwave(parent, at, 18.0 if crit else 11.0, Color(1, 0.95, 0.85, 0.75))


## Anel de choque que se expande e some.
static func shockwave(parent: Node, at: Vector2, radius: float, col: Color) -> void:
	if not _enabled():
		return
	var ring := Line2D.new()
	ring.z_index = 30
	ring.width = 2.0
	ring.default_color = col
	var pts := PackedVector2Array()
	for i in 21:
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a), sin(a) * 0.6))
	ring.points = pts
	ring.position = at
	ring.scale = Vector2.ONE * 3.0
	parent.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2.ONE * radius, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	tw.parallel().tween_property(ring, "width", 0.5, 0.22)
	tw.tween_callback(ring.queue_free)


## Projétil mágico (Seta Infalível, Raio Arcano): cabeça brilhante com rastro, faz curva leve.
static func spell_bolt(parent: Node, from: Vector2, to: Vector2, col: Color, duration: float = 0.22, curve_amp: float = 14.0) -> void:
	if not _enabled():
		return
	var head := Sprite2D.new()
	head.texture = _tex_soft()
	head.scale = Vector2.ONE * 1.6
	head.modulate = Color(col, 1.0)
	head.z_index = 33
	head.position = from
	parent.add_child(head)
	var trail := CPUParticles2D.new()
	trail.texture = _tex_soft()
	trail.amount = 24
	trail.lifetime = 0.25
	trail.local_coords = false
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 0; trail.initial_velocity_max = 8
	trail.scale_amount_min = 0.4; trail.scale_amount_max = 0.9
	trail.color = Color(col, 0.7)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	trail.color_ramp = ramp
	head.add_child(trail)
	var n := (to - from).orthogonal().normalized() * curve_amp * (1.0 if randf() < 0.5 else -1.0)
	var tw := head.create_tween()
	tw.tween_method(func(t: float): head.position = from.lerp(to, t) + n * sin(t * PI), 0.0, 1.0, duration)
	tw.tween_callback(func():
		trail.emitting = false
		head.modulate.a = 0.0
		impact_burst(parent, to, to - from, "magia", false, 0.8))
	tw.tween_interval(0.3)
	tw.tween_callback(head.queue_free)


## Arco elétrico (Toque Chocante): zigue-zague que treme algumas vezes.
static func lightning(parent: Node, from: Vector2, to: Vector2) -> void:
	if not _enabled():
		return
	var line := Line2D.new()
	line.z_index = 33
	line.width = 2.0
	line.default_color = Color(0.75, 0.9, 1.0)
	parent.add_child(line)
	var tw := line.create_tween()
	for k in 5:
		tw.tween_callback(func():
			var pts := PackedVector2Array([from])
			var n := (to - from).orthogonal().normalized()
			for i in range(1, 7):
				pts.append(from.lerp(to, float(i) / 7.0) + n * randf_range(-7.0, 7.0))
			pts.append(to)
			line.points = pts)
		tw.tween_interval(0.045)
	tw.tween_property(line, "modulate:a", 0.0, 0.12)
	tw.tween_callback(line.queue_free)
	impact_burst(parent, to, to - from, "magia", false, 1.0)


## Anel cintilante (Armadura Arcana) e brilhos subindo (cura).
static func aura(parent: Node, at: Vector2, col: Color, rising: bool = false) -> void:
	if not _enabled():
		return
	var p := CPUParticles2D.new()
	p.z_index = 33
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 18
	p.lifetime = 0.7
	p.texture = _tex_soft()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 12.0
	p.gravity = Vector2(0, -60) if rising else Vector2.ZERO
	p.initial_velocity_min = 4; p.initial_velocity_max = 18
	p.scale_amount_min = 0.3; p.scale_amount_max = 0.7
	p.color = col
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	p.position = at + Vector2(0, -12)
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	shockwave(parent, at + Vector2(0, -8), 14.0, Color(col, 0.8))


## Poeira dos pés (arrancar, frear, virar): vende a sensação de peso no movimento.
static func dust(parent: Node, at: Vector2, dir: Vector2 = Vector2.ZERO, amount: int = 5) -> void:
	if not _enabled() or _g().settings.graphics == "baixo":
		return
	var p := CPUParticles2D.new()
	p.z_index = 2
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.4
	p.texture = _tex_soft()
	p.direction = -dir if dir != Vector2.ZERO else Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 10; p.initial_velocity_max = 30
	p.gravity = Vector2(0, -12)
	p.scale_amount_min = 0.4; p.scale_amount_max = 0.8
	p.color = Color(0.78, 0.7, 0.58, 0.55)
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	p.position = at + Vector2(0, 2)
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Hit stop (Dead Cells): congela quase tudo por alguns milissegundos reais.
static func hit_stop(tree: SceneTree, seconds: float, slow_after: float = 0.0) -> void:
	if _g().settings.reduce_motion or _g().safe_mode or seconds <= 0.0:
		return
	Engine.time_scale = 0.05
	tree.create_timer(seconds, true, false, true).timeout.connect(func():
		if slow_after > 0.0:
			Engine.time_scale = 0.4
			tree.create_timer(slow_after, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)
		else:
			Engine.time_scale = 1.0)
