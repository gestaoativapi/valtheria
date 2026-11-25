extends SceneTree
# Mede a postura final (depois de todos os ajustes) de cada raça: inclinação do tronco (pelve -> peito) e do
# pescoço/cabeça (peito -> cabeça) em graus, + = para a frente. Lê ossos por BoneAttachment3D (pose final).
# uso: -s teste/medir_postura.gd -- [--lista=raca:g,...] [--anim=Idle] [--combate]
var q := 0
var bonecos := []
var marcas := []
var anim := "Idle"
var combate := false
var lista := "humano:m,humano:f,elfo:m,elfo:f,sombrio:m,sombrio:f,anao:m,anao:f,orc:m,orc:f,orc:m:goblin,gigante:m,gigante:f,beastman:m,beastman:f,draconato:m,draconato:f"
var acum := {}

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--anim="): anim = a.trim_prefix("--anim=")
		elif a.begins_with("--lista="): lista = a.trim_prefix("--lista=")
		elif a == "--combate": combate = true

func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		var C = load("res://scripts/character.gd")
		var i := 0
		for it in lista.split(","):
			var p := it.split(":")
			var o := {"race": p[0], "gender": p[1], "equipment": {"armadura": "pesada_ng", "arma": "espada_ng"}}
			if p.size() > 2: o["subtipo"] = p[2]
			var c: Node3D = C.create(o)
			root.add_child(c)
			c.position = Vector3(i * 3.0, 0, 0)
			c.set_battle(combate)
			bonecos.append([it, c])
			var m := {}
			for b in ["pelvis", "spine_03", "Head", "upperarm_l", "hand_l", "upperarm_r", "hand_r"]:
				var at := BoneAttachment3D.new()
				at.bone_name = b
				c.skel.add_child(at)
				m[b] = at
			marcas.append(m)
			i += 1
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.position = Vector3(0, 1, 5)
		cam.current = true
	elif q >= 2:
		for b in bonecos:
			b[1].play(anim)
	if q > 30 and q <= 90:
		for k in bonecos.size():
			var c: Node3D = bonecos[k][1]
			var m: Dictionary = marcas[k]
			var inv := c.global_transform.affine_inverse()
			var pel: Vector3 = inv * (m.pelvis as Node3D).global_position
			var pei: Vector3 = inv * (m.spine_03 as Node3D).global_position
			var cab: Vector3 = inv * (m.Head as Node3D).global_position
			var t := rad_to_deg(atan2(pei.z - pel.z, pei.y - pel.y))
			var h := rad_to_deg(atan2(cab.z - pei.z, cab.y - pei.y))
			var abre := 0.0
			for lado in ["l", "r"]:
				var o3: Vector3 = inv * (m["upperarm_" + lado] as Node3D).global_position
				var mao: Vector3 = inv * (m["hand_" + lado] as Node3D).global_position
				abre += rad_to_deg(atan2(absf(mao.x - o3.x), o3.y - mao.y)) * 0.5
			# olhar: para onde o rosto aponta (rotação da cabeça em relação ao repouso), + = olhando para baixo
			var sk: Skeleton3D = c.skel
			var hi := sk.find_bone("Head")
			var rr := (inv.basis * sk.global_basis * sk.get_bone_global_rest(hi).basis).orthonormalized()
			var ra := (inv.basis * (m.Head as Node3D).global_basis).orthonormalized()
			var fw := (ra * rr.inverse()) * Vector3(0, 0, 1)
			var olhar := rad_to_deg(atan2(-fw.y, Vector2(fw.x, fw.z).length()))
			var a: Array = acum.get(k, [0.0, 0.0, 0.0, 0, 0.0])
			acum[k] = [a[0] + t, a[1] + h, a[2] + abre, a[3] + 1, a[4] + olhar]
	if q == 91:
		for k in bonecos.size():
			var a: Array = acum[k]
			print("POSTURA %-18s %-8s tronco %5.1f  cabeca %5.1f  bracos %5.1f  olhar %5.1f" % [bonecos[k][0], anim + ("+c" if combate else ""), a[0] / a[3], a[1] / a[3], a[2] / a[3], a[4] / a[3]])
		quit()
	return false
