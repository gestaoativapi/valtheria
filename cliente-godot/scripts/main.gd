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


func _ready() -> void:
	_log_open()
	compat = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	forward = RenderingServer.get_current_rendering_method() == "forward_plus"
	world = World.new()
	add_child(world)
	world.build()
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
	ui.want_window.connect(_window)
	ui.want_action.connect(_action)
	ui.want_chat.connect(_chat)
	ui.want_new_char.connect(_new_char)
	ui.want_preview.connect(_preview)
	ui.want_create.connect(_create)
	ui.want_back_to_chars.connect(func():
		creating = false
		_preview({"equipment": {"armadura": "pesada_ng", "arma": "espada_ng"}})
		ui.show_chars(ui.last_chars, ui.last_account))
	ui.want_login.connect(_login)
	ui.want_signup.connect(_signup)
	ui.want_offline.connect(func(): _enter({"name": "Viajante", "level": 1, "equipment": {"armadura": "pesada_ng", "arma": "espada_ng"}}))
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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--race="):
			var rp := a.trim_prefix("--race=").split(",")
			test_race = rp[0]
			if rp.size() > 1: test_gender = rp[1]
			if rp.size() > 2: test_armor = rp[2]
			if rp.size() > 3: test_weapon = rp[3]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.trim_prefix("--shot=")
		elif a.begins_with("--lite"):
			var lite_q := a.trim_prefix("--lite=") if a.contains("=") else "0"  # teste em máquina sem placa de vídeo
			_set_quality(int(lite_q))
			shot_wait = 4
		elif a == "--play":
			_enter({"name": "Viajante", "level": 1, "race": test_race, "gender": test_gender, "skin": 1, "hair": 2, "hair_color": 1, "equipment": {"armadura": test_armor, "arma": test_weapon}})
		elif a.begins_with("--frames="):
			shot_wait = int(a.trim_prefix("--frames="))
		elif a.begins_with("--win="):
			net.inventory = {"pocao_hp": 8, "retorno": 2, "espadao_ng": 1, "madeira_ng": 14, "elmo_pesada_ng": 1}
			me.aurum = 1250
			me.equipment = {"arma": "espada_ng", "armadura": "pesada_ng"}
			ui.open_window(a.trim_prefix("--win="), me, net.inventory, {})
			ui.chat_line("Lyra", "alguém para caçar javali?")
		elif a.begins_with("--hour="):
			atmos.t_day = float(a.trim_prefix("--hour=")) / 24.0
		elif a == "--rain":
			atmos.weather = "chuva"
			atmos.wet = 1.0
			atmos.weather_t = 999.0
		elif a == "--fight":
			test_fight = true
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
	_swap_player(me)
	var pos := Vector3(float(me.get("x", home.x)), 0.0, float(me.get("z", home.z)))
	_place_player(pos)
	saved_pos = player.position
	note("entrando no jogo em %d, %d" % [int(player.position.x), int(player.position.z)])
	for i in 6:
		world.stream(player.position, 8)
	var nm := str(me.get("name", "Viajante"))
	player.set_tag(nm)
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
	await net.save(player.position.x, player.position.z, maxf(1.0, combat.hp), combat.mp)


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
	var acts := ["Idle", "Walk", "Jog_Fwd", "Dance", "Idle_Talking", "Sword_Regular_A", "Idle_FoldArms"]
	for i in 50:
		var races: Array = world.info.races.keys()
		var n: Node3D = Character.create({"race": races[rng.randi() % races.size()], "gender": "f" if rng.randf() < 0.5 else "m", "skin": rng.randi() % 4, "hair": rng.randi() % 6, "hair_color": rng.randi() % 8, "equipment": {"armadura": ["pesada_ng", "leve_ng", "robe_ng"][rng.randi() % 3], "arma": ["espada_ng", "espadao_ng", "arco_ng", "cajado_ng", "martelo_ng"][rng.randi() % 5]}})
		add_child(n)
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
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				combat.use_skill(ev.keycode - KEY_1)
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
			var npc_win: String = npcs.pick(cam.project_ray_origin(ev.position), cam.project_ray_normal(ev.position))
			if npc_win != "":
				_window(npc_win)
				return
			var mob = combat.pick(cam.project_ray_origin(ev.position), cam.project_ray_normal(ev.position))
			if mob != null:
				if combat.target == mob:
					combat.engage(mob)
				else:
					combat.target = mob
				return
			combat.stop_auto()
			var hit: Variant = _ground_under(ev.position) if not combat.dead else null
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
		var step := speed * dt
		if has_target:  # nunca passa do destino
			var left := Vector2(target.x - player.position.x, target.z - player.position.z).length()
			step = minf(step, left)
		var p: Vector3 = world.resolve(player.position + move * step, player.position)
		player.position = Vector3(p.x, world.height(p.x, p.z), p.z)
		facing = lerp_angle(facing, atan2(move.x, move.z), minf(1.0, dt * 12.0))
		player.rotation.y = facing
		player.play("Walk" if walk else "Jog_Fwd", 1.1 if walk else speed / 5.2)
	elif not player.is_busy() and not combat.dead:
		player.play("Idle")


func _process(dt: float) -> void:
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
		var want := focus + dir * dist
		var floor_y: float = maxf(world.height(want.x, want.z), 0.0) + 0.35
		if want.y < floor_y:
			want.y = floor_y
		cam.position = cam.position.lerp(want, minf(1.0, dt * 14.0))
		cam.look_at(focus)
		if marker.visible:
			marker.rotation.y += dt * 2.0
		ui.set_bars(combat.hp, combat.st.get("maxHp", 1.0), combat.mp, combat.st.get("maxMp", 1.0), float(me.get("xp", 0.0)), float(world.info.xpneed[clampi(int(me.get("level", 1)) - 1, 0, 79)]))
		ui.set_target(combat.target)
		ui.set_cooldowns(combat.cds, combat.now())
		save_t += dt
		if save_t > 20.0:
			save_t = 0.0
			_save_now()
		if Engine.get_frames_drawn() % 30 == 0:
			var nt: Dictionary = world.nearest_town(player.position.x, player.position.z)
			var where: String = nt.town.name + ("  ·  zona segura" if nt.dist < 70.0 else "  ·  arredores (nível %d a %d)" % [int(nt.town.min), int(nt.town.max)])
			ui.place_label.text = "%s\nPosição %d, %d   ·   %s%s" % [where, int(player.position.x), int(player.position.z), atmos.hour_text(), "   ·   chuva" if atmos.wet > 0.3 else ""]
	elif creating:
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


# ---------- bolsa, loja, ofício, clã, bate-papo ----------
func _online() -> bool:
	return me.has("id") and net.token != ""


func _window(name: String) -> void:
	if ui.win.visible and ui.win_name == name:
		ui.close_window()
		return
	if name == "loja" and world.nearest_town(player.position.x, player.position.z).dist > 80.0:
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


var fn_heals := false


func _chat(text: String) -> void:
	if text.begins_with("/cla "):
		var p := text.trim_prefix("/cla ").strip_edges().rsplit(" ", false, 1)
		if p.size() < 2:
			ui.chat_line("", "Use: /cla Nome TAG", "sistema")
			return
		_action("game_clan_create", {"p_name": p[0], "p_tag": p[1]})
		return
	social.say(text)
