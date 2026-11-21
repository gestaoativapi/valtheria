extends Node3D
# Efeitos dos elementos (fogo, gelo, água, terra, vento, raio, luz, sombra...), feitos com partículas leves
# que funcionam em qualquer modo gráfico. `amount` (0 a 1) reduz a quantidade nas qualidades baixas.

const ELEM := {
	"fire": [Color(1.0, 0.85, 0.3), Color(1.0, 0.35, 0.05)], "fogo": [Color(1.0, 0.85, 0.3), Color(1.0, 0.35, 0.05)],
	"ice": [Color(0.85, 0.97, 1.0), Color(0.35, 0.7, 1.0)], "gelo": [Color(0.85, 0.97, 1.0), Color(0.35, 0.7, 1.0)],
	"agua": [Color(0.7, 0.9, 1.0), Color(0.15, 0.45, 0.9)],
	"earth": [Color(0.8, 0.65, 0.4), Color(0.45, 0.32, 0.18)], "terra": [Color(0.8, 0.65, 0.4), Color(0.45, 0.32, 0.18)],
	"wind": [Color(0.9, 1.0, 0.95), Color(0.55, 0.9, 0.75)], "vento": [Color(0.9, 1.0, 0.95), Color(0.55, 0.9, 0.75)],
	"raio": [Color(1.0, 1.0, 0.8), Color(0.6, 0.6, 1.0)],
	"holy": [Color(1.0, 0.98, 0.8), Color(1.0, 0.8, 0.3)], "luz": [Color(1.0, 0.98, 0.8), Color(1.0, 0.8, 0.3)],
	"dark": [Color(0.75, 0.45, 1.0), Color(0.25, 0.05, 0.4)], "sombra": [Color(0.75, 0.45, 1.0), Color(0.25, 0.05, 0.4)],
	"nature": [Color(0.75, 1.0, 0.5), Color(0.2, 0.6, 0.2)], "natureza": [Color(0.75, 1.0, 0.5), Color(0.2, 0.6, 0.2)],
	"poison": [Color(0.75, 1.0, 0.3), Color(0.35, 0.55, 0.05)],
	"arcane": [Color(0.9, 0.7, 1.0), Color(0.5, 0.25, 1.0)], "spirit": [Color(0.7, 1.0, 0.95), Color(0.2, 0.7, 0.75)],
	"blood": [Color(1.0, 0.4, 0.35), Color(0.55, 0.02, 0.05)],
	"enc_branco": [Color(1.0, 1.0, 1.0), Color(0.78, 0.84, 0.95)], "enc_azul": [Color(0.8, 0.93, 1.0), Color(0.2, 0.5, 1.0)],
	"enc_ouro": [Color(1.0, 0.95, 0.72), Color(1.0, 0.68, 0.18)], "falha": [Color(0.62, 0.58, 0.58), Color(0.22, 0.18, 0.2)],
	"": [Color(1.0, 0.95, 0.85), Color(0.8, 0.75, 0.6)],
}
static var amount := 1.0
static var _mats := {}


static func colors(elem: String) -> Array:
	return ELEM.get(elem, ELEM[""])


# material de partícula: disco macio, sempre de frente para a câmera; add = brilho somado (fogo, magia)
static func _mat(add: bool) -> StandardMaterial3D:
	if _mats.has(add):
		return _mats[add]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	_mats[add] = m
	return m


static func emitter(count: int, life: float, add: bool, size: float, c0: Color, c1: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(2, int(count * maxf(amount, 0.25)))
	p.lifetime = life
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _mat(add)
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, Color(c1.r, c1.g, c1.b, 0.0))
	g.add_point(0.5, c1)
	p.color_ramp = g
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = c
	p.gravity = Vector3.ZERO
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# fogueira ou tocha: chamas, brasas e fumaça
static func fire(size := 1.0, smoke := true) -> Node3D:
	var root := Node3D.new()
	var f := emitter(26, 0.75, true, 0.75 * size, Color(1.0, 0.92, 0.45, 0.9), Color(1.0, 0.3, 0.04, 0.8))
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = 0.22 * size
	f.direction = Vector3.UP
	f.spread = 12.0
	f.initial_velocity_min = 1.1 * size
	f.initial_velocity_max = 2.0 * size
	f.scale_amount_min = 0.6
	f.scale_amount_max = 1.2
	root.add_child(f)
	var e := emitter(10, 1.6, true, 0.07 * size, Color(1.0, 0.8, 0.3), Color(1.0, 0.3, 0.05))
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.25 * size
	e.direction = Vector3.UP
	e.spread = 30.0
	e.initial_velocity_min = 1.0
	e.initial_velocity_max = 2.6
	e.gravity = Vector3(0.3, 0.6, 0.0)
	root.add_child(e)
	if smoke:
		var s := emitter(12, 3.2, false, 1.1 * size, Color(0.2, 0.19, 0.18, 0.0), Color(0.3, 0.29, 0.28, 0.32))
		s.position = Vector3(0, 0.9 * size, 0)
		s.direction = Vector3.UP
		s.spread = 14.0
		s.initial_velocity_min = 0.7
		s.initial_velocity_max = 1.2
		s.gravity = Vector3(0.35, 0.25, 0.1)
		s.scale_amount_min = 0.8
		s.scale_amount_max = 1.8
		root.add_child(s)
	return root


# explosão curta do elemento num ponto (golpe, magia acertando, cura)
static func burst(parent: Node, pos: Vector3, elem: String, size := 1.0) -> void:
	var c := colors(elem)
	var p := emitter(int(22 * size), 0.55, true, 0.4 * size, c[0], c[1])
	p.one_shot = true
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.5 * size
	p.initial_velocity_max = 4.5 * size
	p.damping_min = 4.0
	p.damping_max = 6.0
	if elem in ["earth", "terra", "blood", "poison"]:
		p.gravity = Vector3(0, -9.0, 0)
	elif elem in ["fire", "fogo", "holy", "luz", "spirit"]:
		p.gravity = Vector3(0, 2.5, 0)
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	# anel que se abre no chão
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 24
	tm.ring_segments = 4
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_color = Color(c[1].r, c[1].g, c[1].b, 0.9)
	tm.material = rm
	ring.mesh = tm
	ring.position = pos
	ring.scale = Vector3(0.4, 0.3, 0.4)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	var tw := parent.create_tween()
	tw.tween_property(ring, "scale", Vector3(3.2 * size, 0.3, 3.2 * size), 0.4)
	tw.parallel().tween_property(rm, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(ring.queue_free)
	tw.tween_interval(0.5)
	tw.tween_callback(p.queue_free)


# projétil do elemento voando até o alvo; chama `done` ao chegar
static func bolt(parent: Node, from: Vector3, to: Vector3, elem: String, time := 0.28) -> void:
	var c := colors(elem)
	var root := Node3D.new()
	root.position = from
	parent.add_child(root)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 8
	sm.rings = 4
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = c[0]
	sm.material = mm
	core.mesh = sm
	root.add_child(core)
	var trail := emitter(18, 0.35, true, 0.38, c[0], c[1])
	trail.local_coords = false
	trail.spread = 180.0
	trail.initial_velocity_max = 0.6
	root.add_child(trail)
	var tw := parent.create_tween()
	tw.tween_property(root, "position", to, time)
	tw.tween_callback(func():
		trail.emitting = false
		core.visible = false
		burst(parent, to, elem, 0.9))
	tw.tween_interval(0.5)
	tw.tween_callback(root.queue_free)


# flecha de verdade voando em arco leve até o alvo (arqueiros)
static func flecha(parent: Node, from: Vector3, to: Vector3, time := 0.32) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = from
	var haste := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = 0.8
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.55, 0.42, 0.28)
	cm.material = mt
	haste.mesh = cm
	haste.rotation = Vector3(PI * 0.5, 0, 0)  # haste ao longo de -Z (frente do look_at)
	root.add_child(haste)
	var d := to - from
	if d.length() > 0.1:
		root.look_at(to, Vector3.UP)
	var tw := parent.create_tween()
	tw.tween_property(root, "global_position", to, time)
	tw.tween_callback(root.queue_free)


# aura em volta do personagem (proteção, bônus)
static func aura(target: Node3D, elem: String, seconds: float) -> void:
	var c := colors(elem)
	var p := emitter(16, 1.0, true, 0.22, c[0], c[1])
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.7
	p.emission_ring_inner_radius = 0.6
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 5.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 1.8
	p.position = Vector3(0, 0.1, 0)
	target.add_child(p)
	var tw := target.create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(func(): p.emitting = false)
	tw.tween_interval(1.2)
	tw.tween_callback(p.queue_free)


# poeira nos pés ao correr
static func dust() -> CPUParticles3D:
	var p := emitter(8, 0.7, false, 0.5, Color(0.7, 0.62, 0.5, 0.0), Color(0.7, 0.62, 0.5, 0.3))
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.local_coords = false
	p.emitting = false
	p.position = Vector3(0, 0.1, 0)
	return p


# ================= efeitos de habilidade (fase de efeitos por classe) =================
# Tudo com poucos nós e vida curta: um material por tipo, reaproveitado; nada de luz dinâmica nova.

const SH_ESTRELA := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 cor : source_color = vec3(1.0);
uniform float forca = 1.0;
uniform float raios = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float e = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[0] *= e; MODELVIEW_MATRIX[1] *= e; MODELVIEW_MATRIX[2] *= e;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float g = TIME * 0.8;
	mat2 r = mat2(vec2(cos(g), -sin(g)), vec2(sin(g), cos(g)));
	vec2 q = r * p;
	float nucleo = exp(-d * d * 22.0);
	float halo = exp(-d * d * 4.0) * 0.45;
	float cruz = (exp(-abs(q.x) * 55.0) + exp(-abs(q.y) * 55.0)) * (1.0 - smoothstep(0.0, 1.0, d)) * raios;
	ALBEDO = mix(cor, vec3(1.0), nucleo * 0.6) * (nucleo * 1.5 + halo + cruz) * forca;
}
"""

const SH_CIRCULO := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 cor : source_color = vec3(0.6, 0.8, 1.0);
uniform float forca = 1.0;
float anel(float d, float r, float w) { return smoothstep(w, 0.0, abs(d - r)); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float a = atan(p.y, p.x);
	float giro = TIME * 0.9;
	float c = anel(d, 0.94, 0.025) + anel(d, 0.80, 0.015) + anel(d, 0.46, 0.012) * 0.8;
	// runas: traços curtos entre os anéis externos, girando
	float runa = step(0.55, fract((a + giro) * 24.0 / 6.2832)) * step(0.82, d) * step(d, 0.92);
	runa *= step(0.3, fract(sin(floor((a + giro) * 24.0 / 6.2832) * 91.7) * 437.5));
	// estrela de seis pontas (dois triângulos) girando ao contrário
	float h = 0.0;
	for (int k = 0; k < 6; k++) {
		float ang = float(k) * 1.0472 - giro * 0.6;
		vec2 n = vec2(cos(ang), sin(ang));
		h += smoothstep(0.012, 0.0, abs(dot(p, n) - 0.40)) * step(d, 0.80);
	}
	float miolo = (1.0 - smoothstep(0.0, 0.5, d)) * 0.18;
	float v = (c + runa * 0.9 + h * 0.7 + miolo) * step(d, 1.0);
	ALBEDO = cor * v * forca;
}
"""

const SH_CORTE := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 cor : source_color = vec3(1.0, 0.9, 0.6);
uniform float prog = 0.0;
void fragment() {
	// UV.x ao longo do arco (0 = início, 1 = fim), UV.y da borda interna (0) para a externa (1)
	float frente = smoothstep(prog - 0.55, prog, UV.x) * (1.0 - smoothstep(prog, prog + 0.02, UV.x));
	float borda = pow(UV.y, 3.0);
	float a = frente * borda * (1.0 - smoothstep(0.85, 1.0, prog));
	ALBEDO = mix(cor, vec3(1.0), borda * 0.5) * a * 2.2;
}
"""

const SH_COLUNA := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 cor : source_color = vec3(1.0, 0.9, 0.5);
uniform float forca = 1.0;
void fragment() {
	// UV.y: 0 no topo, 1 na base. Brilho maior na base, some suave no alto; bordas macias (sem cara de tubo de vidro)
	float frente = abs(dot(NORMAL, VIEW));
	float macio = pow(frente, 1.6);
	float v = pow(UV.y, 1.8) * smoothstep(1.0, 0.94, UV.y);
	float riscos = 0.55 + 0.45 * sin(UV.x * 37.7 + UV.y * 9.0 - TIME * 7.0);
	ALBEDO = cor * macio * v * riscos * forca * 0.9;
}
"""

static var _sh := {}


static func _shader(nome: String, codigo: String) -> Shader:
	if not _sh.has(nome):
		var s := Shader.new()
		s.code = codigo
		_sh[nome] = s
	return _sh[nome]


static func _sm(nome: String, codigo: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(nome, codigo)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func _quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	return q


static func _cor3(c: Color) -> Color:
	return Color(c.r, c.g, c.b)


# clarão em forma de estrela (impacto, ponta de arma, conjuração)
static func flare(parent: Node, pos: Vector3, cor: Color, tam := 1.0, dur := 0.35, raios := 1.0) -> void:
	var m := _sm("estrela", SH_ESTRELA, {"cor": _cor3(cor), "forca": 1.4, "raios": raios})
	var mi := MeshInstance3D.new()
	mi.mesh = _quad()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * tam * 0.4
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * tam * 1.3, dur * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v): m.set_shader_parameter("forca", v), 1.6, 0.0, dur).set_delay(dur * 0.2)
	tw.tween_callback(mi.queue_free)


# círculo mágico de conjuração no chão, girando, na cor do elemento
static func circulo_magico(alvo: Node3D, elem: String, dur := 0.9, raio := 1.3) -> void:
	var c := colors(elem)
	var m := _sm("circulo", SH_CIRCULO, {"cor": _cor3(c[1]).lerp(_cor3(c[0]), 0.2), "forca": 0.0})
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * raio * 2.0
	mi.mesh = pm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.05, 0)
	alvo.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_method(func(v): m.set_shader_parameter("forca", v), 0.0, 1.4, dur * 0.25)
	tw.parallel().tween_property(mi, "scale", Vector3.ONE, dur * 0.25).from(Vector3.ONE * 0.6)
	tw.tween_interval(dur * 0.45)
	tw.tween_method(func(v): m.set_shader_parameter("forca", v), 1.4, 0.0, dur * 0.3)
	tw.tween_callback(mi.queue_free)
	# faíscas subindo do círculo
	var p := emitter(int(14 * maxf(amount, 0.4)), 0.8, true, 0.12, c[0], c[1])
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = raio * 0.85
	p.emission_ring_inner_radius = raio * 0.6
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 6.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.4
	p.one_shot = true
	p.explosiveness = 0.3
	alvo.add_child(p)
	p.emitting = true
	var t2 := p.create_tween()
	t2.tween_interval(1.6)
	t2.tween_callback(p.queue_free)


static var _arco_mesh: ArrayMesh


# malha do corte: meia-lua achatada (gerada uma vez)
static func _malha_corte() -> ArrayMesh:
	if _arco_mesh != null:
		return _arco_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	for i in n + 1:
		var t := float(i) / n
		var a := lerpf(-1.25, 1.25, t)
		var larg := sin(t * PI) * 0.45 + 0.05
		var r_ext := 1.0
		var r_int := 1.0 - larg
		st.set_uv(Vector2(t, 1.0))
		st.add_vertex(Vector3(sin(a) * r_ext, 0, -cos(a) * r_ext))
		st.set_uv(Vector2(t, 0.0))
		st.add_vertex(Vector3(sin(a) * r_int, 0, -cos(a) * r_int))
	for i in n:
		var k := i * 2
		st.add_index(k)
		st.add_index(k + 1)
		st.add_index(k + 2)
		st.add_index(k + 1)
		st.add_index(k + 3)
		st.add_index(k + 2)
	_arco_mesh = st.commit()
	return _arco_mesh


# golpe de arma: meia-lua de luz que varre na frente do personagem (inclinação = tipo de golpe)
static func corte(dono: Node3D, cor: Color, raio := 1.5, altura := 1.1, inclina := 0.35, dur := 0.28) -> void:
	var m := _sm("corte", SH_CORTE, {"cor": _cor3(cor), "prog": 0.0})
	var mi := MeshInstance3D.new()
	mi.mesh = _malha_corte()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dono.add_child(mi)
	mi.position = Vector3(0, altura, 0.25)
	mi.rotation = Vector3(0, PI, inclina)  # a frente do personagem é +Z; a malha nasce virada para -Z
	mi.scale = Vector3.ONE * raio
	var tw := mi.create_tween()
	tw.tween_method(func(v): m.set_shader_parameter("prog", v), 0.0, 1.0, dur)
	tw.tween_callback(mi.queue_free)


# coluna de luz (cura, bênção, magia sagrada caindo do céu)
static func coluna(parent: Node, pos: Vector3, elem: String, altura := 5.0, raio := 0.8, dur := 0.9) -> void:
	var c := colors(elem)
	var m := _sm("coluna", SH_COLUNA, {"cor": _cor3(c[0]).lerp(_cor3(c[1]), 0.4), "forca": 0.0})
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = raio * 0.7
	cm.bottom_radius = raio
	cm.height = altura
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 20
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, altura * 0.5, 0)
	var tw := mi.create_tween()
	tw.tween_method(func(v): m.set_shader_parameter("forca", v), 0.0, 1.6, dur * 0.2)
	tw.parallel().tween_property(mi, "scale", Vector3.ONE, dur * 0.2).from(Vector3(0.3, 1, 0.3))
	tw.tween_method(func(v): m.set_shader_parameter("forca", v), 1.6, 0.0, dur * 0.8)
	tw.parallel().tween_property(mi, "scale", Vector3(1.4, 1, 1.4), dur * 0.8)
	tw.tween_callback(mi.queue_free)


# raio elétrico em zigue-zague entre dois pontos, piscando
static func relampago(parent: Node, de: Vector3, ate: Vector3, cor := Color(0.75, 0.8, 1.0)) -> void:
	var raiz := Node3D.new()
	parent.add_child(raiz)
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mt.albedo_color = cor.lerp(Color.WHITE, 0.5)
	var mg := StandardMaterial3D.new()
	mg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mg.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mg.albedo_color = cor * 0.22
	mg.disable_fog = true
	mt.disable_fog = true
	var pts: Array = [de]
	var n := 7
	var d := ate - de
	var lado := d.cross(Vector3.UP).normalized()
	if lado.length() < 0.1:
		lado = Vector3.RIGHT
	for i in range(1, n):
		var t := float(i) / n
		pts.append(de + d * t + lado * randf_range(-0.35, 0.35) + Vector3.UP * randf_range(-0.3, 0.3))
	pts.append(ate)
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		for camada in [[0.05, mt], [0.12, mg]]:
			var seg := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = camada[0]
			cm.bottom_radius = camada[0]
			cm.height = a.distance_to(b) + camada[0]
			cm.radial_segments = 6
			cm.rings = 1
			cm.material = camada[1]
			seg.mesh = cm
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			raiz.add_child(seg)
			seg.global_position = (a + b) * 0.5
			var dir := (b - a).normalized()
			var eixo := Vector3.UP.cross(dir)
			if eixo.length() > 0.001:
				seg.global_basis = Basis(eixo.normalized(), Vector3.UP.angle_to(dir))
	flare(parent, ate, cor, 1.4, 0.3)
	flare(parent, de, cor, 0.7, 0.2, 0.0)
	var tw := raiz.create_tween()
	tw.tween_property(raiz, "visible", false, 0.05).set_delay(0.06)
	tw.tween_property(raiz, "visible", true, 0.0).set_delay(0.04)
	tw.tween_interval(0.1)
	tw.tween_callback(raiz.queue_free)


# área no chão: círculo do elemento que se abre e faíscas subindo (golpes em área, armadilhas)
static func zona(parent: Node, pos: Vector3, elem: String, raio := 4.0, dur := 1.0) -> void:
	var c := colors(elem)
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = pos
	circulo_magico(holder, elem, dur, raio)
	burst(parent, pos + Vector3(0, 0.3, 0), elem, raio * 0.35)
	var tw := holder.create_tween()
	tw.tween_interval(dur + 0.8)
	tw.tween_callback(holder.queue_free)


# projétil de magia com forma por elemento: núcleo em clarão, rastro do elemento e impacto forte
static func magia(parent: Node, de: Vector3, ate: Vector3, elem: String, time := 0.3) -> void:
	if elem == "raio":
		relampago(parent, de, ate)
		burst(parent, ate, elem, 0.8)
		return
	var c := colors(elem)
	var raiz := Node3D.new()
	parent.add_child(raiz)
	raiz.global_position = de
	var nucleo := MeshInstance3D.new()
	nucleo.mesh = _quad()
	nucleo.material_override = _sm("estrela", SH_ESTRELA, {"cor": _cor3(c[1]).lerp(_cor3(c[0]), 0.5), "forca": 1.3, "raios": 0.5})
	nucleo.scale = Vector3.ONE * 0.9
	nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(nucleo)
	if elem in ["ice", "gelo"]:  # lasca de gelo girando dentro do brilho
		var lasca := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.18, 0.55, 0.18)
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.8, 0.95, 1.0, 0.85)
		lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lm.emission_enabled = true
		lm.emission = Color(0.5, 0.8, 1.0)
		lm.emission_energy_multiplier = 1.5
		pm.material = lm
		lasca.mesh = pm
		lasca.rotation = Vector3(PI * 0.5, 0, 0)
		raiz.add_child(lasca)
	var rastro := emitter(26, 0.45, true, 0.42, c[0], c[1])
	rastro.local_coords = false
	rastro.spread = 180.0
	rastro.initial_velocity_max = 0.5
	if elem in ["fire", "fogo"]:
		rastro.gravity = Vector3(0, 2.0, 0)
		rastro.scale_amount_max = 1.6
	raiz.add_child(rastro)
	if ate.distance_to(de) > 0.1:
		raiz.look_at(ate, Vector3.UP)
	var tw := raiz.create_tween()
	tw.tween_property(raiz, "global_position", ate, time)
	tw.tween_callback(func():
		rastro.emitting = false
		nucleo.visible = false
		for ch in raiz.get_children():
			if ch is MeshInstance3D:
				(ch as MeshInstance3D).visible = false
		flare(parent, ate, c[1].lerp(c[0], 0.5), 1.6, 0.35)
		burst(parent, ate, elem, 1.0))
	tw.tween_interval(0.6)
	tw.tween_callback(raiz.queue_free)


# flecha de habilidade: flecha com rastro brilhante e clarão no impacto
static func flecha_brilho(parent: Node, de: Vector3, ate: Vector3, elem: String, time := 0.3) -> void:
	flecha(parent, de, ate, time)
	var c := colors(elem if elem != "" else "wind")
	var raiz := Node3D.new()
	parent.add_child(raiz)
	raiz.global_position = de
	var rastro := emitter(24, 0.3, true, 0.22, c[0], c[1])
	rastro.local_coords = false
	rastro.spread = 10.0
	rastro.initial_velocity_max = 0.2
	raiz.add_child(rastro)
	var tw := raiz.create_tween()
	tw.tween_property(raiz, "global_position", ate, time)
	tw.tween_callback(func():
		rastro.emitting = false
		flare(parent, ate, c[0], 1.2, 0.3)
		burst(parent, ate, elem if elem != "" else "wind", 0.7))
	tw.tween_interval(0.5)
	tw.tween_callback(raiz.queue_free)


# ---------- reação elemental (pedido de Robson 21/11) ----------
# Quem solta a habilidade mostra o elemento nas mãos e no corpo; quem recebe reage ao elemento:
# fogo queima, gelo cria cristais e névoa, raio dá choques, vento gira em rajada, terra estilhaça o chão,
# luz brilha, sombra escorre em névoa escura, água respinga; golpe sem elemento solta faíscas.
static func _efeito_temp(no: Node, dur: float) -> void:
	no.get_tree().create_timer(dur).timeout.connect(func(): if is_instance_valid(no): no.queue_free())


static func _particulas(alvo: Node3D, pos: Vector3, elem: String, qtd: int, vida: float, tam: float, dur: float, cfg: Dictionary) -> CPUParticles3D:
	var c := colors(elem)
	var p := emitter(qtd, vida, true, tam, c[0], c[1])
	p.emission_shape = int(cfg.get("forma", CPUParticles3D.EMISSION_SHAPE_SPHERE))
	p.emission_sphere_radius = float(cfg.get("raio", 0.35))
	p.emission_box_extents = cfg.get("caixa", Vector3(0.3, 0.6, 0.3))
	p.emission_ring_radius = float(cfg.get("raio", 0.5))
	p.emission_ring_inner_radius = float(cfg.get("raio", 0.5)) * 0.8
	p.emission_ring_height = 0.05
	p.emission_ring_axis = Vector3.UP
	p.direction = cfg.get("dir", Vector3.UP)
	p.spread = float(cfg.get("spread", 30.0))
	p.initial_velocity_min = float(cfg.get("vel", 0.6)) * 0.5
	p.initial_velocity_max = float(cfg.get("vel", 0.6))
	p.gravity = cfg.get("grav", Vector3.ZERO)
	p.orbit_velocity_min = float(cfg.get("orbita", 0.0))
	p.orbit_velocity_max = float(cfg.get("orbita", 0.0))
	p.tangential_accel_min = float(cfg.get("tang", 0.0))
	p.tangential_accel_max = float(cfg.get("tang", 0.0))
	p.position = pos
	alvo.add_child(p)
	p.emitting = true
	alvo.get_tree().create_timer(dur).timeout.connect(func(): if is_instance_valid(p): p.emitting = false)
	_efeito_temp(p, dur + vida + 0.2)
	return p


static func reacao(alvo: Node3D, elem: String, papel: String, altura := 1.8, forca := 1.0) -> void:
	if alvo == null or not is_instance_valid(alvo) or not alvo.is_inside_tree():
		return
	var h := altura
	var k := clampf(forca, 0.6, 2.0)
	if papel == "conjurador":
		# o elemento acende em volta das mãos e sobe pelo corpo
		if elem == "":
			return
		_particulas(alvo, Vector3(0, h * 0.55, 0.25), elem, int(18 * k), 0.5, 0.07, 0.35, {"raio": 0.25, "vel": 0.8, "spread": 60.0})
		_particulas(alvo, Vector3(0, 0.05, 0), elem, int(16 * k), 0.8, 0.06, 0.3, {"forma": CPUParticles3D.EMISSION_SHAPE_RING, "raio": 0.55, "vel": 1.4, "spread": 8.0})
		return
	match elem:
		"fogo", "fire":
			_particulas(alvo, Vector3(0, h * 0.45, 0), "fogo", int(30 * k), 0.6, 0.12, 1.2, {"forma": CPUParticles3D.EMISSION_SHAPE_BOX, "caixa": Vector3(0.22, h * 0.35, 0.22), "vel": 1.2, "grav": Vector3(0, 2.0, 0)})
		"gelo", "ice":
			_particulas(alvo, Vector3(0, 0.15, 0), "gelo", int(22 * k), 1.2, 0.09, 0.4, {"forma": CPUParticles3D.EMISSION_SHAPE_RING, "raio": 0.45, "vel": 0.2, "spread": 5.0})
			_particulas(alvo, Vector3(0, h * 0.5, 0), "gelo", int(14 * k), 1.0, 0.18, 0.8, {"raio": 0.4, "vel": 0.15, "grav": Vector3(0, -0.3, 0)})
		"raio":
			_particulas(alvo, Vector3(0, h * 0.5, 0), "raio", int(26 * k), 0.15, 0.06, 0.6, {"raio": 0.45, "vel": 3.0, "spread": 180.0})
			var topo := alvo.global_position + Vector3(0, h + 0.4, 0)
			relampago(alvo.get_parent(), topo, alvo.global_position + Vector3(0, h * 0.4, 0), colors("raio")[0])
		"vento", "wind":
			_particulas(alvo, Vector3(0, h * 0.4, 0), "vento", int(30 * k), 0.7, 0.08, 0.7, {"forma": CPUParticles3D.EMISSION_SHAPE_RING, "raio": 0.6, "vel": 1.2, "orbita": 1.4, "spread": 10.0})
		"terra", "earth":
			_particulas(alvo, Vector3(0, 0.1, 0), "terra", int(20 * k), 0.7, 0.14, 0.15, {"forma": CPUParticles3D.EMISSION_SHAPE_RING, "raio": 0.5, "vel": 3.2, "spread": 25.0, "grav": Vector3(0, -9.0, 0)})
		"luz", "holy":
			_particulas(alvo, Vector3(0, h * 0.5, 0), "luz", int(24 * k), 0.6, 0.1, 0.4, {"raio": 0.5, "vel": 0.9, "spread": 180.0})
			flare(alvo.get_parent(), alvo.global_position + Vector3(0, h * 0.6, 0), colors("luz")[0], 0.9 * k, 0.35)
		"sombra", "dark":
			_particulas(alvo, Vector3(0, h * 0.7, 0), "sombra", int(24 * k), 1.0, 0.22, 0.9, {"forma": CPUParticles3D.EMISSION_SHAPE_BOX, "caixa": Vector3(0.25, 0.2, 0.25), "vel": 0.3, "grav": Vector3(0, -1.2, 0)})
		"agua":
			_particulas(alvo, Vector3(0, h * 0.6, 0), "agua", int(26 * k), 0.8, 0.08, 0.2, {"raio": 0.3, "vel": 2.5, "spread": 70.0, "grav": Vector3(0, -8.0, 0)})
		_:
			_particulas(alvo, Vector3(0, h * 0.55, 0.15), "", int(14 * k), 0.25, 0.05, 0.12, {"raio": 0.12, "vel": 3.0, "spread": 90.0, "dir": Vector3(0, 0.3, 1)})


# ---------- formas de ataque por tipo de habilidade ----------
static func _mat_add(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = cor
	m.disable_fog = true
	m.no_depth_test = false
	return m


# onda de choque: anel do elemento que se abre rente ao chão (atordoar, grito, impacto no chão)
static func onda_choque(parent: Node, pos: Vector3, elem: String, raio := 4.0, dur := 0.5) -> void:
	var c := colors(elem if elem != "" else "terra")
	for k in 2:
		var mi := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.86
		tm.outer_radius = 1.0
		tm.rings = 32
		tm.ring_segments = 6
		mi.mesh = tm
		var m := _mat_add(c[k].lerp(Color.WHITE, 0.2 if k == 0 else 0.0))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.global_position = pos + Vector3(0, 0.15 + 0.1 * k, 0)
		mi.scale = Vector3(0.3, 0.5, 0.3)
		var tw := mi.create_tween()
		tw.tween_interval(0.08 * k)
		tw.tween_property(mi, "scale", Vector3(raio, 0.25, raio), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(m, "albedo_color:a", 0.0, dur)
		tw.tween_callback(mi.queue_free)
	burst(parent, pos + Vector3(0, 0.2, 0), elem, raio * 0.25)


# chuva do elemento: projéteis caindo do céu em pontos da área (magias em área: meteoros, granizo, raios, flechas)
static func chuva(parent: Node, centro: Vector3, elem: String, raio := 4.0, qtd := 7, dur := 0.9) -> void:
	if not parent.is_inside_tree():
		return
	for i in qtd:
		var a := randf() * TAU
		var r := sqrt(randf()) * raio
		var alvo := centro + Vector3(cos(a) * r, 0.1, sin(a) * r)
		var de := alvo + Vector3(randf_range(-1.5, 1.5), 9.0 + randf() * 3.0, randf_range(-1.5, 1.5))
		var atraso := dur * float(i) / qtd
		parent.get_tree().create_timer(atraso).timeout.connect(func():
			if not is_instance_valid(parent):
				return
			if elem == "raio":
				relampago(parent, de, alvo, colors(elem)[0])
			else:
				magia(parent, de, alvo, elem, 0.22)
			parent.get_tree().create_timer(0.22).timeout.connect(func():
				if is_instance_valid(parent):
					burst(parent, alvo + Vector3(0, 0.2, 0), elem, 0.7)))


# espinhos que brotam do chão em volta do alvo e o prendem (gelo vira cristais, terra vira rocha, sombra vira garras)
static func espinhos(parent: Node, pos: Vector3, elem: String, raio := 1.1, qtd := 7, dur := 1.6) -> void:
	var c := colors(elem if elem != "" else "terra")
	var raiz := Node3D.new()
	parent.add_child(raiz)
	raiz.global_position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = c[1].darkened(0.1)
	m.emission_enabled = true
	m.emission = c[0]
	m.emission_energy_multiplier = 1.2
	m.metallic = 0.2
	m.roughness = 0.35
	for i in qtd:
		var a := TAU * float(i) / qtd + randf() * 0.3
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.16 + randf() * 0.08
		cm.height = 1.0 + randf() * 0.7
		cm.radial_segments = 5
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = m
		raiz.add_child(mi)
		mi.position = Vector3(cos(a) * raio, -cm.height * 0.5, sin(a) * raio)
		mi.rotation = Vector3(-sin(a) * 0.45, 0, cos(a) * 0.45)
		var tw := mi.create_tween()
		tw.tween_interval(0.03 * i)
		tw.tween_property(mi, "position:y", cm.height * 0.45, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst(parent, pos + Vector3(0, 0.3, 0), elem, 0.8)
	var t2 := raiz.create_tween()
	t2.tween_interval(dur)
	t2.tween_property(raiz, "scale", Vector3(1, 0.01, 1), 0.25)
	t2.tween_callback(raiz.queue_free)


# corte em X (crítico): duas meias-luas cruzadas e clarão
static func corte_x(dono: Node3D, cor: Color, raio := 1.7) -> void:
	corte(dono, cor.lerp(Color.WHITE, 0.35), raio, 1.15, 0.85, 0.22)
	dono.get_tree().create_timer(0.09).timeout.connect(func():
		if is_instance_valid(dono):
			corte(dono, cor, raio * 1.05, 1.15, -0.85, 0.22))
