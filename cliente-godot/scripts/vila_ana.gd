extends RefCounted
# Vila anã de Pedra Alta (MESA-016.1 do ChatGPT, 18/11): pedra cinza de montanha, basalto, ferro, bronze,
# telhados baixos de ardósia, janelas âmbar, runas e fogo. Peças desenhadas em lote (uma MultiMesh por
# peça para todas as casas) e efeitos de fogo e fumaça só nas forjas.
#   casa padrão "Morada da Rocha" 9 x 8 x 5 m, fachada arredondada, fundo apoiado em rocha
#   "Grande Forja" 16 x 14 x 12 m, cúpula de cobre, chaminé alta com fumaça, boca de fornalha acesa
#   estalagem "Descanso do Martelo" 14 x 12 x 9 m, dois pavimentos, varanda de pedra, janelas âmbar
#   "Cofre das Sete Fechaduras" 13 x 11 x 7 m, baixo, portão de ferro com sete travas
#   "Salão dos Ancestrais" 22 x 20 x 15 m, octogonal, colunas grossas, estátuas e braseiros
const FX = preload("res://scripts/fx.gd")

const COR := {"pedra": "#777B7D", "clara": "#A6A39A", "basalto": "#34383D", "metal": "#59636A", "bronze": "#A66E3F",
	"cobre": "#B66D45", "madeira": "#493326", "telhado": "#3A3F45", "luz": "#FFB347", "cristal": "#E5A94F"}

static var _mats := {}


static func _m(nome: String) -> StandardMaterial3D:
	if _mats.has(nome):
		return _mats[nome]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(str(COR.get(nome, "#777777")))
	m.roughness = 0.9
	match nome:
		"pedra", "clara", "basalto":
			m.albedo_texture = load("res://assets/world/t_rock.webp")
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(0.35, 0.35, 0.35)
			m.albedo_color = m.albedo_color.lightened(0.35)
		"metal":
			m.metallic = 0.7
			m.roughness = 0.45
		"bronze", "cobre":
			m.metallic = 0.75
			m.roughness = 0.4
		"luz", "cristal":
			m.emission_enabled = true
			m.emission = m.albedo_color
			m.emission_energy_multiplier = 1.6
		"brasa":
			m.albedo_color = Color(1.0, 0.45, 0.1)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.4, 0.08)
			m.emission_energy_multiplier = 3.0
	_mats[nome] = m
	return m


static func _caixa(sx: float, sy: float, sz: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(sx, sy, sz)
	return b


static func _cil(r0: float, r1: float, h: float, lados := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r0
	c.bottom_radius = r1
	c.height = h
	c.radial_segments = lados
	return c


static func _prisma(sx: float, sy: float, sz: float) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = Vector3(sx, sy, sz)
	return p


# peças [malha, material, Transform3D] de cada construção, frente para +Z, base em y = 0
static func _casa() -> Array:
	var p: Array = []
	p.append([_caixa(9.4, 0.6, 8.4), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0))])        # alicerce
	p.append([_caixa(9.0, 3.4, 6.0), _m("pedra"), Transform3D(Basis.IDENTITY, Vector3(0, 2.3, -1.0))])     # corpo
	var frente := _cil(4.5, 4.5, 3.4, 20)
	p.append([frente, _m("pedra"), Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.45)), Vector3(0, 2.3, 1.6))])  # fachada arredondada
	p.append([_prisma(10.0, 1.4, 8.6), _m("telhado"), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 4.7, 0.0))])  # telhado baixo
	p.append([_caixa(10.2, 0.25, 8.8), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(0, 4.05, 0.0))])  # beiral
	p.append([_caixa(1.0, 2.2, 1.0), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(2.6, 5.3, -2.0))])  # chaminé curta
	p.append([_caixa(1.6, 2.4, 0.3), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(0, 1.8, 3.6))])      # porta reforçada
	for y in [1.1, 1.9, 2.7]:
		p.append([_caixa(1.7, 0.12, 0.34), _m("metal"), Transform3D(Basis.IDENTITY, Vector3(0, y, 3.62))])   # faixas de ferro
	p.append([_cil(0.95, 0.95, 0.3, 14), _m("madeira"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 3.0, 3.6))])  # arco da porta
	for lado in [-1.0, 1.0]:
		p.append([_caixa(1.0, 0.8, 0.2), _m("luz"), Transform3D(Basis.IDENTITY, Vector3(lado * 2.7, 2.5, 3.25))])  # janela âmbar
		p.append([_caixa(1.25, 1.05, 0.15), _m("metal"), Transform3D(Basis.IDENTITY, Vector3(lado * 2.7, 2.5, 3.2))])  # moldura
	p.append([_cil(0.35, 0.35, 0.08, 6), _m("bronze"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 3.6, 3.75))])  # runa
	# rocha no fundo: a casa parece apoiada na encosta
	p.append([_cil(3.2, 4.2, 3.6, 7), _m("basalto"), Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.4)), Vector3(0, 1.6, -4.3))])
	return p


static func _forja() -> Array:
	var p: Array = []
	p.append([_caixa(16.0, 0.8, 14.0), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0))])
	p.append([_caixa(15.0, 6.0, 12.0), _m("pedra"), Transform3D(Basis.IDENTITY, Vector3(0, 3.8, 0))])
	var cup := SphereMesh.new()
	cup.radius = 5.0
	cup.height = 5.0
	cup.is_hemisphere = true
	cup.radial_segments = 20
	cup.rings = 8
	p.append([cup, _m("cobre"), Transform3D(Basis.IDENTITY, Vector3(-1.5, 6.8, -0.5))])      # cúpula de fundição
	p.append([_caixa(16.0, 0.5, 13.0), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(0, 6.9, 0))])
	p.append([_cil(1.1, 1.4, 9.0, 10), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(5.0, 11.0, -3.0))])  # chaminé alta
	p.append([_cil(1.5, 1.5, 0.6, 10), _m("metal"), Transform3D(Basis.IDENTITY, Vector3(5.0, 15.3, -3.0))])
	# boca da fornalha com brasas na fachada
	p.append([_caixa(4.0, 3.0, 0.6), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(-3.0, 2.3, 6.2))])
	p.append([_caixa(2.6, 1.8, 0.4), _m("brasa"), Transform3D(Basis.IDENTITY, Vector3(-3.0, 2.0, 6.4))])
	p.append([_cil(1.3, 1.3, 0.62, 12), _m("basalto"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-3.0, 3.8, 6.2))])
	# portão largo de madeira e ferro
	p.append([_caixa(4.2, 4.2, 0.4), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(3.5, 2.9, 6.1))])
	for y in [1.6, 2.9, 4.2]:
		p.append([_caixa(4.4, 0.18, 0.45), _m("metal"), Transform3D(Basis.IDENTITY, Vector3(3.5, y, 6.15))])
	# bigornas e área de trabalho externa
	for x in [-5.5, 0.0]:
		p.append([_caixa(1.1, 0.8, 0.5), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(x, 0.8, 8.8))])
		p.append([_caixa(1.4, 0.35, 0.55), _m("metal"), Transform3D(Basis.IDENTITY, Vector3(x, 1.35, 8.8))])
	p.append([_cil(0.4, 0.4, 0.1, 6), _m("cristal"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(3.5, 5.6, 6.35))])  # runa de calor
	return p


static func _estalagem() -> Array:
	var p: Array = []
	p.append([_caixa(14.0, 0.8, 12.0), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0))])
	p.append([_caixa(13.0, 4.0, 10.0), _m("pedra"), Transform3D(Basis.IDENTITY, Vector3(0, 2.8, -0.5))])
	p.append([_caixa(13.4, 3.2, 10.4), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(0, 6.4, -0.5))])  # 2º pavimento de carvalho
	p.append([_prisma(14.4, 2.2, 11.6), _m("telhado"), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 9.1, -0.5))])
	# varanda de pedra com colunas
	p.append([_caixa(13.0, 0.4, 3.0), _m("clara"), Transform3D(Basis.IDENTITY, Vector3(0, 4.9, 5.4))])
	for x in [-5.5, -1.8, 1.8, 5.5]:
		p.append([_cil(0.35, 0.42, 4.2, 10), _m("clara"), Transform3D(Basis.IDENTITY, Vector3(x, 2.9, 6.4))])
	p.append([_caixa(2.6, 2.8, 0.3), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(0, 2.2, 4.6))])   # porta dupla
	for x in [-4.2, -1.4, 1.4, 4.2]:
		p.append([_caixa(1.1, 1.1, 0.2), _m("luz"), Transform3D(Basis.IDENTITY, Vector3(x, 6.4, 4.75))])   # janelas âmbar
	for x in [-4.4, 4.4]:
		p.append([_caixa(1.3, 1.2, 0.2), _m("luz"), Transform3D(Basis.IDENTITY, Vector3(x, 2.6, 4.55))])
	p.append([_cil(0.7, 0.7, 0.12, 12), _m("bronze"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 4.2, 4.8))])  # placa do martelo
	p.append([_caixa(1.3, 3.0, 1.3), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(-5.0, 9.5, -3.0))])  # chaminé da lareira
	return p


static func _cofre() -> Array:
	var p: Array = []
	p.append([_caixa(13.0, 5.5, 11.0), _m("pedra"), Transform3D(Basis.IDENTITY, Vector3(0, 2.75, 0))])
	p.append([_caixa(13.6, 1.0, 11.6), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(0, 6.0, 0))])
	p.append([_cil(5.5, 6.5, 3.0, 8), _m("basalto"), Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.6)), Vector3(0, 1.5, -6.5))])
	p.append([_caixa(4.0, 4.0, 0.5), _m("metal"), Transform3D(Basis.IDENTITY, Vector3(0, 2.0, 5.6))])     # portão de ferro
	for k in 7:
		p.append([_cil(0.18, 0.18, 0.15, 8), _m("bronze"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-1.5 + k * 0.5, 2.2 + (k % 2) * 0.4, 5.9))])  # sete travas
	return p


static func _salao() -> Array:
	var p: Array = []
	p.append([_cil(12.0, 12.5, 1.2, 8), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0))])
	p.append([_cil(10.0, 10.5, 9.0, 8), _m("clara"), Transform3D(Basis.IDENTITY, Vector3(0, 5.7, 0))])
	p.append([_cil(5.0, 10.8, 5.0, 8), _m("telhado"), Transform3D(Basis.IDENTITY, Vector3(0, 12.7, 0))])
	p.append([_cil(0.0, 5.2, 2.0, 8), _m("bronze"), Transform3D(Basis.IDENTITY, Vector3(0, 16.2, 0))])
	for k in 8:
		var a := TAU * k / 8.0 + PI / 8.0
		p.append([_cil(0.9, 1.1, 9.5, 10), _m("pedra"), Transform3D(Basis.IDENTITY, Vector3(sin(a) * 10.8, 5.9, cos(a) * 10.8))])  # colunas grossas
	p.append([_caixa(5.0, 7.0, 0.6), _m("bronze"), Transform3D(Basis.IDENTITY, Vector3(0, 4.7, 10.5))])   # portas monumentais
	# estátuas de ancestrais ladeando a porta (pedestal, corpo, cabeça, barba e martelo)
	for lado in [-1.0, 1.0]:
		var x: float = lado * 5.0
		p.append([_caixa(2.2, 1.4, 2.2), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(x, 0.7, 13.0))])
		p.append([_cil(0.9, 1.2, 3.2, 10), _m("clara"), Transform3D(Basis.IDENTITY, Vector3(x, 3.0, 13.0))])
		var cab := SphereMesh.new()
		cab.radius = 0.65
		cab.height = 1.3
		p.append([cab, _m("clara"), Transform3D(Basis.IDENTITY, Vector3(x, 5.1, 13.0))])
		p.append([_cil(0.1, 0.6, 1.4, 8), _m("clara"), Transform3D(Basis(Vector3.RIGHT, PI), Vector3(x, 4.3, 13.5))])
		p.append([_caixa(0.3, 2.6, 0.3), _m("metal"), Transform3D(Basis.IDENTITY, Vector3(x + lado * 1.2, 3.2, 13.3))])
		p.append([_caixa(1.0, 0.7, 0.7), _m("metal"), Transform3D(Basis.IDENTITY, Vector3(x + lado * 1.2, 4.6, 13.3))])
	return p


static func _lote(root: Node3D, pecas: Array, xfs: Array, vis_end: float) -> void:
	for peca in pecas:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = peca[0]
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, (xfs[i] as Transform3D) * (peca[2] as Transform3D))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = peca[1]
		mi.visibility_range_end = vis_end
		root.add_child(mi)


# xfs no espaço de root (cidade). tipo: casa | forja | estalagem | cofre | salao. escala opcional (1 = medidas do parecer)
static func construir(w: Node3D, root: Node3D, tipo: String, xfs: Array, escala := 1.0) -> void:
	if xfs.is_empty():
		return
	var pecas: Array
	var raio := 4.5
	match tipo:
		"forja":
			pecas = _forja()
			raio = 8.0
		"estalagem":
			pecas = _estalagem()
			raio = 7.0
		"cofre":
			pecas = _cofre()
			raio = 6.5
		"salao":
			pecas = _salao()
			raio = 12.0
		_:
			pecas = _casa()
	var xs: Array = []
	for t in xfs:
		xs.append((t as Transform3D) * Transform3D(Basis.from_scale(Vector3.ONE * escala), Vector3.ZERO))
	_lote(root, pecas, xs, 900.0)
	var org := root.global_position if root.is_inside_tree() else root.position
	for t in xfs:
		var o: Vector3 = (t as Transform3D).origin + org
		w.block(o.x, o.z, raio * escala)
	if tipo == "forja":
		for t in xs:
			_fumaca(root, (t as Transform3D) * Vector3(5.0, 15.8, -3.0))
			var fogo: Node3D = FX.fire(1.2)
			fogo.position = (t as Transform3D) * Vector3(-3.0, 1.6, 6.9)
			root.add_child(fogo)


static func _fumaca(root: Node3D, pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 28
	p.lifetime = 5.0
	p.position = pos
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.25, 0.5, 0.0)
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 1.8
	var cv := Curve.new()
	cv.add_point(Vector2(0, 0.6))
	cv.add_point(Vector2(1, 3.2))
	p.scale_amount_curve = cv
	var g := Gradient.new()
	g.set_color(0, Color(0.32, 0.3, 0.3, 0.55))
	g.set_color(1, Color(0.6, 0.6, 0.62, 0.0))
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.5))
	m.albedo_texture = ImageTexture.create_from_image(img)
	q.material = m
	p.mesh = q
	p.visibility_range_end = 400.0
	root.add_child(p)
	# brasas subindo junto
	var b := CPUParticles3D.new()
	b.amount = 16
	b.lifetime = 1.6
	b.position = pos
	b.direction = Vector3.UP
	b.spread = 25.0
	b.initial_velocity_min = 2.0
	b.initial_velocity_max = 3.5
	b.gravity = Vector3(0, -0.6, 0)
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.12, 0.12)
	var m2 := StandardMaterial3D.new()
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.albedo_color = Color(1.0, 0.6, 0.2)
	m2.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q2.material = m2
	b.mesh = q2
	b.visibility_range_end = 150.0
	root.add_child(b)
