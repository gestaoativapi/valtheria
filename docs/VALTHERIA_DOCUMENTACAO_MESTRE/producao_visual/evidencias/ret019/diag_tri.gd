extends Node3D
const CS := preload("res://scripts/character.gd")
var sol: DirectionalLight3D
var out := []
func montar(dir: String, corpo: String, pecas: Array) -> Node3D:
	var body: Node3D = (load(dir + corpo + ".glb") as PackedScene).instantiate(); add_child(body)
	var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D
	for p in pecas:
		var src: Node3D = (load(dir + p + ".glb") as PackedScene).instantiate()
		for m in src.find_children("*", "MeshInstance3D", true, false):
			m.get_parent().remove_child(m); m.owner = null; skel.add_child(m); (m as MeshInstance3D).skeleton = NodePath("..")
		src.free()
	var a := AnimationPlayer.new(); body.add_child(a); a.add_animation_library("", CS._clips(skel, "")); a.play("Idle")
	return body
func info(t: int, k: int) -> int:
	return RenderingServer.viewport_get_render_info(get_viewport().get_viewport_rid(), t, k)
func _ready() -> void:
	get_viewport().size = Vector2i(1600, 900)
	sol = DirectionalLight3D.new(); sol.rotation_degrees = Vector3(-42, -35, 0); add_child(sol)
	var cam := Camera3D.new(); add_child(cam); cam.current = true
	var tipos := {"atual_m": ["res://assets/chars/", "body_male_peasant", ["outfit_male_peasant", "hair_simpleparted", "hair_eyebrows_regular"]],
		"v3_m": ["res://assets_v3/personagens/", "pc_humano_m", ["rp_aldeao_tunica_m", "rp_aldeao_calca_m", "rp_botas_couro_m", "ca_curto_01"]],
		"v3_f": ["res://assets_v3/personagens/", "pc_humano_f", ["rp_aldeao_tunica_f", "rp_aldeao_calca_f", "rp_botas_couro_f", "ca_tranca_longa"]]}
	for nome in tipos:
		var t: Array = tipos[nome]; var b := montar(t[0], t[1], t[2])
		# triângulos de arquivo (soma das superfícies, LOD 0)
		var arq := 0
		for m in b.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (m as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s); var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				arq += (idx.size() / 3) if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX].size() / 3)
		for dist in [2.5, 6.0, 15.0, 30.0]:
			for lod in [1.0, 0.0]:
				for sombra in [true, false]:
					get_viewport().mesh_lod_threshold = lod; sol.shadow_enabled = sombra
					cam.position = Vector3(0, 1.2, dist); cam.look_at(Vector3(0, 0.9, 0))
					for i in 4: await RenderingServer.frame_post_draw
					out.append({"tipo": nome, "arquivo": arq, "dist_m": dist, "lod_auto": lod > 0.0, "sombra": sombra,
						"visivel_tri": info(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
						"sombra_tri": info(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
						"visivel_dc": info(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
						"sombra_dc": info(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)})
		b.free(); await get_tree().process_frame
	var f := FileAccess.open("/tmp/diag_tri.json", FileAccess.WRITE); f.store_string(JSON.stringify(out)); f.close()
	get_tree().quit()
