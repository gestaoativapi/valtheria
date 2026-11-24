extends Node3D
# Clareira de comparação com o protótipo Unity (só teste): o mesmo cenário dos dois lados.
# Chão de grama, trilha de terra, 90 árvores, 40 pedras e 260 plantas (Quaternius, CC0), o céu, a luz e a névoa
# do jogo, o jogador e 0/20/40 cavaleiros extras. Câmera fixa igual à do Unity.
# Uso: Valtheria.exe -- --clareira=C:/pasta/godot   -> grava godot.png (20 cavaleiros) e godot.json (FPS 0/20/40)
const Ch := preload("res://scripts/character.gd")
const ARVORES := ["n_commontree_1", "n_commontree_2", "n_commontree_3", "n_pine_1", "n_pine_2"]
const PEDRAS := ["n_rock_medium_1", "n_rock_medium_2", "n_rock_medium_3", "n_rock_large_1"]
const PLANTAS := ["n_bush_common", "n_bush_common_flowers", "n_fern_1", "n_flower_3_group", "n_plant_1_big"]
const FASES := [20, 0, 20, 40]  # a primeira é só a foto
var saida := ""
var extras: Array = []
var fase := 0
var t := 0.0
var tempos: PackedFloat32Array = []
var res := {}
var cam: Camera3D
var cenas := {}
var semente := 7


func _s() -> float:
	semente = (semente * 1103515245 + 12345) % 2147483648
	return float(semente) / 2147483648.0


func iniciar(caminho: String) -> void:
	saida = caminho


func _ready() -> void:
	var w: Node3D = load("res://scripts/world.gd").new()
	add_child(w)
	w._build_sky()
	# variações para achar o peso (variável CLAREIRA_MODO): ceu = céu atualizado aos poucos (não todo quadro);
	# sombra = 2 faixas de sombra até 100 m; leve = as duas
	var modo := OS.get_environment("CLAREIRA_MODO")
	if modo in ["ceu", "leve"]:
		w.env.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	if modo in ["sombra", "leve"]:
		w.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		w.sun.directional_shadow_max_distance = 100.0
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	chao.mesh = pm
	chao.material_override = _mat("res://assets/world/t_grass.webp", Vector3(70, 70, 1))
	add_child(chao)
	var tr := MeshInstance3D.new()
	var pt := PlaneMesh.new()
	pt.size = Vector2(16, 45)
	tr.mesh = pt
	tr.position = Vector3(0, 0.01, -10)
	tr.material_override = _mat("res://assets/world/t_dirt.webp", Vector3(8, 8, 1))
	add_child(tr)
	# sorteio igual ao do Unity (mesma sequência): plantas, pedras e árvores no mesmo lugar nas duas cenas
	semente = 7
	for i in 90:
		var p := Vector3(_s() * 180 - 90, 0, _s() * 180 - 90)
		var k := int(_s() * ARVORES.size())
		var g := _s() * TAU
		var e := 0.9 + _s() * 0.5
		if p.length() >= 12:
			_por(ARVORES[k], p, g, e, true)
	for i in 40:
		var p := Vector3(_s() * 160 - 80, 0, _s() * 160 - 80)
		var k := int(_s() * PEDRAS.size())
		var g := _s() * TAU
		var e := 0.6 + _s()
		_por(PEDRAS[k], p, g, e, true)
	for i in 260:
		var p := Vector3(_s() * 70 - 35, 0, _s() * 70 - 35)
		var k := int(_s() * PLANTAS.size())
		var g := _s() * TAU
		var e := 0.7 + _s() * 0.6
		if p.length() >= 3:
			_por(PLANTAS[k], p, g, e, false)
	# mesmo personagem do protótipo Unity: o cavaleiro antigo (corpo + armadura de cavaleiro, Quaternius)
	Ch.V3_HUMANOS = OS.get_environment("CLAREIRA_V3") == "1"
	_vila()
	var jog = Ch.create({"race": "humano", "gender": "m", "equipment": {"armadura": "pesada_ng", "arma": "espada_ng"}})
	add_child(jog)
	cam = Camera3D.new()
	cam.far = 250.0
	cam.fov = 60.0  # mesmo campo de visão da câmera do Unity
	add_child(cam)
	cam.position = Vector3(-5.5, 4.2, 7.5)
	cam.look_at(Vector3(1.5, 1.0, -9.0), Vector3.UP)
	cam.current = true
	_extras(FASES[0])


func _mat(tex: String, escala: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(tex)
	m.uv1_scale = escala
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _por(nome: String, p: Vector3, giro: float, esc: float, sombra: bool) -> void:
	if not cenas.has(nome):
		cenas[nome] = load("res://assets/world/" + nome + ".glb")
	var n: Node3D = cenas[nome].instantiate()
	n.position = Vector3(-p.x, p.y, p.z)  # o Unity usa eixo X invertido: espelha para as duas fotos baterem
	n.rotation.y = giro
	n.scale = Vector3.ONE * esc
	add_child(n)
	if not sombra:
		for m in n.find_children("*", "GeometryInstance3D", true, false):
			(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _extras(n: int) -> void:
	for e in extras:
		e.queue_free()
	extras.clear()
	for i in n:
		var c = Ch.create({"race": "humano", "gender": "m", "equipment": {"armadura": "pesada_ng", "arma": "espada_ng"}})
		add_child(c)
		c.position = Vector3(-((i % 8) * 3.0 - 10.5), 0, -6.0 - (i / 8) * 3.0)
		c.play("Walk" if i % 2 == 0 else "Sword_Idle")
		extras.append(c)


func _process(dt: float) -> void:
	t += dt
	if fase == 0:
		if t >= 8.0:
			get_viewport().get_texture().get_image().save_png(saida + ".png")
			_trocar()
		return
	if t > 3.0:
		tempos.append(dt * 1000.0)
	if t < 18.0:
		return
	var l := Array(tempos)
	l.sort()
	var soma := 0.0
	for v in l:
		soma += v
	var k: int = maxi(1, l.size() / 100)
	var pior := 0.0
	for i in range(l.size() - k, l.size()):
		pior += l[i]
	res["extras_%d" % FASES[fase]] = {"fps_medio": snappedf(1000.0 * l.size() / maxf(soma, 0.001), 0.1),
		"fps_1pct_baixo": snappedf(1000.0 * k / maxf(pior, 0.001), 0.1), "quadros": l.size()}
	_trocar()


func _trocar() -> void:
	fase += 1
	t = 0.0
	tempos = PackedFloat32Array()
	if fase >= FASES.size():
		res["placa_de_video"] = RenderingServer.get_video_adapter_name()
		res["renderizador"] = RenderingServer.get_current_rendering_method() + " / " + RenderingServer.get_current_rendering_driver_name()
		res["janela"] = str(get_viewport().get_visible_rect().size)
		var f := FileAccess.open(saida + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify(res, "  "))
		f.close()
		get_tree().quit()
		return
	_extras(FASES[fase])


# a mesma vila do protótipo Unity (mesmos modelos, tamanhos e lugares; X espelhado como o resto)
func _vila() -> void:
	var L := [["b_inn", -16, -34, 10.5, 20], ["b_house_1", 14, -36, 7.5, -25], ["b_blacksmith", -22, -18, 6.8, 75],
		["b_stable", 22, -20, 6.2, -80], ["b_mill", 30, -48, 9.0, -40], ["b_house_1", -6, -50, 7.5, 5],
		["b_well", 3, -24, 2.6, 0], ["b_bonfire_lit", -4, -16, 1.5, 0], ["b_marketstand_1", 9, -14, 3.1, -60],
		["b_marketstand_1", -12, -10, 3.1, 50], ["b_cart", 12, -26, 2.4, 30], ["b_hay", 15, -24, 1.2, 10],
		["b_hay", 16.2, -25.5, 1.2, 70], ["b_barrel", -9, -13, 0.9, 0], ["b_barrel", -9.8, -12.2, 0.9, 40],
		["b_crate", -10.5, -14.2, 0.7, 15], ["b_bags", 8, -12.5, 0.6, 0], ["b_bench_1", -1, -19, 1.6, 90],
		["b_bench_1", 6, -20, 1.6, -90], ["n_light_street_1", -3, -8, 4.2, 0], ["n_light_street_1", 5, -30, 4.2, 0],
		["d_torch", -14, -24, 2.2, 0], ["q_birchtree_1", 26, -8, 9.0, 0], ["q_willow_1", -28, -40, 8.0, 30],
		["n_twistedtree_1", 36, -30, 10.0, 0], ["n_tree_light_1", -32, -6, 8.0, 0], ["q_treestump_moss", 18, -6, 1.0, 0],
		["q_woodlog_moss", -20, -4, 2.5, 60], ["q_bushberries_1", 10, -6, 1.3, 0], ["n_mushroom_common", -16, -6, 0.5, 0],
		["n_flower_4_group", 4, -6, 0.7, 0], ["a_deer", 30, -2, 1.7, -120], ["a_horse", 24, -14, 2.4, -95]]
	for e in L:
		var caminho: String = "res://assets/world/" + e[0] + ".glb"
		if not ResourceLoader.exists(caminho):
			continue
		var n: Node3D = load(caminho).instantiate()
		add_child(n)
		var bb := AABB()
		var primeiro := true
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var a: AABB = mi.global_transform * mi.get_aabb()
			bb = a if primeiro else bb.merge(a)
			primeiro = false
		var maior := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
		if maior > 0.001:
			n.scale = Vector3.ONE * float(e[3]) / maior
		n.position = Vector3(-float(e[1]), 0, float(e[2]))
		n.rotation.y = -deg_to_rad(float(e[4]))
