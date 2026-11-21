extends SceneTree
# Protocolo do grupo (party) com três jogadores simulados ligados por um "canal" em memória:
# convite, aceite, lista, segundo membro, fala, expulsão, recusa, saída do líder (passa a liderança)
# e proteção contra lista falsa (quem não aceitou convite não entra em grupo).

class Barramento:
	var nos: Array = []
	func enviar(p: Dictionary) -> void:
		for n in nos:
			n.net.remote_grupo.emit(p.duplicate(true))


class NetFalsa:
	signal remote_grupo(p: Dictionary)
	var bus
	func rt_grupo(p: Dictionary) -> void:
		bus.enviar(p)


class UiFalsa:
	var falas: Array = []
	var convite := ""
	var lista: Array = []
	func chat_line(_q: String, m: String, k := "chat") -> void:
		falas.append([k, m])
	func say(_t: String) -> void:
		pass
	func mostrar_convite(n: String) -> void:
		convite = n
	func set_grupo(l: Array, _lider: bool) -> void:
		lista = l


class SocialFalso:
	var others := {}


class MainFalso:
	var me := {}
	var net := NetFalsa.new()
	var ui := UiFalsa.new()
	var social := SocialFalso.new()
	var playing := true
	func _online() -> bool:
		return true


var falhas := 0


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("FALHOU: ", msg)
		falhas += 1


func _init() -> void:
	var G = load("res://scripts/grupo.gd")
	var bus := Barramento.new()
	var j := {}
	for n in [["a", "Ana"], ["b", "Bruno"], ["c", "Caio"], ["d", "Dora"]]:
		var m := MainFalso.new()
		m.me = {"id": n[0], "name": n[1]}
		m.net.bus = bus
		var g = G.new()
		g.setup(m)
		bus.nos.append(m)
		j[n[0]] = {"m": m, "g": g}
	for k in j:
		for o in j:
			if o != k:
				j[k].m.social.others[o] = {"name": j[o].m.me.name, "lvl": 1}
	var A = j.a.g
	var B = j.b.g
	var C = j.c.g
	var D = j.d.g
	# lista falsa: D não aceitou nada e não pode ser posto num grupo
	j.c.m.net.rt_grupo({"de": "c", "nd": "Caio", "t": "lista", "gid": "x", "lider": "c", "m": [{"id": "c", "n": "Caio"}, {"id": "d", "n": "Dora"}]})
	ok(not D.em_grupo(), "lista sem convite aceito é ignorada")
	A.convidar("b")
	ok(j.b.m.ui.convite == "Ana", "B recebe o convite de A")
	B.aceitar()
	ok(A.em_grupo() and A.sou_lider(), "A vira líder ao primeiro aceite")
	ok(B.em_grupo() and B.lider == "a" and B.membros.size() == 2, "B entra com a lista do líder")
	ok(j.a.m.ui.lista.size() == 2 and j.b.m.ui.lista.size() == 2, "painel mostra 2 membros nos dois")
	A.convidar("c")
	C.recusar()
	ok(not C.em_grupo() and A.membros.size() == 2, "recusa não entra")
	A.convidar("c")
	C.aceitar()
	ok(A.membros.size() == 3 and B.membros.size() == 3 and C.membros.size() == 3, "terceiro membro chega para todos")
	B.convidar("d")
	ok(j.d.m.ui.convite == "", "só o líder convida")
	B.falar("oi grupo")
	var viu := false
	for f in j.c.m.ui.falas:
		if f[0] == "grupo" and f[1] == "oi grupo":
			viu = true
	ok(viu, "fala do grupo chega aos outros")
	ok(not j.d.m.ui.falas.any(func(f): return f[1] == "oi grupo"), "quem está fora não lê a fala do grupo")
	# B tenta expulsar C sem ser líder: mensagem forjada não vale
	j.b.m.net.rt_grupo({"de": "b", "nd": "Bruno", "t": "expulso", "para": "c", "gid": A.gid})
	ok(C.em_grupo(), "expulsão só vale vinda do líder")
	A.expulsar("c")
	ok(not C.em_grupo() and A.membros.size() == 2 and B.membros.size() == 2, "líder tira C do grupo")
	A.sair()
	ok(not A.em_grupo(), "A saiu")
	ok(not B.em_grupo(), "grupo de 1 se desfaz quando o líder sai")
	# liderança passa adiante com 3 membros
	A.convidar("b")
	B.aceitar()
	A.convidar("c")
	C.aceitar()
	A.sair()
	ok(B.em_grupo() and C.em_grupo() and B.lider == "b" and C.lider == "b" and B.membros.size() == 2, "líder sai e B assume")
	print("RESULTADO: ", "PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas)
	quit(0 if falhas == 0 else 1)
