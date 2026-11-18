extends RefCounted
# Identidade visual dos monstros humanoides (corpos de personagem): chifres, olhos acesos,
# lascas de pedra, galhos e folhas, asas; e a aura dos chefes. Tudo preso aos ossos, leve (poucas malhas).

static func _osso(skel: Skeleton3D, nome: String) -> BoneAttachment3D:
	var b := BoneAttachment3D.new()
	b.bone_name = nome
	skel.add_child(b)
	return b


static func _mat(cor: Color, emite := 0.0, rugoso := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rugoso
	if emite > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = emite
	return m


static func _peca(pai: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, esc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = esc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


static func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	return c


static func olhos(skel: Skeleton3D, cor: Color) -> void:
	var cab := _osso(skel, "Head")
	var esf := SphereMesh.new()
	esf.radius = 0.018
	esf.height = 0.036
	var m := _mat(cor, 4.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for lado in [-1.0, 1.0]:
		_peca(cab, esf, m, Vector3(0.032 * lado, 0.075, 0.085))


static func chifres(skel: Skeleton3D, cor: Color, tam := 1.0) -> void:
	var cab := _osso(skel, "Head")
	var m := _mat(cor, 0.0, 0.5)
	for lado in [-1.0, 1.0]:
		_peca(cab, _cone(0.03 * tam, 0.22 * tam), m, Vector3(0.06 * lado, 0.2, 0.0), Vector3(-25, 0, -28 * lado))


static func lascas(skel: Skeleton3D, cor: Color) -> void:
	var m := _mat(cor, 0.0, 1.0)
	for osso in ["clavicle_l", "clavicle_r", "spine_03"]:
		var b := _osso(skel, osso)
		for k in 3:
			var bx := BoxMesh.new()
			bx.size = Vector3(0.09, 0.14, 0.09) * (1.0 + 0.3 * k)
			_peca(b, bx, m, Vector3(0.05 * (k - 1), 0.12 + 0.03 * k, -0.06), Vector3(20 * k, 35 * k, 10))


static func galhos(skel: Skeleton3D) -> void:
	var casca := _mat(Color(0.3, 0.22, 0.14), 0.0, 1.0)
	var folha := _mat(Color(0.28, 0.45, 0.18), 0.0, 0.9)
	for osso in ["Head", "clavicle_l", "clavicle_r"]:
		var b := _osso(skel, osso)
		for k in 2:
			_peca(b, _cone(0.035, 0.35), casca, Vector3(0.05 * (k * 2 - 1), 0.22, -0.04), Vector3(-10, 0, 30 * (k * 2 - 1)))
			var ramo := _cone(0.02, 0.22)
			_peca(b, ramo, casca, Vector3(0.1 * (k * 2 - 1), 0.36, -0.04), Vector3(10, 0, 55 * (k * 2 - 1)))
			var folhas := PrismMesh.new()
			folhas.size = Vector3(0.14, 0.1, 0.03)
			_peca(b, folhas, folha, Vector3(0.16 * (k * 2 - 1), 0.42, -0.04), Vector3(0, 0, 40 * (k * 2 - 1)))


static func asas(skel: Skeleton3D, cor: Color) -> void:
	var b := _osso(skel, "spine_03")
	var m := _mat(cor, 0.0, 0.7)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for lado in [-1.0, 1.0]:
		var p := PrismMesh.new()
		p.size = Vector3(0.9, 0.7, 0.02)
		p.left_to_right = 0.0 if lado < 0 else 1.0
		_peca(b, p, m, Vector3(0.5 * lado, 0.15, -0.18), Vector3(0, 25 * lado, 0))


# aura de chefe: névoa escura girando no chão e brasas subindo, na cor da família
static func aura_chefe(no: Node3D, cor: Color, raio: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = 48
	p.lifetime = 2.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = raio
	p.emission_ring_inner_radius = raio * 0.6
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.albedo_color = cor
	q.material = qm
	p.mesh = q
	p.visibility_range_end = 80.0
	no.add_child(p)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 1.2
	luz.omni_range = raio * 3.0
	luz.position = Vector3(0, 0.6, 0)
	luz.shadow_enabled = false
	no.add_child(luz)


static func aplicar(id: String, modelo: String, c: Node3D, boss: bool, cor_familia: Color) -> void:
	var skel: Skeleton3D = c.get("skel")
	if skel == null:
		return
	match modelo:
		"golem":
			lascas(skel, Color(0.45, 0.43, 0.4))
			olhos(skel, Color(0.4, 0.9, 1.0))
		"ent":
			galhos(skel)
			olhos(skel, Color(0.7, 1.0, 0.3))
		"dragon":
			asas(skel, cor_familia.darkened(0.2))
			chifres(skel, Color(0.85, 0.8, 0.65), 1.2)
			olhos(skel, Color(1.0, 0.7, 0.1))
		_:
			if id in ["demonio", "senhor_dem"]:
				chifres(skel, Color(0.15, 0.08, 0.06), 1.4)
				olhos(skel, Color(1.0, 0.3, 0.1))
			elif id in ["esqueleto", "caido"]:
				olhos(skel, Color(0.4, 0.7, 1.0))
			elif id == "bandido":
				olhos(skel, Color(1.0, 0.8, 0.3)) if boss else null
	if boss:
		aura_chefe(c, cor_familia.lightened(0.2), 0.9)
