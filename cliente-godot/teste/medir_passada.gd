extends SceneTree
# Mede a velocidade "natural" de cada animação de andar/correr em cada corpo: com o personagem parado no lugar,
# o pé que está apoiado no chão anda para trás na velocidade em que o corpo deveria avançar para o pé não escorregar.
# Compara com a velocidade que o jogo usa (andar 1,9 m/s, correr 5,2 m/s, ronda 1,35 m/s) e o ritmo que ele dá à
# animação, e diz quanto o pé escorrega em cada caso.
# uso: --fixed-fps 60 -s teste/medir_passada.gd -- [--lista=raca:g,...] [--saida=arquivo.json]

const ANIMS := ["Walk", "Walk_Formal", "Jog_Fwd", "Sprint"]
var lista := "humano:m,humano:f,elfo:m,elfo:f,sombrio:m,sombrio:f,orc:m,orc:f,anao:m,anao:f,gigante:m,gigante:f"
var saida := "/tmp/passada.json"
var bonecos: Array = []
var q := 0
var fase := 0
var amostras := {}
const QUADROS := 300  # 2,5 s por animação a 60 qps


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lista="): lista = a.trim_prefix("--lista=")
		elif a.begins_with("--saida="): saida = a.trim_prefix("--saida=")


func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		var C = load("res://scripts/character.gd")
		var i := 0
		for it in lista.split(","):
			var p := it.split(":")
			var c: Node3D = C.create({"race": p[0], "gender": p[1], "equipment": {"armadura": "leve_ng"}})
			root.add_child(c)
			c.position = Vector3(i * 4.0, 0, 0)
			var pes := {}
			for lado in ["l", "r"]:
				var b := BoneAttachment3D.new()
				b.bone_name = "ball_" + lado
				c.skel.add_child(b)
				pes[lado] = b
			bonecos.append({"c": c, "nome": it, "pes": pes})
			i += 1
		return false
	if q < 10:
		return false
	var k := q - 10
	var anim_i := k / (QUADROS + 20)
	var f := k % (QUADROS + 20)
	if anim_i >= ANIMS.size():
		_fim()
		quit()
		return true
	var an: String = ANIMS[anim_i]
	if f == 0:
		for bo in bonecos:
			var c: Node3D = bo.c
			c.current = ""
			c.play(an, 1.0)
			c.anim.speed_scale = 1.0  # ritmo puro da animação (sem o ciclo da raça) para medir a passada natural
	if f < 20:
		return false
	for bo in bonecos:
		var c: Node3D = bo.c
		var chave: String = bo.nome + "|" + an
		if not amostras.has(chave):
			amostras[chave] = {"l": [], "r": [], "anim": c.current, "ciclo": c.ciclo_raca}
		for lado in ["l", "r"]:
			var p: Vector3 = (bo.pes[lado] as Node3D).global_position - c.global_position
			(amostras[chave][lado] as Array).append(p)
	return false


func _fim() -> void:
	var out := {}
	var dt := 1.0 / 60.0
	for chave in amostras:
		var s: Dictionary = amostras[chave]
		var vel := []
		var altura_min := 99.0
		for lado in ["l", "r"]:
			for p in s[lado]:
				altura_min = minf(altura_min, (p as Vector3).y)
		# pé de apoio: o mais baixo dos dois, enquanto estiver a até 2,5 cm do ponto mais baixo
		var n: int = (s.l as Array).size()
		for i in range(1, n):
			var pl: Vector3 = s.l[i]
			var pr: Vector3 = s.r[i]
			var lado := "l" if pl.y < pr.y else "r"
			var a: Vector3 = s[lado][i - 1]
			var b: Vector3 = s[lado][i]
			if b.y - altura_min > 0.025:
				continue
			vel.append(-(b.z - a.z) / dt)
		vel.sort()
		var natural := 0.0
		if vel.size() > 4:
			natural = vel[vel.size() / 2]  # mediana, à prova de quadros de troca de pé
		# conferência: amplitude do pé (frente-trás) e período do ciclo
		var zs: Array = (s.l as Array).map(func(p): return (p as Vector3).z)
		var zmin: float = zs.min()
		var zmax: float = zs.max()
		var zm := (zmin + zmax) * 0.5
		var cruz := []
		for i in range(1, zs.size()):
			if zs[i - 1] < zm and zs[i] >= zm:
				cruz.append(i)
		var periodo := 0.0
		if cruz.size() >= 2:
			periodo = float(cruz[-1] - cruz[0]) / (cruz.size() - 1) * dt
		var xs: Array = (s.l as Array).map(func(p): return (p as Vector3).x)
		print("CONF ", chave, " z=", snappedf(zmin, 0.01), "..", snappedf(zmax, 0.01), " x=", snappedf(xs.min(), 0.01), "..", snappedf(xs.max(), 0.01), " periodo=", snappedf(periodo, 0.01), " passo/periodo=", snappedf((zmax - zmin) * 2.0 / maxf(periodo, 0.01), 0.01))
		out[chave] = {"anim": s.anim, "natural_ms": snappedf(natural, 0.01), "ciclo_raca": s.ciclo, "amostras": vel.size(), "l": (s.l as Array).map(func(p): return [snappedf(p.x, 0.0001), snappedf(p.y, 0.0001), snappedf(p.z, 0.0001)]), "r": (s.r as Array).map(func(p): return [snappedf(p.x, 0.0001), snappedf(p.y, 0.0001), snappedf(p.z, 0.0001)])}
	var fa := FileAccess.open(saida, FileAccess.WRITE)
	fa.store_string(JSON.stringify(out, "  "))
	fa.close()
	# resumo: velocidade natural x velocidade do jogo
	for chave in out:
		var o: Dictionary = out[chave]
		var jogo := 0.0
		var ritmo := 0.0
		if chave.ends_with("|Walk"):
			jogo = 1.9
			ritmo = 1.1 * float(o.ciclo_raca) * (1.08 if o.anim == "Walk_Formal" else 1.0)
		else:
			jogo = 5.2
			ritmo = 1.0 * float(o.ciclo_raca)
		var pe := float(o.natural_ms) * ritmo
		var esc := 0.0 if jogo <= 0.0 else (jogo - pe) / jogo * 100.0
		print("PASSADA %-22s %-12s natural=%.2f m/s  pé no jogo=%.2f m/s  corpo=%.2f m/s  escorrega=%+.0f%%" % [chave, o.anim, o.natural_ms, pe, jogo, esc])
