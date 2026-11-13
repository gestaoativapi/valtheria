extends Node3D
# Mundo real de Valtheria: o mesmo relevo do servidor (assado em data/height.bin), carregado por blocos em volta do jogador.

const FX = preload("res://scripts/fx.gd")
const CH := 100.0  # tamanho do bloco de terreno, em metros
const WATER_Y := 0.0

var info := {}
var size := 3000.0
var step := 2.0
var n := 1501
var lo := -40.0
var hrange := 300.0
var hb := PackedByteArray()
var splat_img: Image
var rng := RandomNumberGenerator.new()
var env: Environment
var sun: DirectionalLight3D
var fire: OmniLight3D
var water: MeshInstance3D
var terrain_mat: ShaderMaterial
var blade: ArrayMesh
var chunks := {}  # Vector2i -> {"node", "lod"}
var grass := {}  # Vector2i -> MultiMeshInstance3D
var models := {}  # arquivo -> {"parts", "bb"}
var blockers := {}
var trunks := {}  # bloco -> [Vector3(x, z, raio)] dos troncos e pedras grandes
var near_r := 300.0
var far_r := 1200.0
var grass_r := 70.0
var detail_f := 1.0
var tree_shadows := true
var base_fog := 0.0016
var fire_mat: StandardMaterial3D
var fires: Array = []
var counts := {"arvores": 0, "grama": 0, "blocos": 0}

const TERRAIN_SHADER := """
shader_type spatial;
uniform sampler2D tint : source_color, filter_linear, repeat_disable;
uniform sampler2D splat : filter_linear, repeat_disable;
uniform sampler2D grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float world_size = 3000.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 wuv = (wpos.xz + 1.0) / (world_size + 2.0);
	vec3 tn = texture(tint, wuv).rgb;
	vec4 sp = texture(splat, wuv);
	vec2 uv = wpos.xz * 0.2;
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(60.0, 160.0, dist);
	float lg = dot(texture(grass, uv).rgb, vec3(0.33)) / 0.3;
	float lr = dot(texture(rock, uv * 0.45).rgb, vec3(0.33)) / 0.42;
	float detail = mix(1.0, clamp(mix(lg, lr, sp.b), 0.7, 1.25), near);
	float big = mix(0.9, 1.1, texture(grass, uv * 0.03).g * 1.6);
	vec3 col = tn * 0.62 * detail * big;
	vec3 d = texture(dirt, uv * 0.9).rgb * vec3(0.72, 0.78, 0.8);
	col = mix(col, mix(vec3(0.45, 0.38, 0.3), d, near), sp.r);
	ALBEDO = col;
	ROUGHNESS = 0.96;
	SPECULAR = 0.15;
}
"""

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec3 base : source_color = vec3(0.17, 0.27, 0.09);
uniform vec3 tip : source_color = vec3(0.4, 0.52, 0.2);
varying float hgt;
void vertex() {
	hgt = UV.y;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float s = sin(TIME * 1.6 + w.x * 0.35 + w.z * 0.27) * 0.5 + sin(TIME * 2.7 + w.x * 0.9) * 0.2;
	VERTEX.x += s * 0.12 * UV.y * UV.y;
	VERTEX.z += s * 0.06 * UV.y * UV.y;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	ALBEDO = mix(base, tip, hgt);
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);  // as duas faces recebem a mesma luz
	ROUGHNESS = 0.9;
}
"""

const WATER_SHADER := """
shader_type spatial;
uniform sampler2D waves : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D heights : filter_nearest, repeat_disable;
uniform float cells = 1501.0;
uniform float lo = -40.0;
uniform float hrange = 300.0;
varying vec3 wpos;
float ground(vec2 p) {
	vec2 f = clamp(p / 2.0, vec2(0.0), vec2(cells - 1.001));
	ivec2 i = ivec2(f);
	vec2 t = fract(f);
	float h[4];
	for (int k = 0; k < 4; k++) {
		vec2 c = texelFetch(heights, i + ivec2(k & 1, k >> 1), 0).rg * 255.0;
		h[k] = lo + (c.g * 256.0 + c.r) / 65535.0 * hrange;
	}
	return mix(mix(h[0], h[1], t.x), mix(h[2], h[3], t.x), t.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wpos.xz * 0.05;
	vec3 a = texture(waves, uv + TIME * vec2(0.012, 0.008)).rgb;
	vec3 b = texture(waves, uv * 1.7 - TIME * vec2(0.01, 0.014)).rgb;
	NORMAL_MAP = mix(a, b, 0.5);
	NORMAL_MAP_DEPTH = 0.9;
	float depth = max(0.0, -ground(wpos.xz));
	float k = clamp(depth / 5.0, 0.0, 1.0);
	vec3 col = mix(vec3(0.16, 0.5, 0.52), vec3(0.03, 0.14, 0.26), k);
	float wob = (a.r + b.g - 1.0) * 0.35 + sin(TIME * 1.5 + wpos.x * 0.6 + wpos.z * 0.4) * 0.08;
	float foam = 1.0 - smoothstep(0.12, 0.42, depth + wob);
	ALBEDO = mix(col, vec3(0.92, 0.97, 1.0), foam * 0.85);
	ALPHA = mix(0.55, 0.93, k) + foam * 0.3;
	ROUGHNESS = mix(0.05, 0.5, foam);
	SPECULAR = 0.7;
}
"""



func _init() -> void:
	rng.seed = 12345
	info = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	size = info.size
	step = info.step
	n = int(info.n)
	lo = info.lo
	hrange = info.range
	hb = FileAccess.get_file_as_bytes("res://data/height.bin")
	splat_img = (load("res://data/splat.png") as Texture2D).get_image()
	if splat_img.is_compressed():
		splat_img.decompress()


func build() -> void:
	_build_sky()
	var sh := Shader.new()
	sh.code = TERRAIN_SHADER
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = sh
	terrain_mat.set_shader_parameter("tint", load("res://data/tint.png"))
	terrain_mat.set_shader_parameter("splat", load("res://data/splat.png"))
	terrain_mat.set_shader_parameter("grass", load("res://assets/world/t_grass.webp"))
	terrain_mat.set_shader_parameter("dirt", load("res://assets/world/t_dirt.webp"))
	terrain_mat.set_shader_parameter("rock", load("res://assets/world/t_rock.webp"))
	terrain_mat.set_shader_parameter("world_size", size)
	blade = _blade_mesh()
	_build_water()
	for t in info.towns:
		_build_town(t)
		_build_walls(t)
	for b in info.get("bridges", []):
		_build_bridge(b)


# ---------- relevo ----------
func _h(i: int, j: int) -> float:
	return lo + hb.decode_u16((clampi(j, 0, n - 1) * n + clampi(i, 0, n - 1)) * 2) / 65535.0 * hrange


func height(x: float, z: float) -> float:
	var fx := clampf(x / step, 0.0, n - 1.001)
	var fz := clampf(z / step, 0.0, n - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	return lerpf(lerpf(_h(i, j), _h(i + 1, j), tx), lerpf(_h(i, j + 1), _h(i + 1, j + 1), tx), tz)


func normal(x: float, z: float) -> Vector3:
	return Vector3(height(x - 2.0, z) - height(x + 2.0, z), 4.0, height(x, z - 2.0) - height(x, z + 2.0)).normalized()


# pesos do chão: r = terra/estrada, g = grama, b = pedra, a = região (255 - faixa * 40)
func ground(x: float, z: float) -> Color:
	return splat_img.get_pixel(clampi(roundi(x / step), 0, n - 1), clampi(roundi(z / step), 0, n - 1))


func nearest_town(x: float, z: float) -> Dictionary:
	var best := {}
	var bd := 1e9
	for t in info.towns:
		var d := Vector2(x - t.x, z - t.z).length()
		if d < bd:
			bd = d
			best = t
	return {"town": best, "dist": bd}


func town_by_id(id: String) -> Dictionary:
	for t in info.towns:
		if t.id == id:
			return t
	return info.towns[0]


# ---------- blocos de terreno ----------
func _chunk_mesh(cx: int, cz: int, lod: int) -> ArrayMesh:
	var cells := 50 if lod == 0 else 10
	var st := CH / cells
	var w := cells + 3
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.resize(w * w)
	norms.resize(w * w)
	for j in w:
		for i in w:
			var ci := clampi(i - 1, 0, cells)
			var cj := clampi(j - 1, 0, cells)
			var x := cx * CH + ci * st
			var z := cz * CH + cj * st
			var y := height(x, z)
			if ci != i - 1 or cj != j - 1:
				y -= 6.0 if lod == 0 else 14.0  # saia: esconde frestas entre blocos de detalhe diferente
			verts[j * w + i] = Vector3(ci * st, y, cj * st)
			norms[j * w + i] = normal(x, z)
	for j in w - 1:
		for i in w - 1:
			var a := j * w + i
			idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, terrain_mat)
	return mesh


func _make_chunk(key: Vector2i, lod: int) -> void:
	if chunks.has(key):
		(chunks[key].node as Node).queue_free()
	var mi := MeshInstance3D.new()
	mi.mesh = _chunk_mesh(key.x, key.y, lod)
	mi.position = Vector3(key.x * CH, 0.0, key.y * CH)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	chunks[key] = {"node": mi, "lod": lod}
	if lod == 0:
		_vegetation(key, mi)
	counts.blocos = chunks.size()


# carrega e descarta blocos em volta de um ponto; budget = quantos blocos novos por chamada
func stream(center: Vector3, budget := 3) -> void:
	var cc := Vector2i(floori(center.x / CH), floori(center.z / CH))
	var reach := ceili(far_r / CH)
	var maxc := int(size / CH) - 1
	var todo: Array = []
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var key := cc + Vector2i(dx, dz)
			if key.x < 0 or key.y < 0 or key.x > maxc or key.y > maxc:
				continue
			var d := Vector2((key.x + 0.5) * CH - center.x, (key.y + 0.5) * CH - center.z).length()
			if d > far_r + CH:
				continue
			var lod := 0 if d < near_r else 1
			var cur: Dictionary = chunks.get(key, {})
			if cur.is_empty() or (cur.lod != lod and (lod == 0 or d > near_r + CH * 0.6)):
				todo.append([d, key, lod])
	todo.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(budget, todo.size()):
		_make_chunk(todo[i][1], todo[i][2])
	for key in chunks.keys():
		var d := Vector2((key.x + 0.5) * CH - center.x, (key.y + 0.5) * CH - center.z).length()
		if d > far_r + CH * 2.5:
			(chunks[key].node as Node).queue_free()
			chunks.erase(key)
			trunks.erase(key)
	_stream_grass(center)
	if water:
		water.position = Vector3(center.x, WATER_Y, center.z)


func pending(center: Vector3) -> bool:
	var cc := Vector2i(floori(center.x / CH), floori(center.z / CH))
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var cur: Dictionary = chunks.get(cc + Vector2i(dx, dz), {})
			if cur.is_empty() or cur.lod != 0:
				return true
	return false


func reset_stream() -> void:
	for key in chunks.keys():
		(chunks[key].node as Node).queue_free()
	chunks.clear()
	trunks.clear()
	for key in grass.keys():
		if grass[key]:
			(grass[key] as Node).queue_free()
	grass.clear()


# ---------- modelos ----------
func _meshes(node: Node, xf: Transform3D, out: Array) -> void:
	for c in node.get_children():
		var t := xf
		if c is Node3D:
			t = xf * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			out.append([(c as MeshInstance3D).mesh, t])
		_meshes(c, t, out)


func _model(file: String) -> Dictionary:
	if models.has(file):
		return models[file]
	var sc: Node3D = (load("res://assets/world/%s.glb" % file) as PackedScene).instantiate()
	var parts: Array = []
	_meshes(sc, Transform3D.IDENTITY, parts)
	var bb := AABB()
	var first := true
	for p in parts:
		var a: AABB = (p[1] as Transform3D) * (p[0] as Mesh).get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	sc.free()
	models[file] = {"parts": parts, "bb": bb}
	return models[file]


# desenha um modelo em vários pontos de uma vez; pts em coordenadas do mundo, nó filho de `parent`
func place(parent: Node3D, file: String, pts: Array, target_h: float, shadows := true, vis_end := 0.0) -> Vector3:
	var m := _model(file)
	var bb: AABB = m.bb
	var k := target_h / bb.size.y
	var c := bb.get_center()
	var norm := Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(-c.x, -bb.position.y, -c.z))
	var inv := parent.global_transform.affine_inverse() if parent.is_inside_tree() else Transform3D(Basis.IDENTITY, -parent.position)
	for p in m.parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _lit(p[0])
		mm.instance_count = pts.size()
		for i in pts.size():
			mm.set_instance_transform(i, inv * (pts[i] as Transform3D) * norm * (p[1] as Transform3D))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		if not shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if vis_end > 0.0:
			mi.visibility_range_end = vis_end
			mi.visibility_range_end_margin = 10.0
		parent.add_child(mi)
	return bb.size * k


# superfícies chamadas "Fire" nos modelos passam a brilhar como fogo
func _lit(mesh: Mesh) -> Mesh:
	var hit := false
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m and m.resource_name == "Fire":
			hit = true
	if not hit:
		return mesh
	if fire_mat == null:
		fire_mat = StandardMaterial3D.new()
		fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fire_mat.albedo_color = Color(1.0, 0.55, 0.12)
	var d: Mesh = mesh.duplicate()
	for i in d.get_surface_count():
		var m := d.surface_get_material(i)
		if m and m.resource_name == "Fire":
			d.surface_set_material(i, fire_mat)
	return d


func at(x: float, z: float, yaw := 0.0, s := 1.0, sink := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(x, height(x, z) - sink, z))


func block(x: float, z: float, r: float) -> void:
	var key := Vector2i(floori(x / 8.0), floori(z / 8.0))
	if not blockers.has(key):
		blockers[key] = []
	blockers[key].append(Vector3(x, z, r))


# empurra um ponto para fora dos obstáculos e não deixa entrar em água funda nem sair do mapa
func resolve(p: Vector3, from: Vector3) -> Vector3:
	var cx := floori(p.x / 8.0)
	var cz := floori(p.z / 8.0)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var list: Array = blockers.get(Vector2i(cx + dx, cz + dz), [])
			for b in list:
				var v := Vector2(p.x - b.x, p.z - b.y)
				var d := v.length()
				var r: float = b.z + 0.35
				if d < r and d > 0.001:
					v = v / d * r
					p.x = b.x + v.x
					p.z = b.y + v.y
	var kc := Vector2i(floori(p.x / CH), floori(p.z / CH))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var tl: Array = trunks.get(kc + Vector2i(dx, dz), [])
			for b in tl:
				var v := Vector2(p.x - b.x, p.z - b.y)
				var d := v.length()
				var r: float = b.z + 0.3
				if d < r and d > 0.001:
					v = v / d * r
					p.x = b.x + v.x
					p.z = b.y + v.y
	p.x = clampf(p.x, 8.0, size - 8.0)
	p.z = clampf(p.z, 8.0, size - 8.0)
	if height(p.x, p.z) < WATER_Y - 1.1 and height(from.x, from.z) >= height(p.x, p.z):
		return from
	return p


# ---------- vegetação por bloco ----------
const TREES := [
	[["n_commontree_1", 8.5], ["n_commontree_2", 9.5], ["q_birchtree_1", 9.0]],
	[["n_commontree_2", 9.0], ["q_birchtree_1", 9.5], ["q_willow_1", 8.5]],
	[["n_pine_1", 11.0], ["n_pine_3", 10.0], ["n_commontree_3", 8.0]],
	[["n_commontree_1", 10.5], ["n_commontree_3", 9.5], ["q_willow_1", 10.0]],
	[["n_pine_3", 9.0], ["n_commontree_3", 7.0]],
	[["n_pine_1", 12.0], ["n_pine_2", 13.0]],
]
const DENSITY := [34, 26, 30, 60, 12, 24]


func _vegetation(key: Vector2i, parent: Node3D) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = key.x * 7349 + key.y * 9151 + 17
	var mid := ground((key.x + 0.5) * CH, (key.y + 0.5) * CH)
	var band := clampi(roundi((255.0 - mid.a8) / 40.0), 0, 5)
	var by_file := {}
	var tk: Array = []
	trunks[key] = tk
	for i in DENSITY[band]:
		var x := (key.x + r.randf()) * CH
		var z := (key.y + r.randf()) * CH
		var pick: Array = TREES[band][r.randi() % TREES[band].size()]
		var s := r.randf_range(0.75, 1.35)
		var yaw := r.randf() * TAU
		var g := ground(x, z)
		if g.g < 0.75 or height(x, z) < 1.6 or nearest_town(x, z).dist < 100.0:
			continue
		if not by_file.has(pick[0]):
			by_file[pick[0]] = [pick[1], []]
		by_file[pick[0]][1].append(at(x, z, yaw, s, 0.15))
		tk.append(Vector3(x, z, 0.4 * s))
	for f in by_file:
		place(parent, f, by_file[f][1], by_file[f][0], tree_shadows)
		counts.arvores += (by_file[f][1] as Array).size()
	if detail_f <= 0.0:
		return
	var small := [["n_rock_medium_1", 1.2, 5, 0.0, true], ["n_rock_large_1", 3.0, 2, 0.0, true], ["n_bush_common", 1.2, 14, 150.0, true], ["n_fern_1", 0.7, 26, 90.0, false], ["n_flower_3_group", 0.5, 22, 80.0, false], ["n_mushroom_common", 0.35, 8, 60.0, false]]
	for sdef in small:
		var pts: Array = []
		for i in int(sdef[2] * detail_f):
			var x := (key.x + r.randf()) * CH
			var z := (key.y + r.randf()) * CH
			var g := ground(x, z)
			var rocky: bool = String(sdef[0]).begins_with("n_rock")
			if height(x, z) < 1.4 or g.r > 0.3 or nearest_town(x, z).dist < 70.0 or (not rocky and g.g < 0.6):
				continue
			pts.append(at(x, z, r.randf() * TAU, r.randf_range(0.6, 1.5), 0.1))
		if not pts.is_empty():
			place(parent, sdef[0], pts, sdef[1], sdef[4] and tree_shadows, sdef[3] * maxf(detail_f, 0.3))


# ---------- grama ----------
func _blade_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for b in 6:
		var o := Vector3(r.randf_range(-0.22, 0.22), 0.0, r.randf_range(-0.22, 0.22))
		var yaw := r.randf() * TAU
		var side := Vector3(cos(yaw), 0.0, sin(yaw)) * 0.03
		var lean := Vector3(-sin(yaw), 0.0, cos(yaw)) * r.randf_range(0.03, 0.14)
		var h := r.randf_range(0.16, 0.34)
		var s := v.size()
		v.append_array([o - side, o + side, o - side * 0.6 + Vector3(0, h * 0.55, 0) + lean * 0.5, o + side * 0.6 + Vector3(0, h * 0.55, 0) + lean * 0.5, o + Vector3(0, h, 0) + lean])
		uv.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 0.55), Vector2(1, 0.55), Vector2(0.5, 1)])
		idx.append_array([s, s + 1, s + 2, s + 1, s + 3, s + 2, s + 2, s + 3, s + 4])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sh := Shader.new()
	sh.code = GRASS_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	m.surface_set_material(0, mat)
	return m



func _stream_grass(center: Vector3) -> void:
	var cell := 25.0
	var cc := Vector2i(floori(center.x / cell), floori(center.z / cell))
	for key in grass.keys():
		if grass_r <= 0.0 or Vector2((key.x + 0.5) * cell - center.x, (key.y + 0.5) * cell - center.z).length() > grass_r + cell * 2.0:
			if grass[key]:
				(grass[key] as Node).queue_free()
			grass.erase(key)
	if grass_r <= 0.0:
		return
	var reach := ceili(grass_r / cell)
	var best := Vector2i(-99999, 0)
	var bd := 1e9
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var key := cc + Vector2i(dx, dz)
			if grass.has(key):
				continue
			var d := Vector2((key.x + 0.5) * cell - center.x, (key.y + 0.5) * cell - center.z).length()
			if d < grass_r + cell * 0.7 and d < bd:
				bd = d
				best = key
	if best.x == -99999:
		return
	var r := RandomNumberGenerator.new()
	r.seed = best.x * 5171 + best.y * 3571
	var ox := (best.x + 0.5) * cell
	var oz := (best.y + 0.5) * cell
	var xfs: Array[Transform3D] = []
	for k in 1500:
		var x := ox + r.randf_range(-cell, cell) * 0.5
		var z := oz + r.randf_range(-cell, cell) * 0.5
		var g := ground(x, z)
		if g.g < 0.8 or g.a8 < 110 or height(x, z) < 1.3:
			continue
		var s := r.randf_range(0.8, 1.3)
		xfs.append(Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.8, 1.3), s)), Vector3(x - ox, height(x, z), z - oz)))
	if xfs.is_empty():
		grass[best] = null
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = blade
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.position = Vector3(ox, 0.0, oz)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = grass_r
	mi.visibility_range_end_margin = 8.0
	add_child(mi)
	grass[best] = mi
	counts.grama += xfs.size()


# ---------- cidades ----------
func _building(parent: Node3D, file: String, x: float, z: float, h: float, cx: float, cz: float) -> void:
	var sz := place(parent, file, [at(x, z, atan2(cx - x, cz - z), 1.0, 0.15)], h, true, 900.0)
	block(x, z, maxf(sz.x, sz.z) * 0.42)


func _build_town(t: Dictionary) -> void:
	var cx: float = t.x
	var cz: float = t.z
	var root := Node3D.new()
	root.name = t.id
	root.position = Vector3(cx, 0, cz)
	add_child(root)
	var r := RandomNumberGenerator.new()
	r.seed = hash(t.id)
	var kinds := ["b_house_1", "b_house_2", "b_house_3", "b_house_4"]
	for ring in 2:
		var count := 9 if ring == 0 else 14
		var rad := 30.0 if ring == 0 else 50.0
		for i in count:
			var a := TAU * (i + 0.5 * ring) / count + 0.3
			if _near_gate(t, a, 0.22 if ring == 1 else 0.3):
				continue  # ruas que levam aos portões
			var rr := rad + r.randf_range(-2.5, 2.5)
			_building(root, kinds[r.randi() % 4], cx + sin(a) * rr, cz + cos(a) * rr, r.randf_range(6.8, 8.2), cx, cz)
	_building(root, "b_inn", cx - 7.0, cz - 66.0, 10.5, cx, cz)
	_building(root, "b_blacksmith", cx - 66.0, cz - 12.0, 6.8, cx, cz)
	_building(root, "b_stable", cx + 66.0, cz + 18.0, 6.2, cx, cz)
	_building(root, "b_bell_tower", cx + 14.0, cz - 16.0, 17.0, cx, cz)
	_building(root, "b_mill", cx - 60.0, cz + 52.0, 13.0, cx, cz)
	_building(root, "b_well", cx + 7.0, cz + 6.0, 2.6, cx + 30.0, cz + 30.0)
	_building(root, "b_marketstand_1", cx - 10.0, cz + 9.0, 3.1, cx, cz)
	_building(root, "b_marketstand_2", cx - 12.5, cz - 3.0, 3.1, cx, cz)
	place(root, "b_cart", [at(cx + 11.0, cz - 7.0, 0.8)], 1.6, true, 200.0)
	place(root, "b_barrel", [at(cx - 7.0, cz + 11.5, 0.2), at(cx - 6.1, cz + 12.2, 1.3), at(cx + 13.5, cz + 3.0, 2.0)], 1.0, true, 150.0)
	place(root, "b_crate", [at(cx - 8.2, cz + 12.6, 0.5), at(cx - 14.0, cz - 1.4, 1.1), at(cx + 12.4, cz - 9.2, 0.3)], 0.85, true, 150.0)
	place(root, "b_bench_1", [at(cx + 3.5, cz - 9.5, 0.0), at(cx - 4.5, cz - 9.0, 0.3), at(cx + 9.5, cz + 9.5, 2.3)], 0.95, true, 150.0)
	place(root, "b_bonfire_lit", [at(cx, cz)], 1.5, true, 300.0)
	block(cx, cz, 0.8)
	var gy := height(cx, cz)
	var bf: Node3D = FX.fire(1.25)
	bf.position = Vector3(0.0, gy + 0.55, 0.0)
	root.add_child(bf)
	fires.append(bf)
	# tochas em volta da praça e nas entradas
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.09
	pole.height = 2.4
	pole.radial_segments = 6
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.25, 0.17, 0.1)
	pole.material = pm
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var rr := 20.0 if i % 2 == 0 else 66.0
		var tx := sin(a) * rr
		var tz := cos(a) * rr
		var ty := height(cx + tx, cz + tz)
		var post := MeshInstance3D.new()
		post.mesh = pole
		post.position = Vector3(tx, ty + 1.2, tz)
		post.visibility_range_end = 160.0
		root.add_child(post)
		var tf: Node3D = FX.fire(0.5, false)
		tf.position = Vector3(tx, ty + 2.5, tz)
		root.add_child(tf)
		fires.append(tf)
		block(cx + tx, cz + tz, 0.2)
	# anel dourado no chão: limite da zona segura
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 69.6
	tm.outer_radius = 70.0
	tm.rings = 96
	tm.ring_segments = 4
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(1.0, 0.82, 0.4, 0.55)
	tm.material = rmat
	ring.mesh = tm
	ring.position = Vector3(0.0, gy + 0.12, 0.0)
	ring.scale = Vector3(1.0, 0.2, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var l := OmniLight3D.new()
	l.position = Vector3(0.0, height(cx, cz) + 1.3, 0.0)
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 3.0
	l.omni_range = 16.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = 90.0
	root.add_child(l)
	var plate := Label3D.new()
	plate.text = t.name
	plate.font = load("res://assets/cinzel.ttf")
	plate.font_size = 96
	plate.pixel_size = 0.02
	plate.outline_size = 18
	plate.modulate = Color(1.0, 0.9, 0.62)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.position = Vector3(0.0, height(cx, cz) + 22.0, 0.0)
	plate.visibility_range_begin = 60.0
	plate.visibility_range_end = 700.0
	root.add_child(plate)


func _near_gate(t: Dictionary, a: float, tol: float) -> bool:
	for g in t.get("gates", []):
		if absf(wrapf(a - float(g), -PI, PI)) < tol:
			return true
	return false


func _stone(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/world/t_rock.webp")
	m.albedo_color = Color(col.r * 1.7, col.g * 1.7, col.b * 1.7)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	m.roughness = 0.95
	return m


func _boxes(parent: Node3D, mat: Material, xfs: Array, vis := 700.0) -> void:
	if xfs.is_empty():
		return
	var bm := BoxMesh.new()
	bm.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bm
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.visibility_range_end = vis
	parent.add_child(mi)


# caixa de tamanho `size`, centrada em `pos` (coordenadas da cidade), girada em Y
func _box(pos: Vector3, size: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(size), pos)


# muralha de pedra em volta da cidade, com torres e um portão em cada estrada
func _build_walls(t: Dictionary) -> void:
	var cx: float = t.x
	var cz: float = t.z
	var root: Node3D = get_node(str(t.id))
	var tones := [Color(0.72, 0.7, 0.66), Color(0.8, 0.74, 0.58), Color(0.62, 0.62, 0.64), Color(0.6, 0.68, 0.6), Color(0.7, 0.5, 0.42), Color(0.78, 0.86, 0.95)]
	var mat := _stone(tones[clampi(int(t.band), 0, 5)])
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.22, 0.13)
	var gy := height(cx, cz)
	var R := 86.0
	var segs := 60
	var walls: Array = []
	var merlons: Array = []
	var towers: Array = []
	var beams: Array = []
	for i in segs:
		var a := TAU * (i + 0.5) / segs
		if _near_gate(t, a, 0.075):
			continue
		var p := Vector3(sin(a) * R, gy + 3.0, cos(a) * R)
		var len := TAU * R / segs + 0.3
		walls.append(_box(p, Vector3(len, 6.6, 1.7), a))
		for k in 3:
			var off := (k - 1) * len / 3.0
			merlons.append(_box(p + Vector3(cos(a), 0, -sin(a)) * off + Vector3(sin(a), 0, cos(a)) * 0.45 + Vector3(0, 3.75, 0), Vector3(len / 5.0, 0.9, 0.7), a))
		if i % 6 == 0:
			towers.append(_box(Vector3(sin(a) * R, gy + 4.6, cos(a) * R), Vector3(4.6, 10.2, 4.6), a))
		for k in 5:
			var bx := cx + p.x + cos(a) * (k - 2) * len / 5.0
			var bz := cz + p.z - sin(a) * (k - 2) * len / 5.0
			block(bx, bz, 1.0)
	for g in t.get("gates", []):
		var a := float(g)
		var side := Vector3(cos(a), 0, -sin(a))
		var c := Vector3(sin(a) * R, gy, cos(a) * R)
		for sgn in [-1.0, 1.0]:
			var tp: Vector3 = c + side * sgn * 5.6
			towers.append(_box(tp + Vector3(0, 5.6, 0), Vector3(4.2, 12.0, 4.2), a))
			block(cx + tp.x, cz + tp.z, 2.4)
			var tf: Node3D = FX.fire(0.5, false)
			tf.position = tp + Vector3(sin(a), 0, cos(a)) * 2.6 + Vector3(0, 3.4, 0)
			root.add_child(tf)
		walls.append(_box(c + Vector3(0, 8.4, 0), Vector3(8.0, 3.0, 1.9), a))
		beams.append(_box(c + Vector3(0, 6.7, 0), Vector3(7.6, 0.45, 2.3), a))
	_boxes(root, mat, walls)
	_boxes(root, mat, merlons, 260.0)
	_boxes(root, mat, towers)
	_boxes(root, wood, beams, 300.0)


# ponte de madeira nos trechos em que a estrada cruza a água
func _build_bridge(b: Array) -> void:
	var a := Vector3(float(b[0]), 0, float(b[1]))
	var c := Vector3(float(b[2]), 0, float(b[3]))
	var dir := (c - a).normalized()
	var yaw := atan2(dir.x, dir.z)
	var len := a.distance_to(c) + 14.0
	var mid := (a + c) * 0.5
	var root := Node3D.new()
	root.name = "Ponte"
	root.position = Vector3(mid.x, 2.3, mid.z)
	add_child(root)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.3, 0.18)
	wood.roughness = 0.9
	var parts: Array = [_box(Vector3.ZERO, Vector3(6.0, 0.35, len), yaw)]
	var side := Vector3(dir.z, 0, -dir.x)
	for sgn in [-1.0, 1.0]:
		parts.append(_box(side * sgn * 2.9 + Vector3(0, 1.0, 0), Vector3(0.18, 0.18, len), yaw))
		for k in range(0, int(len / 4.0) + 1):
			var along := dir * (k * 4.0 - len * 0.5)
			parts.append(_box(side * sgn * 2.9 + along + Vector3(0, -1.2, 0), Vector3(0.3, 4.6, 0.3), yaw))
	_boxes(root, wood, parts, 500.0)


func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(4200, 4200)
	var tex := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	tex.noise = fn
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 5.0
	var sh := Shader.new()
	sh.code = WATER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("waves", tex)
	mat.set_shader_parameter("heights", ImageTexture.create_from_image(Image.create_from_data(n, n, false, Image.FORMAT_RG8, hb)))
	mat.set_shader_parameter("cells", float(n))
	mat.set_shader_parameter("lo", lo)
	mat.set_shader_parameter("hrange", hrange)
	pm.material = mat
	water = MeshInstance3D.new()
	water.mesh = pm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


# ---------- céu e luz ----------
func _build_sky() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.18, 0.36, 0.68)
	sky_mat.sky_horizon_color = Color(0.72, 0.8, 0.88)
	sky_mat.ground_bottom_color = Color(0.12, 0.14, 0.12)
	sky_mat.ground_horizon_color = Color(0.72, 0.8, 0.88)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.58, 0.68, 0.8)
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.0
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.9, 0.93, 1.0)
	env.volumetric_fog_length = 160.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -128.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 170.0
	sun.shadow_blur = 1.2
	sun.light_volumetric_fog_energy = 1.4
	add_child(sun)



# nível de detalhe do cenário: 0 = mínimo ... 4 = ultra
func set_detail(q: int) -> void:
	near_r = [150.0, 200.0, 300.0, 350.0, 450.0][q]
	far_r = [450.0, 700.0, 1100.0, 1400.0, 1800.0][q]
	grass_r = [0.0, 28.0, 45.0, 70.0, 110.0][q]
	var new_detail: float = [0.0, 0.5, 1.0, 1.0, 1.4][q]
	var new_shadows := q >= 1
	if new_detail != detail_f or new_shadows != tree_shadows:
		detail_f = new_detail
		tree_shadows = new_shadows
		reset_stream()
	for g in grass.values():
		if g:
			(g as MultiMeshInstance3D).visibility_range_end = grass_r
	base_fog = [0.003, 0.002, 0.0012, 0.001, 0.0008][q]
	env.fog_density = base_fog
	FX.amount = [0.35, 0.6, 1.0, 1.0, 1.3][q]
