class_name Reliquias
extends RefCounted
# Relíquias de Criaturas (27/11, escolha de Robson): as armas S e SS ganham uma criatura própria.
#   S  : cabeça da criatura na guarda (a lâmina sai da boca) ou na cabeça da arma, emblema gravado dos dois lados,
#        fio aceso no elemento, aura parada; no golpe, rastro de luz do elemento e clarão no acerto.
#   SS : tudo do S maior e mais forte + asas/espinhos na guarda, coroa de runas girando, olhos acesos, aura dupla;
#        no golpe forte o espírito da criatura surge e avança (ver efeitos_reliquia.gd).
# Tudo é montado por código (peças simples, sem arquivo pago); os emblemas vêm de ferramentas/armas/emblemas_reliquias.py.

const CRIATURA := {
	"espada": "dragao", "espadao": "dragao",
	"adaga": "lobo", "punhal": "lobo", "duplas": "lobo",
	"martelo": "golem", "machado": "golem", "escudo": "golem",
	"lanca": "serpente",
	"cajado": "fenix", "cetro": "fenix",
	"arco": "grifo",
}
# elemento e cores: [brilho, cor, sombra, metal]
const DADOS := {
	"dragao": {"elemento": "fogo", "cores": [Color(1.0, 0.82, 0.48), Color(1.0, 0.35, 0.12), Color(0.35, 0.05, 0.02), Color(0.32, 0.1, 0.08)],
		"nome_s": "Presa do Dragão Rubro", "nome_ss": "Ira do Dragão Ancestral"},
	"lobo": {"elemento": "sombra", "cores": [Color(0.86, 0.8, 1.0), Color(0.52, 0.36, 1.0), Color(0.1, 0.05, 0.22), Color(0.16, 0.14, 0.22)],
		"nome_s": "Garra do Lobo Sombrio", "nome_ss": "Uivo da Lua Negra"},
	"golem": {"elemento": "terra", "cores": [Color(1.0, 0.88, 0.55), Color(0.86, 0.56, 0.22), Color(0.18, 0.13, 0.08), Color(0.36, 0.32, 0.28)],
		"nome_s": "Punho do Golem", "nome_ss": "Coração da Montanha"},
	"serpente": {"elemento": "gelo", "cores": [Color(0.88, 0.98, 1.0), Color(0.3, 0.78, 1.0), Color(0.03, 0.15, 0.26), Color(0.55, 0.7, 0.8)],
		"nome_s": "Presa da Serpente Glacial", "nome_ss": "Tormenta do Mar Gelado"},
	"fenix": {"elemento": "luz", "cores": [Color(1.0, 0.97, 0.8), Color(1.0, 0.68, 0.2), Color(0.3, 0.12, 0.02), Color(0.85, 0.66, 0.32)],
		"nome_s": "Pena da Fênix", "nome_ss": "Renascer da Fênix Dourada"},
	"grifo": {"elemento": "tempestade", "cores": [Color(0.92, 0.99, 1.0), Color(0.55, 0.84, 1.0), Color(0.07, 0.18, 0.28), Color(0.62, 0.6, 0.55)],
		"nome_s": "Asa do Grifo", "nome_ss": "Fúria do Grifo da Tempestade"},
}
static var _mats := {}
const Enfeites = preload("res://scripts/enfeites.gd")


static func nome(kind: String, n: int) -> String:
	var c: String = CRIATURA.get(kind, "")
	if c == "" or n < 5:
		return ""
	return str(DADOS[c]["nome_ss" if n >= 6 else "nome_s"])


static func _m(chave: String, cor: Color, metal := 0.0, rug := 0.5, emissao := 0.0, aditivo := false) -> StandardMaterial3D:
	if _mats.has(chave):
		return _mats[chave]
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.metallic = metal
	m.roughness = rug
	if emissao > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = emissao
	if aditivo:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_fog = true
	_mats[chave] = m
	return m


static func _p(pai: Node3D, malha: Mesh, mat: Material, pos: Vector3, base := Basis.IDENTITY, esc := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = Transform3D(base.scaled(esc) if esc != Vector3.ONE else base, pos)
	pai.add_child(mi)
	return mi


# cone/tronco ao longo de +Z (de z0 a z1)
static func _tronco(pai: Node3D, z0: float, z1: float, r0: float, r1: float, mat: Material, lados := 8, desloc := Vector3.ZERO, giro := Basis.IDENTITY) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r0
	cm.top_radius = r1
	cm.height = absf(z1 - z0)
	cm.radial_segments = lados
	cm.rings = 1
	return _p(pai, cm, mat, desloc + giro * Vector3(0, 0, (z0 + z1) * 0.5), giro * Basis(Vector3.RIGHT, PI * 0.5))


# chifre/pena/espinho: cone que sai de "de" na direção "dir"
static func _ponta(pai: Node3D, de: Vector3, dir: Vector3, comp: float, r: float, mat: Material, lados := 6) -> void:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = 0.0
	cm.height = comp
	cm.radial_segments = lados
	cm.rings = 1
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_p(pai, cm, mat, de + y * comp * 0.5, Basis(x, y, z))


# ---------- cabeças das criaturas (focinho em +Z, topo em +Y, tamanho t = largura da cabeça) ----------
# cabeça esculpida (assets/armas/reliquias/<tipo>.glb, gerada por ferramentas/armas/cabecas_reliquias.py);
# os materiais vêm por nome (metal, escuro, olho, brilho, dente) e são trocados pelos da criatura
static func cabeca(tipo: String, t: float, cores: Array, ss: bool) -> Node3D:
	var arq := "res://assets/armas/reliquias/%s.glb" % tipo
	if ResourceLoader.exists(arq):
		var cena := (load(arq) as PackedScene).instantiate() as Node3D
		var mats := {
			"metal": _m("r_metal_%s" % tipo, (cores[3] as Color), 0.85, 0.32),
			"escuro": _m("r_esc_%s" % tipo, (cores[2] as Color).lerp(Color(0.05, 0.05, 0.06), 0.4), 0.6, 0.45),
			"olho": _m("r_olho_%s_%s" % [tipo, ss], cores[0], 0.0, 0.2, 6.0 if ss else 3.5),
			"brilho": _m("r_bri_%s" % tipo, cores[1], 0.2, 0.3, 2.4),
			"dente": _m("r_dente", Color(0.95, 0.92, 0.85), 0.0, 0.4),
		}
		for mi in cena.find_children("*", "MeshInstance3D", true, false):
			var malha := (mi as MeshInstance3D).mesh
			for i in malha.get_surface_count():
				var nm := String(malha.surface_get_material(i).resource_name) if malha.surface_get_material(i) else ""
				var chave := nm.get_slice(".", 0)
				if mats.has(chave):
					(mi as MeshInstance3D).set_surface_override_material(i, mats[chave])
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cena.scale = Vector3.ONE * t * 1.15
		var h0 := Node3D.new()
		h0.add_child(cena)
		return h0
	var h := Node3D.new()
	var metal := _m("r_metal_%s" % tipo, (cores[3] as Color), 0.85, 0.32)
	var escuro := _m("r_esc_%s" % tipo, (cores[2] as Color).lerp(Color(0.05, 0.05, 0.06), 0.4), 0.6, 0.45)
	var olho := _m("r_olho_%s_%s" % [tipo, ss], cores[0], 0.0, 0.2, 6.0 if ss else 3.5)
	var brilho := _m("r_bri_%s" % tipo, cores[1], 0.2, 0.3, 2.4)
	match tipo:
		"dragao":
			_tronco(h, -0.35 * t, 0.25 * t, 0.5 * t, 0.36 * t, metal, 7)                       # crânio
			_tronco(h, 0.2 * t, 0.95 * t, 0.34 * t, 0.16 * t, metal, 6, Vector3(0, 0.06 * t, 0))   # focinho
			_tronco(h, 0.15 * t, 0.85 * t, 0.26 * t, 0.1 * t, escuro, 6, Vector3(0, -0.2 * t, 0), Basis(Vector3.RIGHT, 0.32))  # mandíbula aberta
			for s in [-1.0, 1.0]:
				_ponta(h, Vector3(0.28 * s * t, 0.3 * t, -0.15 * t), Vector3(0.35 * s, 0.6, -1.0), (1.25 if ss else 0.95) * t, 0.12 * t, escuro)  # chifres
				_ponta(h, Vector3(0.36 * s * t, 0.05 * t, -0.25 * t), Vector3(0.9 * s, 0.1, -0.6), 0.5 * t, 0.07 * t, escuro)               # espinhos da face
				_p(h, _esfera(0.075 * t), olho, Vector3(0.24 * s * t, 0.24 * t, 0.3 * t))
				for i in 3:
					_ponta(h, Vector3(0.11 * s * t, -0.02 * t, (0.45 + 0.15 * i) * t), Vector3(0, -1, 0.15), 0.14 * t, 0.03 * t, _m("r_dente", Color(0.95, 0.92, 0.85), 0.0, 0.4))
			_ponta(h, Vector3(0, 0.34 * t, 0.05 * t), Vector3(0, 1, -0.6), 0.35 * t, 0.06 * t, escuro)  # crista
			_p(h, _esfera(0.12 * t), brilho, Vector3(0, -0.05 * t, 0.55 * t))  # brasa na garganta
		"lobo":
			_tronco(h, -0.3 * t, 0.25 * t, 0.45 * t, 0.36 * t, metal, 7)
			_tronco(h, 0.2 * t, 0.9 * t, 0.26 * t, 0.1 * t, metal, 6, Vector3(0, -0.04 * t, 0))
			_tronco(h, 0.2 * t, 0.75 * t, 0.18 * t, 0.07 * t, escuro, 6, Vector3(0, -0.2 * t, 0), Basis(Vector3.RIGHT, 0.28))
			for s in [-1.0, 1.0]:
				_ponta(h, Vector3(0.22 * s * t, 0.3 * t, -0.05 * t), Vector3(0.25 * s, 1, -0.25), (0.6 if ss else 0.45) * t, 0.13 * t, metal, 4)  # orelhas
				_p(h, _esfera(0.07 * t), olho, Vector3(0.2 * s * t, 0.15 * t, 0.3 * t))
				for i in 3:
					_ponta(h, Vector3(0.38 * s * t, (0.1 - 0.12 * i) * t, -0.2 * t), Vector3(0.8 * s, -0.2, -1.0), 0.4 * t, 0.07 * t, escuro, 4)  # juba
		"golem":
			_p(h, BoxMesh.new(), metal, Vector3.ZERO, Basis.IDENTITY, Vector3(0.95, 0.85, 0.8) * t)
			_p(h, BoxMesh.new(), olho, Vector3(0, 0.08 * t, 0.41 * t), Basis.IDENTITY, Vector3(0.6, 0.1, 0.02) * t)  # fenda dos olhos
			_p(h, BoxMesh.new(), brilho, Vector3(0, -0.22 * t, 0.41 * t), Basis.IDENTITY, Vector3(0.36, 0.06, 0.02) * t)
			for i in (5 if ss else 3):
				var x := (float(i) / maxf((5 if ss else 3) - 1, 1) - 0.5) * 0.7 * t
				_ponta(h, Vector3(x, 0.42 * t, 0), Vector3(x * 1.5, 1, 0), (0.45 - absf(x) * 0.4) * t, 0.12 * t, escuro, 5)  # coroa de rocha
		"serpente":
			_tronco(h, -0.3 * t, 0.3 * t, 0.42 * t, 0.3 * t, metal, 6, Vector3.ZERO, Basis.IDENTITY)
			_tronco(h, 0.25 * t, 0.85 * t, 0.28 * t, 0.12 * t, metal, 6, Vector3(0, -0.03 * t, 0))
			for s in [-1.0, 1.0]:
				for i in (4 if ss else 3):
					_ponta(h, Vector3(0.3 * s * t, 0.1 * t, (-0.2 + 0.12 * i) * t), Vector3(1.0 * s, 0.7, -0.5), (0.55 - 0.08 * i) * t, 0.08 * t, brilho, 4)  # barbatanas de gelo
				_p(h, _esfera(0.065 * t), olho, Vector3(0.2 * s * t, 0.16 * t, 0.32 * t))
				_ponta(h, Vector3(0.09 * s * t, -0.1 * t, 0.7 * t), Vector3(0, -1, 0.3), 0.22 * t, 0.035 * t, _m("r_dente", Color(0.95, 0.92, 0.85), 0.0, 0.4))
		"fenix":
			_p(h, _esfera(0.42 * t), metal, Vector3.ZERO)
			_ponta(h, Vector3(0, 0.0, 0.32 * t), Vector3(0, -0.35, 1), 0.55 * t, 0.16 * t, brilho, 6)  # bico
			for i in (5 if ss else 3):
				var a := (float(i) / maxf((5 if ss else 3) - 1, 1) - 0.5) * 1.2
				_ponta(h, Vector3(0, 0.3 * t, -0.05 * t), Vector3(sin(a), 1.0, -0.5), (0.75 if ss else 0.6) * t, 0.07 * t, brilho, 4)  # crista de chama
			for s in [-1.0, 1.0]:
				_p(h, _esfera(0.07 * t), olho, Vector3(0.22 * s * t, 0.12 * t, 0.28 * t))
		"grifo":
			_p(h, _esfera(0.42 * t), metal, Vector3.ZERO, Basis.IDENTITY, Vector3(0.95, 1.0, 1.15))
			_ponta(h, Vector3(0, 0.05 * t, 0.3 * t), Vector3(0, -0.15, 1), 0.45 * t, 0.17 * t, escuro, 6)
			_ponta(h, Vector3(0, -0.02 * t, 0.68 * t), Vector3(0, -1, 0.35), 0.2 * t, 0.06 * t, escuro, 5)  # gancho do bico
			for s in [-1.0, 1.0]:
				_p(h, _esfera(0.07 * t), olho, Vector3(0.22 * s * t, 0.15 * t, 0.25 * t))
				for i in (4 if ss else 3):
					_ponta(h, Vector3(0.18 * s * t, (0.25 - 0.1 * i) * t, -0.25 * t), Vector3(0.5 * s, 0.6 - 0.3 * i, -1), 0.55 * t, 0.07 * t, brilho, 4)  # penas da nuca
	return h


static var _ponto: Texture2D


# ponto redondo de borda macia para partículas (sem quadradinhos)
static func ponto_macio() -> Texture2D:
	if _ponto == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_ponto = t
	return _ponto


static func _esfera(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	return s


static func _emblema(pai: Node3D, tipo: String, pos: Vector3, base: Basis, lado: float) -> void:
	var tex := load("res://assets/emblemas/reliquia_%s.png" % tipo) as Texture2D
	if tex == null:
		return
	var q := QuadMesh.new()
	q.size = Vector2(lado, lado)
	var m := _mats.get("r_emb_" + tipo) as StandardMaterial3D
	if m == null:
		m = StandardMaterial3D.new()
		m.albedo_texture = tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = 0.6
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.4
		m.metallic = 0.3
		_mats["r_emb_" + tipo] = m
	_p(pai, q, m, pos, base)


static func _aura(pai: Node3D, elemento: String, cores: Array, pos: Vector3, caixa: Vector3, qtd: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = qtd
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = caixa
	p.local_coords = false
	p.position = pos
	p.visibility_range_end = 40.0
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if elemento == "sombra" else BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = ponto_macio()
	q.material = m
	p.mesh = q
	var grad := Gradient.new()
	match elemento:
		"fogo":  # brasas subindo
			q.size = Vector2(0.03, 0.03)
			p.lifetime = 0.9
			p.direction = Vector3.UP
			p.spread = 20.0
			p.gravity = Vector3(0, 0.9, 0)
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.35
			grad.colors = PackedColorArray([cores[0], cores[1], Color(cores[2], 0.0)])
		"sombra":  # fumaça escura que se arrasta
			q.size = Vector2(0.09, 0.09)
			p.lifetime = 1.3
			p.direction = Vector3.UP
			p.spread = 60.0
			p.gravity = Vector3(0, 0.12, 0)
			p.initial_velocity_min = 0.02
			p.initial_velocity_max = 0.08
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.4
			grad.colors = PackedColorArray([Color(cores[2], 0.0), Color(cores[2], 0.75), Color(cores[1], 0.35), Color(cores[2], 0.0)])
		"gelo":  # cristais caindo devagar
			q.size = Vector2(0.025, 0.025)
			p.lifetime = 1.4
			p.direction = Vector3.DOWN
			p.spread = 40.0
			p.gravity = Vector3(0, -0.25, 0)
			p.initial_velocity_min = 0.02
			p.initial_velocity_max = 0.1
			grad.colors = PackedColorArray([cores[0], cores[1], Color(cores[1], 0.0)])
		"luz":  # pontos dourados que sobem girando
			q.size = Vector2(0.03, 0.03)
			p.lifetime = 1.2
			p.direction = Vector3.UP
			p.spread = 45.0
			p.gravity = Vector3(0, 0.4, 0)
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.2
			p.tangential_accel_min = 0.6
			p.tangential_accel_max = 1.2
			grad.colors = PackedColorArray([cores[0], cores[1], Color(cores[1], 0.0)])
		"tempestade":  # faíscas rápidas para todo lado
			q.size = Vector2(0.018, 0.05)
			p.lifetime = 0.35
			p.direction = Vector3.UP
			p.spread = 180.0
			p.gravity = Vector3.ZERO
			p.initial_velocity_min = 0.4
			p.initial_velocity_max = 1.0
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			grad.colors = PackedColorArray([Color(1, 1, 1), cores[1], Color(cores[1], 0.0)])
		_:  # terra: lascas de pedra e poeira dourada
			q.size = Vector2(0.03, 0.03)
			p.lifetime = 1.0
			p.direction = Vector3.DOWN
			p.spread = 30.0
			p.gravity = Vector3(0, -1.5, 0)
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.15
			grad.colors = PackedColorArray([cores[0], cores[1], Color(cores[2], 0.0)])
	p.color_ramp = grad
	pai.add_child(p)
	return p


# monta a relíquia na arma já posicionada (eixo, ponta, cabo e faces medidos pelo mesmo método do Enfeites)
static func aplicar(w: Node3D, n: int, kind: String) -> bool:
	var tipo: String = CRIATURA.get(kind, "")
	if w == null or n < 5 or tipo == "":
		return false
	var ss := n >= 6
	var d: Dictionary = DADOS[tipo]
	var cores: Array = d.cores
	var el: String = d.elemento
	var bb := AABB()
	var primeiro := true
	for mm in w.find_children("*", "MeshInstance3D", true, false):
		var mi := mm as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = Enfeites._rel(w, mi) * mi.get_aabb()
		bb = b if primeiro else bb.merge(b)
		primeiro = false
	if primeiro:
		return false
	# o metal da arma escurece para a cor da criatura (as peças acesas se destacam)
	for mm in w.find_children("*", "MeshInstance3D", true, false):
		var mi := mm as MeshInstance3D
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var mt := mi.get_active_material(si) as BaseMaterial3D
			if mt == null:
				continue
			var nm := mt.duplicate() as BaseMaterial3D
			nm.albedo_color = nm.albedo_color.lerp(cores[3], 0.55)
			nm.metallic = maxf(nm.metallic, 0.7)
			nm.roughness = minf(nm.roughness, 0.35)
			mi.set_surface_override_material(si, nm)
	var tam := bb.size
	var ordem := [0, 1, 2]
	ordem.sort_custom(func(a, b): return tam[a] > tam[b])
	var lg: int = ordem[0]
	var md: int = ordem[1]
	var fn: int = ordem[2]
	var c := bb.get_center()
	var sinal := 1.0 if c[lg] >= 0.0 else -1.0
	var eixo := Vector3.ZERO
	eixo[lg] = sinal
	var face := Vector3.ZERO
	face[fn] = 1.0
	var lado := Vector3.ZERO
	lado[md] = 1.0
	var L := tam[lg]
	var larg := maxf(tam[md], 0.03)
	var esp := maxf(tam[fn], 0.01)
	var base_c := c
	base_c[lg] = 0.0
	var ponta := base_c + eixo * (absf(c[lg]) + L * 0.5)
	var cabo := base_c + eixo * (absf(c[lg]) - L * 0.5)
	var lamina := kind in ["espada", "espadao", "adaga", "punhal", "duplas"]
	var haste := kind in ["lanca", "cajado", "cetro"]
	# largura de verdade da lâmina (a caixa inclui a guarda): vértices entre 45% e 70% do comprimento
	var larg_lamina := larg * 0.3
	if lamina:
		var mx := 0.0
		for mm in w.find_children("*", "MeshInstance3D", true, false):
			var mi := mm as MeshInstance3D
			if mi.mesh == null or mi.mesh is PrimitiveMesh:
				continue
			var tr: Transform3D = Enfeites._rel(w, mi)
			for si in mi.mesh.get_surface_count():
				for v in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
					var pv: Vector3 = tr * v
					var u := (pv - cabo).dot(eixo) / L
					if u > 0.45 and u < 0.7:
						mx = maxf(mx, absf((pv - base_c).dot(lado)))
		if mx > 0.004:
			larg_lamina = mx * 2.0
	var giro := Basis.looking_at(eixo, face if absf(face.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT)
	# giro.z aponta para -eixo (looking_at); a cabeça usa +Z = para onde olha
	var olha_ponta := Basis(giro.x, giro.y, -giro.z)
	# tamanho da cabeça em fração do comprimento da arma (os modelos vêm em escalas locais diferentes)
	var fr: float = {"espada": 0.16, "espadao": 0.15, "adaga": 0.24, "punhal": 0.24, "duplas": 0.22, "lanca": 0.11,
		"cajado": 0.14, "cetro": 0.2, "martelo": 0.17, "machado": 0.17, "arco": 0.2}.get(kind, 0.0)
	var t := (L * fr if fr > 0.0 else larg * 0.45) * (1.15 if ss else 1.0)
	var foco: Vector3
	var b_cab: Basis = olha_ponta
	match kind:
		"espada", "espadao", "adaga", "punhal", "duplas":
			foco = base_c + eixo * (L * (0.2 if kind == "espadao" else 0.14))  # guarda: a lâmina sai da boca
		"lanca", "cajado", "cetro":
			foco = ponta - eixo * L * (0.16 if kind == "lanca" else 0.1)
		"martelo", "machado":
			# rosto da criatura cravado na face larga da cabeça da arma, olhando para fora
			foco = ponta - eixo * L * 0.12 + face * (esp * 0.5 + t * 0.15)
			b_cab = Basis.looking_at(face, eixo)
			b_cab = Basis(b_cab.x, b_cab.y, -b_cab.z)
		"arco":
			foco = base_c + face * esp * 0.4
			b_cab = Basis.looking_at(face, eixo)
			b_cab = Basis(b_cab.x, b_cab.y, -b_cab.z)
		_:  # escudo
			foco = base_c + face * esp * 0.6
			b_cab = Basis.looking_at(face, eixo)
			b_cab = Basis(b_cab.x, b_cab.y, -b_cab.z)
	if OS.has_environment("RELIQUIA_DEBUG"): print("RELIQ ", kind, " L=", L, " larg=", larg, " lam=", larg_lamina, " t=", t)
	var u := t / 0.2  # 1 "centímetro" na escala local da arma
	var cab := cabeca(tipo, t, cores, ss)
	cab.transform = Transform3D(b_cab, foco - (b_cab.z * t * 0.25 if lamina else Vector3.ZERO))
	cab.set_meta("reliquia_peca", true)
	w.add_child(cab)
	# emblema gravado dos dois lados (lâmina: logo acima da guarda; haste: abaixo da cabeça; escudo: no centro)
	var b_face := Basis.looking_at(face, eixo if absf(face.dot(eixo)) < 0.9 else Vector3.UP)
	var lado_emb := (minf(larg_lamina * 1.3, t * 0.7) if lamina else t * 0.7)
	var p_emb := foco + eixo * (t * 0.75 + lado_emb * 0.6) if lamina else (foco - eixo * L * 0.12 if haste else foco)
	if kind == "escudo":
		lado_emb = clampf(larg * 0.55, 0.15, 0.4)
		p_emb = foco + face * esp * 0.05
	if kind != "arco":
		for s in ([-1.0, 1.0] if kind != "escudo" else [1.0]):
			_emblema(w, tipo, p_emb + face * s * (esp * 0.5 + 0.004 * u), b_face if s > 0 else Basis(b_face.x * -1.0, b_face.y, b_face.z * -1.0), lado_emb)
	# fio aceso no elemento (lâminas: os dois gumes; hastes: espiral de luz até a ponta)
	var fio_mat := _m("r_fio_%s_%s" % [tipo, ss], cores[1], 0.0, 0.2, 3.2 if ss else 2.2)
	if lamina:
		var ini := (foco - cabo).dot(eixo) + t * 0.4
		var fim := L * 0.93
		var comp := fim - ini
		var fio := BoxMesh.new()
		fio.size = Vector3(0.006 * u, 0.006 * u, comp)
		for s in [-1.0, 1.0]:
			_p(w, fio, fio_mat, cabo + eixo * (ini + comp * 0.5) + lado * s * larg_lamina * 0.47, giro)
	elif haste:
		for i in 6:
			var z := L * (0.25 + 0.08 * i)
			var a := i * 1.1
			_p(w, _esfera(0.012 * u), fio_mat, cabo + eixo * z + (lado * cos(a) + face * sin(a)) * maxf(larg * 0.35, 0.025 * u))
	# SS: asas/espinhos na guarda e coroa de runas girando em volta da arma
	if ss:
		var asa_mat := _m("r_asa_%s" % tipo, (cores[3] as Color).darkened(0.2), 0.85, 0.3)
		if lamina:
			# asas de metal na guarda: três penas largas e chatas por lado, abertas como um leque
			for s in [-1.0, 1.0]:
				for i in 3:
					var ang := 0.35 - 0.42 * i
					var dirv: Vector3 = (lado * s * cos(ang) + eixo * sin(ang)).normalized()
					var comp_p := larg * (0.62 - 0.12 * i)
					var pena := BoxMesh.new()
					pena.size = Vector3(comp_p, t * (0.42 - 0.08 * i), 0.012 * u)
					var bx: Vector3 = dirv
					var bz: Vector3 = face
					var by: Vector3 = bz.cross(bx).normalized()
					_p(w, pena, asa_mat, foco + dirv * (t * 0.35 + comp_p * 0.5) - eixo * t * 0.1 * i, Basis(bx, by, bz))
					_p(w, BoxMesh.new(), fio_mat, foco + dirv * (t * 0.35 + comp_p * 0.5) + face * 0.008 * u, Basis(bx, by, bz), Vector3(comp_p * 0.9, 0.006 * u, 0.004 * u))
		var coroa := Node3D.new()
		coroa.position = (foco + ponta) * 0.5 if lamina else foco
		coroa.basis = giro
		w.add_child(coroa)
		var runa := _m("r_runa_%s" % tipo, cores[0], 0.0, 0.2, 4.0)
		for i in 8:
			var a := TAU * i / 8.0
			var r := maxf(larg, 0.06 * u) * 0.95
			_p(coroa, BoxMesh.new(), runa, Vector3(cos(a) * r, sin(a) * r, 0), Basis(Vector3.BACK, a), Vector3(0.012, 0.03, 0.004) * u)
		var gira := load("res://scripts/gira.gd").new() as Node
		gira.set("velocidade", 1.4)
		coroa.add_child(gira)
	# aura parada (o SS tem a aura do elemento e uma segunda, mais clara)
	var meio := (foco + ponta) * 0.5 if (lamina or haste) else foco
	var caixa := Vector3(larg * 0.4, larg * 0.4, L * 0.3) if (lamina or haste) else Vector3(t, t, t)
	caixa = giro * caixa
	caixa = Vector3(absf(caixa.x), absf(caixa.y), absf(caixa.z))
	_aura(w, el, cores, meio, caixa, 18 if not ss else 30)
	if ss:
		_aura(w, "luz" if el != "luz" else "fogo", [cores[0], cores[0], cores[1], cores[3]], foco, Vector3(t, t, t) * 0.8, 12)
	w.set_meta("reliquia", {"tipo": tipo, "elemento": el, "ss": ss, "cor": cores[1], "brilho": cores[0], "sombra": cores[2],
		"ponta": ponta, "base": foco if lamina else (cabo + eixo * L * 0.5)})
	return true


# ---------- efeitos em jogo (rastro, impacto com clarão, espírito da criatura no SS) ----------
const FX = preload("res://scripts/fx.gd")
const RASTRO = preload("res://scripts/rastro_reliquia.gd")
const GOLPES := ["Attack", "Sword", "Chop", "Slash", "Stab", "Heavy", "Combo", "Dash", "Spin", "Punch", "Kick", "Staff"]


static func e_golpe(anim: String) -> bool:
	for g in GOLPES:
		if anim.contains(g):
			return true
	return false


# rastro de luz do elemento durante o golpe
static func rastro(w: Node3D, dur: float) -> void:
	if w == null or not w.has_meta("reliquia") or not w.is_inside_tree():
		return
	var r: Dictionary = w.get_meta("reliquia")
	var tr := RASTRO.new()
	tr.arma = w
	tr.base_l = r.base
	tr.ponta_l = r.ponta
	tr.cor = r.cor
	tr.brilho = (r.brilho as Color).lerp(r.cor, 0.45)
	tr.dura = clampf(dur, 0.2, 1.2)
	var cena := w.get_tree().current_scene
	(cena if cena != null else w.get_tree().root).add_child(tr)


# no acerto: clarão do elemento e anel de choque; no SS o espírito da criatura avança no golpe forte
static func impacto(pai: Node, w: Node3D, ponto: Vector3, de: Vector3, forte: bool) -> void:
	if w == null or not w.has_meta("reliquia"):
		return
	var r: Dictionary = w.get_meta("reliquia")
	var ss: bool = r.ss
	FX.flare(pai, ponto, r.cor, (1.0 if not forte else 1.6) * (1.25 if ss else 1.0), 0.22, 1.6)
	FX.burst(pai, ponto, _elem_fx(r.elemento), 0.7 if not forte else 1.1)
	_anel(pai, ponto, r.brilho, 0.9 if not forte else 1.5)
	if ss and forte:
		espirito(pai, String(r.tipo), de, ponto, r.cor)


static func _elem_fx(el: String) -> String:
	return {"fogo": "fire", "sombra": "dark", "terra": "earth", "gelo": "ice", "luz": "holy", "tempestade": "raio"}.get(el, el)


# anel de luz que abre no ponto do golpe (QuadMesh deitado de frente para a câmera)
static func _anel(pai: Node, pos: Vector3, cor: Color, tam: float) -> void:
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _textura_anel()
	m.albedo_color = cor
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(q)
	q.global_position = pos
	q.scale = Vector3.ONE * 0.2
	var tw := q.create_tween().set_parallel()
	tw.tween_property(q, "scale", Vector3.ONE * tam, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(q.queue_free)


static var _anel_tex: Texture2D


static func _textura_anel() -> Texture2D:
	if _anel_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.62, 0.8, 0.9, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_anel_tex = t
	return _anel_tex


# espírito da criatura: a silhueta luminosa surge atrás de quem golpeia e avança até o alvo, crescendo e sumindo
static func espirito(pai: Node, tipo: String, de: Vector3, ate: Vector3, cor: Color) -> void:
	var arq := "res://assets/emblemas/espirito_%s.png" % tipo
	if not ResourceLoader.exists(arq):
		return
	var s := Sprite3D.new()
	s.texture = load(arq)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.transparent = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.modulate = Color(cor.r, cor.g, cor.b, 0.0).lerp(Color(1, 1, 1, 0), 0.3)
	s.pixel_size = 2.4 / float(maxi(s.texture.get_width(), 1))
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.render_priority = 2
	pai.add_child(s)
	var ini := de + Vector3(0, 1.3, 0) + (de - ate).normalized() * 0.4
	s.global_position = ini
	s.scale = Vector3.ONE * 0.6
	var tw := s.create_tween()
	tw.set_parallel()
	tw.tween_property(s, "modulate:a", 0.75, 0.12)
	tw.tween_property(s, "global_position", ate + Vector3(0, 0.3, 0), 0.42).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(s, "scale", Vector3.ONE * 1.35, 0.42)
	tw.chain().tween_property(s, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(s.queue_free)
