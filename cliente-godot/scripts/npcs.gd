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
# capital: lugar (ponto de serviço), nome, deslocamento x, z, giro, animação, janela, roupa, arma
const CAPITAL_ROLES := [
	["lendarios", "Mercador de Lendários", 0.0, 0.0, PI * 0.5, "Idle_FoldArms", "loja", "robe_ng", ""],
	["artesao", "Mestre Artesão Lendário", 0.0, 0.0, PI * 0.5, "Idle_FoldArms", "oficio", "leve_ng", "martelo_ng"],
	["arena", "Mestre da Arena", 0.0, 2.0, 0.0, "Idle_FoldArms", "", "pesada_ng", ""],
	["arena", "Cavaleiro da Arena", -6.0, 0.0, 0.0, "Idle", "", "pesada_ng", "espadao_ng"],
	["arena", "Cavaleira da Arena", 6.0, 0.0, 0.0, "Idle", "", "pesada_ng", "espadao_ng"],
	["palacio", "Cavaleiro Real", -8.0, 0.0, 0.0, "Idle", "", "pesada_ng", "espadao_ng"],
	["palacio", "Cavaleira Real", 8.0, 0.0, 0.0, "Idle", "", "pesada_ng", "espadao_ng"],
	["palacio", "Arauto do Rei", 0.0, 4.0, 0.0, "Idle_Talking", "", "robe_ng", ""],
	["quartel", "Comandante dos Cavaleiros", 6.0, 22.0, 0.0, "Idle_FoldArms", "classe", "pesada_ng", "espadao_ng"],
	["igreja", "Sumo Sacerdote", 0.0, 0.0, 0.0, "Idle", "", "robe_ng", ""],
]
# conversas entre dois moradores (falas alternadas)
const DIALOGS := [
	["Bom dia! Vai ao mercado hoje?", "Vou sim, preciso de farinha e sal.", "Diz que chegou tecido novo do porto.", "Então vou junto, quero ver."],
	["Ouviu os sinos ontem à noite?", "Ouvi. Dizem que foi alarme na muralha.", "Os guardas não falaram nada.", "Guardas nunca falam nada."],
	["Como vai a família?", "Todos bem, graças à Aurora.", "E o pequeno, já anda?", "Anda e corre! Não paro um minuto."],
	["O torneio da arena começa quando?", "Na próxima lua cheia, pelo que falam.", "Quero ver o campeão perder um dia.", "Difícil. Ele nunca perdeu."],
	["A colheita foi boa este ano?", "Melhor que a do ano passado.", "Então o pão vai baixar de preço.", "Tomara!"],
	["Você viu o aventureiro que chegou?", "Vi, armadura brilhando e tudo.", "Será que vai às ruínas?", "Todos vão. Poucos voltam ricos."],
	["Que calor hoje.", "Vamos até o chafariz?", "Boa ideia, e depois uma cerveja.", "Combinado."],
	["Me paga o que deve?", "Amanhã, prometo.", "Você disse isso ontem.", "E amanhã eu digo de novo."],
	["Viu o céu ontem? Sem estrelas no norte.", "O Véu está mais fino, dizem os velhos.", "Melhor nem pensar nisso.", "Melhor rezar, isso sim."],
]
const COLD_LINES := ["Que frio! Ainda bem que trouxe a capa de pele.", "A neve não para desde ontem.", "Chegue perto do fogo, viajante.", "Lã, pele e chá quente: assim se vive aqui."]
const ACTS := {
	"forja": ["TreeChopping", "Interact", "Idle_FoldArms"], "mercado": ["Idle_Talking", "Interact", "PickUp_Table", "Yes"], "campo": ["Farm_Harvest", "Farm_Harvest", "PickUp_Table"],
	"pousada": ["Consume", "Idle_Talking", "Idle"], "estabulo": ["Interact", "PickUp_Table", "Idle"], "praca": ["Idle_Talking", "Idle", "Yes", "Idle_FoldArms"], "banco": ["Sitting_Idle"],
	"igreja": ["Idle", "Yes"], "jardim": ["Idle", "Idle_FoldArms", "Farm_Harvest"], "treino": ["Sword_Regular_A", "Sword_Block", "Sword_Regular_B"], "fogueira": ["Dance", "Idle_Talking"],
	"poco": ["PickUp_Table", "Consume", "Idle"], "cais": ["PickUp_Table", "Interact", "Idle"], "arena": ["Idle_FoldArms", "Yes", "Idle_Talking"],
}
const JOBS := [["mercado", 22], ["forja", 9], ["campo", 16], ["pousada", 8], ["estabulo", 6], ["praca", 14], ["igreja", 5], ["jardim", 6], ["treino", 5], ["cais", 9]]
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
var nodes: Array = []  # cruzamentos e pontos de rua (mundo)
var adj: Array = []  # ligações entre os pontos
var places := {}  # tipo de lugar -> [pontos]: casa, praca, banco, mercado, forja, pousada, estabulo, campo, igreja, jardim, fogueira...
var clock := 0.0


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


# ---------- rede de caminhos e lugares da cidade ----------
func _node(p: Vector3) -> int:
	nodes.append(p)
	adj.append([])
	return nodes.size() - 1


func _link(i: int, j: int) -> void:
	if i == j or i < 0 or j < 0:
		return
	if not (adj[i] as Array).has(j):
		adj[i].append(j)
		adj[j].append(i)


func _nearest_node(p: Vector3) -> int:
	var best := -1
	var bd := 1e9
	for i in nodes.size():
		var d := Vector2((nodes[i] as Vector3).x - p.x, (nodes[i] as Vector3).z - p.z).length_squared()
		if d < bd:
			bd = d
			best = i
	return best


# caminho pelas ruas (menor distância na rede) de um ponto a outro
func _route(from: Vector3, to: Vector3) -> Array:
	var s := _nearest_node(from)
	var g := _nearest_node(to)
	if s < 0 or g < 0 or s == g or from.distance_to(to) < 12.0:
		return [to]
	var dist := {s: 0.0}
	var prev := {}
	var open: Array = [s]
	var seen := {}
	while not open.is_empty():
		var bi := 0
		for k in open.size():
			if float(dist[open[k]]) < float(dist[open[bi]]):
				bi = k
		var u: int = open[bi]
		open.remove_at(bi)
		if u == g:
			break
		seen[u] = true
		for v in adj[u]:
			if seen.has(v):
				continue
			var nd: float = float(dist[u]) + (nodes[u] as Vector3).distance_to(nodes[v])
			if not dist.has(v) or nd < float(dist[v]):
				dist[v] = nd
				prev[v] = u
				if not open.has(v):
					open.append(v)
	var path: Array = [to]
	var c := g
	while prev.has(c):
		path.push_front(nodes[c])
		c = prev[c]
	path.push_front(nodes[s])
	return path


func _place_add(kind: String, p: Vector3) -> void:
	if not places.has(kind):
		places[kind] = []
	places[kind].append(p)


func _reset_places() -> void:
	nodes = []
	adj = []
	places = {}
	spots = []
	benches = []
	homes = []


func _spawn_village(v: Dictionary) -> void:
	town_id = str(v.id)
	town = v
	_reset_places()
	var race := _race_of(v)
	var ring: Array = []
	for k in 6:
		var a := TAU * k / 6.0
		ring.append(_node(_w(v, sin(a) * 9.0, cos(a) * 9.0)))
	for k in 6:
		_link(ring[k], ring[(k + 1) % 6])
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var last: int = ring[k]
		for d in [20.0, 32.0, 44.0]:
			var n := _node(_w(v, sin(a) * d, cos(a) * d))
			_link(last, n)
			last = n
		_place_add("campo", _w(v, sin(a) * 40.0, cos(a) * 40.0))
	for hp in v.homes:
		homes.append(_w(v, (hp as Vector3).x * 0.82, (hp as Vector3).z * 0.82))
		spots.append(_w(v, (hp as Vector3).x * 0.5, (hp as Vector3).z * 0.5))
	places.casa = homes
	benches = [_w(v, 6.0, 8.0)]
	places.banco = benches
	fire_pos = _w(v, -4.0, -3.0)
	places.praca = [_w(v, 2.0, 2.0), _w(v, -6.0, 4.0), _w(v, 4.0, -6.0)]
	places.fogueira = [fire_pos]
	places.poco = [_w(v, 5.0, -2.0)]
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
	_reset_places()
	var race := _race_of(t)
	var W: Node3D = main.world
	var size: String = W.size_of(t)
	var big := size in ["capital", "grande"]
	var R: float = W.wall_r(t)
	var svc: Dictionary = W.town_svc.get(town_id, {})
	var r := RandomNumberGenerator.new()
	r.seed = hash(town_id)
	if big:
		# ruas retas: cruzamentos ligados ao longo das avenidas
		var L: Array = [-185.0, -142.0, -97.0, -52.0, 0.0, 52.0, 97.0, 142.0, 185.0] if size == "capital" else [-116.0, -78.0, -40.0, 0.0, 40.0, 78.0, 116.0]
		var grid := {}
		for i in L.size():
			for j in L.size():
				var gx: float = L[i]
				var gz: float = L[j]
				if gx == 0.0 and gz == 0.0:
					continue
				if absf(gx) < 30.0 and absf(gz) < 30.0:
					continue
				grid[Vector2i(i, j)] = _node(_w(t, gx + (6.0 if gx == 0.0 else 0.0), gz + (6.0 if gz == 0.0 and gx != 0.0 else 0.0)))
		for k in grid:
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				if grid.has(k + d):
					_link(grid[k], grid[k + d])
		var plaza: Array = []
		for k in 8:
			var a := TAU * k / 8.0 + PI / 8.0
			plaza.append(_node(_w(t, sin(a) * 16.0, cos(a) * 16.0)))
		for k in 8:
			_link(plaza[k], plaza[(k + 1) % 8])
			var nn := -1
			var bd := 1e9
			for g in grid.values():
				var dd := (nodes[g] as Vector3).distance_to(nodes[plaza[k]])
				if dd < bd:
					bd = dd
					nn = g
			_link(plaza[k], nn)
		for k in 12:
			var a := TAU * k / 12.0
			_place_add("praca", _w(t, sin(a) * r.randf_range(9.0, 22.0), cos(a) * r.randf_range(9.0, 22.0)))
		for b in [Vector2(10.0, 12.0), Vector2(-10.0, 12.0), Vector2(10.0, -12.0), Vector2(-10.0, -12.0)]:
			benches.append(_w(t, b.x, b.y + (0.8 if b.y > 0 else -0.8)))
		for d in W.doors:
			if str(d.get("town", "")) == town_id and str(d.kind) == "casa":
				homes.append(d.pos)
	else:
		var ring: Array = []
		for k in 8:
			var a := TAU * k / 8.0 + 0.2
			ring.append(_node(_w(t, sin(a) * 13.0, cos(a) * 13.0)))
		for k in 8:
			_link(ring[k], ring[(k + 1) % 8])
		for g in t.get("gates", []):
			var a := float(g)
			var last := -1
			var d := 24.0
			while d < R + 30.0:
				var n := _node(_w(t, sin(a) * d, cos(a) * d))
				if last < 0:
					var nn := -1
					var bd := 1e9
					for rn in ring:
						var dd := (nodes[rn] as Vector3).distance_to(nodes[n])
						if dd < bd:
							bd = dd
							nn = rn
					_link(nn, n)
				else:
					_link(last, n)
				last = n
				d += 14.0
			_place_add("campo", _w(t, sin(a + 0.25) * (R + 22.0), cos(a + 0.25) * (R + 22.0)))
			_place_add("campo", _w(t, sin(a - 0.25) * (R + 26.0), cos(a - 0.25) * (R + 26.0)))
		for i in 10:
			var a := TAU * i / 10.0
			_place_add("praca", _w(t, sin(a) * r.randf_range(7.0, 16.0), cos(a) * r.randf_range(7.0, 16.0)))
		benches = [_w(t, 3.5, -10.3), _w(t, -4.5, -9.8), _w(t, 9.5, 10.3)]
		var sp: String = W.special_of(t)
		var hr := [24.0, 44.0] if sp != "arvore" else [46.0, 56.0]
		for ring_i in 2:
			var count := 9 if ring_i == 0 else 14
			for i in count:
				var a := TAU * (i + 0.5 * ring_i) / count + 0.3
				homes.append(_w(t, sin(a) * (hr[ring_i] - 4.5), cos(a) * (hr[ring_i] - 4.5)))
		_place_add("mercado", _w(t, -8.0, 7.0))
		_place_add("mercado", _w(t, -10.5, -2.5))
		_place_add("poco", _w(t, 5.0, 4.5))
	if homes.is_empty():
		homes = places.get("praca", [_w(t, 0, 0)]).duplicate()
	places.casa = homes
	places.banco = benches
	spots = places.praca.duplicate()
	fire_pos = _w(t, 0, 0)
	places.fogueira = [fire_pos]
	for k in ["forja", "pousada", "estabulo", "mercado", "igreja", "jardim", "treino", "arena", "lendarios", "artesao", "palacio", "quartel", "cais"]:
		if svc.has(k):
			var sv: Vector2 = svc[k]
			var toward := -sv.normalized() * (7.5 if k in ["forja", "pousada", "estabulo"] else 0.0) if sv.length() > 1.0 else Vector2.ZERO
			var base := _w(t, sv.x + toward.x, sv.y + toward.y)
			for j in 3:
				_place_add(k, base + Vector3(r.randf_range(-3.0, 3.0), 0, r.randf_range(-3.0, 3.0)))
			if not big:
				var n := _node(base)
				var nn := -1
				var bd := 1e9
				for i in nodes.size() - 1:
					var dd := (nodes[i] as Vector3).distance_to(base)
					if dd < bd:
						bd = dd
						nn = i
				_link(n, nn)
	# com função
	for d in ROLES:
		queue.append({"kind": "role", "race": race, "def": d})
	for g in t.get("gates", []):
		var a := float(g)
		var gd := R - 4.0
		for sgn in [-1.0, 1.0]:
			queue.append({"kind": "role", "race": race, "def": ["Guarda", Vector3(sin(a) * gd + cos(a) * sgn * 3.2, 0, cos(a) * gd - sin(a) * sgn * 3.2), a + PI, "Idle_Shield", "", "pesada_ng", "espada_ng"]})
	if size == "capital":
		for d in CAPITAL_ROLES:
			var sv: Vector2 = svc.get(d[0], Vector2(0, 30))
			queue.append({"kind": "role", "race": "humano", "def": [d[1], Vector3(sv.x + float(d[2]), 0, sv.y + float(d[3])), float(d[4]), d[5], d[6], d[7], d[8]]})
	elif big and svc.has("arena"):
		var sv: Vector2 = svc.arena
		queue.append({"kind": "role", "race": race, "def": ["Mestre da Arena", Vector3(sv.x, 0, sv.y + 2.0), 0.0, "Idle_FoldArms", "", "pesada_ng", ""]})
	# soldados de ronda pelas ruas
	if big:
		for i in (12 if size == "capital" else 6):
			queue.append({"kind": "patrol", "race": "humano" if size == "capital" else race, "i": i})
	# história
	for s in STORY.get(town_id, []):
		queue.append({"kind": "story", "race": race, "def": s})
	# gente comum e viajantes
	var n_cit := CITIZENS + (28 if size == "capital" else (14 if big else 0))
	for i in n_cit:
		queue.append({"kind": "citizen", "race": race})
	for i in TRAVELERS:
		queue.append({"kind": "traveler", "race": race})
	# animais da cidade
	var stb: Vector2 = svc.get("estabulo", Vector2(62, 22))
	for a in [["a_horse", Vector3(stb.x + 6.0, 0, stb.y + 6.0), 1.7], ["a_horse_white", Vector3(stb.x + 9.0, 0, stb.y + 2.0), 1.7], ["a_donkey", Vector3(stb.x - 6.0, 0, stb.y - 6.0), 1.25],
			["a_husky", Vector3(14.0, 0, 13.0), 0.6], ["a_shibainu", Vector3(-14.0, 0, -6.0), 0.5]]:
		queue.append({"kind": "animal", "def": a})


# lugar frio: o povo anda de capa de pele e capuz
func _cold() -> bool:
	if town.is_empty():
		return false
	if town.get("village", false):
		return str(town.id) in ["vila_geada"]
	return main.world.special_of(town) in ["frio", "montanha"]


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
	var mix := 0.55 if main.world.size_of(town) in ["capital", "grande"] else 0.18  # cidades grandes: povos de todas as raças
	if rng.randf() < mix and not opts.get("fixed_race", false):  # visitantes de outros povos
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
	if _cold():
		c.winter(rng.randi())
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
			var job := "praca"
			var roll := rng.randi() % 100
			for j in JOBS:
				roll -= int(j[1])
				if roll < 0:
					job = j[0]
					break
			if not places.has(job) or (job == "campo" and main.world.size_of(town) in ["capital", "grande"]):
				job = "mercado" if places.has("mercado") and rng.randf() < 0.5 else "praca"
			var e := {"node": c, "window": "", "name": info.name, "kind": "citizen", "age": info.age, "lines": CHAT[info.age], "home": homes[rng.randi() % homes.size()],
				"goal": Vector3.ZERO, "state": "casa", "timer": 0.0, "speed": info.speed, "anim": "", "walks": true, "line_i": rng.randi() % 5,
				"job": job, "group": rng.randi() % 12, "shift": rng.randf_range(-0.8, 0.8), "taste": rng.randf(), "dest_kind": "", "dest": Vector3.ZERO,
				"path": [], "path_i": 0, "act_t": 0.0, "talk_cd": clock + rng.randf_range(10.0, 60.0), "soc_t": rng.randf(), "conv": {}, "meet": {}, "seed": rng.randi()}
			c.set_tag(info.name, Color(0.92, 0.92, 0.88))
			c.tag.visibility_range_end = 18.0
			list.append(e)
			# já começa no lugar onde estaria a esta hora
			var want := _wanted(e, _hour())
			e.dest_kind = want
			e.dest = _dest_point(e, want)
			c.position = Vector3(e.dest.x, main.world.height(e.dest.x, e.dest.z), e.dest.z)
			if want == "casa":
				c.visible = false
				e.state = "casa"
			else:
				e.state = "fazendo"
				c.rotation.y = rng.randf() * TAU
				_do_act(e)
		"patrol":
			var info := _person(q.race, {"fixed_race": true, "adult": true, "armor": "pesada_ng", "weapon": "espada_ng" if int(q.i) % 3 else "lanca_ng"})
			var c: Node3D = info.node
			var cap: bool = main.world.size_of(town) == "capital"
			var L: Array = [52.0, 97.0, 142.0] if cap else [40.0, 78.0]
			var k: float = L[int(q.i) % L.size()]
			var loop: Array = []
			for corner in [Vector2(-k, -k), Vector2(0, -k), Vector2(k, -k), Vector2(k, 0), Vector2(k, k), Vector2(0, k), Vector2(-k, k), Vector2(-k, 0)]:
				loop.append(_w(town, corner.x + 4.5, corner.y + 4.5))
			var start := (int(q.i) * 3) % loop.size()
			c.position = loop[start]
			c.set_tag(("Cavaleiro de Ronda" if cap else "Soldado da Guarda") + "\n" + info.name, Color(0.8, 0.88, 1.0))
			c.tag.visibility_range_end = 26.0
			var e := {"node": c, "window": "", "name": info.name, "kind": "patrol", "age": "adulto", "lines": CHAT.guarda, "loop": loop, "loop_i": (start + 1) % loop.size(),
				"state": "andando", "timer": 0.0, "speed": 1.35, "anim": "", "walks": true, "line_i": 0, "home": c.position}
			list.append(e)
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
	if check_t <= 0.0 and not main.interiores.inside.is_empty():
		check_t = 1.0
	if check_t <= 0.0:
		check_t = 1.0
		var p: Vector3 = main.player.position
		var nt: Dictionary = main.world.nearest_town(p.x, p.z)
		var place: Dictionary = {}
		if nt.dist < float(nt.wall) + 170.0:
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
		elif town_id != "" and nt.dist > float(nt.wall) + 250.0:
			var still := false
			for v in main.world.villages:
				if str(v.id) == town_id and Vector2(float(v.x) - p.x, float(v.z) - p.z).length() < 220.0:
					still = true
			if not still:
				_clear()
	if list.is_empty():
		return
	clock += dt
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
	if e.get("walks", false) and e.state != "conversa" and e.kind in ["citizen", "patrol"]:
		e.paused = e.state == "andando"
		e.state = "fazendo" if e.kind == "citizen" else "parado"
		e.act_t = 5.0
		e.timer = 5.0
		c.rotation.y = atan2(main.player.position.x - c.position.x, main.player.position.z - c.position.z)
		_anim(e, "Idle_Talking")


func _hour() -> float:
	return float(main.atmos.t_day) * 24.0


# o que a pessoa quer fazer a esta hora (rotina do dia)
func _wanted(e: Dictionary, h: float) -> String:
	var hh := fposmod(h + float(e.shift), 24.0)
	var taste: float = e.taste
	match str(e.age):
		"crianca":
			if hh < 7.5 or hh >= 20.0:
				return "casa"
			if hh < 12.0:
				return "jardim" if taste > 0.6 and places.has("jardim") else "praca"
			if hh < 13.0:
				return "casa"
			return "praca" if taste < 0.7 else ("poco" if places.has("poco") else "praca")
		"idoso":
			if hh < 8.0 or hh >= 20.0:
				return "casa"
			if hh < 11.0:
				return "banco"
			if hh < 12.0:
				return "igreja" if places.has("igreja") else "jardim" if places.has("jardim") else "praca"
			if hh < 14.0:
				return "casa"
			if hh < 18.0:
				return "jardim" if taste > 0.5 and places.has("jardim") else "banco"
			return "praca"
	if hh < 6.5 or hh >= 22.5:
		return "pousada" if taste > 0.85 and hh >= 22.5 and hh < 23.5 and places.has("pousada") else "casa"
	if hh < 12.0:
		return e.job
	if hh < 13.0:
		return "pousada" if taste > 0.5 and places.has("pousada") else "praca"
	if hh < 17.5:
		return e.job
	if hh < 20.0:
		return "banco" if taste < 0.25 else ("praca" if taste < 0.7 else ("jardim" if places.has("jardim") else "praca"))
	return "pousada" if taste > 0.45 and places.has("pousada") else "fogueira"


func _dest_point(e: Dictionary, kind: String) -> Vector3:
	if kind == "casa":
		return e.home
	var pts: Array = places.get(kind, places.get("praca", [e.home]))
	var h := absi(int(e.seed) + hash(kind))
	var p: Vector3 = pts[h % pts.size()]
	var j := Vector3(float(h % 7) - 3.0, 0, float((h / 7) % 7) - 3.0) * (0.25 if kind in ["banco", "forja", "estabulo", "pousada"] else 0.6)
	return p + j


func _set_dest(e: Dictionary, kind: String) -> void:
	var c: Node3D = e.node
	e.dest_kind = kind
	e.dest = _dest_point(e, kind)
	e.meet = {}
	if e.state == "casa":  # sai de casa pela porta
		c.position = Vector3((e.home as Vector3).x, main.world.height((e.home as Vector3).x, (e.home as Vector3).z), (e.home as Vector3).z)
		c.visible = true
	e.path = _route(c.position, e.dest)
	e.path_i = 0
	e.state = "andando"


# anda até o ponto; devolve true ao chegar
func _walk(e: Dictionary, to: Vector3, dt: float, run := false) -> bool:
	var c: Node3D = e.node
	var dir := Vector3(to.x - c.position.x, 0, to.z - c.position.z)
	if dir.length() < 0.7:
		return true
	var spd: float = float(e.speed) * (1.8 if run else 1.0)
	dir = dir.normalized()
	# não atropela o jogador: espera ele passar
	var pp: Vector3 = main.player.position
	if Vector2(pp.x - c.position.x, pp.z - c.position.z).length() < 1.3 and dir.dot((pp - c.position).normalized()) > 0.6:
		_anim(e, "Idle")
		return false
	var np: Vector3 = c.position + dir * spd * dt
	np = main.world.resolve(np, c.position)
	c.position = Vector3(np.x, main.world.height(np.x, np.z), np.z)
	c.rotation.y = lerp_angle(c.rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 6.0))
	_anim(e, "Jog_Fwd" if e.age == "crianca" else "Walk", spd / 3.0 if e.age == "crianca" else spd / 1.2)
	return false


func _do_act(e: Dictionary) -> void:
	var acts: Array = ACTS.get(str(e.dest_kind), ["Idle"])
	if e.age == "crianca" and e.dest_kind in ["praca", "jardim", "poco"]:
		acts = ["Dance", "Yes", "Idle", "Jog_Fwd"]
	var act: String = acts[rng.randi() % acts.size()]
	if act == "Jog_Fwd":
		act = "Dance"
	if night_v > 0.6 and e.dest_kind == "fogueira":
		act = "Dance" if rng.randf() < 0.4 else "Idle_Talking"
	_anim(e, act)
	e.act_t = rng.randf_range(10.0, 22.0) if act != "Sitting_Idle" else rng.randf_range(30.0, 60.0)


func _start_talk(a: Dictionary, b: Dictionary) -> void:
	var ca: Node3D = a.node
	var cb: Node3D = b.node
	a.conv = {"lines": DIALOGS[rng.randi() % DIALOGS.size()] if not _cold() or rng.randf() < 0.5 else [COLD_LINES[rng.randi() % 4], COLD_LINES[rng.randi() % 4]], "i": 0, "t": 0.4, "with": b, "resume": a.state}
	b.conv = {"partner": a, "resume": b.state}
	a.state = "conversa"
	b.state = "conversa"
	ca.rotation.y = atan2(cb.position.x - ca.position.x, cb.position.z - ca.position.z)
	cb.rotation.y = atan2(ca.position.x - cb.position.x, ca.position.z - cb.position.z)
	_anim(a, "Idle_Talking")
	_anim(b, "Idle")


func _end_talk(a: Dictionary) -> void:
	var b: Dictionary = a.conv.get("with", {})
	for x in [a, b]:
		if x.is_empty():
			continue
		x.talk_cd = clock + rng.randf_range(90.0, 200.0)
		var back: String = str(x.conv.get("resume", "fazendo"))
		x.conv = {}
		x.meet = {}
		x.state = "andando" if back == "andando" else "fazendo"
		if x.state == "fazendo":
			_do_act(x)


func _friend_near(e: Dictionary, r: float) -> Dictionary:
	var c: Node3D = e.node
	for o in list:
		if o == e or o.kind != "citizen" or int(o.group) != int(e.group) or not (str(o.state) in ["andando", "fazendo"]) or float(o.talk_cd) > clock:
			continue
		if not o.meet.is_empty():
			continue
		if (o.node as Node3D).position.distance_to(c.position) < r:
			return o
	return {}


var night_v := 0.0


func _tick(e: Dictionary, dt: float, night: float) -> void:
	var c: Node3D = e.node
	night_v = night
	match str(e.kind):
		"animal":
			_tick_animal(e, dt)
			return
		"traveler":
			_tick_traveler(e, dt)
			return
		"patrol":
			c.visible = true
			if e.state == "parado":
				e.timer = float(e.timer) - dt
				if float(e.timer) <= 0.0:
					e.state = "andando"
				return
			if _walk(e, e.loop[e.loop_i], dt):
				e.loop_i = (int(e.loop_i) + 1) % (e.loop as Array).size()
				if int(e.loop_i) % 2 == 0:  # nas esquinas para e olha a rua
					e.state = "parado"
					e.timer = rng.randf_range(4.0, 9.0)
					_anim(e, "Idle")
			return
		"role", "story":
			return
	# ---- morador comum ----
	if str(e.state) == "conversa":
		if e.conv.has("lines"):
			e.conv.t = float(e.conv.t) - dt
			if float(e.conv.t) <= 0.0:
				var lines: Array = e.conv.lines
				var i: int = e.conv.i
				if i >= lines.size():
					_end_talk(e)
					return
				var other: Dictionary = e.conv.with
				var spk: Dictionary = e if i % 2 == 0 else other
				var lis: Dictionary = other if i % 2 == 0 else e
				if is_instance_valid(spk.node) and (spk.node as Node3D).visible:
					say(spk, str(lines[i]))
				_anim(spk, "Idle_Talking")
				_anim(lis, "Yes" if rng.randf() < 0.3 else "Idle")
				e.conv.i = i + 1
				e.conv.t = 3.4
		return
	var want := _wanted(e, _hour())
	if want != str(e.dest_kind) and e.meet.is_empty():
		_set_dest(e, want)
	match str(e.state):
		"casa":
			c.visible = false
		"andando":
			c.visible = true
			var path: Array = e.path
			var i: int = e.path_i
			if not e.meet.is_empty():
				var f: Dictionary = e.meet
				if not is_instance_valid(f.node) or str(f.state) == "conversa" or str(f.state) == "casa":
					e.meet = {}
					e.path = _route(c.position, e.dest)
					e.path_i = 0
					return
				var fp: Vector3 = (f.node as Node3D).position
				var off := (c.position - fp)
				off.y = 0.0
				if _walk(e, fp + off.normalized() * 1.3, dt):
					_start_talk(e, f)
				return
			if i >= path.size():
				if str(e.dest_kind) == "casa":
					c.visible = false
					e.state = "casa"
					return
				e.state = "fazendo"
				var to: Vector3 = e.dest
				if e.dest_kind in ["forja", "mercado", "estabulo", "pousada", "igreja", "cais"]:
					c.rotation.y = atan2(to.x - c.position.x, to.z - c.position.z) + PI
				_do_act(e)
				return
			if _walk(e, path[i], dt):
				e.path_i = i + 1
			# encontrou um amigo no caminho: para e conversa
			e.soc_t = float(e.soc_t) - dt
			if float(e.soc_t) <= 0.0:
				e.soc_t = 0.6
				if float(e.talk_cd) < clock:
					var f := _friend_near(e, 3.2)
					if not f.is_empty():
						_start_talk(e, f)
		"fazendo":
			c.visible = true
			e.act_t = float(e.act_t) - dt
			if float(e.act_t) <= 0.0 and e.get("paused", false):  # terminou de falar com o jogador: segue o caminho
				e.paused = false
				e.state = "andando"
				return
			if float(e.act_t) <= 0.0:
				_do_act(e)
				# no lazer procura um amigo por perto para conversar
				if e.dest_kind in ["praca", "jardim", "banco", "fogueira", "pousada", "poco"] and float(e.talk_cd) < clock and e.anim != "Sitting_Idle":
					var f := _friend_near(e, 14.0)
					if not f.is_empty() and str(f.state) == "fazendo":
						e.meet = f
						e.state = "andando"


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
