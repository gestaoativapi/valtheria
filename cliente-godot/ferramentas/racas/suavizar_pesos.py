#!/usr/bin/env python3
"""Suaviza os pesos da pele automática de um corpo próprio (.glb).

A pele automática dá cada vértice ao osso mais próximo, com uma transição estreita: nas fronteiras
(cintura, virilha, ombro, axila, joelho, tornozelo, cotovelo, pescoço) a malha dobra num vinco e os
triângulos esticam várias vezes o tamanho. Aqui os pesos se espalham pelos vizinhos da malha
(difusão), como uma pintura de pesos à mão: a dobra vira uma curva, sem mudar ossos nem animações.
Vértices na mesma posição (costuras de UV) são tratados como um só. Mantém 4 ossos por vértice.
Dedos não entram (cada dedo segue no seu osso).
Uso: python3 suavizar_pesos.py entrada.glb saida.glb [--passos 30] [--forca 0.5]
"""
import json, struct, sys
import numpy as np
import scipy.sparse as sp

COMP = {5126: 'f4', 5123: 'u2', 5121: 'u1', 5125: 'u4'}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def main(src, dst, passos=30, forca=0.5, regiao=None):
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
    nv = len(P)
    nj = len(js['skins'][0]['joints'])
    # solda por posição: costuras de UV viram um vértice só
    chave = np.round(P / 1e-4).astype(np.int64)
    _, solda = np.unique(chave, axis=0, return_inverse=True)
    solda = solda.ravel()
    ns = solda.max() + 1
    # pesos densos por vértice soldado
    D = np.zeros((ns, nj))
    for k in range(4):
        np.add.at(D, (solda, J[:, k]), W[:, k])
    cont = np.bincount(solda, minlength=ns)[:, None]
    D /= np.maximum(cont, 1)
    # vizinhança (arestas dos triângulos), média dos vizinhos ponderada por 1/comprimento
    e = np.vstack([T[:, [0, 1]], T[:, [1, 2]], T[:, [2, 0]]])
    a, b = solda[e[:, 0]], solda[e[:, 1]]
    ok = a != b
    a, b = a[ok], b[ok]
    Ps = np.zeros((ns, 3))
    np.add.at(Ps, solda, P)
    Ps /= np.maximum(cont, 1)
    w = 1.0 / np.maximum(np.linalg.norm(Ps[a] - Ps[b], axis=1), 1e-3)
    A = sp.coo_matrix((np.r_[w, w], (np.r_[a, b], np.r_[b, a])), shape=(ns, ns)).tocsr()
    A.sum_duplicates()
    deg = np.asarray(A.sum(1)).ravel()
    Mn = sp.diags(1.0 / np.maximum(deg, 1e-9)) @ A
    # dedos ficam como estão (a mão fecha no cabo pelos ossos de cada dedo; misturar juntaria os dedos)
    nomes = [js['nodes'][j]['name'] for j in js['skins'][0]['joints']]
    dedo = np.array([any(k in nm for k in ('index', 'middle', 'ring', 'pinky', 'thumb')) for nm in nomes])
    fixo = D[:, dedo].sum(1) > 0.5
    if regiao:
        # só mexe onde os ossos da região pesam (ombro/axila/virilha): o resto, cabeça inclusive, fica como está
        na_regiao = np.array([any(nm == r or nm.startswith(r) for r in regiao) for nm in nomes])
        fixo |= D[:, na_regiao].sum(1) < 0.15
    D0 = D.copy()
    for _ in range(passos):
        D = (1 - forca) * D + forca * (Mn @ D)
        D[fixo] = D0[fixo]
    # 4 maiores, normalizados
    top = np.argsort(-D, axis=1)[:, :4]
    tw = np.take_along_axis(D, top, axis=1)
    tw = np.where(tw < 0.01, 0, tw)
    tw /= np.maximum(tw.sum(1, keepdims=True), 1e-9)
    Jn = top[solda]
    Wn = tw[solda]
    gravar(pr['attributes']['JOINTS_0'], Jn)
    gravar(pr['attributes']['WEIGHTS_0'], Wn.astype(np.float32))
    open(dst, 'wb').write(raw)
    print(f'{src}: {nv} vértices ({ns} soldados), {passos} passos, força {forca}')


if __name__ == '__main__':
    args = sys.argv[1:]
    passos = int(args[args.index('--passos') + 1]) if '--passos' in args else 30
    forca = float(args[args.index('--forca') + 1]) if '--forca' in args else 0.5
    regiao = args[args.index('--regiao') + 1].split(',') if '--regiao' in args else None
    main(args[0], args[1], passos, forca, regiao)
