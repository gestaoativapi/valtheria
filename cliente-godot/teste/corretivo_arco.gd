extends SceneTree
# Forma corretiva do ombro no tiro de arco (26/11).
# Monta o personagem, puxa o arco até o fim, calcula a malha já na pose de tiro (mesma conta da placa de vídeo:
# soma de peso x osso x pose de ligação), alisa a região do ombro/manga que estufa nessa pose e grava a diferença
# de volta na pose de descanso. O jogo liga essa forma só enquanto o braço está no tiro (arqueria.gd).
# uso: -s teste/corretivo_arco.gd -- --corpo=humano:m [--passos=40] [--forca=0.55] [--lados=r] [--saida=data/corpos/arco_humano_m.bin]

var corpo := "humano:m"
var passos := 40
var forca := 0.55
var lados := "r"
var encolher := 1.0
var LIMIAR := 0.02
var RAIO := 0.33
var TRONCO := 1.0
var DESTINO := "spine_03"
var saida := ""
var q := 0
var c: Node3D
var feito := false


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--corpo="): corpo = a.trim_prefix("--corpo=")
		elif a.begins_with("--passos="): passos = int(a.trim_prefix("--passos="))
		elif a.begins_with("--forca="): forca = float(a.trim_prefix("--forca="))
		elif a.begins_with("--raio="): RAIO = float(a.trim_prefix("--raio="))
		elif a.begins_with("--destino="): DESTINO = a.trim_prefix("--destino=")
		elif a.begins_with("--tronco="): TRONCO = float(a.trim_prefix("--tronco="))
		elif a.begins_with("--limiar="): LIMIAR = float(a.trim_prefix("--limiar="))
		elif a.begins_with("--encolher="): encolher = float(a.trim_prefix("--encolher="))
		elif a.begins_with("--lados="): lados = a.trim_prefix("--lados=")
		elif a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
	if saida == "":
		saida = "res://data/corpos/arco_%s.bin" % corpo.replace(":", "_")


func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		var C = load("res://scripts/character.gd")
		C.CORRETIVO_ARCO = false  # calcula sobre o corpo original
		var p := corpo.split(":")
		c = C.create({"race": p[0], "gender": p[1], "equipment": {"arma": "arco_ng", "armadura": "leve_ng"}})
		root.add_child(c)
	if q == 5:
		c.set_battle(true)
		c.disparar_arco()
	if q == 25:
		c.skel.skeleton_updated.connect(_assar, CONNECT_ONE_SHOT)
	if feito:
		quit()
	return false


func _assar() -> void:
	var sk: Skeleton3D = c.skel
	for bn in ["Head", "hand_r", "lowerarm_r", "upperarm_r", "clavicle_r", "spine_03", "hand_l"]:
	var mi: MeshInstance3D = null
	for m in sk.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).skin != null and (m as MeshInstance3D).mesh.get_surface_count() == 1:
			if mi == null or (m as MeshInstance3D).mesh.surface_get_array_len(0) > mi.mesh.surface_get_array_len(0):
				mi = m
	var skin: Skin = mi.skin
	var mats: Array[Transform3D] = []
	for b in skin.get_bind_count():
		var bi := skin.get_bind_bone(b)
		if bi < 0:
			bi = sk.find_bone(skin.get_bind_name(b))
		mats.append(sk.get_bone_global_pose(bi) * skin.get_bind_pose(b))
	# ossos da região que estufa (só o lado da corda, por padrão)
	var regiao := {}
	for b in skin.get_bind_count():
		var bi := skin.get_bind_bone(b)
		if bi < 0:
			bi = sk.find_bone(skin.get_bind_name(b))
		var nome := sk.get_bone_name(bi)
		for lado in lados:
			if nome.begins_with("clavicle_" + lado) or nome.begins_with("upperarm_" + lado):
				regiao[b] = true
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ob: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var ow: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var n := v.size()
	if idx.is_empty():
		for i in n:
			idx.append(i)
	# solda vértices duplicados na costura da textura (mesma posição) para alisar sem rasgar
	var grupo := PackedInt32Array()
	grupo.resize(n)
	var chave := {}
	var ng := 0
	for i in n:
		var k := Vector3i(roundi(v[i].x * 20000.0), roundi(v[i].y * 20000.0), roundi(v[i].z * 20000.0))
		if not chave.has(k):
			chave[k] = ng
			ng += 1
		grupo[i] = chave[k]
	var rep := PackedInt32Array()
	rep.resize(ng)
	for i in n:
		rep[grupo[i]] = i
	# pose e máscara por grupo
	var pos := PackedVector3Array()
	pos.resize(ng)
	var mascara := PackedFloat32Array()
	mascara.resize(ng)
	var blend: Array[Transform3D] = []
	blend.resize(ng)
	for g in ng:
		var i := rep[g]
		var t := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
		var wr := 0.0
		for j in 4:
			var w := ow[i * 4 + j]
			if w <= 0.0:
				continue
			var m: Transform3D = mats[ob[i * 4 + j]]
			t.basis.x += m.basis.x * w
			t.basis.y += m.basis.y * w
			t.basis.z += m.basis.z * w
			t.origin += m.origin * w
			if regiao.has(ob[i * 4 + j]):
				wr += w
		blend[g] = t
		pos[g] = t * v[i]
		mascara[g] = clampf((wr - LIMIAR) / 0.3, 0.0, 1.0)
	# vizinhos (por grupo)
	var viz: Array = []
	viz.resize(ng)
	for g in ng:
		viz[g] = []
	var lig := {}
	for f in range(0, idx.size(), 3):
		for e in 3:
			var ga := grupo[idx[f + e]]
			var gb := grupo[idx[f + (e + 1) % 3]]
			if ga == gb:
				continue
			var kk := Vector2i(mini(ga, gb), maxi(ga, gb))
			if lig.has(kk):
				continue
			lig[kk] = true
			(viz[ga] as Array).append(gb)
			(viz[gb] as Array).append(ga)
	# máscara suave (espalha a borda para não marcar degrau)
	for _p in 6:
		var nm := mascara.duplicate()
		for g in ng:
			var vs: Array = viz[g]
			if vs.is_empty():
				continue
			var s := 0.0
			for o in vs:
				s += mascara[o]
			nm[g] = (mascara[g] + s / vs.size()) * 0.5
		mascara = nm
	var ativos := PackedInt32Array()
	for g in ng:
		if mascara[g] > 0.01:
			ativos.append(g)
	# esvazia o balão: na pose de tiro, a manga não pode ficar mais longe do osso do braço do que fica em descanso
	var p := pos.duplicate()
	for lado in lados:
		var bu := sk.find_bone("upperarm_" + lado)
		var bl := sk.find_bone("lowerarm_" + lado)
		var ru := Vector3.ZERO
		var rl := Vector3.ZERO
		for b in skin.get_bind_count():
			if skin.get_bind_name(b) == "upperarm_" + lado:
				ru = skin.get_bind_pose(b).affine_inverse().origin
			elif skin.get_bind_name(b) == "lowerarm_" + lado:
				rl = skin.get_bind_pose(b).affine_inverse().origin
		var pu := sk.get_bone_global_pose(bu).origin
		var pl := sk.get_bone_global_pose(bl).origin
		# 1) o que é tronco (longe do eixo do braço em descanso) e foi puxado pelo braço volta a seguir o ombro
		#    (clavícula): é isso que fazia o balão. O peso do braço passa para a clavícula só nesta pose.
		var R := (rl - ru).length() * RAIO
		var mc := -1
		var mu := -1
		for b in skin.get_bind_count():
			if skin.get_bind_name(b) == DESTINO: mc = b
			elif skin.get_bind_name(b) == "upperarm_" + lado: mu = b
		var tronco := 0
		for g in ativos:
			var x := v[rep[g]]
			var t0 := clampf((x - ru).dot(rl - ru) / (rl - ru).length_squared(), 0.0, 1.0)
			var r0 := x.distance_to(ru + (rl - ru) * t0)
			var f := clampf((r0 - R) / (R * 0.6), 0.0, 1.0)
			f = f * f * (3.0 - 2.0 * f) * mascara[g] * (1.0 - t0 * 0.5)
			if f <= 0.0:
				continue
			var i := rep[g]
			var y := Vector3.ZERO
			for j in 4:
				var w := ow[i * 4 + j]
				if w <= 0.0: continue
				var bb := ob[i * 4 + j]
				if bb == mu: bb = mc
				y += (mats[bb] * x) * w
			p[g] = p[g].lerp(y, f * TRONCO)
			tronco += 1
		var mexeu := 0
		for g in ativos:
			var x := v[rep[g]]
			var t0 := clampf((x - ru).dot(rl - ru) / (rl - ru).length_squared(), 0.0, 1.0)
			var r0 := x.distance_to(ru + (rl - ru) * t0)
			var y := p[g]
			var t1 := clampf((y - pu).dot(pl - pu) / (pl - pu).length_squared(), 0.0, 1.0)
			var c1 := pu + (pl - pu) * t1
			var r1 := y.distance_to(c1)
			var alvo := r0 * 1.04
			if r1 > alvo and r1 > 1e-4:
				var nr := lerpf(r1, alvo, clampf(mascara[g] * encolher, 0.0, 1.0))
				p[g] = c1 + (y - c1) / r1 * nr
				mexeu += 1
	# alisamento Taubin na pose de tiro (tira as dobras/balão sem encolher o braço)
	for it in passos:
		for fator in [forca, -forca * 1.04]:
			var np := p.duplicate()
			for g in ativos:
				var vs: Array = viz[g]
				if vs.is_empty():
					continue
				var s := Vector3.ZERO
				for o in vs:
					s += p[o]
				np[g] = p[g] + (s / vs.size() - p[g]) * float(fator) * mascara[g]
			p = np
	var g0 := ativos[ativos.size() / 2]
	# volta para a pose de descanso
	var ids := PackedInt32Array()
	var dif := PackedVector3Array()
	var maior := 0.0
	for i in n:
		var g := grupo[i]
		if mascara[g] <= 0.01:
			continue
		var t: Transform3D = blend[g]
		if absf(t.basis.determinant()) < 1e-15:
			continue
		var r := t.affine_inverse() * p[g]
		var d := r - v[i]
		if d.length() < 1e-5:
			continue
		ids.append(i)
		dif.append(d)
		maior = maxf(maior, d.length())
	var fa := FileAccess.open(saida, FileAccess.WRITE)
	fa.store_var({"n": n, "i": ids, "d": dif})
	fa.close()
	print("CORRETIVO ", corpo, " vertices=", n, " mexidos=", ids.size(), " maior=", snappedf(maior, 0.0001), " -> ", saida)
	feito = true
