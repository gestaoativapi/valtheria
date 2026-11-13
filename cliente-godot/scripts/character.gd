extends Node3D
# Personagem: corpo-base + roupa + cabelo presos ao mesmo esqueleto, com as animações do jogo.

const DIR := "res://assets/chars/"
static var _libraries := {}
static var world_ref: Node  # mundo, para os pés pisarem no chão (altura do terreno embaixo de cada pé)

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
	var body: Node3D = (load(DIR + file + ".glb") as PackedScene).instantiate()
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
	play("Idle")


func _tint(mi: MeshInstance3D, col: Color) -> void:
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m is BaseMaterial3D:
			var d := m.duplicate() as BaseMaterial3D
			d.albedo_color = col
			mi.set_surface_override_material(i, d)


func _attach(file: String, tint := Color(0, 0, 0, 0)) -> void:
	var src: Node3D = (load(DIR + file + ".glb") as PackedScene).instantiate()
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
		var sc: Node = (load(DIR + f + ".glb") as PackedScene).instantiate()
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
	var w: Node3D = (load(DIR + file + ".glb") as PackedScene).instantiate()
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
			var w: Node3D = (load(ARMAS + f + ".glb") as PackedScene).instantiate()
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
	shield = (load(sfile) as PackedScene).instantiate()
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
	var best := 1e9
	var gap := 0.0
	for b in feet:
		var p: Vector3 = xf * skel.get_bone_global_pose(b).origin
		var local := p.y - root_y  # altura do pé na animação
		if local < best:
			best = local
			gap = (p.y - ankle) - float(world_ref.height(p.x, p.z))
	var want := clampf(foot_off - gap, -0.35, 0.25)
	foot_off = lerpf(foot_off, want, clampf(dt * 10.0, 0.0, 1.0))
	body_node.position.y = body_base_y + foot_off / maxf(scale.y, 0.01)
