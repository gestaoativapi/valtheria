extends SceneTree
# Pés no chão: todas as raças, homem e mulher, em chão plano, encosta e calçada da cidade.
# Mede a sola (pé final na tela menos a altura do tornozelo) contra o chão. Aceita até 4 cm.
# Lugares: plano, encosta, calçada, as 3 encostas andáveis mais íngremes e pisos elevados do mundo.
# Uso: godot --headless --path . --script testes/test_pes.gd
const Character = preload("res://scripts/character.gd")
var main: Node
var f := 0
var bonecos: Array = []
const LUGARES := [Vector2(1500, 2560), Vector2(1330, 2380), Vector2(1255, 2252), Vector2(2350, 1950), Vector2(1500, 1450)]

func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	f += 1
	if f == 20:
		var ids: Array = main.world.info.races.keys()
		var lugares: Array = LUGARES.duplicate()
		# "todo cenário" (22/11): soma as encostas mais íngremes andáveis perto das cidades e pisos elevados
		# (pontes, plataformas, mirantes) do próprio mundo
		var ingremes := []
		for gx in range(1100, 2600, 37):
			for gz in range(1300, 2700, 37):
				var h0: float = main.world.height(gx, gz)
				var dh := absf(main.world.height(gx + 1.0, gz) - h0) + absf(main.world.height(gx, gz + 1.0) - h0)
				if dh < 0.75 and h0 > -0.5:
					ingremes.append([dh, Vector2(gx, gz)])
		ingremes.sort_custom(func(a, b): return a[0] > b[0])
		for k in mini(3, ingremes.size()):
			lugares.append(ingremes[k][1])
		var npis := 0
		for fl in main.world.floors:
			if str(fl.kind) == "rect" and float(fl.hw) >= 6.0 and float(fl.hd) >= 2.5 and npis < 2:
				lugares.append(Vector2(fl.c.x, fl.c.y))
				npis += 1
		print("lugares: ", lugares.size(), " (", ingremes.size(), " pontos de encosta medidos)")
		for li in lugares.size():
			var L: Vector2 = lugares[li]
			for i in ids.size():
				for g in 2:
					var c: Node3D = Character.create({"race": ids[i], "gender": "mf"[g], "skin": 1, "hair": 1, "hair_color": 1, "equipment": {"armadura": "leve_ng"}})
					c.set_meta("sem_lod", true)  # o teste mede o IK dos pés em qualquer distância da câmera
					main.add_child(c)
					var px := L.x + i * 1.4 - 6.0
					var pz := L.y + g * 2.0
					c.position = Vector3(px, main.world.floor_y(px, pz, main.world.height(px, pz) + 30.0), pz)
					# mede o pé como aparece na tela (pose final, com o IK das pernas), não a pose crua da animação
					for lado in ["l", "r"]:
						var at := BoneAttachment3D.new()
						at.bone_name = "foot_" + lado
						at.name = "MedePe_" + lado
						c.skel.add_child(at)
					bonecos.append([c, "%s/%s @%d" % [ids[i], "mf"[g], li]])
		return false
	if f < 160:
		return false
	var ruins := 0
	var pior := 0.0
	for e in bonecos:
		var c = e[0]
		if c.skel == null or c.feet.is_empty() or c.feet[0] < 0:
			print("sem ossos de pé: ", e[1])
			continue
		var xf: Transform3D = c.skel.global_transform
		var low := 1e9
		for lado in ["l", "r"]:
			var at = c.skel.get_node_or_null("MedePe_" + lado)
			if at == null:
				continue
			var p: Vector3 = at.global_position
			# mede contra o piso de verdade (calçada da cidade fica ~8 cm acima da terra)
			var g: float = (p.y - c.ankle) - float(main.world.floor_y(p.x, p.z, p.y + 0.5))
			low = minf(low, g)
		pior = maxf(pior, absf(low))
		if absf(low) > 0.04:
			ruins += 1
			print("%s: sola %.3f m (%s)" % [e[1], low, "enterrada" if low < 0 else "flutuando"])
	print("bonecos: %d, fora do chão: %d, pior: %.3f m" % [bonecos.size(), ruins, pior])
	print("RESULTADO: " + ("PASSOU" if ruins == 0 else "FALHOU"))
	quit(0 if ruins == 0 else 1)
	return true
