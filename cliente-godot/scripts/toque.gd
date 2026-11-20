extends CanvasLayer
# Controles de toque para celular (21/11): joystick à esquerda para andar, arrastar à direita para girar a câmera,
# pinça para aproximar e botões de ação. Tocar no chão, num monstro ou num NPC continua funcionando como o clique
# do mouse (o Godot transforma o primeiro toque em clique). Liga sozinho no celular; no PC com --toque.

var main: Node
var raio := 110.0
var centro := Vector2.ZERO
var dedo_joy := -1
var dedo_cam := -1
var ultimo_cam := Vector2.ZERO
var dedos := {}
var pinca := 0.0
var mov := Vector2.ZERO
var base: Panel
var pino: Panel


func _ready() -> void:
	layer = 5
	var tela := get_viewport().get_visible_rect().size
	raio = clampf(tela.y * 0.12, 70.0, 140.0)
	centro = Vector2(raio * 1.5, tela.y - raio * 1.5)
	base = _circulo(raio, Color(1, 1, 1, 0.12))
	base.position = centro - Vector2(raio, raio)
	pino = _circulo(raio * 0.42, Color(1, 1, 1, 0.35))
	_por_pino(Vector2.ZERO)
	# botões: ataque grande no canto e habilidades em arco em volta dele
	var b := clampf(tela.y * 0.11, 64.0, 120.0)
	var canto := Vector2(tela.x - b * 1.1, tela.y - b * 1.1)
	_botao("Atacar", canto, b * 0.85, func(): main.combat.engage(main.combat.target))
	for i in 4:   # habilidades 1 a 4 num arco em volta do ataque, sem encostar umas nas outras
		var ang := deg_to_rad(180.0 - i * 30.0)
		var slot := i
		_botao(str(i + 1), canto + Vector2(cos(ang), -sin(ang)) * b * 2.0, b * 0.45, func(): main.ui.press_slot(slot))
	_botao("Pular", canto + Vector2(-b * 3.1, b * 0.2), b * 0.45, func(): main._do("pular"))
	_botao("Alvo", canto + Vector2(-b * 2.45, -b * 2.45), b * 0.45, func(): main.combat.next_target())
	_botao("Usar", canto + Vector2(b * 0.1, -b * 3.15), b * 0.45, func(): main.interiores.key_e())
	_botao("Mapa", Vector2(tela.x - b * 0.6, b * 1.9), b * 0.5, func(): _mapa())
	_botao("Menu", Vector2(tela.x - b * 0.6, b * 2.9), b * 0.5, func(): main._window("acoes"))


func _mapa() -> void:
	if main.mapa_ui != null:
		main.mapa_ui.alternar()


func _circulo(r: float, cor: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(int(r))
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(r * 2.0, r * 2.0)
	p.mouse_filter = Control.MOUSE_FILTER_STOP   # o toque aqui não vira clique no mundo
	add_child(p)
	return p


func _botao(texto: String, centro_b: Vector2, r: float, acao: Callable) -> void:
	var bt := Button.new()
	bt.text = texto
	bt.size = Vector2(r * 2.0, r * 2.0)
	bt.position = centro_b - Vector2(r, r)
	bt.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.12, 0.55)
	sb.border_color = Color(0.86, 0.72, 0.42, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(int(r))
	bt.add_theme_stylebox_override("normal", sb)
	var sp := sb.duplicate() as StyleBoxFlat
	sp.bg_color = Color(0.86, 0.72, 0.42, 0.5)
	bt.add_theme_stylebox_override("pressed", sp)
	bt.add_theme_stylebox_override("hover", sb)
	bt.add_theme_font_size_override("font_size", int(r * 0.45))
	bt.pressed.connect(acao)
	add_child(bt)


func _por_pino(d: Vector2) -> void:
	pino.position = centro + d - pino.size * 0.5


func _input(ev: InputEvent) -> void:
	var tela := get_viewport().get_visible_rect().size
	if ev is InputEventScreenTouch:
		if ev.pressed:
			dedos[ev.index] = ev.position
			if dedo_joy < 0 and ev.position.distance_to(centro) < raio * 1.6:
				dedo_joy = ev.index
				_joy(ev.position)
			elif dedo_cam < 0 and ev.position.x > tela.x * 0.35 and not _em_botao(ev.position):
				dedo_cam = ev.index
				ultimo_cam = ev.position
		else:
			dedos.erase(ev.index)
			if ev.index == dedo_joy:
				dedo_joy = -1
				mov = Vector2.ZERO
				_por_pino(Vector2.ZERO)
			if ev.index == dedo_cam:
				dedo_cam = -1
			pinca = 0.0
	elif ev is InputEventScreenDrag:
		dedos[ev.index] = ev.position
		if ev.index == dedo_joy:
			_joy(ev.position)
		elif dedos.size() >= 2 and dedo_joy < 0:
			# pinça com dois dedos: aproxima ou afasta a câmera
			var ps: Array = dedos.values()
			var d: float = (ps[0] as Vector2).distance_to(ps[1])
			if pinca > 0.0:
				main.dist = clampf(main.dist * pinca / maxf(d, 1.0), 3.0, 18.0)
			pinca = d
		elif ev.index == dedo_cam:
			var rel: Vector2 = ev.position - ultimo_cam
			ultimo_cam = ev.position
			main.yaw -= rel.x * 0.008
			main.pitch = clampf(main.pitch - rel.y * 0.006, -1.35, 0.25)


func _em_botao(p: Vector2) -> bool:
	for ch in get_children():
		if ch is Button and Rect2(ch.position, ch.size).has_point(p):
			return true
	return false


func _joy(p: Vector2) -> void:
	var d := p - centro
	if d.length() > raio:
		d = d.normalized() * raio
	_por_pino(d)
	mov = d / raio
	if mov.length() < 0.15:
		mov = Vector2.ZERO
