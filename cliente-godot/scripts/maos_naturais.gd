extends SkeletonModifier3D
# Mão livre com jeito de mão de verdade (pedido de Robson 22/11: "traços reais" nas mãos).
# As animações do pacote deixam a mão vazia fechada em soco ou dura e aberta. Aqui a mão que não segura nada
# fica relaxada: dedos levemente dobrados em cascata (o mindinho dobra mais que o indicador), as pontas
# acompanham, o polegar descansa ao lado do indicador. A mão que segura arma é do Punho (não mexe nela).

var dono: Node3D
var _ossos := {}

const DEDOS := ["index", "middle", "ring", "pinky"]
# dobra relaxada por articulação (base, meio, ponta) e quanto aumenta do indicador para o mindinho
const DOBRA := [0.22, 0.38, 0.22]
const CASCATA := [0.07, 0.1, 0.05]
const POLEGAR := [0.12, 0.2, 0.18]
const EIXO_POLEGAR := {"r": Vector3(0, 0, 1), "l": Vector3(0, 0, -1)}


func _cache(sk: Skeleton3D, lado: String) -> Array:
	var out := []
	for i in DEDOS.size():
		for j in 3:
			var b := sk.find_bone("%s_0%d_%s" % [DEDOS[i], j + 1, lado])
			if b >= 0:
				out.append([b, DOBRA[j] + CASCATA[j] * i, Vector3.RIGHT])
	for j in 3:
		var b := sk.find_bone("thumb_0%d_%s" % [j + 1, lado])
		if b >= 0:
			out.append([b, POLEGAR[j], EIXO_POLEGAR[lado]])
	return out


func _ocupada(lado: String) -> bool:
	if dono == null:
		return false
	var f = dono.get("fist")
	if f != null and float(f.amount.get(lado, 0.0)) > 0.05:
		return true
	return false


func _process_modification() -> void:
	var __t := Time.get_ticks_usec()
	_pm_corpo()
	preload("res://scripts/perfil.gd").soma("esq_maos_naturais", Time.get_ticks_usec() - __t)


func _pm_corpo() -> void:
	var sk := get_skeleton()
	if sk != null and sk.get_meta("lod_longe", false):  # longe da câmera: ajuste fino desligado (economiza CPU)
		return
	if sk == null:
		return
	for lado in ["r", "l"]:
		if _ocupada(lado):
			continue
		if not _ossos.has(lado):
			_ossos[lado] = _cache(sk, lado)
		for e in _ossos[lado]:
			var b: int = e[0]
			# parte do repouso (dedos esticados) e dobra um pouco: troca o soco/dedo duro da animação por mão solta
			var q := sk.get_bone_rest(b).basis.get_rotation_quaternion() * Quaternion(e[2], float(e[1]))
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(q, 0.85))
