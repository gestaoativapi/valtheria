extends RefCounted
# Perfil de quadro (só teste): soma o tempo (µs) de cada parte pesada no quadro atual.
static var t := {}
static var ativo := false

static func soma(k: String, us: int) -> void:
	if ativo:
		t[k] = int(t.get(k, 0)) + us
