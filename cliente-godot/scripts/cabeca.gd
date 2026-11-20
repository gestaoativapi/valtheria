extends RefCounted
# Encaixe automático do que vai na cabeça (20/11, Robson: "capacetes e acessórios moldem o que fica sobre a
# cabeça... coroas, acessórios especiais... que se moldem perfeitamente a cada raça").
#
# Como funciona: depois que o corpo da raça está pronto (morfos de rosto, focinho, orelhas, proporções), o crânio
# é MEDIDO nos próprios vértices da malha: topo, largura, nuca e altura da testa. Isso vira uma "cabeça unitária"
# (esfera de raio 1 no centro do crânio, frente = +Z, topo = +Y). Todo item de cabeça é modelado UMA vez nesse
# espaço unitário e o jogo o estica para a cabeça de quem usa — anão, gigante, orc, elfo, homem-fera, dragonita.
# Item novo (coroa, tiara, chifre decorativo...): basta montar o Node3D no espaço unitário e chamar
# personagem.vestir_cabeca(no, esconde_cabelo).
#
# Itens prontos (slot "elmo"): elmo_pesada = elmo de metal com nasal e jugulares; elmo_leve = capuz de pano
# (ajustado à cabeça, com abertura do rosto); elmo_robe = chapéu arcano de aba larga; coroa_* = coroa.

static var _cache := {}


# mede o crânio em repouso. Devolve {centro: Vector3 (espaço do esqueleto), raio: Vector3, testa: float}
static func medir(skel: Skeleton3D) -> Dictionary:
	var hb := skel.find_bone("Head")
	if hb < 0:
		hb = skel.find_bone("head")
	if hb < 0:
		return {}
	var cabeca := skel.get_bone_global_rest(hb).origin
	var pesc := skel.find_bone("neck_01")
	var y_pesc := skel.get_bone_global_rest(pesc).origin.y if pesc >= 0 else cabeca.y - 0.1
	var pts: Array = []
	for m in skel.find_children("*", "MeshInstance3D", false, false):
		var nm := String(m.name).to_lower()
		if not (m as Node3D).visible or nm.contains("hood") or nm.begins_with("ca_") or nm.contains("hair") or nm.contains("barba") or nm.contains("beard") or nm.contains("cilio") or nm.contains("sobrancelha"):
			continue
		var mesh: Mesh = (m as MeshInstance3D).mesh
		if mesh == null or not (mesh is ArrayMesh):
			continue
		for si in mesh.get_surface_count():
			var arr := (mesh as ArrayMesh).surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in vs:
				if v.y > cabeca.y - 0.02 and absf(v.x - cabeca.x) < 0.2 and absf(v.z - cabeca.z) < 0.25:
					pts.append(v)
	if pts.size() < 20:
		return {"centro": cabeca + Vector3(0, 0.1, 0.02), "raio": Vector3(0.1, 0.12, 0.115), "testa": 0.0}
	# topo pela linha do meio da cabeça (chifres, orelhas e juba ficam de fora) e larguras por percentil
	var meio: Array = []
	for p in pts:
		if absf(p.x - cabeca.x) < 0.04 and absf(p.z - cabeca.z) < 0.1:
			meio.append(p.y)
	meio.sort()
	var topo: float = meio[int(meio.size() * 0.97)] if meio.size() > 5 else cabeca.y + 0.18
	var lados: Array = []
	var nucas: Array = []
	for p in pts:
		if p.y > topo - 0.11 and p.y < topo - 0.03:
			lados.append(absf(p.x - cabeca.x))
			if absf(p.x - cabeca.x) < 0.05:
				nucas.append(p.z)
	lados.sort()
	nucas.sort()
	var lado: float = lados[int(lados.size() * 0.9)] if lados.size() > 5 else 0.09
	var nuca: float = nucas[int(nucas.size() * 0.08)] if nucas.size() > 3 else cabeca.z - 0.1
	var rx := clampf(lado + 0.012, 0.07, 0.2)
	var ry := clampf((topo - y_pesc) * 0.55, 0.08, 0.2)
	var rz := rx * 1.12
	var centro := Vector3(cabeca.x, topo - ry, nuca + rz)
	return {"centro": centro, "raio": Vector3(rx, ry, rz)}


# nó de encaixe preso ao osso da cabeça: tudo que for posto nele está em "cabeça unitária"
static func encaixe(c: Node3D) -> Node3D:
	var skel: Skeleton3D = c.skel
	if skel == null:
		return null
	var hb := skel.find_bone("Head")
	if hb < 0:
		hb = skel.find_bone("head")
	if hb < 0:
		return null
	var med := medir(skel)
	if med.is_empty():
		return null
	var att := BoneAttachment3D.new()
	att.name = "EncaixeCabeca"
	att.bone_name = skel.get_bone_name(hb)
	skel.add_child(att)
	var no := Node3D.new()
	no.name = "CabecaUnitaria"
	att.add_child(no)
	no.transform = skel.get_bone_global_rest(hb).affine_inverse() * Transform3D(Basis.from_scale(med.raio), med.centro)
	return no


# ---------- itens prontos, modelados na cabeça unitária ----------

static func _mat(cor: Color, metal := 0.0, rug := 0.6, dois_lados := false) -> StandardMaterial3D:
	var k := "%s%.2f%.2f%s" % [cor.to_html(), metal, rug, dois_lados]
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.metallic = metal
	m.roughness = rug
	if dois_lados:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[k] = m
	return m


# casca de esfera recortada: theta (0 = topo) até theta_max, pulando a abertura do rosto quando pedido
static func _casca(raio: float, theta_max: float, rosto_aberto: float, mat: Material, seg := 28, aneis := 14) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in aneis:
		var t0 := theta_max * float(i) / aneis
		var t1 := theta_max * float(i + 1) / aneis
		for j in seg:
			var p0 := TAU * float(j) / seg
			var p1 := TAU * float(j + 1) / seg
			var meio := (p0 + p1) * 0.5
			# rosto: frente (+Z) é phi = 0; abre um oval da testa até o queixo
			if rosto_aberto > 0.0 and t0 > 0.55 and absf(wrapf(meio, -PI, PI)) < rosto_aberto * (1.0 - 0.25 * clampf((t0 - 1.2) / 0.8, 0.0, 1.0)):
				continue
			var q := [[t0, p0], [t1, p0], [t1, p1], [t0, p1]]
			var v: Array = []
			for a in q:
				v.append(Vector3(sin(a[0]) * sin(a[1]), cos(a[0]), sin(a[0]) * cos(a[1])) * raio)
			for idx in [0, 1, 2, 0, 2, 3]:
				var p: Vector3 = v[idx]
				st.set_normal(p.normalized())
				st.add_vertex(p)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	if mat is StandardMaterial3D and (mat as StandardMaterial3D).cull_mode != BaseMaterial3D.CULL_DISABLED:
		mat = (mat as StandardMaterial3D).duplicate()
		(mat as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED  # casca vista por fora e por dentro
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


static func _peca(no: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, esc := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = esc
	no.add_child(mi)


# elmo de metal: calota, aro na testa, nasal e jugulares; grau muda o metal
static func elmo(grau := 0) -> Node3D:
	var n := Node3D.new()
	var metal: Color = [Color(0.42, 0.43, 0.46), Color(0.55, 0.42, 0.28), Color(0.62, 0.64, 0.68), Color(0.7, 0.72, 0.76), Color(0.74, 0.62, 0.38)][clampi(grau, 0, 4)]
	var m := _mat(metal, 0.85, 0.35)
	var esc := _mat(metal.darkened(0.35), 0.8, 0.45)
	n.add_child(_casca(1.13, 1.62, 0.95, m))
	var aro := TorusMesh.new()
	aro.inner_radius = 1.08
	aro.outer_radius = 1.2
	aro.rings = 28
	aro.ring_segments = 6
	_peca(n, aro, esc, Vector3(0, 0.02, 0.0), Vector3.ZERO, Vector3(1, 0.6, 1))
	var crista := BoxMesh.new()
	crista.size = Vector3(0.08, 0.22, 1.9)
	_peca(n, crista, esc, Vector3(0, 0.98, -0.1), Vector3(-0.15, 0, 0))
	var nasal := BoxMesh.new()
	nasal.size = Vector3(0.16, 0.85, 0.08)
	_peca(n, nasal, m, Vector3(0, -0.25, 1.16), Vector3(-0.12, 0, 0))
	for s in [-1.0, 1.0]:
		var jug := BoxMesh.new()
		jug.size = Vector3(0.08, 0.95, 0.65)
		_peca(n, jug, m, Vector3(s * 1.05, -0.55, 0.5), Vector3(0.1, s * 0.35, 0))
	return n


# capuz de pano: cobre crânio, nuca e lados, abertura oval do rosto, borda caindo nos ombros
static func capuz(cor := Color(0.24, 0.36, 0.2)) -> Node3D:
	var n := Node3D.new()
	var m := _mat(cor, 0.0, 0.95, true)
	var c := _casca(1.2, 2.25, 0.82, m, 30, 16)
	c.scale = Vector3(1.0, 1.05, 1.08)
	c.position = Vector3(0, 0.04, -0.06)
	n.add_child(c)
	# ponta do capuz caída para trás
	var ponta := CylinderMesh.new()
	ponta.top_radius = 0.0
	ponta.bottom_radius = 0.42
	ponta.height = 0.9
	ponta.radial_segments = 10
	_peca(n, ponta, m, Vector3(0, 0.55, -1.15), Vector3(-2.2, 0, 0))
	return n


# chapéu arcano: aba larga e copa pontuda dobrada para trás, faixa com pedra
static func chapeu(cor := Color(0.22, 0.2, 0.42)) -> Node3D:
	var n := Node3D.new()
	var m := _mat(cor, 0.0, 0.85, true)
	var aba := CylinderMesh.new()
	aba.top_radius = 2.0
	aba.bottom_radius = 2.05
	aba.height = 0.06
	aba.radial_segments = 28
	_peca(n, aba, m, Vector3(0, 0.45, 0))
	var copa := CylinderMesh.new()
	copa.top_radius = 0.05
	copa.bottom_radius = 1.08
	copa.height = 2.0
	copa.radial_segments = 20
	_peca(n, copa, m, Vector3(0, 1.35, -0.18), Vector3(-0.22, 0, 0))
	var faixa := CylinderMesh.new()
	faixa.top_radius = 1.06
	faixa.bottom_radius = 1.1
	faixa.height = 0.22
	faixa.radial_segments = 20
	_peca(n, faixa, _mat(Color(0.62, 0.48, 0.22), 0.6, 0.4), Vector3(0, 0.6, -0.02))
	var pedra := SphereMesh.new()
	pedra.radius = 0.13
	pedra.height = 0.26
	var mp := _mat(Color(0.35, 0.75, 1.0), 0.1, 0.15)
	mp.emission_enabled = true
	mp.emission = Color(0.3, 0.7, 1.0)
	mp.emission_energy_multiplier = 0.8
	_peca(n, pedra, mp, Vector3(0, 0.6, 1.1))
	return n


# coroa: aro de ouro na altura da testa com pontas e gemas
static func coroa(cor := Color(0.86, 0.68, 0.3)) -> Node3D:
	var n := Node3D.new()
	var ouro := _mat(cor, 0.95, 0.25)
	var aro := CylinderMesh.new()
	aro.top_radius = 1.04
	aro.bottom_radius = 1.0
	aro.height = 0.3
	aro.radial_segments = 32
	aro.cap_top = false
	aro.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = aro
	mi.material_override = _mat(cor, 0.95, 0.25, true)
	mi.position = Vector3(0, 0.55, 0)
	n.add_child(mi)
	var gema := _mat(Color(0.75, 0.1, 0.15), 0.1, 0.1)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var pt := PrismMesh.new()
		pt.size = Vector3(0.32, 0.42 if i % 2 == 0 else 0.28, 0.06)
		_peca(n, pt, ouro, Vector3(sin(a) * 1.03, 0.9 if i % 2 == 0 else 0.83, cos(a) * 1.03), Vector3(0, a, 0))
		if i % 2 == 0:
			var g := SphereMesh.new()
			g.radius = 0.07
			g.height = 0.14
			_peca(n, g, gema, Vector3(sin(a) * 1.07, 0.55, cos(a) * 1.07))
	return n


# item pelo id do slot "elmo"; devolve [nó, esconde_cabelo]
static func item(id: String) -> Array:
	var grau := 0
	for g in ["_d", "_c", "_b", "_a", "_s"]:
		if id.ends_with(g):
			grau = ["_d", "_c", "_b", "_a", "_s"].find(g) + 1
	if id.begins_with("coroa"):
		return [coroa(), false]
	if id.begins_with("elmo_pesada"):
		return [elmo(clampi(grau, 0, 4)), true]
	if id.begins_with("elmo_leve"):
		return [capuz([Color(0.24, 0.36, 0.2), Color(0.36, 0.26, 0.16), Color(0.2, 0.26, 0.34), Color(0.3, 0.3, 0.3), Color(0.4, 0.12, 0.12), Color(0.1, 0.1, 0.12)][grau % 6]), true]
	if id.begins_with("elmo_robe"):
		return [chapeu(), true]
	return [null, false]
