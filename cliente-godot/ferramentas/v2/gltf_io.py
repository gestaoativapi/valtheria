# Leitura e escrita mínima de glTF binário (.glb) para a etapa B3 da V2.
import json, struct, numpy as np
CT = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
def load(path):
    b = open(path, 'rb').read()
    l = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + l])
    bl = struct.unpack('<I', b[20 + l:24 + l])[0]
    return j, b[28 + l:28 + l + bl]
def acc(j, binary, i):
    a = j['accessors'][i]; v = j['bufferViews'][a['bufferView']]
    off = v.get('byteOffset', 0) + a.get('byteOffset', 0); n = NC[a['type']]; dt = CT[a['componentType']]
    stride = v.get('byteStride')
    if stride and stride != n * np.dtype(dt).itemsize:
        raw = np.frombuffer(binary, dtype=np.uint8, count=stride * a['count'], offset=off).reshape(a['count'], stride)
        return raw[:, :n * np.dtype(dt).itemsize].copy().view(dt).reshape(a['count'], n)
    arr = np.frombuffer(binary, dtype=dt, count=a['count'] * n, offset=off).reshape(a['count'], n).copy()
    if a.get('normalized') and dt in (np.uint8, np.uint16):
        arr = arr.astype(np.float32) / np.iinfo(dt).max
    return arr
def q2m(q):
    x, y, z, w = q
    return np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)], [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)], [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
def m2q(m):
    t = np.trace(m)
    if t > 0:
        s = np.sqrt(t + 1) * 2; w = .25 * s; x = (m[2,1]-m[1,2]) / s; y = (m[0,2]-m[2,0]) / s; z = (m[1,0]-m[0,1]) / s
    elif m[0,0] > m[1,1] and m[0,0] > m[2,2]:
        s = np.sqrt(1 + m[0,0] - m[1,1] - m[2,2]) * 2; w = (m[2,1]-m[1,2]) / s; x = .25 * s; y = (m[0,1]+m[1,0]) / s; z = (m[0,2]+m[2,0]) / s
    elif m[1,1] > m[2,2]:
        s = np.sqrt(1 + m[1,1] - m[0,0] - m[2,2]) * 2; w = (m[0,2]-m[2,0]) / s; x = (m[0,1]+m[1,0]) / s; y = .25 * s; z = (m[1,2]+m[2,1]) / s
    else:
        s = np.sqrt(1 + m[2,2] - m[0,0] - m[1,1]) * 2; w = (m[1,0]-m[0,1]) / s; x = (m[0,2]+m[2,0]) / s; y = (m[1,2]+m[2,1]) / s; z = .25 * s
    q = np.array([x, y, z, w]); return q / np.linalg.norm(q)
def trs(n):
    M = np.eye(4)
    if 'matrix' in n: return np.array(n['matrix']).reshape(4, 4).T
    S = np.diag(n.get('scale', [1, 1, 1]))
    M[:3, :3] = q2m(n.get('rotation', [0, 0, 0, 1])) @ S
    M[:3, 3] = n.get('translation', [0, 0, 0]); return M
def skeleton(j):
    """devolve: nomes dos joints (ordem da skin), pai de cada nó, globais (no espaço do nó Armature)"""
    par = {}
    for i, n in enumerate(j['nodes']):
        for c in n.get('children', []): par[c] = i
    joints = j['skins'][0]['joints']
    G = {}
    def glob(i):
        if i in G: return G[i]
        m = trs(j['nodes'][i]); p = par.get(i)
        if p is not None and p in joints_set_or_root(j, joints, p): m = glob(p) @ m
        G[i] = m; return m
    for i in joints: glob(i)
    return joints, par, G
def joints_set_or_root(j, joints, p):
    return set(joints)
