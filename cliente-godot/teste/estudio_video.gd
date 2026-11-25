extends SceneTree
# Estúdio de vídeo das opções de pegada (pedido de Robson 24/11 13:06): personagens lado a lado, cada um com um
# estilo, num roteiro parado > andando > correndo > entra em combate > corre em combate > volta ao normal.
# uso: --fixed-fps 30 -s teste/estudio_video.gd -- --lista=raca:g:arma:roupa:escudo:estilo,... --saida=/tmp/pasta [--lado]
var q := 0
var saida := "/tmp/video"
var lado := false
var bonecos: Array = []
var lista := "humano:m:espada_ng:pesada_ng:escudo_ng:A"
var passo := 2  # grava 1 quadro a cada 2 (15 por segundo)
# roteiro em quadros (30 por segundo)
const ROTEIRO := [[0, "Idle", false], [45, "Walk", false], [105, "Jog_Fwd", false], [150, "Idle", true], [195, "Jog_Fwd", true], [240, "Idle", true], [255, "!Sword_Regular_A", true], [300, "!Sword_Regular_B", true], [345, "Walk", false], [390, "Idle", false]]
const FIM := 420


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
		elif a.begins_with("--lista="): lista = a.trim_prefix("--lista=")
		elif a == "--lado": lado = true
	DirAccess.make_dir_recursive_absolute(saida)


func _montar() -> void:
	var C = load("res://scripts/character.gd")
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
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	chao.mesh = pm
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.24, 0.26, 0.28)
	chao.material_override = mc
	raiz.add_child(chao)
	var itens := lista.split(",")
	for i in itens.size():
		var p := itens[i].split(":")
		var eq := {"armadura": p[3] if p.size() > 3 else "leve_ng"}
		if p.size() > 2 and p[2] != "":
			eq["arma"] = p[2]
		if p.size() > 4 and p[4] != "":
			eq["escudo"] = p[4]
		C.estilo_pegada = p[5] if p.size() > 5 else "A"
		var c: Node3D = C.create({"race": p[0], "gender": p[1], "equipment": eq})
		raiz.add_child(c)
		c.set_battle(false)
		bonecos.append(c)
		c.position = Vector3((i - (itens.size() - 1) * 0.5) * 1.25, 0, 0)
		c.rotation.y = deg_to_rad(90 if lado else 20)
	C.estilo_pegada = "A"
	var cam := Camera3D.new()
	raiz.add_child(cam)
	cam.fov = 30.0
	# --longe=k: câmera k vezes mais afastada e mais alta (gigantes cabem no quadro)
	var longe := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--longe="): longe = float(a.trim_prefix("--longe="))
	cam.position = Vector3(0, 1.2 * longe, (2.6 + itens.size() * 1.25) * longe)
	cam.look_at(Vector3(0, 0.95 * longe, 0))
	cam.current = true


func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		_montar()
		return false
	var f := q - 2
	for r in ROTEIRO:
		if f == int(r[0]):
			for c in bonecos:
				c.set_battle(bool(r[2]))
				c.em_guarda = bool(r[2])
				if str(r[1]).begins_with("!"):
					c.action(str(r[1]).substr(1))
				else:
					c.play(str(r[1]))
	if f >= 0 and f % passo == 0:
		root.get_viewport().get_texture().get_image().save_jpg("%s/q%04d.jpg" % [saida, f / passo], 0.9)
	if f >= FIM:
		quit()
	return false
