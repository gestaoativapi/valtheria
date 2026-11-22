extends SceneTree
# Estúdio de monstros humanoides: monta pelo mesmo caminho do jogo (combat._mob_model), lado a lado, de frente.
# uso: -s teste/estudio_mobs.gd -- --lista=bandido,esqueleto --saida=x.png [--perto] [--combate]
var q := 0
var saida := "/tmp/mobs.png"
var lista := "bandido,esqueleto,demonio,caido,espectro,senhor_dem"
var perto := false
var combate := false
var bonecos: Array = []


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
		elif a.begins_with("--lista="): lista = a.trim_prefix("--lista=")
		elif a == "--perto": perto = true
		elif a == "--combate": combate = true


func _fam(id: String) -> Dictionary:
	var w: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	for band in w.mobs:
		for f in band:
			if str(f.id) == id:
				return f
	return {}


func _montar() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.17, 0.19, 0.23)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.7)
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(deg_to_rad(-35), deg_to_rad(30), 0)
	raiz.add_child(sol)
	var cb = load("res://scripts/combat.gd").new()
	var ids := lista.split(",")
	var passo := 2.2
	for i in ids.size():
		var md: Dictionary = cb._mob_model(_fam(ids[i]))
		var n: Node3D = md.node
		raiz.add_child(n)
		n.position = Vector3((i - (ids.size() - 1) * 0.5) * passo, 0, 0)
		n.rotation.y = deg_to_rad(10)
		if n.has_method("set_battle"):
			n.set_battle(combate)
		bonecos.append(n)
	var cam := Camera3D.new()
	raiz.add_child(cam)
	cam.fov = 30.0
	var largura := ids.size() * passo
	if perto:
		cam.position = Vector3(0, 2.0, 1.0 + largura * 0.95)
		cam.look_at(Vector3(0, 1.85, 0))
	else:
		cam.position = Vector3(0, 1.4, 2.5 + largura * 1.6)
		cam.look_at(Vector3(0, 1.2, 0))
	cam.current = true


func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		_montar()
	if q == 40:
		root.get_viewport().get_texture().get_image().save_png(saida)
		quit()
	return false
