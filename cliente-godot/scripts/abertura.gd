extends CanvasLayer
# Tela de abertura: cena 3D própria (mundo separado do jogo) com os elementos centrais da história:
# a Árvore dos Mil Mundos sobre a ilha do tronco, o coração de luz com runas, os mundos-fruto em órbita,
# as duas luas (Lúmen de prata e Nyx de ônix) em eclipse, os seis fragmentos da Coroa Celeste girando
# em volta do tronco e o Véu, a casca de luz que protege o mundo, com uma Fenda aberta.
# Tudo procedural e leve (sem modelos pesados), e o mundo do jogo não é desenhado enquanto ela aparece.

const Especial := preload("res://scripts/especial.gd")

var vp: SubViewport
var cont: SubViewportContainer
var cam: Camera3D
var raiz: Node3D
var _orbitas: Array = []   # [nó, raio, velocidade, altura, fase, inclinação]
var _frags: Array = []
var _t := 0.0
var _ceu: ShaderMaterial

const CEU := """
shader_type sky;
uniform float eclipse = 0.72;
uniform vec3 dir_lua = vec3(-0.35, 0.42, -1.0);
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float estrelas(vec3 d, float esc){
	vec2 uv = vec2(atan(d.x, d.z), asin(clamp(d.y, -1.0, 1.0))) * esc;
	vec2 c = floor(uv); vec2 f = fract(uv) - 0.5;
	float r = h(c);
	float brilho = step(0.965, r) * smoothstep(0.09, 0.0, length(f - (vec2(h(c + 3.1), h(c + 7.7)) - 0.5) * 0.6));
	return brilho * (0.6 + 0.4 * sin(TIME * (1.0 + r * 3.0) + r * 40.0));
}
void sky(){
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 baixo = vec3(0.10, 0.07, 0.16);
	vec3 meio = vec3(0.07, 0.07, 0.20);
	vec3 alto = vec3(0.012, 0.016, 0.05);
	vec3 c = mix(baixo, meio, smoothstep(-0.15, 0.18, y));
	c = mix(c, alto, smoothstep(0.18, 0.8, y));
	// faixa de névoa estelar (os mil mundos vistos através do Véu)
	float faixa = exp(-pow((d.y - 0.35 * d.x - 0.18) * 4.0, 2.0));
	c += vec3(0.20, 0.12, 0.30) * faixa * 0.35;
	c += vec3(1.0, 0.95, 0.85) * (estrelas(d, 90.0) + estrelas(d, 160.0) * 0.7) * smoothstep(-0.05, 0.2, y);
	// Lúmen (prata) e Nyx (ônix) em eclipse
	vec3 dl = normalize(dir_lua);
	vec3 dn = normalize(dl + vec3(0.045, 0.018, 0.0) * (1.0 - eclipse) * 3.0 + vec3(0.03, 0.012, 0.0));
	float al = acos(clamp(dot(d, dl), -1.0, 1.0));
	float an = acos(clamp(dot(d, dn), -1.0, 1.0));
	float rl = 0.045;
	float disco = smoothstep(rl, rl - 0.004, al);
	float sombra = smoothstep(rl * 0.97, rl * 0.97 - 0.004, an);
	vec3 lua = mix(vec3(0.85, 0.9, 1.0), vec3(0.62, 0.68, 0.82), smoothstep(0.0, rl, al));
	c += vec3(0.55, 0.65, 1.0) * exp(-al * 9.0) * 0.55;          // halo de Lúmen
	c += vec3(0.55, 0.35, 0.95) * exp(-an * 5.0) * 0.12;          // brilho violeta de Nyx
	c = mix(c, lua, disco);
	c = mix(c, vec3(0.012, 0.012, 0.03), sombra * disco + sombra * 0.92 * (1.0 - disco));
	float coroa = smoothstep(rl * 1.25, rl * 0.97, an) * (1.0 - sombra) * 0.35;
	c += vec3(0.7, 0.6, 1.0) * coroa;
	COLOR = c;
}
"""

const VEU := """
shader_type spatial;
render_mode blend_add, unshaded, cull_front, depth_draw_never, fog_disabled;
void fragment(){
	float fr = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	float ondas = 0.5 + 0.5 * sin(UV.y * 60.0 + TIME * 1.2 + sin(UV.x * 30.0 + TIME) * 2.0);
	ALBEDO = vec3(0.45, 0.55, 1.0) * fr * (0.35 + 0.25 * ondas);
}
"""

const FENDA := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;
void fragment(){
	vec2 p = UV * 2.0 - 1.0;
	float zig = sin(p.y * 9.0 + sin(p.y * 23.0) * 0.6) * 0.12 * (1.0 - abs(p.y));
	float d = abs(p.x - zig);
	float corte = smoothstep(0.05 + 0.05 * (1.0 - abs(p.y)), 0.0, d) * (1.0 - smoothstep(0.75, 1.0, abs(p.y)));
	float halo = exp(-d * 6.0) * (1.0 - abs(p.y)) * 0.35;
	ALBEDO = (vec3(0.85, 0.5, 1.0) * corte * (0.8 + 0.2 * sin(TIME * 5.0)) + vec3(0.45, 0.25, 0.8) * halo);
}
"""

const COPA := """
shader_type spatial;
render_mode cull_back;
uniform vec3 cor : source_color = vec3(0.32, 0.55, 0.32);
void vertex(){
	float n = sin(VERTEX.x * 3.1 + TIME * 0.6) * sin(VERTEX.y * 2.7) * sin(VERTEX.z * 3.4 + TIME * 0.4);
	VERTEX += NORMAL * n * 0.18;
}
void fragment(){
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = cor * 0.55;
	ROUGHNESS = 0.9;
	EMISSION = mix(cor, vec3(1.0, 0.85, 0.45), 0.55) * fr * 1.2;
}
"""


func _ready() -> void:
	layer = 0
	cont = SubViewportContainer.new()
	cont.stretch = true
	cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cont)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	cont.add_child(vp)
	raiz = Node3D.new()
	vp.add_child(raiz)
	_ambiente()
	_ilha()
	_arvore()
	_mundos()
	_fragmentos()
	_veu()
	_particulas()
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.current = true
	raiz.add_child(cam)


func _ambiente() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CEU
	sm.shader = sh
	sky.sky_material = sm
	_ceu = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.28, 0.27, 0.42)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var lua := DirectionalLight3D.new()  # luz fria de Lúmen
	lua.light_color = Color(0.7, 0.78, 1.0)
	lua.light_energy = 0.8
	lua.rotation = Vector3(deg_to_rad(-35), deg_to_rad(-160), 0)
	raiz.add_child(lua)


func _mat(c: Color, rough := 0.9, emis := Color.BLACK, e := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if e > 0.0:
		m.emission_enabled = true
		m.emission = emis
		m.emission_energy_multiplier = e
	return m


func _ilha() -> void:
	var rocha := _mat(Color(0.23, 0.21, 0.24))
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 7.0
	cm.bottom_radius = 0.6
	cm.height = 7.0
	cm.radial_segments = 14
	cm.rings = 3
	cm.material = rocha
	base.mesh = cm
	base.position = Vector3(0, -3.6, 0)
	raiz.add_child(base)
	var topo := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 7.05
	tm.bottom_radius = 7.05
	tm.height = 0.35
	tm.radial_segments = 28
	tm.material = _mat(Color(0.2, 0.32, 0.2))
	topo.mesh = tm
	raiz.add_child(topo)
	# rochas soltas flutuando em volta
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 9:
		var pedra := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = r.randf_range(0.3, 0.9)
		sm.height = sm.radius * 1.4
		sm.radial_segments = 6
		sm.rings = 3
		sm.material = rocha
		pedra.mesh = sm
		raiz.add_child(pedra)
		_orbitas.append([pedra, r.randf_range(9.0, 14.0), r.randf_range(0.03, 0.07), r.randf_range(-4.0, 1.0), r.randf() * TAU, 0.0])


func _arvore() -> void:
	var casca := _mat(Color(0.34, 0.25, 0.18), 0.85)
	var r := RandomNumberGenerator.new()
	r.seed = 11
	# tronco torcido
	var pts: Array = []
	var raios: Array = []
	for i in 12:
		var t := i / 11.0
		pts.append(Vector3(sin(t * 4.0) * 0.5, t * 8.5, cos(t * 3.0) * 0.4 - 0.2))
		raios.append(lerpf(1.5, 0.65, t))
	var tronco := MeshInstance3D.new()
	tronco.mesh = Especial._tubo(pts, raios, 12, casca, 0.15)
	raiz.add_child(tronco)
	# raízes que descem pela ilha
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var rp: Array = []
		var rr: Array = []
		for i in 7:
			var t := i / 6.0
			rp.append(Vector3(cos(a) * (0.8 + t * 5.5), 0.5 - t * 0.6 - t * t * 2.5, sin(a) * (0.8 + t * 5.5)))
			rr.append(lerpf(0.55, 0.08, t))
		var m := MeshInstance3D.new()
		m.mesh = Especial._tubo(rp, rr, 7, casca, 0.2)
		raiz.add_child(m)
	# galhos e copa
	var topo: Vector3 = pts[pts.size() - 1]
	var verdes := [Color(0.42, 0.72, 0.42), Color(0.55, 0.74, 0.36), Color(0.36, 0.64, 0.55)]
	for k in 6:
		var a := TAU * k / 6.0 + r.randf() * 0.4
		var fim := topo + Vector3(cos(a) * 4.2, r.randf_range(1.2, 3.0), sin(a) * 4.2)
		var gp: Array = []
		var gr: Array = []
		for i in 6:
			var t := i / 5.0
			gp.append(topo.lerp(fim, t) + Vector3(0, sin(t * PI) * 1.0, 0))
			gr.append(lerpf(0.55, 0.12, t))
		var g := MeshInstance3D.new()
		g.mesh = Especial._tubo(gp, gr, 7, casca, 0.2)
		raiz.add_child(g)
		var copa := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = r.randf_range(2.0, 2.8)
		sp.height = sp.radius * 1.5
		sp.radial_segments = 16
		sp.rings = 8
		var cm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = COPA
		cm.shader = sh
		cm.set_shader_parameter("cor", verdes[k % verdes.size()])
		sp.material = cm
		copa.mesh = sp
		copa.position = fim + Vector3(0, 0.6, 0)
		raiz.add_child(copa)
	var central := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 3.4
	cs.height = 4.6
	cs.radial_segments = 18
	cs.rings = 9
	var cmat := ShaderMaterial.new()
	var csh := Shader.new()
	csh.code = COPA
	cmat.shader = csh
	cmat.set_shader_parameter("cor", Color(0.42, 0.62, 0.35))
	cs.material = cmat
	central.mesh = cs
	central.position = topo + Vector3(0, 2.4, 0)
	raiz.add_child(central)
	# coração de luz com runas, no meio do tronco
	var coracao := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.55
	hs.height = 1.1
	hs.material = _mat(Color(1, 0.9, 0.6), 0.3, Color(1.0, 0.82, 0.45), 6.0)
	coracao.mesh = hs
	coracao.position = Vector3(0.15, 3.2, 1.0)
	raiz.add_child(coracao)
	var anel := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.85
	tor.outer_radius = 0.95
	tor.material = _mat(Color(1, 0.85, 0.5), 0.3, Color(1.0, 0.75, 0.35), 4.0)
	anel.mesh = tor
	anel.position = coracao.position
	anel.rotation.x = PI * 0.5
	anel.name = "AnelRunas"
	raiz.add_child(anel)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.78, 0.45)
	luz.light_energy = 3.0
	luz.omni_range = 11.0
	luz.position = coracao.position + Vector3(0, 0, 0.6)
	raiz.add_child(luz)


func _mundos() -> void:
	# os mundos-fruto da Árvore, cada um com seu anel
	var cores := [Color(0.5, 0.85, 0.76), Color(0.79, 0.63, 1.0), Color(1.0, 0.69, 0.44), Color(0.56, 0.77, 1.0), Color(0.95, 0.9, 0.66), Color(1.0, 0.56, 0.66), Color(0.6, 1.0, 0.6)]
	for i in cores.size():
		var n := Node3D.new()
		var sp := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.35 + 0.1 * (i % 3)
		s.height = s.radius * 2.0
		s.radial_segments = 14
		s.rings = 7
		s.material = _mat(cores[i], 0.6, cores[i], 1.6)
		sp.mesh = s
		n.add_child(sp)
		var an := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = s.radius * 1.35
		t.outer_radius = s.radius * 1.55
		t.material = _mat(cores[i], 0.5, cores[i], 1.0)
		an.mesh = t
		an.rotation = Vector3(0.4, 0, 0.3)
		n.add_child(an)
		raiz.add_child(n)
		_orbitas.append([n, 6.5 + i * 0.7, 0.12 - i * 0.008, 10.5 + (i % 3) * 1.4, TAU * i / cores.size(), 0.25])


func _fragmentos() -> void:
	# os seis fragmentos da Coroa Celeste
	for i in 6:
		var f := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.35, 0.8, 0.35)
		pm.material = _mat(Color(0.75, 0.88, 1.0), 0.15, Color(0.55, 0.78, 1.0), 3.0)
		f.mesh = pm
		raiz.add_child(f)
		_frags.append([f, TAU * i / 6.0])


func _veu() -> void:
	var v := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 24.0
	s.height = 48.0
	s.radial_segments = 32
	s.rings = 16
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VEU
	m.shader = sh
	s.material = m
	v.mesh = s
	v.position = Vector3(0, 5, 0)
	raiz.add_child(v)
	var f := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(5.0, 14.0)
	var fm := ShaderMaterial.new()
	var fsh := Shader.new()
	fsh.code = FENDA
	fm.shader = fsh
	q.material = fm
	f.mesh = q
	f.position = Vector3(-14.0, 9.0, -17.0)
	f.rotation = Vector3(0.1, 0.55, 0.25)
	raiz.add_child(f)


func _particulas() -> void:
	var p := CPUParticles3D.new()
	p.amount = 90
	p.lifetime = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 9.0
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 0.12, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.35
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.07
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.82, 0.45, 0.55)
	var g := Gradient.new()  # ponto de luz macio (sem quadrado)
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	m.albedo_texture = gt
	q.material = m
	p.mesh = q
	p.position = Vector3(0, 6, 0)
	raiz.add_child(p)


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	var a := _t * 0.045 + 0.6
	cam.position = Vector3(sin(a) * 31.0, 7.0 + sin(_t * 0.2) * 1.0, cos(a) * 31.0)
	cam.look_at(Vector3(0, 9.5, 0))
	cam.h_offset = 5.0  # a Árvore um pouco à esquerda; o painel de entrada fica à direita
	# as duas luas sempre no céu visível, no alto à direita, com o eclipse avançando e recuando devagar
	var b := cam.global_transform.basis
	_ceu.set_shader_parameter("dir_lua", (-b.z + b.x * 0.42 + Vector3.UP * 0.30).normalized())
	_ceu.set_shader_parameter("eclipse", 0.62 + 0.3 * sin(_t * 0.07))
	for o in _orbitas:
		var n: Node3D = o[0]
		var ang: float = o[4] + _t * float(o[2])
		var rr: float = o[1]
		n.position = Vector3(cos(ang) * rr, float(o[3]) + sin(ang * 2.0) * float(o[5]) * 2.0, sin(ang) * rr)
		n.rotation.y += dt * 0.4
	for f in _frags:
		var m: MeshInstance3D = f[0]
		var ang: float = f[1] + _t * 0.25
		m.position = Vector3(cos(ang) * 3.0, 4.6 + sin(_t * 1.3 + f[1]) * 0.25, sin(ang) * 3.0)
		m.rotation.y = -ang
	var an := raiz.get_node_or_null("AnelRunas")
	if an:
		an.rotation.z += dt * 0.6


func mostrar(on: bool) -> void:
	visible = on
	cont.visible = on
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
