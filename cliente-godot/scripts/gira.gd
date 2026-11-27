extends Node
# gira o nó pai em volta do próprio eixo Z (coroa de runas das relíquias SS)
var velocidade := 1.0


func _process(dt: float) -> void:
	var p := get_parent() as Node3D
	if p != null and p.is_visible_in_tree():
		p.rotate_object_local(Vector3.BACK, velocidade * dt)
