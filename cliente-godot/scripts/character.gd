extends Node3D
const Perfil := preload("res://scripts/perfil.gd")
const FeraHibrida := preload("res://scripts/fera_hibrida.gd")
const RostoRaca := preload("res://scripts/rosto_raca.gd")
const DragonitaVivo := preload("res://scripts/dragonita_vivo.gd")
var asas: Node3D  # dragonita: asas, cauda viva e sopro
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
# raças que já usam o corpo V3 (as demais seguem no modelo antigo até ganharem corpo próprio)
const V3_RACAS := ["humano", "elfo", "sombrio", "orc", "gigante", "anao", "beastman"]
const DIR_V3 := "res://assets_v3/personagens/"
const V3Ctrl := preload("res://scripts/v3_corretivas.gd")
const Enfeites := preload("res://scripts/enfeites.gd")
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
var mao_l_guarda: Node3D  # alvo da mão esquerda na guarda
var mao_l_golpe: Node3D   # alvo da mão esquerda no golpe: preso ao cabo, segue a arma em todo o movimento
var arma_base: Transform3D  # encaixe da arma de duas mãos na guarda
var arma_golpe: Transform3D  # encaixe da mesma arma na mão direita, alinhada como espada (lâmina para a frente)
var guard_on := false
var arqueria: Node3D  # arco: pose e tiro por IK (arqueria.gd)
var empunho: Node  # Empunhar: mão no cabo com a palma alinhada (postura parada normal e de combate)
var _mao_alvo := {}  # lado -> Node3D (quadro da pegada no corpo)
var _pose_mao := {}  # lado -> {"normal": Transform3D, "combate": Transform3D ou null}
var cabelos: Array = []  # malhas de cabelo (somem debaixo de elmo, capuz e chapéu)
var cabeca_no: Node3D  # "cabeça unitária" medida no crânio da raça (cabeca.gd)
var arco_costas := Transform3D.IDENTITY
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
# Proporções por raça e sexo do parecer MESA-011 (gerência, 18/11): altura alvo em metros e fator por região
# do corpo em relação ao humano (1.0). Vale só para as raças no corpo V3; os fatores viram escala local de
# cada osso dividindo pelo fator do osso pai, para não somar a escala em cascata.
const PROPORCOES := {
	"humano:f": {"altura": 1.68, "pelve": 1.0, "coluna": 0.97, "peito": 0.94, "pescoco": 0.95, "cabeca": 0.98, "ombros": 0.91, "braco": 0.95, "antebraco": 0.95, "mao": 0.95, "coxa": 0.98, "canela": 0.97, "pe": 0.97},
	"elfo:m": {"altura": 1.90, "pelve": 0.98, "coluna": 1.04, "peito": 0.96, "pescoco": 1.0, "cabeca": 0.96, "ombros": 0.96, "braco": 1.04, "antebraco": 1.04, "mao": 1.0, "coxa": 1.08, "canela": 1.08, "pe": 1.02},
	"elfo:f": {"altura": 1.78, "pelve": 1.02, "coluna": 1.02, "peito": 0.94, "pescoco": 1.0, "cabeca": 0.97, "ombros": 0.88, "braco": 1.0, "antebraco": 1.0, "mao": 0.98, "coxa": 1.06, "canela": 1.06, "pe": 1.02},
	"sombrio:m": {"altura": 1.88, "pelve": 1.0, "coluna": 1.03, "peito": 1.02, "pescoco": 1.0, "cabeca": 0.98, "ombros": 1.02, "braco": 1.03, "antebraco": 1.03, "mao": 1.0, "coxa": 1.04, "canela": 1.04, "pe": 1.02},
	"sombrio:f": {"altura": 1.76, "pelve": 1.02, "coluna": 1.0, "peito": 0.96, "pescoco": 0.98, "cabeca": 0.98, "ombros": 0.9, "braco": 1.0, "antebraco": 1.0, "mao": 0.98, "coxa": 1.03, "canela": 1.03, "pe": 1.01},
	"orc:m": {"altura": 2.0, "pelve": 1.08, "coluna": 1.08, "peito": 1.24, "pescoco": 1.15, "cabeca": 1.08, "ombros": 1.24, "braco": 1.15, "antebraco": 1.15, "mao": 1.15, "coxa": 1.08, "canela": 1.08, "pe": 1.08},
	"goblin:m": {"altura": 1.15, "pelve": 0.95, "coluna": 0.86, "peito": 0.9, "pescoco": 0.9, "cabeca": 1.3, "ombros": 0.95, "braco": 1.18, "antebraco": 1.18, "mao": 1.2, "coxa": 0.78, "canela": 0.8, "pe": 1.15},
	"goblin:f": {"altura": 1.08, "pelve": 0.98, "coluna": 0.86, "peito": 0.88, "pescoco": 0.9, "cabeca": 1.28, "ombros": 0.9, "braco": 1.15, "antebraco": 1.15, "mao": 1.15, "coxa": 0.8, "canela": 0.8, "pe": 1.1},
	"orc:f": {"altura": 1.87, "pelve": 1.08, "coluna": 1.05, "peito": 1.12, "pescoco": 1.08, "cabeca": 1.05, "ombros": 1.12, "braco": 1.10, "antebraco": 1.10, "mao": 1.08, "coxa": 1.07, "canela": 1.07, "pe": 1.06},
	"anao:m": {"altura": 1.42, "pelve": 1.08, "coluna": 0.88, "peito": 1.18, "pescoco": 0.9, "cabeca": 1.08, "ombros": 1.18, "braco": 1.1, "antebraco": 1.1, "mao": 1.1, "coxa": 0.78, "canela": 0.78, "pe": 0.9},
	"anao:f": {"altura": 1.35, "pelve": 1.08, "coluna": 0.86, "peito": 1.08, "pescoco": 0.9, "cabeca": 1.06, "ombros": 1.08, "braco": 1.08, "antebraco": 1.08, "mao": 1.06, "coxa": 0.78, "canela": 0.78, "pe": 0.9},
	"beastman:m": {"altura": 1.90, "pelve": 1.04, "coluna": 1.04, "peito": 1.12, "pescoco": 1.08, "cabeca": 0.92, "ombros": 1.12, "braco": 1.08, "antebraco": 1.08, "mao": 1.06, "coxa": 1.06, "canela": 1.06, "pe": 1.04},
	"beastman:f": {"altura": 1.78, "pelve": 1.06, "coluna": 1.02, "peito": 1.04, "pescoco": 1.02, "cabeca": 0.92, "ombros": 1.04, "braco": 1.04, "antebraco": 1.04, "mao": 1.02, "coxa": 1.04, "canela": 1.04, "pe": 1.02},
	"gigante:m": {"altura": 2.15, "pelve": 1.12, "coluna": 1.12, "peito": 1.30, "pescoco": 1.12, "cabeca": 1.04, "ombros": 1.30, "braco": 1.18, "antebraco": 1.18, "mao": 1.15, "coxa": 1.15, "canela": 1.15, "pe": 1.12},
	"gigante:f": {"altura": 2.02, "pelve": 1.12, "coluna": 1.10, "peito": 1.17, "pescoco": 1.08, "cabeca": 1.03, "ombros": 1.17, "braco": 1.14, "antebraco": 1.14, "mao": 1.12, "coxa": 1.12, "canela": 1.12, "pe": 1.10},
}
# osso -> [região, osso pai]
const REGIAO_OSSO := {
	"pelvis": ["pelve", ""], "spine_01": ["coluna", "pelvis"], "spine_02": ["coluna", "spine_01"], "spine_03": ["peito", "spine_02"],
	"neck_01": ["pescoco", "spine_03"], "Head": ["cabeca", "neck_01"],
	"clavicle_l": ["ombros", "spine_03"], "clavicle_r": ["ombros", "spine_03"],
	"upperarm_l": ["braco", "clavicle_l"], "upperarm_r": ["braco", "clavicle_r"],
	"lowerarm_l": ["antebraco", "upperarm_l"], "lowerarm_r": ["antebraco", "upperarm_r"],
	"hand_l": ["mao", "lowerarm_l"], "hand_r": ["mao", "lowerarm_r"],
	"thigh_l": ["coxa", "pelvis"], "thigh_r": ["coxa", "pelvis"], "calf_l": ["canela", "thigh_l"], "calf_r": ["canela", "thigh_r"],
	"foot_l": ["pe", "calf_l"], "foot_r": ["pe", "calf_r"],
}


# Postura e caminhada por raça (parecer MESA-013 do ChatGPT): graus extras por osso sobre as animações,
# perfil de combate, ritmo da caminhada (ciclo) e inclinação ao andar. Ver scripts/postura_raca.gd.
const POSTURAS := {
	"elfo": {"pose": {"pelvis": -2, "spine_02": -2, "spine_03": -3, "Head": 1, "clavicle": -2, "upperarm": -3, "lowerarm": 2, "calf": 2},
		"combate": {"spine_01": -2, "spine_02": -2, "upperarm": -5, "lowerarm": 4}, "ciclo": 0.95, "inclina": -2},
	"sombrio": {"pose": {"pelvis": 4, "spine_01": 5, "spine_02": 3, "neck_01": -2, "Head": -3, "clavicle": 4, "upperarm": 5, "lowerarm": -2, "hand": 3, "thigh": 2, "calf": 3, "foot": -2},
		"combate": {"spine_01": 7, "spine_02": 3, "upperarm": 8, "lowerarm": -4}, "ciclo": 1.05, "inclina": 4},
	"orc": {"pose": {"pelvis": -4, "spine_01": 7, "spine_02": 4, "spine_03": 2, "neck_01": -3, "Head": -4, "clavicle": 8, "upperarm": 9, "lowerarm": -4, "hand": 5, "thigh": 4, "calf": 3, "foot": -3},
		"combate": {"spine_01": 10, "spine_02": 5, "upperarm": 12, "lowerarm": -7}, "ciclo": 0.85, "inclina": 5},
	"goblin": {"pose": {"pelvis": 7, "spine_01": 10, "spine_02": 4, "spine_03": -3, "neck_01": -4, "Head": -5, "clavicle": 5, "upperarm": 8, "lowerarm": -5, "hand": 6, "thigh": 6, "calf": 4, "foot": -4},
		"combate": {"spine_01": 12, "spine_02": 5, "upperarm": 10, "lowerarm": -8}, "ciclo": 1.25, "inclina": 9},
	"beastman": {"pose": {"pelvis": 3, "spine_01": 7, "spine_02": 3, "spine_03": -2, "neck_01": -2, "Head": -3, "clavicle": 5, "upperarm": 7, "lowerarm": -3, "hand": 4, "thigh": 5, "calf": 3, "foot": -3},
		"combate": {"spine_01": 9, "spine_02": 4, "upperarm": 10, "lowerarm": -6}, "ciclo": 1.08, "inclina": 6},
	"draconato": {"pose": {"pelvis": 2, "spine_01": 5, "spine_02": 2, "spine_03": -2, "neck_01": -2, "Head": -2, "clavicle": 4, "upperarm": 6, "lowerarm": -3, "hand": 3, "thigh": 3, "calf": 2, "foot": -2},
		"combate": {"spine_01": 7, "spine_02": 4, "upperarm": 8, "lowerarm": -4}, "ciclo": 0.95, "inclina": 3},
	"gigante": {"pose": {"pelvis": -5, "spine_01": 8, "spine_02": 5, "spine_03": 2, "neck_01": -4, "Head": -5, "clavicle": 8, "upperarm": 9, "lowerarm": -5, "hand": 5, "thigh": 5, "calf": 3, "foot": -3},
		"combate": {"spine_01": 10, "spine_02": 6, "upperarm": 12, "lowerarm": -6}, "ciclo": 0.72, "inclina": 6},
	"anao": {"pose": {"pelvis": -2, "spine_01": 5, "spine_02": 2, "Head": -2, "clavicle": 4, "upperarm": 5, "lowerarm": -2, "hand": 3, "thigh": 5, "calf": 3, "foot": -2},
		"combate": {"spine_01": 6, "upperarm": 6, "lowerarm": -3}, "ciclo": 0.9, "inclina": 3},
}
const PosturaRaca = preload("res://scripts/postura_raca.gd")
var postura: Node
var ciclo_raca := 1.0
var subtipo := ""
var race_id := "humano"
var male_flag := true


const SHAPE := {
	"anao:m": {"all": 0.92, "drop": 0.3, "bones": {"thigh_l": 0.68, "thigh_r": 0.68, "foot_l": 1.4, "foot_r": 1.4, "spine_01": 1.36, "spine_02": 0.93, "spine_03": 0.92, "neck_01": 0.88, "Head": 1.22, "hand_l": 1.2, "hand_r": 1.2}},
	"anao:f": {"all": 0.88, "drop": 0.24, "bones": {"thigh_l": 0.75, "thigh_r": 0.75, "foot_l": 1.28, "foot_r": 1.28, "spine_01": 1.1, "spine_03": 0.96, "neck_01": 0.92, "Head": 1.34, "hand_l": 1.1, "hand_r": 1.1}},
	"orc:m": {"all": 1.1, "drop": 0.0, "bones": {"spine_02": 1.1, "spine_03": 1.1, "neck_01": 0.92, "Head": 0.86, "hand_l": 1.15, "hand_r": 1.15}},
	"gigante:m": {"all": 1.38, "drop": 0.0, "bones": {"spine_03": 1.08, "Head": 0.88}},
	"gigante:f": {"all": 1.3, "drop": 0.0, "bones": {"Head": 0.9}},
	# dragonita mulher: mais baixa e esguia que o homem (antes era o mesmo corpo, só 3% menor)
	"draconato:f": {"all": 0.9, "drop": 0.0, "bones": {"spine_03": 0.93, "neck_01": 1.04, "Head": 0.92, "upperarm_l": 0.95, "upperarm_r": 0.95, "thigh_l": 1.02, "thigh_r": 1.02}},
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
	race_id = race
	subtipo = str(o.get("subtipo", ""))
	# crocodilo saiu das linhagens de homem-fera (decisão de Robson, 19/11: exigiria mutação demais no corpo)
	if race == "beastman" and subtipo == "crocodilo":
		subtipo = "lobo" if str(o.get("gender", "m")) != "f" else "ursa"
		o["subtipo"] = subtipo
	var male := str(o.get("gender", "m")) != "f"
	male_flag = male
	var rd: Dictionary = RACES.get(race, {})
	var look: Dictionary = o.get("look") if o.get("look") is Dictionary else {}
	var eq: Dictionary = o.get("equipment") if o.get("equipment") is Dictionary else {}
	var skins: Array = rd.get("skins", ["#e8b993"])
	var skin := Color(str(skins[clampi(int(o.get("skin", look.get("skin", 0))), 0, skins.size() - 1)]))
	if race == "beastman" and V3_HUMANOS:
		var pel: Array = FERAS.get(str(o.get("subtipo", "leao" if male else "tigre")), FERAS.leao).pelo
		skin = Color(str(pel[clampi(int(o.get("skin", look.get("skin", 0))), 0, pel.size() - 1)]))
	if race in ["elfo", "sombrio", "orc", "gigante", "draconato", "anao"] and V3_HUMANOS:
		var pl: Array = (TRACOS[race] as Dictionary).get("peles", [])
		if not pl.is_empty():
			skin = Color(str(pl[clampi(int(o.get("skin", look.get("skin", 0))), 0, pl.size() - 1)]))
	if race == "orc" and str(o.get("subtipo", "")) == "goblin":
		var gp := ["#789a53", "#91a85d", "#627f48", "#a0a85e"]
		skin = Color(str(gp[clampi(int(o.get("skin", look.get("skin", 0))), 0, gp.size() - 1)]))
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
	if race == "anao" and not (V3_HUMANOS and race in V3_RACAS):  # modelos M1/M5 antigos só fora do V3
		own = "anao_m" if male else "anao_f"
	var file := "body_%s_%s" % [g, outfit]
	if dragon:
		file = "body_dragonita"
	elif own != "":
		file = "body_" + own
	v3 = V3_HUMANOS and race in V3_RACAS
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
			# a textura da dragonita é avermelhada: limita cada canal para a cor da escama não estourar
			_tint(m as MeshInstance3D, Color(minf(skin.r / 0.69, 1.35) * 0.68, minf(skin.g / 0.376, 1.35) * 0.68, minf(skin.b / 0.172, 1.35) * 0.68))
		_armadura_dragonita(armor)
		asas = DragonitaVivo.new()
		asas.name = "DragonitaViva"
		add_child(asas)
		asas.montar(self, skel, skin)
	elif own != "":
		pass
	elif v3:
		if TRACOS.has(race) and TRACOS[race].has("cabelos"):
			var cab: Array = TRACOS[race].cabelos
			hair_col = Color(str(cab[posmod(hc_i, cab.size())]))
		if o.get("sem_roupa", false):
			# chefes mutantes: o corpo V3 só tem as partes à mostra (rosto e mãos); a roupa base vira
			# pelagem, pintada da cor do pelo, e a armadura mutante vai por cima
			var antes := skel.find_children("*", "MeshInstance3D", false, false)
			_vestir_v3(male, "peasant", hair_col, false)
			for m in skel.find_children("*", "MeshInstance3D", false, false):
				if not m in antes:
					_tint(m as MeshInstance3D, skin.darkened(0.15))
		else:
			_vestir_v3(male, outfit, hair_col, race != "beastman")
			if outfit == "peasant":
				roupa_raca(race)
		race_id = race
		if race != "humano":
			subtipo = str(o.get("subtipo", ""))
			if subtipo == "" and race == "beastman":
				subtipo = "leao" if male else "tigre"
			_tracos_raca(race, male, skin, hair_col)
		if o.has("armadura_mutante"):
			_armadura_dragonita(str(o.armadura_mutante))
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
	var chave_prop := "goblin" if (race == "orc" and str(o.get("subtipo", "")) == "goblin") else race
	var prop: Dictionary = PROPORCOES.get("%s:%s" % [chave_prop, "m" if male else "f"], {}) if v3 else {}
	if not prop.is_empty():
		var glob := {}
		for bn in REGIAO_OSSO:
			glob[bn] = float(prop.get(REGIAO_OSSO[bn][0], 1.0))
		for bn in REGIAO_OSSO:
			var bi := skel.find_bone(bn)
			if bi < 0:
				continue
			var pai: String = REGIAO_OSSO[bn][1]
			var local: float = glob[bn] / (float(glob[pai]) if pai != "" else 1.0)
			skel.set_bone_pose_scale(bi, Vector3.ONE * local)
		# altura estimada pelos segmentos que somam na vertical (pernas, tronco, pescoço e cabeça)
		var est: float = 0.245 * glob["thigh_l"] + 0.235 * glob["calf_l"] + 0.04 * glob["foot_l"] + 0.06 * glob["pelvis"] + 0.24 * glob["spine_02"] + 0.06 * glob["spine_03"] + 0.03 * glob["neck_01"] + 0.09 * glob["Head"]
		var base_h := 1.8 if male else 1.68
		var k2: float = float(prop.altura) / base_h / est
		body.scale = Vector3.ONE * k2
		height_m = float(prop.altura)
	elif own != "":
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
	if not dragon and not o.get("sem_roupa", false):
		_cor_grau_roupa(eq)
		var arm := str(eq.get("armadura", ""))
		Enfeites.roupa(self, skel, Enfeites.indice(arm), "pesada" if arm.begins_with("pesada") else ("leve" if arm.begins_with("leve") else ("robe" if arm.begins_with("robe") else "")))
	var chave_postura: String = "goblin" if str(o.get("subtipo", "")) == "goblin" else race
	if POSTURAS.has(chave_postura):
		var pr: Dictionary = POSTURAS[chave_postura]
		postura = PosturaRaca.new()
		postura.name = "PosturaRaca"
		postura.pose = pr.pose
		postura.combate = pr.combate
		postura.inclina = float(pr.inclina)
		postura.ereto = 0.75
		ciclo_raca = float(pr.ciclo)
		skel.add_child(postura)
	if race == "gigante" and not dragon:  # metade humano, metade golem de gelo (pedido de Robson 21/11)
		load("res://scripts/gelo_golem.gd").montar(skel)
	# postura parada ereta (guerreiro reto; mago reto e formal; mulher com jeito feminino), depois da postura da raça
	var ereta = load("res://scripts/postura_ereta.gd").new()
	ereta.name = "PosturaEreta"
	ereta.dono = self
	ereta.feminino = not male
	ereta.mago = str(o.get("type", "")) == "m" or str(eq.get("arma", "")).begins_with("cajado") or str(eq.get("arma", "")).begins_with("cetro")
	skel.add_child(ereta)
	if dragon:  # o modelo da dragonita é mais alto que o humano de referência (medido: 1,96 m e 1,84 m)
		height_m = 1.96 if male else 1.84
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
	# o elmo do conjunto conta nos atributos, mas não aparece na cabeça (pedido de Robson 21/11):
	# na cabeça só aparecem os acessórios de cabeça (ids "aces_")
	var elmo_id := str(eq.get("elmo", ""))
	if elmo_id.begins_with("aces_"):
		var it: Array = load("res://scripts/cabeca.gd").item(elmo_id)
		if it[0] != null:
			vestir_cabeca(it[0], bool(it[1]))
	if bool(o.get("heroi", false)):
		aura_heroi(true)
	play("Idle")


# ---------- brilho de encantamento (+4 a +16) e aura de herói ----------
# Faixas próprias de Valtheria: aço azul (+4), turquesa (+7), âmbar (+10), violeta (+13) e ouro branco (+16).
# Camadas da arma: (1) a arma inteira acesa, mais forte nas bordas; (2) contorno de luz em volta de toda a
# silhueta; (3) a partir do +7, aura de energia em ondas subindo pela lâmina; (4) a partir do +10, rastros em arco.
# +4 começa num azul bem claro e vai ganhando cor, fluxo, brilho e tamanho até o +15; o +16 vira dourado-bronze.
# paleta de encanto em três faixas (escolha de Robson 20/11, opção C do P6):
# branco até +9, azul até +15, laranja-dourado no +16
const BRANCO_ENC := Color(0.957, 0.965, 1.0)
const AZUL_ENC := Color(0.31, 0.525, 1.0)
const OURO_16 := Color(1.0, 0.604, 0.19)
static var cor_forcada := Color(0, 0, 0, 0)  # teste visual de paletas (estúdio)


static func cor_encanto(nivel: int) -> Color:
	if cor_forcada.a > 0.0:
		return cor_forcada
	if nivel >= 16:
		return OURO_16
	if nivel >= 10:
		return AZUL_ENC
	return BRANCO_ENC


# 0 no +4, 1 no +15, 1.15 no +16
static func peso_encanto(nivel: int) -> float:
	if nivel >= 16:
		return 1.15
	return clampf((nivel - 4) / 11.0, 0.0, 1.0)

# (1) superfície: toda a arma brilha, com as bordas (onde a face vira de lado) bem mais fortes
const BRILHO_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never;
uniform vec3 cor : source_color = vec3(0.4, 0.6, 1.0);
uniform float forca = 1.0;
void fragment() {
	float fr = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.8);
	float pulso = 0.9 + 0.1 * sin(TIME * 2.2);
	ALBEDO = cor * (0.12 + fr * 1.3) * forca * pulso;
}
"""

# (2) contorno: casca um pouco maior que a arma, vista só por trás dela, que vira uma linha de luz em todas as bordas
const CONTORNO_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_front, depth_draw_never, skip_vertex_transform;
uniform vec3 cor : source_color = vec3(0.4, 0.6, 1.0);
uniform float forca = 1.0;
uniform float espessura = 0.012;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize(mat3(MODEL_MATRIX) * NORMAL);
	w += n * espessura;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = normalize(mat3(VIEW_MATRIX) * n);
}
void fragment() {
	float d = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float borda = smoothstep(0.0, 0.7, 1.0 - d);
	ALBEDO = mix(cor, vec3(1.0), 0.2) * (0.25 + borda * 0.75) * forca;
}
"""

# (3) aura em onda: casca larga que ondula e deixa subir faixas de energia ao longo da lâmina
const ONDA_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, skip_vertex_transform;
uniform vec3 cor : source_color = vec3(0.4, 0.6, 1.0);
uniform float forca = 1.0;
uniform float largura = 0.05;
uniform vec3 eixo = vec3(0.0, 1.0, 0.0);
uniform float comprimento = 1.0;
uniform float velocidade = 1.0;
uniform float fase = 0.0;
varying vec3 lp;
varying float ph;
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float ruido(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	lp = VERTEX;
	float s = dot(VERTEX, eixo) / comprimento;
	ph = fract(TIME * 0.45 * velocidade + fase - s * 0.6 + ruido(VERTEX / comprimento * 3.0) * 0.5);
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize(mat3(MODEL_MATRIX) * NORMAL);
	w += n * largura * (0.15 + 0.85 * ph);
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = normalize(mat3(VIEW_MATRIX) * n);
}
void fragment() {
	float fluxo = ruido(lp / comprimento * 8.0 - eixo * TIME * 1.5 * velocidade);
	float sumir = (1.0 - ph) * smoothstep(0.0, 0.2, ph);
	float d = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float a = sumir * (0.35 + fluxo * 0.65) * (0.45 + (1.0 - d) * 0.55);
	ALBEDO = mix(cor, vec3(1.0), 0.15) * a * forca;
}
"""

# aura do herói: casca dourada suave sobre o corpo inteiro, com energia subindo devagar
const AURA_HEROI_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, skip_vertex_transform;
uniform vec3 cor : source_color = vec3(0.95, 0.68, 0.36);
uniform float forca = 0.35;
uniform float espessura = 0.1;
uniform float fase = 0.0;
varying vec3 wp;
varying float ph;
float h(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float ruido(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h(i), h(i + vec3(1,0,0)), f.x), mix(h(i + vec3(0,1,0)), h(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h(i + vec3(0,0,1)), h(i + vec3(1,0,1)), f.x), mix(h(i + vec3(0,1,1)), h(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize(mat3(MODEL_MATRIX) * NORMAL);
	vec3 base = w - MODEL_MATRIX[3].xyz;
	ph = fract(TIME * 0.3 + fase + ruido(base * 1.6) * 0.7);
	w += n * (0.008 + espessura * ph) + vec3(0.0, espessura * 0.35 * ph * ph, 0.0);
	wp = w;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = normalize(mat3(VIEW_MATRIX) * n);
}
void fragment() {
	float d = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float borda = pow(1.0 - d, 1.7);
	float fluxo = ruido(wp * 5.0 - vec3(0.0, TIME * 0.7, 0.0));
	float sumir = (1.0 - ph) * smoothstep(0.0, 0.15, ph);
	float a = (borda * 0.85 + 0.08) * sumir * (0.45 + fluxo * 0.75);
	ALBEDO = cor * a * forca;
}
"""
const DISCO_HEROI_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float ang = atan(p.y, p.x);
	float anel = exp(-pow((d - 0.78) * 9.0, 2.0)) * (0.75 + 0.25 * sin(ang * 6.0 + TIME * 1.5));
	float miolo = (1.0 - smoothstep(0.0, 0.85, d)) * 0.45;
	float pul = 0.8 + 0.2 * sin(TIME * 2.0);
	ALBEDO = vec3(1.0, 0.72, 0.32) * (anel * 0.9 + miolo) * pul * (1.0 - smoothstep(0.9, 1.0, d));
}
"""
static var _shaders := {}
var encanto := 0
var _aura: Node3D
var _rastros: Node3D
static var _arco_mesh: ArrayMesh


static func _shader(nome: String, codigo: String) -> Shader:
	if not _shaders.has(nome):
		var sh := Shader.new()
		sh.code = codigo
		_shaders[nome] = sh
	return _shaders[nome]


# transformação de um nó relativa à arma, sem depender de estar na árvore
func _rel_wnode(n: Node) -> Transform3D:
	var t := Transform3D()
	while n != null and n != wnode:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func brilho_encanto(nivel: int) -> void:
	encanto = nivel
	if wnode == null:
		return
	for alvo_b in ([wnode, offhand] if offhand != null else [wnode]):
		for c in alvo_b.get_children():
			if str(c.name).begins_with("BrilhoEncanto"):
				c.queue_free()
		if alvo_b == offhand:
			for m in offhand.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_overlay = null
	var malhas := wnode.find_children("*", "MeshInstance3D", true, false)
	for m in malhas:
		(m as MeshInstance3D).material_overlay = null
	if nivel < 4:
		_rastros_encanto(-1, Color())
		return
	var cor := cor_encanto(nivel)
	var t := peso_encanto(nivel)
	# medidas da arma para orientar o fluxo ao longo da lâmina
	var bb := AABB()
	var first := true
	for m in malhas:
		var a: AABB = _rel_wnode(m) * (m as MeshInstance3D).get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	var eixo := Vector3.UP
	var comp := bb.size.y
	if bb.size.x > comp: eixo = Vector3.RIGHT; comp = bb.size.x
	if bb.size.z > comp: eixo = Vector3.BACK; comp = bb.size.z
	var mat := ShaderMaterial.new()
	mat.shader = _shader("brilho", BRILHO_SHADER)
	mat.set_shader_parameter("cor", cor)
	mat.set_shader_parameter("forca", 0.25 + 0.6 * t)
	var cont := ShaderMaterial.new()
	cont.shader = _shader("contorno", CONTORNO_SHADER)
	cont.set_shader_parameter("cor", cor)
	cont.set_shader_parameter("forca", 0.2 + 0.55 * t)
	cont.set_shader_parameter("espessura", 0.004 + 0.007 * t)
	mat.next_pass = cont
	var ultimo: ShaderMaterial = cont
	if nivel >= 7:   # aura fluida: duas camadas desencontradas que nascem na lâmina e escorrem para fora
		for k in 2:
			var onda := ShaderMaterial.new()
			onda.shader = _shader("onda", ONDA_SHADER)
			onda.set_shader_parameter("cor", cor)
			onda.set_shader_parameter("forca", 0.18 + 0.5 * t)
			onda.set_shader_parameter("largura", 0.025 + 0.075 * t)
			onda.set_shader_parameter("eixo", eixo)
			onda.set_shader_parameter("comprimento", maxf(comp, 0.2))
			onda.set_shader_parameter("velocidade", 0.6 + 1.0 * t)
			onda.set_shader_parameter("fase", 0.5 * k)
			onda.render_priority = 1
			ultimo.next_pass = onda
			ultimo = onda
	for m in malhas:
		(m as MeshInstance3D).material_overlay = mat
	if offhand != null:  # segunda lâmina (armas duplas): o mesmo brilho
		for m in offhand.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_overlay = mat
	if nivel >= 10:   # gotas de luz desprendendo da aura
		var p := CPUParticles3D.new()
		p.name = "BrilhoEncanto"
		p.amount = int(4 + 12 * t)
		p.lifetime = 1.4
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = bb.size * 0.45
		p.position = bb.get_center()
		p.direction = Vector3.UP
		p.spread = 30.0
		p.gravity = Vector3(0, 0.3, 0)
		p.initial_velocity_min = 0.03
		p.initial_velocity_max = 0.15
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.0
		var curva := Curve.new()
		curva.add_point(Vector2(0, 0.0))
		curva.add_point(Vector2(0.3, 1.0))
		curva.add_point(Vector2(1, 0))
		p.scale_amount_curve = curva
		var q := QuadMesh.new()
		q.size = Vector2(0.05, 0.05)
		var qm: StandardMaterial3D = _mat_fiapo().duplicate()
		qm.albedo_color = Color(cor.r, cor.g, cor.b, 0.35 + 0.35 * t)
		q.material = qm
		p.mesh = q
		p.visibility_range_end = 30.0
		wnode.add_child(p)
	if nivel >= 7:
		_clarao_arma(bb, eixo, cor, t, wnode)
		if offhand != null:
			_clarao_arma(bb, eixo, cor, t, offhand)
	_rastros_encanto((4 if nivel >= 16 else 2) if nivel >= 13 else -1, cor * (0.55 if nivel < 16 else 0.8))
	if _rastros != null:
		_rastros.set_meta("forca", t)


# clarão da arma encantada: halo largo e macio ao longo da lâmina (brilho que "vaza" da arma, sem pós-processo,
# leve no celular) e uma estrela de luz pulsando na ponta. Efeito genérico de jogo de fantasia, desenhado aqui.
const ESTRELA_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;
uniform vec3 cor : source_color = vec3(1.0);
uniform float forca = 1.0;
uniform float raios = 1.0;
uniform float fase = 0.0;
void vertex() {
	// sempre de frente para a câmera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float esc = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[0] *= esc; MODELVIEW_MATRIX[1] *= esc; MODELVIEW_MATRIX[2] *= esc;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float pul = 0.75 + 0.25 * sin(TIME * 3.1 + fase);
	float g = TIME * 0.35 + fase;
	mat2 r = mat2(vec2(cos(g), -sin(g)), vec2(sin(g), cos(g)));
	vec2 q = r * p;
	float d = length(p);
	float nucleo = exp(-d * d * 18.0);
	float halo = exp(-d * d * 3.5) * 0.35;
	float cruz = (exp(-abs(q.x) * 60.0) + exp(-abs(q.y) * 60.0)) * (1.0 - smoothstep(0.0, 1.0, d));
	vec2 q2 = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * q;
	float x2 = (exp(-abs(q2.x) * 90.0) + exp(-abs(q2.y) * 90.0)) * (1.0 - smoothstep(0.0, 0.6, d)) * 0.6;
	float a = (nucleo * 1.4 + halo + (cruz + x2) * raios * pul) * forca;
	ALBEDO = mix(cor, vec3(1.0), nucleo * 0.7) * a;
}
"""


func _clarao_arma(bb: AABB, eixo: Vector3, cor: Color, t: float, arma: Node3D) -> void:
	var ponta := bb.get_center() + eixo * bb.size.dot(eixo) * 0.5
	if eixo == Vector3.BACK and absf(bb.position.z) > absf(bb.end.z):
		ponta = bb.get_center() - eixo * bb.size.dot(eixo) * 0.5
	var kw := maxf(arma.transform.basis.get_scale().x, 0.0001)  # a arma pode estar em unidades do modelo
	var est := ShaderMaterial.new()
	est.shader = _shader("estrela", ESTRELA_SHADER)
	est.set_shader_parameter("cor", cor)
	est.set_shader_parameter("forca", 0.5 + 0.6 * t)
	est.set_shader_parameter("raios", 0.6 + 0.8 * t)
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.name = "BrilhoEncantoEstrela"
	mi.mesh = q
	mi.material_override = est
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = ponta
	mi.scale = Vector3.ONE * (0.22 + 0.35 * t) / kw
	mi.visibility_range_end = 40.0
	arma.add_child(mi)
	# halo da lâmina: 3 bolhas macias ao longo do eixo (sem raios)
	var comp := bb.size.dot(eixo) * kw
	for i in 3:
		var h := ShaderMaterial.new()
		h.shader = est.shader
		h.set_shader_parameter("cor", cor)
		h.set_shader_parameter("forca", 0.12 + 0.18 * t)
		h.set_shader_parameter("raios", 0.0)
		h.set_shader_parameter("fase", 1.7 * i)
		var b := MeshInstance3D.new()
		b.name = "BrilhoEncantoHalo"
		b.mesh = q
		b.material_override = h
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.position = bb.get_center() + (ponta - bb.get_center()) * (0.75 - 0.6 * i)
		b.scale = Vector3.ONE * clampf(comp * 0.55, 0.2, 0.9) * (0.7 + 0.5 * t) / kw
		b.visibility_range_end = 40.0
		arma.add_child(b)


# fita em arco (~220 graus), mais larga no meio e sumindo nas pontas
static func _arco() -> ArrayMesh:
	if _arco_mesh != null:
		return _arco_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := 48
	for i in n + 1:
		var t := float(i) / n
		var ang := t * deg_to_rad(220.0)
		var alfa := sin(t * PI)
		var lar := 0.004 + 0.016 * alfa
		var dd := Vector3(cos(ang), 0, sin(ang))
		st.set_color(Color(alfa * alfa, alfa * alfa, alfa * alfa))
		st.add_vertex(dd + Vector3(0, lar, 0))
		st.set_color(Color(alfa * alfa, alfa * alfa, alfa * alfa))
		st.add_vertex(dd - Vector3(0, lar, 0))
	_arco_mesh = st.commit()
	return _arco_mesh


# rastro: some quando visto de lado, para não virar uma barra reta na tela
const ARCO_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 cor : source_color = vec3(1.0);
varying float abre;
void vertex() {
	vec3 eixo = normalize(MODEL_MATRIX[1].xyz);
	vec3 olho = normalize(MODEL_MATRIX[3].xyz - INV_VIEW_MATRIX[3].xyz);
	abre = abs(dot(eixo, olho));
}
void fragment() {
	float face = smoothstep(0.1, 0.4, abre);
	ALBEDO = cor * COLOR.rgb * face * 0.8;
}
"""


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
	var mat := ShaderMaterial.new()
	mat.shader = _shader("arco", ARCO_SHADER)
	mat.set_shader_parameter("cor", cor.lerp(Color.WHITE, 0.2))
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


# aura de herói: casca dourada leve sobre o corpo todo e energia fluindo dos pontos de força
# (peito, mãos e testa), subindo devagar como uma chama celeste.
func aura_heroi(on: bool) -> void:
	if _aura != null:
		_aura.queue_free()
		_aura = null
	var malhas: Array = []
	for m in find_children("*", "MeshInstance3D", true, false):
		if wnode != null and wnode.is_ancestor_of(m):
			continue
		if (m as MeshInstance3D).mesh == null or (m as MeshInstance3D).mesh is QuadMesh:
			continue
		malhas.append(m)
	for m in malhas:
		if (m as MeshInstance3D).material_overlay != null and (m as MeshInstance3D).material_overlay.resource_name == "AuraHeroi":
			(m as MeshInstance3D).material_overlay = null
	if not on:
		return
	var mat := ShaderMaterial.new()
	mat.resource_name = "AuraHeroi"
	mat.shader = _shader("aura_heroi", AURA_HEROI_SHADER)
	var veu := ShaderMaterial.new()   # segunda onda, desencontrada: a aura nunca para de transbordar
	veu.shader = mat.shader
	veu.set_shader_parameter("fase", 0.5)
	veu.set_shader_parameter("espessura", 0.12)
	mat.next_pass = veu
	for m in malhas:
		if (m as MeshInstance3D).material_overlay == null:
			(m as MeshInstance3D).material_overlay = mat
	_aura = Node3D.new()
	_aura.name = "AuraHeroi"
	add_child(_aura)
	var cabeca := "head"
	if skel != null:
		for b in skel.get_bone_count():
			if skel.get_bone_name(b).to_lower().begins_with("head"):
				cabeca = skel.get_bone_name(b)
				break
	# o esqueleto pode vir em escala de centímetros: compensa para os fiapos terem tamanho real
	var esc := 1.0
	var n: Node = skel
	while n != null and n != self:
		if n is Node3D:
			esc *= (n as Node3D).scale.x
		n = n.get_parent()
	var pontos := [["spine_03", 1.0], ["hand_l", 0.55], ["hand_r", 0.55], [cabeca, 0.45]]
	for pt in pontos:
		if skel == null or skel.find_bone(pt[0]) < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = pt[0]
		skel.add_child(att)
		_aura.tree_exiting.connect(att.queue_free)
		var f := _fluxo_aura(float(pt[1]))
		f.scale = Vector3.ONE / maxf(esc, 0.0001)
		att.add_child(f)
	# círculo de luz no chão e brilho macio em volta do corpo (o herói "acende" o lugar onde está)
	var disco := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.7, 1.7) * (height_m / 1.8)
	disco.mesh = pm
	var dm := ShaderMaterial.new()
	dm.shader = _shader("disco_heroi", DISCO_HEROI_SHADER)
	disco.material_override = dm
	disco.position = Vector3(0, 0.03, 0)
	disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disco.visibility_range_end = 50.0
	_aura.add_child(disco)
	var corpo := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	corpo.mesh = qm
	var cm := ShaderMaterial.new()
	cm.shader = _shader("estrela", ESTRELA_SHADER)
	cm.set_shader_parameter("cor", Color(1.0, 0.78, 0.45))
	cm.set_shader_parameter("forca", 0.16)
	cm.set_shader_parameter("raios", 0.0)
	corpo.material_override = cm
	corpo.position = Vector3(0, height_m * 0.55, 0)
	corpo.scale = Vector3.ONE * height_m * 1.1
	corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	corpo.visibility_range_end = 50.0
	_aura.add_child(corpo)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.75, 0.45)
	luz.light_energy = 0.3
	luz.omni_range = 2.6
	luz.position = Vector3(0, 1.1, 0)
	luz.shadow_enabled = false
	luz.distance_fade_enabled = true
	luz.distance_fade_begin = 25.0
	_aura.add_child(luz)


# fiapos de luz dourada que nascem num ponto de força e sobem ondulando
func _fluxo_aura(peso: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = int(16 * peso) + 6
	p.lifetime = 2.2
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.05 + 0.06 * peso
	p.direction = Vector3.UP
	p.spread = 70.0
	p.gravity = Vector3(0, 0.12, 0)
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.22
	p.radial_accel_min = 0.05
	p.radial_accel_max = 0.15
	p.damping_min = 0.15
	p.damping_max = 0.35
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.0))
	curva.add_point(Vector2(0.2, 1.0))
	curva.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curva
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	q.material = _mat_fiapo()
	p.mesh = q
	p.visibility_range_end = 50.0
	return p


# fiapo: gota de luz suave (textura radial), sempre virada para a câmera
static var _fiapo: StandardMaterial3D


static func _mat_fiapo() -> StandardMaterial3D:
	if _fiapo != null:
		return _fiapo
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	_fiapo = StandardMaterial3D.new()
	_fiapo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fiapo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_fiapo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fiapo.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_fiapo.albedo_texture = t
	_fiapo.albedo_color = Color(0.95, 0.7, 0.4, 0.5)
	_fiapo.vertex_color_use_as_albedo = true
	return _fiapo


# ---------- traços de raça no corpo V3 ----------
# A pele do corpo V3 é pintada; para as outras raças a cor é multiplicada pela tinta da raça.
# Orelhas, presas e marcas são peças pequenas presas ao osso da cabeça, medidas em metros
# a partir do corpo de repouso (rosto para +Z).
const TOM_BASE_V3 := Color(0.91, 0.74, 0.6)
var pele_raca := Color.WHITE
const TRACOS := {
	"elfo": {"orelha": [0.085, 0.022, 0.55, -0.35], "cabelos": ["#c9c2a1", "#e8d8a8", "#b58a55", "#5d493d", "#a7b9b2"], "peles": ["#f0d6bc", "#d9b99d", "#b99a80", "#e8dccb"]},
	"sombrio": {"orelha": [0.1, 0.022, 0.6, -0.45], "marca": Color(0.85, 0.85, 1.0), "cabelos": ["#b8b4c2", "#191820", "#51405a", "#7d5269"], "peles": ["#74515a", "#593c4c", "#8b626a", "#a17d79", "#4a3946"]},
	"orc": {"orelha": [0.045, 0.024, 0.25, -0.2], "presas": true, "cabelos": ["#2b211c", "#57402e", "#8a6844", "#c0a47a"], "peles": ["#71834c", "#596b3b", "#89985c", "#a0a36b", "#485b39"]},
	"anao": {"barba": true, "cabelos": ["#e7e0d2", "#a94b2d", "#4b3025", "#b58b52"], "peles": ["#e5b995", "#c9916c", "#a66e4f", "#f0d0b0", "#8d604a"]},
	"beastman": {"fera": true},
	"draconato": {"peles": ["#537b58", "#78975f", "#3c5f4b", "#9b6a46", "#b48b58"]},
	"gigante": {"marca": Color(0.6, 0.85, 1.0), "cabelos": ["#dce7e8", "#afc8d0", "#718b9c", "#e8e2d6"], "peles": ["#b8d6db", "#8db7c2", "#d8e8e8", "#709aa8", "#a8c8cf"]},
}


func _tracos_raca(race: String, male: bool, skin: Color, cor_cabelo := Color(0.3, 0.2, 0.15)) -> void:
	var tinta := Color(minf(skin.r / TOM_BASE_V3.r, 1.4), minf(skin.g / TOM_BASE_V3.g, 1.4), minf(skin.b / TOM_BASE_V3.b, 1.4))
	# cor de pele natural: a tinta da raça entra só em parte, sem saturar
	tinta = Color.WHITE.lerp(tinta, 0.9)
	pele_raca = Color(TOM_BASE_V3.r * tinta.r, TOM_BASE_V3.g * tinta.g, TOM_BASE_V3.b * tinta.b)
	for m in skel.find_children("*", "MeshInstance3D", true, false):
		if String(m.name) == "corpo":
			_tint(m as MeshInstance3D, tinta)
	# rosto próprio da raça (forma da malha em repouso; esqueleto e animações oficiais intactos)
	RostoRaca.aplicar(skel, "goblin" if (race == "orc" and subtipo == "goblin") else race, male)
	var tr: Dictionary = TRACOS.get(race, {})
	var hb := skel.find_bone("Head")
	if tr.is_empty() or hb < 0:
		return
	var rest := skel.get_bone_global_rest(hb)
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	att.name = "TracosRaca"
	skel.add_child(att)
	# pontos do rosto no corpo de repouso (homem e mulher têm cabeça em alturas diferentes)
	var olho_y := 1.69 if male else 1.572
	var olho_z := 0.075 if male else 0.115
	var largura := 0.074 if male else 0.068
	var pele := StandardMaterial3D.new()
	pele.albedo_color = pele_raca
	pele.roughness = 0.75
	if tr.has("orelha"):
		var o: Array = tr.orelha
		for lado in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.0015
			c.bottom_radius = float(o[1])
			c.height = float(o[0])
			c.radial_segments = 10
			c.rings = 1
			mi.mesh = c
			mi.material_override = pele
			# ponta para fora, subindo e indo para trás; achatada como uma folha
			var dir := Vector3(lado, float(o[2]), float(o[3])).normalized()
			var b := Basis(Quaternion(Vector3.UP, dir))
			b = b * Basis.from_scale(Vector3(1.0, 1.0, 0.38))
			var base := Vector3(lado * largura, olho_y - 0.01, olho_z - 0.085)
			mi.transform = rest.affine_inverse() * Transform3D(b, base + dir * float(o[0]) * 0.5)
			att.add_child(mi)
	if tr.get("presas", false):
		var marfim := StandardMaterial3D.new()
		marfim.albedo_color = Color(0.93, 0.88, 0.74)
		marfim.roughness = 0.5
		for lado in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.0085 if subtipo != "goblin" else 0.0045
			c.height = (0.048 if male else 0.026) if subtipo != "goblin" else 0.014
			c.radial_segments = 8
			c.rings = 1
			mi.mesh = c
			mi.material_override = marfim
			var b := Basis(Quaternion(Vector3.UP, Vector3(lado * 0.25, 1.0, 0.25).normalized()))
			mi.transform = rest.affine_inverse() * Transform3D(b, Vector3(lado * 0.022, olho_y - 0.082, olho_z + 0.02))
			att.add_child(mi)
	if tr.get("barba", false) and male:
		# barba cheia de anão: uma casca que nasce na linha do queixo, desce até o peito e afina na ponta
		var pelo := StandardMaterial3D.new()
		pelo.albedo_color = cor_cabelo
		pelo.roughness = 1.0
		pelo.vertex_color_use_as_albedo = true
		pelo.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		mi.mesh = _malha_barba()
		mi.material_override = pelo
		# barba de anão mais cheia e comprida (larga 15%, desce 35% a mais a partir do queixo)
		var queixo := Vector3(0.0, 1.6, 0.09)
		mi.transform = rest.affine_inverse() * Transform3D(Basis.from_scale(Vector3(1.15, 1.35, 1.15)), queixo - Basis.from_scale(Vector3(1.15, 1.35, 1.15)) * queixo)
		att.add_child(mi)
		var cobre := StandardMaterial3D.new()
		cobre.albedo_color = Color(0.72, 0.42, 0.22)
		cobre.metallic = 0.8
		cobre.roughness = 0.35
		var anel := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.018
		cil.bottom_radius = 0.02
		cil.height = 0.03
		anel.mesh = cil
		anel.material_override = cobre
		anel.transform = rest.affine_inverse() * Transform3D(Basis.from_euler(Vector3(0.35, 0, 0)), Vector3(0, 1.415, 0.1))
		att.add_child(anel)
	if tr.get("fera", false):
		if FeraHibrida.ESPECIES.has(subtipo):
			# rosto híbrido (fera + humano) com olhos humanos; garras nos dedos e cauda
			FeraHibrida.montar(skel, att, rest, male, subtipo, skin)
			FeraHibrida.garras(skel, subtipo, male)
			var fh: Dictionary = FERAS[subtipo]
			_cauda_fera(subtipo, fh, male, pele_raca, Color(str(fh.escuro)))
		else:
			_cabeca_fera(subtipo, male, att, rest, olho_y, olho_z, pele_raca)
	_tracos_extras(race, male, olho_y, olho_z)
	if tr.has("marca"):
		# marca rúnica leve na testa (elfo negro: prata; gigante: gelo), brilho bem suave
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.026, 0.034)
		mi.mesh = q
		var mm := StandardMaterial3D.new()
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.albedo_texture = _mat_fiapo().albedo_texture
		var cm: Color = tr.marca
		mm.albedo_color = Color(cm.r, cm.g, cm.b, 0.55)
		mi.mesh.material = mm
		mi.transform = rest.affine_inverse() * Transform3D(Basis(), Vector3(0, olho_y + 0.045, olho_z + 0.012))
		att.add_child(mi)


# Homens-fera (parecer MESA-013): quatro linhagens escolhidas na criação. A cabeça humana fica menor
# e é coberta por um crânio de fera feito de peças (crânio, focinho, mandíbula, nariz, orelhas, olhos),
# com juba, listras ou placas conforme a linhagem e uma cauda em segmentos presa à pelve.
const FERAS := {
	"leao": {"pelo": ["#c19462", "#d4a970", "#a87e4c", "#b98a55"], "escuro": "#754321", "focinho": [0.11, 0.062, 0.85], "orelha": "redonda", "juba": "#8a4e22", "cauda": [0.8, 0.035, "tufo"]},
	"tigre": {"pelo": ["#cf8644", "#d99552", "#bd7638", "#e3aa6a"], "escuro": "#392b22", "focinho": [0.12, 0.058, 0.85], "orelha": "redonda", "listras": true, "cauda": [0.9, 0.032, "listrada"]},
	"lobo": {"pelo": ["#92969b", "#b5b7b4", "#746b65", "#5e6670"], "escuro": "#3c4654", "focinho": [0.19, 0.047, 0.8], "orelha": "pontuda", "cauda": [0.85, 0.06, "peluda"]},
	"javali": {"pelo": ["#4a3428", "#5a4030", "#3a2a20", "#6a4a36"], "escuro": "#1e1410", "focinho": [0.15, 0.078, 0.9], "orelha": "pontuda", "presas": true, "cerdas": true, "cauda": [0.35, 0.03, "tufo"]},
	"onca": {"pelo": ["#d9a24e", "#e3b062", "#c48a3c", "#eabf78"], "escuro": "#2a1e16", "focinho": [0.1, 0.058, 0.85], "orelha": "redonda", "cauda": [0.85, 0.032, "listrada"]},
	"ursa": {"pelo": ["#6b4a32", "#7d5a3c", "#5a3e2a", "#8c6a48"], "escuro": "#3a281c", "focinho": [0.1, 0.06, 0.85], "orelha": "redonda", "cauda": [0.12, 0.05, "tufo"]},
	# fora das linhagens jogáveis desde 19/11; mantido só para não quebrar personagens antigos (são convertidos acima)
	"crocodilo": {"pelo": ["#567e54", "#6b8b55", "#4a6b47", "#7d8f5c"], "escuro": "#354e3c", "focinho": [0.26, 0.05, 0.55], "orelha": "", "placas": true, "cauda": [1.0, 0.075, "placas"]},
}


func _cabeca_fera(sub: String, male: bool, att: Node3D, rest: Transform3D, olho_y: float, olho_z: float, pelo: Color) -> void:
	var f: Dictionary = FERAS.get(sub, FERAS.leao)
	var escuro := Color(str(f.escuro))
	var mp := StandardMaterial3D.new()
	mp.albedo_color = pelo
	mp.roughness = 1.0
	var me := StandardMaterial3D.new()
	me.albedo_color = escuro
	me.roughness = 1.0
	var inv := rest.affine_inverse()
	var c0 := Vector3(0, olho_y + 0.005, olho_z - 0.075)   # centro do crânio
	var poe := func(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, esc := Vector3.ONE) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.transform = inv * Transform3D(Basis.from_euler(rot) * Basis.from_scale(esc), pos)
		att.add_child(mi)
		return mi
	# crânio que cobre a cabeça humana
	var cr := SphereMesh.new()
	cr.radius = 0.118 if male else 0.108
	cr.height = cr.radius * 2.0
	var lado_esc := 0.98 if sub != "crocodilo" else 0.9
	poe.call(cr, mp, c0, Vector3.ZERO, Vector3(lado_esc, 1.0, 1.12))
	# focinho e mandíbula
	var fl: float = float(f.focinho[0]) * (1.0 if male else 0.9)
	var fr: float = float(f.focinho[1])
	var fy: float = float(f.focinho[2])
	var fo := CapsuleMesh.new()
	fo.radius = fr
	fo.height = fl + fr * 2.0
	var base := Vector3(0, olho_y - 0.035, olho_z - 0.01)
	poe.call(fo, mp, base + Vector3(0, 0, fl * 0.5), Vector3(deg_to_rad(90), 0, 0), Vector3(1.0, 1.0, fy))
	var mand := CapsuleMesh.new()
	mand.radius = fr * 0.75
	mand.height = fl * 0.85 + fr * 1.5
	poe.call(mand, mp, base + Vector3(0, -fr * 0.75, fl * 0.38), Vector3(deg_to_rad(90), 0, 0), Vector3(0.95, 1.0, 0.7))
	var na := SphereMesh.new()
	na.radius = fr * 0.55
	na.height = na.radius * 1.4
	poe.call(na, me, base + Vector3(0, fr * 0.35, fl + fr * 0.55))
	# olhos âmbar levemente acesos
	var olho := StandardMaterial3D.new()
	olho.albedo_color = Color(0.95, 0.7, 0.2) if sub != "lobo" else Color(0.75, 0.85, 0.95)
	olho.emission_enabled = true
	olho.emission = olho.albedo_color
	olho.emission_energy_multiplier = 0.6
	var ol := SphereMesh.new()
	ol.radius = 0.014
	ol.height = 0.022
	var abre := 0.05 if sub != "crocodilo" else 0.062
	for lado in [-1.0, 1.0]:
		poe.call(ol, olho, Vector3(lado * abre, olho_y + 0.012 + (0.025 if sub == "crocodilo" else 0.0), olho_z + 0.012))
	# orelhas
	match str(f.orelha):
		"redonda":
			var o := SphereMesh.new()
			o.radius = 0.04
			o.height = 0.08
			for lado in [-1.0, 1.0]:
				poe.call(o, mp, c0 + Vector3(lado * 0.085, 0.1, -0.01), Vector3(0, 0, -lado * 0.4), Vector3(1.0, 1.0, 0.4))
		"pontuda":
			var o2 := CylinderMesh.new()
			o2.top_radius = 0.0
			o2.bottom_radius = 0.042
			o2.height = 0.12
			o2.radial_segments = 4
			for lado in [-1.0, 1.0]:
				poe.call(o2, mp, c0 + Vector3(lado * 0.07, 0.15, -0.01), Vector3(-0.15, 0, -lado * 0.3), Vector3(1.0, 1.0, 0.45))
	# juba do leão (homem) ou gola de pelo (mulher e lobo)
	if f.has("juba") or sub == "lobo":
		var cj := Color(str(f.get("juba", f.escuro))) if sub != "lobo" else pelo.lightened(0.15)
		var mj := StandardMaterial3D.new()
		mj.albedo_color = cj
		mj.roughness = 1.0
		var tufos := 26 if (male and sub == "leao") else 14
		var tam := 0.17 if (male and sub == "leao") else 0.09
		for k in tufos:
			var ang := TAU * float(k) / tufos
			var anel := float(k % 2)
			var tufo := CylinderMesh.new()
			tufo.top_radius = 0.0
			tufo.bottom_radius = 0.06 if (male and sub == "leao") else 0.04
			tufo.height = tam * (0.85 + 0.3 * anel)
			tufo.radial_segments = 5
			var dir := Vector3(sin(ang), cos(ang) * 0.9, -0.35).normalized()
			var pos := c0 + Vector3(sin(ang) * 0.1, cos(ang) * 0.11 - 0.03, -0.04 - anel * 0.03)
			var b := Basis(Quaternion(Vector3.UP, dir))
			var mi := MeshInstance3D.new()
			mi.mesh = tufo
			mi.material_override = mj
			mi.transform = inv * Transform3D(b, pos + dir * tufo.height * 0.4)
			att.add_child(mi)
	# listras do tigre na cabeça
	if f.get("listras", false):
		var li := CapsuleMesh.new()
		li.radius = 0.008
		li.height = 0.1
		for k in 5:
			var a := -0.5 + k * 0.25
			poe.call(li, me, c0 + Vector3(sin(a) * 0.11, 0.04 + absf(a) * 0.03, cos(a) * 0.1 - 0.02), Vector3(0.3, a, 0.0), Vector3(1.0, 1.0, 0.5))
	# placas do crocodilo no alto da cabeça e no dorso
	if f.get("placas", false):
		var pl := CylinderMesh.new()
		pl.top_radius = 0.0
		pl.bottom_radius = 0.022
		pl.height = 0.045
		pl.radial_segments = 4
		for k in 4:
			poe.call(pl, me, c0 + Vector3(0, 0.11, 0.06 - k * 0.05), Vector3(-0.3, 0, 0))
	if f.get("presas", false):
		# presas do javali: curvas para cima, saindo dos cantos da boca
		var marfim := StandardMaterial3D.new()
		marfim.albedo_color = Color(0.93, 0.88, 0.74)
		marfim.roughness = 0.45
		for lado in [-1.0, 1.0]:
			for k in 3:
				var seg := CylinderMesh.new()
				seg.top_radius = 0.0 if k == 2 else 0.011 - k * 0.003
				seg.bottom_radius = 0.014 - k * 0.003
				seg.height = 0.05
				poe.call(seg, marfim, base + Vector3(lado * (0.055 + k * 0.012), -0.01 + k * 0.035, fl * 0.75 - k * 0.008), Vector3(-0.3 + k * 0.3, 0, -lado * (0.35 + k * 0.25)))
	if f.get("cerdas", false):
		# crina de cerdas do alto da cabeça até a nuca
		for k in 7:
			var ce := CylinderMesh.new()
			ce.top_radius = 0.0
			ce.bottom_radius = 0.018
			ce.height = 0.09 + 0.02 * sin(k * 0.9)
			ce.radial_segments = 4
			poe.call(ce, me, c0 + Vector3(0, 0.1 - k * 0.012, 0.03 - k * 0.035), Vector3(-0.5 - k * 0.12, 0, 0))
	_cauda_fera(sub, f, male, pelo, escuro)


# cauda em segmentos presos à pelve, balançando devagar
func _cauda_fera(sub: String, f: Dictionary, male: bool, pelo: Color, escuro: Color) -> void:
	var pi := skel.find_bone("pelvis")
	if pi < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "pelvis"
	att.name = "CaudaFera"
	skel.add_child(att)
	var rest := skel.get_bone_global_rest(pi)
	var raiz := Node3D.new()
	raiz.transform = rest.affine_inverse() * Transform3D(Basis.from_euler(Vector3(deg_to_rad(-145), 0, 0)), rest.origin + Vector3(0, -0.02, -0.12))
	att.add_child(raiz)
	var comp: float = float(f.cauda[0]) * (1.0 if male else 0.9)
	var raio: float = float(f.cauda[1])
	var tipo: String = str(f.cauda[2])
	var n := 7
	var mp := StandardMaterial3D.new()
	mp.albedo_color = pelo
	mp.roughness = 1.0
	var me := StandardMaterial3D.new()
	me.albedo_color = escuro
	me.roughness = 1.0
	var pai: Node3D = raiz
	for k in n:
		var t := float(k) / n
		var seg := Node3D.new()
		seg.position = Vector3(0, comp / n if k > 0 else 0.0, 0)
		seg.rotation = Vector3(deg_to_rad(-6.0 - t * 4.0), 0, 0)
		pai.add_child(seg)
		var r := raio * (1.0 - t * 0.6)
		if tipo == "peluda":
			r = raio * (0.55 + sin(t * PI) * 0.6)
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = maxf(comp / n + r * 2.0, r * 2.0)
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = me if (tipo == "listrada" and k % 2 == 1) else mp
		mi.position = Vector3(0, comp / n * 0.5, 0)
		if tipo == "placas":
			mi.scale = Vector3(0.75, 1.0, 1.15)
		seg.add_child(mi)
		if tipo == "placas" and k < n - 1:
			var pl := CylinderMesh.new()
			pl.top_radius = 0.0
			pl.bottom_radius = r * 0.5
			pl.height = r * 1.1
			pl.radial_segments = 4
			var pm := MeshInstance3D.new()
			pm.mesh = pl
			pm.material_override = me
			pm.position = Vector3(0, comp / n * 0.5, -r * 0.9)
			pm.rotation = Vector3(deg_to_rad(-90), 0, 0)
			seg.add_child(pm)
		if k > 0:
			var tw := seg.create_tween().set_loops()
			var amp := deg_to_rad(4.0 + t * 6.0)
			tw.tween_property(seg, "rotation:z", amp, 0.9 + k * 0.05).from(-amp).set_trans(Tween.TRANS_SINE)
			tw.tween_property(seg, "rotation:z", -amp, 0.9 + k * 0.05).set_trans(Tween.TRANS_SINE)
		pai = seg
	if tipo == "tufo":
		var tf := SphereMesh.new()
		tf.radius = raio * 1.6
		tf.height = raio * 4.0
		var mi2 := MeshInstance3D.new()
		mi2.mesh = tf
		mi2.material_override = me
		mi2.position = Vector3(0, comp / n * 1.1, 0)
		pai.add_child(mi2)


# ---------- peças presas a ossos, em coordenadas do corpo de repouso (metros) ----------
var _anexos := {}


func _anexo(osso: String) -> BoneAttachment3D:
	if _anexos.has(osso) and is_instance_valid(_anexos[osso]):
		return _anexos[osso]
	var a := BoneAttachment3D.new()
	a.bone_name = osso
	a.name = "Peca_" + osso
	skel.add_child(a)
	_anexos[osso] = a
	return a


func _peca_osso(osso: String, mesh: Mesh, mat: Material, pos: Vector3, b := Basis()) -> MeshInstance3D:
	var bi := skel.find_bone(osso)
	if bi < 0:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = skel.get_bone_global_rest(bi).affine_inverse() * Transform3D(b, pos)
	_anexo(osso).add_child(mi)
	return mi


func _mat_simples(cor: Color, metal := 0.0, rug := 0.8, brilho := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.metallic = metal
	m.roughness = rug
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = brilho
	return m


static func _prisma(r: float, h: float, lados := 6) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = lados
	c.rings = 1
	return c


# traços extras do parecer MESA-013: cristal da têmpora (elfo branco), sobrancelha óssea (elfo negro e
# gigante), ombreiras de osso (orc), cristais nos ombros (gigante), orelhas largas e nariz (goblin)
func _tracos_extras(race: String, male: bool, olho_y: float, olho_z: float) -> void:
	var goblin := race == "orc" and subtipo == "goblin"
	var ombro_l := skel.get_bone_global_rest(skel.find_bone("upperarm_l")).origin
	var ombro_r := skel.get_bone_global_rest(skel.find_bone("upperarm_r")).origin
	match race:
		"elfo":
			var cr := _mat_simples(Color("#c8f1f5"), 0.2, 0.15, 0.35)
			for lado in [-1.0, 1.0]:
				_peca_osso("Head", _prisma(0.012, 0.04, 4), cr, Vector3(lado * 0.07, olho_y + 0.045, olho_z - 0.03), Basis.from_euler(Vector3(0.3, 0, -lado * 0.5)))
		"gigante":
			var gelo := _mat_simples(Color("#9be5f4"), 0.1, 0.1, 0.25)
			gelo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gelo.albedo_color.a = 0.85
			for par in [["clavicle_l", ombro_l, 1.0], ["clavicle_r", ombro_r, -1.0]]:
				for k in 4:
					var p: Vector3 = par[1] + Vector3(-float(par[2]) * 0.02 + (k - 1.5) * 0.03 * float(par[2]), 0.06 + (k % 2) * 0.02, -0.04 + k * 0.025)
					_peca_osso(par[0], _prisma(0.025 + (k % 2) * 0.01, 0.1 + (k % 3) * 0.04, 5), gelo, p, Basis.from_euler(Vector3(-0.3 + k * 0.15, 0, float(par[2]) * (0.2 - k * 0.15))))
		"orc":
			if goblin:
				var pele := _mat_simples(pele_raca, 0.0, 0.75)
				for lado in [-1.0, 1.0]:
					var o := _prisma(0.045, 0.15, 6)
					var mi := _peca_osso("Head", o, pele, Vector3(lado * 0.1, olho_y + 0.005, olho_z - 0.07), Basis(Quaternion(Vector3.UP, Vector3(lado, 0.25, -0.25).normalized())) * Basis.from_scale(Vector3(1.0, 1.0, 0.35)))
			else:
				var osso := _mat_simples(Color("#d9cdb2"), 0.0, 0.6)
				var couro := _mat_simples(Color("#74604b"), 0.0, 0.9)
				for par in [["clavicle_l", ombro_l, 1.0], ["clavicle_r", ombro_r, -1.0]]:
					var pad := SphereMesh.new()
					pad.radius = 0.1
					pad.height = 0.12
					_peca_osso(par[0], pad, couro, par[1] + Vector3(float(par[2]) * 0.02, 0.06, 0), Basis.from_euler(Vector3(0, 0, -float(par[2]) * 0.4)))
					for k in 3:
						_peca_osso(par[0], _prisma(0.02, 0.1, 6), osso, par[1] + Vector3(float(par[2]) * (0.0 + k * 0.035), 0.11, -0.03 + k * 0.03), Basis.from_euler(Vector3(-0.2, 0, -float(par[2]) * (0.3 + k * 0.25))))


# Armadura própria da dragonita (as armaduras humanas não vestem o corpo dela): placas de peito,
# ombreiras, braçadeiras, grevas e cinto montados nos ossos dela, deixando focinho, chifres, placas
# das costas e cauda livres. A cor do metal segue o grau da peça.
const METAL_GRAU := {"ng": "#8a8f96", "d": "#9a6a3c", "c": "#b0b4ba", "b": "#6a6f78", "a": "#c9a24a", "s": "#d8dde4", "ss": "#e8d9a8"}


func _armadura_dragonita(armor: String) -> void:
	if armor == "" or armor == "nenhuma":
		return
	var grau := armor.get_slice("_", 1) if armor.contains("_") else "ng"
	var pesada := armor.begins_with("pesada")
	var robe := armor.begins_with("robe")
	var metal := _mat_simples(Color(str(METAL_GRAU.get(grau, "#8a8f96"))), 0.85, 0.35)
	var couro := _mat_simples(Color("#5a3e2b"), 0.0, 0.85)
	var tecido := _mat_simples(Color("#3d3552"), 0.0, 0.95)
	var base: StandardMaterial3D = metal if pesada else (tecido if robe else couro)
	var R := func(b: String) -> Vector3: return skel.get_bone_global_rest(skel.find_bone(b)).origin
	if skel.find_bone("spine_03") < 0:
		return
	var sp2: Vector3 = R.call("spine_02")
	var sp3: Vector3 = R.call("spine_03")
	var pel: Vector3 = R.call("pelvis")
	var larg: float = (R.call("upperarm_l") - R.call("upperarm_r")).length() * 0.42
	# peitoral: casca achatada que cobre o tronco (frente mais funda que as costas, para as placas dorsais)
	var pes: Vector3 = R.call("neck_01")
	var sp1: Vector3 = R.call("spine_01")
	# peitoral ajustado (D5): uma casca tirada do próprio corpo da dragonita, 9 mm para fora da pele,
	# com o mesmo esqueleto e pesos: veste certinho e acompanha cada movimento. Costas com as placas
	# dorsais e cauda ficam livres.
	_casca_ajustada(base, 0.009, sp1.y - 0.04, pes.y - 0.04, sp3.z - 0.07, larg * 1.6, pesada)
	# gola alta que protege o pescoço sem cobrir o focinho
	var gola := CylinderMesh.new()
	gola.top_radius = larg * 0.5
	gola.bottom_radius = larg * 0.8
	gola.height = 0.07
	gola.radial_segments = 16
	_peca_osso("spine_03", gola, base, Vector3(0, pes.y - 0.03, sp3.z + 0.02), Basis.from_scale(Vector3(1.0, 1.0, 0.85)))
	# cinto com fivela
	var cinto := CylinderMesh.new()
	cinto.top_radius = larg * 0.8
	cinto.bottom_radius = larg * 0.85
	cinto.height = 0.07
	cinto.radial_segments = 14
	_peca_osso("pelvis", cinto, couro, pel + Vector3(0, 0.05, 0.01), Basis.from_scale(Vector3(1.0, 1.0, 0.75)))
	_peca_osso("pelvis", BoxMesh.new(), metal, pel + Vector3(0, 0.05, larg * 0.62), Basis.from_scale(Vector3(0.07, 0.06, 0.02)))
	# saiote de placas (frente e lados), aberto atrás para a cauda
	for k in 5:
		var ang := -1.1 + k * 0.55
		var pl := BoxMesh.new()
		pl.size = Vector3(larg * 0.42, 0.2, 0.015)
		_peca_osso("pelvis", pl, base, pel + Vector3(sin(ang) * larg * 0.82, -0.07, cos(ang) * larg * 0.62), Basis.from_euler(Vector3(0.12, ang, 0)))
	for lado in ["l", "r"]:
		var sg := 1.0 if lado == "l" else -1.0
		var ua: Vector3 = R.call("upperarm_" + lado)
		var la: Vector3 = R.call("lowerarm_" + lado)
		var ha: Vector3 = R.call("hand_" + lado)
		var th: Vector3 = R.call("thigh_" + lado)
		var ca: Vector3 = R.call("calf_" + lado)
		var ft: Vector3 = R.call("foot_" + lado)
		if pesada or robe:
			var omb := SphereMesh.new()
			omb.radius = larg * 0.42
			omb.height = larg * 0.5
			_peca_osso("upperarm_" + lado, omb, base, ua + Vector3(sg * 0.03, 0.03, 0.02), Basis.from_euler(Vector3(0, 0, -sg * 0.35)))
			if pesada:   # aba de placa sobre a ombreira
				_peca_osso("upperarm_" + lado, _prisma(0.03, 0.12, 4), metal, ua + Vector3(sg * 0.03, 0.12, -0.02), Basis.from_euler(Vector3(-0.4, 0, -sg * 0.5)))
		# braçadeira no antebraço e grevas na canela, alinhadas ao osso
		var dir_b: Vector3 = (ha - la).normalized()
		var br := CylinderMesh.new()
		br.top_radius = 0.055
		br.bottom_radius = 0.065
		br.height = (ha - la).length() * 0.6
		br.radial_segments = 10
		_peca_osso("lowerarm_" + lado, br, metal if pesada else couro, la.lerp(ha, 0.55), Basis(Quaternion(Vector3.UP, dir_b)))
		var dir_p: Vector3 = (ft - ca).normalized()
		var gr := CylinderMesh.new()
		gr.top_radius = 0.075
		gr.bottom_radius = 0.06
		gr.height = (ft - ca).length() * 0.65
		gr.radial_segments = 10
		_peca_osso("calf_" + lado, gr, base, ca.lerp(ft, 0.45), Basis(Quaternion(Vector3.UP, -dir_p)))
		if pesada:   # coxote
			var dir_c: Vector3 = (ca - th).normalized()
			var cx := CylinderMesh.new()
			cx.top_radius = 0.1
			cx.bottom_radius = 0.085
			cx.height = (ca - th).length() * 0.5
			cx.radial_segments = 10
			_peca_osso("thigh_" + lado, cx, metal, th.lerp(ca, 0.35), Basis(Quaternion(Vector3.UP, -dir_c)) * Basis.from_scale(Vector3(1.0, 1.0, 0.9)))


# casca de armadura moldada no corpo: triângulos do tronco entre duas alturas, empurrados pela normal
func _casca_ajustada(mat: Material, folga: float, y0: float, y1: float, z_costas: float, meia_larg: float, placas: bool, fonte := "", nome := "PeitoralAjustado") -> void:
	var corpo: MeshInstance3D = null
	for m in skel.find_children("*", "MeshInstance3D", false, false):
		if fonte == "" or m.name == fonte:
			corpo = m
			break
	if corpo == null:
		return
	var a := corpo.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var dentro := func(p: Vector3) -> bool:
		return p.y > y0 and p.y < y1 and p.z > z_costas and absf(p.x) < meia_larg
	var novo := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		if dentro.call(v[idx[t]]) and dentro.call(v[idx[t + 1]]) and dentro.call(v[idx[t + 2]]):
			novo.append_array([idx[t], idx[t + 1], idx[t + 2]])
	if novo.is_empty():
		return
	var v2 := v.duplicate()
	var cols := PackedColorArray()
	cols.resize(v.size())
	for i in v.size():
		v2[i] = v[i] + n[i] * folga
		# faixas horizontais de placas (lâminas sobrepostas) pela cor: mais escuro na emenda
		var faixa := fposmod((v[i].y - y0) / 0.075, 1.0)
		var k := 0.72 if (placas and faixa < 0.12) else 1.0
		cols[i] = Color(k, k, k)
	a[Mesh.ARRAY_VERTEX] = v2
	a[Mesh.ARRAY_INDEX] = novo
	a[Mesh.ARRAY_COLOR] = cols
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, corpo.mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = am
	var m2: StandardMaterial3D = (mat as StandardMaterial3D).duplicate()
	m2.vertex_color_use_as_albedo = true
	m2.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m2
	skel.add_child(mi)
	mi.skin = corpo.skin
	mi.skeleton = NodePath("..")


static var _barba: ArrayMesh


# barba em coordenadas do corpo masculino de repouso (metros, rosto para +Z); mechas em tons alternados
static func _malha_barba() -> ArrayMesh:
	if _barba != null:
		return _barba
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 22
	var nv := 14
	var pts := []
	for vi in nv + 1:
		var v := float(vi) / nv
		var linha := []
		for ui in nu + 1:
			var u := float(ui) / nu * 2.0 - 1.0
			var ang := u * deg_to_rad(105.0)
			var afina := 1.0 - 0.75 * pow(v, 1.6)
			var rx := 0.074 * afina
			var rz := 0.088 * (1.0 - 0.35 * v) + 0.02 * sin(v * PI)
			var y := 1.648 - v * 0.235 - 0.03 * (1.0 - cos(u * PI * 0.5)) * (1.0 - v)
			var mecha := 0.004 * sin(u * 31.0 + v * 7.0)
			linha.append(Vector3(sin(ang) * (rx + mecha), y, -0.004 + cos(ang) * (rz + mecha)))
		pts.append(linha)
	for vi in nv:
		for ui in nu:
			var tom := 0.85 + 0.15 * float((ui * 7 + vi * 3) % 5) / 4.0
			var c := Color(tom, tom, tom)
			var a: Vector3 = pts[vi][ui]
			var b: Vector3 = pts[vi][ui + 1]
			var d: Vector3 = pts[vi + 1][ui]
			var e: Vector3 = pts[vi + 1][ui + 1]
			for q in [a, d, b, b, d, e]:
				st.set_color(c)
				st.add_vertex(q)
	# bigode: duas mechas curvas sobre a boca
	for lado in [-1.0, 1.0]:
		for k in 6:
			var t0 := float(k) / 6.0
			var t1 := float(k + 1) / 6.0
			var p0 := Vector3(lado * (0.006 + t0 * 0.045), 1.652 - t0 * t0 * 0.035, 0.093 - t0 * 0.02)
			var p1 := Vector3(lado * (0.006 + t1 * 0.045), 1.652 - t1 * t1 * 0.035, 0.093 - t1 * 0.02)
			var w0 := 0.008 * (1.0 - t0 * 0.7)
			var w1 := 0.008 * (1.0 - t1 * 0.7)
			var c2 := Color(0.95, 0.95, 0.95)
			for q in [p0 + Vector3(0, w0, 0), p0 - Vector3(0, w0, 0), p1 + Vector3(0, w1, 0), p1 + Vector3(0, w1, 0), p0 - Vector3(0, w0, 0), p1 - Vector3(0, w1, 0)]:
				st.set_color(c2)
				st.add_vertex(q)
	st.generate_normals()
	_barba = st.commit()
	return _barba


# V3: aldeão = túnica (formas corretivas + RBF), calça e botas novas; outras armaduras usam a roupa oficial no corpo novo
# ---------- cor do grau (pedido de Robson 21/11: peças de graus diferentes não podem parecer iguais) ----------
# NG fica como sempre foi; D bronze, C aço claro, B azurita, A rubro, S celestial (ouro claro).
const COR_GRAU := {"d": Color(0.8, 0.52, 0.28), "c": Color(1.0, 1.0, 1.0), "b": Color(0.45, 0.62, 0.95), "a": Color(0.82, 0.26, 0.22), "s": Color(1.0, 0.8, 0.42)}
const FORCA_GRAU := {"d": 0.7, "c": 0.5, "b": 0.75, "a": 0.72, "s": 0.78}

static func grau_do_item(id: String) -> String:
	var g := id.get_slice("_", id.get_slice_count("_") - 1)
	return g if g in ["ng", "d", "c", "b", "a", "s"] else ""


# armas e escudos: só as partes de metal (cor pouco saturada e clara) mudam; madeira e couro ficam
static func cor_grau_metal(raiz: Node, grau: String) -> void:
	if raiz == null or not COR_GRAU.has(grau):
		return
	var alvo: Color = COR_GRAU[grau]
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for k in mi.mesh.get_surface_count():
			var mt = mi.get_active_material(k)
			if not (mt is BaseMaterial3D):
				continue
			var c: Color = mt.albedo_color
			if c.s > 0.22 or c.v < 0.42:
				continue  # madeira, couro, pano escuro
			var d := (mt as BaseMaterial3D).duplicate() as BaseMaterial3D
			d.albedo_color = Color(alvo.r * c.v * 1.15, alvo.g * c.v * 1.15, alvo.b * c.v * 1.15)
			d.metallic = maxf(d.metallic, 0.7)
			d.roughness = minf(d.roughness, 0.38)
			mi.set_surface_override_material(k, d)


# roupa: a cor do grau por cima da textura (mais forte nas placas, mais leve no couro e no tecido);
# luvas e botas pintam as mãos e os pés com o grau delas
func _cor_grau_roupa(eq: Dictionary) -> void:
	var armor := str(eq.get("armadura", ""))
	var g_corpo := grau_do_item(armor)
	var g_maos := grau_do_item(str(eq.get("luvas", "")))
	var g_pes := grau_do_item(str(eq.get("botas", "")))
	var leve := 0.55 if (armor.begins_with("leve") or armor.begins_with("robe")) else 1.0
	for m in skel.find_children("*", "MeshInstance3D", false, false):
		var mi := m as MeshInstance3D
		var nm := String(mi.name).to_lower()
		if mi.mesh == null or not (nm.contains("knight") or nm.contains("ranger") or nm.contains("wizard") or nm.contains("peasant") or nm.contains("rp_")):
			continue
		var g := g_corpo
		if nm.contains("feet") or nm.contains("boot") or nm.contains("botas"):
			g = g_pes if g_pes != "" else g_corpo
		elif nm.contains("bracer") or nm.contains("glove") or nm.contains("hand"):
			g = g_maos if g_maos != "" else g_corpo
		if not COR_GRAU.has(g):
			continue
		var f: float = FORCA_GRAU[g] * leve
		var tinta: Color = Color(1, 1, 1).lerp(COR_GRAU[g] * 1.18, f)
		for k in mi.mesh.get_surface_count():
			var mt = mi.get_active_material(k)
			if not (mt is BaseMaterial3D) or String(mt.resource_name).begins_with("MI_Regular"):
				continue  # pele dos braços fica como está
			var d := (mt as BaseMaterial3D).duplicate() as BaseMaterial3D
			d.albedo_color = Color(tinta.r, tinta.g, tinta.b, 1.0)
			mi.set_surface_override_material(k, d)


func _vestir_v3(male: bool, outfit: String, hair_col: Color, com_cabelo := true) -> void:
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
	# (a textura feminina estourava em fios dourados com 14x: parecia um enfeite na cabeça)
	var hc := Color(hair_col.r, hair_col.g, hair_col.b) * (7.0 if male else 6.5)
	hc.a = 1.0
	if not com_cabelo:
		return
	if male:
		for m in _attach_v3("ca_curto_01"):
			_tint(m, hc)
			cabelos.append(m)
	else:
		for m in _attach_v3("ca_tranca_longa"):
			_tint(m, hc)
			cabelos.append(m)
			m.visibility_range_end = 12.0
			m.visibility_range_end_margin = 1.0
		for m in _attach_v3("ca_tranca_longa_lod1"):
			_tint(m, hc)
			cabelos.append(m)
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
		if String(m.name).contains("Hood"):
			# o capuz deixou de fazer parte da roupa: virou item de cabeça (Cabeca.capuz, slot "elmo"),
			# para não atrapalhar elmos, coroas e acessórios. No lugar fica uma gola de pano dobrada (capuz abaixado)
			m.queue_free()
			_gola(Color(0.2, 0.33, 0.16) if file.contains("ranger") else Color(0.35, 0.3, 0.25))
			continue
		if file.begins_with("hair_"):
			cabelos.append(m)
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
	if kind in ["cajado", "cetro"]:  # cajado de verdade (antes era a lança)
		return load("res://scripts/armas_proc.gd").cajado(length, at, kind == "cetro")
	for f in [item_id, kind + "_ng"]:
		if ResourceLoader.exists(ARMAS + f + ".glb"):
			var w: Node3D = cena(ARMAS + f + ".glb").instantiate()
			var holder := Node3D.new()
			holder.add_child(w)
			w.scale = Vector3.ONE * s
			return holder
	return _place(file, length, at)


# pegada de arma por raça (MESA-013 + pedido de Robson 12:17: "forma de segurar armas própria, que não
# se pareça com a humana"). guarda = eixo da arma e posição das mãos na guarda de duas mãos (corpo de 1,8 m);
# uma_mao = giro do punho com arma de uma mão [inclina para frente, gira para fora]. Valores abertos a ajuste.
const PEGADA_RACA := {
	"humano": {"guarda": [Vector3(0.22, 0.86, 0.46), Vector3(-0.04, 0.98, 0.3)], "uma_mao": [0.0, 0.0]},
	"elfo": {"guarda": [Vector3(0.1, 0.96, 0.28), Vector3(-0.02, 1.1, 0.27)], "uma_mao": [-0.18, -0.08]},
	"sombrio": {"guarda": [Vector3(-0.05, 0.6, 0.8), Vector3(0.0, 1.04, 0.33)], "uma_mao": [-0.42, -0.12]},
	"orc": {"guarda": [Vector3(0.5, 0.72, 0.2), Vector3(-0.14, 0.92, 0.3)], "uma_mao": [0.12, 0.38]},
	"goblin": {"guarda": [Vector3(0.3, 0.6, 0.62), Vector3(-0.06, 0.86, 0.34)], "uma_mao": [-0.5, 0.2]},
	"gigante": {"guarda": [Vector3(0.38, 0.68, 0.6), Vector3(-0.06, 0.84, 0.38)], "uma_mao": [0.18, 0.1]},
	"anao": {"guarda": [Vector3(0.26, 0.8, 0.54), Vector3(-0.02, 0.82, 0.28)], "uma_mao": [0.1, 0.15]},
	"beastman": {"guarda": [Vector3(0.14, 0.55, 0.82), Vector3(-0.04, 1.0, 0.37)], "uma_mao": [-0.38, 0.1]},
	"draconato": {"guarda": [Vector3(0.32, 0.84, 0.42), Vector3(-0.07, 1.02, 0.31)], "uma_mao": [0.05, 0.22]},
}


func _pegada() -> Dictionary:
	var k := race_id
	if race_id == "orc" and subtipo == "goblin":
		k = "goblin"
	return PEGADA_RACA.get(k, PEGADA_RACA.humano)


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
	cor_grau_metal(wnode, grau_do_item(item_id))
	Enfeites.arma(wnode, Enfeites.indice(item_id), kind)
	if kind == "arco":
		arco_costas = wnode.transform
	elif float(g.get("two", 0.0)) <= 0.0:
		# pegada natural (pedido de Robson 20/11): as faces largas da lâmina para a esquerda e a direita da mão,
		# um fio para cima e outro para baixo; a inclinação da mão vem da pose (a mesma para todas as raças)
		wnode.transform = _alinhar_lamina(wnode.transform, wnode)
	grip.add_child(wnode)
	grip_node = grip
	var two := float(g.get("two", 0.0))
	if two > 0.0:
		# postura de guarda: arma à frente do corpo, na diagonal, com as duas mãos no cabo
		var k := height_m / 1.8
		var pg: Array = _pegada().guarda
		var up: Vector3 = (pg[0] as Vector3).normalized()
		guard = Node3D.new()
		var gx := Vector3(1, 0, 0).cross(up).normalized()
		guard.transform = Transform3D(Basis(up.cross(gx).normalized(), gx, up), (pg[1] as Vector3) * k)
		add_child(guard)
		var hand_r := Node3D.new()
		guard.add_child(hand_r)
		var hand_l := Node3D.new()
		hand_l.position = Vector3(0, 0, -(float(g.at) - two) * s)
		guard.add_child(hand_l)
		# o IK leva o PULSO ao alvo; a palma fica uns 6 cm adiante, na direção do antebraço. Recua cada alvo
		# para a palma (e não o pulso) cair em cima do cabo — antes as mãos ficavam ao lado da arma.
		for par in [[hand_r, Vector3(-0.19, 1.42, 0.0) * k], [hand_l, Vector3(0.19, 1.42, 0.0) * k]]:
			var mao: Node3D = par[0]
			var ponto: Vector3 = guard.transform * mao.position
			var dirb := (ponto - (par[1] as Vector3)).normalized()
			mao.position += guard.basis.inverse() * (-dirb * 0.065 * k)
		ik_r = _arm_ik("r", hand_r, Vector3(-0.6, 0.45, -0.5) * k)
		ik = _arm_ik("l", hand_l, Vector3(0.6, 0.45, -0.5) * k)
		mao_l_guarda = hand_l
		# no golpe a arma fica na mão direita e a esquerda continua no cabo: o alvo dela é um ponto do próprio
		# cabo (no mesmo lugar da guarda, medido a partir da mão direita), então ela acompanha o giro da arma
		var um2: Array = _pegada().uma_mao
		var giro := Transform3D(Basis.from_euler(Vector3(float(um2[0]), 0.0, float(um2[1]))), Vector3.ZERO)
		arma_base = wnode.transform
		arma_golpe = _alinhar_lamina(giro * wnode.transform, wnode)
		mao_l_golpe = Node3D.new()
		mao_l_golpe.name = "SegundaMao"
		mao_l_golpe.position = giro * Vector3(0, 0, -(float(g.at) - two) * s)
		grip.add_child(mao_l_golpe)
	if g.get("dual", false):
		var g2 := _hand_grip("l")
		if g2 != null:
			offhand = _model(item_id, kind, str(g.file), float(g.len) * s, at, s)
			offhand.transform = _alinhar_lamina(offhand.transform, offhand)
			g2.add_child(offhand)
			offhand.visible = false
	if has_shield and two <= 0.0 and side == "r":
		_make_shield(s, shield_id)
	_make_sheath(bool(g.get("back", false)), kind in ["adaga", "punhal"])
	if kind != "arco":
		_montar_empunho(kind, grip, offhand.get_parent() if offhand != null else null, has_shield)
	else:
		_montar_empunho_arco(grip)
	if kind == "arco" and postura != null:
		postura.ereto = 1.0          # arqueiro: postura própria, mais ereta e de busto firme (parado e no tiro)
		postura.ereto_combate = 1.0
	if kind == "arco":
		# arco segurado por IK num suporte próprio: a mão vai até o arco (serve para todas as raças)
		arqueria = load("res://scripts/arqueria.gd").new()
		add_child(arqueria)
		arqueria.montar(self, wnode, s)
		fist_hands = ["l", "r"]
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
	if mao_l_golpe != null:
		wnode.transform = arma_base if on else arma_golpe
	# as duas mãos ficam sempre no cabo: na guarda as duas vão até a arma parada; no golpe a direita conduz
	# a arma (animação) e a esquerda segue o cabo pelo IK
	if mao_l_golpe != null:
		(ik as TwoBoneIK3D).set_target_node(0, (ik as TwoBoneIK3D).get_path_to(mao_l_guarda if on else mao_l_golpe))
	ik.active = true
	ik_r.active = on
	if postura != null:
		postura.bracos_livres = not on


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
	cor_grau_metal(shield, grau_do_item(shield_id))
	Enfeites.arma(shield, Enfeites.indice(shield_id), "escudo")
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


# ---------- postura com a arma (referências de MMO clássico enviadas por Robson, 20/11) ----------
# Parado e fora de combate: corpo ereto, arma na mão baixa, ponta apontando para o chão à frente e para fora.
# Cajado: cabeça do cajado para baixo, à frente. Duas espadas: uma em cada mão, as duas lâminas baixas e abertas.
# Em combate: mão à frente da cintura, lâmina para a frente e para cima (armas de duas mãos usam a guarda).
# Vetores no espaço do personagem para o lado DIREITO (+Z frente, +Y cima, -X direita); o esquerdo é espelhado.
# mao = direção do ombro até a pegada (vezes k x comprimento do braço); lamina = para onde a arma aponta;
# polo = para onde vai o cotovelo. Medidas pelo braço de cada raça, então valem para todas.
const POSE_ARMA := {
	"normal": {"mao": Vector3(-0.14, -0.95, 0.22), "k": 0.93, "lamina": Vector3(-0.26, -0.78, 0.57), "polo": Vector3(-0.3, -0.35, -0.9)},
	"normal_duas": {"mao": Vector3(-0.16, -0.95, 0.2), "k": 0.93, "lamina": Vector3(-0.22, -0.5, 0.84), "polo": Vector3(-0.3, -0.35, -0.9)},
	# cajado (21/11): postura formal de mago, cajado em pé ao lado do corpo, mão na altura da cintura
	"normal_cajado": {"mao": Vector3(-0.3, -0.72, 0.62), "k": 0.8, "lamina": Vector3(-0.04, 1.0, 0.1), "polo": Vector3(-0.4, -0.5, -0.75)},
	"normal_dupla": {"mao": Vector3(-0.22, -0.95, 0.12), "k": 0.94, "lamina": Vector3(-0.38, -0.84, 0.39), "polo": Vector3(-0.4, -0.3, -0.85)},
	"combate": {"mao": Vector3(-0.08, -0.8, 0.6), "k": 0.88, "lamina": Vector3(-0.22, 0.5, 0.84), "polo": Vector3(-0.7, -0.7, -0.2)},
	# arco (21/11): segurado pelo meio, em pé ao lado do corpo (as duas pontas longe das costas), ponta de cima um pouco à frente
	"normal_arco": {"mao": Vector3(-0.18, -0.95, 0.16), "k": 0.93, "lamina": Vector3(-0.12, -0.96, -0.22), "polo": Vector3(-0.3, -0.35, -0.9)},
	"combate_dupla": {"mao": Vector3(0.02, -0.6, 0.8), "k": 0.86, "lamina": Vector3(-0.12, 0.34, 0.93), "polo": Vector3(-0.7, -0.7, -0.2)},
	"combate_dupla_l": {"mao": Vector3(-0.05, -0.78, 0.6), "k": 0.88, "lamina": Vector3(-0.28, 0.12, 0.95), "polo": Vector3(-0.7, -0.6, -0.3)},
}


# transformação de um nó relativa ao personagem, sem depender da árvore estar pronta
func _rel_self(n: Node) -> Transform3D:
	var t := Transform3D()
	while n != null and n != self:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


# quadro da pegada para uma pose: origem na mão, +Z na lâmina, +Y voltado para o pulso
func _quadro_pose(lado: String, chave: String) -> Array:
	var p: Dictionary = POSE_ARMA[chave]
	var sx := 1.0 if lado == "r" else -1.0
	var rs := _rel_self(skel)
	var ub := skel.find_bone("upperarm_" + lado)
	var lb := skel.find_bone("lowerarm_" + lado)
	var hb := skel.find_bone("hand_" + lado)
	var mb := skel.find_bone("middle_01_" + lado)
	var om: Vector3 = rs * skel.get_bone_global_rest(ub).origin
	var cot: Vector3 = rs * skel.get_bone_global_rest(lb).origin
	var pu: Vector3 = rs * skel.get_bone_global_rest(hb).origin
	var dedo: Vector3 = rs * skel.get_bone_global_rest(mb).origin if mb >= 0 else pu
	var braco := om.distance_to(cot) + cot.distance_to(pu) + pu.distance_to(dedo) * 0.55
	var esp := func(v: Vector3) -> Vector3: return Vector3(v.x * sx, v.y, v.z)
	var mao: Vector3 = om + (esp.call(p.mao) as Vector3).normalized() * braco * float(p.k)
	var z: Vector3 = (esp.call(p.lamina) as Vector3).normalized()
	var dica := (om - mao).normalized()
	if p.get("reto", false):  # punho reto: a arma (arco) fica a 90 graus do antebraço, as duas pontas iguais
		z = (z - dica * z.dot(dica)).normalized()
	var y := (dica - z * dica.dot(z)).normalized()
	var x := y.cross(z).normalized()
	var polo: Vector3 = om + (esp.call(p.polo) as Vector3) * braco
	return [Transform3D(Basis(x, y, z), mao), polo]


# gira a arma em volta do próprio eixo (Z) para a parte fina da lâmina ficar no eixo X da pegada (para o lado,
# medido: X sai para fora do corpo nas duas poses): faces largas para os lados, um fio para cima e outro para baixo
func _alinhar_lamina(t: Transform3D, w: Node3D) -> Transform3D:
	var bb := AABB()
	var first := true
	for m in w.find_children("*", "MeshInstance3D", true, false):
		var rel := Transform3D()
		var n: Node = m
		while n != null and n != w:
			if n is Node3D:
				rel = (n as Node3D).transform * rel
			n = n.get_parent()
		var a: AABB = (t * rel) * (m as MeshInstance3D).get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	if first:
		return t
	if bb.size.y < bb.size.x * 0.85:
		return Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO) * t
	return t


func _montar_empunho(kind: String, grip_r: Node3D, grip_l: Node3D, com_escudo: bool) -> void:
	if skel.find_bone("upperarm_r") < 0 or skel.find_bone("middle_01_r") < 0:
		return
	var duas := float(GRIP[kind].get("two", 0.0)) > 0.0
	var dupla := bool(GRIP[kind].get("dual", false))
	var lados := {"r": grip_r}
	if dupla and grip_l != null:
		lados["l"] = grip_l
	empunho = load("res://scripts/empunhar.gd").new()
	empunho.name = "Empunhar"
	skel.add_child(empunho)
	for lado in lados:
		var nn := "normal"
		var cc := "combate"
		if dupla:
			nn = "normal_dupla"
			cc = "combate_dupla" if lado == "r" else "combate_dupla_l"
		elif kind in ["cajado"]:
			nn = "normal_cajado"
		elif duas:
			nn = "normal_duas"
		var qn := _quadro_pose(lado, nn)
		var qc: Variant = null if duas else _quadro_pose(lado, cc)
		var alvo := Node3D.new()
		alvo.name = "PegadaAlvo_" + lado
		alvo.transform = qn[0]
		add_child(alvo)
		var polo := Node3D.new()
		polo.position = qn[1]
		add_child(polo)
		_mao_alvo[lado] = [alvo, polo]
		_pose_mao[lado] = {"normal": qn, "combate": qc}
		empunho.alvo[lado] = alvo
		empunho.polo[lado] = polo
		empunho.pegada[lado] = lados[lado]
		empunho.peso[lado] = 1.0


# arco fora de combate: na mão esquerda, baixo e inclinado à frente (pedido de Robson 20/11, como nas referências)
func _montar_empunho_arco(grip_l: Node3D) -> void:
	if skel.find_bone("upperarm_l") < 0 or skel.find_bone("middle_01_l") < 0:
		return
	empunho = load("res://scripts/empunhar.gd").new()
	empunho.name = "Empunhar"
	skel.add_child(empunho)
	var qn := _quadro_pose("l", "normal_arco")
	var alvo := Node3D.new()
	alvo.transform = qn[0]
	add_child(alvo)
	var polo := Node3D.new()
	polo.position = qn[1]
	add_child(polo)
	_mao_alvo["l"] = [alvo, polo]
	_pose_mao["l"] = {"normal": qn, "combate": null}
	empunho.alvo["l"] = alvo
	empunho.polo["l"] = polo
	empunho.pegada["l"] = grip_l
	empunho.peso["l"] = 1.0  # já nasce segurando (sem transição da animação no primeiro quadro)


# arco parado na mão (pedido de Robson 20/11): a mão fecha no centro da empunhadura, a corda fica por dentro
# (voltada para o corpo, junto do braço) e o desenho do arco para fora; o arco fica baixo, apontado para o chão.
# Modelo do arco: comprimento em Z, corda em +X (x = 0,16), empunhadura em -X (x = -0,09).
func _arco_na_mao() -> Transform3D:
	var qn: Array = _pose_mao["l"].normal
	var quadro: Basis = (qn[0] as Transform3D).basis
	var dentro := quadro.inverse() * Vector3(0.35, -1.0, 0.0).normalized()  # (medido) eixo X do modelo para baixo: corda junto do braço, pontas e barriga do arco para o chão
	var zg := Vector3(0, 0, 1)
	var xg := (dentro - zg * dentro.dot(zg)).normalized()
	var b := Basis(xg, zg.cross(xg), zg)
	var pega := Vector3(-0.09, 0, 0) * float(arqueria.escala)
	return Transform3D(b, -(b * pega))


# a cada quadro: escolhe a pose (normal ou combate), suaviza a troca e desliga durante golpes e no arco
func _empunho_passo(dt: float) -> void:
	if empunho == null:
		return
	var golpe := is_busy() or _mart_alvo != null
	if arqueria != null and _pose_mao.has("l"):
		# arco: a mão esquerda segura o centro da empunhadura com o punho reto, parado e no tiro
		var no_tiro: bool = armed and arqueria.get("alvo_mao") != null
		empunho.alvo["l"] = arqueria.alvo_mao if no_tiro else _mao_alvo["l"][0]
		empunho.polo["l"] = (arqueria.polo_l if arqueria.polo_l != null else _mao_alvo["l"][1]) if no_tiro else _mao_alvo["l"][1]
		var na: Node3D = _mao_alvo["l"][0]
		na.transform = na.transform.interpolate_with(_pose_mao["l"].normal[0], clampf(dt * 6.0, 0.0, 1.0))
		empunho.meta["l"] = 1.0
		empunho.velocidade = 8.0
		return
	for lado in _pose_mao:
		var pm: Dictionary = _pose_mao[lado]
		var usa_combate: bool = armed and pm.combate != null
		var q: Array = pm.combate if usa_combate else pm.normal
		var no: Array = _mao_alvo[lado]
		var a: Node3D = no[0]
		var k := clampf(dt * 6.0, 0.0, 1.0)
		a.transform = a.transform.interpolate_with(q[0], k)
		(no[1] as Node3D).position = (no[1] as Node3D).position.lerp(q[1], k)
		var on := not golpe and not (guard != null and armed) and not (arqueria != null and armed)
		empunho.meta[lado] = 1.0 if on else 0.0
	empunho.velocidade = 4.0 if not golpe else 14.0


# em combate a arma vai para a mão; fora dele, para as costas ou a cintura
# (com a postura de arma na mão, a arma fica na mão também fora de combate, baixa e firme)
func set_battle(on: bool) -> void:
	if postura != null:
		postura.em_combate = on
	if asas != null and asas.estado != "planar":
		asas.estado = "combate" if on else "dobrada"
	if on == armed or wnode == null or sheath == null:
		armed = on
		return
	armed = on
	if empunho != null and arqueria == null:
		_arma_na_mao(on)
		return
	if fist != null:
		for h in ["r", "l"]:
			fist.amount[h] = 1.0 if (on and h in fist_hands) or (not on and arqueria != null and empunho != null and h == "l") else 0.0
	wnode.get_parent().remove_child(wnode)
	if arqueria != null:
		(arqueria.mira if on else (grip_node if empunho != null else sheath)).add_child(wnode)
		if not on:
			wnode.transform = _arco_na_mao() if empunho != null else arco_costas
		else:
			arqueria.mira.remove_child(wnode)
			arqueria.montar_arco(wnode)
		arqueria.ligar(on)
	else:
		(grip_node if on else sheath).add_child(wnode)
	if guard != null:
		guard_on = false
		if on:
			_set_guard(true)
		else:
			ik.active = false
			ik_r.active = false
			if postura != null:
				postura.bracos_livres = true
	if offhand != null:
		offhand.visible = on
	if shield != null and shield_arm != null and shield_back != null:
		shield.get_parent().remove_child(shield)
		var keep := shield.transform
		(shield_arm if on else shield_back).add_child(shield)
		shield.transform = keep


# com a postura de arma: a arma nunca vai para a bainha; muda só a pose (normal ou combate)
func _arma_na_mao(on: bool) -> void:
	if fist != null:
		for h in ["r", "l"]:
			fist.amount[h] = 1.0 if h in fist_hands and not (h == "l" and guard != null and not on) else 0.0
	if wnode.get_parent() != grip_node:
		wnode.get_parent().remove_child(wnode)
		grip_node.add_child(wnode)
	if guard != null:
		guard_on = false
		wnode.transform = arma_golpe
		if on:
			_set_guard(true)
		else:
			ik.active = false
			ik_r.active = false
			if postura != null:
				postura.bracos_livres = true
	if offhand != null:
		offhand.visible = true
	if shield != null and shield_arm != null:
		if shield.get_parent() != shield_arm:
			var keep := shield.transform
			shield.get_parent().remove_child(shield)
			shield_arm.add_child(shield)
			shield.transform = keep


func play(n: String, speed := 1.0) -> void:
	if guard != null and armed and not guard_on and not is_busy() and _mart_alvo == null:
		_set_guard(true)
	if n == "Idle" and armed and magic_idle and anim.has_animation("Spell_Simple_Idle"):
		n = "Spell_Simple_Idle"
	if not anim.has_animation(n):
		return
	var anda := n.contains("Walk") or n.contains("Run") or n.contains("Jog")
	if postura != null:
		postura.andando = 1.0 if anda else 0.0
	if anda:
		speed *= ciclo_raca
	if current == n:
		anim.speed_scale = speed
		return
	current = n
	anim.play(n, -1, 1.0)
	anim.speed_scale = speed


# gesto mágico da habilidade (por cima da animação, depois da pegada da arma para os braços aparecerem)
var gesto: SkeletonModifier3D
const GestoMagico := preload("res://scripts/gesto_magico.gd")

func tocar_gesto(nome: String, dur := 0.9) -> float:
	if skel == null:
		return 0.0
	if gesto == null:
		gesto = GestoMagico.new()
		gesto.name = "GestoMagico"
		gesto.raca = race_id if race_id != "" else "humano"
		gesto.feminino = not male_flag
		skel.add_child(gesto)
	skel.move_child(gesto, -1)
	return gesto.tocar(nome, dur)


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


# gola dobrada no pescoço (o capuz abaixado da roupa de patrulheiro); cobre a borda da roupa no pescoço
func _gola(cor: Color) -> void:
	var nb := skel.find_bone("neck_01")
	if nb < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "neck_01"
	skel.add_child(att)
	var rest := skel.get_bone_global_rest(nb)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.95
	# camisa de baixo: sem o capuz, a pele do peito aparecia no decote da túnica. Uma casca tirada do próprio
	# corpo (do peito até a base do pescoço) veste esse vão e acompanha a respiração e os movimentos
	var sb := skel.find_bone("spine_03")
	if sb >= 0 and skel.find_child("corpo", false, false) != null:
		var sp3 := skel.get_bone_global_rest(sb).origin
		var ua := skel.get_bone_global_rest(skel.find_bone("upperarm_l")).origin
		var ub := skel.get_bone_global_rest(skel.find_bone("upperarm_r")).origin
		var camisa := mat.duplicate() as StandardMaterial3D
		camisa.albedo_color = cor.lightened(0.12)
		_casca_ajustada(camisa, 0.004, sp3.y - 0.02, rest.origin.y + 0.025, -1.0, absf(ua.x - ub.x) * 0.5, false, "corpo", "CamisaGola")
	for k in 1:  # uma volta de pano justa na base do pescoço
		var tm := TorusMesh.new()
		tm.inner_radius = 0.052
		tm.outer_radius = 0.085
		tm.rings = 22
		tm.ring_segments = 8
		tm.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = tm
		att.add_child(mi)
		mi.transform = rest.affine_inverse() * Transform3D(Basis.from_scale(Vector3(1.1, 0.5, 1.0)), rest.origin + Vector3(0, -0.035, -0.01))


# põe na cabeça um item modelado na "cabeça unitária" (elmo, capuz, chapéu, coroa ou acessório novo): o encaixe
# é medido no crânio desta raça, então o mesmo item serve em todas. Passe null para tirar.
func vestir_cabeca(item: Node3D, esconde_cabelo := false) -> void:
	if cabeca_no == null:
		cabeca_no = load("res://scripts/cabeca.gd").encaixe(self)
		if cabeca_no == null:
			return
	for ch in cabeca_no.get_children():
		ch.queue_free()
	for m in cabelos:
		if is_instance_valid(m):
			(m as Node3D).visible = item == null or not esconde_cabelo
	if item != null:
		# molde: o item segue o formato real da cabeça (ou do cabelo, quando o cabelo continua à mostra)
		var molde: PackedFloat32Array = cabeca_no.get_meta("molde_cabelo" if not esconde_cabelo else "molde", PackedFloat32Array())
		if molde.size() > 0:
			load("res://scripts/cabeca.gd").moldar(item, molde)
		cabeca_no.add_child(item)


# tiro com arco (movimento humano completo: erguer, puxar a corda até a boca, soltar e baixar)
func disparar_arco() -> float:
	if arqueria == null:
		return action("Sword_Attack")
	play("Idle")
	var d: float = arqueria.disparar()
	busy_until = Time.get_ticks_msec() * 0.001 + d * 0.9
	return d


func is_busy() -> bool:
	return Time.get_ticks_msec() * 0.001 < busy_until


# perto > 0: o nome só aparece quando a câmera chega a essa distância (moradores e NPCs, 20/11)
func set_tag(text: String, color := Color(1, 0.92, 0.7), perto := 0.0) -> void:
	if not tag:
		tag = Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0, height_m + 0.25, 0)
		# nome com tamanho fixo na tela (pequeno e legível de perto ou de longe, como nos MMOs clássicos)
		tag.fixed_size = true
		tag.pixel_size = 0.00042
		tag.font_size = 44
		tag.outline_size = 10
		tag.outline_modulate = Color(0, 0, 0, 0.85)
		tag.no_depth_test = false
		add_child(tag)
	tag.text = text
	tag.modulate = color
	if perto > 0.0:
		tag.visibility_range_end = perto
		tag.visibility_range_end_margin = 2.0
		tag.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


# placa da loja pessoal sobre o nome (texto do dono, até 32 letras); "" tira a placa
var placa: Label3D

func set_placa(text: String) -> void:
	if text == "":
		if placa:
			placa.queue_free()
			placa = null
		return
	if not placa:
		placa = Label3D.new()
		placa.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		placa.position = Vector3(0, height_m + 0.62, 0)
		placa.fixed_size = true
		placa.pixel_size = 0.00045
		placa.font_size = 46
		placa.outline_size = 14
		placa.outline_modulate = Color(0.16, 0.09, 0.02, 0.95)
		placa.modulate = Color(1.0, 0.84, 0.42)
		add_child(placa)
	placa.text = "◆ %s ◆" % text


# sem o "boneco em cruz" ao nascer (pedido de Robson 20/11): o personagem fica oculto nos primeiros quadros,
# até a animação e a postura da arma estarem aplicadas no esqueleto; antes disso o motor mostraria a pose de repouso
var _aparecer := 0


func _ready() -> void:
	add_to_group("personagens")
	if anim != null and anim.current_animation != "":
		anim.advance(0.0)
	if visible:
		visible = false
		_aparecer = 3


# pés no chão: o pé que está apoiado (o mais baixo na animação) encosta no terreno embaixo dele.
# Corrige o corpo flutuando em descidas e o pé afundando em subidas; suaviza para não tremer.
func _process(dt: float) -> void:
	if _aparecer > 0:
		_aparecer -= 1
		if _aparecer == 0:
			visible = true
	_empunho_passo(dt)
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
			var chao := float(world_ref.floor_y(p.x, p.z, root_y + 0.5))
			if absf(chao - root_y) > 0.9:
				chao = root_y  # sem chão do mundo por perto (interior de casa, ponte alta): o piso é o da própria raiz
			gap = minf(gap, ((p as Vector3).y - ankle) - chao)
	var want := clampf(foot_off - gap, -0.35, 0.25)
	foot_off = lerpf(foot_off, want, clampf(dt * 10.0, 0.0, 1.0))
	body_node.position.y = body_base_y + foot_off / maxf(scale.y, 0.01)


# roupa de frio: capa de pele nas costas, gola felpuda e capuz (lugares gelados)
# roupa de ofício por cima da roupa comum (19/11, pedido de Robson: NPCs com características da função).
# avental: peito tirado do próprio corpo (veste e acompanha o movimento) + saia presa à pélvis até o joelho.
const OFICIOS := {
	"ferreiro": {"avental": "#3E2B1F", "rug": 0.75, "luvas": "#2A1F18", "faixa": "#6B4A2E"},
	"aprendiz": {"avental": "#5A4231", "rug": 0.85, "luvas": "", "faixa": ""},
	"estalajadeiro": {"avental": "#A8885E", "rug": 1.0, "luvas": "", "faixa": "#7A2E22"},
	"mercador": {"avental": "#4C5B3A", "rug": 0.95, "luvas": "", "faixa": "#B08A3E"},
	"cozinheiro": {"avental": "#E4DED0", "rug": 1.0, "luvas": "", "faixa": ""},
}


# túnica tingida (moradores): linho cru, castanho, oliva, ferrugem, anil, ocre e ameixa — cores de tintura natural
const TINGIMENTOS := [Color(1, 1, 1), Color(0.8, 0.68, 0.52), Color(0.58, 0.64, 0.46), Color(0.74, 0.47, 0.4),
	Color(0.52, 0.58, 0.72), Color(0.82, 0.72, 0.46), Color(0.62, 0.52, 0.62), Color(0.45, 0.4, 0.36)]


func tingir_roupa(semente: int) -> void:
	if skel == null:
		return
	var cor: Color = TINGIMENTOS[absi(semente) % TINGIMENTOS.size()]
	var cor_calca: Color = TINGIMENTOS[absi(semente / 7 + 3) % TINGIMENTOS.size()].darkened(0.25)
	for m in skel.find_children("*", "MeshInstance3D", false, false):
		if String(m.name).begins_with("tunica"):
			_tint(m, cor)
		elif String(m.name).begins_with("calca"):
			_tint(m, cor_calca)


func oficio(tipo: String, sem_tunica := false) -> void:
	if skel == null or not OFICIOS.has(tipo) or skel.find_bone("spine_01") < 0 or skel.find_bone("calf_l") < 0:
		return
	var cfg: Dictionary = OFICIOS[tipo]
	if tipo == "ferreiro" and wnode != null:
		wnode.scale *= 0.42  # martelo de forja, não o martelo de guerra
	var R := func(b: String) -> Vector3: return skel.get_bone_global_rest(skel.find_bone(b)).origin
	var pel: Vector3 = R.call("pelvis")
	var sp2: Vector3 = R.call("spine_02")
	var sp3: Vector3 = R.call("spine_03")
	var joelho: Vector3 = R.call("calf_l")
	var larg: float = (R.call("upperarm_l") - R.call("upperarm_r")).length() * 0.42
	var couro := _mat_simples(Color(str(cfg.avental)), 0.0, float(cfg.rug))
	# peito do avental tirado da própria túnica (frente, da cintura ao peito): veste certinho e acompanha cada movimento
	var tem_tunica := skel.find_child("tunica", false, false) != null
	if tem_tunica:
		_casca_ajustada(couro, 0.014, pel.y - 0.1, sp3.y + 0.16, sp2.z - 0.03, larg * 1.0, false, "tunica", "AventalPeito")
	# sem túnica (outra roupa): placa presa ao peito com alças
	var pa := BoneAttachment3D.new()
	pa.visible = not tem_tunica
	pa.bone_name = "spine_03"
	skel.add_child(pa)
	var inv3 := skel.get_bone_global_rest(skel.find_bone("spine_03")).affine_inverse()
	var alt_peito := sp3.y + 0.1 - (pel.y + 0.06)
	var pb := BoxMesh.new()
	pb.size = Vector3(larg * 1.05, alt_peito, 0.014)
	pb.material = couro
	var peito := MeshInstance3D.new()
	peito.name = "AventalPeito"
	peito.mesh = pb
	pa.add_child(peito)
	peito.transform = inv3 * Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(0, pel.y + 0.06 + alt_peito * 0.5, sp2.z + larg * 1.55))
	var al := BoxMesh.new()
	al.size = Vector3(0.025, 0.2, 0.012)
	al.material = couro
	for lado in [-1.0, 1.0]:
		var alca := MeshInstance3D.new()
		alca.mesh = al
		pa.add_child(alca)
		alca.transform = inv3 * Transform3D(Basis(Vector3.RIGHT, -0.7) * Basis(Vector3.FORWARD, lado * 0.25), Vector3(lado * larg * 0.42, sp3.y + 0.17, sp2.z + larg * 1.1))
	# saia do avental: painel preso à pélvis, da cintura até abaixo do joelho, levemente curvado
	var att := BoneAttachment3D.new()
	att.bone_name = "pelvis"
	skel.add_child(att)
	var alt := pel.y - joelho.y + 0.2
	var bm := BoxMesh.new()
	bm.size = Vector3(larg * 1.45, alt, 0.014)
	bm.material = couro
	var saia := MeshInstance3D.new()
	saia.name = "AventalSaia"
	saia.mesh = bm
	att.add_child(saia)
	var inv := skel.get_bone_global_rest(skel.find_bone("pelvis")).affine_inverse()
	var centro := Vector3(0, pel.y - alt * 0.5 + 0.1, pel.z + larg * 1.2)
	saia.transform = inv * Transform3D(Basis(Vector3.RIGHT, -0.06), centro)
	if str(cfg.faixa) != "":  # cinta na cintura
		var cm := CylinderMesh.new()
		cm.top_radius = larg * 0.78
		cm.bottom_radius = larg * 0.8
		cm.height = 0.05
		cm.radial_segments = 14
		cm.material = _mat_simples(Color(str(cfg.faixa)), 0.0, 0.8)
		var cinta := MeshInstance3D.new()
		cinta.mesh = cm
		att.add_child(cinta)
		cinta.transform = inv * Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.78)), Vector3(0, pel.y + 0.04, pel.z + 0.01))
	if str(cfg.luvas) != "":  # luvas grossas de couro (mãos e punhos)
		for lado in ["l", "r"]:
			var b: String = "hand_" + lado
			if skel.find_bone(b) < 0:
				continue
			var la := BoneAttachment3D.new()
			la.bone_name = b
			skel.add_child(la)
			var gm := CapsuleMesh.new()
			gm.radius = 0.04
			gm.height = 0.15
			gm.material = _mat_simples(Color(str(cfg.luvas)), 0.0, 0.9)
			var luva := MeshInstance3D.new()
			luva.mesh = gm
			la.add_child(luva)
			luva.rotation = Vector3(0, 0, PI * 0.5 if lado == "l" else -PI * 0.5)
			luva.position = Vector3(0.02 if lado == "l" else -0.02, 0, 0)


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


# Traje base de cada raça (20/11): a túnica de aldeão deixa de ser igual para todos. Cada raça tem tecido, debrum
# (a barra azul do modelo) e calça próprios, em tons naturais; o shader separa o tecido da barra pela cor original.
const TRAJES := {
	"humano": ["#d9cdb4", "#3c5a8c", "#5a4a3a"],     # linho cru, barra azul, calça marrom
	"elfo": ["#7f9a64", "#d8d2b0", "#3e4a32"],       # verde musgo, barra de prata clara, calça verde escura
	"sombrio": ["#3b3346", "#8c6fae", "#26222c"],    # ameixa escura, barra violeta, calça quase preta
	"orc": ["#8a6440", "#7a2a1e", "#4a3a2a"],        # couro curtido, barra vermelho sangue
	"anao": ["#8c3f2c", "#c9a24a", "#4a3626"],       # vermelho tijolo, barra dourada, calça de couro
	"beastman": ["#a8865c", "#4e3a24", "#5e4630"],   # pele crua, barra escura
	"gigante": ["#c8d6e0", "#3d6f96", "#6a7884"],    # lã clara, barra azul glacial, calça cinza
}
static var _traje_shader: Shader


func roupa_raca(race: String) -> void:
	if skel == null or not TRAJES.has(race):
		return
	if _traje_shader == null:
		_traje_shader = Shader.new()
		_traje_shader.code = """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform sampler2D nmap : hint_normal, filter_linear_mipmap;
uniform bool tem_nmap = false;
uniform vec3 tecido : source_color;
uniform vec3 barra : source_color;
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float lum = dot(c, vec3(0.3, 0.55, 0.15));
	float azul = smoothstep(0.04, 0.14, c.b - c.r);          // barra original azulada
	float escuro = 1.0 - smoothstep(0.18, 0.42, lum);        // cinto, costuras e sombras pintadas ficam como estão
	vec3 pano = mix(tecido * (0.42 + lum * 0.42), barra * (0.5 + lum * 0.5), azul);
	ALBEDO = mix(pano, c, escuro * (1.0 - azul));
	ROUGHNESS = 0.9;
	if (tem_nmap) { NORMAL_MAP = texture(nmap, UV).rgb; }
}
"""
	var cfg: Array = TRAJES[race]
	for m in skel.find_children("*", "MeshInstance3D", false, false):
		var nm := String(m.name)
		var mi := m as MeshInstance3D
		if nm.begins_with("tunica"):
			for i in mi.mesh.get_surface_count():
				var orig := mi.mesh.surface_get_material(i) as BaseMaterial3D
				if orig == null or orig.albedo_texture == null:
					# parte lisa da túnica (forro da gola): antes ficava branca no decote
					var liso := StandardMaterial3D.new()
					liso.albedo_color = Color(str(cfg[0])).darkened(0.25)
					liso.roughness = 0.9
					mi.set_surface_override_material(i, liso)
					continue
				var sm := ShaderMaterial.new()
				sm.shader = _traje_shader
				sm.set_shader_parameter("tex", orig.albedo_texture)
				if orig.normal_enabled and orig.normal_texture != null:
					sm.set_shader_parameter("nmap", orig.normal_texture)
					sm.set_shader_parameter("tem_nmap", true)
				sm.set_shader_parameter("tecido", Color(str(cfg[0])))
				sm.set_shader_parameter("barra", Color(str(cfg[1])))
				mi.set_surface_override_material(i, sm)
		elif nm.begins_with("calca"):
			_tint(mi, Color(str(cfg[2])).lightened(0.35))


# ---------- ferreiro martelando na bigorna (20/11, Robson: "animar por código") ----------
# Sem animação de ofício gratuita: a mão direita, com o martelo, sobe e desce num arco acima da bigorna pelo IK do
# braço; a esquerda segura a peça na mesa da bigorna. O corpo segue na animação parada, então serve a qualquer raça.
class _Martelada extends Node:
	var c: Node3D
	var t := 0.0
	func _process(dt: float) -> void:
		t += dt
		c._martelo_passo(t)

var _mart_alvo: Node3D
var _mart_dist := 0.85
var _mart_topo := 0.77


# dist e topo em metros do mundo: distância até a bigorna à frente e altura da mesa dela
func martelar(dist := 0.85, topo := 0.77) -> void:
	if skel == null or wnode == null:
		return
	var esc := maxf(scale.x, 0.01)
	_mart_dist = dist / esc
	_mart_topo = topo / esc
	set_battle(true)
	# martelo numa mão só, alinhado como ferramenta
	if guard != null:
		guard_on = false
		wnode.get_parent().remove_child(wnode)
		grip_node.add_child(wnode)
		if mao_l_golpe != null:
			wnode.transform = arma_golpe
		if ik_r != null:
			ik_r.active = false
	# martelo de ferramenta: cabo curto na mão, cabeça virada para a frente para bater na bigorna
	wnode.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3.ZERO) * wnode.transform
	if postura != null:
		postura.bracos_livres = false
	var k := height_m / 1.8
	_mart_alvo = Node3D.new()
	add_child(_mart_alvo)
	_arm_ik("r", _mart_alvo, Vector3(-0.55, 1.25, -0.35) * k).active = true
	var peca := Node3D.new()
	peca.position = Vector3(0.1, _mart_topo + 0.1, _mart_dist - 0.22)
	add_child(peca)
	if ik != null:
		(ik as TwoBoneIK3D).set_target_node(0, (ik as TwoBoneIK3D).get_path_to(peca))
		ik.active = true
	else:
		_arm_ik("l", peca, Vector3(0.6, 1.0, -0.4) * k).active = true
	play("Idle")
	var m := _Martelada.new()
	m.c = self
	add_child(m)


func _martelo_passo(t: float) -> void:
	if _mart_alvo == null:
		return
	var k := height_m / 1.8
	var f := fposmod(t, 1.15) / 1.15
	var bate := Vector3(-0.12, _mart_topo + 0.24 * k, _mart_dist - 0.32)   # mão quando a cabeça do martelo toca a bigorna
	var alto := Vector3(-0.2, _mart_topo + 0.85 * k, _mart_dist - 0.62)    # mão no alto, martelo erguido
	var p: Vector3
	if f < 0.55:      # sobe devagar
		p = bate.lerp(alto, ease(f / 0.55, 0.6))
	elif f < 0.68:    # desce rápido
		p = alto.lerp(bate, ease((f - 0.55) / 0.13, 2.4))
	else:             # repique e pausa na bigorna
		p = bate + Vector3(0, sin((f - 0.68) / 0.32 * PI) * 0.05 * k, 0)
	_mart_alvo.position = p
