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
	_pose_baixo(1.0)


func ligar(on: bool) -> void:
	ativo = on
	ik_l.active = on
	ik_r.active = false
	flecha.visible = false
	t = -1.0
	if c.postura != null:
		c.postura.bracos_livres = not on


# devolve a duração do tiro; o personagem já deve estar virado para o alvo
func disparar() -> float:
	if not ativo:
		ligar(true)
	t = 0.0
	return DURACAO


func soltou() -> bool:
	return t >= SOLTAR


# pose parada: arco em pé ao lado do quadril esquerdo, ponta de baixo à frente
func _pose_baixo(_w: float) -> void:
	mira.position = Vector3(0.24, 0.98, 0.16) * k
	mira.basis = Basis(Vector3.RIGHT, 0.35) * Basis(Vector3.UP, 0.5)


func _pose_mira(w: float) -> void:
	# braço esquerdo esticado à frente, na altura do ombro; arco quase em pé (leve inclinação para fora)
	var baixo := Transform3D(Basis(Vector3.RIGHT, 0.35) * Basis(Vector3.UP, 0.5), Vector3(0.24, 0.98, 0.16) * k)
	var alto := Transform3D(Basis(Vector3.BACK, -0.12), Vector3(0.1, 1.4, 0.56) * k)
	var tr := baixo.interpolate_with(alto, clampf(w, 0.0, 1.0))
	mira.transform = tr


func _process(dt: float) -> void:
	if not ativo or mira == null:
		return
	if t < 0.0:
		_pose_baixo(1.0)
		return
	t += dt
	var ancora := Vector3(-0.07, 1.5, 0.06) * k   # canto da boca, lado direito
	if t < ERGUER:
		_pose_mira(t / ERGUER)
		ik_r.active = false
		flecha.visible = false
	elif t < SOLTAR:
		_pose_mira(1.0)
		ik_r.active = true
		var nock: Vector3 = mira.transform * corda
		var f := clampf((t - ERGUER) / (PUXAR - ERGUER), 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		mao_corda.position = nock.lerp(ancora, f)
		_corda(mira.transform.affine_inverse() * (mao_corda.position + (mira.transform.basis * Vector3(0, 0, 0.0))))
		# flecha da mão direita até passar o arco, apontada para frente
		var frente := (mira.global_position - mao_corda.global_position).normalized()
		flecha.visible = true
		flecha.global_position = mao_corda.global_position + frente * (0.39 * k)
		flecha.global_basis = _base_y(frente)
	elif t < BAIXAR:
		_pose_mira(1.0)
		flecha.visible = false
		_corda(corda)
		mao_corda.position = ancora + Vector3(-0.04, 0.02, -0.08) * k   # recuo da mão ao soltar
	elif t < DURACAO:
		_pose_mira(1.0 - (t - BAIXAR) / (DURACAO - BAIXAR))
		ik_r.active = false
	else:
		t = -1.0
		_pose_baixo(1.0)


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
