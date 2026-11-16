extends Node3D
# Valtheria V3 — AUT-023: perfilamento do controlador das túnicas (AUT-022 × otimizado), por pose, P1 e P2.
# Mede µs por avaliação (CPU, script) e confere que os pesos do otimizado batem com os do controlador de referência.
# Uso: godot --headless --path . res://testes/prototipos/perfil_rbf.tscn -- --saida=<pasta>
const V3 := "res://assets_v3/personagens/"
const CS := preload("res://scripts/character.gd")
const Ref := preload("res://testes/prototipos/corretivas_controlador.gd")
const Opt := preload("res://testes/prototipos/corretivas_controlador_otimizado.gd")
const POSES := [["Idle", 0.0], ["Walk", 0.25], ["Jog_Fwd", 0.25], ["Sprint", 0.25], ["Sitting_Idle", 0.5], ["Farm_Harvest", 0.5],
	["OverhandThrow", 0.5], ["Sword_Attack", 0.5], ["Sword_Regular_A", 0.5], ["Sword_Regular_B", 0.5], ["Sword_Regular_C", 0.5], ["Death01", 0.5]]
const N := 500
var saida := "user://perfil"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="): saida = a.substr(8)
	DirAccess.make_dir_recursive_absolute(saida)
	var r := {}
	for g in ["m", "f"]:
		var body: Node3D = (load(V3 + "pc_humano_%s.glb" % g) as PackedScene).instantiate(); add_child(body)
		var skel := body.find_child("Skeleton3D", true, false) as Skeleton3D
		var src: Node3D = (load(V3 + "rp_aldeao_tunica_%s_rbf.glb" % g) as PackedScene).instantiate()
		var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
		mi.get_parent().remove_child(mi); mi.owner = null; skel.add_child(mi); mi.skeleton = NodePath("..")
		src.free()
		var anim := AnimationPlayer.new(); body.add_child(anim); anim.add_animation_library("", CS._clips(skel, ""))
		var ref = Ref.new(); add_child(ref); ref.configurar(skel, mi); ref.carregar_rbf(V3 + "rp_aldeao_tunica_%s_rbf.rbf.json" % g); ref.set_process(false)
		var opt = Opt.new(); add_child(opt); opt.configurar(skel, mi); opt.carregar_rbf(V3 + "rp_aldeao_tunica_%s_rbf.rbf.json" % g); opt.set_process(false)
		var linhas := []
		for p in POSES:
			var an := str(p[0])
			for a in anim.get_animation_list():
				if a.begins_with(an): an = a; break
			if not anim.has_animation(an): continue
			anim.play(an, 0.0); anim.seek(anim.get_animation(an).length * float(p[1]), true); anim.pause()
			ref.aplicar(); var w_ref: Dictionary = ref.ultimo.duplicate()
			opt.atual.fill(-1.0); opt.aplicar(); var w_opt: Dictionary = opt.ultimo.duplicate()
			var dif := 0.0
			for k in w_ref.keys(): dif = maxf(dif, absf(float(w_ref[k]) - float(w_opt.get(k, 0.0))))
			var t0 := Time.get_ticks_usec()
			for i in N: ref.aplicar()
			var t1 := Time.get_ticks_usec()
			opt.usar_condicional = false
			for i in N: opt.aplicar()
			var t2 := Time.get_ticks_usec()
			opt.usar_condicional = true; var antes: int = int(opt.avaliacoes_rbf)
			Opt.us_angulos = 0; Opt.us_aplicar = 0; Opt.us_rbf = 0; Opt.avaliacoes = 0
			for i in N: opt.aplicar()
			var t3 := Time.get_ticks_usec()
			linhas.append({"pose": an, "us_referencia": snappedf((t1 - t0) / float(N), 0.1), "us_otimizado_sempre": snappedf((t2 - t1) / float(N), 0.1),
				"us_otimizado_condicional": snappedf((t3 - t2) / float(N), 0.1), "rbf_ativo": opt.avaliacoes_rbf > antes, "dif_max_pesos": snappedf(dif, 0.0001),
				"partes_us": [snappedf(Opt.us_angulos / float(N), 0.1), snappedf(Opt.us_aplicar / float(N), 0.1), snappedf(Opt.us_rbf / float(N), 0.1)], "ang": str(opt.ang_ultimo)})
			print("PERFIL ", g, " ", linhas[-1])
		r[g] = linhas
		body.queue_free(); ref.queue_free(); opt.queue_free()
		await get_tree().process_frame
	var f := FileAccess.open(saida + "/perfil_rbf.json", FileAccess.WRITE); f.store_string(JSON.stringify(r, " "))
	get_tree().quit()
