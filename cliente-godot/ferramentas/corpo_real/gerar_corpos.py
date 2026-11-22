#!/usr/bin/env python3
"""Fase 2 (estrutura corporal real): gera corpos humanos anatômicos por raça a partir da malha-base e dos
alvos de forma do MakeHuman/MPFB2 (licença CC0), sem serviço pago. Saída: OBJ por raça/gênero em metros.
Uso: python3 gerar_corpos.py <pasta_mpfb_data> <pasta_saida>
"""
import gzip, os, sys

DATA = sys.argv[1]
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)

def ler_base():
    vs, fs, grupo = [], [], None
    for ln in open(os.path.join(DATA, "3dobjs", "base.obj")):
        if ln.startswith("v "):
            vs.append([float(x) for x in ln.split()[1:4]])
        elif ln.startswith("g "):
            grupo = ln.split()[1]
        elif ln.startswith("f ") and grupo == "body":
            fs.append([int(t.split("/")[0]) for t in ln.split()[1:]])
    return vs, fs

CACHE = {}
def alvo(rel):
    if rel in CACHE:
        return CACHE[rel]
    p = os.path.join(DATA, "targets", rel + ".target.gz")
    d = []
    if os.path.exists(p):
        for ln in gzip.open(p, "rt"):
            ln = ln.strip()
            if not ln or ln.startswith("#"):
                continue
            a = ln.split()
            d.append((int(a[0]), float(a[1]), float(a[2]), float(a[3])))
    else:
        print("  (sem alvo)", rel)
    CACHE[rel] = d
    return d

def niveis(x, nomes):
    # 0..1 -> pesos de min / average / max (como o MakeHuman)
    if x < 0.5:
        return {nomes[0]: 1 - 2 * x, nomes[1]: 2 * x}
    return {nomes[1]: 2 - 2 * x, nomes[2]: 2 * x - 1}

def corpo(gen, musc, peso, alt, prop, locais):
    vs, fs = ler_base()
    acum = {}
    def soma(rel, w):
        if abs(w) < 1e-4:
            return
        for i, dx, dy, dz in alvo(rel):
            a = acum.setdefault(i, [0.0, 0.0, 0.0])
            a[0] += dx * w; a[1] += dy * w; a[2] += dz * w
    M = niveis(musc, ["minmuscle", "averagemuscle", "maxmuscle"])
    W = niveis(peso, ["minweight", "averageweight", "maxweight"])
    for m, wm in M.items():
        for p, wp in W.items():
            soma(f"macrodetails/universal-{gen}-young-{m}-{p}", wm * wp)
            if alt > 0.5:
                soma(f"macrodetails/height/{gen}-young-{m}-{p}-maxheight", wm * wp * (alt - 0.5) * 2)
            elif alt < 0.5:
                soma(f"macrodetails/height/{gen}-young-{m}-{p}-minheight", wm * wp * (0.5 - alt) * 2)
            soma(f"macrodetails/proportions/{gen}-young-{m}-{p}-idealproportions", wm * wp * prop)
    for et, we in (("caucasian", 0.6), ("african", 0.2), ("asian", 0.2)):
        soma(f"macrodetails/{et}-{gen}-young", we)
    for rel, w in locais.items():
        soma(rel, w)
    for i, d in acum.items():
        vs[i][0] += d[0]; vs[i][1] += d[1]; vs[i][2] += d[2]
    return vs, fs

def ambos(base, w):
    return {f"{base.replace('*', 'l')}": w, f"{base.replace('*', 'r')}": w}

# raças (masculino; a feminina usa os mesmos ajustes com gen=female e um pouco menos de músculo)
RACAS = {
    "humano": dict(musc=0.55, peso=0.5, alt=0.55, prop=0.8, locais={}),
    "elfo": dict(musc=0.45, peso=0.3, alt=0.8, prop=1.0, locais={
        "head/head-scale-horiz-decr": 0.3, "neck/measure-neck-height-incr": 0.3, **ambos("ears/*-ear-scale-incr", 0.4)}),
    "sombrio": dict(musc=0.6, peso=0.35, alt=0.75, prop=1.0, locais={
        "head/head-scale-horiz-decr": 0.2, **ambos("ears/*-ear-scale-incr", 0.4)}),
    "orc": dict(musc=1.0, peso=0.65, alt=0.9, prop=0.4, locais={
        "torso/measure-shoulder-dist-incr": 0.8, "neck/measure-neck-circ-incr": 0.8, "head/head-square": 0.7,
        "torso/torso-muscle-pectoral-incr": 0.6}),
    "anao": dict(musc=0.9, peso=0.75, alt=0.0, prop=0.2, locais={
        "torso/measure-shoulder-dist-incr": 0.9, "torso/torso-scale-horiz-incr": 0.6, "head/head-scale-horiz-incr": 0.35,
        "neck/measure-neck-height-decr": 0.7, **ambos("legs/*-upperleg-scale-vert-decr", 0.5), **ambos("legs/*-lowerleg-scale-vert-decr", 0.5)}),
    "gigante": dict(musc=1.0, peso=0.55, alt=1.0, prop=0.6, locais={
        "torso/measure-shoulder-dist-incr": 0.6, "head/head-rectangular": 0.5}),
}

def salvar(nome, vs, fs, altura_m):
    ys = [v[1] for v in vs]
    lo = min(ys); hi = max(ys)
    k = altura_m / (hi - lo)
    usados = sorted({i for f in fs for i in f})
    mapa = {o: n + 1 for n, o in enumerate(usados)}
    with open(os.path.join(OUT, nome + ".obj"), "w") as fh:
        fh.write("# gerado de MakeHuman/MPFB2 (CC0) por ferramentas/corpo_real/gerar_corpos.py\n")
        for o in usados:
            x, y, z = vs[o - 1]
            fh.write(f"v {x * k:.5f} {(y - lo) * k:.5f} {z * k:.5f}\n")
        for f in fs:
            fh.write("f " + " ".join(str(mapa[i]) for i in f) + "\n")
    print(nome, "altura", round(altura_m, 2), "vértices", len(usados))

ALTURA = {"humano": (1.80, 1.68), "elfo": (1.90, 1.78), "sombrio": (1.88, 1.76), "orc": (2.0, 1.87), "anao": (1.42, 1.35), "gigante": (2.15, 2.0)}
for raca, r in RACAS.items():
    for gen in ("male", "female"):
        musc = r["musc"] if gen == "male" else max(0.0, r["musc"] - 0.25)
        vs, fs = corpo(gen, musc, r["peso"], r["alt"], r["prop"], r["locais"])
        salvar(f"{raca}_{gen[0]}", vs, fs, ALTURA[raca][0 if gen == "male" else 1])
