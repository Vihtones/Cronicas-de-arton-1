class_name UiEstilo
## Fundo opaco com borda dourada para as janelas grandes (inventário, loja, guilda, criação).


static func janela(p: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.065, 0.08, 0.97)
	sb.border_color = Color(0.62, 0.48, 0.24)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
