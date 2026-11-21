extends Node
# Grupo (party) de até 9 jogadores.
# Combinado pelo canal de tempo real "mundo" (evento "g"): convite, aceite, lista de membros, estado
# (vida, mana, CP, nível, posição) e fala do grupo. Nada é gravado no servidor.
# Quem manda na lista é o líder: mudanças de membros só valem quando vêm dele.
# Limite conhecido: o canal não confirma quem enviou; divisão de experiência e de itens
# precisa ser feita no servidor (fase própria, no Supabase de testes).

const MAX := 9
const ESPERA_CONVITE := 20.0  # segundos para aceitar
const SUMIDO := 120.0  # sem notícias por esse tempo, o líder tira o membro

var main  # main.gd (sem tipo fixo para o teste com objetos simulados)
var gid := ""  # "" = sem grupo
var lider := ""
var membros := {}  # id -> {"name", "lvl", "cls", "hp", "mp", "cp", "x", "z", "seen"}
var ordem: Array = []  # ordem de entrada (o líder primeiro)
var convite := {}  # convite recebido: {"de", "nome", "gid", "ate"}
var enviados := {}  # id -> {"gid", "ate"}: convites que eu mandei
var aceito := {}  # convite que eu aceitei: {"gid", "ate"} — só essa lista me coloca num grupo
var _estado_t := 0.0
var _tag_sig := ""
var teste := false  # --grupo-teste: membros simulados, só para fotos e testes


func setup(m) -> void:
	main = m
	main.net.remote_grupo.connect(_rx)


func meu_id() -> String:
	return str(main.me.get("id", ""))


func em_grupo() -> bool:
	return gid != ""


func sou_lider() -> bool:
	return em_grupo() and lider == meu_id()


func _agora() -> float:
	return Time.get_ticks_msec() * 0.001


func _tx(p: Dictionary) -> void:
	p.de = meu_id()
	p.nd = str(main.me.get("name", ""))
	main.net.rt_grupo(p)


func _sistema(t: String) -> void:
	main.ui.chat_line("", t, "sistema")


# ---------- ações do jogador ----------
func convidar(id: String) -> void:
	if not main._online() and not teste:
		main.ui.say("Entre com uma conta para formar grupo")
		return
	var o: Dictionary = main.social.others.get(id, {})
	var nome := str(o.get("name", "?"))
	if id == "" or id == meu_id():
		return
	if em_grupo() and not sou_lider():
		main.ui.say("Só o líder do grupo pode convidar")
		return
	if membros.has(id):
		main.ui.say("%s já está no grupo" % nome)
		return
	if membros.size() >= MAX:
		main.ui.say("O grupo está cheio (%d)" % MAX)
		return
	var g := gid if em_grupo() else "%s-%d" % [meu_id(), Time.get_ticks_msec()]
	enviados[id] = {"gid": g, "ate": _agora() + ESPERA_CONVITE}
	_tx({"t": "convite", "para": id, "gid": g})
	_sistema("Convite de grupo enviado a %s." % nome)


func convidar_nome(nome: String) -> void:
	nome = nome.strip_edges().to_lower()
	for id in main.social.others:
		if str(main.social.others[id].name).to_lower() == nome:
			convidar(str(id))
			return
	main.ui.say("Jogador não encontrado por perto")


func aceitar() -> void:
	if convite.is_empty():
		return
	aceito = {"gid": convite.gid, "ate": _agora() + ESPERA_CONVITE}
	var c := convite
	convite = {}
	main.ui.mostrar_convite("")
	_tx({"t": "aceitar", "para": c.de, "gid": c.gid})
	if not em_grupo():
		_sistema("Você aceitou o convite de %s." % str(c.nome))


func recusar() -> void:
	if convite.is_empty():
		return
	_tx({"t": "recusar", "para": convite.de})
	convite = {}
	main.ui.mostrar_convite("")


func sair() -> void:
	if not em_grupo():
		return
	if sou_lider():
		# passa a liderança para o próximo da fila
		ordem.erase(meu_id())
		membros.erase(meu_id())
		if ordem.size() >= 2:
			lider = str(ordem[0])
			_enviar_lista()
		else:
			_tx({"t": "desfazer", "gid": gid})
	else:
		_tx({"t": "sair", "gid": gid})
	_sistema("Você saiu do grupo.")
	_limpar()


func expulsar(id: String) -> void:
	if not sou_lider() or id == meu_id() or not membros.has(id):
		return
	_sistema("%s foi retirado do grupo." % str(membros[id].name))
	membros.erase(id)
	ordem.erase(id)
	_tx({"t": "expulso", "para": id, "gid": gid})
	_depois_de_mudar()


func falar(msg: String) -> void:
	msg = msg.strip_edges().left(160)
	if msg == "":
		return
	if not em_grupo():
		main.ui.say("Você não está em um grupo. Selecione um jogador e use Convidar ao grupo.")
		return
	_tx({"t": "fala", "gid": gid, "msg": msg})
	main.ui.chat_line(str(main.me.get("name", "Você")), msg, "grupo")


# ---------- rede ----------
func _rx(p: Dictionary) -> void:
	var de := str(p.get("de", ""))
	if de == "" or de == meu_id():
		return
	var t := str(p.get("t", ""))
	var para := str(p.get("para", ""))
	var nd := str(p.get("nd", "?")).left(24)
	if para != "" and para != meu_id():
		return
	match t:
		"convite":
			if em_grupo():
				_tx({"t": "recusar", "para": de, "ocupado": true})
				return
			convite = {"de": de, "nome": nd, "gid": str(p.get("gid", "")), "ate": _agora() + ESPERA_CONVITE}
			main.ui.mostrar_convite(nd)
			_sistema("%s convidou você para um grupo." % nd)
		"recusar":
			if enviados.has(de):
				enviados.erase(de)
				_sistema("%s %s." % [nd, "já está em outro grupo" if p.get("ocupado", false) else "recusou o convite"])
		"aceitar":
			if not enviados.has(de) or float(enviados[de].ate) < _agora():
				return
			if em_grupo() and not sou_lider():
				return
			if membros.size() >= MAX:
				_tx({"t": "expulso", "para": de, "gid": str(enviados[de].gid)})
				return
			if not em_grupo():
				gid = str(enviados[de].gid)
				lider = meu_id()
				_entrar(meu_id(), str(main.me.get("name", "")))
			enviados.erase(de)
			_entrar(de, nd)
			_sistema("%s entrou no grupo." % nd)
			_depois_de_mudar()
		"lista":
			# só vale vindo do líder; quem aceitou um convite também aceita a primeira lista
			var g := str(p.get("gid", ""))
			var lista: Array = p.get("m") if p.get("m") is Array else []
			var novo_lider := str(p.get("lider", ""))
			var ids: Array = []
			for e in lista:
				if e is Dictionary:
					ids.append(str(e.get("id", "")))
			if not ids.has(meu_id()):
				if g == gid:
					_sistema("Você não faz mais parte do grupo.")
					_limpar()
				return
			if not em_grupo() and (aceito.is_empty() or str(aceito.gid) != g or float(aceito.ate) < _agora()):
				return
			if em_grupo() and g != gid:
				return
			if em_grupo() and de != lider:
				return
			var era := gid
			aceito = {}
			gid = g
			lider = novo_lider
			var antes := membros.duplicate()
			membros.clear()
			ordem.clear()
			for e in lista:
				var id := str(e.get("id", ""))
				var m: Dictionary = antes.get(id, {"lvl": 1, "cls": "", "hp": 100.0, "mp": 100.0, "cp": 100.0, "x": 0.0, "z": 0.0, "seen": _agora()})
				m.name = str(e.get("n", "?")).left(24)
				membros[id] = m
				ordem.append(id)
			if era == "":
				_sistema("Você entrou no grupo de %s." % str(membros.get(lider, {}).get("name", nd)))
			_atualizar_ui()
		"sair":
			if sou_lider() and str(p.get("gid", "")) == gid and membros.has(de):
				_sistema("%s saiu do grupo." % str(membros[de].name))
				membros.erase(de)
				ordem.erase(de)
				_depois_de_mudar()
		"expulso":
			if str(p.get("gid", "")) == gid and de == lider:
				_sistema("O líder tirou você do grupo.")
				_limpar()
		"desfazer":
			if str(p.get("gid", "")) == gid and de == lider:
				_sistema("O grupo foi desfeito.")
				_limpar()
		"estado":
			if str(p.get("gid", "")) == gid and membros.has(de):
				var m: Dictionary = membros[de]
				for k in ["lvl", "hp", "mp", "cp", "x", "z"]:
					if p.has(k):
						m[k] = float(p[k])
				m.cls = str(p.get("cls", m.get("cls", ""))).left(32)
				m.seen = _agora()
		"fala":
			if str(p.get("gid", "")) == gid and membros.has(de):
				main.ui.chat_line(str(membros[de].name), str(p.get("msg", "")).left(160), "grupo")


func _entrar(id: String, nome: String) -> void:
	if not membros.has(id):
		membros[id] = {"name": nome.left(24), "lvl": 1, "cls": "", "hp": 100.0, "mp": 100.0, "cp": 100.0, "x": 0.0, "z": 0.0, "seen": _agora()}
		ordem.append(id)


func _depois_de_mudar() -> void:
	if membros.size() <= 1:
		if em_grupo():
			_tx({"t": "desfazer", "gid": gid})
			_sistema("O grupo foi desfeito (ficou só você).")
		_limpar()
		return
	_enviar_lista()
	_atualizar_ui()


func _enviar_lista() -> void:
	var lista: Array = []
	for id in ordem:
		lista.append({"id": id, "n": str(membros.get(id, {}).get("name", "?"))})
	_tx({"t": "lista", "gid": gid, "lider": lider, "m": lista})


func _limpar() -> void:
	gid = ""
	lider = ""
	membros.clear()
	ordem.clear()
	_tag_sig = ""
	_atualizar_ui()


func _atualizar_ui() -> void:
	var lista: Array = []
	var agora := _agora()
	for id in ordem:
		var m: Dictionary = membros.get(id, {})
		if m.is_empty():
			continue
		lista.append({"id": id, "name": m.name, "lvl": int(m.get("lvl", 1)), "cls": str(m.get("cls", "")), "hp": float(m.get("hp", 100.0)), "mp": float(m.get("mp", 100.0)), "cp": float(m.get("cp", 100.0)),
			"eu": id == meu_id(), "lider": id == lider, "longe": id != meu_id() and agora - float(m.get("seen", 0.0)) > 30.0})
	main.ui.set_grupo(lista, sou_lider())


func limpar_tudo() -> void:
	convite = {}
	enviados.clear()
	main.ui.mostrar_convite("")
	_limpar()


# ---------- a cada quadro ----------
func _process(dt: float) -> void:
	if not main.playing:
		return
	var agora := _agora()
	if not convite.is_empty() and float(convite.ate) < agora:
		_tx({"t": "recusar", "para": convite.de})
		_sistema("O convite de %s expirou." % str(convite.nome))
		convite = {}
		main.ui.mostrar_convite("")
	if not em_grupo():
		return
	_estado_t += dt
	if _estado_t < 1.0:
		return
	_estado_t = 0.0
	# meu próprio estado (vida, mana e CP em %)
	var st: Dictionary = main.combat.st
	var eu: Dictionary = membros.get(meu_id(), {})
	if not eu.is_empty():
		eu.lvl = int(main.me.get("level", 1))
		eu.hp = main.combat.hp / maxf(float(st.get("maxHp", 1.0)), 1.0) * 100.0
		eu.mp = main.combat.mp / maxf(float(st.get("maxMp", 1.0)), 1.0) * 100.0
		eu.cp = 100.0
		eu.seen = agora
		var cl: Dictionary = main.world.info.classes.get(str(main.me.get("class_id", "")), {})
		eu.cls = str(cl.get("name", ""))
		if not teste:
			_tx({"t": "estado", "gid": gid, "lvl": eu.lvl, "hp": roundf(eu.hp), "mp": roundf(eu.mp), "cp": 100, "cls": eu.cls,
				"x": snappedf(main.player.position.x, 0.1), "z": snappedf(main.player.position.z, 0.1)})
	if teste:
		for id in membros:
			membros[id].seen = agora if id != "t3" else membros[id].seen
	# o líder tira quem sumiu há muito tempo (fechou o jogo sem sair)
	if sou_lider() and not teste:
		for id in ordem.duplicate():
			if id != meu_id() and agora - float(membros[id].get("seen", agora)) > SUMIDO:
				_sistema("%s ficou muito tempo sem conexão e saiu do grupo." % str(membros[id].name))
				membros.erase(id)
				ordem.erase(id)
				_depois_de_mudar()
				return
	_atualizar_ui()
	_cor_nomes()


# nome dos colegas de grupo em verde sobre a cabeça
func _cor_nomes() -> void:
	var sig := gid + "|" + ",".join(ordem) + "|" + str(main.social.others.size())
	if sig == _tag_sig:
		return
	_tag_sig = sig
	for id in main.social.others:
		var o: Dictionary = main.social.others[id]
		if is_instance_valid(o.node):
			o.node.set_tag("%s  Nv %d" % [str(o.name), int(o.lvl)], Color(0.55, 1.0, 0.6) if membros.has(id) else Color(0.75, 0.9, 1.0))


# membros simulados para fotos (--grupo-teste)
func simular() -> void:
	teste = true
	gid = "teste"
	lider = meu_id()
	_entrar(meu_id(), str(main.me.get("name", "Viajante")))
	var fake := [["t1", "Lyra", 34, "Arqueira", 82.0, 64.0], ["t2", "Borin", 31, "Guardião", 46.0, 30.0], ["t3", "Selene", 33, "Sacerdotisa", 100.0, 91.0], ["t4", "Kael", 29, "Duelista", 18.0, 55.0]]
	for f in fake:
		_entrar(f[0], f[1])
		var m: Dictionary = membros[f[0]]
		m.lvl = f[2]
		m.cls = f[3]
		m.hp = f[4]
		m.mp = f[5]
		m.cp = 100.0 if f[4] > 50.0 else 40.0
	membros.t3.seen = _agora() - 60.0
	_atualizar_ui()
