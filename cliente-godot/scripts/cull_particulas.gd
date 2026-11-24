extends Node
# Liga/desliga as partículas fixas do cenário (grupo "cull_particulas", ver FX.cull) pela distância
# até a câmera. Longe: invisível e sem processar (não gasta CPU). Confere 2,5 vezes por segundo.
var t := 0.0


func _process(dt: float) -> void:
	t -= dt
	if t > 0.0:
		return
	t = 0.4
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.global_position
	for n in get_tree().get_nodes_in_group("cull_particulas"):
		var no := n as Node3D
		if no == null or not no.is_inside_tree():
			continue
		var d: float = no.get_meta("cull_dist", 70.0)
		var perto := no.global_position.distance_squared_to(p) < d * d
		if no.visible != perto:
			no.visible = perto
			no.process_mode = Node.PROCESS_MODE_INHERIT if perto else Node.PROCESS_MODE_DISABLED
