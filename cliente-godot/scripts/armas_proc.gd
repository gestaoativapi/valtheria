class_name ArmasProc
extends RefCounted
# Armas montadas por código (sem modelo pago): o cajado e o cetro deixam de usar a lança.
# Convenção das armas do jogo: origem no ponto da mão, a arma segue +Z, o cabo vai para -Z (metros).


static func _mat(cor: Color, metal := 0.0, rug := 0.7, emissao := Color.BLACK, energia := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.metallic = metal
	m.roughness = rug
	if energia > 0.0:
		m.emission_enabled = true
		m.emission = emissao
		m.emission_energy_multiplier = energia
	return m


static func _cil(pai: Node3D, z0: float, z1: float, r0: float, r1: float, mat: Material, lados := 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r0
	cm.top_radius = r1
	cm.height = absf(z1 - z0)
	cm.radial_segments = lados
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.rotation = Vector3(PI * 0.5, 0, 0)  # eixo Y do cilindro vira +Z
	mi.position = Vector3(0, 0, (z0 + z1) * 0.5)
	pai.add_child(mi)
	return mi


static func _anel(pai: Node3D, z: float, r: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.78
	tm.outer_radius = r * 1.25
	tm.rings = 16
	tm.ring_segments = 6
	mi.mesh = tm
	mi.material_override = mat
	mi.rotation = Vector3(PI * 0.5, 0, 0)
	mi.position = Vector3(0, 0, z)
	pai.add_child(mi)


# cajado de mago: haste de madeira escura que afina para baixo, anéis de bronze, garras curvas segurando um cristal
# (curto = cetro de uma mão). length e at em metros, já na escala de quem usa.
static func cajado(length: float, at: float, curto := false) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Cetro" if curto else "Cajado"
	var madeira := _mat(Color(0.27, 0.18, 0.11), 0.0, 0.82)
	var madeira2 := _mat(Color(0.2, 0.13, 0.08), 0.0, 0.85)
	var bronze := _mat(Color(0.55, 0.42, 0.24), 0.85, 0.42)
	var cristal := _mat(Color(0.62, 0.78, 0.92, 1.0), 0.1, 0.12, Color(0.45, 0.7, 1.0), 1.6)
	var z_pe := -at
	var z_topo := length - at
	var r := 0.018 * (length / 1.7) + 0.008
	var cabeca := 0.24 * length if not curto else 0.32 * length
	var z_cab := z_topo - cabeca
	_cil(raiz, z_pe, z_cab, r * 0.8, r * 1.15, madeira, 9)
	_cil(raiz, z_pe - 0.02, z_pe + 0.06, r * 0.75, r * 0.95, bronze, 8)  # ponteira
	# empunhadura com tiras de couro e anéis
	_cil(raiz, -0.09, 0.11, r * 1.28, r * 1.28, madeira2, 9)
	for z in [-0.1, 0.12, z_cab - 0.02]:
		_anel(raiz, z, r * 1.25, bronze)
	# colar da cabeça
	_cil(raiz, z_cab - 0.03, z_cab + 0.05, r * 1.15, r * 1.6, bronze, 10)
	# garras: quatro hastes curvas que se abrem e fecham em volta do cristal
	var rc := cabeca * 0.24
	var zc := z_cab + cabeca * 0.55
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var lado := Vector3(cos(a), sin(a), 0)
		var pontos := [Vector3(0, 0, z_cab + 0.04), lado * rc * 0.9 + Vector3(0, 0, z_cab + cabeca * 0.28),
			lado * rc * 1.25 + Vector3(0, 0, zc), lado * rc * 0.55 + Vector3(0, 0, z_topo)]
		for j in 3:
			var p0: Vector3 = pontos[j]
			var p1: Vector3 = pontos[j + 1]
			var seg := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.bottom_radius = r * (0.75 - 0.18 * j)
			cm.top_radius = r * (0.6 - 0.18 * j)
			cm.height = p0.distance_to(p1)
			cm.radial_segments = 6
			cm.rings = 1
			seg.mesh = cm
			seg.material_override = madeira
			raiz.add_child(seg)
			var d := (p1 - p0).normalized()
			var eixo := Vector3.UP.cross(d)
			seg.transform = Transform3D(Basis(eixo.normalized(), Vector3.UP.angle_to(d)) if eixo.length() > 0.001 else Basis.IDENTITY, (p0 + p1) * 0.5)
	# cristal: dois cones (losango alongado) e um brilho interno
	var cri := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = rc * 0.72
	sm.height = rc * 2.2
	sm.radial_segments = 6
	sm.rings = 3
	cri.mesh = sm
	cri.material_override = cristal
	cri.rotation = Vector3(PI * 0.5, 0, 0)
	cri.position = Vector3(0, 0, zc)
	cri.name = "Foco"
	raiz.add_child(cri)
	return raiz
