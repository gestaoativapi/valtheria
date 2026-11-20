extends RefCounted
const Arq = preload("res://scripts/arquitetura.gd")
# Casas élficas (decisão D8 de Robson, 18/11: primeira vila de raça = élfica, em Sylvar).
# Casa redonda sobre base de mármore claro, paredes de madeira clara com nervuras de árvore viva,
# telhado em folha (cúpula pontuda) verde-prata com anel dourado, janelas redondas acesas,
# porta em arco e poste de cristal. Cada peça é desenhada em lote (uma MultiMesh por peça para
# todas as casas da vila): leve para o computador.

static var _malhas := {}


static func _mat(c: Color, rough := 0.8, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


static func _torno(perfil: Array, lados := 24) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in perfil.size() - 1:
		var a: Vector2 = perfil[i]
		var b: Vector2 = perfil[i + 1]
		for k in lados:
			var t0 := TAU * k / lados
			var t1 := TAU * (k + 1) / lados
			var p00 := Vector3(sin(t0) * a.x, a.y, cos(t0) * a.x)
			var p01 := Vector3(sin(t1) * a.x, a.y, cos(t1) * a.x)
			var p10 := Vector3(sin(t0) * b.x, b.y, cos(t0) * b.x)
			var p11 := Vector3(sin(t1) * b.x, b.y, cos(t1) * b.x)
			for p in [p00, p10, p01, p01, p10, p11]:
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


static func _pecas() -> Array:
	# [malha, material, Transform3D local] em metros, casa de 6 m de altura até a ponta do telhado
	if _malhas.has("pecas"):
		return _malhas.pecas
	var marmore := Arq.material("pedra", Color(0.88, 0.87, 0.83), {"bloco": Vector2(1.2, 0.55), "rugosidade": 0.45, "variacao": 0.1, "desgaste": 0.2})
	var madeira := Arq.material("madeira", Color(0.86, 0.8, 0.68), {"variacao": 0.14, "desgaste": 0.15})
	var nervura := _mat(Color(0.78, 0.72, 0.6), 0.85)
	var telhado := Arq.material("telha", Color(0.36, 0.55, 0.5), {"bloco": Vector2(0.3, 0.2), "rugosidade": 0.5, "metalico": 0.25, "desgaste": 0.15})
	var ouro := _mat(Color(0.84, 0.72, 0.44), 0.35, 0.0, 0.7)
	var janela := _mat(Color(1.0, 0.88, 0.6), 0.4, 1.4)
	var porta := _mat(Color(0.42, 0.3, 0.2), 0.7)
	var cristal := _mat(Color(0.6, 0.9, 1.0), 0.15, 2.0)
	var folha := _mat(Color(0.3, 0.5, 0.26), 0.9)
	var p: Array = []
	var base := CylinderMesh.new()
	base.top_radius = 2.9
	base.bottom_radius = 3.1
	base.height = 0.5
	base.radial_segments = 24
	p.append([base, marmore, Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0))])
	var parede := CylinderMesh.new()
	parede.top_radius = 2.15
	parede.bottom_radius = 2.4
	parede.height = 3.0
	parede.radial_segments = 24
	p.append([parede, madeira, Transform3D(Basis.IDENTITY, Vector3(0, 1.9, 0))])
	# nervuras de árvore viva subindo pela parede e curvando para o telhado
	var nerv := CylinderMesh.new()
	nerv.top_radius = 0.07
	nerv.bottom_radius = 0.13
	nerv.height = 3.4
	nerv.radial_segments = 6
	for k in 8:
		var a := TAU * k / 8.0
		p.append([nerv, nervura, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.08), Vector3(sin(a) * 2.32, 1.9, cos(a) * 2.32))])
	# telhado em folha: cúpula que sobe em ponta, com beiral largo
	var teto := _torno([Vector2(0.0, 3.2), Vector2(3.1, 3.25), Vector2(3.0, 3.55), Vector2(2.55, 4.4), Vector2(1.85, 5.25), Vector2(1.05, 6.05), Vector2(0.45, 6.75), Vector2(0.12, 7.35), Vector2(0.0, 7.7)], 24)
	p.append([teto, telhado, Transform3D.IDENTITY])
	var anel := TorusMesh.new()
	anel.inner_radius = 2.95
	anel.outer_radius = 3.15
	anel.rings = 24
	anel.ring_segments = 6
	p.append([anel, ouro, Transform3D(Basis.IDENTITY, Vector3(0, 3.38, 0))])
	var ponta := CylinderMesh.new()
	ponta.top_radius = 0.0
	ponta.bottom_radius = 0.09
	ponta.height = 1.1
	ponta.radial_segments = 6
	p.append([ponta, ouro, Transform3D(Basis.IDENTITY, Vector3(0, 8.1, 0))])
	# janelas redondas acesas (3) e porta em arco (frente = +Z)
	var jan := CylinderMesh.new()
	jan.top_radius = 0.38
	jan.bottom_radius = 0.38
	jan.height = 0.08
	jan.radial_segments = 14
	for a in [1.3, PI, -1.3]:
		p.append([jan, janela, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(sin(a) * 2.3, 2.3, cos(a) * 2.3))])
	var aro := TorusMesh.new()
	aro.inner_radius = 0.38
	aro.outer_radius = 0.48
	aro.rings = 14
	aro.ring_segments = 5
	for a in [1.3, PI, -1.3]:
		p.append([aro, ouro, Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(sin(a) * 2.33, 2.3, cos(a) * 2.33))])
	var pt := BoxMesh.new()
	pt.size = Vector3(1.1, 1.7, 0.2)
	p.append([pt, porta, Transform3D(Basis.IDENTITY, Vector3(0, 1.25, 2.36))])
	var arco := CylinderMesh.new()
	arco.top_radius = 0.55
	arco.bottom_radius = 0.55
	arco.height = 0.2
	arco.radial_segments = 14
	p.append([arco, porta, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 2.1, 2.36))])
	var moldura := TorusMesh.new()
	moldura.inner_radius = 0.55
	moldura.outer_radius = 0.68
	moldura.rings = 16
	moldura.ring_segments = 5
	p.append([moldura, ouro, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 2.1, 2.4))])
	# poste de cristal ao lado da porta
	var poste := CylinderMesh.new()
	poste.top_radius = 0.05
	poste.bottom_radius = 0.08
	poste.height = 2.2
	poste.radial_segments = 6
	p.append([poste, nervura, Transform3D(Basis.IDENTITY, Vector3(1.6, 1.1, 3.2))])
	var cr := CylinderMesh.new()
	cr.top_radius = 0.0
	cr.bottom_radius = 0.16
	cr.height = 0.5
	cr.radial_segments = 5
	p.append([cr, cristal, Transform3D(Basis.IDENTITY, Vector3(1.6, 2.45, 3.2))])
	p.append([cr, cristal, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(1.6, 2.1, 3.2))])
	# trepadeira em volta da base do telhado
	var hera := TorusMesh.new()
	hera.inner_radius = 2.25
	hera.outer_radius = 2.45
	hera.rings = 20
	hera.ring_segments = 5
	p.append([hera, folha, Transform3D(Basis.from_euler(Vector3(0.06, 0, 0.04)), Vector3(0, 3.05, 0))])
	_malhas.pecas = p
	return p


# pts: Transform3D no mundo (como em world.place); altura = altura da casa até a ponta
static func casas(w: Node3D, root: Node3D, pts: Array, altura := 7.0, vis_end := 900.0, bloquear := true) -> void:
	if pts.is_empty():
		return
	var k := altura / 8.6
	var inv := root.global_transform.affine_inverse() if root.is_inside_tree() else Transform3D(Basis.IDENTITY, -root.position)
	for peca in _pecas():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = peca[0]
		mm.instance_count = pts.size()
		for i in pts.size():
			mm.set_instance_transform(i, inv * (pts[i] as Transform3D) * Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO) * (peca[2] as Transform3D))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = peca[1]
		mi.visibility_range_end = vis_end
		if peca[1] is StandardMaterial3D and (peca[1] as StandardMaterial3D).emission_enabled:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	for t in (pts if bloquear else []):
		var o: Vector3 = (t as Transform3D).origin
		w.block(o.x, o.z, 3.1 * k)
