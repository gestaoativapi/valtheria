extends SceneTree
# Vídeo antes/agora da passada: o mesmo corpo andando e correndo de verdade sobre um chão quadriculado.
# Em cada par, a fila de trás é como era (pé patinando) e a da frente é a passada sincronizada.
# uso: --fixed-fps 30 -s teste/estudio_passada.gd -- --saida=/tmp/vp [--lista=humano:m,anao:m,gigante:m]

var saida := "/tmp/vp"
var lista := "humano:m,anao:m,gigante:m"
var bonecos: Array = []
var cam: Camera3D
var q := 0
var x := 0.0
const FASES := [["andar", 1.5, 150], ["correr", 5.2, 150]]


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
		elif a.begins_with("--lista="): lista = a.trim_prefix("--lista=")
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
	sol.rotation = Vector3(deg_to_rad(-50), deg_to_rad(20), 0)
	raiz.add_child(sol)
	# chão quadriculado (meio metro) para ver o pé parado ou patinando
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for i in 64:
		for j in 64:
			img.set_pixel(i, j, Color(0.36, 0.37, 0.38) if (i / 32 + j / 32) % 2 == 0 else Color(0.22, 0.23, 0.25))
	var mc := StandardMaterial3D.new()
	mc.albedo_texture = ImageTexture.create_from_image(img)
	mc.uv1_scale = Vector3(400, 30, 1)
	mc.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 30)
	chao.mesh = pm
	chao.material_override = mc
	chao.position = Vector3(190, 0, 0)
	raiz.add_child(chao)
	var itens := lista.split(",")
	var z := 0.0
	for i in itens.size():
		var p := itens[i].split(":")
		for modo in ["agora", "antes"]:
			var c: Node3D = C.create({"race": p[0], "gender": p[1], "equipment": {"armadura": "leve_ng"}})
			raiz.add_child(c)
			c.rotation.y = PI * 0.5  # olha para +X
			c.position = Vector3(0, 0, z)
			var tag := Label3D.new()
			tag.text = ("ANTES" if modo == "antes" else "AGORA") + "  " + p[0]
			tag.font_size = 40
			tag.modulate = Color(1, 0.6, 0.5) if modo == "antes" else Color(0.6, 1, 0.7)
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			raiz.add_child(tag)
			bonecos.append({"c": c, "modo": modo, "tag": tag, "z": z})
			z -= 0.0
	cam = Camera3D.new()
	raiz.add_child(cam)
	cam.fov = 40.0
	cam.current = true


func _process(dt: float) -> bool:
	q += 1
	if q == 1:
		_montar()
		return false
	var k := q - 2
	var fi := 0
	var acc := 0
	while fi < FASES.size() and k >= acc + int(FASES[fi][2]):
		acc += int(FASES[fi][2])
		fi += 1
	if fi >= FASES.size():
		quit()
		return true
	var fase: Array = FASES[fi]
	var v: float = fase[1]
	x += v * dt
	for bo in bonecos:
		var c: Node3D = bo.c
		if bo.modo == "antes":  # como era antes de 26/11
			if fase[0] == "andar":
				c.play("Walk", 1.1)
			else:
				c.play("Jog_Fwd", v / 5.2)
		else:
			c.mover(v, "andar" if fase[0] == "andar" else "correr")
		var alt0 := float(bonecos[0].c.altura_quadril()) / 0.77
		var dx := (-1.3 if bo.modo == "agora" else 1.3) * alt0
		c.position.x = x + dx
		(bo.tag as Label3D).position = Vector3(x + dx, 2.15 * alt0, 0.0)
	var zc := float(bonecos[-1].z) * 0.5
	var alt := float(bonecos[0].c.altura_quadril()) / 0.77
	cam.position = Vector3(x, 2.4 * alt, 6.0 * alt)
	cam.look_at(Vector3(x, 0.8 * alt, 0.0))
	root.get_viewport().get_texture().get_image().save_jpg("%s/q%04d.jpg" % [saida, k], 0.88)
	return false
