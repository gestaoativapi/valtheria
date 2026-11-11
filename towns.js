// ===== Valtheria — cidades com arquitetura de cada raça, castelos, ruínas e covis =====
import * as THREE from './three.module.min.js';
import { makeFire, makeSmoke, ROCK_GEOS, rockMat } from './world3d.js';
import { GLTFLoader } from './GLTFLoader.js';
import { MeshoptDecoder } from './meshopt_decoder.module.js';

// ---------- prédios e objetos 3D (Quaternius Medieval Village Pack, CC0) ----------
// cada peça nasce com a versão procedural e é trocada pelo modelo quando ele carrega
const gl = new GLTFLoader(); gl.setMeshoptDecoder(MeshoptDecoder); const BCACHE = new Map();
const loadB = n => { if (!BCACHE.has(n)) BCACHE.set(n, gl.loadAsync(n + '.glb').then(g => { g.scene.traverse(o => { if (o.isMesh) { o.castShadow = o.receiveShadow = true; o.material.envMapIntensity = 0.8; } }); return g.scene; })); return BCACHE.get(n); };
export const BLD = { on: true };
function glbB(name, scale, fallback, rot = 0) {
  const g = new THREE.Group(); if (fallback) g.add(fallback);
  if (BLD.on) loadB(name).then(src => { const o = src.clone(true); o.scale.setScalar(scale); o.rotation.y = rot; if (fallback) g.remove(fallback); g.add(o); }).catch(() => {});
  return g;
}
const PROPS = [['b_barrel', 3.4], ['b_crate', 3.4], ['b_hay', 3.6], ['b_cart', 3.2], ['b_bags', 3.4], ['b_bench_1', 3.2], ['b_cauldron', 3.4]];
// objetos de rua perto das casas
function scatterProps(ctx, g, n, r1, r2, list = PROPS) {
  for (let i = 0; i < n; i++) { const a = i / n * Math.PI * 2 + 0.41 + (i % 3) * 0.05; if (!freeAt(ctx, a, 0.22)) continue; const r = r1 + ((i * 37) % 100) / 100 * (r2 - r1), x = ctx.t.x + Math.cos(a) * r, z = ctx.t.z + Math.sin(a) * r, [nm, sc] = list[i % list.length];
    place(ctx, g, glbB(nm, sc, null), x, z, a * 3.1, nm === 'b_cart' ? 1.4 : 0.7); }
}

const mats = new Map();
function M(color, o = {}) {
  const k = color + JSON.stringify(o);
  if (!mats.has(k)) mats.set(k, new THREE.MeshStandardMaterial({ color, roughness: o.rough ?? 0.85, metalness: o.metal ?? 0, emissive: o.em || 0, emissiveIntensity: o.ei ?? 1, transparent: !!o.op, opacity: o.op ?? 1, side: o.ds ? THREE.DoubleSide : THREE.FrontSide }));
  return mats.get(k);
}
export const ANIM = [];
const A = (p, c) => { p.add(c); return c; }; // objetos animados (moinhos, ilhas flutuantes, bandeiras)
const mesh = (geo, m, x = 0, y = 0, z = 0) => { const o = new THREE.Mesh(geo, m); o.position.set(x, y, z); o.castShadow = true; o.receiveShadow = true; return o; };
const box = (w, h, d, c, o) => mesh(new THREE.BoxGeometry(w, h, d), M(c, o));
const cyl = (rt, rb, h, c, s = 12, o) => mesh(new THREE.CylinderGeometry(rt, rb, h, s), M(c, o));
const cone = (r, h, c, s = 12, o) => mesh(new THREE.ConeGeometry(r, h, s), M(c, o));
const sph = (r, c, o, ws = 16, hs = 12) => mesh(new THREE.SphereGeometry(r, ws, hs), M(c, o));
function gable(w, d, h, c) { const s = new THREE.Shape(); s.moveTo(-w / 2 - 0.4, 0); s.lineTo(w / 2 + 0.4, 0); s.lineTo(0, h); s.lineTo(-w / 2 - 0.4, 0); const g = new THREE.ExtrudeGeometry(s, { depth: d + 0.8, bevelEnabled: false }); g.translate(0, 0, -(d + 0.8) / 2); return mesh(g, M(c)); }
function flag(color, h = 6) { const g = new THREE.Group(); g.add(cyl(0.08, 0.08, h, '#5a4a3a', 6)); g.children[0].position.y = h / 2; const cl = mesh(new THREE.PlaneGeometry(1.8, 1.1, 6, 2), M(color, { ds: true }), 0.95, h - 0.7, 0); g.add(cl); ANIM.push({ kind: 'flag', o: cl }); return g; }

// ---------- contexto ----------
// ctx: { t, H(x,z), roadAngles[], collide(x,z,r), statue(race,x,z,s,rot), dragonStatue(x,z,s) }
function freeAt(ctx, a, w = 0.28) { return !ctx.roadAngles.some(r => Math.abs(Math.atan2(Math.sin(a - r), Math.cos(a - r))) < w); }
function ringPlaces(ctx, n, r1, r2, w = 0.3) { const out = []; for (let i = 0; i < n; i++) { const a = i / n * Math.PI * 2 + 0.17; if (!freeAt(ctx, a, w)) continue; const r = i % 2 ? r2 : r1; out.push({ a, x: ctx.t.x + Math.cos(a) * r, z: ctx.t.z + Math.sin(a) * r }); } return out; }
function place(ctx, g, o, x, z, rot = 0, rad = 0) { o.position.set(x, ctx.H(x, z) - 0.2, z); o.rotation.y = rot; g.add(o); if (rad) ctx.collide(x, z, rad); return o; }
function facing(ctx, x, z) { return Math.atan2(ctx.t.x - x, ctx.t.z - z); }

// muralha circular com torres e portões nas estradas
function wallRing(ctx, g, o) {
  const { t } = ctx, R = o.r || 92, segs = Math.round(2 * Math.PI * R / o.seg);
  for (let i = 0; i < segs; i++) {
    const a = (i + 0.5) / segs * Math.PI * 2; if (!freeAt(ctx, a, o.gate || 0.13)) continue;
    const x = t.x + Math.cos(a) * R, z = t.z + Math.sin(a) * R, w = new THREE.Group();
    w.add(o.piece()); place(ctx, g, w, x, z, -a + Math.PI / 2);
  }
  if (o.tower) for (let i = 0; i < (o.towers || 8); i++) { const a = i / (o.towers || 8) * Math.PI * 2; const x = t.x + Math.cos(a) * R, z = t.z + Math.sin(a) * R; if (!freeAt(ctx, a, 0.2)) { if (o.gateFire) { [-0.16, 0.16].forEach(d => { const fx = t.x + Math.cos(a + d) * (R + 1), fz = t.z + Math.sin(a + d) * (R + 1); A(g, cyl(0.12, 0.14, 2.6, '#4a3a2a', 6)).position.set(fx, ctx.H(fx, fz) + 1.3, fz); g.add(makeFire(fx, ctx.H(fx, fz) + 2.7, fz, 0.5, o.gateFire, true)); }); } continue; } place(ctx, g, o.tower(), x, z, -a, 4); }
}

// ---------- casas por estilo ----------
function timberHouse(c) {
  const g = new THREE.Group(), w = 7 + c.v * 2, d = 6, h1 = 2.6, h2 = 2.8;
  A(g, box(w, h1, d, '#8a8478')).position.y = h1 / 2;
  A(g, box(w - 0.2, h2, d - 0.2, '#efe3c8')).position.y = h1 + h2 / 2;
  const beam = '#3a2a1e';
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) A(g, box(0.28, h2, 0.28, beam)).position.set(sx * (w / 2 - 0.1), h1 + h2 / 2, sz * (d / 2 - 0.1));
  A(g, box(w, 0.25, d + 0.05, beam)).position.y = h1 + 0.1; A(g, box(w, 0.25, d + 0.05, beam)).position.y = h1 + h2;
  for (const sz of [-1, 1]) { const x1 = box(0.2, 3.6, 0.1, beam); x1.position.set(-w / 4, h1 + h2 / 2, sz * d / 2); x1.rotation.z = 0.7; g.add(x1); const x2 = x1.clone(); x2.position.x = w / 4; x2.rotation.z = -0.7; g.add(x2); }
  const r = gable(w, d, 3.2, c.roof); r.position.y = h1 + h2; g.add(r);
  A(g, box(1.2, 2, 0.2, '#5a3a22')).position.set(0, 1, d / 2 + 0.05);
  [-1, 1].forEach(s => { const win = box(0.9, 0.8, 0.12, '#ffd98a', { em: 0xffa040, ei: c.night ? 1 : 0.25 }); win.position.set(s * w / 4, h1 + 1.4, d / 2 + 0.08); g.add(win); });
  if (c.chimney) { A(g, box(0.8, 3, 0.8, '#6a645a')).position.set(w / 3, h1 + h2 + 1.6, -d / 5); g.add(makeSmoke(w / 3, h1 + h2 + 3.2, -d / 5, 0.6)); }
  return g;
}
function stoneHouse(c) {
  const g = new THREE.Group(), w = 7 + c.v * 1.5, d = 7, h = 3.6;
  A(g, box(w, h, d, c.wall || '#7a7066')).position.y = h / 2;
  A(g, box(w + 0.8, 0.6, d + 0.8, c.roof || '#5a544c')).position.y = h + 0.3;
  if (c.rune) A(g, box(w + 0.02, 0.25, d + 0.02, '#3ad0ff', { em: 0x2aa0ff, ei: 1.2 })).position.y = h - 0.6;
  A(g, box(1.6, 2.4, 0.3, '#3a2a1e')).position.set(0, 1.2, d / 2 + 0.1);
  if (c.chimney) { A(g, box(1, 2.6, 1, '#5a544c')).position.set(-w / 3, h + 1.6, 0); g.add(makeSmoke(-w / 3, h + 3, 0, 0.7)); }
  return g;
}
function hobbitHole(c) {
  const g = new THREE.Group();
  const mound = sph(5, '#5a8a3a', {}, 20, 12); mound.scale.set(1.2, 0.6, 1); g.add(mound);
  const door = cyl(1.2, 1.2, 0.3, c.door, 20); door.rotation.x = Math.PI / 2; door.position.set(0, 1.2, 4.6); g.add(door);
  A(g, sph(0.12, '#e8c84a', { metal: 0.6, rough: 0.3 })).position.set(0.5, 1.2, 4.8);
  [-1, 1].forEach(s => { const w = cyl(0.55, 0.55, 0.2, '#ffd98a', 16, { em: 0xffa040, ei: 0.35 }); w.rotation.x = Math.PI / 2; w.position.set(s * 2.6, 1.5, 4.0); g.add(w); });
  A(g, cyl(0.35, 0.4, 2, '#7a6a5a', 8)).position.set(-1.5, 3.3, -1); g.add(makeSmoke(-1.5, 4.3, -1, 0.5));
  for (let i = 0; i < 6; i++) A(g, sph(0.25, ['#e84a6a', '#f0d040', '#a84ae8', '#ffffff'][i % 4], {}, 8, 6)).position.set(-3 + i * 1.2, 0.3, 5.6);
  return g;
}
function tent(c) {
  const g = new THREE.Group();
  if (c.yurt) { A(g, cyl(3.6, 3.6, 2.6, c.hide, 16)).position.y = 1.3; A(g, cone(4.2, 2.4, c.hide2 || c.hide, 16)).position.y = 3.8; }
  else { A(g, cone(3.4, 5.5, c.hide, 9)).position.y = 2.75; for (let i = 0; i < 4; i++) { const p = cyl(0.08, 0.08, 2, '#4a3422', 5); p.position.set(Math.cos(i * 1.6) * 0.3, 6, Math.sin(i * 1.6) * 0.3); p.rotation.z = (i - 1.5) * 0.25; g.add(p); } }
  A(g, box(1.4, 2, 0.2, '#2a1a10')).position.set(0, 1, c.yurt ? 3.6 : 2.2);
  return g;
}
function spireTower(c) {
  const g = new THREE.Group(), h = c.h || 16;
  A(g, cyl(c.r * 0.85, c.r, h, c.wall, 14)).position.y = h / 2;
  A(g, cone(c.r * 1.25, c.roofH || 6, c.roof, 14)).position.y = h + (c.roofH || 6) / 2;
  if (c.spire) A(g, cyl(0.06, 0.06, 3, '#e8d8a0', 6, { metal: 0.6 })).position.y = h + (c.roofH || 6) + 1.2;
  for (let i = 0; i < 3; i++) { const w = box(0.7, 1.2, 0.2, c.glow || '#ffd98a', { em: new THREE.Color(c.glow || '#ffa040').getHex(), ei: 0.6 }); const a = i * 2.1; w.position.set(Math.sin(a) * c.r * 0.86, h * (0.35 + i * 0.2), Math.cos(a) * c.r * 0.86); w.rotation.y = a; g.add(w); }
  return g;
}
function totem(colors) { const g = new THREE.Group(); colors.forEach((c, i) => { A(g, cyl(0.55, 0.6, 1.2, c, 8)).position.y = 0.6 + i * 1.2; }); const w = box(3.2, 0.3, 0.6, colors[0]); w.position.y = colors.length * 1.2 - 0.4; g.add(w); A(g, sph(0.5, '#efe8d8')).position.y = colors.length * 1.2 + 0.3; return g; }
function crystal(color, s = 1) { const g = new THREE.Group(); for (let i = 0; i < 5; i++) { const c = mesh(new THREE.OctahedronGeometry(0.8 * s, 0), M(color, { em: new THREE.Color(color).getHex(), ei: 0.7, rough: 0.2 })); c.scale.set(0.5, 1.6 + (i % 3) * 0.5, 0.5); c.position.set(Math.cos(i * 1.3) * 0.7 * s, 1.2 * s, Math.sin(i * 1.3) * 0.7 * s); c.rotation.z = (i - 2) * 0.25; g.add(c); } return g; }
function lampPost(ctx, g, x, z, color = '#ffffff', h = 3.4) { const y = ctx.H(x, z); A(g, cyl(0.1, 0.14, h, '#2a2420', 6)).position.set(x, y + h / 2, z); g.add(makeFire(x, y + h + 0.1, z, 0.42, color, false)); }

// ---------- estilos de cidade por raça ----------
const STYLES = {
  humano(ctx, g) {
    wallRing(ctx, g, { seg: 10, piece: () => { const p = new THREE.Group(); A(p, box(10.4, 6, 1.8, '#8a8478')).position.y = 3; for (let i = -2; i <= 2; i++) A(p, box(1.1, 1.1, 1.9, '#8a8478')).position.set(i * 2.2, 6.5, 0); return p; },
      tower: () => { const tw = new THREE.Group(); A(tw, cyl(3.2, 3.6, 10, '#7e786c', 16)).position.y = 5; A(tw, cone(4, 5, '#8a3b2b', 16)).position.y = 12.5; return tw; }, gateFire: '#ffffff' });
    const roofs = ['#8a3b2b', '#6a3a22', '#5a4a3a', '#7a2a22'];
    const HS = [['b_house_1', 3.3], ['b_house_2', 3.2], ['b_inn', 3.1], ['b_house_3', 3.6], ['b_house_4', 4.2], ['b_stable', 2.8], ['b_house_1', 3.3], ['b_blacksmith', 3.0]];
    ringPlaces(ctx, 16, 54, 72).forEach((p, i) => { const [nm, sc] = HS[i % HS.length]; place(ctx, g, glbB(nm, sc, timberHouse({ roof: roofs[i % 4], v: i % 3 * 0.5, chimney: i % 3 === 0 })), p.x, p.z, facing(ctx, p.x, p.z), 5.5); });
    { const a = ctx.freeDir(5), x = ctx.t.x + Math.cos(a) * 30, z = ctx.t.z + Math.sin(a) * 30; place(ctx, g, glbB('b_bell_tower', 3.4, null), x, z, facing(ctx, x, z), 3.5); }
    scatterProps(ctx, g, 26, 46, 80);
    // torre de menagem (castelo) atrás da praça
    const ka = ctx.freeDir(), kx = ctx.t.x + Math.cos(ka) * 40, kz = ctx.t.z + Math.sin(ka) * 40, keep = new THREE.Group();
    A(keep, box(12, 16, 12, '#8a8478')).position.y = 8; for (const sx of [-1, 1]) for (const sz of [-1, 1]) { A(keep, cyl(2.2, 2.4, 19, '#7e786c', 12)).position.set(sx * 6, 9.5, sz * 6); A(keep, cone(2.8, 4, '#3b4a8a', 12)).position.set(sx * 6, 21, sz * 6); }
    for (let i = -2; i <= 2; i++) for (const s of [-1, 1]) { A(keep, box(1.2, 1.2, 1.2, '#8a8478')).position.set(i * 2.4, 16.6, s * 5.6); A(keep, box(1.2, 1.2, 1.2, '#8a8478')).position.set(s * 5.6, 16.6, i * 2.4); }
    A(keep, box(2.4, 4, 0.4, '#3a2a1e')).position.set(0, 2, 6.1); const fl = flag('#c8a03a', 8); fl.position.y = 17; keep.add(fl);
    place(ctx, g, keep, kx, kz, facing(ctx, kx, kz), 10);
    // poço e barracas de feira
    const wl = new THREE.Group(); A(wl, cyl(1.4, 1.5, 1.1, '#8a8478', 16)).position.y = 0.55; A(wl, cyl(1.2, 1.2, 0.1, '#2a5a8a', 16)).position.y = 1.0; [-1, 1].forEach(s => A(wl, box(0.2, 2.4, 0.2, '#4a3422')).position.set(s * 1.2, 1.9, 0)); A(wl, gable(2.6, 2.4, 1, '#6a3a22')).position.y = 3.1;
    place(ctx, g, glbB('b_well', 3.6, wl), ctx.t.x + 22, ctx.t.z - 22, 0, 1.6);
    ['#c83a3a', '#3a7ac8', '#e8c03a'].forEach((cc, i) => { const s = new THREE.Group(); A(s, box(3, 1, 1.6, '#6a4a2a')).position.y = 0.5; [-1, 1].forEach(a => [-1, 1].forEach(b => A(s, box(0.12, 2.6, 0.12, '#4a3422')).position.set(a * 1.4, 1.3, b * 0.75))); const cv = box(3.4, 0.12, 2, cc); cv.position.y = 2.6; cv.rotation.x = 0.15; s.add(cv); const a = ctx.freeDir(i + 2), x = ctx.t.x + Math.cos(a) * 32, z = ctx.t.z + Math.sin(a) * 32; place(ctx, g, glbB(i % 2 ? 'b_marketstand_2' : 'b_marketstand_1', 3.2, s), x, z, facing(ctx, x, z), 2); });
    ringPlaces(ctx, 10, 42, 42, 0.2).forEach(p => lampPost(ctx, g, p.x, p.z));
  },
  halfling(ctx, g) {
    const doors = ['#2a7a3a', '#c8a03a', '#3a5ac8', '#c83a3a', '#7a3ac8'];
    ringPlaces(ctx, 14, 52, 70).forEach((p, i) => place(ctx, g, hobbitHole({ door: doors[i % 5] }), p.x, p.z, facing(ctx, p.x, p.z), 5.5));
    // cercas baixas
    for (let i = 0; i < 70; i++) { const a = i / 70 * Math.PI * 2; if (!freeAt(ctx, a, 0.12)) continue; const x = ctx.t.x + Math.cos(a) * 88, z = ctx.t.z + Math.sin(a) * 88, f = new THREE.Group(); A(f, box(0.2, 1.2, 0.2, '#7a5a3a')).position.y = 0.6; A(f, box(0.12, 0.12, 8.2, '#8a6a4a')).position.y = 0.9; place(ctx, g, f, x, z, -a); }
    // moinho de vento
    const a = ctx.freeDir(), x = ctx.t.x + Math.cos(a) * 38, z = ctx.t.z + Math.sin(a) * 38, mill = new THREE.Group();
    A(mill, cyl(2.2, 3.2, 10, '#e8dcc0', 12)).position.y = 5; A(mill, cone(3, 3.5, '#6a3a22', 12)).position.y = 11.7;
    const blades = new THREE.Group(); blades.position.set(0, 9, 3.2); for (let i = 0; i < 4; i++) { const b = box(1.1, 7, 0.12, '#efe3c8'); b.position.y = 3.6; const arm = new THREE.Group(); arm.add(b); arm.rotation.z = i * Math.PI / 2; blades.add(arm); } mill.add(blades); ANIM.push({ kind: 'spin', o: blades, s: 0.6 });
    place(ctx, g, mill, x, z, facing(ctx, x, z), 3.5);
    ringPlaces(ctx, 8, 40, 40, 0.2).forEach(p => lampPost(ctx, g, p.x, p.z, '#ffe8b0', 2.6));
    { const b = ctx.freeDir(6), mx = ctx.t.x + Math.cos(b) * 34, mz = ctx.t.z + Math.sin(b) * 34; place(ctx, g, glbB('b_mill', 3.4, null), mx, mz, facing(ctx, mx, mz), 4); }
    scatterProps(ctx, g, 22, 44, 82, [['b_hay', 3.8], ['b_cart', 3.2], ['b_barrel', 3.4], ['b_bench_1', 3.2], ['b_crate', 3.4]]);
  },
  anao(ctx, g) {
    wallRing(ctx, g, { seg: 9, piece: () => { const p = new THREE.Group(); A(p, box(9.4, 8, 3, '#6a645a')).position.y = 4; A(p, box(9.6, 1, 3.4, '#4a463e')).position.y = 8.5; return p; },
      tower: () => { const tw = new THREE.Group(); A(tw, box(7, 12, 7, '#5a554c')).position.y = 6; A(tw, box(8, 1.4, 8, '#3a3630')).position.y = 12.7; tw.add(makeFire(0, 13.6, 0, 1.0, '#ffffff', true)); return tw; }, towers: 6, gateFire: '#ffffff' });
    ringPlaces(ctx, 14, 52, 70).forEach((p, i) => place(ctx, g, stoneHouse({ v: i % 3, rune: i % 2 === 0, chimney: true }), p.x, p.z, facing(ctx, p.x, p.z), 5.5));
    // grande forja
    const a = ctx.freeDir(), x = ctx.t.x + Math.cos(a) * 38, z = ctx.t.z + Math.sin(a) * 38, f = new THREE.Group();
    A(f, box(14, 7, 10, '#5a554c')).position.y = 3.5; A(f, box(15, 1, 11, '#3a3630')).position.y = 7.5; A(f, box(6, 5, 0.3, '#1a1410')).position.set(0, 2.5, 5.1);
    f.add(makeFire(0, 0.8, 5.8, 1.6, '#ffffff', true)); A(f, box(1.6, 8, 1.6, '#4a463e')).position.set(5, 9, -2); f.add(makeSmoke(5, 13, -2, 1.3));
    place(ctx, g, f, x, z, facing(ctx, x, z), 8);
    scatterProps(ctx, g, 20, 44, 80, [['b_barrel', 3.6], ['b_crate', 3.6], ['b_cauldron', 3.6], ['b_cart', 3.2]]);
    const b = ctx.freeDir(3), sx = ctx.t.x + Math.cos(b) * 30, sz = ctx.t.z + Math.sin(b) * 30; ctx.statue('anao', sx, sz, 3.2, facing(ctx, sx, sz));
    ringPlaces(ctx, 8, 42, 42, 0.2).forEach(p => { const y = ctx.H(p.x, p.z); A(g, cyl(0.8, 0.5, 1.2, '#3a3630', 8)).position.set(p.x, y + 0.6, p.z); g.add(makeFire(p.x, y + 1.3, p.z, 0.7, '#ffffff', false)); });
  },
  elfo(ctx, g) {
    ringPlaces(ctx, 10, 56, 74).forEach((p, i) => place(ctx, g, spireTower({ r: 2 + (i % 3) * 0.4, h: 14 + (i % 4) * 4, wall: '#f0f0ea', roof: '#2a8a7a', spire: true, glow: '#9ad8ff' }), p.x, p.z, 0, 3));
    // árvores colossais
    for (let i = 0; i < 4; i++) { const a = ctx.freeDir(i * 2), x = ctx.t.x + Math.cos(a) * 82, z = ctx.t.z + Math.sin(a) * 82, tr = new THREE.Group(); A(tr, cyl(1.6, 2.4, 16, '#6a5a44', 12)).position.y = 8; [[0, 18, 0, 7], [4, 15, 2, 5], [-4, 16, -2, 5.5], [1, 21, -1, 4.5]].forEach(([cx, cy, cz, r]) => A(tr, sph(r, '#3a8a4a', {}, 18, 12)).position.set(cx, cy, cz)); place(ctx, g, tr, x, z, 0, 3); }
    // arcos e lanternas flutuantes
    ringPlaces(ctx, 6, 36, 36, 0.25).forEach(p => { const ar = mesh(new THREE.TorusGeometry(3, 0.3, 8, 24, Math.PI), M('#f0f0ea', { metal: 0.2 })); place(ctx, g, ar, p.x, p.z, facing(ctx, p.x, p.z) + Math.PI / 2); ar.position.y += 0; const l = makeFire(p.x, ctx.H(p.x, p.z) + 5, p.z, 0.5, '#7ad0ff'); g.add(l); ANIM.push({ kind: 'bob', o: l, y: l.position.y, s: 1 + Math.random() }); });
  },
  orc(ctx, g) {
    wallRing(ctx, g, { seg: 2.3, gate: 0.1, piece: () => { const p = new THREE.Group(); const h = 6 + Math.random() * 1.6; A(p, cyl(0.6, 0.7, h, '#6a4a2a', 7)).position.y = h / 2; A(p, cone(0.6, 1.4, '#7a5a3a', 7)).position.y = h + 0.7; return p; },
      tower: () => { const tw = new THREE.Group(); [-1, 1].forEach(a => [-1, 1].forEach(b => A(tw, cyl(0.25, 0.3, 9, '#5a3a22', 6)).position.set(a * 1.8, 4.5, b * 1.8))); A(tw, box(5, 0.4, 5, '#6a4a2a')).position.y = 8; A(tw, cone(3.6, 3, '#8a5a3a', 6)).position.y = 10; const f = flag('#a82a22', 4); f.position.y = 11; tw.add(f); return tw; }, gateFire: '#ffffff' });
    const hides = ['#8a6a4a', '#7a5a3a', '#9a7a5a', '#6a4a2a'];
    ringPlaces(ctx, 16, 52, 70).forEach((p, i) => place(ctx, g, tent({ hide: hides[i % 4] }), p.x, p.z, facing(ctx, p.x, p.z), 3.6));
    scatterProps(ctx, g, 18, 44, 80, [['b_barrel', 3.4], ['b_hay', 3.6], ['b_cart', 3.2], ['b_bags', 3.6]]);
    for (let i = 0; i < 5; i++) { const a = ctx.freeDir(i * 3), x = ctx.t.x + Math.cos(a) * 34, z = ctx.t.z + Math.sin(a) * 34; place(ctx, g, totem(['#8a2a1a', '#3a2a1a', '#8a6a2a']), x, z, facing(ctx, x, z), 1); }
    const a = ctx.freeDir(1), bx = ctx.t.x + Math.cos(a) * 26, bz = ctx.t.z + Math.sin(a) * 26; g.add(makeFire(bx, ctx.H(bx, bz) + 0.2, bz, 2.4, '#ffffff', true, true));
    for (let i = 0; i < 8; i++) A(g, cyl(0.18, 0.2, 2.4, '#4a3422', 5)).position.set(bx + Math.cos(i) * 2.6, ctx.H(bx, bz) + 0.4, bz + Math.sin(i) * 2.6).y;
  },
  sylph(ctx, g) {
    ringPlaces(ctx, 12, 56, 74).forEach((p, i) => place(ctx, g, spireTower({ r: 1.6, h: 18 + (i % 3) * 5, wall: '#f4f6ff', roof: '#a8c8f0', roofH: 9, spire: true, glow: '#c8e8ff' }), p.x, p.z, 0, 2.5));
    for (let i = 0; i < 7; i++) {
      const a = i / 7 * Math.PI * 2 + 0.3, x = ctx.t.x + Math.cos(a) * 46, z = ctx.t.z + Math.sin(a) * 46, isl = new THREE.Group();
      const rk = mesh(ROCK_GEOS[i % 3], rockMat); rk.scale.set(4, 3.2, 4); rk.rotation.x = Math.PI; isl.add(rk); A(isl, cyl(3.6, 3.6, 0.4, '#7ac87a', 16)).position.y = 0.2; A(isl, crystal('#9ae8ff', 0.8)).position.y = 0.2;
      isl.position.set(x, ctx.H(x, z) + 14 + (i % 3) * 5, z); g.add(isl); ANIM.push({ kind: 'bob', o: isl, y: isl.position.y, s: 0.5 + i * 0.1 });
    }
    ringPlaces(ctx, 8, 38, 38, 0.2).forEach(p => place(ctx, g, crystal('#c8f0ff', 0.9), p.x, p.z));
  },
  beastman(ctx, g) {
    const hides = ['#a8784a', '#8a5a3a', '#c8a070', '#7a6a5a'];
    ringPlaces(ctx, 14, 52, 70).forEach((p, i) => place(ctx, g, tent({ yurt: true, hide: hides[i % 4], hide2: hides[(i + 1) % 4] }), p.x, p.z, facing(ctx, p.x, p.z), 4.4));
    scatterProps(ctx, g, 18, 44, 80, [['b_hay', 3.6], ['b_cart', 3.2], ['b_barrel', 3.4], ['b_cauldron', 3.6]]);
    for (let i = 0; i < 6; i++) { const a = ctx.freeDir(i * 2), x = ctx.t.x + Math.cos(a) * 36, z = ctx.t.z + Math.sin(a) * 36; place(ctx, g, totem(['#c84a2a', '#e8c03a', '#3a8a5a', '#2a2a2a']), x, z, facing(ctx, x, z), 1); }
    // arco de presas
    for (let i = 0; i < 3; i++) { const a = ctx.roadAngles[i] ?? i * 2, x = ctx.t.x + Math.cos(a) * 88, z = ctx.t.z + Math.sin(a) * 88; [-1, 1].forEach(s => { const tk = cone(0.8, 9, '#efe8d8', 10); const ox = x + Math.cos(a + Math.PI / 2) * s * 4, oz = z + Math.sin(a + Math.PI / 2) * s * 4; tk.position.set(ox, ctx.H(ox, oz) + 4, oz); tk.rotation.set(0, -a, s * 0.35); g.add(tk); }); }
    ringPlaces(ctx, 5, 26, 26, 0.3).forEach(p => g.add(makeFire(p.x, ctx.H(p.x, p.z) + 0.2, p.z, 1.1, '#ffffff', true, true)));
  },
  sombrio(ctx, g) {
    wallRing(ctx, g, { seg: 3.2, gate: 0.12, piece: () => { const p = new THREE.Group(); const c = cone(1.6, 7 + Math.random() * 4, '#2a2238', 5, { rough: 0.3, metal: 0.3 }); c.position.y = 4; p.add(c); return p; } });
    ringPlaces(ctx, 12, 54, 72).forEach((p, i) => { const sp = new THREE.Group(); const o = mesh(new THREE.OctahedronGeometry(3, 0), M('#2a2238', { rough: 0.25, metal: 0.4 })); o.scale.set(0.8, 3.5 + (i % 3), 0.8); o.position.y = 9; sp.add(o); const win = box(0.6, 6, 0.2, '#c86aff', { em: 0x9a3aff, ei: 1 }); win.position.set(0, 9, 2.2); sp.add(win); place(ctx, g, sp, p.x, p.z, facing(ctx, p.x, p.z), 3); });
    ringPlaces(ctx, 10, 36, 40, 0.2).forEach((p, i) => { place(ctx, g, crystal('#b06aff', 1.1), p.x, p.z); if (i % 2) g.add(makeFire(p.x, ctx.H(p.x, p.z) + 3.2, p.z, 0.6, '#c06aff', true)); });
  },
  draconato(ctx, g) {
    scatterProps(ctx, g, 14, 46, 80, [['b_barrel', 3.4], ['b_crate', 3.4], ['b_bags', 3.4]]);
    const a = ctx.freeDir(), x = ctx.t.x + Math.cos(a) * 40, z = ctx.t.z + Math.sin(a) * 40, zig = new THREE.Group();
    [[22, 4], [16, 4], [10, 4], [5, 3]].reduce((y, [s, h]) => { A(zig, box(s, h, s, '#2a2626', { rough: 0.6 })).position.y = y + h / 2; A(zig, box(s + 0.1, 0.3, s + 0.1, '#ff6a1a', { em: 0xff4a0a, ei: 1.4 })).position.y = y + h - 0.2; return y + h; }, 0);
    zig.add(makeFire(0, 15.2, 0, 2.4, '#ffffff', true, true)); place(ctx, g, zig, x, z, facing(ctx, x, z), 12);
    ringPlaces(ctx, 12, 56, 74).forEach((p, i) => place(ctx, g, stoneHouse({ v: i % 3, wall: '#3a3434', roof: '#1e1a1a' }), p.x, p.z, facing(ctx, p.x, p.z), 5.5));
    ringPlaces(ctx, 6, 30, 30, 0.25).forEach(p => { const lv = mesh(new THREE.CircleGeometry(3, 20), M('#ff6a1a', { em: 0xff3a00, ei: 1.6 })); lv.rotation.x = -Math.PI / 2; lv.position.set(p.x, ctx.H(p.x, p.z) + 0.08, p.z); g.add(lv); });
    ringPlaces(ctx, 10, 44, 44, 0.2).forEach(p => { const y = ctx.H(p.x, p.z); A(g, cyl(0.9, 0.5, 2.4, '#2a2626', 8)).position.set(p.x, y + 1.2, p.z); g.add(makeFire(p.x, y + 2.5, p.z, 1, '#ffffff', false)); });
    const b = ctx.freeDir(4), dx = ctx.t.x + Math.cos(b) * 28, dz = ctx.t.z + Math.sin(b) * 28; ctx.dragonStatue(dx, dz, 2.2, facing(ctx, dx, dz));
  },
  nocturno(ctx, g) {
    scatterProps(ctx, g, 14, 46, 80, [['b_barrel', 3.4], ['b_crate', 3.4], ['b_bags', 3.4]]);
    wallRing(ctx, g, { seg: 10, piece: () => { const p = new THREE.Group(); A(p, box(10.4, 9, 2, '#2e2a33')).position.y = 4.5; for (let i = -2; i <= 2; i++) A(p, cone(0.7, 2, '#2e2a33', 4)).position.set(i * 2.2, 10, 0); return p; },
      tower: () => spireTower({ r: 3, h: 16, wall: '#2e2a33', roof: '#1a161e', roofH: 10, spire: true, glow: '#ff3a4a' }), gateFire: '#ff6a6a' });
    // catedral
    const a = ctx.freeDir(), x = ctx.t.x + Math.cos(a) * 42, z = ctx.t.z + Math.sin(a) * 42, c = new THREE.Group();
    A(c, box(12, 14, 26, '#2e2a33')).position.y = 7; A(c, gable(12, 26, 8, '#1a161e')).position.y = 14;
    [-1, 1].forEach(s => { const sp = spireTower({ r: 2.6, h: 24, wall: '#2e2a33', roof: '#1a161e', roofH: 12, spire: true, glow: '#ff3a4a' }); sp.position.set(s * 5, 0, 13); c.add(sp); });
    const rose = cyl(3, 3, 0.3, '#c81a2a', 20, { em: 0xff1a2a, ei: 0.9 }); rose.rotation.x = Math.PI / 2; rose.position.set(0, 10, 13.1); c.add(rose);
    place(ctx, g, c, x, z, facing(ctx, x, z), 13);
    ringPlaces(ctx, 12, 58, 74).forEach((p, i) => place(ctx, g, stoneHouse({ v: i % 3, wall: '#3a3440', roof: '#1e1a22' }), p.x, p.z, facing(ctx, p.x, p.z), 5.5));
    ringPlaces(ctx, 10, 36, 36, 0.2).forEach(p => lampPost(ctx, g, p.x, p.z, '#ff4a4a', 3.8));
  },
  gigante(ctx, g) {
    scatterProps(ctx, g, 14, 46, 80, [['b_barrel', 3.4], ['b_crate', 3.4], ['b_bags', 3.4]]);
    wallRing(ctx, g, { seg: 8, piece: () => { const p = new THREE.Group(); A(p, box(8.4, 9, 4, '#c8dce8', { rough: 0.4 })).position.y = 4.5; A(p, box(8.6, 1.4, 4.4, '#ffffff')).position.y = 9.6; return p; },
      tower: () => { const tw = new THREE.Group(); A(tw, cyl(4, 5, 14, '#b8d0e0', 10, { rough: 0.4 })).position.y = 7; A(tw, cone(5.4, 6, '#ffffff', 10)).position.y = 17; return tw; }, towers: 6, gateFire: '#7ad8ff' });
    ringPlaces(ctx, 10, 56, 74).forEach((p, i) => { const lh = new THREE.Group(); A(lh, box(10, 6, 16, '#8a98a8')).position.y = 3; const r = gable(10, 16, 5, '#f4f8ff'); r.position.y = 6; lh.add(r); A(lh, box(2.4, 4, 0.3, '#3a2a1e')).position.set(0, 2, 8.1); for (let k = 0; k < 6; k++) A(lh, cone(0.25, 1.2, '#d8f0ff', 6, { op: 0.8 })).position.set(-4 + k * 1.6, 5.4, 8.2); place(ctx, g, lh, p.x, p.z, facing(ctx, p.x, p.z), 8); });
    ringPlaces(ctx, 10, 36, 40, 0.2).forEach((p, i) => { const ic = crystal('#bfefff', 1.5); place(ctx, g, ic, p.x, p.z); if (i % 2) g.add(makeFire(p.x, ctx.H(p.x, p.z) + 0.3, p.z, 1.1, '#7ad8ff', true)); });
  },
};
export function buildTownArchitecture(ctx) {
  const g = new THREE.Group(); const fn = STYLES[ctx.t.race] || STYLES.humano;
  let k = 0; ctx.freeDir = (seed = 0) => { for (let i = 0; i < 24; i++) { const a = ((seed * 7 + k++ * 5 + i) % 24) / 24 * Math.PI * 2 + 0.13; if (freeAt(ctx, a, 0.45)) return a; } return 0.5; };
  fn(ctx, g); return g;
}

// ---------- locais especiais ----------
export function buildLandmark(ctx, L) {
  const g = new THREE.Group(), x = L.x, z = L.z, y0 = ctx.H(x, z);
  if (L.type === 'castelo') {
    const stone = L.id === 'castelo_sangue' ? '#3a3036' : L.id === 'forte_bandido' ? '#6a5a4a' : '#5a5650', S = 26;
    for (let i = -2; i <= 2; i++) for (const s of [-1, 1]) {
      if (s === 1 && i === 0) continue; // portão
      const broken = (i * 7 + s * 3 + L.x) % 5 === 0;
      const w1 = box(10.6, broken ? 4 : 8, 2, stone); w1.position.set(x + i * 10.4, y0 + (broken ? 2 : 4), z + s * S); g.add(w1);
      const w2 = box(2, broken ? 3 : 8, 10.6, stone); w2.position.set(x + s * S, y0 + (broken ? 1.5 : 4), z + i * 10.4); g.add(w2);
    }
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) { A(g, cyl(4, 4.4, 14, stone, 14)).position.set(x + sx * S, y0 + 7, z + sz * S); A(g, cone(4.8, 6, L.id === 'castelo_sangue' ? '#5a0a1a' : '#2a2a2a', 14)).position.set(x + sx * S, y0 + 17, z + sz * S); }
    const keep = box(14, 20, 14, stone); keep.position.set(x, y0 + 10, z - 4); g.add(keep);
    for (let i = -2; i <= 2; i++) A(g, box(1.4, 1.4, 1.4, stone)).position.set(x + i * 2.8, y0 + 20.7, z + 3);
    const f = flag(L.id === 'castelo_sangue' ? '#8a0a1a' : '#2a2a3a', 8); f.position.set(x, y0 + 20, z - 4); g.add(f);
    [-4, 4].forEach(d => g.add(makeFire(x + d, y0 + 3.6, z + S + 1.4, 0.55, L.id === 'castelo_sangue' ? '#ff5a5a' : '#ffffff', true)));
    ctx.collide(x, z - 4, 9);
  } else if (L.type === 'ruina') {
    const stone = L.id === 'templo_lua' ? '#b8b8d0' : '#9a9486';
    for (let i = 0; i < 14; i++) { const a = i / 14 * Math.PI * 2, r = 18, px = x + Math.cos(a) * r, pz = z + Math.sin(a) * r, h = (i % 3 === 0) ? 3 + (i % 4) : 10; const col = cyl(1, 1.2, h, stone, 12); col.position.set(px, y0 + h / 2, pz); g.add(col); if (h > 8 && i % 2) { const cap = box(2.6, 0.8, 2.6, stone); cap.position.set(px, y0 + h + 0.4, pz); g.add(cap); } ctx.collide(px, pz, 1.4); }
    for (let i = 0; i < 6; i++) { const fc = cyl(1, 1, 7, stone, 10); fc.rotation.z = Math.PI / 2; fc.rotation.y = i; fc.position.set(x + Math.cos(i * 1.7) * 10, y0 + 0.9, z + Math.sin(i * 1.7) * 10); g.add(fc); }
    for (let i = 0; i < 5; i++) { const w = box(8, 3 + (i % 3) * 2, 1.4, stone); const a = i * 1.3; w.position.set(x + Math.cos(a) * 26, y0 + 2, z + Math.sin(a) * 26); w.rotation.y = -a; g.add(w); }
    const alt = box(5, 1.6, 5, stone); alt.position.set(x, y0 + 0.8, z); g.add(alt);
    g.add(makeFire(x, y0 + 2, z, 1.4, L.id === 'templo_lua' ? '#9ab0ff' : '#7aff9a', true));
  } else if (L.type === 'tumba') {
    // cemitério com lápides, cripta de pedra, colunas quebradas, ossos e velas
    const st = '#7a766e', dk = '#4a4640';
    for (let i = 0; i < 34; i++) { const a = i * 2.39996, r = 8 + Math.sqrt(i) * 4.2, px = x + Math.cos(a) * r, pz = z + Math.sin(a) * r, ty = i % 4, gy = ctx.H(px, pz);
      const t = new THREE.Group(); if (ty === 0) { A(t, box(0.9, 1.4, 0.22, st)).position.y = 0.6; A(t, cyl(0.45, 0.45, 0.22, st, 12)).position.y = 1.3; t.children[1].rotation.x = Math.PI / 2; }
      else if (ty === 1) { A(t, box(0.18, 1.8, 0.18, dk)).position.y = 0.9; A(t, box(0.9, 0.18, 0.18, dk)).position.y = 1.3; }
      else if (ty === 2) { A(t, box(1.1, 0.5, 2.1, st)).position.y = 0.25; A(t, box(0.8, 1.1, 0.25, st)).position.set(0, 0.8, -0.9); }
      else A(t, box(0.7, 1.0, 0.2, st)).position.y = 0.45;
      t.rotation.set((i % 5 - 2) * 0.06, a + 1.57, (i % 3 - 1) * 0.08); t.position.set(px, gy - 0.1, pz); g.add(t); }
    const cr = new THREE.Group(); A(cr, box(9, 7, 11, '#6a665e')).position.y = 3.5; A(cr, gable(9, 11, 3.4, '#3a3632')).position.y = 7; A(cr, box(2.6, 4, 0.4, '#1a1612')).position.set(0, 2, 5.6);
    [-1, 1].forEach(sd => A(cr, cyl(0.5, 0.6, 7.6, st, 10)).position.set(sd * 2.4, 3.8, 5.8)); cr.add(makeFire(-1.8, 4.6, 6.1, 0.4, '#7aff9a', false)); cr.add(makeFire(1.8, 4.6, 6.1, 0.4, '#7aff9a', false));
    place(ctx, g, cr, x, z - 16, 0, 7);
    [['d_column_broken', 1.1, -10, -6], ['d_column', 1.0, 10, -6], ['d_column_broken2', 1.1, -12, 6], ['d_bones', 1.0, 4, 4], ['d_bones2', 1.0, -5, 3], ['d_candelabrum_tall', 1.2, 2.5, -9], ['d_candelabrum_tall', 1.2, -2.5, -9], ['d_chest_gold', 1.3, 0, -11], ['d_bones', 1.0, -8, -2], ['d_column_broken', 1.0, 14, 10]]
      .forEach(([n, sc, dx, dz]) => place(ctx, g, glbB(n, sc, null), x + dx, z + dz, dx * 0.3, 0));
    for (let i = 0; i < 4; i++) { const tx = x + Math.cos(i * 1.6) * 20, tz = z + Math.sin(i * 1.6) * 20; place(ctx, g, glbB('q_willow_dead_' + (i % 2 ? 1 : 3), 3.2, null), tx, tz, i, 1.2); }
    g.add(makeFire(x, y0 + 0.3, z - 9, 0.7, '#7aff9a', true));
    g.userData.ambient = { fog: '#9ab89a', particles: '#aaffbb' };
  } else if (L.type === 'pantano') {
    // água parada escura, salgueiros, vitórias-régias, troncos com musgo e névoa
    const pools = [[0, 0, 15], [18, 8, 9], [-16, -10, 10], [6, -20, 7], [-8, 18, 8]];
    pools.forEach(([dx, dz, r]) => { const w = mesh(new THREE.CircleGeometry(r, 28), M('#1e2a16', { rough: 0.55, metal: 0, op: 0.92 })); w.rotation.x = -Math.PI / 2; w.position.set(x + dx, ctx.H(x + dx, z + dz) + 0.08, z + dz); w.receiveShadow = true; g.add(w);
      for (let k = 0; k < Math.round(r / 2); k++) { const a = k * 2.4 + dx, rr = r * (0.3 + (k % 3) * 0.2); place(ctx, g, glbB('q_lilypad', 2.2, null), x + dx + Math.cos(a) * rr, z + dz + Math.sin(a) * rr, a, 0).position.y += 0.22; } });
    for (let i = 0; i < 12; i++) { const a = i * 0.52 + 0.2, r = 24 + (i % 3) * 5, tx = x + Math.cos(a) * r, tz = z + Math.sin(a) * r; place(ctx, g, glbB(['q_willow_1', 'q_willow_dead_1', 'q_willow_3', 'q_willow_dead_3'][i % 4], 3.4 + (i % 3) * 0.4, null), tx, tz, a * 2, 1.3); }
    [['q_woodlog_moss', 3, 9, 12], ['q_treestump_moss', 3, -12, 14], ['q_woodlog_moss', 3, 22, -6], ['q_rock_moss_2', 3, -20, 0], ['q_rock_moss_5', 3, 12, 16], ['q_treestump_moss', 3, 2, 26]].forEach(([n, sc, dx, dz]) => place(ctx, g, glbB(n, sc, null), x + dx, z + dz, dx, 0.8));
    g.userData.ambient = { fog: '#6a7a5a', particles: '#c8ff7a' };
  } else if (L.type === 'destrocos') {
    // comboio destruído: carroças tombadas, caixotes e barris espalhados, muros caídos e fumaça
    const props = [['b_cart', 3.2], ['b_crate', 3.6], ['b_barrel', 3.6], ['b_bags', 3.6], ['b_crate', 3.6], ['d_barrel', 1.2], ['b_hay', 3.6], ['b_cart', 3.2]];
    for (let i = 0; i < 26; i++) { const a = i * 1.97, r = 4 + (i * 7 % 22), [n, sc] = props[i % props.length]; const o = place(ctx, g, glbB(n, sc, null), x + Math.cos(a) * r, z + Math.sin(a) * r, a * 1.7, 0); o.rotation.z = (i % 4 === 0) ? 1.3 : (i % 5 - 2) * 0.12; }
    for (let i = 0; i < 5; i++) { const w = box(6 + (i % 2) * 3, 1.5 + (i % 3), 1.2, '#7a6a5a'); w.position.set(x + Math.cos(i * 1.3) * 18, y0 + 0.6, z + Math.sin(i * 1.3) * 18); w.rotation.set(0.15, i * 1.3, (i % 2) * 0.3); g.add(w); }
    for (let i = 0; i < 3; i++) { const sx = x + Math.cos(i * 2.1) * 8, sz = z + Math.sin(i * 2.1) * 8; g.add(makeFire(sx, ctx.H(sx, sz) + 0.3, sz, 0.9, '#ffffff', true)); g.add(makeSmoke(sx, ctx.H(sx, sz) + 2, sz, 1.2)); }
    g.userData.ambient = { fog: '#8a7a6a', particles: '#ffaa5a' };
  } else if (L.type === 'estranho') {
    // anomalia: monólito negro com runas, pedras flutuando em órbita e cristais pulsando
    const mono = new THREE.Group(); A(mono, box(3, 16, 1.6, '#16121e', { rough: 0.2, metal: 0.6 })).position.y = 8;
    for (let i = 0; i < 6; i++) A(mono, box(2.2, 0.18, 1.66, '#b07aff', { em: 0x9a5aff, ei: 2 })).position.y = 2 + i * 2.4;
    place(ctx, g, mono, x, z, 0.4, 2.5);
    for (let i = 0; i < 9; i++) { const a = i / 9 * Math.PI * 2, r = 16, px = x + Math.cos(a) * r, pz = z + Math.sin(a) * r, h = 5 + (i % 3) * 1.5; const st = box(1.8, h, 1.2, '#2a2632', { rough: 0.5 }); st.position.set(px, ctx.H(px, pz) + h / 2 - 0.3, pz); st.rotation.set((i % 3 - 1) * 0.1, -a, 0); g.add(st);
      const rn = box(0.9, 0.9, 0.05, '#c89aff', { em: 0x9a5aff, ei: 1.6 }); rn.position.set(px - Math.cos(a) * 0.62, ctx.H(px, pz) + h * 0.6, pz - Math.sin(a) * 0.62); rn.rotation.y = -a + Math.PI / 2; g.add(rn); }
    for (let i = 0; i < 7; i++) { const rk = mesh(ROCK_GEOS[i % 3], M('#3a3444', { rough: 0.7 })); rk.scale.setScalar(1.2 + (i % 3) * 0.7); const isl = new THREE.Group(); isl.add(rk); isl.add(crystal('#c89aff', 0.5));
      isl.position.set(x + Math.cos(i * 0.9) * (7 + i), y0 + 7 + (i % 4) * 2.5, z + Math.sin(i * 0.9) * (7 + i)); g.add(isl); ANIM.push({ kind: 'bob', o: isl, y: isl.position.y, s: 0.6 + i * 0.13 }); }
    for (let i = 0; i < 6; i++) place(ctx, g, crystal(i % 2 ? '#7a3aff' : '#3ad8ff', 1.1 + (i % 3) * 0.4), x + Math.cos(i * 1.05 + 0.5) * 24, z + Math.sin(i * 1.05 + 0.5) * 24, i);
    g.add(makeFire(x, y0 + 17, z, 1.2, '#b07aff', true));
    g.userData.ambient = { fog: '#4a3a6a', particles: '#c89aff' };
  } else {
    // covil: arco de rochas, ossos e ambiente próprio
    for (let i = 0; i < 16; i++) { const a = i / 16 * Math.PI * 2, r = 22 + (i % 3) * 3, rk = mesh(ROCK_GEOS[i % 3], rockMat); const s = 3 + (i % 4); rk.scale.set(s, s * 1.4, s); rk.position.set(x + Math.cos(a) * r, y0 + s * 0.6, z + Math.sin(a) * r); g.add(rk); }
    for (let i = 0; i < 10; i++) { const b = cyl(0.25, 0.3, 2.4, '#efe8d8', 6); b.position.set(x + Math.sin(i * 2.3) * 9, y0 + 0.3, z + Math.cos(i * 1.7) * 9); b.rotation.set(1.3, i, 0.4); g.add(b); A(g, sph(0.5, '#efe8d8')).position.set(x + Math.cos(i * 2.1) * 7, y0 + 0.4, z + Math.sin(i * 1.9) * 7); }
    if (L.id === 'covil_hidra') { const sw = mesh(new THREE.CircleGeometry(16, 30), M('#3a5a2a', { rough: 0.2, op: 0.85 })); sw.rotation.x = -Math.PI / 2; sw.position.set(x, y0 + 0.12, z); g.add(sw); }
    if (L.id === 'trono_gelo') for (let i = 0; i < 12; i++) { const ic = cone(1.2, 6 + (i % 4) * 2, '#bfefff', 6, { op: 0.85, rough: 0.2 }); ic.position.set(x + Math.cos(i) * 14, y0 + 3, z + Math.sin(i) * 14); ic.rotation.z = (i % 3 - 1) * 0.2; g.add(ic); }
  }
  return g;
}

export function updateTownAnim(t) {
  for (const a of ANIM) {
    if (a.kind === 'spin') a.o.rotation.z = t * a.s;
    else if (a.kind === 'bob') a.o.position.y = a.y + Math.sin(t * a.s) * 0.8;
    else if (a.kind === 'flag') { const p = a.o.geometry.attributes.position; if (!a.base) a.base = p.array.slice(); for (let i = 0; i < p.count; i++) { const x = a.base[i * 3]; p.setZ(i, Math.sin(t * 4 + x * 3) * 0.15 * (x + 0.9)); } p.needsUpdate = true; }
  }
}
