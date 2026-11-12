extends Node3D
# Personagem: corpo-base + roupa + cabelo presos ao mesmo esqueleto, com as animações do jogo.

const DIR := "res://assets/chars/"
static var _library: AnimationLibrary

var skel: Skeleton3D
var anim: AnimationPlayer
var current := ""
var busy_until := 0.0
var tag: Label3D


static func create(gender := "m", with_weapon := true) -> Node3D:
	var c: Node3D = load("res://scripts/character.gd").new()
	c._setup(gender, with_weapon)
	return c


func _setup(gender: String, with_weapon: bool) -> void:
	var male := gender != "f"
	var body: Node3D = (load(DIR + ("body_male" if male else "body_female") + ".glb") as PackedScene).instantiate()
	body.name = "Corpo"
	add_child(body)
	skel = body.find_child("Skeleton3D", true, false) as Skeleton3D
	_attach("outfit_male_knight" if male else "outfit_female_ranger")
	_attach("hair_simpleparted" if male else "hair_long", Color(0.24, 0.15, 0.08) if male else Color(0.5, 0.28, 0.12))
	var brows := skel.get_node_or_null("Eyebrows") as MeshInstance3D
	if brows:
		_tint(brows, Color(0.2, 0.13, 0.07))
	for m in skel.get_children():
		if m is MeshInstance3D:
			# o corpo se mexe muito além da caixa de repouso; amplia para não sumir na borda da tela
			(m as MeshInstance3D).extra_cull_margin = 1.5
	anim = AnimationPlayer.new()
	body.add_child(anim)
	anim.add_animation_library("", _clips(skel))
	anim.playback_default_blend_time = 0.18
	if with_weapon:
		_weapon("w_sword", 1.0)
	play("Idle")


# liga as malhas de outro arquivo (roupa, cabelo) ao esqueleto do corpo, pelo nome dos ossos
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
static func _clips(sk: Skeleton3D) -> AnimationLibrary:
	if _library:
		return _library
	_library = AnimationLibrary.new()
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
				else:
					a.track_set_path(t, NodePath("Armature/Skeleton3D:" + bone))
			if n in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Dance", "Idle_Talking", "Sitting_Idle", "Idle_FoldArms", "Idle_Shield", "Spell_Simple_Idle"]:
				a.loop_mode = Animation.LOOP_LINEAR
			_library.add_animation(n, a)
		sc.free()
	return _library


func _weapon(file: String, length: float) -> void:
	var hand := skel.find_bone("hand_r")
	var mid := skel.find_bone("middle_01_r")
	var idx := skel.find_bone("index_01_r")
	var pinky := skel.find_bone("pinky_01_r")
	if hand < 0 or mid < 0 or idx < 0 or pinky < 0:
		return
	var gh := skel.get_bone_global_rest(hand)
	var fing := (skel.get_bone_global_rest(mid).origin - gh.origin).normalized()
	var th := skel.get_bone_global_rest(idx).origin - skel.get_bone_global_rest(pinky).origin
	th = (th - fing * th.dot(fing)).normalized()
	# referencial da mão: dedos = -Y, lado do polegar = +Z; a lâmina sai pelo lado do polegar
	var frame := Basis(Vector3(-fing).cross(th).normalized(), -fing, th)
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_r"
	skel.add_child(att)
	var grip := Node3D.new()
	grip.transform = Transform3D(gh.basis.inverse() * frame, skel.get_bone_rest(mid).origin * 0.55)
	att.add_child(grip)
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
	var q := Quaternion(dir, Vector3(0, 0, 1))
	var c := bb.get_center()
	var off := Vector3(c.x, c.y, c.z)
	off[axis] = handle + dir[axis] * 0.14 / k
	w.transform = Transform3D(Basis(q).scaled(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -off)
	grip.add_child(w)


func play(n: String, speed := 1.0) -> void:
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
		tag.position = Vector3(0, 2.05, 0)
		tag.pixel_size = 0.003
		tag.font_size = 64
		tag.outline_size = 14
		tag.outline_modulate = Color(0, 0, 0, 0.85)
		tag.no_depth_test = false
		add_child(tag)
	tag.text = text
	tag.modulate = color
