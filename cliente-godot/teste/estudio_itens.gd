extends SceneTree
# Estúdio de itens: lado a lado, mesma altura, para conferir pacotes de armas. uso: -- --pasta=res://... --saida=x.png
var f := 0
var saida := "/tmp/itens.png"
func _init() -> void:
	pass
func _setup() -> void:
	var pasta := "res://assets/armas_cc0/rgpoly"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pasta="): pasta = a.substr(8)
		if a.begins_with("--saida="): saida = a.substr(8)
	var raiz := Node3D.new()
	get_root().add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.2, 0.23)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(-0.6, 0.6, 0)
	raiz.add_child(sol)
	var nomes: Array = []
	for n in DirAccess.get_files_at(pasta):
		if n.ends_with(".glb") or n.ends_with(".gltf"):
			nomes.append(n)
	nomes.sort()
	var col := 8
	for i in nomes.size():
		var n: Node3D = (load(pasta + "/" + nomes[i]) as PackedScene).instantiate()
		raiz.add_child(n)
		var bb := AABB()
		var first := true
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			bb = b if first else bb.merge(b)
			first = false
		var k := 1.0 / maxf(bb.get_longest_axis_size(), 0.001)
		n.scale = Vector3.ONE * k
		n.position = Vector3((i % col) * 1.2, -(i / col) * 1.3, 0) - bb.get_center() * k
		var l := Label3D.new()
		l.text = nomes[i].get_basename()
		l.pixel_size = 0.0025
		l.position = Vector3((i % col) * 1.2, -(i / col) * 1.3 - 0.6, 0)
		raiz.add_child(l)
	var cam := Camera3D.new()
	raiz.add_child(cam)
	var linhas := ceili(nomes.size() / float(col))
	cam.position = Vector3((col - 1) * 0.6, -(linhas - 1) * 0.65, 8.5)
	cam.fov = 50
func _process(_d: float) -> bool:
	f += 1
	if f == 1:
		_setup()
	if f == 10:
		get_root().get_texture().get_image().save_png(saida)
		return true
	return false
