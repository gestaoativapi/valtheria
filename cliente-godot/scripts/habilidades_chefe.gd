extends RefCounted
# Habilidades dos chefes (decisão D7 de Robson + especificação MESA-015.1 do ChatGPT, 18/11).
# Cada chefe tem 3 habilidades liberadas por fase de vida (100-60, 60-30, 30-0; as anteriores continuam).
# Antes de cada golpe aparece o aviso no chão (círculo ou cone que se enche) pelo tempo "aviso";
# quem sair da marca não toma o golpe. Roda na simulação local de combate (a mesma dos monstros hoje):
# é o teste local pedido em D7. Nada aqui toca no servidor de produção.

const FX = preload("res://scripts/fx.gd")
static var _dados := {}

const AVISO_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 cor : source_color = vec4(1.0, 0.25, 0.1, 1.0);
uniform float progresso = 0.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	// UV.x = distância do centro (0..1); a frente de preenchimento anda do centro para fora
	float r = UV.x;
	float borda = smoothstep(0.9, 1.0, r);
	float cheio = step(r, progresso);
	float pulso = 0.5 + 0.5 * sin(TIME * 10.0);
	ALBEDO = cor.rgb;
	ALPHA = clamp(0.12 + cheio * 0.3 + borda * (0.5 + 0.3 * pulso), 0.0, 0.9);
}
"""
static var _aviso_shader: Shader


static func dados() -> Dictionary:
	if _dados.is_empty():
		var f := FileAccess.open("res://data/habilidades_chefes.json", FileAccess.READ)
		if f:
			_dados = JSON.parse_string(f.get_as_text())
	return _dados


static func lista(id: String) -> Array:
	return (dados().get("chefes", {}) as Dictionary).get(id, [])


static func _na_fase(h: Dictionary, vida: float) -> bool:
	match str(h.fase):
		"100-60":
			return true
		"60-30":
			return vida <= 0.6
		_:
			return vida <= 0.3


# malha do aviso: disco (área) ou leque (cone) deitado no chão, UV.x = distância relativa ao centro
static func _malha_aviso(tipo: String, raio: float, alcance: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 40
	var a0 := 0.0
	var a1 := TAU
	var r := raio
	if tipo == "cone":
		var meia := atan2(raio, alcance)
		a0 = -meia
		a1 = meia
		r = alcance
	for anel in 6:
		var t0 := float(anel) / 6.0
		var t1 := float(anel + 1) / 6.0
		for k in n:
			var b0 := lerpf(a0, a1, float(k) / n)
			var b1 := lerpf(a0, a1, float(k + 1) / n)
			var p := [Vector3(sin(b0) * r * t0, 0, cos(b0) * r * t0), Vector3(sin(b1) * r * t0, 0, cos(b1) * r * t0),
				Vector3(sin(b0) * r * t1, 0, cos(b0) * r * t1), Vector3(sin(b1) * r * t1, 0, cos(b1) * r * t1)]
			var u := [t0, t0, t1, t1]
			for i in [0, 2, 1, 1, 2, 3]:
				st.set_uv(Vector2(u[i], 0))
				st.add_vertex(p[i])
	return st.commit()


static func _cor(elem: String) -> Color:
	match elem:
		"fogo":
			return Color(1.0, 0.35, 0.08)
		"terra":
			return Color(0.85, 0.55, 0.2)
		"natureza", "veneno":
			return Color(0.45, 0.95, 0.25)
		"gelo":
			return Color(0.5, 0.85, 1.0)
		"arcano":
			return Color(0.75, 0.45, 1.0)
		"vento":
			return Color(0.85, 0.95, 1.0)
	return Color(1.0, 0.3, 0.2)


# chamado a cada quadro para um chefe em combate; devolve true enquanto estiver lançando (não ataca normal)
static func tick(c: Node, m: Dictionary, dt: float) -> bool:
	var hs := lista(str(m.fam.id))
	if hs.is_empty():
		return false
	# relógio próprio do chefe em tempo de jogo (soma de dt): independe do relógio do sistema
	if m.has("hab"):
		m.hab.relogio = float(m.hab.relogio) + dt
	var t: float = float(m.hab.relogio) if m.has("hab") else 0.0
	if not m.has("hab"):
		m.hab = {"cd": {}, "lanca": null, "buff_ate": 0.0, "atk_base": float(m.atk), "relogio": 0.0}
		for h in hs:
			m.hab.cd[h.id] = t + (0.5 if str(m.spot) == "gm" else 4.0 + randf() * 4.0)   # primeira habilidade alguns segundos depois do início
	var hab: Dictionary = m.hab
	if float(hab.buff_ate) > 0.0 and t > float(hab.buff_ate):
		hab.buff_ate = 0.0
		m.atk = float(hab.atk_base)
	var l = hab.lanca
	if l != null:
		var dur: float = float(l.h.aviso)
		var prog := clampf((t - float(l.t0)) / dur, 0.0, 1.0)
		if is_instance_valid(l.no):
			((l.no as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("progresso", prog)
		if prog >= 1.0:
			_executar(c, m, l)
			hab.lanca = null
		return true
	var vida: float = float(m.hp) / maxf(float(m.maxHp), 1.0)
	var pp: Vector3 = c.main.player.position
	var node: Node3D = m.node
	var d := Vector2(pp.x - node.position.x, pp.z - node.position.z).length()
	for h in hs:
		if not _na_fase(h, vida) or t < float(hab.cd[h.id]):
			continue
		var alcance: float = float(h.alcance)
		if str(h.tipo) != "buff" and str(h.tipo) != "invocacao" and d > alcance + 1.0:
			continue
		_comecar(c, m, h, pp)
		hab.cd[h.id] = t + float(h.recarga)
		return true
	return false


static func _comecar(c: Node, m: Dictionary, h: Dictionary, alvo: Vector3) -> void:
	var node: Node3D = m.node
	var tipo := str(h.tipo)
	node.rotation.y = atan2(alvo.x - node.position.x, alvo.z - node.position.z)
	var centro := node.position
	var giro := node.rotation.y
	var raio := float(h.raio)
	if tipo in ["area", "projetil"] and float(h.alcance) > float(h.raio) * 1.5:
		centro = Vector3(alvo.x, alvo.y, alvo.z)   # golpe à distância: cai onde o jogador estava
	if tipo in ["buff", "invocacao"]:
		raio = maxf(raio, 3.0)
	if _aviso_shader == null:
		_aviso_shader = Shader.new()
		_aviso_shader.code = AVISO_SHADER
	var mi := MeshInstance3D.new()
	mi.mesh = _malha_aviso("cone" if tipo == "cone" else "area", raio, float(h.alcance))
	var mat := ShaderMaterial.new()
	mat.shader = _aviso_shader
	var cor := _cor(str(h.elem))
	if tipo == "buff" or tipo == "invocacao":
		cor = Color(1.0, 0.85, 0.3)
	mat.set_shader_parameter("cor", cor)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	c.add_child(mi)
	mi.global_position = Vector3(centro.x, c.world.height(centro.x, centro.z) + 0.08, centro.z)
	mi.rotation.y = giro
	c._float_text(node.position + Vector3(0, float(m.height) + 0.6, 0), str(h.nome), Color(1.0, 0.85, 0.4))
	c._mob_anim(m, "attack")
	m.hab.lanca = {"h": h, "t0": float(m.hab.relogio), "no": mi, "centro": centro, "giro": giro, "raio": raio}


static func _dentro(l: Dictionary, p: Vector3) -> bool:
	var h: Dictionary = l.h
	var c: Vector3 = l.centro
	var v := Vector2(p.x - c.x, p.z - c.z)
	if str(h.tipo) == "cone":
		if v.length() > float(h.alcance):
			return false
		var frente := Vector2(sin(float(l.giro)), cos(float(l.giro)))
		return v.length() < 0.5 or absf(frente.angle_to(v.normalized())) <= atan2(float(h.raio), float(h.alcance))
	return v.length() <= float(l.raio)


static func _executar(c: Node, m: Dictionary, l: Dictionary) -> void:
	var h: Dictionary = l.h
	var tipo := str(h.tipo)
	if is_instance_valid(l.no):
		(l.no as Node).queue_free()
	var centro: Vector3 = l.centro
	var y: float = c.world.height(centro.x, centro.z)
	match tipo:
		"buff":
			# fase final: o chefe muda (fica mais forte por 12 s) e explode a aura
			m.hab.buff_ate = float(m.hab.relogio) + 12.0
			m.atk = float(m.hab.atk_base) * 1.3
			FX.burst(c, (m.node as Node3D).position + Vector3(0, float(m.height) * 0.6, 0), str(h.elem), 2.4)
			c._float_text((m.node as Node3D).position + Vector3(0, float(m.height) + 1.0, 0), "FÚRIA", Color(1.0, 0.3, 0.2))
			return
		"invocacao":
			# chama 2 crias da mesma região perto do chefe
			var fams: Array = (c.info.mobs as Array).reduce(func(acc, b): return acc + (b as Array), [])
			var cria: Dictionary = {}
			for f in fams:
				if str(f.id) == "aranha":
					cria = f
			for k in 2:
				var a := randf() * TAU
				var p := (m.node as Node3D).position + Vector3(sin(a), 0, cos(a)) * 4.0
				c._spawn(p.x, p.z, false, 0, "", cria)
			FX.burst(c, centro + Vector3(0, 0.5, 0), str(h.elem), 1.6)
			return
	# golpe: efeito no chão e dano em quem ficou na marca
	var tam: float = clampf(float(l.raio) * 0.35, 0.8, 3.0)
	if tipo == "cone":
		for k in 4:
			var dist := float(h.alcance) * (0.25 + k * 0.22)
			FX.burst(c, centro + Vector3(sin(float(l.giro)) * dist, 0.6, cos(float(l.giro)) * dist), str(h.elem), tam)
	else:
		if tipo == "projetil":
			FX.bolt(c, (m.node as Node3D).position + Vector3(0, float(m.height) * 0.7, 0), Vector3(centro.x, y + 0.5, centro.z), str(h.elem))
		FX.burst(c, Vector3(centro.x, y + 0.5, centro.z), str(h.elem), tam)
	var pp: Vector3 = c.main.player.position
	if not _dentro(l, pp):
		c._float_text(pp + Vector3(0, 2.0, 0), "esquivou", Color(0.7, 0.9, 1.0))
		return
	var atk: float = float(m.atk) * float(h.dano_pct) / 100.0
	var dmg: float = atk * atk / (atk + float(c.st.pdef) * 0.5)
	c._hurt_player(dmg)
	var db: Array = h.debuff
	if str(db[0]) != "nenhum":
		c.aplicar_debuff(str(db[0]), float(db[1]), float(db[2]), (m.node as Node3D).position)
