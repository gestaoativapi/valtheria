extends RefCounted
# Cidadela Rubra, vila orc com o bairro goblin (MESA-017.1 do ChatGPT, 18/11).
# Pedra vermelha, basalto, ferro bruto, madeira escura, couro e tecido de clã; brasas e fornalhas.
#   "Morada do Clã" (orc) 11 x 9 x 7 m: base de pedra vermelha, estrutura de madeira, telhado inclinado
#     de madeira com placas de metal, porta larga reforçada, estandarte, grades, ornamentos de osso
#   "Morada da Engrenagem" (goblin) 6 x 5 x 4 m: compacta e assimétrica, telhado torto, chaminé,
#     canos de cobre e anexo de oficina
#   "Forja do Sangue de Pedra" 17 x 14 x 11 m: fornalha aberta, chaminé lateral com fumaça, armas expostas
#   "Caneca do Guerreiro" (estalagem) 15 x 12 x 10 m e "Depósito" (armazém)
# Mesma técnica das outras vilas: uma MultiMesh por peça, sem luzes dinâmicas novas.
const VilaAna := preload("res://scripts/vila_ana.gd")
const FX = preload("res://scripts/fx.gd")
const Arq = preload("res://scripts/arquitetura.gd")

const COR := {"pedra": "#783D32", "escura": "#393536", "basalto": "#292B2D", "metal": "#55504A", "ferro": "#343638",
	"bronze": "#95613D", "cobre": "#A65E3D", "madeira": "#493024", "couro": "#68432E", "tecido": "#792D25", "luz": "#FF8A32", "osso": "#D9CDB2"}
static var _mats := {}


static func _m(nome: String) -> Material:
	if _mats.has(nome):
		return _mats[nome]
	var arq := {"pedra": ["pedra", {"bloco": Vector2(1.0, 0.5), "textura": "unevenbrick"}], "escura": ["pedra", {"bloco": Vector2(0.8, 0.4)}],
		"basalto": ["pedra", {"bloco": Vector2(1.2, 0.55)}], "madeira": ["madeira", {"variacao": 0.3}],
		"metal": ["metal", {}], "ferro": ["metal", {"rugosidade": 0.55}], "bronze": ["metal", {"rugosidade": 0.35, "metalico": 0.75}],
		"cobre": ["metal", {"rugosidade": 0.35, "metalico": 0.75}], "osso": ["reboco", {"desgaste": 0.5}]}
	if arq.has(nome):
		var c := Color(str(COR.get(nome, "#777777")))
		if arq[nome][0] == "pedra":
			c = c.darkened(0.05)
		_mats[nome] = Arq.material(arq[nome][0], c, arq[nome][1])
		return _mats[nome]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(str(COR.get(nome, "#777777")))
	m.roughness = 0.9
	match nome:
		"pedra", "escura", "basalto":
			m.albedo_texture = load("res://assets/world/t_rock.webp")
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(0.35, 0.35, 0.35)
			m.albedo_color = m.albedo_color.lightened(0.3)
		"metal", "ferro":
			m.metallic = 0.6
			m.roughness = 0.55
		"bronze", "cobre":
			m.metallic = 0.7
			m.roughness = 0.45
		"tecido", "couro":
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"luz":
			m.emission_enabled = true
			m.emission = m.albedo_color
			m.emission_energy_multiplier = 1.5
		"brasa":
			m.albedo_color = Color(1.0, 0.4, 0.1)
			m.emission_enabled = true
			m.emission = Color(0.91, 0.36, 0.14)
			m.emission_energy_multiplier = 3.0
	_mats[nome] = m
	return m


static func _cx(x: float, y: float, z: float) -> BoxMesh:
	return VilaAna._caixa(x, y, z)


static func _orc() -> Array:
	var p: Array = []
	p.append([_cx(11.4, 3.2, 9.4), _m("pedra"), Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0))])         # base de pedra vermelha
	p.append([_cx(10.6, 2.6, 8.6), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(0, 4.5, 0))])       # andar de madeira
	for x in [-5.3, 5.3]:
		for z in [-4.3, 4.3]:
			p.append([VilaAna._cil(0.28, 0.34, 6.2, 8), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(x, 3.1, z))])  # pilares externos
	p.append([VilaAna._prisma(12.4, 2.8, 10.4), _m("madeira"), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 7.2, 0))])  # telhado inclinado
	# placas de metal no telhado (duas águas)
	for lado in [-1.0, 1.0]:
		p.append([_cx(5.6, 0.1, 10.6), _m("ferro"), Transform3D(Basis(Vector3.BACK, lado * 0.46), Vector3(lado * 2.9, 7.25, 0))])
	p.append([_cx(3.0, 3.0, 0.4), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 4.8))])     # porta larga
	for y in [0.7, 1.6, 2.5]:
		p.append([_cx(3.2, 0.16, 0.48), _m("ferro"), Transform3D(Basis.IDENTITY, Vector3(0, y, 4.85))])
	for lado in [-1.0, 1.0]:
		p.append([_cx(1.2, 0.9, 0.2), _m("luz"), Transform3D(Basis.IDENTITY, Vector3(lado * 3.2, 4.5, 4.35))])  # janela
		for g in 3:
			p.append([_cx(0.08, 1.0, 0.1), _m("ferro"), Transform3D(Basis.IDENTITY, Vector3(lado * 3.2 - 0.4 + g * 0.4, 4.5, 4.45))])  # grade
		# chifres/ossos sobre a porta
		p.append([VilaAna._cil(0.0, 0.14, 1.1, 6), _m("osso"), Transform3D(Basis(Vector3.BACK, lado * 0.9), Vector3(lado * 1.0, 3.6, 5.0))])
	# estandarte do clã pendurado na fachada
	p.append([_cx(1.6, 3.0, 0.06), _m("tecido"), Transform3D(Basis.IDENTITY, Vector3(4.1, 3.6, 4.75))])
	p.append([_cx(2.0, 0.12, 0.12), _m("ferro"), Transform3D(Basis.IDENTITY, Vector3(4.1, 5.15, 4.8))])
	return p


static func _goblin() -> Array:
	var p: Array = []
	p.append([_cx(6.0, 2.4, 5.0), _m("escura"), Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0))])
	p.append([_cx(5.4, 1.3, 4.6), _m("madeira"), Transform3D(Basis.from_euler(Vector3(0, 0.0, 0.04)), Vector3(0.2, 3.0, 0))])
	p.append([VilaAna._prisma(6.8, 1.5, 5.6), _m("madeira"), Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis.from_euler(Vector3(0.0, 0.0, 0.08)), Vector3(0.3, 4.3, 0))])  # telhado torto
	p.append([_cx(2.6, 1.8, 2.6), _m("madeira"), Transform3D(Basis.from_euler(Vector3(0, 0.15, 0)), Vector3(-3.6, 0.9, -0.8))])  # anexo de oficina
	p.append([VilaAna._prisma(3.0, 0.9, 3.0), _m("ferro"), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-3.6, 2.2, -0.8))])
	p.append([VilaAna._cil(0.32, 0.38, 2.2, 8), _m("cobre"), Transform3D(Basis.IDENTITY, Vector3(1.8, 4.9, -1.2))])  # chaminé de cobre
	p.append([VilaAna._cil(0.12, 0.12, 3.6, 6), _m("cobre"), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.6, 2.7, 2.6))])  # cano na fachada
	p.append([_cx(1.1, 1.7, 0.25), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(-1.2, 0.85, 2.55))])  # porta na escala goblin
	p.append([VilaAna._cil(0.35, 0.35, 0.1, 10), _m("luz"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(1.4, 1.6, 2.55))])  # janela redonda
	p.append([VilaAna._cil(0.5, 0.5, 0.08, 8), _m("bronze"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-1.2, 2.2, 2.6))])  # placa de oficina (engrenagem)
	return p


static func _forja() -> Array:
	var p: Array = []
	p.append([_cx(17.0, 0.8, 14.0), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0))])
	p.append([_cx(16.0, 5.6, 12.0), _m("pedra"), Transform3D(Basis.IDENTITY, Vector3(0, 3.6, -0.5))])
	p.append([VilaAna._prisma(17.0, 3.0, 13.0), _m("ferro"), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 7.9, -0.5))])
	p.append([VilaAna._cil(1.2, 1.5, 10.0, 8), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(-8.6, 6.0, -3.0))])  # chaminé lateral
	# fornalha aberta na frente: arco de basalto com brasas
	p.append([_cx(5.0, 3.6, 1.0), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(-3.5, 2.6, 6.0))])
	p.append([_cx(3.4, 2.2, 0.5), _m("brasa"), Transform3D(Basis.IDENTITY, Vector3(-3.5, 2.0, 6.4))])
	# armas rústicas expostas num cavalete
	p.append([_cx(5.0, 0.2, 0.3), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(4.0, 2.2, 7.6))])
	for k in 5:
		p.append([_cx(0.12, 2.4, 0.06), _m("ferro"), Transform3D(Basis(Vector3.BACK, -0.2 + k * 0.1), Vector3(2.2 + k * 0.9, 1.6, 7.75))])
	for x in [-6.5, 0.5]:
		p.append([_cx(1.2, 0.8, 0.6), _m("basalto"), Transform3D(Basis.IDENTITY, Vector3(x, 0.8, 9.0))])
		p.append([_cx(1.5, 0.35, 0.6), _m("metal"), Transform3D(Basis.IDENTITY, Vector3(x, 1.35, 9.0))])
	p.append([_cx(2.2, 2.2, 0.08), _m("tecido"), Transform3D(Basis.IDENTITY, Vector3(5.5, 4.8, 5.8))])
	return p


static func _estalagem() -> Array:
	var p: Array = []
	p.append([_cx(15.0, 4.2, 12.0), _m("pedra"), Transform3D(Basis.IDENTITY, Vector3(0, 2.1, 0))])
	p.append([_cx(14.4, 3.4, 11.4), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(0, 5.9, 0))])
	p.append([VilaAna._prisma(16.0, 3.0, 13.0), _m("ferro"), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 9.1, 0))])
	p.append([_cx(14.0, 0.4, 3.0), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(0, 4.4, 7.4))])   # varanda reforçada
	for x in [-6.4, -2.1, 2.1, 6.4]:
		p.append([VilaAna._cil(0.3, 0.36, 4.4, 8), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(x, 2.2, 8.6))])
	p.append([_cx(3.0, 3.0, 0.3), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 6.1))])
	for x in [-4.5, -1.5, 1.5, 4.5]:
		p.append([_cx(1.2, 1.1, 0.2), _m("luz"), Transform3D(Basis.IDENTITY, Vector3(x, 6.0, 5.8))])
	p.append([VilaAna._cil(0.8, 0.8, 0.12, 10), _m("bronze"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 3.6, 6.25))])  # placa caneca e machado
	for lado in [-1.0, 1.0]:
		p.append([_cx(1.6, 3.4, 0.06), _m("tecido"), Transform3D(Basis.IDENTITY, Vector3(lado * 5.0, 6.0, 5.85))])
	return p


static func _armazem() -> Array:
	var p: Array = []
	p.append([_cx(14.0, 5.0, 11.0), _m("escura"), Transform3D(Basis.IDENTITY, Vector3(0, 2.5, 0))])
	p.append([VilaAna._prisma(15.0, 2.4, 12.0), _m("madeira"), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 6.2, 0))])
	p.append([_cx(5.0, 3.6, 0.4), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(0, 1.8, 5.6))])
	for k in 3:
		p.append([_cx(1.2, 1.0, 1.2), _m("madeira"), Transform3D(Basis.IDENTITY, Vector3(-4.5 + k * 1.4, 0.5, 6.8))])  # caixas de carga
	return p


static func construir(w: Node3D, root: Node3D, tipo: String, xfs: Array, escala := 1.0) -> void:
	if xfs.is_empty():
		return
	var pecas: Array
	var raio := 5.0
	match tipo:
		"goblin":
			pecas = _goblin()
			raio = 3.2
		"forja":
			pecas = _forja()
			raio = 8.5
		"estalagem":
			pecas = _estalagem()
			raio = 7.5
		"armazem":
			pecas = _armazem()
			raio = 7.0
		_:
			pecas = _orc()
	var xs: Array = []
	for t in xfs:
		xs.append((t as Transform3D) * Transform3D(Basis.from_scale(Vector3.ONE * escala), Vector3.ZERO))
	VilaAna._lote(root, pecas, xs, 900.0)
	var org := root.global_position if root.is_inside_tree() else root.position
	for t in xfs:
		var o: Vector3 = (t as Transform3D).origin + org
		w.block(o.x, o.z, raio * escala)
	if tipo == "forja":
		for t in xs:
			VilaAna._fumaca(root, (t as Transform3D) * Vector3(-8.6, 11.2, -3.0))
			var fogo: Node3D = FX.fire(1.3)
			fogo.position = (t as Transform3D) * Vector3(-3.5, 1.4, 7.0)
			root.add_child(fogo)
