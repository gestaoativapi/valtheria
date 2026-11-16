extends Node3D
# Valtheria V3 — AUT-023 (D64/D65): rosto A aplicado ao P1/P2, visto no próprio Godot (antes × depois).
# Uso: godot --path . --rendering-driver opengl3 res://testes/prototipos/rosto_jogo.tscn -- --saida=<pasta>
const V3 := "res://assets_v3/personagens/"
var saida := "user://rosto"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): saida = a.substr(8)
	DirAccess.make_dir_recursive_absolute(saida)
	var sol := DirectionalLight3D.new(); sol.rotation_degrees = Vector3(-35, -30, 0); sol.shadow_enabled = true; add_child(sol)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.46, 0.5, 0.55); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65); add_child(env)
	for g in ["m", "f"]:
		for v in ["", "_rostoA"]:
			var body: Node3D = (load(V3 + "pc_humano_%s%s.glb" % [g, v]) as PackedScene).instantiate(); add_child(body)
			var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D
			for p in ["rp_aldeao_tunica_" + g, "ca_curto_01" if g == "m" else "ca_tranca_longa"]:
				var src: Node3D = (load(V3 + p + ".glb") as PackedScene).instantiate()
				for mm in src.find_children("*", "MeshInstance3D", true, false):
					mm.get_parent().remove_child(mm); mm.owner = null; skel.add_child(mm); (mm as MeshInstance3D).skeleton = NodePath("..")
				src.free()
			var cabeca := skel.get_bone_global_rest(skel.find_bone("Head")).origin + Vector3(0, 0.08, 0)
			for vista in [["frente", 0.0], ["tres_quartos", 35.0]]:
				var cam := Camera3D.new(); add_child(cam); cam.fov = 22
				var ang := deg_to_rad(float(vista[1]))
				cam.look_at_from_position(cabeca + Vector3(sin(ang), 0.02, cos(ang)) * 1.1, cabeca); cam.current = true
				for i in 4: await get_tree().process_frame
				get_viewport().get_texture().get_image().save_png("%s/rosto_jogo_%s%s_%s.png" % [saida, g, ("_A" if v != "" else "_atual"), vista[0]])
				cam.queue_free()
			body.queue_free(); await get_tree().process_frame
	get_tree().quit()
