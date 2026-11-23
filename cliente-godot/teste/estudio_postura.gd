extends SceneTree
# Estúdio da postura parada: personagens lado a lado, de frente ou de lado.
# uso: -s teste/estudio_postura.gd -- --saida=x.png [--lista=raca:g:arma:roupa,...] [--lado] [--quadros=N]
var q := 0
var saida := "/tmp/postura.png"
var lado := false
var quadros := 40
var combate := false
var perto := false
var tiro := 0
var anim := ""  # --anim=NOME: toca a animação em todos (play; nomes de golpe/reação com --acao)
var acao := false
var guarda := false
var bonecos: Array = []
var lista := "humano:m:espada_ng:pesada_ng,humano:f:espada_ng:pesada_ng,elfo:m:cajado_ng:robe_ng,elfo:f:cajado_ng:robe_ng,orc:m:machado_ng:pesada_ng,sombrio:f:adaga_ng:leve_ng,anao:m:martelo_ng:pesada_ng,humano:f:arco_ng:leve_ng"

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
		elif a.begins_with("--lista="): lista = a.trim_prefix("--lista=")
		elif a == "--lado": lado = true
		elif a == "--combate": combate = true
		elif a == "--perto": perto = true
		elif a.begins_with("--tiro="): tiro = int(a.trim_prefix("--tiro="))
		elif a.begins_with("--quadros="): quadros = int(a.trim_prefix("--quadros="))
		elif a.begins_with("--anim="): anim = a.trim_prefix("--anim=")
		elif a == "--acao": acao = true
		elif a == "--guarda": guarda = true


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
	var itens := lista.split(",")
	for i in itens.size():
		var p := itens[i].split(":")
		var eq := {"armadura": p[3] if p.size() > 3 else "leve_ng"}
		if p.size() > 2 and p[2] != "":
			eq["arma"] = p[2]
		var c: Node3D = C.create({"race": p[0], "gender": p[1], "equipment": eq})
		raiz.add_child(c)
		if not combate:
			c.set_battle(false)
		bonecos.append(c)
		c.position = Vector3((i - (itens.size() - 1) * 0.5) * 1.05, 0, 0)
		c.rotation.y = deg_to_rad(90 if lado else 12)
	var cam := Camera3D.new()
	raiz.add_child(cam)
	cam.fov = 30.0
	cam.position = Vector3(0, 1.05, 2.0 + itens.size() * 0.95)
	cam.look_at(Vector3(0, 0.95, 0))
	if perto:  # rostos
		cam.position = Vector3(0, 1.62, 1.2 + itens.size() * 0.42)
		cam.look_at(Vector3(0, 1.55, 0))
	cam.current = true


func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		_montar()
	if tiro > 0 and q == tiro:
		for c in bonecos:
			c.set_battle(true)
			c.disparar_arco()
	if anim != "" and q >= 2:
		var ini := quadros - int(OS.get_environment("ACAO_QUADROS") if OS.get_environment("ACAO_QUADROS") != "" else "18") if acao else 2
		for c in bonecos:
			c.em_guarda = guarda
			if acao and q == ini:
				c.action(anim)
			elif not acao:
				c.play(anim)
	if q == quadros:
		root.get_viewport().get_texture().get_image().save_png(saida)
		quit()
	return false
