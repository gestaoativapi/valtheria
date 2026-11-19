extends Control
# Fôlego (estamina): correr (Shift), nadar em água funda e planar gastam; descansar recupera.
# O máximo cresce com o nível. Quando acaba: corrida para, nado fica lento, planador fecha.
# Planador: ao cair de um barranco (mais de 2,5 m), aperte Espaço no ar para abrir.

const GASTO_CORRIDA := 16.0
const GASTO_NADO := 5.0
const GASTO_PLANAR := 9.0
const RECUPERA := 24.0
const ESPERA := 0.8
const GRAVIDADE := 18.0
const QUEDA_PLANANDO := 2.4

var main: Node
var maximo := 100.0
var atual := 100.0
var _parado := 0.0
var correndo := false
var no_ar := false
var planando := false
var vy := 0.0
var _mostrar := 0.0
var asa: Node3D


func setup(m: Node) -> void:
	main = m
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func atualizar_maximo(nivel: int) -> void:
	maximo = 100.0 + 1.5 * float(maxi(nivel - 1, 0))   # cresce com o nível (nv 80 = 218)
	atual = minf(atual, maximo)


# multiplicador de velocidade do passo (chamado pelo movimento a cada quadro)
func passo(dt: float, quer_correr: bool, andando: bool, nadando: bool) -> float:
	var mult := 1.0
	var gastou := false
	correndo = false
	if planando:
		atual -= GASTO_PLANAR * dt * (0.5 if main.player.get("asas") != null else 1.0)
		gastou = true
		if atual <= 0.0:
			fechar_planador()
	elif nadando:
		if main.world.height(main.player.position.x, main.player.position.z) < main.world.WATER_Y - 2.0:
			atual -= GASTO_NADO * dt
			gastou = true
			if atual <= 0.0:
				mult = 0.6   # cansado: nada devagar
	elif quer_correr and andando and atual > 0.0:
		atual -= GASTO_CORRIDA * dt
		gastou = true
		correndo = true
		mult = 1.55
	if gastou:
		_parado = 0.0
		_mostrar = 2.0
	else:
		_parado += dt
		if _parado > ESPERA:
			atual += RECUPERA * dt
	atual = clampf(atual, 0.0, maximo)
	if atual < maximo:
		_mostrar = 2.0
	_mostrar = maxf(0.0, _mostrar - dt)
	queue_redraw()
	return mult


# altura do corpo com queda livre ou planador; chamado depois de mover no plano
func altura(dt: float, chao: float) -> float:
	var y: float = main.player.position.y
	if not no_ar:
		if y - chao > 2.5:   # saiu de um barranco ou de uma ponte: começa a cair
			no_ar = true
			vy = 0.0
		else:
			return chao
	if planando:
		# dragonita cai mais devagar com as asas abertas
		vy = -QUEDA_PLANANDO * (0.6 if main.player.get("asas") != null else 1.0)
	else:
		vy -= GRAVIDADE * dt
	y += vy * dt
	if y <= chao:
		no_ar = false
		fechar_planador()
		return chao
	return y


func tentar_planar() -> bool:
	if no_ar and not planando and atual > 5.0:
		planando = true
		_asa(true)
		return true
	if planando:
		fechar_planador()
		return true
	return false


func fechar_planador() -> void:
	if planando:
		planando = false
		_asa(false)


func _asa(on: bool) -> void:
	if asa != null:
		asa.queue_free()
		asa = null
	var dr = main.player.get("asas") if main.player != null else null
	if dr != null:
		# dragonita plana com as próprias asas (D5): sem planador de lona
		dr.estado = "planar" if on else ("combate" if main.player.get("armed") else "dobrada")
		return
	if not on:
		return
	# planador simples de lona e varetas sobre os ombros
	asa = Node3D.new()
	var lona := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(2.6, 0.5, 0.9)
	lona.mesh = pm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(0.82, 0.74, 0.55)
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	lona.material_override = mt
	lona.position = Vector3(0, 2.1, -0.1)
	lona.rotation_degrees = Vector3(-12, 0, 0)
	asa.add_child(lona)
	main.player.add_child(asa)


func _draw() -> void:
	if main == null or main.player == null or _mostrar <= 0.0:
		return
	var cam: Camera3D = main.cam
	var cabeca: Vector3 = main.player.position + Vector3(0, main.player.height_m * 0.6, 0)
	if cam.is_position_behind(cabeca):
		return
	var c := cam.unproject_position(cabeca) + Vector2(60, 0)
	var f := atual / maximo
	var cor := Color(0.45, 0.95, 0.4) if f > 0.25 else Color(1.0, 0.45, 0.25)
	cor.a = minf(1.0, _mostrar)
	draw_arc(c, 18, -PI * 0.5, -PI * 0.5 + TAU, 40, Color(0, 0, 0, 0.45 * cor.a), 6.0, true)
	draw_arc(c, 18, -PI * 0.5, -PI * 0.5 + TAU * f, 40, cor, 5.0, true)
