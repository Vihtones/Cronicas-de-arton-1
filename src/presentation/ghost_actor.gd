class_name GhostActor
extends Node2D
## Fantasma do jogador no combate: um sprite translúcido que ENSAIA o plano em laço — anda o caminho,
## investe contra o alvo, dispara ou conjura — para o jogador ver o turno antes de confirmar.
## Pura apresentação: não toca no mundo. Recebe uma lista de trechos já calculada (ver CombatView._ghost_script):
##   {"k":"walk","pts":[Vector2,...]}                  anda por pontos (mundo)
##   {"k":"hit","from":Vector2,"to":Vector2}           golpe corpo a corpo: recua, avança e volta
##   {"k":"shoot","from":Vector2,"to":Vector2}         ataque à distância: recuo curto e projétil
##   {"k":"cast","at":Vector2,"to":Vector2}            conjuração: pulso (e raio, se houver alvo)

const WALK_SPEED := 110.0
const HIT_TIME := 0.42
const SHOOT_TIME := 0.5
const CAST_TIME := 0.5
const HOLD := 0.55          # pausa no fim antes de repetir
const COLOR := Color(0.55, 0.85, 1.0, 0.6)

var sprite: Sprite2D
var _segs: Array = []
var _sig := ""
var _t := 0.0
var _total := 0.0
var _origin := Vector2.ZERO
var _dir := 0
var _pos := Vector2.ZERO
var _walking := false
var _fx: Array = []          # desenhos do instante: {"type","a","b","p"}


func _ready() -> void:
	z_index = 40
	visible = false
	sprite = Sprite2D.new()
	sprite.hframes = 3
	sprite.vframes = 4
	sprite.offset = Vector2(0, -12)
	add_child(sprite)


## Define o roteiro. Só reinicia o laço se ele mudou (o preview é refeito a cada movimento do mouse).
func set_script_data(origin: Vector2, segs: Array, texture: Texture2D, tint: Color, scale_factor: float) -> void:
	if sprite == null:
		return
	var sig := str(origin) + str(segs)
	if sig == _sig:
		return
	_sig = sig
	_origin = origin
	_segs = segs
	_t = 0.0
	_total = 0.0
	for s in _segs:
		_total += _dur(s)
	sprite.texture = texture
	sprite.self_modulate = tint
	sprite.scale = Vector2.ONE * scale_factor
	visible = not _segs.is_empty() and texture != null
	_pos = origin
	position = origin


func clear() -> void:
	_segs = []
	_sig = ""
	visible = false


func _dur(s: Dictionary) -> float:
	match s.k:
		"walk":
			var d := 0.0
			var prev := _origin
			# a duração só depende do comprimento do caminho
			for p in s.pts:
				d += prev.distance_to(p)
				prev = p
			return maxf(0.15, d / WALK_SPEED)
		"hit": return HIT_TIME
		"shoot": return SHOOT_TIME
		"cast": return CAST_TIME
	return 0.0


func _face(d: Vector2) -> void:
	if d.length() < 0.1:
		return
	if absf(d.x) > absf(d.y):
		_dir = 2 if d.x > 0 else 1
	else:
		_dir = 0 if d.y > 0 else 3


func _process(delta: float) -> void:
	if not visible or _segs.is_empty():
		return
	_t += delta
	var cycle := _total + HOLD
	if _t >= cycle:
		_t = fmod(_t, cycle)
	_fx.clear()
	_walking = false
	var pos := _origin
	var scale_mul := Vector2.ONE
	var t := _t
	var alpha := 1.0
	var done := true
	for s in _segs:
		var d := _dur(s)
		if t >= d:
			# trecho já cumprido: só atualiza onde o fantasma ficou
			match s.k:
				"walk":
					if not s.pts.is_empty():
						pos = s.pts[-1]
						if s.pts.size() > 1:
							_face(s.pts[-1] - s.pts[-2])
				"hit", "shoot", "cast":
					_face(s.to - s.from if s.has("from") else s.to - s.at)
			t -= d
			continue
		done = false
		var u := clampf(t / maxf(d, 0.001), 0.0, 1.0)
		match s.k:
			"walk":
				_walking = true
				var travelled := u * d * WALK_SPEED
				var prev: Vector2 = pos
				for p in s.pts:
					var seg := prev.distance_to(p)
					if travelled <= seg or p == s.pts[-1]:
						var f := clampf(travelled / maxf(seg, 0.001), 0.0, 1.0)
						pos = prev.lerp(p, f)
						_face(p - prev)
						break
					travelled -= seg
					prev = p
			"hit":
				var dirv: Vector2 = (s.to - s.from)
				var n := dirv.normalized()
				_face(dirv)
				pos = s.from
				# antecipação (0..0.3) recua; golpe (0.3..0.55) avança 70% do caminho; recuperação volta
				var off := 0.0
				if u < 0.3:
					off = -6.0 * (u / 0.3)
					scale_mul = Vector2(1.1, 0.9)
				elif u < 0.55:
					var k := (u - 0.3) / 0.25
					off = lerpf(-6.0, maxf(0.0, dirv.length() - 14.0), k)
					scale_mul = Vector2(0.9, 1.1)
					if k > 0.7:
						_fx.append({"type": "slash", "a": s.to, "p": (k - 0.7) / 0.3, "n": n})
				else:
					off = lerpf(maxf(0.0, dirv.length() - 14.0), 0.0, (u - 0.55) / 0.45)
				pos += n * off
			"shoot":
				var dv: Vector2 = s.to - s.from
				_face(dv)
				pos = s.from
				if u < 0.3:
					pos -= dv.normalized() * 3.0 * (u / 0.3)
				else:
					var k2 := (u - 0.3) / 0.7
					_fx.append({"type": "bolt", "a": s.from, "b": s.to, "p": k2})
			"cast":
				pos = s.at
				if s.to != s.at:
					_face(s.to - s.at)
				var pulse := sin(u * PI)
				scale_mul = Vector2.ONE * (1.0 + 0.12 * pulse)
				_fx.append({"type": "ring", "a": s.at, "p": u})
				if s.to != s.at and u > 0.4:
					_fx.append({"type": "ray", "a": s.at, "b": s.to, "p": (u - 0.4) / 0.6})
		break
	if done:
		# fim do roteiro: segura a última pose e esmaece antes de repetir
		var hold_t := _t - _total
		alpha = clampf(1.0 - maxf(0.0, hold_t - (HOLD - 0.2)) / 0.2, 0.0, 1.0)
		if not _segs.is_empty():
			var last: Dictionary = _segs[-1]
			if last.k == "walk" and not last.pts.is_empty():
				pos = last.pts[-1]
	_pos = pos
	position = pos
	if _walking:
		sprite.frame = _dir * 3 + 1 + (int(_t * 8.0) % 2)
	else:
		sprite.frame = _dir * 3
	sprite.position = Vector2(0, -absf(sin(_t * 16.0)) * 1.5) if _walking else Vector2.ZERO
	sprite.modulate = Color(0.55, 0.9, 1.25, 0.78 * alpha * (0.88 + 0.12 * sin(_t * 6.0)))
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	# sombra do fantasma e efeitos do instante (desenhados em coordenadas locais: o nó está em _pos)
	draw_circle(Vector2(0, 3), 5.0, Color(COLOR.r, COLOR.g, COLOR.b, 0.18))
	for f in _fx:
		match f.type:
			"slash":
				var c: Vector2 = f.a - _pos
				var n: Vector2 = f.n
				var perp := Vector2(-n.y, n.x)
				var a: float = 1.0 - float(f.p)
				for i in 3:
					var o := perp * (i - 1) * 5.0
					draw_line(c - n * 6.0 + o, c + n * 6.0 + o, Color(1, 0.8, 0.5, a), 1.5)
			"bolt":
				var from: Vector2 = f.a - _pos
				var to: Vector2 = f.b - _pos
				draw_circle(from.lerp(to, f.p), 2.5, Color(1, 0.9, 0.6, 0.9))
				draw_line(from.lerp(to, maxf(0.0, f.p - 0.15)), from.lerp(to, f.p), Color(1, 0.9, 0.6, 0.5), 1.5)
			"ring":
				draw_arc(Vector2(0, -8), 8.0 + 10.0 * f.p, 0, TAU, 20, Color(0.7, 0.75, 1.0, 0.7 * (1.0 - f.p)), 1.5)
			"ray":
				var from2: Vector2 = f.a - _pos
				var to2: Vector2 = f.b - _pos
				draw_line(from2 + Vector2(0, -8), (from2 + Vector2(0, -8)).lerp(to2 + Vector2(0, -8), f.p), Color(0.7, 0.75, 1.0, 0.8), 2.0)
