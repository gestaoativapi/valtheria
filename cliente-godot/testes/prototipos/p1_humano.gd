extends Node3D
# Valtheria V3 — cena de teste isolada do marco P1/P2/P5 (não faz parte do jogo).
# Monta os protótipos pelo MESMO método do character.gd (um esqueleto, peças presas a ele, animações oficiais
# reapontadas por _clips) e a espada pela mesma pegada (_hand_grip) e bainha (_make_sheath) do jogo.
# Uso: godot --path . res://testes/prototipos/p1_humano.tscn -- --saida=<pasta> [--modo=capturas|medidas]
const CharacterScript := preload("res://scripts/character.gd")
const V3 := "res://assets_v3/"
var saida := "user://prototipos"
var modo := "capturas"
var cam: Camera3D
var resultado := {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): saida = a.substr(8)
		if a.begins_with("--modo="): modo = a.substr(7)
	DirAccess.make_dir_recursive_absolute(saida)
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.46, 0.50, 0.55)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.64, 0.70); e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e; add_child(env)
	var sol := DirectionalLight3D.new(); sol.rotation_degrees = Vector3(-42, -35, 0); sol.light_energy = 1.25; sol.light_color = Color(1.0, 0.95, 0.86); add_child(sol)
	cam = Camera3D.new(); add_child(cam); cam.current = true
	await get_tree().process_frame
	if modo == "medidas": await _medidas()
	else: await _capturas()
	var f := FileAccess.open(saida.path_join("resultado_%s.json" % modo), FileAccess.WRITE)
	f.store_string(JSON.stringify(resultado, " ")); f.close()
	get_tree().quit()

# ---------------- montagem ----------------
func montar(corpo: String, pecas: Array, oficial := false) -> Dictionary:
	var dir := "res://assets/chars/" if oficial else V3 + "personagens/"
	var body: Node3D = (load(dir + corpo + ".glb") as PackedScene).instantiate()
	add_child(body)
	var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D
	for p in pecas:
		var src: Node3D = (load(dir + p + ".glb") as PackedScene).instantiate()
		for m in src.find_children("*", "MeshInstance3D", true, false):
			m.get_parent().remove_child(m); m.owner = null; skel.add_child(m)
			(m as MeshInstance3D).skeleton = NodePath("..")
		src.free()
	var anim := AnimationPlayer.new(); body.add_child(anim)
	anim.add_animation_library("", CharacterScript._clips(skel, ""))
	return {"body": body, "skel": skel, "anim": anim}

func pose(c: Dictionary, nome: String, frac := 0.5) -> void:
	var a: AnimationPlayer = c.anim
	a.play(nome); a.seek(a.get_animation(nome).length * frac, true); a.pause()

# pegada e bainha: cópia fiel de character.gd (_place, _hand_grip, _make_sheath)
func place(path: String, length: float, at: float) -> Node3D:
	var w: Node3D = (load(path) as PackedScene).instantiate()
	var bb := AABB(); var first := true
	for m in w.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D; var a: AABB = mi.transform * mi.get_aabb()
		bb = a if first else bb.merge(a); first = false
	var axis := bb.get_longest_axis_index(); var k := length / bb.size[axis]
	var dir := Vector3.ZERO; dir[axis] = 1.0
	var far_pos: float = bb.position[axis] + bb.size[axis]; var far_neg: float = bb.position[axis]
	if absf(far_neg) > absf(far_pos): dir = -dir
	var handle: float = (far_neg if dir[axis] > 0.0 else far_pos)
	var off := bb.get_center(); off[axis] = handle + dir[axis] * ((length * 0.5) if at < 0.0 else at) / k
	w.transform = Transform3D(Basis(Quaternion(dir, Vector3(0, 0, 1))).scaled(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -off)
	return w

func hand_grip(skel: Skeleton3D, side: String) -> Node3D:
	var hand := skel.find_bone("hand_" + side); var mid := skel.find_bone("middle_01_" + side)
	var idx := skel.find_bone("index_01_" + side); var pinky := skel.find_bone("pinky_01_" + side)
	var gh := skel.get_bone_global_rest(hand)
	var fing := (skel.get_bone_global_rest(mid).origin - gh.origin).normalized()
	var th := skel.get_bone_global_rest(idx).origin - skel.get_bone_global_rest(pinky).origin
	th = (th - fing * th.dot(fing)).normalized()
	var frame := Basis(Vector3(-fing).cross(th).normalized(), -fing, th)
	var att := BoneAttachment3D.new(); att.bone_name = "hand_" + side; skel.add_child(att)
	var grip := Node3D.new(); grip.transform = Transform3D(gh.basis.inverse() * frame, skel.get_bone_rest(mid).origin * 0.55)
	att.add_child(grip)
	grip.scale = Vector3.ONE / maxf(skel.get_bone_global_pose(hand).basis.get_scale().x, 0.01)
	return grip

func sheath(skel: Skeleton3D, back: bool, height_m: float) -> Node3D:
	var bone := skel.find_bone("spine_03") if back else skel.find_bone("pelvis")
	var gb := skel.get_bone_global_rest(bone)
	var att := BoneAttachment3D.new(); att.bone_name = skel.get_bone_name(bone); skel.add_child(att)
	var k := height_m / 1.8
	var blade := Vector3(-0.42, -0.9, 0.0).normalized(); var out := Vector3(0, 0, -1)
	var handle := gb.origin + Vector3(0.2, 0.2, -0.17) * k
	if not back:
		blade = Vector3(0.15, -0.7, -0.7).normalized(); out = Vector3(1, 0, 0); handle = gb.origin + Vector3(0.2, 0.04, 0.05) * k
	var x := out.cross(blade).normalized(); var y := blade.cross(x).normalized()
	var s := Node3D.new(); s.transform = Transform3D(gb.basis.inverse() * Basis(x, y, blade), gb.affine_inverse() * handle)
	att.add_child(s); return s

# ---------------- capturas ----------------
func foto(nome: String, alvo: Vector3, dist: float, ang_y: float, altura := 0.0, tam := 2.0) -> void:
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = tam
	cam.position = alvo + Vector3(sin(deg_to_rad(ang_y)), 0, cos(deg_to_rad(ang_y))) * dist + Vector3(0, altura, 0)
	cam.look_at(alvo, Vector3.UP)
	await RenderingServer.frame_post_draw; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(saida.path_join(nome + ".png"))

const PECAS_M := ["rp_aldeao_tunica_m", "rp_aldeao_calca_m", "rp_botas_couro_m", "ca_curto_01"]
const PECAS_F := ["rp_aldeao_tunica_f", "rp_aldeao_calca_f", "rp_botas_couro_f", "ca_tranca_longa"]

func limpar() -> void:
	for c in get_children():
		if c is Node3D and not (c is Camera3D) and not (c is DirectionalLight3D) and not (c is WorldEnvironment): c.queue_free()
	await get_tree().process_frame

func _capturas() -> void:
	get_viewport().size = Vector2i(1200, 900)
	# 1) prancha: atual (aldeão oficial) x V3 masculino x V3 feminino, em Idle
	var atual := montar("body_male_peasant", ["outfit_male_peasant", "hair_simpleparted", "hair_eyebrows_regular"], true)
	var m := montar("pc_humano_m", PECAS_M); var f := montar("pc_humano_f", PECAS_F)
	atual.body.position.x = -1.0; f.body.position.x = 1.0
	for c in [atual, m, f]: pose(c, "Idle", 0.3)
	for v in [["frente", 0.0], ["lado", 90.0], ["costas", 180.0]]:
		await foto("prancha_" + v[0], Vector3(0, 0.9, 0), 6.0, v[1], 0.0, 2.3)
	await foto("rosto_m", Vector3(0, 1.62, 0), 3.0, 0.0, 0.0, 0.42)
	await foto("rosto_f", Vector3(1.0, 1.52, 0), 3.0, 0.0, 0.0, 0.42)
	await limpar()
	# 2) as 28 animações, quadro do meio, masculino e feminino lado a lado
	var nomes := []
	for g in ["m", "f"]:
		var c := montar("pc_humano_" + g, PECAS_M if g == "m" else PECAS_F)
		var lista: PackedStringArray = (c.anim as AnimationPlayer).get_animation_list()
		for n in lista:
			pose(c, n, 0.5)
			await foto("anim_%s_%s" % [g, n], Vector3(0, 0.85, 0), 6.0, 35.0, 0.6, 2.4)
			if g == "m": nomes.append(n)
		c.body.queue_free(); await get_tree().process_frame
	resultado["animacoes"] = nomes
	# 3) espada: na mão (Sword_Regular_A e Idle), na cintura (bainha do jogo) e nas costas (bainha de costas)
	var esp := []
	for g in ["d", "b", "s"]:
		var c := montar("pc_humano_m", PECAS_M)
		var w := place(V3 + "equipamentos/wp_espada_longa_%s.glb" % g, 1.0, 0.1)
		hand_grip(c.skel, "r").add_child(w)
		var cin := place(V3 + "equipamentos/wp_espada_longa_%s.glb" % g, 1.0, 0.1); sheath(c.skel, false, 1.8).add_child(cin)
		var cos := place(V3 + "equipamentos/wp_espada_longa_%s.glb" % g, 1.0, 0.1); sheath(c.skel, true, 1.8).add_child(cos)
		for p in [["guarda", "Sword_Regular_A", 0.3], ["parado", "Idle", 0.3], ["bloqueio", "Sword_Block", 0.5]]:
			pose(c, p[1], p[2]); await foto("espada_%s_%s" % [g, p[0]], Vector3(0, 1.0, 0), 6.0, 30.0, 0.4, 2.2)
		await foto("espada_%s_costas_cintura" % g, Vector3(0, 1.0, 0), 6.0, 200.0, 0.3, 2.2)
		await foto("espada_%s_mao_detalhe" % g, (c.skel as Skeleton3D).to_global((c.skel as Skeleton3D).get_bone_global_pose((c.skel as Skeleton3D).find_bone("hand_r")).origin), 3.0, 30.0, 0.2, 0.6)
		esp.append(g)
		c.body.queue_free(); await get_tree().process_frame
	resultado["espada_graus"] = esp

# ---------------- medidas (uma peça montada por vez, câmera enquadrando) ----------------
func medir(rotulo: String) -> Dictionary:
	for i in 6: await RenderingServer.frame_post_draw
	return {"chamadas_de_desenho": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"triangulos": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"objetos": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"memoria_texturas_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1)}

func _medidas() -> void:
	get_viewport().size = Vector2i(800, 600)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.4; cam.position = Vector3(0, 0.9, 6); cam.look_at(Vector3(0, 0.9, 0))
	resultado["vazio"] = await medir("vazio")
	var casos := {
		"atual_aldeao_m": ["body_male_peasant", ["outfit_male_peasant", "hair_simpleparted", "hair_eyebrows_regular"], true],
		"v3_humano_m": ["pc_humano_m", PECAS_M, false], "v3_humano_f": ["pc_humano_f", PECAS_F, false]}
	for k in casos:
		var c := montar(casos[k][0], casos[k][1], casos[k][2]); pose(c, "Idle", 0.3)
		resultado[k] = await medir(k)
		if k == "v3_humano_m":
			var w := place(V3 + "equipamentos/wp_espada_longa_s.glb", 1.0, 0.1); hand_grip(c.skel, "r").add_child(w)
			resultado["v3_humano_m_com_espada_s"] = await medir("esp")
		c.body.queue_free(); await get_tree().process_frame; await get_tree().process_frame
