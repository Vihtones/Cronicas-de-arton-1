class_name SpellWheel
extends Control
## Roda de magias (Tab): as magias conhecidas em fatias coloridas pela escola. Passe o mouse para ver nome,
## custo e texto; clique para escolher. Em combate a magia vai para o modo magia do turno; fora de combate
## abre as formas de lançá-la ali (alvos e objetos próximos), e o domínio valida o lançamento.

signal picked(spell: String)

const COR_ESCOLA := {"abjuracao": Color(0.4, 0.65, 0.95), "adivinhacao": Color(0.85, 0.85, 0.5), "convocacao": Color(0.55, 0.8, 0.45),
	"encantamento": Color(0.9, 0.5, 0.8), "evocacao": Color(0.95, 0.5, 0.3), "ilusao": Color(0.65, 0.5, 0.95),
	"necromancia": Color(0.5, 0.6, 0.5), "transmutacao": Color(0.9, 0.7, 0.35)}
const R_IN := 40.0
const R_OUT := 112.0

var spells: Array = []
var hover := -1
var _font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = ThemeDB.fallback_font


func open() -> void:
	var s: CharacterSheet = Game.world.player_sheet
	spells = Array(s.spells)
	if s.has_power("raio_arcano"):
		spells.append("raio_arcano")
	hover = -1
	visible = true
	queue_redraw()


func _centro() -> Vector2:
	return size / 2.0


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := _fatia(e.position)
		if h != hover:
			hover = h
			queue_redraw()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT and _fatia(e.position) >= 0:
			var sp: String = spells[_fatia(e.position)]
			visible = false
			picked.emit(sp)
		else:
			visible = false
		accept_event()


func _fatia(p: Vector2) -> int:
	if spells.is_empty():
		return -1
	var d := p - _centro()
	if d.length() < R_IN or d.length() > R_OUT + 30:
		return -1
	var a := fposmod(d.angle() + PI / 2.0, TAU)
	return int(a / (TAU / spells.size())) % spells.size()


func _draw() -> void:
	var c := _centro()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	if spells.is_empty():
		draw_string(_font, c + Vector2(-80, 0), "Você não conhece magias.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		return
	var n := spells.size()
	var passo := TAU / n
	var w: WorldState = Game.world
	for i in n:
		var a0 := -PI / 2.0 + i * passo
		var r: Dictionary = GhostPlanner.spell_rule(w.rules, spells[i])
		var cor: Color = COR_ESCOLA.get(str(r.get("escola", "")), Color.from_hsv(float(i) / n, 0.45, 0.85))
		if i != hover:
			cor = cor.darkened(0.45)
		var pts := PackedVector2Array()
		var seg := maxi(4, int(48.0 / n))
		for k in seg + 1:
			pts.append(c + Vector2.from_angle(a0 + passo * k / seg + 0.01) * (R_OUT + (10.0 if i == hover else 0.0)))
		for k in range(seg, -1, -1):
			pts.append(c + Vector2.from_angle(a0 + passo * k / seg + 0.01) * R_IN)
		draw_colored_polygon(pts, cor)
		draw_line(c + Vector2.from_angle(a0) * R_IN, c + Vector2.from_angle(a0) * R_OUT, Color(0.05, 0.05, 0.08), 2.0)
		var mid := c + Vector2.from_angle(a0 + passo / 2.0) * ((R_IN + R_OUT) / 2.0)
		var curto := _nome(spells[i]).substr(0, 12)
		draw_string(_font, mid + Vector2(-curto.length() * 3.0, 4), curto, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1))
	draw_circle(c, R_IN - 4, Color(0.1, 0.09, 0.12, 0.95))
	if hover >= 0:
		var sp: String = spells[hover]
		var r: Dictionary = GhostPlanner.spell_rule(w.rules, sp)
		var custo := GhostPlanner.spell_cost(w.rules, r, {})
		draw_string(_font, c + Vector2(-38, -4), "%d PM" % custo, HORIZONTAL_ALIGNMENT_CENTER, 76, 12, Color(0.6, 0.8, 1.0))
		draw_string(_font, c + Vector2(-38, 12), "%dº círc." % int(r.get("circulo", 1)), HORIZONTAL_ALIGNMENT_CENTER, 76, 9)
		var x := c.x + R_OUT + 24
		var y := c.y - 60
		draw_rect(Rect2(x - 8, y - 16, 190, 150), Color(0.08, 0.07, 0.1, 0.9))
		draw_string(_font, Vector2(x, y), _nome(sp), HORIZONTAL_ALIGNMENT_LEFT, 180, 11, Color(1, 0.85, 0.45))
		draw_string(_font, Vector2(x, y + 13), "%s · %s · %s" % [str(r.get("escola", r.get("tipo", ""))).capitalize(), str(r.get("execucao", "")), str(r.get("alcance", ""))], HORIZONTAL_ALIGNMENT_LEFT, 180, 8, Color(0.7, 0.7, 0.75))
		var txt := str(r.get("texto", ""))
		var linhas := _quebrar(txt.substr(0, 300) + ("…" if txt.length() > 300 else ""), 38)
		for i in mini(linhas.size(), 9):
			draw_string(_font, Vector2(x, y + 28 + i * 11), linhas[i], HORIZONTAL_ALIGNMENT_LEFT, 180, 8, Color(0.9, 0.9, 0.85))
	else:
		draw_string(_font, c + Vector2(-38, 4), "Tab fecha", HORIZONTAL_ALIGNMENT_CENTER, 76, 9)


func _nome(sp: String) -> String:
	return str(GhostPlanner.spell_rule(Game.world.rules, sp).get("nome", sp.replace("_", " ").capitalize()))


static func _quebrar(t: String, largura: int) -> PackedStringArray:
	var out := PackedStringArray()
	var linha := ""
	for p in t.split(" "):
		if linha.length() + p.length() + 1 > largura:
			out.append(linha)
			linha = p
		else:
			linha = (linha + " " + p).strip_edges()
	if linha != "":
		out.append(linha)
	return out
