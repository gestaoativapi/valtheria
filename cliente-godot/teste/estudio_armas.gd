extends SceneTree
# Vitrine das armas (27/11): cada arma montada pelo jogo (modelo + grau + relíquia) em pé, lado a lado,
# com fundo escuro, para conferir de perto. Opcional: --giro=graus gira todas no eixo vertical.
# uso: -s teste/estudio_armas.gd -- --lista=espada_s,espada_ss,... --saida=/tmp/x.png [--giro=30] [--quadros=20]

var lista := "espada_ng,espada_a,espada_s,espada_ss"
var saida := "/tmp/armas.png"
var giro := 25.0
var quadros := 20
var q := 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lista="): lista = a.trim_prefix("--lista=")
		elif a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
		elif a.begins_with("--giro="): giro = float(a.trim_prefix("--giro="))
		elif a.begins_with("--quadros="): quadros = int(a.trim_prefix("--quadros="))


func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.09, 0.1, 0.13)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.55, 0.57, 0.65)
		env.glow_enabled = true
		env.glow_intensity = 0.8
		env.glow_bloom = 0.08
		var we := WorldEnvironment.new()
		we.environment = env
		root.add_child(we)
		var sol := DirectionalLight3D.new()
		sol.rotation = Vector3(-0.7, 0.6, 0)
		sol.light_energy = 1.3
		root.add_child(sol)
		var C = load("res://scripts/character.gd")
		var itens := lista.split(",")
		var maior := 0.5
		var x := 0.0
		for i in itens.size():
			var id: String = itens[i]
			var kind := id.get_slice("_", 0)
			var eq := {"arma": id} if kind != "escudo" else {"arma": "espada_ng", "escudo": id}
			var c: Node3D = C.create({"race": "humano", "gender": "m", "equipment": eq})
			root.add_child(c)
			var w: Node3D = c.wnode if kind != "escudo" else c.get("shield")
			if w == null:
				continue
			var t := w.global_transform
			w.get_parent().remove_child(w)
			root.add_child(w)
			# em pé: o eixo mais longo da arma (lado da ponta) vira +Y, a face larga para a câmera
			var bb := AABB()
			var pri := true
			for mm in w.find_children("*", "MeshInstance3D", true, false):
				var mi := mm as MeshInstance3D
				if mi.mesh == null or mi.mesh is QuadMesh:
					continue
				var peca := false
				var no: Node = mi
				while no != w:
					peca = peca or no.has_meta("reliquia_peca")
					no = no.get_parent()
				if peca:
					continue
				var b: AABB = load("res://scripts/enfeites.gd")._rel(w, mi) * mi.get_aabb()
				bb = b if pri else bb.merge(b)
				pri = false
			var tam := bb.size
			var ordem := [0, 1, 2]
			ordem.sort_custom(func(a, b): return tam[a] > tam[b])
			var ex := Vector3.ZERO
			ex[ordem[0]] = 1.0 if bb.get_center()[ordem[0]] >= 0.0 else -1.0
			var fx := Vector3.ZERO
			fx[ordem[2]] = 1.0
			var lx := ex.cross(fx)
			var bas := Basis(lx, ex, fx).inverse()  # leva ponta -> +Y, face -> +Z
			var esc := 1.0 / maxf(w.transform.basis.get_scale().x, 0.001)
			var tm0 := 1.9 if kind in ["lanca", "cajado"] else (1.45 if kind in ["espadao", "arco", "martelo"] else (0.55 if kind in ["adaga", "punhal"] else 1.05))
			var e := tm0 / maxf(tam[ordem[0]], 0.01)
			var cen: Vector3 = bas * bb.get_center() * e
			w.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(giro)) * bas.scaled(Vector3.ONE * e), Vector3(x, tm0 * 0.5, 0) - Basis(Vector3.UP, deg_to_rad(giro)) * cen)
			if kind == "escudo":  # escudo: o rosto da relíquia de frente para a câmera
				for ch in w.get_children():
					if ch.has_meta("reliquia_peca"):
						var dz: Vector3 = (w.transform.basis * (ch as Node3D).transform.basis.z).normalized()
						var rq := Basis(Quaternion(dz, Vector3.BACK))
						w.transform = Transform3D(rq * w.transform.basis, w.transform.origin)
						break
			c.queue_free()
			maior = maxf(maior, tm0 * 1.2)
			x += 0.55 if kind in ["adaga", "punhal"] else 0.75
			var lb := Label3D.new()
			lb.text = id
			lb.font_size = 28
			lb.position = Vector3(w.position.x, -0.18, 0.2)
			root.add_child(lb)
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.fov = 40.0
		var meio := (x - 0.75) * 0.5
		cam.position = Vector3(meio, maior * 0.45, maxf(x * 0.95, maior * 1.55))
		cam.look_at(Vector3(meio, maior * 0.42, 0))
		cam.current = true
	if q == quadros:
		root.get_viewport().get_texture().get_image().save_png(saida)
		quit()
	return false
