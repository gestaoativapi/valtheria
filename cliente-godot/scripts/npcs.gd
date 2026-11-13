extends Node3D
# Moradores e animais das cidades: aparecem só na cidade em que o jogador está.

const Character = preload("res://scripts/character.gd")
# função, posição (x, z a partir do centro), giro, animação, janela que abre ao clicar, roupa, arma
const ROLES := [
	["Mercador", Vector3(-9.2, 0, 7.4), 2.4, "Idle_Talking", "loja", "leve_ng", ""],
	["Ferreiro", Vector3(-60.0, 0, -11.0), 1.4, "Idle_FoldArms", "oficio", "leve_ng", "martelo_ng"],
	["Mestre do Clã", Vector3(5.0, 0, -11.0), 0.2, "Idle", "cla", "robe_ng", ""],
	["Estalajadeiro", Vector3(-6.0, 0, -58.0), 0.1, "Idle_Talking", "", "leve_ng", ""],
	["Morador", Vector3(10.5, 0, 9.0), 3.6, "Idle", "", "leve_ng", ""],
]

var main: Node3D
var town_id := ""
var list: Array = []  # {"node", "window", "name"}
var check_t := 0.0


func setup(m: Node3D) -> void:
	main = m


func _clear() -> void:
	for n in list:
		if is_instance_valid(n.node):
			n.node.queue_free()
	list = []
	town_id = ""


func _spawn(t: Dictionary) -> void:
	town_id = str(t.id)
	var race := str(t.race) if main.world.info.races.has(str(t.race)) else "humano"
	var r := RandomNumberGenerator.new()
	r.seed = hash(town_id)
	var defs: Array = ROLES.duplicate()
	for g in t.get("gates", []):
		var a := float(g)
		for sgn in [-1.0, 1.0]:
			defs.append(["Guarda", Vector3(sin(a) * 82.0 + cos(a) * sgn * 3.2, 0, cos(a) * 82.0 - sin(a) * sgn * 3.2), a + PI, "Idle_Shield", "", "pesada_ng", "espada_ng"])
	for d in defs:
		var types: Array = main.world.info.races[race].types
		var c: Node3D = Character.create({"race": race, "gender": "f" if r.randf() < 0.45 and d[0] != "Guarda" else "m", "skin": r.randi() % 3, "hair": r.randi() % 6, "hair_color": r.randi() % 7, "equipment": {"armadura": d[5], "arma": d[6]}})
		add_child(c)
		var x: float = float(t.x) + (d[1] as Vector3).x
		var z: float = float(t.z) + (d[1] as Vector3).z
		c.position = Vector3(x, main.world.height(x, z), z)
		c.rotation.y = d[2]
		c.play(d[3])
		c.set_tag(d[0], Color(0.7, 1.0, 0.75) if d[4] != "" else Color(0.85, 0.9, 1.0))
		list.append({"node": c, "window": d[4], "name": d[0]})
	# animais perto do estábulo
	for a in [["a_horse", Vector3(62.0, 0, 26.0), 1.7], ["a_donkey", Vector3(70.0, 0, 12.0), 1.25], ["a_husky", Vector3(14.0, 0, 13.0), 0.6]]:
		var holder := Node3D.new()
		var sc: Node3D = (load("res://assets/world/%s.glb" % a[0]) as PackedScene).instantiate()
		var bb := AABB()
		var first := true
		for mi in sc.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = (mi as MeshInstance3D).get_aabb()
			bb = box if first else bb.merge(box)
			first = false
		if bb.size.y > 0.05 and bb.size.y < 50.0:
			sc.scale = Vector3.ONE * (float(a[2]) / bb.size.y)
		holder.add_child(sc)
		add_child(holder)
		var x: float = float(t.x) + (a[1] as Vector3).x
		var z: float = float(t.z) + (a[1] as Vector3).z
		holder.position = Vector3(x, main.world.height(x, z), z)
		holder.rotation.y = r.randf() * TAU
		var ap := sc.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap:
			for n in ["Eating", "Idle", "Idle_2"]:
				if ap.has_animation(n):
					ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
					ap.play(n)
					break
		list.append({"node": holder, "window": "", "name": ""})


func _process(dt: float) -> void:
	check_t -= dt
	if check_t > 0.0:
		return
	check_t = 1.0
	var p: Vector3 = main.player.position
	var nt: Dictionary = main.world.nearest_town(p.x, p.z)
	if nt.dist < 230.0:
		if town_id != str(nt.town.id):
			_clear()
			_spawn(nt.town)
	elif town_id != "" and nt.dist > 300.0:
		_clear()


# morador com função sob o cursor (raio da câmera), até 9 m do jogador
func pick(origin: Vector3, dir: Vector3) -> String:
	for n in list:
		if n.window == "":
			continue
		var node: Node3D = n.node
		if node.position.distance_to(main.player.position) > 9.0:
			continue
		var c: Vector3 = node.position + Vector3(0, 1.0, 0)
		var t := (c - origin).dot(dir)
		if t > 0.0 and (origin + dir * t).distance_to(c) < 1.0:
			return n.window
	return ""
