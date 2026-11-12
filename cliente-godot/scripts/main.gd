extends Node3D
# Valtheria - cliente nativo (protótipo): liga o mundo, o personagem, a câmera, a rede e as telas.

const World = preload("res://scripts/world.gd")
const Character = preload("res://scripts/character.gd")
const Net = preload("res://scripts/net.gd")
const UI = preload("res://scripts/ui.gd")

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


func _ready() -> void:
	compat = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	world = World.new()
	add_child(world)
	world.build()
	net = Net.new()
	add_child(net)
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.15
	cam.far = 900.0
	add_child(cam)
	cam.make_current()
	player = Character.create("m")
	add_child(player)
	_place_player(Vector3(3.5, 0.0, 6.0))
	facing = 2.6
	player.rotation.y = facing
	_npcs()
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
	add_child(ui)
	ui.want_login.connect(_login)
	ui.want_signup.connect(_signup)
	ui.want_offline.connect(func(): _enter({"name": "Viajante", "level": 1, "gender": "m", "race": "humano"}))
	ui.want_char.connect(_enter)
	ui.want_quality.connect(func(): _set_quality((quality + 1) % QUALITY.size()))
	ui.want_vsync.connect(_toggle_vsync)
	ui.want_crowd.connect(_spawn_crowd)
	ui.want_api.connect(_switch_api)
	ui.want_exit_to_login.connect(_to_login)
	_load_prefs()
	_set_quality(quality)
	_refresh_bar()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.trim_prefix("--shot=")
		elif a.begins_with("--lite"):
			var lite_q := a.trim_prefix("--lite=") if a.contains("=") else "0"  # teste em máquina sem placa de vídeo
			_set_quality(int(lite_q))
			shot_wait = 4
		elif a == "--play":
			_enter({"name": "Viajante", "level": 1, "gender": "m", "race": "humano"})
		elif a == "--crowd":
			_spawn_crowd()
		elif a.begins_with("--at="):
			var p := a.trim_prefix("--at=").split(",")
			_place_player(Vector3(float(p[0]), 0, float(p[1])))
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
			ui.show_chars([{"name": "Arthas", "level": 34, "race": "humano", "gender": "m"}, {"name": "Lyria", "level": 12, "race": "elfo", "gender": "f"}], "robson")


func _npcs() -> void:
	var spots := [[Vector3(-8.0, 0, 6.5), 0.9, "Idle_Talking", "f", "Mercadora"], [Vector3(-9.6, 0, -1.2), 1.4, "Idle_FoldArms", "m", "Ferreiro"], [Vector3(9.0, 0, -6.2), 0.6, "Idle", "f", "Viajante"], [Vector3(-2.2, 0, 2.2), 2.3, "Idle", "m", "Guarda"]]
	for s in spots:
		var n: Node3D = Character.create(s[3], s[4] == "Guarda")
		add_child(n)
		var p: Vector3 = s[0]
		n.position = Vector3(p.x, world.height(p.x, p.z), p.z)
		n.rotation.y = s[1]
		n.play(s[2])
		n.set_tag(s[4], Color(0.75, 0.9, 1.0))


func _place_player(p: Vector3) -> void:
	p = world.resolve(p)
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


func _enter(c: Dictionary) -> void:
	var gender := "f" if str(c.get("gender", "m")) == "f" else "m"
	var pos := player.position
	player.queue_free()
	player = Character.create(gender)
	add_child(player)
	player.position = pos
	player.rotation.y = facing
	var nm := str(c.get("name", "Viajante"))
	player.set_tag(nm)
	has_target = false
	playing = true
	yaw = facing + PI
	pitch = -0.3
	dist = 7.5
	ui.show_hud("%s   ·   Nv %d" % [nm, int(c.get("level", 1))])


func _to_login() -> void:
	playing = false
	net.logout()
	player.set_tag("")
	player.play("Idle")
	ui.show_login()
	_refresh_bar()


# ---------- preferências ----------
func _load_prefs() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://valtheria.cfg") == OK:
		ui.user_edit.text = str(cf.get_value("conta", "usuario", ""))
		if cf.has_section_key("video", nkey()):
			quality = clampi(int(cf.get_value("video", nkey(), 3)), 0, 4)
		else:
			quality = 0 if compat else 3
	else:
		quality = 0 if compat else 3  # primeira vez: modo compatibilidade começa no mínimo
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
	vp.scaling_3d_scale = [0.6, 0.75, 1.0, 1.0, 1.0][q]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X][q]
	world.sun.shadow_enabled = q >= 1
	world.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if q == 1 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096, 4096, 8192][q], true)
	world.sun.directional_shadow_max_distance = [40.0, 60.0, 140.0, 170.0, 220.0][q]
	world.fire.visible = q >= 1
	cam.far = [240.0, 420.0, 900.0, 900.0, 900.0][q]
	e.ssao_enabled = q >= 2
	e.glow_enabled = q >= 2
	e.adjustment_enabled = q >= 2
	e.volumetric_fog_enabled = q >= 3 and not compat
	e.ssil_enabled = q >= 4 and not compat
	e.sdfgi_enabled = q >= 4 and not compat
	world.set_detail(q)
	ui.btn_quality.text = "Qualidade: " + QUALITY[q]
	_save_prefs()


func _api_name() -> String:
	var d := RenderingServer.get_current_rendering_driver_name()
	return {"d3d12": "DirectX 12", "vulkan": "Vulkan", "opengl3": "OpenGL", "opengl3_angle": "OpenGL (ANGLE)", "metal": "Metal"}.get(d, d)


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
		var n: Node3D = Character.create("f" if rng.randf() < 0.5 else "m")
		add_child(n)
		var a := rng.randf() * TAU
		var r := rng.randf_range(5.0, 17.0)
		var p: Vector3 = world.resolve(Vector3(sin(a) * r, 0, cos(a) * r))
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
				_to_login()
			KEY_1:
				player.action("Sword_Regular_A")
			KEY_2:
				player.action("Sword_Regular_B")
			KEY_3:
				player.action("Sword_Regular_C")
			KEY_E:
				player.play("Dance")
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
			var hit: Variant = _ground_under(ev.position)
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
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input.x += 1.0
	if Input.is_physical_key_pressed(KEY_W): input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): input.y += 1.0
	var move := Vector3.ZERO
	if input.length() > 0.1:
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
		else:
			move = to.normalized()
	if player.is_busy():
		move = Vector3.ZERO
	if move != Vector3.ZERO:
		var sprint := Input.is_physical_key_pressed(KEY_SHIFT)
		var walk := Input.is_physical_key_pressed(KEY_CTRL)
		var speed := WALK if walk else (SPRINT if sprint else RUN)
		var step := speed * dt
		if has_target:  # nunca passa do destino
			var left := Vector2(target.x - player.position.x, target.z - player.position.z).length()
			step = minf(step, left)
		var p: Vector3 = world.resolve(player.position + move * step)
		player.position = Vector3(p.x, world.height(p.x, p.z), p.z)
		facing = lerp_angle(facing, atan2(move.x, move.z), minf(1.0, dt * 12.0))
		player.rotation.y = facing
		player.play("Walk" if walk else ("Sprint" if sprint else "Jog_Fwd"), 1.0 if not walk else 1.1)
	elif not player.is_busy() and player.current != "Dance":
		player.play("Idle")
	elif not player.is_busy() and player.current == "Dance" and has_target:
		player.play("Idle")


func _process(dt: float) -> void:
	if playing:
		var focus := player.position + Vector3(0, 1.45, 0)
		var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
		var want := focus + dir * dist
		var floor_y: float = world.height(want.x, want.z) + 0.35
		if want.y < floor_y:
			want.y = floor_y
		cam.position = cam.position.lerp(want, minf(1.0, dt * 14.0))
		cam.look_at(focus)
		if marker.visible:
			marker.rotation.y += dt * 2.0
	else:
		# tela de entrada: a câmera passeia devagar em volta da vila
		var t := Time.get_ticks_msec() * 0.00004
		var a := 2.2 + sin(t * TAU) * 0.55
		var c := Vector3(sin(a) * 15.0, 0, cos(a) * 15.0)
		cam.position = Vector3(c.x, world.height(c.x, c.z) + 3.6, c.z)
		cam.look_at(Vector3(-1.0, 2.6, 0.0))
	smooth_fps = lerpf(smooth_fps, Engine.get_frames_per_second(), 0.1)
	if playing and Engine.get_frames_drawn() % 15 == 0:
		var size := get_window().size
		ui.stats.text = "%d FPS   ·   %.1f ms\n%s   ·   %d x %d\n%s\nObjetos desenhados: %d\nChamadas de desenho: %d\nTriângulos: %s\nÁrvores no mapa: %d\nTufos de grama: %s\nPersonagens animados: %d" % [
			int(Engine.get_frames_per_second()), 1000.0 / maxf(1.0, Engine.get_frames_per_second()), _api_name(), size.x, size.y, RenderingServer.get_video_adapter_name(),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			_fmt(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))), world.counts.arvores, _fmt(world.counts.grama), 5 + crowd.size()]
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
	return "nivel_gl" if compat else "nivel"
