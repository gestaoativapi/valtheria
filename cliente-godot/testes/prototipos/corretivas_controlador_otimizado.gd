extends Node
# Valtheria V3 — AUT-023: controlador OTIMIZADO das formas corretivas + RBF da túnica (protótipo, não integrado).
# Mesma matemática de corretivas_controlador.gd (AUT-022) e de ferramentas/v3/corretivas_base.py, com:
#  1) tudo que depende só do repouso calculado uma vez (bases, ângulos e direções de repouso, índices de ossos);
#  2) RBF condicional: só é avaliado quando alguma coxa sai da faixa comum (mesmos limiares de corretivas_base.rbf_ativo);
#  3) distância: além de DISTANCIA_MAX da câmera nada é recalculado (e as formas voltam a zero uma vez);
#  4) atualização a cada A_CADA quadros, com fase por personagem (para não pesar todos no mesmo quadro);
#  5) só chama set_blend_shape_value quando o peso muda mais que MUDANCA_MIN;
#  6) contadores de tempo (µs) por etapa, para o perfilamento.
const ALFA := 0.5
const LIMITE := 1.3
const FLEX_MAX := 45.0
const FLEX_MIN := -35.0
const ABD_ABS := 25.0
var DISTANCIA_MAX := 12.0
var A_CADA := 2
var MUDANCA_MIN := 0.002
var usar_condicional := true

var skel: Skeleton3D
var malha: MeshInstance3D
var idx := {}                       # nome da forma -> índice
var atual := PackedFloat32Array()   # último peso aplicado por índice
var ultimo := {}
var ang_ultimo := {}
var _b := {}                        # índices de ossos
var _F: Vector3; var _U: Vector3; var _L: Vector3
var _rrel_t: Basis
var _ang0 := {}                     # ângulo de repouso por lado
var _dir0 := {}                     # direção de repouso por lado (referencial da saia)
var _fase := 0
var _q := 0
var _zerado := false
# RBF
var rbf_centros := PackedFloat32Array(); var rbf_pesos := PackedFloat32Array(); var rbf_formas: Array = []
var rbf_idx := PackedInt32Array(); var rbf_sigma := 1.0; var rbf_n := 0; var rbf_k := 0
# perfilamento (acumulado)
static var us_angulos := 0; static var us_rbf := 0; static var us_aplicar := 0; static var avaliacoes := 0; static var avaliacoes_rbf := 0; static var puladas := 0

func configurar(s: Skeleton3D, m: MeshInstance3D) -> void:
	skel = s; malha = m
	for i in m.mesh.get_blend_shape_count(): idx[str(m.mesh.get_blend_shape_name(i))] = i
	atual.resize(m.mesh.get_blend_shape_count())
	for n in ["pelvis", "spine_01", "thigh_l", "calf_l", "thigh_r", "calf_r"]: _b[n] = skel.find_bone(n)
	var r0 := skel.get_bone_global_rest(_b["pelvis"]).basis.orthonormalized()
	_F = r0.transposed() * Vector3(0, 0, 1); _U = r0.transposed() * Vector3(0, 1, 0); _L = r0.transposed() * Vector3(1, 0, 0)
	_rrel_t = (r0.transposed() * skel.get_bone_global_rest(_b["spine_01"]).basis.orthonormalized()).transposed()
	var q0 := Basis(r0)
	for par in [["l", 1.0], ["r", -1.0]]:
		var d := _dir_em(par[0], q0, true)
		_dir0[par[0]] = d; _ang0[par[0]] = _ang_de(d, par[1])
	_fase = int(get_instance_id()) % A_CADA

func carregar_rbf(caminho: String) -> bool:
	if not FileAccess.file_exists(caminho): return false
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	rbf_sigma = float(m["sigma"]); rbf_formas = m["formas"]
	var C: Array = m["centros"]; var W: Array = m["pesos"]; rbf_n = C.size(); rbf_k = rbf_formas.size()
	for c in C:
		for v in c: rbf_centros.append(float(v))
	for w in W:
		for v in w: rbf_pesos.append(float(v))
	for f in rbf_formas: rbf_idx.append(int(idx.get(str(f), -1)))
	return true

func _dir_em(s: String, q: Basis, rest: bool) -> Vector3:
	var a: Transform3D = skel.get_bone_global_rest(_b["thigh_" + s]) if rest else skel.get_bone_global_pose(_b["thigh_" + s])
	var c: Transform3D = skel.get_bone_global_rest(_b["calf_" + s]) if rest else skel.get_bone_global_pose(_b["calf_" + s])
	return q.transposed() * (c.origin - a.origin).normalized()

func _ang_de(d: Vector3, sinal: float) -> Vector2:
	return Vector2(rad_to_deg(atan2(d.dot(_F), -d.dot(_U))), rad_to_deg(asin(clampf(sinal * d.dot(_L), -1.0, 1.0))))

static func _tenda(x: float, a: float, b: float, c: float) -> float:
	return clampf((x - a) / (b - a), 0.0, 1.0) - clampf((x - b) / (c - b), 0.0, 1.0)

func _por(nome: String, v: float) -> void:
	ultimo[nome] = v
	if not idx.has(nome): return
	var i: int = idx[nome]
	if absf(atual[i] - v) > MUDANCA_MIN:
		atual[i] = v; malha.set_blend_shape_value(i, v)

func aplicar() -> void:
	if malha == null: return
	var t0 := Time.get_ticks_usec()
	var qa := Quaternion(skel.get_bone_global_pose(_b["pelvis"]).basis.orthonormalized())
	var qb := Quaternion(skel.get_bone_global_pose(_b["spine_01"]).basis.orthonormalized() * _rrel_t)
	var q := Basis(qa.slerp(qb, ALFA))
	var d := {}; var ang := {}
	for par in [["l", 1.0], ["r", -1.0]]:
		var s: String = par[0]
		d[s] = _dir_em(s, q, false); ang[s] = _ang_de(d[s], par[1]) - _ang0[s]
	ang_ultimo = ang
	var t1 := Time.get_ticks_usec()
	for s in ["l", "r"]:
		var a: Vector2 = ang[s]
		_por("corr_coxa_%s_frente45" % s, _tenda(a.x, 0, 45, 90))
		_por("corr_coxa_%s_frente90" % s, _tenda(a.x, 45, 90, 135))
		_por("corr_coxa_%s_frente135" % s, clampf((a.x - 90) / 45, 0, LIMITE))
		_por("corr_coxa_%s_tras45" % s, clampf(-a.x / 45, 0, LIMITE))
		_por("corr_coxa_%s_fora45" % s, clampf(a.y / 45, 0, LIMITE))
		_por("corr_coxa_%s_dentro25" % s, clampf(-a.y / 25, 0, LIMITE))
	_por("corr_coxas_ambas90", clampf(minf(ang["l"].x, ang["r"].x) / 90, 0, LIMITE))
	var ativo := false
	for s in ["l", "r"]:
		var a: Vector2 = ang[s]
		if a.x > FLEX_MAX or a.x < FLEX_MIN or absf(a.y) > ABD_ABS: ativo = true
	var t2 := Time.get_ticks_usec()
	if rbf_n > 0:
		if ativo or not usar_condicional:
			var f := PackedFloat32Array()
			for s in ["l", "r"]:
				var v: Vector3 = d[s] - _dir0[s]
				f.append(v.x); f.append(v.y); f.append(v.z)
			var out := PackedFloat32Array(); out.resize(rbf_k)
			var inv := 1.0 / (rbf_sigma * rbf_sigma)
			for i in rbf_n:
				var o := i * 6
				var e0 := f[0] - rbf_centros[o]; var e1 := f[1] - rbf_centros[o + 1]; var e2 := f[2] - rbf_centros[o + 2]
				var e3 := f[3] - rbf_centros[o + 3]; var e4 := f[4] - rbf_centros[o + 4]; var e5 := f[5] - rbf_centros[o + 5]
				var d2 := (e0 * e0 + e1 * e1 + e2 * e2 + e3 * e3 + e4 * e4 + e5 * e5) * inv
				if d2 > 13.8: continue   # exp(-13,8) < 1e-6
				var phi := exp(-d2); var base := i * rbf_k
				for k in rbf_k: out[k] += phi * rbf_pesos[base + k]
			for k in rbf_k: _por(str(rbf_formas[k]), out[k])
			avaliacoes_rbf += 1
		else:
			for k in rbf_k: _por(str(rbf_formas[k]), 0.0)
	var t3 := Time.get_ticks_usec()
	us_angulos += t1 - t0; us_aplicar += t2 - t1; us_rbf += t3 - t2; avaliacoes += 1

func _zerar() -> void:
	for i in atual.size():
		if atual[i] != 0.0: atual[i] = 0.0; malha.set_blend_shape_value(i, 0.0)

func _process(_dt: float) -> void:
	_q += 1
	if (_q % A_CADA) != _fase: puladas += 1; return
	var cam := get_viewport().get_camera_3d()
	if cam and malha.global_position.distance_to(cam.global_position) > DISTANCIA_MAX:
		if not _zerado: _zerar(); _zerado = true
		puladas += 1
		return
	_zerado = false
	aplicar()
