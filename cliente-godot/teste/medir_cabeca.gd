extends SceneTree
# Mede quanto o rosto estica durante as animações (corpos próprios com pele automática).
# Pega os vértices da cabeça (acima do queixo, perto do eixo), faz a pele na CPU com a pose real dos
# ossos (BoneAttachment3D, que já inclui os modificadores de postura) e compara 300 pares de pontos com o
# repouso: distorção = quanto a distância entre os pares muda, descontada a escala.
# uso: -s teste/medir_cabeca.gd -- --lista=orc:m,orc:f --anims=Idle,Walk,Sprint --queixo=1.704,1.574
var lista := "orc:m,orc:f"
var anims := "Idle,Walk,Sprint"
var queixos := "1.704,1.574"
var q := 0
var casos: Array = []
var i_caso := 0
var c: Node3D


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lista="): lista = a.trim_prefix("--lista=")
		elif a.begins_with("--anims="): anims = a.trim_prefix("--anims=")
		elif a.begins_with("--queixo="): queixos = a.trim_prefix("--queixo=")
	var qs := queixos.split(",")
	var ls := lista.split(",")
	for k in ls.size():
		for an in anims.split(","):
			casos.append([ls[k], an, float(qs[k])])


func _process(_d: float) -> bool:
	q += 1
	if i_caso >= casos.size():
		return true
	var cs: Array = casos[i_caso]
	if q == 1:
		var p: PackedStringArray = str(cs[0]).split(":")
		c = load("res://scripts/character.gd").create({"race": p[0], "gender": p[1], "equipment": {"armadura": "nenhuma"}})
		root.add_child(c)
		c.set_battle(false)
		if str(cs[1]) != "Idle":
			c.play(str(cs[1]))
	if q == 40:
		_preparar(cs)
	if q == 43:
		_medir(cs)
		c.queue_free()
		i_caso += 1
		q = 0
	return false


var _d := {}


func _preparar(cs: Array) -> void:
	var mi: MeshInstance3D = null
	for m in c.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).to_lower().begins_with("corpo") and (m as MeshInstance3D).skin != null:
			mi = m
	if mi == null:
		print("sem corpo próprio: ", cs[0]); _d = {}; return
	var skel: Skeleton3D = mi.get_node(mi.skeleton)
	var arr := mi.mesh.surface_get_arrays(0)
	var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var B: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var W: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var nb := B.size() / V.size()
	var sk := mi.skin
	var mats := {}
	var eixo := Vector2.ZERO
	var sel: Array = []
	var queixo: float = cs[2]
	for v in V.size():
		if V[v].y > queixo:
			sel.append(v)
	# eixo da cabeça: média horizontal dos pontos acima do queixo e perto do centro
	var soma := Vector2.ZERO
	var n := 0
	for v in sel:
		if absf(V[v].x) < 0.15:
			soma += Vector2(V[v].x, V[v].z); n += 1
	eixo = soma / maxf(1, n)
	var cab: Array = []
	for v in sel:
		if Vector2(V[v].x, V[v].z).distance_to(eixo) < 0.12:
			cab.append(v)
	var inv := skel.global_transform.affine_inverse()
	var pose := {}
	for bi in sk.get_bind_count():
		var nome := sk.get_bind_name(bi)
		var sb := skel.find_bone(nome) if nome != "" else sk.get_bind_bone(bi)
		var at := BoneAttachment3D.new()
		skel.add_child(at)
		at.bone_idx = sb
		mats[bi] = [at, sk.get_bind_pose(bi)]
	_d = {"mats": mats, "inv": inv, "cab": cab, "V": V, "B": B, "W": W, "nb": nb}


func _medir(cs: Array) -> void:
	if _d.is_empty():
		return
	var mats: Dictionary = _d.mats
	var inv: Transform3D = _d.inv
	var cab: Array = _d.cab
	var V: PackedVector3Array = _d.V
	var B: PackedInt32Array = _d.B
	var W: PackedFloat32Array = _d.W
	var nb: int = _d.nb
	for bi in mats:
		mats[bi] = (inv * (mats[bi][0] as Node3D).global_transform) * (mats[bi][1] as Transform3D)
	var P := {}
	for v in cab:
		var acc := Vector3.ZERO
		for k in nb:
			var w := W[v * nb + k]
			if w > 0.0:
				acc += (mats[B[v * nb + k]] as Transform3D) * V[v] * w
		P[v] = acc
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var razoes: Array = []
	for t in 400:
		var a: int = cab[rng.randi() % cab.size()]
		var b: int = cab[rng.randi() % cab.size()]
		var d0 := V[a].distance_to(V[b])
		if d0 < 0.04:
			continue
		razoes.append((P[a] as Vector3).distance_to(P[b]) / d0)
	razoes.sort()
	var med: float = razoes[razoes.size() / 2]
	var desv := 0.0
	var mx := 0.0
	for r in razoes:
		var e := absf(r / med - 1.0)
		desv += e; mx = maxf(mx, e)
	print("CABECA %s %s: pontos %d, distorção média %.1f%%, máx %.1f%%" % [cs[0], cs[1], cab.size(), 100.0 * desv / razoes.size(), 100.0 * mx])
