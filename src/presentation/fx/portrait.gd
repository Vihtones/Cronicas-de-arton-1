class_name Portrait
extends Control
## Retrato com expressão (sistema pronto; a arte é PROVISÓRIA e procedural).
## Quando houver retratos aprovados pelo governador de arte (papel "retrato", id "<ator>_<expressao>"),
## eles substituem o desenho procedural sem mudar quem chama: set_actor(id, raça) + set_expression(...).
## Expressões: neutro, determinado, furioso, surpreso, dor, alegria, medo, concentrado.

const EXPRESSIONS := ["neutro", "determinado", "furioso", "surpreso", "dor", "alegria", "medo", "concentrado"]
const HAIR := [Color(0.18, 0.12, 0.08), Color(0.42, 0.26, 0.12), Color(0.75, 0.6, 0.3), Color(0.55, 0.15, 0.08), Color(0.12, 0.12, 0.14), Color(0.7, 0.7, 0.72)]
const SKIN := [Color(0.95, 0.8, 0.66), Color(0.82, 0.62, 0.46), Color(0.6, 0.42, 0.3), Color(0.42, 0.28, 0.2)]

var actor_id := ""
var race := "humano"
var expression := "neutro"
var is_creature := false
var _tex: Texture2D
var _seed := 0
var _bounce := 0.0
static var _gov: ArtGovernor


func _init() -> void:
	custom_minimum_size = Vector2(72, 72)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_actor(id: String, p_race: String, creature: bool = false) -> void:
	actor_id = id
	race = p_race
	is_creature = creature
	_seed = absi(hash(id))
	queue_redraw()


func set_expression(e: String) -> void:
	expression = e if EXPRESSIONS.has(e) else "neutro"
	_tex = _approved_texture()
	_bounce = 1.0
	queue_redraw()


## Retrato aprovado, se existir (por enquanto nenhum: o governador ainda não tem esse papel aprovado).
func _approved_texture() -> Texture2D:
	if _gov == null:
		_gov = ArtGovernor.load_default()
	for a in _gov.assets_for("retrato", "qualquer"):
		if str(a.get("retrato_de", "")) == "%s_%s" % [actor_id, expression]:
			return load(a.caminho)
	return null


func _process(delta: float) -> void:
	if _bounce > 0.0:
		_bounce = move_toward(_bounce, 0.0, delta * 4.0)
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# moldura de bronze gasto (estilo dos painéis)
	draw_rect(r, Color(0.08, 0.06, 0.08))
	draw_rect(r.grow(-2), Color(0.16, 0.12, 0.14))
	draw_rect(r, Color(0.72, 0.56, 0.28), false, 2.0)
	draw_rect(r.grow(-3), Color(0.35, 0.27, 0.16), false, 1.0)
	if _tex:
		draw_texture_rect(_tex, r.grow(-4), false)
		return
	var c := size / 2.0 + Vector2(0, 4 - _bounce * 3.0)
	var s := minf(size.x, size.y) / 72.0
	var tint: Color = RaceLook.of(race).tint
	if is_creature and actor_id.begins_with("hiena"):
		_draw_hyena(c, s)
		return
	var skin: Color = (SKIN[_seed % SKIN.size()] as Color) * tint
	var hair: Color = HAIR[(_seed / 7) % HAIR.size()]
	# ombros e pescoço
	draw_rect(Rect2(c + Vector2(-22, 18) * s, Vector2(44, 20) * s), Color(0.3, 0.24, 0.22) if not is_creature else Color(0.35, 0.2, 0.18))
	draw_rect(Rect2(c + Vector2(-6, 10) * s, Vector2(12, 10) * s), skin.darkened(0.15))
	# cabeça
	draw_circle(c, 16.0 * s, skin)
	# cabelo / capuz
	if is_creature:
		draw_arc(c + Vector2(0, -2) * s, 18.0 * s, PI, TAU, 16, Color(0.35, 0.2, 0.15), 7.0 * s)
	else:
		draw_arc(c + Vector2(0, -3) * s, 16.0 * s, PI * 1.05, TAU - 0.05, 16, hair, 7.0 * s)
	if race == "minotauro":
		draw_line(c + Vector2(-12, -12) * s, c + Vector2(-20, -22) * s, Color(0.9, 0.85, 0.7), 3.0 * s)
		draw_line(c + Vector2(12, -12) * s, c + Vector2(20, -22) * s, Color(0.9, 0.85, 0.7), 3.0 * s)
	if race in ["elfo", "goblin"]:
		draw_line(c + Vector2(-15, -2) * s, c + Vector2(-22, -8) * s, skin, 3.0 * s)
		draw_line(c + Vector2(15, -2) * s, c + Vector2(22, -8) * s, skin, 3.0 * s)
	_draw_face(c, s)


func _draw_face(c: Vector2, s: float) -> void:
	var eye := Color(0.1, 0.08, 0.08)
	var brow := Color(0.15, 0.1, 0.08)
	var le := c + Vector2(-6, -2) * s
	var re := c + Vector2(6, -2) * s
	match expression:
		"surpreso", "medo":
			draw_circle(le, 2.6 * s, Color.WHITE); draw_circle(re, 2.6 * s, Color.WHITE)
			draw_circle(le, 1.3 * s, eye); draw_circle(re, 1.3 * s, eye)
		"dor":
			draw_line(le + Vector2(-3, -1) * s, le + Vector2(3, 1) * s, eye, 1.5 * s)
			draw_line(re + Vector2(-3, 1) * s, re + Vector2(3, -1) * s, eye, 1.5 * s)
		"alegria":
			draw_arc(le, 2.5 * s, PI, TAU, 8, eye, 1.5 * s); draw_arc(re, 2.5 * s, PI, TAU, 8, eye, 1.5 * s)
		_:
			draw_circle(le, 1.6 * s, eye); draw_circle(re, 1.6 * s, eye)
	# sobrancelhas
	match expression:
		"furioso", "determinado":
			draw_line(le + Vector2(-4, -5) * s, le + Vector2(3, -3) * s, brow, 2.0 * s)
			draw_line(re + Vector2(4, -5) * s, re + Vector2(-3, -3) * s, brow, 2.0 * s)
		"surpreso", "medo":
			draw_line(le + Vector2(-3, -7) * s, le + Vector2(3, -7) * s, brow, 1.5 * s)
			draw_line(re + Vector2(-3, -7) * s, re + Vector2(3, -7) * s, brow, 1.5 * s)
		"dor":
			draw_line(le + Vector2(-3, -4) * s, le + Vector2(3, -6) * s, brow, 1.5 * s)
			draw_line(re + Vector2(3, -4) * s, re + Vector2(-3, -6) * s, brow, 1.5 * s)
		"concentrado":
			draw_line(le + Vector2(-3, -4) * s, le + Vector2(3, -4) * s, brow, 1.5 * s)
			draw_line(re + Vector2(-3, -4) * s, re + Vector2(3, -4) * s, brow, 1.5 * s)
	# boca
	var m := c + Vector2(0, 8) * s
	match expression:
		"alegria":
			draw_arc(m + Vector2(0, -3) * s, 5.0 * s, 0.2, PI - 0.2, 10, eye, 1.5 * s)
		"furioso":
			draw_rect(Rect2(m + Vector2(-5, -1) * s, Vector2(10, 3) * s), eye)
			draw_line(m + Vector2(-4, 0) * s, m + Vector2(4, 0) * s, Color.WHITE, 1.0 * s)
		"surpreso":
			draw_circle(m, 2.5 * s, eye)
		"dor", "medo":
			draw_arc(m + Vector2(0, 3) * s, 4.0 * s, PI + 0.3, TAU - 0.3, 10, eye, 1.5 * s)
			if expression == "medo":
				draw_circle(c + Vector2(13, -6) * s, 1.8 * s, Color(0.6, 0.8, 1.0))   # gota de suor
		"determinado":
			draw_line(m + Vector2(-5, 1) * s, m + Vector2(5, -1) * s, eye, 1.5 * s)
		_:
			draw_line(m + Vector2(-4, 0) * s, m + Vector2(4, 0) * s, eye, 1.5 * s)


func _draw_hyena(c: Vector2, s: float) -> void:
	var fur := Color(0.62, 0.5, 0.32)
	draw_circle(c, 15.0 * s, fur)
	draw_rect(Rect2(c + Vector2(-8, 2) * s, Vector2(16, 12) * s), fur.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -8) * s, c + Vector2(-8, -24) * s, c + Vector2(-3, -10) * s]), fur.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([c + Vector2(14, -8) * s, c + Vector2(8, -24) * s, c + Vector2(3, -10) * s]), fur.darkened(0.25))
	for sp in [Vector2(-9, -4), Vector2(7, 6), Vector2(-3, 9)]:
		draw_circle(c + sp * s, 2.0 * s, Color(0.3, 0.22, 0.12))
	var eye := Color(0.95, 0.75, 0.2) if expression in ["furioso", "determinado"] else Color(0.1, 0.08, 0.05)
	draw_circle(c + Vector2(-5, -3) * s, 1.8 * s, eye); draw_circle(c + Vector2(5, -3) * s, 1.8 * s, eye)
	draw_rect(Rect2(c + Vector2(-5, 9) * s, Vector2(10, 3) * s), Color(0.15, 0.08, 0.06))
	if expression in ["furioso", "alegria"]:
		for x in [-4, -1, 2]:
			draw_line(c + Vector2(x, 9) * s, c + Vector2(x + 1, 12) * s, Color.WHITE, 1.0 * s)
