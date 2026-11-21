extends SceneTree
# Estúdio de ícones: fotografa cada arma, escudo e peça de roupa com o próprio modelo 3D do jogo
# (o mesmo que aparece no personagem), em fundo transparente, para a loja, a bolsa e o mercado.
# uso: godot --path . --rendering-method gl_compatibility -s teste/estudio_icones.gd -- [--so=id1,id2] [--de=0 --ate=999] [--pasta=res://assets/icones/itens]
# Armas e escudos: a peça sozinha, na diagonal, com a parte plana virada para a câmera.
# Roupas: um manequim humano vestindo só a peça, com a câmera na região dela (cabeça, peito, mãos ou pés).

const LADO := 128
var Character
var vp: SubViewport
var cam: Camera3D
var palco: Node3D
var fila: Array = []
var i := -1
var f := 0
var atual: Node3D
var pasta := "res://assets/icones/itens"
var feitos := 0


func _init() -> void:
	Character = load("res://scripts/character.gd")
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	var so := ""
	var de := 0
	var ate := 99999
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--so="): so = a.trim_prefix("--so=")
		elif a.begins_with("--de="): de = int(a.trim_prefix("--de="))
		elif a.begins_with("--ate="): ate = int(a.trim_prefix("--ate="))
		elif a.begins_with("--pasta="): pasta = a.trim_prefix("--pasta=")
	var ids: Array = []
	for id in info.items:
		var it: Dictionary = info.items[id]
		if str(it.get("slot", "")) in ["arma", "escudo", "elmo", "armadura", "luvas", "botas"]:
			ids.append(str(id))
	ids.sort()
	if so != "":
		ids = Array(so.split(","))
	for k in ids.size():
		if k >= de and k <= ate:
			fila.append([ids[k], info.items.get(ids[k], {})])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))

	vp = SubViewport.new()
	vp.size = Vector2i(LADO * 2, LADO * 2)  # desenha no dobro e reduz: bordas mais lisas
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	palco = Node3D.new()
	vp.add_child(palco)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	palco.add_child(we)
	for l in [[-38.0, 32.0, 1.35], [-12.0, -145.0, 0.6], [25.0, 180.0, 0.35]]:  # principal, recorte e preenchimento
		var d := DirectionalLight3D.new()
		d.rotation = Vector3(deg_to_rad(l[0]), deg_to_rad(l[1]), 0)
		d.light_energy = l[2]
		palco.add_child(d)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.01
	cam.far = 50.0
	palco.add_child(cam)
	cam.current = true
	print("ícones a fazer: ", fila.size())


func _aabb(n: Node3D, ref: Transform3D) -> AABB:
	var bb := AABB()
	var primeiro := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var b: AABB = (ref * mi.global_transform) * mi.get_aabb()
		bb = b if primeiro else bb.merge(b)
		primeiro = false
	return bb


func _esconder_menos(raiz: Node3D, manter: Array) -> void:
	for m in raiz.find_children("*", "GeometryInstance3D", true, false):
		var dentro := false
		for k in manter:
			if k != null and (m == k or (k as Node).is_ancestor_of(m)):
				dentro = true
		if not dentro:
			(m as GeometryInstance3D).visible = false


# põe a peça na diagonal (ponta para cima e para a direita) com o lado plano virado para a câmera
func _pose_objeto(obj: Node3D, frente := 1.0) -> void:
	var sc := obj.global_basis.get_scale()
	var loc := _aabb(obj, obj.global_transform.affine_inverse())
	var tam := loc.size
	var eixos := [0, 1, 2]
	eixos.sort_custom(func(a, b): return tam[a] > tam[b])
	var longo: int = eixos[0]
	var fino: int = eixos[2]
	var meio: int = eixos[1]
	var centro := loc.get_center()
	var dir_l := Vector3(0.7071, 0.7071, 0) * (1.0 if centro[longo] >= 0.0 else -1.0)
	var dir_f := Vector3(0, 0, frente)
	var dir_m := dir_f.cross(dir_l)
	var cols := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	cols[longo] = dir_l
	cols[fino] = dir_f
	cols[meio] = dir_m
	var b := Basis(cols[0], cols[1], cols[2])
	if b.determinant() < 0.0:
		cols[meio] = -dir_m
		b = Basis(cols[0], cols[1], cols[2])
	# um leve giro para a peça não ficar chapada
	b = Basis(Vector3.UP, deg_to_rad(18.0)) * Basis(Vector3.RIGHT, deg_to_rad(-10.0)) * b
	obj.global_transform = Transform3D(b * Basis.from_scale(sc), Vector3.ZERO)
	var w := _aabb(obj, Transform3D.IDENTITY)
	obj.global_position -= w.get_center()
	var s := maxf(w.size.x, w.size.y)
	cam.size = s * 1.12
	cam.global_position = Vector3(0, 0, 10)
	cam.look_at(Vector3.ZERO)


func _osso(c: Node3D, nome: String) -> Vector3:
	for sk in c.find_children("*", "Skeleton3D", true, false):
		var k: int = (sk as Skeleton3D).find_bone(nome)
		if k >= 0:
			return ((sk as Skeleton3D).global_transform * (sk as Skeleton3D).get_bone_global_pose(k)).origin
	return Vector3.INF


func _pose_roupa(c: Node3D, slot: String) -> void:
	var h: float = c.height_m
	var alvo := Vector3(0, h * 0.62, 0)
	var tam := h * 0.5
	match slot:
		"elmo":
			var p := _osso(c, "Head")
			alvo = (p if p != Vector3.INF else Vector3(0, h * 0.92, 0)) + Vector3(0, h * 0.05, 0)
			tam = h * 0.26
		"armadura":
			alvo = Vector3(0, h * 0.64, 0)
			tam = h * 0.52
		"luvas":
			var p := _osso(c, "hand_r")
			alvo = (p + Vector3(-0.03, -0.07, 0.02)) if p != Vector3.INF else Vector3(-0.25, h * 0.5, 0)
			tam = h * 0.22
		"botas":
			var a := _osso(c, "foot_r")
			var b := _osso(c, "foot_l")
			alvo = ((a + b) * 0.5) if a != Vector3.INF and b != Vector3.INF else Vector3(0, h * 0.05, 0)
			alvo.y = h * 0.07
			tam = h * 0.27
	var ang := deg_to_rad(28.0 if slot != "luvas" else 10.0)
	cam.size = tam
	cam.global_position = alvo + Vector3(sin(ang), 0.12, cos(ang)) * 6.0
	cam.look_at(alvo)


func _process(_dt: float) -> bool:
	f += 1
	if i < 0 or f == 14:
		if atual != null:
			var img := vp.get_texture().get_image()
			img.resize(LADO, LADO, Image.INTERPOLATE_LANCZOS)
			img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [pasta, fila[i][0]]))
			feitos += 1
			atual.queue_free()
			atual = null
		i += 1
		f = 0
		if i >= fila.size():
			print("ícones feitos: ", feitos)
			quit()
			return true
		var id: String = fila[i][0]
		var it: Dictionary = fila[i][1]
		var slot := str(it.get("slot", ""))
		var eq := {}
		eq[slot] = id
		if slot == "escudo":
			eq["arma"] = "espada_ng"  # o escudo só aparece com arma de uma mão
		if slot in ["luvas", "botas"]:
			# luvas e botas aparecem pelo conjunto de mesmo tipo e grau (luvas_pesada_d -> pesada_d)
			var conj := id.trim_prefix(slot + "_")
			eq["armadura"] = conj
		atual = Character.create({"race": "humano", "gender": "m", "skin": 1, "hair": 0, "equipment": eq})
		atual.set_meta("slot", slot)
		palco.add_child(atual)
		return false
	if f == 8 and atual != null:
		var slot: String = atual.get_meta("slot")
		if slot == "arma" or slot == "escudo":
			var peca: Node3D = atual.wnode if slot == "arma" else atual.shield
			if peca == null:
				peca = atual.wnode if atual.wnode != null else atual.shield
			if peca == null:
				print("sem modelo: ", fila[i][0])
				return false
			var solto := Node3D.new()
			palco.add_child(solto)
			var gt := peca.global_transform
			peca.get_parent().remove_child(peca)
			solto.add_child(peca)
			peca.global_transform = gt
			for m in peca.find_children("*", "GeometryInstance3D", true, false):
				(m as GeometryInstance3D).visible = not (m is GPUParticles3D or m is CPUParticles3D)
			atual.visible = false
			atual.queue_free()
			atual = solto
			_pose_objeto(peca, -1.0 if slot == "escudo" else 1.0)
		else:
			if atual.wnode != null:
				atual.wnode.visible = false
			_pose_roupa(atual, slot)
	return false
