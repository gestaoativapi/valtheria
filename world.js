// ===== Valtheria — geração determinística do mundo (cliente e servidor) =====
(function (root) {
  const GD = root.GD || (typeof require !== 'undefined' ? require('./data.js') : null);
  const { SIZE, SEED } = GD.WORLD, TOWNS = GD.TOWNS, CORE = GD.CORE_TOWNS, LM = GD.LANDMARKS || [];

  function hash2(x, y, s) { let h = Math.imul(x | 0, 0x27d4eb2d) ^ Math.imul(y | 0, 0x165667b1) ^ Math.imul(s | 0, 0x9e3779b1); h = Math.imul(h ^ (h >>> 15), 0x85ebca6b); h = Math.imul(h ^ (h >>> 13), 0xc2b2ae35); h ^= h >>> 16; return (h >>> 0) / 4294967296; }
  function vnoise(x, y, s) {
    const x0 = Math.floor(x), y0 = Math.floor(y), fx = x - x0, fy = y - y0;
    const sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
    const a = hash2(x0, y0, s), b = hash2(x0 + 1, y0, s), c = hash2(x0, y0 + 1, s), d = hash2(x0 + 1, y0 + 1, s);
    return a + (b - a) * sx + (c - a) * sy + (a - b - c + d) * sx * sy;
  }
  function fbm(x, y, s, oct) { let v = 0, amp = 0.5, f = 1, n = 0; for (let i = 0; i < oct; i++) { v += amp * vnoise(x * f, y * f, s + i * 17); n += amp; amp *= 0.5; f *= 2.03; } return v / n; }
  function mulberry32(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

  // estradas entre cidades
  const ROADS = [[0, 1], [0, 2], [1, 3], [2, 3], [3, 4], [3, 5], [1, 4], [2, 5], [6, 1], [6, 3], [7, 3], [7, 2], [8, 4], [8, 5], [9, 5], [9, 2], [10, 4]].map(([a, b]) => [TOWNS[a], TOWNS[b]]);
  const ROADS_V1 = ROADS.slice(0, 8);
  function roadDist(x, z, roads = ROADS) {
    let best = 1e9;
    for (const [a, b] of roads) {
      const dx = b.x - a.x, dz = b.z - a.z, L2 = dx * dx + dz * dz;
      let t = ((x - a.x) * dx + (z - a.z) * dz) / L2; t = Math.max(0, Math.min(1, t));
      // leve curvatura
      const wob = Math.sin(t * Math.PI * 3 + a.x) * 40 * Math.sin(t * Math.PI);
      const px = a.x + dx * t - dz / Math.sqrt(L2) * wob, pz = a.z + dz * t + dx / Math.sqrt(L2) * wob;
      const d = Math.hypot(x - px, z - pz); if (d < best) best = d;
    }
    return best;
  }
  function nearestTown(x, z) { let bi = 0, bd = 1e9; TOWNS.forEach((t, i) => { const d = Math.hypot(x - t.x, z - t.z); if (d < bd) { bd = d; bi = i; } }); return { town: TOWNS[bi], dist: bd }; }
  function nearestCore(x, z) { let bi = 0, bd = 1e9; CORE.forEach((t, i) => { const d = Math.hypot(x - t.x, z - t.z); if (d < bd) { bd = d; bi = i; } }); return { town: CORE[bi], dist: bd }; }
  function region(x, z) {
    const { town, dist } = nearestTown(x, z), core = nearestCore(x, z), band = core.town.band;
    const k = Math.max(0, Math.min(1, (core.dist - GD.SAFE_R) / 450));
    return { town, dist, safe: dist < GD.SAFE_R, level: Math.round(core.town.min + (core.town.max - core.town.min) * k), grade: band, core: core.town };
  }
  function nearestLandmark(x, z) { let b = null, bd = 1e9; for (const l of LM) { const d = Math.hypot(x - l.x, z - l.z); if (d < bd) { bd = d; b = l; } } return { lm: b, dist: bd }; }
  const TOWN_H = 6;
  function rawHeight(x, z) {
    const n = fbm(x / 420, z / 420, SEED, 4), m = fbm(x / 95, z / 95, SEED + 50, 3);
    let h = (n - 0.42) * 70 + (m - 0.5) * 10;
    const ridge = 1 - Math.abs(fbm(x / 260, z / 260, SEED + 99, 3) * 2 - 1); h += Math.pow(ridge, 3) * 28;
    const edge = Math.min(x, z, SIZE - x, SIZE - z); if (edge < 120) h = h * (edge / 120) - (1 - edge / 120) * 25;
    return h;
  }
  function height(x, z) {
    let h = rawHeight(x, z);
    const { town, dist } = nearestTown(x, z);
    if (dist < 150) { const k = Math.max(0, Math.min(1, (dist - 95) / 55)); h = TOWN_H + (h - TOWN_H) * k * k; }
    const L = nearestLandmark(x, z); if (L.dist < 80) { const base = Math.max(4, rawHeight(L.lm.x, L.lm.z)), k = Math.max(0, Math.min(1, (L.dist - 50) / 30)); h = base + (h - base) * k * k; }
    const rd = roadDist(x, z);
    if (rd < 14) { const k = rd / 14; const target = Math.max(1.2, h); h = target + (h - target) * k; if (h < 1.2) h = 1.2 + (h - 1.2) * k; }
    return h;
  }
  const WATER = 0;
  const isWater = (x, z) => height(x, z) < WATER + 0.3;

  // ---- versão 1 do mundo (6 cidades), usada só para manter os nós de recurso iguais aos do banco
  function nearest6(x, z) { let bi = 0, bd = 1e9; CORE.forEach((t, i) => { const d = Math.hypot(x - t.x, z - t.z); if (d < bd) { bd = d; bi = i; } }); return { town: CORE[bi], dist: bd }; }
  function heightV1(x, z) {
    let h = rawHeight(x, z); const { dist } = nearest6(x, z);
    if (dist < 150) { const k = Math.max(0, Math.min(1, (dist - 95) / 55)); h = TOWN_H + (h - TOWN_H) * k * k; }
    const rd = roadDist(x, z, ROADS_V1); if (rd < 14) { const k = rd / 14; const target = Math.max(1.2, h); h = target + (h - target) * k; if (h < 1.2) h = 1.2 + (h - 1.2) * k; }
    return h;
  }
  function regionV1(x, z) { const { town, dist } = nearest6(x, z); return { dist, grade: town.index }; }
  // nós de recurso (iguais no cliente e no banco) — posições da versão 1; o cliente esconde os que caíram em cidades/locais novos
  function nodeVisible(n) { return nearestTown(n.x, n.z).dist > 105 && nearestLandmark(n.x, n.z).dist > 70 && roadDist(n.x, n.z) > 8 && height(n.x, n.z) > 1.2; }
  function genNodes() {
    const nodes = [], STEP = 15; let id = 1;
    for (let gz = 0; gz < SIZE / STEP; gz++) for (let gx = 0; gx < SIZE / STEP; gx++) {
      const r = hash2(gx, gz, SEED + 7); if (r > 0.13) continue;
      const x = gx * STEP + hash2(gx, gz, SEED + 8) * STEP, z = gz * STEP + hash2(gx, gz, SEED + 9) * STEP;
      if (x < 140 || z < 140 || x > SIZE - 140 || z > SIZE - 140) continue;
      const rg = regionV1(x, z); if (rg.dist < 110 || (rg.grade > 0 && r > 0.085)) continue;
      const h = heightV1(x, z); if (h < 1.5 || roadDist(x, z, ROADS_V1) < 10) continue;
      const p = hash2(gx, gz, SEED + 10);
      const type = h > 26 ? (p < 0.7 ? 'minerio' : 'fibra') : p < 0.4 ? 'madeira' : p < 0.7 ? 'fibra' : 'minerio';
      nodes.push({ id: id++, x: Math.round(x * 10) / 10, z: Math.round(z * 10) / 10, type, grade: rg.grade });
    }
    return nodes;
  }

  // pontos de caça sempre em terra firme
  TOWNS.forEach(t => t.spotsPos.forEach(sp => {
    if (height(sp.x, sp.z) > 2) return;
    for (let r = 10; r < 300; r += 10) { let ok = false; for (let a = 0; a < 16; a++) { const x = sp.x + Math.cos(a / 16 * 6.283) * r, z = sp.z + Math.sin(a / 16 * 6.283) * r; if (height(x, z) > 2.5) { sp.x = Math.round(x); sp.z = Math.round(z); ok = true; break; } } if (ok) break; }
  }));

  const api = { hash2, fbm, mulberry32, height, rawHeight, isWater, region, nearestTown, nearestCore, nearestLandmark, nodeVisible, roadDist, genNodes, WATER, TOWN_H, ROADS };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.WG = api;
})(typeof window !== 'undefined' ? window : globalThis);
