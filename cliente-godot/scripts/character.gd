extends Node3D
const Perfil := preload("res://scripts/perfil.gd")
# Personagem: corpo-base + roupa + cabelo presos ao mesmo esqueleto, com as animações do jogo.

const DIR := "res://assets/chars/"
static var _libraries := {}
# cenas (.glb) carregadas ficam guardadas aqui: sem isso, quando os moradores de uma cidade somem,
# o motor descarta o modelo e a próxima cidade recarrega tudo do disco (travadas de 0,5 a 2 s no notebook)
static var _cenas := {}

# aquece o cache: carrega em segundo plano (outra linha de execução) os modelos de todas as raças, roupas e cabelos
static func aquecer() -> void:
	var lista := []
	for f in DirAccess.get_files_at(DIR) + DirAccess.get_files_at(DIR_V3):
		var nome := String(f).trim_suffix(".import").trim_suffix(".remap")
		if nome.ends_with(".glb") and not lista.has(nome):
			lista.append(nome)
	for nome in lista:
		var caminho: String = (DIR_V3 if FileAccess.file_exists(DIR_V3 + nome + ".import") or ResourceLoader.exists(DIR_V3 + nome) else DIR) + nome
		if ResourceLoader.exists(caminho) and not _cenas.has(caminho):
			ResourceLoader.load_threaded_request(caminho)
			_pendentes.append(caminho)

static var _pendentes := []

# chamado a cada quadro: guarda o que terminou de carregar
static func recolher() -> void:
	for i in range(_pendentes.size() - 1, -1, -1):
		var c: String = _pendentes[i]
		var st := ResourceLoader.load_threaded_get_status(c)
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_cenas[c] = ResourceLoader.load_threaded_get(c)
			_pendentes.remove_at(i)
		elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_pendentes.remove_at(i)


static func cena(caminho: String) -> PackedScene:
	var c: PackedScene = _cenas.get(caminho)
	if c == null:
		if _pendentes.has(caminho):   # já está chegando em segundo plano: espera esse mesmo carregamento
			_pendentes.erase(caminho)
			c = ResourceLoader.load_threaded_get(caminho)
		else:
			c = load(caminho)
		_cenas[caminho] = c
	return c
static var world_ref: Node  # mundo, para os pés pisarem no chão (altura do terreno embaixo de cada pé)
# V3 (base de teste): humanos com corpo e rosto A novos, roupa de aldeão com formas corretivas e RBF otimizado (v3o)
static var V3_HUMANOS := true
const DIR_V3 := "res://assets_v3/personagens/"
const V3Ctrl := preload("res://scripts/v3_corretivas.gd")
var v3 := false

var skel: Skeleton3D
var anim: AnimationPlayer
var current := ""
var busy_until := 0.0
var tag: Label3D
var height_m := 1.8
var wnode: Node3D
var grip_node: Node3D
var sheath: Node3D
var armed := true
var magic_idle := false
var ik: SkeletonModifier3D  # braço esquerdo até o cabo (arma de duas mãos)
var ik_r: SkeletonModifier3D  # braço direito até a guarda, na postura parada
var guard: Node3D  # arma de duas mãos segura à frente do corpo, com as duas mãos
var guard_on := false
var fist: Node  # Punho: fecha os dedos no cabo
var fist_hands := ["r"]
var offhand: Node3D  # segunda adaga (armas duplas), só aparece em combate
var shield: Node3D
var shield_arm: Node3D
var shield_back: Node3D
var body_node: Node3D
var body_base_y := 0.0
var feet := []  # [osso do pé esquerdo, osso do pé direito]
var ankle := -1.0  # altura do tornozelo acima da sola, medida no primeiro quadro
var foot_off := 0.0


static var RACES := {}
static var HAIR_COLORS: Array = []
const HAIR_M := ["hair_buzzed", "hair_simpleparted", "hair_long", "hair_slickback", "hair_bob", "hair_buns"]
const HAIR_F := ["hair_buzzedfemale", "hair_bob", "hair_long", "hair_buns", "hair_long", "hair_buns"]
# forma própria de cada raça: escala geral, ossos (encolhe pernas, alarga tronco, aumenta cabeça) e quanto o corpo desce
# para os pés tocarem o chão depois de encurtar as pernas
const SHAPE := {
	"anao:m": {"all": 0.92, "drop": 0.3, "bones": {"thigh_l": 0.68, "thigh_r": 0.68, "foot_l": 1.4, "foot_r": 1.4, "spine_01": 1.36, "spine_02": 0.93, "spine_03": 0.92, "neck_01": 0.88, "Head": 1.22, "hand_l": 1.2, "hand_r": 1.2}},
	"anao:f": {"all": 0.88, "drop": 0.24, "bones": {"thigh_l": 0.75, "thigh_r": 0.75, "foot_l": 1.28, "foot_r": 1.28, "spine_01": 1.1, "spine_03": 0.96, "neck_01": 0.92, "Head": 1.34, "hand_l": 1.1, "hand_r": 1.1}},
	"orc:m": {"all": 1.1, "drop": 0.0, "bones": {"spine_02": 1.1, "spine_03": 1.1, "neck_01": 0.92, "Head": 0.86, "hand_l": 1.15, "hand_r": 1.15}},
	"gigante:m": {"all": 1.38, "drop": 0.0, "bones": {"spine_03": 1.08, "Head": 0.88}},
	"gigante:f": {"all": 1.3, "drop": 0.0, "bones": {"Head": 0.9}},
}
# modelos próprios: altura e quanto o quadril fica mais baixo que o do humano (as animações movem o quadril)
# bones: ajuste fino de proporção (braço mais curto, mão menor, perna um pouco mais longa, cabeça)
const OWN := {"anao_m": {"height": 1.36, "hip": 0.624, "bones": {}}, "anao_f": {"height": 1.3, "hip": 0.657, "bones": {}}}
# pegada por tipo de arma (medidas em metros para 1,80 m de altura):
# at = onde a mão principal segura, medido a partir da ponta do cabo; two = onde a segunda mão segura (0 = uma mão só)
# hand = mão principal; back = guardada nas costas (senão na cintura); dual = uma em cada mão
const GRIP := {
	"espada": {"file": "w_sword", "len": 1.0, "at": 0.1},
	"adaga": {"file": "w_dagger", "len": 0.5, "at": 0.06},
	"punhal": {"file": "w_dagger", "len": 0.42, "at": 0.05},
	"duplas": {"file": "w_sword", "len": 0.8, "at": 0.08, "dual": true},
	"machado": {"file": "w_axe", "len": 0.95, "at": 0.12},
	"cetro": {"file": "w_spear", "len": 0.75, "at": 0.1},
	"espadao": {"file": "w_claymore", "len": 1.45, "at": 0.3, "two": 0.1, "back": true},
	"martelo": {"file": "w_hammer_double", "len": 1.1, "at": 0.4, "two": 0.12, "back": true},
	"cajado": {"file": "w_spear", "len": 1.7, "at": 0.75, "two": 0.42, "back": true},
	"lanca": {"file": "w_spear", "len": 1.9, "at": 0.75, "two": 0.38, "back": true},
	"arco": {"file": "w_bow_wooden", "len": 1.3, "at": -1.0, "hand": "l", "back": true},
}
const WEAPON := {"espada": ["w_sword", 1.0], "espadao": ["w_claymore", 1.45], "arco": ["w_bow_wooden", 1.3], "adaga": ["w_dagger", 0.5], "martelo": ["w_hammer_double", 1.2], "cajado": ["w_spear", 1.7], "machado": ["w_axe", 0.95]}


# o: {race, gender, skin, hair, hair_color, look, equipment}; aceita o registro do personagem vindo do servidor
static func create(o: Dictionary = {}) -> Node3D:
	var c: Node3D = load("res://scripts/character.gd").new()
	c._setup(o)
	return c


func _setup(o: Dictionary) -> void:
	var __t := Time.get_ticks_usec()
	_setup_medido(o)
	Perfil.soma("boneco", Time.get_ticks_usec() - __t)


func _setup_medido(o: Dictionary) -> void:
	var race := str(o.get("race", "humano"))
	var male := str(o.get("gender", "m")) != "f"
	var rd: Dictionary = RACES.get(race, {})
	var look: Dictionary = o.get("look") if o.get("look") is Dictionary else {}
	var eq: Dictionary = o.get("equipment") if o.get("equipment") is Dictionary else {}
	var skins: Array = rd.get("skins", ["#e8b993"])
	var skin := Color(str(skins[clampi(int(o.get("skin", look.get("skin", 0))), 0, skins.size() - 1)]))
	if o.has("skin_color"):
		skin = Color(str(o.skin_color))
	var hair_i := clampi(int(o.get("hair", look.get("hair", 1))), 0, 5)
	var hc_i := int(o.get("hair_color", look.get("hair_color", 0)))
	var hair_col := Color(str(HAIR_COLORS[clampi(hc_i, 0, HAIR_COLORS.size() - 1)])) if not HAIR_COLORS.is_empty() else Color(0.24, 0.15, 0.08)
	var armor := str(eq.get("armadura", "pesada_ng"))
	var g := "male" if male else "female"
	var outfit := "peasant"
	if armor.begins_with("pesada"):
		outfit = "knight" if male else "ranger"
	elif armor.begins_with("leve"):
		outfit = "ranger"
	elif armor.begins_with("robe"):
		outfit = "wizard" if male else "peasant"
	var dragon := race == "draconato"
	# raças com modelo próprio (corpo, roupa e cabelo numa peça só)
	var own := ""
	if race == "anao":
		own = "anao_m" if male else "anao_f"
	var file := "body_%s_%s" % [g, outfit]
	if dragon:
		file = "body_dragonita"
	elif own != "":
		file = "body_" + own
	v3 = V3_HUMANOS and race == "humano"
	var body: Node3D = cena(DIR_V3 + ("pc_humano_m_rostoA" if male else "pc_humano_f_rostoA") + ".glb").instantiate() if v3 else cena(DIR + file + ".glb").instantiate()
	body.name = "Corpo"
	add_child(body)
	body_node = body
	skel = body.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel.get_parent() == body:  # as animações procuram o esqueleto em Armature/Skeleton3D
		var arm := Node3D.new()
		arm.name = "Armature"
		body.add_child(arm)
		body.remove_child(skel)
		arm.add_child(skel)
	if dragon:
		for m in skel.find_children("*", "MeshInstance3D", true, false):
			_tint(m as MeshInstance3D, Color(skin.r / 0.69, skin.g / 0.376, skin.b / 0.172))
	elif own != "":
		pass
	elif v3:
		_vestir_v3(male, outfit, hair_col)
	else:
		for m in skel.find_children("*", "MeshInstance3D", true, false):
			var nm := String(m.name).to_lower()
			if nm.contains("eyebrow"):
				_tint(m as MeshInstance3D, hair_col.darkened(0.25))
			elif not (nm.contains("eye") or nm.contains("teeth") or nm.contains("tongue")):
				_tint(m as MeshInstance3D, Color(skin.r / 0.89, skin.g / 0.71, skin.b / 0.56))
		_attach("outfit_%s_%s" % [g, outfit])
		if not rd.get("no_hair", false):
			_attach((HAIR_M if male else HAIR_F)[hair_i], hair_col)
		if male and (race in ["anao", "gigante"] or int(look.get("beard", 0)) > 0):
			_attach("hair_beard", hair_col)
	for m in skel.get_children():
		if m is MeshInstance3D:
			# o corpo se mexe muito além da caixa de repouso; amplia para não sumir na borda da tela
			(m as MeshInstance3D).extra_cull_margin = 1.5
	var w: float = rd.get("w", 1.0)
	var h: float = rd.get("h", 1.0) * (1.0 if male else 0.97)
	var shape: Dictionary = SHAPE.get("%s:%s" % [race, "m" if male else "f"], {})
	if own != "":
		height_m = float(OWN[own].height)
		for bn in OWN[own].bones:
			skel.set_bone_pose_scale(skel.find_bone(bn), Vector3.ONE * float(OWN[own].bones[bn]))
	elif shape.is_empty():
		body.scale = Vector3(w, h, w)
		height_m = 1.8 * h
	else:
		var k: float = shape.all
		body.scale = Vector3.ONE * k
		body.position.y = -float(shape.drop) * k
		for bn in shape.bones:
			var bi := skel.find_bone(bn)
			if bi >= 0:
				skel.set_bone_pose_scale(bi, Vector3.ONE * float(shape.bones[bn]))
		height_m = (1.8 + (0.12 if race == "anao" else 0.0)) * k - float(shape.drop) * k
	anim = AnimationPlayer.new()
	body.add_child(anim)
	anim.add_animation_library("", _clips(skel, own))
	anim.playback_default_blend_time = 0.18
	var wid := str(eq.get("arma", ""))
	var kind := wid.split("_")[0]
	if GRIP.has(kind):
		# a arma acompanha o tamanho de quem usa: menor no anão, maior no gigante
		_weapon(kind, lerpf(1.0, height_m / 1.8, 0.85), str(eq.get("escudo", "")) != "", wid, str(eq.get("escudo", "")))
		var en: Dictionary = o.get("enchant") if o.get("enchant") is Dictionary else {}
		brilho_encanto(int(en.get(wid, 0)))
	if bool(o.get("heroi", false)):
		aura_heroi(true)
	play("Idle")


# ---------- brilho de encantamento (+4 a +16) e aura de herói ----------
# Faixas próprias de Valtheria: aço azul (+4), turquesa (+7), âmbar (+10), violeta (+13) e ouro branco (+16).
const FAIXAS_ENCANTO := [[4, Color(0.35, 0.55, 1.0)], [7, Color(0.2, 0.95, 0.85)], [10, Color(1.0, 0.55, 0.15)], [13, Color(0.7, 0.3, 1.0)], [16, Color(1.0, 0.92, 0.6)]]
const BRILHO_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;
uniform vec3 cor : source_color = vec3(0.4, 0.6, 1.0);
uniform float forca = 1.0;
void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float pulso = 0.75 + 0.25 * sin(TIME * 3.0);
	ALBEDO = cor * (0.25 + fr * 1.6) * forca * pulso;
}
"""
static var _brilho_shader: Shader
var encanto := 0
var _aura: Node3D


func brilho_encanto(nivel: int) -> void:
	encanto = nivel
	if wnode == null:
		return
	for c in wnode.get_children():
		if c.name == "BrilhoEncanto":
			c.queue_free()
	var faixa := -1
	for i in FAIXAS_ENCANTO.size():
		if nivel >= int(FAIXAS_ENCANTO[i][0]):
			faixa = i
	for m in wnode.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = null
	if faixa < 0:
		_rastros_encanto(-1, Color())
		return
	if _brilho_shader == null:
		_brilho_shader = Shader.new()
		_brilho_shader.code = BRILHO_SHADER
	var cor: Color = FAIXAS_ENCANTO[faixa][1]
	var mat := ShaderMaterial.new()
	mat.shader = _brilho_shader
	mat.set_shader_parameter("cor", cor)
	mat.set_shader_parameter("forca", 0.5 + 0.3 * faixa + 0.05 * float(nivel - int(FAIXAS_ENCANTO[faixa][0])))
	var bb := AABB()
	var first := true
	for m in wnode.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = mat
		var a: AABB = _rel_wnode(m) * (m as MeshInstance3D).get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	if faixa >= 1:   # a partir do +7: faíscas subindo da lâmina
		var p := CPUParticles3D.new()
		p.name = "BrilhoEncanto"
		p.amount = 6 + faixa * 6
		p.lifetime = 0.9
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = bb.size * 0.45
		p.position = bb.get_center()
		p.direction = Vector3.UP
		p.spread = 25.0
		p.gravity = Vector3(0, 0.6, 0)
		p.initial_velocity_min = 0.05
		p.initial_velocity_max = 0.25
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.0
		var q := QuadMesh.new()
		q.size = Vector2(0.025, 0.025)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		qm.albedo_color = cor * 1.5
		q.material = qm
		p.mesh = q
		p.visibility_range_end = 30.0
		wnode.add_child(p)
		# estrela de luz na ponta da lâmina (ponta mais distante da empunhadura)
		var ponta := bb.get_center()
		var eixo := 0
		if bb.size.y > bb.size[eixo]: eixo = 1
		if bb.size.z > bb.size[eixo]: eixo = 2
		var fim := bb.position[eixo] + bb.size[eixo]
		ponta[eixo] = fim if absf(fim) > absf(bb.position[eixo]) else bb.position[eixo]
		var est := MeshInstance3D.new()
		est.name = "BrilhoEncanto"
		var eq := QuadMesh.new()
		var tam := 0.4 + 0.18 * faixa
		eq.size = Vector2(tam, tam)
		est.mesh = eq
		est.material_override = _estrela_mat(cor, faixa)
		est.position = ponta
		est.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		est.visibility_range_end = 40.0
		wnode.add_child(est)
	_rastros_encanto(faixa, cor)


const ESTRELA_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
uniform vec3 cor : source_color = vec3(1.0);
uniform float forca = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = TIME * 0.5;
	vec2 q = vec2(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a));
	float raios = 0.004 / (abs(q.x) + 0.012) * smoothstep(1.0, 0.0, abs(q.y)) + 0.004 / (abs(q.y) + 0.012) * smoothstep(1.0, 0.0, abs(q.x));
	vec2 d = vec2(q.x + q.y, q.x - q.y) * 0.7071;
	raios += 0.5 * (0.003 / (abs(d.x) + 0.015) * smoothstep(0.7, 0.0, abs(d.y)) + 0.003 / (abs(d.y) + 0.015) * smoothstep(0.7, 0.0, abs(d.x)));
	float nucleo = exp(-r * r * 18.0) * 2.5;
	float halo = exp(-r * r * 3.0) * 0.35;
	float pulso = 0.8 + 0.2 * sin(TIME * 4.0);
	float v = (nucleo + halo + raios * 0.6) * smoothstep(1.0, 0.55, r) * pulso;
	ALBEDO = mix(cor, vec3(1.0), clamp(nucleo * 0.4, 0.0, 0.8)) * v * forca;
}
"""
static var _estrela_shader: Shader
static var _arco_mesh: ArrayMesh


# transformação de um nó relativa à arma, sem depender de estar na árvore
func _rel_wnode(n: Node) -> Transform3D:
	var t := Transform3D()
	while n != null and n != wnode:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
var _rastros: Node3D


static func _estrela_mat(cor: Color, faixa: int) -> ShaderMaterial:
	if _estrela_shader == null:
		_estrela_shader = Shader.new()
		_estrela_shader.code = ESTRELA_SHADER
	var m := ShaderMaterial.new()
	m.shader = _estrela_shader
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("forca", 0.7 + 0.15 * faixa)
	return m


# fita em arco (~220 graus), mais larga no meio e sumindo nas pontas
static func _arco() -> ArrayMesh:
	if _arco_mesh != null:
		return _arco_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := 40
	for i in n + 1:
		var t := float(i) / n
		var ang := t * deg_to_rad(220.0)
		var alfa := sin(t * PI)
		var lar := 0.006 + 0.02 * alfa
		var dd := Vector3(cos(ang), 0, sin(ang))
		st.set_color(Color(alfa * alfa, alfa * alfa, alfa * alfa))
		st.add_vertex(dd + Vector3(0, lar, 0))
		st.set_color(Color(alfa * alfa, alfa * alfa, alfa * alfa))
		st.add_vertex(dd - Vector3(0, lar, 0))
	_arco_mesh = st.commit()
	return _arco_mesh


# a partir do +10: 2 rastros de luz girando em volta do corpo (3 no +16)
func _rastros_encanto(faixa: int, cor: Color) -> void:
	if _rastros != null:
		_rastros.queue_free()
		_rastros = null
	if faixa < 2:
		return
	_rastros = Node3D.new()
	_rastros.name = "RastrosEncanto"
	_rastros.position = Vector3(0, 1.0, 0)
	add_child(_rastros)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(minf(cor.r * 1.6, 1.0), minf(cor.g * 1.6, 1.0), minf(cor.b * 1.6, 1.0))
	var qtd := 2 if faixa < 4 else 3
	for i in qtd:
		var piv := Node3D.new()
		piv.rotation = Vector3(deg_to_rad(-25.0 + 30.0 * i), deg_to_rad(120.0 * i), deg_to_rad(18.0 - 22.0 * i))
		_rastros.add_child(piv)
		var giro := Node3D.new()
		piv.add_child(giro)
		var mi := MeshInstance3D.new()
		mi.mesh = _arco()
		mi.material_override = mat
		mi.scale = Vector3.ONE * (0.62 + 0.08 * i)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 45.0
		giro.add_child(mi)
		var tw := giro.create_tween().set_loops()
		tw.tween_property(giro, "rotation:y", TAU * (1.0 if i % 2 == 0 else -1.0), 1.6 + 0.5 * i).from(0.0)


# aura de herói: anel de luz dourada aos pés e brilho subindo pelo corpo
func aura_heroi(on: bool) -> void:
	if _aura != null:
		_aura.queue_free()
		_aura = null
	if not on:
		return
	_aura = Node3D.new()
	add_child(_aura)
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.55
	p.emission_ring_inner_radius = 0.4
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 8.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.1
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.12)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.albedo_color = Color(1.0, 0.8, 0.35)
	q.material = qm
	p.mesh = q
	p.visibility_range_end = 60.0
	_aura.add_child(p)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.82, 0.45)
	luz.light_energy = 0.6
	luz.omni_range = 3.0
	luz.position = Vector3(0, 1.0, 0)
	luz.shadow_enabled = false
	luz.distance_fade_enabled = true
	luz.distance_fade_begin = 25.0
	_aura.add_child(luz)
	# duas esferas de luz orbitando (azul e âmbar): marca própria do herói
	var orb := Node3D.new()
	orb.position = Vector3(0, 1.35, 0)
	_aura.add_child(orb)
	var cores := [Color(0.45, 0.7, 1.0), Color(1.0, 0.6, 0.25)]
	for i in 2:
		var e := MeshInstance3D.new()
		var q2 := QuadMesh.new()
		q2.size = Vector2(0.3, 0.3)
		e.mesh = q2
		e.material_override = _estrela_mat(cores[i], 1)
		e.position = Vector3(0.75 if i == 0 else -0.75, 0.15 * i, 0)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.add_child(e)
	var tw := orb.create_tween().set_loops()
	tw.tween_property(orb, "rotation:y", TAU, 3.2).from(0.0)


# V3: aldeão = túnica (formas corretivas + RBF), calça e botas novas; outras armaduras usam a roupa oficial no corpo novo
func _vestir_v3(male: bool, outfit: String, hair_col: Color) -> void:
	var g := "m" if male else "f"
	if outfit == "peasant":
		var tunica := _attach_v3("rp_aldeao_tunica_%s_rbf" % g)
		for m in tunica:
			var co = V3Ctrl.new()
			add_child(co)
			co.configurar(skel, m)
			co.carregar_rbf(DIR_V3 + "rp_aldeao_tunica_%s_rbf.rbf.json" % g)
		_attach_v3("rp_aldeao_calca_m_sem_entrepernas" if male else "rp_aldeao_calca_f")
		_attach_v3("rp_botas_couro_" + g)
	else:
		_attach("outfit_%s_%s" % ["male" if male else "female", outfit])
	# a textura do cabelo V3 é quase preta (fios escuros): a cor escolhida é multiplicada para aparecer
	var hc := Color(hair_col.r, hair_col.g, hair_col.b) * (7.0 if male else 14.0)
	hc.a = 1.0
	if male:
		for m in _attach_v3("ca_curto_01"):
			_tint(m, hc)
	else:
		for m in _attach_v3("ca_tranca_longa"):
			_tint(m, hc)
			m.visibility_range_end = 12.0
			m.visibility_range_end_margin = 1.0
		for m in _attach_v3("ca_tranca_longa_lod1"):
			_tint(m, hc)
			m.visibility_range_begin = 12.0
			m.visibility_range_begin_margin = 1.0


func _attach_v3(file: String) -> Array:
	var out := []
	var src: Node3D = cena(DIR_V3 + file + ".glb").instantiate()
	for m in src.find_children("*", "MeshInstance3D", true, false):
		m.get_parent().remove_child(m)
		m.owner = null
		skel.add_child(m)
		(m as MeshInstance3D).skeleton = NodePath("..")
		out.append(m)
	src.free()
	return out


func _tint(mi: MeshInstance3D, col: Color) -> void:
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m is BaseMaterial3D:
			var d := m.duplicate() as BaseMaterial3D
			d.albedo_color = col
			mi.set_surface_override_material(i, d)


func _attach(file: String, tint := Color(0, 0, 0, 0)) -> void:
	var src: Node3D = cena(DIR + file + ".glb").instantiate()
	for m in src.find_children("*", "MeshInstance3D", true, false):
		m.get_parent().remove_child(m)
		m.owner = null
		skel.add_child(m)
		(m as MeshInstance3D).skeleton = NodePath("..")
		if tint.a > 0.0:
			_tint(m as MeshInstance3D, tint)
	src.free()


# as animações vêm em arquivos sem malha; as trilhas são reapontadas para os ossos do esqueleto
static func _clips(sk: Skeleton3D, own := "") -> AnimationLibrary:
	if _libraries.has(own):
		return _libraries[own]
	var lib := AnimationLibrary.new()
	var hip: float = OWN[own].hip if own != "" else 1.0
	for f in ["anims_a", "anims_b"]:
		var sc: Node = cena(DIR + f + ".glb").instantiate()
		var ap := sc.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for n in ap.get_animation_list():
			var a: Animation = ap.get_animation(n).duplicate(true)
			for t in range(a.get_track_count() - 1, -1, -1):
				var p := a.track_get_path(t)
				var bone := String(p.get_name(p.get_name_count() - 1))
				if sk.find_bone(bone) < 0:
					a.remove_track(t)
					continue
				a.track_set_path(t, NodePath("Armature/Skeleton3D:" + bone))
				if hip != 1.0 and a.track_get_type(t) == Animation.TYPE_POSITION_3D:
					for k in a.track_get_key_count(t):
						a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Vector3) * hip)
			if n in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Dance", "Idle_Talking", "Sitting_Idle", "Idle_FoldArms", "Idle_Shield", "Spell_Simple_Idle"]:
				a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(n, a)
		sc.free()
	_libraries[own] = lib
	return lib


# ponto de pegada numa mão: eixo +Z sai pelo lado do polegar (para onde aponta a lâmina), +Y volta para o pulso
func _hand_grip(side: String) -> Node3D:
	var hand := skel.find_bone("hand_" + side)
	var mid := skel.find_bone("middle_01_" + side)
	var idx := skel.find_bone("index_01_" + side)
	var pinky := skel.find_bone("pinky_01_" + side)
	if hand < 0 or mid < 0 or idx < 0 or pinky < 0:
		return null
	var gh := skel.get_bone_global_rest(hand)
	var fing := (skel.get_bone_global_rest(mid).origin - gh.origin).normalized()
	var th := skel.get_bone_global_rest(idx).origin - skel.get_bone_global_rest(pinky).origin
	th = (th - fing * th.dot(fing)).normalized()
	var frame := Basis(Vector3(-fing).cross(th).normalized(), -fing, th)
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_" + side
	skel.add_child(att)
	var grip := Node3D.new()
	grip.transform = Transform3D(gh.basis.inverse() * frame, skel.get_bone_rest(mid).origin * 0.55)
	att.add_child(grip)
	# desfaz a escala dos ossos do braço e da mão, para o tamanho da arma valer em metros
	grip.scale = Vector3.ONE / maxf(skel.get_bone_global_pose(hand).basis.get_scale().x, 0.01)
	return grip


# modelo da arma com o comprimento dado; o ponto a "at" metros da ponta do cabo fica na origem e a lâmina segue +Z
# (at < 0: segura pelo meio, como o arco)
static func _place(file: String, length: float, at: float) -> Node3D:
	var w: Node3D = cena(DIR + file + ".glb").instantiate()
	var bb := AABB()
	var first := true
	for m in w.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var a: AABB = mi.transform * mi.get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	var axis := bb.get_longest_axis_index()
	var k := length / bb.size[axis]
	var dir := Vector3.ZERO
	dir[axis] = 1.0
	# ponta = lado mais distante da origem do modelo; cabo fica na palma
	var far_pos: float = bb.position[axis] + bb.size[axis]
	var far_neg: float = bb.position[axis]
	if absf(far_neg) > absf(far_pos):
		dir = -dir
	var handle: float = (far_neg if dir[axis] > 0.0 else far_pos)
	var off := bb.get_center()
	off[axis] = handle + dir[axis] * ((length * 0.5) if at < 0.0 else at) / k
	w.transform = Transform3D(Basis(Quaternion(dir, Vector3(0, 0, 1))).scaled(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -off)
	return w


# arma já encaixada pela ferramenta encaixe_armas.mjs: origem no ponto da mão, lâmina em +Z, medida em metros
const ARMAS := "res://assets/armas/"


static func _model(item_id: String, kind: String, file: String, length: float, at: float, s: float) -> Node3D:
	for f in [item_id, kind + "_ng"]:
		if ResourceLoader.exists(ARMAS + f + ".glb"):
			var w: Node3D = cena(ARMAS + f + ".glb").instantiate()
			var holder := Node3D.new()
			holder.add_child(w)
			w.scale = Vector3.ONE * s
			return holder
	return _place(file, length, at)


func _weapon(kind: String, s: float, has_shield: bool, item_id := "", shield_id := "") -> void:
	var g: Dictionary = GRIP[kind]
	var side := str(g.get("hand", "r"))
	fist = load("res://scripts/punho.gd").new()
	skel.add_child(fist)
	fist_hands = [side]
	if float(g.get("two", 0.0)) > 0.0 or g.get("dual", false) or has_shield:
		fist_hands = ["r", "l"]
	var grip := _hand_grip(side)
	if grip == null:
		return
	var at := float(g.at) * s if float(g.at) >= 0.0 else -1.0
	wnode = _model(item_id, kind, str(g.file), float(g.len) * s, at, s)
	if kind == "arco":
		wnode.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO) * wnode.transform
	grip.add_child(wnode)
	grip_node = grip
	var two := float(g.get("two", 0.0))
	if two > 0.0:
		# postura de guarda: arma à frente do corpo, na diagonal, com as duas mãos no cabo
		var k := height_m / 1.8
		var up := Vector3(0.22, 0.86, 0.46).normalized()
		guard = Node3D.new()
		var gx := Vector3(1, 0, 0).cross(up).normalized()
		guard.transform = Transform3D(Basis(up.cross(gx).normalized(), gx, up), Vector3(-0.04, 0.98, 0.3) * k)
		add_child(guard)
		var hand_r := Node3D.new()
		guard.add_child(hand_r)
		var hand_l := Node3D.new()
		hand_l.position = Vector3(0, 0, -(float(g.at) - two) * s)
		guard.add_child(hand_l)
		ik_r = _arm_ik("r", hand_r, Vector3(-0.6, 0.45, -0.5) * k)
		ik = _arm_ik("l", hand_l, Vector3(0.6, 0.45, -0.5) * k)
	if g.get("dual", false):
		var g2 := _hand_grip("l")
		if g2 != null:
			offhand = _model(item_id, kind, str(g.file), float(g.len) * s, at, s)
			g2.add_child(offhand)
			offhand.visible = false
	if has_shield and two <= 0.0 and side == "r":
		_make_shield(s, shield_id)
	_make_sheath(bool(g.get("back", false)), kind in ["adaga", "punhal"])
	armed = false
	set_battle(true)


func _arm_ik(side: String, target: Node3D, pole_pos: Vector3) -> SkeletonModifier3D:
	var pole := Node3D.new()
	pole.position = pole_pos
	add_child(pole)
	var t := TwoBoneIK3D.new()
	t.set_setting_count(1)
	t.set_root_bone_name(0, "upperarm_" + side)
	t.set_middle_bone_name(0, "lowerarm_" + side)
	t.set_end_bone_name(0, "hand_" + side)
	skel.add_child(t)
	t.set_target_node(0, t.get_path_to(target))
	t.set_pole_node(0, t.get_path_to(pole))
	t.active = false
	return t


# arma de duas mãos: na guarda (parado ou andando) ou na mão direita (golpeando)
func _set_guard(on: bool) -> void:
	if guard == null or on == guard_on:
		return
	guard_on = on
	wnode.get_parent().remove_child(wnode)
	(guard if on else grip_node).add_child(wnode)
	ik.active = on
	ik_r.active = on


# escudo no antebraço esquerdo em combate; nas costas fora dele
func _make_shield(s: float, shield_id := "") -> void:
	shield_arm = _hand_grip("l")
	if shield_arm == null:
		return
	var sfile := DIR + "w_shield_heater.glb"
	for f in [shield_id, shield_id.get_slice("_", 0) + "_ng"]:
		if f != "" and ResourceLoader.exists(ARMAS + f + ".glb"):
			sfile = ARMAS + f + ".glb"
			break
	shield = cena(sfile).instantiate()
	var bb := AABB()
	var first := true
	for m in shield.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var a: AABB = mi.transform * mi.get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	var tall := bb.get_longest_axis_index()
	var thin := bb.get_shortest_axis_index()
	var k := 0.72 * s / bb.size[tall]
	var basis := Basis()
	var ax := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	# altura do escudo ao longo do antebraço (+Y do suporte), frente do escudo para fora (+X)
	basis = Basis(ax[3 - tall - thin], ax[tall], ax[thin]).inverse()
	basis = Basis(Vector3.BACK, Vector3.UP, Vector3.RIGHT) * basis
	shield.transform = Transform3D(basis.scaled(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -bb.get_center())
	shield.position += Vector3(0.07, 0.16, 0) * s
	shield_back = Node3D.new()
	var bone := skel.find_bone("spine_03")
	if bone >= 0:
		var att := BoneAttachment3D.new()
		att.bone_name = "spine_03"
		skel.add_child(att)
		var gb := skel.get_bone_global_rest(bone)
		shield_back.transform = Transform3D(gb.basis.inverse() * Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)), gb.affine_inverse() * (gb.origin + Vector3(0, -0.05, -0.2) * s))
		att.add_child(shield_back)
	shield_back.add_child(shield)


# ponto de descanso da arma fora de combate: nas costas (cabo no ombro direito) ou na cintura (adaga)
func _make_sheath(back: bool, small: bool) -> void:
	var bone := skel.find_bone("spine_03") if back else skel.find_bone("pelvis")
	if bone < 0:
		return
	var gb := skel.get_bone_global_rest(bone)
	var att := BoneAttachment3D.new()
	att.bone_name = skel.get_bone_name(bone)
	skel.add_child(att)
	var k := height_m / 1.8
	# no espaço do modelo: +Y para cima, +Z para a frente; a lâmina (eixo +Z do suporte) aponta para baixo
	var blade := Vector3(-0.42, -0.9, 0.0).normalized()  # costas: cruzando na diagonal
	var out := Vector3(0, 0, -1)
	var handle := gb.origin + Vector3(0.2, 0.2, -0.17) * k
	if not back:  # cintura, lado esquerdo, inclinada para trás para não arrastar no chão
		blade = (Vector3(0.1, -0.95, -0.3) if small else Vector3(0.15, -0.7, -0.7)).normalized()
		out = Vector3(1, 0, 0)
		handle = gb.origin + Vector3(0.2, 0.04, 0.05) * k
	var x := out.cross(blade).normalized()
	var y := blade.cross(x).normalized()
	sheath = Node3D.new()
	# a arma entra pelo mesmo ponto onde a mão segura, então recua o cabo para fora da bainha
	sheath.transform = Transform3D(gb.basis.inverse() * Basis(x, y, blade), gb.affine_inverse() * handle)
	att.add_child(sheath)


# em combate a arma vai para a mão; fora dele, para as costas ou a cintura
func set_battle(on: bool) -> void:
	if on == armed or wnode == null or sheath == null:
		armed = on
		return
	armed = on
	if fist != null:
		for h in ["r", "l"]:
			fist.amount[h] = 1.0 if on and h in fist_hands else 0.0
	wnode.get_parent().remove_child(wnode)
	(grip_node if on else sheath).add_child(wnode)
	if guard != null:
		guard_on = false
		if on:
			_set_guard(true)
		else:
			ik.active = false
			ik_r.active = false
	if offhand != null:
		offhand.visible = on
	if shield != null and shield_arm != null and shield_back != null:
		shield.get_parent().remove_child(shield)
		var keep := shield.transform
		(shield_arm if on else shield_back).add_child(shield)
		shield.transform = keep


func play(n: String, speed := 1.0) -> void:
	if guard != null and armed and not guard_on and not is_busy():
		_set_guard(true)
	if n == "Idle" and armed and magic_idle and anim.has_animation("Spell_Simple_Idle"):
		n = "Spell_Simple_Idle"
	if not anim.has_animation(n):
		return
	if current == n:
		anim.speed_scale = speed
		return
	current = n
	anim.play(n, -1, 1.0)
	anim.speed_scale = speed


func action(n: String) -> float:
	if not anim.has_animation(n):
		return 0.0
	current = n
	if guard != null and armed:
		_set_guard(false)
	anim.speed_scale = 1.0
	anim.play(n)
	anim.seek(0.0)
	var len := anim.get_animation(n).length
	busy_until = Time.get_ticks_msec() * 0.001 + len * 0.9
	return len


func is_busy() -> bool:
	return Time.get_ticks_msec() * 0.001 < busy_until


func set_tag(text: String, color := Color(1, 0.92, 0.7)) -> void:
	if not tag:
		tag = Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0, height_m + 0.25, 0)
		tag.pixel_size = 0.003
		tag.font_size = 64
		tag.outline_size = 14
		tag.outline_modulate = Color(0, 0, 0, 0.85)
		tag.no_depth_test = false
		add_child(tag)
	tag.text = text
	tag.modulate = color


# pés no chão: o pé que está apoiado (o mais baixo na animação) encosta no terreno embaixo dele.
# Corrige o corpo flutuando em descidas e o pé afundando em subidas; suaviza para não tremer.
func _process(dt: float) -> void:
	if world_ref == null or skel == null or body_node == null or not visible:
		return
	if feet.is_empty():
		for side in ["l", "r"]:
			var b := skel.find_bone("foot_" + side)
			if b < 0:
				feet = [-1]
				return
			feet.append(b)
		body_base_y = body_node.position.y
	if feet[0] < 0:
		return
	var root_y := global_position.y
	var xf := skel.global_transform
	if ankle < 0.0:
		ankle = maxf(((xf * skel.get_bone_global_rest(feet[0]).origin).y - root_y) - foot_off, 0.0)
	# pés apoiados = os que estão perto do mais baixo na animação (parado: os dois; andando: o de apoio).
	# Em encosta o corpo sobe até o pé apoiado mais "enterrado" encostar no chão.
	var locs := []
	var best := 1e9
	for b in feet:
		var p: Vector3 = xf * skel.get_bone_global_pose(b).origin
		locs.append(p)
		best = minf(best, p.y - root_y)
	var gap := 1e9
	for p in locs:
		if (p as Vector3).y - root_y <= best + 0.06:
			gap = minf(gap, ((p as Vector3).y - ankle) - float(world_ref.floor_y(p.x, p.z, root_y + 0.5)))
	var want := clampf(foot_off - gap, -0.35, 0.25)
	foot_off = lerpf(foot_off, want, clampf(dt * 10.0, 0.0, 1.0))
	body_node.position.y = body_base_y + foot_off / maxf(scale.y, 0.01)


# roupa de frio: capa de pele nas costas, gola felpuda e capuz (lugares gelados)
func winter(seed: int) -> void:
	var h := height_m
	var k := h / 1.8
	var furs := [Color(0.45, 0.32, 0.2), Color(0.32, 0.24, 0.18), Color(0.62, 0.58, 0.52), Color(0.38, 0.12, 0.1), Color(0.2, 0.26, 0.38)]
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = furs[absi(seed) % furs.size()]
	cloth.roughness = 1.0
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.86, 0.82, 0.74) if seed % 2 == 0 else Color(0.5, 0.4, 0.3)
	fur.roughness = 1.0
	var bm := BoxMesh.new()
	bm.size = Vector3(0.46 * k, 0.62 * h, 0.04 * k)
	bm.material = cloth
	var cape := MeshInstance3D.new()
	cape.mesh = bm
	cape.position = Vector3(0, 0.5 * h, -0.16 * k)
	cape.rotation.x = 0.1
	add_child(cape)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.08 * k
	tm.outer_radius = 0.16 * k
	tm.rings = 12
	tm.ring_segments = 6
	tm.material = fur
	var collar := MeshInstance3D.new()
	collar.mesh = tm
	collar.position = Vector3(0, 0.815 * h, -0.02 * k)
	collar.scale = Vector3(1.0, 0.55, 0.9)
	add_child(collar)
	var sm := SphereMesh.new()
	sm.radius = 0.12 * k
	sm.height = 0.24 * k
	sm.is_hemisphere = true
	sm.radial_segments = 12
	sm.rings = 6
	sm.material = cloth
	var hood := MeshInstance3D.new()
	hood.mesh = sm
	hood.position = Vector3(0, 0.915 * h, -0.025 * k)
	hood.scale = Vector3(1.0, 1.1, 1.15)
	add_child(hood)
