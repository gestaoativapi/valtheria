extends Node3D
const Perfil := preload("res://scripts/perfil.gd")
# Outros jogadores na tela e bate-papo.

const Character = preload("res://scripts/character.gd")

var main: Node3D
var others := {}  # id -> {"node", "pos", "rot", "seen", "sig"}
var send_t := 0.0
var chat_t := 0.0
var last_chat := -1
var last_sent := Vector3.ZERO
var idle_t := 0.0


func setup(m: Node3D) -> void:
	main = m
	main.net.remote_pos.connect(_on_pos)
	main.net.remote_leave.connect(_drop)


func clear() -> void:
	for id in others.keys():
		_drop(id)
	last_chat = -1


func _drop(id: String) -> void:
	if others.has(id):
		if is_instance_valid(others[id].node):
			others[id].node.queue_free()
		others.erase(id)


func _on_pos(p: Dictionary) -> void:
	var id := str(p.get("id", ""))
	if id == "" or id == str(main.me.get("id", "")) or not main.playing:
		return
	var pos := Vector3(float(p.get("x", 0)), 0, float(p.get("z", 0)))
	var sig := "%s|%s|%s|%s|%s|%s|%s|%s" % [p.get("ra"), p.get("ge"), p.get("h"), p.get("hc"), p.get("sk"), p.get("w"), p.get("a"), p.get("en")]
	if others.has(id) and others[id].sig != sig:
		_drop(id)
	if not others.has(id):
		if others.size() >= 40 or pos.distance_to(Vector3(main.player.position.x, 0, main.player.position.z)) > 220.0:
			return
		var node: Node3D = Character.create({"race": str(p.get("ra", "humano")), "gender": str(p.get("ge", "m")), "skin": int(p.get("sk", 0)), "hair": int(p.get("h", 0)), "hair_color": int(p.get("hc", 0)),
			"look": p.get("lk") if p.get("lk") is Dictionary else {}, "equipment": {"arma": str(p.get("w", "")), "armadura": str(p.get("a", "pesada_ng"))}, "enchant": {str(p.get("w", "")): clampi(int(p.get("en", 0)), 0, 16)}})
		add_child(node)
		node.position = Vector3(pos.x, main.world.height(pos.x, pos.z), pos.z)
		node.set_tag("%s  Nv %d" % [str(p.get("n", "?")), int(p.get("l", 1))], Color(0.75, 0.9, 1.0))
		others[id] = {"node": node, "pos": pos, "rot": 0.0, "seen": 0.0, "sig": sig, "name": "?", "lvl": 1, "hp": 100.0, "cp": 100.0}
	others[id].name = str(p.get("n", "?"))
	others[id].lvl = int(p.get("l", 1))
	others[id].hp = float(p.get("hp", 100.0))
	others[id].cp = float(p.get("cp", 100.0))
	# 26/11: velocidade real do outro jogador entre dois avisos (5 por segundo andando); serve para ele andar no
	# mesmo ritmo, sem arrancar e frear a cada aviso, e para a passada da animação bater com o chão
	var agora := Time.get_ticks_msec() * 0.001
	var o_: Dictionary = others[id]
	var dtr := agora - float(o_.get("t_rx", 0.0))
	if o_.has("t_rx") and dtr > 0.05 and dtr < 1.5:
		var vn := (pos - (o_.pos as Vector3)) / dtr
		if vn.length() > 12.0:
			vn = Vector3.ZERO  # teleporte/entrada em mapa: não extrapola
		o_.vnet = vn
	elif dtr >= 1.5:
		o_.vnet = Vector3.ZERO
	o_.t_rx = agora
	others[id].pos = pos
	others[id].rot = float(p.get("r", 0.0))
	others[id].seen = agora
	var lj := str(p.get("lj", "")).strip_edges().left(32)
	if lj != str(others[id].get("loja", "")):
		others[id].loja = lj
		others[id].node.set_placa(lj)


func _process(dt: float) -> void:
	var __t := Time.get_ticks_usec()
	_process_medido(dt)
	Perfil.soma("social", Time.get_ticks_usec() - __t)


func _process_medido(dt: float) -> void:
	if not main.playing:
		return
	var now := Time.get_ticks_msec() * 0.001
	for id in others.keys():
		var o: Dictionary = others[id]
		var node: Node3D = o.node
		if now - float(o.seen) > 20.0 or (o.pos as Vector3).distance_to(Vector3(main.player.position.x, 0, main.player.position.z)) > 260.0:
			_drop(id)
			continue
		var cur := Vector3(node.position.x, 0, node.position.z)
		# 26/11: segue a posição prevista (último aviso + velocidade x tempo, no máximo 0,35 s à frente) em ritmo
		# constante; antes ia em "pulos" (rápido logo após o aviso, quase parando antes do próximo) e trocava
		# corrida/parado várias vezes por segundo
		# revisão 26/11: sem prever à frente (o último aviso antes de parar ainda trazia velocidade, e o boneco
		# passava até 1,8 m do ponto onde o jogador parou e depois voltava andando). Segue o último ponto no ritmo
		# medido entre avisos (chega junto com o próximo aviso) e só acelera se ficar mais de 1/4 de aviso atrás.
		var vn: Vector3 = o.get("vnet", Vector3.ZERO)
		var alvo: Vector3 = o.pos
		var d := cur.distance_to(alvo)
		var np := alvo
		if d < 12.0:
			var ritmo := vn.length() + maxf(0.0, d - vn.length() * 0.25) * 2.0
			np = cur.move_toward(alvo, maxf(ritmo, 0.4) * dt)
		var vis := (np - cur).length() / maxf(dt, 0.001) if d < 12.0 else 0.0
		o.vvis = lerpf(float(o.get("vvis", 0.0)), vis, minf(1.0, dt * 6.0))
		node.position = Vector3(np.x, main.world.height(np.x, np.z), np.z)
		node.rotation.y = lerp_angle(node.rotation.y, float(o.rot), minf(1.0, dt * 8.0))
		var andando: bool = o.get("andando", false)
		andando = float(o.vvis) > (0.25 if andando else 0.6)  # folga: não pisca entre andar e parar
		o.andando = andando
		if andando:
			node.mover(float(o.vvis))
		else:
			node.play("Sitting_Idle" if str(o.get("loja", "")) != "" else "Idle")
	# envia a própria posição: 5 vezes por segundo andando, a cada 3 s parado
	send_t += dt
	var moved: bool = main.player.position.distance_to(last_sent) > 0.05
	idle_t = 0.0 if moved else idle_t + dt
	if send_t > 0.2 and (moved or idle_t > 3.0) and main.me.has("id"):
		send_t = 0.0
		idle_t = 0.0
		last_sent = main.player.position
		var c: Dictionary = main.me
		var eq: Dictionary = c.get("equipment") if c.get("equipment") is Dictionary else {}
		main.net.rt_pos({"id": c.id, "n": c.get("name", ""), "x": snappedf(main.player.position.x, 0.01), "z": snappedf(main.player.position.z, 0.01), "r": snappedf(main.player.rotation.y, 0.01), "st": "run" if moved else "idle",
			"ra": c.get("race"), "ge": c.get("gender"), "h": c.get("hair"), "hc": c.get("hair_color"), "sk": c.get("skin"), "lk": c.get("look"), "c": c.get("class_id"), "l": c.get("level"), "hp": int(main.combat.hp / maxf(float(main.combat.st.get("maxHp", 1.0)), 1.0) * 100.0), "cp": 100, "w": eq.get("arma", ""), "a": eq.get("armadura", ""),
			"en": int((c.get("enchant") if c.get("enchant") is Dictionary else {}).get(str(eq.get("arma", "")), 0)), "lj": main.loja_titulo})
	chat_t += dt
	if chat_t > 4.0 and main.net.token != "":
		chat_t = 0.0
		_poll_chat()


func _poll_chat() -> void:
	var r: Dictionary = await main.net.rpc_call("game_chat_recent")
	if not r.ok or not (r.data is Array):
		return
	for m in r.data:
		if int(m.get("id", 0)) > last_chat:
			last_chat = int(m.get("id", 0))
			main.ui.chat_line(str(m.get("name", "")), str(m.get("msg", "")), str(m.get("kind", "chat")))


func say(text: String) -> void:
	text = text.strip_edges()
	if text == "":
		return
	if main.net.token == "" or not main.me.has("id"):
		main.ui.chat_line("", "O bate-papo precisa de uma conta conectada.", "sistema")
		return
	var err: String = await main.net.act("game_chat", {"p_msg": text})
	if err != "":
		main.ui.chat_line("", err, "sistema")
	chat_t = 3.5


# jogador sob o clique: devolve o id ou ""
func pick(origin: Vector3, dir: Vector3) -> String:
	for id in others:
		var node: Node3D = others[id].node
		var c: Vector3 = node.position + Vector3(0, 0.9, 0)
		var t := (c - origin).dot(dir)
		if t > 0.0 and (origin + dir * t).distance_to(c) < 0.8:
			return id
	return ""
