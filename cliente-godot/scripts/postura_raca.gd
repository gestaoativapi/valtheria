extends SkeletonModifier3D
# Postura própria de cada raça: rotações extras por osso aplicadas DEPOIS das 28 animações oficiais,
# sem alterar o esqueleto nem as animações (parecer MESA-013). Os ângulos estão em graus e seguem
# um sentido de leitura fácil, convertido aqui para o eixo certo de cada osso:
#   coluna, pescoço, cabeça e pelve: positivo = inclina para a frente
#   clavícula: positivo = ombro para a frente;  braço: positivo = braço afastado do corpo
#   antebraço e mão: positivo = dobra;  coxa: positivo = perna à frente;  canela: positivo = joelho dobrado
#   pé: positivo = ponta do pé para cima
# Em combate soma-se o perfil de combate. A mudança entre os dois é suave.

const OSSOS := {
	"pelvis": ["frente", ""], "spine_01": ["frente", ""], "spine_02": ["frente", ""], "spine_03": ["frente", ""],
	"neck_01": ["frente", ""], "Head": ["frente", ""],
	"clavicle_l": ["clavicula", "clavicle"], "clavicle_r": ["clavicula", "clavicle"],
	"upperarm_l": ["afasta", "upperarm"], "upperarm_r": ["afasta", "upperarm"],
	"lowerarm_l": ["dobra", "lowerarm"], "lowerarm_r": ["dobra", "lowerarm"],
	"hand_l": ["dobra", "hand"], "hand_r": ["dobra", "hand"],
	"thigh_l": ["perna", "thigh"], "thigh_r": ["perna", "thigh"],
	"calf_l": ["joelho", "calf"], "calf_r": ["joelho", "calf"],
	"foot_l": ["pe", "foot"], "foot_r": ["pe", "foot"],
}

var pose := {}       # nome curto do osso -> graus (postura normal)
var combate := {}    # nome curto do osso -> graus extras em combate
var inclina := 0.0   # inclinação extra da caminhada (graus), aplicada só andando
var em_combate := false
# os ângulos do parecer são conservadores; o Robson quer raças que não pareçam humanas: reforço de 2,1x a pedido do Robson (o perfil de combate entra a 80%)
var intensidade := 2.1
var bracos_livres := true  # com a guarda armada (IK nos braços) a postura não mexe nos braços
var andando := 0.0   # 0 parado .. 1 andando (o personagem atualiza)
# postura ereta e firme fora de combate (pedido de Robson 20/11, referências de MMO clássico): tira parte da
# curvatura de coluna, pescoço e pernas; em combate a postura de ataque da raça volta inteira
var ereto := 0.0
var _mix := 0.0
var _ids := {}
var _base := {}     # rotação da animação antes da postura
var _ultimo := {}   # rotação que a postura gravou no quadro anterior


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for b in OSSOS:
		var i := sk.find_bone(b)
		if i >= 0:
			_ids[b] = i


func _graus(nome: String) -> float:
	var curto: String = OSSOS[nome][1] if OSSOS[nome][1] != "" else nome
	var base := float(pose.get(curto, 0.0)) * intensidade
	if OSSOS[nome][0] in ["frente", "perna", "joelho", "pe"]:
		base *= 1.0 - ereto * (1.0 - _mix)
	var g := base + _mix * float(combate.get(curto, 0.0)) * 0.8
	if nome == "spine_01":
		g += inclina * andando
	return g


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _ids.is_empty():
		return
	_mix = move_toward(_mix, 1.0 if em_combate else 0.0, delta * 3.0)
	# ordem pai -> filho: cada rotação usa a pose global já corrigida do pai
	for b in OSSOS:
		if not _ids.has(b):
			continue
		var g := _graus(b)
		if absf(g) < 0.01:
			continue
		if not bracos_livres and OSSOS[b][0] in ["clavicula", "afasta", "dobra"]:
			continue
		var i: int = _ids[b]
		var lado := 1.0 if b.ends_with("_l") else -1.0
		var eixo := Vector3.RIGHT
		var ang := deg_to_rad(g)
		match OSSOS[b][0]:
			"frente":
				eixo = Vector3.RIGHT
			"clavicula":
				eixo = Vector3.UP
				ang = -lado * ang
			"afasta":
				eixo = Vector3.BACK
				ang = lado * ang
			"dobra":
				eixo = Vector3.RIGHT
				ang = -ang
			"perna":
				eixo = Vector3.RIGHT
				ang = -ang
			"joelho":
				eixo = Vector3.RIGHT
			"pe":
				eixo = Vector3.RIGHT
				ang = -ang
		var pai := sk.get_bone_parent(i)
		var gp := sk.get_bone_global_pose(pai).basis.get_rotation_quaternion() if pai >= 0 else Quaternion.IDENTITY
		var q := Quaternion(eixo, ang)
		# sem animação tocando, a pose do osso continua a que a postura gravou: parte da rotação original,
		# senão a inclinação somaria quadro a quadro
		var local := sk.get_bone_pose_rotation(i)
		if _ultimo.has(i) and local.is_equal_approx(_ultimo[i]):
			local = _base[i]
		_base[i] = local
		var novo := (gp.inverse() * q * gp * local).normalized()
		_ultimo[i] = novo
		sk.set_bone_pose_rotation(i, novo)
