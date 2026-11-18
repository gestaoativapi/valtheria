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
	p.color = cor
	q.material = _mat_brilho()
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


static func _cil(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r * 0.8
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	return c


# ---------- javali: corpo de lobo transformado (baixo, robusto, cabeção, presas e crina de cerdas) ----------
# Usa o mesmo esqueleto de quadrúpede do lobo, então anda, corre e ataca com as animações dele.
const JAVALI_OSSOS := {
	"Torso": 1.42, "Neck1": 0.72, "Head": 1.2,
	"FrontUpperLeg.L": 0.72, "FrontUpperLeg.R": 0.72, "FrontLowerLeg.L": 0.7, "FrontLowerLeg.R": 0.7,
	"BackLeg.L": 0.75, "BackLeg.R": 0.75, "BackUpperLeg.L": 0.75, "BackUpperLeg.R": 0.75, "BackLowerLeg.L": 0.7, "BackLowerLeg.R": 0.7,
	"Ear1.L": 0.55, "Ear1.R": 0.55, "Tail1": 0.4,
}


static func javali(raiz: Node3D, boss := false) -> void:
	var sk := raiz.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return
	# pernas curtas e corpo largo: as pernas do lobo seguem os alvos de IK, então o achatamento vai na raiz
	raiz.scale *= Vector3(1.4, 0.74, 1.0)
	for b in JAVALI_OSSOS:
		var i := sk.find_bone(b)
		if i >= 0:
			sk.set_bone_pose_scale(i, Vector3.ONE * float(JAVALI_OSSOS[b]))
	# pelagem marrom-escura sobre a textura cinza do lobo
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var orig := mi.get_active_material(s)
			if orig is StandardMaterial3D:
				var nm: StandardMaterial3D = (orig as StandardMaterial3D).duplicate()
				nm.albedo_color = Color(0.62, 0.42, 0.3) if not boss else Color(0.42, 0.3, 0.26)
				nm.roughness = 1.0
				mi.set_surface_override_material(s, nm)
	var marfim := _mat(Color(0.92, 0.88, 0.76), 0.0, 0.45)
	var focinho := _mat(Color(0.32, 0.2, 0.18), 0.0, 0.7)
	var cerda := _mat(Color(0.18, 0.12, 0.09), 0.0, 1.0)
	var hi := sk.find_bone("Head")
	var cab := _osso(sk, "Head")
	var inv := sk.get_bone_global_rest(hi).affine_inverse()
	# focinho em disco achatado na ponta da cabeça
	var disco := CylinderMesh.new()
	disco.top_radius = 0.16
	disco.bottom_radius = 0.19
	disco.height = 0.16
	var fm := _peca(cab, disco, focinho, Vector3.ZERO)
	fm.transform = inv * Transform3D(Basis.from_euler(Vector3(deg_to_rad(80), 0, 0)), Vector3(0, 1.98, 2.62))
	# presas curvas para cima, saindo dos lados da boca
	for lado in [-1.0, 1.0]:
		for k in 3:
			var seg := _cone(0.045 - k * 0.012, 0.16) if k == 2 else _cil(0.045 - k * 0.012, 0.15)
			var p := Vector3(lado * (0.17 + k * 0.03), 1.86 + k * 0.1, 2.48 + k * 0.03)
			var r := Vector3(deg_to_rad(-20 + k * 25), 0, deg_to_rad(-lado * (25 + k * 12)))
			var pm := _peca(cab, seg, marfim, Vector3.ZERO)
			pm.transform = inv * Transform3D(Basis.from_euler(r), p)
	# crina de cerdas escuras ao longo do dorso (presa aos ossos do tronco)
	for par in [["Torso3", 1.0], ["Torso2", 0.9], ["Torso", 0.8], ["Back", 0.6]]:
		var bi := sk.find_bone(par[0])
		if bi < 0:
			continue
		var at := _osso(sk, par[0])
		var inv2 := sk.get_bone_global_rest(bi).affine_inverse()
		var o := sk.get_bone_global_rest(bi).origin
		for k in 4:
			var h: float = 0.22 * float(par[1])
			var c := _peca(at, _cone(0.05, h), cerda, Vector3.ZERO)
			c.transform = inv2 * Transform3D(Basis.from_euler(Vector3(deg_to_rad(-25), 0, 0)), o + Vector3(0, 0.36 + h * 0.4, -0.15 + k * 0.1))



# ---------- chefes: mutação, armamento rústico, elemento e habilidade ----------
# Cada chefe ganha: ombreiras com espinhos e placas mutantes, espinhos na arma, olhos acesos,
# aura do elemento (terra, fogo, natureza, gelo, trevas, luz) e um golpe de habilidade periódico
# (onda no chão + explosão do elemento). O dano e os efeitos negativos ficam no servidor.
const ELEMENTOS := {
	"terra": [Color(0.75, 0.55, 0.3), Color(0.45, 0.35, 0.25)],
	"fogo": [Color(1.0, 0.45, 0.12), Color(1.0, 0.8, 0.3)],
	"natureza": [Color(0.45, 0.95, 0.3), Color(0.75, 0.35, 0.9)],
	"gelo": [Color(0.55, 0.85, 1.0), Color(0.9, 0.97, 1.0)],
	"trevas": [Color(0.45, 0.2, 0.7), Color(0.15, 0.05, 0.25)],
	"luz": [Color(1.0, 0.95, 0.7), Color(0.7, 0.9, 1.0)],
}


static func chefe(c: Node3D, fam: Dictionary) -> void:
	var skel: Skeleton3D = c.get("skel")
	if skel == null:
		return
	var el: Array = ELEMENTOS.get(str(fam.get("elem", "terra")), ELEMENTOS.terra)
	var cor: Color = el[0]
	var ferro := _mat(Color(0.22, 0.2, 0.19), 0.0, 0.5)
	ferro.metallic = 0.7
	var osso := _mat(Color(0.88, 0.83, 0.7), 0.0, 0.55)
	# ombreiras mutantes com espinhos de osso
	for lado in ["l", "r"]:
		var bi := skel.find_bone("upperarm_" + lado)
		if bi < 0:
			continue
		var sg := 1.0 if lado == "l" else -1.0
		var at := _osso(skel, "upperarm_" + lado)
		var inv := skel.get_bone_global_rest(bi).affine_inverse()
		var o := skel.get_bone_global_rest(bi).origin
		var esf := SphereMesh.new()
		esf.radius = 0.13
		esf.height = 0.16
		var pm := _peca(at, esf, ferro, Vector3.ZERO)
		pm.transform = inv * Transform3D(Basis.from_euler(Vector3(0, 0, -sg * 0.4)), o + Vector3(sg * 0.03, 0.06, 0))
		for k in 4:
			var e := _peca(at, _cone(0.025, 0.16 + (k % 2) * 0.06), osso, Vector3.ZERO)
			e.transform = inv * Transform3D(Basis.from_euler(Vector3(-0.5 + k * 0.33, 0, -sg * (0.25 + 0.2 * (k % 2)))), o + Vector3(sg * (0.04 + k * 0.012), 0.16, -0.08 + k * 0.05))
	# placas de mutação nas costas
	var sp := skel.find_bone("spine_03")
	if sp >= 0:
		var at2 := _osso(skel, "spine_03")
		var inv2 := skel.get_bone_global_rest(sp).affine_inverse()
		var o2 := skel.get_bone_global_rest(sp).origin
		for k in 5:
			var e2 := _peca(at2, _cone(0.04, 0.18 + 0.05 * sin(k * 1.3)), osso, Vector3.ZERO)
			e2.transform = inv2 * Transform3D(Basis.from_euler(Vector3(-0.9, 0, (k - 2) * 0.25)), o2 + Vector3((k - 2) * 0.06, 0.05 - absf(k - 2) * 0.04, -0.14))
	# espinhos na cabeça da arma
	var arma: Node3D = c.get("wnode")
	if arma != null:
		for k in 6:
			var ang := TAU * k / 6.0
			var e3 := _peca(arma, _cone(0.03, 0.14), ferro, Vector3.ZERO)
			e3.transform = Transform3D(Basis(Quaternion(Vector3.UP, Vector3(cos(ang), 0.3, sin(ang)).normalized())), Vector3(cos(ang) * 0.06, 0.62, sin(ang) * 0.06))
	olhos(skel, cor.lightened(0.3))
	_aura_elemento(c, el)
	_habilidade(c, el)


# partículas do elemento subindo do corpo (fogo, cinza, folhas, cristais de gelo, fumaça escura, luz)
static func _aura_elemento(c: Node3D, el: Array) -> void:
	var p := CPUParticles3D.new()
	p.name = "AuraElemento"
	p.amount = 40
	p.lifetime = 1.8
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.position = Vector3(0, 1.1, 0)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	var cv := Curve.new()
	cv.add_point(Vector2(0, 0.0))
	cv.add_point(Vector2(0.2, 1.0))
	cv.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = cv
	p.color_ramp = _rampa(el[0], el[1])
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	q.material = _mat_brilho()
	p.mesh = q
	p.visibility_range_end = 90.0
	c.add_child(p)


static func _rampa(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(a.r, a.g, a.b, 0.9))
	g.set_color(1, Color(b.r, b.g, b.b, 0.0))
	return g


static var _brilho: StandardMaterial3D


static func _mat_brilho() -> StandardMaterial3D:
	if _brilho != null:
		return _brilho
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	_brilho = StandardMaterial3D.new()
	_brilho.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_brilho.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_brilho.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_brilho.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_brilho.vertex_color_use_as_albedo = true
	_brilho.albedo_texture = t
	return _brilho


# golpe de habilidade a cada ~6 s: onda no chão que se abre e explosão do elemento
static func _habilidade(c: Node3D, el: Array) -> void:
	var anel := MeshInstance3D.new()
	anel.name = "OndaHabilidade"
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.0
	tor.rings = 32
	anel.mesh = tor
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(el[0].r, el[0].g, el[0].b, 0.0)
	anel.material_override = m
	anel.position = Vector3(0, 0.05, 0)
	anel.scale = Vector3(0.2, 0.3, 0.2)
	c.add_child(anel)
	var est := CPUParticles3D.new()
	est.name = "ExplosaoHabilidade"
	est.amount = 60
	est.lifetime = 1.0
	est.one_shot = true
	est.emitting = false
	est.explosiveness = 0.9
	est.local_coords = false
	est.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	est.emission_ring_axis = Vector3.UP
	est.emission_ring_radius = 0.8
	est.emission_ring_inner_radius = 0.3
	est.emission_ring_height = 0.1
	est.direction = Vector3.UP
	est.spread = 40.0
	est.gravity = Vector3(0, -3.0, 0)
	est.initial_velocity_min = 2.0
	est.initial_velocity_max = 4.5
	est.color_ramp = _rampa(el[0], el[1])
	var q := QuadMesh.new()
	q.size = Vector2(0.25, 0.25)
	q.material = _mat_brilho()
	est.mesh = q
	c.add_child(est)
	var tw := c.create_tween().set_loops()
	tw.tween_interval(4.5)
	tw.tween_callback(func() -> void:
		est.restart()
		anel.scale = Vector3(0.2, 0.3, 0.2)
		m.albedo_color.a = 0.9)
	tw.tween_property(anel, "scale", Vector3(4.0, 0.3, 4.0), 0.9).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.9)
