extends RefCounted
# Casas montadas com o kit modular CC0 "Medieval Village MegaKit" (Quaternius), em assets/modelos/vila_kit.
# Módulo de parede: 2 m de largura x 3,12 m de altura. Frente da casa = +Z, base em y = 0, centro em (0, 0).
# Cada peça é desenhada uma vez por tipo (MultiMesh) para todas as casas do mesmo modelo.
# tingir: cores da raça aplicadas por cima das texturas (StandardMaterial com albedo_color).

const KIT := "res://assets/modelos/vila_kit/%s.gltf"
const MOD := 2.0
const ALT := 3.12

static var _malhas := {}  # nome -> [[Mesh, Transform3D local], ...]
static var _mats := {}
# tom das texturas do kit puxado para a paleta realista do jogo (madeira menos laranja, telha menos saturada)
const TOM := {"WoodTrim": Color(0.6, 0.5, 0.44), "RoundTiles": Color(0.72, 0.6, 0.57), "Plaster": Color(0.92, 0.9, 0.86),
	"UnevenBrick": Color(0.85, 0.84, 0.82), "RockTrim": Color(0.8, 0.8, 0.8)}


# malhas de uma peça do kit (com a transformação interna de cada nó)
static func malhas(nome: String) -> Array:
	if _malhas.has(nome):
		return _malhas[nome]
	var out: Array = []
	var ps = load(KIT % nome)
	if ps == null:
		push_warning("casa_kit: peça não encontrada " + nome)
		_malhas[nome] = out
		return out
	var cena: Node = ps.instantiate()
	_coleta(cena, Transform3D.IDENTITY, out)
	cena.free()
	_malhas[nome] = out
	return out


static func _coleta(n: Node, xf: Transform3D, out: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append([_ajusta((n as MeshInstance3D).mesh), t])
	for c in n.get_children():
		_coleta(c, t, out)


static func _ajusta(m: Mesh) -> Mesh:
	for i in m.get_surface_count():
		var mat := m.surface_get_material(i)
		if not (mat is StandardMaterial3D):
			continue
		if not _mats.has(mat):
			var novo := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			for k in TOM:
				if String(mat.resource_name).contains(k):
					novo.albedo_color = TOM[k]
			_mats[mat] = novo
		m.surface_set_material(i, _mats[mat])
	return m


# planta de uma casa: lista de [peça, Transform3D]. larg e fundo em módulos de 2 m; andares 1 ou 2
static func planta(larg := 3, fundo := 4, andares := 2, estilo := "enxaimel") -> Array:
	var p: Array = []
	var hx := larg * MOD * 0.5
	var hz := fundo * MOD * 0.5
	for andar in andares:
		var y := andar * ALT
		var terreo := andar == 0
		var parede := "Wall_UnevenBrick_Straight" if terreo else ("Wall_Plaster_WoodGrid" if estilo == "enxaimel" else "Wall_Plaster_Straight")
		var janela := "Wall_UnevenBrick_Window_Wide_Round" if terreo else "Wall_Plaster_Window_Wide_Round"
		var janela_fina := "Wall_UnevenBrick_Window_Thin_Round" if terreo else "Wall_Plaster_Window_Thin_Round"
		# frente (+Z) e fundo (-Z)
		for i in larg:
			var x := -hx + MOD * (i + 0.5)
			var meio := i == larg / 2
			var frente := "Wall_UnevenBrick_Door_Round" if (terreo and meio) else janela
			p.append([frente, Transform3D(Basis.IDENTITY, Vector3(x, y, hz))])
			if frente == janela:
				_janela(p, "Wide", Transform3D(Basis.IDENTITY, Vector3(x, y, hz)))
			if terreo and meio:
				p.append(["Door_1_Round", Transform3D(Basis.IDENTITY, Vector3(x, y, hz))])
			var tf := Transform3D(Basis(Vector3.UP, PI), Vector3(x, y, -hz))
			p.append([janela_fina if i % 2 == 0 else parede, tf])
			if i % 2 == 0:
				_janela(p, "Thin", tf)
		# laterais
		for j in fundo:
			var z := -hz + MOD * (j + 0.5)
			var nome := janela if j % 2 == 1 else parede
			for lado in [1.0, -1.0]:
				var t := Transform3D(Basis(Vector3.UP, PI * 0.5 * lado), Vector3(hx * lado, y, z))
				p.append([nome, t])
				if nome == janela:
					_janela(p, "Wide", t)
		# quinas
		var quina := "Corner_Exterior_Brick" if terreo else "Corner_Exterior_Wood"
		for s in [[1, 1, 0.0], [-1, 1, -PI * 0.5], [-1, -1, PI], [1, -1, PI * 0.5]]:
			p.append([quina, Transform3D(Basis(Vector3.UP, s[2]), Vector3(hx * s[0], y, hz * s[1]))])
		if andar > 0:
			p.append(["Floor_WoodDark", Transform3D(Basis.from_scale(Vector3(larg, 1, fundo)), Vector3(0, y, 0))])
	var topo := andares * ALT
	var telhado := "Roof_RoundTiles_%dx%d" % [larg * 2, fundo * 2]
	p.append([telhado, Transform3D(Basis.IDENTITY, Vector3(0, topo, 0))])
	var oitao := "Roof_Front_Brick%d" % (larg * 2)
	p.append([oitao, Transform3D(Basis.IDENTITY, Vector3(0, topo, hz))])
	p.append([oitao, Transform3D(Basis(Vector3.UP, PI), Vector3(0, topo, -hz))])
	p.append(["Prop_Chimney", Transform3D(Basis.IDENTITY, Vector3(hx - 1.0, topo, -hz + 1.6))])
	return p


# vidro com caixilho e venezianas abertas no vão da parede
static func _janela(p: Array, tipo: String, t: Transform3D) -> void:
	p.append(["Window_%s_Round1" % tipo, t])
	p.append(["WindowShutters_%s_Round_Open" % tipo, t])


# desenha casas iguais em lote. xfs: Transform3D de cada casa no espaço de root
static func construir(root: Node3D, xfs: Array, larg := 3, fundo := 4, andares := 2, vis_end := 260.0, estilo := "enxaimel") -> void:
	if xfs.is_empty():
		return
	# agrupa por peça: uma MultiMesh por malha, com todas as ocorrências em todas as casas
	var grupos := {}
	for peca in planta(larg, fundo, andares, estilo):
		if not grupos.has(peca[0]):
			grupos[peca[0]] = []
		for x in xfs:
			grupos[peca[0]].append((x as Transform3D) * (peca[1] as Transform3D))
	for nome in grupos:
		var lista: Array = grupos[nome]
		for ms in malhas(str(nome)):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = ms[0]
			mm.instance_count = lista.size()
			for i in lista.size():
				mm.set_instance_transform(i, (lista[i] as Transform3D) * (ms[1] as Transform3D))
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.visibility_range_end = vis_end
			root.add_child(mi)
