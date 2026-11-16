extends Node3D
# Valtheria V3 — AUT-021 D58/D59: capturas antes/depois das formas corretivas da túnica e da calça sem a faixa do
# entrepernas (não faz parte do jogo). Monta P1/P2 a partir de assets_v3/personagens, como o character.gd.
# Também grava os pesos calculados pelo controlador nas poses críticas (para conferir com corretivas_base.py).
# Uso: godot --path . --rendering-driver opengl3 res://testes/prototipos/corretivas_teste.tscn -- --saida=<pasta>
const V3 := "res://assets_v3/personagens/"
const CS := preload("res://scripts/character.gd")
const Ctrl := preload("res://testes/prototipos/corretivas_controlador.gd")
const POSES := [["Idle", 0.0], ["Sitting_Idle_Loop", 0.5], ["Sword_Regular_A", 0.5], ["Sprint_Loop", 0.25], ["Farm_Harvest", 0.5], ["OverhandThrow", 0.5], ["Sword_Attack", 0.5], ["Sword_Regular_B", 0.5], ["Sword_Regular_C", 0.5], ["Walk_Loop", 0.25], ["Jog_Fwd_Loop", 0.25]]
var saida := "user://corretivas"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): saida = a.substr(8)
	DirAccess.make_dir_recursive_absolute(saida)
	var sol := DirectionalLight3D.new(); sol.rotation_degrees = Vector3(-50, -35, 0); sol.shadow_enabled = true; add_child(sol)
	var env := WorldEnvironment.new(); env.environment = Environment.new(); env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.46, 0.5, 0.55); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6); add_child(env)
	var pesos := {}
	var versoes := [["m", "atual", "rp_aldeao_tunica_m", "rp_aldeao_calca_m"], ["m", "corretiva", "rp_aldeao_tunica_m_corretiva", "rp_aldeao_calca_m"],
		["m", "rbf", "rp_aldeao_tunica_m_rbf", "rp_aldeao_calca_m"],
		["m", "rbf_sem_entrepernas", "rp_aldeao_tunica_m_rbf", "rp_aldeao_calca_m_sem_entrepernas"],
		["f", "atual", "rp_aldeao_tunica_f", "rp_aldeao_calca_f"], ["f", "corretiva", "rp_aldeao_tunica_f_corretiva", "rp_aldeao_calca_f"],
		["f", "rbf", "rp_aldeao_tunica_f_rbf", "rp_aldeao_calca_f"]]
	var custo := {}
	for v in versoes:
		var m := montar(v[0], v[2], v[3])
		for p in POSES:
			var an := str(p[0])
			if not m["anim"].has_animation(an):
				for a in m["anim"].get_animation_list():
					if a.begins_with(an.replace("_Loop", "")): an = a; break
			m["anim"].play(an, 0.0); m["anim"].seek(m["anim"].get_animation(an).length * float(p[1]), true); m["anim"].pause()
			if m["ctrl"] != null:
				m["ctrl"].aplicar()
				pesos["%s_%s" % [v[0], an]] = m["ctrl"].ultimo
			var base := "%s_%s_%s" % [v[0], v[1], an]
			await foto(base + "_lado", 80, 0.15)
			await foto(base + "_frente", 15, 0.15)
			if v[0] == "m" and v[1] in ["atual", "rbf_sem_entrepernas"]:
				await foto(base + "_baixo", 20, -0.75)
				await foto_rente(base + "_rente_frente", 15)
				await foto_rente(base + "_rente_costas", 165)
				await foto_rente(base + "_rente_lado", 85)
		if m["ctrl"] != null:   # custo de CPU do controlador: 2000 avaliações seguidas na pose atual
			var t0 := Time.get_ticks_usec()
			for i in 2000: m["ctrl"].aplicar()
			custo["%s_%s" % [v[0], v[1]]] = {"us_por_avaliacao": snappedf((Time.get_ticks_usec() - t0) / 2000.0, 0.1), "formas": m["ctrl"].indices.size(), "centros_rbf": m["ctrl"].rbf_n}
		m["body"].queue_free()
		await get_tree().process_frame
	var f := FileAccess.open(saida + "/pesos_godot.json", FileAccess.WRITE); f.store_string(JSON.stringify(pesos, " "))
	var f2 := FileAccess.open(saida + "/custo_cpu.json", FileAccess.WRITE); f2.store_string(JSON.stringify(custo, " "))
	get_tree().quit()

func montar(g: String, tunica: String, calca: String) -> Dictionary:
	var body: Node3D = (load(V3 + "pc_humano_%s.glb" % g) as PackedScene).instantiate(); add_child(body)
	var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D
	var ctrl = null
	for p in [tunica, calca, "rp_botas_couro_" + g, "ca_curto_01" if g == "m" else "ca_tranca_longa"]:
		var src: Node3D = (load(V3 + p + ".glb") as PackedScene).instantiate()
		for mm in src.find_children("*", "MeshInstance3D", true, false):
			mm.get_parent().remove_child(mm); mm.owner = null; skel.add_child(mm)
			(mm as MeshInstance3D).skeleton = NodePath("..")
			if p.ends_with("_corretiva"):
				ctrl = Ctrl.new(); add_child(ctrl); ctrl.configurar(skel, mm); ctrl.set_process(false)
			if p.ends_with("_rbf"):
				ctrl = Ctrl.new(); add_child(ctrl); ctrl.configurar(skel, mm); ctrl.set_process(false)
				ctrl.carregar_rbf(V3 + p + ".rbf.json")
		src.free()
	var anim := AnimationPlayer.new(); body.add_child(anim)
	anim.add_animation_library("", CS._clips(skel, ""))
	return {"body": body, "skel": skel, "anim": anim, "ctrl": ctrl}

# câmera rente ao chão (5 cm), perto (1,4 m), olhando para o quadril: procura aberturas entre as pernas
func foto_rente(nome: String, ang: float) -> void:
	var cam := Camera3D.new(); add_child(cam); cam.fov = 50
	var alvo := Vector3(0, 0.85, 0)
	cam.look_at_from_position(Vector3(sin(deg_to_rad(ang)), 0, cos(deg_to_rad(ang))) * 1.4 + Vector3(0, 0.05, 0), alvo); cam.current = true
	for i in 3: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(saida + "/" + nome + ".png")
	cam.queue_free()

func foto(nome: String, ang: float, alt: float) -> void:
	var cam := Camera3D.new(); add_child(cam); cam.fov = 35
	var alvo := Vector3(0, 0.8, 0)
	cam.look_at_from_position(alvo + Vector3(sin(deg_to_rad(ang)), 0, cos(deg_to_rad(ang))) * 2.6 + Vector3(0, alt, 0), alvo); cam.current = true
	for i in 3: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(saida + "/" + nome + ".png")
	cam.queue_free()
