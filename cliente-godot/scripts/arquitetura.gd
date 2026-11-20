extends RefCounted
# Materiais de arquitetura com detalhe procedural (19/11, pedido de Robson: "muitas coisas sem definição,
# parecendo apenas blocos"). Um único shader para todas as vilas e cidades, sem texturas novas:
#   pedra   cantaria (blocos em fiadas desencontradas, argamassa funda, quina chanfrada, tom por bloco)
#   madeira tábuas com frestas, veio e tom por tábua
#   telha   telhas/escamas em fileiras sobrepostas, com sombra na borda
#   reboco  reboco com manchas e leve relevo
#   metal   chapa escovada com riscos
#   palha   cobertura de palha ou capim em camadas, com fios
# Projeção triplanar no espaço do mundo (funciona em MultiMesh e em peças escaladas) e relevo por
# derivadas de tela (não precisa de tangentes). O detalhe some aos poucos com a distância para não
# cintilar e o custo é só aritmética no fragmento.

const TIPOS := {"pedra": 0, "madeira": 1, "telha": 2, "reboco": 3, "metal": 4, "palha": 5}

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform vec4 cor : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform int tipo = 0;
uniform vec2 bloco = vec2(0.9, 0.42);   // largura x altura da peça (m): bloco, tábua, telha
uniform float relevo = 1.0;
uniform float rugosidade = 0.9;
uniform float metalico = 0.0;
uniform float variacao = 0.22;           // diferença de tom entre peças
uniform float desgaste = 0.35;           // manchas grandes (sujeira, umidade)
// textura de verdade (kit CC0 da Quaternius): cor, relevo (normal map) e aspereza, projetadas no mundo
uniform bool usa_tex = false;
uniform sampler2D tex_cor : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rug : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_metros = 2.0;          // metros cobertos por uma repetição da textura
uniform vec4 tex_media : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float tingir = 0.85;             // 0 = cor original da textura, 1 = cor da paleta da raça

varying vec3 wpos;
varying vec3 wnor;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnor = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return ruido(p) * 0.55 + ruido(p * 2.3 + 7.1) * 0.3 + ruido(p * 5.1 - 3.7) * 0.15; }

// x = altura (0 fundo .. 1 topo), y = tom da peça (0..1), z = máscara de junta (1 = junta)
vec3 cantaria(vec2 uv, vec2 b) {
	float fila = floor(uv.y / b.y);
	float desl = fract(fila * 0.5) + h21(vec2(fila, 3.1)) * 0.35;
	float largura = b.x * (0.75 + 0.5 * h21(vec2(fila, 9.7)));
	vec2 q = vec2(uv.x / largura + desl, uv.y / b.y);
	vec2 c = floor(q); vec2 f = fract(q);
	vec2 m = min(f, 1.0 - f) * vec2(largura, b.y);
	float d = min(m.x, m.y);
	float junta = 1.0 - smoothstep(0.012, 0.028, d);
	float chanfro = smoothstep(0.0, 0.07, d);
	float face = fbm(uv * 3.0 + c * 1.7);
	return vec3((1.0 - junta) * (0.55 + 0.35 * chanfro) + face * 0.18, h21(c + fila * 1.3), junta);
}

vec3 tabuas(vec2 uv, vec2 b) {
	// tábuas correm em v; largura b.x*0.3
	float lw = b.x * 0.28;
	float i = floor(uv.x / lw);
	float f = fract(uv.x / lw);
	float comp = 2.4 + 1.6 * h21(vec2(i, 2.0));
	float j = floor((uv.y + h21(vec2(i, 5.0)) * comp) / comp);
	float fy = fract((uv.y + h21(vec2(i, 5.0)) * comp) / comp);
	float d = min(min(f, 1.0 - f) * lw, min(fy, 1.0 - fy) * comp);
	float junta = 1.0 - smoothstep(0.004, 0.012, d);
	float veio = ruido(vec2(uv.x * 38.0 + i * 3.0, uv.y * 1.6)) * 0.6 + ruido(vec2(uv.x * 90.0, uv.y * 4.0)) * 0.4;
	float tom = h21(vec2(i, j));
	return vec3((1.0 - junta) * (0.7 + 0.15 * smoothstep(0.0, 0.03, d)) + veio * 0.12, tom * 0.7 + veio * 0.3, junta);
}

vec3 telhas(vec2 uv, vec2 b) {
	float fila = floor(uv.y / b.y);
	float fy = fract(uv.y / b.y);
	float x = uv.x / b.x + fila * 0.5;
	float c = floor(x);
	float fx = fract(x);
	// borda de baixo de cada telha fica alta (sobrepõe a fileira de baixo), sobe em rampa
	float h = 1.0 - fy * 0.75;
	float lado = min(fx, 1.0 - fx) * b.x;
	float junta = 1.0 - smoothstep(0.006, 0.02, lado);
	// borda arredondada (escama)
	float arco = smoothstep(0.0, 0.12, fy - 0.12 * (1.0 - pow(2.0 * fx - 1.0, 2.0)) + 0.06);
	h *= mix(0.4, 1.0, arco) * (1.0 - junta * 0.6);
	return vec3(h, h21(vec2(c, fila)), max(junta, 1.0 - arco));
}

vec3 palha(vec2 uv, vec2 b) {
	float fila = floor(uv.y / b.y);
	float fy = fract(uv.y / b.y);
	float fio = ruido(vec2(uv.x * 55.0 + fila * 7.0, uv.y * 2.5)) * 0.6 + ruido(vec2(uv.x * 140.0, uv.y * 6.0)) * 0.4;
	float ponta = smoothstep(0.0, 0.25, fy + (fio - 0.5) * 0.25);
	float h = (1.0 - fy * 0.6) * (0.55 + 0.45 * fio) * mix(0.5, 1.0, ponta);
	return vec3(h, fio * 0.7 + h21(vec2(floor(uv.x * 1.3), fila)) * 0.3, (1.0 - ponta) * 0.8);
}

vec3 padrao(vec2 uv, int t, vec2 b, bool chao) {
	if (t == 5) return palha(uv, b);
	if (t == 0) return chao ? cantaria(uv, vec2(b.x * 1.1, b.x * 0.8)) : cantaria(uv, b);
	if (t == 1) return tabuas(uv.yx * (chao ? 1.0 : 0.0) + uv * (chao ? 0.0 : 1.0), b);
	if (t == 2) return telhas(uv, b);
	if (t == 3) {
		float n = fbm(uv * 1.3);
		return vec3(0.6 + fbm(uv * 9.0) * 0.25, n, 0.0);
	}
	float r = ruido(vec2(uv.x * 2.0, uv.y * 140.0));
	return vec3(0.5 + r * 0.1, r, 0.0);
}

vec3 nmap(vec2 uv) {
	vec3 t = texture(tex_nor, uv).xyz * 2.0 - 1.0;
	t.y = -t.y;   // normal map no padrão DirectX
	return t;
}

void fragment() {
	vec3 n = normalize(wnor);
	vec3 w = pow(abs(n), vec3(5.0));
	w /= (w.x + w.y + w.z);
	if (usa_tex) {
		float k = 1.0 / tex_metros;
		vec2 ux = vec2(wpos.z * sign(n.x), -wpos.y) * k;
		vec2 uy = vec2(wpos.x, wpos.z * sign(n.y)) * k;
		vec2 uz = vec2(-wpos.x * sign(n.z), -wpos.y) * k;
		vec3 c = texture(tex_cor, ux).rgb * w.x + texture(tex_cor, uy).rgb * w.y + texture(tex_cor, uz).rgb * w.z;
		float rr = texture(tex_rug, ux).g * w.x + texture(tex_rug, uy).g * w.y + texture(tex_rug, uz).g * w.z;
		// relevo: mistura "whiteout" das três projeções
		vec3 tx = nmap(ux); vec3 ty = nmap(uy); vec3 tz = nmap(uz);
		tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
		ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
		tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
		vec3 nw = normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
		vec3 tingida = c / max(tex_media.rgb, vec3(0.02)) * cor.rgb;
		float mancha = fbm(wpos.xz * 0.12 + wpos.y * 0.05);
		ALBEDO = mix(c, tingida, tingir) * (1.0 - desgaste * 0.3 * smoothstep(0.45, 0.85, mancha));
		ROUGHNESS = clamp(rr * rugosidade / 0.85, 0.05, 1.0);
		METALLIC = metalico;
		SPECULAR = 0.35;
	} else {
	vec2 b = bloco;
	vec3 px = padrao(wpos.zy, tipo, b, false);
	vec3 pz = padrao(wpos.xy, tipo, b, false);
	vec3 py = padrao(wpos.xz, tipo, b, true);
	vec3 p = px * w.x + pz * w.z + py * w.y;

	// detalhe enquanto a peça ocupa pixels suficientes (some sem cintilar quando fica pequena)
	float px_m = length(fwidth(wpos));
	float perto = 1.0 - smoothstep(0.12, 0.35, px_m / max(bloco.y, 0.05));
	float mancha = fbm(wpos.xz * 0.12 + wpos.y * 0.05);
	vec3 base = cor.rgb * (1.0 + (p.y - 0.5) * variacao * 2.0 * perto);
	base = mix(base, base * vec3(1.06, 1.0, 0.9), fract(p.y * 7.31) * 0.6 * perto);   // tom quente/frio por peça
	base *= 1.0 - desgaste * 0.35 * smoothstep(0.45, 0.85, mancha);
	vec3 escuro = base * (tipo == 2 ? 0.45 : (tipo == 5 ? 0.6 : 0.5));
	ALBEDO = mix(base, escuro, p.z * perto);
	ALBEDO *= mix(1.0, 0.82 + 0.18 * p.x, perto);   // oclusão nas partes fundas
	if (tipo == 0 || tipo == 3) {   // grão da pedra e do reboco
		float fino = fbm(wpos.xy * 4.3 + wpos.zx * 3.7);
		ALBEDO *= mix(1.0, 0.78 + 0.36 * fino, perto);
	}

	// relevo: gradiente da altura em espaço de tela
	float alt = p.x * relevo * perto;
	vec3 dpx = dFdx(VERTEX); vec3 dpy = dFdy(VERTEX);
	float dhx = dFdx(alt); float dhy = dFdy(alt);
	vec3 r1 = cross(dpy, NORMAL); vec3 r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * 0.06);

	ROUGHNESS = clamp(rugosidade + p.z * 0.08 - (1.0 - p.x) * 0.04, 0.05, 1.0);
	METALLIC = metalico;
	SPECULAR = 0.35;
	}
}
"""

# cor média de cada textura (para tingir na paleta da raça sem perder o desenho)
const MEDIAS := {"brick": Color(0.574, 0.523, 0.459), "unevenbrick": Color(0.53, 0.474, 0.4),
	"plaster": Color(0.684, 0.621, 0.497), "roundtiles": Color(0.697, 0.33, 0.186)}
# Texturas: kit "Medieval Village MegaKit" da Quaternius, licença CC0 (assets/world/arq/LICENSE_CC0_Quaternius.txt)

static var _shader: Shader
static var _cache := {}


# tipo: pedra | madeira | telha | reboco | metal. opcoes: bloco (Vector2 m), relevo, rugosidade, metalico,
# variacao, desgaste
static func material(tipo: String, c: Color, opcoes := {}) -> ShaderMaterial:
	var k := tipo + c.to_html() + str(opcoes)
	if _cache.has(k):
		return _cache[k]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("cor", c)
	m.set_shader_parameter("tipo", int(TIPOS.get(tipo, 3)))
	var bloco: Vector2 = {"pedra": Vector2(0.9, 0.42), "madeira": Vector2(0.9, 0.42), "telha": Vector2(0.34, 0.24), "palha": Vector2(1, 0.45),
		"reboco": Vector2(1, 1), "metal": Vector2(1, 1)}.get(tipo, Vector2(1, 1))
	m.set_shader_parameter("bloco", opcoes.get("bloco", bloco))
	m.set_shader_parameter("rugosidade", opcoes.get("rugosidade", {"metal": 0.4, "telha": 0.75}.get(tipo, 0.9)))
	m.set_shader_parameter("metalico", opcoes.get("metalico", 0.7 if tipo == "metal" else 0.0))
	m.set_shader_parameter("relevo", opcoes.get("relevo", 1.0))
	m.set_shader_parameter("variacao", opcoes.get("variacao", 0.3 if tipo == "pedra" else 0.22))
	m.set_shader_parameter("desgaste", opcoes.get("desgaste", 0.35))
	var tex: String = opcoes.get("textura", {"pedra": "brick", "telha": "roundtiles", "reboco": "plaster"}.get(tipo, ""))
	if tex != "" and tex != "nenhuma" and ResourceLoader.exists("res://assets/world/arq/%s_basecolor.webp" % tex):
		m.set_shader_parameter("usa_tex", true)
		m.set_shader_parameter("tex_cor", load("res://assets/world/arq/%s_basecolor.webp" % tex))
		m.set_shader_parameter("tex_nor", load("res://assets/world/arq/%s_normal.webp" % tex))
		m.set_shader_parameter("tex_rug", load("res://assets/world/arq/%s_roughness.webp" % tex))
		m.set_shader_parameter("tex_media", MEDIAS.get(tex, Color(0.5, 0.5, 0.5)))
		m.set_shader_parameter("tex_metros", float(opcoes.get("metros", 2.0 if tipo != "telha" else 1.6)))
		m.set_shader_parameter("tingir", float(opcoes.get("tingir", 0.85)))
	_cache[k] = m
	return m
