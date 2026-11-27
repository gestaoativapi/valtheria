extends MeshInstance3D
# Rastro de luz da Relíquia (27/11): faixa entre o cabo e a ponta da arma que segue o golpe e some
# do fim para o começo. Uma malha imediata por golpe, sem luz dinâmica (só aditivo sem sombra).

const AMOSTRAS := 18

var arma: Node3D
var base_l := Vector3.ZERO   # pontos no espaço local da arma
var ponta_l := Vector3.ZERO
var cor := Color.WHITE
var brilho := Color.WHITE
var dura := 0.4
var _t := 0.0
var _pts: Array = []  # [[base, ponta, idade], ...] em coordenadas do mundo
var _im := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = false
	material_override = m


func _process(dt: float) -> void:
	_t += dt
	if arma != null and is_instance_valid(arma) and arma.is_inside_tree() and _t < dura:
		var g := arma.global_transform
		_pts.push_front([g * base_l, g * ponta_l, 0.0])
	for p in _pts:
		p[2] += dt
	while _pts.size() > AMOSTRAS or (_pts.size() > 0 and float(_pts[-1][2]) > 0.3):
		_pts.pop_back()
	_im.clear_surfaces()
	if _pts.size() >= 2:
		_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in _pts.size():
			var f := 1.0 - float(i) / float(_pts.size() - 1)
			var a := f * clampf(1.0 - float(_pts[i][2]) / 0.3, 0.0, 1.0)
			var b: Vector3 = _pts[i][0]
			var pt: Vector3 = _pts[i][1]
			# a parte de dentro (perto do cabo) é mais fraca; a ponta é quase branca
			_im.surface_set_color(Color(cor.r, cor.g, cor.b, a * 0.45))
			_im.surface_add_vertex(b.lerp(pt, 0.35))
			_im.surface_set_color(Color(brilho.r, brilho.g, brilho.b, a * 0.9))
			_im.surface_add_vertex(pt)
		_im.surface_end()
	if _t >= dura and _pts.is_empty():
		queue_free()
