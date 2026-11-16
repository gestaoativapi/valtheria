extends "res://testes/prototipos/p1_humano.gd"
# Valtheria V3 — cena de teste da AUT-020 (correções do marco 1). Não faz parte do jogo.
# Compara a versão do marco 1 (commit 943995a, copiada para --antes=<res://pasta>) com a versão corrigida
# (res://assets_v3/), pelo mesmo método de montagem do character.gd.
# Uso: godot --path . res://testes/prototipos/marco1_correcoes.tscn -- --saida=<pasta> --antes=res://antes_v3/
#      [--modo=capturas|medidas]
var antes := ""
var caso := ""
var so := ""   # --so=barra,piores,anim,espada,medalhao,tranca (vazio = tudo)
func parte(n: String) -> bool:
	return so == "" or n in so.split(",")
const PIORES := [["Sitting_Idle", 0.5], ["Farm_Harvest", 0.5], ["OverhandThrow", 0.5], ["Sword_Regular_C", 0.5], ["Sword_Regular_B", 0.5], ["Sword_Attack", 0.5]]

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--antes="): antes = a.substr(8)
		if a.begins_with("--caso="): caso = a.substr(7)
		if a.begins_with("--so="): so = a.substr(5)
	super._ready()

func montar_de(raiz: String, corpo: String, pecas: Array) -> Dictionary:
	var dir := raiz + "personagens/"
	var body: Node3D = (load(dir + corpo + ".glb") as PackedScene).instantiate()
	add_child(body)
	var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D
	for p in pecas:
		if not ResourceLoader.exists(dir + p + ".glb"): continue
		var src: Node3D = (load(dir + p + ".glb") as PackedScene).instantiate()
		for m in src.find_children("*", "MeshInstance3D", true, false):
			m.get_parent().remove_child(m); m.owner = null; skel.add_child(m)
			(m as MeshInstance3D).skeleton = NodePath("..")
			m.name = p
		src.free()
	var anim := AnimationPlayer.new(); body.add_child(anim)
	anim.add_animation_library("", CharacterScript._clips(skel, ""))
	return {"body": body, "skel": skel, "anim": anim}

# bainha de cintura lida de espada_longa.json (AUT-020 4.2), mesma construção de _make_sheath do jogo
func bainha_cfg(skel: Skeleton3D, height_m: float, cfg_path: String) -> Node3D:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
	var b: Dictionary = cfg["bainha_cintura"]
	var bone := skel.find_bone(b["osso"]); var gb := skel.get_bone_global_rest(bone)
	var att := BoneAttachment3D.new(); att.bone_name = b["osso"]; skel.add_child(att)
	var k := height_m / 1.8
	var d: Array = b["direcao_lamina"]; var o: Array = b["deslocamento_cabo"]
	var blade := Vector3(d[0], d[1], d[2]).normalized(); var out := Vector3(1, 0, 0)
	var handle := gb.origin + Vector3(o[0], o[1], o[2]) * k
	var x := out.cross(blade).normalized(); var y := blade.cross(x).normalized()
	var s := Node3D.new(); s.transform = Transform3D(gb.basis.inverse() * Basis(x, y, blade), gb.affine_inverse() * handle)
	att.add_child(s); return s

func foto_persp(nome: String, alvo: Vector3, dist: float, ang_y: float, altura := 0.0, fov := 40.0) -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE; cam.fov = fov
	cam.position = alvo + Vector3(sin(deg_to_rad(ang_y)), 0, cos(deg_to_rad(ang_y))) * dist + Vector3(0, altura, 0)
	cam.look_at(alvo, Vector3.UP)
	await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(saida.path_join(nome + ".png"))

func _capturas() -> void:
	get_viewport().size = Vector2i(1000, 1000)
	var versoes := [["depois", V3]]
	if antes != "": versoes.push_front(["antes", antes])
	# 1) barra, busto e 6 piores quadros (saia x coxa), frente e lado
	for v in (versoes if parte("barra") or parte("piores") else []):
		for g in ["m", "f"]:
			var c := montar_de(v[1], "pc_humano_" + g, PECAS_M if g == "m" else PECAS_F)
			var zb := 0.80 if g == "m" else 0.70
			pose(c, "Idle", 0.3)
			await foto("%s_%s_barra_frente" % [v[0], g], Vector3(0, zb + 0.1, 0), 4.0, 0.0, 0.0, 0.75)
			await foto("%s_%s_barra_lado" % [v[0], g], Vector3(0, zb + 0.1, 0), 4.0, 90.0, 0.0, 0.75)
			await foto("%s_%s_barra_baixo" % [v[0], g], Vector3(0, zb + 0.05, 0), 4.0, 20.0, -1.2, 0.75)
			if g == "f":
				await foto("%s_f_busto_lado" % v[0], Vector3(0, 1.15, 0), 4.0, 90.0, 0.0, 0.6)
			for p in (PIORES if parte("piores") else []):
				pose(c, p[0], p[1])
				await foto("%s_%s_pior_%s_frente" % [v[0], g, p[0]], Vector3(0, 0.75, 0), 4.0, 0.0, 0.4, 1.9)
				await foto("%s_%s_pior_%s_lado" % [v[0], g, p[0]], Vector3(0, 0.75, 0), 4.0, 70.0, 0.4, 1.9)
			c.body.queue_free(); await get_tree().process_frame
	# 2) 28 animações da versão corrigida (quadro do meio), frente 3/4
	for g in (["m", "f"] if parte("anim") else []):
		var c := montar_de(V3, "pc_humano_" + g, PECAS_M if g == "m" else PECAS_F)
		for n in (c.anim as AnimationPlayer).get_animation_list():
			pose(c, n, 0.5); await foto("depois_anim_%s_%s" % [g, n], Vector3(0, 0.85, 0), 6.0, 35.0, 0.6, 2.4)
		c.body.queue_free(); await get_tree().process_frame
	# 3) espada: 3 graus x mão / costas / cintura (cintura pela configuração de espada_longa.json)
	var cfg := V3 + "equipamentos/espada_longa.json"
	for g in (["d", "b", "s"] if parte("espada") else []):
		var c := montar_de(V3, "pc_humano_m", PECAS_M)
		hand_grip(c.skel, "r").add_child(place(V3 + "equipamentos/wp_espada_longa_%s.glb" % g, 1.0, 0.1))
		pose(c, "Sword_Block", 0.5); await foto("depois_espada_%s_mao" % g, Vector3(0, 1.0, 0), 6.0, 330.0, 0.4, 2.2)
		c.body.queue_free(); await get_tree().process_frame
		c = montar_de(V3, "pc_humano_m", PECAS_M)
		sheath(c.skel, true, 1.8).add_child(place(V3 + "equipamentos/wp_espada_longa_%s.glb" % g, 1.0, 0.1))
		pose(c, "Idle", 0.3); await foto("depois_espada_%s_costas" % g, Vector3(0, 1.0, 0), 6.0, 200.0, 0.3, 2.2)
		c.body.queue_free(); await get_tree().process_frame
		c = montar_de(V3, "pc_humano_m", PECAS_M)
		bainha_cfg(c.skel, 1.8, cfg).add_child(place(V3 + "equipamentos/wp_espada_longa_%s.glb" % g, 1.0, 0.1))
		for p in [["parado", "Idle", 0.3], ["andando", "Walk", 0.25], ["correndo", "Jog_Fwd", 0.3]]:
			pose(c, p[1], p[2]); await foto("depois_espada_%s_cintura_%s" % [g, p[0]], Vector3(0, 0.9, 0), 6.0, 70.0, 0.3, 2.2)
		c.body.queue_free(); await get_tree().process_frame
	if antes != "" and parte("espada"):   # cintura antes (regra do jogo) x depois, mesma pose
		for v in [["antes", antes], ["depois", V3]]:
			var c := montar_de(v[1], "pc_humano_m", PECAS_M)
			var w := place(v[1] + "equipamentos/wp_espada_longa_b.glb", 1.0, 0.1)
			if v[0] == "antes": sheath(c.skel, false, 1.8).add_child(w)
			else: bainha_cfg(c.skel, 1.8, cfg).add_child(w)
			pose(c, "Idle", 0.3)
			await foto("%s_espada_cintura_lado" % v[0], Vector3(0, 0.9, 0), 6.0, 90.0, 0.0, 2.2)
			await foto("%s_espada_cintura_tras" % v[0], Vector3(0, 0.9, 0), 6.0, 160.0, 0.0, 2.2)
			c.body.queue_free(); await get_tree().process_frame
	# 4) medalhão: espada na mão, câmera em perspectiva a 3 m e 6 m (FOV 40), antes x depois, graus B e S
	get_viewport().size = Vector2i(1600, 900)
	for v in (versoes if parte("medalhao") else []):
		for g in ["b", "s"]:
			var c := montar_de(v[1], "pc_humano_m", PECAS_M)
			hand_grip(c.skel, "r").add_child(place(v[1] + "equipamentos/wp_espada_longa_%s.glb" % g, 1.0, 0.1))
			pose(c, "Sword_Block", 0.5)
			var sk := c.skel as Skeleton3D
			var mao := sk.to_global(sk.get_bone_global_pose(sk.find_bone("hand_r")).origin)
			for dist in [3.0, 6.0]:
				await foto_persp("%s_medalhao_%s_%dm" % [v[0], g, int(dist)], mao + Vector3(0, 0.15, 0), dist, 20.0, 0.3, 40.0)
			c.body.queue_free(); await get_tree().process_frame
		# espada sozinha, de pé, com a face da lâmina (e o medalhão) virada para a câmera, ao lado de um personagem
		for g in ["b", "s"]:
			var c := montar_de(v[1], "pc_humano_m", PECAS_M); pose(c, "Idle", 0.3); c.body.position.x = -0.7
			var w := place(v[1] + "equipamentos/wp_espada_longa_%s.glb" % g, 1.0, 0.1)
			var suporte := Node3D.new(); add_child(suporte); suporte.add_child(w)
			suporte.transform = Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(-90.0)), Vector3(0, 1.0, 0))   # lâmina para cima
			var alvo := Vector3(0, 0.82, 0)   # altura da guarda
			for dist in [3.0, 6.0]:
				await foto_persp("%s_medalhao_frente_%s_%dm" % [v[0], g, int(dist)], alvo, dist, 0.0, 0.0, 40.0)
			c.body.queue_free(); suporte.queue_free(); await get_tree().process_frame
	# 5) trança: completa x LOD manual, a 5, 15 e 30 m (perspectiva)
	for d in ([5.0, 15.0, 30.0] if parte("tranca") else []):
		for t in ["ca_tranca_longa", "ca_tranca_longa_lod1"]:
			var c := montar_de(V3, "pc_humano_f", ["rp_aldeao_tunica_f", "rp_aldeao_calca_f", "rp_botas_couro_f", t])
			pose(c, "Idle", 0.3)
			await foto_persp("depois_tranca_%s_%dm" % [("lod" if t.ends_with("lod1") else "completa"), int(d)], Vector3(0, 1.3, 0), d, 160.0, 0.2, 40.0)
			c.body.queue_free(); await get_tree().process_frame

# ---------------- medidas: arquivo, visível e sombra separados ----------------
func tri_arquivo(raiz: Node) -> int:
	var n := 0
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (m as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arr := mesh.surface_get_arrays(s); var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			n += (idx.size() / 3) if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX].size() / 3)
	return n

func info(t: int, k: int) -> int:
	return RenderingServer.viewport_get_render_info(get_viewport().get_viewport_rid(), t, k)

func _medidas() -> void:
	get_viewport().size = Vector2i(1600, 900)
	var sol: DirectionalLight3D = null
	for c in get_children():
		if c is DirectionalLight3D: sol = c
	var casos := {"atual_aldeao_m": ["res://assets/chars/", "body_male_peasant", ["outfit_male_peasant", "hair_simpleparted", "hair_eyebrows_regular"]],
		"v3_m": [V3, "pc_humano_m", PECAS_M], "v3_f": [V3, "pc_humano_f", PECAS_F],
		"v3_f_tranca_lod": [V3, "pc_humano_f", ["rp_aldeao_tunica_f", "rp_aldeao_calca_f", "rp_botas_couro_f", "ca_tranca_longa_lod1"]]}
	if antes != "":
		casos["antes_m"] = [antes, "pc_humano_m", PECAS_M]; casos["antes_f"] = [antes, "pc_humano_f", PECAS_F]
	for k in casos:
		if caso != "" and k != caso: continue
		for i in 4: await RenderingServer.frame_post_draw
		var mem_vazio := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
		var c: Dictionary
		if k == "atual_aldeao_m": c = montar(casos[k][1], casos[k][2], true)
		else: c = montar_de(casos[k][0], casos[k][1], casos[k][2])
		pose(c, "Idle", 0.3)
		var r := {"triangulos_arquivo": tri_arquivo(c.body)}
		for dist in [2.5, 6.0, 15.0, 30.0]:
			for sombra in [true, false]:
				get_viewport().mesh_lod_threshold = 1.0; sol.shadow_enabled = sombra
				cam.projection = Camera3D.PROJECTION_PERSPECTIVE; cam.fov = 40.0
				cam.position = Vector3(0, 1.2, dist); cam.look_at(Vector3(0, 0.9, 0))
				for i in 4: await RenderingServer.frame_post_draw
				r["%sm_%s" % [str(dist), "sombra" if sombra else "sem_sombra"]] = {
					"visivel_tri": info(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
					"sombra_tri": info(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
					"chamadas_visivel": info(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
					"chamadas_sombra": info(RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)}
		r["memoria_texturas_mb"] = snappedf((Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) - mem_vazio) / 1048576.0, 0.1)
		resultado[k] = r
		c.body.queue_free(); for i in 3: await get_tree().process_frame
	sol.shadow_enabled = true
