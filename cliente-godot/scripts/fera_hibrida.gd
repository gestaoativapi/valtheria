extends RefCounted
# Homens-fera, rosto híbrido (pedido de Robson, 18/11): rosto humano + fera, olhos humanos firmes,
# focinho curto e definido como extensão do rosto, silhueta arredondada, juba de fios definidos.
#
# Como é feito: uma máscara lisa (uma malha só) é gerada em volta da cabeça humana do corpo V3,
# medida vértice a vértice. A máscara fica poucos milímetros fora da pele, ganha focinho, almofadas
# de bigode, sobrancelha firme e maçãs largas, e afunda na região dos olhos para que os olhos humanos
# apareçam. Cor por vértice (focinho claro, contorno escuro dos olhos, listras ou rosetas) e duas
# cascas de pelo curto dão o acabamento. Orelhas, nariz, juba e bigodes são peças à parte.

const ESPECIES := {
	# focinho: [comprimento m, largura (rad), altura acima, altura abaixo]
	"leao": {"claro": "#efd7a6", "escuro": "#6b3e1e", "nariz": "#5a3a32", "olho_contorno": "#3a2416",
		"focinho": [0.047, 0.45, 0.38, 0.30], "almofada": 0.013, "bochecha": 0.016, "testa": 0.008,
		"orelha": ["redonda", 0.058, 0.034], "orelha_dir": [0.95, 0.72], "pelo_juba": ["#4a2a16", "#6e4222", "#94612f", "#2e1a0e"]},
	"lobo": {"claro": "#e3e1dc", "escuro": "#3f4650", "nariz": "#1c1a1a", "olho_contorno": "#1d2026",
		"focinho": [0.066, 0.36, 0.55, 0.28], "almofada": 0.005, "bochecha": 0.010, "testa": 0.007,
		"orelha": ["pontuda", 0.10, 0.036], "orelha_dir": [0.62, 0.95], "pelo_juba": ["#c9ccce", "#9aa0a6", "#e8e8e4", "#6e747c"]},
	"tigre": {"claro": "#f6efe2", "escuro": "#241a14", "nariz": "#c27c6c", "olho_contorno": "#2a1c14",
		"focinho": [0.036, 0.42, 0.34, 0.30], "almofada": 0.012, "bochecha": 0.017, "testa": 0.006,
		"orelha": ["redonda", 0.056, 0.032], "orelha_dir": [0.98, 0.72], "listras": true, "pelo_juba": ["#f2ece0", "#e09a4c", "#f6f2ea", "#d28b42"]},
	"onca": {"claro": "#f3e6c8", "escuro": "#2a1e16", "nariz": "#a8665a", "olho_contorno": "#2a1c14",
		"focinho": [0.034, 0.42, 0.34, 0.30], "almofada": 0.011, "bochecha": 0.015, "testa": 0.006,
		"orelha": ["redonda", 0.050, 0.030], "orelha_dir": [1.0, 0.70], "rosetas": true, "pelo_juba": ["#f3e6c8", "#d9a24e", "#f6efe0", "#c48a3c"]},
	"ursa": {"claro": "#b88a5e", "escuro": "#3a281c", "nariz": "#1a1412", "olho_contorno": "#2a1c14",
		"focinho": [0.050, 0.40, 0.42, 0.30], "almofada": 0.004, "bochecha": 0.020, "testa": 0.010,
		"orelha": ["urso", 0.044, 0.032], "orelha_dir": [0.92, 0.82], "pelo_juba": ["#6e4a30", "#5a3c26", "#7e5638", "#4a3020"]},
}

static var _tabelas := {}     # medida da cabeça humana por sexo
static var _mascaras := {}    # malhas prontas por sexo + espécie
static var _fios := {}        # malha de um fio de juba
static var _shader: Shader

const NLA := 60
const NLO := 96


static func montar(skel: Skeleton3D, att: Node3D, rest: Transform3D, male: bool, sub: String, pelo: Color) -> void:
	var f: Dictionary = ESPECIES.get(sub, ESPECIES.leao)
	var tab := _tabela(skel, male)
	if tab.is_empty():
		return
	var chave := ("m" if male else "f") + sub + pelo.to_html()
	if not _mascaras.has(chave):
		_mascaras[chave] = _mascara(tab, f, sub, male, pelo)
	var inv := rest.affine_inverse()
	var mi := MeshInstance3D.new()
	mi.name = "RostoFera"
	mi.mesh = _mascaras[chave]
	mi.transform = inv
	mi.material_override = _mat_pelo(0.0, 0.0)
	att.add_child(mi)
	# duas cascas de pelo curto por cima: dão a borda macia de pelagem em vez de plástico.
	# Só perto da câmera (até 14 m): de longe a diferença não aparece e o custo some.
	var casca := MeshInstance3D.new()
	casca.name = "PeloCurto"
	casca.mesh = mi.mesh
	casca.transform = inv
	var m1 := _mat_pelo(0.0022, 0.45)
	m1.next_pass = _mat_pelo(0.0042, 0.7)
	casca.material_override = m1
	casca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	casca.visibility_range_end = 14.0
	casca.visibility_range_end_margin = 2.0
	casca.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	att.add_child(casca)
	_nariz(att, inv, tab, f, sub, male)
	_orelhas(att, inv, tab, f, sub, male, pelo)
	_juba(att, inv, tab, f, sub, male, pelo)
	if sub in ["leao", "tigre", "onca"]:
		_bigodes(att, inv, tab, f, male)
	_olhos_ambar(skel, sub)


# olhos humanos com íris âmbar (decisão D4 de Robson, 18/11): mesma textura do olho humano,
# só a íris muda de cor; o branco fica um pouco mais limpo para o olhar ficar firme
const OLHO_SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 iris : source_color = vec3(0.86, 0.56, 0.14);
uniform vec3 borda : source_color = vec3(0.32, 0.17, 0.04);
void fragment() {
	vec4 t = texture(tex, UV);
	vec3 c = t.rgb;
	float d = min(distance(UV, vec2(0.705, 0.29)), distance(UV, vec2(0.29, 0.71)));
	float l = dot(t.rgb, vec3(0.3, 0.59, 0.11));
	float m_iris = 1.0 - smoothstep(0.105, 0.118, d);
	float m_pupila = 1.0 - smoothstep(0.03, 0.04, d);
	vec3 ambar = mix(borda, iris, smoothstep(0.05, 0.1, d) * 0.0 + smoothstep(0.118, 0.06, d)) * (0.55 + l * 1.6);
	c = mix(c, ambar, m_iris * (1.0 - m_pupila));
	c = mix(c, vec3(0.02), m_pupila);
	c = mix(c, vec3(0.93, 0.91, 0.88), (1.0 - m_iris) * 0.35);
	ALBEDO = c;
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
}
"""
static var _olho_mat: ShaderMaterial


static func _olhos_ambar(skel: Skeleton3D, sub: String) -> void:
	for m in skel.find_children("olhos", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var base := mi.mesh.surface_get_material(0)
		if not (base is StandardMaterial3D):
			continue
		if _olho_mat == null:
			var sh := Shader.new()
			sh.code = OLHO_SHADER
			_olho_mat = ShaderMaterial.new()
			_olho_mat.shader = sh
			_olho_mat.set_shader_parameter("tex", (base as StandardMaterial3D).albedo_texture)
		var mat: ShaderMaterial = _olho_mat
		if sub == "lobo":
			mat = _olho_mat.duplicate()
			mat.set_shader_parameter("iris", Color(0.92, 0.72, 0.24))
		mi.material_override = mat


# ---------------------------------------------------------------- medida da cabeça humana
static func _tabela(skel: Skeleton3D, male: bool) -> Dictionary:
	var k := "m" if male else "f"
	if _tabelas.has(k):
		return _tabelas[k]
	var hb := skel.find_bone("Head")
	var corpo: MeshInstance3D = null
	var olhos: MeshInstance3D = null
	for m in skel.find_children("*", "MeshInstance3D", true, false):
		if String(m.name) == "corpo":
			corpo = m
		elif String(m.name) == "olhos":
			olhos = m
	if corpo == null or hb < 0:
		return {}
	var pts := PackedVector3Array()
	var mesh := corpo.mesh
	for s in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var bo = a[Mesh.ARRAY_BONES]
		var w = a[Mesh.ARRAY_WEIGHTS]
		if bo == null or v.is_empty():
			continue
		var nb: int = bo.size() / v.size()
		for i in v.size():
			var hw := 0.0
			for j in nb:
				if int(bo[i * nb + j]) == hb:
					hw += float(w[i * nb + j])
			if hw > 0.5:
				pts.append(v[i])
	if pts.is_empty():
		return {}
	var mn := pts[0]
	var mx := pts[0]
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	# olhos: centro de cada olho (vértices da malha "olhos", separados pelo lado)
	var oe := Vector3.ZERO
	var od := Vector3.ZERO
	var ne := 0
	var nd := 0
	if olhos:
		var a := olhos.mesh.surface_get_arrays(0)
		for p in (a[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if p.x < 0:
				oe += p
				ne += 1
			else:
				od += p
				nd += 1
	oe = oe / maxf(ne, 1) if ne > 0 else Vector3(-0.03, 1.69 if male else 1.572, 0.08)
	od = od / maxf(nd, 1) if nd > 0 else Vector3(0.03, 1.69 if male else 1.572, 0.08)
	var c := Vector3(0, (oe.y + od.y) * 0.5, (mn.z + mx.z) * 0.5)
	# raio da pele por direção (máximo em cada célula), depois fecha buracos e suaviza
	var r := PackedFloat32Array()
	r.resize(NLA * NLO)
	r.fill(-1.0)
	for p in pts:
		var d := p - c
		var dist := d.length()
		var th := acos(clampf(d.y / dist, -1.0, 1.0))
		var ph := atan2(d.x, d.z)
		var ia := mini(int(th / PI * NLA), NLA - 1)
		var io := int(fposmod(ph + PI, TAU) / TAU * NLO) % NLO
		r[ia * NLO + io] = maxf(r[ia * NLO + io], dist)
	for _passo in 40:
		var falta := false
		var r2 := r.duplicate()
		for ia in NLA:
			for io in NLO:
				if r[ia * NLO + io] >= 0.0:
					continue
				var s := 0.0
				var n := 0
				for da in [-1, 0, 1]:
					for dd in [-1, 0, 1]:
						var ja: int = ia + da
						if ja < 0 or ja >= NLA:
							continue
						var v2 := r[ja * NLO + (io + dd + NLO) % NLO]
						if v2 >= 0.0:
							s += v2
							n += 1
				if n > 0:
					r2[ia * NLO + io] = s / n
				else:
					falta = true
		r = r2
		if not falta:
			break
	# dilata (máximo 3x3) e depois tira a média: a máscara nunca entra na pele
	var dil := r.duplicate()
	for ia in NLA:
		for io in NLO:
			var m := 0.0
			for da in [-1, 0, 1]:
				for dd in [-1, 0, 1]:
					var ja := clampi(ia + da, 0, NLA - 1)
					m = maxf(m, r[ja * NLO + (io + dd + NLO) % NLO])
			dil[ia * NLO + io] = m
	var med := dil.duplicate()
	for ia in NLA:
		for io in NLO:
			var s := 0.0
			for da in [-1, 0, 1]:
				for dd in [-1, 0, 1]:
					var ja := clampi(ia + da, 0, NLA - 1)
					s += dil[ja * NLO + (io + dd + NLO) % NLO]
			med[ia * NLO + io] = maxf(s / 9.0, r[ia * NLO + io])
	var t := {"c": c, "r": med, "olhos": [oe, od], "topo": mx.y, "queixo": mn.y}
	_tabelas[k] = t
	return t


static func _pele(t: Dictionary, th: float, ph: float) -> float:
	var r: PackedFloat32Array = t.r
	var fa := clampf(th / PI * NLA - 0.5, 0.0, NLA - 1.001)
	var fo := fposmod(ph + PI, TAU) / TAU * NLO - 0.5
	var a0 := int(fa)
	var o0 := int(floorf(fo))
	var ta := fa - a0
	var to := fo - o0
	var o1 := (o0 + 1 + NLO) % NLO
	o0 = (o0 + NLO) % NLO
	var a1 := mini(a0 + 1, NLA - 1)
	return lerpf(lerpf(r[a0 * NLO + o0], r[a0 * NLO + o1], to), lerpf(r[a1 * NLO + o0], r[a1 * NLO + o1], to), ta)


# ---------------------------------------------------------------- forma do rosto
# devolve [raio, focinho, boca, contorno do olho, olho (dentro)] para uma direção (az, el) a partir do centro
static func _forma(t: Dictionary, f: Dictionary, male: bool, az: float, el: float) -> Array:
	var th := PI * 0.5 - el
	var base := _pele(t, th, az) + 0.0045
	var fo: Array = f.focinho
	var esc := 1.0 if male else 0.86
	var el_m := -0.40
	# focinho: um platô arredondado (borda definida), mais alto em cima para emendar na testa
	var sy: float = float(fo[2]) if el > el_m else float(fo[3])
	var q := sqrt(pow(az / float(fo[1]), 2.0) + pow((el - el_m) / sy, 2.0))
	var wf := 1.0 - smoothstep(0.35, 1.0, q)
	wf = wf * wf * (3.0 - 2.0 * wf)
	# queixo um pouco recuado em relação ao focinho: marca a boca
	if el < el_m - 0.1:
		wf *= lerpf(1.0, 0.72, smoothstep(el_m - 0.1, el_m - 0.3, el))
	var add := float(fo[0]) * esc * wf
	# almofadas de bigode (duas bolsas ao lado do nariz)
	var alm := float(f.almofada) * esc
	for lado in [-1.0, 1.0]:
		var dq := Vector2((az - lado * 0.16) / 0.13, (el - (el_m - 0.04)) / 0.11).length()
		add += alm * exp(-dq * dq)
	# sobrancelha firme: faixa sobre os olhos, levemente mais baixa no centro
	var el_b := 0.24 + 0.06 * minf(absf(az), 0.6)
	var wb := exp(-pow((el - el_b) / 0.075, 2.0)) * (1.0 - smoothstep(0.55, 0.9, absf(az)))
	add += float(f.testa) * wb
	# maçãs largas: rosto redondo, silhueta cheia
	for lado in [-1.0, 1.0]:
		var dq := Vector2((az - lado * 0.9) / 0.42, (el + 0.3) / 0.4).length()
		add += float(f.bochecha) * esc * exp(-dq * dq)
	# têmporas cheias: o alto da cabeça fica mais largo e redondo (menos crânio humano)
	for lado in [-1.0, 1.0]:
		var dq := Vector2((az - lado * 1.15) / 0.45, (el - 0.45) / 0.4).length()
		add += float(f.bochecha) * 0.6 * esc * exp(-dq * dq)
	# boca: filtro vertical sob o nariz e duas curvas descendo para os lados (sulco escuro)
	var el_boca := el_m - 0.075
	var boca := 0.0
	var curva := el_boca - 0.55 * absf(az) * absf(az) * 4.0
	if absf(az) < 0.3:
		boca = maxf(boca, exp(-pow((el - curva) / 0.016, 2.0)) * (1.0 - smoothstep(0.22, 0.3, absf(az))))
	if absf(az) < 0.02 and el > el_boca and el < el_m + 0.06:
		boca = maxf(boca, 1.0 - smoothstep(0.008, 0.02, absf(az)))
	add -= 0.0028 * boca
	# olhos: a máscara afunda até abaixo da pele para os olhos humanos aparecerem
	var dentro := 0.0
	var contorno := 0.0
	var c: Vector3 = t.c
	for oc in t.olhos:
		var d := (oc as Vector3) - c
		var oaz := atan2(d.x, d.z)
		var oel := asin(d.y / d.length())
		var dq := Vector2((az - oaz) / 0.24, (el - oel) / 0.13).length()
		dentro = maxf(dentro, 1.0 - smoothstep(0.62, 1.2, dq))
		contorno = maxf(contorno, exp(-pow((dq - 0.95) / 0.11, 2.0)))
	var r := base + add
	r = lerpf(r, base - 0.0075, dentro)
	return [r, wf, boca, contorno, dentro]


static func _dir(az: float, el: float) -> Vector3:
	return Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az))


static func ponto(t: Dictionary, f: Dictionary, male: bool, az: float, el: float) -> Vector3:
	var fm: Array = _forma(t, f, male, az, el)
	return (t.c as Vector3) + _dir(az, el) * float(fm[0])


# ---------------------------------------------------------------- máscara (malha + cores)
static func _mascara(t: Dictionary, f: Dictionary, sub: String, male: bool, pelo: Color) -> ArrayMesh:
	var na := 84
	var nl := 132
	var el_min := -1.2
	var claro := Color(str(f.claro))
	var escuro := Color(str(f.escuro))
	var contorno_c := Color(str(f.olho_contorno))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pos := PackedVector3Array()
	var cor := PackedColorArray()
	var uv := PackedVector2Array()
	var c: Vector3 = t.c
	var front_z := c.z + _pele(t, PI * 0.5 + 0.35, 0.0) + float(f.focinho[0]) * (1.0 if male else 0.86) * 0.82
	for i in na + 1:
		var el := lerpf(PI * 0.5, el_min, float(i) / na)
		for j in nl + 1:
			var az := lerpf(-PI, PI, float(j) / nl)
			var fm: Array = _forma(t, f, male, az, el)
			var p := c + _dir(az, el) * float(fm[0])
			# frente do focinho achatada: ponta firme, não um cilindro
			if p.z > front_z:
				p.z = front_z + (p.z - front_z) * 0.3
			pos.append(p)
			uv.append(Vector2(float(j) / nl, float(i) / na))
			cor.append(_cor(f, sub, pelo, claro, escuro, contorno_c, az, el, fm))
	for i in na:
		for j in nl:
			var a := i * (nl + 1) + j
			var b := a + 1
			var cc := a + nl + 1
			var d := cc + 1
			for idx in [a, b, cc, b, d, cc]:
				st.set_color(cor[idx])
				st.set_uv(uv[idx])
				st.add_vertex(pos[idx])
	st.index()
	st.generate_normals()
	return st.commit()


static func _ruido(x: float, y: float) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


static func _cor(f: Dictionary, sub: String, pelo: Color, claro: Color, escuro: Color, contorno_c: Color, az: float, el: float, fm: Array) -> Color:
	var wf: float = fm[1]
	var boca: float = fm[2]
	var cont: float = fm[3]
	var dentro: float = fm[4]
	var k := pelo
	# topo da cabeça e nuca um pouco mais escuros; focinho, queixo e garganta claros
	k = k.lerp(pelo.darkened(0.25), smoothstep(0.5, 1.3, el) * 0.6)
	k = k.lerp(pelo.darkened(0.18), smoothstep(1.6, 2.6, absf(az)) * 0.5)
	var clr := smoothstep(0.2, 0.75, wf) * (1.0 - smoothstep(-0.25, -0.1, el))
	clr = maxf(clr, smoothstep(-0.75, -1.0, el) * (1.0 - smoothstep(0.7, 1.4, absf(az))))
	if sub in ["tigre", "onca"]:
		# mancha clara acima dos olhos e nas bochechas
		for lado in [-1.0, 1.0]:
			var dq := Vector2((az - lado * 0.33) / 0.1, (el - 0.28) / 0.05).length()
			clr = maxf(clr, exp(-dq * dq) * 0.7)
			var db := Vector2((az - lado * 0.75) / 0.35, (el + 0.38) / 0.25).length()
			clr = maxf(clr, exp(-db * db) * 0.85)
	if sub == "lobo":
		# máscara de lobo: dorso do focinho e testa escuros, bochechas e garganta claras
		var dorso := exp(-pow(az / 0.14, 2.0)) * smoothstep(-0.38, -0.2, el) * (1.0 - smoothstep(0.5, 0.9, el))
		k = k.lerp(escuro, dorso * 0.55)
		var db := Vector2((absf(az) - 0.75) / 0.4, (el + 0.35) / 0.3).length()
		clr = maxf(clr, exp(-db * db))
	k = k.lerp(claro, clamp(clr, 0.0, 1.0))
	if f.get("listras", false):
		var lst := 0.0
		# testa: listras verticais finas; bochechas e lados: listras horizontais que afinam
		if el > 0.24 and absf(az) < 0.8:
			# testa: arcos que convergem para o centro, de espessuras diferentes e interrompidos
			var s := absf(sin(absf(az) * 8.0 - (el - 0.24) * 5.0 + _ruido(floorf(absf(az) * 8.0 / PI), 1.0) * 1.2))
			var corte_l := 0.9 + 0.06 * _ruido(floorf(absf(az) * 8.0 / PI), floorf(el * 6.0))
			lst = smoothstep(corte_l, corte_l + 0.05, s) * smoothstep(0.24, 0.42, el) * (1.0 - smoothstep(0.02, 0.06, absf(az)) * 0.0)
		if absf(az) > 0.55 and absf(az) < 2.4 and el < 0.5:
			var s2 := absf(sin(el * 13.0 + absf(az) * 2.2))
			lst = maxf(lst, smoothstep(0.88, 0.96, s2) * smoothstep(0.55, 0.85, absf(az)))
		if absf(az) > 2.2:
			var s3 := absf(sin(az * 9.0 + el * 4.0))
			lst = maxf(lst, smoothstep(0.86, 0.95, s3))
		k = k.lerp(escuro, lst * (1.0 - clr * 0.85))
	if f.get("rosetas", false):
		# rosetas de onça: anéis escuros pequenos em grade irregular, sem tocar o focinho
		var gx := az * 9.0
		var gy := el * 9.0
		var ix := floorf(gx)
		var iy := floorf(gy)
		var m := 0.0
		for dx in [-1.0, 0.0, 1.0]:
			for dy in [-1.0, 0.0, 1.0]:
				var cx: float = ix + dx + 0.25 + 0.5 * _ruido(ix + dx, iy + dy)
				var cy: float = iy + dy + 0.25 + 0.5 * _ruido(iy + dy, ix + dx + 7.0)
				var dd := Vector2(gx - cx, gy - cy).length()
				m = maxf(m, exp(-pow((dd - 0.28) / 0.08, 2.0)) if el > -0.2 or absf(az) > 0.6 else 0.0)
		k = k.lerp(escuro, m * (1.0 - clr) * 0.9)
	# contorno escuro dos olhos (delineado natural) e boca
	k = k.lerp(contorno_c, cont * 0.45)
	k = k.lerp(contorno_c, boca)
	# alfa = densidade das cascas de pelo (zero perto dos olhos, nariz e boca)
	var a := 1.0 - maxf(maxf(dentro, cont * 0.8), boca)
	a *= 1.0 - smoothstep(0.55, 0.95, wf) * 0.7
	return Color(k.r, k.g, k.b, clampf(a, 0.0, 1.0))


static func _mat_pelo(casca: float, corte: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
render_mode cull_back, depth_draw_opaque;
uniform float casca = 0.0;
uniform float corte = 0.0;
varying vec2 p;
varying float dens;
void vertex() {
	VERTEX += NORMAL * casca * COLOR.a;
	p = UV;
	dens = COLOR.a;
}
float h(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 g = vec2(p.x * 1100.0, p.y * 170.0);
	float n = h(floor(g));
	float n2 = h(floor(g * 0.37) + 3.1);
	float fio = mix(0.82, 1.02, n * 0.65 + n2 * 0.35);
	vec3 c = COLOR.rgb * fio;
	if (casca > 0.0) {
		if (n < corte || dens < 0.35) { discard; }
		c *= 1.0 + casca * 12.0;
	}
	ALBEDO = c;
	ROUGHNESS = 0.92;
	SPECULAR = 0.22;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("casca", casca)
	m.set_shader_parameter("corte", corte)
	return m


# ---------------------------------------------------------------- nariz, orelhas, bigodes
static func _nariz(att: Node3D, inv: Transform3D, t: Dictionary, f: Dictionary, sub: String, male: bool) -> void:
	var el_n := -0.30
	var p := ponto(t, f, male, 0.0, el_n)
	var front_z := (t.c as Vector3).z + _pele(t, PI * 0.5 + 0.35, 0.0) + float(f.focinho[0]) * (1.0 if male else 0.86) * 0.82
	if p.z > front_z:
		p.z = front_z + (p.z - front_z) * 0.3
	var grande := 1.25 if sub in ["lobo", "ursa"] else 1.0
	var esc := (1.0 if male else 0.9) * grande
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(str(f.nariz))
	m.roughness = 0.32
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 16
	s.rings = 8
	# almofada do nariz: triângulo arredondado (mais largo em cima), um pouco à frente do focinho
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = m
	mi.transform = inv * Transform3D(Basis.from_euler(Vector3(-0.35, 0, 0)) * Basis.from_scale(Vector3(0.026, 0.014, 0.018) * esc), p + Vector3(0, 0.002, 0.002))
	att.add_child(mi)
	for lado in [-1.0, 1.0]:
		var n2 := MeshInstance3D.new()
		n2.mesh = s
		n2.material_override = m
		n2.transform = inv * Transform3D(Basis.from_euler(Vector3(0, 0, lado * 0.5)) * Basis.from_scale(Vector3(0.012, 0.013, 0.012) * esc), p + Vector3(lado * 0.009 * esc, -0.004 * esc, 0.0))
		att.add_child(n2)


static func _malha_orelha(forma: String, cor_fora: Color, cor_dentro: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 10
	var nv := 8
	var grade := []
	for face in 2:
		var linhas := []
		for i in nu + 1:
			var u := float(i) / nu
			var hw := 0.0
			match forma:
				"pontuda":
					hw = pow(1.0 - u, 0.8) * (1.0 + 0.25 * sin(PI * u))
				"urso":
					hw = sqrt(maxf(0.0, 1.0 - pow((u - 0.35) / 0.65, 2.0)))
				_:
					hw = sqrt(maxf(0.0, 1.0 - pow((u - 0.42) / 0.58, 2.0)))
			var lin := []
			for j in nv + 1:
				var v := lerpf(-1.0, 1.0, float(j) / nv)
				var concha := 0.35 * (1.0 - v * v) * sin(PI * minf(u * 1.15, 1.0))
				var z := -concha if face == 0 else -concha * 0.55 - 0.16 * (1.0 - u * 0.6)
				lin.append(Vector3(v * hw * 0.5, u, z))
			linhas.append(lin)
		grade.append(linhas)
	for face in 2:
		var cor := cor_dentro if face == 0 else cor_fora
		for i in nu:
			for j in nv:
				var a: Vector3 = grade[face][i][j]
				var b: Vector3 = grade[face][i][j + 1]
				var c: Vector3 = grade[face][i + 1][j]
				var d: Vector3 = grade[face][i + 1][j + 1]
				var tri := [a, b, c, b, d, c] if face == 0 else [a, c, b, b, c, d]
				for k in 6:
					var pv: Vector3 = tri[k]
					var borda := absf(pv.x) / maxf(0.0001, 0.5)
					var cc := cor
					if face == 0:
						cc = cor_dentro.lerp(cor_fora, smoothstep(0.55, 0.95, absf(pv.x) * 2.0 / maxf(0.001, sqrt(maxf(0.0, 1.0 - pow((pv.y - 0.42) / 0.58, 2.0))) + 0.001)))
					st.set_color(Color(cc.r, cc.g, cc.b, 0.0 if face == 0 else 1.0))
					st.set_uv(Vector2(pv.x + 0.5, pv.y))
					st.add_vertex(pv)
	# borda que fecha as duas faces
	for i in nu:
		for j in [0, nv]:
			var a: Vector3 = grade[0][i][j]
			var b: Vector3 = grade[0][i + 1][j]
			var c: Vector3 = grade[1][i][j]
			var d: Vector3 = grade[1][i + 1][j]
			var tri := [a, c, b, b, c, d] if j == 0 else [a, b, c, b, d, c]
			for pv in tri:
				st.set_color(Color(cor_fora.r, cor_fora.g, cor_fora.b, 1.0))
				st.set_uv(Vector2(0.5, (pv as Vector3).y))
				st.add_vertex(pv)
	st.index()
	st.generate_normals()
	return st.commit()


static func _orelhas(att: Node3D, inv: Transform3D, t: Dictionary, f: Dictionary, sub: String, male: bool, pelo: Color) -> void:
	var o: Array = f.orelha
	var od: Array = f.orelha_dir
	var dentro := Color(str(f.claro)).lerp(Color("#c99a8a"), 0.35)
	if sub == "lobo":
		dentro = Color("#d8d0c8")
	var fora := pelo.darkened(0.12)
	if sub == "tigre":
		fora = Color("#2a1e18")
	var mesh := _malha_orelha(str(o[0]), fora, dentro)
	var esc := 1.0 if male else 0.92
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.95
	for lado in [-1.0, 1.0]:
		var az: float = lado * float(od[0])
		var el: float = float(od[1])
		var raiz := ponto(t, f, male, az, el)
		var d := (raiz - (t.c as Vector3)).normalized()
		var y := (d * 0.55 + Vector3.UP * (1.0 if sub == "lobo" else 0.7)).normalized()
		var lateral := Vector3(lado, 0, 0)
		var frente := (Vector3(0, 0, 1) + lateral * (0.25 if sub == "lobo" else 0.55)).normalized()
		var z := (frente - y * frente.dot(y)).normalized()
		var x := y.cross(z).normalized()
		var b := Basis(x * float(o[2]) * 2.0 * esc, y * float(o[1]) * esc, z * float(o[2]) * 2.0 * esc)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.transform = inv * Transform3D(b, raiz - d * 0.008)
		att.add_child(mi)
		# mancha clara atrás da orelha do tigre (marca da espécie)
		if sub == "tigre":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			var mm := StandardMaterial3D.new()
			mm.albedo_color = Color("#f2ece0")
			mm.roughness = 1.0
			var sp := MeshInstance3D.new()
			sp.mesh = s
			sp.material_override = mm
			sp.transform = inv * Transform3D(Basis(x, y, z) * Basis.from_scale(Vector3(0.016, 0.018, 0.004) * esc), raiz - d * 0.008 + y * float(o[1]) * 0.4 * esc - z * 0.012 * esc)
			att.add_child(sp)


static func _bigodes(att: Node3D, inv: Transform3D, t: Dictionary, f: Dictionary, male: bool) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.93, 0.88)
	m.roughness = 0.6
	var cil := CylinderMesh.new()
	cil.top_radius = 0.0002
	cil.bottom_radius = 0.0009
	cil.height = 1.0
	cil.radial_segments = 4
	cil.rings = 1
	for lado in [-1.0, 1.0]:
		for k in 4:
			var raiz := ponto(t, f, male, lado * 0.19, -0.42 - k * 0.025)
			var dir := Vector3(lado * 1.0, 0.12 - k * 0.1, -0.15).normalized()
			var comp := 0.075 - k * 0.006
			var b := Basis(Quaternion(Vector3.UP, dir)) * Basis.from_scale(Vector3(1, comp, 1))
			var mi := MeshInstance3D.new()
			mi.mesh = cil
			mi.material_override = m
			mi.transform = inv * Transform3D(b, raiz + dir * comp * 0.5)
			mi.visibility_range_end = 10.0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			att.add_child(mi)


# ---------------------------------------------------------------- juba e golas de pelo (fios definidos)
static func _malha_fio() -> ArrayMesh:
	if _fios.has("fio"):
		return _fios.fio
	# mecha: tubo de 5 lados que afina até a ponta e se curva; base escura, ponta mais clara
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 7
	var lados := 5
	var aneis := []
	for i in n + 1:
		var t := float(i) / n
		var c := Vector3(0.06 * sin(t * PI * 1.5), t, 0.34 * t * t - 0.08 * sin(t * PI))
		var r := 0.5 * pow(1.0 - t, 0.45) + 0.02
		var anel := []
		for k in lados:
			var a := TAU * k / lados
			anel.append(c + Vector3(cos(a) * r, 0, sin(a) * r * 0.85))
		aneis.append(anel)
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var k0 := Color(0.55, 0.55, 0.55).lerp(Color(1.1, 1.1, 1.1), t0)
		var k1 := Color(0.55, 0.55, 0.55).lerp(Color(1.1, 1.1, 1.1), t1)
		for k in lados:
			var k2 := (k + 1) % lados
			var a: Vector3 = aneis[i][k]
			var b: Vector3 = aneis[i][k2]
			var c: Vector3 = aneis[i + 1][k]
			var d: Vector3 = aneis[i + 1][k2]
			for v in [[a, k0], [c, k1], [b, k0], [b, k0], [c, k1], [d, k1]]:
				st.set_color(v[1])
				st.add_vertex(v[0])
	st.generate_normals()
	_fios.fio = st.commit()
	return _fios.fio


static func _juba(att: Node3D, inv: Transform3D, t: Dictionary, f: Dictionary, sub: String, male: bool, pelo: Color) -> void:
	var cores: Array = f.pelo_juba
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sub + ("m" if male else "f"))
	var od: Array = f.orelha_dir
	var xf := []
	var cs := []
	var leao := sub == "leao" and male
	var total := 1500 if leao else (510 if sub == "lobo" else 360)
	var tentativas := 0
	while xf.size() < total and tentativas < total * 6:
		tentativas += 1
		var az := rng.randf_range(-PI, PI)
		var el := asin(rng.randf_range(-1.0, 1.0))
		# fora do rosto: a juba emoldura, nunca cobre olhos e focinho
		var face := Vector2(az / 1.05, (el + 0.15) / 0.95).length()
		var comp := 0.0
		var largura := 0.03
		if leao:
			if face < 1.0 or el < -1.45 or el > 1.2:
				continue
			# coroa curta no alto, longa nos lados, nuca e pescoço
			comp = lerpf(0.1, 0.3, smoothstep(0.9, -0.7, el)) * lerpf(1.0, 1.15, smoothstep(1.2, 2.6, absf(az)))
			largura = 0.011
			# moldura do rosto: fios curtos e densos que suavizam a borda
			if face < 1.3:
				comp *= 0.38
				largura = 0.008
		elif sub == "lobo":
			# gola: bochechas, garganta e nuca; topo da cabeça liso
			if face < 1.05 or el > 0.25 or el < -1.45:
				continue
			comp = lerpf(0.045, 0.12, smoothstep(-0.1, -1.0, el))
			largura = 0.014
		else:
			# felinas e ursa: gola curta nas bochechas e no pescoço (fecha a borda da cabeça)
			if face < 1.12 or el > -0.05 or el < -1.4:
				continue
			comp = lerpf(0.035, 0.075, smoothstep(-0.2, -1.0, el)) * (0.85 if sub == "ursa" else 1.0)
			largura = 0.012
		# longe das orelhas
		var perto := false
		for lado in [-1.0, 1.0]:
			if Vector2(az - lado * float(od[0]), el - float(od[1])).length() < 0.32:
				perto = true
		if perto:
			continue
		comp *= rng.randf_range(0.8, 1.2) * (1.0 if male else 0.9)
		var elc := maxf(el, -1.2)
		var raiz := ponto(t, f, male, az, elc)
		if el < -1.2:
			# abaixo da máscara: os fios descem pelo pescoço
			raiz += Vector3(0, (el + 1.2) * 0.09, 0)
		var d := (raiz - (t.c as Vector3)).normalized()
		# no alto os fios vão para trás; dos lados e embaixo caem com o peso
		var cai := (1.0 if leao else 0.6) * smoothstep(0.65, -0.1, el)
		var g := (d * (0.5 if leao else 1.0) + Vector3(0, -cai, 0) + Vector3(0, 0.15 * (1.0 - cai), -0.6)).normalized()
		g = (g + Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.1, 0.1), rng.randf_range(-0.15, 0.15))).normalized()
		var fora := (d - g * d.dot(g)).normalized()
		if fora.length() < 0.1:
			fora = Vector3(0, 0, -1)
		var x := g.cross(fora).normalized()
		var k: Color = Color(str(cores[rng.randi() % cores.size()]))
		# camada de fora mais escura no leão (juba clássica: escura atrás, dourada na frente)
		if leao and face > 1.6:
			k = k.lerp(Color(str(cores[3])), 0.35)
		# tufo: 3 fios juntos com a mesma direção (mechas definidas, não espinhos soltos)
		for fio in 3:
			var w := largura * rng.randf_range(0.75, 1.1)
			var desvio := x * rng.randf_range(-0.008, 0.008) + g.cross(x) * rng.randf_range(-0.004, 0.004)
			var g2 := (g + x * rng.randf_range(-0.12, 0.12)).normalized()
			var b := Basis(x * w, g2 * comp * rng.randf_range(0.88, 1.08), fora * comp * 0.6)
			xf.append(Transform3D(b, raiz - d * 0.006 + desvio))
			cs.append(k.lerp(k.lightened(0.15), rng.randf()))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# dois níveis de detalhe: todos os fios até 22 m; depois, 1 a cada 3 fios mais grossos (mesma silhueta, 1/3 do custo)
	for nivel in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _malha_fio()
		var idx := []
		for i in xf.size():
			if nivel == 0 or i % 3 == 0:
				idx.append(i)
		mm.instance_count = idx.size()
		for n in idx.size():
			var tr: Transform3D = xf[idx[n]]
			if nivel == 1:
				tr.basis.x *= 1.7
				tr.basis.z *= 1.25
			mm.set_instance_transform(n, inv * tr)
			mm.set_instance_color(n, cs[idx[n]])
		var mi := MultiMeshInstance3D.new()
		mi.name = "Juba" if nivel == 0 else "JubaLonge"
		mi.multimesh = mm
		mi.material_override = mat
		if nivel == 0:
			mi.visibility_range_end = 22.0
			mi.visibility_range_end_margin = 2.0
		else:
			mi.visibility_range_begin = 22.0
			mi.visibility_range_begin_margin = 2.0
			mi.visibility_range_end = 160.0
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		att.add_child(mi)


# ---------------------------------------------------------------- sinais de fera no corpo
static func garras(skel: Skeleton3D, sub: String, male: bool) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#2b2420") if sub != "lobo" else Color("#1e1c1c")
	m.roughness = 0.35
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 8
	cone.rings = 1
	var comp := (0.024 if sub == "ursa" else 0.018) * (1.0 if male else 0.85)
	for lado in ["l", "r"]:
		for dedo in ["thumb", "index", "middle", "ring", "pinky"]:
			var b3 := skel.find_bone(dedo + "_03_" + lado)
			var b4 := skel.find_bone(dedo + "_04_leaf_" + lado)
			if b3 < 0 or b4 < 0:
				continue
			var r3 := skel.get_bone_global_rest(b3)
			var p4 := skel.get_bone_global_rest(b4).origin
			var dir := (p4 - r3.origin).normalized()
			var att := BoneAttachment3D.new()
			att.bone_name = dedo + "_03_" + lado
			skel.add_child(att)
			# garra saindo da ponta do dedo, levemente curvada para baixo
			var d2 := (dir + Vector3(0, -0.35, 0)).normalized()
			var b := Basis(Quaternion(Vector3.UP, d2)) * Basis.from_scale(Vector3(0.0075, comp, 0.0055) * (1.0 if male else 0.85))
			var mi := MeshInstance3D.new()
			mi.mesh = cone
			mi.material_override = m
			mi.transform = r3.affine_inverse() * Transform3D(b, p4 - dir * 0.004 + d2 * comp * 0.45)
			att.add_child(mi)
