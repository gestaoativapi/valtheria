extends Node3D
# Mundo do protótipo: terreno, vila, floresta, grama, lago, céu e luz.

const SIZE := 520.0
const LAKE := Vector2(96.0, -62.0)
const WATER_Y := -1.3

var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var env: Environment
var sun: DirectionalLight3D
var fire: OmniLight3D
var grass_nodes: Array[MultiMeshInstance3D] = []
var tree_nodes: Array[MultiMeshInstance3D] = []
var detail_nodes: Array[MultiMeshInstance3D] = []
var detail_range := {}
var blockers := {}  # célula -> [Vector3(x, z, raio)]
var counts := {"arvores": 0, "grama": 0, "objetos": 0}

const TERRAIN_SHADER := """
shader_type spatial;
uniform sampler2D grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wpos.xz * 0.2;
	float big = texture(grass, uv * 0.045).g;
	vec3 g = texture(grass, uv).rgb * mix(0.72, 1.18, big);
	vec3 d = texture(dirt, uv * 0.9).rgb * vec3(0.72, 0.78, 0.8);
	vec3 r = texture(rock, uv * 0.45).rgb;
	vec3 w = COLOR.rgb / max(COLOR.r + COLOR.g + COLOR.b, 0.001);
	ALBEDO = g * w.g + d * w.r + r * w.b;
	ROUGHNESS = 0.96;
	SPECULAR = 0.15;
}
"""

const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec3 base : source_color = vec3(0.16, 0.3, 0.08);
uniform vec3 tip : source_color = vec3(0.46, 0.62, 0.2);
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
	ROUGHNESS = 0.9;
}
"""

const WATER_SHADER := """
shader_type spatial;
uniform sampler2D waves : hint_normal, repeat_enable, filter_linear_mipmap;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wpos.xz * 0.05;
	vec3 a = texture(waves, uv + TIME * vec2(0.012, 0.008)).rgb;
	vec3 b = texture(waves, uv * 1.7 - TIME * vec2(0.01, 0.014)).rgb;
	NORMAL_MAP = mix(a, b, 0.5);
	NORMAL_MAP_DEPTH = 0.9;
	ALBEDO = vec3(0.05, 0.22, 0.27);
	ALPHA = 0.86;
	ROUGHNESS = 0.05;
	SPECULAR = 0.7;
}
"""


func _init() -> void:
	noise.seed = 7
	noise.frequency = 0.011
	noise.fractal_octaves = 4
	noise2.seed = 21
	noise2.frequency = 0.06
	rng.seed = 12345


func build() -> void:
	_build_sky()
	_build_terrain()
	_build_water()
	_build_village()
	_build_forest()
	_build_grass()


# ---------- relevo ----------
func height(x: float, z: float) -> float:
	var d := sqrt(x * x + z * z)
	var h := noise.get_noise_2d(x, z) * 8.0 + noise2.get_noise_2d(x, z) * 0.9
	h *= smoothstep(36.0, 90.0, d)
	var dl := Vector2(x - LAKE.x, z - LAKE.y).length()
	h = lerpf(h, -4.5, 1.0 - smoothstep(16.0, 48.0, dl))
	h += smoothstep(175.0, 255.0, d) * 48.0 * (0.65 + 0.35 * noise.get_noise_2d(x * 0.6 + 300.0, z * 0.6))
	return h


func normal(x: float, z: float) -> Vector3:
	return Vector3(height(x - 1.0, z) - height(x + 1.0, z), 2.0, height(x, z - 1.0) - height(x, z + 1.0)).normalized()


func on_path(x: float, z: float) -> float:
	var d := sqrt(x * x + z * z)
	var w := 1.0 - smoothstep(15.0, 19.0, d)  # praça
	var road := absf(x + sin(z * 0.05) * 5.0)  # estrada para o sul
	if z > 10.0 and z < 150.0:
		w = maxf(w, 1.0 - smoothstep(1.8, 3.4, road))
	var road2 := absf(z + sin(x * 0.06) * 4.0)  # estrada para o lago
	if x > 10.0 and x < 70.0:
		w = maxf(w, 1.0 - smoothstep(1.6, 3.0, road2))
	return w


# pesos do chão: r = terra, g = grama, b = pedra
func ground(x: float, z: float) -> Color:
	var n := normal(x, z)
	var h := height(x, z)
	var rock := smoothstep(0.22, 0.42, 1.0 - n.y) + smoothstep(22.0, 34.0, h)
	var dirt := on_path(x, z)
	dirt = maxf(dirt, 1.0 - smoothstep(WATER_Y + 0.2, WATER_Y + 1.6, h))  # margem do lago
	dirt += noise2.get_noise_2d(x * 2.0, z * 2.0) * 0.12 * dirt
	rock = clampf(rock, 0.0, 1.0)
	dirt = clampf(dirt, 0.0, 1.0) * (1.0 - rock)
	return Color(dirt, maxf(0.0, 1.0 - dirt - rock), rock)


func _build_terrain() -> void:
	var n := 240
	var step := SIZE / n
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in n + 1:
		for i in n + 1:
			var x := -SIZE / 2.0 + i * step
			var z := -SIZE / 2.0 + j * step
			verts.append(Vector3(x, height(x, z), z))
			norms.append(normal(x, z))
			cols.append(ground(x, z))
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + n + 1
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sh := Shader.new()
	sh.code = TERRAIN_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("grass", load("res://assets/world/t_grass.webp"))
	mat.set_shader_parameter("dirt", load("res://assets/world/t_dirt.webp"))
	mat.set_shader_parameter("rock", load("res://assets/world/t_rock.webp"))
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Terreno"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(130, 130)
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
	pm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.name = "Lago"
	mi.position = Vector3(LAKE.x, WATER_Y, LAKE.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


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
	env.fog_light_color = Color(0.68, 0.77, 0.86)
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.5
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


# ---------- modelos ----------
func _meshes(n: Node, xf: Transform3D, out: Array) -> void:
	for c in n.get_children():
		var t := xf
		if c is Node3D:
			t = xf * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			out.append([(c as MeshInstance3D).mesh, t])
		_meshes(c, t, out)


func _bounds(parts: Array) -> AABB:
	var bb := AABB()
	var first := true
	for p in parts:
		var a: AABB = (p[1] as Transform3D) * (p[0] as Mesh).get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	return bb


# espalha um modelo em vários pontos de uma vez (um desenho por malha, não por objeto)
func place(file: String, pts: Array, target_h: float, shadows := true, vis_end := 0.0, kind := "") -> AABB:
	var sc: Node3D = (load("res://assets/world/%s.glb" % file) as PackedScene).instantiate()
	var parts: Array = []
	_meshes(sc, Transform3D.IDENTITY, parts)
	var bb := _bounds(parts)
	var k := target_h / bb.size.y
	var c := bb.get_center()
	var norm := Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(-c.x, -bb.position.y, -c.z))
	# divide em blocos de 64 m: a placa só desenha os blocos que estão na tela e perto
	var cells := {}
	for t in pts:
		var o: Vector3 = (t as Transform3D).origin
		var key := Vector2i(floori(o.x / 64.0), floori(o.z / 64.0)) if pts.size() > 12 else Vector2i.ZERO
		if not cells.has(key):
			cells[key] = []
		cells[key].append(t)
	for key in cells:
		var list: Array = cells[key]
		var center := Vector3.ZERO
		for t in list:
			center += (t as Transform3D).origin
		center /= list.size()
		var shift := Transform3D(Basis.IDENTITY, -center)
		for p in parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = p[0]
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, shift * (list[i] as Transform3D) * norm * (p[1] as Transform3D))
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.name = file
			mi.position = center
			if not shadows:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if vis_end > 0.0:
				mi.visibility_range_end = vis_end
				mi.visibility_range_end_margin = 12.0
				mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(mi)
			if kind == "tree":
				tree_nodes.append(mi)
			elif kind == "detail":
				detail_nodes.append(mi)
				detail_range[mi] = vis_end
	sc.free()
	counts.objetos += pts.size()
	return AABB(Vector3(-bb.size.x, 0, -bb.size.z) * k * 0.5, bb.size * k)


# nível de detalhe do cenário: 0 = mínimo ... 4 = ultra
func set_detail(q: int) -> void:
	var tree_r: float = [120.0, 190.0, 0.0, 0.0, 0.0][q]
	for t in tree_nodes:
		t.visibility_range_end = tree_r
		t.visibility_range_end_margin = 15.0 if tree_r > 0.0 else 0.0
		t.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if q >= 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var f: float = [0.0, 0.5, 1.0, 1.0, 1.4][q]
	for d in detail_nodes:
		d.visible = f > 0.0
		d.visibility_range_end = float(detail_range[d]) * maxf(f, 0.1)
		d.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if q >= 2 else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	set_grass_range([0.0, 28.0, 45.0, 70.0, 110.0][q])
	for g in grass_nodes:
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if q >= 2 else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	env.fog_density = [0.0042, 0.0028, 0.0016, 0.0016, 0.0016][q]


func at(x: float, z: float, yaw := 0.0, s := 1.0, sink := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(x, height(x, z) - sink, z))


func block(x: float, z: float, r: float) -> void:
	var key := Vector2i(floori(x / 8.0), floori(z / 8.0))
	if not blockers.has(key):
		blockers[key] = []
	blockers[key].append(Vector3(x, z, r))


# empurra um ponto para fora dos obstáculos
func resolve(p: Vector3) -> Vector3:
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
	var lim := SIZE * 0.5 - 60.0
	var d2 := Vector2(p.x, p.z).length()
	if d2 > lim:
		p.x *= lim / d2
		p.z *= lim / d2
	if height(p.x, p.z) < WATER_Y - 0.7:  # não entra fundo no lago
		var out := Vector2(p.x - LAKE.x, p.z - LAKE.y).normalized() * 0.25
		p.x += out.x
		p.z += out.y
	return p


func _building(file: String, x: float, z: float, h: float, face_center := true, yaw := 0.0) -> void:
	if face_center:
		yaw = atan2(-x, -z)
	var box := place(file, [at(x, z, yaw, 1.0, 0.15)], h)
	var r := maxf(box.size.x, box.size.z) * 0.42
	block(x, z, r)


func _build_village() -> void:
	var houses := ["b_house_1", "b_house_2", "b_house_3", "b_house_4", "b_house_2", "b_house_1", "b_house_4", "b_house_3"]
	for i in houses.size():
		var a := TAU * (i + 0.5) / houses.size() + 0.35
		if absf(wrapf(a - PI * 0.0, -PI, PI)) < 0.32:
			continue  # abertura para a estrada do sul
		_building(houses[i], sin(a) * 29.0, cos(a) * 29.0, 7.5)
	_building("b_inn", -6.0, -44.0, 10.0)
	_building("b_blacksmith", -42.0, -10.0, 6.5)
	_building("b_stable", 40.0, 22.0, 6.0)
	_building("b_bell_tower", 20.0, -42.0, 16.0)
	_building("b_mill", -70.0, 46.0, 13.0)
	_building("b_well", 6.5, 5.0, 2.6, false, 0.4)
	_building("b_marketstand_1", -9.0, 8.5, 3.1, false, 2.4)
	_building("b_marketstand_2", -11.5, -2.5, 3.1, false, 1.6)
	place("b_cart", [at(11.0, -7.0, 0.8)], 1.6)
	block(11.0, -7.0, 1.2)
	place("b_barrel", [at(-7.0, 11.0, 0.2), at(-6.1, 11.6, 1.3), at(13.5, 3.0, 2.0), at(-13.2, -4.0, 0.7)], 1.0)
	place("b_crate", [at(-8.2, 12.0, 0.5), at(-13.5, -1.2, 1.1), at(12.4, -9.2, 0.3)], 0.85)
	place("b_hay", [at(36.0, 16.0, 0.4), at(37.6, 17.2, 1.9), at(-66.0, 40.0, 1.0)], 1.3)
	place("b_bench_1", [at(3.5, -9.5, 0.0), at(-4.5, -9.0, 0.3), at(9.5, 9.5, 2.3)], 0.95)
	place("b_bonfire_lit", [at(0.0, 0.0)], 1.5)
	block(0.0, 0.0, 0.8)
	fire = OmniLight3D.new()
	fire.position = Vector3(0.0, 1.3, 0.0)
	fire.light_color = Color(1.0, 0.55, 0.2)
	fire.light_energy = 3.0
	fire.omni_range = 16.0
	fire.omni_attenuation = 1.4
	add_child(fire)


func _free_spot(x: float, z: float, min_d: float) -> bool:
	var d := sqrt(x * x + z * z)
	if d < min_d or d > SIZE * 0.5 - 20.0:
		return false
	if on_path(x, z) > 0.05:
		return false
	if height(x, z) < WATER_Y + 0.9:
		return false
	if normal(x, z).y < 0.8:
		return false
	return true


func _points(count: int, min_d: float, s_min: float, s_max: float, radius := 0.0, cluster := 0.0) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < count and tries < count * 30:
		tries += 1
		var x := rng.randf_range(-SIZE / 2.0, SIZE / 2.0)
		var z := rng.randf_range(-SIZE / 2.0, SIZE / 2.0)
		if not _free_spot(x, z, min_d):
			continue
		if cluster > 0.0 and noise.get_noise_2d(x * 1.7 + 900.0, z * 1.7) < cluster:
			continue
		out.append(at(x, z, rng.randf() * TAU, rng.randf_range(s_min, s_max), 0.1))
		if radius > 0.0:
			block(x, z, radius)
	return out


func _build_forest() -> void:
	var trees := {"n_commontree_1": [520, 8.5], "n_commontree_2": [520, 9.5], "n_commontree_3": [420, 8.0], "n_pine_1": [520, 11.0], "n_pine_2": [460, 12.5], "n_pine_3": [380, 10.0], "q_birchtree_1": [260, 9.0], "q_willow_1": [90, 8.5]}
	for f in trees:
		var pts := _points(trees[f][0], 46.0, 0.75, 1.35, 0.45, -0.12)
		place(f, pts, trees[f][1], true, 0.0, "tree")
		counts.arvores += pts.size()
	place("n_rock_large_1", _points(70, 44.0, 0.6, 1.6, 1.6), 3.2)
	place("n_rock_medium_1", _points(120, 40.0, 0.6, 1.5, 0.7), 1.3, true, 0.0, "tree")
	place("n_rock_medium_2", _points(120, 40.0, 0.6, 1.5, 0.7), 1.2)
	place("n_rock_medium_3", _points(120, 40.0, 0.6, 1.5, 0.7), 1.1)
	place("n_bush_common", _points(700, 36.0, 0.7, 1.4), 1.2, true, 150.0, "detail")
	place("n_bush_common_flowers", _points(500, 34.0, 0.7, 1.4), 1.2, true, 150.0, "detail")
	place("n_fern_1", _points(1600, 34.0, 0.7, 1.5), 0.7, false, 90.0, "detail")
	place("n_flower_3_group", _points(1300, 22.0, 0.8, 1.4), 0.5, false, 80.0, "detail")
	place("n_flower_4_group", _points(1300, 22.0, 0.8, 1.4), 0.5, false, 80.0, "detail")
	place("n_mushroom_common", _points(500, 40.0, 0.7, 1.6), 0.35, false, 60.0, "detail")


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


func _build_grass() -> void:
	var blade := _blade_mesh()
	var cell := 24.0
	var per := 1500
	for cz in range(-7, 7):
		for cx in range(-7, 7):
			var ox := (cx + 0.5) * cell
			var oz := (cz + 0.5) * cell
			var xfs: Array[Transform3D] = []
			for k in per:
				var x := ox + rng.randf_range(-cell, cell) * 0.5
				var z := oz + rng.randf_range(-cell, cell) * 0.5
				if on_path(x, z) > 0.2 or height(x, z) < WATER_Y + 1.2 or normal(x, z).y < 0.86:
					continue
				var s := rng.randf_range(0.8, 1.3)
				xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), Vector3(x - ox, height(x, z), z - oz)))
			if xfs.is_empty():
				continue
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
			mi.visibility_range_end = 70.0
			mi.visibility_range_end_margin = 10.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(mi)
			grass_nodes.append(mi)
			counts.grama += xfs.size()


func set_grass_range(r: float) -> void:
	for g in grass_nodes:
		g.visible = r > 0.0
		g.visibility_range_end = r


func _process(_dt: float) -> void:
	if fire:
		var t := Time.get_ticks_msec() * 0.001
		fire.light_energy = 3.0 + sin(t * 11.0) * 0.35 + sin(t * 23.0) * 0.2
