extends Node3D
const CS := preload("res://scripts/character.gd")
func montar(g: String) -> Dictionary:
	var dir := "res://assets_v3/personagens/"
	var body: Node3D = (load(dir + "pc_humano_" + g + ".glb") as PackedScene).instantiate(); add_child(body)
	var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D
	var tun: MeshInstance3D
	for p in ["rp_aldeao_tunica_" + g, "rp_aldeao_calca_" + g, "rp_botas_couro_" + g]:
		var src: Node3D = (load(dir + p + ".glb") as PackedScene).instantiate()
		for m in src.find_children("*", "MeshInstance3D", true, false):
			m.get_parent().remove_child(m); m.owner = null; skel.add_child(m); (m as MeshInstance3D).skeleton = NodePath("..")
			if "tunica" in p: tun = m
		src.free()
	var a := AnimationPlayer.new(); body.add_child(a); a.add_animation_library("", CS._clips(skel, ""))
	a.play("Idle"); a.seek(a.get_animation("Idle").length * 0.3, true); a.pause()
	return {"body": body, "tun": tun}
func _ready() -> void:
	get_viewport().size = Vector2i(900, 600)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.46, 0.5, 0.55)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.64, 0.7); e.ambient_light_energy = 0.55; env.environment = e; add_child(env)
	var sol := DirectionalLight3D.new(); sol.rotation_degrees = Vector3(-42, -35, 0); sol.light_energy = 1.25; add_child(sol)
	var cam := Camera3D.new(); add_child(cam); cam.current = true
	for g in ["m", "f"]:
		var c := montar(g); var zb := 0.80 if g == "m" else 0.69
		cam.position = Vector3(0, zb - 0.05, 1.1); cam.look_at(Vector3(0, zb + 0.02, 0))
		for modo in ["dupla", "simples", "marcado"]:
			var tun: MeshInstance3D = c.tun
			var mat := (tun.mesh.surface_get_material(0) as BaseMaterial3D).duplicate() as BaseMaterial3D
			if modo != "dupla": mat.cull_mode = BaseMaterial3D.CULL_BACK
			tun.material_override = mat
			if modo == "marcado":
				var m2 := mat.duplicate() as BaseMaterial3D; m2.cull_mode = BaseMaterial3D.CULL_FRONT; m2.albedo_texture = null; m2.albedo_color = Color(1, 0, 1)
				m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.next_pass = m2
			for i in 4: await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/barra_%s_%s.png" % [g, modo])
		c.body.free(); await get_tree().process_frame
	get_tree().quit()
