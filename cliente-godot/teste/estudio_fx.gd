extends SceneTree
# Estúdio de efeitos de habilidade: um personagem e um alvo; dispara um efeito e fotografa no quadro pedido.
# uso: godot --path . --fixed-fps 30 -s teste/estudio_fx.gd -- --fx=magia:fogo --quadro=8 --saida=/tmp/x.png
#   --fx: corte | corte2 | magia:<elem> | circulo:<elem> | coluna | zona:<elem> | relampago | flecha | impacto
var quadros := 0
var saida := "/tmp/fx.png"
var fx := "corte"
var quadro := 8
var cam: Camera3D
var heroi: Node3D
var alvo: Node3D
var FX = load("res://scripts/fx.gd")
var raiz: Node3D


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fx="): fx = a.trim_prefix("--fx=")
		elif a.begins_with("--quadro="): quadro = int(a.trim_prefix("--quadro="))
		elif a.begins_with("--saida="): saida = a.trim_prefix("--saida=")


func _montar() -> void:
	var Character = load("res://scripts/character.gd")
	raiz = Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.48, 0.58)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(deg_to_rad(-40), deg_to_rad(35), 0)
	sol.light_energy = 0.9
	raiz.add_child(sol)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.22, 0.24, 0.2)
	pm.material = cm
	chao.mesh = pm
	raiz.add_child(chao)
	heroi = Character.create({"race": "humano", "gender": "m", "equipment": {"arma": "espada_ng", "armadura": "pesada_ng"}})
	raiz.add_child(heroi)
	heroi.position = Vector3(0, 0, 0)
	alvo = Character.create({"race": "orc", "gender": "m", "equipment": {"armadura": "leve_ng"}})
	raiz.add_child(alvo)
	alvo.position = Vector3(0, 0, 5.5)
	alvo.rotation.y = PI
	cam = Camera3D.new()
	cam.fov = 45
	raiz.add_child(cam)
	cam.position = Vector3(6.5, 3.2, 1.2)
	cam.look_at(Vector3(0, 1.2, 2.8))


func _process(_d: float) -> bool:
	quadros += 1
	if quadros == 1:
		_montar()
		return false
	if quadros == 20:
		var p := fx.split(":")
		var el := p[1] if p.size() > 1 else ""
		var peito := heroi.global_position + Vector3(0, 1.3, 0)
		var centro := alvo.global_position + Vector3(0, 1.1, 0)
		match p[0]:
			"corte":
				heroi.action("Sword_Attack")
				FX.corte(heroi, Color(1.0, 0.85, 0.5), 1.6, 1.15, 0.35)
			"corte2":
				FX.corte(heroi, Color(0.5, 0.75, 1.0), 1.7, 1.0, -0.45)
			"magia":
				FX.circulo_magico(heroi, el, 0.9, 1.2)
				FX.magia(raiz, peito + Vector3(0, 0.3, 0), centro, el, 0.45)
			"circulo":
				FX.circulo_magico(heroi, el, 2.0, 1.3)
			"coluna":
				FX.coluna(raiz, heroi.global_position, "holy", 5.0, 0.9, 1.2)
				FX.burst(raiz, peito, "holy", 1.1)
			"zona":
				FX.zona(raiz, alvo.global_position, el, 4.0, 1.2)
			"relampago":
				FX.relampago(raiz, peito + Vector3(0, 0.5, 0), centro)
			"flecha":
				FX.flecha_brilho(raiz, peito, centro, el, 0.5)
			"impacto":
				FX.flare(raiz, centro, Color(1, 0.8, 0.4), 1.4, 0.6)
				FX.burst(raiz, centro, "fire", 1.0)
	if quadros == 20 + quadro:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(saida)
		return true
	return false
