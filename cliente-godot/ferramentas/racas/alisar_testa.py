#!/usr/bin/env python3
"""Alisa a testa de um corpo próprio (.glb) sem mudar vértices, UVs, ossos nem pesos (27/11).

O humano masculino tinha um calombo acima da sobrancelha esquerda (geometria da malha, não textura).
Região: vértices da cabeça (osso Head >= 0,8), na frente do rosto, entre a sobrancelha e a raiz do cabelo.
Alisamento Taubin (não encolhe) só ali, com borda suave; o resto do corpo fica idêntico byte a byte.
Uso: python3 alisar_testa.py entrada.glb saida.glb [--passos 25] [--ver]
"""
import json, struct, sys
import numpy as np
import scipy.sparse as sp

COMP = {5126: 'f4', 5123: 'u2', 5121: 'u1', 5125: 'u4'}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def main(src, dst, passos=25, ver=False, faixa=(0.66, 0.86)):
    raw = bytearray(open(src, 'rb').read())
    n = struct.unpack('<I', raw[12:16])[0]
    js = json.loads(raw[20:20 + n])
    b0 = 20 + n + 8

    def info(i):
        a = js['accessors'][i]
        bv = js['bufferViews'][a['bufferView']]
        return b0 + bv.get('byteOffset', 0) + a.get('byteOffset', 0), bv.get('byteStride', 0), np.dtype(COMP[a['componentType']]), NC[a['type']], a['count']

    def ler(i):
        o, st, dt, nc, cnt = info(i)
        st = st or nc * dt.itemsize
        m = np.frombuffer(bytes(raw), dtype=np.uint8, count=st * cnt, offset=o).reshape(cnt, st)[:, :nc * dt.itemsize].copy()
        return m.view(dt).reshape(cnt, nc)

    def gravar(i, arr):
        o, st, dt, nc, cnt = info(i)
        st = st or nc * dt.itemsize
        a = np.ascontiguousarray(arr.astype(dt)).view(np.uint8).reshape(cnt, nc * dt.itemsize)
        for k in range(cnt):
            raw[o + k * st:o + k * st + nc * dt.itemsize] = a[k].tobytes()

    pr = js['meshes'][0]['primitives'][0]
    P = ler(pr['attributes']['POSITION']).astype(float)
    J = ler(pr['attributes']['JOINTS_0']).astype(int)
    W = ler(pr['attributes']['WEIGHTS_0']).astype(float)
    T = ler(pr['indices']).reshape(-1, 3).astype(int)
    nomes = [js['nodes'][j]['name'] for j in js['skins'][0]['joints']]
    ih = nomes.index('Head')
    wh = (W * (J == ih)).sum(1)
    chave = np.round(P / 1e-4).astype(np.int64)
    _, solda = np.unique(chave, axis=0, return_inverse=True)
    solda = solda.ravel()
    ns = solda.max() + 1
    cont = np.bincount(solda, minlength=ns)[:, None]
    Ps = np.zeros((ns, 3)); np.add.at(Ps, solda, P); Ps /= np.maximum(cont, 1)
    Wh = np.zeros(ns); np.add.at(Wh, solda, wh); Wh /= cont.ravel()
    cab = Wh >= 0.8
    # frente do rosto: o lado da cabeça para onde o nariz aponta (ponto mais à frente)
    c = Ps[cab]
    yb, yt = c[:, 1].min(), c[:, 1].max()
    eixo = 2  # glTF: frente do personagem em +Z
    zc = np.median(c[:, eixo])
    zf = c[:, eixo].max()
    xc = np.median(c[:, 0])
    altura = (Ps[:, 1] - yb) / max(yt - yb, 1e-6)
    frente = (Ps[:, eixo] - zc) / max(zf - zc, 1e-6)
    lado = np.abs(Ps[:, 0] - xc) / max(np.ptp(c[:, 0]) * 0.5, 1e-6)
    m = cab & (altura > faixa[0]) & (altura < faixa[1]) & (frente > 0.35) & (lado < 0.75)
    # borda suave
    e = np.vstack([T[:, [0, 1]], T[:, [1, 2]], T[:, [2, 0]]])
    a, b = solda[e[:, 0]], solda[e[:, 1]]
    ok = a != b
    a, b = a[ok], b[ok]
    A = sp.coo_matrix((np.ones(len(a) * 2), (np.r_[a, b], np.r_[b, a])), shape=(ns, ns)).tocsr()
    A.data[:] = 1.0
    deg = np.asarray(A.sum(1)).ravel()
    Mn = sp.diags(1.0 / np.maximum(deg, 1)) @ A
    peso = m.astype(float)
    for _ in range(4):
        peso = 0.5 * peso + 0.5 * (Mn @ peso)
    # nunca desce até a sobrancelha (mexer ali estica a textura da sobrancelha): rampa de 0 a 1 logo acima dela
    rampa = np.clip((altura - (faixa[0] - 0.02)) / 0.06, 0, 1)
    peso = np.clip(peso * 1.6, 0, 1) * cab * rampa
    Q = Ps.copy()
    for _ in range(passos):
        for f in (0.5, -0.53):
            L = Mn @ Q - Q
            Q = Q + f * L * peso[:, None]
    desl = np.linalg.norm(Q - Ps, axis=1)
    print('cabeça %d vértices; região %d; maior deslocamento %.2f mm; médio %.2f mm' % (cab.sum(), (peso > 0.05).sum(), desl.max() * 1000, desl[peso > 0.05].mean() * 1000))
    if ver:
        return
    novo = P + (Q - Ps)[solda]
    gravar(pr['attributes']['POSITION'], novo.astype(np.float32))
    # normais da região refeitas da forma nova (senão a luz ainda desenha o calombo)
    if 'NORMAL' in pr['attributes']:
        N = ler(pr['attributes']['NORMAL']).astype(float)
        fn = np.cross(Q[solda[T[:, 1]]] - Q[solda[T[:, 0]]], Q[solda[T[:, 2]]] - Q[solda[T[:, 0]]])
        Ns = np.zeros((ns, 3))
        for k in range(3):
            np.add.at(Ns, solda[T[:, k]], fn)
        Ns /= np.maximum(np.linalg.norm(Ns, axis=1, keepdims=True), 1e-12)
        pv = peso[solda][:, None]
        nn = N * (1 - pv) + Ns[solda] * pv
        nn /= np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-12)
        gravar(pr['attributes']['NORMAL'], nn.astype(np.float32))
    # limites do acessor de posição
    acc = js['accessors'][pr['attributes']['POSITION']]
    if 'min' in acc:
        acc['min'] = [float(v) for v in novo.min(0)]
        acc['max'] = [float(v) for v in novo.max(0)]
        js_bytes = json.dumps(js, separators=(',', ':')).encode()
        if len(js_bytes) <= n:
            js_bytes += b' ' * (n - len(js_bytes))
            raw[20:20 + n] = js_bytes
    open(dst, 'wb').write(raw)


if __name__ == '__main__':
    args = sys.argv[1:]
    passos = int(args[args.index('--passos') + 1]) if '--passos' in args else 25
    main(args[0], args[1], passos, '--ver' in args)
