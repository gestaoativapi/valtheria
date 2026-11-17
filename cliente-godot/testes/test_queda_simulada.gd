extends SceneTree
# D39: confere a queda simulada (net.gd). No executável oficial ela não funciona; no de teste,
# bloqueia os envios pelo tempo pedido e depois libera.
# Uso: godot --headless --path . --script testes/test_queda_simulada.gd
func _init() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/net.gd")
	var falhas := 0
	var Net = load("res://scripts/net.gd")
	var n = Net.new()
	if n.simular_queda(1.0): falhas += 1; print("FALHA: queda funcionou fora do ambiente de teste")
	else: print("ok: oficial recusa a queda simulada")
	var s2 := GDScript.new()
	s2.source_code = src.replace('const AMBIENTE := "producao"', 'const AMBIENTE := "testes"').replace('if AMBIENTE == "testes" and (URL.contains', 'if false and (URL.contains')
	if s2.reload() != OK: print("FALHA: script de teste não compilou"); quit(1); return
	var t = s2.new()
	if not t.simular_queda(0.3): falhas += 1; print("FALHA: queda não ativou no ambiente de teste")
	if not t.em_queda(): falhas += 1; print("FALHA: em_queda() falso logo após a queda")
	else: print("ok: rede caída durante a queda")
	OS.delay_msec(400)
	if t.em_queda(): falhas += 1; print("FALHA: queda não terminou")
	else: print("ok: rede volta depois do tempo")
	n.free(); t.free()
	print("RESULTADO: " + ("PASSOU" if falhas == 0 else "FALHOU"))
	quit(0 if falhas == 0 else 1)
