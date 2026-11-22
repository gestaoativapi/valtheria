import gzip, os
CACHE = {}
def ler_base_completa(DATA):
    vs, uvs, faces, grupos, g = [], [], [], {}, None
    for ln in open(os.path.join(DATA, "3dobjs", "base.obj")):
        if ln.startswith("v "):
            vs.append([float(x) for x in ln.split()[1:4]])
        elif ln.startswith("vt "):
            uvs.append(tuple(float(x) for x in ln.split()[1:3]))
        elif ln.startswith("g "):
            g = ln.split()[1]
        elif ln.startswith("f "):
            idx = []
            for t in ln.split()[1:]:
                p = t.split("/")
                idx.append((int(p[0]) - 1, int(p[1]) - 1 if len(p) > 1 and p[1] else 0))
            grupos.setdefault(g, set()).update(i for i, _ in idx)
            if g == "body":
                faces.append(idx)
    return vs, uvs, faces, grupos

def alvo(DATA, rel):
    if rel in CACHE:
        return CACHE[rel]
    p = os.path.join(DATA, "targets", rel + ".target.gz")
    d = []
    if os.path.exists(p):
        for ln in gzip.open(p, "rt"):
            ln = ln.strip()
            if ln and not ln.startswith("#"):
                a = ln.split(); d.append((int(a[0]), float(a[1]), float(a[2]), float(a[3])))
    CACHE[rel] = d
    return d

def niveis(x, nomes):
    if x < 0.5:
        return {nomes[0]: 1 - 2 * x, nomes[1]: 2 * x}
    return {nomes[1]: 2 - 2 * x, nomes[2]: 2 * x - 1}

def aplicar(DATA, vs, gen, musc, peso, alt, prop, locais):
    vs = [list(v) for v in vs]
    acum = {}
    def soma(rel, w):
        if abs(w) < 1e-4: return
        for i, dx, dy, dz in alvo(DATA, rel):
            a = acum.setdefault(i, [0.0, 0.0, 0.0]); a[0] += dx * w; a[1] += dy * w; a[2] += dz * w
    M = niveis(musc, ["minmuscle", "averagemuscle", "maxmuscle"]); W = niveis(peso, ["minweight", "averageweight", "maxweight"])
    for m, wm in M.items():
        for p, wp in W.items():
            soma(f"macrodetails/universal-{gen}-young-{m}-{p}", wm * wp)
            if alt > 0.5: soma(f"macrodetails/height/{gen}-young-{m}-{p}-maxheight", wm * wp * (alt - 0.5) * 2)
            elif alt < 0.5: soma(f"macrodetails/height/{gen}-young-{m}-{p}-minheight", wm * wp * (0.5 - alt) * 2)
            soma(f"macrodetails/proportions/{gen}-young-{m}-{p}-idealproportions", wm * wp * prop)
    for et, we in (("caucasian", 0.6), ("african", 0.2), ("asian", 0.2)):
        soma(f"macrodetails/{et}-{gen}-young", we)
    for rel, w in locais.items():
        soma(rel, w)
    for i, d in acum.items():
        vs[i][0] += d[0]; vs[i][1] += d[1]; vs[i][2] += d[2]
    return vs

def ambos(base, w):
    return {base.replace("*", "l"): w, base.replace("*", "r"): w}

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

