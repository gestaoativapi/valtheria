# Valtheria V3 — P5: espada longa original com guarda no motivo da Árvore (galhos na guarda, raízes no cabo,
# medalhão com a Árvore). 1 material com textura 512 px assada. Três graus pelo mesmo modelo:
#   D = ferro escuro e couro marrom;  B = aço azulado, guarda de bronze e folhas extras;
#   S = platina, guarda de ouro envelhecido, mais galhos e folhas, gema e runas acesas no sulco.
# Origem na ponta do cabo (pomo), lâmina em +Y no glTF, comprimento total 1,00 m (a tabela GRIP reescala).
# Uso: python espada_v3.py <pasta_saida>
import sys, os, math, json
import bpy, bmesh
import numpy as np
from mathutils import Vector, Matrix
SAIDA = sys.argv[-1]; os.makedirs(SAIDA, exist_ok=True)

GRAUS = {
    "d": dict(lamina=(0.30, 0.31, 0.32), fio=(0.55, 0.56, 0.57), guarda=(0.22, 0.21, 0.20), cabo=(0.16, 0.09, 0.05), runa=None, folhas=0, gema=None),
    "b": dict(lamina=(0.36, 0.42, 0.50), fio=(0.70, 0.74, 0.80), guarda=(0.45, 0.28, 0.12), cabo=(0.10, 0.06, 0.04), runa=None, folhas=1, gema=None),
    "s": dict(lamina=(0.72, 0.73, 0.76), fio=(0.92, 0.93, 0.95), guarda=(0.62, 0.45, 0.16), cabo=(0.55, 0.50, 0.42), runa=(0.35, 0.75, 1.0), folhas=2, gema=(0.15, 0.55, 0.85)),
}

def anel(bm, centro, eixo, raio_x, raio_y, n, lado=None):
    eixo = Vector(eixo).normalized(); a = Vector((1, 0, 0)) if abs(eixo.x) < 0.9 else Vector((0, 1, 0))
    u = eixo.cross(a).normalized(); w = eixo.cross(u).normalized()
    return [bm.verts.new(Vector(centro) + u * math.cos(2 * math.pi * k / n) * raio_x + w * math.sin(2 * math.pi * k / n) * raio_y) for k in range(n)]
def ponte(bm, a, b):
    n = len(a)
    for k in range(n): bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
def tampa(bm, a, centro):
    c = bm.verts.new(Vector(centro)); n = len(a)
    for k in range(n): bm.faces.new((a[k], a[(k + 1) % n], c))
def tubo(bm, pontos, raios, n=8, achata=1.0):
    aneis = []
    for i, p in enumerate(pontos):
        d = (Vector(pontos[min(i + 1, len(pontos) - 1)]) - Vector(pontos[max(i - 1, 0)])).normalized()
        aneis.append(anel(bm, p, d, raios[i], raios[i] * achata, n))
    for i in range(len(aneis) - 1): ponte(bm, aneis[i], aneis[i + 1])
    tampa(bm, aneis[0][::-1], pontos[0]); tampa(bm, aneis[-1], pontos[-1])
def folha(bm, base, direcao, comp=0.032, larg=0.013):
    d = Vector(direcao).normalized(); lado = d.cross(Vector((0, 1, 0))).normalized() * larg
    b = Vector(base); m = b + d * comp * 0.5; p = b + d * comp
    up = Vector((0, 1, 0)) * 0.004
    vs = [bm.verts.new(b), bm.verts.new(m + lado), bm.verts.new(p), bm.verts.new(m - lado), bm.verts.new(m + up), bm.verts.new(m - up)]
    for f in [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (0, 5, 1), (1, 5, 2), (2, 5, 3), (3, 5, 0)]: bm.faces.new([vs[i] for i in f])

def construir(grau):
    g = GRAUS[grau]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {}
    for nome in ("lamina", "guarda", "cabo", "pomo"):
        m = bpy.data.materials.new(nome); mats[nome] = m
    me = bpy.data.meshes.new("espada"); ob = bpy.data.objects.new(f"wp_espada_longa_{grau}", me); bpy.context.collection.objects.link(ob)
    for m in mats.values(): me.materials.append(m)
    bm = bmesh.new(); regiao = {}  # índice da face -> material

    def marcar(antes, mat):
        bm.faces.ensure_lookup_table()
        for f in bm.faces[antes:]: f.material_index = list(mats).index(mat)

    # pomo: semente da Árvore (ovoide com anel)
    n0 = len(bm.faces)
    perfil = [(0.000, 0.0), (0.006, 0.014), (0.016, 0.022), (0.030, 0.026), (0.044, 0.020), (0.052, 0.012), (0.056, 0.0)]
    aneis = [anel(bm, (0, 0, z), (0, 0, 1), max(r, 0.002), max(r, 0.002), 12) for z, r in perfil]
    for i in range(len(aneis) - 1): ponte(bm, aneis[i], aneis[i + 1])
    tampa(bm, aneis[0][::-1], (0, 0, -0.001)); tampa(bm, aneis[-1], (0, 0, 0.057))
    marcar(n0, "pomo")
    # cabo: couro enrolado (anéis alternados) + raízes da guarda descendo pelo cabo
    n0 = len(bm.faces)
    zs = np.linspace(0.056, 0.205, 16); aneis = [anel(bm, (0, 0, z), (0, 0, 1), 0.0150 + 0.0012 * (k % 2), 0.0135 + 0.0012 * (k % 2), 10) for k, z in enumerate(zs)]
    for i in range(len(aneis) - 1): ponte(bm, aneis[i], aneis[i + 1])
    marcar(n0, "cabo")
    n0 = len(bm.faces)
    for s in (1, -1):
        for ang in (0.0, math.pi):
            pts = [(math.cos(ang + s * t * 1.4) * 0.0168, math.sin(ang + s * t * 1.4) * 0.0152, 0.205 - t * 0.075) for t in np.linspace(0, 1, 7)]
            tubo(bm, pts, [0.0035 - 0.0028 * t for t in np.linspace(0, 1, 7)], n=5)
    marcar(n0, "guarda")
    # guarda: tronco central com medalhão + dois galhos que se abrem e sobem levemente, com forquilhas e folhas
    n0 = len(bm.faces)
    base = anel(bm, (0, 0, 0.205), (0, 0, 1), 0.020, 0.017, 12); topo = anel(bm, (0, 0, 0.245), (0, 0, 1), 0.024, 0.016, 12)
    ponte(bm, base, topo); tampa(bm, base[::-1], (0, 0, 0.205)); tampa(bm, topo, (0, 0, 0.245))
    for sy in (1, -1):  # medalhão nas duas faces, com a Árvore em relevo (tronco, três galhos, duas raízes)
        tubo(bm, [(0, sy * 0.010, 0.226), (0, sy * 0.017, 0.226)], [0.024, 0.022], n=20)
        yy = sy * 0.0185
        tubo(bm, [(0, yy, 0.210), (0, yy, 0.232)], [0.0022, 0.0016], n=5)
        for dx, dz in [(-0.010, 0.012), (0.0, 0.016), (0.010, 0.012)]:
            tubo(bm, [(0, yy, 0.229), (dx * 0.6, yy, 0.229 + dz * 0.6), (dx, yy, 0.229 + dz)], [0.0016, 0.0013, 0.0009], n=5)
        for dx in (-0.009, 0.009):
            tubo(bm, [(0, yy, 0.212), (dx, yy, 0.207)], [0.0015, 0.0008], n=5)
    for sx in (1, -1):
        caminho = [(sx * (0.020 + 0.085 * t), 0, 0.226 + 0.034 * t ** 2.0) for t in np.linspace(0, 1, 9)]
        tubo(bm, caminho, [0.0085 - 0.0050 * t for t in np.linspace(0, 1, 9)], n=7, achata=0.75)
        ponta = Vector(caminho[-1])
        tubo(bm, [ponta, ponta + Vector((sx * 0.018, 0, 0.012))], [0.0035, 0.0012], n=5)
        tubo(bm, [ponta, ponta + Vector((sx * 0.010, 0, -0.013))], [0.0032, 0.0011], n=5)
        folha(bm, ponta + Vector((sx * 0.012, 0, 0.008)), (sx * 0.6, 0, 1.0))
        for k in range(g["folhas"]):  # ornamento por grau: folhas extras ao longo do galho
            t = 0.45 + 0.25 * k; p = Vector(caminho[int(t * 8)])
            folha(bm, p + Vector((0, 0, 0.004)), (sx * 0.4, 0, 1.0), comp=0.024, larg=0.010)
            folha(bm, p + Vector((0, 0, -0.004)), (sx * 0.5, 0, -1.0), comp=0.020, larg=0.009)
    marcar(n0, "guarda")
    if g["gema"]:
        n0 = len(bm.faces)
        for sy in (1, -1):
            tubo(bm, [(0, sy * 0.019, 0.226), (0, sy * 0.024, 0.226)], [0.009, 0.004], n=10)
        marcar(n0, "pomo")
    # lâmina: seção em losango com sulco central, afinando até a ponta
    n0 = len(bm.faces)
    estacoes = [(0.245, 0.052, 0.0105), (0.30, 0.050, 0.0098), (0.50, 0.047, 0.0090), (0.70, 0.044, 0.0082), (0.86, 0.040, 0.0074), (0.93, 0.030, 0.0062), (0.975, 0.014, 0.0040)]
    secs = []
    for z, w, e in estacoes:
        h, f = w / 2, (0.0016 if z < 0.86 else 0.0)
        pts = [(h, 0), (h * 0.45, e / 2), (h * 0.12, e / 2 - f), (0, e / 2 - f), (-h * 0.12, e / 2 - f), (-h * 0.45, e / 2), (-h, 0),
               (-h * 0.45, -e / 2), (-h * 0.12, -e / 2 + f), (0, -e / 2 + f), (h * 0.12, -e / 2 + f), (h * 0.45, -e / 2)]
        secs.append([bm.verts.new((x, y, z)) for x, y in pts])
    for i in range(len(secs) - 1): ponte(bm, secs[i], secs[i + 1])
    tampa(bm, secs[0][::-1], (0, 0, 0.245)); tampa(bm, secs[-1], (0, 0, 1.0))
    marcar(n0, "lamina")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True

    # pintura procedural por região -> uma textura 512 px (cor) + emissão das runas no grau S
    sc = bpy.context.scene; sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 8
    sc.render.bake.margin = 4; sc.render.bake.use_pass_direct = False; sc.render.bake.use_pass_indirect = False; sc.render.bake.use_pass_color = True
    img = bpy.data.images.new(f"tx_espada_longa_{grau}", 512, 512)
    for nome, m in mats.items():
        m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
        co = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(co.outputs["Object"], sep.inputs[0])
        nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 60; nt.links.new(co.outputs["Object"], nz.inputs["Vector"])
        cr = nt.nodes.new("ShaderNodeValToRGB"); nt.links.new(nz.outputs["Fac"], cr.inputs[0])
        if nome == "lamina":  # escovado no comprimento + fio claro nas bordas (|x| grande)
            cr.color_ramp.elements[0].color = (*[c * 0.85 for c in g["lamina"]], 1); cr.color_ramp.elements[1].color = (*g["lamina"], 1)
            ab = nt.nodes.new("ShaderNodeMath"); ab.operation = "ABSOLUTE"; nt.links.new(sep.outputs["X"], ab.inputs[0])
            mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs[1].default_value = 0.012; mr.inputs[2].default_value = 0.020; nt.links.new(ab.outputs[0], mr.inputs[0])
            mx = nt.nodes.new("ShaderNodeMix"); mx.data_type = "RGBA"; nt.links.new(mr.outputs[0], mx.inputs[0])
            nt.links.new(cr.outputs[0], mx.inputs[6]); mx.inputs[7].default_value = (*g["fio"], 1); saida = mx.outputs[2]
            if g["runa"]:  # runas no sulco: marcas regulares ao longo do comprimento
                wv = nt.nodes.new("ShaderNodeTexWave"); wv.inputs["Scale"].default_value = 3.0; wv.bands_direction = "Z"
                nt.links.new(co.outputs["Object"], wv.inputs["Vector"])
                lim = nt.nodes.new("ShaderNodeMath"); lim.operation = "GREATER_THAN"; lim.inputs[1].default_value = 0.82; nt.links.new(wv.outputs["Fac"], lim.inputs[0])
                cen = nt.nodes.new("ShaderNodeMath"); cen.operation = "LESS_THAN"; cen.inputs[1].default_value = 0.006; nt.links.new(ab.outputs[0], cen.inputs[0])
                zz = nt.nodes.new("ShaderNodeMath"); zz.operation = "LESS_THAN"; zz.inputs[1].default_value = 0.80; nt.links.new(sep.outputs["Z"], zz.inputs[0])
                m1 = nt.nodes.new("ShaderNodeMath"); m1.operation = "MULTIPLY"; nt.links.new(lim.outputs[0], m1.inputs[0]); nt.links.new(cen.outputs[0], m1.inputs[1])
                m2 = nt.nodes.new("ShaderNodeMath"); m2.operation = "MULTIPLY"; nt.links.new(m1.outputs[0], m2.inputs[0]); nt.links.new(zz.outputs[0], m2.inputs[1])
                mr2 = nt.nodes.new("ShaderNodeMix"); mr2.data_type = "RGBA"; nt.links.new(m2.outputs[0], mr2.inputs[0])
                nt.links.new(saida, mr2.inputs[6]); mr2.inputs[7].default_value = (*g["runa"], 1); saida = mr2.outputs[2]
        elif nome == "cabo":  # couro com faixas do enrolamento
            wv = nt.nodes.new("ShaderNodeTexWave"); wv.inputs["Scale"].default_value = 9.0; wv.bands_direction = "Z"; nt.links.new(co.outputs["Object"], wv.inputs["Vector"])
            cr.color_ramp.elements[0].color = (*[c * 0.7 for c in g["cabo"]], 1); cr.color_ramp.elements[1].color = (*g["cabo"], 1)
            nt.links.new(wv.outputs["Fac"], cr.inputs[0]); saida = cr.outputs[0]
        else:  # guarda e pomo: metal do grau, com sujeira nos vãos
            base = g["guarda"] if nome == "guarda" else (g["gema"] if (g["gema"] and False) else g["guarda"])
            cr.color_ramp.elements[0].color = (*[c * 0.6 for c in base], 1); cr.color_ramp.elements[1].color = (*[min(1, c * 1.15) for c in base], 1)
            saida = cr.outputs[0]
        nt.links.new(saida, b.inputs["Base Color"])
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = img; nt.nodes.active = t
    bpy.context.view_layer.objects.active = ob; ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(55), island_margin=0.01); bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.bake(type="DIFFUSE")
    cor = np.array(img.pixels[:]).reshape(-1, 4).copy()
    ao = bpy.data.images.new("ao", 512, 512)
    for m in mats.values(): m.node_tree.nodes.active.image = ao
    sc.cycles.samples = 24; bpy.ops.object.bake(type="AO")
    a = np.array(ao.pixels[:]).reshape(-1, 4)[:, :1]; cor[:, :3] = np.clip(cor[:, :3] * (0.55 + 0.45 * a), 0, 1)
    img.pixels = cor.reshape(-1).tolist(); img.filepath_raw = f"{SAIDA}/tx_espada_longa_{grau}.png"; img.file_format = "PNG"; img.save()
    # emissão (runas) do grau S: máscara pelos pixels azuis da textura
    emi = None
    if g["runa"]:
        px = cor[:, :3]; mask = (px[:, 2] > px[:, 0] * 1.6) & (px[:, 2] > 0.35)
        e = np.zeros_like(cor); e[:, 3] = 1; e[mask, :3] = np.array(g["runa"])
        emi = bpy.data.images.new(f"tx_espada_longa_{grau}_emissao", 512, 512); emi.pixels = e.reshape(-1).tolist()
        emi.filepath_raw = f"{SAIDA}/tx_espada_longa_{grau}_emissao.png"; emi.file_format = "PNG"; emi.save()
    # material único final
    final = bpy.data.materials.new(f"espada_longa_{grau}"); final.use_nodes = True; nt = final.node_tree; b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = img; nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Metallic"].default_value = 0.85; b.inputs["Roughness"].default_value = 0.38
    if emi is not None:
        te = nt.nodes.new("ShaderNodeTexImage"); te.image = emi
        nt.links.new(te.outputs["Color"], b.inputs["Emission Color"]); b.inputs["Emission Strength"].default_value = 2.0
    me.materials.clear(); me.materials.append(final)
    bpy.ops.export_scene.gltf(filepath=f"{SAIDA}/wp_espada_longa_{grau}.glb", use_selection=True, export_yup=True, export_image_format="AUTO")
    tri = sum(len(p.vertices) - 2 for p in me.polygons); dims = ob.dimensions
    return {"arquivo": f"wp_espada_longa_{grau}.glb", "triangulos": tri, "materiais": 1, "textura": "512x512" + (" + emissão" if emi else ""),
            "comprimento_m": round(dims.z, 3), "largura_guarda_m": round(dims.x, 3)}

res = [construir(gr) for gr in ("d", "b", "s")]
json.dump(res, open(f"{SAIDA}/espada_longa.json", "w"), ensure_ascii=False, indent=1)
print("FEITO", json.dumps(res, ensure_ascii=False))
