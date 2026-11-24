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
var _ref := {}  # lado -> [média lenta da mão animada, média do antebraço animado]
var segue_peito := 0.0  # 0..1: quanto a pose gira junto com o peito (arma no ombro)
var balanco := 1.0  # quanto do balanço da animação a arma acompanha (1 = todo)
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
	var esc_sk := sk.global_transform.basis.get_scale().x
	for lado in alvo:
		peso[lado] = move_toward(float(peso[lado]), float(meta.get(lado, 0.0)), delta * velocidade)
		var w: float = peso[lado]
		var ids: Array = _ossos(sk, lado)
		if ids[0] < 0 or ids[1] < 0 or ids[2] < 0 or not is_instance_valid(alvo[lado]) or not is_instance_valid(pegada[lado]):
			continue
		var hand_g := sk.get_bone_global_pose(ids[2])
		# a arma acompanha o corpo (pedido de Robson 24/11): o balanço que a animação dá à mão e ao antebraço é somado
		# à pose da pegada. Referência = média lenta da própria animação (atualizada sempre, também no golpe, para não
		# dar salto quando ele acaba). Limites (24/11 14:38, "o braço roda até entrar no corpo"): o desvio tem teto,
		# não puxa a mão para dentro do corpo e o giro do antebraço entra só pela metade e até 20 graus.
		var mao_anim: Vector3 = hand_g.origin
		var ante_anim: Vector3 = (hand_g.origin - sk.get_bone_global_pose(ids[1]).origin).normalized()
		if not _ref.has(lado):
			_ref[lado] = [mao_anim, ante_anim]
		var ref: Array = _ref[lado]
		var k_ref := clampf(delta * 1.6, 0.0, 1.0)
		ref[0] = (ref[0] as Vector3).lerp(mao_anim, k_ref)
		ref[1] = (ref[1] as Vector3).lerp(ante_anim, k_ref).normalized()
		if w > 0.001:
			var g: Transform3D = (pegada[lado] as Node3D).transform  # pegada no espaço do osso da mão
			var a: Transform3D = inv * (alvo[lado] as Node3D).global_transform
			a.basis = a.basis.orthonormalized()
			var esc := hand_g.basis.get_scale()
			var p_polo: Vector3 = inv * (polo[lado] as Node3D).global_position
			# arma apoiada no ombro (machado): a pose acompanha a inclinação do peito, girando em volta do ombro,
			# para continuar no ombro quando o tronco se curva (orc correndo); antes ela deitava para trás
			if segue_peito > 0.0:
				var b3 := sk.find_bone("spine_03")
				if b3 >= 0:
					var gp := sk.get_bone_global_pose(b3).basis.orthonormalized()
					var gr := sk.get_bone_global_rest(b3).basis.orthonormalized()
					var rq := Quaternion.IDENTITY.slerp((gp * gr.inverse()).get_rotation_quaternion(), segue_peito)
					var om := sk.get_bone_global_pose(ids[0]).origin
					a.origin = om + Basis(rq) * (a.origin - om)
					a.basis = Basis(rq) * a.basis
					p_polo = om + Basis(rq) * (p_polo - om)
			var desvio: Vector3 = (mao_anim - (ref[0] as Vector3)) * balanco
			var centro := _eixo_corpo(sk, a.origin)
			var radial := a.origin - centro
			radial.y = 0.0
			if radial.length() > 1e-4 and desvio.dot(radial.normalized()) < 0.0:
				desvio -= radial.normalized() * desvio.dot(radial.normalized())  # nunca para dentro do corpo
			desvio = desvio.limit_length(DESVIO_MAX / maxf(esc_sk, 1e-4))
			a.origin += desvio
			p_polo += desvio
			if (ref[1] as Vector3).length() > 0.5:
				var giro := Quaternion(ref[1] as Vector3, ante_anim)
				var ang_g := giro.get_angle()
				if ang_g > 1e-4:
					var k_g := minf(balanco * 0.5, GIRO_MAX / ang_g)
					a.basis = Basis(Quaternion.IDENTITY.slerp(giro, k_g)) * a.basis
			a = _fora_do_corpo(sk, a, esc_sk)
			var rot := (a.basis * g.basis.inverse()).orthonormalized()
			var mao := Basis(rot.x * esc.x, rot.y * esc.y, rot.z * esc.z)
			var pulso := a.origin - mao * g.origin
			_ik(sk, ids, pulso, p_polo, w)
			# punho natural: a mão continua o antebraço e só dobra até punho_max; o resto vai para a arma
			var ante: Vector3 = sk.get_bone_global_pose(ids[1]).origin - sk.get_bone_global_pose(ids[2]).origin
			var y: Vector3 = a.basis.y
			if ante.length() > 1e-5:
				ante = ante.normalized()
				var ang := y.angle_to(ante)
				if ang > punho_max:
					var eixo := y.cross(ante)
					if eixo.length() > 1e-5:
						a.basis = Basis(eixo.normalized(), ang - punho_max) * a.basis
						a = _fora_do_corpo(sk, a, esc_sk)
						rot = (a.basis * g.basis.inverse()).orthonormalized()
						mao = Basis(rot.x * esc.x, rot.y * esc.y, rot.z * esc.z)
						pulso = a.origin - mao * g.origin
						_ik(sk, ids, pulso, p_polo, w)
			# palma no cabo
			var pai := sk.get_bone_parent(ids[2])
			var pg := sk.get_bone_global_pose(pai)
			var q := (pg.basis.inverse() * mao).get_rotation_quaternion()
			sk.set_bone_pose_rotation(ids[2], sk.get_bone_pose_rotation(ids[2]).slerp(q, w))
		# no golpe (e na transição) a animação manda; aqui só se tira a mão e a lâmina de dentro do corpo
		if w < 0.999 and not capsulas.is_empty():
			_golpe_fora_do_corpo(sk, ids, lado, esc_sk)


# ---------- o corpo como cápsulas (medidas na malha de cada raça; ver character.gd _capsulas) ----------
var capsulas: Array = []      # [osso_a, osso_b, raio] no espaço do esqueleto
var lamina := 1.0             # comprimento da arma a partir da mão (metros)
var largura := 0.03            # meia-largura da cabeça/lâmina (machado é largo), vale na ponta
var cabo := 0.1               # comprimento do cabo atrás da mão (pomo), também não pode entrar no corpo
const DESVIO_MAX := 0.12      # metros que o balanço pode afastar a mão da pose
const GIRO_MAX := deg_to_rad(20.0)
const GIRO_FORA_MAX := deg_to_rad(35.0)
var correcoes_mao := 0
var residuo_mao := 0.0
var correcoes_lamina := 0
const FOLGA := 0.03           # metros de folga entre arma/mão e o corpo


func _eixo_corpo(sk: Skeleton3D, p: Vector3) -> Vector3:
	if capsulas.is_empty():
		return Vector3(0, p.y, 0)
	var c: Array = capsulas[0]
	var a := sk.get_bone_global_pose(c[0]).origin
	var b := sk.get_bone_global_pose(c[1]).origin
	return _ponto_seg(p, a, b)


static func _ponto_seg(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return a + ab * t


# empurra para fora: quanto o ponto p está dentro da cápsula mais funda (vetor de saída) ou zero
func _saida(sk: Skeleton3D, p: Vector3, folga: float) -> Vector3:
	var melhor := Vector3.ZERO
	for c in capsulas:
		var a := sk.get_bone_global_pose(c[0]).origin
		var b := sk.get_bone_global_pose(c[1]).origin
		if c.size() > 3 and float(c[3]) > 0.0:
			b += (b - a).normalized() * float(c[2]) * float(c[3])
		var q := _ponto_seg(p, a, b)
		var d := p - q
		var dentro: float = float(c[2]) + folga - d.length()
		if dentro > melhor.length():
			melhor = (d.normalized() if d.length() > 1e-5 else Vector3.RIGHT) * dentro
	return melhor


# pegada fora do corpo e lâmina girada para fora quando passaria por dentro (tronco, peito, cabeça, coxas)
func _fora_do_corpo(sk: Skeleton3D, a: Transform3D, esc_sk: float) -> Transform3D:
	if capsulas.is_empty():
		return a
	var folga := FOLGA / maxf(esc_sk, 1e-4)
	a.origin += _saida(sk, a.origin, folga * 2.0)
	var L := lamina / maxf(esc_sk, 1e-4)
	var C := cabo / maxf(L * esc_sk, 1e-4)  # cabo em fração da lâmina (pontos com t negativo)
	var girado := 0.0
	for _i in 6:
		var pior := Vector3.ZERO
		var t_pior := 0.0
		for t in [-C, -C * 0.5, 0.1, 0.25, 0.45, 0.65, 0.85, 1.0]:
			var s := _saida(sk, a.origin + a.basis.z * L * t, folga + (largura / maxf(esc_sk, 1e-4) if t > 0.6 else 0.0))
			if s.length() > pior.length():
				pior = s
				t_pior = t
		if pior.length() < 1e-5:
			break
		var z := a.basis.z
		var nz := (z * L * t_pior + pior * 1.6).normalized()
		var q := Quaternion(z, nz)
		# girar demais vira a arma de cabeça para baixo (24/11): até 35 graus no total; o que faltar, a mão se afasta
		if girado + q.get_angle() > GIRO_FORA_MAX:
			a.origin += pior * 1.1
			continue
		girado += q.get_angle()
		a.basis = Basis(q) * a.basis
	return a


func _golpe_fora_do_corpo(sk: Skeleton3D, ids: Array, lado: String, esc_sk: float) -> void:
	var h := sk.get_bone_global_pose(ids[2])
	var folga := FOLGA / maxf(esc_sk, 1e-4)
	for _i in 4:
		var palma := h.origin
		if pegada.has(lado) and is_instance_valid(pegada[lado]):
			palma = h * (pegada[lado] as Node3D).transform.origin
		var s := _saida(sk, palma, folga * 1.5)
		if s.length() < 1e-5:
			break
		correcoes_mao += 1
		var rot_mao := h.basis
		_ik(sk, ids, h.origin + s * 1.15, sk.get_bone_global_pose(ids[1]).origin + s, 1.0)
		var pai := sk.get_bone_parent(ids[2])
		var pg := sk.get_bone_global_pose(pai)
		sk.set_bone_pose_rotation(ids[2], (pg.basis.inverse() * rot_mao).get_rotation_quaternion())
		h = sk.get_bone_global_pose(ids[2])
	if pegada.has(lado) and is_instance_valid(pegada[lado]):
		residuo_mao = maxf(residuo_mao, _saida(sk, h * (pegada[lado] as Node3D).transform.origin, 0.0).length())
	# lâmina: se passaria por dentro do corpo, o punho gira o bastante para ela sair por fora
	if not pegada.has(lado) or not is_instance_valid(pegada[lado]):
		return
	var g: Transform3D = (pegada[lado] as Node3D).transform
	var L := lamina / maxf(esc_sk, 1e-4)
	var C := cabo / maxf(L * esc_sk, 1e-4)
	for _i in 5:
		h = sk.get_bone_global_pose(ids[2])
		var base := h * g
		var z := base.basis.z.normalized()
		var pior := Vector3.ZERO
		var t_pior := 0.0
		for t in [-C, 0.08, 0.18, 0.3, 0.55, 0.8, 1.0]:
			var sa := _saida(sk, base.origin + z * L * t, folga + (largura / maxf(esc_sk, 1e-4) if t > 0.6 else 0.0))
			if sa.length() > pior.length():
				pior = sa
				t_pior = t
		if pior.length() < 1e-5:
			return
		correcoes_lamina += 1
		var nz := (z * L * t_pior + pior * 1.6).normalized()
		var giro := Basis(Quaternion(z, nz))
		var pai2 := sk.get_bone_parent(ids[2])
		var pg2 := sk.get_bone_global_pose(pai2)
		sk.set_bone_pose_rotation(ids[2], (pg2.basis.inverse() * (giro * h.basis)).get_rotation_quaternion())


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
