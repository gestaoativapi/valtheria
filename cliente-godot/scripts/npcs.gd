extends Node3D
# Gente das cidades e das estradas. Cada cidade perto do jogador ganha mais de 50 moradores:
# os que têm função (loja, ofício, clã, classe), guardas, personagens da história e gente comum
# fazendo o dia a dia (andando, conversando, sentando, trabalhando, dançando na fogueira à noite).
# Nas estradas que saem dos portões passam viajantes. Todos falam: de tempos em tempos e ao clique.

const Character = preload("res://scripts/character.gd")

# função, posição (x, z a partir do centro), giro, animação, janela que abre ao clicar, roupa, arma
const ROLES := [
	["Mercador", Vector3(-9.2, 0, 7.4), 2.4, "Idle_Talking", "loja", "leve_ng", ""],
	["Ferreiro", Vector3(-60.0, 0, -11.0), 1.4, "Idle_FoldArms", "oficio", "leve_ng", "martelo_ng"],
	["Mestre do Clã", Vector3(5.0, 0, -11.0), 0.2, "Idle", "cla", "robe_ng", ""],
	["Mestre de Classes", Vector3(-3.0, 0, -12.5), 0.0, "Idle_FoldArms", "classe", "pesada_ng", "espadao_ng"],
	["Estalajadeiro", Vector3(-6.0, 0, -58.0), 0.1, "Idle_Talking", "", "leve_ng", ""],
]
const CITIZENS := 46  # gente comum por cidade (com funções, guardas e história passa de 50)
const TRAVELERS := 8  # viajantes nas estradas de cada cidade

# Personagens da história: o Pacto do Véu, firmado pelos sete povos, se partiu e as sombras voltam pelas fendas.
const STORY := {
	"aurora": [["Irmã Elowen", "Guardiã do Santuário", ["O Véu que separa o nosso mundo das sombras está rachando. Eu sinto isso nas orações.", "Sete povos juraram o Pacto do Véu. Hoje mal lembram o próprio juramento.", "Se você for às Ruínas de Vel'Anor, procure o selo partido. Ele ainda guarda a primeira palavra do pacto."]],
		["Capitão Doran Vel", "Guarda de Aurora", ["Javalis eu aguento. Mas o que anda no Castelo dos Corvos à noite não é bicho.", "Treine nos arredores antes de ir longe. A estrada cobra caro dos apressados."]],
		["Velho Tobias", "Cronista", ["Meu avô viu a última fenda se fechar. Contava que o céu ficou sem estrelas por uma semana.", "Dizem que o Pacto tinha um oitavo nome, apagado de propósito. Ninguém sabe de quem."]]],
	"dourado": [["Mira Pés-Ligeiros", "Mensageira", ["Levo cartas entre as sete cidades. Ultimamente, mais avisos que cartas.", "O Forte dos Saqueadores voltou a ter fogo aceso. Gente nova lá dentro."]],
		["Ancião Bramble", "Conselho do Vale", ["O trigo está nascendo cinzento perto do Monólito Sussurrante. Mau sinal."]]],
	"pedra": [["Thrain Martelo-Fundo", "Mestre das Forjas", ["As forjas de Pedra Alta selaram o Véu com aço e runas. O aço lembra, mesmo quando a gente esquece.", "Traga minério das montanhas e eu mostro o que é uma arma de verdade."]],
		["Brunna Cinzel", "Guardiã das Runas", ["As runas da cripta estão apagando uma por uma. Alguém está bebendo o poder delas."]]],
	"sylvar": [["Aelar Folha-Prata", "Sentinela da Floresta", ["As árvores falam devagar. Esta semana disseram uma só palavra: fenda.", "O Templo da Lua Partida foi nosso. Hoje só a lua o visita."]],
		["Lyria Canto-de-Orvalho", "Curandeira", ["Os ents estão adoecendo. Uma raiz escura corre por baixo da floresta."]]],
	"rubra": [["Grukk Dente-de-Ferro", "Chefe de Guerra", ["Orc não foge. Mas orc também não é burro: o Castelo do Sangue Eterno está acordando."]],
		["Shara Olho-Rubro", "Xamã", ["O sangue dos antigos ferve sob a cidadela. O Véu daqui é fino como pele."]]],
	"celeste": [["Seren do Alto Céu", "Vigia das Estrelas", ["Contei as estrelas ontem. Faltavam três. Estrelas não somem sozinhas."]]],
	"presas": [["Ruk Garra-Cinza", "Caçador do Clã", ["As presas do clã sentem o cheiro das sombras antes de qualquer um. E o cheiro está forte."]]],
	"umbraval": [["Nyxara", "Senhora das Sombras", ["Nós, elfos negros, fomos acusados de rasgar o Véu. Não fomos nós. Mas sabemos quem foi."]]],
	"pico": [["Kaelthar Escama-de-Bronze", "Guardião do Pico", ["O Dragão Celeste não dorme mais. Quando ele voa baixo, o Véu treme."]]],
}

const NAMES := {
	"humano": [["Arin", "Bento", "Caio", "Davi", "Edran", "Fábio", "Gael", "Heitor", "Ivo", "Joran", "Lauro", "Mateo", "Nilo", "Otto", "Rafa", "Tomás"], ["Alice", "Bia", "Clara", "Dália", "Elisa", "Flora", "Gina", "Helena", "Iara", "Júlia", "Lia", "Marta", "Nina", "Olívia", "Rosa", "Sara"]],
	"elfo": [["Aelion", "Caelir", "Elandor", "Faelar", "Ilyndor", "Lethar", "Naeris", "Thalion"], ["Aerin", "Elanil", "Ilyra", "Lessa", "Miriel", "Naela", "Sylvi", "Thaliel"]],
	"sombrio": [["Drazen", "Ilvar", "Kaelos", "Nyx", "Rhazar", "Vexor"], ["Ilvra", "Myrith", "Nyssa", "Sabrae", "Vaelith", "Zhara"]],
	"orc": [["Brug", "Durk", "Gorak", "Krag", "Mog", "Thrak", "Urg"], ["Agra", "Brakka", "Gasha", "Morka", "Shagra", "Urza"]],
	"anao": [["Balin", "Borin", "Dorn", "Gimrik", "Thoren", "Durgan", "Hamrik"], ["Brynja", "Dagna", "Helga", "Kili", "Runa", "Thyra"]],
	"beastman": [["Rakh", "Fenn", "Garr", "Lupo", "Tharn"], ["Kira", "Rhea", "Sasha", "Vixa", "Yuna"]],
	"draconato": [["Arkhan", "Drazhar", "Kesrith", "Vorath"], ["Ilsyr", "Sora", "Vessra", "Zyra"]],
	"gigante": [["Bjorn", "Hrolf", "Ulfar"], ["Frida", "Sigrun", "Yrsa"]],
}

const CHAT := {
	"adulto": ["Bom dia! O mercado está cheio hoje.", "Ouviu falar das ruínas? Dizem que os mortos andam por lá.", "Meu primo foi para as montanhas e voltou com uma espada nova.", "Cuidado com os lobos depois do pôr do sol.",
		"O ferreiro está cobrando caro, mas o trabalho é bom.", "Vai chover, minhas costas não mentem.", "Já viu o céu à noite? Tem estrelas a menos, juro.", "Preciso levar essas coisas para casa antes de escurecer.",
		"Os guardas estão mais nervosos que de costume.", "Dizem que um aventureiro derrotou um chefe ontem perto daqui.", "Que dia bonito para trabalhar.", "Você não é daqui, é? Seja bem-vindo."],
	"crianca": ["Pega-pega! Você tá com ele!", "Quando eu crescer vou ser cavaleiro!", "Minha mãe disse para eu não ir até o portão.", "Você já matou um dragão?", "Eu vi um sapo enorme no rio!"],
	"idoso": ["No meu tempo, as estradas eram seguras.", "Ah, as costas... já não sou mais o mesmo.", "Escute os velhos, jovem: o Véu não se remenda sozinho.", "Eu lembro da última vez que o céu ficou escuro de dia."],
	"guarda": ["Circulando, circulando.", "Portão aberto até o anoitecer.", "Viu algo estranho na estrada? Avise a guarda.", "Mantenha a arma guardada dentro da cidade."],
	"viajante": ["Longa estrada até a próxima cidade.", "Bons ventos, viajante.", "Cuidado mais adiante, vi bandidos na colina.", "Estou levando mercadoria para o Vale Dourado.", "Essa estrada já viu dias melhores."],
	"noite": ["Que noite fria.", "Hora de voltar para casa.", "A fogueira está boa hoje.", "Olha quantas estrelas... ou quantas faltam."],
}

var main: Node3D
var town_id := ""
var list: Array = []  # {"node", "window", "name", ...}
var queue: Array = []  # moradores ainda por criar (alguns por quadro, para não travar)
var check_t := 0.0
var talk_t := 0.0
var rng := RandomNumberGenerator.new()
var spots: Array = []  # pontos aonde os moradores vão (mundo)
var benches: Array = []
var homes: Array = []
var fire_pos := Vector3.ZERO
var town: Dictionary = {}


func setup(m: Node3D) -> void:
	main = m
	rng.randomize()


func _clear() -> void:
	for n in list:
		if is_instance_valid(n.node):
			n.node.queue_free()
	list = []
	queue = []
	town_id = ""


func _w(t: Dictionary, x: float, z: float) -> Vector3:
	var wx: float = float(t.x) + x
	var wz: float = float(t.z) + z
	return Vector3(wx, main.world.height(wx, wz), wz)


func _spawn_village(v: Dictionary) -> void:
	town_id = str(v.id)
	town = v
	var race := _race_of(v)
	spots = []
	homes = []
	for hp in v.homes:
		homes.append(_w(v, (hp as Vector3).x, (hp as Vector3).z))
		spots.append(_w(v, (hp as Vector3).x * 0.5, (hp as Vector3).z * 0.5))
	for k in 4:
		var a := TAU * k / 4.0
		spots.append(_w(v, sin(a) * 34.0, cos(a) * 34.0))  # campos
	benches = [_w(v, 6.0, 8.0)]
	fire_pos = _w(v, -4.0, -3.0)
	for i in 14:
		queue.append({"kind": "citizen", "race": race})
	for a in [["a_alpaca", Vector3(30.0, 0, 8.0), 1.5], ["a_shibainu", Vector3(-6.0, 0, 6.0), 0.5], ["a_donkey", Vector3(-28.0, 0, -12.0), 1.25]]:
		queue.append({"kind": "animal", "def": a})


func _spawn(t: Dictionary) -> void:
	if t.get("village", false):
		_spawn_village(t)
		return
	town_id = str(t.id)
	town = t
	var race := _race_of(t)
	var r := RandomNumberGenerator.new()
	r.seed = hash(town_id)
	# pontos da cidade: praça, mercado, poço, fogueira, bancos, portas das casas, ruas até os portões
	spots = []
	for i in 10:
		var a := TAU * i / 10.0
		spots.append(_w(t, sin(a) * r.randf_range(7.0, 20.0), cos(a) * r.randf_range(7.0, 20.0)))
	for p in [Vector2(-9, 9), Vector2(-11, -1), Vector2(7, 4), Vector2(12, -6), Vector2(-5, -56), Vector2(-56, -10), Vector2(60, 16), Vector2(-54, 46)]:
		spots.append(_w(t, p.x, p.y))
	for g in t.get("gates", []):
		var a := float(g)
		for d in [30.0, 45.0, 60.0, 74.0]:
			spots.append(_w(t, sin(a) * d, cos(a) * d))
	benches = [_w(t, 3.5, -9.5), _w(t, -4.5, -9.0), _w(t, 9.5, 9.5)]
	homes = []
	for ring in 2:
		var count := 9 if ring == 0 else 14
		var rad := 24.0 if ring == 0 else 44.0
		for i in count:
			var a := TAU * (i + 0.5 * ring) / count + 0.3
			homes.append(_w(t, sin(a) * rad, cos(a) * rad))
	fire_pos = _w(t, 0, 0)
	# com função
	for d in ROLES:
		queue.append({"kind": "role", "race": race, "def": d})
	for g in t.get("gates", []):
		var a := float(g)
		for sgn in [-1.0, 1.0]:
			queue.append({"kind": "role", "race": race, "def": ["Guarda", Vector3(sin(a) * 82.0 + cos(a) * sgn * 3.2, 0, cos(a) * 82.0 - sin(a) * sgn * 3.2), a + PI, "Idle_Shield", "", "pesada_ng", "espada_ng"]})
	# história
	for s in STORY.get(town_id, []):
		queue.append({"kind": "story", "race": race, "def": s})
	# gente comum e viajantes
	for i in CITIZENS:
		queue.append({"kind": "citizen", "race": race})
	for i in TRAVELERS:
		queue.append({"kind": "traveler", "race": race})
	# animais da cidade
	for a in [["a_horse", Vector3(62.0, 0, 26.0), 1.7], ["a_horse_white", Vector3(66.0, 0, 22.0), 1.7], ["a_donkey", Vector3(70.0, 0, 12.0), 1.25], ["a_alpaca", Vector3(-50.0, 0, 52.0), 1.5],
			["a_husky", Vector3(14.0, 0, 13.0), 0.6], ["a_shibainu", Vector3(-14.0, 0, -6.0), 0.5]]:
		queue.append({"kind": "animal", "def": a})


func _race_of(t: Dictionary) -> String:
	var race := str(t.race)
	if race == "halfling":
		return "humano"
	if race == "sylph" or race == "nocturno":
		return "elfo" if race == "sylph" else "sombrio"
	return race if main.world.info.races.has(race) else "humano"


func _name(race: String, female: bool) -> String:
	var pool: Array = NAMES.get(race, NAMES.humano)[1 if female else 0]
	return pool[rng.randi() % pool.size()]


# cria um morador com variação de raça, sexo, idade, altura, porte, pele e cabelo
func _person(race: String, opts: Dictionary = {}) -> Dictionary:
	if rng.randf() < 0.18 and not opts.get("fixed_race", false):  # visitantes de outros povos
		var all: Array = main.world.info.races.keys().filter(func(x): return x != "gigante")
		race = all[rng.randi() % all.size()]
	var female: bool = opts.get("female", rng.randf() < 0.5)
	var age := "adulto"
	var roll := rng.randf()
	if not opts.get("adult", false):
		if roll < 0.12:
			age = "crianca"
		elif roll < 0.3:
			age = "idoso"
	var skins: Array = main.world.info.races[race].get("skins", [])
	var armor: String = opts.get("armor", ["", "robe_ng", "", "", "leve_ng", ""][rng.randi() % 6])
	var c: Node3D = Character.create({"race": race, "gender": "f" if female else "m", "skin": rng.randi() % maxi(skins.size(), 1),
		"hair": rng.randi() % 6, "hair_color": 6 if age == "idoso" and rng.randf() < 0.8 else rng.randi() % 6,
		"equipment": {"armadura": armor, "arma": opts.get("weapon", "")}})
	var h := rng.randf_range(0.94, 1.06)
	var w := rng.randf_range(0.93, 1.1)
	if age == "crianca":
		h = rng.randf_range(0.56, 0.68)
		w = h * 1.04
	elif age == "idoso":
		h *= 0.96
	c.scale = Vector3(w, h, w)
	add_child(c)
	c.set_battle(false)  # ninguém anda de arma em punho na cidade nem na estrada
	return {"node": c, "race": race, "female": female, "age": age, "name": _name(race, female),
		"speed": (1.2 if age == "adulto" else (2.0 if age == "crianca" else 0.8)) * rng.randf_range(0.9, 1.1)}


func _make(q: Dictionary) -> void:
	var t := town
	match str(q.kind):
		"role", "story":
			var d: Array = q.def
			var role: bool = q.kind == "role"
			var info := _person(q.race, {"fixed_race": true, "adult": true, "armor": d[5] if role else "robe_ng", "weapon": d[6] if role else ""})
			var c: Node3D = info.node
			var pos: Vector3
			if role:
				var lp: Vector3 = d[1]
				var svc: Dictionary = main.world.town_svc.get(town_id, {})
				var key: String = {"Ferreiro": "forja", "Estalajadeiro": "pousada"}.get(str(d[0]), "")
				if key != "" and svc.has(key):  # perto da forja ou da pousada desta cidade
					var sp: Vector2 = svc[key]
					var toward := -sp.normalized() * 5.5
					lp = Vector3(sp.x + toward.x, 0, sp.y + toward.y)
				pos = _w(t, lp.x, lp.z)
				c.rotation.y = d[2]
				c.play(d[3])
			else:
				pos = spots[rng.randi() % 10]
				c.play("Idle")
			c.position = pos
			var nm: String = (d[0] if role else "%s\n%s" % [d[0], d[1]])
			c.set_tag(nm, Color(0.7, 1.0, 0.75) if (role and str(d[4]) != "") else (Color(1.0, 0.85, 0.45) if not role else Color(0.85, 0.9, 1.0)))
			var e := {"node": c, "window": d[4] if role else "", "name": d[0], "kind": q.kind, "age": "adulto", "lines": (d[2] as Array) if not role else (CHAT.guarda if d[0] == "Guarda" else CHAT.adulto),
				"home": pos, "goal": pos, "state": "parado", "timer": rng.randf_range(3.0, 10.0), "speed": 1.0, "anim": d[3] if role else "Idle", "walks": not role, "line_i": 0}
			list.append(e)
		"citizen":
			var info := _person(q.race)
			var c: Node3D = info.node
			var pos: Vector3 = spots[rng.randi() % spots.size()] + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
			c.position = Vector3(pos.x, main.world.height(pos.x, pos.z), pos.z)
			c.rotation.y = rng.randf() * TAU
			c.set_tag(info.name, Color(0.92, 0.92, 0.88))
			c.tag.visibility_range_end = 18.0
			var e := {"node": c, "window": "", "name": info.name, "kind": "citizen", "age": info.age, "lines": CHAT[info.age], "home": homes[rng.randi() % homes.size()],
				"goal": c.position, "state": "parado", "timer": rng.randf_range(0.5, 6.0), "speed": info.speed, "anim": "Idle", "walks": true, "line_i": rng.randi() % 5}
			list.append(e)
			c.play("Idle")
		"traveler":
			var gates: Array = t.get("gates", [])
			if gates.is_empty():
				return
			var a := float(gates[rng.randi() % gates.size()])
			var info := _person(q.race, {"adult": true, "armor": ["leve_ng", "pesada_ng", "robe_ng"][rng.randi() % 3], "weapon": ["espada_ng", "", "lanca_ng", "arco_ng", ""][rng.randi() % 5]})
			var c: Node3D = info.node
			var d := rng.randf_range(100.0, 260.0)
			var side := 2.2 if rng.randf() < 0.5 else -2.2
			c.position = _w(t, sin(a) * d + cos(a) * side, cos(a) * d - sin(a) * side)
			c.set_tag(info.name + "\nViajante", Color(0.85, 0.85, 1.0))
			c.tag.visibility_range_end = 22.0
			var e := {"node": c, "window": "", "name": info.name, "kind": "traveler", "age": "adulto", "lines": CHAT.viajante, "road": a, "side": side, "dir": 1.0 if rng.randf() < 0.5 else -1.0,
				"dist": d, "state": "andando", "timer": 0.0, "speed": info.speed, "anim": "Walk", "walks": true, "line_i": 0}
			list.append(e)
			c.play("Walk")
		"animal":
			var a: Array = q.def
			var holder := Node3D.new()
			var sc: Node3D = (load("res://assets/world/%s.glb" % a[0]) as PackedScene).instantiate()
			var bb := AABB()
			var first := true
			for mi in sc.find_children("*", "MeshInstance3D", true, false):
				var box: AABB = (mi as MeshInstance3D).get_aabb()
				bb = box if first else bb.merge(box)
				first = false
			if bb.size.y > 0.05 and bb.size.y < 50.0:
				sc.scale = Vector3.ONE * (float(a[2]) / bb.size.y)
				sc.position.y = -bb.position.y * sc.scale.y
			holder.add_child(sc)
			add_child(holder)
			holder.position = _w(t, (a[1] as Vector3).x, (a[1] as Vector3).z)
			holder.rotation.y = rng.randf() * TAU
			var ap := sc.find_child("AnimationPlayer", true, false) as AnimationPlayer
			var e := {"node": holder, "window": "", "name": "", "kind": "animal", "ap": ap, "home": holder.position, "goal": holder.position, "state": "parado", "timer": rng.randf_range(2.0, 8.0),
				"speed": 0.9, "anim": "", "walks": true}
			_animal_anim(e, "idle")
			list.append(e)


func _animal_anim(e: Dictionary, what: String) -> void:
	if e.anim == what or e.ap == null:
		return
	e.anim = what
	var ap: AnimationPlayer = e.ap
	for n in ({"idle": ["Eating", "Idle", "Idle_2"], "walk": ["Walk"]}[what] as Array):
		if ap.has_animation(n):
			ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			ap.play(n, 0.3)
			return


func _night() -> float:
	var t: float = main.atmos.t_day
	return 1.0 - smoothstep(-0.12, 0.2, sin((t - 0.25) * TAU))


func _process(dt: float) -> void:
	# cria poucos por quadro
	for k in 3:
		if queue.is_empty():
			break
		_make(queue.pop_front())
	check_t -= dt
	if check_t <= 0.0:
		check_t = 1.0
		var p: Vector3 = main.player.position
		var nt: Dictionary = main.world.nearest_town(p.x, p.z)
		var place: Dictionary = {}
		if nt.dist < 260.0:
			place = nt.town
		else:
			for v in main.world.villages:
				if Vector2(float(v.x) - p.x, float(v.z) - p.z).length() < 150.0:
					place = v
					break
		if not place.is_empty():
			if town_id != str(place.id):
				_clear()
				_spawn(place)
		elif town_id != "" and nt.dist > 340.0:
			var still := false
			for v in main.world.villages:
				if str(v.id) == town_id and Vector2(float(v.x) - p.x, float(v.z) - p.z).length() < 220.0:
					still = true
			if not still:
				_clear()
	if list.is_empty():
		return
	var pp: Vector3 = main.player.position
	var night := _night()
	for e in list:
		var node: Node3D = e.node
		if not is_instance_valid(node) or not e.walks:
			continue
		var d2 := node.position.distance_squared_to(pp)
		if d2 > 170.0 * 170.0:
			node.visible = false
			continue
		_tick(e, dt, night)
	# conversa espontânea perto do jogador
	talk_t -= dt
	if talk_t <= 0.0:
		talk_t = rng.randf_range(4.0, 9.0)
		var near := list.filter(func(e): return is_instance_valid(e.node) and e.kind != "animal" and e.node.visible and (e.node as Node3D).position.distance_to(pp) < 22.0)
		if not near.is_empty():
			var e: Dictionary = near[rng.randi() % near.size()]
			say(e, _line(e, night))


func _line(e: Dictionary, night: float) -> String:
	if night > 0.6 and e.kind == "citizen" and rng.randf() < 0.5:
		return CHAT.noite[rng.randi() % CHAT.noite.size()]
	var lines: Array = e.lines
	if e.kind == "story":
		var l: String = lines[int(e.line_i) % lines.size()]
		e.line_i = int(e.line_i) + 1
		return l
	return lines[rng.randi() % lines.size()]


# balão de fala acima da cabeça
func say(e: Dictionary, text: String) -> void:
	var c: Node3D = e.node
	var b: Label3D = c.get_node_or_null("Fala")
	if b == null:
		b = Label3D.new()
		b.name = "Fala"
		b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		b.pixel_size = 0.0028
		b.font_size = 52
		b.outline_size = 12
		b.width = 700.0
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.modulate = Color(1, 1, 0.92)
		b.outline_modulate = Color(0.05, 0.04, 0.03, 0.9)
		b.visibility_range_end = 30.0
		c.add_child(b)
	b.position = Vector3(0, float(c.height_m) + 0.75, 0)
	b.scale = Vector3.ONE / maxf(c.scale.y, 0.01)
	b.text = text
	b.visible = true
	b.set_meta("until", Time.get_ticks_msec() + 5500)
	get_tree().create_timer(5.6).timeout.connect(func():
		if is_instance_valid(b) and Time.get_ticks_msec() >= int(b.get_meta("until", 0)):
			b.visible = false)


# clique num morador: ele fala e a fala vai para o bate-papo
func talk(e: Dictionary) -> void:
	if e.is_empty() or e.kind == "animal":
		return
	var line := _line(e, _night())
	say(e, line)
	main.ui.chat_line(str(e.name), line, "npc")
	var c: Node3D = e.node
	if e.get("walks", false) and e.state != "conversa":
		e.state = "parado"
		e.timer = 4.0
		c.rotation.y = atan2(main.player.position.x - c.position.x, main.player.position.z - c.position.z)
		c.play("Idle_Talking")


func _go(e: Dictionary, to: Vector3) -> void:
	e.goal = to
	e.state = "andando"


func _tick(e: Dictionary, dt: float, night: float) -> void:
	var c: Node3D = e.node
	if e.kind == "animal":
		_tick_animal(e, dt)
		return
	if e.kind == "traveler":
		_tick_traveler(e, dt)
		return
	# à noite a maioria vai para casa e some; alguns ficam na fogueira
	var sleepy: bool = night > 0.7 and e.kind == "citizen" and hash(e.name + str(e.home)) % 3 != 0
	match str(e.state):
		"andando":
			var to: Vector3 = e.goal
			var dir := Vector3(to.x - c.position.x, 0, to.z - c.position.z)
			if dir.length() < 0.6:
				if sleepy and (e.goal as Vector3).distance_to(e.home) < 1.0:
					c.visible = false
					e.state = "casa"
					return
				_arrive(e, night)
				return
			var fast: bool = e.age == "crianca" and rng.randf() < 0.002
			var spd: float = e.speed
			dir = dir.normalized()
			var np: Vector3 = c.position + dir * spd * dt
			np = main.world.resolve(np, c.position)
			c.position = Vector3(np.x, main.world.height(np.x, np.z), np.z)
			c.rotation.y = lerp_angle(c.rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 6.0))
			_anim(e, "Jog_Fwd" if e.age == "crianca" else "Walk", spd / 1.2 if e.age != "crianca" else spd / 3.0)
			e.timer = float(e.timer) - dt
			if float(e.timer) < -40.0:  # preso: escolhe outro destino
				_pick(e, night)
		"casa":
			c.visible = night > 0.7 and false
			if night < 0.5:
				c.visible = true
				_pick(e, night)
		_:
			c.visible = true
			e.timer = float(e.timer) - dt
			if float(e.timer) <= 0.0:
				if sleepy:
					_go(e, e.home)
					e.timer = 0.0
				else:
					_pick(e, night)


func _arrive(e: Dictionary, night: float) -> void:
	var c: Node3D = e.node
	e.state = "parado"
	var roll := rng.randf()
	var acts := ["Idle", "Idle_FoldArms", "Idle_Talking", "Interact", "PickUp_Table", "Consume", "Farm_Harvest"]
	if e.age == "crianca":
		acts = ["Idle", "Dance", "Yes"]
	elif e.age == "idoso":
		acts = ["Idle", "Idle_FoldArms", "Sitting_Idle"]
	var act: String = acts[rng.randi() % acts.size()]
	# perto do banco: senta; perto da fogueira à noite: dança ou conversa
	for b in benches:
		if (b as Vector3).distance_to(c.position) < 2.5 and roll < 0.7:
			act = "Sitting_Idle"
	if night > 0.6 and c.position.distance_to(fire_pos) < 9.0:
		act = "Dance" if roll < 0.4 else "Idle_Talking"
	# conversa em dupla: procura alguém parado perto
	if act == "Idle_Talking":
		for o in list:
			if o != e and o.kind == "citizen" and o.state == "parado" and is_instance_valid(o.node) and (o.node as Node3D).position.distance_to(c.position) < 4.0:
				var on: Node3D = o.node
				c.rotation.y = atan2(on.position.x - c.position.x, on.position.z - c.position.z)
				on.rotation.y = atan2(c.position.x - on.position.x, c.position.z - on.position.z)
				o.timer = maxf(float(o.timer), 8.0)
				_anim(o, "Idle_Talking")
				break
	_anim(e, act)
	e.timer = rng.randf_range(5.0, 16.0) if act != "Sitting_Idle" else rng.randf_range(15.0, 35.0)


func _pick(e: Dictionary, night: float) -> void:
	var roll := rng.randf()
	var to: Vector3
	if night > 0.6 and roll < 0.5:
		to = fire_pos + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
	elif roll < 0.15:
		to = benches[rng.randi() % benches.size()]
	elif roll < 0.3:
		to = e.home
	else:
		to = spots[rng.randi() % spots.size()] + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
	e.timer = 0.0
	_go(e, to)


func _anim(e: Dictionary, n: String, speed := 1.0) -> void:
	var c: Node3D = e.node
	if e.anim != n:
		e.anim = n
		c.play(n, speed)


func _tick_traveler(e: Dictionary, dt: float) -> void:
	var c: Node3D = e.node
	var a: float = e.road
	e.dist = float(e.dist) + float(e.dir) * float(e.speed) * dt
	if float(e.dist) > 300.0 or float(e.dist) < 92.0:
		e.dir = -float(e.dir)  # chegou ao fim do trecho: dá meia-volta
	var side: float = e.side
	var x: float = float(town.x) + sin(a) * float(e.dist) + cos(a) * side
	var z: float = float(town.z) + cos(a) * float(e.dist) - sin(a) * side
	var dir := Vector3(sin(a), 0, cos(a)) * float(e.dir)
	c.position = Vector3(x, main.world.height(x, z), z)
	c.rotation.y = lerp_angle(c.rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 4.0))
	c.visible = true
	_anim(e, "Walk")


func _tick_animal(e: Dictionary, dt: float) -> void:
	var c: Node3D = e.node
	c.visible = true
	if e.state == "andando":
		var to: Vector3 = e.goal
		var dir := Vector3(to.x - c.position.x, 0, to.z - c.position.z)
		if dir.length() < 0.5:
			e.state = "parado"
			e.timer = rng.randf_range(4.0, 12.0)
			_animal_anim(e, "idle")
			return
		dir = dir.normalized()
		var np: Vector3 = c.position + dir * float(e.speed) * dt
		c.position = Vector3(np.x, main.world.height(np.x, np.z), np.z)
		c.rotation.y = lerp_angle(c.rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 4.0))
		_animal_anim(e, "walk")
	else:
		e.timer = float(e.timer) - dt
		if float(e.timer) <= 0.0:
			var a := rng.randf() * TAU
			e.goal = (e.home as Vector3) + Vector3(sin(a), 0, cos(a)) * rng.randf_range(1.5, 6.0)
			e.state = "andando"


# morador com função sob o cursor (raio da câmera), até 9 m do jogador
func pick(origin: Vector3, dir: Vector3) -> String:
	for n in list:
		if n.window == "":
			continue
		var node: Node3D = n.node
		if node.position.distance_to(main.player.position) > 9.0:
			continue
		var c: Vector3 = node.position + Vector3(0, 1.0, 0)
		var t := (c - origin).dot(dir)
		if t > 0.0 and (origin + dir * t).distance_to(c) < 1.0:
			return n.window
	return ""


# NPC sob o clique: o dicionário dele ou {} (o primeiro clique seleciona e ele fala, o segundo abre a janela)
func pick_npc(origin: Vector3, dir: Vector3) -> Dictionary:
	var best := {}
	var best_t := 1e9
	for n in list:
		if str(n.name) == "" or not is_instance_valid(n.node) or not (n.node as Node3D).visible:
			continue
		var node: Node3D = n.node
		if node.position.distance_to(main.player.position) > 18.0:
			continue
		var c: Vector3 = node.position + Vector3(0, float(node.height_m) * 0.55 * node.scale.y, 0)
		var t := (c - origin).dot(dir)
		if t > 0.0 and t < best_t and (origin + dir * t).distance_to(c) < 0.7:
			best = n
			best_t = t
	return best
