extends SceneTree
# Sonda do tiro de arco: posições (espaço do personagem) do ombro, cotovelo e mão da corda, cabeça e polo, quadro a quadro.
# uso: --fixed-fps 30 -s teste/sonda_arco.gd -- --lista=raca:g [--quadros=a,b,c]
var q := 0
var lista := "humano:m"
var quadros := [12, 18, 22, 26]
var c: Node3D
var ja := false


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lista="): lista = a.trim_prefix("--lista=")
		elif a.begins_with("--quadros="): quadros = Array(a.trim_prefix("--quadros=").split(",")).map(func(x): return int(x))


var att := {}
func _p(n: String) -> Vector3:
	if not att.has(n):
		var b := BoneAttachment3D.new()
		b.bone_name = n
		c.skel.add_child(b)
		att[n] = b
		return Vector3.ZERO
	return c.global_transform.affine_inverse() * (att[n] as Node3D).global_position


func _process(_d: float) -> bool:
	q += 1
	if q == 1:
		var p := lista.split(":")
		c = load("res://scripts/character.gd").create({"race": p[0], "gender": p[1], "equipment": {"armadura": "leve_ng", "arma": "arco_ng"}})
		root.add_child(c)
		c.set_battle(false)
	if q == 3:
		for n in ["upperarm_r", "lowerarm_r", "hand_r", "Head", "upperarm_l", "hand_l"]:
			_p(n)
	if q == 5:
		c.set_battle(true)
		c.disparar_arco()
	var a0: Node3D = c.arqueria if q > 5 else null
	var cheio: bool = a0 != null and a0.t >= 0.585 and not ja
	if cheio: ja = true
	if q in quadros or cheio:
		var a: Node3D = c.arqueria
		var f := func(v: Vector3) -> String: return "(%5.2f %5.2f %5.2f)" % [v.x, v.y, v.z]
		print("Q%d t=%.2f ombroR%s cotov%s mao%s cab%s ombroL%s maoL%s polo%s alvo%s" % [q, a.t, f.call(_p("upperarm_r")), f.call(_p("lowerarm_r")), f.call(_p("hand_r")), f.call(_p("Head")), f.call(_p("upperarm_l")), f.call(_p("hand_l")), f.call(a.polo_r.position) if a.polo_r else "-", f.call(a.mao_corda.position)])
		var hb: Basis = (c.global_transform.affine_inverse() * (att["Head"] as Node3D).global_transform).basis.orthonormalized()
		print("   cabeça eixos x%s y%s z%s" % [f.call(hb.x), f.call(hb.y), f.call(hb.z)])
	return q >= quadros.max() and ja
