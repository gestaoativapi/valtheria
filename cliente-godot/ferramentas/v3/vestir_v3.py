# Valtheria V3 — P1/P2: humano completo (corpo V2 + rosto, pele, olhos, sobrancelhas, cílios, cabelo,
# túnica com cinto, calça e botas de fantasia, com texturas próprias assadas em 1024 px).
# Uso:  BLENDER_USER_RESOURCES=... python vestir_v3.py <m|f> <pasta_saida>
# Fontes: MPFB2 (ferramenta, GPL) + MakeHuman system assets (CC0). Roupas: modeladas a partir das malhas
# auxiliares CC0 do corpo-base (helper-skirt, helper-tights) e da própria pele, com pintura procedural própria.
import sys, os, json, math, importlib
import bpy, bmesh, addon_utils
import numpy as np

SEXO, SAIDA = sys.argv[-2], sys.argv[-1]
os.makedirs(SAIDA, exist_ok=True)
A = "/home/claude/v2/mh_assets/pacote"
TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../fontes/personagens/texturas")
CFG = {
    "m": dict(macro={"gender": 1.0, "age": 0.5, "muscle": 0.65, "weight": 0.5, "proportions": 0.8, "height": 0.5,
                     "cupsize": 0.5, "firmness": 0.5, "race": {"asian": 0.33, "caucasian": 0.34, "african": 0.33}},
              altura=1.80, rig="game_engine", pele="pele_humano_m.png", olho="brown", sobr="eyebrow001",
              cilio="eyelashes01", cabelo="short02", cor_cabelo=(0.16, 0.10, 0.06),
              tunica=(0.40, 0.33, 0.22), barra=(0.07, 0.12, 0.20), calca=(0.13, 0.09, 0.055), couro=(0.075, 0.042, 0.022),
              barra_coxa=0.62),
    "f": dict(macro={"gender": 0.0, "age": 0.5, "muscle": 0.5, "weight": 0.5, "proportions": 0.8, "height": 0.5,
                     "cupsize": 0.5, "firmness": 0.6, "race": {"asian": 0.33, "caucasian": 0.34, "african": 0.33}},
              altura=1.68, rig="game_engine_with_breast", pele="pele_humano_f.png", olho="green", sobr="eyebrow010",
              cilio="eyelashes02", cabelo="braid01", cor_cabelo=(0.22, 0.12, 0.06),
              tunica=(0.36, 0.38, 0.30), barra=(0.09, 0.15, 0.24), calca=(0.14, 0.10, 0.065), couro=(0.085, 0.048, 0.026),
              barra_coxa=0.52),
}[SEXO]

bpy.ops.wm.read_factory_settings(use_empty=True)
addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)
def imp(p, k):
    for m in list(sys.modules):
        if m.endswith(p): return getattr(importlib.import_module(m), k)
HS = imp("mpfb.services.humanservice", "HumanService")

def altura_corpo(o):
    gi = o.vertex_groups["body"].index
    dg = bpy.context.evaluated_depsgraph_get(); ev = o.evaluated_get(dg); me = ev.to_mesh()
    zs = [v.co.z for v, ov in zip(me.vertices, o.data.vertices) if any(g.group == gi for g in ov.groups)]
    h = max(zs) - min(zs); ev.to_mesh_clear(); return h

# ---------- 1. corpo com a altura-alvo ----------
macro = dict(CFG["macro"]); lo, hi = 0.0, 1.0
for _ in range(9):
    macro["height"] = (lo + hi) / 2
    bpy.ops.wm.read_factory_settings(use_empty=True)
    hum = HS.create_human(macro_detail_dict=dict(macro))
    if altura_corpo(hum) < CFG["altura"]: lo = macro["height"]
    else: hi = macro["height"]
rig = HS.add_builtin_rig(hum, CFG["rig"])
HS.set_character_skin(f"{A}/skins/young_caucasian_{'male' if SEXO == 'm' else 'female'}/young_caucasian_{'male' if SEXO == 'm' else 'female'}.mhmat", hum, skin_type="GAMEENGINE")
pecas = {}
for sub, arq, tipo, nome in [("eyes", "low-poly/low-poly.mhclo", "Eyes", "olhos"), ("eyebrows", f"{CFG['sobr']}/{CFG['sobr']}.mhclo", "Eyebrows", "sobrancelha"),
                             ("eyelashes", f"{CFG['cilio']}/{CFG['cilio']}.mhclo", "Eyelashes", "cilios"), ("hair", f"{CFG['cabelo']}/{CFG['cabelo']}.mhclo", "Hair", "cabelo")]:
    ob = HS.add_mhclo_asset(f"{A}/{sub}/{arq}", hum, asset_type=tipo, subdiv_levels=0, material_type="MAKESKIN")
    ob.name = nome; pecas[nome] = ob
hum.name = "corpo"

def congelar(o):
    bpy.context.view_layer.objects.active = o
    for md in list(o.modifiers):
        if md.type in ("SUBSURF", "MASK"): o.modifiers.remove(md)
    if o.data.shape_keys:
        o.shape_key_add(name="final", from_mix=True)
        for kb in list(o.data.shape_keys.key_blocks):
            if kb.name != "final": o.shape_key_remove(kb)
        o.shape_key_remove(o.data.shape_keys.key_blocks["final"])
for o in [hum] + list(pecas.values()): congelar(o)

# ---------- 2. referências anatômicas (cabeças dos ossos, espaço do objeto) ----------
B = {b.name: (rig.matrix_world @ b.head_local) for b in rig.data.bones}
inv = hum.matrix_world.inverted()
Bz = {k: (inv @ v) for k, v in B.items()}
z_joelho = Bz["calf_l"].z; z_quadril = Bz["thigh_l"].z; z_pelvis = Bz["pelvis"].z; z_pesc = Bz["neck_01"].z
z_cintura = z_pelvis + 0.10 * (z_pesc - z_pelvis)
z_barra = z_joelho + CFG["barra_coxa"] * (z_quadril - z_joelho)
z_bota = Bz["foot_l"].z + 0.62 * (z_joelho - Bz["foot_l"].z)

gidx = {g.name: g.index for g in hum.vertex_groups}
ossos = set(b.name for b in rig.data.bones)
def dominante(v):
    best, bw = None, 0
    for g in v.groups:
        n = hum.vertex_groups[g.group].name
        if n in ossos and g.weight > bw: best, bw = n, g.weight
    return best
def no_grupo(v, nome, lim=0.5):
    return any(g.group == gidx[nome] and g.weight > lim for g in v.groups)
V = hum.data.vertices
dom = [dominante(v) for v in V]
corpo = [no_grupo(v, "body") for v in V]
P = np.array([v.co[:] for v in V])
mao = {s: np.array(Bz[f"hand_{s}"][:]) for s in "lr"}

TRONCO = {"pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"}
def perto_mao(i, d):
    return min(np.linalg.norm(P[i] - mao["l"]), np.linalg.norm(P[i] - mao["r"])) < d

# ---------- 3. peças de roupa ----------
def copia(nome, manter, empurrar, extra=None):
    o = hum.copy(); o.data = hum.data.copy(); o.name = nome
    bpy.context.collection.objects.link(o)
    for md in list(o.modifiers):
        if md.type != "ARMATURE": o.modifiers.remove(md)
    o.data.materials.clear()
    bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    fora = [bm.verts[i] for i in range(len(bm.verts)) if not manter[i]]
    bmesh.ops.delete(bm, geom=fora, context="VERTS")
    bm.normal_update()
    for v in bm.verts:
        d = empurrar(v) if callable(empurrar) else empurrar
        v.co += v.normal * d
    if extra: extra(bm)
    bm.to_mesh(o.data); bm.free()
    return o

# túnica: pele do tronco e dos braços (até o punho) + saia auxiliar cortada no meio da coxa, com roda na barra
saia = [no_grupo(v, "helper-skirt") for v in V]
z_top_saia = z_cintura
Y0 = float(P[np.array(saia), 1].mean())
def manter_tunica(i):
    if saia[i]: return z_barra - 0.01 <= P[i][2] <= z_cintura + 0.03
    if not corpo[i] or dom[i] not in TRONCO: return False
    if dom[i].startswith("lowerarm") and perto_mao(i, 0.035): return False
    return P[i][2] > z_cintura - 0.02
def cortar(bm, co, no, filtro):
    # AUT-020: listas em ordem fixa de índice (conjuntos de objetos variavam de ordem entre execuções)
    bm.verts.index_update(); bm.edges.index_update(); bm.faces.index_update()
    geo = sorted((v for v in bm.verts if filtro(v.co)), key=lambda v: v.index)
    if not geo: return
    edges = sorted({e for v in geo for e in v.link_edges}, key=lambda e: e.index); faces = sorted({f for v in geo for f in v.link_faces}, key=lambda f: f.index)
    bmesh.ops.bisect_plane(bm, geom=list(geo) + list(edges) + list(faces), plane_co=co, plane_no=no, clear_outer=True)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
from mathutils import Vector
cot = {s: Vector(Bz[f"lowerarm_{s}"][:]) for s in "lr"}; pul = {s: Vector(Bz[f"hand_{s}"][:]) for s in "lr"}
def cair_do_busto(bm):
    """AUT-020 3.3: o tecido cai em linha reta do ponto mais saliente do busto até a cintura (frente = -Y),
    sem acompanhar a curva por baixo do busto; mais 3 mm de folga no peito."""
    frente = [v for v in bm.verts if abs(v.co.x) < 0.16 and v.co.y < Y0 and z_cintura - 0.01 < v.co.z < z_pesc - 0.06]
    for v in frente:
        viz = [w for w in frente if abs(w.co.x - v.co.x) < 0.012]
        alto = [w for w in viz if w.co.z > z_cintura + 0.08]
        if not alto: continue
        apice = min(alto, key=lambda w: w.co.y)
        if not (z_cintura < v.co.z < apice.co.z): continue
        cint = [w for w in viz if abs(w.co.z - z_cintura) < 0.02]
        if not cint: continue
        yw = min(w.co.y for w in cint)
        t = (v.co.z - z_cintura) / max(apice.co.z - z_cintura, 1e-3)
        yt = yw + (apice.co.y - yw) * t
        if v.co.y > yt: v.co.y = yt
    for v in frente:  # +3 mm no peito, sumindo para os lados e para a cintura (sem degraus)
        lado = min(1.0, (Y0 - v.co.y) / 0.06); alt = min(1.0, max(0.0, (v.co.z - z_cintura - 0.02) / 0.06))
        v.co.y -= 0.003 * lado * alt
    bmesh.ops.smooth_vert(bm, verts=frente, factor=0.5, use_axis_x=False, use_axis_y=True, use_axis_z=False)
    bmesh.ops.smooth_vert(bm, verts=frente, factor=0.5, use_axis_x=False, use_axis_y=True, use_axis_z=False)
def roda(bm):
    cortar(bm, (0, Y0, z_pesc - 0.015), (0, -0.45, 1), lambda c: c.z > z_pesc - 0.15 and abs(c.x) < 0.14)
    for sd in "lr":
        d = (pul[sd] - cot[sd]).normalized(); co = pul[sd] - d * 0.04
        cortar(bm, co, d, lambda c, sd=sd: (c - pul[sd]).length < 0.16)
    cortar(bm, (0, 0, z_barra), (0, 0, -1), lambda c: c.z < z_barra + 0.06 and abs(c.x) < 0.32)
    tronco = [v for v in bm.verts if z_cintura + 0.05 < v.co.z < z_pesc - 0.07 and abs(v.co.x) < 0.17]
    for _ in range(10 if SEXO == "f" else 5):
        bmesh.ops.smooth_vert(bm, verts=tronco, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=False)
    if SEXO == "f": cair_do_busto(bm)
    for v in bm.verts:
        z = v.co.z
        if z < z_cintura - 0.02 and abs(v.co.x) < 0.30:
            t = min(1.0, max(0.0, (z_cintura - z) / max(z_cintura - z_barra, 1e-3)))
            v.co.x *= 1.0 + 0.13 * t; v.co.y = Y0 + (v.co.y - Y0) * (1.0 + 0.28 * t)  # AUT-020: abertura um pouco maior
BLUSA = float(os.environ.get("V3_BLUSA", "0.015"))
def folga_saia(v):
    t = min(1.0, max(0.0, (z_cintura - v.co.z) / max(z_cintura - z_barra, 1e-3)))
    f = 0.010 + 0.005 * t                                   # 10 mm sob o cinto -> 15 mm na barra
    if v.co.y < Y0:                                         # frente: tecido "blusado" sob o cinto, onde a coxa sobe ao sentar/agachar
        f += BLUSA * math.sin(math.pi * min(1.0, t / 0.6)) * min(1.0, (Y0 - v.co.y) / 0.05)
    return f
tunica = copia("tunica", [manter_tunica(i) for i in range(len(V))], lambda v: (0.019 if v.co.z > z_pesc - 0.08 else 0.012) if v.co.z > z_cintura - 0.02 else folga_saia(v), roda)  # AUT-020: 15 mm na barra

# cinto: faixa da pele na cintura, mais afastada
def manter_cinto(i):
    return corpo[i] and dom[i] in ("pelvis", "spine_01") and abs(P[i][2] - z_cintura) < 0.032
cinto = copia("cinto", [manter_cinto(i) for i in range(len(V))], 0.024)

# calça: malha auxiliar justa (helper-tights) da cintura até dentro da bota
PERNA = {"thigh_l", "thigh_r", "calf_l", "calf_r", "pelvis"}
# só a parte visível (abaixo da barra da túnica + folga): evita atravessar a saia e esticar na virilha
# AUT-020 3.2: a calça sobe até o quadril por baixo da saia (a coxa não fica sem tecido quando a perna avança)
calca = copia("calca", [corpo[i] and dom[i] in PERNA and z_bota - 0.07 < P[i][2] < z_quadril for i in range(len(V))], 0.006)

# botas: pele dos pés e da canela até o meio da panturrilha; sola achatada
PE = {"foot_l", "foot_r", "ball_l", "ball_r", "calf_l", "calf_r"}
z_tornozelo = Bz["foot_l"].z
def sola(bm):
    # o pé da bota é um casco fechado (sem dedos) sobre o pé de cada lado; o cano vem da pele da canela
    for lado in (1, -1):
        pe = [v for v in bm.verts if v.co.z < z_tornozelo + 0.035 and v.co.x * lado > 0]
        faces = {f for v in pe for f in v.link_faces if all(w.co.z < z_tornozelo + 0.035 and w.co.x * lado > 0 for w in f.verts)}
        r = bmesh.ops.convex_hull(bm, input=pe)
        bmesh.ops.delete(bm, geom=list(faces), context="FACES_ONLY")
        bmesh.ops.delete(bm, geom=[v for v in r["geom_interior"] if isinstance(v, bmesh.types.BMVert)], context="VERTS")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for v in bm.verts:
        if v.co.z < 0.03: v.co.z = max(0.0, v.co.z - 0.006)
    cortar(bm, (0, 0, z_bota), (0, 0, 1), lambda c: c.z > z_bota - 0.06)
botas = copia("botas", [corpo[i] and dom[i] in PE and P[i][2] < z_bota for i in range(len(V))], 0.011, sola)

# cinto entra na túnica (mesma peça, mesmo material)
bpy.ops.object.select_all(action="DESELECT")
cinto.select_set(True); tunica.select_set(True); bpy.context.view_layer.objects.active = tunica
bpy.ops.object.join()

# AUT-020 3.1: pesos da saia sem troca brusca esquerda/direita no centro. Mantém a parte de cada osso que o MakeHuman
# deu à saia (bacia x coxas), mas reparte a parte das coxas em gradiente pelo centro e suaviza os pesos (3 passadas).
def suave(a, b, x): return min(1.0, max(0.0, (x - a) / (b - a)))
COXA_MAX = float(os.environ.get("V3_COXA", "0.95")); COXA_TOPO = float(os.environ.get("V3_COXA_TOPO", "0.7"))
def pesos_saia(o):
    nomes = {gr.index: gr.name for gr in o.vertex_groups}
    ztop = z_cintura - 0.035
    alvo = {}
    for v in o.data.vertices:
        if v.co.z >= ztop: continue
        w = {}
        for gr in v.groups:
            n = nomes[gr.group]
            if n in ossos and gr.weight > 1e-4: w[n] = w.get(n, 0.0) + gr.weight
        coxa = w.pop("thigh_l", 0.0) + w.pop("thigh_r", 0.0)
        # parte mínima das coxas: cresce da articulação do quadril até a barra (a saia acompanha a perna que avança)
        u = suave(ztop, z_barra, v.co.z); u = u * u * (3 - 2 * u)
        frente = suave(Y0 + 0.02, Y0 - 0.06, v.co.y)                # 1 na frente (-Y), 0 atrás
        lateral = suave(0.0, 0.06, abs(v.co.x))                      # o centro entre as pernas fica dividido
        minimo = COXA_MAX * (COXA_TOPO + (1 - COXA_TOPO) * u) * (0.35 + 0.65 * frente) * (0.5 + 0.5 * lateral)
        if coxa < minimo:
            resto = sum(w.values())
            if resto > 1e-6:
                for k in w: w[k] *= (1.0 - minimo) / resto
            coxa = minimo
        wl = suave(-0.05, 0.05, v.co.x)                      # thigh_l fica em x > 0
        w["thigh_l"] = coxa * wl; w["thigh_r"] = coxa * (1 - wl)
        alvo[v.index] = w
    bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    for _ in range(3):
        novo = {}
        for i, w in alvo.items():
            viz = [e.other_vert(bm.verts[i]).index for e in bm.verts[i].link_edges if e.other_vert(bm.verts[i]).index in alvo]
            ks = sorted(set(w).union(*[alvo[j] for j in viz])) if viz else sorted(w)   # ordem fixa (determinístico)
            novo[i] = {k: 0.5 * w.get(k, 0.0) + (0.5 * sum(alvo[j].get(k, 0.0) for j in viz) / len(viz) if viz else 0.5 * w.get(k, 0.0)) for k in ks}
        alvo = novo
    bm.free()
    for i, w in alvo.items():
        v = o.data.vertices[i]
        for gi in [gr.group for gr in v.groups]:
            if nomes[gi] in ossos: o.vertex_groups[gi].remove([i])
        top = sorted(w.items(), key=lambda kv: (-kv[1], kv[0]))[:4]; s = sum(x for _, x in top)   # até 4 influências, normalizadas
        for k, x in top:
            if x > 1e-4:
                if k not in o.vertex_groups: o.vertex_groups.new(name=k)
                o.vertex_groups[k].add([i], x / s, "REPLACE")
    return len(alvo)
n_saia = pesos_saia(tunica)

# AUT-020 3.1: forro interno escuro na mesma malha (saia, gola e punhos), marcado para a pintura
def forro(o):
    bm = bmesh.new(); bm.from_mesh(o.data); lay = bm.verts.layers.float.new("forro"); bm.normal_update()
    def precisa(f):
        c = f.calc_center_median()
        return c.z < z_cintura - 0.03 or c.z > z_pesc - 0.10 or min((c - pul[s]).length for s in "lr") < 0.10
    sel = [f for f in bm.faces if precisa(f)]
    novo = bmesh.ops.duplicate(bm, geom=sel)
    nf = [e for e in novo["geom"] if isinstance(e, bmesh.types.BMFace)]
    nv = [e for e in novo["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.reverse_faces(bm, faces=nf)
    bm.normal_update()
    for v in nv: v.co += v.normal * 0.003   # normal já invertida: 3 mm para dentro
    for v in nv: v[lay] = 1.0
    bm.to_mesh(o.data); bm.free()
    at = o.data.attributes.get("forro")
    ca = o.data.color_attributes.new("forro_cor", "FLOAT_COLOR", "POINT")
    for i, d in enumerate(at.data): ca.data[i].color = (d.value, d.value, d.value, 1.0)
    o.data.attributes.remove(o.data.attributes["forro"])
    return len(nf)
n_forro = forro(tunica)

# ---------- 4. corpo: tira as auxiliares e a pele coberta (fica cabeça, pescoço e mãos) ----------
COBERTO = TRONCO | {"thigh_l", "thigh_r"} | PE
def some(i):
    if not corpo[i]: return True
    if dom[i] in ("neck_01", "head") or (dom[i] or "").startswith(("hand", "index", "middle", "ring", "pinky", "thumb")): return False
    if P[i][2] > z_pesc - 0.075: return False
    if dom[i] and dom[i].startswith("lowerarm") and perto_mao(i, 0.06): return False
    return dom[i] in COBERTO
bm = bmesh.new(); bm.from_mesh(hum.data); bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.verts[i] for i in range(len(V)) if some(i)], context="VERTS")
bm.to_mesh(hum.data); bm.free()

# ---------- 5. materiais: pele pintada, olhos, pelos; roupas com pintura procedural assada ----------
def mat_imagem(nome, img, alfa=False, rug=0.75):
    m = bpy.data.materials.new(nome); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = rug
    if "Specular IOR Level" in b.inputs: b.inputs["Specular IOR Level"].default_value = 0.25
    if img is not None and max(img.size) > 1024: img.scale(1024, 1024)
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = img; nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    if alfa:
        nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
        try: m.blend_method = "CLIP"
        except Exception: pass
    return m
def img_de(o, chaves):
    for s in o.material_slots:
        if s.material and s.material.use_nodes:
            for n in s.material.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and any(k in (n.image.filepath or n.image.name).lower() for k in chaves): return n.image
    return None
pele = bpy.data.images.load(os.path.abspath(os.path.join(TEX, CFG["pele"])))
hum.data.materials.clear(); hum.data.materials.append(mat_imagem("pele", pele, rug=0.6))
olho = bpy.data.images.load(f"{A}/eyes/materials/{CFG['olho']}_eye.png")
pecas["olhos"].data.materials.clear(); pecas["olhos"].data.materials.append(mat_imagem("olhos", olho, rug=0.2))
for nome in ("sobrancelha", "cilios", "cabelo"):
    o = pecas[nome]; im = img_de(o, ("diffuse", ".png"))
    if nome == "cabelo" and im is not None:  # tinge o cabelo na cor escolhida mantendo o desenho dos fios
        px = np.array(im.pixels[:]).reshape(-1, 4); lum = px[:, :3].mean(1, keepdims=True)
        px[:, :3] = np.clip(lum * 1.9 * np.array(CFG["cor_cabelo"]) + lum * 0.15, 0, 1)
        im = im.copy(); im.pixels = px.reshape(-1).tolist(); im.name = f"cabelo_{SEXO}"
    o.data.materials.clear(); o.data.materials.append(mat_imagem(nome, im, alfa=True, rug=0.55))

sc = bpy.context.scene; sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 8
sc.render.bake.margin = 6
sc.render.threads_mode = "FIXED"; sc.render.threads = 1  # AUT-020: bake determinístico (sem ruído de processamento paralelo)
def no(nt, tipo, **kw):
    n = nt.nodes.new(tipo)
    for k, v in kw.items(): setattr(n, k, v)
    return n
def tecido(nt, cor, escala_trama, z_faixas, cor_faixa, desgaste, couro=False):
    """pintura procedural: cor base com manchas largas, trama fina, faixas de barra e desgaste nas bordas"""
    co = no(nt, "ShaderNodeTexCoord"); sep = no(nt, "ShaderNodeSeparateXYZ"); nt.links.new(co.outputs["Object"], sep.inputs[0])
    n1 = no(nt, "ShaderNodeTexNoise"); n1.inputs["Scale"].default_value = 4.0; n1.inputs["Detail"].default_value = 3
    nt.links.new(co.outputs["Object"], n1.inputs["Vector"])
    base = no(nt, "ShaderNodeMix"); base.data_type = "RGBA"; base.blend_type = "MULTIPLY"
    base.inputs[6].default_value = (*cor, 1); nt.links.new(n1.outputs["Fac"], base.inputs[0])
    var = no(nt, "ShaderNodeValToRGB"); nt.links.new(n1.outputs["Fac"], var.inputs[0])
    var.color_ramp.elements[0].color = (0.86, 0.86, 0.86, 1); var.color_ramp.elements[1].color = (1.08, 1.06, 1.02, 1)
    nt.links.new(var.outputs[0], base.inputs[7]); base.inputs[0].default_value = 1.0
    cur = base.outputs[2]
    if escala_trama:
        w = no(nt, "ShaderNodeTexWave"); w.inputs["Scale"].default_value = escala_trama; w.inputs["Distortion"].default_value = 1.5
        nt.links.new(co.outputs["Object"], w.inputs["Vector"])
        r = no(nt, "ShaderNodeMapRange"); r.inputs[3].default_value = 0.93; r.inputs[4].default_value = 1.03; nt.links.new(w.outputs["Fac"], r.inputs[0])
        m = no(nt, "ShaderNodeMix"); m.data_type = "RGBA"; m.blend_type = "MULTIPLY"; m.inputs[0].default_value = 1.0
        nt.links.new(cur, m.inputs[6]); nt.links.new(r.outputs[0], m.inputs[7]); cur = m.outputs[2]
    for fx in z_faixas:  # faixas tingidas (barra, gola) ou de couro (cinto)
        z0, z1 = fx[0], fx[1]; cor_f = fx[2] if len(fx) > 2 else cor_faixa
        a = no(nt, "ShaderNodeMath", operation="GREATER_THAN"); a.inputs[1].default_value = z0; nt.links.new(sep.outputs["Z"], a.inputs[0])
        b = no(nt, "ShaderNodeMath", operation="LESS_THAN"); b.inputs[1].default_value = z1; nt.links.new(sep.outputs["Z"], b.inputs[0])
        f = no(nt, "ShaderNodeMath", operation="MULTIPLY"); nt.links.new(a.outputs[0], f.inputs[0]); nt.links.new(b.outputs[0], f.inputs[1])
        m = no(nt, "ShaderNodeMix"); m.data_type = "RGBA"; nt.links.new(f.outputs[0], m.inputs[0])
        nt.links.new(cur, m.inputs[6]); m.inputs[7].default_value = (*cor_f, 1); cur = m.outputs[2]
    if desgaste:  # bordas e partes baixas mais gastas e sujas
        n2 = no(nt, "ShaderNodeTexNoise"); n2.inputs["Scale"].default_value = 18; n2.inputs["Detail"].default_value = 6
        nt.links.new(co.outputs["Object"], n2.inputs["Vector"])
        r = no(nt, "ShaderNodeMapRange"); r.inputs[1].default_value = 0.55; r.inputs[2].default_value = 0.75
        r.inputs[3].default_value = 0.0; r.inputs[4].default_value = desgaste; nt.links.new(n2.outputs["Fac"], r.inputs[0])
        m = no(nt, "ShaderNodeMix"); m.data_type = "RGBA"; nt.links.new(r.outputs[0], m.inputs[0])
        nt.links.new(cur, m.inputs[6]); m.inputs[7].default_value = (0.17, 0.13, 0.09, 1) if not couro else (0.45, 0.32, 0.20, 1); cur = m.outputs[2]
    return cur

def mascara_esfera(nt, ponto, raio_in, raio_out):
    co = no(nt, "ShaderNodeTexCoord"); dist = no(nt, "ShaderNodeVectorMath", operation="DISTANCE")
    nt.links.new(co.outputs["Object"], dist.inputs[0]); dist.inputs[1].default_value = ponto
    a = no(nt, "ShaderNodeMath", operation="LESS_THAN"); a.inputs[1].default_value = raio_out; nt.links.new(dist.outputs["Value"], a.inputs[0])
    b = no(nt, "ShaderNodeMath", operation="GREATER_THAN"); b.inputs[1].default_value = raio_in; nt.links.new(dist.outputs["Value"], b.inputs[0])
    m = no(nt, "ShaderNodeMath", operation="MULTIPLY"); nt.links.new(a.outputs[0], m.inputs[0]); nt.links.new(b.outputs[0], m.inputs[1]); return m.outputs[0]
def caixa(nt, xmin, xmax, ymin, ymax, zmin, zmax, absx=False):
    co = no(nt, "ShaderNodeTexCoord"); sep = no(nt, "ShaderNodeSeparateXYZ"); nt.links.new(co.outputs["Object"], sep.inputs[0])
    out = None
    for eixo, lo, hi in (("X", xmin, xmax), ("Y", ymin, ymax), ("Z", zmin, zmax)):
        src = sep.outputs[eixo]
        if eixo == "X" and absx:
            ab = no(nt, "ShaderNodeMath", operation="ABSOLUTE"); nt.links.new(src, ab.inputs[0]); src = ab.outputs[0]
        a = no(nt, "ShaderNodeMath", operation="GREATER_THAN"); a.inputs[1].default_value = lo; nt.links.new(src, a.inputs[0])
        b = no(nt, "ShaderNodeMath", operation="LESS_THAN"); b.inputs[1].default_value = hi; nt.links.new(src, b.inputs[0])
        m = no(nt, "ShaderNodeMath", operation="MULTIPLY"); nt.links.new(a.outputs[0], m.inputs[0]); nt.links.new(b.outputs[0], m.inputs[1])
        if out is None: out = m.outputs[0]
        else:
            m2 = no(nt, "ShaderNodeMath", operation="MULTIPLY"); nt.links.new(out, m2.inputs[0]); nt.links.new(m.outputs[0], m2.inputs[1]); out = m2.outputs[0]
    return out
def pintar(nt, cur, mascara, cor):
    m = no(nt, "ShaderNodeMix"); m.data_type = "RGBA"; nt.links.new(mascara, m.inputs[0])
    nt.links.new(cur, m.inputs[6]); m.inputs[7].default_value = (*cor, 1); return m.outputs[2]
def listras(nt, eixo, escala):
    co = no(nt, "ShaderNodeTexCoord"); w = no(nt, "ShaderNodeTexWave"); w.bands_direction = eixo; w.inputs["Scale"].default_value = escala
    nt.links.new(co.outputs["Object"], w.inputs["Vector"])
    g = no(nt, "ShaderNodeMath", operation="GREATER_THAN"); g.inputs[1].default_value = 0.6; nt.links.new(w.outputs["Fac"], g.inputs[0]); return g.outputs[0]
def mult(nt, a, b):
    m = no(nt, "ShaderNodeMath", operation="MULTIPLY"); nt.links.new(a, m.inputs[0]); nt.links.new(b, m.inputs[1]); return m.outputs[0]

def assar(o, nome, pintura):
    bpy.ops.object.select_all(action="DESELECT"); o.select_set(True); bpy.context.view_layer.objects.active = o
    for uv in list(o.data.uv_layers): o.data.uv_layers.remove(uv)
    o.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.012); bpy.ops.object.mode_set(mode="OBJECT")
    m = bpy.data.materials.new(nome + "_pintura"); m.use_nodes = True; nt = m.node_tree; bsdf = nt.nodes["Principled BSDF"]
    nt.links.new(pintura(nt), bsdf.inputs["Base Color"])
    img = bpy.data.images.new(nome, 1024, 1024); t = nt.nodes.new("ShaderNodeTexImage"); t.image = img; nt.nodes.active = t
    o.data.materials.clear(); o.data.materials.append(m)
    sc.render.bake.use_pass_direct = False; sc.render.bake.use_pass_indirect = False; sc.render.bake.use_pass_color = True
    bpy.ops.object.bake(type="DIFFUSE")
    cor = np.array(img.pixels[:]).reshape(-1, 4).copy()
    ao = bpy.data.images.new(nome + "_ao", 1024, 1024); t.image = ao
    sc.cycles.samples = 64; bpy.ops.object.bake(type="AO"); sc.cycles.samples = 8  # AUT-020: AO sem ruído
    a = np.array(ao.pixels[:]).reshape(-1, 4)[:, :1]
    cor[:, :3] = np.clip(cor[:, :3] * (0.58 + 0.42 * a), 0, 1)  # sombra pintada nas dobras
    img.pixels = cor.reshape(-1).tolist()
    img.filepath_raw = os.path.join(SAIDA, f"tx_{nome}_{SEXO}.png"); img.file_format = "PNG"; img.save()
    o.data.materials.clear(); o.data.materials.append(mat_imagem(nome, img, rug=0.85 if nome != "botas" else 0.6))

cfg = CFG; zp, zc = z_pesc, z_cintura
joelho = {s: Bz[f"calf_{s}"] for s in "lr"}
def pint_tunica(nt):
    cur = tecido(nt, cfg["tunica"], 160, [(z_barra - 0.01, z_barra + 0.04), (zc - 0.031, zc + 0.033, tuple(c * 0.75 for c in cfg["couro"])), (zp - 0.09, zp + 0.05)], cfg["barra"], 0.30)
    for sd in "lr":  # punho tingido
        cur = pintar(nt, cur, mascara_esfera(nt, tuple(pul[sd]), 0.04, 0.085), cfg["barra"])
    # abertura da gola na frente com cordão de couro cruzado
    gola = caixa(nt, 0, 0.016, -1, Y0 - 0.02, zp - 0.16, zp + 0.02, absx=True)
    cur = pintar(nt, cur, gola, tuple(c * 0.55 for c in cfg["tunica"]))
    cur = pintar(nt, cur, mult(nt, gola, listras(nt, "Z", 55)), tuple(c * 0.9 for c in cfg["couro"]))
    at = no(nt, "ShaderNodeAttribute"); at.attribute_name = "forro_cor"   # forro interno: mesmo tecido, bem mais escuro
    return pintar(nt, cur, at.outputs["Fac"], tuple(c * 0.30 for c in cfg["tunica"]))
def pint_calca(nt):
    cur = tecido(nt, cfg["calca"], 120, [], cfg["calca"], 0.30)
    for sd in "lr":  # remendo no joelho, com costura
        k = (joelho[sd].x, joelho[sd].y - 0.055, joelho[sd].z)
        cur = pintar(nt, cur, mascara_esfera(nt, k, 0.0, 0.050), tuple(c * 1.25 for c in cfg["calca"]))
        cur = pintar(nt, cur, mascara_esfera(nt, k, 0.047, 0.053), tuple(c * 0.6 for c in cfg["calca"]))
    return cur
def pint_botas(nt):
    cur = tecido(nt, cfg["couro"], 0, [(-0.01, 0.022), (z_bota - 0.03, z_bota + 0.01)], (0.10, 0.065, 0.04), 0.18, couro=True)
    tira = caixa(nt, -1, 1, -1, 1, z_bota - 0.12, z_bota - 0.095)
    cur = pintar(nt, cur, tira, tuple(c * 0.5 for c in cfg["couro"]))
    fivela = caixa(nt, 0.045, 0.075, -1, 1, z_bota - 0.123, z_bota - 0.092, absx=True)
    return pintar(nt, cur, fivela, (0.42, 0.33, 0.16))
assar(tunica, "tunica", pint_tunica)
assar(calca, "calca", pint_calca)
assar(botas, "botas", pint_botas)
tunica.data.color_attributes.remove(tunica.data.color_attributes["forro_cor"])  # não exportar cor por vértice
for o in (tunica, calca, botas):  # AUT-020: roupas com uma face só (o avesso agora é o forro)
    for m in o.data.materials: m.use_backface_culling = True

# AUT-020 5: LOD manual simplificado da trança (só P2), alvo ~800 triângulos; o LOD automático do Godot continua valendo
if CFG["cabelo"] == "braid01":
    cab = pecas["cabelo"]; lod = cab.copy(); lod.data = cab.data.copy(); lod.name = "cabelo_lod"
    bpy.context.collection.objects.link(lod)
    for md in list(lod.modifiers):
        if md.type != "ARMATURE": lod.modifiers.remove(md)
    n_tri = sum(len(p.vertices) - 2 for p in lod.data.polygons)
    bpy.context.view_layer.objects.active = lod
    dm = lod.modifiers.new("lod", "DECIMATE"); dm.decimate_type = "COLLAPSE"; dm.ratio = 800.0 / n_tri; dm.use_collapse_triangulate = True
    bpy.ops.object.modifier_move_to_index(modifier="lod", index=0); bpy.ops.object.modifier_apply(modifier="lod")

# ---------- 6. exportação e medidas ----------
for o in bpy.data.objects:
    if o.type == "MESH":
        bpy.context.view_layer.objects.active = o
        o.data.validate()
malhas = [o for o in bpy.data.objects if o.type == "MESH"]
tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in malhas}
bpy.ops.object.select_all(action="DESELECT")
for o in malhas + [rig]: o.select_set(True)
bpy.ops.export_scene.gltf(filepath=f"{SAIDA}/mpfb_{SEXO}.glb", use_selection=True, export_skins=True, export_animations=False,
                          export_yup=True, export_image_format="AUTO")
info = {"sexo": SEXO, "altura_corpo_m": round(CFG["altura"], 2), "triangulos_por_malha": tris, "triangulos_total": sum(v for k, v in tris.items() if not k.endswith("_lod")),
        "z": {"barra_tunica": round(z_barra, 3), "cintura": round(z_cintura, 3), "topo_bota": round(z_bota, 3)},
        "fontes": {"pele": f"MakeHuman young_caucasian_{'male' if SEXO=='m' else 'female'} (CC0), repintada", "olhos": f"MakeHuman low-poly + {CFG['olho']} (CC0)",
                   "sobrancelha": f"MakeHuman {CFG['sobr']} (CC0)", "cilios": f"MakeHuman {CFG['cilio']} (CC0)", "cabelo": f"MakeHuman {CFG['cabelo']} (CC0), tingido",
                   "roupas": "Modeladas a partir de helper-skirt, helper-tights e da pele do corpo-base MakeHuman (CC0); pintura procedural própria"}}
info["aut020"] = {"vertices_saia_repesados": n_saia, "faces_forro": n_forro}
json.dump(info, open(f"{SAIDA}/mpfb_{SEXO}.json", "w"), ensure_ascii=False, indent=1)
if os.environ.get("V3_BLEND"):  # fonte editável (.blend) para conferência e retoque; os scripts continuam sendo a fonte principal
    for im in bpy.data.images:
        if im.source == "FILE" and im.filepath: im.pack()
    bpy.ops.wm.save_as_mainfile(filepath=os.environ["V3_BLEND"], compress=True)
print("FEITO", json.dumps(info, ensure_ascii=False))
