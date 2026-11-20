extends RefCounted
# Vilas das demais raças, a partir das especificações do ChatGPT (MESA-018.1 em diante).
# Cada raça: paleta própria + peças [malha, material, Transform3D] de cada construção (frente = +Z, base y = 0).
# Desenho em lote com VilaAna._lote (uma MultiMesh por peça), sem luzes dinâmicas novas.
const VilaAna := preload("res://scripts/vila_ana.gd")
const FX = preload("res://scripts/fx.gd")
const Arq = preload("res://scripts/arquitetura.gd")

const PALETAS := {
	# Umbraval, elfos negros (MESA-018.1): pedra vulcânica, obsidiana, prata e cristal violeta
	"sombrio": {"pedra": "#39343D", "obsidiana": "#211F29", "pedra2": "#514653", "madeira": "#30252F", "metal": "#777786",
		"prata": "#B7B5C5", "cristal": "#9860D5", "cristal_claro": "#C7A6F2", "tecido": "#392344", "luz": "#A879E8"},
	# Clã das Presas, homens-fera (MESA-019.1): pedra, madeira, osso, couro, vegetação
	"beastman": {"pedra": "#716451", "pedra2": "#393A32", "madeira": "#60432D", "madeira_clara": "#987047", "osso": "#D5C6A0",
		"couro": "#704A32", "tecido": "#8A573B", "vegetacao": "#3D4F2C", "luz": "#E5A34D"},
	# Fortaleza Glacial, gigantes de gelo (MESA-019.1): granito, gelo, cristal azul — escala de gigante
	"gigante": {"pedra": "#68727A", "pedra2": "#343C46", "gelo": "#B9DCE8", "gelo_profundo": "#3A5468", "cristal": "#8EDCF5",
		"metal": "#667984", "prata": "#AABBC3", "madeira": "#514A43", "tecido": "#526D83", "luz": "#A9E9FF"},
	# Pico do Dragão, dragonitas (MESA-019.1): rocha vulcânica, basalto, bronze, escamas e cristais elementais
	"draconato": {"pedra": "#39343A", "obsidiana": "#25272C", "pedra2": "#68504A", "metal": "#555D66", "bronze": "#A66D43",
		"escama": "#6A2C25", "escama_azul": "#426D8C", "cristal": "#B77A55", "cristal_claro": "#A47AD6", "luz": "#F18A45"},
}
static var _mats := {}


static func _m(raca: String, nome: String) -> Material:
	var k := raca + ":" + nome
	if _mats.has(k):
		return _mats[k]
	var pal: Dictionary = PALETAS.get(raca, {})
	var arq := {"pedra": ["pedra", {}], "pedra2": ["pedra", {"bloco": Vector2(0.7, 0.35)}],
		"obsidiana": ["pedra", {"bloco": Vector2(1.3, 0.6), "rugosidade": 0.4, "variacao": 0.12}],
		"madeira": ["madeira", {}], "madeira_clara": ["madeira", {"variacao": 0.3}],
		"metal": ["metal", {}], "prata": ["metal", {"rugosidade": 0.3, "metalico": 0.8}], "bronze": ["metal", {"rugosidade": 0.35, "metalico": 0.75}],
		"escama": ["telha", {"bloco": Vector2(0.38, 0.26), "rugosidade": 0.5}], "escama_azul": ["telha", {"bloco": Vector2(0.38, 0.26), "rugosidade": 0.5}],
		"osso": ["reboco", {"desgaste": 0.5}], "vegetacao": ["palha", {"variacao": 0.35}], "gelo_profundo": ["telha", {"bloco": Vector2(0.6, 0.4), "rugosidade": 0.7, "variacao": 0.15, "desgaste": 0.2}]}
	if arq.has(nome):
		var c := Color(str(pal.get(nome, "#777777")))
		if arq[nome][0] == "pedra" and nome != "gelo_profundo":
			c = c.darkened(0.02 if raca == "sombrio" else 0.08)
		if raca == "gigante":
			var o: Dictionary = (arq[nome][1] as Dictionary).duplicate()
			o["bloco"] = (o.get("bloco", Vector2(0.9, 0.42)) as Vector2) * 1.8  # escala de gigante
			_mats[k] = Arq.material(arq[nome][0], c, o)
		else:
			_mats[k] = Arq.material(arq[nome][0], c, arq[nome][1])
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(str(pal.get(nome, "#777777")))
	m.roughness = 0.85
	match nome:
		"pedra", "pedra2", "obsidiana", "basalto", "gelo_pedra":
			m.albedo_texture = load("res://assets/world/t_rock.webp")
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(0.35, 0.35, 0.35)
			m.albedo_color = m.albedo_color.lightened(0.3 if raca in ["sombrio"] else 0.55)
			if nome == "obsidiana":
				m.roughness = 0.35
		"metal", "prata", "bronze", "ouro":
			m.metallic = 0.75
			m.roughness = 0.35
		"tecido":
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"luz", "cristal", "cristal_claro", "gelo":
			m.emission_enabled = true
			m.emission = m.albedo_color
			m.emission_energy_multiplier = 1.4 if nome != "gelo" else 0.4
			if nome == "gelo":
				m.albedo_color.a = 0.85
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.roughness = 0.1
		"brasa":
			m.albedo_color = Color(1.0, 0.45, 0.15)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.4, 0.1)
			m.emission_energy_multiplier = 3.0
	_mats[k] = m
	return m


static func _cx(x: float, y: float, z: float) -> BoxMesh:
	return VilaAna._caixa(x, y, z)


static func _cil(a: float, b: float, h: float, n := 12) -> CylinderMesh:
	return VilaAna._cil(a, b, h, n)


static func _T(pos: Vector3, b := Basis.IDENTITY) -> Transform3D:
	return Transform3D(b, pos)


# ---------------------------------------------------------------- Umbraval (elfos negros)
static func _sombrio(tipo: String) -> Array:
	var R := "sombrio"
	var M := func(n: String) -> Material: return _m(R, n)
	var p: Array = []
	match tipo:
		"casa":
			# Morada vertical: plinto de obsidiana, corpo alto, telhado em ponta suave, janelas altas e estreitas
			p.append([_cx(9.0, 0.6, 8.0), M.call("obsidiana"), _T(Vector3(0, 0.3, 0))])
			p.append([_cx(8.0, 7.0, 7.0), M.call("pedra"), _T(Vector3(0, 4.1, 0))])
			p.append([_cil(0.0, 6.0, 4.6, 4), M.call("obsidiana"), _T(Vector3(0, 9.9, 0), Basis(Vector3.UP, PI * 0.25))])
			for lado in [-1.0, 1.0]:
				p.append([_cil(0.0, 0.45, 3.0, 6), M.call("prata"), _T(Vector3(lado * 3.8, 9.1, 3.3))])       # pináculos
				p.append([_cil(0.35, 0.35, 7.0, 6), M.call("pedra2"), _T(Vector3(lado * 3.8, 4.1, 3.3))])     # colunas de canto
				p.append([_cx(0.7, 2.8, 0.2), M.call("luz"), _T(Vector3(lado * 2.2, 5.2, 3.55))])             # janela alta
				p.append([_cx(0.95, 3.1, 0.15), M.call("metal"), _T(Vector3(lado * 2.2, 5.2, 3.5))])
			p.append([_cx(1.4, 2.6, 0.3), M.call("madeira"), _T(Vector3(0, 1.9, 3.55))])                      # porta arqueada
			p.append([_cil(0.7, 0.7, 0.3, 12), M.call("madeira"), _T(Vector3(0, 3.2, 3.55), Basis(Vector3.RIGHT, PI * 0.5))])
			p.append([_cil(0.0, 0.3, 0.9, 5), M.call("cristal"), _T(Vector3(0, 4.6, 3.7))])                   # cristal sobre a entrada
			p.append([_cil(0.3, 0.0, 0.5, 5), M.call("cristal"), _T(Vector3(0, 3.95, 3.7))])
		"estalagem":
			p.append([_cx(14.0, 0.7, 11.0), M.call("obsidiana"), _T(Vector3(0, 0.35, 0))])
			p.append([_cx(12.0, 8.0, 9.0), M.call("pedra"), _T(Vector3(-1.0, 4.7, 0))])
			p.append([_cil(0.0, 8.0, 3.6, 4), M.call("obsidiana"), _T(Vector3(-1.0, 10.5, 0), Basis(Vector3.UP, PI * 0.25))])
			p.append([_cil(2.2, 2.4, 13.0, 8), M.call("pedra2"), _T(Vector3(5.8, 6.5, -2.0))])                # torre lateral
			p.append([_cil(0.0, 2.8, 4.0, 8), M.call("obsidiana"), _T(Vector3(5.8, 15.0, -2.0))])
			p.append([_cil(0.0, 0.35, 1.6, 5), M.call("cristal"), _T(Vector3(5.8, 17.6, -2.0))])
			p.append([_cx(11.0, 0.35, 2.6), M.call("prata"), _T(Vector3(-1.0, 4.4, 5.5))])                   # varanda elevada
			for x in [-5.5, -2.5, 0.5, 3.5]:
				p.append([_cil(0.22, 0.22, 4.2, 8), M.call("pedra2"), _T(Vector3(x, 2.4, 6.6))])               # arcos da varanda
			for x in [-5.0, -2.0, 1.0]:
				p.append([_cx(0.8, 2.6, 0.2), M.call("luz"), _T(Vector3(x, 6.6, 4.55))])
			p.append([_cx(2.4, 3.0, 0.3), M.call("madeira"), _T(Vector3(-1.0, 2.2, 4.6))])
			p.append([_cil(0.7, 0.7, 0.1, 16), M.call("prata"), _T(Vector3(-1.0, 4.0, 4.7), Basis(Vector3.RIGHT, PI * 0.5))])  # placa da lua
		"forja":
			p.append([_cx(13.0, 0.7, 12.0), M.call("obsidiana"), _T(Vector3(0, 0.35, 0))])
			p.append([_cx(12.0, 5.0, 10.0), M.call("pedra2"), _T(Vector3(0, 3.2, 0))])
			p.append([_cil(1.5, 6.5, 4.0, 6), M.call("obsidiana"), _T(Vector3(0, 7.7, 0))])                   # cúpula angular
			p.append([_cil(0.55, 0.75, 8.0, 6), M.call("pedra"), _T(Vector3(4.2, 9.5, -3.0))])               # chaminé estreita
			p.append([_cx(3.2, 2.4, 0.6), M.call("obsidiana"), _T(Vector3(-2.5, 1.9, 5.2))])
			p.append([_cx(2.2, 1.5, 0.4), M.call("brasa"), _T(Vector3(-2.5, 1.6, 5.45))])
			p.append([_cx(2.8, 3.2, 0.3), M.call("madeira"), _T(Vector3(2.8, 2.3, 5.1))])
			p.append([_cil(0.0, 0.25, 0.8, 5), M.call("cristal"), _T(Vector3(2.8, 4.4, 5.3))])
		"armazem":
			p.append([_cx(12.0, 4.5, 10.0), M.call("obsidiana"), _T(Vector3(0, 2.25, 0))])
			p.append([_cx(12.6, 0.6, 10.6), M.call("pedra2"), _T(Vector3(0, 4.8, 0))])
			for x in [-4.0, -1.3, 1.3, 4.0]:
				p.append([_cx(1.8, 2.6, 0.4), M.call("pedra"), _T(Vector3(x, 1.9, 4.85))])                     # nichos
				p.append([_cil(0.25, 0.25, 4.5, 8), M.call("prata"), _T(Vector3(x + 1.35, 2.25, 5.1))])        # pilares
			p.append([_cil(0.5, 0.5, 0.1, 12), M.call("cristal_claro"), _T(Vector3(0, 3.9, 5.1), Basis(Vector3.RIGHT, PI * 0.5))])
		"santuario":
			# Santuário da Lua Velada: octogonal, oito arcos altos, torre central com cristal, escadaria
			p.append([_cil(10.5, 11.0, 1.2, 8), M.call("obsidiana"), _T(Vector3(0, 0.6, 0))])
			for k in 4:
				p.append([_cx(8.0 - k * 1.2, 0.35, 1.0), M.call("pedra2"), _T(Vector3(0, 0.2 + k * 0.35, 11.5 - k * 0.6))])  # escadaria
			p.append([_cil(8.0, 8.4, 8.0, 8), M.call("pedra"), _T(Vector3(0, 5.2, 0))])
			for k in 8:
				var a := TAU * k / 8.0 + PI / 8.0
				p.append([_cil(0.4, 0.5, 10.5, 8), M.call("prata"), _T(Vector3(sin(a) * 9.4, 6.4, cos(a) * 9.4))])  # colunas esguias
				p.append([_cx(1.6, 5.0, 0.2), M.call("luz"), _T(Vector3(sin(a + PI / 8.0) * 8.45, 5.5, cos(a + PI / 8.0) * 8.45), Basis(Vector3.UP, a + PI / 8.0))])  # vitrais violeta
			p.append([_cil(5.0, 9.0, 3.0, 8), M.call("obsidiana"), _T(Vector3(0, 10.7, 0))])
			p.append([_cil(2.4, 2.8, 8.0, 8), M.call("pedra2"), _T(Vector3(0, 15.0, 0))])                     # torre central
			p.append([_cil(0.0, 3.0, 3.5, 8), M.call("obsidiana"), _T(Vector3(0, 20.7, 0))])
			p.append([_cil(0.0, 1.0, 3.2, 6), M.call("cristal"), _T(Vector3(0, 23.6, 0))])                    # cristal no topo
			p.append([_cil(1.0, 0.0, 1.4, 6), M.call("cristal"), _T(Vector3(0, 21.3, 0))])
			for lado in [-1.0, 1.0]:
				p.append([_cx(1.4, 1.0, 1.4), M.call("obsidiana"), _T(Vector3(lado * 4.2, 1.7, 11.0))])        # guardiões
				p.append([_cil(0.4, 0.65, 3.0, 8), M.call("pedra2"), _T(Vector3(lado * 4.2, 3.7, 11.0))])
				p.append([_cil(0.0, 0.35, 0.9, 6), M.call("cristal_claro"), _T(Vector3(lado * 4.2, 5.7, 11.0))])
	return p


# ---------------------------------------------------------------- Clã das Presas (homens-fera)
static func _fera(tipo: String) -> Array:
	var M := func(n: String) -> Material: return _m("beastman", n)
	var p: Array = []
	match tipo:
		"casa":
			# Morada das Presas: base circular de pedra, parede de madeira, cobertura orgânica, varanda e totem da linhagem
			p.append([_cil(5.0, 5.2, 1.0, 14), M.call("pedra"), _T(Vector3(0, 0.5, 0))])
			p.append([_cil(4.2, 4.4, 3.0, 14), M.call("madeira"), _T(Vector3(0, 2.5, 0))])
			p.append([_cil(0.4, 5.8, 3.6, 14), M.call("vegetacao"), _T(Vector3(0, 5.6, 0))])
			p.append([_cil(0.0, 0.8, 1.4, 8), M.call("madeira_clara"), _T(Vector3(0, 8.1, 0))])
			p.append([_cx(5.0, 0.3, 2.4), M.call("madeira_clara"), _T(Vector3(0, 1.1, 5.0))])            # varanda
			for x in [-2.2, 2.2]:
				p.append([_cil(0.18, 0.2, 3.4, 8), M.call("madeira"), _T(Vector3(x, 2.6, 6.0))])
			p.append([_cx(1.4, 2.4, 0.3), M.call("couro"), _T(Vector3(0, 2.1, 4.25))])                   # porta de couro
			p.append([_cil(0.25, 0.3, 4.2, 8), M.call("madeira"), _T(Vector3(3.6, 2.1, 5.8))])          # totem
			var cab := SphereMesh.new()
			cab.radius = 0.55
			cab.height = 1.0
			p.append([cab, M.call("osso"), _T(Vector3(3.6, 4.5, 5.8))])
			for lado in [-1.0, 1.0]:
				p.append([_cil(0.0, 0.22, 0.55, 5), M.call("osso"), _T(Vector3(3.6 + lado * 0.35, 5.0, 5.8))])  # orelhas do totem
			p.append([_cx(1.0, 1.8, 0.05), M.call("tecido"), _T(Vector3(-3.6, 3.0, 4.0))])               # símbolo da linhagem
		"estalagem":
			p.append([_cx(16.0, 1.0, 13.0), M.call("pedra"), _T(Vector3(0, 0.5, 0))])
			p.append([_cx(15.0, 6.0, 11.0), M.call("madeira"), _T(Vector3(0, 4.0, -0.5))])
			p.append([_cil(6.5, 6.5, 15.6, 12), M.call("vegetacao"), _T(Vector3(0, 7.0, -0.5), Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.55)))])  # telhado curvo
			p.append([_cx(15.0, 0.35, 3.0), M.call("madeira_clara"), _T(Vector3(0, 3.6, 6.4))])
			for x in [-6.5, -2.2, 2.2, 6.5]:
				p.append([_cil(0.3, 0.35, 3.6, 8), M.call("madeira"), _T(Vector3(x, 1.8, 7.6))])
			p.append([_cx(3.0, 3.0, 0.3), M.call("couro"), _T(Vector3(0, 2.5, 5.05))])
			p.append([_cil(0.0, 0.35, 2.2, 6), M.call("osso"), _T(Vector3(-1.6, 6.8, 5.2), Basis(Vector3.BACK, 0.6))])  # brasão de presa
			p.append([_cil(0.0, 0.35, 2.2, 6), M.call("osso"), _T(Vector3(1.6, 6.8, 5.2), Basis(Vector3.BACK, -0.6))])
			for x in [-5.0, 5.0]:
				p.append([_cx(1.4, 1.2, 0.2), M.call("luz"), _T(Vector3(x, 4.6, 5.0))])
		"forja":
			p.append([_cx(14.0, 0.8, 12.0), M.call("pedra2"), _T(Vector3(0, 0.4, 0))])
			p.append([_cx(12.0, 4.5, 9.0), M.call("pedra2"), _T(Vector3(0, 3.0, -1.0))])
			p.append([VilaAna._prisma(13.0, 2.6, 10.0), M.call("madeira"), _T(Vector3(0, 6.5, -1.0), Basis(Vector3.UP, PI * 0.5))])
			p.append([_cil(0.8, 1.0, 6.0, 8), M.call("pedra"), _T(Vector3(4.0, 8.0, -3.0))])
			p.append([_cx(3.0, 2.2, 0.5), M.call("pedra"), _T(Vector3(-2.5, 1.9, 3.7))])
			p.append([_cx(2.0, 1.4, 0.3), M.call("brasa"), _T(Vector3(-2.5, 1.6, 3.95))])
			p.append([_cx(1.4, 0.8, 0.6), M.call("pedra2"), _T(Vector3(2.5, 0.8, 5.0))])
		"armazem":
			for x in [-4.5, 4.5]:
				for z in [-3.5, 3.5]:
					p.append([_cil(0.3, 0.35, 2.0, 8), M.call("madeira"), _T(Vector3(x, 1.0, z))])          # palafitas contra a umidade
			p.append([_cx(11.0, 4.0, 9.0), M.call("madeira_clara"), _T(Vector3(0, 4.0, 0))])
			p.append([VilaAna._prisma(12.0, 2.4, 10.0), M.call("vegetacao"), _T(Vector3(0, 7.2, 0), Basis(Vector3.UP, PI * 0.5))])
			p.append([_cx(8.0, 0.2, 1.2), M.call("madeira"), _T(Vector3(0, 3.2, 5.0))])                    # prateleira externa
		"santuario":
			# Salão das Cinco Presas: circular, cinco totens das linhagens e grande símbolo central
			p.append([_cil(11.0, 11.5, 1.5, 20), M.call("pedra"), _T(Vector3(0, 0.75, 0))])
			p.append([_cil(9.0, 9.3, 6.0, 20), M.call("madeira"), _T(Vector3(0, 4.5, 0))])
			p.append([_cil(1.0, 11.5, 7.0, 20), M.call("vegetacao"), _T(Vector3(0, 11.0, 0))])
			var anel := TorusMesh.new()
			anel.inner_radius = 2.2
			anel.outer_radius = 2.8
			p.append([anel, M.call("osso"), _T(Vector3(0, 6.2, 9.3), Basis(Vector3.RIGHT, PI * 0.5))])        # símbolo central
			for k in 5:
				var a := -PI * 0.5 + k * PI / 4.0
				var pos := Vector3(sin(a) * 12.5, 0, cos(a) * 12.5)
				p.append([_cil(0.5, 0.6, 7.0, 8), M.call("madeira"), _T(pos + Vector3(0, 3.5, 0))])
				var c2 := SphereMesh.new()
				c2.radius = 0.9
				c2.height = 1.6
				p.append([c2, M.call("osso"), _T(pos + Vector3(0, 7.6, 0))])
	return p


# ---------------------------------------------------------------- Fortaleza Glacial (gigantes de gelo)
static func _gigante(tipo: String) -> Array:
	var M := func(n: String) -> Material: return _m("gigante", n)
	var p: Array = []
	match tipo:
		"casa":
			# Morada do Colosso: blocos maciços, telhado de gelo reforçado, entrada monumental, poucas aberturas
			p.append([_cx(22.0, 1.4, 18.0), M.call("pedra2"), _T(Vector3(0, 0.7, 0))])
			p.append([_cx(20.0, 10.0, 16.0), M.call("pedra"), _T(Vector3(0, 6.4, 0))])
			p.append([VilaAna._prisma(23.0, 6.0, 19.0), M.call("gelo_profundo"), _T(Vector3(0, 14.4, 0), Basis(Vector3.UP, PI * 0.5))])
			p.append([_cx(5.0, 8.0, 0.6), M.call("madeira"), _T(Vector3(0, 5.4, 8.1))])                    # porta de gigante
			p.append([_cx(5.6, 0.4, 0.8), M.call("metal"), _T(Vector3(0, 9.6, 8.1))])
			for lado in [-1.0, 1.0]:
				p.append([_cx(1.6, 2.4, 0.3), M.call("luz"), _T(Vector3(lado * 6.0, 8.0, 8.1))])
				p.append([_cil(0.0, 1.0, 4.5, 6), M.call("cristal"), _T(Vector3(lado * 10.0, 13.2, 8.0))])  # cristais de gelo nos cantos
				p.append([_cx(2.2, 11.0, 2.2), M.call("pedra2"), _T(Vector3(lado * 10.0, 6.9, 8.0))])
		"estalagem":
			p.append([_cx(30.0, 1.5, 24.0), M.call("pedra2"), _T(Vector3(0, 0.75, 0))])
			p.append([_cx(28.0, 13.0, 22.0), M.call("pedra"), _T(Vector3(0, 8.0, 0))])
			p.append([VilaAna._prisma(31.0, 8.0, 25.0), M.call("gelo_profundo"), _T(Vector3(0, 18.5, 0), Basis(Vector3.UP, PI * 0.5))])
			for x in [-11.0, -4.0, 4.0, 11.0]:
				p.append([_cx(2.6, 14.0, 2.6), M.call("pedra2"), _T(Vector3(x, 7.0, 11.6))])
			p.append([_cx(7.0, 10.0, 0.8), M.call("madeira"), _T(Vector3(0, 6.5, 11.2))])
			p.append([_cx(3.0, 6.0, 3.0), M.call("pedra2"), _T(Vector3(-8.0, 22.0, -5.0))])                 # chaminé da lareira
		"forja":
			p.append([_cx(28.0, 1.5, 22.0), M.call("pedra2"), _T(Vector3(0, 0.75, 0))])
			p.append([_cx(26.0, 14.0, 20.0), M.call("pedra2"), _T(Vector3(0, 8.5, 0))])
			p.append([_cil(2.4, 3.2, 14.0, 8), M.call("pedra"), _T(Vector3(8.0, 20.0, -5.0))])               # chaminé alta
			p.append([_cx(9.0, 7.0, 1.0), M.call("pedra"), _T(Vector3(-4.0, 5.0, 10.4))])
			p.append([_cx(6.0, 4.5, 0.6), M.call("brasa"), _T(Vector3(-4.0, 4.0, 10.9))])                    # fornalha monumental
			p.append([_cx(4.0, 2.4, 2.0), M.call("metal"), _T(Vector3(6.0, 2.7, 13.0))])                     # bigorna colossal
		"armazem":
			p.append([_cx(24.0, 14.0, 20.0), M.call("pedra2"), _T(Vector3(0, 7.0, 0))])
			p.append([_cx(25.0, 2.0, 21.0), M.call("pedra"), _T(Vector3(0, 15.0, 0))])
			p.append([_cx(8.0, 9.0, 1.0), M.call("metal"), _T(Vector3(0, 4.5, 10.2))])
			for x in [-8.0, 8.0]:
				p.append([_cil(0.0, 1.2, 5.0, 6), M.call("cristal"), _T(Vector3(x, 18.5, 8.0))])
		"santuario":
			# Trono dos Antigos: templo-fortaleza, colunas de gelo, estátuas e cristal suspenso
			p.append([_cx(42.0, 3.0, 34.0), M.call("pedra2"), _T(Vector3(0, 1.5, 0))])
			p.append([_cx(30.0, 22.0, 24.0), M.call("pedra"), _T(Vector3(0, 14.0, -2.0))])
			p.append([VilaAna._prisma(32.0, 10.0, 26.0), M.call("gelo_profundo"), _T(Vector3(0, 30.0, -2.0), Basis(Vector3.UP, PI * 0.5))])
			for k in 6:
				var x := -17.5 + k * 7.0
				p.append([_cil(1.4, 1.6, 24.0, 8), M.call("gelo"), _T(Vector3(x, 15.0, 14.0))])              # colunas de gelo
			for lado in [-1.0, 1.0]:
				p.append([_cx(5.0, 3.0, 5.0), M.call("pedra2"), _T(Vector3(lado * 10.0, 4.5, 19.0))])
				p.append([_cil(1.8, 2.6, 9.0, 8), M.call("pedra"), _T(Vector3(lado * 10.0, 10.5, 19.0))])     # estátuas de ancestrais
				var cab := SphereMesh.new()
				cab.radius = 1.7
				cab.height = 3.2
				p.append([cab, M.call("pedra"), _T(Vector3(lado * 10.0, 16.6, 19.0))])
			p.append([_cil(0.0, 3.5, 6.0, 6), M.call("cristal"), _T(Vector3(0, 41.0, -2.0))])                # cristal suspenso
			p.append([_cil(3.5, 0.0, 6.0, 6), M.call("cristal"), _T(Vector3(0, 35.0, -2.0))])
			p.append([_cx(10.0, 14.0, 1.0), M.call("madeira"), _T(Vector3(0, 10.0, 10.2))])
	return p


# ---------------------------------------------------------------- Pico do Dragão (dragonitas)
static func _draco(tipo: String) -> Array:
	var M := func(n: String) -> Material: return _m("draconato", n)
	var p: Array = []
	match tipo:
		"casa":
			# Morada da Escama: pedra vulcânica, telhado angular, aberturas amplas, sacada com suportes
			p.append([_cx(12.0, 1.0, 10.0), M.call("obsidiana"), _T(Vector3(0, 0.5, 0))])
			p.append([_cx(11.0, 7.0, 9.0), M.call("pedra"), _T(Vector3(0, 4.5, 0))])
			p.append([_cil(0.0, 8.4, 4.5, 4), M.call("escama"), _T(Vector3(0, 10.25, 0), Basis(Vector3.UP, PI * 0.25))])
			p.append([_cx(7.0, 0.4, 2.6), M.call("pedra2"), _T(Vector3(0, 5.0, 5.6))])                      # sacada
			for x in [-3.0, 3.0]:
				p.append([_cx(0.4, 2.0, 2.4), M.call("bronze"), _T(Vector3(x, 4.0, 5.4), Basis(Vector3.RIGHT, 0.6))])  # suportes
			p.append([_cx(4.0, 3.6, 0.3), M.call("luz"), _T(Vector3(0, 2.8, 4.55))])                         # abertura ampla
			p.append([_cx(4.6, 0.4, 0.5), M.call("bronze"), _T(Vector3(0, 4.8, 4.6))])
			for lado in [-1.0, 1.0]:
				p.append([_cil(0.0, 0.5, 1.6, 4), M.call("cristal"), _T(Vector3(lado * 5.2, 8.8, 4.2))])
		"estalagem":
			p.append([_cx(19.0, 1.2, 15.0), M.call("obsidiana"), _T(Vector3(0, 0.6, 0))])
			p.append([_cx(17.0, 11.0, 13.0), M.call("pedra"), _T(Vector3(0, 6.7, 0))])
			p.append([_cx(18.0, 0.6, 14.0), M.call("pedra2"), _T(Vector3(0, 12.5, 0))])                     # terraço panorâmico
			p.append([_cil(5.0, 5.0, 0.5, 16), M.call("bronze"), _T(Vector3(0, 13.1, 0))])                  # plataforma de pouso
			var anel := TorusMesh.new()
			anel.inner_radius = 4.6
			anel.outer_radius = 5.0
			p.append([anel, M.call("luz"), _T(Vector3(0, 13.4, 0))])
			for x in [-5.5, -1.8, 1.8, 5.5]:
				p.append([_cx(2.0, 3.0, 0.3), M.call("luz"), _T(Vector3(x, 8.0, 6.55))])
			p.append([_cx(4.0, 4.5, 0.4), M.call("bronze"), _T(Vector3(0, 3.4, 6.6))])
		"forja":
			p.append([_cx(18.0, 1.2, 15.0), M.call("obsidiana"), _T(Vector3(0, 0.6, 0))])
			p.append([_cx(16.0, 9.0, 13.0), M.call("pedra"), _T(Vector3(0, 5.7, 0))])
			p.append([_cil(1.6, 2.2, 10.0, 6), M.call("obsidiana"), _T(Vector3(0, 15.0, -2.0))])              # exaustão vertical
			for x in [-5.0, 0.0, 5.0]:
				p.append([_cx(0.5, 8.0, 0.2), M.call("brasa"), _T(Vector3(x, 5.5, 6.55))])                    # canais de calor
			p.append([_cx(4.0, 3.0, 0.4), M.call("brasa"), _T(Vector3(-5.0, 2.2, 6.6))])
		"armazem":
			p.append([_cx(15.0, 9.0, 12.0), M.call("obsidiana"), _T(Vector3(0, 4.5, 0))])
			p.append([_cx(16.0, 0.8, 13.0), M.call("pedra2"), _T(Vector3(0, 9.4, 0))])
			p.append([_cx(6.0, 5.5, 0.5), M.call("metal"), _T(Vector3(0, 2.75, 6.1))])
			for x in [-5.0, 5.0]:
				p.append([_cx(2.4, 4.0, 0.4), M.call("escama_azul"), _T(Vector3(x, 4.0, 6.1))])
		"santuario":
			# Santuário da Primeira Chama: torre central, arcos em forma de asa, cristais elementais e altar
			p.append([_cil(14.0, 15.0, 2.0, 10), M.call("obsidiana"), _T(Vector3(0, 1.0, 0))])
			p.append([_cil(4.5, 5.5, 26.0, 8), M.call("pedra"), _T(Vector3(0, 15.0, 0))])
			p.append([_cil(0.0, 6.0, 6.0, 8), M.call("escama"), _T(Vector3(0, 31.0, 0))])
			for lado in [-1.0, 1.0]:
				for k in 3:
					p.append([_cx(1.2, 14.0 - k * 3.0, 1.2), M.call("bronze"), _T(Vector3(lado * (6.0 + k * 3.0), 10.0 - k * 1.5, 0), Basis(Vector3.BACK, lado * (0.6 + k * 0.25)))])  # arcos-asa
			var cores := ["luz", "cristal_claro", "escama_azul", "cristal"]
			for k in 4:
				var a := TAU * k / 4.0 + PI * 0.25
				p.append([_cil(0.0, 1.0, 4.5, 6), M.call(cores[k]), _T(Vector3(sin(a) * 10.0, 4.3, cos(a) * 10.0))])  # cristais elementais
			p.append([_cx(4.0, 1.4, 2.6), M.call("pedra2"), _T(Vector3(0, 2.7, 9.0))])                       # altar
			p.append([_cil(0.0, 0.6, 1.6, 6), M.call("luz"), _T(Vector3(0, 4.2, 9.0))])
	return p


static func pecas(raca: String, tipo: String) -> Array:
	match raca:
		"sombrio":
			return _sombrio(tipo)
		"beastman":
			return _fera(tipo)
		"gigante":
			return _gigante(tipo)
		"draconato":
			return _draco(tipo)
	return []


const RAIO := {"casa": 4.6, "estalagem": 7.5, "forja": 7.0, "armazem": 6.5, "santuario": 11.0}
# escala de cada construção por raça (as medidas do parecer são em escala real; a vila média tem lotes de ~12 m)
const ESCALA := {
	"sombrio": {"casa": 0.8, "estalagem": 0.75, "forja": 0.75, "armazem": 0.72, "santuario": 0.62},
	"beastman": {"casa": 0.85, "estalagem": 0.7, "forja": 0.75, "armazem": 0.75, "santuario": 0.6},
	"gigante": {"casa": 0.45, "estalagem": 0.42, "forja": 0.4, "armazem": 0.42, "santuario": 0.38},
	"draconato": {"casa": 0.72, "estalagem": 0.6, "forja": 0.6, "armazem": 0.62, "santuario": 0.48},
}


static func escala(raca: String, tipo: String) -> float:
	return float((ESCALA.get(raca, {}) as Dictionary).get(tipo, 0.75))


static func construir(w: Node3D, root: Node3D, raca: String, tipo: String, xfs: Array, escala := 1.0) -> void:
	var ps := pecas(raca, tipo)
	if xfs.is_empty() or ps.is_empty():
		return
	var xs: Array = []
	for t in xfs:
		xs.append((t as Transform3D) * Transform3D(Basis.from_scale(Vector3.ONE * escala), Vector3.ZERO))
	VilaAna._lote(root, ps, xs, 900.0)
	var org := root.global_position if root.is_inside_tree() else root.position
	for t in xfs:
		var o: Vector3 = (t as Transform3D).origin + org
		w.block(o.x, o.z, float(RAIO.get(tipo, 5.0)) * escala)
	if tipo == "forja":
		var bocal := {"sombrio": Vector3(4.2, 13.6, -3.0), "beastman": Vector3(4.0, 11.2, -3.0), "gigante": Vector3(8.0, 27.2, -5.0), "draconato": Vector3(0, 20.2, -2.0)}
		for t in xs:
			VilaAna._fumaca(root, (t as Transform3D) * (bocal.get(raca, Vector3(0, 10, 0)) as Vector3))
