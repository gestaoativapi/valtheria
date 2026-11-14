extends Node
# Conversa com o servidor do jogo (o mesmo da versão web): entrar, criar conta e listar personagens.

const URL := "https://irpzdghikvoezfeodyiq.supabase.co"
# chave pública do projeto (a mesma que o site usa); não dá acesso de administrador
const KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlycHpkZ2hpa3ZvZXpmZW9keWlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQzMzc3NzMsImV4cCI6MjEwOTkxMzc3M30.aQPcA_-gO2XA2MwydJ4DOOh0_MHya2Yic_XasmhQzQk"
const DOMAIN := "@jogadores.reinosdeaurora.app"

var token := ""
var username := ""
var refresh := ""
var char_id := ""
var inventory := {}
var ws: WebSocketPeer
var ws_ref := 0
var ws_joined := false
var ws_beat := 0.0
var ws_me := {}
var is_gm := false  # conta de GM (vem de game_chars)
var ws_want := false  # tempo real desejado: se cair, reconecta sozinho
var ws_retry := 0.0  # segundos até a próxima tentativa
var ws_backoff := 2.0  # espera cresce até 30 s entre tentativas
signal remote_pos(p: Dictionary)
signal remote_leave(id: String)


func _post(path: String, body: Dictionary, bearer := "") -> Dictionary:
	var h := HTTPRequest.new()
	h.timeout = 20.0
	add_child(h)
	var headers := PackedStringArray(["apikey: " + KEY, "Content-Type: application/json", "Authorization: Bearer " + (bearer if bearer != "" else KEY)])
	var err := h.request(URL + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		h.queue_free()
		return {"ok": false, "code": 0, "data": null}
	var r: Array = await h.request_completed
	h.queue_free()
	var data: Variant = null
	var txt := (r[3] as PackedByteArray).get_string_from_utf8()
	if txt != "":
		data = JSON.parse_string(txt)
	return {"ok": r[0] == HTTPRequest.RESULT_SUCCESS and r[1] >= 200 and r[1] < 300, "code": r[1] if r[0] == HTTPRequest.RESULT_SUCCESS else 0, "data": data}


static func _msg(r: Dictionary, fallback: String) -> String:
	if r.code == 0:
		return "Sem conexão com o servidor. Confira a internet e tente de novo."
	var d: Variant = r.data
	if d is Dictionary:
		for k in ["error", "msg", "error_description", "message"]:
			if d.has(k) and d[k] is String and d[k] != "":
				return d[k]
	return fallback


# devolve "" se deu certo, ou a mensagem de erro
func login(user: String, password: String) -> String:
	user = user.strip_edges().to_lower()
	if user == "" or password == "":
		return "Preencha usuário e senha"
	var r := await _post("/auth/v1/token?grant_type=password", {"email": user + DOMAIN, "password": password})
	if not r.ok:
		var m := _msg(r, "Não foi possível entrar")
		if m.findn("invalid login") >= 0 or m.findn("invalid_credentials") >= 0 or r.code == 400:
			return "Usuário ou senha incorretos" if r.code != 0 else m
		return m
	token = str((r.data as Dictionary).get("access_token", ""))
	refresh = str((r.data as Dictionary).get("refresh_token", ""))
	username = user
	return "" if token != "" else "Resposta inesperada do servidor"


func signup(user: String, password: String) -> String:
	user = user.strip_edges()
	if user.length() < 3:
		return "O usuário precisa de pelo menos 3 letras"
	if password.length() < 6:
		return "A senha precisa de pelo menos 6 caracteres"
	var r := await _post("/functions/v1/signup", {"username": user, "password": password})
	if not r.ok:
		return _msg(r, "Não foi possível criar a conta")
	return await login(user, password)


# chamada ao servidor do jogo; renova a sessão sozinho se ela venceu
func rpc_call(fn: String, args := {}) -> Dictionary:
	var r := await _post("/rest/v1/rpc/" + fn, args, token)
	if r.code == 401 and refresh != "":
		var t := await _post("/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh})
		if t.ok:
			token = str((t.data as Dictionary).get("access_token", ""))
			refresh = str((t.data as Dictionary).get("refresh_token", refresh))
			r = await _post("/rest/v1/rpc/" + fn, args, token)
	return {"ok": r.ok, "data": r.data, "erro": "" if r.ok else _msg(r, "O servidor recusou o pedido")}


func chars() -> Dictionary:
	var r := await rpc_call("game_chars")
	var list: Array = []
	if r.ok and r.data is Dictionary and (r.data as Dictionary).get("chars") is Array:
		list = r.data.chars
		is_gm = bool((r.data as Dictionary).get("is_gm", false))
	return {"ok": r.ok, "chars": list, "erro": r.erro, "is_gm": is_gm}


func create_char(o: Dictionary) -> String:
	var r := await rpc_call("game_create_char2", {"p_name": o.name, "p_race": o.race, "p_type": o.type, "p_gender": o.gender, "p_look": o.look})
	return r.erro


# estado completo do personagem (posição, vida, equipamento)
func state(id: String) -> Dictionary:
	char_id = id
	var r := await rpc_call("game_state", {"p_char": id})
	if r.ok and r.data is Dictionary and (r.data as Dictionary).get("char") is Dictionary:
		inventory = r.data.inventory if r.data.get("inventory") is Dictionary else {}
		return r.data.char
	return {}


# salva posição, vida e mana; o servidor (game_save2) limita a vida e a mana ao máximo
# e recusa deslocamento impossível, devolvendo a posição que ele tem registrada
func save(x: float, z: float, hp: float, mp: float) -> Dictionary:
	if token == "" or char_id == "":
		return {"ok": false}
	var r := await rpc_call("game_save2", {"p_char": char_id, "p_x": x, "p_z": z, "p_hp": hp, "p_mp": mp})
	if not r.ok or not (r.data is Dictionary):
		return {"ok": false, "erro": r.erro}
	return r.data


# ação do personagem no servidor (equipar, comprar, usar...); devolve "" ou a mensagem de erro
func act(fn: String, args := {}) -> String:
	var a := args.duplicate()
	a.p_char = char_id
	var r := await rpc_call(fn, a)
	return r.erro


# ---------- tempo real: outros jogadores (mesmo canal "mundo" da versão web) ----------
func rt_join(me: Dictionary) -> void:
	rt_leave()
	if token == "" or not me.has("id"):
		return
	ws_me = me
	ws_want = true
	ws_backoff = 2.0
	_rt_open()


func _rt_open() -> void:
	ws = WebSocketPeer.new()
	ws_joined = false
	if ws.connect_to_url(URL.replace("https://", "wss://") + "/realtime/v1/websocket?apikey=" + KEY + "&vsn=1.0.0") != OK:
		ws = null


func rt_leave() -> void:
	ws_want = false
	if ws:
		ws.close()
	ws = null
	ws_joined = false


func _rt_send(topic: String, event: String, payload: Dictionary) -> void:
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	ws_ref += 1
	ws.send_text(JSON.stringify({"topic": topic, "event": event, "payload": payload, "ref": str(ws_ref)}))


func rt_pos(p: Dictionary) -> void:
	if ws_joined:
		_rt_send("realtime:mundo", "broadcast", {"type": "broadcast", "event": "p", "payload": p})


func _process(dt: float) -> void:
	if ws == null:
		# conexão caiu: tenta de novo com espera crescente (2, 4, 8... até 30 s)
		if ws_want and token != "":
			ws_retry -= dt
			if ws_retry <= 0.0:
				ws_retry = ws_backoff
				ws_backoff = minf(30.0, ws_backoff * 2.0)
				_rt_open()
		return
	ws.poll()
	var state := ws.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		ws = null
		ws_joined = false
		ws_retry = ws_backoff
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	if not ws_joined:
		ws_joined = true
		ws_backoff = 2.0
		_rt_send("realtime:mundo", "phx_join", {"config": {"broadcast": {"self": false}, "presence": {"key": str(ws_me.get("id", ""))}}, "access_token": token})
		_rt_send("realtime:mundo", "presence", {"type": "presence", "event": "track", "payload": {"name": str(ws_me.get("name", "")), "gm": bool(ws_me.get("is_gm", false))}})
	ws_beat += dt
	if ws_beat > 25.0:
		ws_beat = 0.0
		_rt_send("phoenix", "heartbeat", {})
	while ws.get_available_packet_count() > 0:
		var msg: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
		if not (msg is Dictionary):
			continue
		var pl: Variant = msg.get("payload")
		if msg.get("event") == "broadcast" and pl is Dictionary and pl.get("event") == "p" and pl.get("payload") is Dictionary:
			remote_pos.emit(pl.payload)
		elif msg.get("event") == "presence_diff" and pl is Dictionary and pl.get("leaves") is Dictionary:
			for k in pl.leaves:
				remote_leave.emit(str(k))


# comando de GM no servidor (registrado em game.gm_log); devolve o texto da resposta
func gm(cmd: String, args := {}) -> String:
	var r := await rpc_call("game_gm", {"p_char": char_id, "p_cmd": cmd, "p_args": args})
	if not r.ok:
		return "Erro: " + str(r.erro)
	return str(r.data)


func logout() -> void:
	rt_leave()
	inventory = {}
	is_gm = false
	token = ""
	username = ""
	refresh = ""
	char_id = ""
