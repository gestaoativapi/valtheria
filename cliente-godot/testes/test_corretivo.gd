extends SceneTree
# 27/11: a forma corretiva do arco (data/corpos/arco_<corpo>.bin) tem que bater com o corpo atual.
# Se o corpo (.glb) mudar, refazer com teste/corretivo_arco.gd; senão o ombro ficaria sem a correção.
func _init() -> void:
	var C = load("res://scripts/character.gd")
	var falhas := 0
	for k in ["humano", "elfo", "sombrio", "orc", "gigante", "anao"]:
		for g in ["m", "f"]:
			var arq := "res://data/corpos/arco_%s_%s.bin" % [k, g]
			var cena: Node = (load("res://assets/chars/body_%s_%s.glb" % [k, g]) as PackedScene).instantiate()
			var mi: MeshInstance3D = null
			for m in cena.find_children("*", "MeshInstance3D", true, false):
				if (m as MeshInstance3D).skin != null and (mi == null or (m as MeshInstance3D).mesh.surface_get_array_len(0) > mi.mesh.surface_get_array_len(0)):
					mi = m
			var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var fa := FileAccess.open(arq, FileAccess.READ)
			var d: Dictionary = fa.get_var() if fa else {}
			var ok: bool = not d.is_empty() and int(d.get("n", -1)) == v.size() and str(d.get("assinatura", "")) == C.assinatura_malha(v)
			if not ok:
				print("DESATUALIZADA: ", arq)
				falhas += 1
			cena.free()
	print("RESULTADO: " + ("PASSOU" if falhas == 0 else "FALHOU"))
	quit()
