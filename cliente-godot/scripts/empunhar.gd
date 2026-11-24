class_name Empunhar
extends SkeletonModifier3D
# Leva a mão até o cabo da arma e alinha a palma com ele (IK de dois ossos + giro da mão).
# A arma continua presa à mão: com peso 1 a pegada da mão cai exatamente no quadro do alvo,
# então não há troca de pai nem salto quando o golpe (animação) assume e o peso volta a 0.
# Serve para todas as raças: comprimentos e ombros são lidos do próprio esqueleto a cada quadro.

var alvo := {}      # lado -> Node3D: quadro desejado da pegada (+Z = lâmina, +Y = para o pulso)
var polo := {}      # lado -> Node3D: para onde aponta o cotovelo
var pegada := {}    # lado -> Node3D: ponto de pegada preso à mão (o mesmo onde a arma está presa)
var peso := {"r": 0.0, "l": 0.0}
var meta := {"r": 0.0, "l": 0.0}
var velocidade := 5.0
var _ids := {}
# quanto o punho pode dobrar em relação ao antebraço: firme em combate; solto (arma pendendo) fora dele
var punho_max := deg_to_rad(22.0)


func _ossos(sk: Skeleton3D, lado: String) -> Array:
	if not _ids.has(lado):
		_ids[lado] = [sk.find_bone("upperarm_" + lado), sk.find_bone("lowerarm_" + lado), sk.find_bone("hand_" + lado)]
	return _ids[lado]


func _process_modification_with_delta(delta: float) -> void:
	var __t := Time.get_ticks_usec()
	_pm_corpo(delta)
	preload("res://scripts/perfil.gd").soma("esq_empunhar", Time.get_ticks_usec() - __t)


func _pm_corpo(delta: float) -> void:
	var sk := get_skeleton()
	if sk != null and sk.get_meta("lod_longe", false):  # longe da câmera: ajuste fino desligado (economiza CPU)
		return
	if sk == null:
		return
	var inv := sk.global_transform.affine_inverse()
	for lado in alvo:
		peso[lado] = move_toward(float(peso[lado]), float(meta.get(lado, 0.0)), delta * velocidade)
		var w: float = peso[lado]
		if w <= 0.001 or not is_instance_valid(alvo[lado]) or not is_instance_valid(pegada[lado]):
			continue
		var ids: Array = _ossos(sk, lado)
		if ids[0] < 0 or ids[1] < 0 or ids[2] < 0:
			continue
		var g: Transform3D = (pegada[lado] as Node3D).transform  # pegada no espaço do osso da mão
		var a: Transform3D = inv * (alvo[lado] as Node3D).global_transform
		a.basis = a.basis.orthonormalized()
		var hand_g := sk.get_bone_global_pose(ids[2])
		var esc := hand_g.basis.get_scale()
		var p_polo: Vector3 = inv * (polo[lado] as Node3D).global_position
		var rot := (a.basis * g.basis.inverse()).orthonormalized()
		var mao := Basis(rot.x * esc.x, rot.y * esc.y, rot.z * esc.z)
		var pulso := a.origin - mao * g.origin
		_ik(sk, ids, pulso, p_polo, w)
		# punho natural (pedido de Robson 24/11 12:07: "o punho parece desproporcional"): a mão continua o
		# antebraço e só dobra até punho_max; o resto da inclinação vai para a arma (que gira junto com a mão)
		var ante: Vector3 = sk.get_bone_global_pose(ids[1]).origin - sk.get_bone_global_pose(ids[2]).origin
		var y: Vector3 = a.basis.y
		if ante.length() > 1e-5:
			ante = ante.normalized()
			var ang := y.angle_to(ante)
			if ang > punho_max:
				var eixo := y.cross(ante)
				if eixo.length() > 1e-5:
					a.basis = Basis(eixo.normalized(), ang - punho_max) * a.basis
					rot = (a.basis * g.basis.inverse()).orthonormalized()
					mao = Basis(rot.x * esc.x, rot.y * esc.y, rot.z * esc.z)
					pulso = a.origin - mao * g.origin
					_ik(sk, ids, pulso, p_polo, w)
		# palma no cabo
		var pai := sk.get_bone_parent(ids[2])
		var pg := sk.get_bone_global_pose(pai)
		var q := (pg.basis.inverse() * mao).get_rotation_quaternion()
		sk.set_bone_pose_rotation(ids[2], sk.get_bone_pose_rotation(ids[2]).slerp(q, w))


func _gira(sk: Skeleton3D, b: int, de: Vector3, para: Vector3, w: float) -> void:
	if de.length() < 1e-5 or para.length() < 1e-5:
		return
	var gp := sk.get_bone_global_pose(b)
	var nova := Basis(Quaternion(de.normalized(), para.normalized())) * gp.basis
	var pai := sk.get_bone_parent(b)
	var pb := sk.get_bone_global_pose(pai).basis if pai >= 0 else Basis()
	var q := (pb.inverse() * nova).get_rotation_quaternion()
	sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(q, w))


func _ik(sk: Skeleton3D, ids: Array, t: Vector3, p: Vector3, w: float) -> void:
	var a := sk.get_bone_global_pose(ids[0]).origin
	var b := sk.get_bone_global_pose(ids[1]).origin
	var c := sk.get_bone_global_pose(ids[2]).origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var dv := t - a
	var d := clampf(dv.length(), absf(l1 - l2) + 1e-4, (l1 + l2) * 0.9995)
	var dir := dv.normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var perp := p - a
	perp = perp - dir * perp.dot(dir)
	if perp.length() < 1e-5:
		perp = (b - a) - dir * (b - a).dot(dir)
	perp = perp.normalized()
	var cotovelo := a + dir * (l1 * cos_a) + perp * (l1 * sqrt(1.0 - cos_a * cos_a))
	_gira(sk, ids[0], b - a, cotovelo - a, w)
	b = sk.get_bone_global_pose(ids[1]).origin
	c = sk.get_bone_global_pose(ids[2]).origin
	_gira(sk, ids[1], c - b, (a + dir * d) - b, w)
