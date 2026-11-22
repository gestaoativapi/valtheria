extends SceneTree
# Estúdio do arqueiro: a mesma raça vista de 4 lados (alvo à frente dela), congelada num instante do tiro.
# uso: -s teste/estudio_arco.gd -- --raca=humano:m --t=0.61 --saida=x.png   (t: 0,22 ergue · 0,6 âncora · 0,62 solta; -1 = prontidão; -2 = parado sem combate)
var q := 0
var saida := "/tmp/arco.png"
var raca := "humano:m"
var t_fix := 0.61
var bonecos: Array = []

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
		elif a.begins_with("--raca="): raca = a.trim_prefix("--raca=")
		elif a.begins_with("--t="): t_fix = float(a.trim_prefix("--t="))


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
	var p := raca.split(":")
	var angs := [90, 0, -90, 180]  # de lado (alvo à direita), de frente, do outro lado, de costas
	for i in 4:
		var c: Node3D = C.create({"race": p[0], "gender": p[1], "equipment": {"arma": "arco_ng", "armadura": "leve_ng"}})
		raiz.add_child(c)
		c.position = Vector3((i - 1.5) * 1.6, 0, 0)
		c.rotation.y = deg_to_rad(angs[i])
		bonecos.append(c)
	var cam := Camera3D.new()
	raiz.add_child(cam)
	cam.fov = 32.0
	cam.position = Vector3(0, 1.2, 7.0)
	cam.look_at(Vector3(0, 1.1, 0))
	cam.current = true


func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		_montar()
	if q == 8:
		for c in bonecos:
			c.set_battle(t_fix > -2.0)
			if t_fix >= 0.0:
				c.disparar_arco()
	if q >= 8 and OS.get_environment("ANDAR") == "1":
		for c in bonecos:
			c.play("Walk")
	if q > 8 and t_fix >= 0.0:
		for c in bonecos:
			if c.arqueria != null:
				c.arqueria.t = t_fix
	if q == 29 and OS.get_environment("MARCA") == "1":
		for c in bonecos:
			for nm in ["Head", "neck_01", "upperarm_l"]:
				var bi: int = c.skel.find_bone(nm)
				var m := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.03
				sm.height = 0.06
				m.mesh = sm
				m.material_override = StandardMaterial3D.new()
				m.material_override.albedo_color = Color.RED if nm == "Head" else Color.YELLOW
				m.material_override.no_depth_test = true
				m.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				root.add_child(m)
				m.global_position = c.skel.global_transform * c.skel.get_bone_global_pose(bi).origin
	if q == 30:
		root.get_viewport().get_texture().get_image().save_png(saida)
		quit()
	return false
