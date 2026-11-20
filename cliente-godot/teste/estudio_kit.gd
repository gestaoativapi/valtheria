extends SceneTree
# Estúdio: monta uma casa do kit e fotografa. uso: godot -s teste/estudio_kit.gd -- --out=x.png [--ang=0.6] [--dist=18]
const CasaKit = preload("res://scripts/casa_kit.gd")
var frame := 0
var out := "/tmp/kit.png"

func _init() -> void:
	var ang := 0.7
	var dist := 20.0
	var pecas := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
		if a.begins_with("--ang="): ang = float(a.substr(6))
		if a.begins_with("--dist="): dist = float(a.substr(7))
		if a.begins_with("--pecas="): pecas = a.substr(8)
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.7, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.3
	root.add_child(sun)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	chao.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.35, 0.42, 0.25)
	chao.material_override = cm
	root.add_child(chao)
	if pecas != "":
		var i := 0
		for p in pecas.split(","):
			for ms in CasaKit.malhas(p):
				var mi := MeshInstance3D.new()
				mi.mesh = ms[0]
				mi.transform = Transform3D(Basis.IDENTITY, Vector3(i * 4.0 - 6.0, 0, 0)) * ms[1]
				root.add_child(mi)
			i += 1
	else:
		CasaKit.construir(root, [Transform3D(Basis.IDENTITY, Vector3(-5, 0, 0)), Transform3D(Basis(Vector3.UP, 0.4), Vector3(7, 0, -3))], 3, 4, 2)
	var cam := Camera3D.new()
	root.add_child(cam)
	var pos := Vector3(sin(ang) * dist, dist * 0.45, cos(ang) * dist)
	cam.transform = Transform3D(Basis.IDENTITY, pos).looking_at(Vector3(0, 3.5, 0))
	cam.fov = 50.0

func _process(_d: float) -> bool:
	frame += 1
	if frame == 12:
		get_root().get_texture().get_image().save_png(out)
		return true
	return false
