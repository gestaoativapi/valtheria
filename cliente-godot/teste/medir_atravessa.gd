extends SceneTree
# Mede quanto a arma, o escudo e a mão atravessam o próprio corpo (tronco, peito, cabeça, coxas e canelas) ao longo
# do mesmo roteiro dos vídeos: parado > andando > correndo > guarda > correndo em combate > golpes > volta ao normal.
# O corpo vira cápsulas medidas na própria malha de cada raça (vértices de cada osso, em repouso).
# uso: --fixed-fps 30 -s teste/medir_atravessa.gd -- --lista=raca:g:arma:roupa:escudo,... [--saida=arquivo.json]
var q := 0
var lista := "humano:m:espada_ng:pesada_ng:escudo_ng"
var saida := ""
var bonecos: Array = []
const ROTEIRO := [[0, "Idle", false, "parado"], [45, "Walk", false, "andando"], [105, "Jog_Fwd", false, "correndo"], [150, "Idle", true, "guarda"], [195, "Jog_Fwd", true, "correndo_combate"], [240, "Idle", true, "guarda"], [255, "!Sword_Regular_A", true, "golpe"], [300, "!Sword_Regular_B", true, "golpe"], [345, "Walk", false, "andando"], [390, "Idle", false, "parado"]]
const FIM := 420
const SEGMENTOS := {
	"tronco": ["pelvis", "spine_03", ["pelvis", "spine_01", "spine_02"]],
	"peito": ["spine_03", "neck_01", ["spine_03"]],
	"cabeca": ["neck_01", "Head", ["neck_01", "Head"]],
	"coxa_l": ["thigh_l", "calf_l", ["thigh_l"]],
	"coxa_r": ["thigh_r", "calf_r", ["thigh_r"]],
	"canela_l": ["calf_l", "foot_l", ["calf_l"]],
	"canela_r": ["calf_r", "foot_r", ["calf_r"]],
}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lista="): lista = a.trim_prefix("--lista=")
		elif a.begins_with("--saida="): saida = a.trim_prefix("--saida=")


func _montar() -> void:
	var C = load("res://scripts/character.gd")
	var itens := lista.split(",")
	for i in itens.size():
		var p := itens[i].split(":")
		var eq := {"armadura": p[3] if p.size() > 3 else "leve_ng"}
		if p.size() > 2 and p[2] != "":
			eq["arma"] = p[2]
		if p.size() > 4 and p[4] != "":
			eq["escudo"] = p[4]
		var c: Node3D = C.create({"race": p[0], "gender": p[1], "equipment": eq})
		root.add_child(c)
		c.position = Vector3(i * 4.0, 0, 0)
		c.set_battle(false)
		bonecos.append({"c": c, "nome": itens[i], "raios": _raios(c), "att": _atts(c), "pontos": _pontos(c), "fases": {}})


func _atts(c: Node3D) -> Dictionary:
	var sk: Skeleton3D = c.skel
	var d := {}
	for s in SEGMENTOS.values():
		for b in [s[0], s[1]]:
			if not d.has(b):
				var at := BoneAttachment3D.new()
				at.bone_name = b
				sk.add_child(at)
				d[b] = at
	for b in ["middle_01_r", "hand_r"]:
		var at := BoneAttachment3D.new()
		at.bone_name = b
		sk.add_child(at)
		d[b] = at
	return d


# raio de cada cápsula: 60% dos vértices daquele osso ficam dentro (corpo + roupa, em repouso)
func _raios(c: Node3D) -> Dictionary:
	var sk: Skeleton3D = c.skel
	var dist := {}
	for k in SEGMENTOS:
		dist[k] = []
	var osso_seg := {}
	for k in SEGMENTOS:
		for b in SEGMENTOS[k][2]:
			osso_seg[sk.find_bone(b)] = k
	for m in c.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.skin == null or mi.name in ["olhos", "sobrancelha", "cilios", "cabelo"]:
			continue
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bs = arr[Mesh.ARRAY_BONES]
			var ws = arr[Mesh.ARRAY_WEIGHTS]
			if bs == null or ws == null or vs.size() == 0:
				continue
			var per: int = bs.size() / vs.size()
			for v in range(0, vs.size(), 3):
				var best := 0
				for j in per:
					if ws[v * per + j] > ws[v * per + best]:
						best = j
				var bind: int = bs[v * per + best]
				var bone: int = mi.skin.get_bind_bone(bind) if mi.skin.get_bind_bone(bind) >= 0 else sk.find_bone(mi.skin.get_bind_name(bind))
				if not osso_seg.has(bone):
					continue
				var k: String = osso_seg[bone]
				var a: Vector3 = sk.get_bone_global_rest(sk.find_bone(SEGMENTOS[k][0])).origin
				var b: Vector3 = sk.get_bone_global_rest(sk.find_bone(SEGMENTOS[k][1])).origin
				var pv: Vector3 = sk.get_bone_global_rest(bone) * (mi.skin.get_bind_pose(bind) * vs[v])
				dist[k].append(_dist_seg(pv, a, b))
	var r := {}
	var esc: float = _escala(c, sk)
	for k in dist:
		var l: Array = dist[k]
		l.sort()
		r[k] = (l[int(l.size() * 0.6)] if l.size() > 10 else 0.08) * esc
	return r


func _escala(c: Node3D, sk: Skeleton3D) -> float:
	return (c._rel_no(sk, c) as Transform3D).basis.get_scale().x


func _pontos(c: Node3D) -> Array:
	# vértices (amostra) da arma e do escudo, no espaço de cada malha
	var l := []
	for raiz in [c.wnode, c.shield]:
		if raiz == null:
			continue
		for m in (raiz as Node3D).find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var vs := PackedVector3Array()
			for si in mi.mesh.get_surface_count():
				vs.append_array(mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX])
			var passo := maxi(1, vs.size() / 120)
			var amostra := PackedVector3Array()
			for i in range(0, vs.size(), passo):
				amostra.append(vs[i])
			l.append([mi, amostra, "escudo" if raiz == c.shield else "arma"])
	return l


static func _dist_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _medir(bo: Dictionary, fase: String) -> void:
	var att: Dictionary = bo.att
	var raios: Dictionary = bo.raios
	var pior := {"arma": 0.0, "escudo": 0.0, "mao": 0.0}
	var onde := {"arma": "", "escudo": "", "mao": ""}
	var testar := func(p: Vector3, tipo: String) -> void:
		for k in SEGMENTOS:
			var a: Vector3 = (att[SEGMENTOS[k][0]] as Node3D).global_position
			var b: Vector3 = (att[SEGMENTOS[k][1]] as Node3D).global_position
			if k == "cabeca":
				b += (b - a).normalized() * float(raios[k]) * 1.2
			var dentro: float = float(raios[k]) * 0.92 - _dist_seg(p, a, b)
			if dentro > pior[tipo]:
				pior[tipo] = dentro
				onde[tipo] = k
	for item in bo.pontos:
		var mi: MeshInstance3D = item[0]
		if not is_instance_valid(mi) or not mi.is_visible_in_tree():
			continue
		var gt := mi.global_transform
		for v in (item[1] as PackedVector3Array):
			testar.call(gt * v, item[2])
	var palma: Vector3 = ((att["hand_r"] as Node3D).global_position + (att["middle_01_r"] as Node3D).global_position) * 0.5
	testar.call(palma, "mao")
	var f: Dictionary = bo.fases.get(fase, {"quadros": 0})
	f.quadros = int(f.quadros) + 1
	for tipo in pior:
		if pior[tipo] > 0.01:
			f[tipo + "_quadros"] = int(f.get(tipo + "_quadros", 0)) + 1
			f[tipo + "_max_cm"] = maxf(float(f.get(tipo + "_max_cm", 0.0)), snappedf(pior[tipo] * 100.0, 0.1))
			var lug: Dictionary = f.get(tipo + "_onde", {})
			lug[onde[tipo]] = int(lug.get(onde[tipo], 0)) + 1
			f[tipo + "_onde"] = lug
	bo.fases[fase] = f


var fase_atual := "parado"


func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		_montar()
		return false
	var f := q - 2
	for r in ROTEIRO:
		if f == int(r[0]):
			fase_atual = str(r[3])
			for bo in bonecos:
				var c = bo.c
				c.set_battle(bool(r[2]))
				c.em_guarda = bool(r[2])
				if str(r[1]).begins_with("!"):
					if c.arqueria != null:  # arqueiro: o golpe dele é o tiro (puxa a corda até o queixo), como no jogo
						c.disparar_arco()
					else:
						c.action(str(r[1]).substr(1))
				else:
					c.play(str(r[1]))
	if f > 5:
		for bo in bonecos:
			_medir(bo, fase_atual)
	if f >= FIM:
		var out := {}
		for bo in bonecos:
			var fs := {}
			for k in bo.fases:
				var d: Dictionary = bo.fases[k]
				var e := {}
				for tipo in ["arma", "escudo", "mao"]:
					if d.has(tipo + "_quadros"):
						e[tipo] = {"pct": snappedf(100.0 * float(d[tipo + "_quadros"]) / float(d.quadros), 1), "max_cm": d[tipo + "_max_cm"], "onde": d[tipo + "_onde"]}
				fs[k] = e
			out[bo.nome] = {"corr": [bo.c.empunho.correcoes_mao, bo.c.empunho.correcoes_lamina, bo.c.empunho.residuo_mao] if bo.c.empunho != null else [], "fases": fs, "raios_cm": (bo.raios as Dictionary).keys().map(func(k): return "%s=%d" % [k, int(bo.raios[k] * 100)])}
		var txt := JSON.stringify(out, "  ")
		print("RESULTADO_ATRAVESSA ", txt)
		if saida != "":
			var fa := FileAccess.open(saida, FileAccess.WRITE)
			fa.store_string(txt)
			fa.close()
		quit()
	return false
