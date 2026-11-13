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
var rim_w := 1
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
		_box(face, base, rim if not hover else Color(0.95, 0.8, 0.45), rim_w, rad)
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
		# ---------- itens ----------
		"espada", "adaga":
			var L := 1.0 if kind == "espada" else 0.62
			_poly(c, u, [[-6, 6], [-4, 4], [12 * L - 2, -12 * L], [13 * L, -13 * L], [12 * L, -12 * L + 2], [-4, 8]], col)
			if not mono:
				_ln(c, u, [-4, 6], [12 * L - 1, -12 * L + 1], lt, 1.0)
			_ln(c, u, [-11, 1], [-1, 11], dk if not mono else col, 3.2)
			_ln(c, u, [-6, 6], [-12, 12], dk if not mono else col, 3.0)
			draw_circle(c + Vector2(-13, 13) * u, 2.4 * u, col)
		"espadao":
			_poly(c, u, [[-7, 4], [-4, 1], [12, -15], [15, -15], [15, -12], [-1, 4], [-4, 7]], col)
			if not mono:
				_ln(c, u, [-4, 4], [14, -14], lt, 1.2)
			_ln(c, u, [-12, -1], [1, 12], dk if not mono else col, 3.6)
			_ln(c, u, [-5, 6], [-13, 14], dk if not mono else col, 3.4)
		"arco":
			draw_arc(c + Vector2(-9, 0) * u, 16 * u, -1.15, 1.15, 20, col, 3.4 * u, true)
			_ln(c, u, [-2.5, -14.6], [-2.5, 14.6], lt, 1.0)
			_ln(c, u, [-14, 0], [12, 0], lt, 1.6)
			_poly(c, u, [[12, -3], [17, 0], [12, 3]], lt)
		"cajado":
			_ln(c, u, [-9, 15], [6, -6], dk if not mono else col, 3.2)
			draw_circle(c + Vector2(8, -9) * u, 6 * u, col)
			if not mono:
				draw_circle(c + Vector2(6.5, -10.5) * u, 2.2 * u, Color(1, 1, 1, 0.75))
		"machado":
			_ln(c, u, [-10, 15], [7, -12], dk if not mono else col, 3.2)
			_poly(c, u, [[3, -12], [9, -16], [16, -9], [14, 0], [6, -4]], col)
			if not mono:
				_ln(c, u, [9, -15], [15, -1], lt, 1.4)
		"martelo":
			_ln(c, u, [-10, 15], [4, -6], dk if not mono else col, 3.2)
			_poly(c, u, [[-3, -12], [8, -18], [15, -6], [4, 0]], col)
			if not mono:
				_poly(c, u, [[-3, -12], [8, -18], [9, -16], [-2, -10]], lt)
		"lanca":
			_ln(c, u, [-14, 15], [8, -7], dk if not mono else col, 2.6)
			_poly(c, u, [[6, -5], [16, -16], [9, -4]], col)
			_poly(c, u, [[6, -5], [16, -16], [5, -9]], lt)
		"garras":
			for i in 3:
				var x := -8.0 + i * 8.0
				draw_arc(c + Vector2(x - 6, -2) * u, 12 * u, -0.9, 0.55, 12, col, 2.8 * u, true)
			draw_rect(Rect2(c + Vector2(-13, 8) * u, Vector2(24, 6) * u), dk if not mono else col)
		"punhos":
			_poly(c, u, [[-12, -8], [10, -8], [13, -3], [13, 8], [9, 12], [-10, 12], [-13, 7]], col)
			if not mono:
				for i in 3:
					_ln(c, u, [-5 + i * 6, -8], [-5 + i * 6, -1], dk, 1.4)
		"elmo":
			_poly(c, u, [[-12, 12], [-13, -1], [-9, -10], [0, -14], [9, -10], [13, -1], [12, 12], [5, 12], [5, 4], [-5, 4], [-5, 12]], col)
			if not mono:
				draw_rect(Rect2(c + Vector2(-9, -3) * u, Vector2(18, 3) * u), dk)
				_ln(c, u, [0, -14], [0, -4], lt, 1.4)
		"peitoral":
			_poly(c, u, [[-14, -12], [-6, -14], [0, -10], [6, -14], [14, -12], [12, 2], [9, 14], [-9, 14], [-12, 2]], col)
			if not mono:
				_ln(c, u, [0, -10], [0, 13], dk, 1.4)
				_ln(c, u, [-10, 2], [10, 2], dk, 1.4)
		"luvas":
			_poly(c, u, [[-8, 15], [-9, 2], [-13, -3], [-10, -6], [-6, -2], [-6, -13], [-2, -14], [-1, -5], [1, -15], [5, -14], [5, -5], [8, -13], [11, -11], [10, 1], [8, 15]], col)
			if not mono:
				draw_rect(Rect2(c + Vector2(-8, 9) * u, Vector2(16, 3) * u), dk)
		"botas":
			_poly(c, u, [[-8, -14], [4, -14], [4, 3], [14, 7], [15, 14], [-9, 14]], col)
			if not mono:
				draw_rect(Rect2(c + Vector2(-8, -9) * u, Vector2(12, 3) * u), dk)
				draw_rect(Rect2(c + Vector2(-9, 11) * u, Vector2(24, 3) * u), dk)
		"egide":
			_shield(c, u, col)
			if not mono:
				draw_circle(c + Vector2(0, -1) * u, 5.5 * u, lt)
				draw_circle(c + Vector2(0, -1) * u, 2.5 * u, dk)
		"pocao":
			draw_circle(c + Vector2(0, 5) * u, 10 * u, Color(0.85, 0.9, 0.95, 0.35) if not mono else col)
			draw_rect(Rect2(c + Vector2(-3.5, -12) * u, Vector2(7, 9) * u), Color(0.85, 0.9, 0.95, 0.35) if not mono else col)
			if not mono:
				draw_circle(c + Vector2(0, 6) * u, 8 * u, col)
				draw_rect(Rect2(c + Vector2(-4, -16) * u, Vector2(8, 5) * u), Color(0.55, 0.38, 0.2))
				draw_circle(c + Vector2(-3, 3) * u, 2 * u, Color(1, 1, 1, 0.7))
		"pergaminho":
			_poly(c, u, [[-11, -11], [11, -11], [11, 11], [-11, 11]], col)
			draw_circle(c + Vector2(-11, -11) * u, 3.4 * u, dk if not mono else col)
			draw_circle(c + Vector2(11, 11) * u, 3.4 * u, dk if not mono else col)
			if not mono:
				for y in [-5.0, 0.0, 5.0]:
					_ln(c, u, [-6, y], [6, y], dk, 1.2)
		"encantar":
			_poly(c, u, [[0, -16], [3.5, -3.5], [16, 0], [3.5, 3.5], [0, 16], [-3.5, 3.5], [-16, 0], [-3.5, -3.5]], col)
			if not mono:
				draw_circle(c, 3 * u, Color(1, 1, 1, 0.85))
		"gema":
			_poly(c, u, [[-12, -5], [-6, -12], [6, -12], [12, -5], [0, 14]], col)
			if not mono:
				_poly(c, u, [[-6, -12], [6, -12], [3, -5], [-3, -5]], lt)
				_ln(c, u, [-12, -5], [12, -5], dk, 1.0)
				_ln(c, u, [-3, -5], [0, 14], dk, 1.0)
				_ln(c, u, [3, -5], [0, 14], dk, 1.0)
		"minerio":
			_poly(c, u, [[-14, 8], [-10, -6], [-2, -12], [9, -9], [14, 2], [8, 13], [-6, 13]], col)
			if not mono:
				for q in [[-5, -3], [4, 2], [-2, 7], [6, -6]]:
					draw_circle(c + Vector2(q[0], q[1]) * u, 2 * u, lt)
		"madeira":
			_poly(c, u, [[-14, 2], [6, -12], [12, -4], [-8, 10]], col)
			draw_circle(c + Vector2(9, -8) * u, 5.4 * u, lt)
			if not mono:
				draw_arc(c + Vector2(9, -8) * u, 3 * u, 0, TAU, 12, dk, 1.0 * u, true)
		"tabua":
			for i in 3:
				var y := -11.0 + i * 8.0
				draw_rect(Rect2(c + Vector2(-14, y) * u, Vector2(28, 6) * u), col if i != 1 else lt)
				if not mono:
					_ln(c, u, [-8, y + 3], [4, y + 3], dk, 0.8)
		"fibra":
			for i in 4:
				var x := -9.0 + i * 6.0
				_ln(c, u, [x, 14], [x + 4, -14], col, 2.4)
			draw_rect(Rect2(c + Vector2(-12, -2) * u, Vector2(24, 4) * u), dk if not mono else col)
		"tecido":
			_poly(c, u, [[-14, -10], [10, -14], [14, 10], [-10, 14]], col)
			if not mono:
				_poly(c, u, [[-14, -10], [10, -14], [2, 0]], lt)
		"pele":
			_poly(c, u, [[-6, -14], [6, -14], [9, -8], [15, -9], [12, 0], [15, 10], [8, 9], [4, 15], [-4, 15], [-8, 9], [-15, 10], [-12, 0], [-15, -9], [-9, -8]], col)
		"barra":
			_poly(c, u, [[-15, 8], [-9, -6], [11, -6], [15, 8]], col)
			if not mono:
				_poly(c, u, [[-9, -6], [11, -6], [9, -2], [-7, -2]], lt)
		"trofeu":  # presa
			_poly(c, u, [[-9, -13], [9, -13], [6, -4], [0, 15], [-6, -4]], col)
			if not mono:
				_ln(c, u, [-3, -10], [0, 8], lt, 1.4)
		"kit":  # picareta
			_ln(c, u, [-11, 14], [5, -4], dk if not mono else col, 3.2)
			draw_arc(c + Vector2(4, 6) * u, 16 * u, -2.6, -0.55, 18, col, 3.6 * u, true)
		"pata":
			draw_circle(c + Vector2(0, 6) * u, 7 * u, col)
			for q in [[-10, -3], [-4, -10], [4, -10], [10, -3]]:
				draw_circle(c + Vector2(q[0], q[1]) * u, 3.4 * u, col)
		"ferradura":
			draw_arc(c + Vector2(0, -1) * u, 11 * u, PI * 0.82, PI * 2.18, 22, col, 5.0 * u, true)
			if not mono:
				for a in [0.95, 1.3, 1.7, 2.05]:
					var d := Vector2.RIGHT.rotated(PI * a + PI * 0.0)
					draw_circle(c + Vector2(0, -1) * u - d * 11 * u, 1.0 * u, dk)
		"asas":
			for sx in [-1.0, 1.0]:
				_poly(c, u, [[sx * 2, -2], [sx * 15, -14], [sx * 14, -4], [sx * 16, 2], [sx * 12, 6], [sx * 13, 11], [sx * 3, 6]], col)
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


const METAL := Color(0.8, 0.83, 0.88)
const WOOD := Color(0.72, 0.52, 0.32)
const ARMA := {"espada": "espada", "adaga": "adaga", "punhal": "adaga", "espadao": "espadao", "arco": "arco", "cajado": "cajado", "cetro": "cajado",
	"machado": "machado", "martelo": "martelo", "lanca": "lanca", "garras": "garras", "punhos": "punhos", "duplas": "atacar"}
const SLOT := {"elmo": "elmo", "armadura": "peitoral", "luvas": "luvas", "botas": "botas", "escudo": "escudo", "arma": "espada"}


# ícone e cor de um item (arma, armadura, poção, material...)
static func item_look(id: String, it: Dictionary) -> Array:
	var ty := str(it.get("type", ""))
	var k := str(it.get("kind", ""))
	var nm := str(it.get("name", "")).to_lower()
	match ty:
		"weapon":
			return [ARMA.get(k, "espada"), WOOD if k in ["arco", "cajado", "cetro"] else METAL]
		"armor":
			var sl := str(it.get("slot", ""))
			if sl == "escudo":
				return ["egide" if k == "egide" else "escudo", METAL]
			var col := METAL if k == "pesada" else (Color(0.62, 0.46, 0.3) if k == "leve" else Color(0.45, 0.5, 0.8))
			return [SLOT.get(sl, "peitoral"), col]
		"potion":
			return ["pocao", Color(0.35, 0.55, 1.0) if "mana" in nm else Color(0.95, 0.25, 0.25)]
		"scroll":
			return ["pergaminho", Color(0.92, 0.85, 0.66)]
		"enchant":
			return ["encantar", Color(0.75, 0.6, 1.0) if "arma" in id else Color(0.55, 0.85, 1.0)]
		"special":
			return ["gema", Color(0.5, 0.75, 1.0)] if "gema" in id else ["estrela", Color(1.0, 0.92, 0.55)]
		"tool":
			return ["kit", METAL]
		"pet":
			return ["pata", Color(0.95, 0.75, 0.5)]
		"mount":
			return ["ferradura", METAL]
		"wings":
			return ["asas", Color(0.85, 0.9, 1.0)]
		"trophy":
			return ["trofeu", Color(0.93, 0.88, 0.75)]
		"raw", "refined":
			for pair in [["madeira", "madeira", WOOD], ["minerio", "minerio", Color(0.6, 0.58, 0.55)], ["fibra", "fibra", Color(0.8, 0.75, 0.5)], ["pele", "pele", Color(0.7, 0.5, 0.35)],
					["tabua", "tabua", WOOD], ["barra", "barra", METAL], ["tecido", "tecido", Color(0.6, 0.7, 0.9)], ["couro", "pele", Color(0.55, 0.36, 0.22)]]:
				if id.begins_with(pair[0]):
					return [pair[1], pair[2]]
	return ["estrela", Color(0.9, 0.85, 0.7)]
