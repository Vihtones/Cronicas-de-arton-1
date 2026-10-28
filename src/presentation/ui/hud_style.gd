class_name HudStyle
extends RefCounted
## Estilo do HUD (presentação): molduras e barras desenhadas em código, sem arte externa.
## Inspirado no HUD de Baldur's Gate 3 e Stoneshard: painel escuro com gradiente, moldura de bronze
## com filete dourado interno, barras com brilho no topo e valor escrito dentro.

static var _cache: Dictionary = {}


## Textura de 24x24 com gradiente vertical, borda de bronze (2 px) e filete dourado interno.
## Usada como nine-patch: os cantos ficam fixos e o miolo estica.
static func moldura(topo: Color, fundo: Color, borda: Color, filete: Color, margem: int = 6) -> StyleBoxTexture:
	var chave := "m%s%s%s%s%d" % [topo, fundo, borda, filete, margem]
	if not _cache.has(chave):
		var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		for y in 24:
			var k := float(y) / 23.0
			var base := topo.lerp(fundo, k)
			for x in 24:
				var c := base
				if x < 2 or x > 21 or y < 2 or y > 21:
					c = borda
				if (x == 2 or x == 21 or y == 2 or y == 21) and x >= 2 and x <= 21 and y >= 2 and y <= 21:
					c = filete
				img.set_pixel(x, y, c)
		_cache[chave] = ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = _cache[chave]
	sb.texture_margin_left = margem
	sb.texture_margin_right = margem
	sb.texture_margin_top = margem
	sb.texture_margin_bottom = margem
	sb.set_content_margin_all(8)
	return sb


## Painel padrão do HUD: tom ardósia escuro com gradiente e moldura de bronze.
static func painel() -> StyleBoxTexture:
	return moldura(Color(0.13, 0.11, 0.12, 0.96), Color(0.05, 0.04, 0.05, 0.96), Color(0.42, 0.31, 0.16), Color(0.86, 0.68, 0.36))


## Barra de fill com brilho no topo e sombra embaixo (textura 4x8, esticada).
static func barra_fill(cor: Color) -> StyleBoxTexture:
	var chave := "f%s" % cor
	if not _cache.has(chave):
		var img := Image.create(4, 8, false, Image.FORMAT_RGBA8)
		for y in 8:
			var k := float(y) / 7.0
			var c := cor.lightened(0.35 * (1.0 - k)).darkened(0.35 * k)
			for x in 4:
				var px := c
				if y == 7:
					px = cor.darkened(0.55)
				elif y == 0:
					px = cor.lightened(0.55)
				img.set_pixel(x, y, px)
		_cache[chave] = ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = _cache[chave]
	sb.texture_margin_left = 1
	sb.texture_margin_right = 1
	sb.texture_margin_top = 1
	sb.texture_margin_bottom = 1
	return sb


## Fundo de barra: poço escuro com borda fina de bronze.
static func barra_fundo() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.025, 0.03)
	sb.border_color = Color(0.36, 0.27, 0.15)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	return sb
