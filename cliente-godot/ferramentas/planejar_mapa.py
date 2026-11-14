#!/usr/bin/env python3
"""
Plano do mapa do Valtheria: estilo de cada cidade, castelos (fora das cidades, futuras zonas de cerco)
e vilas ligadas às cidades ou no caminho entre elas. Escreve data/mapa.json, que o jogo lê.

Uso:  python3 ferramentas/planejar_mapa.py
Para mudar o porte de uma cidade, o nome de um castelo ou a dona de uma vila, edite as tabelas abaixo e rode de novo.
"""
import json, math, os, zlib
import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(os.path.dirname(AQUI), "data")
W = json.load(open(os.path.join(DATA, "world.json"), encoding="utf-8"))
H = np.fromfile(os.path.join(DATA, "height.bin"), dtype="<u2").reshape(1501, 1501).astype(float) / 65535 * 300 - 40
TOWNS = {t["id"]: t for t in W["towns"]}
POIS = W["landmarks"]


def h(x, z):
    i = min(1500, max(0, int(round(z / 2))))
    j = min(1500, max(0, int(round(x / 2))))
    return H[i, j]


def slope(x, z, r=20):
    vals = [h(x + dx, z + dz) for dx in (-r, 0, r) for dz in (-r, 0, r)]
    return max(vals) - min(vals)


def dry(x, z, r=40):
    return all(h(x + r * math.cos(a), z + r * math.sin(a)) > 2.0 for a in np.linspace(0, 2 * math.pi, 12, endpoint=False)) and h(x, z) > 2.0


# ------------------------------------------------------------------ cidades: estilo e porte (porte: decisão do Robson)
STYLE = {
    "aurora":   ("radial",      "Casas em dois anéis em volta da praça; torre do sino; moinho."),
    "dourado":  ("campos",      "Casas pequenas em quadras, celeiros, plantações e fardos de feno; coreto no centro."),
    "pedra":    ("terracos",    "Muralha quadrada; casas em três terraços; bairro das forjas com caldeirões; salão de pedra."),
    "sylvar":   ("bosque",      "Casas soltas entre árvores grandes e árvores luminosas; pavilhão central; sem ruas retas."),
    "rubra":    ("fortaleza",   "Muralha quadrada; quartéis em fileiras; arena de pedra no centro; braseiros."),
    "celeste":  ("mirante",     "Muralha hexagonal; casas em espiral subindo; torre alta no centro."),
    "presas":   ("acampamento", "Paliçada de madeira; cabanas em círculo grande; totens de pedra; várias fogueiras."),
    "umbraval": ("crescente",   "Casas em meia-lua em volta de um obelisco escuro; colunas; luz fria."),
    "pico":     ("encosta",     "Uma rua principal com casas dos dois lados; santuário do dragão no fim da rua."),
    "noctis":   ("gotica",      "Muralha quadrada; quadras retas; catedral de pedra com torres no centro; grades de ferro."),
    "glacial":  ("salao",       "Poucas casas grandes em volta de um grande salão; muralha redonda."),
}

# ------------------------------------------------------------------ castelos (sempre fora da cidade: 260 a 460 m dela)
CASTLES = [
    ("castelo_corvos", "Castelo dos Corvos", "aurora", (1180, 2250)),
    ("castelo_dourado", "Castelo do Vale Dourado", "dourado", None),
    ("castelo_pedra", "Castelo de Pedra Alta", "pedra", None),
    ("castelo_sylvar", "Castelo de Sylvar", "sylvar", None),
    ("castelo_rubra", "Castelo Rubro", "rubra", None),
    ("castelo_celeste", "Castelo Celeste", "celeste", None),
    ("castelo_sangue", "Castelo do Sangue Eterno", "noctis", (2650, 820)),
    ("castelo_pico", "Castelo do Pico", "pico", None),
    ("castelo_inverno", "Castelo do Trono do Inverno", "glacial", (520, 520)),
]

# ------------------------------------------------------------------ vilas: [id, nome, cidade dona] ou entre duas cidades
VILLAGES = [
    ("vila_campina", "Campina Velha", ["aurora"]),
    ("vila_moinhos", "Aldeia dos Moinhos", ["aurora", "dourado"]),
    ("vila_trigal", "Trigal", ["dourado"]),
    ("vila_vau", "Vau das Presas", ["dourado", "presas"]),
    ("vila_mina", "Mina Funda", ["pedra"]),
    ("vila_ponte", "Ponte de Pedra", ["aurora", "pedra"]),
    ("vila_clareira", "Clareira de Lys", ["sylvar"]),
    ("vila_sombria", "Encruzilhada Sombria", ["sylvar", "umbraval"]),
    ("vila_cinzas", "Acampamento das Cinzas", ["rubra"]),
    ("vila_nuvens", "Pouso das Nuvens", ["celeste"]),
    ("vila_escamas", "Vila das Escamas", ["pico"]),
    ("vila_fronteira", "Posto da Fronteira", ["pico", "rubra"]),
    ("vila_corvo", "Vigia do Corvo", ["noctis", "umbraval"]),
    ("vila_geada", "Aldeia da Geada", ["glacial"]),
]


def far_from_all(x, z, others, d_town=230, d_poi=150, d_other=180):
    if any(math.hypot(x - t["x"], z - t["z"]) < d_town for t in TOWNS.values()):
        return False
    if any(math.hypot(x - p["x"], z - p["z"]) < d_poi + p["r"] for p in POIS if not p["id"].startswith(("castelo", "trono"))):
        return False
    return all(math.hypot(x - o[0], z - o[1]) > d_other for o in others)


def find(cx, cz, rmin, rmax, others, need_high=False, wide=40, **kw):
    best = None
    for rr in np.linspace(rmin, rmax, 8):
        for a in np.linspace(0, 2 * math.pi, 48, endpoint=False):
            x, z = cx + rr * math.sin(a), cz + rr * math.cos(a)
            if not (80 < x < 2920 and 80 < z < 2920) or not dry(x, z, wide) or not far_from_all(x, z, others, **kw):
                continue
            score = slope(x, z) * 2.0 - (h(x, z) * 0.15 if need_high else 0) + abs(rr - (rmin + rmax) / 2) * 0.02
            if best is None or score < best[0]:
                best = (score, x, z)
    return None if best is None else (round(best[1]), round(best[2]))


def main():
    placed = []
    castles = []
    for cid, name, town, fixed in CASTLES:
        t = TOWNS[town]
        pos = fixed or find(t["x"], t["z"], 270, 460, placed, need_high=True, wide=50)
        if pos is None:
            print("sem lugar para", cid)
            continue
        placed.append(pos)
        castles.append({"id": cid, "name": name, "town": town, "x": pos[0], "z": pos[1], "dist": round(math.hypot(pos[0] - t["x"], pos[1] - t["z"]))})
    villages = []
    for vid, name, owners in VILLAGES:
        if len(owners) == 1:
            t = TOWNS[owners[0]]
            pos = find(t["x"], t["z"], 240, 340, placed, wide=30, d_other=200)
        else:
            a, b = TOWNS[owners[0]], TOWNS[owners[1]]
            mx, mz = (a["x"] + b["x"]) / 2, (a["z"] + b["z"]) / 2
            pos = find(mx, mz, 0, 260, placed, wide=30, d_other=200) or find(mx, mz, 0, 420, placed, wide=25, d_other=170, d_town=200)
        if pos is None:
            print("sem lugar para", vid)
            continue
        placed.append(pos)
        villages.append({"id": vid, "name": name, "towns": owners, "x": pos[0], "z": pos[1],
                         "houses": 7 + zlib.crc32(vid.encode()) % 6, "seed": zlib.crc32(vid.encode()) % 100000})
    towns = {tid: {"style": s, "desc": d, "size": "?"} for tid, (s, d) in STYLE.items()}
    out = {"towns": towns, "castles": castles, "villages": villages}
    with open(os.path.join(DATA, "mapa.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print(len(castles), "castelos,", len(villages), "vilas")
    for c in castles:
        print(f"  {c['name']}: {c['dist']} m de {TOWNS[c['town']]['name']}")
    for v in villages:
        print(f"  {v['name']} ({' / '.join(TOWNS[t]['name'] for t in v['towns'])}): {v['x']}, {v['z']}")


if __name__ == "__main__":
    main()
