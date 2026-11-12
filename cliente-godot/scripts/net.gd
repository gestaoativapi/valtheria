extends Node
# Conversa com o servidor do jogo (o mesmo da versão web): entrar, criar conta e listar personagens.

const URL := "https://irpzdghikvoezfeodyiq.supabase.co"
# chave pública do projeto (a mesma que o site usa); não dá acesso de administrador
const KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlycHpkZ2hpa3ZvZXpmZW9keWlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQzMzc3NzMsImV4cCI6MjEwOTkxMzc3M30.aQPcA_-gO2XA2MwydJ4DOOh0_MHya2Yic_XasmhQzQk"
const DOMAIN := "@jogadores.reinosdeaurora.app"

var token := ""
var username := ""


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


# lista de personagens da conta: {"ok", "chars": [...], "erro"}
func chars() -> Dictionary:
	var r := await _post("/rest/v1/rpc/game_chars", {}, token)
	if not r.ok:
		return {"ok": false, "chars": [], "erro": _msg(r, "Não foi possível ler os personagens")}
	var list: Array = []
	if r.data is Dictionary and (r.data as Dictionary).get("chars") is Array:
		list = r.data.chars
	return {"ok": true, "chars": list, "erro": ""}


func logout() -> void:
	token = ""
	username = ""
