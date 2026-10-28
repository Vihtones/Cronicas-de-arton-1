class_name ShopPanel
extends PanelContainer
## Loja: comprar e vender lado a lado. A ficha do item (números de regra) e a comparação com o que você usa
## aparecem antes de pagar. O vendedor tem bolsa (limita o que compra), revende o que você vendeu e aceita
## uma pechincha por dia (Diplomacia).

signal command(type: String, payload: Dictionary)

var npc := ""
var _sel := ""
var _modo := "comprar"
var _titulo: Label
var _fala: Label
var _lista: VBoxContainer
var _detalhe: VBoxContainer
var _rodape: Label
var _abas: HBoxContainer


func _init() -> void:
	UiEstilo.janela(self)
	custom_minimum_size = Vector2(560, 300)
	var v := VBoxContainer.new()
	add_child(v)
	_titulo = _lbl("", 11, Color(0.98, 0.82, 0.45))
	v.add_child(_titulo)
	_fala = _lbl("", 9, Color(0.85, 0.85, 0.7))
	v.add_child(_fala)
	_abas = HBoxContainer.new()
	v.add_child(_abas)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(290, 200)
	h.add_child(sc)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_lista)
	_detalhe = VBoxContainer.new()
	_detalhe.custom_minimum_size.x = 230
	h.add_child(_detalhe)
	_rodape = _lbl("", 9)
	v.add_child(_rodape)


func open(p_npc: String) -> void:
	npc = p_npc
	_sel = ""
	_modo = "comprar"
	_fala.text = _saudacao()
	visible = true
	refresh()


func refresh() -> void:
	var w: WorldState = Game.world
	if w == null or npc == "":
		return
	var eco: EconomyModule = w.modules.economy
	for c in _lista.get_children() + _detalhe.get_children() + _abas.get_children():
		c.queue_free()
	_titulo.text = "Loja de %s  [Esc fecha]" % str(w.npc_def(npc).get("name", npc))
	for m in ["comprar", "vender"]:
		var b := _btn(m.capitalize(), func(): _modo = m; _sel = ""; refresh())
		b.modulate = Color(1.3, 1.2, 0.8) if m == _modo else Color(0.75, 0.75, 0.75)
		_abas.add_child(b)
	_abas.add_child(_btn("Pechinchar (Diplomacia)", func(): command.emit("Haggle", {"npc_id": npc}); _fala.text = _resposta_pechincha(); refresh()))
	_abas.add_child(_btn("Sair", func(): visible = false))
	var itens: Array = eco.estoque(npc) if _modo == "comprar" else w.modules.state.inventory.keys().filter(func(i): return int(w.modules.state.inventory[i]) > 0)
	for it in itens:
		var i := ItemsModule.info(w.rules, w.db, it)
		var preco: int = eco.price(it, "vila", npc) if _modo == "comprar" else eco.preco_venda(it)
		var qtd: int = int(w.modules.state.inventory.get(it, 0))
		var b := _btn("%s%s   T$ %d" % [i.nome, (" (você tem %d)" % qtd) if qtd > 0 else "", preco], func(): _sel = it; refresh())
		b.add_theme_color_override("font_color", InventoryPanel.COR_TIPO.get(i.tipo, Color.WHITE))
		if it == _sel:
			b.modulate = Color(1.3, 1.3, 1.0)
		_lista.add_child(b)
	if itens.is_empty():
		_lista.add_child(_lbl("Nada aqui.", 9))
	_detalhe_item(w, eco)
	_rodape.text = "Seu ouro: T$ %d   ·   Bolsa do vendedor: T$ %d" % [int(w.player.gold), eco.bolsa(npc)]


func _detalhe_item(w: WorldState, eco: EconomyModule) -> void:
	if _sel == "":
		_detalhe.add_child(_lbl("Escolha um item para ver a ficha.", 9))
		return
	var i := ItemsModule.info(w.rules, w.db, _sel)
	_detalhe.add_child(_lbl(i.nome, 11, InventoryPanel.COR_TIPO.get(i.tipo, Color.WHITE)))
	_detalhe.add_child(_lbl("%s · preço de tabela T$ %d" % [i.tipo, int(i.preco)], 8, Color(0.75, 0.75, 0.75)))
	for l in i.linhas:
		_detalhe.add_child(_lbl("• " + str(l), 9))
	var cmp := ItemsModule.comparar(w.rules, w.db, _sel, w.player_sheet)
	if cmp != "":
		_detalhe.add_child(_lbl(cmp, 9, Color(0.5, 0.9, 0.5) if cmp.begins_with("+") else Color(0.95, 0.55, 0.45)))
	var it := _sel
	if _modo == "comprar":
		var p := eco.price(it, "vila", npc)
		var b := _btn("Comprar por T$ %d" % p, func(): command.emit("Buy", {"npc_id": npc, "item": it}); refresh())
		b.disabled = int(w.player.gold) < p
		_detalhe.add_child(b)
	else:
		var pv := eco.preco_venda(it)
		var bv := _btn("Vender por T$ %d" % pv, func(): command.emit("Sell", {"npc_id": npc, "item": it}); refresh())
		bv.disabled = pv <= 0 or eco.bolsa(npc) < pv
		_detalhe.add_child(bv)


func _saudacao() -> String:
	var w: WorldState = Game.world
	var mem = w.module("memory")
	var bias: float = mem.bias(npc, "player") if mem != null else 0.0
	var h: int = w.hour()
	var hora := "Bom dia" if h < 12 else ("Boa tarde" if h < 18 else "Boa noite")
	if bias < 0:
		return "\"%s. Olhe, mas não toque sem pagar.\"" % hora
	if bias > 20:
		return "\"%s, amigo! Separei umas coisas boas para você.\"" % hora
	return "\"%s. Veja o que tenho.\"" % hora


func _resposta_pechincha() -> String:
	var p: Dictionary = (Game.world.modules.economy as EconomyModule).pechincha.get(npc, {})
	match float(p.get("mod", 1.0)):
		0.8: return "\"Está bem, está bem... vinte por cento. Mas só hoje.\""
		0.9: return "\"Hmm. Dez por cento, e não se fala mais nisso.\""
		1.1: return "\"Está me chamando de ladrão? Agora o preço subiu.\""
	return "\"O preço é esse.\""


func _lbl(text: String, size: int, cor: Color = Color(0.92, 0.9, 0.85)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b
