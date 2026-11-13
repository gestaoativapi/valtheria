extends CanvasLayer

const Character = preload("res://scripts/character.gd")
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
signal want_new_char
signal want_create(o: Dictionary)
signal want_preview(o: Dictionary)
signal want_back_to_chars
signal want_skill(i: int)
signal want_action(fn: String, args: Dictionary)
signal want_window(name: String)
signal want_chat(text: String)

const GOLD := Color(0.86, 0.72, 0.42)

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
var info := {}
var create_box: VBoxContainer
var name_edit: LineEdit
var opt := {}
var race_ids: Array = []
var place_label: Label
var last_chars: Array = []
var last_account := ""
var bar_hp: ProgressBar
var bar_mp: ProgressBar
var bar_xp: ProgressBar
var bar_txt := {}
var tgt_box: PanelContainer
var tgt_name: Label
var tgt_bar: ProgressBar
var hot: Array[Button] = []
var toast: Label
var toast_until := 0.0
var win: PanelContainer
var win_title: Label
var win_list: VBoxContainer
var win_name := ""
var chat_log: RichTextLabel
var chat_edit: LineEdit
var assist: Array[Button] = []
var assist_ids: Array = []
var sel := ""
var sel_eq := false
var w_me := {}
var w_inv := {}
var w_extra := {}
var movers := {}
var drag: Control
var drag_off := Vector2.ZERO
var resizing := false
var placed := false
var hot_panel: PanelContainer
var chat_panel: Control
var plate_panel: Control
var right_panel: Control
var ui_scale := 1.0
var tab := "equip"
var shop_cat := "armas"
var doll_char: Node3D


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
	s.bg_color = Color(0.055, 0.06, 0.08, alpha)
	s.border_color = Color(0.5, 0.39, 0.2)
	s.set_border_width_all(2)
	s.border_width_top = 3
	s.set_corner_radius_all(3)
	s.set_content_margin_all(14)
	s.shadow_color = Color(GOLD, 0.45)  # filete dourado por fora da borda de bronze
	s.shadow_size = 1
	return s


const GRADES := ["NG", "D", "C", "B", "A", "S", "SS"]
const GRADE_COL := [Color(0.62, 0.62, 0.62), Color(0.78, 0.58, 0.35), Color(0.84, 0.87, 0.9), Color(0.35, 0.66, 1.0), Color(1.0, 0.4, 0.38), Color(0.83, 0.55, 1.0), Color(1.0, 0.82, 0.3)]


func grade_of(id: String) -> int:
	if id.begins_with("lend_") or id.begins_with("set_") or id.begins_with("anel_") or id.begins_with("asas_"):
		return 6  # lendário
	return clampi(int(info.items.get(id, {}).get("grade", 0)), 0, 5)


# cartão quadrado (item, habilidade); cor = borda do grau
func _card(size: float, col: Color, selected := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color(0.93, 0.92, 0.88))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.62))
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.11, 0.14, 0.95) if st != "hover" else Color(0.17, 0.18, 0.22, 0.95)
		if st == "disabled":
			sb.bg_color = Color(0.05, 0.05, 0.06, 0.95)
		sb.border_color = col if not selected else Color(1, 1, 1)
		sb.set_border_width_all(2 if selected else 1)
		sb.border_width_bottom = 3
		sb.set_corner_radius_all(2)
		sb.set_content_margin_all(3)
		b.add_theme_stylebox_override(st, sb)
	return b


func _short(name: String) -> String:
	var w := name.split(" ", false)
	if w.size() == 1:
		return name.left(8)
	return w[0].left(6) + "\n" + w[w.size() - 1].left(6)


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
	panel.offset_top = -330
	panel.offset_bottom = 330
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

	create_box = VBoxContainer.new()
	create_box.add_theme_constant_override("separation", 7)
	create_box.visible = false
	v.add_child(create_box)
	_build_create()

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
	var pv := VBoxContainer.new()
	plate.add_child(pv)
	who = _label("", 20, GOLD, true)
	pv.add_child(who)
	place_label = _label("", 14, Color(0.85, 0.88, 0.92))
	pv.add_child(place_label)
	bar_hp = _bar(pv, Color(0.78, 0.2, 0.18), "hp")
	bar_mp = _bar(pv, Color(0.2, 0.42, 0.85), "mp")
	bar_xp = _bar(pv, Color(0.8, 0.66, 0.25), "xp")

	tgt_box = PanelContainer.new()
	tgt_box.add_theme_stylebox_override("panel", ps)
	tgt_box.anchor_left = 0.5
	tgt_box.anchor_right = 0.5
	tgt_box.offset_left = -170
	tgt_box.offset_right = 170
	tgt_box.offset_top = 16
	tgt_box.visible = false
	hud.add_child(tgt_box)
	var tv := VBoxContainer.new()
	tgt_box.add_child(tv)
	tgt_name = _label("", 16, Color(1, 0.92, 0.8))
	tgt_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(tgt_name)
	tgt_bar = _bar(tv, Color(0.78, 0.2, 0.18), "tgt")

	hot_panel = PanelContainer.new()
	var hps := _panel_style(0.78)
	hps.set_content_margin_all(6)
	hot_panel.add_theme_stylebox_override("panel", hps)
	hot_panel.anchor_left = 0.5
	hot_panel.anchor_right = 0.5
	hot_panel.anchor_top = 1.0
	hot_panel.anchor_bottom = 1.0
	hot_panel.offset_left = -262
	hot_panel.offset_right = 262
	hot_panel.offset_top = -162
	hot_panel.offset_bottom = -40
	hud.add_child(hot_panel)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	hot_panel.add_child(grid)
	for i in 9:
		var b := _card(52, Color(GOLD, 0.7))
		b.pressed.connect(func(): want_skill.emit(i))
		grid.add_child(b)
		hot.append(b)
	for i in 9:
		var b := _card(52, Color(0.4, 0.62, 0.5))
		b.pressed.connect(func(): use_assist(i))
		grid.add_child(b)
		assist.append(b)

	# janela única (bolsa, loja, ofício, clã)
	win = PanelContainer.new()
	win.add_theme_stylebox_override("panel", _panel_style(0.93))
	win.anchor_left = 0.5
	win.anchor_right = 0.5
	win.anchor_top = 0.5
	win.anchor_bottom = 0.5
	win.offset_left = -350
	win.offset_right = 350
	win.offset_top = -300
	win.offset_bottom = 270
	win.visible = false
	hud.add_child(win)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 8)
	win.add_child(wv)
	var wh := HBoxContainer.new()
	wv.add_child(wh)
	win_title = _label("", 19, GOLD, true)
	win_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(win_title)
	var wx := _button("X")
	wx.custom_minimum_size = Vector2(34, 30)
	wx.pressed.connect(close_window)
	wh.add_child(wx)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wv.add_child(sc)
	win_list = VBoxContainer.new()
	win_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	win_list.add_theme_constant_override("separation", 4)
	sc.add_child(win_list)
	var grip := _label("◢ arraste para ajustar", 11, Color(GOLD, 0.7))
	grip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	grip.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			resizing = ev.pressed
			if not ev.pressed:
				_save_layout()
		elif ev is InputEventMouseMotion and resizing:
			win.size = Vector2(clampf(win.size.x + ev.relative.x, 420, 1100), clampf(win.size.y + ev.relative.y, 300, 820)))
	wv.add_child(grip)

	# atalhos das janelas
	var menu := HBoxContainer.new()
	menu.anchor_left = 1.0
	menu.anchor_right = 1.0
	menu.anchor_top = 1.0
	menu.anchor_bottom = 1.0
	menu.offset_left = -600
	menu.offset_right = -16
	menu.offset_top = -92
	menu.offset_bottom = -48
	menu.alignment = BoxContainer.ALIGNMENT_END
	hud.add_child(menu)
	for def in [["Bolsa (I)", "bolsa"], ["Loja (B)", "loja"], ["Ofício (C)", "oficio"], ["Classe (K)", "classe"], ["Clã (G)", "cla"]]:
		var mb := _button(def[0])
		mb.focus_mode = Control.FOCUS_NONE
		mb.pressed.connect(func(): want_window.emit(def[1]))
		menu.add_child(mb)

	# bate-papo
	var cb := VBoxContainer.new()
	chat_panel = cb
	cb.anchor_top = 1.0
	cb.anchor_bottom = 1.0
	cb.offset_left = 16
	cb.offset_right = 420
	cb.offset_top = -250
	cb.offset_bottom = -48
	hud.add_child(cb)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_log.add_theme_font_size_override("normal_font_size", 14)
	chat_log.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	chat_log.add_theme_constant_override("outline_size", 5)
	cb.add_child(chat_log)
	chat_edit = _edit("Enter para conversar")
	chat_edit.custom_minimum_size = Vector2(0, 32)
	chat_edit.add_theme_font_size_override("font_size", 14)
	chat_edit.max_length = 160
	chat_edit.text_submitted.connect(func(t):
		chat_edit.text = ""
		chat_edit.release_focus()
		want_chat.emit(t))
	cb.add_child(chat_edit)

	toast = _label("", 22, Color(1, 0.93, 0.7), true)
	toast.anchor_left = 0.0
	toast.anchor_right = 1.0
	toast.offset_top = 96
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast.add_theme_constant_override("outline_size", 8)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(toast)
	_movable(win, "janela")
	_movable(hot_panel, "barra")
	_movable(plate, "status")
	_movable(tgt_box, "alvo")

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
	_movable(right, "painel")
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
	var bs := _button("Interface: 100%")
	bs.pressed.connect(func(): bs.text = cycle_scale())
	v.add_child(bs)
	var full := _button("Tela cheia (F11)")
	full.pressed.connect(toggle_fullscreen)
	v.add_child(full)
	var back := _button("Voltar à entrada (Esc)")
	back.pressed.connect(func(): want_exit_to_login.emit())
	v.add_child(back)

	var help := _label("W A S D ou clique: andar   ·   clique no monstro: alvo (2º clique ou F: atacar)   ·   Tab: próximo alvo   ·   1 a 9: habilidades   ·   F1 a F9: itens   ·   arraste os painéis para mover", 14, Color(0.9, 0.9, 0.92))
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.anchor_right = 1.0
	help.offset_top = -34
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	help.add_theme_constant_override("outline_size", 6)
	hud.add_child(help)


func _bar(parent: Control, col: Color, key: String) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(250, 18)
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(3)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	var l := _label("", 12, Color.WHITE)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)
	bar_txt[key] = l
	parent.add_child(b)
	return b


func set_bars(hp: float, max_hp: float, mp: float, max_mp: float, xp: float, need: float) -> void:
	bar_hp.max_value = max_hp
	bar_hp.value = hp
	bar_txt.hp.text = "Vida %d / %d" % [int(hp), int(max_hp)]
	bar_mp.max_value = max_mp
	bar_mp.value = mp
	bar_txt.mp.text = "Mana %d / %d" % [int(mp), int(max_mp)]
	bar_xp.max_value = maxf(need, 1.0)
	bar_xp.value = xp
	bar_txt.xp.text = "XP %.1f%%" % (xp / maxf(need, 1.0) * 100.0)


func set_target(m) -> void:
	tgt_box.visible = m != null
	if m != null:
		tgt_name.text = "%s   ·   Nv %d" % [m.fam.name, int(m.L)]
		tgt_bar.max_value = m.maxHp
		tgt_bar.value = maxf(0.0, m.hp)
		bar_txt.tgt.text = "%d / %d" % [int(maxf(0.0, m.hp)), int(m.maxHp)]


func set_skills(list: Array) -> void:
	for i in hot.size():
		hot[i].disabled = i >= list.size()
		if i < list.size():
			hot[i].set_meta("nome", "%d\n%s" % [i + 1, _short(str(list[i].name))])
			hot[i].text = hot[i].get_meta("nome")
			hot[i].tooltip_text = "%s  (tecla %d)\nMana %d   ·   recarga %ds" % [list[i].name, i + 1, int(list[i].mp), int(list[i].cd)]
		else:
			hot[i].set_meta("nome", str(i + 1))
			hot[i].text = str(i + 1)
			hot[i].tooltip_text = "Vazio: novas habilidades chegam com o nível e a classe"


func set_cooldowns(cds: Array, now: float) -> void:
	for i in hot.size():
		if i < cds.size():
			var left: float = float(cds[i]) - now
			hot[i].disabled = left > 0.0
			hot[i].text = ("%d\n%.0fs" % [i + 1, ceilf(left)]) if left > 0.0 else str(hot[i].get_meta("nome"))


# barra de assistência: poções e pergaminhos da bolsa, um por espaço (F1 a F9)
func set_assist(inv: Dictionary) -> void:
	assist_ids = []
	for id in inv:
		if str(info.items.get(str(id), {}).get("type", "")) in ["potion", "scroll", "special"] and assist_ids.size() < 9:
			assist_ids.append(str(id))
	for i in assist.size():
		if i < assist_ids.size():
			var it: Dictionary = info.items[assist_ids[i]]
			assist[i].text = "F%d\n%s\nx%d" % [i + 1, str(it.name).split(" ")[0].left(6), int(inv[assist_ids[i]])]
			assist[i].tooltip_text = "%s  (tecla F%d)" % [it.name, i + 1]
			assist[i].disabled = false
		else:
			assist[i].text = "F%d" % (i + 1)
			assist[i].tooltip_text = "Vazio: poções e pergaminhos da bolsa aparecem aqui"
			assist[i].disabled = true


func use_assist(i: int) -> void:
	if i < assist_ids.size():
		want_action.emit("game_use", {"p_item": assist_ids[i]})


# ---------- janelas e painéis móveis, que grudam nas bordas da tela ----------
func _movable(c: Control, key: String) -> void:
	movers[key] = c
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				drag = c
				drag_off = c.get_global_mouse_position() - c.global_position
			elif drag == c:
				drag = null
				_snap(c)
				_save_layout()
		elif ev is InputEventMouseMotion and drag == c:
			c.global_position = c.get_global_mouse_position() - drag_off
			_snap(c, false))


func _snap(c: Control, magnet := true) -> void:
	var vp := root.size
	var p := c.position
	var m := 14.0 if magnet else 0.0
	if p.x < m: p.x = 4.0 if magnet else 0.0
	if p.y < m: p.y = 4.0 if magnet else 0.0
	if p.x + c.size.x > vp.x - m: p.x = vp.x - c.size.x - (4.0 if magnet else 0.0)
	if p.y + c.size.y > vp.y - m: p.y = vp.y - c.size.y - (4.0 if magnet else 0.0)
	c.position = Vector2(maxf(p.x, 0.0), maxf(p.y, 0.0))


func _save_layout() -> void:
	var cf := ConfigFile.new()
	cf.load("user://interface.cfg")
	for k in movers:
		cf.set_value("pos", k, (movers[k] as Control).position)
	cf.set_value("janela", "tamanho", win.size)
	cf.set_value("janela", "escala", ui_scale)
	cf.save("user://interface.cfg")


# na primeira vez que o painel do jogo aparece: solta os painéis das âncoras e aplica as posições salvas
func _place_panels() -> void:
	if placed:
		return
	placed = true
	await get_tree().process_frame
	await get_tree().process_frame
	var cf := ConfigFile.new()
	cf.load("user://interface.cfg")
	for k in movers:
		var c: Control = movers[k]
		var keep_vis := c.visible
		c.visible = true
		var r := c.get_rect()
		c.set_anchors_preset(Control.PRESET_TOP_LEFT)
		c.position = cf.get_value("pos", k, r.position)
		c.size = r.size
		c.visible = keep_vis
		_snap(c, false)
	win.size = cf.get_value("janela", "tamanho", win.size)


func cycle_scale() -> String:
	ui_scale = {1.0: 0.85, 0.85: 1.15, 1.15: 1.0}.get(ui_scale, 1.0)
	get_window().content_scale_factor = ui_scale
	_save_layout()
	for k in movers:
		_snap(movers[k], false)
	return "Interface: %d%%" % int(ui_scale * 100.0)


func typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit


func chat_line(who_name: String, msg: String, kind := "chat") -> void:
	var safe := msg.replace("[", "[lb]")
	if kind == "chat":
		chat_log.append_text("[color=#ffd98a]%s:[/color] %s\n" % [who_name.replace("[", "[lb]"), safe])
	else:
		chat_log.append_text("[color=#9fd0ff]%s[/color]\n" % safe)


func close_window() -> void:
	win.visible = false
	win_name = ""


func _row(text: String, actions: Array, color := Color(0.88, 0.89, 0.93)) -> void:
	var h := HBoxContainer.new()
	var l := _label(text, 15, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	for a in actions:
		var b := _button(a[0])
		b.custom_minimum_size = Vector2(92, 30)
		b.add_theme_font_size_override("font_size", 13)
		b.focus_mode = Control.FOCUS_NONE
		var fn: String = a[1]
		var args: Dictionary = a[2]
		b.pressed.connect(func(): want_action.emit(fn, args))
		h.add_child(b)
	win_list.add_child(h)


var stats_view := {}


func _inset() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.05, 0.9)
	sb.border_color = Color(0.36, 0.29, 0.16)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(8)
	return sb


func _note(text: String) -> void:
	var l := _label(text, 14, Color(0.75, 0.77, 0.82))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win_list.add_child(l)


func _tabs(defs: Array, current: String, on_pick: Callable) -> void:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 6)
	for d in defs:
		var b := _button(d[1], d[0] == current)
		b.custom_minimum_size = Vector2(0, 34)
		b.add_theme_font_size_override("font_size", 14)
		b.focus_mode = Control.FOCUS_NONE
		var key: String = d[0]
		b.pressed.connect(func(): on_pick.call(key))
		h.add_child(b)
	win_list.add_child(h)


func _stat_lines(it: Dictionary) -> Array:
	var names := {"patk": "Ataque", "matk": "Magia", "pdef": "Defesa", "mdef": "Defesa mágica", "hp": "Vida", "mp": "Mana", "hpPct": "Recupera vida", "mpPct": "Recupera mana", "spd": "Velocidade", "matkPct": "Magia"}
	var out: Array = []
	for k in it.get("stats", {}):
		var v: float = it.stats[k]
		out.append("%s: %s" % [names.get(k, k), ("%d%%" % int(v * 100.0)) if (str(k).ends_with("Pct") or k == "spd") else ("%.1f" % v if v < 3.0 else str(int(v)))])
	return out


# cartão de item para lojas: cada informação na sua linha, preço em quadro próprio
func _item_card(title: String, g: int, lines: Array, price: String, action: String, fn: String, args: Dictionary, enabled: bool) -> Control:
	var pc := PanelContainer.new()
	var sb := _inset()
	sb.border_color = GRADE_COL[g]
	sb.border_width_top = 3
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(196, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	pc.add_child(v)
	var t := _label(title, 15, GRADE_COL[g], true)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	v.add_child(_label("Grau %s" % GRADES[g], 12, Color(0.7, 0.72, 0.78)))
	for ln in lines:
		var l := _label(str(ln), 13)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	if price != "":
		var pp := PanelContainer.new()
		var ps := _inset()
		ps.bg_color = Color(0.12, 0.1, 0.05, 0.9)
		pp.add_theme_stylebox_override("panel", ps)
		var pl := _label(price, 15, GOLD, true)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pp.add_child(pl)
		v.add_child(pp)
	var b := _button(action, enabled)
	b.custom_minimum_size = Vector2(0, 32)
	b.add_theme_font_size_override("font_size", 14)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	b.pressed.connect(func(): want_action.emit(fn, args))
	v.add_child(b)
	return pc


# painel de detalhe do item escolhido
func _detail(title: String, g: int, lines: Array, extra_line: String, acts: Array) -> void:
	var pc := PanelContainer.new()
	var sb := _inset()
	sb.border_color = GRADE_COL[g]
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	pc.add_child(v)
	v.add_child(_label(title, 16, GRADE_COL[g], true))
	v.add_child(_label("Grau %s%s" % [GRADES[g], " (lendário)" if g == 6 else ""], 12, Color(0.7, 0.72, 0.78)))
	for ln in lines:
		v.add_child(_label(str(ln), 13))
	if extra_line != "":
		v.add_child(_label(extra_line, 13, GOLD))
	var h := HFlowContainer.new()
	for a in acts:
		var b := _button(a[0], true)
		b.custom_minimum_size = Vector2(120, 32)
		b.add_theme_font_size_override("font_size", 14)
		b.focus_mode = Control.FOCUS_NONE
		var fn: String = a[1]
		var args: Dictionary = a[2]
		b.pressed.connect(func(): want_action.emit(fn, args))
		h.add_child(b)
	v.add_child(h)
	win_list.add_child(pc)


# encaixe de equipamento: moldura rebaixada com o nome do local e a peça dentro
func _socket(slot: String, id: String, g: int, selected: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(118, 104)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 12)
	b.text = "%s\n\n%s" % [slot.to_upper(), ("%s\nGrau %s" % [str(info.items.get(id, {}).get("name", id)), GRADES[g]]) if id != "" else "vazio"]
	b.add_theme_color_override("font_color", GRADE_COL[g] if id != "" else Color(0.45, 0.46, 0.5))
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.02, 0.025, 0.035, 0.95) if st != "hover" else Color(0.08, 0.09, 0.12, 0.95)
		sb.border_color = Color(1, 1, 1) if selected else (GRADE_COL[g] if id != "" else Color(0.36, 0.29, 0.16))
		sb.border_width_left = 4
		sb.border_width_right = 4
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.corner_radius_top_left = 10
		sb.corner_radius_bottom_right = 10
		sb.set_content_margin_all(6)
		sb.shadow_color = Color(0, 0, 0, 0.6)
		sb.shadow_size = 3
		b.add_theme_stylebox_override(st, sb)
	return b


# boneco 3D do personagem, girando devagar, dentro da janela
func _doll(me: Dictionary) -> Control:
	var holder := PanelContainer.new()
	holder.add_theme_stylebox_override("panel", _inset())
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(250, 340)
	svc.stretch = true
	holder.add_child(svc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(vp)
	doll_char = Character.create(me)
	vp.add_child(doll_char)
	var cam := Camera3D.new()
	var h: float = doll_char.height_m
	cam.position = Vector3(0, h * 0.55, h * 1.75)
	cam.fov = 38.0
	vp.add_child(cam)
	cam.look_at(Vector3(0, h * 0.5, 0))
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.3
	vp.add_child(key)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	return holder


func _stat_text(it: Dictionary) -> String:
	var names := {"patk": "ataque", "matk": "magia", "pdef": "defesa", "mdef": "def. mágica", "hp": "vida", "mp": "mana", "hpPct": "cura", "mpPct": "mana"}
	var out: Array = []
	for k in it.get("stats", {}):
		var v: float = it.stats[k]
		out.append("%s %s" % [names.get(k, k), ("%d%%" % int(v * 100.0)) if str(k).ends_with("Pct") else ("%.1f" % v if v < 3.0 else str(int(v)))])
	return "  (" + ", ".join(out) + ")" if not out.is_empty() else ""


# desenha a janela pedida com os dados atuais; me = personagem, inv = bolsa, extra = dados do clã
func open_window(name: String, me: Dictionary, inv: Dictionary, extra := {}) -> void:
	win_name = name
	win.visible = true
	for c in win_list.get_children():
		c.queue_free()
	var items: Dictionary = info.items
	var aurum := int(me.get("aurum", 0))
	w_me = me
	w_inv = inv
	w_extra = extra
	if name == "bolsa":
		win_title.text = "◆ Personagem   ·   %d aurum" % aurum
		var eq: Dictionary = me.get("equipment") if me.get("equipment") is Dictionary else {}
		_tabs([["equip", "Equipamento"], ["bolsa", "Bolsa"], ["attr", "Atributos"]], tab, func(k):
			tab = k
			sel = ""
			open_window("bolsa", w_me, w_inv, w_extra))
		if tab == "equip":
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 12)
			win_list.add_child(row)
			var left := VBoxContainer.new()
			left.add_theme_constant_override("separation", 10)
			var right := VBoxContainer.new()
			right.add_theme_constant_override("separation", 10)
			row.add_child(left)
			row.add_child(_doll(me))
			row.add_child(right)
			var side := {"elmo": left, "armadura": left, "luvas": left, "arma": right, "escudo": right, "botas": right}
			for slot in ["elmo", "armadura", "luvas", "arma", "escudo", "botas"]:
				var id := str(eq.get(slot, ""))
				var g := grade_of(id) if id != "" else 0
				var cb := _socket(slot, id, g, sel_eq and sel == slot)
				cb.pressed.connect(func():
					sel = slot
					sel_eq = true
					open_window("bolsa", w_me, w_inv, w_extra))
				(side[slot] as VBoxContainer).add_child(cb)
			var sid := str(eq.get(sel, "")) if sel_eq else ""
			if sid != "":
				var it: Dictionary = items.get(sid, {})
				_detail(it.get("name", sid), grade_of(sid), _stat_lines(it), "", [["Tirar", "game_unequip", {"p_slot": sel}]])
			else:
				_note("Clique em um encaixe para ver a peça. Para vestir um item, abra a aba Bolsa.")
		elif tab == "bolsa":
			var bag := HFlowContainer.new()
			bag.add_theme_constant_override("h_separation", 6)
			bag.add_theme_constant_override("v_separation", 6)
			win_list.add_child(bag)
			for id in inv:
				var it: Dictionary = items.get(str(id), {})
				var g := grade_of(str(id))
				var cb := _card(72, GRADE_COL[g], not sel_eq and sel == str(id))
				cb.text = "%s\n%s\nx%d" % [_short(str(it.get("name", id))), GRADES[g], int(inv[id])]
				cb.tooltip_text = str(it.get("name", id))
				cb.pressed.connect(func():
					sel = str(id)
					sel_eq = false
					open_window("bolsa", w_me, w_inv, w_extra))
				bag.add_child(cb)
			for i in maxi(0, 28 - inv.size()):
				var e := _card(72, Color(0.22, 0.22, 0.26))
				e.disabled = true
				bag.add_child(e)
			if not sel_eq and sel != "" and inv.has(sel):
				var it: Dictionary = items.get(sel, {})
				var acts: Array = []
				if str(it.get("slot", "")) != "":
					acts.append(["Equipar", "game_equip", {"p_item": sel}])
				elif str(it.get("type", "")) in ["potion", "scroll", "special"]:
					acts.append(["Usar", "game_use", {"p_item": sel}])
				acts.append(["Vender", "game_npc_sell", {"p_item": sel, "p_qty": 1}])
				_detail(it.get("name", sel), grade_of(sel), _stat_lines(it), "Venda: %d aurum" % int(it.get("sell", 1)), acts)
			else:
				_note("Clique em um item para ver os detalhes.")
		else:
			var cl: Dictionary = info.classes.get(str(me.get("class_id", "")), {})
			var lines := ["Nome: %s" % me.get("name", "-"), "Raça: %s" % info.races.get(str(me.get("race", "")), {}).get("name", "-"), "Classe: %s" % cl.get("name", "-"), "Nível: %d" % int(me.get("level", 1))]
			for k in stats_view:
				lines.append("%s: %s" % [k, stats_view[k]])
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 8)
			flow.add_theme_constant_override("v_separation", 8)
			win_list.add_child(flow)
			for t in lines:
				var pc := PanelContainer.new()
				pc.add_theme_stylebox_override("panel", _inset())
				pc.custom_minimum_size = Vector2(190, 0)
				pc.add_child(_label(t, 14))
				flow.add_child(pc)
	elif name == "loja":
		win_title.text = "◆ Mercador   ·   %d aurum" % aurum
		_note("\"Bem-vindo, viajante. Tenho de tudo um pouco. Diga o que procura e eu mostro o que há na banca.\"")
		_tabs([["armas", "Armas"], ["armaduras", "Armaduras"], ["pecas", "Elmos, luvas e botas"], ["consumo", "Poções e utilidades"]], shop_cat, func(k):
			shop_cat = k
			open_window("loja", w_me, w_inv, w_extra))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		win_list.add_child(flow)
		for id in info.shop:
			var it: Dictionary = items.get(str(id), {})
			var slot := str(it.get("slot", ""))
			var cat := "armas" if slot == "arma" else ("armaduras" if slot in ["armadura", "escudo"] else ("pecas" if slot != "" else "consumo"))
			if cat != shop_cat:
				continue
			flow.add_child(_item_card(str(it.get("name", id)), grade_of(str(id)), _stat_lines(it), "%d aurum" % int(info.shop[id]), "Comprar", "game_shop_buy", {"p_item": id, "p_qty": 1}, aurum >= int(info.shop[id])))
	elif name == "oficio":
		win_title.text = "◆ Ferreiro   ·   ofício"
		_note("\"Traga o material que eu mostro o que dá para fazer. O que você já pode fabricar aparece primeiro.\"")
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		win_list.add_child(flow)
		var shown := 0
		for pass_i in 2:
			for r in info.recipes:
				var can := true
				var parts: Array = []
				for k in r.inputs:
					parts.append("%s: %d de %d" % [items.get(str(k), {}).get("name", k), int(inv.get(k, 0)), int(r.inputs[k])])
					if int(inv.get(k, 0)) < int(r.inputs[k]):
						can = false
				if (pass_i == 0) != can or (pass_i == 1 and shown > 40):
					continue
				shown += 1
				flow.add_child(_item_card("%s x%d" % [items.get(str(r.out), {}).get("name", r.out), int(r.qty)], grade_of(str(r.out)), parts, "", "Fabricar", "game_craft", {"p_recipe": r.id, "p_times": 1}, can))
	elif name == "classe":
		var cur := str(me.get("class_id", ""))
		var cl: Dictionary = info.classes.get(cur, {})
		var lvl := int(me.get("level", 1))
		win_title.text = "Classe: %s   ·   nível %d" % [cl.get("name", "-"), lvl]
		var found := false
		for k in info.classes:
			var nc: Dictionary = info.classes[k]
			if str(nc.get("parent", "")) != cur:
				continue
			found = true
			var need := int(info.rank_lvl[clampi(int(nc.rank), 0, info.rank_lvl.size() - 1)])
			var arch: Dictionary = info.arch.get(str(nc.arch), {})
			var txt := "%s   ·   %s   ·   requer nível %d%s" % [nc.name, arch.get("name", ""), need, "   ·   exclusiva da raça" if nc.get("excl", false) else ""]
			_row(txt, [["Evoluir", "game_class_change", {"p_class": k}]] if lvl >= need else [], Color(0.88, 0.89, 0.93) if lvl >= need else Color(0.55, 0.56, 0.6))
		if not found:
			_row("Você já está na última classe desta linha.", [])
		_row("A evolução só pode ser feita dentro de uma cidade.", [], Color(0.6, 0.62, 0.68))
	elif name == "cla":
		win_title.text = "Clãs"
		if extra.is_empty():
			_row("Entre com uma conta para ver os clãs.", [])
			return
		var mine: Variant = extra.get("clan")
		if mine is Dictionary:
			_row("Seu clã: [%s] %s   ·   nível %s   ·   %s pontos" % [mine.get("tag", ""), mine.get("name", ""), str(mine.get("level", 1)), str(mine.get("points", 0))], [["Sair", "game_clan_leave", {}]], GOLD)
			if extra.get("members") is Array:
				for m in extra.members:
					_row("   %s   ·   Nv %s" % [m.get("name", "?"), str(m.get("level", "?"))], [])
		else:
			_row("Você não está em um clã. Para criar: escreva no bate-papo  /cla Nome TAG", [])
		if extra.get("invites") is Array:
			for iv in extra.invites:
				_row("Convite: [%s] %s (por %s)" % [iv.get("tag", ""), iv.get("name", ""), iv.get("by", "")], [["Aceitar", "game_clan_answer", {"p_clan": iv.get("clan_id"), "p_accept": true}], ["Recusar", "game_clan_answer", {"p_clan": iv.get("clan_id"), "p_accept": false}]])
		_row("Ranking", [], GOLD)
		if extra.get("top") is Array:
			for t in extra.top:
				_row("[%s] %s   ·   nível %s   ·   %s pontos   ·   %s membros" % [t.get("tag", ""), t.get("name", ""), str(t.get("level", 1)), str(t.get("points", 0)), str(t.get("n", 0))], [])


func say(t: String) -> void:
	toast.text = t
	toast_until = Time.get_ticks_msec() * 0.001 + 2.2


func set_who(c: Dictionary) -> void:
	who.text = "%s   ·   Nv %d" % [str(c.get("name", "Viajante")), int(c.get("level", 1))]


func _process(_dt: float) -> void:
	if doll_char and is_instance_valid(doll_char) and win.visible:
		doll_char.rotation.y += _dt * 0.7
	if toast and toast.text != "" and Time.get_ticks_msec() * 0.001 > toast_until:
		toast.text = ""


func toggle_fullscreen() -> void:
	var w := get_window()
	w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _option(title: String, items: Array) -> OptionButton:
	var h := HBoxContainer.new()
	var l := _label(title, 15)
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.add_theme_font_size_override("font_size", 15)
	for it in items:
		ob.add_item(str(it))
	ob.item_selected.connect(func(_i): _preview())
	h.add_child(ob)
	create_box.add_child(h)
	return ob


func _build_create() -> void:
	create_box.add_child(_label("Novo personagem", 18, GOLD, true))
	name_edit = _edit("Nome (3 a 16 letras ou números)")
	name_edit.max_length = 16
	create_box.add_child(name_edit)
	race_ids = (info.get("races", {}) as Dictionary).keys()
	opt.race = _option("Raça", race_ids.map(func(k): return info.races[k].name))
	opt.race.item_selected.connect(func(_i): _race_changed())
	opt.gender = _option("Gênero", ["Masculino", "Feminino"])
	opt.type = _option("Caminho", ["Lutador", "Místico"])
	opt.skin = _option("Tom de pele", [])
	opt.hair = _option("Cabelo", info.get("hair_styles", []))
	opt.hair_color = _option("Cor do cabelo", ["Preto", "Castanho", "Loiro", "Platinado", "Ruivo", "Azul", "Branco", "Verde", "Rosa", "Roxo"])
	var ok := _button("Criar personagem", true)
	ok.pressed.connect(func():
		var o := creation()
		o.name = name_edit.text.strip_edges()
		want_create.emit(o))
	create_box.add_child(ok)
	var back := _button("Voltar")
	back.pressed.connect(func(): want_back_to_chars.emit())
	create_box.add_child(back)
	if not race_ids.is_empty():
		_race_changed(false)


func _race_changed(emit := true) -> void:
	var rd: Dictionary = info.races[race_ids[opt.race.selected]]
	opt.skin.clear()
	for i in (rd.skins as Array).size():
		opt.skin.add_item("Tom %d" % (i + 1))
	opt.type.clear()
	for t in rd.types:
		opt.type.add_item(str(info.types[t]))
	if emit:
		_preview()


func creation() -> Dictionary:
	var race: String = race_ids[opt.race.selected]
	var types: Array = info.races[race].types
	var look := {"skin": opt.skin.selected, "hair": opt.hair.selected, "hair_color": opt.hair_color.selected, "face": 0, "beard": 0}
	return {"race": race, "gender": "f" if opt.gender.selected == 1 else "m", "type": types[clampi(opt.type.selected, 0, types.size() - 1)], "look": look,
		"skin": look.skin, "hair": look.hair, "hair_color": look.hair_color, "equipment": {"armadura": "pesada_ng" if types[clampi(opt.type.selected, 0, types.size() - 1)] == "l" else "robe_ng"}}


func _preview() -> void:
	want_preview.emit(creation())


func show_create() -> void:
	char_box.visible = false
	login_box.find_child("Form", true, false).visible = false
	create_box.visible = true
	name_edit.text = ""
	set_status("")
	_preview()


func show_login() -> void:
	login_box.visible = true
	hud.visible = false
	char_box.visible = false
	create_box.visible = false
	login_box.find_child("Form", true, false).visible = true
	pass_edit.text = ""
	set_status("")
	busy(false)


func show_hud(name_text: String) -> void:
	login_box.visible = false
	hud.visible = true
	_place_panels()
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
	last_chars = list
	last_account = account
	create_box.visible = false
	login_box.visible = true
	hud.visible = false
	login_box.find_child("Form", true, false).visible = false
	for c in char_box.get_children():
		c.queue_free()
	char_box.visible = true
	char_box.add_child(_label("Conta: %s" % account, 15, Color(0.75, 0.78, 0.82)))
	if list.is_empty():
		var l := _label("Esta conta ainda não tem personagem.", 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		char_box.add_child(l)
	else:
		char_box.add_child(_label("Escolha o personagem", 18, GOLD, true))
		for c in list:
			var d: Dictionary = c
			var race: String = info.races[d.race].name if (info.get("races", {}) as Dictionary).has(str(d.get("race", ""))) else str(d.get("race", "")).capitalize()
			var b := _button("%s   ·   Nv %s   ·   %s" % [d.get("name", "?"), str(int(d.get("level", 1))), race], true)
			b.pressed.connect(func(): want_char.emit(d))
			char_box.add_child(b)
	if list.size() < 3:
		var nb := _button("Criar personagem")
		nb.pressed.connect(func(): want_new_char.emit())
		char_box.add_child(nb)
	var out := _button("Trocar de conta")
	out.pressed.connect(func(): want_exit_to_login.emit())
	char_box.add_child(out)
	set_status("")
