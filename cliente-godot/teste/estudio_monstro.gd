extends SceneTree
# Estúdio de criaturas: põe lado a lado os modelos pedidos, toca a animação e fotografa.
# uso: godot -s teste/estudio_monstro.gd -- --lista=stone_golem,yeti --anim=walk --t=0.3 --saida=x.png
var frame := 0
var saida := "/tmp/monstro.png"
var t := 0.3
var players: Array = []

func _init() -> void:
	pass

func _setup() -> void:
	var lista := "stone_golem"
	var anim := "walk"
	var ang := 0.5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lista="): lista = a.substr(8)
		if a.begins_with("--anim="): anim = a.substr(7)
		if a.begins_with("--t="): t = float(a.substr(4))
		if a.begins_with("--saida="): saida = a.substr(8)
		if a.begins_with("--ang="): ang = float(a.substr(6))
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.17, 0.19, 0.23)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.75)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.5, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	root.add_child(sun)
	var nomes := lista.split(",")
	var x := 0.0
	var alt := 0.0
	for i in nomes.size():
		var cena: PackedScene = load("res://assets/monstros/%s.glb" % nomes[i])
		var n: Node3D = cena.instantiate()
		root.add_child(n)
		var aabb := _caixa(n)
		var s := 2.4 / maxf(aabb.size.y, 0.01)
		n.scale = Vector3.ONE * s
		n.position = Vector3(x, -aabb.position.y * s, 0)
		print("MONSTRO ", nomes[i], " altura original ", aabb.size.y, " largura ", aabb.size.x)
		x += 3.2
		alt = maxf(alt, 2.4)
		for ap in n.find_children("*", "AnimationPlayer", true, false):
			print("  anims ", (ap as AnimationPlayer).get_animation_list())
			if (ap as AnimationPlayer).has_animation(anim):
				players.append(ap)
				(ap as AnimationPlayer).play(anim)
	var cam := Camera3D.new()
	root.add_child(cam)
	var cx := (x - 3.2) * 0.5
	var d := 3.5 + nomes.size() * 1.9
	cam.transform = Transform3D(Basis.IDENTITY, Vector3(cx + sin(ang) * d, 1.6, cos(ang) * d)).looking_at(Vector3(cx, 1.15, 0))
	cam.fov = 40.0

func _caixa(n: Node3D) -> AABB:
	# altura pelos ossos já posicionados (a caixa da malha com pele ignora a escala do esqueleto)
	var a := AABB()
	var primeiro := true
	for sk in n.find_children("*", "Skeleton3D", true, false):
		var k := sk as Skeleton3D
		for b in k.get_bone_count():
			var p := k.global_transform * k.get_bone_global_pose(b).origin
			var bb := AABB(p, Vector3.ZERO)
			a = bb if primeiro else a.merge(bb)
			primeiro = false
	a = a.grow(a.size.y * 0.06)
	return a

func _process(_d: float) -> bool:
	frame += 1
	if frame == 1:
		_setup()
	if frame == 4:
		for ap in players:
			(ap as AnimationPlayer).seek(t * (ap as AnimationPlayer).current_animation_length, true)
			(ap as AnimationPlayer).pause()
	if frame == 12:
		get_root().get_texture().get_image().save_png(saida)
		return true
	return false
