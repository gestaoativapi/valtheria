extends SceneTree
# Vídeo das Relíquias em combate (27/11): o herói golpeia um boneco com cada arma S/SS; mostra o rastro de luz,
# o clarão do impacto e, no SS, o espírito da criatura. Uso (grava com o próprio Godot):
#   godot --path . --write-movie /tmp/rel.avi --fixed-fps 30 -s teste/video_reliquia.gd -- --lista=espada_ss,lanca_ss

const C = preload("res://scripts/character.gd")
const R = preload("res://scripts/reliquias.gd")

var lista := "espada_ss,martelo_ss,lanca_ss,cajado_ss"
var q := 0
var heroi: Node3D
var alvo: Node3D
var idx := -1
var prox := 0
var golpes := 0
var cam: Camera3D
const POR_ARMA := 3
const INTERVALO := 40  # quadros entre golpes


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lista="): lista = a.trim_prefix("--lista=")


func _cena() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.52, 0.6)
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.1
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation = Vector3(-0.8, 0.7, 0)
	sol.light_energy = 1.2
	root.add_child(sol)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	chao.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.18, 0.17, 0.16)
	chao.material_override = cm
	root.add_child(chao)
	alvo = C.create({"race": "orc", "gender": "m", "equipment": {}})
	root.add_child(alvo)
	alvo.position = Vector3(0, 0, 1.4)
	alvo.rotation.y = PI
	cam = Camera3D.new()
	root.add_child(cam)
	cam.fov = 45.0
	cam.position = Vector3(3.4, 1.7, 0.5)
	cam.look_at(Vector3(0, 1.0, 0.7))
	cam.current = true


func _arma(id: String) -> void:
	if heroi != null:
		heroi.queue_free()
	var kind := id.get_slice("_", 0)
	var eq := {"arma": id} if kind != "escudo" else {"arma": "espada_ng", "escudo": id}
	heroi = C.create({"race": "humano", "gender": "m", "equipment": eq})
	root.add_child(heroi)
	heroi.position = Vector3.ZERO
	if heroi.has_method("set_armed"):
		heroi.call("set_armed", true)
	var lb := Label3D.new()
	lb.text = R.nome(kind, 6 if id.ends_with("_ss") else 5)
	lb.font_size = 64
	lb.outline_size = 12
	lb.pixel_size = 0.004
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.position = Vector3(0, 2.15, 0)
	heroi.add_child(lb)


func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		_cena()
	var itens := lista.split(",")
	if q >= prox:
		if idx < 0 or golpes >= POR_ARMA:
			idx += 1
			golpes = 0
			if idx >= itens.size():
				return true
			_arma(itens[idx])
			prox = q + 15
			return false
		golpes += 1
		var w: Node3D = heroi.get("wnode")
		var n := "Sword_Attack" if golpes != 2 else "Sword_Regular_B"
		var dur: float = heroi.call("action", n)
		var forte := golpes == POR_ARMA
		var em := int(maxf(dur * 0.45, 0.2) * 30.0)
		get_root_timer(em, func():
			if is_instance_valid(w):
				R.impacto(root, w, alvo.position + Vector3(0, 1.1, -0.25), heroi.position, forte))
		prox = q + INTERVALO
	return false


var _agenda: Array = []


func get_root_timer(quadros: int, f: Callable) -> void:
	var t := create_timer(quadros / 30.0)
	t.timeout.connect(f)
