#!/usr/bin/env python3
"""Afina a manga larga no braço (pedido de Robson 26/11: o ombro inchava ao puxar o arco).

Aproxima do eixo do osso os vértices do braço (upperarm) e do ombro (clavicle), na proporção do peso desses
ossos: a manga fica mais justa, sem mexer em ossos, pesos ou animações.
Uso: python3 afinar_manga.py entrada.glb saida.glb [--fator 0.82]
"""
import json, struct, sys
import numpy as np

COMP = {5126: 'f4', 5123: 'u2', 5121: 'u1', 5125: 'u4'}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def main(src, dst, fator=0.82):
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

    sk = js['skins'][0]
    juntas = sk['joints']
    nomes = [js['nodes'][j]['name'] for j in juntas]
    ibm = ler(sk['inverseBindMatrices']).reshape(-1, 4, 4).transpose(0, 2, 1)  # glTF é coluna-major
    pos_osso = np.array([np.linalg.inv(m)[:3, 3] for m in ibm])
    idx = {nm: i for i, nm in enumerate(nomes)}
    pr = js['meshes'][0]['primitives'][0]
    P = ler(pr['attributes']['POSITION']).astype(float)
    J = ler(pr['attributes']['JOINTS_0']).astype(int)
    W = ler(pr['attributes']['WEIGHTS_0']).astype(float)
    novo = P.copy()
    for lado in ('l', 'r'):
        a = pos_osso[idx['upperarm_' + lado]]
        b = pos_osso[idx['lowerarm_' + lado]]
        alvo = [idx['upperarm_' + lado], idx['clavicle_' + lado]]
        if 'upperarm_twist_01_' + lado in idx:
            alvo.append(idx['upperarm_twist_01_' + lado])
        w = np.zeros(len(P))
        for k in range(4):
            w += np.where(np.isin(J[:, k], alvo), W[:, k], 0.0)
        w = np.clip((w - 0.25) / 0.5, 0, 1)  # só onde o braço/ombro manda; transição suave para peito e cotovelo
        ab = b - a
        t = np.clip(((P - a) @ ab) / (ab @ ab), 0.0, 1.0)
        perto = a + t[:, None] * ab
        k_ = 1.0 - (1.0 - fator) * w
        novo = np.where(w[:, None] > 0, perto + (novo - perto) * k_[:, None], novo)
    gravar(pr['attributes']['POSITION'], novo.astype(np.float32))
    # limites do acessório de posição
    acc = js['accessors'][pr['attributes']['POSITION']]
    acc['min'] = novo.min(0).tolist(); acc['max'] = novo.max(0).tolist()
    js_b = json.dumps(js, separators=(',', ':')).encode()
    js_b += b' ' * ((4 - len(js_b) % 4) % 4)
    if len(js_b) != n:
        raise SystemExit('json mudou de tamanho; gravar não implementado')
    raw[20:20 + n] = js_b
    open(dst, 'wb').write(raw)
    print(f'{src}: manga afinada ({fator})')


if __name__ == '__main__':
    args = sys.argv[1:]
    fator = float(args[args.index('--fator') + 1]) if '--fator' in args else 0.82
    main(args[0], args[1], fator)
