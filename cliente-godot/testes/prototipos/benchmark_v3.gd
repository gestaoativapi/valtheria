extends Node3D
# Valtheria V3 — benchmark do marco P1/P2/P5 (D56). Não faz parte do jogo.
# Mede, na máquina real, o custo dos personagens atuais x protótipos V3, com espada na mão,
# em cenas de 1, 20 e 40 personagens animados. Grava resultado_benchmark.json e .csv ao lado do executável.
# Uso no editor: godot --path . res://testes/prototipos/benchmark_v3.tscn -- [--segundos=15] [--saida=<pasta>]
const CharacterScript := preload("res://scripts/character.gd")
const V3 := "res://assets_v3/"
const OFI := "res://assets/chars/"
# AUT-022: "v3r" = como v3s, com as túnicas RBF (formas corretivas + 16 formas por exemplos e controlador RBF)
# AUT-021: "v3s" = V3 da sprint (túnicas com formas corretivas + controlador por personagem; trança troca para a LOD a 12 m)
const CENARIOS := [["vazio", 0], ["atual", 1], ["atual", 20], ["atual", 40], ["v3", 1], ["v3", 20], ["v3", 40], ["v3s", 1], ["v3s", 20], ["v3s", 40], ["v3r", 1], ["v3r", 20], ["v3r", 40]]
const Ctrl := preload("res://testes/prototipos/corretivas_controlador.gd")
const ANIMS := ["Walk", "Idle", "Jog_Fwd", "Sword_Regular_A", "Idle_Talking"]
var segundos := 15.0
var aquecer := 3.0
var saida := ""
var cam: Camera3D
var placa: Label
var grupo: Node3D
var linhas := []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--segundos="): segundos = float(a.substr(11))
		if a.begins_with("--saida="): saida = a.substr(8)
	if saida == "":
		saida = OS.get_executable_path().get_base_dir() if OS.has_feature("template") else "user://benchmark"
	DirAccess.make_dir_recursive_absolute(saida)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.46, 0.50, 0.55)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.64, 0.70); e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e; add_child(env)
	var sol := DirectionalLight3D.new(); sol.rotation_degrees = Vector3(-42, -35, 0); sol.light_energy = 1.25
	sol.shadow_enabled = true; add_child(sol)
	var chao := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, 40); chao.mesh = pm; add_child(chao)
	cam = Camera3D.new(); add_child(cam); cam.current = true
	cam.position = Vector3(0, 6.5, 13.0); cam.look_at(Vector3(0, 0.9, -2.0), Vector3.UP)
	var ui := CanvasLayer.new(); add_child(ui)
	placa = Label.new(); placa.position = Vector2(16, 12); placa.add_theme_font_size_override("font_size", 20)
	placa.add_theme_color_override("font_outline_color", Color.BLACK); placa.add_theme_constant_override("outline_size", 6)
	ui.add_child(placa)
	await get_tree().process_frame
	var adaptador := RenderingServer.get_video_adapter_name()
	var software := _software(adaptador)
	for c in CENARIOS:
		await _rodar(c[0], c[1])
	# identificação do build (AUT-022): commit gravado no momento da exportação, hash do próprio executável, renderizador real
	var build := {}
	if FileAccess.file_exists("res://testes/prototipos/build_info.json"):
		build = JSON.parse_string(FileAccess.get_file_as_string("res://testes/prototipos/build_info.json"))
	var exe := OS.get_executable_path()
	var hash_exe := FileAccess.get_sha256(exe) if not OS.has_feature("editor") else "editor (sem executável exportado)"
	var renderizador_real := "%s / %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name()]
	var info := {
		"versao_teste": "benchmark_v3 1.1", "commit": build.get("commit", "desconhecido"), "branch": build.get("branch", ""),
		"gerado_em": build.get("gerado_em", ""), "executavel": exe.get_file(), "sha256_executavel": hash_exe,
		"placa_de_video": adaptador, "fabricante": RenderingServer.get_video_adapter_vendor(),
		"driver_api": RenderingServer.get_video_adapter_api_version(), "renderizador": renderizador_real,
		"renderizador_configurado": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"sistema": OS.get_name() + " " + OS.get_version(), "processador": OS.get_processor_name(), "nucleos": OS.get_processor_count(),
		"resolucao": str(get_viewport().get_visible_rect().size), "vsync": "desligado", "segundos_por_cenario": segundos,
		"renderizacao_por_software": software,
		"aviso": "RENDERIZAÇÃO POR SOFTWARE: FPS NÃO REPRESENTA DESEMPENHO REAL" if software else "",
		"cenarios": linhas}
	var f := FileAccess.open(saida.path_join("resultado_benchmark.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(info, " ")); f.close()
	var csv := FileAccess.open(saida.path_join("resultado_benchmark.csv"), FileAccess.WRITE)
	csv.store_line("cenario;personagens;fps_medio;fps_1pct_baixo;tempo_quadro_medio_ms;tempo_quadro_p99_ms;chamadas_de_desenho;triangulos;memoria_video_mb;memoria_total_mb;versao_teste;commit;sha256_executavel;placa_de_video;renderizador;renderizacao_por_software")
	for l in linhas:
		csv.store_line("%s;%d;%.1f;%.1f;%.2f;%.2f;%d;%d;%.1f;%.1f;%s;%s;%s;%s;%s;%s" % [l.cenario, l.personagens, l.fps_medio, l.fps_1pct_baixo, l.tempo_quadro_medio_ms, l.tempo_quadro_p99_ms, l.chamadas_de_desenho, l.triangulos, l.memoria_video_mb, l.memoria_total_mb,
			info.versao_teste, info.commit, info.sha256_executavel, adaptador.replace(";", ","), renderizador_real, "sim" if software else "nao"])
	csv.close()
	var txt := "Teste concluído (commit %s). Resultados em:\n%s\n\nPlaca: %s%s\n\n" % [info.commit, ProjectSettings.globalize_path(saida), adaptador, "\nAVISO: renderização por software — FPS não é real." if software else ""]
	for l in linhas:
		txt += "%-6s %2d personagens: %6.1f FPS (1%% baixo %6.1f)  %4d chamadas  %7d triângulos\n" % [l.cenario, l.personagens, l.fps_medio, l.fps_1pct_baixo, l.chamadas_de_desenho, l.triangulos]
	placa.text = txt + "\nPode fechar a janela."
	if "--sair" in OS.get_cmdline_user_args(): get_tree().quit()

func _software(nome: String) -> bool:
	var n := nome.to_lower()
	for s in ["llvmpipe", "swiftshader", "softpipe", "microsoft basic", "basic render", "lavapipe"]:
		if s in n: return true
	return false

func _rodar(tipo: String, n: int) -> void:
	if grupo: grupo.queue_free(); await get_tree().process_frame; await get_tree().process_frame
	grupo = Node3D.new(); add_child(grupo)
	var cols := 8
	for i in n:
		var fem := i % 2 == 1
		var c := _montar(tipo, fem)
		var x := (i % cols - (cols - 1) * 0.5) * 1.3; var z := -float(i / cols) * 1.6
		c.body.position = Vector3(x, 0, z)
		var anim: AnimationPlayer = c.anim
		var nome: String = ANIMS[i % ANIMS.size()]
		if anim.has_animation(nome):
			anim.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
			anim.play(nome); anim.seek(fmod(i * 0.37, anim.get_animation(nome).length), true)
	placa.text = "Benchmark Valtheria V3 — aquecendo: %s, %d personagens" % [tipo, n]
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < aquecer * 1000.0: await get_tree().process_frame
	var tempos := PackedFloat64Array()
	var dc := 0.0; var tri := 0.0; var amostras := 0
	var ultimo := Time.get_ticks_usec(); t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < segundos * 1000.0:
		await get_tree().process_frame
		var agora := Time.get_ticks_usec(); tempos.append((agora - ultimo) / 1000.0); ultimo = agora
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		tri += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME); amostras += 1
		placa.text = "Benchmark Valtheria V3 — medindo: %s, %d personagens (%d s)" % [tipo, n, int(segundos - (Time.get_ticks_msec() - t0) / 1000.0)]
	var soma := 0.0
	for t in tempos: soma += t
	var ord := tempos.duplicate(); ord.sort()
	var k := maxi(1, int(ord.size() * 0.01))
	var pior := 0.0
	for j in k: pior += ord[ord.size() - 1 - j]
	pior /= k
	var media := soma / tempos.size()
	linhas.append({"cenario": tipo, "personagens": n, "quadros": tempos.size(),
		"fps_medio": 1000.0 / media, "fps_1pct_baixo": 1000.0 / pior,
		"tempo_quadro_medio_ms": media, "tempo_quadro_p99_ms": ord[int(ord.size() * 0.99) - 1] if ord.size() > 1 else media,
		"chamadas_de_desenho": int(round(dc / amostras)), "triangulos": int(round(tri / amostras)),
		"memoria_video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"memoria_total_mb": (Performance.get_monitor(Performance.MEMORY_STATIC) + Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)) / 1048576.0})

# montagem pelo mesmo método do character.gd e da cena p1_humano
func _montar(tipo: String, fem: bool) -> Dictionary:
	var corpo: String; var pecas: Array; var dir: String; var arma: String
	if tipo == "atual":
		dir = OFI; arma = OFI + "w_sword.glb"
		corpo = "body_female_peasant" if fem else "body_male_peasant"
		pecas = ["outfit_female_peasant", "hair_long", "hair_eyebrows_female"] if fem else ["outfit_male_peasant", "hair_simpleparted", "hair_eyebrows_regular"]
	else:
		dir = V3 + "personagens/"; arma = V3 + "equipamentos/wp_espada_longa_b.glb"
		corpo = "pc_humano_f" if fem else "pc_humano_m"
		pecas = ["rp_aldeao_tunica_f", "rp_aldeao_calca_f", "rp_botas_couro_f", "ca_tranca_longa"] if fem else ["rp_aldeao_tunica_m", "rp_aldeao_calca_m", "rp_botas_couro_m", "ca_curto_01"]
		if tipo == "v3s" or tipo == "v3r":
			pecas[0] = pecas[0] + ("_corretiva" if tipo == "v3s" else "_rbf")
			if fem: pecas.append("ca_tranca_longa_lod1")
	var body: Node3D = (load(dir + corpo + ".glb") as PackedScene).instantiate()
	grupo.add_child(body)
	var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D
	for p in pecas:
		var src: Node3D = (load(dir + p + ".glb") as PackedScene).instantiate()
		for m in src.find_children("*", "MeshInstance3D", true, false):
			m.get_parent().remove_child(m); m.owner = null; skel.add_child(m)
			(m as MeshInstance3D).skeleton = NodePath("..")
			if p.ends_with("_corretiva") or p.ends_with("_rbf"):
				var ct = Ctrl.new(); body.add_child(ct); ct.configurar(skel, m)
				if p.ends_with("_rbf"): ct.carregar_rbf(dir + p + ".rbf.json")
			if (tipo == "v3s" or tipo == "v3r") and p == "ca_tranca_longa":
				m.visibility_range_end = 12.0; m.visibility_range_end_margin = 1.0
			if p == "ca_tranca_longa_lod1":
				m.visibility_range_begin = 12.0; m.visibility_range_begin_margin = 1.0
		src.free()
	var anim := AnimationPlayer.new(); body.add_child(anim)
	anim.add_animation_library("", CharacterScript._clips(skel, ""))
	_mao(skel).add_child(_place(arma, 1.0, 0.1))
	return {"body": body, "skel": skel, "anim": anim}

func _place(path: String, length: float, at: float) -> Node3D:
	var w: Node3D = (load(path) as PackedScene).instantiate()
	var bb := AABB(); var first := true
	for m in w.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D; var a: AABB = mi.transform * mi.get_aabb()
		bb = a if first else bb.merge(a); first = false
	var axis := bb.get_longest_axis_index(); var k := length / bb.size[axis]
	var d := Vector3.ZERO; d[axis] = 1.0
	var far_pos: float = bb.position[axis] + bb.size[axis]; var far_neg: float = bb.position[axis]
	if absf(far_neg) > absf(far_pos): d = -d
	var handle: float = (far_neg if d[axis] > 0.0 else far_pos)
	var off := bb.get_center(); off[axis] = handle + d[axis] * at / k
	w.transform = Transform3D(Basis(Quaternion(d, Vector3(0, 0, 1))).scaled(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -off)
	return w

func _mao(skel: Skeleton3D) -> Node3D:
	var hand := skel.find_bone("hand_r"); var mid := skel.find_bone("middle_01_r")
	var idx := skel.find_bone("index_01_r"); var pinky := skel.find_bone("pinky_01_r")
	var gh := skel.get_bone_global_rest(hand)
	var fing := (skel.get_bone_global_rest(mid).origin - gh.origin).normalized()
	var th := skel.get_bone_global_rest(idx).origin - skel.get_bone_global_rest(pinky).origin
	th = (th - fing * th.dot(fing)).normalized()
	var frame := Basis(Vector3(-fing).cross(th).normalized(), -fing, th)
	var att := BoneAttachment3D.new(); att.bone_name = "hand_r"; skel.add_child(att)
	var grip := Node3D.new(); grip.transform = Transform3D(gh.basis.inverse() * frame, skel.get_bone_rest(mid).origin * 0.55)
	att.add_child(grip)
	return grip
