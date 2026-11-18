extends PanelContainer
# Quadro de conversa com NPC: nome e ofício em destaque, fala que aparece letra por letra e opções.
# Abre ao clicar num morador, guarda ou mestre; fecha com "Até logo", Esc ou ao se afastar.

const ROTULOS := {"loja": "Ver mercadorias", "ferraria": "Forjar e encantar", "armazem": "Abrir o armazém",
	"teleporte": "Viajar (teleporte)", "missoes": "Missões", "cla": "Assuntos do clã", "arena": "Entrar na arena",
	"estabulo": "Montarias", "taverna": "Pedir algo", "classe": "Mudar de classe", "livros": "Aprender técnicas (livros)", "oficio": "Ofício e forja"}

var main: Node
var e: Dictionary = {}
var nome: Label
var oficio: Label
var fala: RichTextLabel
var opcoes: HBoxContainer
var _letras := 0.0


func setup(m: Node) -> void:
	main = m
	visible = false
	custom_minimum_size = Vector2(620, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.05, 0.92)
	sb.border_color = Color(0.72, 0.56, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var topo := HBoxContainer.new()
	v.add_child(topo)
	nome = Label.new()
	nome.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	nome.add_theme_font_size_override("font_size", 18)
	topo.add_child(nome)
	oficio = Label.new()
	oficio.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	oficio.add_theme_font_size_override("font_size", 13)
	oficio.size_flags_vertical = Control.SIZE_SHRINK_END
	topo.add_child(oficio)
	fala = RichTextLabel.new()
	fala.fit_content = true
	fala.bbcode_enabled = false
	fala.custom_minimum_size = Vector2(580, 44)
	fala.add_theme_font_size_override("normal_font_size", 15)
	v.add_child(fala)
	opcoes = HBoxContainer.new()
	opcoes.add_theme_constant_override("separation", 8)
	v.add_child(opcoes)


func abrir(npc: Dictionary, linha: String) -> void:
	e = npc
	nome.text = str(npc.get("name", "")) + "  "
	var w := str(npc.get("window", ""))
	oficio.text = ("· " + ROTULOS.get(w, w.capitalize())) if w != "" else ("· " + {"patrol": "Guarda", "traveler": "Viajante", "story": "Personagem"}.get(str(npc.kind), "Morador"))
	fala.text = linha
	fala.visible_ratio = 0.0
	_letras = 0.0
	for c in opcoes.get_children():
		c.queue_free()
	if w != "":
		_botao(ROTULOS.get(w, "Abrir"), func(): fechar(); main._window(w))
	_botao("Conversar", func(): _outra())
	_botao("Até logo", func(): fechar())
	visible = true
	_posicionar()


func _outra() -> void:
	if e.is_empty():
		return
	var linha: String = main.npcs._line(e, main.npcs._night())
	fala.text = linha
	fala.visible_ratio = 0.0
	_letras = 0.0
	main.npcs.say(e, linha)


func _botao(t: String, f: Callable) -> void:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(f)
	opcoes.add_child(b)


func fechar() -> void:
	visible = false
	e = {}


func _posicionar() -> void:
	var vp := get_viewport_rect().size
	reset_size()
	position = Vector2((vp.x - size.x) * 0.5, vp.y - size.y - 175)


func _process(dt: float) -> void:
	if not visible:
		return
	_letras += dt * 45.0
	var n := maxi(1, fala.text.length())
	fala.visible_ratio = minf(1.0, _letras / n)
	if e.is_empty() or not is_instance_valid(e.get("node")) or (e.node as Node3D).global_position.distance_to(main.player.position) > 7.0:
		fechar()
