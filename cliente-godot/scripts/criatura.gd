extends Node3D
# Criatura de modelo próprio (CC0, pasta assets/monstros): golem, yeti, lobisomem...
# Os modelos vêm só com andar e correr; parado, ataque, golpe recebido e morte são feitos aqui por
# movimento do corpo inteiro (respiração, investida, recuo e queda), sem trocar o esqueleto.

# id do monstro -> [arquivo em assets/monstros, altura em metros na escala 1]
const MODELOS := {
	"golem": ["stone_golem", 2.5],
	"golem_anc": ["stone_golem", 2.5],
}

var ap: AnimationPlayer
var pivo: Node3D      # gira a partir dos pés (investida, queda)
var modelo: Node3D
var altura := 2.0
var estado_atual := "idle"
var t := 0.0
var tw: Tween


static func tem(id: String) -> bool:
	return MODELOS.has(id)


# monta a criatura; devolve o nó raiz (este script) já na escala do jogo
static func criar(id: String, escala: float) -> Node3D:
	var c: Node3D = load("res://scripts/criatura.gd").new()
	c.name = "Criatura_" + id
	var cfg: Array = MODELOS[id]
	c.pivo = Node3D.new()
	c.add_child(c.pivo)
	c.modelo = (load("res://assets/monstros/%s.glb" % cfg[0]) as PackedScene).instantiate()
	c.pivo.add_child(c.modelo)
	var caixa := _caixa_ossos(c.modelo)
	var alvo := float(cfg[1]) * escala
	var k := alvo / maxf(caixa.size.y, 0.01)
	c.modelo.scale = Vector3.ONE * k
	c.modelo.position.y = -caixa.position.y * k
	c.altura = alvo
	for mi in c.modelo.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).extra_cull_margin = alvo   # a caixa da malha com pele não segue a pose
	c.ap = c.modelo.find_child("AnimationPlayer", true, false)
	if c.ap != null:
		for n in c.ap.get_animation_list():
			c.ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	return c


# altura pelos ossos (a caixa da malha com pele ignora a escala interna do esqueleto)
static func _caixa_ossos(raiz: Node3D) -> AABB:
	var a := AABB()
	var primeiro := true
	for sk in raiz.find_children("*", "Skeleton3D", true, false):
		var k := sk as Skeleton3D
		var xf := Transform3D.IDENTITY
		var n: Node = k
		while n != null and n != raiz:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for b in k.get_bone_count():
			var p := xf * k.get_bone_global_rest(b).origin
			a = AABB(p, Vector3.ZERO) if primeiro else a.merge(AABB(p, Vector3.ZERO))
			primeiro = false
	return a.grow(a.size.y * 0.06)


func estado(o_que: String) -> void:
	if ap == null:
		return
	if tw != null and tw.is_valid() and estado_atual == "death":
		return
	estado_atual = o_que
	match o_que:
		"idle":
			ap.play("walk", 0.3)
			ap.speed_scale = 0.0   # pose parada de pé; a respiração é feita em _process
			ap.seek(0.0, true)
		"walk":
			ap.play("walk", 0.2)
			ap.speed_scale = 1.0
		"run":
			ap.play("run" if ap.has_animation("run") else "walk", 0.2)
			ap.speed_scale = 1.0
		"attack":
			_golpe(0.42, altura * 0.12, 0.22, 0.38)
		"hit":
			_golpe(-0.16, -altura * 0.04, 0.08, 0.2)
		"death":
			ap.speed_scale = 0.0
			_novo_tween()
			tw.set_parallel(true)
			tw.tween_property(pivo, "rotation:x", -PI * 0.47, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(pivo, "position:y", -altura * 0.08, 0.9)


func _novo_tween() -> void:
	if tw != null and tw.is_valid():
		tw.kill()
	tw = create_tween()


# investida (ângulo > 0 inclina para a frente) com avanço e volta
func _golpe(ang: float, avanco: float, ida: float, volta: float) -> void:
	_novo_tween()
	tw.set_parallel(true)
	tw.tween_property(pivo, "rotation:x", ang, ida).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivo, "position:z", avanco, ida)
	tw.chain().set_parallel(true)
	tw.tween_property(pivo, "rotation:x", 0.0, volta).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pivo, "position:z", 0.0, volta)


func _process(dt: float) -> void:
	t += dt
	if estado_atual == "idle" and modelo != null:
		# respiração e balanço leve do corpo parado
		pivo.scale = Vector3(1.0, 1.0 + sin(t * 1.7) * 0.012, 1.0)
		pivo.rotation.z = sin(t * 0.9) * 0.02
	elif estado_atual != "death":
		pivo.scale = Vector3.ONE
		pivo.rotation.z = 0.0
