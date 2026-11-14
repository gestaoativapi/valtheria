extends SceneTree
# Teste da reconexão do tempo real (net.gd): simula uma queda e confere as tentativas e a espera crescente.
# Uso: godot --headless --path . --script testes/test_reconexao.gd
func _init() -> void:
	var Net = load("res://scripts/net.gd")
	var n = Net.new()
	n.token = "teste"
	n.ws_me = {"id": "x", "name": "Teste"}
	n.ws_want = true
	n.ws = null
	n.ws_retry = 0.0
	n.ws_backoff = 2.0
	var tentativas: Array = []
	var t := 0.0
	var dt := 0.25
	while t < 70.0:
		var antes = n.ws
		n._process(dt)
		if antes == null and n.ws != null:
			tentativas.append(snappedf(t, 0.25))
			n.ws = null  # a conexão "cai" de novo (sem rede no teste)
			n.ws_joined = false
		t += dt
	var esperas: Array = []
	for i in range(1, tentativas.size()):
		esperas.append(snappedf(tentativas[i] - tentativas[i - 1], 0.25))
	print("tentativas em (s): ", tentativas)
	print("esperas entre tentativas (s): ", esperas)
	var ok: bool = tentativas.size() >= 4 and esperas.size() >= 3 and esperas[0] <= 2.5 and esperas[1] >= 3.5 and esperas.back() <= 30.25
	# sair do jogo (rt_leave) desliga a reconexão
	n.rt_leave()
	var antes2 = n.ws
	for i in 200:
		n._process(dt)
	var parou: bool = n.ws == null
	print("depois de sair, não reconecta: ", parou)
	print("RESULTADO: ", "PASSOU" if ok and parou else "FALHOU")
	n.free()
	quit(0 if ok and parou else 1)
