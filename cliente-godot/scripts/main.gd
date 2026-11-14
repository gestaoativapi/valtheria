extends Node3D
# Valtheria - cliente nativo (protótipo): liga o mundo, o personagem, a câmera, a rede e as telas.

const World = preload("res://scripts/world.gd")
const Character = preload("res://scripts/character.gd")
const Net = preload("res://scripts/net.gd")
const UI = preload("res://scripts/ui.gd")
const Combat = preload("res://scripts/combat.gd")
const Social = preload("res://scripts/social.gd")
const Atmos = preload("res://scripts/atmos.gd")
const Npcs = preload("res://scripts/npcs.gd")
const FX = preload("res://scripts/fx.gd")

const QUALITY := ["Mínima", "Baixa", "Média", "Alta", "Ultra"]
const WALK := 1.9
const RUN := 5.2
const SPRINT := 8.2

var world: Node3D
var net: Node
var ui: CanvasLayer
var cam: Camera3D
var player: Node3D
var marker: MeshInstance3D
var crowd: Array = []

var playing := false
var quality := 3
var vsync := true
var yaw := 0.6
var pitch := -0.32
var dist := 7.5
var orbiting := false
var target := Vector3.ZERO
var has_target := false
var facing := 0.0
var sel := {}  # alvo que não é monstro: {"kind": "self"|"player"|"npc", ...}
var emote := ""
var jumping := false
var jump_t := 0.0
var shot_path := ""
var shot_frames := 0
var shot_wait := 40
var smooth_fps := 60.0
var compat := false
var me := {}  # personagem em jogo (registro do servidor)
var creating := false
var save_t := 0.0
var saved_pos := Vector3.ZERO
var home := Vector3(1503.5, 0.0, 2556.0)
var quitting := false
var combat: Node3D
var chasing := false
var social: Node3D
var atmos: Node3D
var npcs: Node3D
var dust: CPUParticles3D
var test_fight := false
var log_file: FileAccess
var log_t := 0.0
var forward := true
var showing := false  # tela de entrada mostrando o personagem escolhido
var gm := false  # conta de GM
var gm_god := false
var gm_speed := false
var gm_fly := false
var gm_hide := false
var fly_y := 0.0
var interiores: Node3D
var swimming := false


func _ready() -> void:
	_log_open()
	compat = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	forward = RenderingServer.get_current_rendering_method() == "forward_plus"
	world = World.new()
	add_child(world)
	world.build()
	Character.world_ref = world
	note("mundo montado (cidades e dados)")
	Character.RACES = world.info.races
	Character.HAIR_COLORS = world.info.hair_colors
	net = Net.new()
	add_child(net)
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.15
	cam.far = 1500.0
	add_child(cam)
	cam.make_current()
	player = Character.create({"equipment": {"armadura": "pesada_ng", "arma": "espada_ng"}})
	add_child(player)
	_place_player(home)
	facing = 2.6
	player.rotation.y = facing
	get_tree().auto_accept_quit = false
	marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.32
	tm.outer_radius = 0.42
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1.0, 0.85, 0.4)
	mm.emission_enabled = true
	mm.emission = Color(1.0, 0.8, 0.3)
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.material = mm
	marker.mesh = tm
	marker.visible = false
	add_child(marker)

	ui = UI.new()
	ui.info = world.info
	add_child(ui)
	combat = Combat.new()
	add_child(combat)
	combat.setup(self)
	combat.message.connect(func(t): ui.say(t))
	ui.want_skill.connect(func(i): combat.use_skill(i))
	npcs = Npcs.new()
	add_child(npcs)
	npcs.setup(self)
	atmos = Atmos.new()
	add_child(atmos)
	atmos.setup(self)
	social = Social.new()
	add_child(social)
	social.setup(self)
	interiores = load("res://scripts/interiores.gd").new()
	add_child(interiores)
	interiores.setup(self)
	ui.want_window.connect(_window)
	ui.want_do.connect(_do)
	ui.want_self.connect(func():
		sel = {"kind": "self"}
		combat.target = null)
	ui.want_action.connect(_action)
	ui.want_chat.connect(_chat)
	ui.want_new_char.connect(_new_char)
	ui.want_preview.connect(_preview)
	ui.want_create.connect(_create)
	ui.want_show_char.connect(_show_char)
	ui.want_gm.connect(_gm)
	ui.want_back_to_chars.connect(func():
		creating = false
		_preview({"equipment": {"armadura": "pesada_ng", "arma": "espada_ng"}})
		ui.show_chars(ui.last_chars, ui.last_account))
	ui.want_login.connect(_login)
	ui.want_signup.connect(_signup)
	ui.want_offline.connect(func():
		gm = true  # sozinho no mundo: comandos de GM liberados para teste
		_enter({"name": "Viajante", "level": 1, "equipment": {"armadura": "pesada_ng", "arma": "espada_ng"}}))
	ui.want_char.connect(_enter)
	ui.want_quality.connect(func(): _set_quality((quality + 1) % QUALITY.size()))
	ui.want_vsync.connect(_toggle_vsync)
	ui.want_crowd.connect(_spawn_crowd)
	ui.want_api.connect(_switch_api)
	ui.want_exit_to_login.connect(_to_login)
	_load_prefs()
	_refresh_bar()
	note("telas prontas")
	_set_quality(quality)
	note("qualidade %s aplicada; carregando terreno aos poucos" % QUALITY[quality])
	var test_race := "humano"
	var test_gender := "m"
	var test_armor := "pesada_ng"
	var test_weapon := "espada_ng"
	var test_shield := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--race="):
			var rp := a.trim_prefix("--race=").split(",")
			test_race = rp[0]
			if rp.size() > 1: test_gender = rp[1]
			if rp.size() > 2: test_armor = rp[2]
			if rp.size() > 3: test_weapon = rp[3]
			if rp.size() > 4: test_shield = rp[4]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.trim_prefix("--shot=")
		elif a.begins_with("--lite"):
			var lite_q := a.trim_prefix("--lite=") if a.contains("=") else "0"  # teste em máquina sem placa de vídeo
			_set_quality(int(lite_q))
			shot_wait = 4
		elif a == "--play":
			_enter({"name": "Viajante", "level": 1, "race": test_race, "gender": test_gender, "skin": 1, "hair": 2, "hair_color": 1, "equipment": {"armadura": test_armor, "arma": test_weapon, "escudo": test_shield}})
		elif a.begins_with("--frames="):
			shot_wait = int(a.trim_prefix("--frames="))
		elif a.begins_with("--win="):
			net.inventory = {"pocao_hp": 8, "retorno": 2, "espadao_ng": 1, "madeira_ng": 14, "elmo_pesada_ng": 1}
			me.aurum = 1250
			me.equipment = {"arma": "espada_ng", "armadura": "pesada_ng"}
			net.inventory["lend_espada_harmonia"] = 1
			net.inventory["robe_ng"] = 1
			var seen := {}
			for iid in world.info.items:  # um item de cada tipo, para conferir os ícones
				var itd: Dictionary = world.info.items[iid]
				var key := "%s|%s|%s|%s" % [itd.get("type", ""), itd.get("slot", ""), itd.get("kind", ""), str(iid).get_slice("_", 0)]
				if not seen.has(key) and net.inventory.size() < 60:
					seen[key] = true
					net.inventory[iid] = 1 + randi() % 5
			me.equipment["elmo"] = "elmo_pesada_ng"
			var wn := a.trim_prefix("--win=")
			if ":" in wn:
				ui.tab = wn.get_slice(":", 1)
				wn = wn.get_slice(":", 0)
			ui.open_window(wn, me, net.inventory, {})
			ui.set_assist(net.inventory)
			ui.chat_line("Lyra", "alguém para caçar javali?")
		elif a.begins_with("--hour="):
			atmos.t_day = float(a.trim_prefix("--hour=")) / 24.0
		elif a == "--rain":
			atmos.weather = "chuva"
			atmos.wet = 1.0
			atmos.weather_t = 999.0
		elif a == "--clean":  # teste: sem névoa e sem interface, para fotos do mapa
			world.env.fog_enabled = false
			ui.visible = false
			for c in ui.get_children():
				if c is CanvasItem:
					(c as CanvasItem).visible = false
		elif a.begins_with("--tilt="):
			pitch = -float(a.trim_prefix("--tilt="))
		elif a.begins_with("--aerial="):  # teste: vista do alto (distância em metros)
			dist = float(a.trim_prefix("--aerial="))
			pitch = -1.05
		elif a.begins_with("--yaw="):  # teste: câmera girada (graus em volta do personagem)
			yaw = facing + deg_to_rad(float(a.trim_prefix("--yaw=")))
			pitch = -0.05
		elif a == "--back":
			yaw = facing + PI + 0.5
			dist = 3.2
			pitch = -0.15
		elif a == "--nofeet":  # teste: sem o ajuste dos pés, para comparar
			Character.world_ref = null
		elif a == "--fight":
			test_fight = true
		elif a == "--armed":  # teste: postura de combate parado, sem monstro
			combat.combat_until = 1e9
		elif a == "--lineup":  # teste: uma fileira com todas as raças
			var ids: Array = world.info.races.keys()
			for i in ids.size():
				for gi in 2:
					var c: Node3D = Character.create({"race": ids[i], "gender": "mf"[gi], "skin": 1, "hair": 2 - gi, "hair_color": i, "equipment": {"armadura": ["pesada_ng", "leve_ng", "robe_ng"][i % 3], "arma": ["espada_ng", "arco_ng", "cajado_ng", "espadao_ng", "martelo_ng"][i % 5]}})
					add_child(c)
					var px := player.position.x - 5.6 + i * 1.6
					var pz := player.position.z + 3.2 + gi * 1.8
					c.position = Vector3(px, world.height(px, pz), pz)
					if gi == 0:
						c.set_tag(world.info.races[ids[i]].name, Color(0.8, 0.92, 1.0))
			facing = PI
		elif a == "--crowd":
			_spawn_crowd()
		elif a.begins_with("--look="):  # teste: câmera atrás do personagem olhando para x, z
			var lk := a.trim_prefix("--look=").split(",")
			yaw = atan2(player.position.x - float(lk[0]), player.position.z - float(lk[1]))
			facing = yaw + PI
			player.rotation.y = facing
		elif a == "--gm":
			gm = true
			ui.set_gm(true)
		elif a.begins_with("--interior="):  # teste: abre um interior
			interiores.call_deferred("enter_kind", a.trim_prefix("--interior="))
		elif a == "--showchar":  # teste: tela de escolha com o personagem como está
			ui.show_chars([{"name": "SpeedX", "level": 80, "race": test_race, "gender": test_gender, "look": {"skin": 1, "hair": 2, "hair_color": 1}, "equipment": {"armadura": test_armor, "arma": test_weapon, "escudo": test_shield}},
				{"name": "Dragonitte", "level": 1, "race": "draconato", "gender": "f", "equipment": {"armadura": "leve_ng"}}], "robsonpereira26")
		elif a.begins_with("--at="):
			var p := a.trim_prefix("--at=").split(",")
			home = Vector3(float(p[0]), 0, float(p[1]))
			_place_player(home)
			for i in 6:
				world.stream(player.position, 8)
			if p.size() > 2:
				yaw = float(p[2])
		elif a.begins_with("--dist="):
			dist = float(a.trim_prefix("--dist="))
			yaw = facing + 0.5
			pitch = -0.12
		elif a.begins_with("--anim="):
			player.play(a.trim_prefix("--anim="))
			player.current = "Dance"
		elif a.begins_with("--chars"):
			_new_char()


func _place_player(p: Vector3) -> void:
	player.position = Vector3(p.x, world.height(p.x, p.z), p.z)
	player.position.y = _ground_at(p.x, p.z)


# ---------- conta ----------
func _login(user: String, password: String) -> void:
	ui.busy(true)
	ui.set_status("Entrando...", false)
	var err: String = await net.login(user, password)
	if err != "":
		ui.busy(false)
		ui.set_status(err)
		return
	_save_prefs()
	await _list_chars()


func _signup(user: String, password: String) -> void:
	ui.busy(true)
	ui.set_status("Criando a conta...", false)
	var err: String = await net.signup(user, password)
	if err != "":
		ui.busy(false)
		ui.set_status(err)
		return
	_save_prefs()
	await _list_chars()


func _list_chars() -> void:
	ui.set_status("Lendo os personagens...", false)
	var r: Dictionary = await net.chars()
	if not r.ok:
		ui.busy(false)
		ui.set_status(r.erro)
		return
	gm = bool(r.get("is_gm", false))
	ui.show_chars(r.chars, net.username)


func _swap_player(o: Dictionary) -> void:
	var pos := player.position
	player.queue_free()
	player = Character.create(o)
	add_child(player)
	dust = FX.dust()
	player.add_child(dust)
	player.position = pos
	player.rotation.y = facing


func _preview(o: Dictionary) -> void:
	_swap_player(o)


# tela de entrada: o personagem aparece como está agora (raça, visual, armadura e arma equipadas)
func _show_char(c: Dictionary) -> void:
	showing = true
	_swap_player(c)
	_place_player(home)
	facing = 0.0
	player.rotation.y = facing
	player.set_battle(true)
	player.set_tag("%s%s  Nv %d" % ["[GM] " if gm else "", str(c.get("name", "?")), int(c.get("level", 1))], Color(1.0, 0.82, 0.35) if gm else Color(0.9, 0.95, 1.0))


func _new_char() -> void:
	creating = true
	ui.show_create()


func _create(o: Dictionary) -> void:
	ui.busy(true)
	ui.set_status("Criando o personagem...", false)
	var err: String = await net.create_char(o)
	if err != "":
		ui.busy(false)
		ui.set_status(err)
		return
	creating = false
	await _list_chars()


func _enter(c: Dictionary) -> void:
	creating = false
	showing = false
	me = c.duplicate(true)
	if c.has("id") and net.token != "":
		ui.busy(true)
		ui.set_status("Carregando o personagem...", false)
		var st: Dictionary = await net.state(str(c.id))
		if st.is_empty():
			ui.busy(false)
			ui.set_status("Não foi possível carregar o personagem. Tente de novo.")
			return
		me = st
	me.is_gm = gm
	_swap_player(me)
	var pos := Vector3(float(me.get("x", home.x)), 0.0, float(me.get("z", home.z)))
	_place_player(pos)
	saved_pos = player.position
	note("entrando no jogo em %d, %d" % [int(player.position.x), int(player.position.z)])
	for i in 6:
		world.stream(player.position, 8)
	var nm := str(me.get("name", "Viajante"))
	if gm:
		player.set_tag("[GM] " + nm, Color(1.0, 0.8, 0.3))
	else:
		player.set_tag(nm)
	ui.set_gm(gm)
	player.set_battle(false)
	has_target = false
	playing = true
	yaw = facing + PI
	pitch = -0.3
	dist = 7.5
	save_t = 0.0
	if not me.has("level"):
		me.level = 1
	ui.show_hud("")
	ui.set_who(me)
	combat.start()
	net.rt_join(me)
	ui.chat_line("", "Bem-vindo a Valtheria. Enter abre o bate-papo.", "sistema")


func _save_now(force := false) -> void:
	if not me.has("id") or (not force and player.position.distance_to(saved_pos) < 0.5):
		return
	saved_pos = player.position
	# dentro de um prédio o personagem fica numa sala fora do mapa: salva a porta por onde entrou
	var p := player.position
	if interiores and not interiores.inside.is_empty() and (interiores.inside.get("door") is Dictionary):
		var dp: Variant = (interiores.inside.door as Dictionary).get("pos")
		if dp is Vector3:
			p = dp
	var r: Dictionary = await net.save(p.x, p.z, maxf(1.0, combat.hp), combat.mp)
	if not bool(r.get("ok", false)) and str(r.get("motivo", "")) == "movimento" and r.has("x"):
		# o servidor não aceitou o deslocamento: volta para a última posição registrada
		ui.say("Posição corrigida pelo servidor")
		if interiores and not interiores.inside.is_empty():
			return
		_place_player(Vector3(float(r.x), 0, float(r.z)))
		saved_pos = player.position


func _to_login() -> void:
	if playing:
		await _save_now()
	playing = false
	creating = false
	combat.clear()
	social.clear()
	ui.close_window()
	me = {}
	net.logout()
	_swap_player({"equipment": {"armadura": "pesada_ng", "arma": "espada_ng"}})
	_place_player(home)
	ui.show_login()
	_refresh_bar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not quitting:
		quitting = true
		if playing:
			await _save_now()
		get_tree().quit()


# ---------- preferências ----------
func _load_prefs() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://valtheria.cfg") == OK:
		ui.user_edit.text = str(cf.get_value("conta", "usuario", ""))
		if cf.has_section_key("video", nkey()):
			quality = clampi(int(cf.get_value("video", nkey(), 3)), 0, 4)
		else:
			quality = 0 if compat else 1
	else:
		quality = 0 if compat else 1  # primeira vez: modo compatibilidade começa no mínimo
	if cf.has_section_key("video", "vsync"):
		vsync = bool(cf.get_value("video", "vsync", true))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	ui.btn_vsync.text = "VSync: " + ("ligado" if vsync else "desligado (FPS livre)")


func _save_prefs() -> void:
	var cf := ConfigFile.new()
	cf.set_value("conta", "usuario", ui.user_edit.text.strip_edges())  # a senha nunca é gravada
	cf.set_value("video", nkey(), quality)
	cf.set_value("video", "vsync", vsync)
	cf.save("user://valtheria.cfg")


func _toggle_vsync() -> void:
	vsync = not vsync
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	ui.btn_vsync.text = "VSync: " + ("ligado" if vsync else "desligado (FPS livre)")
	_save_prefs()


func _set_quality(q: int) -> void:
	quality = q
	var vp := get_viewport()
	var e: Environment = world.env
	vp.scaling_3d_scale = [0.6, 0.77, 1.0, 1.0, 1.0][q]
	# FSR 1: desenha em resolução menor e amplia com nitidez (só nos modos Vulkan/DirectX completos)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if (forward and q <= 1) else Viewport.SCALING_3D_MODE_BILINEAR
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH][q])
	world.sun.directional_shadow_blend_splits = q >= 3
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X][q]
	world.sun.shadow_enabled = q >= 1
	world.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == 1 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096, 4096, 8192][q], q >= 2)
	world.sun.directional_shadow_max_distance = [40.0, 42.0, 120.0, 170.0, 220.0][q]
	e.ssao_enabled = q >= 2 and (forward or compat)
	e.glow_enabled = q >= 2
	e.adjustment_enabled = q >= 2
	e.volumetric_fog_enabled = q >= 3 and forward
	e.ssil_enabled = q >= 4 and forward
	e.sdfgi_enabled = q >= 4 and forward
	world.set_detail(q)
	cam.far = world.far_r + 400.0
	ui.btn_quality.text = "Qualidade: " + QUALITY[q]
	_save_prefs()


func _api_name() -> String:
	var d := RenderingServer.get_current_rendering_driver_name()
	var n: String = {"d3d12": "DirectX 12", "vulkan": "Vulkan", "opengl3": "OpenGL", "opengl3_angle": "OpenGL (ANGLE)", "metal": "Metal"}.get(d, d)
	return n + (" leve" if RenderingServer.get_current_rendering_method() == "mobile" else "")


func _refresh_bar() -> void:
	ui.bar_info.text = "Motor Godot %s   ·   %s   ·   %s" % [Engine.get_version_info().string.split(" ")[0], _api_name(), RenderingServer.get_video_adapter_name()]
	var d := RenderingServer.get_current_rendering_driver_name()
	ui.btn_api.visible = OS.get_name() == "Windows"
	ui.btn_api.text = "Trocar para " + ("Vulkan" if d == "d3d12" else "DirectX 12")


# grava a API escolhida num arquivo ao lado do jogo e reinicia
func _switch_api() -> void:
	var next := "vulkan" if RenderingServer.get_current_rendering_driver_name() == "d3d12" else "d3d12"
	var path := OS.get_executable_path().get_base_dir().path_join("override.cfg")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		ui.set_status("Não consegui gravar a configuração nesta pasta. Mova o jogo para uma pasta sua (por exemplo, Documentos) e tente de novo.")
		return
	f.store_string("[rendering]\n\nrendering_device/driver.windows=\"%s\"\n" % next)
	f.close()
	OS.set_restart_on_exit(true)
	get_tree().quit()


# ---------- multidão (teste de desempenho) ----------
func _spawn_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = crowd.size() + 1
	var acts := ["Idle", "Walk", "Jog_Fwd", "Dance", "Idle_Talking", "Idle_FoldArms"]
	for i in 50:
		var races: Array = world.info.races.keys()
		var n: Node3D = Character.create({"race": races[rng.randi() % races.size()], "gender": "f" if rng.randf() < 0.5 else "m", "skin": rng.randi() % 4, "hair": rng.randi() % 6, "hair_color": rng.randi() % 8, "equipment": {"armadura": ["pesada_ng", "leve_ng", "robe_ng"][rng.randi() % 3], "arma": ["espada_ng", "espadao_ng", "arco_ng", "cajado_ng", "martelo_ng"][rng.randi() % 5]}})
		add_child(n)
		n.set_battle(false)
		var a := rng.randf() * TAU
		var r := rng.randf_range(5.0, 17.0)
		var p: Vector3 = player.position + Vector3(sin(a) * r, 0, cos(a) * r)
		n.position = Vector3(p.x, world.height(p.x, p.z), p.z)
		n.rotation.y = rng.randf() * TAU
		var act: String = acts[rng.randi() % acts.size()]
		n.anim.get_animation(act).loop_mode = Animation.LOOP_LINEAR
		n.play(act)
		n.anim.seek(rng.randf() * 1.5)
		crowd.append(n)


# ---------- controles ----------
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_F11:
			ui.toggle_fullscreen()
		if not playing:
			return
		match ev.keycode:
			KEY_ESCAPE:
				if ui.win.visible:
					ui.close_window()
				else:
					_to_login()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				ui.press_slot(ev.keycode - KEY_1)
			KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9:
				ui.use_assist(ev.keycode - KEY_F1)
			KEY_SPACE:
				if not gm_fly:
					_do("pular")
			KEY_E:
				if not ui.typing():
					interiores.key_e()
			KEY_V:
				if gm and not ui.typing():
					_gm("voar", {})
			KEY_F10:
				if gm:
					_window("gm")
			KEY_J:
				_window("acoes")
			KEY_I:
				_window("bolsa")
			KEY_B:
				_window("loja")
			KEY_C:
				_window("oficio")
			KEY_G:
				_window("cla")
			KEY_K:
				_window("classe")
			KEY_ENTER, KEY_KP_ENTER:
				ui.chat_edit.grab_focus()
			KEY_TAB:
				combat.next_target()
			KEY_F:
				combat.engage(combat.target)
	if not playing:
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_RIGHT:
			orbiting = ev.pressed
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			dist = maxf(2.2, dist * 0.9)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			dist = minf(40.0, dist * 1.1)
		elif ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			var ro := cam.project_ray_origin(ev.position)
			var rd := cam.project_ray_normal(ev.position)
			if not interiores.inside.is_empty():
				if interiores.talk_near(ro, rd):
					return
				if rd.y < -0.01:
					var tt: float = (interiores.ground() - ro.y) / rd.y
					target = ro + rd * tt
					has_target = true
					marker.position = target + Vector3(0, 0.08, 0)
					marker.visible = true
				return
			var npc: Dictionary = npcs.pick_npc(ro, rd)
			if not npc.is_empty():
				if sel.get("kind", "") == "npc" and sel.get("node") == npc.node and str(npc.window) != "":
					_window(str(npc.window))
				else:
					sel = {"kind": "npc", "node": npc.node, "name": npc.name, "window": npc.window}
					combat.target = null
					npcs.talk(npc)
				return
			var mob = combat.pick(ro, rd)
			if mob != null:
				sel = {}
				if combat.target == mob:
					combat.engage(mob)
				else:
					combat.target = mob
				return
			var other: String = social.pick(ro, rd)
			if other != "":
				sel = {"kind": "player", "id": other}
				combat.target = null
				return
			var pc: Vector3 = player.position + Vector3(0, player.height_m * 0.5, 0)
			var pt := (pc - ro).dot(rd)
			if pt > 0.0 and (ro + rd * pt).distance_to(pc) < 0.55:
				sel = {"kind": "self"}
				combat.target = null
				return
			sel = {}
			combat.stop_auto()
			var hit: Variant = _ground_under(ev.position) if not combat.dead else null
			if gm and hit != null and Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_ALT):
				_teleport((hit as Vector3).x, (hit as Vector3).z)
				return
			if hit != null:
				target = hit
				has_target = true
				marker.position = target + Vector3(0, 0.08, 0)
				marker.visible = true
	elif ev is InputEventMouseMotion and orbiting:
		yaw -= ev.relative.x * 0.006
		pitch = clampf(pitch - ev.relative.y * 0.005, -1.35, 0.25)


# ponto do chão sob o cursor (anda ao longo do raio até cruzar o relevo)
func _ground_under(screen: Vector2) -> Variant:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var t := 0.0
	var prev := 0.0
	while t < 260.0:
		var p := o + d * t
		if p.y < world.height(p.x, p.z):
			var a := prev
			var b := t
			for i in 12:
				var m := (a + b) * 0.5
				var q := o + d * m
				if q.y < world.height(q.x, q.z):
					b = m
				else:
					a = m
			var r := o + d * b
			return Vector3(r.x, world.height(r.x, r.z), r.z)
		prev = t
		t += 0.8 + t * 0.02
	return null


func _physics_process(dt: float) -> void:
	if not playing:
		return
	var input := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	var typing: bool = ui.typing()
	if typing:
		input = Vector2.ZERO
	if not typing and Input.is_physical_key_pressed(KEY_A): input.x -= 1.0
	if not typing and Input.is_physical_key_pressed(KEY_D): input.x += 1.0
	if not typing and Input.is_physical_key_pressed(KEY_W): input.y -= 1.0
	if not typing and Input.is_physical_key_pressed(KEY_S): input.y += 1.0
	var move := Vector3.ZERO
	if input.length() > 0.1 and not combat.dead:
		combat.stop_auto()
		has_target = false
		marker.visible = false
		var f := Vector3(-sin(yaw), 0, -cos(yaw))
		var r := Vector3(cos(yaw), 0, -sin(yaw))
		move = (r * input.x - f * input.y).normalized()
	elif has_target:
		var to := target - player.position
		to.y = 0.0
		if to.length() < 0.25:
			has_target = false
			marker.visible = false
		elif chasing:
			marker.visible = false
			move = to.normalized()
		else:
			move = to.normalized()
	if player.is_busy():
		move = Vector3.ZERO
	if dust and is_instance_valid(dust):
		dust.emitting = move != Vector3.ZERO
	if move != Vector3.ZERO:
		var sprint := Input.is_physical_key_pressed(KEY_SHIFT)
		var walk := Input.is_physical_key_pressed(KEY_CTRL)
		var speed: float = WALK if walk else float(combat.st.get("speed", RUN)) * (1.0 if not sprint else 1.0)
		if gm_speed:
			speed *= 3.0
		var step := speed * dt
		if has_target:  # nunca passa do destino
			var left := Vector2(target.x - player.position.x, target.z - player.position.z).length()
			step = minf(step, left)
		if swimming:
			step *= 0.55
		if not interiores.inside.is_empty():
			player.position = interiores.clamp_move(player.position + move * step, player.position)
		else:
			var p: Vector3 = world.resolve(player.position + move * step, player.position)
			var zo: Dictionary = world.zone_at(player.position.x, player.position.z)
			if str(zo.get("kind", "")) == "submarina" and world.zone_at(p.x, p.z).is_empty():
				p = player.position  # a bolha de ar de Abissália: não dá para sair a pé
			player.position = Vector3(p.x, _ground_at(p.x, p.z), p.z)
		facing = lerp_angle(facing, atan2(move.x, move.z), minf(1.0, dt * 12.0))
		player.rotation.y = facing
		player.play("Walk" if walk or swimming else "Jog_Fwd", 0.7 if swimming else (1.1 if walk else speed / 5.2))
		emote = ""
	elif not player.is_busy() and not combat.dead:
		if combat.auto:
			emote = ""
		player.play(emote if emote != "" else "Idle")
	if gm_fly:
		if not typing and Input.is_physical_key_pressed(KEY_SPACE):
			fly_y += 9.0 * dt
		if not typing and Input.is_physical_key_pressed(KEY_X):
			fly_y -= 9.0 * dt
		var gy: float = world.height(player.position.x, player.position.z)
		fly_y = maxf(fly_y, gy)
		player.position.y = fly_y
		if move == Vector3.ZERO and not player.is_busy():
			player.play("Idle")
	if jumping:
		jump_t += dt / 0.62
		if jump_t >= 1.0:
			jumping = false
			jump_t = 1.0
		var base_y: float = interiores.ground() if not interiores.inside.is_empty() else _ground_at(player.position.x, player.position.z)
		player.position.y = base_y + sin(PI * jump_t) * 0.85


func _process(dt: float) -> void:
	if interiores == null or interiores.inside.is_empty():
		world.stream(player.position, 2)
	log_t += dt
	if log_t > 2.0:
		log_t = 0.0
		note("fps %d | RAM %d MB | vídeo %d MB | blocos %d | grama %d | nós %d" % [int(Engine.get_frames_per_second()), int(OS.get_static_memory_usage() / 1048576.0), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0), world.chunks.size(), world.grass.size(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	if playing and log_t == 0.0:
		note("combate: nv %d xp %d | vida %d/%d | monstros %d | alvo %s" % [int(me.get("level", 1)), int(me.get("xp", 0)), int(combat.hp), int(combat.st.get("maxHp", 0)), combat.mobs.size(), str(combat.target.fam.name) if combat.target else "-"])
		if test_fight:
			if combat.target == null:
				combat.next_target()
			combat.engage(combat.target)
			combat.use_skill(0)
	if playing:
		var focus := player.position + Vector3(0, player.height_m * 0.82, 0)
		var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
		var want := focus + dir * (dist if interiores.inside.is_empty() else minf(dist, 5.0))
		if not interiores.inside.is_empty():
			want = interiores.clamp_cam(want)
		else:
			var under_sea: bool = str(world.zone_at(player.position.x, player.position.z).get("kind", "")) == "submarina"
			var floor_y: float = (world.height(want.x, want.z) if under_sea else maxf(world.height(want.x, want.z), 0.0)) + 0.35
			if want.y < floor_y:
				want.y = floor_y
		cam.position = cam.position.lerp(want, minf(1.0, dt * 14.0))
		cam.look_at(focus)
		if marker.visible:
			marker.rotation.y += dt * 2.0
		ui.set_bars(combat.hp, combat.st.get("maxHp", 1.0), combat.mp, combat.st.get("maxMp", 1.0), float(me.get("xp", 0.0)), float(world.info.xpneed[clampi(int(me.get("level", 1)) - 1, 0, 79)]))
		ui.set_target(_target_info())
		var cpm := floorf(float(combat.st.get("maxHp", 100.0)) * 0.6)
		ui.set_cp(cpm, cpm)
		if Engine.get_frames_drawn() % 12 == 0:
			ui.set_effects(_effects())
		if ui.win.visible and Engine.get_frames_drawn() % 20 == 0:
			var cs: Dictionary = combat.st
			ui.stats_view = {"Vida": "%d / %d" % [int(combat.hp), int(cs.get("maxHp", 0))], "Mana": "%d / %d" % [int(combat.mp), int(cs.get("maxMp", 0))], "Ataque físico": str(int(cs.get("patk", 0))), "Ataque mágico": str(int(cs.get("matk", 0))), "Defesa": str(int(cs.get("pdef", 0))), "Velocidade": "%.1f m/s" % float(cs.get("speed", 0)), "Alcance": "%.1f m" % float(cs.get("range", 0)), "Intervalo de ataque": "%.2f s" % float(cs.get("interval", 0)), "Elemento": str(combat.my_elem).capitalize()}
		# na cidade ninguém fica em postura de combate: arma guardada dentro da zona segura
		var in_town: bool = world.nearest_town(player.position.x, player.position.z).in_safe
		var fighting: bool = (combat.auto or combat.now() < combat.combat_until) and not in_town
		if fighting != player.armed:
			player.magic_idle = bool(combat.st.get("magic", false))
			player.set_battle(fighting)
			player.current = ""
		if Engine.get_frames_drawn() % 45 == 0:
			ui.set_assist(net.inventory)
		ui.set_cooldowns(combat.cds, combat.now())
		save_t += dt
		if save_t > 20.0:
			save_t = 0.0
			_save_now()
		if Engine.get_frames_drawn() % 30 == 0:
			var nt: Dictionary = world.nearest_town(player.position.x, player.position.z)
			if not interiores.inside.is_empty():
				var dt_: Dictionary = interiores.inside.door
				nt = world.nearest_town((dt_.pos as Vector3).x, (dt_.pos as Vector3).z)
				nt.in_safe = true
				nt.town = {"name": "%s · %s" % [interiores.inside.name, nt.town.name], "min": 1, "max": 1}
			var where: String = nt.town.name + ("  ·  zona segura" if nt.in_safe else "  ·  arredores (nível %d a %d)" % [int(nt.town.min), int(nt.town.max)])
			ui.place_label.text = "%s\nPosição %d, %d   ·   %s%s" % [where, int(player.position.x), int(player.position.z), atmos.hour_text(), "   ·   chuva" if atmos.wet > 0.3 else ""]
	elif creating or showing:
		var f := Vector3(sin(facing), 0, cos(facing))
		var side := Vector3(f.z, 0, -f.x)
		cam.position = player.position + f * 3.8 - side * 0.9 + Vector3(0, player.height_m * 0.62, 0)
		cam.look_at(player.position - side * 0.9 + Vector3(0, player.height_m * 0.52, 0))
	else:
		# tela de entrada: a câmera passeia devagar em volta da praça
		var t := Time.get_ticks_msec() * 0.00004
		var a := 2.2 + sin(t * TAU) * 0.55
		var c := Vector3(home.x - 3.5 + sin(a) * 15.0, 0, home.z - 6.0 + cos(a) * 15.0)
		cam.position = Vector3(c.x, world.height(c.x, c.z) + 3.6, c.z)
		cam.look_at(Vector3(home.x - 4.5, world.height(home.x, home.z) + 2.6, home.z - 6.0))
	smooth_fps = lerpf(smooth_fps, Engine.get_frames_per_second(), 0.1)
	if playing and Engine.get_frames_drawn() % 15 == 0:
		var size := get_window().size
		ui.stats.text = "%d FPS   ·   %.1f ms\n%s   ·   %d x %d\n%s\nObjetos desenhados: %d\nChamadas de desenho: %d\nTriângulos: %s\nBlocos de terreno: %d\nÁrvores carregadas: %d\nPersonagens animados: %d" % [
			int(Engine.get_frames_per_second()), 1000.0 / maxf(1.0, Engine.get_frames_per_second()), _api_name(), size.x, size.y, RenderingServer.get_video_adapter_name(),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			_fmt(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))), world.chunks.size(), world.counts.arvores, 1 + crowd.size()]
	if shot_path != "":
		shot_frames += 1
		if shot_frames == shot_wait:
			get_viewport().get_texture().get_image().save_png(shot_path)
			note("teste: pés %.3f m, tornozelo %.3f m" % [player.foot_off, player.ankle])
			get_tree().quit()


func _fmt(n: int) -> String:
	if n >= 1000000:
		return "%.1f mi" % (n / 1000000.0)
	if n >= 1000:
		return "%d mil" % (n / 1000)
	return str(n)


func nkey() -> String:
	return "nivel2_gl" if compat else ("nivel2" if forward else "nivel2_leve")


# registro gravado na pasta do jogo, linha a linha, para descobrir onde parou se o computador travar
func _log_open() -> void:
	var path := OS.get_executable_path().get_base_dir().path_join("registro.txt")
	log_file = FileAccess.open(path, FileAccess.WRITE)
	if log_file == null:
		log_file = FileAccess.open("user://registro.txt", FileAccess.WRITE)
	note("Valtheria %s | %s | %s | %s | %s" % [ProjectSettings.get_setting("application/config/version"), RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name(), OS.get_name()])
	note("memória do computador: %s" % str(OS.get_memory_info()))


func note(t: String) -> void:
	if log_file:
		log_file.store_line("%7.1fs  %s" % [Time.get_ticks_msec() / 1000.0, t])
		log_file.flush()


# ---------- alvo, efeitos e ações ----------
func _target_info() -> Dictionary:
	var cpm := floorf(float(combat.st.get("maxHp", 100.0)) * 0.6)
	match str(sel.get("kind", "")):
		"self":
			return {"name": "%s   ·   Nv %d" % [str(me.get("name", "Viajante")), int(me.get("level", 1))], "hp": combat.hp, "max": combat.st.get("maxHp", 1.0), "cp": cpm, "maxcp": cpm}
		"player":
			var o: Dictionary = social.others.get(str(sel.id), {})
			if o.is_empty():
				sel = {}
				return {}
			return {"name": "%s   ·   Nv %d" % [str(o.name), int(o.lvl)], "hp": o.hp, "max": 100.0, "cp": o.cp, "maxcp": 100.0, "pct": true}
		"npc":
			if not is_instance_valid(sel.node):
				sel = {}
				return {}
			return {"name": str(sel.name)}
	var m = combat.target
	if m != null:
		return {"name": "%s   ·   Nv %d" % [m.fam.name, int(m.L)], "hp": m.hp, "max": m.maxHp}
	return {}


func _effects() -> Array:
	var out := []
	var t: float = combat.now()
	var names := {"patk": ["forca", "Ataque físico"], "matk": ["luz", "Ataque mágico"], "pdef": ["escudo", "Defesa"], "speed": ["pressa", "Velocidade"], "aspd": ["pressa", "Velocidade de ataque"], "crit": ["estrela", "Crítico"]}
	for b in combat.buffs:
		var left: float = float(b.until) - t
		if left <= 0.0:
			continue
		var d: Array = names.get(str(b.k), ["estrela", str(b.k).capitalize()])
		var up: bool = float(b.v) >= 0.0
		out.append({"kind": d[0] if up else "fraqueza", "col": Color(0.6, 0.95, 0.65) if up else Color(1.0, 0.45, 0.4), "tip": "%s %s%d%%" % [d[1], "+" if up else "", int(roundf(float(b.v) * 100.0))], "left": left})
	if combat.shield > 0.0 and combat.shield_until > t:
		out.append({"kind": "escudo", "col": Color(0.6, 0.86, 1.0), "tip": "Escudo: absorve %d de dano" % int(combat.shield), "left": combat.shield_until - t})
	for i in combat.cds.size():
		var left: float = float(combat.cds[i]) - t
		if left > 0.0 and i < combat.skills.size():
			out.append({"kind": "recarga", "col": Color(0.75, 0.75, 0.8), "tip": "Recarga: %s" % str(combat.skills[i].name), "left": left})
	return out


func _do(id: String) -> void:
	if not playing or combat.dead:
		return
	var head: Vector3 = player.position + Vector3(0, player.height_m + 0.2, 0)
	match id:
		"atacar":
			if combat.target == null:
				combat.next_target()
			sel = {}
			combat.engage(combat.target)
		"sentar":
			has_target = false
			emote = "Sitting_Idle"
		"dancar":
			has_target = false
			emote = "Dance"
		"conversar":
			emote = "Idle_Talking"
		"acenar":
			emote = ""
			player.action("Yes")
		"pular":
			if not jumping:
				jumping = true
				jump_t = 0.0
		"sorrir":
			combat._float_text(head, "sorri  :)", Color(1.0, 0.92, 0.5))
			ui.chat_line("", "%s sorri" % str(me.get("name", "Viajante")), "emote")
		"chorar":
			combat._float_text(head, "chora  :'(", Color(0.6, 0.8, 1.0))
			ui.chat_line("", "%s chora" % str(me.get("name", "Viajante")), "emote")
		"escalar":
			ui.say("Escalar chega com os paredões escaláveis")


# ---------- bolsa, loja, ofício, clã, bate-papo ----------
func _online() -> bool:
	return me.has("id") and net.token != ""


func _window(name: String) -> void:
	if name == "gm":
		if not gm:
			return
		if ui.win.visible and ui.win_name == "gm":
			ui.close_window()
			return
		_gm_open()
		return
	if ui.win.visible and ui.win_name == name:
		ui.close_window()
		return
	if name == "loja" and not world.nearest_town(player.position.x, player.position.z).in_safe:
		ui.say("A loja só abre dentro de uma cidade")
		return
	if _online() and name != "cla":
		await _refresh_char()
	var extra := {}
	if name == "cla" and _online():
		var r: Dictionary = await net.rpc_call("game_clan_info", {"p_char": net.char_id})
		if r.ok and r.data is Dictionary:
			extra = r.data
	ui.open_window(name, me, net.inventory, extra)


# pede a ação ao servidor, relê o personagem e redesenha o que mudou
func _action(fn: String, args: Dictionary) -> void:
	if not _online():
		ui.say("Entre com uma conta para usar a bolsa, a loja e o ofício")
		return
	if fn in ["game_use", "game_class_change"]:
		await _save_now(true)
	var err: String = await net.act(fn, args)
	if err != "":
		ui.say(err)
		return
	fn_heals = fn == "game_use"
	await _refresh_char()
	if ui.win.visible:
		var keep: String = ui.win_name
		ui.win_name = ""
		await _window(keep)


func _refresh_char() -> void:
	var before := JSON.stringify(me.get("equipment", {}))
	var st: Dictionary = await net.state(net.char_id)
	if st.is_empty():
		return
	st.x = player.position.x
	st.z = player.position.z
	var hp_was: float = float(st.get("hp", combat.hp))
	me = st
	combat.recalc()
	combat.hp = clampf(maxf(combat.hp, hp_was) if fn_heals else combat.hp, 1.0, combat.st.maxHp)
	combat.mp = minf(maxf(combat.mp, float(st.get("mp", combat.mp))) if fn_heals else combat.mp, combat.st.maxMp)
	fn_heals = false
	ui.set_skills(combat.skills)
	ui.set_who(me)
	if JSON.stringify(me.get("equipment", {})) != before:
		_swap_player(me)
		player.set_tag(str(me.get("name", "")))
		player.set_battle(false)


var fn_heals := false


func _chat(text: String) -> void:
	if text.begins_with("/") and not text.begins_with("/cla "):
		_command(text)
		return
	if text.begins_with("/cla "):
		var p := text.trim_prefix("/cla ").strip_edges().rsplit(" ", false, 1)
		if p.size() < 2:
			ui.chat_line("", "Use: /cla Nome TAG", "sistema")
			return
		_action("game_clan_create", {"p_name": p[0], "p_tag": p[1]})
		return
	social.say(text)


# ---------- GM ----------
func _gm_open() -> void:
	var online: Array = []
	for id in social.others:
		var o: Dictionary = social.others[id]
		online.append({"name": o.name, "lvl": o.lvl, "x": (o.pos as Vector3).x, "z": (o.pos as Vector3).z})
	ui.gm_view.merge({"god": gm_god, "speed": gm_speed, "fly": gm_fly, "hide": gm_hide, "online": online, "mapa": world.mapa}, true)
	ui.open_window("gm", me, net.inventory, {})


func _teleport(x: float, z: float) -> void:
	has_target = false
	marker.visible = false
	combat.stop_auto()
	_place_player(Vector3(x, 0, z))
	fly_y = player.position.y
	for i in 8:
		world.stream(player.position, 8)
	ui.say("Teleportado para %d, %d" % [int(x), int(z)])
	_save_now(true)


func _gm(cmd: String, args: Dictionary) -> void:
	if not gm:
		ui.say("Apenas GM")
		return
	var msg := ""
	match cmd:
		"tp":
			_teleport(float(args.x), float(args.z))
		"interior":
			if has_node("Interiores"):
				get_node("Interiores").call("enter_kind", str(args.kind))
		"deus":
			gm_god = not gm_god
			msg = "Invencível " + ("ligado" if gm_god else "desligado")
		"vel":
			gm_speed = not gm_speed
			msg = "Velocidade de GM " + ("ligada" if gm_speed else "desligada")
		"voar":
			gm_fly = not gm_fly
			fly_y = player.position.y
			msg = "Voo " + ("ligado (Espaço sobe, X desce)" if gm_fly else "desligado")
			if not gm_fly:
				player.position.y = world.height(player.position.x, player.position.z)
		"oculto":
			gm_hide = not gm_hide
			for m in combat.mobs:
				m.aggro = false
			msg = "Monstros " + ("não enxergam você" if gm_hide else "voltam a enxergar você")
		"curar":
			combat.recalc()
			combat.hp = float(combat.st.get("maxHp", combat.hp))
			combat.mp = float(combat.st.get("maxMp", combat.mp))
			msg = "Vida e mana cheias"
		"hora":
			atmos.t_day = float(args.h) / 24.0
			msg = "Hora: " + atmos.hour_text()
		"clima":
			atmos.weather = str(args.w)
			atmos.weather_t = 240.0
			msg = "Clima: " + str(args.w)
		"onde":
			msg = "Posição %.1f, %.1f (altura %.1f)" % [player.position.x, player.position.z, player.position.y]
		"matar":
			if combat.target == null:
				msg = "Selecione um monstro primeiro"
			else:
				combat.gm_kill(combat.target, true)
				msg = "Monstro eliminado"
		"matartodos", "limpar":
			var n: int = combat.gm_area(float(args.get("r", 40.0)), cmd == "matartodos")
			msg = "%d monstro(s) %s" % [n, "eliminado(s)" if cmd == "matartodos" else "removido(s)"]
		"spawn":
			var a := facing
			if combat.gm_spawn(str(args.fam), player.position.x + sin(a) * 6.0, player.position.z + cos(a) * 6.0):
				msg = "Monstro criado"
			else:
				msg = "Família desconhecida: " + str(args.fam)
		_:
			# comandos do servidor
			if not _online():
				ui.say("Esse comando precisa de conta online")
				return
			var a := args.duplicate()
			if not a.has("alvo") and str(ui.gm_view.get("alvo", "")).strip_edges() != "":
				a.alvo = str(ui.gm_view.alvo).strip_edges()
			if cmd == "puxar":
				a.x = player.position.x + 2.0
				a.z = player.position.z
			msg = await net.gm(cmd, a)
			await _refresh_char()
			combat.recalc()
			ui.set_who(me)
	if msg != "":
		ui.say(msg)
		ui.chat_line("GM", msg, "sistema")
	if ui.win.visible and ui.win_name == "gm":
		_gm_open()


func _command(text: String) -> void:
	var p := text.substr(1).strip_edges().split(" ", false)
	if p.is_empty():
		return
	var c := p[0].to_lower()
	var a := p.slice(1)
	match c:
		"ajuda":
			ui.chat_line("", "Comandos: /onde" + (" | GM: /tp x z, /ir nome, /vel, /deus, /voar, /oculto, /curar, /hora h, /chuva, /limpo, /give item qtd [jogador], /aurum qtd [jogador], /nivel n [jogador], /karma n [jogador], /prof coleta|refino|forja n, /info j, /puxar j, /kick j, /ban j, /desban j, /anuncio texto, /matar, /matartodos [raio], /limpar [raio], /spawn família, /reset, /interior taverna|forja|igreja|casa|loja" if gm else ""), "sistema")
			return
		"onde":
			ui.chat_line("", "Posição %d, %d" % [int(player.position.x), int(player.position.z)], "sistema")
			return
	if not gm:
		ui.chat_line("", "Comando desconhecido. Use /ajuda", "sistema")
		return
	var n := func(i: int, d: float) -> float: return float(a[i]) if a.size() > i and a[i].is_valid_float() else d
	var who := func(i: int) -> Dictionary: return {"alvo": a[i]} if a.size() > i else {}
	match c:
		"tp": _gm("tp", {"x": n.call(0, player.position.x), "z": n.call(1, player.position.z)})
		"ir":
			var q := " ".join(a).to_lower()
			var dest := {}
			for t in world.info.towns:
				if str(t.id).begins_with(q) or str(t.name).to_lower().contains(q):
					dest = {"x": float(t.x) + 3.0, "z": float(t.z) + 8.0}
					break
			if dest.is_empty():
				for grp in ["castles", "villages"]:
					for v in world.mapa.get(grp, []):
						if dest.is_empty() and (str(v.id).begins_with(q) or str(v.name).to_lower().contains(q)):
							dest = {"x": float(v.x), "z": float(v.z) + 40.0}
			if dest.is_empty():
				for l in world.info.landmarks:
					if dest.is_empty() and (str(l.id).begins_with(q) or str(l.name).to_lower().contains(q)):
						dest = {"x": float(l.x), "z": float(l.z) + 30.0}
			if dest.is_empty():
				ui.chat_line("", "Destino não encontrado", "sistema")
			else:
				_gm("tp", dest)
		"vel", "deus", "voar", "oculto", "curar", "matar", "reset":
			_gm({"reset": "reset_nos"}.get(c, c), {})
		"hora": _gm("hora", {"h": n.call(0, 12.0)})
		"chuva", "limpo": _gm("clima", {"w": c})
		"matartodos", "limpar": _gm(c, {"r": n.call(0, 40.0)})
		"spawn": _gm("spawn", {"fam": a[0] if a.size() > 0 else "javali"})
		"interior": _gm("interior", {"kind": a[0] if a.size() > 0 else "taverna"})
		"give": _gm("give", {"item": a[0] if a.size() > 0 else "", "qtd": int(n.call(1, 1.0))}.merged(who.call(2)))
		"aurum": _gm("aurum", {"qtd": int(n.call(0, 0.0))}.merged(who.call(1)))
		"nivel": _gm("nivel", {"nivel": int(n.call(0, 1.0))}.merged(who.call(1)))
		"karma": _gm("karma", {"qtd": int(n.call(0, 0.0))}.merged(who.call(1)))
		"prof": _gm("prof", {"prof": a[0] if a.size() > 0 else "coleta", "nivel": int(n.call(1, 1.0))}.merged(who.call(2)))
		"info", "puxar", "kick", "ban", "desban", "setgm": _gm(c, who.call(0))
		"anuncio": _gm("anuncio", {"msg": " ".join(a)})
		_: ui.chat_line("", "Comando desconhecido. Use /ajuda", "sistema")



# chão onde o personagem pisa: relevo, cais, ponte, plataformas; em água funda ele nada
func _ground_at(x: float, z: float) -> float:
	var f: float = world.floor_y(x, z, player.position.y)
	if f < world.WATER_Y - 1.25 and world.zone_at(x, z).is_empty():
		swimming = true
		return world.WATER_Y - 1.25
	swimming = false
	return f
