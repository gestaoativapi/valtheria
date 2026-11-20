extends SceneTree
# Estúdio de retrato (teste visual): personagens lado a lado, luz de estúdio, câmera no rosto.
# uso: godot --path . -s teste/estudio_rosto.gd -- --lista=beastman:leao:m,beastman:lobo:m --saida=/tmp/x.png [--ang=0] [--dist=0.75] [--corpo]
var quadros := 0
var saida := "/tmp/estudio.png"
var cam: Camera3D

func _init() -> void:
	var lista := "beastman:leao:m,beastman:lobo:m,beastman:tigre:f,beastman:onca:f,beastman:ursa:f"
	var ang := 0.0
	var dist := 0.8
	var corpo := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lista="): lista = a.trim_prefix("--lista=")
		elif a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
		elif a.begins_with("--ang="): ang = deg_to_rad(float(a.trim_prefix("--ang=")))
		elif a.begins_with("--dist="): dist = float(a.trim_prefix("--dist="))
		elif a == "--corpo": corpo = true; corpo_modo = true
		elif a == "--sopro": sopro = true
	var Character = load("res://scripts/character.gd")
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.2, 0.23)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(deg_to_rad(-35), deg_to_rad(30), 0)
	sol.light_energy = 1.25
	sol.shadow_enabled = true
	raiz.add_child(sol)
	var rec := DirectionalLight3D.new()
	rec.rotation = Vector3(deg_to_rad(-10), deg_to_rad(-140), 0)
	rec.light_energy = 0.45
	rec.light_color = Color(0.8, 0.85, 1.0)
	raiz.add_child(rec)
	var itens := lista.split(",")
	var passo := 0.5 if not corpo else 1.1
	var x0 := -passo * (itens.size() - 1) * 0.5
	var alt := 0.0
	for i in itens.size():
		var p := itens[i].split(":")
		var o := {"armadura_teste": p[4] if p.size() > 4 else "", "race": p[0], "gender": p[2] if p.size() > 2 else "m", "skin": 0, "hair": 1, "hair_color": 1, "equipment": {"armadura": p[4] if p.size() > 4 else "nenhuma", "arma": p[3] if p.size() > 3 else ""}}
		if p.size() > 1 and p[1] != "":
			o["subtipo"] = p[1]
		var c: Node3D = Character.create(o)
		raiz.add_child(c)
		c.position = Vector3(x0 + i * passo, 0, 0)
		c.rotation.y = ang
		if c.has_method("play"):
			c.play("Idle")
		if p.size() > 5 and p[5] != "":  # 6º campo: roupa de ofício (ferreiro, estalajadeiro...)
			c.oficio(p[5], p[4] == "nenhuma")
			if p[3] != "":
				c.set_battle(true)
		alt = maxf(alt, 1.0)
	cam = Camera3D.new()
	cam.fov = 30.0 if not corpo else 34.0
	raiz.add_child(cam)
	var largura := passo * itens.size()
	var y := 1.72 if not corpo else 1.0
	var d := maxf(dist, largura * 0.5 / tan(deg_to_rad(cam.fov * 0.5 * 1.6))) if not corpo else largura * 0.95 + 1.2
	cam.position = Vector3(0, y + 0.02, d)
	cam.look_at(Vector3(0, y, 0))

var y_ajustado := false
var corpo_modo := false

var sopro := false

func _process(_dt: float) -> bool:
	quadros += 1
	if sopro and quadros == 18:
		for c in root.find_children("*", "Node3D", true, false):
			if c.get("asas") != null:
				c.asas.sopro("fogo")
	if quadros == 22 and not corpo_modo:
		# mira a câmera na altura média das cabeças
		var soma := 0.0
		var n := 0
		for sk in root.find_children("*", "Skeleton3D", true, false):
			var b: int = (sk as Skeleton3D).find_bone("Head")
			if b >= 0:
				soma += ((sk as Skeleton3D).global_transform * (sk as Skeleton3D).get_bone_global_pose(b)).origin.y
				n += 1
		if n > 0:
			var y := soma / n - 0.09
			cam.position.y = y + 0.02
			cam.look_at(Vector3(0, y, 0))
			print("cabeças em y=", y, " cam=", cam.global_position)
	if quadros == 30:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(saida)
		quit()
	return false
