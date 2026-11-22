extends RefCounted
# Identidade nas armas e nas roupas (pedido de Robson 21/11, item 4: "escritas e emblemas nas armas e roupas").
#   lâmina  runas de um alfabeto próprio do jogo gravadas no meio das duas faces da lâmina, com brilho frio fraco
#   peito   medalhão de bronze com o brasão da raça (sol, folha, olho, escudo de presas, bigorna, garras, chama,
#           floco de neve), preso no peito por cima de qualquer roupa
# Tudo é malha leve (quads e um disco), sem luz extra e sem decal (o celular usa o renderizador de compatibilidade).

const BRASOES := ["humano", "elfo", "sombrio", "orc", "anao", "beastman", "draconato", "gigante"]
const LAMINAS := ["espada", "espadao", "adaga", "punhal", "duplas"]

static var _mat_runas: StandardMaterial3D
static var _mat_bronze: StandardMaterial3D
static var _mat_brasao := {}


static func _runas() -> StandardMaterial3D:
	if _mat_runas == null:
		_mat_runas = StandardMaterial3D.new()
		_mat_runas.albedo_texture = load("res://assets/emblemas/runas.png")
		_mat_runas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_runas.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_runas.albedo_color = Color(0.75, 0.88, 1.0, 0.85)
		_mat_runas.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat_runas


# runas nas duas faces da lâmina; w = nó da arma (origem na mão, lâmina para longe da mão)
static func lamina(w: Node3D, kind: String) -> void:
	if w == null or not kind in LAMINAS:
		return
	var bb := AABB()
	var primeiro := true
	for m in w.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = _rel(w, mi) * mi.get_aabb()
		bb = b if primeiro else bb.merge(b)
		primeiro = false
	if primeiro:
		return
	var tam := bb.size
	var ord := [0, 1, 2]
	ord.sort_custom(func(a, b): return tam[a] > tam[b])
	var lg: int = ord[0]
	var md: int = ord[1]
	var fn: int = ord[2]
	var c := bb.get_center()
	var sinal := 1.0 if c[lg] >= 0.0 else -1.0
	var eixo := Vector3.ZERO
	eixo[lg] = sinal
	var lado := Vector3.ZERO
	lado[md] = 1.0
	var face := Vector3.ZERO
	face[fn] = 1.0
	var L: float = tam[lg]
	# a lâmina ocupa a parte longe da mão: as runas vão de 40% a 85% do comprimento
	var ini: float = bb.position[lg] if sinal > 0.0 else bb.end[lg]
	var meio := ini + sinal * L * 0.62
	var q := QuadMesh.new()
	q.size = Vector2(L * 0.42, maxf(tam[md] * 0.3, 0.012))
	for s in [1.0, -1.0]:
		var mi := MeshInstance3D.new()
		mi.name = "Runas"
		mi.mesh = q
		mi.material_override = _runas()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p := c
		p[lg] = meio
		p += face * s * (tam[fn] * 0.5 + 0.0015)
		mi.transform = Transform3D(Basis(eixo * s, lado, face * s), p)
		w.add_child(mi)


static func _rel(raiz: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var a: Node = n
	while a != null and a != raiz:
		if a is Node3D:
			xf = (a as Node3D).transform * xf
		a = a.get_parent()
	return xf


# medalhão com o brasão da raça no peito (osso spine_03); k = altura / 1,8 m
static func peito(skel: Skeleton3D, raca: String, frente: float) -> void:
	if skel == null or not raca in BRASOES:
		return
	var i := skel.find_bone("spine_03")
	if i < 0:
		return
	if _mat_bronze == null:
		_mat_bronze = StandardMaterial3D.new()
		_mat_bronze.albedo_color = Color(0.42, 0.3, 0.16)
		_mat_bronze.metallic = 0.85
		_mat_bronze.roughness = 0.4
	if not _mat_brasao.has(raca):
		var mb := StandardMaterial3D.new()
		mb.albedo_texture = load("res://assets/emblemas/emblema_%s.png" % raca)
		mb.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mb.alpha_scissor_threshold = 0.4
		mb.metallic = 0.35
		mb.roughness = 0.35
		mb.albedo_color = Color(1.25, 1.15, 0.95)
		_mat_brasao[raca] = mb
	var att := BoneAttachment3D.new()
	att.bone_name = "spine_03"
	att.name = "Brasao"
	skel.add_child(att)
	var rest := skel.get_bone_global_rest(i)
	var centro := rest.origin + Vector3(0.0, 0.15, frente)
	var disco := CylinderMesh.new()
	disco.top_radius = 0.042
	disco.bottom_radius = 0.046
	disco.height = 0.008
	disco.radial_segments = 20
	var md := MeshInstance3D.new()
	md.mesh = disco
	md.material_override = _mat_bronze
	att.add_child(md)
	md.transform = rest.affine_inverse() * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), centro)
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var mq := MeshInstance3D.new()
	mq.mesh = q
	mq.material_override = _mat_brasao[raca]
	att.add_child(mq)
	mq.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, centro + Vector3(0, 0, 0.0045))
