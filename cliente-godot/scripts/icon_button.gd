extends Button
# Botão esculpido: base em relevo que afunda ao clicar e ícone desenhado em vetor (sem arquivo de imagem).
# O nome e a descrição aparecem ao passar o mouse.

var kind := "":
	set(v):
		kind = v
		queue_redraw()
var tint := Color(0.93, 0.79, 0.47)
var label := "":  # texto curto no canto (tecla, quantidade, segundos)
	set(v):
		label = v
		queue_redraw()
var dim := 0.0:  # 0 a 1: parte escurecida de baixo para cima (recarga)
	set(v):
		dim = v
		queue_redraw()
var rim := Color(0.55, 0.42, 0.2)
var flat_look := false  # sem base: só o desenho (ícones pequenos de status)

const ELEM := {"fire": Color(1.0, 0.5, 0.2), "fogo": Color(1.0, 0.5, 0.2), "ice": Color(0.6, 0.86, 1.0), "gelo": Color(0.6, 0.86, 1.0), "water": Color(0.35, 0.62, 1.0), "agua": Color(0.35, 0.62, 1.0),
	"wind": Color(0.7, 0.95, 0.8), "vento": Color(0.7, 0.95, 0.8), "earth": Color(0.72, 0.56, 0.36), "terra": Color(0.72, 0.56, 0.36), "holy": Color(1.0, 0.92, 0.6), "luz": Color(1.0, 0.92, 0.6),
	"dark": Color(0.68, 0.5, 0.95), "sombra": Color(0.68, 0.5, 0.95), "lightning": Color(1.0, 0.95, 0.45), "raio": Color(1.0, 0.95, 0.45), "nature": Color(0.5, 0.85, 0.4), "poison": Color(0.6, 0.85, 0.3)}


func _ready() -> void:
	var e := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(st, e)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _box(r: Rect2, col: Color, border: Color, bw: int, rad: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _draw() -> void:
	var down := get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
	var hover := is_hovered() and not disabled
	var depth := maxf(2.0, size.y * 0.09)
	var off := Vector2(0, depth if down else 0.0)
	var rad := size.y * 0.24
	if not flat_look:
		# lateral (a espessura do botão) e sombra
		_box(Rect2(Vector2(0, depth), size - Vector2(0, depth)), Color(0.03, 0.03, 0.04, 0.9), Color(0.12, 0.09, 0.05), 1, rad)
		# face
		var face := Rect2(off, size - Vector2(0, depth))
		var base := Color(0.17, 0.16, 0.17) if not hover else Color(0.25, 0.22, 0.18)
		if down:
			base = Color(0.1, 0.1, 0.11)
		if disabled:
			base = Color(0.09, 0.09, 0.1)
		_box(face, base, rim if not hover else Color(0.95, 0.8, 0.45), 1, rad)
		# luz em cima e sombra interna embaixo: dá o relevo
		var inner := face.grow(-2.0)
		_box(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.45)), Color(1, 1, 1, 0.07 if not down else 0.02), Color(0, 0, 0, 0), 0, rad - 2.0)
		draw_line(inner.position + Vector2(rad * 0.7, 0.5), inner.position + Vector2(inner.size.x - rad * 0.7, 0.5), Color(1, 0.95, 0.8, 0.28 if not down else 0.05), 1.0, true)
		draw_line(inner.position + Vector2(rad * 0.7, inner.size.y - 0.5), inner.position + Vector2(inner.size.x - rad * 0.7, inner.size.y - 0.5), Color(0, 0, 0, 0.45), 1.0, true)
	var area := size - Vector2(0, 0.0 if flat_look else depth)
	var c := area * 0.5 + off
	var u := minf(area.x, area.y) / 46.0
	var col := tint if not disabled else Color(0.42, 0.42, 0.45)
	if kind != "":
		# desenho esculpido: sombra deslocada, luz deslocada e a cor por cima
		_glyph(c + Vector2(1.3, 1.7) * u, u, Color(0, 0, 0, 0.75), true)
		_glyph(c - Vector2(0.9, 0.9) * u, u, Color(1, 1, 1, 0.22), true)
		_glyph(c, u, col, false)
	if dim > 0.0 and not flat_look:
		var h := (size.y - depth) * clampf(dim, 0.0, 1.0)
		draw_rect(Rect2(off + Vector2(2, size.y - depth - h), Vector2(size.x - 4, h - 1)), Color(0, 0, 0, 0.62))
	if label != "":
		var f := get_theme_default_font()
		var fs := int(clampf(size.y * 0.24, 9.0, 13.0))
		var lines := label.split("\n")
		draw_string_outline(f, off + Vector2(4, fs + 1), lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.9))
		draw_string(f, off + Vector2(4, fs + 1), lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.96, 0.85))
		if lines.size() > 1:
			var w := f.get_string_size(lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var p := off + Vector2(size.x - w - 4, size.y - depth - 4)
			draw_string_outline(f, p, lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.9))
			draw_string(f, p, lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))


func _poly(c: Vector2, u: float, pts: Array, col: Color) -> void:
	var p := PackedVector2Array()
	for q in pts:
		p.append(c + Vector2(q[0], q[1]) * u)
	draw_colored_polygon(p, col)


func _ln(c: Vector2, u: float, a: Array, b: Array, col: Color, w: float) -> void:
	draw_line(c + Vector2(a[0], a[1]) * u, c + Vector2(b[0], b[1]) * u, col, w * u, true)


func _person(c: Vector2, u: float, col: Color, pose: String) -> void:
	var w := 3.2
	match pose:
		"sit":
			draw_circle(c + Vector2(-2, -11) * u, 4.2 * u, col)
			_ln(c, u, [-2, -6], [-3, 5], col, w + 0.6)
			_ln(c, u, [-3, 5], [8, 5], col, w)
			_ln(c, u, [8, 5], [8, 14], col, w)
			_ln(c, u, [-2, -3], [6, 0], col, w - 0.6)
			_ln(c, u, [-10, -4], [-10, 14], col, w - 0.8)
			_ln(c, u, [-10, 8], [3, 8], col, w - 0.8)
			_ln(c, u, [3, 8], [3, 14], col, w - 0.8)
		"jump":
			draw_circle(c + Vector2(0, -12) * u, 4.2 * u, col)
			_ln(c, u, [0, -7], [0, 3], col, w + 0.6)
			_ln(c, u, [0, -5], [-9, -13], col, w - 0.4)
			_ln(c, u, [0, -5], [9, -13], col, w - 0.4)
			_ln(c, u, [0, 3], [-7, 7], col, w)
			_ln(c, u, [-7, 7], [-4, 12], col, w)
			_ln(c, u, [0, 3], [7, 7], col, w)
			_ln(c, u, [7, 7], [4, 12], col, w)
			_ln(c, u, [-12, 16], [-5, 16], col, w - 1.2)
			_ln(c, u, [5, 16], [12, 16], col, w - 1.2)
		_:
			draw_circle(c + Vector2(3, -12) * u, 4.2 * u, col)
			_ln(c, u, [2, -7], [-1, 3], col, w + 0.6)
			_ln(c, u, [1, -5], [-8, -2], col, w - 0.4)
			_ln(c, u, [1, -5], [10, -1], col, w - 0.4)
			_ln(c, u, [-1, 3], [-10, 9], col, w)
			_ln(c, u, [-10, 9], [-13, 14], col, w)
			_ln(c, u, [-1, 3], [6, 8], col, w)
			_ln(c, u, [6, 8], [5, 15], col, w)


func _shield(c: Vector2, u: float, col: Color) -> void:
	_poly(c, u, [[-12, -13], [12, -13], [12, 1], [8, 9], [0, 15], [-8, 9], [-12, 1]], col)


func _glyph(c: Vector2, u: float, col: Color, mono: bool) -> void:
	var dk := col if mono else col.darkened(0.55)
	var lt := col if mono else col.lightened(0.3)
	var w := 2.8
	match kind:
		"bolsa":  # bolsa de couro com aba, fivela e alça
			draw_arc(c + Vector2(0, -4) * u, 12 * u, PI * 1.08, TAU * 0.96, 18, col, (w - 0.8) * u, true)
			_poly(c, u, [[-11, -5], [11, -5], [16, 9], [13, 15], [-13, 15], [-16, 9]], col)
			if not mono:
				_poly(c, u, [[-13.5, -6], [13.5, -6], [12, 2], [4, 6], [-4, 6], [-12, 2]], lt)
				draw_rect(Rect2(c + Vector2(-3, 2) * u, Vector2(6, 7) * u), dk)
				draw_rect(Rect2(c + Vector2(-1.3, 4) * u, Vector2(2.6, 3) * u), lt)
				_ln(c, u, [-9, 11], [-5, 11], dk, 1.4)
				_ln(c, u, [5, 11], [9, 11], dk, 1.4)
		"loja":  # barraca com toldo
			_poly(c, u, [[-13, -13], [13, -13], [16, -3], [-16, -3]], col)
			_ln(c, u, [-12, -3], [-12, 14], col, w)
			_ln(c, u, [12, -3], [12, 14], col, w)
			draw_rect(Rect2(c + Vector2(-14, 5) * u, Vector2(28, 5) * u), col)
			if not mono:
				for x in [-8.0, 0.0, 8.0]:
					_poly(c, u, [[x - 2, -13], [x + 2, -13], [x + 2.6, -3], [x - 2.6, -3]], dk)
				draw_circle(c + Vector2(0, 0.8) * u, 3.2 * u, lt)
		"oficio":  # bigorna e martelo
			draw_rect(Rect2(c + Vector2(-9, 0) * u, Vector2(20, 5.5) * u), col)
			_poly(c, u, [[-9, 0], [-17, 1.5], [-9, 5]], col)
			_poly(c, u, [[-4, 5.5], [6, 5.5], [4, 9], [9, 12], [9, 15], [-8, 15], [-8, 12], [-2, 9]], col)
			_ln(c, u, [-6, -4], [6, -14], lt, w)
			_ln(c, u, [2, -16], [10, -10], lt, w + 3.4)
		"classe":  # espada e estrela
			_ln(c, u, [-7, 9], [11, -13], col, w + 0.8)
			_ln(c, u, [-11, 1], [-1, 11], lt, w)
			_ln(c, u, [-9, 11], [-13, 15], col, w + 0.6)
			_poly(c, u, [[-9, -15], [-7, -10], [-2, -8], [-7, -6], [-9, -1], [-11, -6], [-16, -8], [-11, -10]], lt)
		"cla":  # brasão
			_shield(c, u, col)
			if not mono:
				_ln(c, u, [0, -10], [0, 11], dk, w)
				_ln(c, u, [-9, -3], [9, -3], dk, w)
		"acoes":
			_person(c, u, col, "run")
		"config":
			draw_circle(c, 9.5 * u, col)
			for i in 8:
				var d := Vector2.RIGHT.rotated(TAU * i / 8.0)
				draw_line(c + d * 8 * u, c + d * 14.5 * u, col, 5.0 * u, true)
			if not mono:
				draw_circle(c, 4.2 * u, dk)
		"tela":
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var k := c + Vector2(13 * sx, 12 * sy) * u
					draw_line(k, k - Vector2(8 * sx, 0) * u, col, (w + 0.6) * u, true)
					draw_line(k, k - Vector2(0, 8 * sy) * u, col, (w + 0.6) * u, true)
		"sair":  # porta e seta
			_poly(c, u, [[-13, -14], [1, -11], [1, 14], [-13, 15]], col)
			if not mono:
				draw_circle(c + Vector2(-2.5, 1) * u, 1.6 * u, dk)
			_ln(c, u, [4, 0], [15, 0], lt, w)
			_poly(c, u, [[11, -6], [17, 0], [11, 6]], lt)
		"atacar":  # espadas cruzadas
			_ln(c, u, [-12, 12], [11, -12], col, w + 0.4)
			_ln(c, u, [12, 12], [-11, -12], col, w + 0.4)
			_ln(c, u, [-13, 4], [-5, 12], lt, w - 0.4)
			_ln(c, u, [13, 4], [5, 12], lt, w - 0.4)
		"sentar":
			_person(c, u, col, "sit")
		"pular":
			_person(c, u, col, "jump")
		"dancar":  # notas musicais
			draw_circle(c + Vector2(-8, 10) * u, 4.6 * u, col)
			draw_circle(c + Vector2(8, 6) * u, 4.6 * u, col)
			_ln(c, u, [-4, 10], [-4, -11], col, w - 0.4)
			_ln(c, u, [12, 6], [12, -15], col, w - 0.4)
			_poly(c, u, [[-5.2, -12], [13.2, -16], [13.2, -10], [-5.2, -6]], col)
		"sorrir", "chorar":
			draw_circle(c, 14 * u, col)
			if not mono:
				draw_circle(c + Vector2(-5, -4) * u, 2.2 * u, dk)
				draw_circle(c + Vector2(5, -4) * u, 2.2 * u, dk)
				if kind == "sorrir":
					draw_arc(c + Vector2(0, 0) * u, 8 * u, 0.25, PI - 0.25, 12, dk, 2.2 * u, true)
				else:
					draw_arc(c + Vector2(0, 11) * u, 6 * u, PI + 0.35, TAU - 0.35, 12, dk, 2.2 * u, true)
					_poly(c, u, [[7, -1], [9.5, 5], [7, 7.5], [4.5, 5]], Color(0.45, 0.75, 1.0))
		"escalar":  # montanha e bandeira
			_poly(c, u, [[-16, 14], [-3, -8], [3, 0], [7, -4], [16, 14]], col)
			_ln(c, u, [-3, -8], [-3, -16], lt, w - 1.2)
			_poly(c, u, [[-3, -16], [5, -13.5], [-3, -11]], lt)
		"conversar":  # balão de fala
			_poly(c, u, [[-14, -12], [14, -12], [14, 5], [-2, 5], [-9, 13], [-8, 5], [-14, 5]], col)
			if not mono:
				for x in [-7.0, 0.0, 7.0]:
					draw_circle(c + Vector2(x, -3.5) * u, 1.9 * u, dk)
		"acenar":  # mão aberta
			draw_rect(Rect2(c + Vector2(-8, -2) * u, Vector2(15, 14) * u), col)
			for i in 4:
				_ln(c, u, [-6 + i * 4, 0], [-6.5 + i * 4.3, -13 + absf(i - 1.5) * 2.0], col, 3.2)
			_ln(c, u, [7, 4], [14, -3], col, 3.2)
		"escudo":
			_shield(c, u, col)
			if not mono:
				_poly(c, u, [[-7, -9], [7, -9], [7, 0], [0, 9], [-7, 0]], lt)
		"forca":  # seta para cima
			_poly(c, u, [[0, -15], [13, 0], [5, 0], [5, 14], [-5, 14], [-5, 0], [-13, 0]], col)
		"fraqueza":  # seta para baixo
			_poly(c, u, [[0, 15], [13, 0], [5, 0], [5, -14], [-5, -14], [-5, 0], [-13, 0]], col)
		"pressa":
			for x in [-10.0, 0.0]:
				_poly(c, u, [[x, -11], [x + 5, -11], [x + 14, 0], [x + 5, 11], [x, 11], [x + 9, 0]], col)
		"recarga":  # ampulheta
			_poly(c, u, [[-10, -14], [10, -14], [2, 0], [10, 14], [-10, 14], [-2, 0]], col)
			if not mono:
				_poly(c, u, [[-6, 12], [6, 12], [0, 4]], lt)
		"cura":
			draw_rect(Rect2(c + Vector2(-4.5, -14) * u, Vector2(9, 28) * u), col)
			draw_rect(Rect2(c + Vector2(-14, -4.5) * u, Vector2(28, 9) * u), col)
		"estrela":
			var p := []
			for i in 10:
				var r := 15.0 if i % 2 == 0 else 6.5
				var a := -PI / 2 + TAU * i / 10.0
				p.append([cos(a) * r, sin(a) * r])
			_poly(c, u, p, col)
		"golpe":  # corte de lâmina
			_poly(c, u, [[-15, 10], [-6, -6], [12, -15], [2, 0], [-4, 12]], col)
			if not mono:
				_ln(c, u, [-9, 8], [8, -11], lt, 1.6)
		"fogo":
			_poly(c, u, [[0, -16], [5, -8], [9, -11], [13, 2], [9, 12], [0, 16], [-9, 12], [-13, 3], [-7, -4], [-4, 1]], col)
			if not mono:
				_poly(c, u, [[0, -3], [5, 5], [3, 12], [0, 14], [-4, 11], [-5, 5]], lt)
		"gelo":
			for i in 3:
				var d := Vector2.RIGHT.rotated(PI * i / 3.0 + PI / 6.0)
				draw_line(c - d * 15 * u, c + d * 15 * u, col, w * u, true)
				for s in [-1.0, 1.0]:
					var q: Vector2 = c + d * 9 * u * s
					draw_line(q, q + d.rotated(0.8) * 5 * u * s, col, (w - 1.0) * u, true)
					draw_line(q, q + d.rotated(-0.8) * 5 * u * s, col, (w - 1.0) * u, true)
		"raio":
			_poly(c, u, [[4, -16], [-10, 2], [-1, 2], [-5, 16], [11, -4], [1, -4]], col)
		"agua":
			_poly(c, u, [[0, -16], [9, -1], [11, 6], [7, 13], [0, 15], [-7, 13], [-11, 6], [-9, -1]], col)
			if not mono:
				draw_arc(c + Vector2(0, 5) * u, 6 * u, 0.3, 1.5, 8, lt, 1.8 * u, true)
		"terra":
			_poly(c, u, [[-15, 13], [-10, -2], [-3, -10], [4, -4], [9, -8], [15, 13]], col)
			if not mono:
				_ln(c, u, [-3, -10], [0, 2], dk, 1.6)
				_ln(c, u, [0, 2], [-5, 9], dk, 1.6)
		"vento":
			draw_arc(c + Vector2(4, -6) * u, 6 * u, -PI * 0.5, PI * 0.9, 14, col, w * u, true)
			_ln(c, u, [-15, -1], [4, -1], col, w)
			draw_arc(c + Vector2(7, 9) * u, 5 * u, -PI * 0.5, PI * 0.9, 14, col, w * u, true)
			_ln(c, u, [-11, 5], [7, 5], col, w)
			_ln(c, u, [-15, 11], [-3, 11], col, w)
		"luz":
			draw_circle(c, 7 * u, col)
			for i in 8:
				var d := Vector2.RIGHT.rotated(TAU * i / 8.0)
				draw_line(c + d * 10 * u, c + d * 15.5 * u, col, w * u, true)
		"sombra":  # lua crescente
			draw_arc(c + Vector2(1, 0) * u, 11 * u, PI * 0.35, PI * 1.65, 20, col, 6.0 * u, true)
		"vazio":
			pass


# ícone e cor de uma habilidade a partir do tipo e do elemento
static func skill_look(s: Dictionary) -> Array:
	var ty := str(s.get("type", ""))
	var fx := str(s.get("fx", ""))
	var col: Color = ELEM.get(fx, Color(0.93, 0.79, 0.47))
	var k := "golpe"
	match ty:
		"heal":
			k = "cura"
			col = Color(0.5, 0.95, 0.6)
		"shield":
			k = "escudo"
		"buff":
			k = "forca"
		"debuff", "taunt":
			k = "fraqueza"
		_:
			k = {"fire": "fogo", "ice": "gelo", "water": "agua", "wind": "vento", "earth": "terra", "holy": "luz", "dark": "sombra", "lightning": "raio"}.get(fx, "golpe")
	return [k, col]
