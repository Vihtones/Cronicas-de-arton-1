class_name PowerPanel
extends PanelContainer
## Seleção de poderes (tecla K): cartões filtráveis com o efeito, o custo, os pré-requisitos e o que falta.
## "Disponíveis" mostra só o que pode ser escolhido agora. A árvore desenhada continua acessível pelo botão.
## Escolher envia ChoosePower; o domínio valida de novo.

signal chose(power: String, option: String)

const FILTROS := {"disponiveis": "Disponíveis", "classe": "Da classe", "geral": "Gerais", "possui": "Que você tem", "todos": "Todos"}
const COR := {"possui": Color(0.55, 0.8, 1.0), "possui_repetivel": Color(0.55, 0.8, 1.0), "disponivel": Color(0.5, 0.95, 0.5),
	"bloqueado": Color(0.75, 0.6, 0.5), "nao_implementado": Color(0.5, 0.5, 0.5)}
const ESTADO := {"possui": "você tem", "possui_repetivel": "você tem (pode repetir)", "disponivel": "disponível", "bloqueado": "bloqueado", "nao_implementado": "ainda não implementado"}

var filtro := "disponiveis"
var busca := ""
var _cab: Label
var _sc: ScrollContainer
var _filtros: HBoxContainer
var _lista: VBoxContainer
var _arvore: PowerTreePanel
var _attr_row: HBoxContainer


func _init() -> void:
	UiEstilo.janela(self)
	custom_minimum_size = Vector2(600, 330)
	var v := VBoxContainer.new()
	add_child(v)
	_cab = Label.new()
	_cab.add_theme_font_size_override("font_size", 11)
	_cab.add_theme_color_override("font_color", Color(0.98, 0.82, 0.45))
	v.add_child(_cab)
	_filtros = HBoxContainer.new()
	v.add_child(_filtros)
	_attr_row = HBoxContainer.new()
	_attr_row.visible = false
	v.add_child(_attr_row)
	for a in ["for", "des", "con", "int", "sab", "car"]:
		var b := _btn("+1 " + a.to_upper(), func(): _attr_row.visible = false; chose.emit("aumento_atributo", a))
		_attr_row.add_child(b)
	_sc = ScrollContainer.new()
	_sc.custom_minimum_size = Vector2(584, 260)
	_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_sc)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sc.add_child(_lista)
	_arvore = PowerTreePanel.new()
	_arvore.visible = false
	_arvore.chose.connect(func(p: String, o: String): chose.emit(p, o))
	v.add_child(_arvore)


func refresh() -> void:
	if Game.world == null:
		return
	var tree: Dictionary = (Game.world.modules.progression as ProgressionModule).power_tree()
	var s: CharacterSheet = Game.world.player_sheet
	_cab.text = "Poderes — %s nível %d · %s  [K fecha]" % [str(tree["class"]).capitalize(), s.level,
		("%d para escolher" % int(tree.pending)) if int(tree.pending) > 0 else "nenhum poder pendente"]
	for n in _filtros.get_children() + _lista.get_children():
		n.get_parent().remove_child(n)
		n.queue_free()
	for f in FILTROS:
		var b := _btn(FILTROS[f], func(): filtro = f; refresh())
		b.modulate = Color(1.3, 1.2, 0.8) if f == filtro else Color(0.7, 0.7, 0.7)
		_filtros.add_child(b)
	var le := LineEdit.new()
	le.placeholder_text = "buscar..."
	le.text = busca
	le.custom_minimum_size.x = 110
	le.text_submitted.connect(func(t: String): busca = t; refresh())
	_filtros.add_child(le)
	_filtros.add_child(_btn("Ver árvore", func(): _arvore.visible = not _arvore.visible; _sc.visible = not _arvore.visible; _arvore.refresh()))
	var nodes: Array = tree.nodes.filter(func(n): return _passa(n, str(tree["class"])))
	nodes.sort_custom(func(a, b): return _ordem(a) < _ordem(b))
	for n in nodes:
		_lista.add_child(_cartao(n, int(tree.pending) > 0))
	if nodes.is_empty():
		_lista.add_child(_lbl("Nada neste filtro." + (" Suba de nível para escolher novos poderes." if filtro == "disponiveis" else ""), 9))


func _passa(n: Dictionary, cls: String) -> bool:
	var nome := str(PowerTreePanel.NAMES.get(n.id, n.id)).to_lower()
	if busca != "" and not nome.contains(busca.to_lower()) and not str(n.effect).to_lower().contains(busca.to_lower()):
		return false
	match filtro:
		"disponiveis": return str(n.state) in ["disponivel", "possui_repetivel"]
		"classe": return str(n.branch) == cls
		"geral": return str(n.branch) == "geral"
		"possui": return str(n.state).begins_with("possui")
	return true


func _ordem(n: Dictionary) -> String:
	var o := {"disponivel": "0", "possui_repetivel": "1", "bloqueado": "2", "possui": "3", "nao_implementado": "4"}
	return str(o.get(str(n.state), "5")) + str(PowerTreePanel.NAMES.get(n.id, n.id))


func _cartao(n: Dictionary, pendente: bool) -> Control:
	var box := HBoxContainer.new()
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(v)
	var cor: Color = COR.get(str(n.state), Color.WHITE)
	v.add_child(_lbl("%s  ·  %s%s%s" % [PowerTreePanel.NAMES.get(n.id, str(n.id).replace("_", " ").capitalize()), ESTADO.get(str(n.state), n.state),
		("  ·  %d PM" % int(n.cost)) if int(n.cost) > 0 else "", ("  ·  LB p.%d" % int(n.page)) if int(n.page) > 0 else ""], 10, cor))
	if str(n.effect) != "":
		v.add_child(_lbl(str(n.effect), 8))
	v.add_child(_lbl("Pré-requisitos: " + str(n.prereq) + (("  —  falta: " + str(n.falta)) if str(n.falta) != "" else ""), 8, Color(0.7, 0.7, 0.72)))
	if pendente and str(n.state) in ["disponivel", "possui_repetivel"]:
		var pid := str(n.id)
		box.add_child(_btn("Escolher", func():
			if pid == "aumento_atributo":
				_attr_row.visible = true
			else:
				chose.emit(pid, "")))
	return box


func _lbl(text: String, size: int, cor: Color = Color(0.92, 0.9, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 460
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 9)
	b.pressed.connect(cb)
	return b
