# B3 — liga o corpo V2 (MPFB) ao ESQUELETO DO JOGO (65 ossos, mesmas orientações de repouso).
# 1) posa o corpo MPFB para que cada osso aponte como o osso do jogo; 2) cria o esqueleto final com as
# rotações de repouso do jogo e as articulações na anatomia V2; 3) reaproveita os pesos do MPFB por nome.
import sys, json, struct, numpy as np
sys.path.insert(0, '/home/claude/v2/b3')
from gltf_io import load, acc, trs, q2m, m2q
JOGO, V2, SAIDA = sys.argv[1], sys.argv[2], sys.argv[3]

def esqueleto(path):
    j, b = load(path)
    par = {}
    for i, n in enumerate(j['nodes']):
        for c in n.get('children', []): par[c] = i
    joints = j['skins'][0]['joints']; js = set(joints)
    G = {}
    def glob(i):
        if i in G: return G[i]
        m = trs(j['nodes'][i])
        if par.get(i) in js: m = glob(par[i]) @ m
        G[i] = m; return m
    names = [j['nodes'][i]['name'] for i in joints]
    glob_by = {j['nodes'][i]['name'].lower(): glob(i) for i in joints}
    parent_by = {j['nodes'][i]['name'].lower(): (j['nodes'][par[i]]['name'].lower() if par.get(i) in js else None) for i in joints}
    local_by = {j['nodes'][i]['name'].lower(): trs(j['nodes'][i]) for i in joints}
    return j, b, names, glob_by, parent_by, local_by

jg, bg, nomes_jogo, Gj, Pj, Lj = esqueleto(JOGO)
jv, bv, nomes_v2, Gv, Pv, Lv = esqueleto(V2)

# filho "principal" que define a direção de cada osso
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

# 1) pose: percorre a hierarquia do MPFB do pai para o filho
ordem = []
def visita(n):
    ordem.append(n)
    for k, p in Pv.items():
        if p == n: visita(k)
visita('root')
T = {}
for n in ordem:
    p = Pv[n]
    if n not in Gj and n not in FILHO: pass
    T[n] = Gv[n].copy() if p is None else T[p] @ np.linalg.inv(Gv[p]) @ Gv[n]
    f = FILHO.get(n)
    if f and f in Gv and f in Gj and n in Gj:
        pos = T[n][:3, 3]
        filho_agora = (T[n] @ np.linalg.inv(Gv[n]) @ Gv[f])[:3, 3]
        quer = Gj[f][:3, 3] - Gj[n][:3, 3]
        R = arco(filho_agora - pos, quer)
        M = np.eye(4); M[:3, :3] = R
        Tr = np.eye(4); Tr[:3, 3] = pos; Ti = np.eye(4); Ti[:3, 3] = -pos
        T[n] = Tr @ M @ Ti @ T[n]
S = {n: T[n] @ np.linalg.inv(Gv[n]) for n in T}

# malha do V2
prim = jv['meshes'][0]['primitives'][0]; at = prim['attributes']
P = acc(jv, bv, at['POSITION']).astype(np.float64); N = acc(jv, bv, at['NORMAL']).astype(np.float64)
UV = acc(jv, bv, at['TEXCOORD_0']) if 'TEXCOORD_0' in at else None
J = acc(jv, bv, at['JOINTS_0']).astype(np.int64); W = acc(jv, bv, at['WEIGHTS_0']).astype(np.float64)
IDX = acc(jv, bv, prim['indices']).reshape(-1)
W = W / W.sum(1, keepdims=True)
vnomes = [n.lower() for n in nomes_v2]
mats = np.stack([S[vnomes[k]] for k in range(len(vnomes))])
def skin(P, N, mats, J, W):
    M = np.einsum('vk,vkij->vij', W, mats[J])
    P2 = np.einsum('vij,vj->vi', M[:, :3, :3], P) + M[:, :3, 3]
    N2 = np.einsum('vij,vj->vi', M[:, :3, :3], N); N2 /= np.linalg.norm(N2, axis=1, keepdims=True)
    return P2, N2
P2, N2 = skin(P, N, mats, J, W)

# 2) esqueleto final: rotação de repouso do jogo + posição da articulação V2 posada
NEW = {}
alt_v2 = (T['head'][:3, 3] - T['pelvis'][:3, 3]); alt_j = (Gj['head'][:3, 3] - Gj['pelvis'][:3, 3])
esc = np.linalg.norm(alt_v2) / np.linalg.norm(alt_j)
jordem = [n.lower() for n in nomes_jogo]
def novo(n):
    if n in NEW: return NEW[n]
    R = Gj[n][:3, :3] / np.linalg.norm(Gj[n][:3, :3], axis=0)
    M = np.eye(4); M[:3, :3] = R
    if n in T: M[:3, 3] = T[n][:3, 3]
    else:  # ossos de ponta: mesma posição local do jogo, na escala do corpo V2
        p = Pj[n]; pm = novo(p)
        M[:3, 3] = (pm @ np.linalg.inv(Gj[p]) @ Gj[n])[:3, 3] if p else Gj[n][:3, 3]
        M[:3, 3] = pm[:3, 3] + (M[:3, 3] - pm[:3, 3]) * esc
    NEW[n] = M; return M
for n in jordem: novo(n)
# conferência: rotação local de repouso igual à do jogo
dif = []
for n in jordem:
    p = Pj[n]
    lr = (np.linalg.inv(NEW[p]) @ NEW[n])[:3, :3] if p else NEW[n][:3, :3]
    lj = Lj[n][:3, :3] / np.linalg.norm(Lj[n][:3, :3], axis=0)
    c = np.clip((np.trace(lr.T @ lj) - 1) / 2, -1, 1); dif.append(np.degrees(np.arccos(c)))
# 3) pesos: índice do MPFB -> índice do jogo, pelo nome
def alvo(n):
    while n not in jordem: n = Pv[n]  # osso que o jogo não tem (ex.: breast_l): o peso vai para o pai
    return jordem.index(n)
mapa = np.array([alvo(n) for n in vnomes])
J2 = mapa[J]
hip = NEW['pelvis'][:3, 3][1] / Gj['pelvis'][:3, 3][1] if abs(Gj['pelvis'][:3, 3][1]) > 1e-6 else 1.0

# escrita do .glb
buf = bytearray(); views = []; accs = []
def add(arr, comp, typ, target=None, mm=False):
    arr = np.ascontiguousarray(arr)
    while len(buf) % 4: buf.append(0)
    off = len(buf); buf.extend(arr.tobytes())
    v = {'buffer': 0, 'byteOffset': off, 'byteLength': arr.nbytes}
    if target: v['target'] = target
    views.append(v)
    a = {'bufferView': len(views) - 1, 'componentType': comp, 'count': int(arr.shape[0]), 'type': typ}
    if mm: a['min'] = arr.min(0).tolist(); a['max'] = arr.max(0).tolist()
    accs.append(a); return len(accs) - 1
nodes = []
for n, nome in zip(jordem, nomes_jogo):
    p = Pj[n]; L = np.linalg.inv(NEW[p]) @ NEW[n] if p else NEW[n]
    R = L[:3, :3]; R = R / np.linalg.norm(R, axis=0)
    nodes.append({'name': nome, 'translation': L[:3, 3].tolist(), 'rotation': m2q(R).tolist(), 'children': []})
for k, n in enumerate(jordem):
    p = Pj[n]
    if p: nodes[jordem.index(p)]['children'].append(k)
for nd in nodes:
    if not nd['children']: del nd['children']
attrs = {'POSITION': add(P2.astype(np.float32), 5126, 'VEC3', 34962, True), 'NORMAL': add(N2.astype(np.float32), 5126, 'VEC3', 34962)}
if UV is not None: attrs['TEXCOORD_0'] = add(UV.astype(np.float32), 5126, 'VEC2', 34962)
attrs['JOINTS_0'] = add(J2.astype(np.uint16), 5123, 'VEC4', 34962)
attrs['WEIGHTS_0'] = add(W.astype(np.float32), 5126, 'VEC4', 34962)
ind = add(IDX.astype(np.uint32), 5125, 'SCALAR', 34963)
ibm = add(np.stack([np.linalg.inv(NEW[n]).T.reshape(-1) for n in jordem]).astype(np.float32), 5126, 'MAT4')
nome_malha = SAIDA.split('/')[-1].replace('.glb', '')
mesh_node = len(nodes); nodes.append({'name': nome_malha, 'mesh': 0, 'skin': 0})
arm = len(nodes); nodes.append({'name': 'Armature', 'children': [jordem.index('root'), mesh_node]})
gl = {'asset': {'version': '2.0', 'generator': 'Valtheria V2 B3 (ligar_esqueleto.py)'}, 'scene': 0, 'scenes': [{'nodes': [arm]}], 'nodes': nodes,
      'meshes': [{'name': nome_malha, 'primitives': [{'attributes': attrs, 'indices': ind, 'material': 0}]}],
      'materials': [{'name': 'pele_v2', 'pbrMetallicRoughness': {'baseColorFactor': [0.74, 0.56, 0.45, 1], 'metallicFactor': 0, 'roughnessFactor': 0.75}}],
      'skins': [{'joints': list(range(len(jordem))), 'inverseBindMatrices': ibm, 'skeleton': jordem.index('root')}],
      'accessors': accs, 'bufferViews': views, 'buffers': [{'byteLength': len(buf)}]}
js = json.dumps(gl, separators=(',', ':')).encode()
while len(js) % 4: js += b' '
while len(buf) % 4: buf.append(0)
out = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf)) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(buf), 0x004E4942) + bytes(buf)
open(SAIDA, 'wb').write(out)
info = {'arquivo': SAIDA, 'ossos': len(jordem), 'vertices': int(len(P2)), 'triangulos': int(len(IDX) // 3),
        'rot_local_max_dif_graus': round(float(max(dif)), 3), 'hip': round(float(hip), 4), 'escala_pontas': round(float(esc), 4),
        'altura': round(float(P2[:, 1].max() - P2[:, 1].min()), 3)}
json.dump(info, open(SAIDA.replace('.glb', '.json'), 'w'), indent=1); print(info)
