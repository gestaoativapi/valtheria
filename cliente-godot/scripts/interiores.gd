extends Node3D
# Interiores: ao chegar na porta de um prédio (taverna, ferraria, igreja, casa, loja, palácio, arena) aparece
# "E — Entrar". Dentro há móveis, luz própria, moradores fazendo o seu trabalho e uma planta da sala no canto
# da tela, com a posição de cada pessoa e a saída.

const Character = preload("res://scripts/character.gd")
const FX = preload("res://scripts/fx.gd")
const BASE := Vector3(-2400.0, 600.0, -2400.0)  # longe do mapa: a sala fica fora do mundo

var main: Node3D
var inside := {}  # sala atual: {"kind", "name", "w", "d", "items", "npcs", "exit", "door"}
var room: Node3D
var near_door := {}
var check_t := 0.0
var portal_cd := 0.0
var plan: Control
var hint: Label
var fade: ColorRect
var blockers: Array = []  # [Vector2 local, raio]
var people: Array = []  # [{"node", "name", "lines"}]

const LINES := {
	"taverna": ["Mais uma rodada para a mesa do canto!", "Ouvi dizer que a Arena dos Heróis abre torneio na lua cheia.", "O ensopado de hoje é de javali.", "Cuidado com as estradas à noite.", "Senta, viajante, que a lareira está acesa."],
	"forja": ["O aço quer fogo e paciência.", "Traga minério que eu faço o resto.", "Essa lâmina ainda vai ver muita batalha.", "Martelo firme, mão leve."],
	"igreja": ["Que a Aurora guie seus passos.", "O Pacto do Véu nasceu de uma promessa.", "Aqui todos os povos rezam juntos.", "Acenda uma vela pelos que partiram."],
	"casa": ["Fique à vontade, a casa é simples.", "As crianças não param quietas.", "O pão acabou de sair do forno.", "Meu avô lutou na Guerra das Brumas."],
	"loja": ["Peças únicas, uma de cada. Olhe com calma.", "Itens lendários não voltam ao estoque tão cedo.", "Só aceitamos aurum.", "Essa espada pertenceu a um herói da arena."],
	"palacio": ["Sua Majestade recebe os heróis no salão do trono.", "Silêncio no salão real.", "Os cavaleiros da guarda real são os mais fortes do reino.", "O conselho se reúne ao anoitecer."],
	"arena": ["Os títulos de herói são disputados nos torneios.", "Inscrições nos dias de evento, aqui no salão.", "O campeão da última temporada nunca perdeu um duelo.", "PvP só dentro da arena ou fora da cidade."],
}


func setup(m: Node3D) -> void:
	main = m
	name = "Interiores"
	plan = Planta.new()
	plan.visible = false
	plan.anchor_left = 1.0
	plan.anchor_right = 1.0
	plan.offset_left = -250
	plan.offset_right = -14
	plan.offset_top = 120
	plan.offset_bottom = 356
	main.ui.add_child(plan)
	hint = Label.new()
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -220
	hint.offset_right = 220
	hint.offset_top = -210
	hint.offset_bottom = -180
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("outline_size", 6)
	hint.visible = false
	main.ui.add_child(hint)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.ui.add_child(fade)


func _process(dt: float) -> void:
	if not main.playing:
		hint.visible = false
		plan.visible = false
		return
	portal_cd -= dt
	check_t -= dt
	if check_t > 0.0:
		return
	check_t = 0.2
	var p: Vector3 = main.player.position
	if not inside.is_empty():
		var lp := p - BASE
		var ex: Vector2 = inside.exit
		var close := Vector2(lp.x, lp.z).distance_to(ex) < 1.6
		hint.text = "E — Sair para a rua" if close else ""
		hint.visible = close
		plan.player = Vector2(lp.x, lp.z)
		plan.facing = main.facing
		plan.queue_redraw()
		return
	near_door = {}
	var best := 2.8
	for d in main.world.doors:
		var dp: Vector3 = d.pos
		var dd := Vector2(dp.x - p.x, dp.z - p.z).length()
		if d.kind == "portal":
			if dd < 1.8 and portal_cd <= 0.0 and absf(dp.y - p.y) < 3.0:
				portal_cd = 4.0
				_portal(d)
				return
			continue
		if dd < best:
			best = dd
			near_door = d
	hint.visible = not near_door.is_empty()
	if hint.visible:
		hint.text = "E — Entrar: %s" % near_door.name


func key_e() -> bool:
	if not inside.is_empty():
		var lp: Vector3 = main.player.position - BASE
		if Vector2(lp.x, lp.z).distance_to(inside.exit) < 1.8:
			leave()
			return true
		return false
	if not near_door.is_empty():
		enter(near_door)
		return true
	return false


func _portal(d: Dictionary) -> void:
	await _fade(1.0)
	var to: Vector3 = d.to
	main._place_player(to)
	main.fly_y = main.player.position.y
	for i in 6:
		main.world.stream(main.player.position, 8)
	main.ui.say(d.name)
	await _fade(0.0)


func _fade(a: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, 0.35)
	await tw.finished


# GM: abre um interior de exemplo de qualquer tipo
func enter_kind(kind: String) -> void:
	var p: Vector3 = main.player.position
	enter({"kind": kind, "name": kind.capitalize(), "pos": p, "yaw": main.facing, "town": ""})


func enter(d: Dictionary) -> void:
	await _fade(1.0)
	inside = _layout(str(d.kind), str(d.name))
	inside.door = d
	_build()
	var ex: Vector2 = inside.exit
	main.has_target = false
	main.marker.visible = false
	main.player.position = BASE + Vector3(ex.x, 0, ex.y - 1.6)
	main.facing = PI
	main.player.rotation.y = PI
	main.yaw = 0.0
	main.pitch = -0.22
	main.dist = 5.0
	plan.data = inside
	plan.visible = true
	if main.player.tag:
		main.player.tag.visible = false
	hint.visible = false
	main.ui.say(str(d.name))
	await _fade(0.0)


func leave() -> void:
	await _fade(1.0)
	var d: Dictionary = inside.door
	inside = {}
	if room:
		room.queue_free()
		room = null
	people = []
	blockers = []
	plan.visible = false
	if main.player.tag:
		main.player.tag.visible = true
	var dp: Vector3 = d.pos
	var yaw: float = d.yaw
	main._place_player(dp + Vector3(sin(yaw), 0, cos(yaw)) * 1.2)
	main.facing = yaw
	main.player.rotation.y = yaw
	main.yaw = yaw + PI
	main.dist = 7.5
	for i in 4:
		main.world.stream(main.player.position, 8)
	await _fade(0.0)


# fala de alguém da sala (clique)
func talk_near(origin: Vector3, dir: Vector3) -> bool:
	for e in people:
		var c: Node3D = e.node
		var pc := c.global_position + Vector3(0, 1.0, 0)
		var t := (pc - origin).dot(dir)
		if t > 0.0 and (origin + dir * t).distance_to(pc) < 0.7:
			var lines: Array = e.lines
			var l: String = lines[randi() % lines.size()]
			main.ui.chat_line(str(e.name), l, "npc")
			main.npcs.say({"node": c}, l)
			return true
	return false


# ---------- chão, movimento e câmera dentro da sala ----------
func ground() -> float:
	return BASE.y


func clamp_move(np: Vector3, from: Vector3) -> Vector3:
	var hw: float = float(inside.w) * 0.5 - 0.45
	var hd: float = float(inside.d) * 0.5 - 0.45
	var l := np - BASE
	l.x = clampf(l.x, -hw, hw)
	l.z = clampf(l.z, -hd, hd)
	for b in blockers:
		var c: Vector2 = b[0]
		var r: float = b[1] + 0.35
		var v := Vector2(l.x, l.z) - c
		if v.length() < r:
			v = v.normalized() * r if v.length() > 0.001 else Vector2(r, 0)
			l.x = c.x + v.x
			l.z = c.y + v.y
	return BASE + Vector3(l.x, 0, l.z)


func clamp_cam(p: Vector3) -> Vector3:
	var hw: float = float(inside.w) * 0.5 - 0.3
	var hd: float = float(inside.d) * 0.5 - 0.3
	var l := p - BASE
	return BASE + Vector3(clampf(l.x, -hw, hw), clampf(l.y, 0.4, float(inside.h) - 0.3), clampf(l.z, -hd, hd))


# ---------- planta de cada tipo de sala ----------
func _layout(kind: String, title: String) -> Dictionary:
	var L := {"kind": kind, "name": title, "w": 14.0, "d": 12.0, "h": 4.2, "items": [], "npcs": [], "exit": Vector2(0, 5.4), "floor": Color(0.42, 0.3, 0.2), "wall": Color(0.72, 0.64, 0.52)}
	var it: Array = L.items
	var np: Array = L.npcs
	match kind:
		"taverna":
			L.w = 18.0
			L.d = 14.0
			L.exit = Vector2(0, 6.4)
			it.append(["balcao", -6.0, -4.0, 6.0, 1.0, "Balcão"])
			it.append(["prateleira", -6.0, -6.6, 6.0, 0.5, ""])
			it.append(["lareira", 7.0, -6.4, 3.0, 0.8, "Lareira"])
			for k in 3:
				it.append(["mesa", -2.0 + k * 4.0, 1.0, 1.6, 1.6, ""])
			it.append(["mesa", 5.5, -2.0, 1.6, 1.6, ""])
			it.append(["barril", -8.2, -1.0, 0.8, 0.8, ""])
			it.append(["barril", -8.2, 0.2, 0.8, 0.8, ""])
			it.append(["escada", 7.6, 4.0, 1.6, 3.0, "Quartos"])
			np.append(["Estalajadeira", -6.0, -5.0, 0.0, "Interact", "taverna"])
			np.append(["Bardo", 6.2, -4.6, PI * 0.8, "Dance", "taverna"])
			for k in 3:
				np.append(["Freguês", -2.0 + k * 4.0 - 1.0, 1.0, PI * 0.5, "Sitting_Idle", "taverna"])
				np.append(["Freguesa", -2.0 + k * 4.0 + 1.0, 1.0, -PI * 0.5, "Sitting_Idle", "taverna"])
			np.append(["Viajante", 4.5, -2.0, PI * 0.5, "Consume", "taverna"])
		"forja":
			L.w = 14.0
			L.d = 12.0
			L.floor = Color(0.3, 0.28, 0.26)
			L.wall = Color(0.5, 0.46, 0.42)
			it.append(["fornalha", -4.5, -4.6, 3.0, 2.0, "Fornalha"])
			it.append(["bigorna", -1.0, -2.0, 1.0, 0.6, "Bigorna"])
			it.append(["mesa", 4.0, -4.6, 3.0, 1.2, "Bancada"])
			it.append(["armas", 6.4, 0.0, 0.5, 5.0, "Armas"])
			it.append(["barril", -6.0, 2.0, 0.8, 0.8, ""])
			np.append(["Ferreiro", -1.0, -3.0, 0.0, "TreeChopping", "forja"])
			np.append(["Aprendiz", 4.0, -3.6, PI, "Interact", "forja"])
			np.append(["Cliente", 1.5, 1.0, -PI * 0.6, "Idle_FoldArms", "forja"])
		"igreja":
			L.w = 14.0
			L.d = 26.0
			L.h = 9.0
			L.exit = Vector2(0, 12.4)
			L.floor = Color(0.62, 0.6, 0.56)
			L.wall = Color(0.78, 0.76, 0.72)
			it.append(["altar", 0.0, -11.0, 4.0, 1.4, "Altar"])
			for k in 6:
				it.append(["banco", -3.2, -6.0 + k * 3.0, 4.0, 0.7, ""])
				it.append(["banco", 3.2, -6.0 + k * 3.0, 4.0, 0.7, ""])
			for s in [-1.0, 1.0]:
				for k in 4:
					it.append(["coluna", s * 5.6, -9.0 + k * 6.0, 0.8, 0.8, ""])
			np.append(["Sacerdotisa", 0.0, -9.6, PI, "Idle", "igreja"])
			np.append(["Fiel", -3.0, -3.0, PI, "Sitting_Idle", "igreja"])
			np.append(["Fiel", 3.4, 0.0, PI, "Sitting_Idle", "igreja"])
			np.append(["Peregrino", 2.0, -9.0, 0.0, "Yes", "igreja"])
		"casa":
			L.w = 11.0
			L.d = 9.0
			L.exit = Vector2(0, 4.2)
			it.append(["cama", -3.6, -3.0, 2.0, 2.4, "Cama"])
			it.append(["mesa", 1.4, -0.8, 1.8, 1.2, "Mesa"])
			it.append(["lareira", 3.8, -3.8, 2.2, 0.8, "Fogão"])
			it.append(["armario", -4.8, 1.8, 0.6, 2.0, ""])
			np.append(["Dona da casa", 3.4, -2.6, 0.0, "Interact", "casa"])
			np.append(["Morador", 1.4, 0.2, PI, "Sitting_Idle", "casa"])
			np.append(["Criança", -1.6, 1.4, 0.0, "Dance", "casa"])
		"loja":
			L.w = 15.0
			L.d = 12.0
			L.wall = Color(0.32, 0.3, 0.42)
			L.floor = Color(0.24, 0.2, 0.18)
			it.append(["balcao", 0.0, -3.4, 7.0, 1.0, "Balcão"])
			for k in 4:
				it.append(["vitrine", -5.6 + k * 3.7, 3.0, 1.6, 1.0, "Vitrine"])
			it.append(["prateleira", 0.0, -5.6, 12.0, 0.5, ""])
			np.append(["Mercador de Lendários", 0.0, -4.4, 0.0, "Idle_FoldArms", "loja"])
			np.append(["Guarda Real", -6.6, -4.6, PI * 0.25, "Idle_Shield", "loja"])
			np.append(["Cliente", 2.0, 1.6, PI, "Idle_Talking", "loja"])
		"palacio":
			L.w = 22.0
			L.d = 30.0
			L.h = 11.0
			L.exit = Vector2(0, 14.4)
			L.floor = Color(0.7, 0.66, 0.6)
			L.wall = Color(0.86, 0.84, 0.8)
			it.append(["trono", 0.0, -13.0, 3.0, 2.0, "Trono"])
			it.append(["tapete", 0.0, 0.0, 3.0, 24.0, ""])
			for s in [-1.0, 1.0]:
				for k in 5:
					it.append(["coluna", s * 7.0, -10.0 + k * 5.5, 1.0, 1.0, ""])
			np.append(["Rei Aldemar", 0.0, -12.6, 0.0, "Sitting_Idle", "palacio"])
			np.append(["Conselheira", -2.4, -11.0, 0.4, "Idle_Talking", "palacio"])
			for s in [-1.0, 1.0]:
				for k in 3:
					np.append(["Cavaleiro Real", s * 4.2, -8.0 + k * 7.0, -s * PI * 0.5, "Idle_Shield", "palacio"])
		"arena":
			L.w = 16.0
			L.d = 12.0
			L.floor = Color(0.5, 0.42, 0.3)
			it.append(["balcao", 0.0, -3.6, 6.0, 1.0, "Inscrições"])
			it.append(["mural", -7.6, 0.0, 0.3, 6.0, "Ranking de Heróis"])
			it.append(["armas", 7.6, 0.0, 0.5, 6.0, "Armas de treino"])
			np.append(["Mestre da Arena", 0.0, -4.6, 0.0, "Idle_FoldArms", "arena"])
			np.append(["Campeã da Arena", -5.6, 1.0, PI * 0.5, "Idle_Shield", "arena"])
			np.append(["Gladiador", 4.0, 2.0, -PI * 0.6, "Idle_Talking", "arena"])
			np.append(["Gladiador", 5.4, 1.0, PI * 0.8, "Idle_Talking", "arena"])
	return L


func _box(parent: Node3D, mat: Material, pos: Vector3, size: Vector3) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)


func _mat(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _build() -> void:
	room = Node3D.new()
	room.position = BASE
	add_child(room)
	blockers = []
	people = []
	var W: float = inside.w
	var D: float = inside.d
	var H: float = inside.h
	var floor_m := _mat(inside.floor)
	floor_m.albedo_texture = load("res://assets/world/t_dirt.webp") if inside.kind in ["forja", "arena"] else null
	var wall_m := _mat(inside.wall)
	var wood := _mat(Color(0.36, 0.24, 0.14))
	var dark := _mat(Color(0.2, 0.14, 0.09))
	_box(room, floor_m, Vector3(0, -0.1, 0), Vector3(W, 0.2, D))
	_box(room, wall_m, Vector3(0, H + 0.1, 0), Vector3(W, 0.2, D))
	_box(room, wall_m, Vector3(-W * 0.5 - 0.1, H * 0.5, 0), Vector3(0.2, H, D))
	_box(room, wall_m, Vector3(W * 0.5 + 0.1, H * 0.5, 0), Vector3(0.2, H, D))
	_box(room, wall_m, Vector3(0, H * 0.5, -D * 0.5 - 0.1), Vector3(W, H, 0.2))
	var ex: Vector2 = inside.exit
	_box(room, wall_m, Vector3(-W * 0.25 - 0.8, H * 0.5, D * 0.5 + 0.1), Vector3(W * 0.5 - 1.6, H, 0.2))
	_box(room, wall_m, Vector3(W * 0.25 + 0.8, H * 0.5, D * 0.5 + 0.1), Vector3(W * 0.5 - 1.6, H, 0.2))
	_box(room, wall_m, Vector3(0, H * 0.5 + 1.4, D * 0.5 + 0.1), Vector3(3.2, H - 2.8, 0.2))
	_box(room, _mat(Color(0.95, 0.85, 0.6), 1.6), Vector3(0, 1.4, D * 0.5 + 0.25), Vector3(3.0, 2.8, 0.05))  # luz da rua pela porta
	for k in int(W / 3.0):  # vigas do teto
		_box(room, dark, Vector3(-W * 0.5 + 1.5 + k * 3.0, H - 0.15, 0), Vector3(0.3, 0.3, D))
	for s in [-1.0, 1.0]:  # janelas com luz de fora
		for k in 2:
			_box(room, _mat(Color(0.9, 0.85, 0.7), 1.1), Vector3(s * (W * 0.5 - 0.02), H * 0.55, -D * 0.25 + k * D * 0.4), Vector3(0.05, 1.4, 1.2))
	for i in inside.items:
		_item(i, wood, dark)
	# luzes
	var l1 := OmniLight3D.new()
	l1.position = Vector3(0, H - 0.6, 0)
	l1.light_color = Color(1.0, 0.86, 0.68)
	l1.light_energy = 2.6
	l1.omni_range = maxf(W, D) * 0.9
	room.add_child(l1)
	var l2 := OmniLight3D.new()
	l2.position = Vector3(0, H * 0.6, -D * 0.3)
	l2.light_color = Color(1.0, 0.8, 0.6)
	l2.light_energy = 1.6
	l2.omni_range = maxf(W, D) * 0.7
	room.add_child(l2)
	# pessoas
	for n in inside.npcs:
		var race: Array = main.world.info.races.keys()
		var rr: String = race[randi() % race.size()] if randf() < 0.45 else "humano"
		if str(n[0]).begins_with("Cavaleiro") or str(n[0]).begins_with("Guarda"):
			rr = "humano"
		var armor: String = "pesada_ng" if str(n[4]) == "Idle_Shield" else ["", "robe_ng", "leve_ng"][randi() % 3]
		var c: Node3D = Character.create({"race": rr, "gender": "f" if str(n[0]).ends_with("a") or str(n[0]).ends_with("eira") else "m", "skin": randi() % 3, "hair": randi() % 6, "hair_color": randi() % 6,
			"equipment": {"armadura": armor, "arma": "espada_ng" if armor == "pesada_ng" else ""}})
		if str(n[0]) == "Criança":
			c.scale = Vector3.ONE * 0.62
		room.add_child(c)
		c.set_battle(false)
		c.position = Vector3(float(n[1]), 0, float(n[2]))
		c.rotation.y = float(n[3])
		c.play(str(n[4]))
		if str(n[4]) == "Sitting_Idle":  # banquinho embaixo de quem está sentado
			var back := Vector3(sin(float(n[3])), 0, cos(float(n[3]))) * -0.15
			_box(room, _mat(Color(0.36, 0.24, 0.14)), Vector3(float(n[1]), 0.24, float(n[2])) + back, Vector3(0.5, 0.48, 0.5))
		c.set_tag(str(n[0]), Color(0.92, 0.92, 0.85))
		people.append({"node": c, "name": n[0], "lines": LINES.get(str(n[5]), LINES.casa)})
		blockers.append([Vector2(float(n[1]), float(n[2])), 0.35])


func _item(i: Array, wood: Material, dark: Material) -> void:
	var k: String = i[0]
	var x: float = i[1]
	var z: float = i[2]
	var w: float = i[3]
	var d: float = i[4]
	var h := 1.0
	var mat: Material = wood
	match k:
		"balcao":
			h = 1.1
		"prateleira", "armario":
			h = 2.4
			mat = dark
		"lareira", "fornalha":
			h = 2.2
			mat = _mat(Color(0.45, 0.42, 0.4))
			var f: Node3D = FX.fire(0.9 if k == "fornalha" else 0.7, true)
			f.position = Vector3(x, 0.5, z + d * 0.55)
			room.add_child(f)
		"mesa":
			h = 0.78
		"banco":
			h = 0.5
		"barril":
			h = 1.0
		"bigorna":
			h = 0.8
			mat = _mat(Color(0.25, 0.25, 0.27))
		"cama":
			h = 0.6
			_box(room, _mat(Color(0.75, 0.2, 0.18)), Vector3(x, 0.66, z + 0.2), Vector3(w * 0.95, 0.12, d * 0.7))
		"coluna":
			h = float(inside.h)
			mat = _mat(Color(0.86, 0.84, 0.8))
		"altar":
			h = 1.2
			mat = _mat(Color(0.9, 0.88, 0.82))
			_box(room, _mat(Color(1.0, 0.85, 0.5), 2.0), Vector3(x, 1.6, z), Vector3(0.3, 0.8, 0.3))
		"trono":
			h = 2.6
			mat = _mat(Color(0.95, 0.75, 0.3))
		"tapete":
			h = 0.03
			mat = _mat(Color(0.6, 0.1, 0.12))
		"vitrine":
			h = 1.2
			_box(room, _mat(Color(0.6, 0.85, 1.0), 1.5), Vector3(x, 1.45, z), Vector3(w * 0.5, 0.3, d * 0.4))
		"armas", "mural":
			h = 2.2
			mat = dark
		"escada":
			for s in 6:
				_box(room, wood, Vector3(x, 0.2 + s * 0.4, z - d * 0.5 + s * d / 6.0), Vector3(w, 0.4 + s * 0.4 * 0.0, d / 6.0))
			h = 0.0
	if h > 0.0:
		_box(room, mat, Vector3(x, h * 0.5, z), Vector3(w, h, d))
	if k not in ["tapete", "escada"]:
		blockers.append([Vector2(x, z), maxf(w, d) * 0.5 if k != "coluna" else 0.5])
		if maxf(w, d) > 2.5:  # peças compridas: mais pontos de bloqueio ao longo
			var along := Vector2(w * 0.35, 0) if w > d else Vector2(0, d * 0.35)
			blockers[blockers.size() - 1][1] = minf(w, d) * 0.5 + 0.2
			blockers.append([Vector2(x, z) + along, minf(w, d) * 0.5 + 0.2])
			blockers.append([Vector2(x, z) - along, minf(w, d) * 0.5 + 0.2])
	if i.size() > 5 and str(i[5]) != "":
		var l := Label3D.new()
		l.text = i[5]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.pixel_size = 0.005
		l.font_size = 40
		l.outline_size = 8
		l.modulate = Color(1.0, 0.92, 0.7)
		l.position = Vector3(x, maxf(h, 0.8) + 0.6, z)
		room.add_child(l)


# planta da sala, desenhada no canto da tela
class Planta extends Control:
	var data := {}
	var player := Vector2.ZERO
	var facing := 0.0

	func _draw() -> void:
		if data.is_empty():
			return
		var W: float = data.w
		var D: float = data.d
		var box := size
		var k := minf((box.x - 20.0) / W, (box.y - 40.0) / D)
		var o := Vector2(box.x * 0.5, 30.0 + D * k * 0.5)
		draw_rect(Rect2(Vector2.ZERO, box), Color(0.04, 0.045, 0.06, 0.86))
		draw_rect(Rect2(Vector2.ZERO, box), Color(0.62, 0.5, 0.26), false, 1.5)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(10, 20), str(data.name), HORIZONTAL_ALIGNMENT_LEFT, box.x - 20.0, 14, Color(1.0, 0.86, 0.5))
		var tl := o - Vector2(W, D) * 0.5 * k
		draw_rect(Rect2(tl, Vector2(W, D) * k), Color(data.floor).darkened(0.2))
		draw_rect(Rect2(tl, Vector2(W, D) * k), Color(0.85, 0.8, 0.7), false, 2.0)
		for i in data.items:
			var r := Rect2(o + Vector2(float(i[1]) - float(i[3]) * 0.5, float(i[2]) - float(i[4]) * 0.5) * k, Vector2(i[3], i[4]) * k)
			draw_rect(r, Color(0.55, 0.42, 0.28) if i[0] not in ["lareira", "fornalha"] else Color(0.9, 0.45, 0.15))
		for n in data.npcs:
			draw_circle(o + Vector2(n[1], n[2]) * k, 3.5, Color(1.0, 0.85, 0.3))
		var ex: Vector2 = data.exit
		draw_rect(Rect2(o + (ex - Vector2(1.5, 0.3)) * k, Vector2(3.0, 0.6) * k), Color(0.9, 0.3, 0.25))
		draw_string(font, o + (ex + Vector2(-1.5, 1.4)) * k, "saída", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.6, 0.55))
		var pp := o + player * k
		draw_circle(pp, 5.0, Color(0.4, 1.0, 0.5))
		draw_line(pp, pp + Vector2(sin(facing), cos(facing)) * 11.0, Color(0.4, 1.0, 0.5), 2.0)
		draw_string(font, Vector2(10, box.y - 8), "● você   ● pessoas", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 0.78, 0.82))
