extends RefCounted
# Enfeites por grau (pedido de Robson 21/11): do NG ao SS a arma e a armadura ficam cada vez mais
# trabalhadas e mostram mais poder. Tudo é feito com peças simples presas ao modelo (sem arquivo novo),
# na cor do grau, e só os graus altos ganham brilho e partículas (o NG fica como sempre foi).
#   arma:   D anel no pomo · C anel na empunhadura · B gema acesa · A runas acesas no fio e 2ª gema ·
#           S halo de runas e faíscas subindo · SS coroa de luz e aura forte
#   roupa:  C ombreiras de metal · B emblema aceso no peito · A espinhos nas ombreiras e cinto de runas ·
#           S capa · SS capa com borda de luz e aura nos pés

const GRAUS := ["ng", "d", "c", "b", "a", "s", "ss"]
const COR := [Color(0.6, 0.6, 0.62), Color(0.8, 0.52, 0.28), Color(0.88, 0.9, 0.94), Color(0.45, 0.62, 0.95), Color(0.85, 0.25, 0.2), Color(1.0, 0.82, 0.42), Color(1.0, 0.95, 0.8)]
const BRILHO := [Color(0, 0, 0), Color(0, 0, 0), Color(0.7, 0.85, 1.0), Color(0.35, 0.65, 1.0), Color(1.0, 0.35, 0.2), Color(1.0, 0.8, 0.35), Color(1.0, 0.92, 0.6)]
static var _mats := {}


static func indice(id: String) -> int:
	if id.begins_with("lend_") or id.begins_with("set_"):
		return 6
	var g := id.get_slice("_", id.get_slice_count("_") - 1)
	return GRAUS.find(g) if g in GRAUS else 0


static func _metal(n: int) -> StandardMaterial3D:
	var k := "metal%d" % n
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = COR[n]
		m.metallic = 0.85
		m.roughness = 0.3
		_mats[k] = m
	return _mats[k]


static func _luz(n: int, forca := 2.2) -> StandardMaterial3D:
	var k := "luz%d_%s" % [n, forca]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = BRILHO[n]
		m.emission_enabled = true
		m.emission = BRILHO[n]
		m.emission_energy_multiplier = forca
		m.roughness = 0.2
		_mats[k] = m
	return _mats[k]


static func _pano(n: int) -> StandardMaterial3D:
	var k := "pano%d" % n
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = [Color(0.3, 0.22, 0.15), Color(0.3, 0.22, 0.15), Color(0.32, 0.33, 0.36), Color(0.14, 0.2, 0.42), Color(0.42, 0.06, 0.08), Color(0.36, 0.05, 0.09), Color(0.88, 0.86, 0.8)][n]
		m.roughness = 0.9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[k] = m
	return _mats[k]


static func _peca(pai: Node3D, malha: Mesh, mat: Material, pos: Vector3, base := Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(base, pos)
	pai.add_child(mi)
	return mi


static func _esfera(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _anel(r: float, esp: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = r
	t.outer_radius = r + esp
	t.rings = 18
	t.ring_segments = 6
	return t


static func _faiscas(pai: Node3D, n: int, pos: Vector3, caixa: Vector3, qtd: int, sobe := 0.35) -> void:
	var p := CPUParticles3D.new()
	p.amount = qtd
	p.lifetime = 1.1
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = caixa
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, sobe, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.025)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = BRILHO[n]
	m.disable_fog = true
	q.material = m
	p.mesh = q
	p.local_coords = false
	p.position = pos
	p.visibility_range_end = 40.0
	pai.add_child(p)


# ---------- arma ----------
# acha o eixo da arma pelo próprio modelo: a ponta é o lado mais longe da mão (origem do nó)
static func arma(w: Node3D, n: int, kind: String) -> void:
	if w == null or n <= 0:
		return
	var bb := AABB()
	var primeiro := true
	for m in w.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = (_rel(w, mi)) * mi.get_aabb()
		bb = b if primeiro else bb.merge(b)
		primeiro = false
	if primeiro:
		return
	var tam := bb.size
	var ord := [0, 1, 2]
	ord.sort_custom(func(a, b): return tam[a] > tam[b])
	var lg: int = ord[0]
	var md: int = ord[1]
	var fn: int = ord[2]
	var c := bb.get_center()
	var sinal := 1.0 if c[lg] >= 0.0 else -1.0
	var eixo := Vector3.ZERO
	eixo[lg] = sinal
	var lado := Vector3.ZERO
	lado[md] = 1.0
	var face := Vector3.ZERO
	face[fn] = 1.0
	var L := tam[lg]
	var larg := maxf(tam[md], 0.02)
	var base_c := c
	base_c[lg] = 0.0
	var ponta := base_c + eixo * (absf(c[lg]) + L * 0.5)
	var cabo := base_c + eixo * (absf(c[lg]) - L * 0.5)
	var lamina := kind in ["espada", "espadao", "adaga", "punhal", "duplas"]
	var cabeca := kind in ["cajado", "cetro", "lanca", "machado", "martelo"]
	var guarda := base_c + eixo * (L * 0.09 if lamina else 0.0)
	var foco := ponta - eixo * L * 0.08 if cabeca else (guarda if lamina else base_c)
	var giro := Basis.looking_at(eixo, face if absf(face.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT)
	# D: anel no pomo (ou na empunhadura do arco)
	var r_anel := clampf(larg * 0.22, 0.012, 0.05)
	_peca(w, _anel(r_anel, r_anel * 0.45), _metal(n), (cabo + eixo * L * 0.02) if kind != "arco" else base_c, giro * Basis(Vector3.RIGHT, PI * 0.5))
	if n >= 2:
		# C: segundo anel, na empunhadura (cabo envolto em metal)
		_peca(w, _anel(r_anel * 0.9, r_anel * 0.4), _metal(n), (cabo + base_c) * 0.5 if kind != "arco" else base_c + eixo * L * 0.06, giro * Basis(Vector3.RIGHT, PI * 0.5))
	if n >= 3:
		# B: gema acesa (na guarda ou na cabeça da arma)
		_peca(w, _esfera(clampf(larg * 0.16, 0.012, 0.045) * (1.0 + 0.12 * (n - 3))), _luz(n, 2.4), foco + face * tam[fn] * 0.3)
	if n >= 4:
		# A: segunda gema no pomo e runas acesas ao longo do fio (ou da haste)
		_peca(w, _esfera(clampf(larg * 0.11, 0.01, 0.03)), _luz(n, 2.0), cabo + eixo * L * 0.02)
		var fio := BoxMesh.new()
		var comp := L * (0.6 if lamina else 0.35)
		fio.size = Vector3(0.006, 0.006, comp)
		var meio := (guarda + eixo * comp * 0.55) if lamina else (ponta - eixo * comp * 0.7)
		for s in [-1.0, 1.0]:
			_peca(w, fio, _luz(n, 1.6), meio + face * s * (tam[fn] * 0.5 + 0.003), giro)
	if n >= 5:
		# S: halo de runas em volta da arma e faíscas subindo
		_peca(w, _anel(larg * 0.75, 0.008), _luz(n, 2.6), foco + eixo * L * 0.06, giro * Basis(Vector3.RIGHT, PI * 0.5))
		_faiscas(w, n, (guarda + ponta) * 0.5, Vector3(larg * 0.3, larg * 0.3, L * 0.3), 14 if n == 5 else 28)
	if n >= 6:
		# SS: coroa de luz na ponta
		_peca(w, _esfera(larg * 0.32), _luz(n, 3.2), ponta - eixo * L * 0.03)


static func _rel(raiz: Node3D, filho: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = filho
	while n != null and n != raiz:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


# ---------- roupa ----------
# prende uma peça num osso, no ponto pedido (coordenadas do personagem, pose de descanso); depois ela acompanha o osso
static func _preso(ch: Node3D, sk: Skeleton3D, osso: String, ponto: Vector3) -> Node3D:
	var b := sk.find_bone(osso)
	if b < 0:
		return null
	var at := BoneAttachment3D.new()
	at.bone_name = osso
	sk.add_child(at)
	var tb: Transform3D = _rel(ch, sk) * sk.get_bone_global_rest(b)
	var no := Node3D.new()
	at.add_child(no)
	no.transform = tb.affine_inverse() * Transform3D(Basis.IDENTITY, ponto)
	return no


static func roupa(ch: Node3D, sk: Skeleton3D, n: int, tipo: String) -> void:
	if sk == null or n < 2:
		return
	var h: float = ch.height_m
	var o := Vector3.ZERO  # coordenadas do próprio personagem (ainda fora da cena quando é criado)
	var fr := Vector3(0, 0, 1)   # frente do personagem
	var dr := Vector3(1, 0, 0)
	var pesada := tipo == "pesada"
	var leve := tipo == "leve"
	# C: ombreiras (metal na pesada, couro reforçado na leve; a túnica ganha gola com broches)
	if pesada or leve:
		var esc: float = (0.078 if pesada else 0.06) * (1.0 + 0.14 * (n - 2)) * h / 1.8
		for s in [-1.0, 1.0]:
			var p: Vector3 = o + Vector3.UP * h * 0.795 + dr * s * h * 0.128
			var no := _preso(ch, sk, "clavicle_l" if s > 0 else "clavicle_r", p)
			if no == null:
				continue
			var cupula := _esfera(esc)
			cupula.is_hemisphere = true
			cupula.height = esc
			_peca(no, cupula, _metal(n), Vector3.DOWN * esc * 0.25).scale = Vector3(1.1, 0.95, 1.2)
			if n >= 4 and pesada:  # A: espinhos
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = esc * 0.28
				cone.height = esc * (1.1 + 0.25 * (n - 4))
				cone.radial_segments = 8
				_peca(no, cone, _metal(n), Vector3.UP * esc * 0.45)
	if n >= 3:
		# B: emblema aceso no peito (disco de metal com gema)
		var p := o + Vector3.UP * h * 0.72 + fr * h * 0.075
		var no := _preso(ch, sk, "spine_03", p)
		if no != null:
			var disco := CylinderMesh.new()
			disco.top_radius = 0.035 * (1.0 + 0.15 * (n - 3))
			disco.bottom_radius = disco.top_radius
			disco.height = 0.012
			disco.radial_segments = 16
			_peca(no, disco, _metal(n), Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5))
			_peca(no, _esfera(disco.top_radius * 0.45), _luz(n, 2.2), fr * 0.008)
	if n >= 4:
		# A: cinto de runas acesas na cintura
		var p := o + Vector3.UP * h * 0.56
		var no := _preso(ch, sk, "pelvis", p)
		if no != null:
			var cinto := _anel(h * 0.095, 0.01)
			_peca(no, cinto, _luz(n, 1.4), Vector3.ZERO).scale = Vector3(1.0, 1.0, 0.75)
	if n >= 5:
		# S: capa presa às costas; SS: capa maior com borda de luz e aura nos pés
		# a capa fica presa ao corpo (não ao osso da coluna, que gira na postura e deixava a capa de lado)
		var no := Node3D.new()
		no.position = o + Vector3.UP * h * 0.8 - fr * h * 0.085
		ch.add_child(no)
		if no != null:
			# a capa pende da borda de cima, um pouco afastada das pernas
			var pivo: Node3D = load("res://scripts/pano_balanco.gd").new()
			pivo.rotation = Vector3(0.16, 0, 0)
			var larg_c := h * (0.26 if n == 5 else 0.32)
			var alt_c := h * (0.56 if n == 5 else 0.66)
			pivo.dono = ch
			pivo.altura = alt_c
			if sk != null and sk.find_bone("spine_03") >= 0:
				var ac := BoneAttachment3D.new()
				ac.bone_name = "spine_03"
				sk.add_child(ac)
				pivo.ancora = ac
			no.add_child(pivo)
			var capa := QuadMesh.new()
			capa.size = Vector2(larg_c, alt_c)
			_peca(pivo, capa, _pano(n), Vector3(0, -alt_c * 0.5, 0)).name = "Capa"
			if n >= 5:  # borda dourada (S) ou de luz (SS)
				var borda := BoxMesh.new()
				borda.size = Vector3(larg_c, 0.014, 0.006)
				_peca(pivo, borda, _luz(n, 2.0) if n >= 6 else _metal(5), Vector3(0, -alt_c + 0.007, 0))
				var gola := BoxMesh.new()
				gola.size = Vector3(larg_c * 1.05, 0.03, 0.03)
				_peca(pivo, gola, _metal(5), Vector3.ZERO)
		if n >= 6:
			_faiscas(ch, n, Vector3(0, 0.1, 0), Vector3(0.35, 0.05, 0.35), 20, 0.6)
