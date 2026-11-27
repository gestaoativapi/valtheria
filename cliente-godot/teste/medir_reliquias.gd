extends SceneTree
# Custo de CPU das Relíquias (27/11, método da skill performance-optimization): monta N personagens
# com armas de um grau e mede o tempo de criação e o tempo de quadro (média, p95, p99) parado.
#   godot --headless --path . -s teste/medir_reliquias.gd -- --grau=ss --n=30
# Sem GPU: mede só scripts, partículas de CPU e motor; o custo de desenho é conferido no aparelho.

const C = preload("res://scripts/character.gd")
const ARMAS := ["espada", "espadao", "adaga", "martelo", "machado", "lanca", "cajado", "arco"]


func _initialize() -> void:
	var grau := "ss"
	var n := 30
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--grau="): grau = a.trim_prefix("--grau=")
		if a.begins_with("--n="): n = int(a.trim_prefix("--n="))
	OS.low_processor_usage_mode_sleep_usec = 0
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 3, 12)
	var t0 := Time.get_ticks_usec()
	for i in n:
		var id := "%s_%s" % [ARMAS[i % ARMAS.size()], grau]
		var c: Node3D = C.create({"race": "humano", "gender": "m", "equipment": {"arma": id}})
		root.add_child(c)
		c.position = Vector3((i % 6) * 1.5 - 4.0, 0, -(i / 6) * 1.5)
	var criar := (Time.get_ticks_usec() - t0) / 1000.0
	for i in 60:
		await process_frame
	var ms := PackedFloat64Array()
	var last := Time.get_ticks_usec()
	for i in 300:
		await process_frame
		var now := Time.get_ticks_usec()
		ms.append((now - last) / 1000.0)
		last = now
	ms.sort()
	var avg := 0.0
	for v in ms:
		avg += v / ms.size()
	var part := 0
	for p in root.find_children("*", "CPUParticles3D", true, false):
		part += (p as CPUParticles3D).amount
	print("RELIQ grau=%s n=%d criar=%.0fms (%.1fms/pers) quadro avg=%.2fms p95=%.2fms p99=%.2fms particulas=%d"
			% [grau, n, criar, criar / n, avg, ms[int(ms.size() * 0.95)], ms[int(ms.size() * 0.99)], part])
	quit()
