extends Node
# Medição de EFEITOS (só teste, pedido do agente gerente: "medir antes de escolher CPU ou GPU").
# Coloca 20 personagens das 8 raças em roda, num campo aberto, lançando golpes e magias de todos os
# 9 elementos sem parar, e mede 4 fases de 20 s cada:
#   A) partículas na CPU, quantidade cheia   B) CPU, modo baixo (metade)
#   C) partículas na GPU, quantidade cheia   D) GPU, modo baixo
# Grava FPS médio, 1% mais lento e a placa de vídeo em JSON.
# Uso: Valtheria.exe -- --play --at=1250,2250 --medir-efeitos=C:/caminho/efeitos.json
const FX := preload("res://scripts/fx.gd")
const Perfil := preload("res://scripts/perfil.gd")
var perfil_soma := {}
var perfil_quadros := 0
const ELEM := ["fogo", "gelo", "agua", "luz", "sombra", "natureza", "terra", "vento", "raio"]
const RACAS := [["humano", "m"], ["humano", "f"], ["elfo", "m"], ["elfo", "f"], ["sombrio", "m"], ["orc", "m"], ["anao", "m"], ["beastman", "m"], ["draconato", "m"], ["gigante", "m"]]
var FASES := [["A_cpu_cheio", false, 1.0], ["B_cpu_baixo", false, 0.5], ["C_gpu_cheio", true, 1.0], ["D_gpu_baixo", true, 0.5]]
# modo gargalo (--medir-gargalo=): separa o que pesa. [nome, personagens, animados, efeitos, escala 3D, sombras]
const GARGALO := [["G0_vazio", 0, true, false, 1.0, true], ["G1_10_pers", 10, true, false, 1.0, true],
	["G2_20_pers", 20, true, false, 1.0, true], ["G3_20_pers_parados", 20, false, false, 1.0, true],
	["G4_20_pers_efeitos", 20, true, true, 1.0, true], ["G5_resolucao_metade", 20, true, true, 0.5, true],
	["G6_sem_sombras", 20, true, true, 1.0, false],
	# sem os personagens do teste, desligando uma parte do jogo por vez (o que sobra de quadro é o peso dela)
	["H1_sem_npcs", 0, true, false, 1.0, true, ["npcs"]], ["H2_sem_combate_mobs", 0, true, false, 1.0, true, ["combat"]],
	["H3_sem_interface", 0, true, false, 1.0, true, ["ui"]], ["H4_sem_clima", 0, true, false, 1.0, true, ["atmos"]],
	["H5_sem_social", 0, true, false, 1.0, true, ["social"]], ["H6_mundo_escondido", 0, true, false, 1.0, true, ["world_vis"]],
	["H7_so_mundo", 0, true, false, 1.0, true, ["npcs", "combat", "ui", "atmos", "social"]]]
var desligados: Array = []
var gargalo := false
var efeitos_on := true
var cpu_ms: PackedFloat32Array = []
var gpu_ms: PackedFloat32Array = []
var luzes: Array = []
var DUR := 20.0
var AQUECE := 4.0

var main: Node
var saida := ""
var bonecos: Array = []
var centro := Vector3.ZERO
var fase := -1
var t_fase := 0.0
var t_golpe := 0.0
var i_golpe := 0
var usar_gpu := false
var tempos: PackedFloat32Array = []
var resultado := {}
var rng := RandomNumberGenerator.new()


func iniciar(m: Node, caminho: String, modo_gargalo := false) -> void:
	main = m
	gargalo = modo_gargalo
	if gargalo:
		FASES = GARGALO
	if gargalo:
		DUR = 12.0
		AQUECE = 3.0
	saida = caminho
	rng.seed = 42
	if OS.get_environment("MEDIR_SEG") != "":  # testes rápidos
		DUR = float(OS.get_environment("MEDIR_SEG"))
		AQUECE = 1.0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	Perfil.ativo = true
	get_tree().node_added.connect(_no_novo)


func _montar() -> void:
	centro = main.player.position + Vector3(0, 0, 0)
	var Ch = load("res://scripts/character.gd")
	for i in 20:
		var r: Array = RACAS[i % RACAS.size()]
		var mago := i % 3 == 2
		var c = Ch.create({"race": r[0], "gender": r[1], "type": "m" if mago else "l",
			"equipment": {"armadura": "leve_ng", "arma": "cajado_ng" if mago else "espada_ng"}})
		main.add_child(c)
		var ang := TAU * float(i) / 20.0
		var p := centro + Vector3(cos(ang), 0, sin(ang)) * 7.0
		c.position = Vector3(p.x, main.world.height(p.x, p.z), p.z)
		c.look_at(Vector3(centro.x, c.position.y, centro.z), Vector3.UP)
		c.rotate_y(PI)
		c.em_guarda = true
		bonecos.append(c)
	# câmera de cima, olhando a roda inteira
	main.player.visible = false


func _no_novo(n: Node) -> void:
	if not usar_gpu or not (n is CPUParticles3D):
		return
	_trocar.call_deferred(n)


# põe ao lado a partícula equivalente de GPU e desliga a de CPU (o código dos efeitos continua
# mexendo na de CPU sem erro; ela fica parada e invisível, sem custo)
func _trocar(cpu: CPUParticles3D) -> void:
	if not is_instance_valid(cpu) or not cpu.is_inside_tree() or cpu.has_meta("trocada"):
		return
	cpu.set_meta("trocada", true)
	var gpu := GPUParticles3D.new()
	gpu.convert_from_particles(cpu)
	gpu.transform = cpu.transform
	gpu.one_shot = cpu.one_shot
	gpu.emitting = true
	cpu.get_parent().add_child(gpu)
	cpu.emitting = false
	cpu.visible = false
	cpu.process_mode = Node.PROCESS_MODE_DISABLED
	if gpu.one_shot:
		get_tree().create_timer(gpu.lifetime + 0.5).timeout.connect(func(): if is_instance_valid(gpu): gpu.queue_free())


func _process(dt: float) -> void:
	if main == null or not main.playing:
		return
	var tc = main.ui.get("tela_carga")
	if tc != null and is_instance_valid(tc) and (tc as Control).is_visible_in_tree():
		return  # ainda na tela de carregamento
	if bonecos.is_empty():
		_montar()
		_proxima_fase()
		return
	t_fase += dt
	if t_fase > AQUECE:
		tempos.append(dt * 1000.0)
		for k in Perfil.t:
			perfil_soma[k] = float(perfil_soma.get(k, 0.0)) + int(Perfil.t[k]) / 1000.0
		perfil_quadros += 1
		var vr := get_viewport().get_viewport_rid()
		cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(vr) + RenderingServer.get_frame_setup_time_cpu())
		gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(vr))
	Perfil.t = {}
	if efeitos_on:
		_golpes(dt)
	_camera()
	if fase == 0 and OS.get_environment("MEDIR_FOTO") != "" and absf(t_fase - (AQUECE + DUR * 0.5)) < dt:
		get_viewport().get_texture().get_image().save_png(OS.get_environment("MEDIR_FOTO"))
	if t_fase >= AQUECE + DUR:
		if gargalo and fase == 0:
			resultado["censo_mundo"] = _censo()
		_fechar_fase()
		_proxima_fase()


func _camera() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	cam.global_position = centro + Vector3(0, 9.0, 14.0)
	cam.look_at(centro + Vector3(0, 1.0, 0), Vector3.UP)


func _golpes(dt: float) -> void:
	t_golpe -= dt
	if t_golpe > 0.0:
		return
	t_golpe = 0.12  # ~8 ações por segundo no grupo (cada personagem age a cada ~2,5 s)
	var ativos := bonecos.filter(func(b): return b.visible)
	if ativos.size() < 2:
		return
	var c = ativos[i_golpe % ativos.size()]
	var alvo = ativos[(i_golpe + 7) % ativos.size()]
	i_golpe += 1
	var e: String = ELEM[rng.randi() % ELEM.size()]
	var de: Vector3 = c.position + Vector3(0, 1.4, 0)
	var ate: Vector3 = alvo.position + Vector3(0, 1.0, 0)
	var pai: Node = main
	match i_golpe % 8:
		0:
			c.action("Spell_Simple_Shoot")
			FX.magia(pai, de, ate, e)
		1:
			c.action("Sword_Regular_A")
			FX.corte(c, FX.colors(e)[0])
			FX.burst(pai, ate, e)
		2:
			c.action("Spell_Simple_Shoot")
			FX.coluna(pai, alvo.position, e)
		3:
			c.action("Sword_Dash")
			FX.onda_choque(pai, c.position, e)
		4:
			c.action("Spell_Simple_Shoot")
			FX.chuva(pai, alvo.position, e)
		5:
			c.action("Sword_Regular_B")
			FX.corte_x(c, FX.colors(e)[0])
			FX.reacao(alvo, e, "alvo")
		6:
			c.action("Spell_Simple_Shoot")
			FX.circulo_magico(c, e)
			FX.bolt(pai, de, ate, e)
		7:
			c.action("Spell_Simple_Shoot")
			FX.zona(pai, alvo.position, e)
			FX.reacao(c, e, "conjurador")
	if not alvo.is_busy():
		alvo.action("Hit_Chest")


func _proxima_fase() -> void:
	fase += 1
	if fase >= FASES.size():
		_gravar()
		return
	var f: Array = FASES[fase]
	print("MEDIR_EFEITOS fase ", f[0])
	if gargalo:
		usar_gpu = false
		FX.amount = 1.0
		efeitos_on = bool(f[3])
		for i in bonecos.size():
			var on: bool = i < int(f[1])
			bonecos[i].visible = on
			bonecos[i].process_mode = Node.PROCESS_MODE_INHERIT if (on and bool(f[2])) else Node.PROCESS_MODE_DISABLED
		get_viewport().scaling_3d_scale = float(f[4])
		for d in desligados:  # religa o que a fase anterior desligou
			if is_instance_valid(d[0]):
				d[0].process_mode = d[1]
				if d[0] is Node3D or d[0] is CanvasLayer:
					d[0].visible = d[2]
		desligados.clear()
		if f.size() > 6:
			for nome in f[6]:
				var alvo = main.get("world" if nome == "world_vis" else nome)
				if alvo == null:
					continue
				desligados.append([alvo, alvo.process_mode, alvo.visible])
				if nome == "world_vis":
					alvo.visible = false
				else:
					alvo.process_mode = Node.PROCESS_MODE_DISABLED
					if nome != "combat":
						alvo.visible = false
		if luzes.is_empty():
			for l in get_tree().root.find_children("*", "Light3D", true, false):
				luzes.append([l, (l as Light3D).shadow_enabled])
		for par in luzes:
			if is_instance_valid(par[0]):
				(par[0] as Light3D).shadow_enabled = bool(par[1]) and bool(f[5])
	else:
		usar_gpu = bool(f[1])
		FX.amount = float(f[2])
	t_fase = 0.0
	tempos = PackedFloat32Array()
	cpu_ms = PackedFloat32Array()
	gpu_ms = PackedFloat32Array()


func _fechar_fase() -> void:
	var lista := Array(tempos)
	lista.sort()
	var soma := 0.0
	for v in lista:
		soma += v
	var n := lista.size()
	var pior := 0.0
	var k: int = maxi(1, n / 100)
	for i in range(n - k, n):
		pior += lista[i]
	resultado[FASES[fase][0]] = {
		"quadros": n,
		"fps_medio": snappedf(1000.0 * n / maxf(soma, 0.001), 0.1),
		"fps_1pct_baixo": snappedf(1000.0 * k / maxf(pior, 0.001), 0.1),
		"quadro_p99_ms": snappedf(lista[int(n * 0.99)] if n > 0 else 0.0, 0.01),
		"particulas_cpu": get_tree().root.find_children("*", "CPUParticles3D", true, false).size(),
		"particulas_gpu": get_tree().root.find_children("*", "GPUParticles3D", true, false).size(),
		"render_cpu_ms": snappedf(_media(cpu_ms), 0.01),
		"render_gpu_ms": snappedf(_media(gpu_ms), 0.01),
		"logica_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
		"fisica_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
		"chamadas_desenho": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"triangulos": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	}
	var pm := {}
	for parte in perfil_soma:
		pm[parte] = snappedf(float(perfil_soma[parte]) / maxf(1.0, perfil_quadros), 0.01)
	resultado[FASES[fase][0]]["ms_por_parte"] = pm
	perfil_soma = {}
	perfil_quadros = 0


func _media(a: PackedFloat32Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


func _censo() -> Dictionary:
	# de onde vêm as partículas e malhas que já existem no mundo (sem os personagens do teste)
	var cont := {}
	for n in get_tree().root.find_children("*", "CPUParticles3D", true, false):
		if not (n as Node3D).is_visible_in_tree() or not n.can_process():
			continue
		var dono: Node = n.get_parent()
		while dono != null and dono.get_script() == null:
			dono = dono.get_parent()
		var cp := n as CPUParticles3D
		var k: String = "particulas:" + (dono.get_script().resource_path.get_file() if dono else "?") + ":" + String(n.get_parent().name).rstrip("0123456789@_") + ":q" + str(cp.amount) + ":v" + str(int(cp.lifetime * 10))
		cont[k] = int(cont.get(k, 0)) + 1
	var lista := []
	for k in cont:
		lista.append([cont[k], k])
	lista.sort_custom(func(a, b): return a[0] > b[0])
	var r := {}
	for i in mini(12, lista.size()):
		r[lista[i][1]] = lista[i][0]
	r["malhas_visiveis"] = get_tree().root.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.is_visible_in_tree()).size()
	r["multimalhas"] = get_tree().root.find_children("*", "MultiMeshInstance3D", true, false).size()
	return r


func _gravar() -> void:
	resultado["placa_de_video"] = RenderingServer.get_video_adapter_name()
	resultado["driver"] = RenderingServer.get_video_adapter_api_version()
	resultado["renderizador"] = RenderingServer.get_current_rendering_method() + " / " + RenderingServer.get_current_rendering_driver_name()
	var placa := RenderingServer.get_video_adapter_name().to_lower()
	if placa.contains("llvmpipe") or placa.contains("basic render") or placa.contains("swiftshader"):
		resultado["aviso"] = "PLACA DE SOFTWARE: o FPS não representa o desempenho real"
	resultado["processador"] = OS.get_processor_name()
	resultado["janela"] = str(get_viewport().get_visible_rect().size)
	resultado["personagens"] = bonecos.size()
	var f := FileAccess.open(saida, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(resultado, "  "))
		f.close()
	print("MEDIR_EFEITOS ", JSON.stringify(resultado))
	get_tree().quit()
