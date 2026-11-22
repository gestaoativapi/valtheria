class_name GeloGolem
extends RefCounted
# Gigante de Gelo (pedido de Robson 21/11): metade humano, metade golem de gelo.
# O lado esquerdo (braço, perna e metade do peito) vira blocos de gelo facetado presos aos ossos,
# com cristais saindo do ombro e das costas e um punho de gelo maior. O lado direito continua de carne.
# Peças presas por BoneAttachment3D: acompanham as 28 animações sem alterar o esqueleto.

static var _mat_gelo: StandardMaterial3D
static var _mat_nucleo: StandardMaterial3D


static func materiais() -> Array:
	if _mat_gelo == null:
		_mat_gelo = StandardMaterial3D.new()
		_mat_gelo.albedo_color = Color(0.42, 0.62, 0.78, 0.9)
		_mat_gelo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		_mat_gelo.roughness = 0.08
		_mat_gelo.metallic = 0.35
		_mat_gelo.metallic_specular = 0.9
		_mat_gelo.clearcoat_enabled = true
		_mat_gelo.clearcoat = 1.0
		_mat_gelo.rim_enabled = true
		_mat_gelo.rim = 0.7
		_mat_gelo.rim_tint = 0.3
		_mat_gelo.emission_enabled = true
		_mat_gelo.emission = Color(0.2, 0.45, 0.7)
		_mat_gelo.emission_energy_multiplier = 0.22
		_mat_nucleo = StandardMaterial3D.new()
		_mat_nucleo.albedo_color = Color(0.82, 0.95, 1.0)
		_mat_nucleo.emission_enabled = true
		_mat_nucleo.emission = Color(0.55, 0.85, 1.0)
		_mat_nucleo.emission_energy_multiplier = 2.2
		_mat_nucleo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return [_mat_gelo, _mat_nucleo]


# bloco de gelo facetado: caixa achatada nas quinas (prisma de 6 lados alongado)
static func _bloco(tam: Vector3) -> Mesh:
	var bm := BoxMesh.new()
	bm.size = Vector3(tam.x, tam.y, tam.x * 0.8)
	return bm


static func _cristal(alt: float, raio: float) -> Mesh:
	var cm := CylinderMesh.new()
	cm.radial_segments = 5
	cm.rings = 1
	cm.top_radius = 0.0
	cm.bottom_radius = raio
	cm.height = alt
	return cm


static func _peca(skel: Skeleton3D, osso: String, mesh: Mesh, mat: Material, pos_esq: Vector3, dir: Vector3, giro := 0.0) -> void:
	var i := skel.find_bone(osso)
	if i < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = osso
	att.name = "Gelo_" + osso
	skel.add_child(att)
	var g := skel.get_bone_global_rest(i)
	var d := dir.normalized()
	var eixo := Vector3.UP.cross(d)
	var b := Basis(eixo.normalized(), Vector3.UP.angle_to(d)) if eixo.length() > 0.001 else Basis.IDENTITY
	b = b * Basis(Vector3.UP, giro)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	att.add_child(mi)
	mi.transform = g.affine_inverse() * Transform3D(b, pos_esq)


# reveste um segmento (osso -> filho) com blocos de gelo
static func _segmento(skel: Skeleton3D, osso: String, filho: String, grossura: float, n: int, rng: RandomNumberGenerator) -> void:
	var a := skel.find_bone(osso)
	var f := skel.find_bone(filho)
	if a < 0 or f < 0:
		return
	var p0 := skel.get_bone_global_rest(a).origin
	var p1 := skel.get_bone_global_rest(f).origin
	var d := p1 - p0
	var mats := materiais()
	for k in n:
		var t := (k + 0.5) / n
		for j in 2:  # dois blocos cruzados por trecho: contorno quebrado, como gelo lascado
			var lado := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * grossura * 0.22
			var tam := Vector3(grossura * rng.randf_range(0.75, 1.0), d.length() / n * rng.randf_range(0.9, 1.25), 0)
			var inc := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35)) * d.length()
			_peca(skel, osso, _bloco(tam), mats[0], p0 + d * t + lado, d + inc, rng.randf() * TAU)


static func montar(skel: Skeleton3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var mats := materiais()
	# braço esquerdo inteiro e punho de gelo
	_segmento(skel, "clavicle_l", "upperarm_l", 0.16, 1, rng)
	_segmento(skel, "upperarm_l", "lowerarm_l", 0.15, 3, rng)
	_segmento(skel, "lowerarm_l", "hand_l", 0.14, 3, rng)
	var h := skel.find_bone("hand_l")
	var m := skel.find_bone("middle_01_l")
	if h >= 0 and m >= 0:
		var ph := skel.get_bone_global_rest(h).origin
		var pm := skel.get_bone_global_rest(m).origin
		_peca(skel, "hand_l", _bloco(Vector3(0.17, 0.16, 0)), mats[0], ph.lerp(pm, 0.6), pm - ph)
		for k in 3:  # nós dos dedos em cristal
			_peca(skel, "hand_l", _cristal(0.07, 0.025), mats[0], ph.lerp(pm, 1.05) + Vector3(0, 0.03 - k * 0.03, 0.02), pm - ph)
	# perna esquerda
	_segmento(skel, "thigh_l", "calf_l", 0.2, 3, rng)
	_segmento(skel, "calf_l", "foot_l", 0.16, 3, rng)
	var fb := skel.find_bone("foot_l")
	if fb >= 0:
		var pf := skel.get_bone_global_rest(fb).origin
		_peca(skel, "foot_l", _bloco(Vector3(0.16, 0.26, 0)), mats[0], pf + Vector3(0, -0.04, 0.07), Vector3(0, 0.15, 1))
	# metade esquerda do peito e da barriga
	for osso in ["spine_01", "spine_02", "spine_03"]:
		var i := skel.find_bone(osso)
		if i < 0:
			continue
		var p := skel.get_bone_global_rest(i).origin
		for k in 2:
			var off := Vector3(0.09 + 0.05 * k, rng.randf_range(-0.03, 0.05), 0.1 - 0.17 * k)
			_peca(skel, osso, _bloco(Vector3(0.17, 0.2, 0)), mats[0], p + off, Vector3(0.2, 1, 0.1 - 0.3 * k), rng.randf() * TAU)
	# cristais saindo do ombro e das costas, e o núcleo brilhando no peito
	var c3 := skel.find_bone("spine_03")
	var cl := skel.find_bone("clavicle_l")
	if cl >= 0:
		var pc := skel.get_bone_global_rest(skel.find_bone("upperarm_l")).origin
		for k in 3:
			_peca(skel, "clavicle_l", _cristal(0.16 + 0.06 * k, 0.045), mats[0], pc + Vector3(-0.02 * k, 0.06, -0.04 * k), Vector3(0.35 - 0.1 * k, 1, -0.4 - 0.15 * k))
	if c3 >= 0:
		var p3 := skel.get_bone_global_rest(c3).origin
		for k in 2:
			_peca(skel, "spine_03", _cristal(0.18 + 0.05 * k, 0.04), mats[0], p3 + Vector3(0.05 + 0.04 * k, 0.05 - 0.07 * k, -0.13), Vector3(0.2, 0.6, -1))
		var nuc := SphereMesh.new()
		nuc.radius = 0.045
		nuc.height = 0.09
		nuc.radial_segments = 8
		nuc.rings = 4
		_peca(skel, "spine_03", nuc, mats[1], p3 + Vector3(0.08, -0.02, 0.13), Vector3.UP)
	# rosto: placa de gelo cobrindo o lado esquerdo da cabeça
	var hd := skel.find_bone("Head")
	if hd >= 0:
		var pcab := skel.get_bone_global_rest(hd).origin
		_peca(skel, "Head", _bloco(Vector3(0.07, 0.12, 0)), mats[0], pcab + Vector3(0.075, 0.07, 0.0), Vector3(-0.2, 1, 0.1))
		_peca(skel, "Head", _cristal(0.1, 0.025), mats[0], pcab + Vector3(0.07, 0.15, -0.03), Vector3(0.6, 1, -0.3))
