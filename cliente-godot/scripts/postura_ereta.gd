extends SkeletonModifier3D
# Postura parada ereta (pedido de Robson 21/11): fora de combate e sem andar, o corpo fica reto e firme,
# como um guerreiro; o mago fica reto e mais formal. Homem e mulher com a mesma base, a mulher com jeito
# feminino (quadril levemente de lado, um joelho solto, ombros mais leves).
# Funciona por cima das 28 animações oficiais, sem alterá-las: pelve, coluna, pescoço, cabeça e pernas
# vão na direção da pose de repouso do esqueleto (que é reta) e recebem um ajuste de atitude.
# Os braços continuam com a animação (e com a pegada da arma, que vem depois).

const CORPO := ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head"]
const PERNAS := ["thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r"]

var dono: Node3D            # personagem (para saber se está parado e fora de combate)
var feminino := false
var mago := false
var forca := 0.9            # quanto vai para a postura reta (0 a 1)
var _peso := 0.0
var _t := 0.0
var _ids := {}
var _base := {}
var _ultimo := {}
var _base_pos := Vector3.ZERO
var _ultimo_pos := Vector3.INF


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for b in CORPO + PERNAS + ["clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"]:
		var i := sk.find_bone(b)
		if i >= 0:
			_ids[b] = i


func _parado() -> bool:
	if dono == null or not is_instance_valid(dono):
		return true
	var a = dono.get("anim")
	if a == null:
		return true
	var nome := str((a as AnimationPlayer).current_animation)
	if not (nome == "Idle" or nome == "Idle_Shield" or nome == "Spell_Simple_Idle" or nome == "Idle_Talking"):
		return false
	if bool(dono.get("armed")):  # arma em guarda (combate): fica a postura de ataque da raça
		return false
	var p = dono.get("postura")
	if p != null and is_instance_valid(p) and float(p.andando) > 0.05:
		return false
	return true


# mão com arma (a pegada cuida desse braço)
func _mao_ocupada(lado: String) -> bool:
	var e = dono.get("empunho") if dono != null else null
	if e != null and is_instance_valid(e) and float(e.peso.get(lado, 0.0)) > 0.0:
		return true
	if lado == "l" and dono != null and dono.get("shield_arm") != null:
		return true
	return false


# braço solto: caído ao lado do corpo, um pouco afastado e à frente; antebraço levemente dobrado
func _braco_solto(sk: Skeleton3D, i: int, b: String, lado: String, local: Quaternion) -> Quaternion:
	var sx := 1.0 if lado == "l" else -1.0
	var filho := sk.find_bone(("lowerarm_" if b.begins_with("upper") else "hand_") + lado)
	if filho < 0:
		return local
	var pai := sk.get_bone_parent(i)
	var gp := sk.get_bone_global_pose(pai) if pai >= 0 else Transform3D()
	var g := gp * Transform3D(Basis(local), sk.get_bone_pose_position(i))
	var dir_atual := (g.basis * sk.get_bone_rest(filho).origin).normalized()
	var abre := 0.16 if feminino else 0.2
	var alvo_dir := Vector3(sx * abre, -1.0, 0.06 if b.begins_with("upper") else 0.32).normalized()
	if mago and b.begins_with("lower"):
		alvo_dir = Vector3(sx * 0.08, -1.0, 0.45).normalized()
	var giro := Quaternion(dir_atual, alvo_dir)
	var nova_g := (giro * g.basis.get_rotation_quaternion()).normalized()
	return (gp.basis.get_rotation_quaternion().inverse() * nova_g).normalized()


# atitude por cima da pose reta (graus): [frente/trás, lado]
func _atitude(b: String) -> Vector2:
	var respira := sin(_t * 1.6) * 0.8
	if feminino:
		match b:
			"pelvis": return Vector2(-2.0, 4.0)        # quadril levemente de lado
			"spine_01": return Vector2(0.0, -2.0)
			"spine_02": return Vector2(-1.0, -1.5)
			"spine_03": return Vector2(-3.0 - respira, 0.0)
			"neck_01": return Vector2(0.0, 0.0)
			"Head": return Vector2(1.0, 3.0)           # cabeça levemente inclinada
			"thigh_l": return Vector2(4.0, -2.0)       # perna de apoio à frente, a outra solta
			"calf_l": return Vector2(9.0, 0.0)         # joelho solto
			"thigh_r": return Vector2(-1.0, 1.5)
			"clavicle_l", "clavicle_r": return Vector2(-3.0, 0.0)
	else:
		match b:
			"pelvis": return Vector2(-1.0, 0.0)
			"spine_02": return Vector2(-2.0, 0.0)
			"spine_03": return Vector2(-5.0 - respira, 0.0)   # peito aberto
			"neck_01": return Vector2(0.0, 0.0)
			"Head": return Vector2(1.5, 0.0)           # olhar à frente
			"thigh_l": return Vector2(0.0, -4.5)       # pés na largura dos ombros
			"thigh_r": return Vector2(0.0, 4.5)
			"calf_l", "calf_r": return Vector2(2.0, 0.0)
			"clavicle_l", "clavicle_r": return Vector2(-5.0, 0.0)  # ombros para trás
	if mago and b == "spine_03":
		return Vector2(-2.0 - respira * 0.5, 0.0)
	return Vector2.ZERO


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk != null and sk.get_meta("lod_longe", false):  # longe da câmera: ajuste fino desligado (economiza CPU)
		return
	if sk == null or _ids.is_empty():
		return
	_t += delta
	_peso = move_toward(_peso, forca if _parado() else 0.0, delta * 2.5)
	for b: String in _ids:
		var i: int = _ids[b]
		var local := sk.get_bone_pose_rotation(i)
		if _ultimo.has(i) and local.is_equal_approx(_ultimo[i]):
			local = _base[i]  # sem animação nova neste quadro: parte da pose original
		_base[i] = local
		if _peso <= 0.001:
			_ultimo.erase(i)
			continue
		var alvo := local
		if b in CORPO or b in PERNAS:
			alvo = sk.get_bone_rest(i).basis.get_rotation_quaternion()
		elif b.begins_with("upperarm") or b.begins_with("lowerarm"):
			var lado: String = str(b).right(1)
			if _mao_ocupada(lado):
				_ultimo[i] = local
				continue
			alvo = _braco_solto(sk, i, b, lado, local)
		var at := _atitude(b)
		if at != Vector2.ZERO:
			var pai := sk.get_bone_parent(i)
			var gp := sk.get_bone_global_pose(pai).basis.get_rotation_quaternion() if pai >= 0 else Quaternion.IDENTITY
			var q := Quaternion(Vector3.RIGHT, deg_to_rad(at.x)) * Quaternion(Vector3.BACK, deg_to_rad(at.y))
			alvo = (gp.inverse() * q * gp * alvo).normalized()
		var novo := local.slerp(alvo, _peso).normalized()
		_ultimo[i] = novo
		sk.set_bone_pose_rotation(i, novo)
	# a pelve sobe junto com as pernas retas (pés continuam no chão)
	if _ids.has("pelvis"):
		var ip: int = _ids.pelvis
		var pos := sk.get_bone_pose_position(ip)
		if pos.is_equal_approx(_ultimo_pos):
			pos = _base_pos
		_base_pos = pos
		var rp := sk.get_bone_rest(ip).origin
		var np := Vector3(pos.x, lerpf(pos.y, rp.y, _peso), pos.z)
		_ultimo_pos = np
		sk.set_bone_pose_position(ip, np)
