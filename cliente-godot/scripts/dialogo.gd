extends PanelContainer
# Quadro de conversa com NPC: nome e ofício em destaque, fala que aparece letra por letra e opções.
# Abre ao clicar num morador, guarda ou mestre; fecha com "Até logo", Esc ou ao se afastar.

const ROTULOS := {"loja": "Ver mercadorias", "ferraria": "Forjar e encantar", "armazem": "Abrir o armazém",
	"teleporte": "Viajar (teleporte)", "missoes": "Missões", "cla": "Assuntos do clã", "arena": "Entrar na arena",
	"estabulo": "Montarias", "taverna": "Pedir algo", "classe": "Mudar de classe", "livros": "Aprender técnicas (livros)", "oficio": "Ofício e forja", "guia": "Guia do jogo"}
# assuntos do guia: título e explicação (o texto também vai para o bate-papo, para consulta depois)
const GUIA := [
	["Primeiros passos", "Ande com W A S D ou clicando no chão. Clique num morador para conversar. Os mestres de nome verde abrem lojas, forja, clã e classes. Comece pelas missões do quadro e pelos monstros fracos perto do portão."],
	["Combate e skills", "Clique no monstro para marcar o alvo; o segundo clique ou F ataca. Tab troca de alvo. As skills ficam nas teclas 1 a 9 e Shift+1 a 9: a janela de habilidades (P) mostra todas as que você já aprendeu."],
	["PvP", "Jogadores só são atacados de propósito: segure Ctrl e use a skill ou clique no jogador. Sem o Ctrl nada acontece, para ninguém atacar um amigo sem querer."],
	["Classes", "Cada raça começa numa classe base e evolui no nível 20, 40 e 76 com o Mestre de Classes (tecla K). A partir do nível 40 dá para aprender uma subclasse de outra raça."],
	["Equipamento e graus", "Os equipamentos têm grau: Sem Grau, D, C, B, A, S e R. Cada grau pede um nível mínimo. A forja cria e o encantamento fortalece; acima de +3 a chance de falhar aumenta a cada nível."],
	["Missões e história", "O quadro de missões e os personagens de nome dourado contam a história de Valtheria. Cada missão dá experiência, moedas e às vezes uma peça de equipamento."],
]

var main: Node
var e: Dictionary = {}
var nome: Label
var oficio: Label
var fala: RichTextLabel
var opcoes: HFlowContainer
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
	opcoes = HFlowContainer.new()
	opcoes.add_theme_constant_override("h_separation", 8)
	opcoes.add_theme_constant_override("v_separation", 6)
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
	if w == "guia":
		for g in GUIA:
			var t: String = g[0]
			var x: String = g[1]
			_botao(t, func(): _explicar(t, x))
	elif w != "":
		_botao(ROTULOS.get(w, "Abrir"), func(): fechar(); main._window(w))
	if w in ["oficio", "ferraria"]:
		_botao("Encantar equipamento", func(): fechar(); main._window("encantar"))
	_botao("Conversar", func(): _outra())
	_botao("Até logo", func(): fechar())
	visible = true
	_posicionar()


func _explicar(t: String, x: String) -> void:
	fala.text = x
	fala.visible_ratio = 0.0
	_letras = 0.0
	main.ui.chat_line("Guia · " + t, x, "npc")


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
