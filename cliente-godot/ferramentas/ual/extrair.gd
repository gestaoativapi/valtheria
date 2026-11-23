extends SceneTree
const PEGAR := {
	"UAL1_Standard.glb": ["Roll", "Hit_Head", "Sword_Idle", "Walk_Formal", "Jump_Start", "Jump", "Jump_Land", "Spell_Simple_Enter", "Spell_Simple_Exit", "Crouch_Idle", "Crouch_Fwd"],
	"UAL2_Standard.glb": ["Hit_Knockback", "Sword_Heavy_Combo", "Sword_Regular_Combo", "Sword_Dash", "Shield_Dash", "Melee_Hook", "Idle_Shield_Break", "Sword_Regular_A_Rec", "Sword_Regular_B_Rec"],
}
func _init():
	var lib := AnimationLibrary.new()
	for f in PEGAR:
		var sc: Node = (load("res://" + f) as PackedScene).instantiate()
		var ap := sc.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for n in PEGAR[f]:
			if not ap.has_animation(n):
				print("FALTA ", n); continue
			var a: Animation = ap.get_animation(n).duplicate(true)
			var nome: String = n.trim_suffix("_Loop")
			a.loop_mode = Animation.LOOP_LINEAR if n in ["Walk_Formal","Jump","Crouch_Idle","Crouch_Fwd","Sword_Idle"] else Animation.LOOP_NONE
			lib.add_animation(nome, a)
			print(nome, " ", snappedf(a.length, 0.01), "s trilhas ", a.get_track_count(), " ex: ", a.track_get_path(0))
		sc.free()
	print(ResourceSaver.save(lib, "res://anims_c.res", ResourceSaver.FLAG_COMPRESS))
	quit()
