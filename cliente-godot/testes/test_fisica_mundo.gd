extends SceneTree
# Física do mundo aberto: em cada cidade, 2.000 passos aleatórios com a mesma regra de movimento do jogo.
# Confere: ninguém termina dentro de caixa (prédio, banca, caixote), não sobe encosta acima do limite,
# não sai do mapa e o ponto de nascimento seguro fica livre. Uso: godot --path . --script testes/test_fisica_mundo.gd
var main: Node
var frames := 0

func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)

func _inside_box(w, p: Vector3) -> bool:
	var key := Vector2i(floori(p.x / 8.0), floori(p.z / 8.0))
	for b in w.boxes.get(key, []):
		var dx: float = p.x - float(b[0]); var dz: float = p.z - float(b[1])
		var lx: float = dx * float(b[2]) - dz * float(b[3]); var lz: float = dx * float(b[3]) + dz * float(b[2])
		if absf(lx) < float(b[4]) + 0.2 and absf(lz) < float(b[5]) + 0.2:
			return true
	return false

func _process(_dt: float) -> bool:
	frames += 1
	if frames < 30:
		return false
	var w = main.world
	var falhas := 0
	var rng := RandomNumberGenerator.new(); rng.seed = 39
	var total_caixas := 0
	for t in w.info.towns:
		var c := Vector3(float(t.x), 0, float(t.z))
		for i in 12:
			w.stream(c, 50)
		var dentro := 0; var encosta := 0; var fora := 0
		var p := Vector3(c.x + 20, 0, c.z + 20)
		var sp: Vector2 = w.safe_spot(c.x, c.z)
		if _inside_box(w, Vector3(sp.x, 0, sp.y)):
			falhas += 1; print("FALHA %s: nascimento dentro de objeto" % t.id)
		for k in 2000:
			var a := rng.randf() * TAU
			var q: Vector3 = w.resolve(p + Vector3(sin(a), 0, cos(a)) * 0.35, p)
			var run := Vector2(q.x - p.x, q.z - p.z).length()
			var rise: float = w.height(q.x, q.z) - w.height(p.x, p.z)
			if run > 0.01 and rise > run * w.INCLINACAO_MAX + 0.05 and w.floor_y(q.x, q.z, p.y) <= w.height(q.x, q.z) + 0.05:
				encosta += 1
			if _inside_box(w, q): dentro += 1
			if q.x < 8 or q.z < 8 or q.x > w.size - 8 or q.z > w.size - 8: fora += 1
			p = q
			if p.distance_to(c) > 120: p = Vector3(c.x + 20, 0, c.z + 20)
		var nb := 0
		for key in w.boxes: nb += (w.boxes[key] as Array).size()
		total_caixas = nb
		var ok := dentro == 0 and encosta == 0 and fora == 0
		if not ok: falhas += 1
		print("%s %s: dentro=%d encosta=%d fora=%d" % ["ok  " if ok else "FALHA", t.id, dentro, encosta, fora])
	var portas_ruins := 0
	for d in w.doors:
		var dp: Vector3 = d.pos
		var lim := 1.8 if d.kind == "portal" else 2.8
		var sp2: Vector2 = w.safe_spot(dp.x, dp.z)
		if sp2.distance_to(Vector2(dp.x, dp.z)) > lim - 0.3:
			portas_ruins += 1
			print("FALHA porta inalcançável: %s %s (%.1f m)" % [d.kind, str(d.get("name", "")), sp2.distance_to(Vector2(dp.x, dp.z))])
	print("portas: %d, inalcançáveis: %d" % [w.doors.size(), portas_ruins])
	if portas_ruins > 0: falhas += 1
	print("caixas de colisão registradas: %d" % total_caixas)
	print("RESULTADO: " + ("PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas))
	quit(0 if falhas == 0 else 1)
	return true
