#!/usr/bin/env python3
"""
Relevo das cidades especiais do Valtheria. Lê o terreno original (ferramentas/base/) e escreve
data/height.bin, data/splat.png, data/tint.png e data/world.json com:
  - capital gigante no centro-sul (Valtheria Real) e 4 cidades grandes com área plana maior;
  - Pico do Dragão e Bastião Celeste no alto de montanhas;
  - Baía das Marés: praia, porto (Porto Maré-Alta), ilha (Ilha de Coralis) e cidade no fundo do mar (Abissália);
  - Umbraval dentro de uma montanha oca (cidade subterrânea; o teto é montado pelo jogo).
Pode rodar quantas vezes quiser: sempre parte do terreno original.

Uso:  python3 ferramentas/relevo_cidades.py   (depois: python3 ferramentas/planejar_mapa.py)
"""
import json, math, os
import numpy as np
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
BASE = os.path.join(AQUI, "base")
DATA = os.path.join(os.path.dirname(AQUI), "data")
N, STEP, LO, RANGE = 1501, 2.0, -40.0, 300.0

H = np.fromfile(os.path.join(BASE, "height_base.bin"), dtype="<u2").reshape(N, N).astype(float) / 65535 * RANGE + LO
SPLAT = np.array(Image.open(os.path.join(BASE, "splat_base.png")).convert("RGBA")).astype(float)
TINT = np.array(Image.open(os.path.join(BASE, "tint_base.png")).convert("RGB")).astype(float)
W = json.load(open(os.path.join(BASE, "world_base.json"), encoding="utf-8"))

zz, xx = np.mgrid[0:N, 0:N].astype(float) * STEP  # linha = z, coluna = x
rng = np.random.default_rng(7)


def noise(scale, octaves=3, seed=0):
    r = np.random.default_rng(seed)
    out = np.zeros((N, N))
    amp = 1.0
    for o in range(octaves):
        cells = int(3000 / scale * (2 ** o)) + 2
        g = r.random((cells, cells))
        gi = np.linspace(0, cells - 1.001, N)
        i0 = gi.astype(int)
        f = gi - i0
        f = f * f * (3 - 2 * f)
        a = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i0 + 1] * f[None, :]
        b = g[i0 + 1][:, i0] * (1 - f)[None, :] + g[i0 + 1][:, i0 + 1] * f[None, :]
        out += amp * (a * (1 - f)[:, None] + b * f[:, None])
        amp *= 0.5
    return out / (2 - 2 ** (1 - octaves)) - 0.5


NZ = noise(260, 4, 1)
NZ2 = noise(90, 3, 2)


def sstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def dist(cx, cz):
    return np.hypot(xx - cx, zz - cz)


def paint(mask, tint=None, splat=None):
    m = mask[..., None]
    global TINT, SPLAT
    if tint is not None:
        TINT = TINT * (1 - m) + np.array(tint, float)[None, None, :] * m
    if splat is not None:
        sp = SPLAT.copy()
        for k, v in enumerate(splat):
            if v is not None:
                sp[..., k] = v
        SPLAT = SPLAT * (1 - m) + sp * m


def flatten(cx, cz, r_flat, r_blend, y):
    global H
    d = dist(cx, cz)
    k = 1 - sstep(r_flat, r_blend, d)
    H = H * (1 - k) + y * k
    return d


TOWN = {t["id"]: t for t in W["towns"]}
ROAD = (255, 0, 0, None)

# ---------------------------------------------------------------- cidades novas
NEW_TOWNS = [
    {"id": "capital", "name": "Valtheria Real", "x": 1500, "z": 1985, "race": "humano", "gates": [0.0, math.pi * 0.5, math.pi, -math.pi * 0.5]},
    {"id": "porto", "name": "Porto Maré-Alta", "x": 2390, "z": 2440, "race": "humano", "gates": [math.pi, math.pi * 0.5, -math.pi * 0.5]},
    {"id": "coralis", "name": "Ilha de Coralis", "x": 2560, "z": 2790, "race": "halfling", "gates": []},
    {"id": "abissal", "name": "Abissália", "x": 2290, "z": 2800, "race": "elfo", "gates": []},
]

# ---------------------------------------------------------------- capital e cidades grandes: áreas planas maiores
def flat_city(cx, cz, r_flat, r_blend, y):
    ring = [(int(min(N - 1, max(0, (cz + r_blend * 1.2 * math.cos(a)) / STEP))), int(min(N - 1, max(0, (cx + r_blend * 1.2 * math.sin(a)) / STEP)))) for a in np.linspace(0, 2 * math.pi, 24, endpoint=False)]
    col = np.median(np.array([TINT[i, j] for i, j in ring if H[i, j] > 1.0]), axis=0)
    d = flatten(cx, cz, r_flat, r_blend, y)
    paint(1 - sstep(r_flat, r_blend, d), tint=tuple(col), splat=(None, 255, 0, None))


flat_city(1500, 1985, 225, 330, 8.0)
for tid in ["dourado", "rubra", "noctis"]:
    t = TOWN[tid]
    flat_city(t["x"], t["z"], 150, 230, 6.0)

# ---------------------------------------------------------------- montanhas com cidade no topo
def mountain(cx, cz, top, r_flat, r_base, seed):
    global H
    d = dist(cx, cz)
    ang = np.arctan2(xx - cx, zz - cz)
    wob = 1 + 0.09 * np.sin(ang * 3 + seed) + 0.06 * np.sin(ang * 7 + seed * 2) + 0.45 * NZ
    rb = r_base * wob
    k = 1 - sstep(r_flat, rb, d)
    k = k ** 1.35
    ridges = (np.abs(NZ2) * 2) * k * (1 - k) * 4 * top * 0.05
    target = 6 + (top - 6) * k + ridges
    target = np.where(d < r_flat, top, target)
    H = np.maximum(H, target)
    slope = (k > 0.04) & (d > r_flat + 8)
    rockness = np.clip((k - 0.04) * 3, 0, 1) * slope
    paint(rockness * 0.85, tint=(118, 112, 104), splat=(0, 40, 255, None))
    snow = np.clip((H - (top * 0.62)) / 25, 0, 1) * (d > r_flat - 4)
    paint(snow * 0.9, tint=(236, 240, 246), splat=(0, 30, 120, None))
    return d


mountain(1450, 420, 168.0, 100, 430, 1.0)   # Pico do Dragão
mountain(2350, 650, 128.0, 98, 350, 2.0)    # Bastião Celeste

# ---------------------------------------------------------------- Baía das Marés
BX, BZ, RX, RZ = 2520, 2860, 480, 340
ang = np.arctan2(zz - BZ, xx - BX)
s = np.hypot((xx - BX) / RX, (zz - BZ) / RZ) * (1 + 0.06 * np.sin(ang * 7) + 0.08 * NZ)
bay = s < 1.14
sea = np.where(s < 0.93, -2 - 36 * sstep(0.93, 0.5, s), np.where(s < 1.0, 1.4 - 3.4 * (1 - s) / 0.07, 1.4))
blend = 1 - sstep(1.0, 1.14, s)
H = np.where(bay, H * (1 - blend) + np.minimum(H, sea) * blend, H)
beach = sstep(0.86, 0.95, s) * (1 - sstep(1.06, 1.14, s))
paint(beach, tint=(222, 202, 150), splat=(0, 60, 0, None))
seabed = s < 0.9
paint(seabed.astype(float) * 0.9, tint=(150, 140, 110), splat=(0, 0, 60, None))

# ilha de Coralis: rodeada de areia; dá para chegar nadando
d = dist(2560, 2790)
island = 3.6 - 14 * sstep(62, 100, d) ** 1.2
H = np.where(d < 100, np.maximum(H, island), H)
paint(sstep(100, 70, d) * (1 - sstep(40, 62, d)), tint=(228, 210, 160), splat=(0, 40, 0, None))
paint(1 - sstep(40, 62, d), tint=(96, 140, 70), splat=(0, 255, 0, None))

# Abissália: fundo do mar plano, dentro de uma bolha de ar
d = flatten(2290, 2800, 92, 130, -34.0)
paint(1 - sstep(80, 120, d), tint=(120, 132, 128), splat=(0, 0, 160, None))

# Porto Maré-Alta: cidade na beira da praia (a parte de cima é plana; o resto desce até a areia)
d = dist(2390, 2440)
kp = (1 - sstep(70, 120, d)) * (zz < 2500)
H = H * (1 - kp) + 6.0 * kp

# ---------------------------------------------------------------- Umbraval: montanha oca
t = TOWN["umbraval"]
d = dist(t["x"], t["z"])
a = np.arctan2(xx - t["x"], zz - t["z"])
gap = np.zeros_like(d)
for g in t["gates"]:
    gap = np.maximum(gap, 1 - sstep(0.07, 0.15, np.abs((a - g + math.pi) % (2 * math.pi) - math.pi)))
ring = sstep(116, 150, d) * (1 - sstep(190, 300, d))
ring_h = 6 + 104 * ring * (1 + 0.15 * NZ2) * (1 - gap * sstep(110, 135, d) * (1 - sstep(200, 240, d)) * 0.97)
H = np.where(d < 300, np.maximum(H, ring_h), H)
paint(np.clip(ring * 2, 0, 1) * (1 - gap * 0.6), tint=(82, 78, 88), splat=(0, 20, 255, None))
paint((1 - sstep(110, 125, d)), tint=(60, 58, 70), splat=(None, 0, 120, None))

# ---------------------------------------------------------------- estradas de terra até as cidades novas
def road(p, q, w=5.0):
    global H
    (x1, z1), (x2, z2) = p, q
    dx, dz = x2 - x1, z2 - z1
    L2 = dx * dx + dz * dz
    tt = np.clip(((xx - x1) * dx + (zz - z1) * dz) / L2, 0, 1)
    dd = np.hypot(xx - (x1 + tt * dx), zz - (z1 + tt * dz))
    m = (1 - sstep(w * 0.5, w, dd)) * (H > 1.0)
    paint(m, splat=ROAD)


road((1500, 2210), (1500, 2470))   # capital -> Vila Aurora
road((1500, 1760), (1500, 1540))   # capital -> Sylvar
road((1275, 1985), (760, 2050))    # capital -> Vale Dourado
road((1725, 1985), (2250, 1960))   # capital -> Pedra Alta
road((2390, 2370), (2350, 2040))   # Porto -> Pedra Alta
road((2300, 2440), (1590, 2550))   # Porto -> Vila Aurora

# ---------------------------------------------------------------- grava
Hq = np.clip(np.round((H - LO) / RANGE * 65535), 0, 65535).astype("<u2")
Hq.tofile(os.path.join(DATA, "height.bin"))
Image.fromarray(np.clip(SPLAT, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(DATA, "splat.png"))
Image.fromarray(np.clip(TINT, 0, 255).astype(np.uint8), "RGB").save(os.path.join(DATA, "tint.png"))


def band_of(x, z):
    i, j = min(N - 1, int(z / STEP)), min(N - 1, int(x / STEP))
    return int(round((255 - SPLAT[i, j, 3]) / 40))


towns = [t for t in W["towns"] if t["id"] not in {n["id"] for n in NEW_TOWNS}]
for nt in NEW_TOWNS:
    near = min(W["towns"], key=lambda t: math.hypot(t["x"] - nt["x"], t["z"] - nt["z"]))
    nt.update({"band": near["band"], "min": near["min"], "max": near["max"], "spots": []})
    if nt["id"] == "capital":
        nt.update({"band": 0, "min": 1, "max": 30})
    towns.append(nt)
W["towns"] = towns
json.dump(W, open(os.path.join(DATA, "world.json"), "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print("relevo gravado;", len(towns), "cidades")
for nt in NEW_TOWNS:
    i, j = int(nt["z"] / STEP), int(nt["x"] / STEP)
    print(f"  {nt['name']}: altura {H[i, j]:.1f}")
for tid in ["pico", "celeste", "umbraval"]:
    t = TOWN[tid]
    print(f"  {t['name']}: altura {H[int(t['z'] / STEP), int(t['x'] / STEP)]:.1f}")
