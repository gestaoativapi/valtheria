extends Node3D
# Céu vivo: ciclo de dia e noite, chuva, neve e partículas do ambiente (folhas, cinzas, vaga-lumes) conforme a região.

const FX = preload("res://scripts/fx.gd")
const DAY_LEN := 1200.0  # um dia completo dura 20 minutos

var main: Node3D
var world: Node3D
var t_day := 0.36
var weather := "limpo"
var weather_t := 90.0
var wet := 0.0
var rain: CPUParticles3D
var snow: CPUParticles3D
var drift: CPUParticles3D
var flies: CPUParticles3D
var band := 0
var rng := RandomNumberGenerator.new()


var lamp_t := 0.0
var amb_src := -1


func setup(m: Node3D) -> void:
	main = m
	world = m.world
	rng.randomize()
	rain = CPUParticles3D.new()
	rain.amount = 420
	rain.lifetime = 0.7
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.7)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.8, 0.88, 1.0, 0.35)
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = rm
	rain.mesh = q
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(16, 0.5, 16)
	rain.direction = Vector3(0.08, -1, 0)
	rain.spread = 2.0
	rain.initial_velocity_min = 22.0
	rain.initial_velocity_max = 26.0
	rain.gravity = Vector3.ZERO
	rain.local_coords = false
	rain.emitting = false
	add_child(rain)
	snow = FX.emitter(260, 6.0, false, 0.09, Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9))
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(18, 0.5, 18)
	snow.direction = Vector3(0.2, -1, 0.1)
	snow.spread = 12.0
	snow.initial_velocity_min = 1.6
	snow.initial_velocity_max = 2.6
	snow.local_coords = false
	snow.emitting = false
	add_child(snow)
	drift = FX.emitter(22, 7.0, false, 0.14, Color(0.5, 0.7, 0.25, 0.0), Color(0.55, 0.7, 0.25, 0.9))
	drift.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drift.emission_box_extents = Vector3(16, 3, 16)
	drift.direction = Vector3(1, -0.25, 0.3)
	drift.spread = 25.0
	drift.initial_velocity_min = 0.8
	drift.initial_velocity_max = 2.2
	drift.local_coords = false
	add_child(drift)
	flies = FX.emitter(26, 5.0, true, 0.1, Color(0.9, 1.0, 0.4, 0.0), Color(0.8, 1.0, 0.3, 1.0))
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies.emission_box_extents = Vector3(14, 1.2, 14)
	flies.spread = 180.0
	flies.initial_velocity_min = 0.1
	flies.initial_velocity_max = 0.5
	flies.local_coords = false
	flies.emitting = false
	add_child(flies)


func hour_text() -> String:
	var h := int(t_day * 24.0)
	return "%02d:%02d" % [h, int(fmod(t_day * 24.0, 1.0) * 60.0)]


func _process(dt: float) -> void:
	if world == null or world.env == null:
		return
	t_day = fmod(t_day + dt / DAY_LEN, 1.0)
	var alt := sin((t_day - 0.25) * TAU)
	var day := smoothstep(-0.12, 0.2, alt)
	var dusk := (1.0 - smoothstep(0.0, 0.45, absf(alt))) * day
	# clima: de tempos em tempos chove (ou neva forte nas terras geladas)
	weather_t -= dt
	if weather_t <= 0.0:
		weather = "chuva" if rng.randf() < 0.3 and weather == "limpo" else "limpo"
		weather_t = rng.randf_range(90.0, 160.0) if weather == "chuva" else rng.randf_range(240.0, 480.0)
	wet = move_toward(wet, 1.0 if weather == "chuva" else 0.0, dt * 0.12)
	var p: Vector3 = main.player.position
	band = clampi(roundi((255.0 - world.ground(p.x, p.z).a8) / 40.0), 0, 5)
	var cold := band == 5
	var sun: DirectionalLight3D = world.sun
	# de dia a luz é o sol; à noite a mesma luz vira a lua, que cruza o céu do outro lado
	if day > 0.02:
		sun.rotation_degrees = Vector3(-lerpf(14.0, 58.0, clampf(alt, 0.0, 1.0)), -128.0 + (t_day - 0.5) * 140.0, 0.0)
	else:
		var nt := fmod(t_day + 0.5, 1.0)
		sun.rotation_degrees = Vector3(-lerpf(18.0, 55.0, clampf(-alt, 0.0, 1.0)), -128.0 + (nt - 0.5) * 140.0, 0.0)
	var sun_col := Color(1.0, 0.95, 0.86).lerp(Color(1.0, 0.62, 0.36), dusk)
	sun.light_color = Color(0.55, 0.66, 1.0).lerp(sun_col, day)
	sun.light_energy = lerpf(0.42, 1.45, day) * (1.0 - 0.45 * wet)
	var night := 1.0 - day
	var gray := Color(0.42, 0.46, 0.52)
	var top := Color(0.015, 0.025, 0.07).lerp(Color(0.18, 0.36, 0.68), day).lerp(gray * (0.3 + 0.7 * day), wet * 0.85)
	var hor := Color(0.05, 0.07, 0.13).lerp(Color(0.72, 0.8, 0.88).lerp(Color(0.98, 0.6, 0.34), dusk), day).lerp(gray * (0.35 + 0.75 * day), wet * 0.85)
	var sky: ShaderMaterial = world.sky_shader
	sky.set_shader_parameter("top_color", top)
	sky.set_shader_parameter("horizon_color", hor)
	sky.set_shader_parameter("ground_color", hor * 0.3)
	sky.set_shader_parameter("night", night)
	sky.set_shader_parameter("cloud_cover", clampf(wet * 1.2, 0.0, 1.0))
	sky.set_shader_parameter("sun_color", sun_col)
	lamp_t -= dt
	if lamp_t <= 0.0:
		lamp_t = 0.5
		world.light_lamps(p, smoothstep(0.35, 0.85, night))
	world.env.ambient_light_energy = lerpf(0.45, 0.9, day)
	world.env.fog_light_color = hor * 0.9
	world.env.fog_density = world.base_fog * (1.0 + wet * 2.2 + (0.8 if cold else 0.0))
	var cam: Vector3 = main.cam.global_position
	rain.global_position = cam + Vector3(0, 9, 0)
	snow.global_position = cam + Vector3(0, 8, 0)
	drift.global_position = Vector3(p.x, p.y + 3.0, p.z)
	flies.global_position = Vector3(p.x, p.y + 1.4, p.z)
	rain.emitting = wet > 0.15 and not cold
	rain.amount = maxi(40, int(420 * FX.amount))
	snow.emitting = cold
	drift.emitting = not cold and band != 4 or band == 4
	flies.emitting = day < 0.25 and band in [0, 1, 3] and wet < 0.2
	# o que o vento carrega muda com a região: folhas, cinzas e brasas nas terras rubras
	var g := drift.color_ramp
	var leaf := Color(0.55, 0.7, 0.25, 0.9) if band in [0, 3] else (Color(0.85, 0.7, 0.25, 0.9) if band == 1 else (Color(0.6, 0.62, 0.55, 0.7) if band == 2 else Color(1.0, 0.45, 0.12, 0.9)))
	g.set_color(1, leaf)
	g.set_color(2, Color(leaf.r, leaf.g, leaf.b, 0.0))
	# janelas acesas à noite
	if world.window_mat:
		world.window_mat.emission_energy_multiplier = smoothstep(0.3, 0.8, night) * 1.8
	# luz própria: dentro de prédios, na caverna de Umbraval e no fundo do mar
	var indoor: bool = main.interiores != null and not main.interiores.inside.is_empty()
	var zn: Dictionary = world.zone_at(p.x, p.z)
	var kind := "interior" if indoor else str(zn.get("kind", ""))
	if amb_src < 0:
		amb_src = world.env.ambient_light_source
	world.env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if kind == "interior" else amb_src
	match kind:
		"interior":
			world.env.ambient_light_color = Color(0.95, 0.82, 0.66)
			sun.light_energy *= 0.06
			world.env.ambient_light_energy = 1.0
			world.env.fog_density = 0.0
		"caverna":
			sun.light_energy *= 0.12
			sun.light_color = Color(0.7, 0.6, 1.0)
			world.env.ambient_light_energy = 0.75
			world.env.fog_light_color = Color(0.2, 0.15, 0.3)
			world.env.fog_density = 0.0018
		"submarina":
			sun.light_energy *= 0.4
			sun.light_color = Color(0.5, 0.85, 1.0)
			world.env.ambient_light_energy = 0.75
			world.env.fog_light_color = Color(0.04, 0.26, 0.4)
			world.env.fog_density = 0.016
	if kind != "":
		rain.emitting = false
		snow.emitting = false
		flies.emitting = false
