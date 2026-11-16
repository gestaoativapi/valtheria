extends Node3D
# Valtheria V3 — AUT-021 D60/D61: teste do protótipo de porte de armas (não faz parte do jogo).
# Usa o personagem oficial (scripts/character.gd, sem alteração) e o controlador isolado porte_armas.gd.
# --modo=medidas : matriz arma x raça x escudo nas 28 animações (arma guardada): chão, pernas, tronco, cabeça, braços, escudo;
#                  e 100 alternâncias mão <-> guardada por configuração.
# --modo=capturas: imagens da arma guardada (repouso, caminhada, corrida, sentado, morte) e na mão (combate).
# Uso: godot --path . res://testes/prototipos/porte_armas_teste.tscn -- --modo=medidas --saida=<pasta>
const CS := preload("res://scripts/character.gd")
const Porte := preload("res://testes/prototipos/porte_armas.gd")
const V3 := "res://assets_v3/equipamentos/"
const ARMAS := ["espada_ng", "espada_longa", "adaga_ng", "punhal_ng", "machado_ng", "martelo_ng", "cajado_ng", "lanca_ng", "arco_ng", "espadao_ng", "cetro_ng", "duplas_ng"]
const RACAS := ["humano", "anao", "gigante"]
const CRITICO := 0.015      # penetração acima de 1,5 cm conta como interseção crítica
# cápsulas do corpo: osso a -> osso b, raio no tamanho de 1,80 m (multiplicado pela escala do osso)
const CAPS := [["thigh_l", "calf_l", 0.085, "pernas"], ["thigh_r", "calf_r", 0.085, "pernas"], ["calf_l", "foot_l", 0.06, "pernas"], ["calf_r", "foot_r", 0.06, "pernas"],
	["pelvis", "spine_02", 0.12, "tronco"], ["spine_02", "neck_01", 0.12, "tronco"], ["neck_01", "Head", 0.09, "cabeca"],
	["upperarm_l", "lowerarm_l", 0.045, "bracos"], ["upperarm_r", "lowerarm_r", 0.045, "bracos"], ["lowerarm_l", "hand_l", 0.04, "bracos"], ["lowerarm_r", "hand_r", 0.04, "bracos"]]
var modo := "medidas"
var saida := "user://porte"
var filtro_itens := []
var filtro_racas := []

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--modo="): modo = a.substr(7)
		if a.begins_with("--saida="): saida = a.substr(8)
		if a.begins_with("--itens="): filtro_itens = a.substr(8).split(",")
		if a.begins_with("--racas="): filtro_racas = a.substr(8).split(",")
	DirAccess.make_dir_recursive_absolute(saida)
	var w: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
	CS.RACES = w["races"]
	if modo == "capturas": await _capturas()
	elif modo == "ajuste": await _ajuste()
	else: await _medidas()
	get_tree().quit()

func _uma_mao(item: String) -> bool:
	var g: Dictionary = CS.GRIP[item.split("_")[0]]
	return float(g.get("two", 0.0)) <= 0.0 and not g.get("dual", false) and str(g.get("hand", "r")) == "r"

func criar(raca: String, item: String, escudo: bool) -> Array:
	var c: Node3D = CS.create({"race": raca, "gender": "m", "equipment": {"arma": item, "escudo": "escudo_ng" if escudo else ""}})
	add_child(c)
	if item == "espada_longa":   # modelo V3 da espada longa (P5) no lugar do modelo oficial, mesma pegada GRIP (len 1,0; at 0,1)
		var s := lerpf(1.0, c.height_m / 1.8, 0.85)
		for ch in c.wnode.get_children(): ch.queue_free()
		c.wnode.add_child(_place(V3 + "wp_espada_longa_b.glb", 1.0 * s, 0.1 * s))
	var p = Porte.new(c, item, escudo)
	return [c, p]

# cópia de character.gd _place com caminho completo (o oficial só lê assets/)
func _place(file: String, length: float, at: float) -> Node3D:
	var wm: Node3D = (load(file) as PackedScene).instantiate()
	var bb := AABB(); var first := true
	for m in wm.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (m as MeshInstance3D).transform * (m as MeshInstance3D).get_aabb()
		bb = a if first else bb.merge(a); first = false
	var axis := bb.get_longest_axis_index(); var k := length / bb.size[axis]
	var dir := Vector3.ZERO; dir[axis] = 1.0
	var far_pos: float = bb.position[axis] + bb.size[axis]; var far_neg: float = bb.position[axis]
	if absf(far_neg) > absf(far_pos): dir = -dir
	var handle: float = (far_neg if dir[axis] > 0.0 else far_pos)
	var off := bb.get_center(); off[axis] = handle + dir[axis] * at / k
	wm.transform = Transform3D(Basis(Quaternion(dir, Vector3(0, 0, 1))).scaled(Vector3.ONE * k), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -off)
	return wm

# pontos da malha da arma no espaço do nó da arma (wnode)
func pontos_arma(c: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var inv: Transform3D = c.wnode.global_transform.affine_inverse()
	for m in c.wnode.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.is_queued_for_deletion(): continue
		var x := inv * mi.global_transform
		for si in mi.mesh.get_surface_count():
			var v: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			var passo := maxi(1, v.size() / 300)
			for i in range(0, v.size(), passo): out.append(x * v[i])
	return out

func dist_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a; var t := clampf((p - a).dot(ab) / maxf(ab.dot(ab), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)

# transformação da arma guardada calculada pela pose do osso (sem esperar o BoneAttachment3D do próximo quadro)
func mundo_arma(c: Node3D, p) -> Transform3D:
	var sk: Skeleton3D = c.skel
	var att := p.suporte.get_parent() as BoneAttachment3D
	if att == null: return p.suporte.global_transform * c.wnode.transform
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(att.bone_name)) * p.suporte.transform * c.wnode.transform

func _medidas() -> void:
	var linhas := []
	for raca in RACAS:
		if filtro_racas.size() > 0 and not (raca in filtro_racas): continue
		for item in ARMAS:
			if filtro_itens.size() > 0 and not (item in filtro_itens): continue
			for escudo in ([false, true] if _uma_mao(item) else [false]):
				var cp := criar(raca, item, escudo); var c: Node3D = cp[0]; var p = cp[1]
				await get_tree().process_frame
				p.definir("guardada")
				await get_tree().process_frame
				var pts := pontos_arma(c)
				var sk: Skeleton3D = c.skel
				var pior := {"chao": 9.0, "pernas": 9.0, "tronco": 9.0, "cabeca": 9.0, "bracos": 9.0, "escudo": 9.0}
				var crit := {"chao": [], "pernas": [], "tronco": [], "cabeca": [], "bracos": [], "escudo": []}
				var pontos_usados := {}
				var escudo_aabb := AABB(); var escudo_mi: MeshInstance3D = null
				if escudo and c.shield != null:
					for m in c.shield.find_children("*", "MeshInstance3D", true, false):
						escudo_mi = m; escudo_aabb = (m as MeshInstance3D).get_aabb().grow(0.005); break
				var acoes := {}
				for an in c.anim.get_animation_list():
					if an == "RESET": continue
					var L: float = c.anim.get_animation(an).length
					var acao: String = p.acao_para(an)
					acoes[an] = acao
					if acao == "mao" or acao == "oculta": continue
					p.definir("guardada", an)
					pontos_usados[p.ponto_para(an) if acao == "porte" else "chao"] = true
					for q in 5:
						c.anim.play(an, 0.0); c.anim.seek(L * q / 4.0, true)
						var minimo := avaliar(c, p, pts, escudo_mi, escudo_aabb)
						for k in minimo.keys():
							pior[k] = minf(pior[k], minimo[k])
							if minimo[k] < -CRITICO and not (an in crit[k]): crit[k].append(an)
				# 100 alternâncias mão <-> guardada
				var falhas := 0
				for i in 100:
					p.definir("mao")
					if c.wnode.get_parent() != c.grip_node and c.wnode.get_parent() != c.guard: falhas += 1
					p.definir("guardada")
					if c.wnode.get_parent() != p.suporte: falhas += 1
				var lin := {"raca": raca, "item": item, "escudo": escudo, "altura_m": snappedf(c.height_m, 0.01), "ponto": p.ponto_nome, "motivo": p.motivo,
					"pontos_usados": pontos_usados.keys(), "acao_por_animacao": acoes, "folga_min_m": {}, "animacoes_criticas": crit, "alternancias": {"vezes": 100, "falhas": falhas, "suportes_criados": p.suportes.size()}}
				for k in pior.keys(): lin["folga_min_m"][k] = snappedf(pior[k], 0.001)
				var n_crit := 0
				for k in crit.keys(): n_crit += crit[k].size()
				lin["aprovado"] = n_crit == 0 and falhas == 0
				linhas.append(lin)
				print("PORTE ", raca, " ", item, " escudo=", escudo, " ponto=", p.ponto_nome, " (", p.motivo, ") criticos=", n_crit, " falhas=", falhas)
				c.queue_free()
				await get_tree().process_frame
	var f := FileAccess.open(saida + "/matriz_porte.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"criterio_critico_m": CRITICO, "configuracoes": linhas}, " "))

func avaliar(c: Node3D, p, pts: PackedVector3Array, escudo_mi: MeshInstance3D, escudo_aabb: AABB) -> Dictionary:
	var sk: Skeleton3D = c.skel
	var gx := sk.global_transform
	var W := mundo_arma(c, p)
	var caps := []
	for cap in CAPS:
		var ba := sk.find_bone(cap[0]); var bb := sk.find_bone(cap[1])
		if ba < 0 or bb < 0: continue
		var ga := gx * sk.get_bone_global_pose(ba); var gb := gx * sk.get_bone_global_pose(bb)
		caps.append([ga.origin, gb.origin, float(cap[2]) * ga.basis.get_scale().x, cap[3]])
	var Ws := Transform3D()
	if escudo_mi != null: Ws = escudo_mi.global_transform.affine_inverse()
	var minimo := {"chao": 9.0, "pernas": 9.0, "tronco": 9.0, "cabeca": 9.0, "bracos": 9.0, "escudo": 9.0}
	for pt in pts:
		var wp := W * pt
		minimo["chao"] = minf(minimo["chao"], wp.y)
		for cap in caps:
			minimo[cap[3]] = minf(minimo[cap[3]], dist_seg(wp, cap[0], cap[1]) - cap[2])
		if escudo_mi != null and escudo_aabb.has_point(Ws * wp): minimo["escudo"] = minf(minimo["escudo"], -0.05)
	return minimo

# varredura dos parâmetros de um ponto de cintura (melhor folga mínima nas animações em que a arma fica guardada)
func _ajuste() -> void:
	var res := {}
	for item: String in filtro_itens:
		var escudo := item.ends_with("+escudo"); var it := item.replace("+escudo", "")
		var cps := []
		for raca in RACAS:
			var cp := criar(raca, it, escudo); cps.append(cp)
			await get_tree().process_frame
			cp[1].definir("guardada"); await get_tree().process_frame
		var nome: String = str(cps[0][1].ponto_nome)
		var melhor := [-9.0, null, {}]
		var cands := []
		if str(cps[0][1]._cfg_ponto(nome)["osso"]) == "spine_03":
			for ox in [0.15, 0.22]:
				for oz in [-0.30, -0.36, -0.42]:
					for dv in [[-0.42, -0.9, 0.0], [-0.3, -0.95, 0.0], [-0.3, -0.95, -0.15], [-0.2, -1.0, -0.1]]:
						cands.append({"osso": "spine_03", "direcao_lamina": dv, "fora": [0, 0, -1], "deslocamento_cabo": [ox, 0.2, oz]})
		else:
			for ox in [0.2, 0.24, 0.28]:
				for oz in [-0.04, 0.04]:
					for dx in [0.05, 0.2, 0.35]:
						for dz in [-0.25, -0.5, -0.75]:
							cands.append({"osso": "pelvis", "direcao_lamina": [dx, -1.0, dz], "fora": [1, 0, 0], "deslocamento_cabo": [ox, 0.04, oz]})
		for cand in cands:
					if true:
						var pior := 9.0; var det := {}
						for cp in cps:
							var c: Node3D = cp[0]; var p = cp[1]
							p.dados["pontos"][nome] = cand
							for sp in p.suportes.values(): sp.get_parent().queue_free()
							p.suportes.clear(); p.definir("guardada")
							var pts := pontos_arma(c)
							var emi: MeshInstance3D = null; var eab := AABB()
							if escudo and c.shield != null:
								for m in c.shield.find_children("*", "MeshInstance3D", true, false):
									emi = m; eab = (m as MeshInstance3D).get_aabb().grow(0.005); break
							for an in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Interact", "Consume", "PickUp_Table", "Idle_Talking", "Dance", "Hit_Chest"]:
								if not c.anim.has_animation(an): continue
								for q in 3:
									pose(c, an, q / 2.0)
									var m := avaliar(c, p, pts, emi, eab)
									for k in ["pernas", "bracos", "tronco", "chao", "escudo"]:
										var v: float = m[k] if k != "chao" else m[k] - 0.0
										if v < pior: pior = v; det = {"anim": an, "parte": k}
						if pior > melhor[0]: melhor = [pior, cand, det]
		res[item] = {"ponto": nome, "folga_min_m": snappedf(melhor[0], 0.001), "melhor": melhor[1], "limite": melhor[2]}
		print("AJUSTE ", item, " ", res[item])
		for cp in cps: cp[0].queue_free()
		await get_tree().process_frame
	var f := FileAccess.open(saida + "/ajuste_cintura.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(res, " "))

# ---------------- capturas ----------------
func _luz() -> void:
	var sol := DirectionalLight3D.new(); sol.rotation_degrees = Vector3(-50, -35, 0); sol.shadow_enabled = true; add_child(sol)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.46, 0.5, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	add_child(env)
	var chao := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(8, 8); chao.mesh = pm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.35, 0.33, 0.3); chao.material_override = mat; add_child(chao)

func foto(nome: String, alvo: Vector3, dist: float, ang_y: float, alt: float) -> void:
	var cam := Camera3D.new(); add_child(cam); cam.fov = 40
	var d := Vector3(sin(deg_to_rad(ang_y)), 0, cos(deg_to_rad(ang_y))) * dist
	cam.look_at_from_position(alvo + d + Vector3(0, alt, 0), alvo); cam.current = true
	for i in 4: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(saida + "/" + nome + ".png")
	cam.queue_free()

func pose(c: Node3D, an: String, f: float) -> void:
	c.anim.play(an, 0.0); c.anim.seek(c.anim.get_animation(an).length * f, true); c.anim.pause()

func _capturas() -> void:
	_luz()
	var casos := [["humano", "espada_longa", false], ["humano", "espada_longa", true], ["humano", "espada_ng", true], ["humano", "adaga_ng", false],
		["humano", "punhal_ng", false], ["humano", "machado_ng", false], ["humano", "martelo_ng", false], ["humano", "cajado_ng", false],
		["humano", "lanca_ng", false], ["humano", "arco_ng", false], ["humano", "espadao_ng", false], ["humano", "cetro_ng", true],
		["anao", "espada_longa", false], ["anao", "machado_ng", true], ["gigante", "espada_longa", false], ["gigante", "lanca_ng", false]]
	var estados := [["Idle", 0.0, "repouso"], ["Walk", 0.5, "caminhada"], ["Sprint", 0.5, "corrida"], ["Sitting_Idle_Loop", 0.5, "sentado"], ["Death", 1.0, "morte"]]
	for cs in casos:
		var cp := criar(cs[0], cs[1], cs[2]); var c: Node3D = cp[0]; var p = cp[1]
		var h: float = c.height_m
		for e in estados:
			var an := str(e[0])
			if not c.anim.has_animation(an):
				for a in c.anim.get_animation_list():
					if a.begins_with(an): an = a; break
			if not c.anim.has_animation(an): continue
			p.definir("guardada", an); pose(c, an, e[1])
			var nome := "%s_%s%s_%s" % [cs[0], cs[1], "_escudo" if cs[2] else "", e[2]]
			if e[2] == "morte":
				await foto(nome + "_lado", Vector3(0, 0.3 * h / 1.8, 0), 3.2 * h / 1.8, 90, 1.6 * h / 1.8)
			else:
				await foto(nome + "_tras", Vector3(0, 0.95 * h / 1.8, 0), 3.0 * h / 1.8, 150, 0.2)
				await foto(nome + "_lado", Vector3(0, 0.95 * h / 1.8, 0), 3.0 * h / 1.8, 75, 0.2)
		p.definir("mao")
		var atk := "Sword_Attack" if c.anim.has_animation("Sword_Attack") else "Idle"
		pose(c, atk, 0.4)
		await foto("%s_%s%s_combate_mao" % [cs[0], cs[1], "_escudo" if cs[2] else ""], Vector3(0, 0.95 * h / 1.8, 0), 3.0 * h / 1.8, 40, 0.2)
		c.queue_free()
		await get_tree().process_frame
