class_name PostProcess
extends CanvasLayer
## Pós-processamento de tela (Bíblia de Arte: luz emocional, blur sutil e SELETIVO, Children of Morta).
## Gradação por hora do dia (técnica de LUT do Graveyard Keeper, aqui como tinta/saturação/contraste),
## vinheta, desfoque dinâmico fora do foco, flash e aberração cromática.
## O centro do foco fica sempre nítido: personagens, chão andável e alvos não são desfocados (AD-13).

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec4 tint : source_color = vec4(1.0);
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float brightness = 0.0;
uniform float vignette = 0.3;
uniform float blur_amount = 0.0;
uniform vec2 focus = vec2(0.5, 0.5);
uniform float focus_radius = 0.32;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float chroma = 0.0;

vec3 sample_blur(vec2 uv, vec2 px, float r) {
	vec3 c = texture(screen_tex, uv).rgb * 0.2;
	c += texture(screen_tex, uv + vec2(r, 0.0) * px).rgb * 0.1;
	c += texture(screen_tex, uv - vec2(r, 0.0) * px).rgb * 0.1;
	c += texture(screen_tex, uv + vec2(0.0, r) * px).rgb * 0.1;
	c += texture(screen_tex, uv - vec2(0.0, r) * px).rgb * 0.1;
	c += texture(screen_tex, uv + vec2(r, r) * px * 0.7).rgb * 0.1;
	c += texture(screen_tex, uv - vec2(r, r) * px * 0.7).rgb * 0.1;
	c += texture(screen_tex, uv + vec2(r, -r) * px * 0.7).rgb * 0.1;
	c += texture(screen_tex, uv - vec2(r, -r) * px * 0.7).rgb * 0.1;
	return c;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 asp = vec2(1.0, SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y);
	float d = distance(uv * asp, focus * asp);
	float b = blur_amount * smoothstep(focus_radius, focus_radius + 0.38, d);
	vec3 col;
	if (b > 0.01) {
		col = sample_blur(uv, SCREEN_PIXEL_SIZE, 1.0 + b * 3.0);
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	if (chroma > 0.0) {
		vec2 off = (uv - 0.5) * chroma * 0.012;
		col.r = texture(screen_tex, uv + off).r;
		col.b = texture(screen_tex, uv - off).b;
	}
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = (col - 0.5) * contrast + 0.5 + brightness;
	col *= tint.rgb;
	float v = smoothstep(0.85, 0.25, distance(uv, vec2(0.5)) * 1.15);
	col *= mix(1.0 - vignette, 1.0, v);
	col = mix(col, flash_color.rgb, flash);
	COLOR = vec4(col, 1.0);
}
"""

var rect: ColorRect
var mat: ShaderMaterial
var enabled := true
var _blur_base := 0.0
var _blur_boost := 0.0
var _flash := 0.0
var _chroma := 0.0


func _ready() -> void:
	layer = 2
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	rect.material = mat
	add_child(rect)
	process_mode = Node.PROCESS_MODE_ALWAYS


## Perfil gráfico: "baixo"/modo seguro desliga o pós-processamento inteiro.
func apply_profile(profile: String, safe_mode: bool) -> void:
	enabled = profile != "baixo" and not safe_mode
	rect.visible = enabled
	_blur_base = {"medio": 0.35, "alto": 0.6}.get(profile, 0.0)


func grade(p_tint: Color, sat: float, con: float, bright: float, vig: float) -> void:
	if not enabled:
		return
	mat.set_shader_parameter("tint", p_tint)
	mat.set_shader_parameter("saturation", sat)
	mat.set_shader_parameter("contrast", con)
	mat.set_shader_parameter("brightness", bright)
	mat.set_shader_parameter("vignette", vig)


## Foco do desfoque em coordenadas de tela (0..1). Raio menor = foco mais fechado (cinematográfico).
func set_focus(screen_uv: Vector2, radius: float = 0.32) -> void:
	mat.set_shader_parameter("focus", screen_uv)
	mat.set_shader_parameter("focus_radius", radius)


func boost_blur(amount: float) -> void:
	_blur_boost = amount


func flash(strength: float, col: Color = Color.WHITE) -> void:
	if Game.settings.reduce_flashes:
		return
	_flash = maxf(_flash, strength)
	mat.set_shader_parameter("flash_color", col)


func aberration(strength: float) -> void:
	if Game.settings.reduce_flashes:
		return
	_chroma = maxf(_chroma, strength)


func _process(delta: float) -> void:
	# usa o tempo real: efeitos continuam suaves mesmo durante câmera lenta
	var rd := delta / maxf(0.05, Engine.time_scale)
	_flash = move_toward(_flash, 0.0, rd * 3.5)
	_chroma = move_toward(_chroma, 0.0, rd * 2.5)
	if not enabled:
		return
	mat.set_shader_parameter("flash", _flash)
	mat.set_shader_parameter("chroma", _chroma)
	mat.set_shader_parameter("blur_amount", _blur_base + _blur_boost)
