extends CanvasLayer

const Character = preload("res://scripts/character.gd")
const IconButton = preload("res://scripts/icon_button.gd")
# Telas: entrada (login, criar conta, escolha de personagem) e painel do jogo.

signal want_login(user: String, password: String)
signal want_signup(user: String, password: String)
signal want_offline
var login_conta: Array = []  # campos e botões de conta (somem na versão de celular sem servidor de testes)


# versão de teste no celular sem o endereço do servidor de testes: só o modo sem conta, nunca o servidor oficial
func modo_so_offline() -> void:
	for n in login_conta:
		if is_instance_valid(n):
			(n as Control).visible = false
signal want_char(c: Dictionary)
signal want_quality
signal want_vsync
signal want_crowd
signal want_api
signal want_exit_to_login
signal want_new_char
signal want_create(o: Dictionary)
signal want_preview(o: Dictionary)
signal want_show_char(c: Dictionary)  # tela de entrada: mostra o personagem escolhido como ele está
signal want_gm(cmd: String, args: Dictionary)
signal want_back_to_chars
signal want_skill(i: int)
signal want_action(fn: String, args: Dictionary)
signal want_window(name: String)
signal want_chat(text: String)
signal want_do(id: String)
signal want_self
signal want_grupo(acao: String, id: String)
signal want_loja(acao: String, nome: String)  # abrir, fechar, ver (loja de outro jogador)  # convidar, aceitar, recusar, sair, expulsar, escolher

const GOLD := Color(0.86, 0.72, 0.42)

var font: Font
var root: Control
var login_box: Control
var painel_entrada: PanelContainer
var logo_painel: TextureRect
var logo_grande: TextureRect
var _historia: Label
var _hist_i := 0
const HISTORIA := [
	"No tronco da Árvore dos Mil Mundos fica Valtheria, o único mundo que toca todos os outros.",
	"Lúmen, a lua de prata, dá vida às florestas. Nyx, a lua de ônix, guarda os sonhos dos mortos.",
	"Há mil anos, Malachar partiu a Coroa Celeste em seis fragmentos. Desde então o Eclipse volta, cada vez mais longo.",
	"Sete povos juraram o Pacto do Véu. Hoje o Véu racha, e as sombras voltam pelas Fendas.",
	"Reúna os povos. Encontre os seis fragmentos. Renove o Pacto antes do último Eclipse.",
]
var tela_carga: Control  # tela de carregamento ao entrar no mundo
var _carga_barra: ProgressBar
var _carga_texto: Label
var _carga_dica: Label
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
var tgt_convidar: Button
var grupo_panel: PanelContainer
var grupo_lista: VBoxContainer
var grupo_titulo: Label
var grupo_sair: Button
var grupo_sig := ""
var grupo_linhas := {}  # id -> {"hp", "mp", "cp", "nome", "nv", "row"}
var convite_box: PanelContainer
var convite_txt: Label
var tgt_name: Label
var tgt_bar: ProgressBar
var hot: Array = []
var toast: Label
var toast_until := 0.0
var faixa: VBoxContainer  # chegada a uma cidade: nome grande no alto da tela, some sozinho
var faixa_tw: Tween
var win: PanelContainer
var win_title: Label
var win_list: VBoxContainer
var win_name := ""
var chat_log: RichTextLabel
var chat_linhas: Array = []  # [canal, bbcode] — guardadas para filtrar por aba
var chat_aba := "todos"
var chat_abas := {}
var hot_linhas := 3  # linhas visíveis da barra de atalhos (1 a 3)
const CANAIS := [["todos", "Todos"], ["geral", "Geral"], ["grupo", "Grupo"], ["cla", "Clã"], ["sistema", "Sistema"]]
var chat_edit: LineEdit
var assist: Array = []
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
var config_panel: Control
var tab := "equip"
var shop_cat := "armas"
var doll_char: Node3D
var tgt_cp: ProgressBar
var bar_cp: ProgressBar
var fx_panel: PanelContainer
var fx_grid: GridContainer
var fx_sig := ""
var hot_custom := {}
var skill_list: Array = []
var _detail_id := ""
var gm_btn: Button
var gm_view := {}  # estado mostrado no painel de GM (ligado/desligado, jogadores online)
# ações do personagem: [id, ícone, nome, descrição]
const ACTIONS := [["atacar", "atacar", "Atacar", "Ataca o alvo selecionado (tecla F)"], ["loja_pessoal", "loja", "Abrir loja", "Senta e mostra uma placa com sua loja (suas ofertas do mercado); andar fecha a loja"], ["sentar", "sentar", "Sentar", "Senta no chão até você andar de novo"], ["pular", "pular", "Pular", "Dá um salto (barra de espaço)"],
	["dancar", "dancar", "Dançar", "Dança até você andar de novo"], ["sorrir", "sorrir", "Sorrir", "Mostra um sorriso sobre o personagem"], ["chorar", "chorar", "Chorar", "Mostra o choro sobre o personagem"],
	["acenar", "acenar", "Acenar", "Faz um gesto de sim"], ["conversar", "conversar", "Conversar", "Gesticula como quem conversa"], ["escalar", "escalar", "Escalar", "Em breve: chega com os paredões escaláveis"]]


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
	s.set_corner_radius_all(11)
	s.set_content_margin_all(14)
	s.shadow_color = Color(GOLD, 0.45)  # filete dourado por fora da borda de bronze
	s.shadow_size = 1
	return s


const GRADES := ["NG", "D", "C", "B", "A", "S", "SS"]
const ENC_SEGURO := 3  # até o +3 não há risco (o mesmo do servidor)
const ENC_MAX := 16
var enc_slot := "arma"
var mkt_tab := "comprar"
var mkt_busca := ""
var mkt_item := ""  # item escolhido para anunciar
var tgt_loja: Button
var enc_confirmar := false  # acima do seguro, o botão pede um segundo clique
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
		sb.set_corner_radius_all(7)
		sb.set_content_margin_all(3)
		b.add_theme_stylebox_override(st, sb)
	return b


func _icon(kind: String, tip: String, size := 46.0) -> Button:
	var b: Button = IconButton.new()
	b.kind = kind
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.11, 0.14, 0.95) if st != "hover" else Color(0.2, 0.19, 0.16, 0.95)
		sb.border_color = Color(0.5, 0.39, 0.2) if st != "hover" else GOLD
		sb.set_border_width_all(1)
		sb.border_width_bottom = 3
		sb.set_corner_radius_all(10)
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
		s.set_corner_radius_all(8)
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
	s.set_corner_radius_all(8)
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
	panel.name = "PainelEntrada"
	panel.add_theme_stylebox_override("panel", _panel_style())
	# o painel cresce só até o conteúdo (sem a área vazia embaixo); a posição muda por tela em _posicionar_painel
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	painel_entrada = panel
	panel.minimum_size_changed.connect(func(): call_deferred("_ajustar_painel"))
	login_box.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	# marca do jogo: a Árvore em forma de V, com o eclipse das duas luas, os mundos-fruto e os seis fragmentos
	logo_painel = TextureRect.new()
	logo_painel.texture = load("res://assets/marca/logo.png")
	logo_painel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_painel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_painel.custom_minimum_size = Vector2(400, 132)
	v.add_child(logo_painel)
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
	login_conta = [user_edit, pass_edit, enter, create]

	char_box = VBoxContainer.new()
	char_box.add_theme_constant_override("separation", 10)
	char_box.visible = false
	v.add_child(char_box)

	create_box = VBoxContainer.new()
	create_box.add_theme_constant_override("separation", 7)
	create_box.visible = false
	v.add_child(create_box)
	_build_create()
	_posicionar_painel("login")

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
	who.mouse_filter = Control.MOUSE_FILTER_STOP
	who.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	who.tooltip_text = "Clique para selecionar você mesmo (curas e reforços em si)"
	who.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			want_self.emit())
	place_label = _label("", 14, Color(0.85, 0.88, 0.92))
	pv.add_child(place_label)
	bar_cp = _bar(pv, Color(0.82, 0.6, 0.18), "cp")
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
	tgt_cp = _bar(tv, Color(0.82, 0.6, 0.18), "tcp")
	tgt_bar = _bar(tv, Color(0.78, 0.2, 0.18), "tgt")
	tgt_convidar = _button("Convidar ao grupo")
	tgt_convidar.custom_minimum_size = Vector2(0, 28)
	tgt_convidar.add_theme_font_size_override("font_size", 13)
	tgt_convidar.focus_mode = Control.FOCUS_NONE
	tgt_convidar.visible = false
	tgt_convidar.pressed.connect(func(): want_grupo.emit("convidar", str(tgt_convidar.get_meta("id", ""))))
	tv.add_child(tgt_convidar)
	tgt_loja = _button("Ver loja", true)
	tgt_loja.custom_minimum_size = Vector2(0, 28)
	tgt_loja.add_theme_font_size_override("font_size", 13)
	tgt_loja.focus_mode = Control.FOCUS_NONE
	tgt_loja.visible = false
	tgt_loja.pressed.connect(func(): want_loja.emit("ver", str(tgt_loja.get_meta("nome", ""))))
	tv.add_child(tgt_loja)

	# grupo (party): uma linha por membro, com nome, nível e barras de CP, vida e mana
	grupo_panel = PanelContainer.new()
	var gps := _panel_style(0.62)
	gps.set_content_margin_all(8)
	grupo_panel.add_theme_stylebox_override("panel", gps)
	grupo_panel.position = Vector2(16, 222)
	grupo_panel.visible = false
	hud.add_child(grupo_panel)
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 6)
	grupo_panel.add_child(gv)
	var gh := HBoxContainer.new()
	gv.add_child(gh)
	grupo_titulo = _label("Grupo", 14, GOLD, true)
	grupo_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gh.add_child(grupo_titulo)
	grupo_sair = _button("Sair")
	grupo_sair.custom_minimum_size = Vector2(48, 22)
	grupo_sair.add_theme_font_size_override("font_size", 12)
	grupo_sair.focus_mode = Control.FOCUS_NONE
	grupo_sair.tooltip_text = "Sair do grupo"
	grupo_sair.pressed.connect(func(): want_grupo.emit("sair", ""))
	gh.add_child(grupo_sair)
	grupo_lista = VBoxContainer.new()
	grupo_lista.add_theme_constant_override("separation", 5)
	gv.add_child(grupo_lista)

	# convite recebido: aparece no meio da tela, com Aceitar e Recusar
	convite_box = PanelContainer.new()
	var cvs := _panel_style(0.92)
	cvs.set_content_margin_all(14)
	cvs.border_color = GOLD
	cvs.set_border_width_all(2)
	convite_box.add_theme_stylebox_override("panel", cvs)
	convite_box.anchor_left = 0.5
	convite_box.anchor_right = 0.5
	convite_box.anchor_top = 0.3
	convite_box.anchor_bottom = 0.3
	convite_box.offset_left = -190
	convite_box.offset_right = 190
	convite_box.visible = false
	hud.add_child(convite_box)
	var cvv := VBoxContainer.new()
	cvv.add_theme_constant_override("separation", 10)
	convite_box.add_child(cvv)
	convite_txt = _label("", 16, Color(0.95, 0.92, 0.85))
	convite_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	convite_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cvv.add_child(convite_txt)
	var cvh := HBoxContainer.new()
	cvh.alignment = BoxContainer.ALIGNMENT_CENTER
	cvh.add_theme_constant_override("separation", 12)
	cvv.add_child(cvh)
	for d in [["Aceitar", "aceitar", true], ["Recusar", "recusar", false]]:
		var b := _button(d[0], d[2])
		b.custom_minimum_size = Vector2(130, 34)
		b.focus_mode = Control.FOCUS_NONE
		var ac: String = d[1]
		b.pressed.connect(func(): want_grupo.emit(ac, ""))
		cvh.add_child(b)

	hot_panel = PanelContainer.new()
	var hps := _panel_style(0.78)
	hps.set_content_margin_all(6)
	hot_panel.add_theme_stylebox_override("panel", hps)
	hot_panel.anchor_left = 0.5
	hot_panel.anchor_right = 0.5
	hot_panel.anchor_top = 1.0
	hot_panel.anchor_bottom = 1.0
	hot_panel.offset_left = -226
	hot_panel.offset_right = 226
	hot_panel.offset_top = -196
	hot_panel.offset_bottom = -40
	hud.add_child(hot_panel)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	hot_panel.add_child(grid)
	var cfh := ConfigFile.new()
	cfh.load("user://interface.cfg")
	hot_linhas = int(cfh.get_value("atalhos", "linhas", 3))
	var saved = cfh.get_value("atalhos", "acoes", {})
	if saved is Dictionary:
		for k in saved:
			hot_custom[int(k)] = str(saved[k])
	for i in 18:
		var b := _icon("vazio", "", 44)
		b.pressed.connect(func(): press_slot(i))
		b.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed and hot_custom.has(i):
				hot_custom.erase(i)
				_save_layout()
				_refresh_hot())
		b.set_drag_forwarding(Callable(), func(_at, data): return data is Dictionary and data.has("acao"), func(_at, data):
			hot_custom[i] = str(data.acao)
			_save_layout()
			_refresh_hot())
		grid.add_child(b)
		hot.append(b)
	for i in 9:
		var b := _icon("vazio", "", 44)
		b.rim = Color(0.3, 0.5, 0.4)
		b.pressed.connect(func(): use_assist(i))
		grid.add_child(b)
		assist.append(b)
	# botão pequeno para mostrar 1, 2 ou 3 linhas da barra
	var hv := hot_panel.get_child(0)
	hot_panel.remove_child(hv)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 4)
	hot_panel.add_child(hh)
	hh.add_child(hv)
	var lin := _button("≡")
	lin.custom_minimum_size = Vector2(22, 0)
	lin.add_theme_font_size_override("font_size", 14)
	lin.tooltip_text = "Linhas da barra: 1, 2 ou 3\n1ª linha: teclas 1 a 9   ·   2ª: Shift + 1 a 9   ·   3ª: itens F1 a F9"
	lin.pressed.connect(func():
		hot_linhas = hot_linhas % 3 + 1
		_aplicar_linhas()
		_save_layout())
	hh.add_child(lin)
	_aplicar_linhas()

	# barra de efeitos: reforços, penalidades e recargas em quadros pequenos, até 9 por linha
	fx_panel = PanelContainer.new()
	var fps := _panel_style(0.7)
	fps.set_content_margin_all(4)
	fx_panel.add_theme_stylebox_override("panel", fps)
	fx_panel.position = Vector2(310, 16)
	fx_panel.visible = false
	hud.add_child(fx_panel)
	fx_grid = GridContainer.new()
	fx_grid.columns = 9
	fx_grid.add_theme_constant_override("h_separation", 2)
	fx_grid.add_theme_constant_override("v_separation", 2)
	fx_panel.add_child(fx_grid)
	_movable(fx_panel, "efeitos")

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
	var wx := _button("✕")
	wx.tooltip_text = "Fechar (Esc)"
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

	# doca única: todas as opções em ícones, com o nome ao passar o mouse
	var dock := PanelContainer.new()
	var dps := _panel_style(0.8)
	dps.set_content_margin_all(6)
	dock.add_theme_stylebox_override("panel", dps)
	dock.anchor_left = 1.0
	dock.anchor_right = 1.0
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_left = -196
	dock.offset_right = -12
	dock.offset_top = -176
	dock.offset_bottom = -40
	hud.add_child(dock)
	var dh := GridContainer.new()
	dh.columns = 4
	dh.add_theme_constant_override("h_separation", 4)
	dh.add_theme_constant_override("v_separation", 4)
	dock.add_child(dh)
	for def in [["bolsa", "Personagem e bolsa (I)", "bolsa"], ["loja", "Loja (B)", "loja"], ["barra", "Mercado e loja pessoal (H)", "mercado"], ["oficio", "Ofício (C)", "oficio"], ["encantar", "Encantamento (N)", "encantar"], ["classe", "Classe (K)", "classe"], ["cla", "Clã (G)", "cla"], ["acoes", "Ações do personagem (J)", "acoes"], ["config", "Configurações e desempenho", "#config"], ["tela", "Tela cheia (F11)", "#tela"], ["sair", "Voltar à entrada (Esc)", "#sair"]]:
		var ib := _icon(def[0], def[1], 40)
		var act: String = def[2]
		ib.pressed.connect(func():
			if act == "#config":
				config_panel.visible = not config_panel.visible
			elif act == "#tela":
				toggle_fullscreen()
			elif act == "#sair":
				want_exit_to_login.emit()
			else:
				want_window.emit(act))
		dh.add_child(ib)
	gm_btn = _icon("coroa", "Painel de GM (F10)", 40)
	gm_btn.visible = false
	gm_btn.pressed.connect(func(): want_window.emit("gm"))
	dh.add_child(gm_btn)
	_movable(dock, "doca")

	# bate-papo: fundo translúcido, abas por canal (Todos, Geral, Grupo, Clã, Sistema)
	var cpn := PanelContainer.new()
	var cst := _panel_style(0.32)
	cst.set_content_margin_all(6)
	cst.shadow_size = 0
	cpn.add_theme_stylebox_override("panel", cst)
	chat_panel = cpn
	cpn.anchor_top = 1.0
	cpn.anchor_bottom = 1.0
	cpn.offset_left = 16
	cpn.offset_right = 436
	cpn.offset_top = -280
	cpn.offset_bottom = -44
	hud.add_child(cpn)
	var cb := VBoxContainer.new()
	cb.add_theme_constant_override("separation", 4)
	cpn.add_child(cb)
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 2)
	cb.add_child(abas)
	for c in CANAIS:
		var ab := Button.new()
		ab.text = c[1]
		ab.toggle_mode = true
		ab.focus_mode = Control.FOCUS_NONE
		ab.add_theme_font_size_override("font_size", 12)
		ab.custom_minimum_size = Vector2(0, 24)
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.85, 0.66, 0.3, 0.55) if st.contains("pressed") else Color(0.05, 0.06, 0.09, 0.45 if st == "normal" else 0.7)
			sb.set_corner_radius_all(4)
			sb.content_margin_left = 4
			sb.content_margin_right = 4
			ab.add_theme_stylebox_override(st, sb)
		ab.add_theme_color_override("font_pressed_color", Color(0.08, 0.06, 0.03))
		ab.add_theme_color_override("font_hover_pressed_color", Color(0.08, 0.06, 0.03))
		var canal: String = c[0]
		ab.pressed.connect(func(): chat_filtrar(canal))
		abas.add_child(ab)
		chat_abas[canal] = ab
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_log.add_theme_font_size_override("normal_font_size", 14)
	chat_log.add_theme_font_size_override("italics_font_size", 14)
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
	_movable(cpn, "chat")
	chat_filtrar("todos")

	toast = _label("", 22, Color(1, 0.93, 0.7), true)
	toast.anchor_left = 0.0
	toast.anchor_right = 1.0
	toast.offset_top = 96
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast.add_theme_constant_override("outline_size", 8)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(toast)
	faixa = VBoxContainer.new()
	faixa.anchor_left = 0.0
	faixa.anchor_right = 1.0
	faixa.offset_top = 140
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.modulate.a = 0.0
	for k in 2:
		var lb := _label("", 46 if k == 0 else 20, Color(1.0, 0.9, 0.62) if k == 0 else Color(0.92, 0.94, 0.98), true)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		lb.add_theme_constant_override("outline_size", 10 if k == 0 else 6)
		if k == 0 and ResourceLoader.exists("res://assets/cinzel.ttf"):
			lb.add_theme_font_override("font", load("res://assets/cinzel.ttf"))
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		faixa.add_child(lb)
	hud.add_child(faixa)
	_movable(win, "janela")
	_movable(hot_panel, "barra")
	_movable(plate, "status")
	_movable(tgt_box, "alvo")
	_movable(grupo_panel, "grupo")

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
	config_panel = right
	right.visible = false
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

	var help := _label("W A S D ou clique: andar   ·   clique no monstro: alvo (2º clique ou F: atacar)   ·   Tab: próximo alvo   ·   1 a 9 e Shift+1 a 9: habilidades   ·   F1 a F9: itens   ·   arraste os painéis para mover", 14, Color(0.9, 0.9, 0.92))
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


# t: {} esconde; {"name", "hp", "max", "cp", "maxcp", "pct"}; sem "hp" mostra só o nome (NPC); "cp" só para jogadores
func set_target(t: Dictionary) -> void:
	tgt_box.visible = not t.is_empty()
	if t.is_empty():
		return
	tgt_name.text = str(t.name)
	tgt_convidar.visible = t.has("convidar")
	tgt_loja.visible = t.has("loja")
	if t.has("loja"):
		tgt_loja.set_meta("nome", str(t.loja))
		tgt_loja.text = "Ver loja: " + str(t.get("placa", "")).left(22)
	if t.has("convidar"):
		tgt_convidar.set_meta("id", str(t.convidar))
	tgt_bar.visible = t.has("hp")
	tgt_cp.visible = t.has("cp")
	var pct: bool = t.get("pct", false)
	if t.has("hp"):
		tgt_bar.max_value = float(t.max)
		tgt_bar.value = maxf(0.0, float(t.hp))
		bar_txt.tgt.text = ("Vida %d%%" % int(t.hp)) if pct else "Vida %d / %d" % [int(maxf(0.0, float(t.hp))), int(t.max)]
	if t.has("cp"):
		tgt_cp.max_value = float(t.maxcp)
		tgt_cp.value = float(t.cp)
		bar_txt.tcp.text = ("CP %d%%" % int(t.cp)) if pct else "CP %d / %d" % [int(t.cp), int(t.maxcp)]


# lista: [{"id", "name", "lvl", "cls", "hp", "mp", "cp" (em %), "eu", "lider", "longe"}]
func set_grupo(lista: Array, lider: bool) -> void:
	grupo_panel.visible = lista.size() > 1
	if lista.size() <= 1:
		grupo_sig = ""
		return
	grupo_titulo.text = "Grupo  %d/9" % lista.size()
	var sig := str(lider)
	for m in lista:
		sig += "|%s%s%s" % [m.id, m.name, m.lider]
	if sig != grupo_sig:
		grupo_sig = sig
		grupo_linhas.clear()
		for c in grupo_lista.get_children():
			c.queue_free()
		for m in lista:
			grupo_linhas[m.id] = _linha_grupo(m, lider)
	for m in lista:
		var l: Dictionary = grupo_linhas.get(m.id, {})
		if l.is_empty():
			continue
		l.cp.value = float(m.cp)
		l.hp.value = float(m.hp)
		l.mp.value = float(m.mp)
		l.nv.text = "Nv %d" % int(m.lvl)
		l.row.modulate = Color(1, 1, 1, 0.45) if m.longe else Color(1, 1, 1, 1)
		l.row.tooltip_text = "%s%s%s" % [m.name, ("  ·  " + str(m.cls)) if str(m.cls) != "" else "", "\nFora de alcance" if m.longe else ""]


func _barrinha(parent: Control, col: Color, alto: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(190, alto)
	b.show_percentage = false
	b.max_value = 100.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(2)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	parent.add_child(b)
	return b


func _linha_grupo(m: Dictionary, lider: bool) -> Dictionary:
	var row := PanelContainer.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(1, 1, 1, 0.06) if m.eu else Color(0, 0, 0, 0)
	rs.set_corner_radius_all(4)
	rs.set_content_margin_all(3)
	row.add_theme_stylebox_override("panel", rs)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var id: String = m.id
	row.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			want_grupo.emit("escolher", id))
	grupo_lista.add_child(row)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var nome := _label(("★ " if m.lider else "") + str(m.name), 13, Color(1.0, 0.86, 0.5) if m.lider else Color(0.9, 0.93, 0.97))
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nome.clip_text = true
	h.add_child(nome)
	var nv := _label("", 12, Color(0.75, 0.78, 0.84))
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(nv)
	if lider and not m.eu:
		var x := Button.new()
		x.text = "✕"
		x.flat = true
		x.focus_mode = Control.FOCUS_NONE
		x.add_theme_font_size_override("font_size", 11)
		x.add_theme_color_override("font_color", Color(0.85, 0.5, 0.45))
		x.tooltip_text = "Tirar do grupo"
		x.pressed.connect(func(): want_grupo.emit("expulsar", id))
		h.add_child(x)
	var cp := _barrinha(v, Color(0.82, 0.6, 0.18), 4)
	var hp := _barrinha(v, Color(0.78, 0.2, 0.18), 8)
	var mp := _barrinha(v, Color(0.2, 0.42, 0.85), 5)
	return {"row": row, "nv": nv, "cp": cp, "hp": hp, "mp": mp}


func mostrar_convite(nome: String) -> void:
	convite_box.visible = nome != ""
	if nome != "":
		convite_txt.text = "%s convidou você para um grupo.\n[ caça e exploração juntos ]" % nome


func set_cp(cp: float, max_cp: float) -> void:
	bar_cp.max_value = maxf(max_cp, 1.0)
	bar_cp.value = cp
	bar_txt.cp.text = "CP %d / %d" % [int(cp), int(max_cp)]


func _action_def(id: String) -> Array:
	for a in ACTIONS:
		if a[0] == id:
			return a
	return []


func press_slot(i: int) -> void:
	if hot_custom.has(i):
		want_do.emit(str(hot_custom[i]))
	else:
		want_skill.emit(i)


func set_skills(list: Array) -> void:
	skill_list = list
	_refresh_hot()


func _tecla(i: int) -> String:
	return str(i + 1) if i < 9 else "⇧%d" % (i - 8)


func _refresh_hot() -> void:
	for i in hot.size():
		var b = hot[i]
		b.dim = 0.0
		b.disabled = false
		var a := _action_def(str(hot_custom.get(i, "")))
		if not a.is_empty():
			b.kind = a[1]
			b.textura = null
			b.tint = Color(0.8, 0.9, 1.0)
			b.label = _tecla(i)
			b.tooltip_text = "%s  (tecla %s)\n%s\nBotão direito tira daqui" % [a[2], _tecla(i), a[3]]
		elif i < skill_list.size():
			var s: Dictionary = skill_list[i]
			var look: Array = IconButton.skill_look(s)
			b.kind = look[0]
			b.tint = look[1]
			b.label = _tecla(i)
			b.textura = null
			var img := "res://assets/icones/habilidades/%s.png" % str(s.get("icone", ""))
			if s.has("icone") and ResourceLoader.exists(img):
				b.textura = load(img)
			var conj := float(s.get("conj", 0.0))
			b.tooltip_text = "%s  (tecla %s)\nMana %d   ·   recarga %ds%s" % [s.name, _tecla(i), int(s.mp), int(s.cd), ("   ·   conjuração %.1fs" % conj) if conj > 0.05 else ""]
		else:
			b.kind = "vazio"
			b.textura = null
			b.label = _tecla(i)
			b.tooltip_text = "Vazio: novas habilidades chegam com o nível e a classe.\nArraste uma ação da janela de Ações para cá."


func set_cooldowns(cds: Array, now: float) -> void:
	for i in hot.size():
		if i < cds.size() and i < skill_list.size() and not hot_custom.has(i):
			var left: float = float(cds[i]) - now
			var b = hot[i]
			b.dim = clampf(left / maxf(float(skill_list[i].cd), 0.1), 0.0, 1.0) if left > 0.0 else 0.0
			b.label = ("%s\n%d" % [_tecla(i), int(ceilf(left))]) if left > 0.0 else _tecla(i)


# list: [{"kind", "col", "tip", "left"}] — reforços, penalidades e recargas ativos
func set_effects(list: Array) -> void:
	var sig := ""
	for e in list:
		sig += str(e.kind) + str(e.tip) + "|"
	fx_panel.visible = not list.is_empty()
	if sig != fx_sig:
		fx_sig = sig
		for c in fx_grid.get_children():
			c.queue_free()
		for e in list:
			var b := _icon(str(e.kind), "", 24)
			b.tint = e.col
			b.mouse_filter = Control.MOUSE_FILTER_PASS
			b.set_meta("tip", str(e.tip))
			fx_grid.add_child(b)
		fx_panel.reset_size()
	var i := 0
	for c in fx_grid.get_children():
		if c.is_queued_for_deletion():
			continue
		if i < list.size():
			c.tooltip_text = "%s\nrestam %d s" % [str(c.get_meta("tip")), int(ceilf(float(list[i].left)))]
		i += 1


# barra de assistência: poções e pergaminhos da bolsa, um por espaço (F1 a F9)
func set_assist(inv: Dictionary) -> void:
	assist_ids = []
	for id in inv:
		if str(info.items.get(str(id), {}).get("type", "")) in ["potion", "scroll", "special"] and assist_ids.size() < 9:
			assist_ids.append(str(id))
	for i in assist.size():
		var b = assist[i]
		if i < assist_ids.size():
			var it: Dictionary = info.items[assist_ids[i]]
			var look: Array = IconButton.item_look(assist_ids[i], it)
			b.kind = look[0]
			b.tint = look[1]
			b.label = "F%d\nx%d" % [i + 1, int(inv[assist_ids[i]])]
			b.tooltip_text = "%s  (tecla F%d)" % [it.name, i + 1]
			b.disabled = false
		else:
			b.kind = "vazio"
			b.label = "F%d" % (i + 1)
			b.tooltip_text = "Vazio: poções e pergaminhos da bolsa aparecem aqui"
			b.disabled = true


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
	cf.set_value("atalhos", "acoes", hot_custom)
	cf.set_value("atalhos", "linhas", hot_linhas)
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
	var nome := who_name.replace("[", "[lb]")
	var canal := "geral"
	var linha := ""
	match kind:
		"chat":
			linha = "[color=#ffd98a]%s:[/color] %s" % [nome, safe]
		"npc":
			linha = "[color=#b8f0b0]%s:[/color] [i]%s[/i]" % [nome, safe]
		"grupo":
			canal = "grupo"
			linha = "[color=#7fd8ff]#%s:[/color] [color=#c8eeff]%s[/color]" % [nome, safe]
		"cla":
			canal = "cla"
			linha = "[color=#c9a0ff]@%s:[/color] [color=#e6d6ff]%s[/color]" % [nome, safe]
		_:
			canal = "sistema"
			linha = "[color=#9fd0ff]%s[/color]" % safe
	chat_linhas.append([canal, linha])
	if chat_linhas.size() > 200:
		chat_linhas.pop_front()
	if chat_aba == "todos" or chat_aba == canal:
		chat_log.append_text(linha + "\n")


func chat_filtrar(canal: String) -> void:
	chat_aba = canal
	for k in chat_abas:
		chat_abas[k].set_pressed_no_signal(k == canal)
	chat_log.clear()
	for l in chat_linhas:
		if canal == "todos" or l[0] == canal:
			chat_log.append_text(str(l[1]) + "\n")
	if chat_edit != null:
		chat_edit.placeholder_text = {"grupo": "Enter para falar com o grupo", "cla": "Canal do clã em breve: use Geral por enquanto"}.get(canal, "Enter para conversar   ·   # no início fala no grupo")


func _aplicar_linhas() -> void:
	for i in hot.size():
		hot[i].visible = i < 9 or hot_linhas >= 2
	for b in assist:
		b.visible = hot_linhas >= 3
	hot_panel.reset_size()


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
	sb.set_corner_radius_all(8)
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
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var item_id := str(args.get("p_item", args.get("_icon", "")))
	if item_id != "":
		var ic := _item_icon(item_id, 64)
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		head.add_child(ic)
	head.add_child(t)
	v.add_child(head)
	v.add_child(_label("Grau %s" % GRADES[g], 12, Color(0.7, 0.72, 0.78)))
	if item_id != "":
		var ap := aparencia(item_id, info.items.get(item_id, {}))
		if ap != "":
			var al := _label(ap, 12, Color(0.78, 0.74, 0.62))
			al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(al)
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
	var send := args.duplicate()
	send.erase("_icon")
	b.pressed.connect(func(): want_action.emit(fn, send))
	v.add_child(b)
	return pc


# mercado entre jogadores: o servidor guarda as ofertas, cobra a taxa e faz a troca (game_market_*).
# A loja pessoal é o mesmo mercado mostrado só com as ofertas de um vendedor.
func _janela_mercado(me: Dictionary, inv: Dictionary, extra: Dictionary) -> void:
	var aurum := int(me.get("aurum", 0))
	var lista: Array = extra.get("lista") if extra.get("lista") is Array else []
	var vendedor := str(extra.get("vendedor", ""))
	var minha_loja := str(extra.get("minha_loja", ""))
	if vendedor != "":
		win_title.text = "◆ Loja de %s   ·   %d aurum" % [vendedor, aurum]
		if str(extra.get("placa", "")) != "":
			_note("\"%s\"" % str(extra.placa))
	else:
		win_title.text = "◆ Mercado   ·   %d aurum" % aurum
		_tabs([["comprar", "Comprar"], ["anunciar", "Anunciar"], ["minhas", "Minhas ofertas"]], mkt_tab, func(k):
			mkt_tab = k
			mkt_item = ""
			open_window("mercado", w_me, w_inv, w_extra))
	if str(extra.get("erro", "")) != "":
		_note(str(extra.erro))
		return
	if vendedor == "" and mkt_tab == "anunciar":
		_mercado_anunciar(inv)
		return
	if vendedor == "" and mkt_tab == "minhas":
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		win_list.add_child(hb)
		var aberta := minha_loja != ""
		var lb := _label("Sua loja está aberta: \"%s\"" % minha_loja if aberta else "Abra sua loja para os outros jogadores verem suas ofertas com uma placa sobre você.", 13, GOLD if aberta else Color(0.8, 0.82, 0.88))
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(lb)
		var bl := _button("Fechar loja" if aberta else "Abrir minha loja", not aberta)
		bl.custom_minimum_size = Vector2(170, 34)
		bl.focus_mode = Control.FOCUS_NONE
		bl.pressed.connect(func(): want_loja.emit("fechar" if aberta else "abrir", ""))
		hb.add_child(bl)
	elif vendedor == "":
		var busca := _edit("Procurar item...")
		busca.text = mkt_busca
		busca.custom_minimum_size = Vector2(0, 32)
		busca.text_submitted.connect(func(t):
			mkt_busca = t.strip_edges()
			open_window("mercado", w_me, w_inv, w_extra))
		win_list.add_child(busca)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	win_list.add_child(flow)
	var n := 0
	for o in lista:
		if not (o is Dictionary):
			continue
		var mine := bool(o.get("mine", false))
		var iid := str(o.get("item", ""))
		var it: Dictionary = info.items.get(iid, {})
		var nome := str(it.get("name", iid))
		if vendedor != "":
			if str(o.get("seller", "")) != vendedor:
				continue
		elif mkt_tab == "minhas" and not mine:
			continue
		elif mkt_tab == "comprar" and (mine or (mkt_busca != "" and not nome.to_lower().contains(mkt_busca.to_lower()))):
			continue
		var preco := int(o.get("price", 0))
		var linhas := ["%d aurum cada  ·  %d unid." % [preco, int(o.get("qty", 1))]]
		if vendedor == "" and not mine:
			linhas.append("Vendedor: %s" % str(o.get("seller", "?")))
		linhas.append_array(_stat_lines(it))
		if mine:
			flow.add_child(_item_card(nome + " x%d" % int(o.get("qty", 1)), grade_of(iid), linhas, "", "Cancelar oferta", "game_market_cancel", {"p_order": o.get("id"), "_icon": iid}, true))
		else:
			flow.add_child(_item_card(nome, grade_of(iid), linhas, "%d aurum" % preco, "Comprar 1", "game_market_buy", {"p_order": o.get("id"), "p_qty": 1, "_icon": iid}, aurum >= preco))
		n += 1
		if n >= 60:
			break
	if n == 0:
		_note("Nenhuma oferta%s." % (" nesta loja agora" if vendedor != "" else (" sua" if mkt_tab == "minhas" else "")))


func _mercado_anunciar(inv: Dictionary) -> void:
	_note("Escolha um item da bolsa, a quantidade e o preço de cada um. O mercado cobra 4% da venda.")
	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 16)
	win_list.add_child(corpo)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	corpo.add_child(grid)
	for iid in inv:
		if not info.items.has(str(iid)) or int(inv[iid]) <= 0:
			continue
		var ic := _item_icon(str(iid), 52, str(iid) == mkt_item)
		ic.label = "x%d" % int(inv[iid])
		ic.tooltip_text = str(info.items[iid].get("name", iid))
		var id := str(iid)
		ic.pressed.connect(func():
			mkt_item = id
			open_window("mercado", w_me, w_inv, w_extra))
		grid.add_child(ic)
	var dir := VBoxContainer.new()
	dir.add_theme_constant_override("separation", 8)
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo.add_child(dir)
	if mkt_item == "" or not inv.has(mkt_item):
		dir.add_child(_label("← escolha um item", 14, Color(0.7, 0.72, 0.78)))
		return
	var it: Dictionary = info.items.get(mkt_item, {})
	dir.add_child(_label(str(it.get("name", mkt_item)), 17, GRADE_COL[grade_of(mkt_item)], true))
	var tem := int(inv[mkt_item])
	var ref := maxi(1, int(it.get("sell", 10)))
	var qh := HBoxContainer.new()
	dir.add_child(qh)
	qh.add_child(_label("Quantidade", 14))
	var q := SpinBox.new()
	q.min_value = 1
	q.max_value = tem
	q.value = 1
	q.custom_minimum_size = Vector2(120, 0)
	qh.add_child(q)
	var ph := HBoxContainer.new()
	dir.add_child(ph)
	ph.add_child(_label("Preço de cada", 14))
	var pr := SpinBox.new()
	pr.min_value = 1
	pr.max_value = 999999999
	pr.value = ref * 2
	pr.suffix = "aurum"
	pr.custom_minimum_size = Vector2(170, 0)
	ph.add_child(pr)
	var res := _label("", 13, Color(0.75, 0.9, 0.75))
	res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	res.custom_minimum_size = Vector2(280, 0)
	dir.add_child(res)
	var calc := func(_v = 0.0):
		var total := int(q.value) * int(pr.value)
		res.text = "Você recebe %d aurum (total %d − taxa %d)\nO mercador da cidade paga %d cada" % [total - int(floor(total * 0.04)), total, int(floor(total * 0.04)), ref]
	q.value_changed.connect(calc)
	pr.value_changed.connect(calc)
	calc.call()
	var b := _button("Anunciar", true)
	b.custom_minimum_size = Vector2(0, 38)
	b.focus_mode = Control.FOCUS_NONE
	var item := mkt_item
	b.pressed.connect(func():
		mkt_item = ""
		want_action.emit("game_market_sell", {"p_item": item, "p_qty": int(q.value), "p_price": int(pr.value)}))
	dir.add_child(b)


# ---------- habilidades por classe (data/classes_v2.json, gerado por ferramentas/gerar_classes_v2.py) ----------
static var _cv2: Dictionary = {}
var ctx_passivas := {}  # grupo, montaria, pet, buffs ativos (main atualiza)
var hab_tab := "ativas"
const CAT_NOME := {"magia": "Magias", "golpe": "Golpes", "reforco": "Reforço", "enfraquecer": "Enfraquecimento", "alternar": "Alternância",
	"equipamento": "Equipamento", "habilidade": "Habilidade", "raca": "Raça", "oficio": "Ofício"}
const CAT_ICONE := {"golpe": "golpe", "reforco": "forca", "enfraquecer": "fraqueza", "alternar": "recarga", "equipamento": "escudo", "habilidade": "estrela", "raca": "coroa", "oficio": "kit"}
const TIPO_ICONE := {"ataque": "espadao", "area": "machado", "critico": "garras", "atordoar": "escudo", "avanco": "pressa", "puxar": "lanca",
	"provocar": "golpe", "aura": "coroa", "invocar": "pata", "cura": "cura", "cura_area": "cura", "reviver": "estrela", "purificar": "luz", "dreno": "sombra", "prender": "gelo", "debuff": "fraqueza"}
const ELEM_ICONE := {"fogo": "fogo", "gelo": "gelo", "raio": "raio", "agua": "agua", "terra": "terra", "vento": "vento", "luz": "luz", "sombra": "sombra"}

static func classes_v2() -> Dictionary:
	if _cv2.is_empty() and FileAccess.file_exists("res://data/classes_v2.json"):
		_cv2 = JSON.parse_string(FileAccess.get_file_as_string("res://data/classes_v2.json"))
	return _cv2


# caminho da classe atual até a base (as habilidades se acumulam ao subir de classe)
static func cadeia_classe(cid: String) -> Array:
	var cv := classes_v2()
	var out: Array = []
	while cid != "" and cv.classes.has(cid):
		out.push_front(cid)
		cid = str(cv.classes[cid].pai)
	return out


# nível de cada habilidade: o que o servidor mandar em me.habilidades; sem isso, o máximo que o nível do personagem permite
static func nivel_hab(h: Dictionary, me: Dictionary, lvl: int) -> int:
	var salvo: Dictionary = me.get("skills") if me.get("skills") is Dictionary else (me.get("habilidades") if me.get("habilidades") is Dictionary else {})
	if me.get("skills") is Dictionary:  # servidor de testes: só vale o que foi aprendido com PH
		return int(salvo.get(h.id, 0))
	if salvo.has(h.id):
		return int(salvo[h.id])
	var n := 0
	for t in h.tabela:
		if int(t.nivel_personagem) <= lvl:
			n = int(t.nivel)
	return n


func _janela_habilidades(me: Dictionary) -> void:
	var cv := classes_v2()
	if cv.is_empty():
		_note("Banco de habilidades não encontrado.")
		return
	var lvl := int(me.get("level", 1))
	var cid := str(me.get("class_id", ""))
	if not cv.classes.has(cid):
		for k in cv.classes:  # sem classe conhecida: começa pela base da raça
			if cv.classes[k].rank == 0 and cv.classes[k].raca == str(me.get("race", "humano")):
				cid = k
				break
	var cadeia := cadeia_classe(cid)
	var cl: Dictionary = cv.classes.get(cid, {})
	win_title.text = "◆ Habilidades   ·   %s   ·   nível %d" % [str(cl.get("nome", "-")), lvl]
	_tabs([["ativas", "Ativas"], ["passivas", "Passivas"], ["aprender", "Aprender"], ["status", "Status"], ["arvore", "Árvore de classes"]], hab_tab, func(k):
		hab_tab = k
		open_window("habilidades", w_me, w_inv, w_extra))
	if me.get("skills") is Dictionary:
		_note("Pontos de habilidade (PH): %d   ·   aurum: %d   ·   aprenda e suba habilidades na aba Aprender." % [int(me.get("ph", 0)), int(me.get("aurum", 0))])
	elif not me.get("habilidades") is Dictionary:
		_note("Prévia: os níveis mostram o máximo que o seu nível permite. Aprender e subir habilidades com pontos de habilidade (PH) chega com o servidor de testes.")
	var todas: Array = []
	for c in cadeia:
		for sid in cv.habilidades_da_classe.get(c, []):
			todas.append(cv.habilidades[sid])
	if hab_tab == "arvore":
		_arvore_classes(cv, cid, lvl)
		return
	if hab_tab == "status":
		_status_classe(cv, cid, lvl)
		return
	if hab_tab == "aprender":
		var n := 0
		for h in todas:
			var atual := nivel_hab(h, me, lvl)
			if atual >= int(h.nivel_max):
				continue
			var prox: Dictionary = h.tabela[atual]
			var pode := int(prox.nivel_personagem) <= lvl
			var servidor: bool = me.get("skills") is Dictionary
			var acao: Array = [["Aprender" if atual == 0 else "Subir", "game_skill_learn", {"p_skill": str(h.id)}]] if (servidor and pode and int(me.get("ph", 0)) >= int(prox.ph) and int(me.get("aurum", 0)) >= int(prox.aurum)) else []
			_row("%s   ·   nível %d → %d   ·   requer nível %d   ·   %d PH   ·   %d aurum" % [h.nome, atual, atual + 1, int(prox.nivel_personagem), int(prox.ph), int(prox.aurum)],
				acao, Color(0.88, 0.9, 0.94) if pode else Color(0.55, 0.56, 0.6))
			n += 1
			if n >= 40:
				break
		if n == 0:
			_note("Todas as habilidades estão no máximo para esta classe.")
		return
	var ativas := hab_tab == "ativas"
	var cats: Array = cv.categorias.ativas if ativas else cv.categorias.passivas
	if not ativas:  # passivas que vêm da arma, da roupa, do conjunto, do encanto, de acessórios, buffs e grupo (iguais para todos)
		var eqp := Passivas.ativas(me, info.items, ctx_passivas)
		win_list.add_child(_label("▬ Equipamento e efeitos", 15, GOLD, true))
		if eqp.is_empty():
			_note("Nenhuma passiva de equipamento agora. Elas aparecem ao vestir arma, escudo, conjunto completo, arma encantada +7, asas, acessórios, ao usar poção ou pergaminho e ao andar em grupo.")
		else:
			var ge := GridContainer.new()
			ge.columns = 9
			ge.add_theme_constant_override("h_separation", 6)
			ge.add_theme_constant_override("v_separation", 6)
			win_list.add_child(ge)
			for e in eqp:
				var b := _icon("escudo", "", 46)
				var img := "res://assets/icones/habilidades/%s.png" % str(e.p.icone)
				if ResourceLoader.exists(img):
					b.textura = load(img)
				b.rim = Color(0.45, 0.75, 0.95)
				b.rim_w = 2
				b.label = GRADES[clampi(int(e.grau), 0, 5)] if int(e.grau) > 0 else ""
				b.tooltip_text = "%s\nPassiva de equipamento · igual para todos\n%s\n%s" % [e.p.nome, str(e.p.descricao), Passivas.texto_bonus(e.p, int(e.grau))]
				ge.add_child(b)
	for cat in cats:
		var lista: Array = []
		for h in todas:
			if str(h.categoria) == cat:
				lista.append(h)
		if lista.is_empty():
			continue
		win_list.add_child(_label("▬ " + str(CAT_NOME.get(cat, cat)), 15, GOLD, true))
		var grade := GridContainer.new()
		grade.columns = 9
		grade.add_theme_constant_override("h_separation", 6)
		grade.add_theme_constant_override("v_separation", 6)
		win_list.add_child(grade)
		for h in lista:
			var nv := nivel_hab(h, me, lvl)
			var tp := str(h.tipo)
			var kind: String = ELEM_ICONE.get(str(h.elemento), "estrela") if (tp == "elemental" or (cat == "magia" and tp in ["ataque", "area"])) else str(TIPO_ICONE.get(tp, CAT_ICONE.get(cat, "estrela")))
			var b := _icon(kind, "", 46)
			b.tint = IconButton.ELEM.get(str(h.elemento), GOLD) if cat in ["magia", "golpe"] else (GOLD if int(h.rank) < 3 else Color(1.0, 0.85, 0.45))
			b.label = ("%d" % nv) if nv > 0 else ""
			b.disabled = nv == 0
			var img := "res://assets/icones/habilidades/%s.png" % str(h.get("icone", ""))
			if ResourceLoader.exists(img):
				b.textura = load(img)
			b.rim = Color(1.0, 0.8, 0.35) if int(h.rank) == 3 else Color(0.55, 0.42, 0.2)
			b.rim_w = 2 if int(h.rank) == 3 else 1
			b.tooltip_text = _dica_hab(h, nv, lvl, cv)
			grade.add_child(b)


func _dica_hab(h: Dictionary, nv: int, lvl: int, cv: Dictionary) -> String:
	var t: Dictionary = h.tabela[maxi(nv - 1, 0)]
	var linhas := ["%s   (nível %d de %d)" % [h.nome, nv, int(h.nivel_max)], "%s · %s · elemento %s" % ["Ativa" if h.ativa else "Passiva", CAT_NOME.get(str(h.categoria), ""), cv.elementos.get(str(h.elemento), "")]]
	if h.ativa:
		linhas.append("Poder %d%%   ·   mana %d   ·   recarga %ds" % [int(float(t.poder) * 100.0), int(t.mana), int(h.recarga)])
	else:
		linhas.append("Bônus %+.1f%%" % (float(t.poder) * 100.0))
	if nv < int(h.nivel_max):
		var p: Dictionary = h.tabela[nv]
		linhas.append("Próximo nível no nível %d   (%d PH, %d aurum)" % [int(p.nivel_personagem), int(p.ph), int(p.aurum)])
	if h.has("conjuracao") and float(h.conjuracao.base) > 0.0:
		var vel := 333.0
		var st: Dictionary = cv.classes.get(str(w_me.get("class_id", "")), {}).get("status", {})
		vel = float(st.get(str(h.conjuracao.por), 333.0))
		linhas.append("Conjuração %.1fs   (base %.1fs pela %s)" % [float(h.conjuracao.base) * 333.0 / maxf(vel, 1.0), float(h.conjuracao.base), "vel. de ataque" if h.conjuracao.por == "vel_ataque" else "vel. de conjuração"])
	if h.has("mana_por_segundo"):
		linhas.append("Mantida ligada: %.2f de mana por segundo" % float(h.mana_por_segundo))
	if h.has("movimento"):
		linhas.append("Movimento: %s (muda com a raça e o sexo)" % {"empurrar": "mãos à frente", "apontar": "braço estendido", "erguer": "mãos ao céu", "abrir": "peito aberto", "prece": "mãos unidas", "cravar": "golpe no chão", "girar": "giro com a arma", "investir": "avanço", "rugir": "grito de guerra", "golpe": "golpe forte"}.get(str(h.movimento.gesto), str(h.movimento.gesto)))
	if h.has("reacao"):
		linhas.append("Em você: %s" % str(h.reacao.conjurador))
		linhas.append("No alvo: %s" % str(h.reacao.alvo))
	if h.get("livro", false):
		linhas.append("Exige um Tomo de Técnica para aprender")
	if h.has("aprimoramento"):
		linhas.append("No máximo: aprimoramento +1 a +15 (poder, custo ou efeito)")
	if nv == 0:
		linhas.append("Ainda não disponível")
	return "\n".join(linhas)


func _status_classe(cv: Dictionary, cid: String, lvl: int) -> void:
	var c: Dictionary = cv.classes.get(cid, {})
	var st: Dictionary = c.get("status", {})
	_note("Status base da classe %s (%s, elemento %s). Guerreiros crescem em força e defesa; magos em magia, conjuração e mana. O elemento da classe soma bônus próprios." % [c.get("nome", ""), str(c.get("arquetipo", "")).capitalize(), cv.elementos.get(str(c.get("elemento", "")), "")])
	var grade := GridContainer.new()
	grade.columns = 4
	grade.add_theme_constant_override("h_separation", 28)
	grade.add_theme_constant_override("v_separation", 6)
	win_list.add_child(grade)
	var nomes := {"FOR": "Força", "DES": "Destreza", "CON": "Constituição", "INT": "Inteligência", "SAB": "Sabedoria", "ESP": "Espírito",
		"p_atq": "Ataque físico", "m_atq": "Ataque mágico", "p_def": "Defesa física", "m_def": "Defesa mágica", "vel_ataque": "Vel. de ataque",
		"vel_conjuracao": "Vel. de conjuração", "critico": "Crítico (%)", "esquiva": "Esquiva", "precisao": "Precisão", "hp_por_nivel": "Vida por nível", "mp_por_nivel": "Mana por nível"}
	for k in nomes:
		if st.has(k):
			grade.add_child(_label(nomes[k], 14, Color(0.75, 0.77, 0.83)))
			var v := float(st[k])
			grade.add_child(_label(str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v, 15, GOLD, true))
	var bonus: Array = []
	for k in st:
		if str(k).begins_with("bonus_"):
			bonus.append("%s +%d%%" % [str(k).trim_prefix("bonus_").replace("_", " "), int(st[k])])
	if not bonus.is_empty():
		var lb := _label("Bônus do elemento: " + ",  ".join(bonus), 14, Color(0.6, 0.9, 0.7))
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		win_list.add_child(lb)
	var lv := _label("Vantagem elemental: +25% de dano e +8% de crítico contra o elemento que o seu vence; −20% contra o que vence o seu. Contra jogadores, a resistência elemental do alvo reduz o bônus.", 13, Color(0.8, 0.8, 0.85))
	lv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win_list.add_child(lv)


func _arvore_classes(cv: Dictionary, cid: String, lvl: int) -> void:
	var raca := str(cv.classes.get(cid, {}).get("raca", "humano"))
	var cadeia := cadeia_classe(cid)
	_note("Classes da raça: base (nível 1), 1ª classe (nível 20), 2ª (nível 40) e 3ª (nível 76). Cada 1ª classe abre dois caminhos.")
	var filhos := {}
	for k in cv.classes:
		var c: Dictionary = cv.classes[k]
		if c.raca == raca:
			if not filhos.has(c.pai):
				filhos[c.pai] = []
			filhos[c.pai].append(k)
	var pilha: Array = []
	for k in filhos.get("", []):
		pilha.append([k, 0])
	while not pilha.is_empty():
		var it: Array = pilha.pop_front()
		var k: String = it[0]
		var c: Dictionary = cv.classes[k]
		var aqui := k in cadeia
		var txt := "%s%s   ·   %s   ·   nível %d   ·   %s" % ["      ".repeat(int(it[1])), c.nome, str(c.arquetipo).capitalize(), int(c.nivel), cv.elementos.get(str(c.elemento), "")]
		if k == cid:
			txt += "   ◀ você"
		_row(txt, [], GOLD if aqui else (Color(0.88, 0.9, 0.94) if int(c.nivel) <= lvl else Color(0.6, 0.62, 0.68)))
		var fs: Array = filhos.get(k, [])
		for i in range(fs.size() - 1, -1, -1):
			pilha.push_front([fs[i], int(it[1]) + 1])


# chance de sucesso do próximo nível (mesma regra do servidor)
static func chance_encanto(n: int) -> float:
	return 1.0 if n < ENC_SEGURO else maxf(0.08, 0.72 - (n - ENC_SEGURO) * 0.05)


static func mult_encanto(slot: String, n: float) -> float:
	var a := [0.045, 0.03] if slot == "arma" else [0.035, 0.025]
	return 1.0 + minf(n, 10.0) * a[0] + maxf(0.0, n - 10.0) * a[1]


static func pergaminho_de(slot: String, g: int) -> String:
	return ("enc_arma_" if slot == "arma" else "enc_arm_") + str(GRADES[clampi(g, 0, 5)]).to_lower()


# janela de encantamento: escolhe a peça vestida, mostra o pergaminho, a chance, o risco e o brilho do próximo nível
func _janela_encantar(me: Dictionary, inv: Dictionary) -> void:
	var eq: Dictionary = me.get("equipment") if me.get("equipment") is Dictionary else {}
	var en: Dictionary = me.get("enchant") if me.get("enchant") is Dictionary else {}
	win_title.text = "◆ Encantamento"
	var slots: Array = []
	for sl in ["arma", "escudo", "elmo", "armadura", "luvas", "botas"]:
		if str(eq.get(sl, "")) != "":
			slots.append(sl)
	if slots.is_empty():
		_note("Vista uma arma ou uma peça de armadura para encantar.")
		return
	if not slots.has(enc_slot):
		enc_slot = slots[0]
	var nomes := {"arma": "Arma", "escudo": "Escudo", "elmo": "Elmo", "armadura": "Armadura", "luvas": "Luvas", "botas": "Botas"}
	var defs: Array = []
	for sl in slots:
		defs.append([sl, "%s +%d" % [nomes[sl], int(en.get(str(eq[sl]), 0))]])
	_tabs(defs, enc_slot, func(k):
		enc_slot = k
		enc_confirmar = false
		open_window("encantar", w_me, w_inv, w_extra))
	var iid := str(eq[enc_slot])
	var it: Dictionary = info.items.get(iid, {})
	var g := grade_of(iid)
	var n := int(en.get(iid, 0))
	var cor := Character.cor_encanto(maxi(n, 4)) if n >= 4 else Color(0.75, 0.78, 0.85)

	var corpo := HBoxContainer.new()
	corpo.add_theme_constant_override("separation", 18)
	win_list.add_child(corpo)
	# esquerda: a peça grande, com moldura na cor do brilho atual
	var esq := VBoxContainer.new()
	esq.add_theme_constant_override("separation", 6)
	corpo.add_child(esq)
	var moldura := PanelContainer.new()
	var ms := _inset()
	ms.border_color = cor if n >= 4 else GRADE_COL[g]
	ms.set_border_width_all(3 if n >= 4 else 2)
	ms.shadow_color = Color(cor, 0.55) if n >= 4 else Color(0, 0, 0, 0)
	ms.shadow_size = 14 if n >= 4 else 0
	moldura.add_theme_stylebox_override("panel", ms)
	esq.add_child(moldura)
	var ic := _item_icon(iid, 112)
	ic.label = "+%d" % n if n > 0 else ""
	ic.mouse_filter = Control.MOUSE_FILTER_PASS
	moldura.add_child(ic)
	var faixa_txt := "sem brilho" if n < 4 else ("brilho branco" if n < 10 else ("brilho azul" if n < 16 else "chama dourada"))
	var fl := _label(faixa_txt, 12, cor if n >= 4 else Color(0.6, 0.62, 0.68))
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esq.add_child(fl)

	# direita: nome, trilha de níveis e números
	var dir := VBoxContainer.new()
	dir.add_theme_constant_override("separation", 7)
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo.add_child(dir)
	var tl := _label(("+%d  " % n if n > 0 else "") + str(it.get("name", iid)), 18, GRADE_COL[g], true)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dir.add_child(tl)
	dir.add_child(_label("Grau %s   ·   %s" % [GRADES[g], nomes[enc_slot]], 12, Color(0.7, 0.72, 0.78)))
	# trilha de +1 a +16: branco até +9, azul até +15, ouro no +16; o próximo nível pisca em contorno
	var trilha := HBoxContainer.new()
	trilha.add_theme_constant_override("separation", 3)
	dir.add_child(trilha)
	for k in range(1, ENC_MAX + 1):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(16, 16 if k < ENC_MAX else 20)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ps := StyleBoxFlat.new()
		var ck := Character.cor_encanto(k) if k >= 4 else Color(0.82, 0.84, 0.9)
		ps.set_corner_radius_all(8 if k == ENC_MAX else 3)
		if k <= n:
			ps.bg_color = ck
		else:
			ps.bg_color = Color(0.08, 0.09, 0.12, 0.9)
			ps.border_color = Color(ck, 0.95 if k == n + 1 else 0.3)
			ps.set_border_width_all(2 if k == n + 1 else 1)
		pip.add_theme_stylebox_override("panel", ps)
		pip.tooltip_text = "+%d%s" % [k, "  (seguro)" if k <= ENC_SEGURO else ""]
		trilha.add_child(pip)

	var linhas := VBoxContainer.new()
	linhas.add_theme_constant_override("separation", 4)
	dir.add_child(linhas)
	var st_nome := "Ataque" if enc_slot == "arma" else "Defesa"
	var agora_m := mult_encanto(enc_slot, n)
	var depois_m := mult_encanto(enc_slot, n + 1)
	var maximo := n >= ENC_MAX
	var perg := pergaminho_de(enc_slot, g)
	var tem := int(inv.get(perg, 0))
	var pit: Dictionary = info.items.get(perg, {})
	if maximo:
		linhas.add_child(_label("Esta peça já está no máximo (+%d)." % ENC_MAX, 15, GOLD, true))
	else:
		var ch := chance_encanto(n)
		linhas.add_child(_label("%s: +%d%%  →  +%d%%" % [st_nome, int(roundf((agora_m - 1.0) * 1000.0) / 10.0), int(roundf((depois_m - 1.0) * 1000.0) / 10.0)], 15, Color(0.85, 0.95, 0.85)))
		var cl := _label("Chance de sucesso: %d%%%s" % [int(roundf(ch * 100.0)), "   (sem risco até +%d)" % ENC_SEGURO if n < ENC_SEGURO else ""], 15, Color(0.6, 0.95, 0.65) if ch >= 0.99 else (GOLD if ch >= 0.5 else Color(1.0, 0.55, 0.45)), true)
		linhas.add_child(cl)
		if n >= ENC_SEGURO:
			var risco := _label("Se falhar, a peça volta para +0 e o pergaminho é gasto.", 13, Color(1.0, 0.6, 0.5))
			risco.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			linhas.add_child(risco)
		if n + 1 == 10 or n + 1 == 16:
			linhas.add_child(_label("No +%d o brilho muda para %s." % [n + 1, "azul" if n + 1 == 10 else "chama dourada"], 13, Character.cor_encanto(n + 1)))
	# pergaminho necessário
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 8)
	dir.add_child(ph)
	if not pit.is_empty():
		var pic := _item_icon(perg, 40)
		pic.label = "x%d" % tem
		pic.mouse_filter = Control.MOUSE_FILTER_PASS
		ph.add_child(pic)
	var pl := _label(("%s\nvocê tem %d" % [str(pit.get("name", perg)), tem]) if not pit.is_empty() else "Sem pergaminho para esse grau", 13, Color(0.85, 0.86, 0.92) if tem > 0 else Color(0.75, 0.6, 0.55))
	ph.add_child(pl)
	# botão: no risco, o primeiro clique só pede confirmação
	var arriscado := n >= ENC_SEGURO
	var pode := not maximo and tem > 0
	var txt := "Encantar"
	if not pode:
		txt = "Sem pergaminho" if not maximo else "Máximo"
	elif arriscado and enc_confirmar:
		txt = "Confirmar: arriscar +%d" % (n + 1)
	var b := _button(txt, pode)
	b.custom_minimum_size = Vector2(0, 40)
	b.disabled = not pode
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		if arriscado and not enc_confirmar:
			enc_confirmar = true
			open_window("encantar", w_me, w_inv, w_extra)
			return
		enc_confirmar = false
		want_action.emit("game_enchant", {"p_slot": enc_slot}))
	dir.add_child(b)
	if not pode and not maximo:
		_note("Pergaminhos de encantamento caem de monstros e chefes do mesmo grau da peça.")


# painel de detalhe do item escolhido
func _detail(title: String, g: int, lines: Array, extra_line: String, acts: Array) -> void:
	var pc := PanelContainer.new()
	var sb := _inset()
	sb.border_color = GRADE_COL[g]
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	pc.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	if str(_detail_id) != "":
		head.add_child(_item_icon(_detail_id, 56))
	var tl := _label(title, 16, GRADE_COL[g], true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	v.add_child(head)
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


# ícone de item com moldura na cor do grau e o nome e descrição ao passar o mouse
# aparência de cada peça (para a loja e a bolsa mostrarem como ela é, além do ícone)
const _METAL := ["ferro batido, de acabamento rústico", "bronze polido com rebites de cobre", "aço temperado com detalhes gravados",
	"aço azulado (azurita) com filetes prateados", "metal rubro de bordas escurecidas e detalhes em ouro velho", "liga celestial clara com filetes dourados e brilho suave"]
const _TECIDO := ["linho cru", "lã tingida em tons de terra", "linho fino cinza com bordado", "seda azul-marinho com bordas prateadas",
	"veludo vinho com bordados dourados", "tecido branco-perolado com runas douradas"]
const _COURO := ["couro cru", "couro curtido com placas de bronze", "couro escuro reforçado com aço", "couro azulado com placas de azurita",
	"couro vinho com fivelas douradas", "couro claro com placas celestiais"]
const _MADEIRA := ["madeira simples", "freixo com anéis de bronze", "carvalho com ponteira de aço", "madeira escura com cristal azul",
	"madeira avermelhada com ouro velho", "madeira clara com cristal celestial"]
const _FORMA_ARMA := {"espada": "Espada de uma mão: lâmina reta e guarda em cruz", "espadao": "Espadão de duas mãos: lâmina longa e larga",
	"adaga": "Adaga curta de lâmina estreita, para golpes rápidos", "punhal": "Punhal leve de ponta fina", "duplas": "Par de lâminas, uma em cada mão",
	"arco": "Arco longo de braços curvados; a corda só aparece ao atirar", "cajado": "Cajado longo de duas mãos, com cabeça de foco mágico",
	"cetro": "Cetro de uma mão com cabeça ornamentada", "lanca": "Lança de haste reta e ponta larga", "machado": "Machado de lâmina curva e cabo firme",
	"martelo": "Martelo de guerra de cabeça pesada", "punhos": "Par de soqueiras para luta corpo a corpo", "garras": "Garras presas ao punho, com três lâminas curvas"}
const _FORMA_ROUPA := {
	"armadura": {"pesada": "Armadura de placas que cobre peito, ombros e cintura", "leve": "Gibão justo ao corpo, com ombreiras leves", "robe": "Túnica longa de mago, com capa leve"},
	"elmo": {"pesada": "Elmo de placas que protege a cabeça e a nuca", "leve": "Proteção de cabeça leve, que não atrapalha a visão", "robe": "Capuz ou chapéu de tecido"},
	"luvas": {"pesada": "Manoplas de placas articuladas", "leve": "Luvas de couro de cano curto", "robe": "Luvas de tecido fino"},
	"botas": {"pesada": "Grevas de metal até o joelho", "leve": "Botas de couro de cano alto", "robe": "Botas leves ou sandálias de tecido"}}
const _QUEM := {"pesada": "Para guerreiros e cavaleiros", "leve": "Para arqueiros e lâminas ágeis", "robe": "Para magos e sacerdotes"}

static func aparencia(id: String, it: Dictionary) -> String:
	if it.has("desc") and str(it.desc) != "":
		return str(it.desc)
	var g := clampi(int(it.get("grade", 0)), 0, 5)
	var sl := str(it.get("slot", ""))
	var k := str(it.get("kind", ""))
	if sl == "arma":
		var mat: String = _MADEIRA[g] if k in ["arco", "cajado", "cetro"] else _METAL[g]
		return "%s, em %s." % [_FORMA_ARMA.get(k, "Arma"), mat]
	if sl == "escudo":
		return ("Égide mágica de braço, em %s." if k == "egide" or id.begins_with("egide") else "Escudo de braço, em %s.") % _METAL[g]
	if _FORMA_ROUPA.has(sl):
		var tipo := "pesada" if "pesada" in id else ("leve" if "leve" in id else ("robe" if "robe" in id else k))
		if not _QUEM.has(tipo):
			return ""
		var mat: String = _METAL[g] if tipo == "pesada" else (_COURO[g] if tipo == "leve" else _TECIDO[g])
		return "%s, em %s. %s." % [_FORMA_ROUPA[sl].get(tipo, ""), mat, _QUEM[tipo]]
	return ""


static var _fotos := {}

# foto 3D do item, gerada por teste/estudio_icones.gd (uma por arma e por peça de roupa)
static func foto_item(id: String) -> Texture2D:
	if _fotos.has(id):
		return _fotos[id]
	var cam := "res://assets/icones/itens/%s.png" % id
	var t: Texture2D = load(cam) if ResourceLoader.exists(cam) else null
	_fotos[id] = t
	return t


func _item_icon(id: String, size: float, selected := false) -> Button:
	var it: Dictionary = info.items.get(id, {})
	var g := grade_of(id)
	var look: Array = IconButton.item_look(id, it)
	var b := _icon(look[0], "", size)
	b.textura = foto_item(id)
	var ap := aparencia(id, it)
	b.tooltip_text = str(it.get("name", id)) + ("\n" + ap if ap != "" else "")
	b.tint = (look[1] as Color).lerp(GRADE_COL[g], 0.3 if g >= 3 else 0.0)
	b.rim = Color(1, 1, 1) if selected else GRADE_COL[g]
	b.rim_w = 2
	var lines := [str(it.get("name", id)), "Grau %s%s" % [GRADES[g], " (lendário)" if g == 6 else ""]]
	lines.append_array(_stat_lines(it))
	b.tooltip_text = "\n".join(lines)
	return b


# encaixe de equipamento: o desenho da peça vestida, ou a silhueta apagada do local quando vazio
func _socket(slot: String, id: String, g: int, selected: bool) -> Button:
	var b: Button
	if id != "":
		b = _item_icon(id, 70, selected)
		b.label = GRADES[g]
	else:
		b = _icon(IconButton.SLOT.get(slot, "vazio"), "%s: vazio" % slot.capitalize(), 70)
		b.tint = Color(0.32, 0.32, 0.36)
		b.rim = Color(1, 1, 1) if selected else Color(0.36, 0.29, 0.16)
		b.rim_w = 2
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
	_detail_id = ""
	for c in win_list.get_children():
		c.queue_free()
	var items: Dictionary = info.items
	var aurum := int(me.get("aurum", 0))
	w_me = me
	w_inv = inv
	w_extra = extra
	if name == "gm":
		_gm_window()
		return
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
				_detail_id = sid
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
				var cb := _item_icon(str(id), 60, not sel_eq and sel == str(id))
				cb.label = "%s\nx%d" % [GRADES[g], int(inv[id])]
				cb.pressed.connect(func():
					sel = str(id)
					sel_eq = false
					open_window("bolsa", w_me, w_inv, w_extra))
				bag.add_child(cb)
			for i in maxi(0, 28 - inv.size()):
				var e := _icon("vazio", "", 60)
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
				_detail_id = sel
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
	elif name == "acoes":
		win_title.text = "◆ Ações"
		_note("Clique para fazer. Arraste um ícone para a barra de habilidades para deixar à mão; botão direito no espaço tira.")
		var ag := GridContainer.new()
		ag.columns = 3
		ag.add_theme_constant_override("h_separation", 14)
		ag.add_theme_constant_override("v_separation", 10)
		win_list.add_child(ag)
		for a in ACTIONS:
			var cell := VBoxContainer.new()
			cell.custom_minimum_size = Vector2(120, 0)
			cell.alignment = BoxContainer.ALIGNMENT_CENTER
			var ib := _icon(a[1], "%s\n%s" % [a[2], a[3]], 56)
			ib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var aid: String = a[0]
			var akind: String = a[1]
			ib.disabled = aid == "escalar"
			ib.pressed.connect(func(): want_do.emit(aid))
			if aid != "escalar":
				ib.set_drag_forwarding(func(_at):
					var pvw := _icon(akind, "", 40)
					ib.set_drag_preview(pvw)
					return {"acao": aid}, Callable(), Callable())
			cell.add_child(ib)
			var nl := _label(a[2], 13, Color(0.9, 0.88, 0.8))
			nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(nl)
			ag.add_child(cell)
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
	elif name == "encantar":
		_janela_encantar(me, inv)
	elif name == "mercado":
		_janela_mercado(me, inv, extra)
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
				flow.add_child(_item_card("%s x%d" % [items.get(str(r.out), {}).get("name", r.out), int(r.qty)], grade_of(str(r.out)), parts, "", "Fabricar", "game_craft", {"p_recipe": r.id, "p_times": 1, "_icon": str(r.out)}, can))
	elif name == "habilidades":
		_janela_habilidades(me)
	elif name == "classe" and me.get("skills") is Dictionary:
		_janela_classe_v2(me)
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


# nome da cidade (ou da área) ao chegar: aparece, fica uns segundos e some
func anunciar(titulo: String, sub := "", segundos := 3.5) -> void:
	if faixa == null:
		return
	(faixa.get_child(0) as Label).text = titulo
	(faixa.get_child(1) as Label).text = sub
	if faixa_tw:
		faixa_tw.kill()
	faixa_tw = create_tween()
	faixa_tw.tween_property(faixa, "modulate:a", 1.0, 0.6)
	faixa_tw.tween_interval(segundos)
	faixa_tw.tween_property(faixa, "modulate:a", 0.0, 1.2)


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
	_posicionar_painel("lista")
	char_box.visible = false
	login_box.find_child("Form", true, false).visible = false
	create_box.visible = true
	name_edit.text = ""
	set_status("")
	_preview()


# login: painel no centro, abaixo do meio (como as telas de entrada de MMO); escolha e criação: à esquerda,
# deixando o personagem no centro da cena
func _posicionar_painel(modo: String) -> void:
	if painel_entrada == null:
		return
	if modo == "login":
		# canto inferior direito: a Árvore da abertura fica livre no centro da tela
		painel_entrada.anchor_left = 0.97
		painel_entrada.anchor_right = 0.97
		painel_entrada.anchor_top = 0.9
		painel_entrada.anchor_bottom = 0.9
		painel_entrada.offset_left = -400
		painel_entrada.offset_right = 0
		painel_entrada.grow_vertical = Control.GROW_DIRECTION_BEGIN
		painel_entrada.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		painel_entrada.custom_minimum_size = Vector2(400, 0)
	else:
		painel_entrada.grow_vertical = Control.GROW_DIRECTION_BOTH
		painel_entrada.grow_horizontal = Control.GROW_DIRECTION_END
		painel_entrada.custom_minimum_size = Vector2(430, 0)
		painel_entrada.anchor_left = 0.05
		painel_entrada.anchor_right = 0.05
		painel_entrada.anchor_top = 0.5
		painel_entrada.anchor_bottom = 0.5
		painel_entrada.offset_left = 0
		painel_entrada.offset_right = 430
	_modo_painel = modo
	_ajustar_painel()
	call_deferred("_ajustar_painel")  # de novo depois que as partes escondidas saem do cálculo


# altura do painel = altura do conteúdo (o Godot não encolhe sozinho quando partes somem)
var _modo_painel := "login"


func _ajustar_painel() -> void:
	if painel_entrada == null:
		return
	var m := painel_entrada.get_combined_minimum_size()
	if _modo_painel == "login":
		painel_entrada.offset_top = -m.y
		painel_entrada.offset_bottom = 0
	else:
		painel_entrada.offset_top = -m.y * 0.5
		painel_entrada.offset_bottom = m.y * 0.5


# tela de carregamento: cobre a montagem do mundo e o preparo dos efeitos, para não aparecer nada pela metade
const DICAS := [
	"Dica: a tecla M abre o mapa do reino.",
	"Dica: armas encantadas brilham mais a cada nível; no +16 ganham chama dourada.",
	"Dica: dentro das cidades há paz; fora delas, cuidado com os monstros de nível alto.",
	"Dica: arqueiros ficam mais firmes parados: mire antes de soltar a flecha.",
	"Dica: Enter abre o bate-papo.",
]


func tela_carregando(on: bool, texto := "", frac := 0.0) -> void:
	if tela_carga == null:
		tela_carga = Control.new()
		tela_carga.set_anchors_preset(Control.PRESET_FULL_RECT)
		tela_carga.mouse_filter = Control.MOUSE_FILTER_STOP
		var camada := CanvasLayer.new()  # acima de tudo (minimapa e janelas)
		camada.layer = 90
		add_child(camada)
		camada.add_child(tela_carga)
		var fundo := ColorRect.new()
		fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sm := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment(){ vec2 p = UV - vec2(0.5, 0.42); float d = length(p * vec2(1.6, 1.0)); vec3 c = mix(vec3(0.10, 0.08, 0.05), vec3(0.015, 0.02, 0.03), smoothstep(0.0, 0.9, d)); float raio = pow(max(0.0, 1.0 - abs(p.x * 2.2 + p.y * 0.4)), 8.0) * 0.06; COLOR = vec4(c + vec3(0.9, 0.7, 0.4) * raio, 1.0); }"
		sm.shader = sh
		fundo.material = sm
		tela_carga.add_child(fundo)
		var v := VBoxContainer.new()
		v.anchor_left = 0.5
		v.anchor_right = 0.5
		v.anchor_top = 0.3
		v.anchor_bottom = 0.3
		v.offset_left = -330
		v.offset_right = 330
		v.add_theme_constant_override("separation", 18)
		tela_carga.add_child(v)
		var t := TextureRect.new()
		t.texture = load("res://assets/marca/logo.png")
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(660, 218)
		v.add_child(t)
		_carga_texto = _label("", 18, Color(0.85, 0.82, 0.74))
		_carga_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(_carga_texto)
		_carga_barra = ProgressBar.new()
		_carga_barra.show_percentage = false
		_carga_barra.custom_minimum_size = Vector2(0, 10)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.05, 0.05, 0.06, 0.9)
		bg.border_color = Color(0.55, 0.43, 0.2)
		bg.set_border_width_all(1)
		bg.set_corner_radius_all(5)
		var fg := StyleBoxFlat.new()
		fg.bg_color = GOLD
		fg.set_corner_radius_all(5)
		_carga_barra.add_theme_stylebox_override("background", bg)
		_carga_barra.add_theme_stylebox_override("fill", fg)
		v.add_child(_carga_barra)
		_carga_dica = _label("", 15, Color(0.62, 0.64, 0.7))
		_carga_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_carga_dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(_carga_dica)
	if on and not tela_carga.visible or (on and _carga_dica.text == ""):
		_carga_dica.text = DICAS[randi() % DICAS.size()]
	tela_carga.visible = on
	tela_carga.modulate.a = 1.0
	if on:
		_carga_texto.text = texto
		_carga_barra.value = clampf(frac, 0.0, 1.0) * 100.0


func esconder_carregando() -> void:
	if tela_carga == null or not tela_carga.visible:
		return
	var tw := tela_carga.create_tween()
	tw.tween_property(tela_carga, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func(): tela_carga.visible = false)


# tela de login sobre a cena da abertura: logotipo grande no alto, painel sem o logotipo pequeno
# e a história contada em frases que se alternam embaixo
func modo_abertura(on: bool) -> void:
	if logo_grande == null:
		logo_grande = TextureRect.new()
		logo_grande.texture = load("res://assets/marca/logo.png")
		logo_grande.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_grande.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_grande.anchor_left = 0.5
		logo_grande.anchor_right = 0.5
		logo_grande.anchor_top = 0.03
		logo_grande.anchor_bottom = 0.03
		logo_grande.offset_left = -390
		logo_grande.offset_right = 390
		logo_grande.offset_bottom = 257
		logo_grande.mouse_filter = Control.MOUSE_FILTER_IGNORE
		login_box.add_child(logo_grande)
		_historia = _label("", 19, Color(0.9, 0.86, 0.74))
		_historia.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_historia.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_historia.anchor_left = 0.03
		_historia.anchor_right = 0.03
		_historia.anchor_top = 1.0
		_historia.anchor_bottom = 1.0
		_historia.offset_left = 0
		_historia.offset_right = 560
		_historia.offset_top = -170
		_historia.offset_bottom = -76
		_historia.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		_historia.add_theme_constant_override("shadow_offset_y", 2)
		_historia.mouse_filter = Control.MOUSE_FILTER_IGNORE
		login_box.add_child(_historia)
		var tm := Timer.new()
		tm.wait_time = 7.0
		tm.autostart = true
		tm.timeout.connect(_proxima_historia)
		add_child(tm)
		_historia.text = HISTORIA[0]
	logo_grande.visible = on
	_historia.visible = on
	logo_painel.visible = not on
	call_deferred("_ajustar_painel")
	var sombra := login_box.get_child(0) as CanvasItem  # escurecimento das bordas: mais leve sobre a abertura
	if sombra:
		sombra.modulate.a = 0.55 if on else 1.0


func _dbg_painel() -> void:
	if OS.get_environment("DBG_PAINEL") != "":
		print("PAINEL ", painel_entrada.get_rect(), " min=", painel_entrada.get_combined_minimum_size(), " ofs=", painel_entrada.offset_top, ",", painel_entrada.offset_bottom, " grow=", painel_entrada.grow_vertical)


func _proxima_historia() -> void:
	if _historia == null or not _historia.visible:
		return
	_hist_i = (_hist_i + 1) % HISTORIA.size()
	var tw := _historia.create_tween()
	tw.tween_property(_historia, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): _historia.text = HISTORIA[_hist_i])
	tw.tween_property(_historia, "modulate:a", 1.0, 0.8)


func show_login() -> void:
	_posicionar_painel("login")
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
	_posicionar_painel("lista")
	get_tree().create_timer(2.0).timeout.connect(_dbg_painel)
	call_deferred("_ajustar_painel")
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
		var pick_info := _label("", 14, Color(0.78, 0.8, 0.85))
		pick_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var enter := _button("Entrar no jogo", true)
		var group: Array = []
		var chosen := {"c": {}}
		var choose := func(d: Dictionary, b: Button):
			chosen.c = d
			for x in group:
				(x as Button).modulate = Color(1, 1, 1, 0.62)
			b.modulate = Color(1, 1, 1, 1)
			var eq: Dictionary = d.get("equipment") if d.get("equipment") is Dictionary else {}
			var gear: Array = []
			for slot in ["arma", "armadura", "escudo"]:
				var iid := str(eq.get(slot, ""))
				if iid != "" and (info.get("items", {}) as Dictionary).has(iid):
					gear.append(str(info.items[iid].get("name", iid)))
			pick_info.text = "%s  ·  Nível %d%s" % [d.get("name", "?"), int(d.get("level", 1)), ("\n" + ", ".join(gear)) if not gear.is_empty() else ""]
			want_show_char.emit(d)
		for c in list:
			var d: Dictionary = c
			var race: String = info.races[d.race].name if (info.get("races", {}) as Dictionary).has(str(d.get("race", ""))) else str(d.get("race", "")).capitalize()
			var b := _button("%s   ·   Nv %s   ·   %s" % [d.get("name", "?"), str(int(d.get("level", 1))), race], false)
			group.append(b)
			b.pressed.connect(func(): choose.call(d, b))
			char_box.add_child(b)
		char_box.add_child(pick_info)
		enter.pressed.connect(func():
			if not (chosen.c as Dictionary).is_empty():
				want_char.emit(chosen.c))
		char_box.add_child(enter)
		choose.call(list[0], group[0])
	if list.size() < 3:
		var nb := _button("Criar personagem")
		nb.pressed.connect(func(): want_new_char.emit())
		char_box.add_child(nb)
	var out := _button("Trocar de conta")
	out.pressed.connect(func(): want_exit_to_login.emit())
	char_box.add_child(out)
	set_status("")


# ---------- painel de GM ----------
func set_gm(on: bool) -> void:
	if gm_btn:
		gm_btn.visible = on
		var dock := gm_btn.get_parent().get_parent() as Control
		dock.offset_top = dock.offset_bottom - (176.0 - 40.0) - (46.0 if on else 0.0)


func _gm_row(parent: Control, defs: Array) -> void:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 6)
	h.add_theme_constant_override("v_separation", 6)
	for d in defs:  # [texto, comando, argumentos, destaque]
		var b := _button(str(d[0]), d.size() > 3 and bool(d[3]))
		b.custom_minimum_size = Vector2(0, 30)
		b.add_theme_font_size_override("font_size", 13)
		b.focus_mode = Control.FOCUS_NONE
		var cmd: String = d[1]
		var args: Dictionary = d[2]
		b.pressed.connect(func(): want_gm.emit(cmd, args))
		h.add_child(b)
	parent.add_child(h)


func _gm_title(t: String) -> void:
	win_list.add_child(_label(t, 15, GOLD, true))


func _gm_window() -> void:
	win_title.text = "♛ Painel de GM"
	_tabs([["gm_mundo", "Teleporte"], ["gm_poder", "Poderes"], ["gm_mob", "Monstros"], ["gm_char", "Personagem"], ["gm_jog", "Jogadores"]], tab if tab.begins_with("gm_") else "gm_mundo", func(k):
		tab = k
		open_window("gm", w_me, w_inv, w_extra))
	var cur: String = tab if tab.begins_with("gm_") else "gm_mundo"
	var v: Dictionary = gm_view
	match cur:
		"gm_mundo":
			_gm_title("Cidades")
			var defs: Array = []
			for t in info.towns:
				defs.append([t.name, "tp", {"x": float(t.x) + 3.0, "z": float(t.z) + 8.0}])
			_gm_row(win_list, defs)
			for grp in [["castles", "Castelos"], ["villages", "Vilas"]]:
				var lst: Array = (v.get("mapa", {}) as Dictionary).get(grp[0], [])
				if lst.is_empty():
					continue
				_gm_title(grp[1])
				defs = []
				for c in lst:
					defs.append([c.name, "tp", {"x": float(c.x), "z": float(c.z) + (44.0 if grp[0] == "castles" else 10.0)}])
				_gm_row(win_list, defs)
			_gm_title("Ruínas e pontos")
			defs = []
			for l in info.get("landmarks", []):
				defs.append([l.name, "tp", {"x": float(l.x), "z": float(l.z) + float(l.get("r", 40)) * 0.7}])
			_gm_row(win_list, defs)
			_gm_title("Interiores")
			_gm_row(win_list, [["Taverna", "interior", {"kind": "taverna"}], ["Forja", "interior", {"kind": "forja"}], ["Igreja", "interior", {"kind": "igreja"}], ["Casa", "interior", {"kind": "casa"}], ["Loja", "interior", {"kind": "loja"}]])
			_note("Também pelo bate-papo: /tp x z   ·   /ir nome   ·   clique com Ctrl+Alt no chão para teleportar ali.")
		"gm_poder":
			_gm_title("Seu personagem")
			_gm_row(win_list, [["Invencível: " + ("ligado" if v.get("god", false) else "desligado"), "deus", {}, v.get("god", false)],
				["Velocidade x3: " + ("ligada" if v.get("speed", false) else "desligada"), "vel", {}, v.get("speed", false)],
				["Voar: " + ("ligado" if v.get("fly", false) else "desligado"), "voar", {}, v.get("fly", false)],
				["Invisível para monstros: " + ("ligado" if v.get("hide", false) else "desligado"), "oculto", {}, v.get("hide", false)],
				["Curar tudo", "curar", {}]])
			_note("Voando: Espaço sobe, X desce, V liga e desliga.")
			_gm_title("Hora e clima")
			_gm_row(win_list, [["Amanhecer", "hora", {"h": 6.0}], ["Meio-dia", "hora", {"h": 12.0}], ["Entardecer", "hora", {"h": 18.0}], ["Meia-noite", "hora", {"h": 0.0}], ["Chuva", "clima", {"w": "chuva"}], ["Céu limpo", "clima", {"w": "limpo"}]])
			_gm_title("Mundo")
			_gm_row(win_list, [["Recursos renascem", "reset_nos", {}], ["Mostrar posição", "onde", {}]])
		"gm_mob":
			_gm_title("Alvo e arredores")
			_gm_row(win_list, [["Matar alvo", "matar", {}], ["Matar todos (40 m)", "matartodos", {"r": 40.0}], ["Limpar sem recompensa (60 m)", "limpar", {"r": 60.0}]])
			_gm_title("Criar monstro aqui (nível do seu personagem)")
			var defs: Array = []
			var seen := {}
			for band in info.mobs:
				for f in band:
					if not seen.has(f.id):
						seen[f.id] = true
						defs.append([("Chefe " if f.boss else "") + str(f.name), "spawn", {"fam": f.id}])
			_gm_row(win_list, defs)
		"gm_char":
			var alvo := _edit("Jogador (vazio = você)")
			alvo.text = str(v.get("alvo", ""))
			alvo.text_changed.connect(func(t): gm_view.alvo = t)
			win_list.add_child(alvo)
			_gm_title("Nível e moeda")
			_gm_row(win_list, [["Nível 20", "nivel", {"nivel": 20}], ["Nível 40", "nivel", {"nivel": 40}], ["Nível 61", "nivel", {"nivel": 61}], ["Nível 76", "nivel", {"nivel": 76}], ["Nível 80", "nivel", {"nivel": 80}],
				["+10 mil aurum", "aurum", {"qtd": 10000}], ["+1 milhão aurum", "aurum", {"qtd": 1000000}], ["Karma zero", "karma", {"qtd": 0}], ["Ver ficha", "info", {}]])
			_gm_title("Profissões no nível 30")
			_gm_row(win_list, [["Coleta", "prof", {"prof": "coleta", "nivel": 30}], ["Refino", "prof", {"prof": "refino", "nivel": 30}], ["Forja", "prof", {"prof": "forja", "nivel": 30}]])
			_gm_title("Dar item")
			var row := HBoxContainer.new()
			var ids: Array = (info.items as Dictionary).keys()
			ids.sort_custom(func(a, b): return str(info.items[a].name) < str(info.items[b].name))
			var ob := OptionButton.new()
			ob.custom_minimum_size = Vector2(260, 32)
			for iid in ids:
				ob.add_item(str(info.items[iid].name))
			ob.fit_to_longest_item = false
			row.add_child(ob)
			var qty := SpinBox.new()
			qty.min_value = 1
			qty.max_value = 9999
			qty.value = 1
			row.add_child(qty)
			var give := _button("Entregar", true)
			give.custom_minimum_size = Vector2(110, 32)
			give.pressed.connect(func(): want_gm.emit("give", {"item": ids[ob.selected], "qtd": int(qty.value)}))
			row.add_child(give)
			win_list.add_child(row)
			_gm_title("Anúncio para todos")
			var an := _edit("Texto do anúncio")
			win_list.add_child(an)
			var ab := _button("Anunciar")
			ab.pressed.connect(func(): want_gm.emit("anuncio", {"msg": an.text}))
			win_list.add_child(ab)
		"gm_jog":
			var online: Array = v.get("online", [])
			_gm_title("Jogadores perto de você (%d)" % online.size())
			if online.is_empty():
				_note("Ninguém por perto agora.")
			for p in online:
				var h := HBoxContainer.new()
				var l := _label("%s  ·  Nv %d" % [p.name, int(p.lvl)], 15)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(l)
				win_list.add_child(h)
				_gm_row(win_list, [["Ir até", "tp", {"x": float(p.x) + 1.5, "z": float(p.z)}], ["Puxar", "puxar", {"alvo": p.name}], ["Ficha", "info", {"alvo": p.name}], ["Desconectar", "kick", {"alvo": p.name}], ["Banir", "ban", {"alvo": p.name}]])
			_gm_title("Por nome")
			var nm := _edit("Nome do jogador")
			win_list.add_child(nm)
			var defs: Array = []
			for k in [["Ficha", "info"], ["Puxar", "puxar"], ["Desconectar", "kick"], ["Banir", "ban"], ["Desbanir", "desban"], ["Tornar GM", "setgm"]]:
				var b := _button(k[0])
				b.custom_minimum_size = Vector2(0, 30)
				var cmd: String = k[1]
				b.pressed.connect(func(): want_gm.emit(cmd, {"alvo": nm.text.strip_edges()}))
				defs.append(b)
			var hf := HFlowContainer.new()
			for b in defs:
				hf.add_child(b)
			win_list.add_child(hf)
	_note("Tudo o que vai ao servidor fica registrado no histórico de GM.")


# ---------- barra de conjuração (acima da barra de atalhos) ----------
var _cast_panel: PanelContainer
var _cast_fill: ColorRect
var _cast_lbl: Label

func cast_bar(nome: String, frac: float, resta: float) -> void:
	if frac < 0.0:
		if _cast_panel:
			_cast_panel.visible = false
		return
	if _cast_panel == null:
		_cast_panel = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.04, 0.03, 0.82)
		sb.border_color = Color(0.72, 0.56, 0.3)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		_cast_panel.add_theme_stylebox_override("panel", sb)
		_cast_panel.custom_minimum_size = Vector2(320, 26)
		_cast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fundo := Control.new()
		fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cast_panel.add_child(fundo)
		_cast_fill = ColorRect.new()
		_cast_fill.color = Color(0.95, 0.72, 0.3)
		_cast_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fundo.add_child(_cast_fill)
		_cast_lbl = Label.new()
		_cast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cast_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cast_lbl.add_theme_font_size_override("font_size", 14)
		_cast_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_cast_lbl.add_theme_constant_override("outline_size", 4)
		_cast_panel.add_child(_cast_lbl)
		add_child(_cast_panel)
	_cast_panel.visible = true
	var vp := get_viewport().get_visible_rect().size
	var y := vp.y * 0.62
	if hot_panel and hot_panel.visible:
		y = hot_panel.global_position.y - 40.0
	_cast_panel.position = Vector2((vp.x - 320.0) * 0.5, y)
	_cast_fill.position = Vector2(2, 2)
	_cast_fill.size = Vector2(312.0 * clampf(frac, 0.0, 1.0), 18)
	_cast_fill.color = Color(0.95, 0.72, 0.3).lerp(Color(1.0, 0.95, 0.75), clampf(frac, 0.0, 1.0))
	_cast_lbl.text = "%s   %.1fs" % [nome, maxf(resta, 0.0)]


# servidor de testes: troca de classe pelo banco novo, com os dois caminhos (A e B) a cada classe
func _janela_classe_v2(me: Dictionary) -> void:
	var cv := classes_v2()
	var lvl := int(me.get("level", 1))
	var cur := str(me.get("class_id", ""))
	if not cv.classes.has(cur):
		for k in cv.classes:
			if int(cv.classes[k].rank) == 0 and str(cv.classes[k].raca) == str(me.get("race", "humano")):
				cur = k
				break
	var cl: Dictionary = cv.classes.get(cur, {})
	win_title.text = "Classe: %s   ·   nível %d" % [str(cl.get("nome", "-")), lvl]
	var achou := false
	for k in cv.classes:
		var nc: Dictionary = cv.classes[k]
		if str(nc.pai) != cur:
			continue
		achou = true
		var need := int(nc.nivel)
		var txt := "%s   ·   caminho %s   ·   %s   ·   elemento %s   ·   requer nível %d" % [nc.nome, str(nc.caminho), str(nc.arquetipo).capitalize(), cv.elementos.get(str(nc.elemento), ""), need]
		_row(txt, [["Evoluir", "game_class_change2", {"p_class": k}]] if lvl >= need else [], Color(0.88, 0.89, 0.93) if lvl >= need else Color(0.55, 0.56, 0.6))
	if not achou:
		_row("Você já está na classe final desta linha.", [])
	_row("A evolução só pode ser feita dentro de uma cidade. As habilidades da classe anterior continuam.", [], Color(0.6, 0.62, 0.68))
