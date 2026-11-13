extends Node3D
# Efeitos dos elementos (fogo, gelo, água, terra, vento, raio, luz, sombra...), feitos com partículas leves
# que funcionam em qualquer modo gráfico. `amount` (0 a 1) reduz a quantidade nas qualidades baixas.

const ELEM := {
	"fire": [Color(1.0, 0.85, 0.3), Color(1.0, 0.35, 0.05)], "fogo": [Color(1.0, 0.85, 0.3), Color(1.0, 0.35, 0.05)],
	"ice": [Color(0.85, 0.97, 1.0), Color(0.35, 0.7, 1.0)], "gelo": [Color(0.85, 0.97, 1.0), Color(0.35, 0.7, 1.0)],
	"agua": [Color(0.7, 0.9, 1.0), Color(0.15, 0.45, 0.9)],
	"earth": [Color(0.8, 0.65, 0.4), Color(0.45, 0.32, 0.18)], "terra": [Color(0.8, 0.65, 0.4), Color(0.45, 0.32, 0.18)],
	"wind": [Color(0.9, 1.0, 0.95), Color(0.55, 0.9, 0.75)], "vento": [Color(0.9, 1.0, 0.95), Color(0.55, 0.9, 0.75)],
	"raio": [Color(1.0, 1.0, 0.8), Color(0.6, 0.6, 1.0)],
	"holy": [Color(1.0, 0.98, 0.8), Color(1.0, 0.8, 0.3)], "luz": [Color(1.0, 0.98, 0.8), Color(1.0, 0.8, 0.3)],
	"dark": [Color(0.75, 0.45, 1.0), Color(0.25, 0.05, 0.4)], "sombra": [Color(0.75, 0.45, 1.0), Color(0.25, 0.05, 0.4)],
	"nature": [Color(0.75, 1.0, 0.5), Color(0.2, 0.6, 0.2)], "natureza": [Color(0.75, 1.0, 0.5), Color(0.2, 0.6, 0.2)],
	"poison": [Color(0.75, 1.0, 0.3), Color(0.35, 0.55, 0.05)],
	"arcane": [Color(0.9, 0.7, 1.0), Color(0.5, 0.25, 1.0)], "spirit": [Color(0.7, 1.0, 0.95), Color(0.2, 0.7, 0.75)],
	"blood": [Color(1.0, 0.4, 0.35), Color(0.55, 0.02, 0.05)], "": [Color(1.0, 0.95, 0.85), Color(0.8, 0.75, 0.6)],
}
static var amount := 1.0
static var _mats := {}


static func colors(elem: String) -> Array:
	return ELEM.get(elem, ELEM[""])


# material de partícula: disco macio, sempre de frente para a câmera; add = brilho somado (fogo, magia)
static func _mat(add: bool) -> StandardMaterial3D:
	if _mats.has(add):
		return _mats[add]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	_mats[add] = m
	return m


static func emitter(count: int, life: float, add: bool, size: float, c0: Color, c1: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(2, int(count * maxf(amount, 0.25)))
	p.lifetime = life
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _mat(add)
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, Color(c1.r, c1.g, c1.b, 0.0))
	g.add_point(0.5, c1)
	p.color_ramp = g
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = c
	p.gravity = Vector3.ZERO
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# fogueira ou tocha: chamas, brasas e fumaça
static func fire(size := 1.0, smoke := true) -> Node3D:
	var root := Node3D.new()
	var f := emitter(26, 0.75, true, 0.75 * size, Color(1.0, 0.92, 0.45, 0.9), Color(1.0, 0.3, 0.04, 0.8))
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	f.emission_sphere_radius = 0.22 * size
	f.direction = Vector3.UP
	f.spread = 12.0
	f.initial_velocity_min = 1.1 * size
	f.initial_velocity_max = 2.0 * size
	f.scale_amount_min = 0.6
	f.scale_amount_max = 1.2
	root.add_child(f)
	var e := emitter(10, 1.6, true, 0.07 * size, Color(1.0, 0.8, 0.3), Color(1.0, 0.3, 0.05))
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.emission_sphere_radius = 0.25 * size
	e.direction = Vector3.UP
	e.spread = 30.0
	e.initial_velocity_min = 1.0
	e.initial_velocity_max = 2.6
	e.gravity = Vector3(0.3, 0.6, 0.0)
	root.add_child(e)
	if smoke:
		var s := emitter(12, 3.2, false, 1.1 * size, Color(0.2, 0.19, 0.18, 0.0), Color(0.3, 0.29, 0.28, 0.32))
		s.position = Vector3(0, 0.9 * size, 0)
		s.direction = Vector3.UP
		s.spread = 14.0
		s.initial_velocity_min = 0.7
		s.initial_velocity_max = 1.2
		s.gravity = Vector3(0.35, 0.25, 0.1)
		s.scale_amount_min = 0.8
		s.scale_amount_max = 1.8
		root.add_child(s)
	return root


# explosão curta do elemento num ponto (golpe, magia acertando, cura)
static func burst(parent: Node, pos: Vector3, elem: String, size := 1.0) -> void:
	var c := colors(elem)
	var p := emitter(int(22 * size), 0.55, true, 0.4 * size, c[0], c[1])
	p.one_shot = true
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.5 * size
	p.initial_velocity_max = 4.5 * size
	p.damping_min = 4.0
	p.damping_max = 6.0
	if elem in ["earth", "terra", "blood", "poison"]:
		p.gravity = Vector3(0, -9.0, 0)
	elif elem in ["fire", "fogo", "holy", "luz", "spirit"]:
		p.gravity = Vector3(0, 2.5, 0)
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	# anel que se abre no chão
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 24
	tm.ring_segments = 4
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_color = Color(c[1].r, c[1].g, c[1].b, 0.9)
	tm.material = rm
	ring.mesh = tm
	ring.position = pos
	ring.scale = Vector3(0.4, 0.3, 0.4)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	var tw := parent.create_tween()
	tw.tween_property(ring, "scale", Vector3(3.2 * size, 0.3, 3.2 * size), 0.4)
	tw.parallel().tween_property(rm, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(ring.queue_free)
	tw.tween_interval(0.5)
	tw.tween_callback(p.queue_free)


# projétil do elemento voando até o alvo; chama `done` ao chegar
static func bolt(parent: Node, from: Vector3, to: Vector3, elem: String, time := 0.28) -> void:
	var c := colors(elem)
	var root := Node3D.new()
	root.position = from
	parent.add_child(root)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 8
	sm.rings = 4
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = c[0]
	sm.material = mm
	core.mesh = sm
	root.add_child(core)
	var trail := emitter(18, 0.35, true, 0.38, c[0], c[1])
	trail.local_coords = false
	trail.spread = 180.0
	trail.initial_velocity_max = 0.6
	root.add_child(trail)
	var tw := parent.create_tween()
	tw.tween_property(root, "position", to, time)
	tw.tween_callback(func():
		trail.emitting = false
		core.visible = false
		burst(parent, to, elem, 0.9))
	tw.tween_interval(0.5)
	tw.tween_callback(root.queue_free)


# aura em volta do personagem (proteção, bônus)
static func aura(target: Node3D, elem: String, seconds: float) -> void:
	var c := colors(elem)
	var p := emitter(16, 1.0, true, 0.22, c[0], c[1])
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.7
	p.emission_ring_inner_radius = 0.6
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 5.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 1.8
	p.position = Vector3(0, 0.1, 0)
	target.add_child(p)
	var tw := target.create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(func(): p.emitting = false)
	tw.tween_interval(1.2)
	tw.tween_callback(p.queue_free)


# poeira nos pés ao correr
static func dust() -> CPUParticles3D:
	var p := emitter(8, 0.7, false, 0.5, Color(0.7, 0.62, 0.5, 0.0), Color(0.7, 0.62, 0.5, 0.3))
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.local_coords = false
	p.emitting = false
	p.position = Vector3(0, 0.1, 0)
	return p
