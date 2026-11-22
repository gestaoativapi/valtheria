class_name FormaRaca
extends RefCounted
# Forma do corpo de cada raça nas roupas e armaduras (Fase 2, escolha de Robson 22/11).
# O corpo atual do jogo é só rosto e mãos; o resto é a própria roupa. Aqui cada vértice da roupa é empurrado
# pelo deslocamento do corpo anatômico da raça (MakeHuman/MPFB2, CC0) em relação ao humano: o orc fica mais
# largo de ombros e peito, o anão atarracado, o elfo esguio. Esqueleto, animações, rosto e mãos não mudam.
# Malhas novas ficam em cache por (malha, raça, gênero): NPCs iguais não recalculam.

const FORCA := {"anao": 1.0, "orc": 1.0, "gigante": 1.0, "beastman": 1.0, "draconato": 1.0, "elfo": 1.0, "sombrio": 1.0}
const LIMITE := 0.07       # nenhum vértice anda mais que 7 cm
const CEL := 0.05          # grade de busca (5 cm)
const PULA := ["corpo", "olhos", "sobrancelha", "cilios", "cabelo", "barba"]

static var _base := {}     # gênero -> PackedVector3Array
static var _grade := {}    # gênero -> Dictionary(Vector3i -> PackedInt32Array)
static var _desl := {}     # "raca_g" -> PackedVector3Array
static var _cache := {}    # chave -> ArrayMesh


static func _ler(caminho: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return out
	var b := f.get_buffer(f.get_length())
	var fl := b.to_float32_array()
	out.resize(fl.size() / 3)
	for i in out.size():
		out[i] = Vector3(fl[i * 3], fl[i * 3 + 1], fl[i * 3 + 2])
	return out


static func _prepara(g: String) -> bool:
	if _base.has(g):
		return not (_base[g] as PackedVector3Array).is_empty()
	var b := _ler("res://data/corpos/forma_base_%s.bin" % g)
	_base[g] = b
	var gr := {}
	for i in b.size():
		var c := Vector3i((b[i] / CEL).floor())
		if not gr.has(c):
			gr[c] = PackedInt32Array()
		(gr[c] as PackedInt32Array).append(i)
	_grade[g] = gr
	return not b.is_empty()


static func _deslocamentos(raca: String, g: String) -> PackedVector3Array:
	var k := raca + "_" + g
	if not _desl.has(k):
		_desl[k] = _ler("res://data/corpos/forma_%s.bin" % k)
	return _desl[k]


# quanto o ponto p (espaço de repouso do esqueleto) anda para a raça: média dos 4 vértices mais próximos do corpo
static func _no_ponto(p: Vector3, g: String, d: PackedVector3Array) -> Vector3:
	var b: PackedVector3Array = _base[g]
	var gr: Dictionary = _grade[g]
	var c := Vector3i((p / CEL).floor())
	var melhores := []   # [dist2, idx]
	for raio in [1, 2]:
		for x in range(-raio, raio + 1):
			for y in range(-raio, raio + 1):
				for z in range(-raio, raio + 1):
					if raio == 2 and absi(x) < 2 and absi(y) < 2 and absi(z) < 2:
						continue
					var cel = gr.get(c + Vector3i(x, y, z))
					if cel == null:
						continue
					for i in cel:
						var d2 := p.distance_squared_to(b[i])
						if melhores.size() < 4:
							melhores.append([d2, i])
							melhores.sort_custom(func(u, v): return u[0] < v[0])
						elif d2 < melhores[3][0]:
							melhores[3] = [d2, i]
							melhores.sort_custom(func(u, v): return u[0] < v[0])
		if melhores.size() >= 4:
			break
	if melhores.is_empty():
		return Vector3.ZERO
	var acc := Vector3.ZERO
	var tot := 0.0
	for m in melhores:
		var w := 1.0 / (sqrt(m[0]) + 0.005)
		acc += d[m[1]] * w
		tot += w
	# longe do corpo (capa, saia larga, ombreira) o efeito diminui
	var perto := clampf(1.0 - (sqrt(melhores[0][0]) - 0.04) / 0.12, 0.25, 1.0)
	return acc / tot * perto


static var _pendente := {}  # chave -> Array de MeshInstance3D esperando a malha
static var _trava := Mutex.new()


static func aplicar(skel: Skeleton3D, raca: String, male: bool) -> void:
	if skel == null or not FORCA.has(raca):
		return
	var g := "m" if male else "f"
	if not _prepara(g):
		return
	var d := _deslocamentos(raca, g)
	if d.size() != (_base[g] as PackedVector3Array).size():
		return
	var forca: float = FORCA[raca]
	for ch in skel.get_children():
		if not (ch is MeshInstance3D):
			continue
		var mi := ch as MeshInstance3D
		var nome := String(mi.name).to_lower()
		if mi.mesh == null or nome in PULA or nome.begins_with("ca_") or nome.contains("hair") or nome.contains("eye"):
			continue
		var chave := "%d|%s|%s" % [mi.mesh.get_instance_id(), raca, g]
		if _cache.has(chave):
			_trocar(mi, _cache[chave])
		elif _pendente.has(chave):
			(_pendente[chave] as Array).append(mi)
		else:
			_pendente[chave] = [mi]
			# o cálculo pesado roda numa thread: o personagem aparece na hora com a roupa padrão e ganha a forma
			# da raça um instante depois, sem travar o jogo (o resultado fica guardado para os próximos)
			var mats := _matrizes(mi.skin, skel)
			var orig := mi.mesh as ArrayMesh
			WorkerThreadPool.add_task(func():
				var m := _deformar(orig, g, d, forca, mats)
				_pronto.call_deferred(chave, m))


static func _pronto(chave: String, m: ArrayMesh) -> void:
	_cache[chave] = m
	for mi in _pendente.get(chave, []):
		if is_instance_valid(mi):
			_trocar(mi, m)
	_pendente.erase(chave)


static func _trocar(mi: MeshInstance3D, m: ArrayMesh) -> void:
	if m == null or mi.mesh == m:
		return
	var mats := []
	for si in mi.mesh.get_surface_count():
		mats.append(mi.get_surface_override_material(si))
	mi.mesh = m
	for si in mini(mats.size(), m.get_surface_count()):
		if mats[si] != null:
			mi.set_surface_override_material(si, mats[si])


# vértices de malha com pele ficam no espaço de "bind" de cada roupa (as do pacote antigo vêm normalizadas entre
# -1 e 1): a matriz de cada vértice (osso em repouso x bind, ponderada pelos pesos) leva o vértice para o espaço
# de repouso do esqueleto, onde o deslocamento da raça é medido, e o deslocamento volta pela inversa
static func _matrizes(skin: Skin, skel: Skeleton3D) -> Array:
	var out := []
	if skin == null:
		return out
	for b in skin.get_bind_count():
		var bi := skin.get_bind_bone(b)
		if bi < 0:
			bi = skel.find_bone(skin.get_bind_name(b))
		var rest := skel.get_bone_global_rest(bi) if bi >= 0 else Transform3D.IDENTITY
		out.append(rest * skin.get_bind_pose(b))
	return out


static func _deformar(orig: ArrayMesh, g: String, d: PackedVector3Array, forca: float, mats: Array) -> ArrayMesh:
	if orig == null:
		return null
	var novo := ArrayMesh.new()
	novo.blend_shape_mode = orig.blend_shape_mode
	for bi in orig.get_blend_shape_count():
		novo.add_blend_shape(orig.get_blend_shape_name(bi))
	for si in orig.get_surface_count():
		var arr := orig.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ossos = arr[Mesh.ARRAY_BONES]
		var pesos = arr[Mesh.ARRAY_WEIGHTS]
		var por := 8 if (orig.surface_get_format(si) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0 else 4
		var memo := {}
		for i in vs.size():
			var p := vs[i]
			var M := Transform3D.IDENTITY
			if not mats.is_empty() and ossos != null and pesos != null and (ossos as PackedInt32Array).size() >= (i + 1) * por:
				var bs := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
				var o := Vector3.ZERO
				var tw := 0.0
				for k in por:
					var w: float = pesos[i * por + k]
					if w <= 0.0:
						continue
					var bi: int = ossos[i * por + k]
					if bi >= mats.size():
						continue
					var t: Transform3D = mats[bi]
					bs = Basis(bs.x + t.basis.x * w, bs.y + t.basis.y * w, bs.z + t.basis.z * w)
					o += t.origin * w
					tw += w
				if tw > 0.0:
					M = Transform3D(Basis(bs.x / tw, bs.y / tw, bs.z / tw), o / tw)
			var pr := M * p
			var chave := Vector3i((pr * 200.0).round())   # vértices repetidos (costuras de UV) andam juntos
			var m = memo.get(chave)
			if m == null:
				m = _no_ponto(pr, g, d) * forca
				if m.length() > LIMITE:
					m = m.normalized() * LIMITE
				memo[chave] = m
			vs[i] = p + M.basis.inverse() * m
		arr[Mesh.ARRAY_VERTEX] = vs
		var fmt := orig.surface_get_format(si)
		novo.add_surface_from_arrays(orig.surface_get_primitive_type(si), arr, orig.surface_get_blend_shape_arrays(si), {}, fmt & (Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS))
		novo.surface_set_material(si, orig.surface_get_material(si))
		novo.surface_set_name(si, orig.surface_get_name(si))
	return novo
