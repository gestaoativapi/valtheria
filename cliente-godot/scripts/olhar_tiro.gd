extends SkeletonModifier3D
# Arqueiro (21/11, referências de Robson): com o corpo de lado para o alvo, pescoço e cabeça viram de volta
# para o alvo (o olho na linha da flecha); a coluna inclina conforme o estilo da raça e o quadril abaixa um pouco
# nas raças que atiram agachadas. Só age enquanto o arqueiro está atirando ou em prontidão.

var giro := 0.0        # radianos que o corpo girou (o olhar devolve quase tudo)
var inclina := 0.0     # graus de inclinação da coluna para a frente (raça)
var agacha := 0.0      # graus de flexão dos joelhos (raça)
var peso := 0.0        # 0 = desligado, 1 = pose de tiro inteira
var _ids := {}


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for b in ["spine_01", "spine_02", "spine_03", "neck_01", "Head", "thigh_l", "thigh_r", "calf_l", "calf_r", "pelvis"]:
		var i := sk.find_bone(b)
		if i >= 0:
			_ids[b] = i


func _gira(sk: Skeleton3D, nome: String, q: Quaternion) -> void:
	if not _ids.has(nome):
		return
	var i: int = _ids[nome]
	var pai := sk.get_bone_parent(i)
	var gp := sk.get_bone_global_pose(pai).basis.get_rotation_quaternion() if pai >= 0 else Quaternion.IDENTITY
	sk.set_bone_pose_rotation(i, (gp.inverse() * q * gp * sk.get_bone_pose_rotation(i)).normalized())


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk != null and sk.get_meta("lod_longe", false):  # longe da câmera: ajuste fino desligado (economiza CPU)
		return
	if sk == null or peso <= 0.001:
		return
	var w := peso
	# coluna: inclina à frente e devolve um pouco do giro (peito aberto)
	_gira(sk, "spine_01", Quaternion(Vector3.RIGHT, deg_to_rad(inclina * 0.5 * w)))
	_gira(sk, "spine_02", Quaternion(Vector3.RIGHT, deg_to_rad(inclina * 0.5 * w)))
	_gira(sk, "spine_03", Quaternion(Vector3.UP, giro * 0.12 * w))
	# pescoço e cabeça para o alvo, nível do olhar mantido
	_gira(sk, "neck_01", Quaternion(Vector3.UP, giro * 0.38 * w) * Quaternion(Vector3.RIGHT, deg_to_rad(-inclina * 0.4 * w)))
	_gira(sk, "Head", Quaternion(Vector3.UP, giro * 0.42 * w) * Quaternion(Vector3.RIGHT, deg_to_rad(-inclina * 0.5 * w + 4.0 * w)))
	# joelhos levemente dobrados nas raças que atiram baixas (pelve desce junto)
	if agacha > 0.1:
		for lado in ["l", "r"]:
			_gira(sk, "thigh_" + lado, Quaternion(Vector3.RIGHT, deg_to_rad(-agacha * 0.5 * w)))
			_gira(sk, "calf_" + lado, Quaternion(Vector3.RIGHT, deg_to_rad(agacha * w)))
		if _ids.has("pelvis"):
			var ip: int = _ids.pelvis
			var p := sk.get_bone_pose_position(ip)
			var perna := sk.get_bone_global_rest(_ids.thigh_l).origin.y
			sk.set_bone_pose_position(ip, p - Vector3(0, perna * (1.0 - cos(deg_to_rad(agacha * 0.6))) * w, 0))
