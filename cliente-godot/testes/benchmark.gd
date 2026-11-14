extends Node3D
# Diagnóstico de vídeo e medição repetível (D42). Só existe na ramificação de teste v2-prova-visual.
# Uso: Valtheria.console.exe -- --benchmark            (medição completa: 3 rodadas por variante)
#      Valtheria.console.exe -- --benchmark --rapido   (teste curto, só para conferir que roda)
#      Valtheria.console.exe -- --diagnostico-video    (só o diagnóstico)
const Character = preload("res://scripts/character.gd")
const V2 := {"m": "res://assets/chars_v2/v2_ligado_masculino.glb", "f": "res://assets/chars_v2/v2_ligado_feminino.glb"}
const HIP := {"m": 1.0302, "f": 0.9573}
var aquece := 10.0
var mede := 30.0
var rodadas := 3
var cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--rapido" in args:
		aquece = 1.0
		mede = 3.0
	var w = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	Character.RACES = w.races
	Character.HAIR_COLORS = w.hair_colors
	var diag := diagnostico()
	_escreve("diagnostico_video.txt", JSON.stringify(diag, "  "))
	print("DIAGNOSTICO ", JSON.stringify(diag))
	if not ("--benchmark" in args):
		get_tree().quit()
		return
	_cena()
	# corpo, armadura e arma medidos em separado; a V2 ainda não tem armadura nem espada (etapas seguintes)
	# [nome, tipo, equipamento, quantidade]; as de 40 são só diagnóstico (sem meta de FPS)
	var variantes := [["corpo_atual", "atual", {}, 20], ["corpo_v2", "v2", {}, 20], ["atual_com_armadura", "atual", {"armadura": "leve_c"}, 20], ["atual_completo_armadura_e_espada", "atual", {"armadura": "leve_c", "arma": "espada_c"}, 20],
		["diag40_atual_completo", "atual", {"armadura": "leve_c", "arma": "espada_c"}, 40], ["diag40_corpo_v2", "v2", {}, 40]]
	var res := {"diagnostico": diag, "config": {"aquecimento_s": aquece, "medicao_s": mede, "rodadas": rodadas, "personagens": "20 (e 40 nas variantes diag40)", "camera": "volta fixa de 30 s, raio 9 m, altura 3 m", "resolucao": str(get_viewport().get_visible_rect().size)}, "variantes": {}}
	for v in variantes:
		var grupo := _povoa(str(v[1]), v[2], int(v[3]))
		var rs: Array = []
		for r in rodadas:
			rs.append(await _rodada())
		grupo.queue_free()
		await get_tree().process_frame
		res.variantes[v[0]] = {"personagens": int(v[3]), "rodadas": rs, "mediana": _mediana(rs)}
		print("VARIANTE ", v[0], " ", JSON.stringify(res.variantes[v[0]].mediana))
	var nome := "benchmark_%s.json" % Time.get_datetime_string_from_system().replace(":", "-")
	_escreve(nome, JSON.stringify(res, "  "))
	print("RESULTADO SALVO EM ", OS.get_user_data_dir().path_join(nome))
	get_tree().quit()


func diagnostico() -> Dictionary:
	var fmt := {}
	for f in ["s3tc", "bptc", "rgtc", "etc", "etc2", "astc"]:
		fmt[f] = RenderingServer.has_os_feature(f)
	return {"godot": Engine.get_version_info().string, "so": OS.get_name() + " " + OS.get_version(),
		"renderizador": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"gpu": RenderingServer.get_video_adapter_name(), "fabricante": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(), "tipo_gpu": RenderingServer.get_video_adapter_type(),
		"resolucao": str(DisplayServer.window_get_size()), "formatos_compressao": fmt, "ramificacao": "v2-prova-visual"}


func _cena() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.4, 0.5, 0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.65)
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	fl.mesh = pm
	add_child(fl)
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 60
	cam.make_current()


func _povoa(tipo: String, eq: Dictionary, qtd: int) -> Node3D:
	var g := Node3D.new()
	add_child(g)
	for i in qtd:
		var gen := "m" if i % 2 == 0 else "f"
		var n: Node3D
		if tipo == "atual":
			n = Character.create({"race": "humano", "gender": gen, "skin": 1, "hair": 0, "equipment": eq})
		else:
			n = (load(V2[gen]) as PackedScene).instantiate()
			var sk := n.find_child("Skeleton3D", true, false) as Skeleton3D
			var ap := AnimationPlayer.new()
			n.add_child(ap)
			ap.add_animation_library("", _lib(sk, float(HIP[gen])))
			ap.play("Idle")
		g.add_child(n)
		n.position = Vector3((i % 5) * 1.6 - 3.2, 0, floorf(i / 5.0) * 1.8 - 2.7 - (3.6 if qtd > 20 else 0.0))  # grade fixa de 5 colunas (5 x 4 ou 5 x 8)
	return g


func _lib(sk: Skeleton3D, hip: float) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for f in ["anims_a", "anims_b"]:
		var sc: Node = (load("res://assets/chars/" + f + ".glb") as PackedScene).instantiate()
		var ap := sc.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for n in ap.get_animation_list():
			var a: Animation = ap.get_animation(n).duplicate(true)
			for t in range(a.get_track_count() - 1, -1, -1):
				var p := a.track_get_path(t)
				var bone := String(p.get_name(p.get_name_count() - 1))
				if sk.find_bone(bone) < 0:
					a.remove_track(t)
					continue
				a.track_set_path(t, NodePath("Armature/Skeleton3D:" + bone))
				if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
					for k in a.track_get_key_count(t):
						a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Vector3) * hip)
			if n == "Idle":
				a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(n, a)
		sc.free()
	return lib


func _cam(t: float) -> void:
	# caminho fixo: volta completa em 30 s, a 9 m do centro e 3 m de altura
	var a := t / 30.0 * TAU
	cam.position = Vector3(sin(a) * 9.0, 3.0, cos(a) * 9.0)
	cam.look_at(Vector3(0, 1, 0))


func _rodada() -> Dictionary:
	var t := 0.0
	while t < aquece:
		_cam(t)
		await get_tree().process_frame
		t += get_process_delta_time()
	var tempos: Array = []
	var dc := 0.0
	var pr := 0.0
	var n := 0
	t = 0.0
	var ult := Time.get_ticks_usec()
	while t < mede:
		_cam(t)
		await get_tree().process_frame
		var agora := Time.get_ticks_usec()
		var ft := (agora - ult) / 1000.0
		ult = agora
		tempos.append(ft)
		t += ft / 1000.0
		dc += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		pr += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		n += 1
	var ord: Array = tempos.duplicate()
	ord.sort()
	var k := maxi(1, int(ord.size() * 0.01))
	var pior := 0.0
	for i in k:
		pior += float(ord[ord.size() - 1 - i])
	pior /= k
	var media := 0.0
	for x in tempos:
		media += float(x)
	media /= maxf(1.0, tempos.size())
	return {"fps_medio": snappedf(1000.0 / media, 0.1), "fps_1pct_baixo": snappedf(1000.0 / pior, 0.1), "tempo_quadro_ms": snappedf(media, 0.01),
		"chamadas_desenho": snappedf(dc / n, 0.1), "triangulos": int(pr / n),
		"memoria_video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"memoria_texturas_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"memoria_estatica_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1), "quadros": tempos.size()}


func _mediana(rs: Array) -> Dictionary:
	var m := {}
	for k in rs[0]:
		var vs: Array = rs.map(func(r): return r[k])
		vs.sort()
		m[k] = vs[vs.size() / 2]
	return m


func _escreve(nome: String, txt: String) -> void:
	var f := FileAccess.open("user://" + nome, FileAccess.WRITE)
	if f:
		f.store_string(txt)
		f.close()
