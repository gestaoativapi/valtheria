extends SceneTree
# Passada natural dos monstros de modelo próprio (lobo, aranha, lagarto e golem): modelo com 1 m de altura,
# animação no ritmo 1, parado no lugar; grava a posição dos ossos mais baixos (pés/patas) para
# /tmp/passada_mob.json. O cálculo da velocidade sem escorregar fica em ferramentas/passada_otima.py.
# uso: --fixed-fps 60 -s teste/medir_passada_mob.gd

const MODELOS := [["m_wolf", "glb"], ["e_spider", "glb"], ["z_raptor", "glb"], ["golem", "criatura"]]
var itens: Array = []
var q := 0
const QUADROS := 300
var dados := {}


func _anim(ap: AnimationPlayer, what: String) -> String:
	var want: Array = {"walk": ["Walk"], "run": ["Gallop", "Run", "Walk"]}[what]
	for n in want:
		if ap.has_animation(n):
			return n
	for n in ap.get_animation_list():
		if String(n).to_lower().contains(what):
			return n
	return ""


func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		var i := 0
		for m in MODELOS:
			var node: Node3D
			var ap: AnimationPlayer
			if m[1] == "glb":
				node = (load("res://assets/world/%s.glb" % m[0]) as PackedScene).instantiate()
				var bb := AABB()
				var first := true
				for mi in node.find_children("*", "MeshInstance3D", true, false):
					var a: AABB = (mi as MeshInstance3D).get_aabb()
					bb = a if first else bb.merge(a)
					first = false
				node.scale = Vector3.ONE / maxf(bb.size.y, 0.01)
				ap = node.find_child("AnimationPlayer", true, false)
			else:
				node = load("res://scripts/criatura.gd").criar(m[0], 1.0)
				node.scale *= 1.0 / maxf(float(node.altura), 0.01)
			root.add_child(node)
			if m[1] != "glb":
				ap = node.ap
			node.position = Vector3(i * 5.0, 0, 0)
			var sk: Skeleton3D = node.find_child("*", true, false) as Skeleton3D
			for s in node.find_children("*", "Skeleton3D", true, false):
				sk = s
			# ossos mais baixos em repouso = pés/patas
			var ys := []
			for b in sk.get_bone_count():
				ys.append((sk.global_transform * sk.get_bone_global_rest(b).origin).y)
			var lo: float = ys.min()
			var hi: float = ys.max()
			var pes := []
			var filhos := {}
			for b in sk.get_bone_count():
				filhos[sk.get_bone_parent(b)] = true
			for b in sk.get_bone_count():
				var lim := 0.12 if m[0] in ["m_wolf", "golem"] else 0.3
				if float(ys[b]) <= lo + (hi - lo) * lim and (m[0] in ["m_wolf", "golem"] or not filhos.has(b)):
					var at := BoneAttachment3D.new()
					at.bone_name = sk.get_bone_name(b)
					sk.add_child(at)
					pes.append(at)
			print("PES ", m[0], " ", pes.map(func(a): return a.bone_name))
			itens.append({"nome": m[0], "node": node, "ap": ap, "pes": pes})
			i += 1
		return false
	if q < 5:
		return false
	var k := q - 5
	var ai := k / (QUADROS + 20)
	var f := k % (QUADROS + 20)
	if ai >= 2:
		var fa := FileAccess.open("/tmp/passada_mob.json", FileAccess.WRITE)
		fa.store_string(JSON.stringify(dados))
		fa.close()
		print("PASSADA_MOB ok ", dados.keys())
		quit()
		return true
	var what: String = ["walk", "run"][ai]
	for it in itens:
		var ap: AnimationPlayer = it.ap
		var an := _anim(ap, what)
		if an == "":
			continue
		if f == 0:
			ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
			ap.play(an, 0.0)
			ap.speed_scale = 1.0
		if f < 20:
			continue
		var chave: String = it.nome + "|" + what
		if not dados.has(chave):
			dados[chave] = {"anim": an, "pes": []}
			for p in it.pes:
				(dados[chave].pes as Array).append([])
		var base: Vector3 = (it.node as Node3D).global_position
		for j in (it.pes as Array).size():
			var p: Vector3 = (it.pes[j] as Node3D).global_position - base
			(dados[chave].pes[j] as Array).append([p.x, p.y, p.z])
	return false
