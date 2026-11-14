extends SceneTree
# D45: lê as constantes de rede de DENTRO do pacote exportado e confirma que ele aponta só para o projeto de testes.
# Uso: godot --headless --main-pack build/conferencia.pck --script res://teste/conferir_ambiente.gd

const PROD_REF := "irpzdghikvoezfeodyiq"

func _init() -> void:
	var c: Dictionary = (load("res://scripts/net.gd") as Script).get_script_constant_map()
	var url := str(c.get("URL", ""))
	var amb := str(c.get("AMBIENTE", ""))
	var key := str(c.get("KEY", ""))
	var p := key.get_slice(".", 1).replace("-", "+").replace("_", "/")
	while p.length() % 4 != 0:
		p += "="
	var payload: Variant = JSON.parse_string(Marshalls.base64_to_utf8(p))
	var ref := str(payload.get("ref", "")) if payload is Dictionary else ""
	var role := str(payload.get("role", "")) if payload is Dictionary else ""
	print("PACOTE URL=", url, " AMBIENTE=", amb, " chave.role=", role, " chave.ref=", ref)
	var ok := amb == "testes" and not url.contains(PROD_REF) and ref != PROD_REF and role == "anon" and url.contains(ref)
	print("CONFERENCIA_PACOTE ", "OK" if ok else "FALHOU")
	quit(0 if ok else 1)
