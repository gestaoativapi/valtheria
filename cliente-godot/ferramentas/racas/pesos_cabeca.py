#!/usr/bin/env python3
"""Corrige os pesos da cabeça e do pescoço de um corpo próprio (.glb com pele automática).

Problema: a pele automática deixava a parte de baixo do rosto (queixo, mandíbula, barba) presa ao
spine_03 e nunca usava o neck_01. Quando a animação gira o pescoço e a cabeça, metade do rosto
fica com o peito e a outra metade acompanha a cabeça: o rosto estica.

Regra (só dentro da coluna da cabeça, e só em vértices que já eram do tronco/pescoço/cabeça):
  acima do queixo                -> 100% Head
  faixa do pescoço               -> spine_03 -> neck_01 -> Head, em rampa
Uso: python3 pesos_cabeca.py entrada.glb saida.glb [--raio-k 1.0]
"""
import json, struct, sys
import numpy as np

COMP = {5126: 'f4', 5123: 'u2', 5121: 'u1', 5125: 'u4'}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def main(src, dst, raio_k=1.0, frente_y=None):
    raw = bytearray(open(src, 'rb').read())
    n = struct.unpack('<I', raw[12:16])[0]
    js = json.loads(raw[20:20 + n])
    b0 = 20 + n + 8  # início do bloco binário

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

    sk = js['skins'][0]
    nomes = [js['nodes'][j]['name'] for j in sk['joints']]
    ib = ler(sk['inverseBindMatrices']).reshape(-1, 4, 4)
    pos = {nm: np.linalg.inv(ib[i].T)[:3, 3] for i, nm in enumerate(nomes)}
    iH, iN, iS = nomes.index('Head'), nomes.index('neck_01'), nomes.index('spine_03')
    H, N = pos['Head'], pos['neck_01']
    pr = js['meshes'][0]['primitives'][0]
    P = ler(pr['attributes']['POSITION']).astype(float)
    J = ler(pr['attributes']['JOINTS_0']).astype(int)
    W = ler(pr['attributes']['WEIGHTS_0']).astype(float)

    seg = max(H[1] - N[1], 0.04)
    topo = P[:, 1].max()
    # medidas da cabeça numa faixa alta (acima dos ombros, que nos orcs chegam perto da altura do rosto)
    alto = (P[:, 1] > topo - 0.16) & (P[:, 1] < topo - 0.07) & (np.abs(P[:, 0] - H[0]) < 0.25)
    cx = float(np.median(P[alto, 0]))
    hx = float(np.percentile(np.abs(P[alto, 0] - cx), 96)) * 1.08 * raio_k
    zb = float(np.percentile(P[alto, 2], 2)) - 0.02
    zf = float(np.percentile(P[alto, 2], 98)) + 0.03
    zc = (zb + zf) * 0.5
    queixo = N[1] + 0.15 * seg
    baixo = N[1] - 1.6 * seg  # faixa do pescoço larga: a cabeça erguida não vinca a garganta
    tronco = np.isin(J, [iS, iN, iH, nomes.index('spine_02')])
    dono = (np.where(tronco, W, 0).sum(1) > 0.85)  # só quem já é do tronco/pescoço/cabeça
    # elipse horizontal da cabeça (x, z) normalizada: < 1 dentro
    frente = np.clip((P[:, 2] - zc) / max(zf - zc, 0.01), 0, 1)  # 0 no meio da cabeça, 1 no rosto
    # o rosto (bochechas, mandíbula, presas) é mais largo que o alto da cabeça; o ombro fica atrás, não à frente
    ex = (P[:, 0] - cx) / (hx * (1.0 + 0.4 * frente))
    ez = (P[:, 2] - zc) / ((zf - zb) * 0.5)
    e = np.hypot(ex, ez)
    lim = queixo - 0.9 * seg * frente  # mandíbula, presas e barba descem mais à frente
    if frente_y is not None:  # barba longa (orc macho): tudo à frente do eixo, acima desta altura, é da cabeça
        lim = np.where(frente > 0.35, np.minimum(lim, frente_y), lim)
    mud = 0
    for v in np.where(dono)[0]:
        y = P[v, 1]
        if y >= lim[v] and e[v] < 1.0:
            jw = [(iH, 1.0)]
        elif y >= lim[v] and e[v] < 1.3:
            # borda da cabeça (trapézio, nuca, lados do pescoço): mistura suave com o que já havia
            wh = (1.3 - e[v]) / 0.3
            mix = {}
            for j, w in zip(J[v], W[v]):
                mix[int(j)] = mix.get(int(j), 0.0) + float(w) * (1 - wh)
            mix[iH] = mix.get(iH, 0.0) + wh
            jw = sorted(mix.items(), key=lambda t: -t[1])[:4]
            soma = sum(w for _, w in jw)
            jw = [(j, w / soma) for j, w in jw]
        elif frente_y is not None and frente[v] > 0.35 and frente_y - 0.06 <= y < lim[v] and e[v] < 1.0:
            t = (y - (frente_y - 0.06)) / 0.06  # transição da barba para o peito
            jw = [(iS, 1 - t), (iH, t)]
        elif baixo <= y < lim[v] and e[v] < 0.85:
            t = (y - baixo) / max(lim[v] - baixo, 0.01)
            jw = [(iS, 1 - 2 * t), (iN, 2 * t)] if t < 0.5 else [(iN, 2 - 2 * t), (iH, 2 * t - 1)]
        else:
            continue
        jj = [j for j, _ in jw] + [iH] * (4 - len(jw))
        ww = [w for _, w in jw] + [0.0] * (4 - len(jw))
        J[v] = jj
        W[v] = ww
        mud += 1
    r = hx
    gravar(pr['attributes']['JOINTS_0'], J)
    gravar(pr['attributes']['WEIGHTS_0'], W)
    open(dst, 'wb').write(raw)
    print(f'{src}: meia-largura {hx:.3f} m, z {zb:.3f}..{zf:.3f}, queixo {queixo:.3f}, pescoço {baixo:.3f}..{queixo:.3f}, vértices ajustados {mud}')


if __name__ == '__main__':
    k = 1.0
    fy = None
    if '--raio-k' in sys.argv:
        k = float(sys.argv[sys.argv.index('--raio-k') + 1])
    if '--frente-y' in sys.argv:
        fy = float(sys.argv[sys.argv.index('--frente-y') + 1])
    main(sys.argv[1], sys.argv[2], k, fy)
