# Valtheria V3 — liga TODAS as peças de um personagem MPFB (corpo, olhos, pelos, cabelo, roupas, com textura)
# ao ESQUELETO DO JOGO (65 ossos, mesmas rotações de repouso) e grava um .glb por peça.
# Mesmo método validado na V2 (ferramentas/v2/ligar_esqueleto.py), agora para várias malhas e materiais:
# 1) posa o MPFB para cada osso apontar como o osso do jogo; 2) cria o esqueleto final com as rotações de repouso
# do jogo e as articulações na anatomia nova; 3) pesos por nome (osso que o jogo não tem -> osso pai).
# Uso: python ligar_pecas.py <glb_do_jogo_com_65_ossos> <mpfb.glb> <pasta_saida> '<json grupos>'
#   grupos: {"pc_humano_m": ["corpo","olhos","sobrancelha","cilios"], "rp_aldeao_tunica_m": ["tunica"], ...}
import sys, json, struct, os, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gltf_io import load, acc, trs, m2q
JOGO, V3, SAIDA, GRUPOS = sys.argv[1], sys.argv[2], sys.argv[3], json.loads(sys.argv[4])
os.makedirs(SAIDA, exist_ok=True)

def esqueleto(j, skin=0):
    par = {}
    for i, n in enumerate(j['nodes']):
        for c in n.get('children', []): par[c] = i
    joints = j['skins'][skin]['joints']; js = set(joints); G = {}
    def glob(i):
        if i in G: return G[i]
        m = trs(j['nodes'][i])
        if par.get(i) in js: m = glob(par[i]) @ m
        G[i] = m; return m
    nomes = [j['nodes'][i]['name'] for i in joints]
    return (nomes, {j['nodes'][i]['name'].lower(): glob(i) for i in joints},
            {j['nodes'][i]['name'].lower(): (j['nodes'][par[i]]['name'].lower() if par.get(i) in js else None) for i in joints},
            {j['nodes'][i]['name'].lower(): trs(j['nodes'][i]) for i in joints})

jg, bg = load(JOGO); nomes_jogo, Gj, Pj, Lj = esqueleto(jg)
jv, bv = load(V3); nomes_v, Gv, Pv, Lv = esqueleto(jv)

FILHO = {'pelvis': 'spine_01', 'spine_01': 'spine_02', 'spine_02': 'spine_03', 'spine_03': 'neck_01', 'neck_01': 'head',
         'clavicle_l': 'upperarm_l', 'upperarm_l': 'lowerarm_l', 'lowerarm_l': 'hand_l', 'hand_l': 'middle_01_l',
         'clavicle_r': 'upperarm_r', 'upperarm_r': 'lowerarm_r', 'lowerarm_r': 'hand_r', 'hand_r': 'middle_01_r',
         'thigh_l': 'calf_l', 'calf_l': 'foot_l', 'foot_l': 'ball_l', 'thigh_r': 'calf_r', 'calf_r': 'foot_r', 'foot_r': 'ball_r'}
for s in 'lr':
    for d in ['index', 'middle', 'ring', 'pinky', 'thumb']:
        FILHO[f'{d}_01_{s}'] = f'{d}_02_{s}'; FILHO[f'{d}_02_{s}'] = f'{d}_03_{s}'
def arco(a, b):
    a = a / np.linalg.norm(a); b = b / np.linalg.norm(b); v = np.cross(a, b); c = float(np.dot(a, b))
    if c < -0.9999:
        ax = np.cross(a, [1, 0, 0]); ax = ax if np.linalg.norm(ax) > 1e-6 else np.cross(a, [0, 1, 0]); ax /= np.linalg.norm(ax)
        return 2 * np.outer(ax, ax) - np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx / (1 + c)

raiz = [n for n, p in Pv.items() if p is None][0]
ordem = []
def visita(n):
    ordem.append(n)
    for k, p in Pv.items():
        if p == n: visita(k)
visita(raiz)
T = {}
for n in ordem:
    p = Pv[n]
    T[n] = Gv[n].copy() if p is None else T[p] @ np.linalg.inv(Gv[p]) @ Gv[n]
    f = FILHO.get(n)
    if f and f in Gv and f in Gj and n in Gj:
        pos = T[n][:3, 3]; agora = (T[n] @ np.linalg.inv(Gv[n]) @ Gv[f])[:3, 3]
        R = arco(agora - pos, Gj[f][:3, 3] - Gj[n][:3, 3])
        M = np.eye(4); M[:3, :3] = R; Tr = np.eye(4); Tr[:3, 3] = pos; Ti = np.eye(4); Ti[:3, 3] = -pos
        T[n] = Tr @ M @ Ti @ T[n]
S = {n: T[n] @ np.linalg.inv(Gv[n]) for n in T}

NEW = {}
esc = np.linalg.norm(T['head'][:3, 3] - T['pelvis'][:3, 3]) / np.linalg.norm(Gj['head'][:3, 3] - Gj['pelvis'][:3, 3])
jordem = [n.lower() for n in nomes_jogo]
def novo(n):
    if n in NEW: return NEW[n]
    R = Gj[n][:3, :3] / np.linalg.norm(Gj[n][:3, :3], axis=0); M = np.eye(4); M[:3, :3] = R
    if n in T: M[:3, 3] = T[n][:3, 3]
    else:
        p = Pj[n]; pm = novo(p)
        M[:3, 3] = (pm @ np.linalg.inv(Gj[p]) @ Gj[n])[:3, 3] if p else Gj[n][:3, 3]
        M[:3, 3] = pm[:3, 3] + (M[:3, 3] - pm[:3, 3]) * esc
    NEW[n] = M; return M
for n in jordem: novo(n)
dif = []
for n in jordem:
    p = Pj[n]; lr = (np.linalg.inv(NEW[p]) @ NEW[n])[:3, :3] if p else NEW[n][:3, :3]
    lj = Lj[n][:3, :3] / np.linalg.norm(Lj[n][:3, :3], axis=0)
    dif.append(np.degrees(np.arccos(np.clip((np.trace(lr.T @ lj) - 1) / 2, -1, 1))))
def alvo(n):
    while n not in jordem: n = Pv[n]
    return jordem.index(n)

# ---- leitura de cada malha (com a skin própria de cada uma) ----
pecas = {}
for ni, nd in enumerate(jv['nodes']):
    if 'mesh' not in nd: continue
    nome = nd['name']; sk = jv['skins'][nd.get('skin', 0)]
    jn = [jv['nodes'][i]['name'].lower() for i in sk['joints']]
    mats = np.stack([S[n] for n in jn]); mapa = np.array([alvo(n) for n in jn])
    prims = []
    for pr in jv['meshes'][nd['mesh']]['primitives']:
        at = pr['attributes']
        P = acc(jv, bv, at['POSITION']).astype(np.float64); N = acc(jv, bv, at['NORMAL']).astype(np.float64)
        UV = acc(jv, bv, at['TEXCOORD_0']).astype(np.float32) if 'TEXCOORD_0' in at else None
        J = acc(jv, bv, at['JOINTS_0']).astype(np.int64); W = acc(jv, bv, at['WEIGHTS_0']).astype(np.float64)
        W = W / np.maximum(W.sum(1, keepdims=True), 1e-9)
        M = np.einsum('vk,vkij->vij', W, mats[J])
        P2 = np.einsum('vij,vj->vi', M[:, :3, :3], P) + M[:, :3, 3]
        N2 = np.einsum('vij,vj->vi', M[:, :3, :3], N); N2 /= np.linalg.norm(N2, axis=1, keepdims=True)
        J2 = mapa[J]
        # o mesmo osso pode aparecer duas vezes depois do mapeamento (ex.: breast -> spine_03): soma os pesos
        Jf = np.zeros_like(J2); Wf = np.zeros_like(W)
        for v in range(len(J2)):
            d = {}
            for k in range(4):
                if W[v, k] > 0: d[J2[v, k]] = d.get(J2[v, k], 0) + W[v, k]
            it = sorted(d.items(), key=lambda x: -x[1])[:4]
            for k, (jj, ww) in enumerate(it): Jf[v, k] = jj; Wf[v, k] = ww
        Wf /= np.maximum(Wf.sum(1, keepdims=True), 1e-9)
        IDX = acc(jv, bv, pr['indices']).reshape(-1)
        prims.append(dict(P=P2, N=N2, UV=UV, J=Jf, W=Wf, I=IDX, mat=pr.get('material')))
    pecas[nome] = prims

def imagem(ti):
    tex = jv['textures'][ti]; im = jv['images'][tex['source']]; bvw = jv['bufferViews'][im['bufferView']]
    o = bvw.get('byteOffset', 0); return bytes(bv[o:o + bvw['byteLength']]), im.get('mimeType', 'image/png')

def gravar(arquivo, nomes_pecas):
    buf = bytearray(); views = []; accs = []; imgs = []; texs = []; mats = []
    def add(arr, comp, typ, target=None, mm=False):
        arr = np.ascontiguousarray(arr)
        while len(buf) % 4: buf.append(0)
        off = len(buf); buf.extend(arr.tobytes()); v = {'buffer': 0, 'byteOffset': off, 'byteLength': arr.nbytes}
        if target: v['target'] = target
        views.append(v); a = {'bufferView': len(views) - 1, 'componentType': comp, 'count': int(arr.shape[0]), 'type': typ}
        if mm: a['min'] = arr.min(0).tolist(); a['max'] = arr.max(0).tolist()
        accs.append(a); return len(accs) - 1
    def add_bytes(b):
        while len(buf) % 4: buf.append(0)
        off = len(buf); buf.extend(b); views.append({'buffer': 0, 'byteOffset': off, 'byteLength': len(b)}); return len(views) - 1
    def material(mi):
        src = json.loads(json.dumps(jv['materials'][mi])); pbr = src.get('pbrMetallicRoughness', {})
        if 'baseColorTexture' in pbr:
            data, mime = imagem(pbr['baseColorTexture']['index'])
            imgs.append({'bufferView': add_bytes(data), 'mimeType': mime}); texs.append({'source': len(imgs) - 1, 'sampler': 0})
            pbr['baseColorTexture'] = {'index': len(texs) - 1}
        for k in ('normalTexture', 'occlusionTexture', 'emissiveTexture'): src.pop(k, None)
        pbr.pop('metallicRoughnessTexture', None); src['pbrMetallicRoughness'] = pbr
        mats.append(src); return len(mats) - 1
    nodes = []
    for n, nome in zip(jordem, nomes_jogo):
        p = Pj[n]; L = np.linalg.inv(NEW[p]) @ NEW[n] if p else NEW[n]
        R = L[:3, :3]; R = R / np.linalg.norm(R, axis=0)
        nodes.append({'name': nome, 'translation': L[:3, 3].tolist(), 'rotation': m2q(R).tolist(), 'children': []})
    for k, n in enumerate(jordem):
        if Pj[n]: nodes[jordem.index(Pj[n])]['children'].append(k)
    for nd in nodes:
        if not nd['children']: del nd['children']
    ibm = add(np.stack([np.linalg.inv(NEW[n]).T.reshape(-1) for n in jordem]).astype(np.float32), 5126, 'MAT4')
    meshes = []; filhos = [jordem.index('root')]; tri = 0; nv = 0
    for nome in nomes_pecas:
        prs = []
        for pr in pecas[nome]:
            at = {'POSITION': add(pr['P'].astype(np.float32), 5126, 'VEC3', 34962, True), 'NORMAL': add(pr['N'].astype(np.float32), 5126, 'VEC3', 34962)}
            if pr['UV'] is not None: at['TEXCOORD_0'] = add(pr['UV'], 5126, 'VEC2', 34962)
            at['JOINTS_0'] = add(pr['J'].astype(np.uint16), 5123, 'VEC4', 34962); at['WEIGHTS_0'] = add(pr['W'].astype(np.float32), 5126, 'VEC4', 34962)
            d = {'attributes': at, 'indices': add(pr['I'].astype(np.uint32), 5125, 'SCALAR', 34963)}
            if pr['mat'] is not None: d['material'] = material(pr['mat'])
            prs.append(d); tri += len(pr['I']) // 3; nv += len(pr['P'])
        meshes.append({'name': nome, 'primitives': prs})
        nodes.append({'name': nome, 'mesh': len(meshes) - 1, 'skin': 0}); filhos.append(len(nodes) - 1)
    nodes.append({'name': 'Armature', 'children': filhos})
    gl = {'asset': {'version': '2.0', 'generator': 'Valtheria V3 (ligar_pecas.py)'}, 'scene': 0, 'scenes': [{'nodes': [len(nodes) - 1]}],
          'nodes': nodes, 'meshes': meshes, 'materials': mats, 'skins': [{'joints': list(range(len(jordem))), 'inverseBindMatrices': ibm, 'skeleton': jordem.index('root')}],
          'accessors': accs, 'bufferViews': views, 'buffers': [{'byteLength': 0}]}
    if imgs: gl['images'] = imgs; gl['textures'] = texs; gl['samplers'] = [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 10497, 'wrapT': 10497}]
    while len(buf) % 4: buf.append(0)
    gl['buffers'][0]['byteLength'] = len(buf)
    js = json.dumps(gl, separators=(',', ':')).encode()
    while len(js) % 4: js += b' '
    out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(buf), 0x004E4942) + bytes(buf)
    open(os.path.join(SAIDA, arquivo + '.glb'), 'wb').write(out)
    return {'arquivo': arquivo + '.glb', 'pecas': nomes_pecas, 'triangulos': tri, 'vertices': nv, 'materiais': len(mats), 'kb': len(out) // 1024}

res = [gravar(a, ps) for a, ps in GRUPOS.items()]
info = {'ossos': len(jordem), 'rot_local_max_dif_graus': round(float(max(dif)), 3), 'escala_pontas': round(float(esc), 4), 'arquivos': res}
print(json.dumps(info, ensure_ascii=False))
json.dump(info, open(os.path.join(SAIDA, 'ligacao_' + list(GRUPOS)[0] + '.json'), 'w'), ensure_ascii=False, indent=1)
