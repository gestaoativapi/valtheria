extends SceneTree
# Estúdio da fogueira e da tocha à noite: fotografa o fogo de FX.fire depois de N quadros.
# uso: godot --path . --fixed-fps 30 -s teste/estudio_fogo.gd -- --quadro=60 --saida=/tmp/fogo.png
var quadros := 0
var quadro := 60
var saida := "/tmp/fogo.png"


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quadro="): quadro = int(a.trim_prefix("--quadro="))
		elif a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
	var FX = load("res://scripts/fx.gd")
	var r := Node3D.new()
	root.add_child(r)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.34, 0.5)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	r.add_child(we)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.2, 0.2, 0.18)
	pm.material = cm
	chao.mesh = pm
	r.add_child(chao)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 2.0
	l.omni_range = 6.0
	l.position = Vector3(0, 1.0, 0)
	r.add_child(l)
	var f: Node3D = FX.fire(1.25)
	f.position = Vector3(0, 0.3, 0)
	r.add_child(f)
	var t: Node3D = FX.fire(0.5, false)
	t.position = Vector3(2.2, 2.0, 0)
	r.add_child(t)
	var poste := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.05
	cy.bottom_radius = 0.06
	cy.height = 2.0
	poste.mesh = cy
	poste.position = Vector3(2.2, 1.0, 0)
	r.add_child(poste)
	var cam := Camera3D.new()
	cam.fov = 45
	r.add_child(cam)
	cam.position = Vector3(1.0, 1.6, 5.5)
	cam.look_at(Vector3(1.0, 1.1, 0))


func _process(_dt: float) -> bool:
	quadros += 1
	if quadros == quadro:
		root.get_viewport().get_texture().get_image().save_png(saida)
		return true
	return false
