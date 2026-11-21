extends SceneTree
# Estúdio dos gestos mágicos: cada personagem no auge de um gesto. uso: -s teste/estudio_gestos.gd -- --saida=x.png [--lista=raca:g:gesto,...]
var q := 0
var saida := "/tmp/gestos.png"
var bonecos: Array = []
var lista := "humano:m:empurrar,humano:f:empurrar,humano:m:erguer,humano:f:erguer,orc:m:abrir,elfo:f:abrir,humano:m:prece,anao:m:cravar,beastman:m:rugir,sombrio:f:apontar"

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
		elif a.begins_with("--lista="): lista = a.trim_prefix("--lista=")


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
		var c: Node3D = C.create({"race": p[0], "gender": p[1], "equipment": {"armadura": "leve_ng"}})
		raiz.add_child(c)
		c.position = Vector3((i - (itens.size() - 1) * 0.5) * 1.0, 0, 0)
		c.rotation.y = deg_to_rad(25)
		c.set_meta("gesto", p[2])
		bonecos.append(c)
	var cam := Camera3D.new()
	raiz.add_child(cam)
	cam.fov = 30.0
	cam.position = Vector3(0, 1.1, 6.6)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.current = true


func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		_montar()
	if q == 12:
		for c in bonecos:
			c.action("Spell_Simple_Shoot")
			c.tocar_gesto(str(c.get_meta("gesto")), 1.6)
	if q == 12 + 26:
		root.get_viewport().get_texture().get_image().save_png(saida)
		quit()
	return false
