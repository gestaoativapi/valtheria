extends CanvasLayer
# Telas: entrada (login, criar conta, escolha de personagem) e painel do jogo.

signal want_login(user: String, password: String)
signal want_signup(user: String, password: String)
signal want_offline
signal want_char(c: Dictionary)
signal want_quality
signal want_vsync
signal want_crowd
signal want_api
signal want_exit_to_login

const GOLD := Color(0.86, 0.72, 0.42)
const RACES := {"humano": "Humano", "elfo": "Elfo Branco", "sombrio": "Elfo Negro", "orc": "Orc", "anao": "Anão", "beastman": "Homem-Fera", "gigante": "Gigante", "draconato": "Dragonita"}

var font: Font
var root: Control
var login_box: Control
var char_box: VBoxContainer
var hud: Control
var user_edit: LineEdit
var pass_edit: LineEdit
var status: Label
var stats: Label
var who: Label
var btn_quality: Button
var btn_vsync: Button
var btn_api: Button
var bar_info: Label
var buttons: Array[Button] = []


func _ready() -> void:
	font = load("res://assets/cinzel.ttf")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_login()
	_build_hud()
	show_login()


func _panel_style(alpha := 0.82) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.06, 0.09, alpha)
	s.border_color = Color(GOLD, 0.55)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(28)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 18
	return s


func _button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46 if primary else 38)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 20 if primary else 16)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := StyleBoxFlat.new()
		var base := Color(0.55, 0.4, 0.16) if primary else Color(0.14, 0.16, 0.22)
		if st == "hover":
			base = base.lightened(0.15)
		if st == "pressed":
			base = base.darkened(0.2)
		if st == "disabled":
			base = Color(0.12, 0.12, 0.14)
		s.bg_color = base
		s.border_color = Color(GOLD, 0.7 if primary else 0.3)
		s.set_border_width_all(1)
		s.set_corner_radius_all(4)
		s.set_content_margin_all(8)
		b.add_theme_stylebox_override(st, s)
	b.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	buttons.append(b)
	return b


func _edit(placeholder: String, secret := false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 42)
	e.add_theme_font_size_override("font_size", 18)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.03, 0.05, 0.9)
	s.border_color = Color(GOLD, 0.35)
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10)
	e.add_theme_stylebox_override("normal", s)
	var f := s.duplicate() as StyleBoxFlat
	f.border_color = GOLD
	e.add_theme_stylebox_override("focus", f)
	return e


func _label(text: String, size := 16, color := Color(0.85, 0.86, 0.9), title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", font)
	return l


func _build_login() -> void:
	login_box = Control.new()
	login_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(login_box)
	# escurece as bordas para destacar o painel sobre o cenário ao vivo
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ float d = distance(UV, vec2(0.62, 0.45)); COLOR = vec4(0.02, 0.03, 0.05, smoothstep(0.25, 0.95, d) * 0.85 + (1.0 - smoothstep(0.0, 0.42, UV.x)) * 0.45); }"
	sm.shader = sh
	shade.material = sm
	login_box.add_child(shade)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.anchor_left = 0.06
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.anchor_right = 0.06
	panel.offset_right = 430
	panel.offset_top = -290
	panel.offset_bottom = 290
	login_box.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := _label("VALTHERIA", 56, GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(title)
	var sub := _label("Cliente nativo · protótipo %s" % ProjectSettings.get_setting("application/config/version"), 15, Color(0.75, 0.76, 0.8))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(HSeparator.new())

	var form := VBoxContainer.new()
	form.name = "Form"
	form.add_theme_constant_override("separation", 10)
	v.add_child(form)
	user_edit = _edit("Usuário")
	pass_edit = _edit("Senha", true)
	form.add_child(user_edit)
	form.add_child(pass_edit)
	var enter := _button("Jogar", true)
	enter.pressed.connect(func(): want_login.emit(user_edit.text, pass_edit.text))
	pass_edit.text_submitted.connect(func(_t): want_login.emit(user_edit.text, pass_edit.text))
	form.add_child(enter)
	var create := _button("Criar conta")
	create.pressed.connect(func(): want_signup.emit(user_edit.text, pass_edit.text))
	form.add_child(create)
	var off := _button("Entrar sem conta (teste)")
	off.pressed.connect(func(): want_offline.emit())
	form.add_child(off)

	char_box = VBoxContainer.new()
	char_box.add_theme_constant_override("separation", 10)
	char_box.visible = false
	v.add_child(char_box)

	status = _label("", 15, Color(1.0, 0.8, 0.5))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(0, 44)
	v.add_child(status)

	# barra de baixo: motor, placa de vídeo e troca de API gráfica
	var bar := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.03, 0.04, 0.06, 0.85)
	bs.set_content_margin_all(10)
	bar.add_theme_stylebox_override("panel", bs)
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.anchor_right = 1.0
	bar.offset_top = -58
	login_box.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	bar.add_child(h)
	bar_info = _label("", 14, Color(0.7, 0.72, 0.78))
	bar_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(bar_info)
	btn_api = _button("API gráfica")
	btn_api.pressed.connect(func(): want_api.emit())
	h.add_child(btn_api)
	var quit := _button("Sair")
	quit.pressed.connect(func(): get_tree().quit())
	h.add_child(quit)


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	root.add_child(hud)

	var plate := PanelContainer.new()
	var ps := _panel_style(0.7)
	ps.set_content_margin_all(12)
	ps.shadow_size = 6
	plate.add_theme_stylebox_override("panel", ps)
	plate.position = Vector2(16, 16)
	hud.add_child(plate)
	who = _label("", 20, GOLD, true)
	plate.add_child(who)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", ps)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -372
	right.offset_right = -16
	right.offset_top = 16
	hud.add_child(right)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	right.add_child(v)
	stats = _label("", 14, Color(0.86, 0.9, 0.86))
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.custom_minimum_size = Vector2(300, 0)
	v.add_child(stats)
	btn_quality = _button("Qualidade")
	btn_quality.pressed.connect(func(): want_quality.emit())
	v.add_child(btn_quality)
	btn_vsync = _button("VSync")
	btn_vsync.pressed.connect(func(): want_vsync.emit())
	v.add_child(btn_vsync)
	var crowd := _button("Multidão: +50 personagens")
	crowd.pressed.connect(func(): want_crowd.emit())
	v.add_child(crowd)
	var full := _button("Tela cheia (F11)")
	full.pressed.connect(toggle_fullscreen)
	v.add_child(full)
	var back := _button("Voltar à entrada (Esc)")
	back.pressed.connect(func(): want_exit_to_login.emit())
	v.add_child(back)

	var help := _label("W A S D ou clique no chão: andar   ·   Shift: correr   ·   botão direito + arrastar: girar a câmera   ·   roda do mouse: zoom   ·   1 2 3: golpes   ·   E: dançar", 14, Color(0.9, 0.9, 0.92))
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.anchor_right = 1.0
	help.offset_top = -34
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	help.add_theme_constant_override("outline_size", 6)
	hud.add_child(help)


func toggle_fullscreen() -> void:
	var w := get_window()
	w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func show_login() -> void:
	login_box.visible = true
	hud.visible = false
	char_box.visible = false
	login_box.find_child("Form", true, false).visible = true
	pass_edit.text = ""
	set_status("")
	busy(false)


func show_hud(name_text: String) -> void:
	login_box.visible = false
	hud.visible = true
	who.text = name_text


func set_status(t: String, error := true) -> void:
	status.text = t
	status.add_theme_color_override("font_color", Color(1.0, 0.62, 0.5) if error else Color(0.7, 0.9, 0.75))


func busy(b: bool) -> void:
	for x in buttons:
		if is_instance_valid(x) and login_box.is_ancestor_of(x):
			x.disabled = b


func show_chars(list: Array, account: String) -> void:
	busy(false)
	login_box.find_child("Form", true, false).visible = false
	for c in char_box.get_children():
		c.queue_free()
	char_box.visible = true
	char_box.add_child(_label("Conta: %s" % account, 15, Color(0.75, 0.78, 0.82)))
	if list.is_empty():
		var l := _label("Esta conta ainda não tem personagem. A criação de personagem continua na versão web; aqui você entra com um personagem de teste.", 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		char_box.add_child(l)
		var t := _button("Entrar com personagem de teste", true)
		t.pressed.connect(func(): want_char.emit({"name": account, "level": 1, "gender": "m", "race": "humano"}))
		char_box.add_child(t)
	else:
		char_box.add_child(_label("Escolha o personagem", 18, GOLD, true))
		for c in list:
			var d: Dictionary = c
			var race: String = RACES.get(str(d.get("race", "")), str(d.get("race", "")).capitalize())
			var b := _button("%s   ·   Nv %s   ·   %s" % [d.get("name", "?"), str(int(d.get("level", 1))), race], true)
			b.pressed.connect(func(): want_char.emit(d))
			char_box.add_child(b)
	var out := _button("Trocar de conta")
	out.pressed.connect(func(): want_exit_to_login.emit())
	char_box.add_child(out)
	set_status("")
