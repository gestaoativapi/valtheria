extends SceneTree
# Pés no chão: todas as raças, homem e mulher, em chão plano, encosta e calçada da cidade.
# Mede a sola (osso do pé menos a altura do tornozelo) contra o chão. Aceita até 4 cm.
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
		for li in LUGARES.size():
			var L: Vector2 = LUGARES[li]
			for i in ids.size():
				for g in 2:
					var c: Node3D = Character.create({"race": ids[i], "gender": "mf"[g], "skin": 1, "hair": 1, "hair_color": 1, "equipment": {"armadura": "leve_ng"}})
					main.add_child(c)
					var px := L.x + i * 1.4 - 6.0
					var pz := L.y + g * 2.0
					c.position = Vector3(px, main.world.height(px, pz), pz)
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
		for b in c.feet:
			var p: Vector3 = xf * c.skel.get_bone_global_pose(b).origin
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
