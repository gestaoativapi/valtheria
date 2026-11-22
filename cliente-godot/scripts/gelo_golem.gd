class_name GeloGolem
extends RefCounted
# Gigante de Gelo (pedido de Robson 21/11, revisto na mesma noite): corpo inteiro de golem de gelo
# com rosto humanizado. Ombros, antebraços e punhos maciços, peito e costas em placas, pernas de pedra de gelo.
# Cada pedaço é uma rocha de gelo facetada (icosfera deformada com faces planas), presa ao osso por
# BoneAttachment3D: acompanha as 28 animações sem alterar o esqueleto. O rosto do gigante fica à mostra,
# emoldurado por uma testa de gelo e uma coroa de cristais.

static var _mat_gelo: StandardMaterial3D
static var _mat_geada: StandardMaterial3D
static var _mat_nucleo: StandardMaterial3D
static var _rochas: Array = []

const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform sampler2D pele_tex : source_color, filter_linear_mipmap;
uniform vec4 pele_cor : source_color = vec4(1.0);
uniform bool usa_pele = false;
uniform vec4 gelo_fundo : source_color = vec4(0.08, 0.24, 0.42, 1.0);
uniform vec4 gelo_claro : source_color = vec4(0.72, 0.88, 0.97, 1.0);
uniform float facetas = 14.0;
varying float rosto;

vec3 h3(vec2 p) {
	vec3 q = vec3(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)), dot(p, vec2(419.2, 371.9)));
	return fract(sin(q) * 43758.5453);
}

void vertex() {
	rosto = COLOR.r;
}

void fragment() {
	// facetas de Voronoi na UV: placas irregulares de gelo com trincas finas entre elas (nada de grade)
	vec2 g = UV * facetas;
	vec2 ib = floor(g);
	float d1 = 9.0;
	float d2 = 9.0;
	vec2 cel = ib;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = ib + vec2(float(x), float(y));
			vec2 pt = o + h3(o).xy;
			float d = length(g - pt);
			if (d < d1) { d2 = d1; d1 = d; cel = o; } else if (d < d2) { d2 = d; }
		}
	}
	vec3 r = h3(cel + 17.0);
	float borda = smoothstep(0.02, 0.09, d2 - d1);
	vec3 gelo = mix(gelo_fundo.rgb, gelo_claro.rgb, 0.2 + 0.75 * r.x * r.x);
	gelo = mix(vec3(0.86, 0.95, 1.0), gelo, 0.55 + 0.45 * borda);
	vec3 n = normalize(NORMAL + (r - 0.5) * 0.9 * (1.0 - rosto));
	vec3 pele = usa_pele ? texture(pele_tex, UV).rgb * pele_cor.rgb : gelo;
	float k = smoothstep(0.35, 0.75, rosto);
	ALBEDO = mix(gelo, pele, k);
	NORMAL = mix(n, NORMAL, k);
	ROUGHNESS = mix(0.12 + 0.25 * r.y, 0.6, k);
	SPECULAR = mix(0.85, 0.4, k);
	RIM = 0.6 * (1.0 - k);
	RIM_TINT = 0.5;
	EMISSION = gelo_fundo.rgb * 0.35 * (1.0 - k) * (0.5 + r.z);
}
"""
static var _shader: Shader


static func _mat_corpo(pele: BaseMaterial3D) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	if pele != null and pele.albedo_texture != null:
		m.set_shader_parameter("pele_tex", pele.albedo_texture)
		m.set_shader_parameter("pele_cor", pele.albedo_color)
		m.set_shader_parameter("usa_pele", true)
	return m


# ossos da cabeça (Head e filhos) pesam 1; o pescoço pesa meio: transição suave entre rosto e gelo
static func _peso_cabeca(skel: Skeleton3D) -> Dictionary:
	var out := {}
	var h := skel.find_bone("Head")
	for i in skel.get_bone_count():
		var j := i
		while j >= 0 and j != h:
			j = skel.get_bone_parent(j)
		if j == h and h >= 0:
			out[i] = 1.0
	var n := skel.find_bone("neck_01")
	if n >= 0:
		out[n] = 0.45
	return out


# copia a malha do corpo gravando na cor do vértice (R) quanto ele pertence à cabeça: 1 no rosto, 0 no resto.
# Serve para shaders que trocam o corpo (gelo, lava) e precisam deixar o rosto à mostra.
static func marcar_cabeca(skel: Skeleton3D, mi: MeshInstance3D, pesos := {}) -> ArrayMesh:
	if pesos.is_empty():
		pesos = _peso_cabeca(skel)
	var orig := mi.mesh as ArrayMesh
	if orig == null:
		return null
	var novo := ArrayMesh.new()
	for si in orig.get_surface_count():
		var arr := orig.surface_get_arrays(si)
		var fmt := orig.surface_get_format(si)
		var ossos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var nv: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var por := 8 if (fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0 else 4
		var cores := PackedColorArray()
		cores.resize(nv)
		for vi in nv:
			var f := 0.0
			for k in por:
				var bi: int = ossos[vi * por + k]
				if mi.skin != null and bi < mi.skin.get_bind_count():
					var bb := mi.skin.get_bind_bone(bi)
					bi = bb if bb >= 0 else skel.find_bone(mi.skin.get_bind_name(bi))
				f += float(pesos.get(bi, 0.0)) * w[vi * por + k]
			cores[vi] = Color(f, f, f)
		arr[Mesh.ARRAY_COLOR] = cores
		novo.add_surface_from_arrays(orig.surface_get_primitive_type(si), arr, [], {}, fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		novo.surface_set_material(si, orig.surface_get_material(si))
	return novo


# corpo de carne vira gelo, menos o rosto; roupas viram gelo inteiras (a silhueta do equipamento continua)
static func _congelar_corpo(skel: Skeleton3D) -> void:
	var pesos := _peso_cabeca(skel)
	for ch in skel.get_children():
		if not (ch is MeshInstance3D):
			continue
		var mi := ch as MeshInstance3D
		var nome := String(mi.name).to_lower()
		if nome in ["olhos", "sobrancelha", "cilios", "cabelo"] or nome.begins_with("ca_") or nome.contains("hair") or nome.contains("eye"):
			continue
		if nome != "corpo":
			mi.material_override = _mat_corpo(null)
			continue
		var novo := marcar_cabeca(skel, mi, pesos)
		if novo == null:
			continue
		for si in novo.get_surface_count():
			novo.surface_set_material(si, _mat_corpo(mi.get_active_material(si) as BaseMaterial3D))
		mi.mesh = novo
		for si in novo.get_surface_count():
			mi.set_surface_override_material(si, null)
		mi.material_override = null



static func materiais() -> Array:
	if _mat_gelo == null:
		_mat_gelo = StandardMaterial3D.new()
		_mat_gelo.albedo_color = Color(0.62, 0.8, 0.92)
		_mat_gelo.vertex_color_use_as_albedo = true
		_mat_gelo.roughness = 0.18
		_mat_gelo.metallic_specular = 0.85
		_mat_gelo.rim_enabled = true
		_mat_gelo.rim = 0.6
		_mat_gelo.rim_tint = 0.4
		_mat_gelo.emission_enabled = true
		_mat_gelo.emission = Color(0.12, 0.32, 0.5)
		_mat_gelo.emission_energy_multiplier = 0.25
		_mat_geada = _mat_gelo.duplicate()
		_mat_geada.albedo_color = Color(0.9, 0.96, 1.0)
		_mat_geada.roughness = 0.55
		_mat_geada.emission_energy_multiplier = 0.1
		_mat_nucleo = StandardMaterial3D.new()
		_mat_nucleo.albedo_color = Color(0.82, 0.95, 1.0)
		_mat_nucleo.emission_enabled = true
		_mat_nucleo.emission = Color(0.5, 0.85, 1.0)
		_mat_nucleo.emission_energy_multiplier = 2.4
		_mat_nucleo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return [_mat_gelo, _mat_geada, _mat_nucleo]


# rocha de gelo: icosfera (raio 1) com vértices empurrados ao acaso e faces planas; topo mais claro (geada)
static func _rocha(semente: int) -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	# só a icosfera base (20 faces grandes): fica angulosa como gelo partido, não redonda
	var f2 := f
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var p := []
	for q in v:
		var n: Vector3 = (q as Vector3).normalized()
		# lascas: alguns vértices afundam bastante (faces grandes e planas, como gelo partido)
		var r := 1.0 + rng.randf_range(-0.22, 0.18)
		p.append(n * r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in f2:
		var a: Vector3 = p[tri[0]]
		var b: Vector3 = p[tri[1]]
		var c: Vector3 = p[tri[2]]
		var nrm := (b - a).cross(c - a).normalized()
		if nrm.dot(a + b + c) < 0.0:
			var tmp := b
			b = c
			c = tmp
			nrm = -nrm
		# faces viradas para cima pegam geada; as de baixo ficam azul profundo
		var claro := clampf(0.72 + 0.28 * nrm.y + rng.randf_range(-0.06, 0.06), 0.5, 1.05)
		var cor := Color(claro * 0.92, claro * 0.98, minf(claro * 1.05, 1.0))
		st.set_smooth_group(-1)
		for q in [a, c, b]:
			st.set_color(cor)
			st.set_normal(nrm)
			st.add_vertex(q)
	return st.commit()


static func _rocha_n(i: int) -> ArrayMesh:
	if _rochas.is_empty():
		for k in 6:
			_rochas.append(_rocha(7001 + k * 131))
	return _rochas[posmod(i, _rochas.size())]


static func _anexo(skel: Skeleton3D, osso: String) -> BoneAttachment3D:
	var nome := "Gelo_" + osso
	var ja := skel.get_node_or_null(nome)
	if ja != null:
		return ja as BoneAttachment3D
	var att := BoneAttachment3D.new()
	att.bone_name = osso
	att.name = nome
	skel.add_child(att)
	return att


# põe uma rocha (ou outra malha) no espaço de repouso do esqueleto, presa ao osso
static func _peca(skel: Skeleton3D, osso: String, mesh: Mesh, mat: Material, pos: Vector3, eixo: Vector3, escala: Vector3, giro := 0.0) -> void:
	var i := skel.find_bone(osso)
	if i < 0:
		return
	var d := eixo.normalized()
	var ex := Vector3.UP.cross(d)
	var b := Basis(ex.normalized(), Vector3.UP.angle_to(d)) if ex.length() > 0.001 else (Basis.IDENTITY if d.y > 0.0 else Basis(Vector3.RIGHT, PI))
	b = b * Basis(Vector3.UP, giro) * Basis.from_scale(escala)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.extra_cull_margin = 1.0
	_anexo(skel, osso).add_child(mi)
	mi.transform = skel.get_bone_global_rest(i).affine_inverse() * Transform3D(b, pos)


static func _pos(skel: Skeleton3D, osso: String) -> Vector3:
	var i := skel.find_bone(osso)
	return skel.get_bone_global_rest(i).origin if i >= 0 else Vector3.ZERO


# reveste o trecho osso->filho com n rochas alongadas; r0/r1 = grossura no começo e no fim
static func _membro(skel: Skeleton3D, osso: String, filho: String, r0: float, r1: float, n: int, rng: RandomNumberGenerator) -> void:
	if skel.find_bone(osso) < 0 or skel.find_bone(filho) < 0:
		return
	var p0 := _pos(skel, osso)
	var p1 := _pos(skel, filho)
	var d := p1 - p0
	var mats := materiais()
	for k in n:
		var t := (k + 0.5) / n
		var r := lerpf(r0, r1, t)
		var lasca := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * r * 0.15
		var comp := d.length() / n * 0.7
		_peca(skel, osso, _rocha_n(rng.randi()), mats[0], p0 + d * t + lasca, d, Vector3(r, comp, r * 0.92), rng.randf() * TAU)


static func montar(skel: Skeleton3D) -> void:
	_congelar_corpo(skel)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var mats := materiais()
	for s in [["_l", 1.0], ["_r", -1.0]]:
		var ld: String = s[0]
		var sx: float = s[1]   # +X é o lado esquerdo do corpo
		# ombro: dois blocos maciços empilhados, maiores que a cabeça
		var po := _pos(skel, "upperarm" + ld)
		_peca(skel, "clavicle" + ld, _rocha_n(1 + int(sx)), mats[0], po + Vector3(0.02 * sx, 0.07, -0.01), Vector3(0.5 * sx, 1, 0), Vector3(0.14, 0.1, 0.13), 0.4)
		_peca(skel, "upperarm" + ld, _rocha_n(3), mats[1], po + Vector3(0.09 * sx, 0.11, -0.03), Vector3(0.7 * sx, 1, -0.2), Vector3(0.07, 0.09, 0.06), 1.1)
		# braço, antebraço grosso perto do punho e o punho de gelo
		_membro(skel, "upperarm" + ld, "lowerarm" + ld, 0.07, 0.065, 1, rng)
		_membro(skel, "lowerarm" + ld, "hand" + ld, 0.08, 0.11, 2, rng)
		var ph := _pos(skel, "hand" + ld)
		var pm := _pos(skel, "middle_01" + ld)
		if pm == Vector3.ZERO:
			pm = ph + (ph - _pos(skel, "lowerarm" + ld)).normalized() * 0.1
		_peca(skel, "hand" + ld, _rocha_n(4), mats[0], ph.lerp(pm, 0.55), pm - ph, Vector3(0.11, 0.095, 0.095), 0.3)
		# perna: coxa e canela em rocha, pé em laje
		_membro(skel, "thigh" + ld, "calf" + ld, 0.095, 0.08, 1, rng)
		_membro(skel, "calf" + ld, "foot" + ld, 0.075, 0.085, 1, rng)
		var pf := _pos(skel, "foot" + ld)
		_peca(skel, "foot" + ld, _rocha_n(5), mats[0], pf + Vector3(0, -0.005, 0.08), Vector3(0, 0.25, 1), Vector3(0.07, 0.12, 0.05), 0.0)
		# peito em duas placas e costas largas
		var p2 := _pos(skel, "spine_02")
		var p3 := _pos(skel, "spine_03")
		_peca(skel, "spine_03", _rocha_n(0), mats[0], p3 + Vector3(0.09 * sx, 0.1, -0.09), Vector3(0.1 * sx, 1, -0.4), Vector3(0.11, 0.1, 0.07), 0.5)
		# quadril
		var pp := _pos(skel, "pelvis")
		_peca(skel, "pelvis", _rocha_n(1), mats[0], pp + Vector3(0.11 * sx, -0.03, 0.0), Vector3(0.3 * sx, 1, 0), Vector3(0.09, 0.07, 0.09), 0.7)
	# barriga e lombar
	var p1 := _pos(skel, "spine_01")
	# peitoral largo e lajes do abdome: tronco de golem (mais largo em cima, como um bloco)
	var pp3 := _pos(skel, "spine_03")
	var pp2 := _pos(skel, "spine_02")
	_peca(skel, "spine_03", _rocha_n(4), mats[0], pp3 + Vector3(0, 0.1, 0.07), Vector3(0, 1, 0.15), Vector3(0.2, 0.08, 0.075), 0.0)
	_peca(skel, "spine_02", _rocha_n(1), mats[0], pp2 + Vector3(0, 0.02, 0.07), Vector3(0, 1, 0.1), Vector3(0.13, 0.07, 0.06), 0.4)
	# cristais nascendo das costas e dos ombros
	var p3c := _pos(skel, "spine_03")
	for k in 4:
		var cm := CylinderMesh.new()
		cm.radial_segments = 5
		cm.rings = 1
		cm.top_radius = 0.0
		cm.bottom_radius = 0.035 + 0.01 * k
		cm.height = 0.2 + 0.07 * k
		var lado := -1.0 if k % 2 == 0 else 1.0
		_peca(skel, "spine_03", cm, mats[1], p3c + Vector3(lado * (0.05 + 0.03 * k), 0.08 - 0.05 * k, -0.17), Vector3(lado * 0.35, 1, -0.8), Vector3.ONE, k * 0.7)
	# núcleo brilhando no meio do peito, entre as placas
	var nuc := SphereMesh.new()
	nuc.radius = 0.028
	nuc.height = 0.056
	nuc.radial_segments = 8
	nuc.rings = 4
	_peca(skel, "spine_03", nuc, mats[2], p3c + Vector3(0, 0.1, 0.148), Vector3.UP, Vector3.ONE)
	# rosto humano à mostra: testa de gelo e coroa de cristais (nada cobre olhos, nariz ou boca)
	var pc := _pos(skel, "Head")
	_peca(skel, "Head", _rocha_n(2), mats[1], pc + Vector3(0, 0.12, 0.05), Vector3(0, 1, 0.5), Vector3(0.085, 0.035, 0.05), 0.0)
	for k in 5:
		var a := (k - 2) * 0.42
		var cr := CylinderMesh.new()
		cr.radial_segments = 5
		cr.rings = 1
		cr.top_radius = 0.0
		cr.bottom_radius = 0.018
		cr.height = 0.11 - absf(k - 2) * 0.02
		_peca(skel, "Head", cr, mats[1], pc + Vector3(sin(a) * 0.07, 0.17, cos(a) * 0.03 - 0.01), Vector3(sin(a) * 0.5, 1, -0.2), Vector3.ONE)
