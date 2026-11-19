extends RefCounted
# Rosto próprio de cada raça (lapidação 18/11, pedido de Robson: "formato do corpo e rosto com
# características da raça, que não pareça humano"). O rosto do corpo V3 é deformado vértice a vértice
# por um campo de deslocamento medido a partir dos olhos: mandíbula, queixo, maçãs, sobrancelha,
# nariz, boca, canto dos olhos e pálpebra. Esqueleto, ossos e animações oficiais não mudam:
# só a forma da malha em repouso. Cada raça e sexo é montado uma vez e reaproveitado.

const PERFIS := {
	# mand = largura da mandíbula (+ larga / - fina); queixo = [frente, baixo]; maca = maçã do rosto;
	# testa = arcada da sobrancelha; nariz = [largura, comprimento]; boca = largura; canto = canto do olho sobe;
	# palpebra = abre o olho (sobe a pálpebra de cima); fronte = testa inclina para trás
	"elfo": {"mand": -0.17, "queixo": [0.005, 0.008], "maca": 0.006, "testa": 0.0, "nariz": [-0.2, 0.003], "boca": -0.08, "canto": 0.004, "palpebra": 0.0012, "fronte": 0.0},
	"sombrio": {"mand": -0.2, "queixo": [0.006, 0.009], "maca": 0.008, "testa": 0.004, "nariz": [-0.18, 0.004], "boca": -0.06, "canto": 0.005, "palpebra": 0.001, "fronte": 0.0},
	"orc": {"mand": 0.34, "queixo": [0.016, 0.004], "maca": 0.004, "testa": 0.014, "nariz": [0.6, -0.004], "boca": 0.2, "canto": -0.0015, "palpebra": 0.0, "fronte": 0.012},
	"goblin": {"mand": -0.06, "queixo": [-0.008, 0.0], "maca": 0.005, "testa": 0.008, "nariz": [0.25, 0.026], "boca": 0.32, "canto": 0.004, "palpebra": 0.0015, "fronte": 0.006},
	"gigante": {"mand": 0.24, "queixo": [0.012, 0.006], "maca": 0.006, "testa": 0.015, "nariz": [0.35, 0.004], "boca": 0.08, "canto": -0.001, "palpebra": 0.0, "fronte": 0.006},
	"anao": {"mand": 0.14, "queixo": [0.004, 0.0], "maca": 0.006, "testa": 0.009, "nariz": [0.38, 0.008], "boca": 0.05, "canto": 0.0, "palpebra": 0.0, "fronte": 0.0},
	"beastman": {"mand": 0.0, "queixo": [0.0, 0.0], "maca": 0.0, "testa": 0.0, "nariz": [0.0, 0.0], "boca": 0.0, "canto": 0.0, "palpebra": 0.0032, "fronte": 0.0},
}

static var _cache := {}


static func aplicar(skel: Skeleton3D, chave: String, male: bool) -> void:
	if not PERFIS.has(chave):
		return
	var p: Dictionary = PERFIS[chave]
	var esc := 1.0 if male else 0.72  # traços pesados mais suaves no rosto feminino
	var hb := skel.find_bone("Head")
	if hb < 0:
		return
	var malhas := {}
	for m in skel.find_children("*", "MeshInstance3D", true, false):
		if String(m.name) in ["corpo", "olhos", "sobrancelha", "cilios"]:
			malhas[String(m.name)] = m
	if not malhas.has("corpo") or not malhas.has("olhos"):
		return
	# centro dos olhos (malha "olhos" em repouso)
	var oe := Vector3.ZERO
	var od := Vector3.ZERO
	var ne := 0
	var nd := 0
	for v in ((malhas.olhos as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		if v.x < 0:
			oe += v
			ne += 1
		else:
			od += v
			nd += 1
	if ne == 0 or nd == 0:
		return
	oe /= ne
	od /= nd
	var c := (oe + od) * 0.5
	for nome in ["corpo", "sobrancelha", "cilios"]:
		if not malhas.has(nome):
			continue
		var mi: MeshInstance3D = malhas[nome]
		var k: String = chave + ("m" if male else "f") + str(nome) + str(mi.mesh.get_rid().get_id())
		if not _cache.has(k):
			_cache[k] = _deformar(mi.mesh, hb, c, oe, od, p, esc)
		var mat := mi.get_surface_override_material(0)
		mi.mesh = _cache[k]
		if mat:
			mi.set_surface_override_material(0, mat)


static func _g(x: float, s: float) -> float:
	return exp(-(x * x) / (s * s))


static func _deformar(mesh: Mesh, hb: int, c: Vector3, oe: Vector3, od: Vector3, p: Dictionary, esc: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bo = a[Mesh.ARRAY_BONES]
		var w = a[Mesh.ARRAY_WEIGHTS]
		var nb: int = bo.size() / maxi(v.size(), 1) if bo != null else 0
		var olho_r := absf(od.x - c.x)
		for i in v.size():
			var hw := 0.0
			for j in nb:
				if int(bo[i * nb + j]) == hb:
					hw += float(w[i * nb + j])
			if hw < 0.05:
				continue
			var q := v[i] - c
			if q.z < -0.02:  # nuca e parte de trás da cabeça não mudam
				hw *= clampf(1.0 + (q.z + 0.02) / 0.03, 0.0, 1.0)
				if hw <= 0.0:
					continue
			var d := Vector3.ZERO
			var frente := smoothstep(-0.03, 0.03, q.z)
			# mandíbula: alarga ou afina tudo abaixo da boca
			var baixo := smoothstep(-0.035, -0.085, q.y)
			d.x += q.x * float(p.mand) * esc * baixo
			# queixo: avança e desce no centro
			var qx := _g(q.x, 0.025) * smoothstep(-0.07, -0.1, q.y) * frente
			var qz: Array = p.queixo
			d.z += float(qz[0]) * esc * qx
			d.y -= float(qz[1]) * esc * qx
			# maçãs do rosto (abaixo e por fora dos olhos)
			for lado in [-1.0, 1.0]:
				var m := _g(q.x - lado * olho_r * 1.25, 0.018) * _g(q.y + 0.022, 0.014) * frente
				d.x += lado * float(p.maca) * 0.6 * m
				d.z += float(p.maca) * m
			# arcada da sobrancelha
			var arc := _g(absf(q.x) - olho_r, 0.03) * _g(q.y - 0.018, 0.009) * frente
			d.z += float(p.testa) * esc * arc
			d.y += float(p.testa) * esc * 0.25 * arc
			# testa inclinada para trás (orcs, gigantes)
			d.z -= float(p.fronte) * esc * smoothstep(0.035, 0.08, q.y) * frente
			# nariz: largura e comprimento (ponta para frente e para baixo)
			var nz: Array = p.nariz
			var nar := _g(q.x, 0.016) * _g(q.y + 0.03, 0.017) * smoothstep(0.05, 0.08, q.z)
			d.x += q.x * float(nz[0]) * esc * nar
			d.z += float(nz[1]) * nar
			d.y -= float(nz[1]) * 0.35 * nar
			# boca: largura
			var boc := _g(q.x, 0.03) * _g(q.y + 0.058, 0.01) * frente
			d.x += q.x * float(p.boca) * boc
			# olhos: canto de fora sobe (traço élfico) e pálpebra de cima abre
			for oc in [oe, od]:
				var r := v[i] - (oc as Vector3)
				var fora := signf((oc as Vector3).x) * r.x
				var canto := _g(fora - 0.013, 0.008) * _g(r.y, 0.009) * smoothstep(-0.005, 0.01, r.z)
				d.y += float(p.canto) * canto
				var pal := _g(r.x, 0.012) * smoothstep(-0.001, 0.004, r.y) * _g(r.y - 0.006, 0.007) * smoothstep(-0.004, 0.006, r.z)
				d.y += float(p.palpebra) * pal
			v[i] += d * hw
		a[Mesh.ARRAY_VERTEX] = v
		# normais recalculadas só onde a forma mudou muito não compensa: as mudanças são de milímetros
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, mesh.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(s, mesh.surface_get_material(s))
	return out
