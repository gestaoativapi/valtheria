extends RefCounted
# Corpo próprio de cada chefe (decisão D6 de Robson, 18/11): nada que lembre um humano de armadura.
# O esqueleto de 65 ossos e as animações oficiais continuam por baixo (o chefe anda e ataca igual),
# mas o corpo humano fica invisível e cada osso ganha a peça da criatura:
#   golem ancestral  -> blocos de rocha com fendas de runa acesa e cristais nos ombros
#   ent milenar      -> tronco e galhos de casca, raízes nos pés, copa de folhas e musgo
#   senhor demônio   -> pele de lava rachada, chifres grandes, asas de membrana e cauda
#   dragão           -> dragonita gigante sem armadura humana, asas abertas e sopro periódico
const DragonitaVivo := preload("res://scripts/dragonita_vivo.gd")

# segmentos [osso pai, osso filho, raio relativo]
const SEGMENTOS := [
	["pelvis", "spine_01", 0.17], ["spine_01", "spine_02", 0.18], ["spine_02", "spine_03", 0.21], ["spine_03", "neck_01", 0.2],
	["neck_01", "Head", 0.08], ["clavicle_l", "upperarm_l", 0.07], ["clavicle_r", "upperarm_r", 0.07],
	["upperarm_l", "lowerarm_l", 0.085], ["upperarm_r", "lowerarm_r", 0.085], ["lowerarm_l", "hand_l", 0.075], ["lowerarm_r", "hand_r", 0.075],
	["thigh_l", "calf_l", 0.1], ["thigh_r", "calf_r", 0.1], ["calf_l", "foot_l", 0.085], ["calf_r", "foot_r", 0.085],
]

static var _rochas: Array = []


static func aplicar(c: Node3D, id: String) -> bool:
	var skel: Skeleton3D = c.get("skel")
	if skel == null:
		return false
	match id:
		"golem_anc":
			_esconder(skel)
			_golem(skel)
		"ent_mil":
			_esconder(skel)
			_ent(skel)
		"senhor_dem":
			_demonio(c, skel)
		"dragao":
			_dragao(c, skel)
		_:
			return false
	return true


static func _esconder(skel: Skeleton3D) -> void:
	for m in skel.find_children("*", "MeshInstance3D", false, false):
		(m as MeshInstance3D).visible = false


static func _r(skel: Skeleton3D, b: String) -> Transform3D:
	return skel.get_bone_global_rest(skel.find_bone(b))


static func _anexo(skel: Skeleton3D, b: String) -> BoneAttachment3D:
	for ch in skel.get_children():
		if ch is BoneAttachment3D and (ch as BoneAttachment3D).bone_name == b and ch.name.begins_with("CorpoChefe"):
			return ch
	var a := BoneAttachment3D.new()
	a.bone_name = b
	a.name = "CorpoChefe_" + b
	skel.add_child(a)
	return a


static func _por(skel: Skeleton3D, b: String, mesh: Mesh, mat: Material, xf: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = _r(skel, b).affine_inverse() * xf
	_anexo(skel, b).add_child(mi)
	return mi


# rocha irregular: esfera deformada por ruído (3 variações reaproveitadas)
static func _rocha(semente: int) -> ArrayMesh:
	if _rochas.size() < 3:
		for k in 3:
			var s := SphereMesh.new()
			s.radial_segments = 10
			s.rings = 6
			var a := s.get_mesh_arrays()
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var rng := RandomNumberGenerator.new()
			rng.seed = 77 + k
			var faces := []
			for f in 7:
				faces.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized())
			for i in v.size():
				var p := v[i]
				# facetas planas: corta a esfera por alguns planos (pedra lascada)
				for n in faces:
					var d := p.dot(n)
					if d > 0.36:
						p -= n * (d - 0.36) * 0.85
				v[i] = p
			a[Mesh.ARRAY_VERTEX] = v
			var st := SurfaceTool.new()
			st.create_from_arrays(a)
			st.generate_normals()
			_rochas.append(st.commit())
	return _rochas[semente % 3]


static func _tex(caminho: String) -> Texture2D:
	return load(caminho) if ResourceLoader.exists(caminho) else null


# ---------------------------------------------------------------- golem
static func _golem(skel: Skeleton3D) -> void:
	var pedra := StandardMaterial3D.new()
	pedra.albedo_texture = _tex("res://assets/world/n_rock_medium_1_Rocks_Diffuse.webp")
	pedra.albedo_color = Color(0.62, 0.6, 0.56)
	pedra.uv1_triplanar = true
	pedra.uv1_scale = Vector3(2.5, 2.5, 2.5)
	pedra.roughness = 0.95
	var runa := StandardMaterial3D.new()
	runa.albedo_color = Color(1.0, 0.6, 0.2)
	runa.emission_enabled = true
	runa.emission = Color(1.0, 0.45, 0.1)
	runa.emission_energy_multiplier = 2.2
	var cristal := StandardMaterial3D.new()
	cristal.albedo_color = Color(0.55, 0.85, 0.95, 0.85)
	cristal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cristal.emission_enabled = true
	cristal.emission = Color(0.3, 0.7, 0.9)
	cristal.emission_energy_multiplier = 0.8
	cristal.roughness = 0.1
	var k := 0
	for sg in SEGMENTOS:
		var a := _r(skel, sg[0]).origin
		var b := _r(skel, sg[1]).origin
		var meio := (a + b) * 0.5
		var comp := (b - a).length()
		var r: float = sg[2] * 1.45
		var dir := (b - a).normalized()
		var base := Basis(Quaternion(Vector3.UP, dir))
		# um bloco por segmento + um bloco menor deslocado (silhueta irregular de pedra empilhada)
		_por(skel, sg[0], _rocha(k), pedra, Transform3D(base * Basis.from_scale(Vector3(r * 2.0, comp * 1.25, r * 1.8)), meio))
		if comp > 0.15:
			_por(skel, sg[0], _rocha(k + 1), pedra, Transform3D(base * Basis.from_euler(Vector3(0.4, k, 0.3)) * Basis.from_scale(Vector3(r * 1.3, comp * 0.6, r * 1.2)), meio + base * Vector3(r * 0.5, 0, r * 0.35)))
		# fenda de runa acesa entre os blocos
		var cil := CylinderMesh.new()
		cil.top_radius = r * 0.55
		cil.bottom_radius = r * 0.55
		cil.height = 0.02
		cil.radial_segments = 8
		_por(skel, sg[0], cil, runa, Transform3D(base, a.lerp(b, 0.08)))
		k += 1
	# cabeça: bloco quadrado com olhos de runa
	var h := _r(skel, "Head").origin
	_por(skel, "Head", _rocha(2), pedra, Transform3D(Basis.from_scale(Vector3(0.26, 0.24, 0.26)), h + Vector3(0, 0.1, 0.0)))
	for lado in [-1.0, 1.0]:
		var o := SphereMesh.new()
		o.radius = 0.022
		o.height = 0.03
		_por(skel, "Head", o, runa, Transform3D(Basis.IDENTITY, h + Vector3(lado * 0.055, 0.12, 0.125)))
	# mãos enormes (punhos de pedra) e cristais nos ombros
	for lado in ["l", "r"]:
		var hd := _r(skel, "hand_" + lado).origin
		_por(skel, "hand_" + lado, _rocha(1), pedra, Transform3D(Basis.from_scale(Vector3(0.24, 0.24, 0.24)), hd + Vector3(0, -0.06, 0)))
		var om := _r(skel, "upperarm_" + lado).origin
		var sg2 := 1.0 if lado == "l" else -1.0
		for c in 4:
			var pr := CylinderMesh.new()
			pr.top_radius = 0.0
			pr.bottom_radius = 0.05 + (c % 2) * 0.02
			pr.height = 0.28 + (c % 3) * 0.1
			pr.radial_segments = 5
			_por(skel, "clavicle_" + lado, pr, cristal, Transform3D(Basis.from_euler(Vector3(-0.3 + c * 0.25, 0, sg2 * (-0.2 - 0.18 * c))), om + Vector3(sg2 * (0.02 + c * 0.04), 0.16, -0.08 + c * 0.04)))


# ---------------------------------------------------------------- ent
static func _ent(skel: Skeleton3D) -> void:
	var casca := StandardMaterial3D.new()
	casca.albedo_texture = _tex("res://assets/world/n_twistedtree_1_Bark_TwistedTree.webp")
	casca.normal_enabled = true
	casca.normal_texture = _tex("res://assets/world/n_twistedtree_1_Bark_TwistedTree_Normal.webp")
	casca.albedo_color = Color(0.75, 0.68, 0.6)
	casca.uv1_triplanar = true
	casca.uv1_scale = Vector3(1.6, 1.6, 1.6)
	casca.roughness = 0.95
	var musgo := StandardMaterial3D.new()
	musgo.albedo_color = Color(0.26, 0.36, 0.14)
	musgo.roughness = 1.0
	var folha := StandardMaterial3D.new()
	folha.albedo_color = Color(0.2, 0.32, 0.11)
	folha.roughness = 0.9
	var folha2 := StandardMaterial3D.new()
	folha2.albedo_color = Color(0.3, 0.4, 0.14)
	folha2.roughness = 0.9
	var olho := StandardMaterial3D.new()
	olho.albedo_color = Color(0.7, 1.0, 0.45)
	olho.emission_enabled = true
	olho.emission = Color(0.5, 1.0, 0.3)
	olho.emission_energy_multiplier = 2.5
	var k := 0
	for sg in SEGMENTOS:
		var a := _r(skel, sg[0]).origin
		var b := _r(skel, sg[1]).origin
		var comp := (b - a).length()
		var r: float = sg[2] * 1.25
		var dir := (b - a).normalized()
		var cil := CylinderMesh.new()
		cil.top_radius = r * 0.8
		cil.bottom_radius = r
		cil.height = comp * 1.12
		cil.radial_segments = 9
		cil.rings = 2
		_por(skel, sg[0], cil, casca, Transform3D(Basis(Quaternion(Vector3.UP, dir)) * Basis.from_euler(Vector3(0, k * 0.9, 0)), (a + b) * 0.5))
		# tufos de musgo
		if k % 3 == 0:
			_por(skel, sg[0], _rocha(k), musgo, Transform3D(Basis.from_scale(Vector3(r * 1.1, r * 0.6, r * 1.1)), a.lerp(b, 0.6) + Vector3(0, 0, r * 0.7)))
		k += 1
	# dedos de galho nas mãos
	for lado in ["l", "r"]:
		var hd := _r(skel, "hand_" + lado).origin
		var sg2 := 1.0 if lado == "l" else -1.0
		for d in 4:
			var g := CylinderMesh.new()
			g.top_radius = 0.004
			g.bottom_radius = 0.018
			g.height = 0.22
			g.radial_segments = 5
			_por(skel, "hand_" + lado, g, casca, Transform3D(Basis.from_euler(Vector3(-0.3 + d * 0.2, 0, sg2 * (1.9 + d * 0.15))), hd + Vector3(sg2 * 0.1, -0.02, -0.03 + d * 0.025)))
		# raízes nos pés, abertas no chão
		var ft := _r(skel, "foot_" + lado).origin
		for rz in 5:
			var ang := -1.2 + rz * 0.6
			var raiz := CylinderMesh.new()
			raiz.top_radius = 0.004
			raiz.bottom_radius = 0.035
			raiz.height = 0.32
			raiz.radial_segments = 5
			_por(skel, "foot_" + lado, raiz, casca, Transform3D(Basis.from_euler(Vector3(1.25, ang, 0)), ft + Vector3(sin(ang) * 0.12, -0.06, cos(ang) * 0.12)))
	# cabeça de tronco com olhos acesos e copa de folhas
	var h := _r(skel, "Head").origin
	var tr := CylinderMesh.new()
	tr.top_radius = 0.1
	tr.bottom_radius = 0.13
	tr.height = 0.32
	tr.radial_segments = 9
	_por(skel, "Head", tr, casca, Transform3D(Basis.IDENTITY, h + Vector3(0, 0.12, 0)))
	for lado in [-1.0, 1.0]:
		var o := SphereMesh.new()
		o.radius = 0.02
		o.height = 0.03
		_por(skel, "Head", o, olho, Transform3D(Basis.IDENTITY, h + Vector3(lado * 0.045, 0.14, 0.12)))
	for f in 9:
		var ang := TAU * f / 9.0
		_por(skel, "Head", _rocha(f), folha if f % 2 == 0 else folha2, Transform3D(Basis.from_scale(Vector3(0.34, 0.26, 0.34) * (1.0 + (f % 3) * 0.15)), h + Vector3(cos(ang) * 0.22, 0.42 + (f % 3) * 0.09, sin(ang) * 0.22 - 0.05)))
	# galhos saindo dos ombros e das costas
	var sp := _r(skel, "spine_03").origin
	for g2 in 6:
		var lado := -1.0 if g2 % 2 == 0 else 1.0
		var ga := CylinderMesh.new()
		ga.top_radius = 0.006
		ga.bottom_radius = 0.035
		ga.height = 0.5 + (g2 % 3) * 0.15
		ga.radial_segments = 5
		var b := Basis.from_euler(Vector3(-0.5 - (g2 / 2) * 0.2, 0, lado * (0.4 + (g2 / 2) * 0.25)))
		_por(skel, "spine_03", ga, casca, Transform3D(b, sp + Vector3(lado * 0.12, 0.12, -0.12) + b * Vector3(0, ga.height * 0.5, 0)))
		_por(skel, "spine_03", _rocha(g2), folha2, Transform3D(Basis.from_scale(Vector3(0.26, 0.2, 0.26)), sp + Vector3(lado * 0.12, 0.12, -0.12) + b * Vector3(0, ga.height, 0)))


# ---------------------------------------------------------------- demônio
static func _demonio(c: Node3D, skel: Skeleton3D) -> void:
	# pele de lava: fendas acesas por cima da pele vermelha escura
	var lava_sh := Shader.new()
	lava_sh.code = """
shader_type spatial;
uniform vec3 pele : source_color = vec3(0.32, 0.06, 0.04);
uniform sampler2D rosto_tex : source_color, filter_linear_mipmap;
uniform bool usa_rosto = false;
varying vec3 lp;
varying float rosto;
void vertex() { lp = VERTEX; rosto = usa_rosto ? COLOR.r : 0.0; }
float h(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vor(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); float d1 = 9.0; float d2 = 9.0;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = vec3(h(i + g), h(i + g + 3.1), h(i + g + 7.7));
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return d2 - d1;
}
void fragment() {
	float e = vor(lp * 9.0);
	float k = smoothstep(0.4, 0.85, rosto);
	// no rosto as fendas somem: a pele vermelha mostra nariz, boca e maçãs (rosto de demônio, não uma máscara de lava)
	float fenda = (1.0 - smoothstep(0.02, 0.09, e)) * (1.0 - k);
	float pulso = 0.7 + 0.3 * sin(TIME * 2.0 + lp.y * 6.0);
	vec3 face = usa_rosto ? texture(rosto_tex, UV).rgb * vec3(0.95, 0.24, 0.17) : pele;
	ALBEDO = mix(mix(pele, face, k), vec3(0.1, 0.02, 0.0), fenda);
	EMISSION = vec3(1.0, 0.35, 0.05) * fenda * 2.4 * pulso;
	ROUGHNESS = 0.75;
}
"""
	var lava := ShaderMaterial.new()
	lava.shader = lava_sh
	for m in skel.find_children("*", "MeshInstance3D", false, false):
		var mi := m as MeshInstance3D
		if String(mi.name) == "corpo":
			var base := mi.get_active_material(0) as BaseMaterial3D
			var novo := GeloGolem.marcar_cabeca(skel, mi)
			if novo != null and base != null and base.albedo_texture != null:
				var lr := ShaderMaterial.new()
				lr.shader = lava_sh
				lr.set_shader_parameter("rosto_tex", base.albedo_texture)
				lr.set_shader_parameter("usa_rosto", true)
				mi.mesh = novo
				mi.material_override = lr
				continue
		mi.material_override = lava
	_rosto_demonio(skel)
	var chifre := StandardMaterial3D.new()
	chifre.albedo_color = Color(0.12, 0.1, 0.09)
	chifre.roughness = 0.4
	var h := _r(skel, "Head").origin
	# chifres grandes e curvos (segmentos que giram para trás e para cima)
	for lado in [-1.0, 1.0]:
		var p := h + Vector3(lado * 0.06, 0.15, 0.02)
		var dir := Vector3(lado * 0.6, 0.6, -0.2).normalized()
		var raio := 0.04
		for s in 6:
			var comp := 0.07
			var cil := CylinderMesh.new()
			cil.bottom_radius = raio
			cil.top_radius = raio * 0.78
			cil.height = comp
			cil.radial_segments = 8
			_por(skel, "Head", cil, chifre, Transform3D(Basis(Quaternion(Vector3.UP, dir)), p + dir * comp * 0.5))
			p += dir * comp * 0.92
			raio *= 0.78
			dir = (dir + Vector3(0, -0.12, -0.38) + Vector3(lado * 0.05, 0, 0)).normalized()
	# asas de membrana escura e cauda (reaproveita a anatomia das asas da dragonita)
	var dv := DragonitaVivo.new()
	dv.name = "AsasDemonio"
	dv.skel = skel
	dv.char = c
	dv._cor = Color(0.35, 0.08, 0.06)
	c.add_child(dv)
	dv._criar_asas()
	dv.tamanho = 1.5
	dv.estado = "combate"
	var pel := _r(skel, "pelvis").origin
	var p2 := pel + Vector3(0, -0.02, -0.12)
	var d2 := Vector3(0, -0.6, -0.8).normalized()
	var r2 := 0.05
	for s in 9:
		var cil2 := CylinderMesh.new()
		cil2.bottom_radius = r2
		cil2.top_radius = r2 * 0.85
		cil2.height = 0.12
		cil2.radial_segments = 7
		_por(skel, "pelvis", cil2, chifre, Transform3D(Basis(Quaternion(Vector3.UP, d2)), p2 + d2 * 0.06))
		p2 += d2 * 0.11
		r2 *= 0.86
		d2 = (d2 + Vector3(0, 0.1, -0.05)).normalized()
	var ponta := CylinderMesh.new()
	ponta.top_radius = 0.0
	ponta.bottom_radius = 0.05
	ponta.height = 0.12
	ponta.radial_segments = 4
	_por(skel, "pelvis", ponta, chifre, Transform3D(Basis(Quaternion(Vector3.UP, d2)) * Basis.from_scale(Vector3(1.0, 1.0, 0.3)), p2 + d2 * 0.06))


# rosto do demônio: olhos acesos em fenda, sobrancelha óssea em V (cara de fúria) e presas saindo da boca
static func _rosto_demonio(skel: Skeleton3D) -> void:
	var brasa := StandardMaterial3D.new()
	brasa.albedo_color = Color(1.0, 0.78, 0.2)
	brasa.emission_enabled = true
	brasa.emission = Color(1.0, 0.55, 0.08)
	brasa.emission_energy_multiplier = 4.0
	brasa.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var osso := StandardMaterial3D.new()
	osso.albedo_color = Color(0.2, 0.05, 0.04)
	osso.roughness = 0.5
	var dente := StandardMaterial3D.new()
	dente.albedo_color = Color(0.9, 0.86, 0.74)
	dente.roughness = 0.35
	for lado in [-1.0, 1.0]:
		var ol := SphereMesh.new()
		ol.radius = 0.5
		ol.height = 1.0
		ol.radial_segments = 10
		ol.rings = 5
		# olho em fenda inclinada para o centro (achatado e girado)
		var b := Basis(Vector3.FORWARD, lado * 0.35) * Basis.from_scale(Vector3(0.03, 0.011, 0.012))
		_por(skel, "Head", ol, brasa, Transform3D(b, Vector3(lado * 0.033, 1.692, 0.088)))
		var sob := BoxMesh.new()
		sob.size = Vector3(0.05, 0.016, 0.03)
		_por(skel, "Head", sob, osso, Transform3D(Basis(Vector3.FORWARD, lado * 0.42), Vector3(lado * 0.03, 1.715, 0.09)))
		var presa := CylinderMesh.new()
		presa.top_radius = 0.0
		presa.bottom_radius = 0.007
		presa.height = 0.035
		presa.radial_segments = 6
		_por(skel, "Head", presa, dente, Transform3D(Basis(Vector3.RIGHT, PI) * Basis(Vector3.FORWARD, lado * 0.15), Vector3(lado * 0.016, 1.612, 0.097)))


# cavaleiro caído: olhos frios acesos sobre os olhos, olheiras fundas, veias escuras subindo do pescoço e
# uma auréola partida e torta flutuando atrás da cabeça
static func _caido(skel: Skeleton3D) -> void:
	# pele cinza-azulada de quem caiu (sem cor de vida)
	for m in skel.find_children("corpo", "MeshInstance3D", false, false):
		var mi := m as MeshInstance3D
		var base := mi.get_active_material(0) as BaseMaterial3D
		if base != null:
			var d := base.duplicate() as BaseMaterial3D
			d.albedo_color = Color(0.6, 0.64, 0.74)
			mi.set_surface_override_material(0, d)
	var frio := StandardMaterial3D.new()
	frio.albedo_color = Color(0.75, 0.9, 1.0)
	frio.emission_enabled = true
	frio.emission = Color(0.45, 0.75, 1.0)
	frio.emission_energy_multiplier = 3.5
	frio.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sombra := StandardMaterial3D.new()
	sombra.albedo_color = Color(0.05, 0.04, 0.08, 0.35)
	sombra.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for lado in [-1.0, 1.0]:
		var ol := SphereMesh.new()
		ol.radius = 0.5
		ol.height = 1.0
		ol.radial_segments = 10
		ol.rings = 5
		_por(skel, "Head", ol, frio, Transform3D(Basis.from_scale(Vector3(0.014, 0.007, 0.008)), Vector3(lado * 0.033, 1.692, 0.09)))
		var olh := SphereMesh.new()
		olh.radius = 0.5
		olh.height = 1.0
		_por(skel, "Head", olh, sombra, Transform3D(Basis.from_scale(Vector3(0.03, 0.022, 0.008)), Vector3(lado * 0.033, 1.684, 0.084)))
	var ouro := StandardMaterial3D.new()
	ouro.albedo_color = Color(0.45, 0.36, 0.2)
	ouro.metallic = 0.9
	ouro.roughness = 0.45
	ouro.emission_enabled = true
	ouro.emission = Color(0.35, 0.5, 0.8)
	ouro.emission_energy_multiplier = 0.5
	# auréola partida: três arcos com falhas entre eles, inclinada; o último pedaço caiu um pouco
	var giro := Basis(Vector3.RIGHT, -0.3) * Basis(Vector3.FORWARD, 0.2)
	var arcos := [[0.2, 2.1, 0.0], [2.45, 4.0, 0.0], [4.35, 5.7, -0.035]]
	for ar in arcos:
		var off := Vector3(0, float(ar[2]), 0)
		_por(skel, "Head", _arco(0.13, 0.012, float(ar[0]), float(ar[1])), ouro, Transform3D(giro * Basis(Vector3.RIGHT, float(ar[2]) * 4.0), Vector3(0, 1.86, -0.04) + off))


# arco de anel achatado (fita grossa) entre os ângulos a0 e a1, no plano XZ
static func _arco(r: float, w: float, a0: float, a1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var sec := [Vector2(-w, -w * 0.5), Vector2(w, -w * 0.5), Vector2(w, w * 0.5), Vector2(-w, w * 0.5)]
	var aneis := []
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		var dirv := Vector3(cos(a), 0, sin(a))
		var anel := []
		for q in sec:
			anel.append(dirv * (r + q.x) + Vector3(0, q.y, 0))
		aneis.append(anel)
	for i in n:
		for j in 4:
			var j2 := (j + 1) % 4
			var p0: Vector3 = aneis[i][j]
			var p1: Vector3 = aneis[i][j2]
			var p2: Vector3 = aneis[i + 1][j]
			var p3: Vector3 = aneis[i + 1][j2]
			for q in [p0, p2, p1, p1, p2, p3]:
				st.add_vertex(q)
	st.generate_normals()
	return st.commit()


# ---------------------------------------------------------------- dragão
static func _dragao(c: Node3D, skel: Skeleton3D) -> void:
	# dragonita gigante: esconde a armadura humana, asas abertas enormes e sopro de fogo de tempos em tempos
	for ch in skel.get_children():
		if ch is MeshInstance3D and String(ch.name) == "PeitoralAjustado":
			(ch as MeshInstance3D).visible = false
	for ch in skel.get_children():
		if ch is BoneAttachment3D and not String(ch.name).begins_with("AsasDragonita") and not String(ch.name).begins_with("CorpoChefe"):
			for m in ch.find_children("*", "MeshInstance3D", true, false):
				if (m as MeshInstance3D).material_override is StandardMaterial3D and ((m as MeshInstance3D).material_override as StandardMaterial3D).metallic > 0.5:
					(m as MeshInstance3D).visible = false
	var dv: Node = c.get("asas")
	if dv == null:
		return
	dv.tamanho = 1.7
	dv.estado = "planar"
	var tw := c.create_tween().set_loops()
	tw.tween_interval(7.0)
	tw.tween_callback(func():
		if is_instance_valid(dv):
			dv.sopro("fogo"))


# ---------------------------------------------------------------- monstros comuns com corpo próprio
static func comum(c: Node3D, id: String) -> void:
	var skel: Skeleton3D = c.get("skel")
	if skel == null:
		return
	match id:
		"golem":
			_esconder(skel)
			_golem(skel)
		"ent":
			_esconder(skel)
			_ent(skel)
		"esqueleto":
			_esconder(skel)
			_esqueleto(skel, Color(0.4, 0.85, 1.0), false)
		"espectro":
			_esconder(skel)
			_esqueleto(skel, Color(0.75, 0.4, 1.0), true)
		"demonio":
			_demonio_menor(c, skel)
		"caido":
			_caido(skel)


static func _esqueleto(skel: Skeleton3D, cor_olho: Color, espectro: bool) -> void:
	var osso := StandardMaterial3D.new()
	osso.albedo_color = Color(0.86, 0.83, 0.74) if not espectro else Color(0.35, 0.32, 0.42, 0.75)
	osso.roughness = 0.6
	if espectro:
		osso.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		osso.emission_enabled = true
		osso.emission = Color(0.4, 0.25, 0.6)
		osso.emission_energy_multiplier = 0.6
	var olho := StandardMaterial3D.new()
	olho.albedo_color = cor_olho
	olho.emission_enabled = true
	olho.emission = cor_olho
	olho.emission_energy_multiplier = 3.0
	var escuro := StandardMaterial3D.new()
	escuro.albedo_color = Color(0.05, 0.04, 0.04)
	for sg in SEGMENTOS:
		var a := _r(skel, sg[0]).origin
		var b := _r(skel, sg[1]).origin
		var dir := (b - a).normalized()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.018
		cil.bottom_radius = 0.022
		cil.height = (b - a).length() * 0.95
		cil.radial_segments = 6
		_por(skel, sg[0], cil, osso, Transform3D(Basis(Quaternion(Vector3.UP, dir)), (a + b) * 0.5))
		# juntas (nós dos ossos)
		var n := SphereMesh.new()
		n.radius = 0.03
		n.height = 0.05
		n.radial_segments = 8
		n.rings = 4
		_por(skel, sg[0], n, osso, Transform3D(Basis.IDENTITY, a))
	# caixa torácica: costelas em arco
	var s2 := _r(skel, "spine_02").origin
	var s3 := _r(skel, "spine_03").origin
	for k in 5:
		var anel := TorusMesh.new()
		anel.inner_radius = 0.1 - k * 0.008
		anel.outer_radius = 0.118 - k * 0.008
		anel.rings = 14
		anel.ring_segments = 5
		_por(skel, "spine_02", anel, osso, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.75)), s2.lerp(s3, 0.1 + k * 0.2) + Vector3(0, -0.05 + k * 0.02, 0.02)))
	# bacia
	var pel := _r(skel, "pelvis").origin
	var bacia := TorusMesh.new()
	bacia.inner_radius = 0.07
	bacia.outer_radius = 0.11
	_por(skel, "pelvis", bacia, osso, Transform3D(Basis.from_scale(Vector3(1.1, 1.6, 0.8)), pel))
	# crânio anatômico: caixa craniana alongada para trás, face que afina até o maxilar, arco das sobrancelhas,
	# maçãs do rosto, órbitas fundas com brasa no fundo, cavidade do nariz, fileiras de dentes e mandíbula separada
	var h := _r(skel, "Head").origin
	var cranio := SphereMesh.new()
	cranio.radius = 0.1
	cranio.height = 0.2
	cranio.radial_segments = 14
	cranio.rings = 8
	_por(skel, "Head", cranio, osso, Transform3D(Basis.from_scale(Vector3(0.86, 0.92, 1.06)), h + Vector3(0, 0.135, -0.012)))
	var face := CylinderMesh.new()
	face.top_radius = 0.07
	face.bottom_radius = 0.05
	face.height = 0.085
	face.radial_segments = 10
	_por(skel, "Head", face, osso, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.75)), h + Vector3(0, 0.07, 0.035)))
	var arco := BoxMesh.new()
	arco.size = Vector3(0.12, 0.02, 0.03)
	_por(skel, "Head", arco, osso, Transform3D(Basis(Vector3.RIGHT, -0.25), h + Vector3(0, 0.124, 0.07)))
	for lado in [-1.0, 1.0]:
		var maca := SphereMesh.new()
		maca.radius = 0.024
		maca.height = 0.048
		_por(skel, "Head", maca, osso, Transform3D(Basis.from_scale(Vector3(1.1, 0.6, 0.8)), h + Vector3(lado * 0.05, 0.078, 0.058)))
		var orb := SphereMesh.new()
		orb.radius = 0.025
		orb.height = 0.046
		_por(skel, "Head", orb, escuro, Transform3D(Basis.from_scale(Vector3(1.0, 0.95, 0.7)), h + Vector3(lado * 0.034, 0.1, 0.072)))
		var ol := SphereMesh.new()
		ol.radius = 0.008
		ol.height = 0.016
		_por(skel, "Head", ol, olho, Transform3D(Basis.IDENTITY, h + Vector3(lado * 0.033, 0.099, 0.082)))
	var nariz := CylinderMesh.new()
	nariz.top_radius = 0.013
	nariz.bottom_radius = 0.0
	nariz.height = 0.03
	nariz.radial_segments = 3
	_por(skel, "Head", nariz, escuro, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.4)), h + Vector3(0, 0.067, 0.082)))
	var mand := BoxMesh.new()
	mand.size = Vector3(0.09, 0.022, 0.065)
	_por(skel, "Head", mand, osso, Transform3D(Basis.IDENTITY, h + Vector3(0, 0.004, 0.035)))
	for fila in [0.036, 0.02]:
		for k in 6:
			var u := (k - 2.5) / 2.5
			var dt := BoxMesh.new()
			dt.size = Vector3(0.011, 0.014, 0.008)
			_por(skel, "Head", dt, osso, Transform3D(Basis(Vector3.UP, -u * 0.6), h + Vector3(u * 0.03, fila, 0.072 - u * u * 0.018)))
	if espectro:
		# manto rasgado de névoa escura
		var manto := CylinderMesh.new()
		manto.top_radius = 0.16
		manto.bottom_radius = 0.42
		manto.height = 1.2
		manto.radial_segments = 12
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.08, 0.06, 0.12, 0.6)
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_por(skel, "spine_03", manto, mm, Transform3D(Basis.IDENTITY, s3 + Vector3(0, -0.55, -0.02)))


static func _demonio_menor(c: Node3D, skel: Skeleton3D) -> void:
	_demonio(c, skel)
	var asas := c.get_node_or_null("AsasDemonio")
	if asas:
		asas.tamanho = 0.9
		asas.estado = "dobrada"
