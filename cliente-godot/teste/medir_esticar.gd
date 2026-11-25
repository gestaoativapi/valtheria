extends SceneTree
# Mapa de esticamento da pele dos corpos próprios: faz a pele na CPU com a pose real dos ossos (BoneAttachment3D,
# já com a postura) em vários quadros de cada animação e mede, aresta por aresta, quanto ela estica ou encolhe em
# relação ao repouso. Grava /tmp/esticar_<raca>_<g>.csv (x,y,z do repouso, pior razão, osso dominante) e imprime
# o resumo por osso. Uso: -s teste/medir_esticar.gd -- --corpo=orc:m --anims=Idle,Walk,Sprint,Sword_Attack
var corpo := "orc:m"
var anims := "Idle,Walk,Sprint,Sword_Attack"
var quadros_medir := [16, 24, 32, 40]
var q := 0
var i_anim := 0
var c: Node3D
var mi: MeshInstance3D
var skel: Skeleton3D
var V: PackedVector3Array
var B: PackedInt32Array
var W: PackedFloat32Array
var I: PackedInt32Array
var nb := 4
var ats := {}
var binds := {}
var pior: PackedFloat32Array
var arestas: PackedInt32Array
var lista: PackedStringArray
var nomes := {}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--corpo="): corpo = a.trim_prefix("--corpo=")
		elif a.begins_with("--anims="): anims = a.trim_prefix("--anims=")
	lista = anims.split(",")


func _process(_d: float) -> bool:
	q += 1
	if i_anim >= lista.size():
		_salvar()
		return true
	if q == 1:
		var p := corpo.split(":")
		c = load("res://scripts/character.gd").create({"race": p[0], "gender": p[1], "equipment": {"armadura": "nenhuma"}})
		root.add_child(c)
		var an := lista[i_anim]
		c.set_battle(an.ends_with("+c"))
		an = an.trim_suffix("+c")
		if an in ["Sword_Attack", "Punch", "Spell"]:
			c.action(an)
		elif an != "Idle":
			c.play(an)
		_preparar()
	if q in quadros_medir:
		_medir()
	if q > quadros_medir[-1]:
		c.queue_free()
		i_anim += 1
		q = 0
	return false


func _preparar() -> void:
	mi = null
	for m in c.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).to_lower().begins_with("corpo") and (m as MeshInstance3D).skin != null:
			mi = m
	skel = mi.get_node(mi.skeleton)
	if V.is_empty():
		var arr := mi.mesh.surface_get_arrays(0)
		V = arr[Mesh.ARRAY_VERTEX]
		B = arr[Mesh.ARRAY_BONES]
		W = arr[Mesh.ARRAY_WEIGHTS]
		I = arr[Mesh.ARRAY_INDEX]
		nb = B.size() / V.size()
		pior.resize(V.size())
		pior.fill(1.0)
		# arestas únicas (solda vértices na mesma posição: costuras de UV não contam como aresta)
		var vistos := {}
		for t in range(0, I.size(), 3):
			for k in 3:
				var a := I[t + k]
				var b := I[t + (k + 1) % 3]
				var ch := Vector2i(mini(a, b), maxi(a, b))
				if not vistos.has(ch):
					vistos[ch] = true
					arestas.append(a)
					arestas.append(b)
	ats.clear()
	binds.clear()
	var sk := mi.skin
	for bi in sk.get_bind_count():
		var nome := sk.get_bind_name(bi)
		var at := BoneAttachment3D.new()
		skel.add_child(at)
		at.bone_idx = skel.find_bone(nome) if nome != "" else sk.get_bind_bone(bi)
		ats[bi] = at
		nomes[bi] = nome
		binds[bi] = sk.get_bind_pose(bi)


func _medir() -> void:
	var inv := skel.global_transform.affine_inverse()
	var m := {}
	for bi in ats:
		if OS.get_cmdline_user_args().has("--rest"):
			m[bi] = skel.get_bone_global_rest((ats[bi] as BoneAttachment3D).bone_idx) * (binds[bi] as Transform3D)
		elif OS.get_cmdline_user_args().has("--global-pose"):
			m[bi] = skel.get_bone_global_pose((ats[bi] as BoneAttachment3D).bone_idx) * (binds[bi] as Transform3D)
		else:
			m[bi] = (inv * (ats[bi] as Node3D).global_transform) * (binds[bi] as Transform3D)
	var P := PackedVector3Array()
	P.resize(V.size())
	for v in V.size():
		var acc := Vector3.ZERO
		for k in nb:
			var w := W[v * nb + k]
			if w > 0.0:
				acc += (m[B[v * nb + k]] as Transform3D) * V[v] * w
		P[v] = acc
	if OS.get_cmdline_user_args().has("--despejar") and q == quadros_medir[0]:
		var fd := FileAccess.open("/tmp/pose_%s.csv" % lista[i_anim], FileAccess.WRITE)
		for v in V.size():
			fd.store_line("%.4f,%.4f,%.4f" % [P[v].x, P[v].y, P[v].z])
		fd.close()
	for e in range(0, arestas.size(), 2):
		var a := arestas[e]
		var b := arestas[e + 1]
		var d0 := V[a].distance_to(V[b])
		if d0 < 0.002:
			continue
		var r := P[a].distance_to(P[b]) / d0
		var f := r  # só esticar (encolher vira dobra de pele, que não rasga a textura)
		if f > pior[a]: pior[a] = f
		if f > pior[b]: pior[b] = f


func _salvar() -> void:
	var f := FileAccess.open("/tmp/esticar_%s.csv" % corpo.replace(":", "_"), FileAccess.WRITE)
	var por_osso := {}
	for v in V.size():
		var dom := 0
		var wm := -1.0
		for k in nb:
			if W[v * nb + k] > wm:
				wm = W[v * nb + k]; dom = B[v * nb + k]
		var nm: String = nomes.get(dom, str(dom))
		f.store_line("%.4f,%.4f,%.4f,%.3f,%s" % [V[v].x, V[v].y, V[v].z, pior[v], nm])
		var o: Array = por_osso.get(nm, [0, 0, 0.0])
		o[0] += 1
		if pior[v] > 1.4: o[1] += 1
		o[2] = maxf(o[2], pior[v])
		por_osso[nm] = o
	f.close()
	var ks := por_osso.keys()
	ks.sort_custom(func(x, y): return por_osso[x][1] > por_osso[y][1])
	for k in ks.slice(0, 12):
		var o: Array = por_osso[k]
		print("ESTICA %s %-12s vértices %5d  esticados>40%% %5d (%.1f%%)  pior %.2fx" % [corpo, k, o[0], o[1], 100.0 * o[1] / o[0], o[2]])
