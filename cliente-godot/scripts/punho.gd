class_name Punho
extends SkeletonModifier3D
# Fecha os dedos em volta do cabo da arma (depois da animação, a cada quadro).
# amount: 0 = mão aberta da animação, 1 = punho fechado no cabo.

var amount := {"r": 0.0, "l": 0.0}
var curl_sign := {"r": 1.0, "l": 1.0}
var _bones := {}  # lado -> [[osso, ângulo], ...]

const FINGERS := ["index", "middle", "ring", "pinky"]
const BEND := [1.25, 1.55, 1.05]  # base, meio e ponta do dedo (radianos com o punho fechado)
const THUMB := [0.35, 0.55, 0.6]
const THUMB_AXIS := {"r": Vector3(0, 0, 1), "l": Vector3(0, 0, -1)}
const SPREAD := {"index": -0.04, "middle": 0.0, "ring": 0.05, "pinky": 0.1}


func _cache(sk: Skeleton3D, side: String) -> Array:
	var out := []
	for f in FINGERS:
		for j in 3:
			var b := sk.find_bone("%s_0%d_%s" % [f, j + 1, side])
			if b >= 0:
				out.append([b, BEND[j], Vector3.RIGHT])
	# polegar: dobra menos, e a base gira para cima dos dedos
	for j in [1, 2, 3]:
		var b := sk.find_bone("thumb_0%d_%s" % [j, side])
		if b >= 0:
			out.append([b, THUMB[j - 1], THUMB_AXIS[side]])
	return out


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for side in amount:
		var a: float = amount[side]
		if a <= 0.001:
			continue
		if not _bones.has(side):
			_bones[side] = _cache(sk, side)
		var sgn: float = curl_sign[side]
		for e in _bones[side]:
			var b: int = e[0]
			var q := sk.get_bone_rest(b).basis.get_rotation_quaternion() * Quaternion(e[2], float(e[1]) * a * sgn)
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(q, a))
