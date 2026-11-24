extends Node
# Liga/desliga as partículas fixas do cenário (grupo "cull_particulas", ver FX.cull) pela distância
# até a câmera. Longe: invisível e sem processar (não gasta CPU). Confere 2,5 vezes por segundo.
# Também marca os personagens longe (grupo "personagens"): os ajustes finos do esqueleto (pés no chão, mãos,
# postura, punho, empunhadura) param a mais de LOD_BONECO metros, onde ninguém percebe.
var t := 0.0
const LOD_BONECO := 35.0


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
	for c in get_tree().get_nodes_in_group("personagens"):
		var pe := c as Node3D
		if pe == null or not pe.is_inside_tree():
			continue
		var sk = pe.get("skel")
		if sk == null or not is_instance_valid(sk):
			continue
		# "sem_lod": testes que medem o ajuste fino de perto (pés no chão em vários lugares do mapa)
		var longe := not pe.has_meta("sem_lod") and pe.global_position.distance_squared_to(p) > LOD_BONECO * LOD_BONECO
		if bool(sk.get_meta("lod_longe", false)) != longe:
			sk.set_meta("lod_longe", longe)
