class_name SpeechBubble
extends RefCounted
## Balão de fala sobre um ator (apresentação). Usado pelos figurantes e pelos moradores.


static func show(host: Node, v: ActorView, txt: String) -> void:
	if txt == "" or not is_instance_valid(v):
		return
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", Color(0.15, 0.12, 0.1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.94, 0.86, 0.92)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(2)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	l.add_theme_stylebox_override("normal", sb)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate.a = 0.0
	l.z_index = 5
	v.add_child(l)
	l.reset_size()   # o balão tem o tamanho exato do texto
	l.position = Vector2(-l.size.x / 2.0, -44)
	var tw := host.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(l, "position:y", -48.0, 0.2)
	tw.tween_interval(clampf(0.9 + txt.length() * 0.045, 1.4, 3.2))
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)
