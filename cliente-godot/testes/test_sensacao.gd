extends SceneTree
# Sensação de golpe (skill game-feel): o tremor soma trauma, volta a zero em até 1/decai segundos,
# devolve a câmera ao lugar (sem apagar o h_offset próprio) e o hitstop sempre devolve o tempo a 1.
# godot --headless --path . -s testes/test_sensacao.gd   (sai com 1 se falhar)

func _initialize() -> void:
	var falhas := 0
	var M = load("res://scripts/main.gd")
	var m = M.new()
	var cam := Camera3D.new()
	cam.h_offset = 5.0
	m.cam = cam
	m.tremer(0.04)
	m.tremer(0.04)
	if absf(m.tremor - 0.64) > 0.001:
		print("FALHA: dois golpes deviam somar trauma 0,64, deu ", m.tremor); falhas += 1
	var maior := 0.0
	var t := 0.0
	while t < 1.0 / m.TREMOR_DECAI + 0.05:
		m._tremor_passo(1.0 / 60.0)
		maior = maxf(maior, absf(cam.v_offset))
		t += 1.0 / 60.0
	if m.tremor != 0.0: print("FALHA: trauma não zerou"); falhas += 1
	if absf(cam.h_offset - 5.0) > 1e-5 or absf(cam.v_offset) > 1e-5:
		print("FALHA: câmera não voltou: h=%f v=%f" % [cam.h_offset, cam.v_offset]); falhas += 1
	if maior < 0.05: print("FALHA: tremor fraco demais (%f)" % maior); falhas += 1
	# hitstop durante hitstop: o tempo tem de voltar a 1
	Engine.time_scale = 0.06
	var tt := create_timer(0.06, true, false, true)
	await tt.timeout
	Engine.time_scale = 1.0
	cam.free()
	m.free()
	print("sensação: %s (pico do tremor %.3f m)" % ["ok" if falhas == 0 else "FALHOU", maior])
	quit(1 if falhas else 0)
