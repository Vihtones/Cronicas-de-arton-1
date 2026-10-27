class_name PowerTreePanel
extends PanelContainer
## Árvore de poderes (tecla K). Tormenta20 não tem "árvore" formal: os poderes têm pré-requisitos
## (atributo, perícia treinada, outro poder, nível). Esta tela desenha essas dependências como
## árvore, na disposição da tabela "Poderes de Combate" do LB p.126 (filhos recuados sob o pai).
## Dois ramos: poderes da classe (LB cap. 1) e poderes gerais (LB p.124: um poder de classe pode ser
## trocado por um geral). Estados: possui, disponível, bloqueado e "ainda não implementado".
## Escolher um poder envia ChoosePower ao domínio, que valida tudo de novo.

signal chose(power: String, option: String)

const NAMES := {
	"especializacao_arma": "Especialização em Arma", "valentao": "Valentão", "golpe_raspao": "Golpe de Raspão",
	"ataque_reflexo": "Ataque Reflexo", "impeto": "Ímpeto", "arqueiro": "Arqueiro", "aumento_atributo": "Aumento de Atributo",
	"gatuno": "Gatuno", "truque_magico": "Truque Mágico", "emboscar": "Emboscar", "velocidade_ladina": "Velocidade Ladina",
	"rolamento_defensivo": "Rolamento Defensivo", "sombra": "Sombra", "arcano_de_batalha": "Arcano de Batalha",
	"magia_pungente": "Magia Pungente", "poder_magico": "Poder Mágico", "raio_arcano": "Raio Arcano",
	"ataque_poderoso": "Ataque Poderoso", "trespassar": "Trespassar", "quebrar_aprimorado": "Quebrar Aprimorado",
	"combate_defensivo": "Combate Defensivo", "derrubar_aprimorado": "Derrubar Aprimorado", "desarmar_aprimorado": "Desarmar Aprimorado",
	"esquiva": "Esquiva", "reflexos_combate": "Reflexos de Combate", "saque_rapido": "Saque Rápido", "vitalidade": "Vitalidade",
	"vontade_de_ferro": "Vontade de Ferro",
	"ambidestria": "Ambidestria",
	"esgrimista": "Esgrimista",
	"especializacao_armadura": "Especialização em Armadura",
	"golpe_pessoal": "Golpe Pessoal",
	"bater_e_correr": "Bater e Correr",
	"golpe_demolidor": "Golpe Demolidor",
	"destruidor": "Destruidor",
	"mestre_em_arma": "Mestre em Arma",
	"planejamento_marcial": "Planejamento Marcial",
	"romper_resistencias": "Romper Resistências",
	"solidez": "Solidez",
	"tornado_de_dor": "Tornado de Dor",
	"assassinar": "Assassinar",
	"contatos_no_submundo": "Contatos no Submundo",
	"escapista": "Escapista",
	"fuga_formidavel": "Fuga Formidável",
	"ladrao_arcano": "Ladrão Arcano",
	"mao_na_boca": "Mão na Boca",
	"maos_rapidas": "Mãos Rápidas",
	"mente_criminosa": "Mente Criminosa",
	"oportunismo": "Oportunismo",
	"roubo_de_mana": "Roubo de Mana",
	"saqueador_de_tumbas": "Saqueador de Tumbas",
	"veneno_persistente": "Veneno Persistente",
	"veneno_potente": "Veneno Potente",
	"caldeirao_do_bruxo": "Caldeirão do Bruxo",
	"conhecimento_magico": "Conhecimento Mágico",
	"contramagica_aprimorada": "Contramágica Aprimorada",
	"envolto_em_misterio": "Envolto em Mistério",
	"escriba_arcano": "Escriba Arcano",
	"especialista_em_escola": "Especialista em Escola",
	"familiar": "Familiar",
	"fluxo_de_mana": "Fluxo de Mana",
	"foco_vital": "Foco Vital",
	"fortalecimento_arcano": "Fortalecimento Arcano",
	"heranca_aprimorada": "Herança Aprimorada",
	"heranca_superior": "Herança Superior",
	"mestre_em_escola": "Mestre em Escola",
	"raio_elemental": "Raio Elemental",
	"raio_poderoso": "Raio Poderoso",
	"tinta_do_mago": "Tinta do Mago",
	"acuidade_com_arma": "Acuidade com Arma",
	"ataque_com_escudo": "Ataque com Escudo",
	"ataque_preciso": "Ataque Preciso",
	"ataque_pesado": "Ataque Pesado",
	"arma_secundaria_grande": "Arma Secundária Grande",
	"arremesso_multiplo": "Arremesso Múltiplo",
	"arremesso_potente": "Arremesso Potente",
	"bloqueio_com_escudo": "Bloqueio com Escudo",
	"carga_de_cavalaria": "Carga de Cavalaria",
	"disparo_preciso": "Disparo Preciso",
	"disparo_rapido": "Disparo Rápido",
	"empunhadura_poderosa": "Empunhadura Poderosa",
	"encouracado": "Encouraçado",
	"estilo_de_arma_e_escudo": "Estilo de Arma e Escudo",
	"estilo_de_arma_longa": "Estilo de Arma Longa",
	"estilo_de_arremesso": "Estilo de Arremesso",
	"estilo_de_disparo": "Estilo de Disparo",
	"estilo_de_duas_armas": "Estilo de Duas Armas",
	"estilo_de_duas_maos": "Estilo de Duas Mãos",
	"estilo_de_uma_arma": "Estilo de Uma Arma",
	"estilo_desarmado": "Estilo Desarmado",
	"fanatico": "Fanático",
	"finta_aprimorada": "Finta Aprimorada",
	"foco_em_arma": "Foco em Arma",
	"ginete": "Ginete",
	"inexpugnavel": "Inexpugnável",
	"mira_apurada": "Mira Apurada",
	"piqueiro": "Piqueiro",
	"presenca_aterradora": "Presença Aterradora",
	"proficiencia": "Proficiência",
}
const STATE_COL := {"possui": Color(0.95, 0.78, 0.38), "possui_repetivel": Color(0.95, 0.78, 0.38), "disponivel": Color(0.55, 0.85, 0.5),
	"bloqueado": Color(0.45, 0.42, 0.4), "nao_implementado": Color(0.35, 0.33, 0.38)}
const STATE_TXT := {"possui": "possui", "possui_repetivel": "possui (repetível)", "disponivel": "disponível", "bloqueado": "bloqueado",
	"nao_implementado": "ainda não implementado no jogo"}

var canvas: Control
var info: Label
var header: Label
var _nodes: Dictionary = {}       # id -> {rect, data}
var _hover := ""
var _attr_row: HBoxContainer
var _pending_attr := false


func _init() -> void:
	custom_minimum_size = Vector2(600, 320)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	header = Label.new()
	header.add_theme_font_size_override("font_size", 10)
	header.add_theme_color_override("font_color", Color(0.98, 0.82, 0.45))
	v.add_child(header)
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(584, 236)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.draw.connect(_draw_tree)
	canvas.gui_input.connect(_on_input)
	v.add_child(canvas)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 8)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(584, 30)
	v.add_child(info)
	_attr_row = HBoxContainer.new()
	_attr_row.visible = false
	v.add_child(_attr_row)
	for a in ["for", "des", "con", "int", "sab", "car"]:
		var b := Button.new()
		b.text = a.to_upper()
		b.pressed.connect(func(): _attr_row.visible = false; chose.emit("aumento_atributo", a))
		_attr_row.add_child(b)


func refresh() -> void:
	if Game.world == null:
		return
	var tree: Dictionary = (Game.world.modules.progression as ProgressionModule).power_tree()
	var s: CharacterSheet = Game.world.player_sheet
	header.text = "Árvore de Poderes — %s nível %d · %s" % [str(tree["class"]).capitalize(), s.level,
		("%d poder(es) para escolher: clique num nó verde" % int(tree.pending)) if int(tree.pending) > 0 else "nenhum poder pendente (sobe de nível para escolher)"]
	_nodes.clear()
	var cls: Array = []
	var gen: Array = []
	for n in tree.nodes:
		(cls if n.branch != "geral" else gen).append(n)
	# ramo da classe: grade de duas colunas
	var x0 := 6.0
	_section(Vector2(x0, 2), "Poderes de %s (LB cap. 1)" % str(tree["class"]).capitalize())
	for i in cls.size():
		var r := Rect2(Vector2(x0 + (i % 2) * 132.0, 16 + (i / 2) * 30.0), Vector2(126, 24))
		_nodes[cls[i].id] = {"rect": r, "data": cls[i]}
	# ramo geral: raízes numa coluna, filhos recuados à direita (como a tabela do livro)
	var gx := 290.0
	_section(Vector2(gx, 2), "Poderes gerais — combate e destino (LB p.124-131)")
	var roots: Array = gen.filter(func(n): return n.parent == "")
	var y := 16.0
	var col := 0
	for rt in roots:
		var kids: Array = gen.filter(func(n): return n.parent == rt.id)
		var need := 30.0 * maxi(1, kids.size())
		if y + need > 232.0 and col == 0:
			col = 1; y = 16.0
		var bx := gx + col * 148.0
		if col == 1:
			bx = gx + 148.0
		_nodes[rt.id] = {"rect": Rect2(Vector2(bx, y), Vector2(140, 24)), "data": rt}
		if not kids.is_empty():
			for k in kids.size():
				_nodes[kids[k].id] = {"rect": Rect2(Vector2(bx + 26, y + 28 + k * 28), Vector2(118, 22)), "data": kids[k]}
			y += 28 + kids.size() * 28 + 4
		else:
			y += 30
	_sections_cache = [[Vector2(x0, 2), "Poderes de %s (LB cap. 1)" % str(tree["class"]).capitalize()], [Vector2(gx, 2), "Poderes gerais (LB p.124-131)"]]
	_show_info(_hover)
	canvas.queue_redraw()


var _sections_cache: Array = []


func _section(_p: Vector2, _t: String) -> void:
	pass


func _draw_tree() -> void:
	var font := canvas.get_theme_default_font()
	for sc in _sections_cache:
		canvas.draw_string(font, sc[0] + Vector2(0, 9), sc[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.7, 0.5))
	canvas.draw_line(Vector2(280, 4), Vector2(280, 232), Color(0.45, 0.35, 0.2, 0.6), 1.0)
	# arestas pai -> filho (cotovelo, como galhos)
	for id in _nodes:
		var d: Dictionary = _nodes[id].data
		if d.parent != "" and _nodes.has(d.parent):
			var pr: Rect2 = _nodes[d.parent].rect
			var cr: Rect2 = _nodes[id].rect
			var a := Vector2(pr.position.x + 12, pr.end.y)
			var b := Vector2(cr.position.x, cr.get_center().y)
			var lit: bool = d.state in ["possui", "disponivel", "possui_repetivel"]
			var lc := Color(0.86, 0.68, 0.36) if lit else Color(0.35, 0.3, 0.26)
			canvas.draw_polyline(PackedVector2Array([a, Vector2(a.x, b.y), b]), lc, 2.0)
	for id in _nodes:
		var r: Rect2 = _nodes[id].rect
		var d: Dictionary = _nodes[id].data
		var sc: Color = STATE_COL.get(d.state, Color.GRAY)
		var hover: bool = id == _hover
		canvas.draw_rect(r, Color(0.08, 0.07, 0.08) if d.state != "disponivel" else Color(0.1, 0.14, 0.09))
		canvas.draw_rect(r, sc if not hover else sc.lightened(0.3), false, 2.0 if hover or d.state.begins_with("possui") else 1.0)
		if d.state.begins_with("possui"):
			canvas.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), sc)
		var txt: String = NAMES.get(id, id)
		var tc := Color(0.95, 0.9, 0.82) if d.state != "nao_implementado" and d.state != "bloqueado" else Color(0.55, 0.52, 0.5)
		canvas.draw_string(font, r.position + Vector2(7, 10), txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10, 8, tc)
		var sub: String = (d.falta if d.state == "bloqueado" and str(d.get("falta", "")) != "" else d.prereq) if d.state != "possui" else "✓"
		if int(d.cost) > 0: sub += " · %d PM" % int(d.cost)
		canvas.draw_string(font, r.position + Vector2(7, r.size.y - 3), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10, 6, Color(sc, 0.9))


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := _hit(e.position)
		if h != _hover:
			_hover = h
			_show_info(h)
			canvas.queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var id := _hit(e.position)
		if id == "" or not _nodes.has(id):
			return
		var st: String = _nodes[id].data.state
		if st in ["disponivel", "possui_repetivel"] and Game.world.player_sheet.pending_powers > 0:
			if id == "aumento_atributo":
				_attr_row.visible = true
				info.text = "Aumento de Atributo: escolha o atributo (+1)."
			else:
				chose.emit(id, "")


func _hit(p: Vector2) -> String:
	for id in _nodes:
		if (_nodes[id].rect as Rect2).has_point(p):
			return id
	return ""


func _show_info(id: String) -> void:
	if id == "" or not _nodes.has(id):
		info.text = "Passe o mouse sobre um poder. Verde = disponível · dourado = já possui · cinza = pré-requisito faltando · escuro = ainda não implementado."
		return
	var d: Dictionary = _nodes[id].data
	var falta: String = (" Falta: %s." % d.falta) if str(d.get("falta", "")) != "" else ""
	info.text = "%s — %s. Pré-requisito: %s.%s%s Estado: %s.%s" % [NAMES.get(id, id), d.effect, d.prereq, falta,
		(" Custo: %d PM." % int(d.cost)) if int(d.cost) > 0 else "", STATE_TXT.get(d.state, d.state),
		(" (LB p.%d)" % int(d.page)) if int(d.page) > 0 else ""]
