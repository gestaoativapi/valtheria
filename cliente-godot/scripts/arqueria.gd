extends Node3D
# Arco e flecha com movimento humano (20/11, Robson: "o arco e flecha continua errado"). Não há animação de arco no
# pacote, então a pose é montada por cinemática inversa (IK), igual para todas as raças, e se adapta sozinha ao
# tamanho de cada corpo (k = altura / 1,8 m; o IK estica ou dobra o braço até o alvo):
#   baixo   arco em pé na mão esquerda, apontado para o chão à frente do quadril (parado ou andando armado)
#   tiro    ergue o braço esquerdo esticado à frente na altura do ombro, a mão direita pega a corda, puxa até
#           o canto da boca (ancoragem), solta a flecha, segura um instante e volta a baixar
# A arma fica num suporte próprio (mira); as mãos vão até o arco, e não o contrário — por isso a pegada não
# depende da orientação dos ossos da mão de cada raça.

const DURACAO := 1.15
const ERGUER := 0.22
const PUXAR := 0.6
const SOLTAR := 0.62
const BAIXAR := 0.9

var c: Node3D           # o personagem (character.gd)
var k := 1.0
var mira: Node3D        # segura o arco: origem = ponto da empunhadura
var mao_arco: Node3D    # alvo da mão esquerda (na empunhadura)
var mao_corda: Node3D   # alvo da mão direita (corda)
var ik_l: SkeletonModifier3D
var ik_r: SkeletonModifier3D
var flecha: MeshInstance3D
var corda := Vector3.ZERO   # ponto de encaixe da flecha na corda, no espaço da mira
var t := -1.0
var ativo := false
var escala := 1.0
var pontas: Array = []   # pontas do arco (onde a corda prende), no espaço da mira
var cordas: Array = []   # dois segmentos de corda: retos em repouso, em "V" até a mão ao puxar


func montar_arco(arco: Node3D) -> void:
	var b := Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
	var pega := Vector3(-0.09, 0, 0) * escala
	if arco.get_parent() != null:
		arco.get_parent().remove_child(arco)
	mira.add_child(arco)
	arco.transform = Transform3D(b, -(b * pega))
	corda = b * (Vector3(0.16, 0, 0) * escala - pega)
	pontas = [b * (Vector3(0.16, 0, 0.64) * escala - pega), b * (Vector3(0.16, 0, -0.64) * escala - pega)]
	# esconde a corda do modelo (fica reta sempre) e desenha a nossa, que dobra quando puxada
	for mi in arco.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m != null and m.get_surface_count() >= 3:
			var oculto := StandardMaterial3D.new()
			oculto.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			oculto.albedo_color = Color(0, 0, 0, 0)
			(mi as MeshInstance3D).set_surface_override_material(2, oculto)
	if cordas.is_empty():
		var mc := StandardMaterial3D.new()
		mc.albedo_color = Color(0.92, 0.9, 0.84)
		mc.roughness = 0.6
		for i in 2:
			var seg := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0035
			cm.bottom_radius = 0.0035
			cm.height = 1.0
			cm.radial_segments = 4
			cm.rings = 1
			cm.material = mc
			seg.mesh = cm
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mira.add_child(seg)
			cordas.append(seg)
	_corda(corda)


func montar(personagem: Node3D, arco: Node3D, s: float) -> void:
	c = personagem
	k = float(c.height_m) / 1.8
	mira = Node3D.new()
	add_child(mira)
	# modelo do arco: comprimento em Z, corda em +X (x = 0,16), empunhadura em -X (x = -0,09). Em pé: Z -> cima;
	# corda virada para o arqueiro (-Z do personagem), barriga do arco para frente
	escala = s
	montar_arco(arco)
	mao_arco = Node3D.new()
	mira.add_child(mao_arco)
	mao_arco.position = Vector3(0.0, -0.01, -0.03) * k   # o pulso fica logo atrás e abaixo do centro da empunhadura
	mao_corda = Node3D.new()
	add_child(mao_corda)
	ik_l = c._arm_ik("l", mao_arco, Vector3(0.7, 0.6, -0.4) * k)
	ik_r = c._arm_ik("r", mao_corda, Vector3(-0.7, 1.55, -0.7) * k)
	# flecha: haste, ponta de ferro e penas
	flecha = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.006
	cm.bottom_radius = 0.006
	cm.height = 0.78 * k
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.55, 0.42, 0.28)
	cm.material = mt
	flecha.mesh = cm
	var ponta := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.0
	pm.bottom_radius = 0.014
	pm.height = 0.06
	var mf := StandardMaterial3D.new()
	mf.albedo_color = Color(0.3, 0.3, 0.32)
	mf.metallic = 0.8
	pm.material = mf
	ponta.mesh = pm
	ponta.position = Vector3(0, cm.height * 0.5 + 0.03, 0)
	flecha.add_child(ponta)
	var pena := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.002, 0.1, 0.03)
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color(0.85, 0.82, 0.76)
	bm.material = mp
	pena.mesh = bm
	pena.position = Vector3(0, -cm.height * 0.5 + 0.06, 0)
	flecha.add_child(pena)
	add_child(flecha)
	flecha.visible = false


func ligar(on: bool) -> void:
	ativo = on
	ik_l.active = on
	ik_r.active = on
	flecha.visible = on
	t = -1.0
	if c.postura != null:
		c.postura.bracos_livres = not on
	for seg in cordas:
		(seg as Node3D).visible = on
	if not on:
		_girar_corpo(0.0)
		# arco nas costas: volta a corda reta do próprio modelo (a nossa só existe na mão)
		if c.wnode != null:
			for mi in c.wnode.find_children("*", "MeshInstance3D", true, false):
				var m: Mesh = (mi as MeshInstance3D).mesh
				if m != null and m.get_surface_count() >= 3:
					(mi as MeshInstance3D).set_surface_override_material(2, null)


# devolve a duração do tiro; o personagem já deve estar virado para o alvo
func disparar() -> float:
	if not ativo:
		ligar(true)
	t = 0.0
	return DURACAO


func soltou() -> bool:
	return t >= SOLTAR


# ---------- pose de arqueiro, a mesma para todas as raças (21/11) ----------
# Tudo é medido no corpo de quem atira, a cada quadro: ombros, cabeça e comprimento do braço. Por isso o braço
# do arco fica sempre esticado na altura do ombro, a mão da corda sempre ancora no queixo e o corpo sempre gira de
# lado para o alvo, seja anão, gigante ou elfo. Em combate parado: arco baixo à frente, flecha encaixada (prontidão).
const GIRO_TIRO := 0.75     # corpo de lado: ombro esquerdo para o alvo
const GIRO_PRONTO := 0.45
var giro_base := 0.0
var giro_ok := false
var giro_atual := 0.0


func _osso(nome: String) -> Vector3:
	var sk: Skeleton3D = c.skel
	var b := sk.find_bone(nome)
	if b < 0:
		return Vector3.ZERO
	return c.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(b).origin)


func _braco() -> float:
	var sk: Skeleton3D = c.skel
	var a := sk.get_bone_global_rest(sk.find_bone("upperarm_l")).origin
	var m := sk.get_bone_global_rest(sk.find_bone("lowerarm_l")).origin
	var h := sk.get_bone_global_rest(sk.find_bone("hand_l")).origin
	var esc := (c.global_transform.affine_inverse() * sk.global_transform).basis.get_scale().x
	return (a.distance_to(m) + m.distance_to(h)) * esc


func _girar_corpo(w: float) -> void:
	var corpo: Node3D = c.body_node
	if corpo == null:
		return
	if not giro_ok:
		giro_base = corpo.rotation.y
		giro_ok = true
	giro_atual = w
	corpo.rotation.y = giro_base - w


# pontos da pose (espaço do personagem): empunhadura do arco e âncora da mão da corda
func _pontos() -> Dictionary:
	var L := _braco()
	var hs := L / 0.56          # escala do corpo pelo braço (braço humano ~0,56 m)
	var sh_l := _osso("upperarm_l")
	var sh_r := _osso("upperarm_r")
	var cab := _osso("Head")
	var ancora := Vector3(cab.x - 0.03 * hs, sh_l.y + 0.07 * hs, cab.z + 0.07 * hs)
	var gx := ancora.x + 0.025 * hs
	var gy := ancora.y - 0.015 * hs
	var dx := gx - sh_l.x
	var dy := gy - sh_l.y
	var alcance := 0.94 * L
	var gz := sh_l.z + sqrt(maxf(alcance * alcance - dx * dx - dy * dy, 0.01))
	var pronto := sh_l + Vector3(0.08, -0.72, 0.69).normalized() * L * 0.92
	return {"L": L, "hs": hs, "sh_l": sh_l, "sh_r": sh_r, "ancora": ancora, "mira": Vector3(gx, gy, gz), "pronto": pronto}


func _pose(w: float, pt: Dictionary) -> void:
	# w = 0: prontidão (arco baixo e inclinado, flecha apontada para o chão à frente); w = 1: mirando
	var pronto := Transform3D(Basis(Vector3.RIGHT, 0.55) * Basis(Vector3.BACK, -0.5), pt.pronto)
	var mirando := Transform3D(Basis(Vector3.BACK, -0.1), pt.mira)
	mira.transform = pronto.interpolate_with(mirando, clampf(w, 0.0, 1.0))
	_polos(pt)


var polo_l: Node3D
var polo_r: Node3D

func _polos(pt: Dictionary) -> void:
	# cotovelo do arco para fora (braço reto); cotovelo da corda alto e atrás, na linha da flecha
	if polo_l == null:
		polo_l = Node3D.new()
		add_child(polo_l)
		polo_r = Node3D.new()
		add_child(polo_r)
		(ik_l as TwoBoneIK3D).set_pole_node(0, (ik_l as TwoBoneIK3D).get_path_to(polo_l))
		(ik_r as TwoBoneIK3D).set_pole_node(0, (ik_r as TwoBoneIK3D).get_path_to(polo_r))
	var hs: float = pt.hs
	polo_l.position = (pt.sh_l as Vector3) + Vector3(0.45, -0.35, 0.1) * hs
	polo_r.position = (pt.sh_r as Vector3) + Vector3(-0.25, 0.12, -0.6) * hs


func _flecha_na_corda(ponto_corda: Vector3) -> void:
	# flecha da corda passando pelo arco, apontada para onde o arco aponta
	var frente := (mira.transform.basis * Vector3(0, 0, 1)).normalized()
	flecha.visible = true
	flecha.position = ponto_corda + frente * (0.39 * k)
	flecha.basis = _base_y(frente)


func _process(dt: float) -> void:
	if not ativo or mira == null or c.skel == null:
		return
	var pt := _pontos()
	var ancora: Vector3 = pt.ancora
	if t < 0.0:
		# prontidão: corpo meio de lado, arco baixo, mão direita na corda com a flecha encaixada
		_girar_corpo(lerpf(giro_atual, GIRO_PRONTO, minf(dt * 6.0, 1.0)))
		_pose(0.0, pt)
		var nock: Vector3 = mira.transform * corda
		mao_corda.position = nock
		ik_r.active = true
		_corda(corda)
		_flecha_na_corda(nock)
		return
	t += dt
	_girar_corpo(lerpf(GIRO_PRONTO, GIRO_TIRO, clampf(t / ERGUER, 0.0, 1.0)) if t < BAIXAR else lerpf(GIRO_TIRO, GIRO_PRONTO, clampf((t - BAIXAR) / (DURACAO - BAIXAR), 0.0, 1.0)))
	if t < ERGUER:
		var w := clampf(t / ERGUER, 0.0, 1.0)
		_pose(w * w * (3.0 - 2.0 * w), pt)
		var nock: Vector3 = mira.transform * corda
		mao_corda.position = nock
		_corda(corda)
		_flecha_na_corda(nock)
	elif t < SOLTAR:
		_pose(1.0, pt)
		var nock: Vector3 = mira.transform * corda
		var f := clampf((t - ERGUER) / (PUXAR - ERGUER), 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		mao_corda.position = nock.lerp(ancora, f)
		_corda(mira.transform.affine_inverse() * mao_corda.position)
		_flecha_na_corda(mao_corda.position)
	elif t < BAIXAR:
		_pose(1.0, pt)
		flecha.visible = false
		_corda(corda)
		mao_corda.position = ancora + Vector3(-0.03, 0.02, -0.07) * float(pt.hs)   # mão recua ao soltar
	elif t < DURACAO:
		var w := 1.0 - (t - BAIXAR) / (DURACAO - BAIXAR)
		_pose(w, pt)
		var nock: Vector3 = mira.transform * corda
		mao_corda.position = mao_corda.position.lerp(nock, 0.25)
		_corda(corda)
	else:
		t = -1.0


# corda das duas pontas até o ponto de puxada (no espaço da mira)
func _corda(p: Vector3) -> void:
	for i in 2:
		var a: Vector3 = pontas[i]
		var d := p - a
		var seg: MeshInstance3D = cordas[i]
		seg.transform = Transform3D(_base_y(d.normalized()).scaled_local(Vector3(1, maxf(d.length(), 0.001), 1)), a + d * 0.5)


static func _base_y(y: Vector3) -> Basis:
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, y, x.cross(y).normalized()).orthonormalized()
