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
var foco := ""  # --foco=x,y,z,dist: câmera de perto num ponto (ex.: a mão)
var giro_cam := 0.0
var bonecos: Array = []
var lista := "humano:m:espada_ng:pesada_ng,humano:f:espada_ng:pesada_ng,elfo:m:cajado_ng:robe_ng,elfo:f:cajado_ng:robe_ng,orc:m:machado_ng:pesada_ng,sombrio:f:adaga_ng:leve_ng,anao:m:martelo_ng:pesada_ng,humano:f:arco_ng:leve_ng"

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
		elif a.begins_with("--lista="): lista = a.trim_prefix("--lista=")
		elif a == "--lado": lado = true
		elif a == "--sem-q":
			load("res://scripts/character.gd").BASE_Q = false
		elif a == "--com-q":
			load("res://scripts/character.gd").BASE_Q = true
		elif a == "--sem-proprios" or a == "--antigos":
			var CH = load("res://scripts/character.gd")
			CH.corpos_proprios = false
			CH.orc_modelo_proprio = false
			if a == "--antigos": CH.V3_HUMANOS = false
		elif a == "--combate": combate = true
		elif a == "--perto": perto = true
		elif a.begins_with("--tiro="): tiro = int(a.trim_prefix("--tiro="))
		elif a.begins_with("--quadros="): quadros = int(a.trim_prefix("--quadros="))
		elif a.begins_with("--anim="): anim = a.trim_prefix("--anim=")
		elif a == "--acao": acao = true
		elif a == "--guarda": guarda = true
		elif a.begins_with("--foco="): foco = a.trim_prefix("--foco=")
		elif a.begins_with("--giro="): giro_cam = float(a.trim_prefix("--giro="))


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
		if p.size() > 4 and p[4] != "":
			eq["escudo"] = p[4]
		var o := {"race": p[0], "gender": p[1], "equipment": eq}
		if p.size() > 5 and p[5] != "" and eq.has("arma"):  # 6º campo: nível de encanto da arma
			o["enchant"] = {eq["arma"]: int(p[5])}
		var c: Node3D = C.create(o)
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
	if foco != "":
		var f := foco.split(",")
		var alvo := Vector3(float(f[0]), float(f[1]), float(f[2]))
		var d := float(f[3])
		cam.position = alvo + Vector3(sin(deg_to_rad(giro_cam)), 0.15, cos(deg_to_rad(giro_cam))) * d
		cam.look_at(alvo)
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
