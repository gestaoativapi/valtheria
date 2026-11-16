# Valtheria V3 — prancha comparativa de evolução facial (AUT-020 3.4). SÓ PROPOSTA: não altera nenhum modelo.
# AUT-021 (D62): íris sem aumento de contraste (só +25% saturação e +8% brilho na B), sobrancelhas e cílios sem sombra
# projetada, sol com sombra macia de 6°, 64 amostras, borda da máscara dos lábios mais suave; B sem alvo de escala do olho.
#   Atual = rosto do marco 1 (MakeHuman neutro, pele repintada);
#   A = realista pintado (mesma forma; só pintura: pálpebras, olheiras suaves, lábios, rubor, íris mais definida);
#   B = fantasia semi-realista estilizada (formas levemente idealizadas pelos alvos CC0 do MakeHuman/MPFB + pintura
#       de ilustração), em 3 variações por sexo. Sem estética anime (olhos em tamanho real, queixo e nariz realistas).
# Renderiza frente e três quartos de cada variante em PNG; a montagem da prancha é feita fora (PIL).
# Uso: BLENDER_USER_RESOURCES=... python rosto_ab.py <m|f> <pasta_saida>
import sys, os, math, json, importlib
import bpy, addon_utils
import numpy as np
from mathutils import Vector
SEXO, SAIDA = sys.argv[-2], sys.argv[-1]; os.makedirs(SAIDA, exist_ok=True)
A = "/home/claude/v2/mh_assets/pacote"
TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../fontes/personagens/texturas")
MACRO = {"m": {"gender": 1.0, "age": 0.5, "muscle": 0.65, "weight": 0.5, "proportions": 0.8, "height": 0.5, "cupsize": 0.5, "firmness": 0.5,
               "race": {"asian": 0.33, "caucasian": 0.34, "african": 0.33}},
         "f": {"gender": 0.0, "age": 0.5, "muscle": 0.5, "weight": 0.5, "proportions": 0.8, "height": 0.5, "cupsize": 0.5, "firmness": 0.6,
               "race": {"asian": 0.33, "caucasian": 0.34, "african": 0.33}}}[SEXO]
CFG = {"m": dict(olho="brown", sobr="eyebrow001", cilio="eyelashes01", cabelo="short02", cor_cabelo=(0.16, 0.10, 0.06), pele="pele_humano_m.png"),
       "f": dict(olho="green", sobr="eyebrow010", cilio="eyelashes02", cabelo="braid01", cor_cabelo=(0.22, 0.12, 0.06), pele="pele_humano_f.png")}[SEXO]
def olhos(v): return {"eyes/l-eye-scale-incr": v, "eyes/r-eye-scale-incr": v}
def bochecha(v): return {"cheek/l-cheek-bones-incr": v, "cheek/r-cheek-bones-incr": v}
# Observação: o alvo de escala dos olhos foi descartado (o olho do MakeHuman ajustado ao globo maior fica escuro
# dentro da órbita); a abertura dos olhos vem da altura das pálpebras e das dobras.
def abre(v): return {"eyes/l-eye-height2-incr": v, "eyes/r-eye-height2-incr": v, "eyes/l-eye-eyefold-up": v * 0.6, "eyes/r-eye-eyefold-up": v * 0.6}
VAR = {"m": [("atual", "Atual (marco 1)", {}, 0.0), ("A", "A - realista pintado", {}, 0.6),
             ("B1", "B1 - herói", {**abre(0.4), **bochecha(0.8), "chin/chin-prominent-incr": 0.5, "chin/chin-width-incr": 0.35, "nose/nose-scale-horiz-decr": 0.4, "nose/nose-point-width-decr": 0.4, "head/head-oval": 0.5}, 1.0),
             ("B2", "B2 - veterano", {**abre(0.2), **bochecha(0.9), "chin/chin-width-incr": 0.7, "chin/chin-height-incr": 0.3, "nose/nose-hump-incr": 0.6, "head/head-square": 0.6, "eyebrows/eyebrows-angle-down": 0.6, "eyebrows/eyebrows-trans-down": 0.3}, 1.0),
             ("B3", "B3 - jovem", {**abre(0.6), "head/head-round": 0.5, "chin/chin-width-decr": 0.5, "nose/nose-scale-vert-decr": 0.4, "nose/nose-point-up": 0.3, "cheek/l-cheek-volume-incr": 0.4, "cheek/r-cheek-volume-incr": 0.4}, 1.0)],
       "f": [("atual", "Atual (marco 1)", {}, 0.0), ("A", "A - realista pintado", {}, 0.6),
             ("B1", "B1 - nobre", {**abre(0.5), **bochecha(0.7), "nose/nose-scale-horiz-decr": 0.5, "nose/nose-point-up": 0.4, "chin/chin-width-decr": 0.5, "head/head-oval": 0.6, "mouth/mouth-lowerlip-volume-incr": 0.5, "mouth/mouth-cupidsbow-incr": 0.4}, 1.0),
             ("B2", "B2 - guerreira", {**abre(0.3), **bochecha(0.9), "chin/chin-prominent-incr": 0.5, "head/head-diamond": 0.5, "eyebrows/eyebrows-angle-up": 0.6, "mouth/mouth-scale-horiz-decr": 0.2, "nose/nose-hump-incr": 0.3}, 1.0),
             ("B3", "B3 - jovem", {**abre(0.7), "head/head-round": 0.5, "cheek/l-cheek-volume-incr": 0.5, "cheek/r-cheek-volume-incr": 0.5, "nose/nose-scale-vert-decr": 0.5, "nose/nose-point-up": 0.4, "chin/chin-height-decr": 0.4}, 1.0)]}[SEXO]

addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)
def imp(p, k):
    for m in list(sys.modules):
        if m.endswith(p): return getattr(importlib.import_module(m), k)
HS = imp("mpfb.services.humanservice", "HumanService"); TS = imp("mpfb.services.targetservice", "TargetService")

def centro(o, grupo):
    vis = [(md, md.show_viewport) for md in o.modifiers]
    for md, _ in vis: md.show_viewport = False          # sem a máscara dos auxiliares, para a ordem dos vértices bater
    gi = o.vertex_groups[grupo].index; dg = bpy.context.evaluated_depsgraph_get(); ev = o.evaluated_get(dg); me = ev.to_mesh()
    pts = [v.co.copy() for v, ov in zip(me.vertices, o.data.vertices) if any(g.group == gi for g in ov.groups)]
    ev.to_mesh_clear()
    for md, s in vis: md.show_viewport = s
    return sum(pts, Vector()) / len(pts)

def pintura(m, img, marcos, forca):
    """pele: textura repintada + máscaras em coordenadas do objeto (lábios, pálpebras, olheiras, rubor)"""
    m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]; b.inputs["Roughness"].default_value = 0.6
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = img; cur = t.outputs["Color"]
    if forca <= 0: nt.links.new(cur, b.inputs["Base Color"]); return
    co = nt.nodes.new("ShaderNodeTexCoord")
    def esfera(c, raio, achata=(1, 1, 1)):
        mp = nt.nodes.new("ShaderNodeMapping"); mp.inputs["Location"].default_value = (-c.x / achata[0], -c.y / achata[1], -c.z / achata[2])
        mp.inputs["Scale"].default_value = (1 / achata[0], 1 / achata[1], 1 / achata[2]); nt.links.new(co.outputs["Object"], mp.inputs["Vector"])
        d = nt.nodes.new("ShaderNodeVectorMath"); d.operation = "LENGTH"; nt.links.new(mp.outputs["Vector"], d.inputs[0])
        r = nt.nodes.new("ShaderNodeMapRange"); r.inputs[1].default_value = raio * 0.40; r.inputs[2].default_value = raio
        r.inputs[3].default_value = 1.0; r.inputs[4].default_value = 0.0; nt.links.new(d.outputs["Value"], r.inputs[0]); return r.outputs[0]
    def misturar(cur, mascara, cor, peso, modo="MIX"):
        mul = nt.nodes.new("ShaderNodeMath"); mul.operation = "MULTIPLY"; mul.inputs[1].default_value = peso; nt.links.new(mascara, mul.inputs[0])
        mx = nt.nodes.new("ShaderNodeMix"); mx.data_type = "RGBA"; mx.blend_type = modo; nt.links.new(mul.outputs[0], mx.inputs[0])
        nt.links.new(cur, mx.inputs[6]); mx.inputs[7].default_value = (*cor, 1); return mx.outputs[2]
    boca, ol, orr = marcos["boca"], marcos["olho_l"], marcos["olho_r"]
    cur = misturar(cur, esfera(boca + Vector((0, -0.004, 0.0)), 0.026, (1.0, 0.8, 0.45)), (0.62, 0.30, 0.27), 0.42 * forca)     # lábios
    for o in (ol, orr):
        lado = 1 if o.x > 0 else -1
        cur = misturar(cur, esfera(o + Vector((0, -0.004, 0.006)), 0.022, (1.1, 0.7, 0.45)), (0.30, 0.20, 0.17), 0.45 * forca, "MULTIPLY")  # pálpebra
        cur = misturar(cur, esfera(o + Vector((0, -0.006, -0.016)), 0.018, (1.1, 0.6, 0.5)), (0.55, 0.42, 0.40), 0.20 * forca, "MULTIPLY")  # olheira
        cur = misturar(cur, esfera(o + Vector((lado * 0.022, -0.012, -0.038)), 0.030), (0.80, 0.42, 0.36), 0.22 * forca)                   # rubor
    nt.links.new(cur, b.inputs["Base Color"])

def montar(alvos, forca):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    hum = HS.create_human(macro_detail_dict=dict(MACRO))
    base = os.path.join(os.path.dirname(TS.target_full_path("head-oval") or ""), "..")
    for nome, v in alvos.items():
        caminho = TS.target_full_path(os.path.basename(nome))
        TS.load_target(hum, caminho, weight=v)
    pecas = {}
    for sub, arq, tipo, nome in [("eyes", "low-poly/low-poly.mhclo", "Eyes", "olhos"), ("eyebrows", f"{CFG['sobr']}/{CFG['sobr']}.mhclo", "Eyebrows", "sobrancelha"),
                                 ("eyelashes", f"{CFG['cilio']}/{CFG['cilio']}.mhclo", "Eyelashes", "cilios"), ("hair", f"{CFG['cabelo']}/{CFG['cabelo']}.mhclo", "Hair", "cabelo")]:
        ob = HS.add_mhclo_asset(f"{A}/{sub}/{arq}", hum, asset_type=tipo, subdiv_levels=0, material_type="MAKESKIN"); pecas[nome] = ob
    for md in list(hum.modifiers):
        if md.type == "SUBSURF": hum.modifiers.remove(md)
    marcos = {"boca": (centro(hum, "helper-upper-teeth") + centro(hum, "helper-lower-teeth")) / 2,
              "olho_l": centro(hum, "helper-l-eye"), "olho_r": centro(hum, "helper-r-eye")}
    marcos["boca"].y = min(marcos["boca"].y - 0.012, marcos["boca"].y)   # superfície dos lábios fica à frente dos dentes
    pele = bpy.data.images.load(os.path.abspath(os.path.join(TEX, CFG["pele"])))
    m = bpy.data.materials.new("pele"); pintura(m, pele, marcos, forca); hum.data.materials.clear(); hum.data.materials.append(m)
    olho = bpy.data.images.load(f"{A}/eyes/materials/{CFG['olho']}_eye.png")
    me = bpy.data.materials.new("olhos"); me.use_nodes = True; nt = me.node_tree; b = nt.nodes["Principled BSDF"]; b.inputs["Roughness"].default_value = 0.15
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = olho; cur = t.outputs["Color"]
    if forca > 0:  # íris mais definida
        hs = nt.nodes.new("ShaderNodeHueSaturation"); hs.inputs["Saturation"].default_value = 1.0 + 0.25 * forca
        hs.inputs["Value"].default_value = 1.0 + 0.08 * forca; nt.links.new(cur, hs.inputs["Color"]); cur = hs.outputs[0]
    nt.links.new(cur, b.inputs["Base Color"]); pecas["olhos"].data.materials.clear(); pecas["olhos"].data.materials.append(me)
    for nome in ("sobrancelha", "cilios", "cabelo"):
        o = pecas[nome]; im = None
        for s in o.material_slots:
            if s.material and s.material.use_nodes:
                for n in s.material.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image: im = n.image
        mm = bpy.data.materials.new(nome); mm.use_nodes = True; nt = mm.node_tree; b = nt.nodes["Principled BSDF"]; b.inputs["Roughness"].default_value = 0.55
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = im
        cor = CFG["cor_cabelo"] if nome == "cabelo" else ((0.10, 0.07, 0.05) if forca > 0 else (0.16, 0.11, 0.08))
        mx = nt.nodes.new("ShaderNodeMix"); mx.data_type = "RGBA"; mx.blend_type = "MULTIPLY"; mx.inputs[0].default_value = 1.0
        nt.links.new(t.outputs["Color"], mx.inputs[6]); mx.inputs[7].default_value = (*[c * 2.2 for c in cor], 1)
        nt.links.new(mx.outputs[2], b.inputs["Base Color"]); nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
        try: mm.blend_method = "HASHED"
        except Exception: pass
        o.data.materials.clear(); o.data.materials.append(mm)
        if nome in ("sobrancelha", "cilios"): o.visible_shadow = False   # SOL-021: evita sombra pontilhada no rosto
    return hum, marcos

def cena(marcos):
    sc = bpy.context.scene; sc.render.engine = "BLENDER_EEVEE"; sc.render.resolution_x = 700; sc.render.resolution_y = 820
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.46, 0.50, 0.55, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    sol = bpy.data.objects.new("sol", bpy.data.lights.new("sol", "SUN")); sc.collection.objects.link(sol)
    sol.rotation_euler = (math.radians(55), 0, math.radians(-35)); sol.data.energy = 3.2; sol.data.color = (1.0, 0.95, 0.86)
    sol.data.angle = math.radians(6.0)                     # SOL-021: sombra de contato macia (sem serrilhado)
    try: sol.data.shadow_resolution_limit = 0.0005
    except Exception: pass
    try: sc.eevee.taa_render_samples = 64
    except Exception: pass
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 85
    return cam

res = []
SO = [x for x in os.environ.get("V3_VAR", "").split(",") if x]
for chave, rotulo, alvos, forca in VAR:
    if SO and chave not in SO: res.append({"chave": chave, "rotulo": rotulo, "alvos": alvos, "pintura": forca}); continue
    hum, marcos = montar(alvos, forca)
    cam = cena(marcos)
    alvo = (marcos["olho_l"] + marcos["olho_r"]) / 2 + Vector((0, 0, -0.035))
    for vista, ang in (("frente", 0.0), ("tres_quartos", 35.0)):
        a = math.radians(ang); d = 0.95
        cam.location = alvo + Vector((math.sin(a) * d, -math.cos(a) * d, 0.02))
        dirv = alvo - cam.location; cam.rotation_euler = dirv.to_track_quat("-Z", "Y").to_euler()
        bpy.context.scene.render.filepath = f"{SAIDA}/rosto_{SEXO}_{chave}_{vista}.png"
        bpy.ops.render.render(write_still=True)
    res.append({"chave": chave, "rotulo": rotulo, "alvos": alvos, "pintura": forca})
json.dump(res, open(f"{SAIDA}/rostos_{SEXO}.json", "w"), ensure_ascii=False, indent=1)
print("FEITO", json.dumps(res, ensure_ascii=False))
