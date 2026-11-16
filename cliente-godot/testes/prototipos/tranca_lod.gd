extends Node3D
# Valtheria V3 — AUT-021 D63: troca experimental da trança completa para a LOD a 12 m (não faz parte do jogo;
# character.gd não é alterado). Mecanismo: GeometryInstance3D.visibility_range nas duas malhas de cabelo, sem fade,
# com margem de 1 m como histerese (completa: fim 12 m; LOD: início 12 m).
# Mede, quadro a quadro, triângulos visíveis e de sombra e chamadas de desenho, e deduz qual malha foi desenhada.
# Uso: godot --path . --rendering-driver opengl3 res://testes/prototipos/tranca_lod.tscn -- --saida=<pasta>
const V3 := "res://assets_v3/personagens/"
const TROCA := 12.0
const MARGEM := 1.0
var saida := "user://tranca"
var completa: MeshInstance3D
var lod: MeshInstance3D
var corpo: Node3D
var cam: Camera3D
var tri_completa := 0
var tri_lod := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): saida = a.substr(8)
	DirAccess.make_dir_recursive_absolute(saida)
	var sol := DirectionalLight3D.new(); sol.rotation_degrees = Vector3(-50, -35, 0); sol.shadow_enabled = true; add_child(sol)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.46, 0.5, 0.55); add_child(env)
	var chao := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(80, 80); chao.mesh = pm; add_child(chao)
	montar()
	cam = Camera3D.new(); cam.fov = 40; add_child(cam); cam.current = true
	await _medir()
	get_tree().quit()

func montar() -> void:
	corpo = (load(V3 + "pc_humano_f.glb") as PackedScene).instantiate(); add_child(corpo)
	var skel := corpo.find_child("Skeleton3D", true, false) as Skeleton3D
	for p in ["rp_aldeao_tunica_f", "rp_aldeao_calca_f", "rp_botas_couro_f", "ca_tranca_longa", "ca_tranca_longa_lod1"]:
		var src: Node3D = (load(V3 + p + ".glb") as PackedScene).instantiate()
		for m in src.find_children("*", "MeshInstance3D", true, false):
			m.get_parent().remove_child(m); m.owner = null; skel.add_child(m)
			(m as MeshInstance3D).skeleton = NodePath(".."); m.name = p
			if p == "ca_tranca_longa": completa = m
			if p == "ca_tranca_longa_lod1": lod = m
		src.free()
	tri_completa = _tri(completa.mesh); tri_lod = _tri(lod.mesh)
	# a troca: só uma das duas é desenhada; a margem segura o estado perto dos 12 m (histerese, sem fade)
	completa.visibility_range_end = TROCA; completa.visibility_range_end_margin = MARGEM
	lod.visibility_range_begin = TROCA; lod.visibility_range_begin_margin = MARGEM
	completa.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	lod.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

func _tri(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		var idx: PackedInt32Array = m.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		n += idx.size() / 3
	return n

func _quadro(dist: float) -> Dictionary:
	cam.look_at_from_position(Vector3(0, 1.5, dist), Vector3(0, 1.0, 0))
	await get_tree().process_frame; await get_tree().process_frame
	var vp := get_viewport()
	return {"d": snappedf(dist, 0.01),
		"tri": vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"tri_sombra": vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"draw": vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"draw_sombra": vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)}

# referência: a mesma cena só com uma malha de cabelo (para saber quantos triângulos cada uma soma)
func _base(dist: float, mostrar_completa: bool, mostrar_lod: bool) -> Dictionary:
	var vc := [completa.visibility_range_end, lod.visibility_range_begin]
	completa.visibility_range_end = 0.0; lod.visibility_range_begin = 0.0
	completa.visible = mostrar_completa; lod.visible = mostrar_lod
	var q := await _quadro(dist)
	completa.visibility_range_end = vc[0]; lod.visibility_range_begin = vc[1]; completa.visible = true; lod.visible = true
	return q

func _qual(q: Dictionary, nenhum: Dictionary) -> String:
	var extra: int = int(q["tri"]) - int(nenhum["tri"])
	if absi(extra - tri_completa) <= 4: return "completa"
	if absi(extra - tri_lod) <= 4: return "lod"
	if absi(extra - tri_completa - tri_lod) <= 4: return "AMBAS"
	if absi(extra) <= 4: return "nenhuma"
	return "?%d" % extra

func _medir() -> void:
	var r := {"troca_m": TROCA, "margem_m": MARGEM, "tri_completa": tri_completa, "tri_lod": tri_lod, "trajetos": {}, "distancias": []}
	# referências sem cabelo, por distância (o resto da cena muda de tamanho na tela mas não de triângulos)
	var sem := {}
	for d in [5.0, 15.0, 30.0]:
		var nen := await _base(d, false, false)
		var q := await _quadro(d)
		var so_c := await _base(d, true, false)
		var so_l := await _base(d, false, true)
		r["distancias"].append({"d": d, "malha": _qual(q, nen), "tri_total": q["tri"], "tri_sombra": q["tri_sombra"], "draw": q["draw"], "draw_sombra": q["draw_sombra"],
			"tri_se_completa": so_c["tri"], "tri_sombra_se_completa": so_c["tri_sombra"], "tri_se_lod": so_l["tri"], "tri_sombra_se_lod": so_l["tri_sombra"]})
		sem[d] = nen
	# nos trajetos o LOD automático de malha do Godot fica desligado, para a contagem de triângulos dizer qual trança foi desenhada
	get_viewport().mesh_lod_threshold = 0.0
	var nen0: Dictionary = await _base(15.0, false, false)
	r["detecao"] = "triângulos do quadro menos a cena sem cabelo (LOD automático de malha desligado nos trajetos)"
	# trajetos: aproximando (30 -> 5), afastando (5 -> 30), parado em 12 m e oscilando 11,5 <-> 12,5
	var trajetos := {"aproximando": [], "afastando": [], "parado_12m": [], "oscilando_11_5_12_5": []}
	var d := 30.0
	while d >= 5.0: trajetos["aproximando"].append(d); d -= 0.25
	d = 5.0
	while d <= 30.0: trajetos["afastando"].append(d); d += 0.25
	for i in 120: trajetos["parado_12m"].append(12.0)
	for i in 60: trajetos["oscilando_11_5_12_5"].append(11.5 if i % 2 == 0 else 12.5)
	for nome in ["aproximando", "afastando", "parado_12m", "oscilando_11_5_12_5"]:
		var trocas := []; var ambas := 0; var anterior := ""; var sombra_ambas := 0
		for dd in trajetos[nome]:
			var q := await _quadro(dd)
			var m := _qual(q, nen0)
			if m == "AMBAS": ambas += 1
			# na sombra: a soma de triângulos de sombra também não pode ter as duas malhas
			if int(q["tri_sombra"]) - int(nen0["tri_sombra"]) > tri_completa + tri_lod - 4: sombra_ambas += 1
			if anterior != "" and m != anterior: trocas.append({"em_m": dd, "de": anterior, "para": m})
			anterior = m
		r["trajetos"][nome] = {"quadros": trajetos[nome].size(), "trocas": trocas, "quadros_com_as_duas": ambas, "quadros_sombra_com_as_duas": sombra_ambas, "final": anterior}
		print("TRANCA ", nome, " ", r["trajetos"][nome])
	get_viewport().mesh_lod_threshold = 1.0
	# capturas na distância de troca (antes e depois) e a 5/15/30 m
	for dd in [5.0, 11.0, 13.0, 15.0, 30.0]:
		await _quadro(dd)
		get_viewport().get_texture().get_image().save_png(saida + "/tranca_lod_%04.1fm.png" % dd)
	var f := FileAccess.open(saida + "/tranca_lod.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(r, " "))
