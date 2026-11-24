extends SkeletonModifier3D
# Gesto mágico das habilidades (pedido de Robson 21/11): cada habilidade tem um movimento do corpo, por cima
# das 28 animações oficiais (sem alterá-las), que muda com a raça e com o sexo.
# Um gesto é um conjunto de ângulos por osso no auge do movimento; entra, segura e sai em curva suave.
# Convenção dos ângulos (graus):
#   frente (coluna, pescoço, cabeça): + inclina para a frente, − abre o peito para trás
#   ergue (braço): + levanta o braço pela lateral;  avanca (braço): + leva o braço para a frente
#   dobra (antebraço, mão): + dobra;  perna: + perna à frente;  joelho: + dobra

const OSSOS := {
	"pelvis": "frente", "spine_01": "frente", "spine_02": "frente", "spine_03": "frente", "neck_01": "frente", "Head": "frente",
	"upperarm_l": "braco", "upperarm_r": "braco", "lowerarm_l": "dobra", "lowerarm_r": "dobra", "hand_l": "dobra", "hand_r": "dobra",
	"thigh_l": "perna", "thigh_r": "perna", "calf_l": "joelho", "calf_r": "joelho",
}

# gestos: osso (sem lado quando vale para os dois; _l/_r para um só) -> [ergue, avanca] nos braços ou graus nos demais
const GESTOS := {
	"empurrar": {"upperarm": [35, 70], "lowerarm": 10, "spine_03": 8, "Head": -5},          # projétil: as duas mãos à frente
	"apontar": {"upperarm_r": [40, 80], "lowerarm_r": 5, "upperarm_l": [10, -10], "spine_03": 5},  # um braço estendido
	"erguer": {"upperarm": [165, 0], "lowerarm": 15, "spine_03": -14, "neck_01": -10, "Head": -18},  # mãos ao céu
	"abrir": {"upperarm": [85, -10], "lowerarm": 5, "spine_03": -12, "Head": -12},           # peito aberto (reforço)
	"prece": {"upperarm": [25, 55], "lowerarm": 95, "hand": 20, "spine_02": 8, "Head": 18},   # mãos unidas (cura)
	"cravar": {"upperarm": [120, 60], "lowerarm": 20, "spine_02": 28, "thigh": 25, "calf": 40},  # golpe no chão
	"girar": {"upperarm": [70, 10], "spine_02": 10, "thigh": 10, "calf": 15},               # giro com a arma
	"investir": {"upperarm_r": [30, 60], "spine_02": 22, "thigh_r": 35, "calf_l": 30},       # avanço
	"rugir": {"upperarm": [55, -25], "lowerarm": 40, "spine_03": -18, "neck_01": -15, "Head": -25},  # grito de guerra
	"golpe": {"upperarm_r": [60, 40], "lowerarm_r": 30, "spine_02": 12},                     # golpe forte
}

# estilo por raça: amplitude e duração (mais pesado e lento no orc e no gigante, mais rápido no elfo)
const RACA := {"humano": [1.0, 1.0], "elfo": [0.95, 0.85], "sombrio": [1.05, 0.9], "orc": [1.2, 1.15], "anao": [0.9, 1.05],
	"beastman": [1.2, 0.95], "draconato": [1.12, 1.05], "gigante": [1.15, 1.25]}

var raca := "humano"
var feminino := false
var _alvo := {}       # osso -> Vector2 (ergue, avanca) ou float
var _t := 0.0
var _dur := 0.0
var _gira := 0.0      # giro do corpo inteiro (gesto "girar")
var _ids := {}
var _base := {}
var _ultimo := {}


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for b in OSSOS:
		var i := sk.find_bone(b)
		if i >= 0:
			_ids[b] = i


func ativo() -> bool:
	return _t < _dur


# inicia um gesto; devolve a duração usada
func tocar(nome: String, dur := 0.9) -> float:
	var g: Dictionary = GESTOS.get(nome, GESTOS.empurrar)
	var est: Array = RACA.get(raca, [1.0, 1.0])
	var amp: float = est[0]
	_dur = dur * float(est[1])
	_t = 0.0
	_alvo.clear()
	for k in g:
		var v = g[k]
		var nomes: Array = [k] if (k.ends_with("_l") or k.ends_with("_r") or not k in ["upperarm", "lowerarm", "hand", "thigh", "calf"]) else [k + "_l", k + "_r"]
		for n in nomes:
			if v is Array:
				var e: float = float(v[0]) * amp
				var a: float = float(v[1]) * amp
				if feminino:  # mais junto do corpo, com o antebraço mais curvo: gesto mais leve
					e *= 0.88
					a *= 0.95
				_alvo[n] = Vector2(e, a)
			else:
				var d: float = float(v) * amp
				if feminino and n.begins_with("lowerarm"):
					d += 12.0
				_alvo[n] = d
	if feminino and nome in ["abrir", "erguer", "prece"]:
		_alvo["pelvis"] = -4.0  # leve inclinação do quadril
	_gira = TAU if nome == "girar" else 0.0
	return _dur


func _peso() -> float:
	if _dur <= 0.0:
		return 0.0
	var u := clampf(_t / _dur, 0.0, 1.0)
	# entra rápido (25%), segura e sai suave
	if u < 0.25:
		return smoothstep(0.0, 1.0, u / 0.25)
	if u < 0.6:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (u - 0.6) / 0.4)


func _process_modification_with_delta(delta: float) -> void:
	var __t := Time.get_ticks_usec()
	_pm_corpo(delta)
	preload("res://scripts/perfil.gd").soma("esq_gesto_magico", Time.get_ticks_usec() - __t)


func _pm_corpo(delta: float) -> void:
	var sk := get_skeleton()
	if sk != null and sk.get_meta("lod_longe", false):  # longe da câmera: ajuste fino desligado (economiza CPU)
		return
	if sk == null or _t >= _dur:
		return
	_t += delta
	var w := _peso()
	if _gira != 0.0:
		var no := sk.get_parent()
		while no != null and not (no is Node3D and no.has_method("tocar_gesto")):
			no = no.get_parent()
		if no != null:
			(no as Node3D).rotation.y += _gira * delta / maxf(_dur, 0.1)
	for b in _alvo:
		if not _ids.has(b):
			continue
		var i: int = _ids[b]
		var lado := 1.0 if b.ends_with("_l") else -1.0
		var q := Quaternion.IDENTITY
		var v = _alvo[b]
		if v is Vector2:
			# ergue: gira pela frente (eixo "para trás" do osso); avança: gira em torno do eixo vertical
			q = Quaternion(Vector3.BACK, lado * deg_to_rad(v.x) * w) * Quaternion(Vector3.UP, -lado * deg_to_rad(v.y) * w)
		else:
			var ang := deg_to_rad(float(v)) * w
			match OSSOS.get(b, "frente"):
				"frente", "joelho":
					q = Quaternion(Vector3.RIGHT, ang)
				"dobra", "perna":
					q = Quaternion(Vector3.RIGHT, -ang)
		var pai := sk.get_bone_parent(i)
		var gp := sk.get_bone_global_pose(pai).basis.get_rotation_quaternion() if pai >= 0 else Quaternion.IDENTITY
		var local := sk.get_bone_pose_rotation(i)
		if _ultimo.has(i) and local.is_equal_approx(_ultimo[i]):
			local = _base[i]  # sem animação tocando, parte da pose original (não soma quadro a quadro)
		_base[i] = local
		var novo := (gp.inverse() * q * gp * local).normalized()
		_ultimo[i] = novo
		sk.set_bone_pose_rotation(i, novo)
