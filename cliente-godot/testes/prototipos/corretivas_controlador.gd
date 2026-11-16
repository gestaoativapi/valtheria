extends Node
# Valtheria V3 — AUT-021 D58: controlador EXPERIMENTAL das formas corretivas da túnica (não integrado ao character.gd).
# A cada quadro mede o ângulo de cada coxa no referencial da saia (mistura bacia/spine_01) e liga as formas
# corr_* da túnica com a MESMA fórmula de ferramentas/v3/corretivas_base.py.
const ALFA := 0.5
const LIMITE := 1.3
var skel: Skeleton3D
var malha: MeshInstance3D
var indices := {}           # nome da forma -> índice do blend shape
var ultimo := {}            # pesos aplicados no último quadro (para conferência)
# AUT-022: modelo RBF opcional (arquivo <tunica>.rbf.json ao lado do .glb)
var rbf_centros := PackedFloat32Array()   # N x 6
var rbf_pesos := PackedFloat32Array()     # N x K
var rbf_formas: Array = []
var rbf_sigma := 1.0
var rbf_puro := false
var rbf_n := 0

func carregar_rbf(caminho: String) -> bool:
	if not FileAccess.file_exists(caminho): return false
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	rbf_sigma = float(m["sigma"]); rbf_formas = m["formas"]; rbf_puro = str(m["modo"]) == "puro"
	var C: Array = m["centros"]; var W: Array = m["pesos"]; rbf_n = C.size()
	for c in C:
		for v in c: rbf_centros.append(float(v))
	for w in W:
		for v in w: rbf_pesos.append(float(v))
	return true

func configurar(s: Skeleton3D, m: MeshInstance3D) -> void:
	skel = s; malha = m
	for i in m.mesh.get_blend_shape_count(): indices[str(m.mesh.get_blend_shape_name(i))] = i

func _rot(b: String, rest: bool) -> Basis:
	var i := skel.find_bone(b)
	return (skel.get_bone_global_rest(i) if rest else skel.get_bone_global_pose(i)).basis.orthonormalized()

func _pos(b: String, rest: bool) -> Vector3:
	var i := skel.find_bone(b)
	return (skel.get_bone_global_rest(i) if rest else skel.get_bone_global_pose(i)).origin

func _quadro(rest: bool) -> Basis:
	var rp0 := _rot("pelvis", true); var rs0 := _rot("spine_01", true)
	var rrel := rp0.transposed() * rs0
	var qa := Quaternion(_rot("pelvis", rest)); var qb := Quaternion(_rot("spine_01", rest) * rrel.transposed())
	return Basis(qa.slerp(qb, ALFA))

func _ang(s: String, sinal: float, rest: bool) -> Vector2:
	var r0 := _rot("pelvis", true)
	var F := r0.transposed() * Vector3(0, 0, 1); var U := r0.transposed() * Vector3(0, 1, 0); var L := r0.transposed() * Vector3(1, 0, 0)
	var d := (_pos("calf_" + s, rest) - _pos("thigh_" + s, rest)).normalized()
	d = _quadro(rest).transposed() * d
	return Vector2(rad_to_deg(atan2(d.dot(F), -d.dot(U))), rad_to_deg(asin(clampf(sinal * d.dot(L), -1.0, 1.0))))

static func _tenda(x: float, a: float, b: float, c: float) -> float:
	return clampf((x - a) / (b - a), 0.0, 1.0) - clampf((x - b) / (c - b), 0.0, 1.0)

func pesos() -> Dictionary:
	var w := {}; var fl := {}
	for par in [["l", 1.0], ["r", -1.0]]:
		var s: String = par[0]
		var a := _ang(s, par[1], false) - _ang(s, par[1], true)
		fl[s] = a.x
		w["corr_coxa_%s_frente45" % s] = _tenda(a.x, 0, 45, 90)
		w["corr_coxa_%s_frente90" % s] = _tenda(a.x, 45, 90, 135)
		w["corr_coxa_%s_frente135" % s] = clampf((a.x - 90) / 45, 0, LIMITE)
		w["corr_coxa_%s_tras45" % s] = clampf(-a.x / 45, 0, LIMITE)
		w["corr_coxa_%s_fora45" % s] = clampf(a.y / 45, 0, LIMITE)
		w["corr_coxa_%s_dentro25" % s] = clampf(-a.y / 25, 0, LIMITE)
	w["corr_coxas_ambas90"] = clampf(minf(fl["l"], fl["r"]) / 90, 0, LIMITE)
	return w

func _dir(s: String, rest: bool) -> Vector3:
	var d := (_pos("calf_" + s, rest) - _pos("thigh_" + s, rest)).normalized()
	return _quadro(rest).transposed() * d

func pesos_rbf() -> Dictionary:
	var f := PackedFloat32Array()
	for s in ["l", "r"]:
		var v := _dir(s, false) - _dir(s, true)
		f.append(v.x); f.append(v.y); f.append(v.z)
	var K := rbf_formas.size(); var out := PackedFloat32Array(); out.resize(K)
	var inv := 1.0 / (rbf_sigma * rbf_sigma)
	for i in rbf_n:
		var d2 := 0.0
		for j in 6:
			var e := f[j] - rbf_centros[i * 6 + j]; d2 += e * e
		var phi := exp(-d2 * inv)
		if phi < 1e-6: continue
		for k in K: out[k] += phi * rbf_pesos[i * K + k]
	var w := {}
	for k in K: w[rbf_formas[k]] = out[k]
	return w

func aplicar() -> void:
	if malha == null: return
	ultimo = {} if (rbf_n > 0 and rbf_puro) else pesos()
	if rbf_n > 0: ultimo.merge(pesos_rbf(), true)
	for n in ultimo.keys():
		if indices.has(n): malha.set_blend_shape_value(indices[n], ultimo[n])

func _process(_d: float) -> void:
	aplicar()
