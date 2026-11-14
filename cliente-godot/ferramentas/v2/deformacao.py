# Protocolo de deformação (guia 8.2): 28 animações × 3 quadros. Mede o estiramento das arestas em relação ao repouso.
# Uso: deformacao.py <corpo.glb> <hip> <saida.json>   (o mesmo cálculo é feito no corpo atual para comparar)
import sys, json, numpy as np
sys.path.insert(0, '/home/claude/v2/b3')
from gltf_io import load, acc, trs, q2m
CORPO, HIP, SAIDA = sys.argv[1], float(sys.argv[2]), sys.argv[3]
ANIMS = ['/home/claude/valtheria/cliente-godot/assets/chars/anims_a.glb', '/home/claude/valtheria/cliente-godot/assets/chars/anims_b.glb']
j, b = load(CORPO)
par = {}
for i, n in enumerate(j['nodes']):
    for c in n.get('children', []): par[c] = i
skin = j['skins'][0]; joints = skin['joints']; jset = set(joints)
nomes = [j['nodes'][i]['name'] for i in joints]
ibm = acc(j, b, skin['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
rest_t = {nomes[k]: np.array(j['nodes'][i].get('translation', [0, 0, 0]), float) for k, i in enumerate(joints)}
rest_r = {nomes[k]: np.array(j['nodes'][i].get('rotation', [0, 0, 0, 1]), float) for k, i in enumerate(joints)}
rest_s = {nomes[k]: np.array(j['nodes'][i].get('scale', [1, 1, 1]), float) for k, i in enumerate(joints)}
pai = {nomes[k]: (j['nodes'][par[i]]['name'] if par.get(i) in jset else None) for k, i in enumerate(joints)}
# malha principal (a de mais vértices)
mi = max(range(len(j['meshes'])), key=lambda m: j['accessors'][j['meshes'][m]['primitives'][0]['attributes']['POSITION']]['count'])
skin_i = [n.get('skin') for n in j['nodes'] if n.get('mesh') == mi][0]
sk = j['skins'][skin_i]; sj = sk['joints']; snomes = [j['nodes'][i]['name'] for i in sj]
sibm = acc(j, b, sk['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)
pr = j['meshes'][mi]['primitives'][0]; at = pr['attributes']
P = acc(j, b, at['POSITION']).astype(float); J = acc(j, b, at['JOINTS_0']).astype(int); W = acc(j, b, at['WEIGHTS_0']).astype(float)
W /= W.sum(1, keepdims=True); IDX = acc(j, b, pr['indices']).reshape(-1, 3)
E_ = np.unique(np.sort(np.concatenate([IDX[:, [0, 1]], IDX[:, [1, 2]], IDX[:, [2, 0]]]), axis=1), axis=0)
# posição de repouso "real" (com a skin aplicada na pose de repouso)
def globais(loc):
    G = {}
    def g(n):
        if n in G: return G[n]
        m = loc[n]; G[n] = (g(pai[n]) @ m) if pai[n] else m; return G[n]
    for n in nomes: g(n)
    return G
def mloc(t, r, s):
    M = np.eye(4); M[:3, :3] = q2m(r) @ np.diag(s); M[:3, 3] = t; return M
def pose(over):
    loc = {n: mloc(over.get(n, {}).get('t', rest_t[n]), over.get(n, {}).get('r', rest_r[n]), rest_s[n]) for n in nomes}
    G = globais(loc)
    mats = np.stack([G[n] @ sibm[k] for k, n in enumerate(snomes)])
    M = np.einsum('vk,vkij->vij', W, mats[J])
    return np.einsum('vij,vj->vi', M[:, :3, :3], P) + M[:, :3, 3]
P0 = pose({})
L0 = np.linalg.norm(P0[E_[:, 0]] - P0[E_[:, 1]], axis=1) + 1e-9
dom = np.array([snomes[J[v][np.argmax(W[v])]] for v in range(len(P))])
def regiao(bn):
    for k, r in [('upperarm', 'ombro/braço'), ('clavicle', 'ombro/braço'), ('lowerarm', 'cotovelo'), ('hand', 'punho/mão'), ('thigh', 'quadril/coxa'), ('calf', 'joelho'), ('foot', 'tornozelo/pé'), ('ball', 'tornozelo/pé'), ('spine', 'tronco'), ('pelvis', 'quadril/coxa'), ('neck', 'pescoço'), ('head', 'cabeça')]:
        if k in bn.lower(): return r
    return 'dedos' if any(x in bn for x in ['index', 'middle', 'ring', 'pinky', 'thumb']) else bn
def amostra(ch, sm, t):
    ts = sm['in']; vs = sm['out']
    if t <= ts[0]: return vs[0]
    if t >= ts[-1]: return vs[-1]
    i = np.searchsorted(ts, t) - 1; f = (t - ts[i]) / (ts[i + 1] - ts[i]); v = vs[i] * (1 - f) + vs[i + 1] * f
    if ch == 'rotation':
        if np.dot(vs[i], vs[i + 1]) < 0: v = vs[i] * (1 - f) - vs[i + 1] * f
        v = v / np.linalg.norm(v)
    return v
res = []
for af in ANIMS:
    ja, ba = load(af)
    for an in ja['animations']:
        canais = []
        for c in an['channels']:
            nome = ja['nodes'][c['target']['node']]['name']; s = an['samplers'][c['sampler']]
            canais.append((nome, c['target']['path'], {'in': acc(ja, ba, s['input']).reshape(-1), 'out': acc(ja, ba, s['output'])}))
        dur = max(c[2]['in'][-1] for c in canais)
        for nome_q, t in [('início', 0.0), ('meio', dur / 2), ('fim', dur)]:
            over = {}
            for nome, path, sm in canais:
                if nome not in rest_t: continue
                v = amostra(path, sm, t)
                if path == 'rotation': over.setdefault(nome, {})['r'] = v
                elif path == 'translation': over.setdefault(nome, {})['t'] = v * HIP
            Pp = pose(over)
            L = np.linalg.norm(Pp[E_[:, 0]] - Pp[E_[:, 1]], axis=1); st = L / L0
            mal = np.where(st > 1.6)[0]
            regs = sorted(set(regiao(dom[E_[e, 0]]) for e in mal))
            res.append({'anim': an['name'], 'quadro': nome_q, 'estiramento_max': round(float(st.max()), 3),
                        'p99': round(float(np.percentile(st, 99)), 3), 'arestas_acima_1_6': int(len(mal)), 'regioes': regs})
json.dump(res, open(SAIDA, 'w'), ensure_ascii=False, indent=1)
anims = sorted(set(r['anim'] for r in res))
print(CORPO.split('/')[-1], 'animações:', len(anims), 'poses:', len(res), 'poses com aresta >1,6x:', sum(1 for r in res if r['arestas_acima_1_6']),
      'max:', max(r['estiramento_max'] for r in res), 'poses >2,0x:', sum(1 for r in res if r['estiramento_max'] > 2.0))
