extends Control
# Minimapa (canto superior direito) e mapa do mundo (tecla M).
# Imagem: data/mapa_mundo.png (gerada por ferramentas/gerar_mapa_mundo.py a partir do relevo).

const TAM_MINI := 190.0
const ALCANCE_MINI := 260.0   # metros mostrados de lado a lado no minimapa

var main: Node
var tex: Texture2D
var aberto := false
var zoom_mini := 1.0
var fonte: Font
var mundo := 3000.0
var cidades: Array = []
var castelos: Array = []
var vilas: Array = []
var marcos: Array = []
var _t := 0.0
# planta da cidade no minimapa: prédios (caixas de colisão) e peças redondas perto do jogador
var _planta: Array = []
var _planta_em := Vector2(INF, INF)


func setup(m: Node) -> void:
	main = m
	tex = load("res://data/mapa_mundo.png")
	fonte = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var w = main.world
	mundo = float(w.size)
	cidades = w.info.get("towns", [])
	marcos = w.info.get("landmarks", [])
	castelos = w.mapa.get("castles", [])
	vilas = w.mapa.get("villages", [])
	if "--mapa" in OS.get_cmdline_user_args():   # teste/fotos: abre o mapa grande
		aberto = true


func alternar() -> void:
	aberto = not aberto
	mouse_filter = Control.MOUSE_FILTER_STOP if aberto else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(dt: float) -> void:
	size = get_viewport_rect().size
	_t += dt
	if _t > 0.1 or aberto:   # minimapa a 10 quadros/s: leve
		_t = 0.0
		queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if aberto and ev is InputEventMouseButton and ev.pressed:
		accept_event()


func _jogador() -> Vector3:
	return main.player.position if main.player else Vector3(mundo * 0.5, 0, mundo * 0.5)


func _visivel() -> bool:
	return main.ui != null and main.ui.hud != null and main.ui.hud.visible and main.player != null


func _draw() -> void:
	if tex == null or not _visivel():
		return
	if main.interiores != null and not main.interiores.inside.is_empty():
		return   # dentro de prédio não há mapa do mundo
	_mini()
	if aberto:
		_grande()


func _px(p: Vector2, r: Rect2) -> Vector2:
	return r.position + p / mundo * r.size


func _seta(c: Vector2, ang: float, s: float, cor: Color) -> void:
	var f := Vector2(sin(ang), cos(ang))
	var l := Vector2(f.y, -f.x)
	draw_colored_polygon(PackedVector2Array([c + f * s, c - f * s * 0.6 + l * s * 0.7, c - f * s * 0.25, c - f * s * 0.6 - l * s * 0.7]), cor)


func _mini() -> void:
	var vp := get_viewport_rect().size
	var r := Rect2(Vector2(vp.x - TAM_MINI - 14, 14), Vector2(TAM_MINI, TAM_MINI))
	var p := _jogador()
	var alc := ALCANCE_MINI / zoom_mini
	var ts := Vector2(tex.get_width(), tex.get_height())
	var src := Rect2(Vector2(p.x - alc * 0.5, p.z - alc * 0.5) / mundo * ts, Vector2(alc, alc) / mundo * ts)
	draw_rect(r.grow(3), Color(0.08, 0.06, 0.04, 0.85))
	draw_texture_rect_region(tex, r, src)
	var esc := TAM_MINI / alc
	_desenhar_planta(r, p, alc, esc)
	for c in cidades:
		var q := r.get_center() + (Vector2(float(c.x), float(c.z)) - Vector2(p.x, p.z)) * esc
		if r.grow(-6).has_point(q):
			draw_circle(q, 5, Color(0.95, 0.82, 0.45))
			draw_string(fonte, q + Vector2(7, 4), str(c.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	_seta(r.get_center(), main.facing, 7, Color(1, 0.25, 0.2))
	draw_rect(r.grow(3), Color(0.75, 0.6, 0.35), false, 2.0)
	draw_string(fonte, Vector2(r.position.x, r.end.y + 16), "M — mapa   %d, %d" % [int(p.x), int(p.z)], HORIZONTAL_ALIGNMENT_LEFT, TAM_MINI, 12, Color(1, 1, 1, 0.9))


# a imagem do mundo tem ~3 m por pixel: numa cidade o minimapa virava um quadrado verde.
# Desenha por cima os prédios e obstáculos reais (os mesmos da colisão), refeitos a cada 8 m andados.
func _desenhar_planta(r: Rect2, p: Vector3, alc: float, esc: float) -> void:
	var w = main.world
	if w == null or not ("boxes" in w):
		return
	var pv := Vector2(p.x, p.z)
	if pv.distance_to(_planta_em) > 8.0:
		_planta_em = pv
		_planta.clear()
		var meio := alc * 0.75
		var vistos := {}
		for kz in range(floori((p.z - meio) / 8.0), floori((p.z + meio) / 8.0) + 1):
			for kx in range(floori((p.x - meio) / 8.0), floori((p.x + meio) / 8.0) + 1):
				var k := Vector2i(kx, kz)
				for e in w.boxes.get(k, []):
					if not vistos.has(e):
						vistos[e] = true
						_planta.append(e)
				for b in w.blockers.get(k, []):
					if float(b.z) >= 1.2:   # chafariz, fogueira, torre (troncos e postes ficam de fora)
						_planta.append(b)
	var centro := r.get_center()
	var dentro := r.grow(-2)
	var cor := Color(0.62, 0.55, 0.45, 0.95)
	var borda := Color(0.2, 0.15, 0.1, 0.9)
	for e in _planta:
		if e is Vector3:
			var q := centro + (Vector2(e.x, e.y) - pv) * esc
			if dentro.has_point(q):
				draw_circle(q, maxf(1.5, e.z * esc), Color(0.55, 0.62, 0.7, 0.9))
			continue
		var o := centro + (Vector2(e[0], e[1]) - pv) * esc
		if not dentro.grow(20).has_point(o):
			continue
		var ax := Vector2(e[2], -e[3]) * float(e[4]) * esc
		var az := Vector2(e[3], e[2]) * float(e[5]) * esc
		var pts := PackedVector2Array([o - ax - az, o + ax - az, o + ax + az, o - ax + az])
		var fora := false
		for i in 4:
			if not dentro.has_point(pts[i]):
				fora = true
		if fora:
			continue   # sem recorte: peça que passa da borda fica de fora (evita desenhar fora do quadro)
		draw_colored_polygon(pts, cor)
		pts.append(pts[0])
		draw_polyline(pts, borda, 1.0)


func _grande() -> void:
	var vp := get_viewport_rect().size
	var lado := minf(vp.x, vp.y) - 90
	var r := Rect2((vp - Vector2(lado, lado)) * 0.5, Vector2(lado, lado))
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55))
	draw_rect(r.grow(6), Color(0.12, 0.09, 0.05))
	draw_texture_rect(tex, r, false)
	for v in vilas:
		draw_circle(_px(Vector2(float(v.x), float(v.z)), r), 3, Color(0.85, 0.75, 0.55))
	for c in castelos:
		var q := _px(Vector2(float(c.x), float(c.z)), r)
		draw_rect(Rect2(q - Vector2(5, 5), Vector2(10, 10)), Color(0.55, 0.15, 0.12))
		draw_string(fonte, q + Vector2(7, 4), str(c.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.85, 0.8))
	for m in marcos:
		if str(m.get("id", "")).begins_with("castelo"):
			continue
		var q := _px(Vector2(float(m.x), float(m.z)), r)
		draw_circle(q, 3.5, Color(0.6, 0.85, 1.0))
	for c in cidades:
		var q := _px(Vector2(float(c.x), float(c.z)), r)
		draw_circle(q, 7, Color(0.1, 0.07, 0.03))
		draw_circle(q, 5.5, Color(0.98, 0.82, 0.4))
		var nome := "%s  (%d–%d)" % [str(c.name), int(c.get("min", 1)), int(c.get("max", 80))]
		draw_string(fonte, q + Vector2(9, 5) + Vector2(1, 1), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.8))
		draw_string(fonte, q + Vector2(9, 5), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	var p := _jogador()
	_seta(_px(Vector2(p.x, p.z), r), main.facing, 10, Color(1, 0.2, 0.15))
	draw_rect(r.grow(6), Color(0.8, 0.65, 0.35), false, 3.0)
	draw_string(fonte, Vector2(r.position.x, r.position.y - 14), "Mapa de Valtheria — M ou Esc fecha", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
