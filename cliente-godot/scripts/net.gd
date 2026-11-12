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
	return {"ok": r.ok, "chars": list, "erro": r.erro}


func create_char(o: Dictionary) -> String:
	var r := await rpc_call("game_create_char2", {"p_name": o.name, "p_race": o.race, "p_type": o.type, "p_gender": o.gender, "p_look": o.look})
	return r.erro


# estado completo do personagem (posição, vida, equipamento)
func state(id: String) -> Dictionary:
	char_id = id
	var r := await rpc_call("game_state", {"p_char": id})
	if r.ok and r.data is Dictionary and (r.data as Dictionary).get("char") is Dictionary:
		return r.data.char
	return {}


func save(x: float, z: float, hp: float, mp: float) -> bool:
	if token == "" or char_id == "":
		return false
	var r := await rpc_call("game_save", {"p_char": char_id, "p_x": x, "p_z": z, "p_hp": hp, "p_mp": mp})
	return r.ok


func logout() -> void:
	token = ""
	username = ""
	refresh = ""
	char_id = ""
