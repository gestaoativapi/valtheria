extends Node3D
# Dragonita viva (decisão D5 de Robson, 18/11): asas de membrana que ficam dobradas nas costas,
# meio abertas e respirando no combate e totalmente abertas para planar; cauda que balança sozinha
# (mais forte no combate); sopro elemental saindo da boca. Tudo é visual no cliente; o dano do sopro
# depende do servidor (pendente, ver painel de decisões).

var char: Node3D
var skel: Skeleton3D
var estado := "dobrada"   # dobrada | combate | planar
var _abre := 0.0          # 0 dobrada .. 1 aberta
var _t := 0.0
var _asas: Array = []     # [raiz, lado]
var _cauda_mat: ShaderMaterial
var _cor := Color(0.3, 0.45, 0.32)
var _amp := 0.1

const CAUDA_SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap;
uniform bool tem_nrm = false;
uniform vec4 cor : source_color = vec4(1.0);
uniform float rough = 0.7;
uniform vec3 pivo = vec3(0.0, 0.95, -0.1);
uniform float amplitude = 0.12;
uniform float ritmo = 1.4;
void vertex() {
	// COLOR.r = quanto o vértice pertence à cauda (0 na base, 1 na ponta), medido no corpo de repouso
	float t = COLOR.r;
	if (t > 0.0) {
		float a = amplitude * sin(TIME * ritmo - t * 2.4) * t;
		vec3 p = VERTEX - pivo;
		float c = cos(a), s = sin(a);
		p = vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
		p.y += 0.04 * amplitude * 4.0 * sin(TIME * ritmo * 0.7 - t * 1.7) * t * t;
		VERTEX = p + pivo;
	}
}
void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb * cor.rgb;
	if (tem_nrm) { NORMAL_MAP = texture(nrm, UV).rgb; }
	ROUGHNESS = rough;
}
"""


func montar(c: Node3D, sk: Skeleton3D, cor_pele: Color) -> void:
	char = c
	skel = sk
	_cor = cor_pele
	_cauda()
	_criar_asas()


# ---------------------------------------------------------------- cauda
func _cauda() -> void:
	var corpo: MeshInstance3D = null
	for m in skel.find_children("*", "MeshInstance3D", true, false):
		corpo = m
		break
	if corpo == null:
		return
	var pel := skel.get_bone_global_rest(skel.find_bone("pelvis")).origin
	var src := corpo.mesh
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var a := src.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var cols := PackedColorArray()
		cols.resize(v.size())
		for i in v.size():
			var atras := pel.z - 0.1 - v[i].z
			var t := clampf(atras / 0.75, 0.0, 1.0) * (1.0 - smoothstep(pel.y + 0.15, pel.y + 0.35, v[i].y))
			cols[i] = Color(t * t * (3.0 - 2.0 * t), 0, 0)
		a[Mesh.ARRAY_COLOR] = cols
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		var base := corpo.get_surface_override_material(s)
		if base == null:
			base = src.surface_get_material(s)
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = CAUDA_SHADER
		sm.shader = sh
		if base is StandardMaterial3D:
			var b := base as StandardMaterial3D
			sm.set_shader_parameter("tex", b.albedo_texture)
			sm.set_shader_parameter("cor", b.albedo_color)
			sm.set_shader_parameter("rough", b.roughness)
			if b.normal_enabled and b.normal_texture:
				sm.set_shader_parameter("nrm", b.normal_texture)
				sm.set_shader_parameter("tem_nrm", true)
		sm.set_shader_parameter("pivo", pel + Vector3(0, 0, -0.1))
		out.surface_set_material(s, sm)
		_cauda_mat = sm
	corpo.mesh = out
	for s in out.get_surface_count():
		corpo.set_surface_override_material(s, null)


# ---------------------------------------------------------------- asas
func _malha_asa(cor: Color) -> ArrayMesh:
	# asa aberta no espaço local: raiz na origem, abre para +X, ponta levemente para cima e para trás.
	# braço (úmero + antebraço) e 3 dedos longos; a membrana liga os dedos entre si e ao corpo.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cotovelo := Vector3(0.38, 0.12, -0.05)
	var pulso := Vector3(0.78, 0.22, 0.02)
	var dedos := [Vector3(1.45, 0.34, -0.1), Vector3(1.3, 0.05, -0.38), Vector3(0.98, -0.2, -0.55)]
	var corpo_pts := [Vector3(0.02, 0.0, -0.05), Vector3(0.04, -0.35, -0.12)]
	var memb := Color(cor.r * cor.r, cor.g * cor.g, cor.b * cor.b).darkened(0.2).lerp(Color(0.35, 0.16, 0.1), 0.3)
	var osso := Color(cor.r * cor.r, cor.g * cor.g, cor.b * cor.b).darkened(0.45)
	# membrana: leque de triângulos entre pulso, pontas dos dedos e raiz
	var anel := [cotovelo, dedos[0], dedos[1], dedos[2], corpo_pts[1]]
	for i in anel.size() - 1:
		var a: Vector3 = anel[i]
		var b: Vector3 = anel[i + 1]
		# borda entre dedos levemente recortada (curva para dentro)
		var meio := (a + b) * 0.5
		var centro: Vector3 = pulso if i < 3 else corpo_pts[0]
		meio = meio.lerp(centro, 0.18 if i in [1, 2] else 0.05)
		for tri in [[centro, a, meio], [centro, meio, b]]:
			for p in tri:
				st.set_color(memb)
				st.add_vertex(p)
	# membrana interna entre cotovelo, pulso e corpo
	for tri in [[corpo_pts[0], cotovelo, pulso], [corpo_pts[0], pulso, corpo_pts[1]]]:
		for p in tri:
			st.set_color(memb)
			st.add_vertex(p)
	# ossos: caixas finas ao longo do braço e dos dedos
	var segs := [[Vector3.ZERO, cotovelo, 0.035], [cotovelo, pulso, 0.028]]
	for d in dedos:
		segs.append([pulso, d, 0.016])
	for sg in segs:
		var a: Vector3 = sg[0]
		var b: Vector3 = sg[1]
		var r: float = sg[2]
		var dir := (b - a).normalized()
		var u := dir.cross(Vector3.UP).normalized() * r
		var w := dir.cross(u).normalized() * r
		var cs := [a + u, a + w, a - u, a - w]
		var ce := [b + u * 0.6, b + w * 0.6, b - u * 0.6, b - w * 0.6]
		for k in 4:
			var k2 := (k + 1) % 4
			for p in [cs[k], ce[k], cs[k2], cs[k2], ce[k], ce[k2]]:
				st.set_color(osso)
				st.add_vertex(p)
	# garra no pulso
	for p in [pulso + Vector3(0, 0.03, 0), pulso + Vector3(0.02, 0.12, 0.04), pulso + Vector3(-0.02, 0.03, 0.03)]:
		st.set_color(osso.darkened(0.3))
		st.add_vertex(p)
	st.generate_normals()
	return st.commit()


func _criar_asas() -> void:
	var b3 := skel.find_bone("spine_03")
	if b3 < 0:
		return
	var rest := skel.get_bone_global_rest(b3)
	var att := BoneAttachment3D.new()
	att.bone_name = "spine_03"
	att.name = "AsasDragonita"
	skel.add_child(att)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.75
	# luz atravessando a membrana: um pouco mais clara contra o sol
	mat.backlight_enabled = true
	mat.backlight = Color(0.35, 0.18, 0.1)
	var mesh := _malha_asa(_cor)
	var k: float = 1.0
	for lado in [1.0, -1.0]:
		var raiz := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.scale = Vector3(lado * k, k, k)   # espelha a asa da direita
		raiz.add_child(mi)
		# raiz entre as escápulas, um pouco atrás do tronco (repouso -> espaço do osso)
		raiz.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin + Vector3(lado * 0.09, 0.02, -0.16))
		att.add_child(raiz)
		_asas.append([raiz, lado, raiz.transform, mi])


func _process(dt: float) -> void:
	_t += dt
	var alvo := 0.0
	match estado:
		"combate":
			alvo = 0.55
		"planar":
			alvo = 1.0
	_abre = move_toward(_abre, alvo, dt * 1.6)
	for a in _asas:
		var raiz: Node3D = a[0]
		var lado: float = a[1]
		var base: Transform3D = a[2]
		var mi: MeshInstance3D = a[3]
		# dobrada: asa recolhida para baixo e para trás, fechada como leque
		var bate := 0.0
		if estado == "combate":
			bate = sin(_t * 1.6) * 0.08
		elif estado == "planar":
			bate = sin(_t * 0.9) * 0.05
		var giro_z := lerpf(-1.25, 0.12 + bate, _abre) * lado
		var giro_y := lerpf(-0.95, -0.25, _abre) * lado
		var giro_x := lerpf(0.35, 0.0, _abre)
		raiz.transform = base * Transform3D(Basis.from_euler(Vector3(giro_x, giro_y, giro_z)), Vector3.ZERO)
		mi.scale = Vector3(lado * lerpf(0.42, 1.0, _abre), lerpf(0.75, 1.0, _abre), 1.0)
	if _cauda_mat:
		var forte := 0.22 if estado == "combate" else 0.1
		var ritmo := 2.6 if estado == "combate" else 1.3
		_amp = lerpf(_amp, forte, dt * 2.0)
		_cauda_mat.set_shader_parameter("amplitude", _amp)
		_cauda_mat.set_shader_parameter("ritmo", ritmo)


# ---------------------------------------------------------------- sopro elemental
const ELEMENTO_COR := {"fogo": [Color(1.0, 0.75, 0.3), Color(0.9, 0.25, 0.05)], "gelo": [Color(0.85, 0.95, 1.0), Color(0.4, 0.7, 1.0)],
	"raio": [Color(1.0, 1.0, 0.85), Color(0.5, 0.6, 1.0)], "veneno": [Color(0.75, 1.0, 0.5), Color(0.3, 0.6, 0.15)]}


func sopro(elemento := "fogo") -> void:
	var hb := skel.find_bone("Head")
	if hb < 0:
		return
	var rest := skel.get_bone_global_rest(hb)
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	skel.add_child(att)
	var cores: Array = ELEMENTO_COR.get(elemento, ELEMENTO_COR.fogo)
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 0.7
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -0.25, 1).normalized()
	pm.spread = 14.0
	pm.initial_velocity_min = 7.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0, 0.6, 0)
	pm.damping_min = 4.0
	pm.damping_max = 6.0
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.3))
	sc.add_point(Vector2(0.4, 1.0))
	sc.add_point(Vector2(1, 1.8))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(cores[0], 1.0))
	g.set_color(1, Color(cores[1], 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	m.albedo_texture = ImageTexture.create_from_image(img)
	q.material = m
	p.draw_pass_1 = q
	# boca: à frente e abaixo dos olhos, apontando para frente
	p.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin + Vector3(0, -0.02, 0.2))
	att.add_child(p)
	p.emitting = true
	# sem luz dinâmica (criar luz em jogo recompila shaders e trava): o brilho vem das partículas aditivas
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_callback(func(): p.emitting = false)
	tw.tween_interval(1.0)
	tw.tween_callback(att.queue_free)
