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
var correndo := 0.0  # 0 .. 1 só na corrida (Jog/Run)
var corrida_reta := 0.0  # graus para trás na corrida (corpos próprios largos: orc e anão não tombam o tronco)
# postura ereta e firme fora de combate (pedido de Robson 20/11, referências de MMO clássico): tira parte da
# curvatura de coluna, pescoço e pernas; em combate a postura de ataque da raça volta inteira
var ereto := 0.0
# corpos próprios (orc, anão, gigante): a malha já vem com o pescoço projetado; graus para erguer a cabeça
# (negativo = para trás), divididos entre pescoço (60%) e cabeça (40%). Vale parado, andando e em combate.
var cabeca_extra := 0.0
# pescoço mais longo nos corpos próprios: a cabeça sobe (e recua) alguns cm em relação ao pescoço, depois das
# animações; os vértices da faixa do pescoço (pesos em rampa) esticam junto, sem mexer no rosto.
var pescoco := Vector3.ZERO  # (x, sobe, frente) em metros no espaço do esqueleto
var _pos_base := Vector3.ZERO
var _pos_ultimo := Vector3(INF, INF, INF)
var ereto_combate := 0.0  # arqueiro: ereto também em combate (busto firme)
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
	var comb := _mix * float(combate.get(curto, 0.0)) * 0.8
	if OSSOS[nome][0] in ["frente", "perna", "joelho", "pe"]:
		base *= 1.0 - ereto_combate * _mix
		comb *= 1.0 - ereto_combate
	var g := base + comb
	if nome == "spine_01":
		g += inclina * andando
	if cabeca_extra != 0.0 and (nome == "neck_01" or nome == "Head"):
		g += cabeca_extra * (0.6 if nome == "neck_01" else 0.4)
	if corrida_reta != 0.0 and correndo > 0.0:
		var parte := {"spine_01": 0.4, "spine_02": 0.3, "neck_01": 0.15, "Head": 0.15}
		if parte.has(nome):
			g -= corrida_reta * correndo * float(parte[nome])
	return g


func _process_modification_with_delta(delta: float) -> void:
	var __t := Time.get_ticks_usec()
	_pm_corpo(delta)
	preload("res://scripts/perfil.gd").soma("esq_postura_raca", Time.get_ticks_usec() - __t)


func _pm_corpo(delta: float) -> void:
	var sk := get_skeleton()
	if sk != null and sk.get_meta("lod_longe", false):  # longe da câmera: ajuste fino desligado (economiza CPU)
		return
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
	if pescoco != Vector3.ZERO and _ids.has("Head"):
		var hi: int = _ids["Head"]
		var pp := sk.get_bone_pose_position(hi)
		if not pp.is_equal_approx(_pos_ultimo):
			_pos_base = pp
		var pai_b := sk.get_bone_global_pose(sk.get_bone_parent(hi)).basis
		var novo_p := _pos_base + pai_b.inverse() * pescoco
		_pos_ultimo = novo_p
		sk.set_bone_pose_position(hi, novo_p)
