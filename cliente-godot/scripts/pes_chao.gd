extends SkeletonModifier3D
# Pés no chão em qualquer cenário (pedido de Robson 22/11): cada pé procura o piso embaixo dele (terra, calçada,
# ponte, plataforma, escada) e a perna se ajusta com IK de dois ossos (coxa e canela), dobrando o joelho do pé
# que está mais alto na encosta. O corpo desce até o pé mais baixo (Character._chao) e este modificador sobe o
# outro. O pé no ar da passada não é puxado para baixo; só é empurrado para cima se for entrar no chão.
# Roda depois das posturas e antes da pegada das armas (não mexe em braços).

var dono: Node3D
var peso := 1.0
var _ids := {}
var _suave := {"l": 0.0, "r": 0.0}

const MAX_SOBE := 0.4
const MAX_DESCE := 0.3


func _ossos(sk: Skeleton3D, lado: String) -> Array:
	if not _ids.has(lado):
		_ids[lado] = [sk.find_bone("thigh_" + lado), sk.find_bone("calf_" + lado), sk.find_bone("foot_" + lado)]
	return _ids[lado]


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or dono == null or peso <= 0.001:
		return
	var mundo = dono.get("world_ref")
	var tornozelo: float = dono.get("ankle") if dono.get("ankle") != null else -1.0
	if mundo == null or tornozelo < 0.0 or not dono.visible:
		return
	var xf := sk.global_transform
	var inv := xf.affine_inverse()
	var raiz_y: float = dono.global_position.y
	var dados := {}
	var mais_baixo := 1e9
	for lado in ["l", "r"]:
		var ids := _ossos(sk, lado)
		if ids[0] < 0 or ids[1] < 0 or ids[2] < 0:
			return
		var pe: Vector3 = xf * sk.get_bone_global_pose(ids[2]).origin
		var chao := float(mundo.floor_y(pe.x, pe.z, raiz_y + 0.5))
		if absf(chao - raiz_y) > 0.9:
			chao = raiz_y  # interior de casa ou ponte alta sem piso do mundo: vale a própria raiz
		dados[lado] = [pe, chao + tornozelo]
		mais_baixo = minf(mais_baixo, pe.y - raiz_y)
	for lado in ["l", "r"]:
		var pe: Vector3 = dados[lado][0]
		var quer: float = dados[lado][1]
		var dy := quer - pe.y
		var apoiado := (pe.y - raiz_y) <= mais_baixo + 0.12
		if not apoiado and dy < 0.0:
			dy = 0.0  # pé no ar da passada: deixa a animação
		dy = clampf(dy, -MAX_DESCE, MAX_SOBE)
		_suave[lado] = lerpf(float(_suave[lado]), dy, clampf(delta * 18.0, 0.0, 1.0))
		var d: float = _suave[lado] * peso
		if absf(d) < 0.002:
			continue
		var ids := _ossos(sk, lado)
		var rot_pe := sk.get_bone_global_pose(ids[2]).basis
		var quadril := sk.get_bone_global_pose(ids[0]).origin
		var joelho := sk.get_bone_global_pose(ids[1]).origin
		var pe_sk := sk.get_bone_global_pose(ids[2]).origin
		var alvo := inv * (pe + Vector3(0, d, 0))
		# polo: mantém o plano atual do joelho (joelho para a frente)
		var meio := (quadril + pe_sk) * 0.5
		var polo := joelho + (joelho - meio).normalized() * 0.5
		_ik(sk, [ids[0], ids[1], ids[2]], alvo, polo)
		# a sola acompanha a inclinação do piso embaixo dela (pé apoiado), sem deixar a ponta entrar no chão
		if apoiado:
			var e := 0.25
			var hx := float(mundo.floor_y(pe.x + e, pe.z, raiz_y + 0.5)) - float(mundo.floor_y(pe.x - e, pe.z, raiz_y + 0.5))
			var hz := float(mundo.floor_y(pe.x, pe.z + e, raiz_y + 0.5)) - float(mundo.floor_y(pe.x, pe.z - e, raiz_y + 0.5))
			var n_mundo := Vector3(-hx, 2.0 * e, -hz).normalized()
			var n := (inv.basis * n_mundo).normalized()
			var cima := (inv.basis * Vector3.UP).normalized()
			if n.angle_to(cima) < 0.6:
				rot_pe = Basis(Quaternion(cima, n).slerp(Quaternion.IDENTITY, 0.25)) * rot_pe
		var pai := sk.get_bone_parent(ids[2])
		var pg := sk.get_bone_global_pose(pai).basis
		sk.set_bone_pose_rotation(ids[2], (pg.inverse() * rot_pe).get_rotation_quaternion())


func _gira(sk: Skeleton3D, b: int, de: Vector3, para: Vector3) -> void:
	if de.length() < 1e-5 or para.length() < 1e-5:
		return
	var gp := sk.get_bone_global_pose(b)
	var nova := Basis(Quaternion(de.normalized(), para.normalized())) * gp.basis
	var pai := sk.get_bone_parent(b)
	var pb := sk.get_bone_global_pose(pai).basis if pai >= 0 else Basis()
	sk.set_bone_pose_rotation(b, (pb.inverse() * nova).get_rotation_quaternion())


func _ik(sk: Skeleton3D, ids: Array, t: Vector3, p: Vector3) -> void:
	var a := sk.get_bone_global_pose(ids[0]).origin
	var b := sk.get_bone_global_pose(ids[1]).origin
	var c := sk.get_bone_global_pose(ids[2]).origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var dv := t - a
	var d := clampf(dv.length(), absf(l1 - l2) + 1e-4, (l1 + l2) * 0.999)
	var dir := dv.normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var perp := p - a
	perp = perp - dir * perp.dot(dir)
	if perp.length() < 1e-5:
		perp = (b - a) - dir * (b - a).dot(dir)
	if perp.length() < 1e-5:
		return
	perp = perp.normalized()
	var joelho := a + dir * (l1 * cos_a) + perp * (l1 * sqrt(1.0 - cos_a * cos_a))
	_gira(sk, ids[0], b - a, joelho - a)
	b = sk.get_bone_global_pose(ids[1]).origin
	c = sk.get_bone_global_pose(ids[2]).origin
	_gira(sk, ids[1], c - b, (a + dir * d) - b)
