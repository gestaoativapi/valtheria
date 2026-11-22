extends SceneTree
# Foto de personagens parados na encosta mais íngreme perto de Vila Aurora (prova do IK das pernas).
var main: Node
var f := 0
var saida := "/tmp/encosta.png"
var ponto := Vector2.ZERO
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
func _process(_d: float) -> bool:
	f += 1
	if f == 20:
		var w = main.world
		var melhor := -1.0
		for gx in range(1250, 1700, 9):
			for gz in range(2250, 2650, 9):
				var h0: float = w.height(gx, gz)
				var dx: float = w.height(gx + 1.0, gz) - h0
				if absf(dx) > melhor and absf(dx) < 0.6 and absf(w.height(gx, gz + 1.0) - h0) < 0.08:
					melhor = absf(dx)
					ponto = Vector2(gx, gz)
		print("encosta ", ponto, " inclinação ", melhor)
		var C = load("res://scripts/character.gd")
		var lista := [["humano", "m"], ["anao", "m"], ["gigante", "m"], ["elfo", "f"]]
		for i in lista.size():
			var c: Node3D = C.create({"race": lista[i][0], "gender": lista[i][1], "equipment": {"armadura": "leve_ng"}})
			main.add_child(c)
			var px := ponto.x + (i - 1.5) * 1.5
			var pz := ponto.y
			c.position = Vector3(px, w.height(px, pz), pz)
			c.rotation.y = PI * 0.5   # de lado para a câmera: a encosta aparece de perfil
		var cam := Camera3D.new()
		main.add_child(cam)
		cam.position = Vector3(ponto.x, w.height(ponto.x, ponto.y) + 1.1, ponto.y) + Vector3(0, 0, 0)
		cam.position += Vector3(0.0, 0.0, 0.0)
		cam.global_position = Vector3(ponto.x, w.height(ponto.x, ponto.y) + 0.9, ponto.y + 6.5)
		cam.look_at(Vector3(ponto.x, w.height(ponto.x, ponto.y) + 0.7, ponto.y))
		cam.fov = 45.0
		cam.current = true
		if main.get("player") != null:
			main.player.visible = false
	if f == 60:
		for n in root.find_children("*", "CanvasLayer", true, false):
			(n as CanvasLayer).visible = false
	if f == 150:
		root.get_viewport().get_texture().get_image().save_png(saida)
		quit()
	return false
