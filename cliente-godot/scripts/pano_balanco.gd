extends Node3D
# Pano que balança (capa, capa de pele): pêndulo com mola em vez de peça dura (pedido de Robson 24/11).
# Correndo a capa vai para trás, virando ela abre para o lado, parando ela volta balançando e assenta.
# Nunca entra nas pernas (inclinação mínima para trás) nem no chão (a borda de baixo fica acima do piso).
var dono: Node3D
var ancora: Node3D         # osso das costas (BoneAttachment): a capa acompanha o tronco quando ele inclina
var _off := Vector3.INF    # posição da capa em relação à âncora, no espaço do dono (medida no 3º quadro)
var _q := 0
var altura := 1.0          # comprimento do pano (m), da borda de cima até a de baixo
var base := Vector2(0.16, 0.0)  # inclinação de repouso (x: para trás, z: de lado), em radianos
var _ang := Vector2.ZERO
var _vel := Vector2.ZERO
var _pos_ant := Vector3.INF
var _giro_ant := 0.0


func _ready() -> void:
	_ang = base


func _process(dt: float) -> void:
	if dono == null or dt <= 0.0:
		return
	if ancora != null and is_instance_valid(ancora):
		var pai := get_parent() as Node3D
		_q += 1
		if _off == Vector3.INF and _q >= 3:
			_off = dono.global_transform.basis.inverse() * (pai.global_position - ancora.global_position)
		if _off != Vector3.INF:
			pai.global_position = ancora.global_position + dono.global_transform.basis * _off
	var p := dono.global_position
	var vfrente := 0.0
	var vlado := 0.0
	var giro := dono.global_rotation.y
	if _pos_ant != Vector3.INF:
		var v := (p - _pos_ant) / dt
		var b := dono.global_transform.basis
		vfrente = v.dot(b.z.normalized())
		vlado = v.dot(b.x.normalized())
	var dgiro := wrapf(giro - _giro_ant, -PI, PI) / dt
	_pos_ant = p
	_giro_ant = giro
	# alvo: para trás com a velocidade, de lado com o passo lateral e com a virada
	var alvo := base + Vector2(clampf(vfrente * 0.11, -0.05, 0.95), clampf(-vlado * 0.08 + dgiro * 0.06, -0.45, 0.45))
	var acc := (alvo - _ang) * 38.0 - _vel * 7.5
	_vel += acc * minf(dt, 0.05)
	_ang += _vel * minf(dt, 0.05)
	_ang.x = maxf(_ang.x, 0.08)  # nunca para dentro das pernas
	# borda de baixo acima do chão (agachado, rolando, ladeira)
	var topo := global_position.y
	var chao := dono.global_position.y + 0.04
	var limite := topo - chao
	if limite < altura:
		var minimo := acos(clampf(limite / maxf(altura, 0.01), -1.0, 1.0))
		_ang.x = maxf(_ang.x, minimo)
	rotation = Vector3(_ang.x, 0.0, _ang.y)
