extends RefCounted
# Cidades especiais: Sylvar na árvore gigante, Umbraval dentro da montanha, Abissália no fundo do mar,
# Ilha de Coralis, enfeites das cidades médias e portais (redemoinhos) entre o porto, a ilha e o fundo do mar.

const FX = preload("res://scripts/fx.gd")


static func _mat(c: Color, rough := 0.9, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


static func _mesh(root: Node3D, mesh: Mesh, pos: Vector3, basis := Basis.IDENTITY, shadow := true, vis := 900.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(basis, pos)
	mi.visibility_range_end = vis
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


static func _cyl(r0: float, r1: float, h: float, mat: Material, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r0
	c.top_radius = r1
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	c.material = mat
	return c


static func _sphere(r: float, mat: Material, seg := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(4, seg / 2)
	s.material = mat
	return s


static func _motes(root: Node3D, pos: Vector3, ext: Vector3, col: Color, amount: int) -> void:
	var p := CPUParticles3D.new()
	p.amount = maxi(8, int(amount * FX.amount))
	p.lifetime = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.5
	p.gravity = Vector3(0, 0.15, 0)
	p.scale_amount_min = 0.08
	p.scale_amount_max = 0.18
	p.mesh = _sphere(0.5, _mat(col, 1.0, 4.0), 4)
	p.position = pos
	p.visibility_range_end = 220.0
	root.add_child(p)


static func _light(root: Node3D, pos: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.distance_fade_enabled = true
	l.distance_fade_begin = 160.0
	root.add_child(l)


# ---------- portal (redemoinho): pisar nele leva ao outro lado ----------
static func portal(w: Node3D, root: Node3D, pos: Vector3, to: Vector3, name: String, col := Color(0.3, 0.8, 1.0)) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 1.5
	ring.outer_radius = 1.9
	ring.rings = 24
	ring.ring_segments = 6
	ring.material = _mat(col, 0.3, 3.0)
	_mesh(root, ring, pos - root.position + Vector3(0, 0.15, 0), Basis.IDENTITY, false)
	var sw := CPUParticles3D.new()
	sw.amount = maxi(12, int(60 * FX.amount))
	sw.lifetime = 1.6
	sw.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	sw.emission_ring_axis = Vector3.UP
	sw.emission_ring_radius = 1.6
	sw.emission_ring_inner_radius = 0.6
	sw.emission_ring_height = 0.1
	sw.direction = Vector3.UP
	sw.spread = 15.0
	sw.initial_velocity_min = 1.0
	sw.initial_velocity_max = 2.2
	sw.orbit_velocity_min = 0.6
	sw.orbit_velocity_max = 0.9
	sw.gravity = Vector3.ZERO
	sw.scale_amount_min = 0.1
	sw.scale_amount_max = 0.2
	sw.mesh = _sphere(0.5, _mat(col, 1.0, 3.0), 4)
	sw.position = pos - root.position
	sw.visibility_range_end = 120.0
	root.add_child(sw)
	var l := Label3D.new()
	l.text = name
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.008
	l.font_size = 48
	l.outline_size = 12
	l.modulate = col.lightened(0.4)
	l.position = pos - root.position + Vector3(0, 3.2, 0)
	l.visibility_range_end = 60.0
	root.add_child(l)
	w.doors.append({"kind": "portal", "name": name, "pos": pos, "yaw": 0.0, "to": to})


# ---------- Sylvar: a cidade na Árvore-Mãe ----------
static func arvore(w: Node3D, t: Dictionary, root: Node3D) -> Dictionary:
	var cx: float = t.x
	var cz: float = t.z
	var g: float = w.height(cx, cz)
	var bark := StandardMaterial3D.new()
	bark.albedo_texture = load("res://assets/world/t_dirt.webp")
	bark.albedo_color = Color(0.62, 0.46, 0.34)
	bark.uv1_triplanar = true
	bark.uv1_world_triplanar = true
	bark.uv1_scale = Vector3(0.12, 0.04, 0.12)
	bark.roughness = 1.0
	var wood: StandardMaterial3D = w._wood_mat()
	var leaf := _mat(Color(0.24, 0.46, 0.2), 1.0, 0.0)
	var leaf2 := _mat(Color(0.3, 0.56, 0.26), 1.0, 0.0)
	var glow := _mat(Color(0.55, 1.0, 0.75), 0.5, 2.5)
	var gold := _mat(Color(1.0, 0.85, 0.45), 0.5, 3.0)
	var H := 84.0
	var r_at := func(y: float) -> float: return lerpf(11.0, 5.5, clampf(y / H, 0.0, 1.0))
	_mesh(root, _cyl(11.0, 5.5, H, bark, 20), Vector3(0, g + H * 0.5 - 1.0, 0))
	w.block(cx, cz, 12.0)
	# raízes enormes em arco
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 9:
		var a := TAU * i / 9.0 + 0.2
		var prev := Vector3(sin(a) * 9.0, g + 10.0, cos(a) * 9.0)
		for k in 5:
			var rr := 9.0 + (k + 1) * 5.2
			var yy := g + 10.0 * (1.0 - pow((k + 1) / 5.0, 0.7)) - 0.5
			var nxt := Vector3(sin(a + k * 0.05) * rr, yy, cos(a + k * 0.05) * rr)
			var mid := (prev + nxt) * 0.5
			var dir := (nxt - prev)
			var len := dir.length()
			var up := dir.normalized()
			var bas := Basis.looking_at(up, Vector3.UP if absf(up.y) < 0.95 else Vector3.FORWARD) * Basis(Vector3.RIGHT, PI * 0.5)
			_mesh(root, _cyl(2.6 - k * 0.38, 2.2 - k * 0.38, len + 1.0, bark, 10), mid, bas)
			prev = nxt
	# copa: nuvem de folhas e luzes penduradas
	for i in 22:
		var a := TAU * i / 22.0 + rng.randf() * 0.3
		var rr := rng.randf_range(14.0, 46.0)
		var pos := Vector3(sin(a) * rr, g + H + rng.randf_range(-14.0, 10.0) - rr * 0.18, cos(a) * rr)
		_mesh(root, _sphere(rng.randf_range(13.0, 21.0), leaf if i % 2 == 0 else leaf2, 10), pos, Basis.from_scale(Vector3(1.0, 0.55, 1.0)), true, 1600.0)
	_mesh(root, _sphere(24.0, leaf2, 12), Vector3(0, g + H + 14.0, 0), Basis.from_scale(Vector3(1.0, 0.7, 1.0)), true, 1600.0)
	for i in 26:
		var a := rng.randf() * TAU
		var rr := rng.randf_range(14.0, 40.0)
		var y := g + rng.randf_range(54.0, 74.0)
		_mesh(root, _sphere(0.45, glow if i % 3 else gold, 6), Vector3(sin(a) * rr, y, cos(a) * rr), Basis.IDENTITY, false, 300.0)
		_mesh(root, _cyl(0.02, 0.02, 3.0, wood, 3), Vector3(sin(a) * rr, y + 1.6, cos(a) * rr), Basis.IDENTITY, false, 120.0)
	# plataformas em volta do tronco, com casinhas e lanternas
	var houses := ["b_house_1", "b_house_2", "b_house_3", "b_house_4"]
	for lvl in 3:
		var y := g + 16.0 * (lvl + 1)
		var r1: float = r_at.call(16.0 * (lvl + 1)) + 0.3
		var r2 := r1 + 9.0
		var segs := 28
		var deck: Array = []
		var rail: Array = []
		for k in segs:
			var a := TAU * k / segs
			var rm := (r1 + r2) * 0.5
			deck.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3(TAU * r2 / segs + 0.3, 0.45, r2 - r1)), Vector3(sin(a) * rm, y - 0.22, cos(a) * rm)))
			if k % 2 == 0 and fposmod(a + 0.3, TAU) > 0.6:
				rail.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3(0.18, 1.1, 0.18)), Vector3(sin(a) * (r2 - 0.2), y + 0.55, cos(a) * (r2 - 0.2))))
			# vigas de apoio
			if k % 4 == 0:
				var sp := Vector3(sin(a) * (r2 - 1.0), y - 3.0, cos(a) * (r2 - 1.0))
				rail.append(Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.75).scaled(Vector3(0.35, 7.5, 0.35)), (sp + Vector3(sin(a) * r1, y - 5.0, cos(a) * r1)) * 0.5 + Vector3(0, 1.5, 0)))
		w._boxes(root, wood, deck, 700.0)
		w._boxes(root, wood, rail, 300.0)
		w.floors.append({"kind": "ring", "c": Vector2(cx, cz), "r1": r1 - 0.5, "r2": r2, "y": y})
		var pts: Array = []
		for k in 4:
			var a := TAU * k / 4.0 + 0.8 + lvl * 0.5
			var rm := r1 + 4.6
			pts.append(Transform3D(Basis(Vector3.UP, a + PI), Vector3(cx + sin(a) * rm, y, cz + cos(a) * rm)))
			w.lamps.append(Vector3(cx + sin(a + 0.4) * (r2 - 0.5), y + 2.2, cz + cos(a + 0.4) * (r2 - 0.5)))
			_mesh(root, _sphere(0.3, gold, 6), Vector3(sin(a + 0.4) * (r2 - 0.5), y + 2.2, cos(a + 0.4) * (r2 - 0.5)), Basis.IDENTITY, false, 200.0)
		w.place(root, houses[lvl % 4], pts, 4.6, true, 500.0)
	# rampa em espiral do chão até a última plataforma
	var hr1 := 19.6
	var hr2 := 23.6
	var pitch := 16.0 / TAU
	var ramp: Array = []
	var posts: Array = []
	var steps := 3 * 40
	for k in steps:
		var a0 := TAU * k / 40.0
		var a1 := TAU * (k + 1) / 40.0
		var am := (a0 + a1) * 0.5
		var rm := (hr1 + hr2) * 0.5
		var y := g + pitch * am
		var seg_len := rm * (a1 - a0)
		var tilt := atan2(pitch * (a1 - a0), seg_len)
		var bas := Basis(Vector3.UP, am + PI * 0.5) * Basis(Vector3.RIGHT, -tilt)
		ramp.append(Transform3D(bas.scaled(Vector3(hr2 - hr1, 0.35, seg_len + 0.15)), Vector3(sin(am) * rm, y - 0.18, cos(am) * rm)))
		if k % 3 == 0:
			posts.append(Transform3D(Basis.from_scale(Vector3(0.16, 1.1, 0.16)), Vector3(sin(am) * (hr2 - 0.15), y + 0.55, cos(am) * (hr2 - 0.15))))
		if k % 5 == 0 and y > g + 3.0:
			posts.append(Transform3D(Basis.from_scale(Vector3(0.4, y - g, 0.4)), Vector3(sin(am) * rm, g + (y - g) * 0.5, cos(am) * rm)))
	w._boxes(root, wood, ramp, 700.0)
	w._boxes(root, wood, posts, 260.0)
	w.floors.append({"kind": "helix", "c": Vector2(cx, cz), "r1": hr1 - 0.3, "r2": hr2 + 0.2, "y0": g, "y1": g + 48.2, "pitch": pitch, "turns": 3})
	# chão: casas entre as raízes, fonte de luz, árvores luminosas e cristais
	var gpts: Array = []
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in 16:
		var a := TAU * i / 16.0 + 0.11
		var rr := 44.0 + (i % 3) * 8.0
		var x := sin(a) * rr
		var z := cos(a) * rr
		if w._clear_of_gates(t, x, z, 8.0):
			gpts.append(w.at(cx + x, cz + z, a + PI))
			w.block(cx + x, cz + z, 3.6)
	w.place(root, "b_house_2", gpts.slice(0, gpts.size() / 2), 6.0, true, 900.0)
	w.place(root, "b_house_4", gpts.slice(gpts.size() / 2), 6.0, true, 900.0)
	var pool := MeshInstance3D.new()
	pool.mesh = _cyl(5.0, 5.0, 0.12, _mat(Color(0.3, 0.9, 1.0), 0.1, 2.0), 24)
	pool.position = Vector3(30.0, w.height(cx + 30.0, cz - 22.0) + 0.1, -22.0)
	root.add_child(pool)
	w.block(cx + 30.0, cz - 22.0, 5.0)
	_light(root, Vector3(30.0, pool.position.y + 2.0, -22.0), Color(0.4, 1.0, 0.9), 2.5, 14.0)
	var crys := _mat(Color(0.6, 0.85, 1.0), 0.2, 2.2)
	for i in 7:
		var a := TAU * i / 7.0 + 0.4
		var p := Vector3(30.0 + sin(a) * 6.5, 0, -22.0 + cos(a) * 6.5)
		p.y = w.height(cx + p.x, cz + p.z) + 1.2
		var pm := PrismMesh.new()
		pm.size = Vector3(0.8, 2.6 + (i % 3), 0.8)
		pm.material = crys
		_mesh(root, pm, p, Basis(Vector3.UP, a) * Basis(Vector3.FORWARD, 0.2), false, 200.0)
	var lights: Array = []
	for i in 10:
		var a := TAU * i / 10.0 + 0.3
		lights.append(w.at(cx + sin(a) * 72.0, cz + cos(a) * 72.0, a))
	w.place(root, "n_tree_light_1", lights, 9.0, true, 600.0)
	_motes(root, Vector3(0, g + 30.0, 0), Vector3(36, 30, 36), Color(0.75, 1.0, 0.7), 140)
	_light(root, Vector3(0, g + 60.0, 0), Color(0.6, 1.0, 0.75), 3.0, 60.0)
	var plate := Label3D.new()
	plate.text = "Sylvar · Árvore-Mãe"
	plate.font = load("res://assets/cinzel.ttf")
	plate.font_size = 96
	plate.pixel_size = 0.02
	plate.outline_size = 18
	plate.modulate = Color(0.8, 1.0, 0.8)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.position = Vector3(0, g + H + 40.0, 0)
	plate.visibility_range_begin = 80.0
	plate.visibility_range_end = 900.0
	root.add_child(plate)
	return {"forja": Vector2(-50, -22), "pousada": Vector2(24, 52), "estabulo": Vector2(56, 20)}


# ---------- Umbraval: cidade dentro da montanha oca ----------
static func caverna(w: Node3D, t: Dictionary, root: Node3D) -> void:
	var cx: float = t.x
	var cz: float = t.z
	var g: float = w.height(cx, cz)
	var rock := StandardMaterial3D.new()
	rock.albedo_texture = load("res://assets/world/t_rock.webp")
	rock.albedo_color = Color(0.7, 0.62, 0.78)
	rock.uv1_triplanar = true
	rock.uv1_world_triplanar = true
	rock.uv1_scale = Vector3(0.03, 0.03, 0.03)
	rock.roughness = 1.0
	rock.cull_mode = BaseMaterial3D.CULL_DISABLED
	rock.emission_enabled = true
	rock.emission = Color(0.3, 0.24, 0.4)
	rock.emission_energy_multiplier = 0.35
	var dome := SphereMesh.new()
	dome.radius = 130.0
	dome.height = 130.0
	dome.is_hemisphere = true
	dome.radial_segments = 48
	dome.rings = 16
	dome.material = rock
	_mesh(root, dome, Vector3(0, g + 18.0, 0), Basis.from_scale(Vector3(1.0, 0.36, 1.0)), true, 2000.0)
	_mesh(root, dome, Vector3(0, g + 17.9, 0), Basis.from_scale(Vector3(-0.998, 0.359, 0.998)), false, 2000.0)  # espelhado: o teto visto por dentro
	var crys := _mat(Color(0.62, 0.4, 1.0), 0.2, 3.0)
	var crys2 := _mat(Color(0.3, 0.9, 1.0), 0.2, 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	# estalactites no teto e cristais no chão, junto da parede
	for i in 90:
		var a := rng.randf() * TAU
		var rr := rng.randf_range(20.0, 118.0)
		var top := g + 18.0 + 0.36 * sqrt(maxf(0.0, 130.0 * 130.0 - rr * rr))
		var len := rng.randf_range(4.0, 14.0)
		var c := _cyl(0.0, rng.randf_range(1.2, 3.4), len, rock, 6)
		_mesh(root, c, Vector3(sin(a) * rr, top - len * 0.5 + 0.5, cos(a) * rr), Basis.IDENTITY, false, 600.0)
		if i % 2 == 0:
			_mesh(root, _sphere(0.9, crys if i % 4 else crys2, 6), Vector3(sin(a) * rr, top - len - 0.5, cos(a) * rr), Basis.IDENTITY, false, 400.0)
	for i in 22:
		var a := TAU * i / 22.0 + rng.randf() * 0.2
		if w._near_gate(t, a, 0.2):
			continue
		var rr := rng.randf_range(100.0, 112.0)
		var p := Vector3(sin(a) * rr, 0, cos(a) * rr)
		p.y = w.height(cx + p.x, cz + p.z)
		for k in 3:
			var pm := PrismMesh.new()
			pm.size = Vector3(1.4, rng.randf_range(3.0, 7.0), 1.4)
			pm.material = crys if (i + k) % 2 else crys2
			_mesh(root, pm, p + Vector3(rng.randf_range(-2, 2), pm.size.y * 0.45, rng.randf_range(-2, 2)), Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, rng.randf_range(-0.3, 0.3)), false, 400.0)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		_light(root, Vector3(sin(a) * 60.0, g + 26.0, cos(a) * 60.0), Color(0.6, 0.45, 1.0) if k % 2 else Color(0.35, 0.8, 1.0), 3.0, 80.0)
	_motes(root, Vector3(0, g + 14.0, 0), Vector3(90, 12, 90), Color(0.7, 0.55, 1.0), 120)
	w.zones.append({"kind": "caverna", "c": Vector2(cx, cz), "r": 124.0, "y": g})
	var plate := Label3D.new()
	plate.text = "Umbraval · Cidade Subterrânea"
	plate.font = load("res://assets/cinzel.ttf")
	plate.font_size = 80
	plate.pixel_size = 0.02
	plate.outline_size = 16
	plate.modulate = Color(0.85, 0.75, 1.0)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.position = Vector3(0, g + 72.0, 0)
	plate.visibility_range_begin = 150.0
	plate.visibility_range_end = 1000.0
	root.add_child(plate)


# ---------- Abissália: cidade no fundo da Baía das Marés, dentro de uma bolha de ar ----------
static func abissal(w: Node3D, t: Dictionary, root: Node3D, urb: RefCounted) -> Dictionary:
	var cx: float = t.x
	var cz: float = t.z
	var g: float = w.height(cx, cz)
	var R := 84.0
	var bubble := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled, depth_draw_never, unshaded;
void fragment() {
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	ALBEDO = mix(vec3(0.1, 0.45, 0.7), vec3(0.6, 0.95, 1.0), f);
	ALPHA = 0.12 + f * 0.55;
}"""
	bubble.shader = sh
	var dome := SphereMesh.new()
	dome.radius = R
	dome.height = R
	dome.is_hemisphere = true
	dome.radial_segments = 48
	dome.rings = 16
	dome.material = bubble
	_mesh(root, dome, Vector3(0, g - 0.5, 0), Basis.from_scale(Vector3(1.0, 0.36, 1.0)), false, 2000.0)
	_mesh(root, dome, Vector3(0, g - 0.55, 0), Basis.from_scale(Vector3(-0.998, 0.359, 0.998)), false, 2000.0)
	# casas de concha e pedra, corais e algas
	urb.begin(root, cx, cz)
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for i in 14:
		var a := TAU * i / 14.0 + 0.1
		var rr := 34.0 + (i % 2) * 18.0
		urb.townhouse(sin(a) * rr, cos(a) * rr, a + PI, r.randf_range(8.0, 11.0), 9.0, r.randi_range(1, 2), ["cimento2", "marmore"][i % 2], "telha_azul")
	urb.hall(0.0, -24.0, 0.0, 18.0, 12.0, 8.0, "marmore", "telha_azul", "Templo das Marés", "igreja")
	urb.fountain(0.0, 10.0, 4.0, true)
	urb.pave_discs.append([0.0, 0.0, 24.0])
	urb.finish()
	var corals := [_mat(Color(1.0, 0.4, 0.55), 0.6, 0.8), _mat(Color(1.0, 0.7, 0.3), 0.6, 0.6), _mat(Color(0.4, 0.9, 1.0), 0.4, 1.2), _mat(Color(0.7, 0.45, 1.0), 0.5, 1.0)]
	var kelp := _mat(Color(0.18, 0.45, 0.22), 1.0)
	for i in 70:
		var a := r.randf() * TAU
		var rr := r.randf_range(12.0, R - 4.0)
		if absf(rr - 34.0) < 7.0 or absf(rr - 52.0) < 7.0:
			continue
		var x := sin(a) * rr
		var z := cos(a) * rr
		var y: float = w.height(cx + x, cz + z)
		if i % 3 == 0:
			var h := r.randf_range(3.0, 8.0)
			_mesh(root, _cyl(0.12, 0.05, h, kelp, 4), Vector3(x, y + h * 0.5, z), Basis(Vector3.FORWARD, r.randf_range(-0.15, 0.15)), false, 200.0)
		else:
			for k in 3:
				var h := r.randf_range(0.6, 1.8)
				_mesh(root, _cyl(0.18, 0.32, h, corals[(i + k) % 4], 6), Vector3(x + r.randf_range(-0.8, 0.8), y + h * 0.5, z + r.randf_range(-0.8, 0.8)), Basis(Vector3.RIGHT, r.randf_range(-0.4, 0.4)), false, 200.0)
			_mesh(root, _sphere(r.randf_range(0.4, 0.9), corals[i % 4], 6), Vector3(x, y + 0.3, z), Basis.IDENTITY, false, 160.0)
	for k in 5:
		var a := TAU * k / 5.0
		_light(root, Vector3(sin(a) * 40.0, g + 10.0, cos(a) * 40.0), Color(0.35, 0.85, 1.0), 2.0, 45.0)
	_motes(root, Vector3(0, g + 12.0, 0), Vector3(70, 14, 70), Color(0.7, 0.95, 1.0), 120)
	w.zones.append({"kind": "submarina", "c": Vector2(cx, cz), "r": R - 2.0, "y": g})
	var porto: Dictionary = w.town_by_id("porto")
	portal(w, root, Vector3(cx, g, cz + 22.0), Vector3(float(porto.x), 0.0, float(porto.z) + 120.0), "Subir ao Porto Maré-Alta")
	var plate := Label3D.new()
	plate.text = "Abissália"
	plate.font = load("res://assets/cinzel.ttf")
	plate.font_size = 96
	plate.pixel_size = 0.02
	plate.outline_size = 18
	plate.modulate = Color(0.7, 0.95, 1.0)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.position = Vector3(0, g + 36.0, 0)
	plate.visibility_range_end = 400.0
	root.add_child(plate)
	return {"forja": Vector2(-44, 18), "pousada": Vector2(40, -20), "estabulo": Vector2(10, -48)}


# ---------- Ilha de Coralis ----------
static func ilha(w: Node3D, t: Dictionary, root: Node3D, urb: RefCounted) -> Dictionary:
	var cx: float = t.x
	var cz: float = t.z
	urb.begin(root, cx, cz)
	var r := RandomNumberGenerator.new()
	r.seed = 31
	for i in 10:
		var a := TAU * i / 10.0 + 0.3
		var rr := 26.0 + (i % 2) * 12.0
		urb.townhouse(sin(a) * rr, cos(a) * rr, a + PI, r.randf_range(7.0, 9.0), 7.5, r.randi_range(1, 2), ["cimento", "cimento3", "marmore"][i % 3], ["telha", "telha_azul"][i % 2])
	urb.fountain(0.0, 0.0, 3.4, false)
	urb.pave_discs.append([0.0, 0.0, 14.0])
	urb.harbor(0.0, -58.0, PI, 30.0)
	urb.lighthouse(40.0, 30.0)
	urb.finish()
	var trees: Array = []
	for i in 14:
		var a := TAU * i / 14.0
		trees.append(w.at(cx + sin(a) * 50.0, cz + cos(a) * 50.0, a))
	w.place(root, "n_tree_spiral_1", trees, 8.0, true, 600.0)
	w.place(root, "n_plant_1_big", trees.map(func(x): return (x as Transform3D).translated(Vector3(2.5, 0, 1.5))), 1.2, false, 200.0)
	var abis: Dictionary = w.town_by_id("abissal")
	portal(w, root, Vector3(cx + 12.0, w.height(cx + 12.0, cz + 8.0), cz + 8.0), Vector3(float(abis.x), 0.0, float(abis.z) + 28.0), "Redemoinho para Abissália")
	var plate := Label3D.new()
	plate.text = t.name
	plate.font = load("res://assets/cinzel.ttf")
	plate.font_size = 96
	plate.pixel_size = 0.02
	plate.outline_size = 18
	plate.modulate = Color(1.0, 0.92, 0.7)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.position = Vector3(0, w.height(cx, cz) + 22.0, 0)
	plate.visibility_range_begin = 60.0
	plate.visibility_range_end = 900.0
	root.add_child(plate)
	return {"forja": Vector2(-30, 10), "pousada": Vector2(18, -30), "estabulo": Vector2(30, 14)}


# ---------- enfeites das cidades médias: praça calçada, ruas de pedra até os portões, canteiros ----------
static func enfeites(w: Node3D, t: Dictionary, root: Node3D, urb: RefCounted) -> void:
	urb.begin(root, float(t.x), float(t.z))
	urb.pave_discs.append([0.0, 0.0, 17.0])
	var R: float = w.wall_r(t)
	for g in t.get("gates", []):
		var a := float(g)
		var d0 := 15.0
		var d1 := R + 8.0
		var m := (d0 + d1) * 0.5
		urb.pave_rects.append([sin(a) * m, cos(a) * m, 2.6, (d1 - d0) * 0.5, a])
	var bushes: Array = []
	for i in 10:
		var a := TAU * i / 10.0 + 0.15
		if w._near_gate(t, a, 0.25):
			continue
		var x := sin(a) * 18.5
		var z := cos(a) * 18.5
		bushes.append(w.at(float(t.x) + x, float(t.z) + z, a))
	w.place(root, "n_bush_common_flowers", bushes, 1.1, true, 180.0)
	urb.finish()
