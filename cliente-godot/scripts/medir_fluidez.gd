extends Node
# Medição de fluidez (só teste): o personagem percorre uma rota fixa entre cidades a 14 m/s,
# como quem viaja a cavalo, e registra o tempo de cada quadro. Grava percentis e travadas em JSON.
# Uso: Valtheria.exe -- --play --medir-fluidez=C:/caminho/fluidez.json
const ROTA := [Vector2(1500, 2550), Vector2(1500, 1985), Vector2(1500, 1450), Vector2(2150, 1300), Vector2(2350, 1950), Vector2(1500, 2550)]
const VEL := 14.0
var main: Node
var saida := ""
var seg := 0
var t_ant := 0
var tempos: PackedFloat32Array = []
var travadas: Array = []
var aquecer := 90
var volta := 1
var volta1 := {}


const Perfil := preload("res://scripts/perfil.gd")
var somas := {}


func iniciar(m: Node, caminho: String) -> void:
	main = m
	saida = caminho
	process_priority = 1000   # roda depois de todos: o perfil já tem o trabalho deste quadro
	Perfil.ativo = true


func _process(_dt: float) -> void:
	if main == null or not main.playing:
		return
	var agora := Time.get_ticks_usec()
	if aquecer > 0:
		aquecer -= 1
		t_ant = agora
		return
	var ms := (agora - t_ant) / 1000.0
	t_ant = agora
	tempos.append(ms)
	var p: Vector3 = main.player.position
	var partes := {}
	for k in Perfil.t:
		partes[k] = snappedf(int(Perfil.t[k]) / 1000.0, 0.1)
		somas[k] = float(somas.get(k, 0.0)) + int(Perfil.t[k]) / 1000.0
	Perfil.t = {}
	if ms > 50.0:
		travadas.append({"ms": snappedf(ms, 0.1), "x": int(p.x), "z": int(p.z), "blocos": main.world.chunks.size(), "partes_ms": partes})
	if seg >= ROTA.size() - 1:
		if volta == 1:   # segunda volta na mesma rota: o que se repete não é carga inicial
			volta1 = _resumo()
			volta = 2
			seg = 0
			tempos = PackedFloat32Array()
			travadas = []
		else:
			_fim()
		return
	var alvo: Vector2 = ROTA[seg + 1]
	var aqui := Vector2(p.x, p.z)
	var passo := VEL * minf(ms / 1000.0, 0.1)
	if aqui.distance_to(alvo) <= passo:
		seg += 1
		aqui = alvo
	else:
		aqui += (alvo - aqui).normalized() * passo
		main.facing = atan2(alvo.x - aqui.x, alvo.y - aqui.y)
		main.player.rotation.y = main.facing
		main.yaw = main.facing + PI
	main.player.position = Vector3(aqui.x, main.world.height(aqui.x, aqui.y), aqui.y)


func _fim() -> void:
	var r := _resumo()
	r["volta1"] = volta1
	r["memoria_ram_mb"] = snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1)
	r["memoria_video_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)
	r["total_por_parte_ms"] = somas
	var f := FileAccess.open(saida, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(r, "  "))
	print("FLUIDEZ ", JSON.stringify(r))
	main.get_tree().quit()


func _resumo() -> Dictionary:
	var s := Array(tempos)
	s.sort()
	var n := s.size()
	var soma := 0.0
	for v in s:
		soma += v
	var pc := func(q: float) -> float: return snappedf(float(s[clampi(int(q * n), 0, n - 1)]), 0.01)
	var r := {
		"quadros": n, "segundos": snappedf(soma / 1000.0, 0.1), "fps_medio": snappedf(n / (soma / 1000.0), 0.1),
		"ms_p50": pc.call(0.5), "ms_p95": pc.call(0.95), "ms_p99": pc.call(0.99), "ms_max": snappedf(float(s[n - 1]), 0.1),
		"travadas_50ms": travadas.size(), "travadas_100ms": travadas.filter(func(t): return float(t.ms) > 100.0).size(),
		"piores": travadas.slice(0, 0) + _piores(), "gpu": RenderingServer.get_video_adapter_name(),
		"renderizador": str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		"memoria_ram_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"memoria_video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
	}
	return r


func _piores() -> Array:
	var c := travadas.duplicate()
	c.sort_custom(func(a, b): return float(a.ms) > float(b.ms))
	return c.slice(0, 12)
