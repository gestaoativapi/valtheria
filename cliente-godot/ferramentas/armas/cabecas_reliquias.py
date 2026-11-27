#!/usr/bin/env python3
"""Cabeças esculpidas das Relíquias de Criaturas (27/11) — modelagem procedural no Blender (bpy), sem arquivo pago.

Cada parte orgânica é um "esqueleto" de pontos com raios (modificador Skin) suavizado por subdivisão: crânio,
focinho, mandíbula, chifres, orelhas, penas e barbatanas saem com forma contínua, como escultura. Olhos, presas
e brasas são peças à parte. Materiais por nome (o jogo troca pelos da criatura): metal, escuro, olho, brilho, dente.
Saída: assets/armas/reliquias/<criatura>.glb, com 1 unidade = largura da cabeça, focinho em +Z e topo em +Y (Godot).
Uso: python3 ferramentas/armas/cabecas_reliquias.py   (precisa do módulo bpy)
"""
import math, os
import bpy

DEST = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'armas', 'reliquias')


def g2b(p):  # Godot (x, y, z) -> Blender (x, -z, y)
    return (p[0], -p[2], p[1])


def limpar():
    bpy.ops.wm.read_factory_settings(use_empty=True)


_mats = {}


def mat(nome, cor, metal=0.0, rug=0.5, emis=0.0):
    if nome in _mats:
        return _mats[nome]
    m = bpy.data.materials.new(nome)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*cor, 1)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rug
    if emis > 0:
        b.inputs['Emission Color'].default_value = (*cor, 1)
        b.inputs['Emission Strength'].default_value = emis
    _mats[nome] = m
    return m


def esqueleto(nome, pontos, ligacoes, raios, material, sub=2, achatar=None):
    """pontos em coordenadas do Godot; raios (rx, ry) por ponto; ligacoes = pares de índices."""
    me = bpy.data.meshes.new(nome)
    me.from_pydata([g2b(p) for p in pontos], ligacoes, [])
    ob = bpy.data.objects.new(nome, me)
    bpy.context.collection.objects.link(ob)
    sk = ob.modifiers.new('skin', 'SKIN')
    sk.use_smooth_shade = True
    for i, r in enumerate(raios):
        r = r if isinstance(r, (tuple, list)) else (r, r)
        me.skin_vertices[0].data[i].radius = r
    me.skin_vertices[0].data[0].use_root = True
    s = ob.modifiers.new('sub', 'SUBSURF')
    s.levels = sub
    s.render_levels = sub
    ob.data.materials.append(material)
    return ob


def esfera(nome, centro, r, material, esc=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=r, location=g2b(centro))
    ob = bpy.context.active_object
    ob.name = nome
    ob.scale = (esc[0], esc[2], esc[1])
    bpy.ops.object.shade_smooth()
    ob.data.materials.append(material)
    return ob


def cone(nome, base, ponta, r, material, lados=8):
    import mathutils
    a = mathutils.Vector(g2b(base))
    b = mathutils.Vector(g2b(ponta))
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=lados, radius1=r, radius2=0.0, depth=d.length, location=(a + b) / 2)
    ob = bpy.context.active_object
    ob.name = nome
    ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = mathutils.Vector((0, 0, 1)).rotation_difference(d.normalized())
    ob.data.materials.append(material)
    return ob


def chifre(nome, raiz, pontos, r0, material):
    """chifre/pena/orelha curvo: raiz + pontos, afinando até a ponta"""
    pts = [raiz] + pontos
    n = len(pts)
    raios = [max(r0 * (1 - i / (n - 0.6)), 0.004) for i in range(n)]
    return esqueleto(nome, pts, [(i, i + 1) for i in range(n - 1)], raios, material, sub=1)


def M(cores):
    brilho, cor, sombra, metal = cores
    return {
        'metal': mat('metal', metal, 0.85, 0.32),
        'escuro': mat('escuro', sombra, 0.6, 0.45),
        'olho': mat('olho', brilho, 0, 0.2, 5.0),
        'brilho': mat('brilho', cor, 0.2, 0.3, 2.5),
        'dente': mat('dente', (0.93, 0.9, 0.82), 0.0, 0.4),
    }


def dragao(m):
    # crânio alongado -> focinho fino; mandíbula aberta; chifres longos que varrem para trás e se abrem para fora
    esqueleto('cranio', [(0, 0.04, -0.45), (0, 0.08, -0.12), (0, 0.06, 0.25), (0, 0.03, 0.62), (0, -0.01, 0.98)], [(0, 1), (1, 2), (2, 3), (3, 4)],
              [(0.34, 0.28), (0.4, 0.33), (0.3, 0.24), (0.2, 0.15), (0.12, 0.09)], m['metal'])
    esqueleto('mandibula', [(0, -0.12, -0.08), (0, -0.28, 0.35), (0, -0.4, 0.8)], [(0, 1), (1, 2)],
              [(0.28, 0.13), (0.2, 0.08), (0.1, 0.045)], m['escuro'])
    for s in (-1, 1):
        esqueleto(f'sobr{s}', [(0.15 * s, 0.27, 0.02), (0.2 * s, 0.31, 0.34)], [(0, 1)], [0.09, 0.05], m['escuro'], sub=1)
        # chifre principal: sobe e abre, depois varre para trás com a ponta virando para cima
        chifre(f'chifre{s}', (0.2 * s, 0.34, -0.1), [(0.34 * s, 0.62, -0.38), (0.52 * s, 0.78, -0.78), (0.6 * s, 0.98, -1.15)], 0.12, m['escuro'])
        chifre(f'chifre2{s}', (0.3 * s, 0.16, -0.25), [(0.58 * s, 0.32, -0.5), (0.78 * s, 0.46, -0.72)], 0.07, m['escuro'])
        # leque de espinhos na bochecha, abrindo para os lados (não para baixo)
        for i, z in enumerate((-0.3, -0.45, -0.6)):
            chifre(f'espinho{s}{i}', (0.3 * s, 0.02 - 0.03 * i, z), [(0.62 * s, 0.08 - 0.06 * i, z - 0.2)], 0.055, m['escuro'])
        esfera(f'olho{s}', (0.2 * s, 0.22, 0.3), 0.065, m['olho'], (1, 0.65, 1.35))
        esfera(f'narina{s}', (0.06 * s, 0.06, 0.95), 0.028, m['brilho'])
        for i in range(4):
            cone(f'dente{s}{i}', (0.09 * s, -0.03, 0.42 + 0.14 * i), (0.09 * s, -0.17, 0.44 + 0.14 * i), 0.026, m['dente'], 6)
            cone(f'dentei{s}{i}', (0.08 * s, -0.3, 0.4 + 0.13 * i), (0.08 * s, -0.17, 0.42 + 0.13 * i), 0.021, m['dente'], 6)
    esqueleto('crista', [(0, 0.32, 0.12), (0, 0.46, -0.25), (0, 0.44, -0.65)], [(0, 1), (1, 2)], [(0.035, 0.13), (0.03, 0.1), (0.01, 0.04)], m['escuro'], sub=1)
    esfera('brasa', (0, -0.14, 0.45), 0.1, m['brilho'], (1.3, 0.6, 2.2))


def lobo(m):
    esqueleto('cranio', [(0, 0.02, -0.35), (0, 0.06, 0.0), (0, 0.0, 0.35), (0, -0.04, 0.72)], [(0, 1), (1, 2), (2, 3)],
              [(0.38, 0.32), (0.4, 0.34), (0.24, 0.2), (0.11, 0.09)], m['metal'])
    esqueleto('mandibula', [(0, -0.14, 0.0), (0, -0.24, 0.35), (0, -0.3, 0.62)], [(0, 1), (1, 2)], [(0.24, 0.12), (0.16, 0.07), (0.07, 0.04)], m['escuro'])
    for s in (-1, 1):
        chifre(f'orelha{s}', (0.2 * s, 0.3, -0.12), [(0.26 * s, 0.55, -0.15), (0.3 * s, 0.78, -0.22)], 0.13, m['metal'])
        for i in range(4):
            chifre(f'juba{s}{i}', (0.3 * s, 0.2 - 0.14 * i, -0.3), [(0.5 * s, 0.25 - 0.18 * i, -0.62), (0.58 * s, 0.22 - 0.2 * i, -0.85)], 0.09, m['escuro'])
        esfera(f'olho{s}', (0.18 * s, 0.16, 0.26), 0.055, m['olho'], (1, 0.6, 1.4))
        cone(f'presa{s}', (0.07 * s, -0.08, 0.55), (0.07 * s, -0.24, 0.58), 0.03, m['dente'], 6)
    esfera('focinho', (0, 0.0, 0.76), 0.05, m['escuro'])


def golem(m):
    # crânio de pedra esculpido: testa pesada, maçãs largas, queixo quadrado, olhos fundos acesos e uma runa na testa
    esqueleto('cranio', [(0, 0.0, -0.3), (0, 0.08, 0.0), (0, 0.04, 0.3)], [(0, 1), (1, 2)],
              [(0.42, 0.4), (0.48, 0.44), (0.36, 0.3)], m['metal'], sub=1)
    esqueleto('testa', [(-0.36, 0.26, 0.3), (0, 0.32, 0.38), (0.36, 0.26, 0.3)], [(0, 1), (1, 2)], [(0.1, 0.11), (0.12, 0.12), (0.1, 0.11)], m['escuro'], sub=1)
    esqueleto('queixo', [(0, -0.28, 0.05), (0, -0.4, 0.3)], [(0, 1)], [(0.34, 0.14), (0.26, 0.12)], m['escuro'], sub=1)
    for s in (-1, 1):
        esqueleto(f'maca{s}', [(0.32 * s, -0.02, 0.1), (0.3 * s, -0.08, 0.34)], [(0, 1)], [(0.14, 0.12), (0.1, 0.09)], m['escuro'], sub=1)
        esfera(f'olho{s}', (0.17 * s, 0.13, 0.4), 0.07, m['olho'], (1.3, 0.55, 0.6))
        # placas de rocha e chifres curtos e grossos
        chifre(f'chifre{s}', (0.38 * s, 0.25, -0.05), [(0.62 * s, 0.45, -0.15), (0.72 * s, 0.7, -0.2)], 0.14, m['escuro'])
        chifre(f'placa{s}', (0.24 * s, 0.38, -0.1), [(0.32 * s, 0.6, -0.3)], 0.1, m['escuro'])
    for i, x in enumerate((-0.16, 0.0, 0.16)):
        cone(f'dente{i}', (x, -0.22, 0.42), (x, -0.32, 0.44), 0.05, m['dente'], 5)
    esfera('runa', (0, 0.3, 0.47), 0.05, m['brilho'], (0.6, 1.6, 0.4))
    esfera('boca', (0, -0.18, 0.4), 0.05, m['brilho'], (3.0, 0.5, 0.6))


def serpente(m):
    esqueleto('cranio', [(0, 0.0, -0.4), (0, 0.04, -0.05), (0, 0.02, 0.35), (0, -0.02, 0.8)], [(0, 1), (1, 2), (2, 3)],
              [(0.34, 0.26), (0.4, 0.28), (0.28, 0.18), (0.13, 0.08)], m['metal'])
    esqueleto('mandibula', [(0, -0.12, 0.0), (0, -0.22, 0.45), (0, -0.26, 0.72)], [(0, 1), (1, 2)], [(0.26, 0.1), (0.18, 0.06), (0.08, 0.03)], m['escuro'])
    for s in (-1, 1):
        for i in range(4):
            # barbatanas de gelo em leque (raios achatados)
            chifre(f'barb{s}{i}', (0.26 * s, 0.12, -0.25 + 0.14 * i), [(0.55 * s, 0.4 - 0.05 * i, -0.45 + 0.1 * i), (0.75 * s, 0.55 - 0.08 * i, -0.65 + 0.08 * i)], 0.07, m['brilho'])
        esfera(f'olho{s}', (0.2 * s, 0.14, 0.3), 0.05, m['olho'], (1, 0.7, 1.4))
        cone(f'presa{s}', (0.08 * s, -0.08, 0.62), (0.08 * s, -0.3, 0.66), 0.035, m['dente'], 6)
    for i in range(5):
        chifre(f'crista{i}', (0, 0.22, -0.3 + 0.15 * i), [(0, 0.5 - 0.05 * i, -0.45 + 0.13 * i)], 0.05, m['brilho'])


def fenix(m):
    esqueleto('cabeca', [(0, -0.05, -0.3), (0, 0.05, 0.0), (0, 0.04, 0.22)], [(0, 1), (1, 2)], [(0.3, 0.3), (0.36, 0.36), (0.26, 0.24)], m['metal'])
    # bico curvo dourado
    esqueleto('bico', [(0, 0.04, 0.3), (0, -0.02, 0.58), (0, -0.14, 0.75)], [(0, 1), (1, 2)], [(0.12, 0.12), (0.07, 0.06), (0.01, 0.01)], m['brilho'], sub=1)
    for i in range(5):
        a = (i / 4 - 0.5) * 1.3
        chifre(f'crista{i}', (math.sin(a) * 0.1, 0.3, -0.05), [(math.sin(a) * 0.35, 0.65, -0.3), (math.sin(a) * 0.5, 0.95, -0.55), (math.sin(a) * 0.45, 1.15, -0.85)], 0.07, m['brilho'])
    for s in (-1, 1):
        esfera(f'olho{s}', (0.19 * s, 0.12, 0.22), 0.05, m['olho'], (1, 0.8, 1.3))
        for i in range(3):
            chifre(f'pena{s}{i}', (0.25 * s, -0.05 - 0.1 * i, -0.2), [(0.5 * s, -0.1 - 0.15 * i, -0.45), (0.72 * s, -0.08 - 0.2 * i, -0.62)], 0.07, m['brilho'])


def grifo(m):
    esqueleto('cabeca', [(0, 0.0, -0.35), (0, 0.06, 0.0), (0, 0.06, 0.25)], [(0, 1), (1, 2)], [(0.34, 0.34), (0.38, 0.38), (0.26, 0.26)], m['metal'])
    # bico de águia em gancho
    esqueleto('bico', [(0, 0.08, 0.3), (0, 0.06, 0.58), (0, -0.04, 0.76), (0, -0.18, 0.74)], [(0, 1), (1, 2), (2, 3)],
              [(0.15, 0.17), (0.1, 0.12), (0.05, 0.06), (0.01, 0.01)], m['escuro'], sub=1)
    esqueleto('bico_inf', [(0, -0.06, 0.32), (0, -0.1, 0.55)], [(0, 1)], [(0.1, 0.06), (0.03, 0.02)], m['escuro'], sub=1)
    for s in (-1, 1):
        esfera(f'olho{s}', (0.19 * s, 0.16, 0.22), 0.055, m['olho'], (1, 0.7, 1.4))
        esqueleto(f'sobr{s}', [(0.12 * s, 0.26, 0.12), (0.2 * s, 0.28, 0.32)], [(0, 1)], [0.06, 0.03], m['escuro'], sub=1)
        for i in range(4):
            chifre(f'pena{s}{i}', (0.18 * s, 0.25 - 0.12 * i, -0.25), [(0.4 * s, 0.38 - 0.16 * i, -0.55), (0.5 * s, 0.42 - 0.2 * i, -0.85)], 0.08, m['brilho'])


CORES = {  # (brilho, cor, sombra, metal) — iguais às de reliquias.gd; o jogo troca pelos dele
    'dragao': ((1.0, 0.82, 0.48), (1.0, 0.35, 0.12), (0.35, 0.05, 0.02), (0.32, 0.1, 0.08)),
    'lobo': ((0.86, 0.8, 1.0), (0.52, 0.36, 1.0), (0.1, 0.05, 0.22), (0.16, 0.14, 0.22)),
    'golem': ((1.0, 0.88, 0.55), (0.86, 0.56, 0.22), (0.18, 0.13, 0.08), (0.36, 0.32, 0.28)),
    'serpente': ((0.88, 0.98, 1.0), (0.3, 0.78, 1.0), (0.03, 0.15, 0.26), (0.55, 0.7, 0.8)),
    'fenix': ((1.0, 0.97, 0.8), (1.0, 0.68, 0.2), (0.3, 0.12, 0.02), (0.85, 0.66, 0.32)),
    'grifo': ((0.92, 0.99, 1.0), (0.55, 0.84, 1.0), (0.07, 0.18, 0.28), (0.62, 0.6, 0.55)),
}
FEITOS = {'dragao': dragao, 'lobo': lobo, 'golem': golem, 'serpente': serpente, 'fenix': fenix, 'grifo': grifo}

if __name__ == '__main__':
    os.makedirs(DEST, exist_ok=True)
    for nome, f in FEITOS.items():
        limpar()
        _mats.clear()
        f(M(CORES[nome]))
        # aplica os modificadores e junta tudo num objeto só
        bpy.ops.object.select_all(action='SELECT')
        bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
        bpy.ops.object.convert(target='MESH')
        bpy.ops.object.join()
        ob = bpy.context.active_object
        ob.name = nome
        # 1 unidade = largura do crânio (já está nessa escala) — exporta com Y para cima
        caminho = os.path.join(DEST, f'{nome}.glb')
        bpy.ops.export_scene.gltf(filepath=caminho, export_format='GLB', use_selection=True, export_yup=True, export_apply=True)
        print('ok', nome, len(ob.data.polygons), 'faces')
