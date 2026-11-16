# Valtheria V3 — funções comuns dos testes de animação (esqueleto de 65 ossos e amostragem das 28 animações oficiais).
# Mesmo método de testar_animacoes.py: rotações das animações aplicadas por nome de osso e translação do quadril
# reescalada pela altura do quadril do modelo.
import os, sys, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gltf_io import load, acc, q2m

def mloc(t, r, s):
    M = np.eye(4); M[:3, :3] = q2m(r) @ np.diag(s); M[:3, 3] = t; return M

class Esqueleto:
    def __init__(self, path):
        j, b = load(path)
        par = {}
        for i, n in enumerate(j['nodes']):
            for c in n.get('children', []): par[c] = i
        sk = j['skins'][0]; js = set(sk['joints']); self.joints = [j['nodes'][i]['name'] for i in sk['joints']]
        nd = {j['nodes'][i]['name']: j['nodes'][i] for i in sk['joints']}
        self.rt = {n: np.array(nd[n].get('translation', [0, 0, 0]), float) for n in self.joints}
        self.rr = {n: np.array(nd[n].get('rotation', [0, 0, 0, 1]), float) for n in self.joints}
        self.rs = {n: np.array(nd[n].get('scale', [1, 1, 1]), float) for n in self.joints}
        self.pai = {j['nodes'][i]['name']: (j['nodes'][par[i]]['name'] if par.get(i) in js else None) for i in sk['joints']}
        self.hip = None
    def globais(self, over):
        loc = {n: mloc(over.get(n, {}).get('t', self.rt[n]), over.get(n, {}).get('r', self.rr[n]), self.rs[n]) for n in self.joints}
        G = {}
        def g(n):
            if n in G: return G[n]
            G[n] = (g(self.pai[n]) @ loc[n]) if self.pai[n] else loc[n]; return G[n]
        for n in self.joints: g(n)
        return G

def canais_animacao(path):
    ja, ba = load(path)
    y_anim = [n for n in ja['nodes'] if n.get('name') == 'pelvis'][0].get('translation', [0, 1, 0])[1]
    for an in ja['animations']:
        canais = []
        for c in an['channels']:
            nome = ja['nodes'][c['target']['node']]['name']; s = an['samplers'][c['sampler']]
            canais.append((nome, c['target']['path'], {'in': acc(ja, ba, s['input']).reshape(-1), 'out': acc(ja, ba, s['output'])}, y_anim))
        yield an['name'], canais, max(c[2]['in'][-1] for c in canais)

def _amostra(path, sm, t):
    ts, vs = sm['in'], sm['out']
    if t <= ts[0]: return vs[0]
    if t >= ts[-1]: return vs[-1]
    i = np.searchsorted(ts, t) - 1; f = (t - ts[i]) / (ts[i + 1] - ts[i]); v = vs[i] * (1 - f) + vs[i + 1] * f
    if path == 'rotation':
        if np.dot(vs[i], vs[i + 1]) < 0: v = vs[i] * (1 - f) - vs[i + 1] * f
        v = v / np.linalg.norm(v)
    return v

HIP_JOGO = 1.0
def amostra_pose(canais, t, esq):
    over = {}
    for nome, path, sm, y_anim in canais:
        if nome not in esq.rt: continue
        v = _amostra(path, sm, t)
        if path == 'rotation': over.setdefault(nome, {})['r'] = v
        elif path == 'translation':   # regra do jogo para humanos (character.gd: hip = 1.0, translação usada como está)
            over.setdefault(nome, {})['t'] = v * HIP_JOGO
    return over
