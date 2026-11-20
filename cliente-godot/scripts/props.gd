extends RefCounted
# Móveis e ferramentas com forma de verdade (19/11): no lugar das caixas dos interiores e ao lado dos NPCs de ofício.
# Cada função devolve um Node3D com base em y = 0 e frente para +Z, em metros.
const FX = preload("res://scripts/fx.gd")
const Arq = preload("res://scripts/arquitetura.gd")

static var _m := {}


static func mat(nome: String) -> Material:
	if _m.has(nome):
		return _m[nome]
	var m: Material
	match nome:
		"madeira":
			m = Arq.material("madeira", Color(0.36, 0.25, 0.16), {"desgaste": 0.2})
		"madeira_escura":
			m = Arq.material("madeira", Color(0.22, 0.15, 0.1), {"desgaste": 0.2})
		"pedra":
			m = Arq.material("pedra", Color(0.32, 0.3, 0.29), {"textura": "unevenbrick", "metros": 1.4})
		"tijolo":
			m = Arq.material("pedra", Color(0.5, 0.36, 0.3), {"metros": 1.4})
		"ferro":
			m = Arq.material("metal", Color(0.22, 0.22, 0.24), {"rugosidade": 0.45, "metalico": 0.8})
		"aco":
			m = Arq.material("metal", Color(0.62, 0.64, 0.68), {"rugosidade": 0.28, "metalico": 0.9})
		"couro":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.36, 0.24, 0.16)
			s.roughness = 0.8
			m = s
		"brasa":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(1.0, 0.42, 0.1)
			s.emission_enabled = true
			s.emission = Color(1.0, 0.38, 0.08)
			s.emission_energy_multiplier = 3.2
			m = s
		"tecido":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.62, 0.18, 0.15)
			s.roughness = 1.0
			m = s
		_:
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.5, 0.5, 0.5)
			m = s
	_m[nome] = m
	return m


static func _peca(no: Node3D, mesh: Mesh, m: String, pos: Vector3, rot := Vector3.ZERO, esc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(m)
	mi.position = pos
	mi.rotation = rot
	mi.scale = esc
	no.add_child(mi)
	return mi


static func _cx(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func _cil(rt: float, rb: float, h: float, seg := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	return c


# bigorna sobre um toco: chifre, mesa plana, cintura fina e pé largo (≈ 0,85 m de altura)
static func bigorna() -> Node3D:
	var n := Node3D.new()
	_peca(n, _cil(0.26, 0.3, 0.42, 10), "madeira_escura", Vector3(0, 0.21, 0))           # toco
	_peca(n, _cx(0.34, 0.08, 0.24), "ferro", Vector3(0, 0.46, 0))                        # pé
	_peca(n, _cx(0.16, 0.16, 0.14), "ferro", Vector3(0, 0.58, 0))                        # cintura
	_peca(n, _cx(0.44, 0.11, 0.2), "ferro", Vector3(-0.03, 0.715, 0))                    # mesa
	var chifre := _cil(0.0, 0.07, 0.26, 8)
	_peca(n, chifre, "ferro", Vector3(0.31, 0.715, 0), Vector3(0, 0, PI * 0.5))           # chifre
	_peca(n, _cx(0.3, 0.03, 0.12), "aco", Vector3(0.0, 0.32, 0.13), Vector3(0.0, 0.0, 0.2))  # tenaz encostada
	return n


# forja: base de pedra, braseiro aceso, coifa e chaminé; fole de couro ao lado
static func fornalha(larg := 2.4, fundo := 1.6, altura_teto := 4.2) -> Node3D:
	var n := Node3D.new()
	_peca(n, _cx(larg, 0.9, fundo), "pedra", Vector3(0, 0.45, 0))
	_peca(n, _cx(larg * 0.7, 0.08, fundo * 0.6), "brasa", Vector3(0, 0.93, 0.05))
	_peca(n, _cx(larg + 0.1, 0.12, fundo + 0.1), "tijolo", Vector3(0, 0.96, 0))
	var coifa := _cil(0.3, larg * 0.62, 1.1, 4)
	_peca(n, coifa, "tijolo", Vector3(0, 2.25, -0.05), Vector3(0, PI * 0.25, 0), Vector3(1.0, 1.0, fundo / larg))
	_peca(n, _cx(0.5, maxf(altura_teto - 2.8, 0.6), 0.5), "tijolo", Vector3(0, 2.8 + maxf(altura_teto - 2.8, 0.6) * 0.5, -0.05))
	for s in [-1.0, 1.0]:  # pilares da coifa
		_peca(n, _cx(0.18, 0.85, 0.18), "pedra", Vector3(s * (larg * 0.5 - 0.12), 1.4, fundo * 0.5 - 0.15))
	# fole
	_peca(n, _cx(0.5, 0.18, 0.8), "couro", Vector3(larg * 0.5 + 0.4, 0.75, 0.0), Vector3(0.15, 0, 0))
	_peca(n, _cx(0.06, 0.06, 0.5), "madeira", Vector3(larg * 0.5 + 0.4, 0.86, 0.55))
	var f: Node3D = FX.fire(0.6, true)
	f.position = Vector3(0, 1.0, 0.05)
	n.add_child(f)
	return n


# lareira/fogão de pedra com boca aberta, fogo dentro, panela pendurada e consolo de madeira
static func lareira(larg := 2.2, fundo := 0.8, alt := 2.4) -> Node3D:
	var n := Node3D.new()
	for s in [-1.0, 1.0]:  # laterais da boca
		_peca(n, _cx(larg * 0.25, 1.2, fundo), "pedra", Vector3(s * larg * 0.375, 0.6, 0))
	_peca(n, _cx(larg, 0.25, fundo), "pedra", Vector3(0, 0.12, 0))                  # soleira
	_peca(n, _cx(larg * 0.5, 1.0, 0.15), "tijolo", Vector3(0, 0.75, -fundo * 0.42))   # fundo da boca
	_peca(n, _cx(larg + 0.15, 0.14, fundo + 0.15), "madeira_escura", Vector3(0, 1.27, 0.04))  # consolo
	_peca(n, _cil(larg * 0.32, larg * 0.48, alt - 1.34, 4), "pedra", Vector3(0, 1.34 + (alt - 1.34) * 0.5, -0.05), Vector3(0, PI * 0.25, 0), Vector3(1, 1, fundo / larg * 1.4))
	_peca(n, _cil(0.16, 0.13, 0.2, 10), "ferro", Vector3(0, 0.62, 0.0))              # panela
	_peca(n, _cx(0.02, 0.4, 0.02), "ferro", Vector3(0, 0.92, 0.0))
	var f: Node3D = FX.fire(0.45, true)
	f.position = Vector3(0, 0.28, 0.0)
	n.add_child(f)
	return n


# faíscas que saltam da bigorna (o ferreiro martelando)
static func faiscas() -> CPUParticles3D:
	var p := FX.emitter(18, 0.5, true, 0.035, Color(1.0, 0.85, 0.4), Color(1.0, 0.45, 0.1))
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -7.0, 0)
	p.explosiveness = 0.85
	return p


static func barril() -> Node3D:
	var n := Node3D.new()
	_peca(n, _cil(0.3, 0.3, 0.9, 14), "madeira", Vector3(0, 0.45, 0))
	_peca(n, _cil(0.34, 0.34, 0.5, 14), "madeira", Vector3(0, 0.45, 0))
	for y in [0.12, 0.45, 0.78]:
		_peca(n, _cil(0.345 if y == 0.45 else 0.32, 0.345 if y == 0.45 else 0.32, 0.04, 14), "ferro", Vector3(0, y, 0))
	return n


static func mesa(larg := 1.6, fundo := 1.0, alt := 0.78) -> Node3D:
	var n := Node3D.new()
	_peca(n, _cx(larg, 0.07, fundo), "madeira", Vector3(0, alt - 0.035, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_peca(n, _cx(0.08, alt - 0.07, 0.08), "madeira_escura", Vector3(sx * (larg * 0.5 - 0.08), (alt - 0.07) * 0.5, sz * (fundo * 0.5 - 0.08)))
	_peca(n, _cx(larg - 0.2, 0.05, 0.05), "madeira_escura", Vector3(0, 0.18, 0))
	return n


# bancada do ferreiro: mesa com ferramentas por cima
static func bancada(larg := 3.0, fundo := 1.2) -> Node3D:
	var n := mesa(larg, fundo, 0.9)
	for k in 4:
		_peca(n, _cx(0.05, 0.05, 0.32), "madeira_escura", Vector3(-larg * 0.35 + k * 0.3, 0.93, 0.1))
		_peca(n, _cx(0.12, 0.07, 0.06), "ferro", Vector3(-larg * 0.35 + k * 0.3, 0.95, 0.27))
	_peca(n, _cx(0.6, 0.02, 0.14), "aco", Vector3(larg * 0.2, 0.92, -0.1), Vector3(0, 0.3, 0))
	return n


# cabide de armas na parede: espadas, machado e escudo redondo
static func armas(larg := 5.0) -> Node3D:
	var n := Node3D.new()
	_peca(n, _cx(0.12, 0.12, larg), "madeira_escura", Vector3(0, 1.9, 0))
	_peca(n, _cx(0.12, 0.12, larg), "madeira_escura", Vector3(0, 0.5, 0))
	var k := 0
	var z := -larg * 0.5 + 0.5
	while z < larg * 0.5 - 0.3:
		if k % 3 == 2:  # escudo
			_peca(n, _cil(0.42, 0.42, 0.05, 16), "madeira", Vector3(0.1, 1.2, z), Vector3(0, 0, PI * 0.5))
			_peca(n, _cil(0.1, 0.1, 0.07, 10), "ferro", Vector3(0.14, 1.2, z), Vector3(0, 0, PI * 0.5))
		else:  # espada em pé: lâmina, guarda e cabo
			_peca(n, _cx(0.02, 1.0, 0.07), "aco", Vector3(0.08, 1.15, z))
			_peca(n, _cx(0.05, 0.04, 0.24), "ferro", Vector3(0.08, 0.63, z))
			_peca(n, _cx(0.04, 0.2, 0.04), "couro", Vector3(0.08, 0.5, z))
		z += 0.75
		k += 1
	return n


static func cama(larg := 2.0, fundo := 2.4) -> Node3D:
	var n := Node3D.new()
	_peca(n, _cx(larg, 0.35, fundo), "madeira", Vector3(0, 0.25, 0))
	_peca(n, _cx(larg * 0.94, 0.16, fundo * 0.92), "tecido", Vector3(0, 0.5, 0.05))
	_peca(n, _cx(larg * 0.6, 0.1, 0.4), "couro", Vector3(0, 0.6, -fundo * 0.38))
	_peca(n, _cx(larg, 0.9, 0.08), "madeira_escura", Vector3(0, 0.45, -fundo * 0.5))
	return n


static func prateleira(larg := 6.0, alt := 2.4, prof := 0.5) -> Node3D:
	var n := Node3D.new()
	for s in [-1.0, 1.0]:
		_peca(n, _cx(0.08, alt, prof), "madeira_escura", Vector3(s * larg * 0.5, alt * 0.5, 0))
	for k in 4:
		var y := 0.3 + k * (alt - 0.4) / 3.0
		_peca(n, _cx(larg, 0.05, prof), "madeira", Vector3(0, y, 0))
		var x := -larg * 0.5 + 0.3
		var i := 0
		while x < larg * 0.5 - 0.3:  # potes e caixas
			var tipo := (i * 7 + k * 3) % 3
			if tipo == 0:
				_peca(n, _cil(0.09, 0.11, 0.26, 8), "tijolo", Vector3(x, y + 0.15, 0))
			elif tipo == 1:
				_peca(n, _cx(0.28, 0.2, 0.3), "madeira", Vector3(x, y + 0.12, 0))
			x += 0.42 + 0.1 * float(i % 2)
			i += 1
	return n


# poste medieval (no lugar do poste de rua moderno): mastro de madeira, braço de ferro e lanterna com vidros
# que acendem à noite. Devolve peças [malha, material ("luz" = vidro aceso), Transform3D] para desenho em lote.
static func poste_pecas(alt := 4.0) -> Array:
	var p: Array = []
	p.append([_cx(0.62, 0.35, 0.62), "pedra", Transform3D(Basis.IDENTITY, Vector3(0, 0.17, 0))])
	p.append([_cil(0.09, 0.12, alt - 0.3, 8), "madeira_escura", Transform3D(Basis.IDENTITY, Vector3(0, 0.3 + (alt - 0.3) * 0.5, 0))])
	p.append([_cx(0.06, 0.06, 0.75), "ferro", Transform3D(Basis.IDENTITY, Vector3(0, alt - 0.25, 0.36))])
	p.append([_cx(0.04, 0.4, 0.04), "ferro", Transform3D(Basis(Vector3.RIGHT, 0.75), Vector3(0, alt - 0.45, 0.16))])
	var lz := 0.68
	var ly := alt - 0.68
	p.append([_cil(0.0, 0.2, 0.16, 4), "ferro", Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, ly + 0.3, lz))])   # chapéu
	p.append([_cx(0.26, 0.04, 0.26), "ferro", Transform3D(Basis.IDENTITY, Vector3(0, ly - 0.22, lz))])                # fundo
	p.append([_cx(0.2, 0.4, 0.2), "luz", Transform3D(Basis.IDENTITY, Vector3(0, ly, lz))])                            # vidro
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			p.append([_cx(0.03, 0.44, 0.03), "ferro", Transform3D(Basis.IDENTITY, Vector3(sx * 0.115, ly, lz + sz * 0.115))])
	p.append([_cx(0.08, 0.08, 0.08), "ferro", Transform3D(Basis.IDENTITY, Vector3(0, ly + 0.42, lz))])
	return p
