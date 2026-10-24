class_name HotSlot
extends Button
## Espaço do cinto de atalhos (estilo Stoneshard): quadrado com moldura de bronze, ícone desenhado,
## tecla no canto e custo em PM. Ícones são PROVISÓRIOS (pictogramas procedurais) até haver arte aprovada.

var icon_id := ""
var key_text := ""
var cost := 0
var active := false          # alternância ligada (ex.: Ataque Especial, Pungente)
var badge := ""              # texto curto no canto inferior (ex.: "auto")


func _init() -> void:
	custom_minimum_size = Vector2(30, 30)
	focus_mode = Control.FOCUS_NONE
	text = ""
	clip_contents = true
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func setup(p_icon: String, p_key: String, tip: String, cb: Callable) -> HotSlot:
	icon_id = p_icon
	key_text = p_key
	tooltip_text = tip
	pressed.connect(cb)
	return self


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var hover: bool = is_hovered() and not disabled
	draw_rect(r, Color(0.06, 0.05, 0.06))
	draw_rect(r.grow(-2), Color(0.13, 0.11, 0.12) if not hover else Color(0.2, 0.16, 0.15))
	var edge := Color(0.86, 0.68, 0.36) if (hover or active) else Color(0.45, 0.35, 0.2)
	draw_rect(r, edge, false, 1.0)
	if active:
		draw_rect(r.grow(-2), Color(0.95, 0.75, 0.3, 0.18))
	var c := size / 2.0 + Vector2(0, 1)
	var ink := Color(0.93, 0.86, 0.7) if not disabled else Color(0.45, 0.42, 0.4)
	_icon(icon_id, c, ink)
	var font := get_theme_default_font()
	if key_text != "":
		draw_string(font, Vector2(2, 8), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.98, 0.82, 0.45))
	if cost > 0:
		draw_string(font, Vector2(size.x - 9, size.y - 2), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(0.55, 0.7, 1.0))
	if badge != "":
		draw_string(font, Vector2(2, size.y - 2), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.8, 0.9, 0.7))


func _icon(id: String, c: Vector2, ink: Color) -> void:
	match id:
		"mover":
			draw_rect(Rect2(c + Vector2(-4, -6), Vector2(5, 9)), ink)
			draw_rect(Rect2(c + Vector2(-4, 3), Vector2(9, 3)), ink)
		"atacar", "extra":
			draw_line(c + Vector2(-6, 6), c + Vector2(6, -6), ink, 2.0)
			draw_line(c + Vector2(-5, 1), c + Vector2(-1, 5), ink, 2.0)
			if id == "extra":
				draw_line(c + Vector2(6, 6), c + Vector2(-6, -6), ink, 2.0)
		"investida":
			for i in 3: draw_line(c + Vector2(-7 + i * 4, -5), c + Vector2(-3 + i * 4, 0), ink, 2.0); draw_line(c + Vector2(-3 + i * 4, 0), c + Vector2(-7 + i * 4, 5), ink, 2.0)
		"misericordia":
			draw_line(c + Vector2(0, -7), c + Vector2(0, 5), ink, 2.0)
			draw_line(c + Vector2(-3, -3), c + Vector2(3, -3), ink, 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 5), c + Vector2(2, 5), c + Vector2(0, 8)]), ink)
		"especial":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				pts.append(c + Vector2(cos(a), sin(a)) * (7.0 if i % 2 == 0 else 3.0))
			draw_colored_polygon(pts, ink)
		"raspao":
			draw_arc(c, 6.0, -2.4, -0.4, 8, ink, 2.0)
			draw_line(c + Vector2(-3, 4), c + Vector2(5, 4), Color(ink, 0.5), 1.0)
		"magia", "pungente":
			for i in 4:
				var a := i * PI / 2 + PI / 4
				draw_line(c, c + Vector2(cos(a), sin(a)) * 7.0, ink, 1.0)
			draw_circle(c, 3.0, Color(0.6, 0.7, 1.0) if id == "magia" else Color(1.0, 0.6, 0.9))
		"pocao":
			draw_circle(c + Vector2(0, 2), 5.0, Color(0.85, 0.2, 0.25))
			draw_rect(Rect2(c + Vector2(-2, -7), Vector2(4, 5)), ink)
		"atirar":
			draw_arc(c + Vector2(-2, 0), 7.0, -1.2, 1.2, 8, ink, 2.0)
			draw_line(c + Vector2(-5, 0), c + Vector2(7, 0), ink, 1.0)
		"levantar":
			draw_line(c + Vector2(0, 7), c + Vector2(0, -6), ink, 2.0)
			draw_line(c + Vector2(-5, -1), c + Vector2(0, -6), ink, 2.0); draw_line(c + Vector2(5, -1), c + Vector2(0, -6), ink, 2.0)
		"impeto", "velocidade":
			for i in 3: draw_line(c + Vector2(-7, -5 + i * 5), c + Vector2(5 - i * 2, -5 + i * 5), ink, 1.5)
		"emboscar":
			draw_arc(c, 7.0, PI + 0.4, TAU - 0.4, 8, ink, 1.5)
			draw_arc(c, 7.0, 0.4, PI - 0.4, 8, ink, 1.5)
			draw_circle(c, 2.5, ink)
		"poderoso":
			draw_rect(Rect2(c + Vector2(-6, -6), Vector2(12, 6)), ink)
			draw_line(c + Vector2(0, 0), c + Vector2(0, 8), ink, 2.0)
		"defensivo":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -7), c + Vector2(6, -7), c + Vector2(6, 0), c + Vector2(0, 8), c + Vector2(-6, 0)]), ink)
		"desfazer":
			draw_arc(c, 6.0, -PI * 0.9, PI * 0.5, 10, ink, 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -2), c + Vector2(-3, -2), c + Vector2(-6, -7)]), ink)
		"confirmar":
			draw_line(c + Vector2(-6, 0), c + Vector2(-2, 5), Color(0.6, 0.95, 0.5), 2.5)
			draw_line(c + Vector2(-2, 5), c + Vector2(7, -6), Color(0.6, 0.95, 0.5), 2.5)
		"fim":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -7), c + Vector2(5, -7), c + Vector2(0, 0)]), ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 7), c + Vector2(5, 7), c + Vector2(0, 0)]), Color(ink, 0.6))
		"interagir":
			draw_rect(Rect2(c + Vector2(-4, -2), Vector2(9, 8)), ink)
			for i in 3: draw_rect(Rect2(c + Vector2(-4 + i * 3, -7), Vector2(2, 6)), ink)
		"diario":
			draw_rect(Rect2(c + Vector2(-6, -7), Vector2(12, 14)), Color(0.55, 0.3, 0.2))
			draw_rect(Rect2(c + Vector2(-4, -6), Vector2(9, 12)), ink)
			for i in 3: draw_line(c + Vector2(-2, -3 + i * 3), c + Vector2(3, -3 + i * 3), Color(0.3, 0.25, 0.2), 1.0)
		"poderes":
			draw_line(c + Vector2(0, 7), c + Vector2(0, -2), ink, 2.0)
			draw_line(c + Vector2(0, 0), c + Vector2(-5, -5), ink, 1.5); draw_line(c + Vector2(0, 0), c + Vector2(5, -5), ink, 1.5)
			for p in [Vector2(-5, -6), Vector2(5, -6), Vector2(0, -4)]: draw_circle(c + p, 2.2, Color(0.98, 0.82, 0.45))
		"furtivo":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 6), c + Vector2(-6, 6)]), Color(ink, 0.8))
			draw_circle(c + Vector2(0, -2), 2.0, Color(0.1, 0.1, 0.1))
		"descansar":
			draw_circle(c, 6.0, ink)
			draw_circle(c + Vector2(3, -2), 5.0, Color(0.13, 0.11, 0.12))
		"salvar":
			draw_rect(Rect2(c + Vector2(-6, -6), Vector2(12, 12)), ink)
			draw_rect(Rect2(c + Vector2(-3, -6), Vector2(6, 4)), Color(0.2, 0.2, 0.25))
		_:
			draw_circle(c, 4.0, ink)
