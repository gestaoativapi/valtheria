extends RefCounted
# Valtheria V3 — AUT-021 D60/D61: controlador EXPERIMENTAL de porte de armas, orientado por dados.
# Cópia isolada da lógica de _make_sheath()/set_battle() do character.gd, lida de assets_v3/equipamentos/porte_armas.json.
# NÃO altera o character.gd: usa o personagem oficial como está e só troca o pai da arma (wnode) quando guardada.
# Precedência do ponto de porte: item > tipo > regra por comprimento; com escudo, a tabela "com_escudo" troca o ponto.

const CS := preload("res://scripts/character.gd")
const V3 := "res://assets_v3/equipamentos/"
var dados: Dictionary
var c: Node3D                 # personagem oficial (scripts/character.gd)
var item := ""
var kind := ""
var comprimento := 0.0
var tem_escudo := false
var ponto_nome := ""
var motivo := ""
var suporte: Node3D           # ponto de porte atual (filho de um BoneAttachment3D)
var suportes := {}            # nome do ponto -> Node3D
var estado := ""
var raca := "humano"

func _init(personagem: Node3D, item_id: String, escudo: bool, raca_id := "humano") -> void:
	raca = raca_id
	dados = JSON.parse_string(FileAccess.get_file_as_string(V3 + "porte_armas.json"))
	c = personagem; item = item_id; kind = item_id.split("_")[0]; tem_escudo = escudo
	comprimento = float(CS.GRIP[kind]["len"]) if CS.GRIP.has(kind) else 0.0
	ponto_nome = resolver()

# regra de decisão (sem efeito colateral): devolve o nome do ponto e guarda o motivo
func resolver() -> String:
	var p := ""
	var itens: Dictionary = dados["itens"]; var tipos: Dictionary = dados["tipos"]; var rp: Dictionary = dados["regra_padrao"]
	var chave_item := ""
	for k in itens.keys():
		if item.begins_with(k): chave_item = k
	if chave_item != "":
		p = str(itens[chave_item]["ponto"]); motivo = "item:" + chave_item
		if tem_escudo and itens[chave_item].has("com_escudo"):
			return _com(str(itens[chave_item]["com_escudo"]), "item:%s+escudo" % chave_item)
	elif _da_raca("tipos").has(kind):   # AUT-022: sobrescrita por raça (antes do tipo geral)
		p = str(_da_raca("tipos")[kind]["ponto"]); motivo = "raca:%s/tipo:%s" % [raca, kind]
	elif tipos.has(kind):
		p = str(tipos[kind]["ponto"]); motivo = "tipo:" + kind
	else:
		p = str(rp["ponto_longo"] if comprimento > float(rp["comprimento_costas_m"]) else rp["ponto_curto"])
		motivo = "comprimento:%.2f m" % comprimento
	if tem_escudo and _da_raca("com_escudo").has(p):
		return _com(str(_da_raca("com_escudo")[p]), motivo + "+escudo(raça)")
	if tem_escudo and dados["com_escudo"].has(p):
		return _com(str(dados["com_escudo"][p]), motivo + "+escudo")
	return p

func _com(p: String, m: String) -> String:
	motivo = m; return p

func _da_raca(chave: String) -> Dictionary:
	return dados.get("racas", {}).get(raca, {}).get(chave, {})

func _cfg_ponto(nome: String) -> Dictionary:
	if _da_raca("pontos").has(nome): return _da_raca("pontos")[nome]   # ajuste do ponto para o corpo da raça
	var pt: Dictionary = dados["pontos"][nome]
	if pt.has("de_arquivo"):   # ponto definido no arquivo do item (relação com espada_longa.json)
		var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(V3 + str(pt["de_arquivo"])))
		var b: Dictionary = cfg[str(pt["chave"])]
		return {"osso": b["osso"], "direcao_lamina": b["direcao_lamina"], "deslocamento_cabo": b["deslocamento_cabo"], "fora": pt["fora"]}
	return pt

# monta (uma vez) o suporte do ponto pedido, pela mesma construção de _make_sheath
func _suporte(nome: String) -> Node3D:
	if suportes.has(nome): return suportes[nome]
	var pt := _cfg_ponto(nome)
	var skel: Skeleton3D = c.skel
	var bone := skel.find_bone(str(pt["osso"]))
	var gb := skel.get_bone_global_rest(bone)
	var att := BoneAttachment3D.new(); att.bone_name = str(pt["osso"]); att.name = "porte_" + nome
	skel.add_child(att)
	var k: float = c.height_m / 1.8
	var d: Array = pt["direcao_lamina"]; var o: Array = pt["deslocamento_cabo"]; var f: Array = pt["fora"]
	var blade := Vector3(d[0], d[1], d[2]).normalized()
	var out := Vector3(f[0], f[1], f[2])
	var handle := gb.origin + Vector3(o[0], o[1], o[2]) * k
	var x := out.cross(blade).normalized(); var y := blade.cross(x).normalized()
	var s := Node3D.new(); s.name = "suporte"
	s.transform = Transform3D(gb.basis.inverse() * Basis(x, y, blade), gb.affine_inverse() * handle)
	att.add_child(s)
	suportes[nome] = s
	return s

func _estado_de(anim_nome: String) -> String:
	for e in dados["estados"].keys():
		for a in dados["estados"][e]["animacoes"]:
			if anim_nome.begins_with(str(a)): return e
	return ""

# ponto efetivo para uma animação (sentado: arma longa da cintura vai para as costas, exceto com escudo nas costas)
func ponto_para(anim_nome: String) -> String:
	var e: Dictionary = dados["estados"]["sentado"]
	if _estado_de(anim_nome) == "sentado" and str(_cfg_ponto(ponto_nome)["osso"]) == "pelvis" and comprimento > float(e["comprimento_m"]):
		if not (tem_escudo and bool(e["exceto_com_escudo"])):
			return str(dados["regra_padrao"]["ponto_longo"])
	return ponto_nome

# o que acontece com a arma guardada nesta animação: "porte" | "mao" | "oculta" | "chao"
func acao_para(anim_nome: String) -> String:
	match _estado_de(anim_nome):
		"combate": return "mao"
		"trabalho": return "oculta" if comprimento > float(dados["estados"]["trabalho"]["comprimento_m"]) else "porte"
		"morte": return "chao"
		"sentado":
			var e: Dictionary = dados["estados"]["sentado"]
			if comprimento > float(e.get("ocultar_acima_de_m", 99.0)): return "oculta"
			if str(_cfg_ponto(ponto_nome)["osso"]) == "pelvis" and comprimento > float(e["comprimento_m"]) and tem_escudo and bool(e["exceto_com_escudo"]):
				return "oculta"   # com escudo nas costas não há lugar livre: a arma longa some enquanto senta
	return "porte"

# estado: "mao" (regra oficial: set_battle(true)) ou "guardada" (ponto deste protótipo, conforme a animação)
func definir(novo: String, anim_nome := "") -> void:
	if c.wnode == null: return
	c.wnode.visible = true
	if novo == "mao":
		_desprender(); c.set_battle(true)
	else:
		if c.armed: c.set_battle(false)          # desliga guarda/IK e leva a arma para a bainha oficial
		var acao := acao_para(anim_nome)
		var alvo: Node3D
		if acao == "chao":
			alvo = _no_chao()
		else:
			alvo = _suporte(ponto_para(anim_nome))
			c.wnode.visible = acao != "oculta"
		if c.wnode.get_parent() != alvo:
			c.wnode.get_parent().remove_child(c.wnode); alvo.add_child(c.wnode)
		suporte = alvo
	estado = novo

# ponto no chão ao lado do corpo (morte): arma deitada, paralela ao corpo, 0,75 m à direita; o giro em volta da lâmina e a
# altura são escolhidos pela caixa da malha (a face mais larga para baixo, o ponto mais baixo 1 cm acima do chão)
func _no_chao() -> Node3D:
	if suportes.has("_chao"): return suportes["_chao"]
	var s := Node3D.new(); s.name = "porte_chao"
	var k: float = c.height_m / 1.8
	c.add_child(s); suportes["_chao"] = s
	var melhor := [INF, Basis()]
	for giro in [0.0, 90.0]:
		var b := Basis(Vector3(0, 0, -1), deg_to_rad(giro)) * Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1))
		var h := _altura_caixa(b)
		if h.y - h.x < melhor[0]: melhor = [h.y - h.x, b, h.x]
	s.transform = Transform3D(melhor[1], Vector3(-1.0 * k, 0.01 - float(melhor[2]), -0.5 * k))
	return s

# menor e maior altura da malha da arma com a base dada (no espaço do personagem)
func _altura_caixa(b: Basis) -> Vector2:
	var lo := INF; var hi := -INF
	var inv: Transform3D = c.wnode.global_transform.affine_inverse()
	for m in c.wnode.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var x: Transform3D = Transform3D(b, Vector3.ZERO) * c.wnode.transform * (inv * mi.global_transform)
		var bb := mi.get_aabb()
		for i in 8:
			var y: float = (x * bb.get_endpoint(i)).y
			lo = minf(lo, y); hi = maxf(hi, y)
	return Vector2(lo, hi)

func _desprender() -> void:
	# devolve a arma à bainha oficial antes de entregar ao set_battle (que tira da bainha e põe na mão)
	if c.wnode.get_parent() != c.sheath and c.sheath != null and not c.armed:
		c.wnode.get_parent().remove_child(c.wnode); c.sheath.add_child(c.wnode)
