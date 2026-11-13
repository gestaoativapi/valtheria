extends Button
# Botão com ícone desenhado em vetor (sem arquivo de imagem). O nome aparece ao passar o mouse.

var kind := ""
var tint := Color(0.92, 0.78, 0.46)


func _draw() -> void:
	var c := size * 0.5
	var u := minf(size.x, size.y) / 48.0
	var col := tint if not disabled else Color(0.45, 0.45, 0.48)
	var w := 2.6 * u
	match kind:
		"bolsa":
			draw_arc(c + Vector2(0, 4) * u, 13 * u, 0.0, TAU, 28, col, w, true)
			draw_line(c + Vector2(-7, -9) * u, c + Vector2(7, -9) * u, col, w + u, true)
			draw_arc(c + Vector2(0, -12) * u, 5 * u, PI, TAU, 12, col, w, true)
		"loja":
			draw_arc(c, 14 * u, 0.0, TAU, 30, col, w, true)
			draw_arc(c, 9 * u, 0.0, TAU, 24, col, w * 0.7, true)
			draw_line(c + Vector2(0, -5) * u, c + Vector2(0, 5) * u, col, w, true)
		"oficio":
			draw_line(c + Vector2(-12, 13) * u, c + Vector2(6, -5) * u, col, w + u, true)
			draw_rect(Rect2(c + Vector2(-2, -15) * u, Vector2(17, 9) * u), col, true)
			draw_line(c + Vector2(-15, 16) * u, c + Vector2(15, 16) * u, col, w, true)
		"classe":
			draw_line(c + Vector2(-11, 13) * u, c + Vector2(11, -13) * u, col, w + u, true)
			draw_line(c + Vector2(-12, 2) * u, c + Vector2(-1, 13) * u, col, w, true)
			draw_circle(c + Vector2(-13, 15) * u, 2.6 * u, col)
		"cla":
			var p := PackedVector2Array([c + Vector2(-12, -13) * u, c + Vector2(12, -13) * u, c + Vector2(12, 2) * u, c + Vector2(0, 15) * u, c + Vector2(-12, 2) * u, c + Vector2(-12, -13) * u])
			draw_polyline(p, col, w, true)
			draw_line(c + Vector2(0, -8) * u, c + Vector2(0, 8) * u, col, w * 0.8, true)
			draw_line(c + Vector2(-7, -2) * u, c + Vector2(7, -2) * u, col, w * 0.8, true)
		"config":
			draw_arc(c, 8 * u, 0.0, TAU, 24, col, w, true)
			for i in 8:
				var d := Vector2.RIGHT.rotated(TAU * i / 8.0)
				draw_line(c + d * 10 * u, c + d * 15 * u, col, w + u, true)
		"tela":
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var k := c + Vector2(13 * sx, 13 * sy) * u
					draw_line(k, k - Vector2(8 * sx, 0) * u, col, w, true)
					draw_line(k, k - Vector2(0, 8 * sy) * u, col, w, true)
		"sair":
			draw_polyline(PackedVector2Array([c + Vector2(2, -14) * u, c + Vector2(-12, -14) * u, c + Vector2(-12, 14) * u, c + Vector2(2, 14) * u]), col, w, true)
			draw_line(c + Vector2(-3, 0) * u, c + Vector2(14, 0) * u, col, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(8, -6) * u, c + Vector2(14, 0) * u, c + Vector2(8, 6) * u]), col, w, true)
