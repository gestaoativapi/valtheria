extends SceneTree
# Mede a pegada: distância da palma de cada mão até o ponto do cabo onde ela deveria estar.
# Uso: godot --headless -s teste/medir_pegada.gd -- raca:genero:arma:armadura[:escudo],...
var q := 0
var bonecos := []
var lista := "humano:m:espadao_ng:pesada_ng,humano:m:martelo_ng:pesada_ng,humano:m:cajado_ng:robe_ng,humano:m:lanca_ng:pesada_ng,humano:m:machado_ng:pesada_ng,humano:m:espada_ng:pesada_ng:escudo_ng"

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lista="):
			lista = a.trim_prefix("--lista=")

# posição final do osso (depois do IK e das posturas): lida por BoneAttachment, como a arma
func _osso(c, nome: String) -> Vector3:
	var chave := "_att_" + nome
	if not c.has_meta(chave):
		var a := BoneAttachment3D.new()
		a.bone_name = nome
		c.skel.add_child(a)
		c.set_meta(chave, a)
		return Vector3.ZERO
	return (c.get_meta(chave) as Node3D).global_position

func _palma(c, lado: String) -> Vector3:
	return (_osso(c, "hand_" + lado) + _osso(c, "middle_01_" + lado)) * 0.5

func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		var C = load("res://scripts/character.gd")
		var itens := lista.split(",")
		for i in itens.size():
			var p := itens[i].split(":")
			var eq := {"armadura": p[3]}
			eq["arma"] = p[2]
			if p.size() > 4:
				eq["escudo"] = p[4]
			var c = C.create({"race": p[0], "gender": p[1], "equipment": eq})
			root.add_child(c)
			c.position = Vector3(i * 3.0, 0, 0)
			c.em_guarda = true
			c.play("Idle")
			bonecos.append([itens[i], c])
	if q == 30:
		for par in bonecos:
			for n in ["hand_r", "hand_l", "middle_01_r", "middle_01_l", "lowerarm_l", "upperarm_l"]:
				_osso(par[1], n)
	if q == 40:
		for par in bonecos:
			var c = par[1]
			var w: Node3D = c.wnode
			var linha := str(par[0]) + ": guarda=" + str(c.guard_on)
			for lado in ["r", "l"]:
				var pm := _palma(c, lado)
				var alvo = null
				if lado == "r" and w != null:
					alvo = c.grip_node.global_position if c.guard == null or not c.guard_on else c.guard.global_position
				elif lado == "l" and c.guard != null:
					# ponto do cabo onde a mão esquerda deve fechar (sem o recuo do alvo do IK)
					var g: Dictionary = c.GRIP[c.arma_kind] if "arma_kind" in c else {}
					var kind := str(par[0]).split(":")[2].get_slice("_", 0)
					g = c.GRIP[kind]
					var sc := lerpf(1.0, c.height_m / 1.8, 0.85)
					var d := -(float(g.at) - float(g.two)) * sc
					if c.guard_on:
						alvo = c.guard.global_transform * Vector3(0, 0, d)
						var omb := _osso(c, "upperarm_l")
						var braco := omb.distance_to(_osso(c, "lowerarm_l")) + _osso(c, "lowerarm_l").distance_to(_osso(c, "hand_l"))
						linha += " [ombro->cabo %.0fcm, braço %.0fcm, alvoIK->ombro %.0fcm]" % [omb.distance_to(alvo) * 100, braco * 100, omb.distance_to(c._alvo_mao["l"].global_position) * 100]
					else:
						alvo = c.mao_l_golpe.global_position
				if lado == "l" and not c._alvo_mao.is_empty() and c.guard_on:
					var pt: Vector3 = c._alvo_mao["l"].global_position - c._corr_mao["l"]
					var gt: Transform3D = c.guard.global_transform
					var dist_eixo := (pt - gt.origin) - gt.basis.z.normalized() * gt.basis.z.normalized().dot(pt - gt.origin)
					linha += "  [mão esq. a %.0fcm da da frente; ponto fora do cabo %.0fcm]" % [pt.distance_to(gt.origin) * 100, dist_eixo.length() * 100]
					alvo = pt
				if alvo != null:
					linha += "  palma_%s->cabo=%.0fcm" % [lado, pm.distance_to(alvo) * 100.0]
				else:
					linha += "  palma_%s livre" % lado
			if c.shield != null:
				var ant := (_osso(c, "lowerarm_l") + _osso(c, "hand_l")) * 0.5
				linha += "  escudo->antebraco=%.0fcm" % (c.shield.global_position.distance_to(ant) * 100.0)
			print(linha)
		quit()
	return false
