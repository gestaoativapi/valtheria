extends RefCounted
# Construções das cidades: calçamento de pedra, casas grandes lado a lado, chafarizes, jardins, igrejas,
# estátuas, palácio, Arena dos Heróis, porto com cais e barcos, farol, ponte de pedra.
# Tudo é feito de peças simples (caixas, prismas, cilindros) agrupadas por material, para pesar pouco.

const FX = preload("res://scripts/fx.gd")

const COBBLE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 base : source_color = vec3(0.56, 0.53, 0.49);
uniform float cell = 0.42;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
vec2 h2(vec2 p) { p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3))); return fract(sin(p) * 43758.5453); }
void fragment() {
	vec2 p = wp.xz / cell;
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = i;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = h2(i + g) * 0.8 + 0.1;
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; id = i + g; } else if (d < d2) { d2 = d; }
		}
	}
	float edge = smoothstep(0.015, 0.09, d2 - d1);
	float v = 0.8 + 0.32 * h2(id).x;
	float far = smoothstep(40.0, 120.0, length(wp - CAMERA_POSITION_WORLD));
	ALBEDO = base * mix(v * mix(0.42, 1.0, edge), 0.9, far);
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
"""

var w: Node3D  # mundo
var mats := {}
var lists := {}  # material -> [Transform3D] (caixas)
var prisms := {}  # material -> [Transform3D] (telhados)
var cyls := {}  # material -> [Transform3D] (colunas, torres)
var root: Node3D
var cx := 0.0
var cz := 0.0
var pave_rects: Array = []  # [x, z, meia largura, meio fundo, giro] (coordenadas da cidade)
var pave_discs: Array = []  # [x, z, raio]
var doors: Array = []  # portas que levam a interiores
var labels: Array = []


func _init(world: Node3D) -> void:
	w = world
	var sh := Shader.new()
	sh.code = COBBLE_SHADER
	var cob := ShaderMaterial.new()
	cob.shader = sh
	mats.calcada = cob
	var cob2 := ShaderMaterial.new()
	cob2.shader = sh
	cob2.set_shader_parameter("base", Color(0.66, 0.62, 0.56))
	cob2.set_shader_parameter("cell", 0.62)
	mats.praca = cob2
	mats.pedra = w._stone(Color(0.66, 0.64, 0.6))
	mats.base = w._stone(Color(0.5, 0.48, 0.46))
	mats.marmore = _plain(Color(0.9, 0.89, 0.85), 0.5)
	mats.cimento = _plain(Color(0.86, 0.82, 0.74), 0.92)
	mats.cimento2 = _plain(Color(0.78, 0.8, 0.82), 0.92)
	mats.cimento3 = _plain(Color(0.88, 0.78, 0.66), 0.92)
	mats.viga = _plain(Color(0.26, 0.17, 0.1), 0.85)
	mats.madeira = w._wood_mat()
	mats.telha = _plain(Color(0.58, 0.24, 0.16), 0.8)
	mats.ardosia = _plain(Color(0.24, 0.27, 0.32), 0.7)
	mats.telha_azul = _plain(Color(0.2, 0.32, 0.5), 0.7)
	mats.porta = _plain(Color(0.2, 0.12, 0.07), 0.8)
	mats.sebe = _plain(Color(0.2, 0.38, 0.14), 1.0)
	mats.terra = _plain(Color(0.3, 0.22, 0.14), 1.0)
	mats.bronze = _plain(Color(0.55, 0.42, 0.24), 0.35)
	mats.bronze.metallic = 0.85
	mats.ouro = _plain(Color(0.95, 0.75, 0.3), 0.3)
	mats.ouro.metallic = 0.9
	mats.areia = _plain(Color(0.86, 0.76, 0.55), 1.0)
	mats.pano = w._cloth_mat(Color(0.62, 0.12, 0.1))
	mats.pano_azul = w._cloth_mat(Color(0.16, 0.26, 0.6))
	mats.vela = w._cloth_mat(Color(0.92, 0.88, 0.78))
	mats.janela = w.window_mat
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.25, 0.5, 0.62, 0.78)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.05
	water.metallic = 0.3
	mats.agua = water


func _plain(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func begin(r: Node3D, x: float, z: float) -> void:
	root = r
	cx = x
	cz = z
	lists = {}
	prisms = {}
	cyls = {}
	pave_rects = []
	pave_discs = []


func gy(x: float, z: float) -> float:
	return w.height(cx + x, cz + z)


# ---------- peças ----------
func box(mat: String, x: float, y: float, z: float, sx: float, sy: float, sz: float, yaw := 0.0) -> void:
	if not lists.has(mat):
		lists[mat] = []
	lists[mat].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sx, sy, sz)), Vector3(x, y, z)))


func roof(mat: String, x: float, y: float, z: float, sx: float, sy: float, sz: float, yaw := 0.0) -> void:
	if not prisms.has(mat):
		prisms[mat] = []
	prisms[mat].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sx, sy, sz)), Vector3(x, y, z)))


func cyl(mat: String, x: float, y: float, z: float, r: float, h: float) -> void:
	if not cyls.has(mat):
		cyls[mat] = []
	cyls[mat].append(Transform3D(Basis.from_scale(Vector3(r * 2.0, h, r * 2.0)), Vector3(x, y, z)))


func label(text: String, x: float, z: float, h: float, col := Color(1.0, 0.88, 0.6), size := 64, far := 160.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/cinzel.ttf")
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 14
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(x, gy(x, z) + h, z)
	l.visibility_range_end = far
	root.add_child(l)


func door(kind: String, name: String, x: float, z: float, yaw: float) -> void:
	# porta na frente do prédio: entrar leva ao interior
	doors.append({"kind": kind, "name": name, "pos": Vector3(cx + x, gy(x, z), cz + z), "yaw": yaw})


func finish() -> void:
	for k in lists:
		w._boxes(root, mats[k], lists[k], 900.0)
	for k in prisms:
		_multi(PrismMesh.new(), k, prisms[k])
	for k in cyls:
		var c := CylinderMesh.new()
		c.radial_segments = 12
		c.top_radius = 0.5
		c.bottom_radius = 0.5
		c.height = 1.0
		_multi(c, k, cyls[k])
	_pave()


func _multi(mesh: PrimitiveMesh, mat: String, xfs: Array) -> void:
	mesh.material = mats[mat]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.visibility_range_end = 900.0
	root.add_child(mi)


# calçamento de pedra: tiras e discos que seguem o relevo, num só desenho
func _pave() -> void:
	if pave_rects.is_empty() and pave_discs.is_empty():
		return
	for which in ["calcada", "praca"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var any := false
		for r in pave_rects:
			if (r.size() > 5 and r[5] != which) or (r.size() <= 5 and which != "calcada"):
				continue
			any = true
			var hx: float = r[2]
			var hz: float = r[3]
			var yaw: float = r[4]
			var bas := Basis(Vector3.UP, yaw)
			var nx := maxi(1, int(ceil(hx * 2.0 / 3.0)))
			var nz := maxi(1, int(ceil(hz * 2.0 / 3.0)))
			for i in nx:
				for j in nz:
					var q: Array = []
					for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
						var lp := bas * Vector3(-hx + 2.0 * hx * c[0] / nx, 0, -hz + 2.0 * hz * c[1] / nz)
						var px: float = float(r[0]) + lp.x
						var pz: float = float(r[1]) + lp.z
						q.append(Vector3(px, gy(px, pz) + 0.07, pz))
					_quad(st, q)
		for d in pave_discs:
			if (d.size() > 3 and d[3] != which) or (d.size() <= 3 and which != "praca"):
				continue
			any = true
			var rad: float = d[2]
			var rings := maxi(2, int(rad / 3.0))
			var segs := 40
			for i in rings:
				for k in segs:
					var q: Array = []
					for c in [[i, k], [i + 1, k], [i + 1, k + 1], [i, k + 1]]:
						var rr: float = rad * c[0] / rings
						var a: float = TAU * c[1] / segs
						var px: float = float(d[0]) + sin(a) * rr
						var pz: float = float(d[1]) + cos(a) * rr
						q.append(Vector3(px, gy(px, pz) + 0.09, pz))
					_quad(st, q)
		if not any:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mats[which]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 700.0
		root.add_child(mi)


func _quad(st: SurfaceTool, q: Array) -> void:
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2((q[idx] as Vector3).x, (q[idx] as Vector3).z) * 0.3)
		st.add_vertex(q[idx])


# ---------- prédios ----------
# casa de cidade: térreo de pedra, andares de cimento com vigas aparentes, janelas, porta e telhado
func townhouse(x: float, z: float, yaw: float, wid: float, dep: float, floors: int, tone: String, roof_mat: String) -> void:
	var g := gy(x, z) - 0.3
	var bas := Basis(Vector3.UP, yaw)
	var fwd := bas * Vector3(0, 0, 1)  # frente (rua)
	var side := bas * Vector3(1, 0, 0)
	var h0 := 3.4
	var hf := 2.9
	var top := h0 + hf * (floors - 1)
	box("base", x, g + h0 * 0.5, z, wid, h0, dep, yaw)
	if floors > 1:
		var up := top - h0
		box(tone, x, g + h0 + up * 0.5, z, wid - 0.05, up, dep - 0.05, yaw)
		for f in floors:  # vigas de cada andar
			var yy := g + h0 + hf * f - 0.1
			box("viga", x, minf(yy, g + top - 0.1), z, wid + 0.12, 0.22, dep + 0.12, yaw)
		for k in [-0.5, 0.5]:
			var p: Vector3 = Vector3(x, 0, z) + side * (wid * k)
			box("viga", p.x, g + h0 + up * 0.5, p.z, 0.24, up, dep + 0.1, yaw)
	# janelas na frente e nos fundos
	var nwin := maxi(1, int(wid / 3.2))
	for f in range(1, floors):
		for k in nwin:
			var off := (k + 0.5) / nwin - 0.5
			for s in [1.0, -1.0]:
				var p: Vector3 = Vector3(x, 0, z) + side * (off * wid) + fwd * (dep * 0.5 * s + 0.03 * s)
				box("janela", p.x, g + h0 + hf * (f - 1) + 1.5, p.z, 1.0, 1.3, 0.12, yaw)
	var dp := Vector3(x, 0, z) + fwd * (dep * 0.5 + 0.04)
	box("porta", dp.x, g + 1.25, dp.z, 1.4, 2.5, 0.14, yaw)
	box("janela", dp.x + side.x * wid * 0.3, g + 1.7, dp.z + side.z * wid * 0.3, 1.1, 1.0, 0.12, yaw)
	roof(roof_mat, x, g + top + 1.6, z, wid + 0.7, 3.2, dep + 0.9, yaw)
	var ch := Vector3(x, 0, z) + side * (wid * 0.3)
	box("base", ch.x, g + top + 2.2, ch.z, 0.7, 2.2, 0.7, yaw)
	w.block(cx + x, cz + z, minf(wid, dep) * 0.55)
	if wid > 8.0:
		w.block(cx + x + side.x * wid * 0.3, cz + z + side.z * wid * 0.3, dep * 0.5)
		w.block(cx + x - side.x * wid * 0.3, cz + z - side.z * wid * 0.3, dep * 0.5)


# prédio público grande (salão, quartel, loja), com colunas na frente e nome
func hall(x: float, z: float, yaw: float, wid: float, dep: float, hgt: float, tone: String, roof_mat: String, title: String, door_kind := "") -> void:
	var g := gy(x, z) - 0.3
	var bas := Basis(Vector3.UP, yaw)
	var fwd := bas * Vector3(0, 0, 1)
	var side := bas * Vector3(1, 0, 0)
	box("base", x, g + 0.6, z, wid + 1.2, 1.2, dep + 1.2, yaw)
	box(tone, x, g + 1.2 + hgt * 0.5, z, wid, hgt, dep, yaw)
	box("viga", x, g + 1.2 + hgt, z, wid + 0.4, 0.4, dep + 0.4, yaw)
	roof(roof_mat, x, g + 1.4 + hgt + 2.2, z, wid + 1.0, 4.4, dep + 1.0, yaw)
	var ncol := maxi(2, int(wid / 4.0))
	for k in ncol:
		var off := (k + 0.5) / ncol - 0.5
		var p := Vector3(x, 0, z) + side * (off * wid * 0.9) + fwd * (dep * 0.5 + 1.6)
		cyl("marmore", p.x, g + 1.2 + hgt * 0.5, p.z, 0.4, hgt)
	var pp := Vector3(x, 0, z) + fwd * (dep * 0.5 + 1.6)
	box("marmore", pp.x, g + 1.4 + hgt, pp.z, wid * 0.95, 0.5, 3.6, yaw)
	var dp := Vector3(x, 0, z) + fwd * (dep * 0.5 + 0.05)
	box("porta", dp.x, g + 2.6, dp.z, 2.4, 3.6, 0.16, yaw)
	for k in [-0.3, 0.3]:
		var q: Vector3 = dp + side * (wid * k)
		box("janela", q.x, g + 1.2 + hgt * 0.55, q.z, 1.4, 2.2, 0.14, yaw)
	w.block(cx + x, cz + z, minf(wid, dep) * 0.5)
	for k in [-0.33, 0.33]:
		w.block(cx + x + side.x * wid * k, cz + z + side.z * wid * k, dep * 0.5)
	if title != "":
		label(title, pp.x, pp.z, hgt + 6.5, Color(1.0, 0.86, 0.55), 56, 140.0)
	if door_kind != "":
		var dd := Vector3(x, 0, z) + fwd * (dep * 0.5 + 3.6)
		door(door_kind, title, dd.x, dd.z, yaw)


func church(x: float, z: float, yaw: float, big := false, title := "Igreja") -> void:
	var k := 1.5 if big else 1.0
	var g := gy(x, z) - 0.3
	var bas := Basis(Vector3.UP, yaw)
	var fwd := bas * Vector3(0, 0, 1)
	var side := bas * Vector3(1, 0, 0)
	var L := 26.0 * k
	var Wd := 12.0 * k
	var Hn := 10.0 * k
	box("pedra", x, g + Hn * 0.5, z, Wd, Hn, L, yaw)
	roof("ardosia", x, g + Hn + 3.2 * k, z, Wd + 1.0, 6.4 * k, L + 0.6, yaw + PI * 0.5)
	for s in [-1.0, 1.0]:  # contrafortes e vitrais
		for i in 5:
			var p: Vector3 = Vector3(x, 0, z) + side * (s * (Wd * 0.5 + 0.5)) + fwd * (-L * 0.4 + i * L * 0.2)
			box("base", p.x, g + Hn * 0.4, p.z, 1.0, Hn * 0.8, 1.2, yaw)
			var v: Vector3 = Vector3(x, 0, z) + side * (s * (Wd * 0.5 + 0.04)) + fwd * (-L * 0.3 + i * L * 0.15)
			box("janela", v.x, g + Hn * 0.55, v.z, 0.12, Hn * 0.5, 1.4, yaw)
	# torre do sino com agulha
	var tp := Vector3(x, 0, z) + fwd * (L * 0.5 + 3.0 * k)
	box("pedra", tp.x, g + 9.0 * k, tp.z, 7.0 * k, 18.0 * k, 7.0 * k, yaw)
	box("janela", tp.x + fwd.x * 3.55 * k, g + 15.0 * k, tp.z + fwd.z * 3.55 * k, 1.6, 3.0, 0.12, yaw)
	var sp := CylinderMesh.new()
	sp.top_radius = 0.0
	sp.bottom_radius = 4.6 * k
	sp.height = 12.0 * k
	sp.radial_segments = 4
	sp.material = mats.ardosia
	var spi := MeshInstance3D.new()
	spi.mesh = sp
	spi.position = Vector3(tp.x, g + 18.0 * k + 6.0 * k, tp.z)
	spi.rotation.y = yaw + PI * 0.25
	spi.visibility_range_end = 1000.0
	root.add_child(spi)
	# rosácea e porta
	var rose := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 1.8 * k
	rm.bottom_radius = 1.8 * k
	rm.height = 0.15
	rm.material = mats.janela
	rose.mesh = rm
	rose.position = Vector3(tp.x + fwd.x * 3.56 * k, g + 9.5 * k, tp.z + fwd.z * 3.56 * k)
	rose.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
	root.add_child(rose)
	box("porta", tp.x + fwd.x * 3.56 * k, g + 2.4 * k, tp.z + fwd.z * 3.56 * k, 2.6 * k, 4.8 * k, 0.16, yaw)
	for i in 5:
		w.block(cx + x + fwd.x * (-L * 0.4 + i * L * 0.2), cz + z + fwd.z * (-L * 0.4 + i * L * 0.2), Wd * 0.55)
	w.block(cx + tp.x, cz + tp.z, 3.8 * k)
	var dd := tp + fwd * (3.6 * k + 2.0)
	door("igreja", title, dd.x, dd.z, yaw)
	pave_rects.append([dd.x, dd.z, 3.0 * k, 3.0, yaw])
	label(title, tp.x, tp.z, 32.0 * k, Color(0.95, 0.92, 1.0), 56, 200.0)


# chafariz: bacia de pedra, coluna, taça e jatos de água
func fountain(x: float, z: float, r: float, statue := false) -> void:
	var g := gy(x, z)
	for i in 16:
		var a := TAU * i / 16.0
		box("marmore", x + sin(a) * r, g + 0.45, z + cos(a) * r, r * 0.42, 0.9, 0.5, a)
	var wd := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = r - 0.2
	wm.bottom_radius = r - 0.2
	wm.height = 0.1
	wm.radial_segments = 24
	wm.material = mats.agua
	wd.mesh = wm
	wd.position = Vector3(x, g + 0.62, z)
	root.add_child(wd)
	cyl("marmore", x, g + 1.5, z, 0.45, 3.0)
	cyl("marmore", x, g + 3.0, z, r * 0.4, 0.35)
	if statue:
		hero_statue(x, z, g + 3.2, 0.0)
	else:
		cyl("marmore", x, g + 3.8, z, 0.25, 1.4)
	var jet := CPUParticles3D.new()
	jet.amount = int(70 * FX.amount) + 10
	jet.lifetime = 1.2
	jet.direction = Vector3.UP
	jet.spread = 28.0
	jet.initial_velocity_min = 2.4
	jet.initial_velocity_max = 3.2
	jet.gravity = Vector3(0, -6.0, 0)
	jet.scale_amount_min = 0.06
	jet.scale_amount_max = 0.1
	jet.color = Color(0.75, 0.88, 1.0, 0.75)
	var pm := SphereMesh.new()
	pm.radius = 0.5
	pm.height = 1.0
	pm.radial_segments = 4
	pm.rings = 2
	var jm := StandardMaterial3D.new()
	jm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	jm.vertex_color_use_as_albedo = true
	jm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.material = jm
	jet.mesh = pm
	jet.position = Vector3(x, g + 3.3 if not statue else g + 3.1, z)
	jet.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	jet.emission_sphere_radius = r * 0.3 if statue else 0.15
	jet.visibility_range_end = 70.0
	root.add_child(jet)
	w.block(cx + x, cz + z, r + 0.3)
	pave_discs.append([x, z, r + 6.0])


# estátua de herói sobre pedestal (figura de bronze com espada erguida)
func hero_statue(x: float, z: float, base_y: float, yaw: float, size := 1.0) -> void:
	var s := size
	box("marmore", x, base_y + 0.9 * s, z, 2.2 * s, 1.8 * s, 2.2 * s, yaw)
	var b := base_y + 1.8 * s
	cyl("bronze", x, b + 1.2 * s, z, 0.42 * s, 2.4 * s)
	box("bronze", x, b + 2.3 * s, z, 1.4 * s, 0.5 * s, 0.6 * s, yaw)
	cyl("bronze", x, b + 2.85 * s, z, 0.24 * s, 0.6 * s)
	var side := Basis(Vector3.UP, yaw) * Vector3(1, 0, 0)
	box("bronze", x + side.x * 0.75 * s, b + 3.0 * s, z + side.z * 0.75 * s, 0.22 * s, 1.4 * s, 0.22 * s, yaw)
	box("bronze", x + side.x * 0.75 * s, b + 4.4 * s, z + side.z * 0.75 * s, 0.1 * s, 2.0 * s, 0.22 * s, yaw)
	box("bronze", x - side.x * 0.75 * s, b + 1.9 * s, z - side.z * 0.75 * s, 0.2 * s, 1.2 * s, 0.9 * s, yaw)
	w.block(cx + x, cz + z, 1.4 * s)


# jardim: cerca viva, canteiros de flores, árvores podadas em bola, bancos e caminho de pedra
func garden(x: float, z: float, hx: float, hz: float, with_fountain := true) -> void:
	var g := gy(x, z)
	# cerca viva nas bordas, com aberturas no meio de cada lado
	for s in [-1.0, 1.0]:
		for half in [-1.0, 1.0]:
			box("sebe", x + half * hx * 0.55, g + 0.55, z + s * hz, hx * 0.8, 1.1, 0.8)
			box("sebe", x + s * hx, g + 0.55, z + half * hz * 0.55, 0.8, 1.1, hz * 0.8)
	pave_rects.append([x, z, 1.6, hz, 0.0])
	pave_rects.append([x, z, hx, 1.6, 0.0])
	var flowers: Array = []
	var bushes: Array = []
	var trees: Array = []
	for qx in [-1.0, 1.0]:
		for qz in [-1.0, 1.0]:
			var px: float = x + qx * hx * 0.5
			var pz: float = z + qz * hz * 0.5
			box("terra", px, g + 0.12, pz, hx * 0.6, 0.24, hz * 0.6)
			for k in 4:
				flowers.append(w.at(cx + px + (k % 2 - 0.5) * hx * 0.3, cz + pz + (k / 2 - 0.5) * hz * 0.3, k * 1.3))
			bushes.append(w.at(cx + x + qx * (hx - 2.0), cz + z + qz * (hz - 2.0), 0.0))
			trees.append(w.at(cx + px + qx * hx * 0.2, cz + pz + qz * hz * 0.2, qx + qz))
	w.place(root, "n_flower_4_group", flowers.slice(0, flowers.size() / 2), 0.6, false, 120.0)
	w.place(root, "n_flower_3_group", flowers.slice(flowers.size() / 2), 0.6, false, 120.0)
	w.place(root, "n_bush_common_flowers", bushes, 1.3, true, 180.0)
	w.place(root, "q_birchtree_1", trees, 7.0, true, 400.0)
	for t in trees:
		w.block((t as Transform3D).origin.x, (t as Transform3D).origin.z, 0.6)
	# árvores podadas em bola
	var topi := SphereMesh.new()
	topi.radius = 0.9
	topi.height = 1.8
	topi.radial_segments = 8
	topi.rings = 5
	topi.material = mats.sebe
	var xs: Array = []
	for qx in [-1.0, 1.0]:
		for qz in [-1.0, 1.0]:
			var px: float = x + qx * 3.2
			var pz: float = z + qz * 3.2
			xs.append(Transform3D(Basis.IDENTITY, Vector3(px, gy(px, pz) + 1.4, pz)))
			cyl("madeira", px, gy(px, pz) + 0.4, pz, 0.12, 0.8)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = topi
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.visibility_range_end = 300.0
	root.add_child(mi)
	w.place(root, "b_bench_1", [w.at(cx + x + 2.6, cz + z + hz * 0.75, PI * 0.5), w.at(cx + x - 2.6, cz + z - hz * 0.75, -PI * 0.5)], 0.95, true, 150.0)
	if with_fountain:
		fountain(x, z, 2.4)


# Arena dos Heróis: coliseu redondo com arquibancadas, arcos e areia
func arena(x: float, z: float, r: float, title: String) -> void:
	var g := gy(x, z)
	var n := int(r * 1.3)
	for i in n:
		var a := TAU * i / n
		var p := Vector2(sin(a), cos(a))
		if absf(wrapf(a - PI, -PI, PI)) < 0.12 or absf(wrapf(a, -PI, PI)) < 0.12:  # dois portões
			continue
		# parede externa com arcos: pilares em dois andares
		box("cimento3", x + p.x * r, g + 4.0, z + p.y * r, 1.2, 8.0, 1.6, a)
		box("cimento3", x + p.x * r, g + 10.0, z + p.y * r, 1.0, 4.0, 1.4, a)
		box("cimento3", x + p.x * r, g + 8.2, z + p.y * r, TAU * r / n + 0.2, 0.8, 1.7, a)
		box("cimento3", x + p.x * r, g + 12.4, z + p.y * r, TAU * r / n + 0.2, 0.9, 1.7, a)
		# arquibancada em degraus
		for k in 4:
			var rr := r - 2.0 - k * 2.0
			box("pedra", x + p.x * rr, g + 6.0 - k * 1.5, z + p.y * rr, TAU * rr / n + 0.3, 1.0 + (3 - k) * 0.1, 2.0, a)
		w.block(cx + x + p.x * r, cz + z + p.y * r, 1.2)
	# muro da arena (separa a luta do público) e areia
	for i in n:
		var a := TAU * i / n
		var rr := r - 10.5
		box("base", x + sin(a) * rr, g + 0.9, z + cos(a) * rr, TAU * rr / n + 0.2, 1.8, 0.6, a)
	var sand := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = r - 10.5
	sm.bottom_radius = r - 10.5
	sm.height = 0.2
	sm.radial_segments = 40
	sm.material = mats.areia
	sand.mesh = sm
	sand.position = Vector3(x, g + 0.08, z)
	root.add_child(sand)
	# mastros com bandeiras
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var p := Vector3(x + sin(a) * (r + 0.2), 0, z + cos(a) * (r + 0.2))
		cyl("madeira", p.x, g + 16.0, p.z, 0.12, 8.0)
		box("pano" if i % 2 == 0 else "pano_azul", p.x + sin(a) * 0.9, g + 18.4, p.z + cos(a) * 0.9, 1.6, 2.4, 0.06, a + PI * 0.5)
	label(title, x, z, 22.0, Color(1.0, 0.8, 0.4), 80, 320.0)
	door("arena", title, x, z + r + 3.0, 0.0)


# palácio: corpo central com cúpula, alas, torres nos cantos e escadaria
func palace(x: float, z: float, yaw: float, title: String) -> void:
	var g := gy(x, z) - 0.3
	var bas := Basis(Vector3.UP, yaw)
	var fwd := bas * Vector3(0, 0, 1)
	var side := bas * Vector3(1, 0, 0)
	box("marmore", x, g + 1.0, z, 74.0, 2.0, 34.0, yaw)
	box("cimento", x, g + 9.0, z, 30.0, 14.0, 22.0, yaw)
	box("cimento2", x + side.x * 25.0, g + 7.0, z + side.z * 25.0, 20.0, 10.0, 18.0, yaw)
	box("cimento2", x - side.x * 25.0, g + 7.0, z - side.z * 25.0, 20.0, 10.0, 18.0, yaw)
	roof("telha_azul", x + side.x * 25.0, g + 14.4, z + side.z * 25.0, 21.0, 4.8, 19.0, yaw)
	roof("telha_azul", x - side.x * 25.0, g + 14.4, z - side.z * 25.0, 21.0, 4.8, 19.0, yaw)
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 9.0
	dm.height = 12.0
	dm.is_hemisphere = true
	dm.material = mats.ouro
	dome.mesh = dm
	dome.position = Vector3(x, g + 16.0, z)
	root.add_child(dome)
	for c in [[-1.0, -1.0], [1.0, -1.0], [-1.0, 1.0], [1.0, 1.0]]:
		var p: Vector3 = Vector3(x, 0, z) + side * (c[0] * 35.0) + fwd * (c[1] * 15.0)
		cyl("cimento", p.x, g + 11.0, p.z, 3.4, 22.0)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 4.2
		cm.height = 8.0
		cm.radial_segments = 10
		cm.material = mats.telha_azul
		cone.mesh = cm
		cone.position = Vector3(p.x, g + 26.0, p.z)
		root.add_child(cone)
		w.block(cx + p.x, cz + p.z, 3.6)
	for k in 8:
		var off := (k + 0.5) / 8.0 - 0.5
		var p := Vector3(x, 0, z) + side * (off * 28.0) + fwd * 12.5
		cyl("marmore", p.x, g + 8.0, p.z, 0.6, 14.0)
	for k in 5:  # escadaria
		var p := Vector3(x, 0, z) + fwd * (17.5 + k * 1.2)
		box("marmore", p.x, g + 1.6 - k * 0.35, p.z, 26.0 - k * 1.0, 0.5, 1.4, yaw)
	box("porta", x + fwd.x * 11.1, g + 5.0, z + fwd.z * 11.1, 5.0, 8.0, 0.2, yaw)
	for i in 7:
		var off := (i / 6.0) - 0.5
		var p := Vector3(x, 0, z) + side * (off * 66.0)
		w.block(cx + p.x, cz + p.z, 10.0)
		w.block(cx + p.x + fwd.x * 8.0, cz + p.z + fwd.z * 8.0, 8.0)
		w.block(cx + p.x - fwd.x * 8.0, cz + p.z - fwd.z * 8.0, 8.0)
	label(title, x, z, 34.0, Color(1.0, 0.85, 0.45), 96, 500.0)
	door("palacio", title, x + fwd.x * 24.0, z + fwd.z * 24.0, yaw)


# barco simples: casco, convés, mastro e vela
func boat(x: float, z: float, yaw: float, size := 1.0) -> void:
	var s := size
	var y := 0.15
	var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	box("madeira", x, y, z, 3.0 * s, 1.4 * s, 9.0 * s, yaw)
	roof("madeira", x + fwd.x * 5.6 * s, y + 0.1, z + fwd.z * 5.6 * s, 3.0 * s, 1.4 * s, 2.2 * s, yaw + PI * 0.5)
	box("viga", x, y + 0.75 * s, z, 3.2 * s, 0.2, 9.2 * s, yaw)
	cyl("madeira", x, y + 4.5 * s, z, 0.14 * s, 8.0 * s)
	box("vela", x + fwd.x * 0.6, y + 5.0 * s, z + fwd.z * 0.6, 4.2 * s, 5.0 * s, 0.05, yaw + PI * 0.5)


# porto: cais de madeira que entra no mar, postes, caixas, barcos e farol
func harbor(x: float, z: float, yaw: float, length: float) -> void:
	var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	var side := Basis(Vector3.UP, yaw) * Vector3(1, 0, 0)
	var deck := 1.3
	var n := int(length / 3.0)
	for i in n:
		var p := Vector3(x, 0, z) + fwd * (i * 3.0)
		box("madeira", p.x, deck, p.z, 6.0, 0.3, 3.05, yaw)
		for s in [-1.0, 1.0]:
			var q: Vector3 = p + side * (s * 2.8)
			box("viga", q.x, deck - 3.0, q.z, 0.35, 6.4, 0.35, yaw)
			if i % 2 == 0:
				box("viga", q.x, deck + 0.6, q.z, 0.22, 1.0, 0.22, yaw)
	w.floors.append({"kind": "rect", "c": Vector2(cx + x + fwd.x * length * 0.5, cz + z + fwd.z * length * 0.5), "yaw": yaw, "hw": 3.0, "hd": length * 0.5 + 1.5, "y": deck + 0.15})
	# braço lateral do cais
	var t := Vector3(x, 0, z) + fwd * (length - 6.0)
	for i in 6:
		var p := t + side * (3.0 + i * 3.0)
		box("madeira", p.x, deck, p.z, 3.05, 0.3, 5.0, yaw)
		box("viga", p.x, deck - 3.0, p.z + 2.2, 0.35, 6.4, 0.35, yaw)
	w.floors.append({"kind": "rect", "c": Vector2(cx + t.x + side.x * 10.5, cz + t.z + side.z * 10.5), "yaw": yaw, "hw": 9.5, "hd": 2.5, "y": deck + 0.15})
	var crates: Array = []
	for i in 5:
		var p := Vector3(x, 0, z) + fwd * (6.0 + i * 7.0) + side * (1.8 if i % 2 == 0 else -1.8)
		crates.append(Transform3D(Basis(Vector3.UP, i * 0.7), Vector3(cx + p.x, deck + 0.15, cz + p.z)))
	w.place(root, "b_crate", crates, 0.85, true, 150.0)
	w.place(root, "b_barrel", crates.map(func(xf): return (xf as Transform3D).translated(Vector3(0.9, 0, 0.6))), 1.0, true, 150.0)
	boat(x + side.x * 8.0 + fwd.x * (length * 0.55), z + side.z * 8.0 + fwd.z * (length * 0.55), yaw, 1.0)
	boat(x - side.x * 7.5 + fwd.x * (length * 0.75), z - side.z * 7.5 + fwd.z * (length * 0.75), yaw + 0.1, 1.2)
	var e := t + side * 14.0 + fwd * 8.0
	boat(e.x, e.z, yaw + PI * 0.5, 0.8)
	label("Cais do Porto", x + fwd.x * length * 0.5, z + fwd.z * length * 0.5, 6.0, Color(0.85, 0.95, 1.0), 48, 120.0)


func lighthouse(x: float, z: float) -> void:
	var g := gy(x, z)
	cyl("marmore", x, g + 9.0, z, 2.6, 18.0)
	for k in 3:
		cyl("pano", x, g + 3.0 + k * 6.0, z, 2.65, 1.2)
	cyl("ardosia", x, g + 19.0, z, 3.2, 0.6)
	cyl("janela", x, g + 20.6, z, 1.8, 2.6)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 2.4
	cm.height = 2.6
	cm.material = mats.ardosia
	cone.mesh = cm
	cone.position = Vector3(x, g + 23.2, z)
	root.add_child(cone)
	w.lamps.append(Vector3(cx + x, g + 20.6, cz + z))
	w.block(cx + x, cz + z, 2.8)
	label("Farol", x, z, 27.0, Color(0.9, 0.95, 1.0), 48, 300.0)


# ponte de pedra com arcos, guarda-corpo e piso de calçamento
func stone_bridge(a: Vector3, b: Vector3, deck_y: float) -> void:
	var dir := (b - a).normalized()
	var yaw := atan2(dir.x, dir.z)
	var len := a.distance_to(b) + 14.0
	var mid := (a + b) * 0.5
	var side := Vector3(dir.z, 0, -dir.x)
	box("pedra", mid.x, deck_y - 0.4, mid.z, 7.0, 0.8, len, yaw)
	for s in [-1.0, 1.0]:
		var q: Vector3 = mid + side * (s * 3.3)
		box("marmore", q.x, deck_y + 0.55, q.z, 0.5, 1.1, len, yaw)
	var piers := int(len / 9.0)
	for k in range(1, piers):
		var p := mid + dir * (k * 9.0 - len * 0.5)
		box("pedra", p.x, deck_y - 6.0, p.z, 6.6, 10.0, 2.6, yaw)
	w.floors.append({"kind": "rect", "c": Vector2(cx + mid.x, cz + mid.z), "yaw": yaw, "hw": 3.1, "hd": len * 0.5, "y": deck_y + 0.07})


# ---------- cidade grande e capital: ruas retas em grade, quarteirões de casas lado a lado ----------
# devolve os pontos de serviço (coordenadas da cidade) para os moradores e funções
func build_big(t: Dictionary, size: String, theme: String) -> Dictionary:
	var cap := size == "capital"
	var L: Array = [-185.0, -142.0, -97.0, -52.0, 0.0, 52.0, 97.0, 142.0, 185.0] if cap else [-116.0, -78.0, -40.0, 0.0, 40.0, 78.0, 116.0]
	var c := L.size() / 2
	var width := func(v: float) -> float: return 16.0 if v == 0.0 else 8.0
	var lim: float = L[L.size() - 1]
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(t.id) + "grade")
	var roofs: Array = ["telha", "telha", "ardosia"] if theme != "noctis" else ["ardosia", "ardosia", "telha_azul"]
	if cap:
		roofs = ["telha", "telha_azul", "ardosia", "telha"]
	var tones := ["cimento", "cimento2", "cimento3"]
	var floors_min := 3 if cap else 2
	var floors_max := 4 if cap else 3
	var svc := {}
	var roles := {}
	var R := func(k: String, cells: Array) -> void:
		for cc in cells:
			roles[cc] = k
	R.call("praca", [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)])
	if cap:
		R.call("palacio", [Vector2i(-1, -3), Vector2i(0, -3), Vector2i(-1, -4), Vector2i(0, -4)])
		R.call("jardim_real", [Vector2i(-1, -2), Vector2i(0, -2)])
		R.call("arena", [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)])
		R.call("catedral", [Vector2i(-2, -2)])
		R.call("jardim", [Vector2i(-3, -2), Vector2i(2, -3), Vector2i(-1, 1), Vector2i(0, 1)])
		R.call("mercado", [Vector2i(1, -1), Vector2i(1, 0)])
		R.call("lendarios", [Vector2i(-2, -1)])
		R.call("artesao", [Vector2i(-2, 0)])
		R.call("quartel", [Vector2i(-3, 1), Vector2i(-2, 1)])
		R.call("treino", [Vector2i(-3, 2), Vector2i(-2, 2)])
		R.call("taverna", [Vector2i(2, -1)])
		R.call("ferraria", [Vector2i(2, 0)])
		R.call("estabulo", [Vector2i(3, 0)])
	else:
		R.call("igreja", [Vector2i(-2, -2)])
		R.call("jardim", [Vector2i(1, -2), Vector2i(-2, 1)])
		R.call("taverna", [Vector2i(1, -1)])
		R.call("ferraria", [Vector2i(-2, -1)])
		R.call("quartel", [Vector2i(-2, 0)])
		R.call("estabulo", [Vector2i(2, -1)])
		match theme:
			"rubra":
				R.call("arena", [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)])
			"dourado":
				R.call("mercado", [Vector2i(1, 1), Vector2i(2, 1)])
				R.call("moinhos", [Vector2i(1, 2), Vector2i(2, 2)])
			"noctis":
				R.call("palacete", [Vector2i(1, 1), Vector2i(2, 1)])
			"porto":
				R.call("mercado", [Vector2i(1, 1), Vector2i(-1, 1)])
				R.call("cais", [Vector2i(0, 2), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(-2, 2), Vector2i(-3, 2), Vector2i(0, 1)])
	var done := {}
	for ix in range(L.size() - 1):
		for iz in range(L.size() - 1):
			var key := Vector2i(ix - c, iz - c)
			var x0: float = float(L[ix]) + width.call(float(L[ix])) * 0.5 + 1.5
			var x1: float = float(L[ix + 1]) - width.call(float(L[ix + 1])) * 0.5 - 1.5
			var z0: float = float(L[iz]) + width.call(float(L[iz])) * 0.5 + 1.5
			var z1: float = float(L[iz + 1]) - width.call(float(L[iz + 1])) * 0.5 - 1.5
			var role: String = roles.get(key, "casas")
			if done.has(role) and role != "casas" and role != "jardim":
				continue
			# blocos com a mesma função viram um só (palácio, arena, mercado...)
			if role != "casas" and role != "jardim":
				done[role] = true
				var keys: Array = roles.keys().filter(func(k): return roles[k] == role)
				var bx0 := 1e9
				var bx1 := -1e9
				var bz0 := 1e9
				var bz1 := -1e9
				for k in keys:
					var kx: int = (k as Vector2i).x + c
					var kz: int = (k as Vector2i).y + c
					bx0 = minf(bx0, float(L[kx]) + width.call(float(L[kx])) * 0.5 + 1.5)
					bx1 = maxf(bx1, float(L[kx + 1]) - width.call(float(L[kx + 1])) * 0.5 - 1.5)
					bz0 = minf(bz0, float(L[kz]) + width.call(float(L[kz])) * 0.5 + 1.5)
					bz1 = maxf(bz1, float(L[kz + 1]) - width.call(float(L[kz + 1])) * 0.5 - 1.5)
				x0 = bx0
				x1 = bx1
				z0 = bz0
				z1 = bz1
			var mx := (x0 + x1) * 0.5
			var mz := (z0 + z1) * 0.5
			var hx := (x1 - x0) * 0.5
			var hz := (z1 - z0) * 0.5
			match role:
				"praca":
					pave_rects.append([0.0, 0.0, hx * 2.0 + 10.0, hz * 2.0 + 10.0, 0.0, "praca"])
					fountain(0.0, 0.0, 6.0 if cap else 4.5, true)
					var bushes: Array = []
					for i in 12:
						var a := TAU * i / 12.0 + 0.26
						bushes.append(w.at(cx + sin(a) * 16.0, cz + cos(a) * 16.0))
					w.place(root, "n_bush_common_flowers", bushes, 1.2, true, 200.0)
					w.place(root, "b_bench_1", [w.at(cx + 10.0, cz + 12.0, PI), w.at(cx - 10.0, cz + 12.0, PI), w.at(cx + 10.0, cz - 12.0, 0.0), w.at(cx - 10.0, cz - 12.0, 0.0)], 0.95, true, 150.0)
					if cap:
						for q in [[-30.0, -30.0], [30.0, -30.0], [-30.0, 30.0], [30.0, 30.0]]:
							hero_statue(q[0], q[1], gy(q[0], q[1]), atan2(-q[0], -q[1]), 1.3)
					svc.praca = Vector2(0, 0)
				"palacio":
					palace(0.0, mz, 0.0, "Palácio Real")
					svc.palacio = Vector2(0, mz + 26.0)
				"jardim_real":
					garden(0.0, mz, hx - 2.0, hz - 2.0, true)
					fountain(-hx * 0.55, mz, 2.6)
					fountain(hx * 0.55, mz, 2.6)
					svc.jardim = Vector2(0, mz)
				"jardim":
					garden(mx, mz, hx - 1.0, hz - 1.0, true)
					if not svc.has("jardim"):
						svc.jardim = Vector2(mx, mz)
				"arena":
					arena(mx, mz, minf(hx, hz) - 2.0, "Arena dos Heróis" if cap else "Arena de Guerra")
					svc.arena = Vector2(mx, mz + minf(hx, hz) + 2.0)
				"catedral", "igreja":
					church(mx, mz, 0.0, role == "catedral" or theme == "noctis", "Catedral da Aurora" if role == "catedral" else ("Catedral Sombria" if theme == "noctis" else "Igreja"))
					svc.igreja = Vector2(mx, mz + 30.0 if role == "catedral" or theme == "noctis" else mz + 21.0)
				"mercado":
					hall(mx, mz - hz * 0.45, 0.0, hx * 1.6, hz * 0.7, 7.0, "cimento3", "telha", "Grande Mercado", "loja")
					var stands: Array = []
					var stands2: Array = []
					for i in 6:
						var sx := mx - hx * 0.7 + i * hx * 0.28
						stands.append(w.at(cx + sx, cz + mz + hz * 0.35, PI))
						stands2.append(w.at(cx + sx, cz + mz + hz * 0.7, 0.0))
						w.block(cx + sx, cz + mz + hz * 0.35, 1.4)
						w.block(cx + sx, cz + mz + hz * 0.7, 1.4)
					w.place(root, "b_marketstand_1", stands, 3.1, true, 300.0)
					w.place(root, "b_marketstand_2", stands2, 3.1, true, 300.0)
					pave_rects.append([mx, mz + hz * 0.5, hx, hz * 0.5, 0.0, "praca"])
					svc.mercado = Vector2(mx, mz + hz * 0.52)
				"lendarios":
					hall(mx, mz, PI * 0.5, hz * 1.5, hx * 1.2, 9.0, "marmore", "telha_azul", "Loja de Lendários e Itens Únicos", "loja")
					svc.lendarios = Vector2(mx + hx * 0.6 + 4.5, mz)
				"artesao":
					hall(mx, mz, PI * 0.5, hz * 1.4, hx * 1.1, 8.0, "pedra", "ardosia", "Forja Lendária", "forja")
					svc.artesao = Vector2(mx + hx * 0.55 + 4.5, mz)
				"quartel":
					hall(mx, mz, PI if not cap else PI * 0.5, (hx if not cap else hz) * 1.6, (hz if not cap else hx) * 0.9, 8.0, "pedra", "ardosia", "Quartel dos Cavaleiros" if cap else "Quartel da Guarda", "")
					svc.quartel = Vector2(mx, mz)
				"treino":
					pave_rects.append([mx, mz, hx, hz, 0.0, "praca"])
					for i in 6:
						var px := mx - hx * 0.6 + (i % 3) * hx * 0.6
						var pz := mz - hz * 0.4 + (i / 3) * hz * 0.8
						cyl("madeira", px, gy(px, pz) + 1.0, pz, 0.12, 2.0)
						box("pano", px, gy(px, pz) + 1.5, pz, 0.6, 0.8, 0.3)
						w.block(cx + px, cz + pz, 0.4)
					svc.treino = Vector2(mx, mz)
				"taverna":
					w._building(root, "b_inn", cx + mx, cz + mz, 11.5, cx + mx, cz + mz + 50.0)
					door("taverna", "Taverna", mx, mz + 9.5, 0.0)
					svc.pousada = Vector2(mx, mz)
				"ferraria":
					w._building(root, "b_blacksmith", cx + mx, cz + mz, 7.0, cx + mx, cz + mz + 50.0)
					door("forja", "Ferraria", mx, mz + 7.0, 0.0)
					svc.forja = Vector2(mx, mz)
				"estabulo":
					w._building(root, "b_stable", cx + mx, cz + mz, 6.4, cx + mx - 50.0, cz + mz)
					svc.estabulo = Vector2(mx, mz)
				"moinhos":
					w.place(root, "b_mill", [w.at(cx + mx - hx * 0.5, cz + mz, 0.4), w.at(cx + mx + hx * 0.5, cz + mz, 2.0)], 13.0, true, 900.0)
					w.block(cx + mx - hx * 0.5, cz + mz, 4.0)
					w.block(cx + mx + hx * 0.5, cz + mz, 4.0)
				"palacete":
					hall(mx, mz, 0.0, hx * 1.5, hz * 1.1, 11.0, "cimento2", "ardosia", "Palacete dos Nobres", "casa")
				"cais":
					pass
				_:
					_block_houses(x0, x1, z0, z1, r, tones, roofs, floors_min, floors_max)
	# ruas retas com calçamento, postes e árvores alinhadas
	var lamp_pts: Array = []
	var alley: Array = []
	for v in L:
		var wd: float = width.call(float(v))
		var span: float = lim + 6.0
		if theme == "porto" and true:
			span = lim + 6.0
		pave_rects.append([float(v), 0.0, wd * 0.5, span, 0.0])
		pave_rects.append([0.0, float(v), span, wd * 0.5, 0.0])
		var step := 22.0 if v == 0.0 else 30.0
		var k := -lim
		while k <= lim:
			for sgn in [-1.0, 1.0]:
				for p in [Vector2(float(v) + sgn * (wd * 0.5 + 0.6), k), Vector2(k, float(v) + sgn * (wd * 0.5 + 0.6))]:
					if absf(p.x) < 12.0 and absf(p.y) < 12.0:
						continue
					lamp_pts.append(w.at(cx + p.x, cz + p.y, 0.0))
					w.block(cx + p.x, cz + p.y, 0.25)
			if v == 0.0 and absf(k) > 50.0:
				for sgn in [-1.0, 1.0]:
					alley.append(w.at(cx + sgn * 5.0, cz + k + 11.0, k))
					alley.append(w.at(cx + k + 11.0, cz + sgn * 5.0, k))
			k += step
	var sz: Vector3 = w.place(root, "n_light_street_1", lamp_pts, 4.4, true, 260.0)
	for xf in lamp_pts:
		w.lamps.append((xf as Transform3D).origin + Vector3(0, sz.y * 0.9, 0))
	w.place(root, "n_commontree_2", alley, 8.0, w.tree_shadows, 500.0)
	for xf in alley:
		w.block((xf as Transform3D).origin.x, (xf as Transform3D).origin.z, 0.6)
	if theme == "porto":
		harbor(0.0, 132.0, 0.0, 66.0)
		harbor(-70.0, 140.0, 0.1, 48.0)
		lighthouse(95.0, 150.0)
		svc.cais = Vector2(0, 150)
	for k in ["forja", "pousada", "estabulo"]:
		if not svc.has(k):
			svc[k] = Vector2(-40, 20)
	return svc


# quarteirão: casas grandes lado a lado de frente para as quatro ruas, pátio no meio
func _block_houses(x0: float, x1: float, z0: float, z1: float, r: RandomNumberGenerator, tones: Array, roofs: Array, fmin: int, fmax: int) -> void:
	var D := 10.0
	if x1 - x0 < 14.0 or z1 - z0 < 14.0:
		return
	var first := true
	for side in 4:
		var a0: float
		var a1: float
		if side < 2:
			a0 = x0
			a1 = x1
		else:
			a0 = z0 + D
			a1 = z1 - D
		var pos := a0
		while a1 - pos > 6.0:
			var wid := minf(r.randf_range(8.0, 12.5), a1 - pos)
			var m := pos + wid * 0.5
			var x: float
			var z: float
			var yaw: float
			match side:
				0:
					x = m
					z = z0 + D * 0.5
					yaw = PI
				1:
					x = m
					z = z1 - D * 0.5
					yaw = 0.0
				2:
					x = x0 + D * 0.5
					z = m
					yaw = -PI * 0.5
				_:
					x = x1 - D * 0.5
					z = m
					yaw = PI * 0.5
			townhouse(x, z, yaw, wid - 0.1, D, r.randi_range(fmin, fmax), tones[r.randi() % tones.size()], roofs[r.randi() % roofs.size()])
			if first:
				first = false
				var f := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
				door("casa", "Casa", x + f.x * (D * 0.5 + 1.2), z + f.z * (D * 0.5 + 1.2), yaw)
			pos += wid
	# pátio interno com árvore
	var mx := (x0 + x1) * 0.5
	var mz := (z0 + z1) * 0.5
	if x1 - x0 > 26.0 and z1 - z0 > 26.0:
		w.place(root, "n_commontree_1", [w.at(cx + mx, cz + mz, r.randf() * TAU)], 7.5, w.tree_shadows, 400.0)
		w.block(cx + mx, cz + mz, 0.7)
