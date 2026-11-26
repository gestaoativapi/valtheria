extends SceneTree
# Mede o quanto o pé de apoio escorrega no chão com o personagem andando/correndo de verdade (como no jogo).
# Para cada corpo e velocidade: em cada apoio (pé no ponto mais baixo), quanto o pé andou no chão, em cm.
# uso: --fixed-fps 60 -s teste/medir_escorrega.gd -- [--lista=raca:g,...] [--antigo] [--saida=/tmp/escorrega.json]

const CASOS := [["andar", 1.5], ["ronda", 1.35], ["correr", 5.2], ["disparar", 6.5]]
var lista := "humano:m,humano:f,elfo:m,elfo:f,sombrio:m,sombrio:f,orc:m,orc:f,anao:m,anao:f,gigante:m,gigante:f"
var saida := "/tmp/escorrega.json"
var antigo := false
var bonecos: Array = []
var q := 0
const QUADROS := 240
var dados := {}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lista="): lista = a.trim_prefix("--lista=")
		elif a.begins_with("--saida="): saida = a.trim_prefix("--saida=")
		elif a == "--antigo": antigo = true
		elif a.begins_with("--k="): load("res://scripts/character.gd").AJUSTE_K = float(a.trim_prefix("--k="))


func _process(dt: float) -> bool:
	q += 1
	if q == 1:
		var C = load("res://scripts/character.gd")
		C.SINCRONIA_PASSADA = not antigo
		var i := 0
		for it in lista.split(","):
			var p := it.split(":")
			var c: Node3D = C.create({"race": p[0], "gender": p[1], "equipment": {"armadura": "leve_ng"}})
			root.add_child(c)
			var pes := {}
			for lado in ["l", "r"]:
				var b := BoneAttachment3D.new()
				b.bone_name = "ball_" + lado
				c.skel.add_child(b)
				pes[lado] = b
			bonecos.append({"c": c, "nome": it, "pes": pes, "x": i * 4.0})
			i += 1
		return false
	var k := q - 2
	var ci := k / (QUADROS + 30)
	var f := k % (QUADROS + 30)
	if ci >= CASOS.size():
		_fim()
		quit()
		return true
	var caso: Array = CASOS[ci]
	var v: float = caso[1]
	for bo in bonecos:
		var c: Node3D = bo.c
		if f == 0:
			c.position = Vector3(bo.x, 0, 0)
		if antigo:  # como era antes de 26/11 (main.gd/npcs.gd)
			if caso[0] == "andar":
				c.play("Walk", 1.1)
			elif caso[0] == "ronda":
				c.play("Walk", 1.0)
			else:
				c.play("Jog_Fwd", v / 5.2)
		else:
			c.mover(v, "andar" if v < 2.6 else "correr")
		c.position.z += v * dt
		if f < 30:
			continue
		var chave: String = bo.nome + "|" + caso[0]
		if not dados.has(chave):
			dados[chave] = {"l": [], "r": [], "anim": "", "ritmo": 0.0}
		dados[chave].anim = c.current
		dados[chave].ritmo = snappedf(c.anim.speed_scale, 0.01)
		for lado in ["l", "r"]:
			(dados[chave][lado] as Array).append((bo.pes[lado] as Node3D).global_position)
	return false


func _fim() -> void:
	var out := {}
	var linhas := []
	for chave in dados:
		var d: Dictionary = dados[chave]
		var desl := []
		for lado in ["l", "r"]:
			var pts: Array = d[lado]
			var ys: Array = pts.map(func(p): return (p as Vector3).y)
			var s := ys.duplicate()
			s.sort()
			var corte: float = maxf(s[int(s.size() * 0.25)], s[0] + 0.03)
			var i := 0
			while i < pts.size():
				if float(ys[i]) <= corte:
					var j := i
					while j < pts.size() and float(ys[j]) <= corte:
						j += 1
					if j - i >= 3:
						var a: Vector3 = pts[i]
						var b: Vector3 = pts[j - 1]
						desl.append(Vector2(b.x - a.x, b.z - a.z).length() * 100.0)
					i = j
				else:
					i += 1
		var media := 0.0
		for x in desl:
			media += x
		media /= maxf(desl.size(), 1)
		out[chave] = {"cm_por_passo": snappedf(media, 0.1), "passos": desl.size(), "anim": d.anim, "ritmo": d.ritmo}
		linhas.append("ESCORREGA %-20s %-11s ritmo=%.2f  %5.1f cm/passo (%d passos)" % [chave, d.anim, d.ritmo, media, desl.size()])
	linhas.sort()
	for l in linhas:
		print(l)
	var fa := FileAccess.open(saida, FileAccess.WRITE)
	fa.store_string(JSON.stringify(out, "  "))
	fa.close()
