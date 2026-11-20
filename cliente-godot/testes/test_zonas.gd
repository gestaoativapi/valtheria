extends SceneTree
# Zonas de paz e de batalha (19/11): cidade e povoado = paz; masmorra e campo = batalha; dano anulado na paz.
var main: Node
var f := 0

func _initialize() -> void:
	main = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	f += 1
	if f < 30:
		return false
	var w = main.world
	var ruins := 0
	for caso in [[1500, 2550, true, "Vila Aurora"], [1500, 1985, true, "Valtheria Real"], [1180, 2250, false, "Castelo dos Corvos"], [1300, 2450, false, ""]]:
		var z: Dictionary = w.zona(float(caso[0]), float(caso[1]))
		var ok: bool = bool(z.paz) == bool(caso[2]) and str(z.nome) == str(caso[3])
		print("%s: paz=%s nome='%s' %s" % [str(caso[3]), str(z.paz), str(z.nome), "ok" if ok else "ERRADO"])
		if not ok:
			ruins += 1
	print("RESULTADO: " + ("PASSOU" if ruins == 0 else "FALHOU"))
	quit(0 if ruins == 0 else 1)
	return true
