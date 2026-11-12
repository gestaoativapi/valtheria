// ===== Valtheria — elementos da natureza: fogo, água, gelo, vento, raio, terra (+ luz, sombra, natureza) =====
// Impactos que marcam o chão por um tempo, meteoro que cai e explode, e a energia que sai do corpo do personagem.
import * as THREE from './lib/three.module.min.js';
import { emit, shock } from './fx.js';

export const ELEM = {
  fogo: { name: 'Fogo', icon: '🔥', c: 0xff6a1a, c2: 0xffd27a }, agua: { name: 'Água', icon: '💧', c: 0x3aa8ff, c2: 0xbfe8ff }, gelo: { name: 'Gelo', icon: '❄️', c: 0x8ad8ff, c2: 0xffffff },
  vento: { name: 'Vento', icon: '🌪️', c: 0xbfffe8, c2: 0xffffff }, raio: { name: 'Raio', icon: '⚡', c: 0xcfe0ff, c2: 0xfff7a0 }, terra: { name: 'Terra', icon: '🪨', c: 0xc8a060, c2: 0x7a5a3a },
  luz: { name: 'Luz', icon: '✨', c: 0xffe36a, c2: 0xffffff }, sombra: { name: 'Sombra', icon: '🌑', c: 0x8a2aff, c2: 0x3a0a5a }, natureza: { name: 'Natureza', icon: '🌿', c: 0x5aff7a, c2: 0xc8ff7a },
};
const FX2EL = { fire: 'fogo', ice: 'gelo', wind: 'vento', earth: 'terra', holy: 'luz', dark: 'sombra', spirit: 'sombra', blood: 'sombra', nature: 'natureza', poison: 'natureza', arcane: 'raio' };
export function elemOf(sk) { if (!sk) return null; const n = sk.name || '';
  if (/Raio|Trov|Relâmp|Tempest|Choque|Faísca/i.test(n)) return 'raio'; if (/Água|Maré|Onda|Tsunami|Correnteza|Jato/i.test(n)) return 'agua'; if (/Terra|Pedra|Rocha|Tremor|Sísm|Terremoto|Avalanche/i.test(n)) return 'terra';
  if (/Vento|Furac|Tornado|Vendaval|Ciclone/i.test(n)) return 'vento'; if (/Meteor|Chama|Fogo|Incêndio|Lava|Inferno|Brasa/i.test(n)) return 'fogo'; if (/Gelo|Geada|Nevasca|Glacial|Congel/i.test(n)) return 'gelo';
  return FX2EL[sk.fx] || null; }
export const isMeteor = sk => !!sk && /Meteor/i.test(sk.name || '');
// elemento dominante de uma classe (o que mais aparece nas suas habilidades)
export function classElem(skills, fallback) { const n = {}; for (const s of skills || []) { const e = elemOf(s); if (e) n[e] = (n[e] || 0) + (s.type === 'hit' || s.type === 'zone' || s.type === 'chain' ? 2 : 1); } const b = Object.entries(n).sort((a, b) => b[1] - a[1])[0]; return b && b[1] >= 3 ? b[0] : fallback; }

let X = null; const LIVE = [];
export function initElements(ctx) { X = ctx; } // { scene, H(x,z), shake, sfx }
const push = (obj, dur, up, end) => { X.scene.add(obj); LIVE.push({ obj, t: 0, dur, up, end }); return obj; };
export function updateElements(dt) { for (let i = LIVE.length - 1; i >= 0; i--) { const f = LIVE[i]; f.t += dt; const k = Math.min(1, f.t / f.dur); f.up && f.up(f.obj, k, dt, f.t); if (k >= 1) { X.scene.remove(f.obj); f.obj.traverse?.(o => { o.geometry && !o.userData.shared && o.geometry.dispose(); }); f.end && f.end(); LIVE.splice(i, 1); } } }

// ---------- marcas no chão ----------
function decalTex(kind) { const c = document.createElement('canvas'); c.width = c.height = 256; const g = c.getContext('2d'), gr = g.createRadialGradient(128, 128, 6, 128, 128, 126);
  const A = { scorch: ['rgba(10,6,4,0.95)', 'rgba(30,16,8,0.75)'], frost: ['rgba(220,245,255,0.9)', 'rgba(150,210,255,0.5)'], wet: ['rgba(20,50,90,0.55)', 'rgba(30,70,120,0.35)'], crack: ['rgba(30,22,14,0.85)', 'rgba(60,44,28,0.5)'] }[kind];
  gr.addColorStop(0, A[0]); gr.addColorStop(0.6, A[1]); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, 256, 256);
  if (kind !== 'wet') { g.strokeStyle = kind === 'frost' ? 'rgba(255,255,255,0.9)' : kind === 'scorch' ? 'rgba(255,120,30,0.9)' : 'rgba(10,8,6,0.95)'; g.lineWidth = kind === 'crack' ? 4 : 2.5;
    for (let i = 0; i < 11; i++) { let a = i / 11 * 6.283 + Math.random() * 0.3, r = 8, x = 128, y = 128; g.beginPath(); g.moveTo(x, y); while (r < 112) { r += 10 + Math.random() * 14; a += (Math.random() - 0.5) * 0.7; x = 128 + Math.cos(a) * r; y = 128 + Math.sin(a) * r; g.lineTo(x, y); if (Math.random() < 0.25) { g.lineTo(x + Math.cos(a + 1) * 14, y + Math.sin(a + 1) * 14); g.moveTo(x, y); } } g.stroke(); } }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t; }
const DT = {}; const dtex = k => DT[k] || (DT[k] = decalTex(k));
const dgeo = new THREE.CircleGeometry(1, 36); dgeo.rotateX(-Math.PI / 2);
// marca que acompanha o relevo de leve, some aos poucos e o chão "normaliza"
export function decal(kind, x, z, r, life = 8, glow = 0) {
  const m = new THREE.Mesh(dgeo, new THREE.MeshBasicMaterial({ map: dtex(kind), transparent: true, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4, toneMapped: !glow, blending: kind === 'frost' ? THREE.AdditiveBlending : THREE.NormalBlending }));
  m.userData.shared = true; m.position.set(x, X.H(x, z) + 0.07, z); m.scale.setScalar(r); m.rotation.y = Math.random() * 6; m.renderOrder = 2;
  const nx = X.H(x + 1, z) - X.H(x - 1, z), nz = X.H(x, z + 1) - X.H(x, z - 1); m.rotation.z = Math.atan2(nx, 2); m.rotation.x = -Math.atan2(nz, 2);
  return push(m, life, (o, k) => { o.material.opacity = k < 0.7 ? 1 : 1 - (k - 0.7) / 0.3; });
}
// fogo no chão que continua queimando
export function groundFire(x, z, r, dur = 5) { const o = new THREE.Object3D(); let acc = 0;
  push(o, dur, (_, k, dt) => { acc += dt; if (acc < 0.07) return; acc = 0; const n = k > 0.75 ? 1 : 3; for (let i = 0; i < n; i++) { const a = Math.random() * 6.283, rr = Math.sqrt(Math.random()) * r, px = x + Math.cos(a) * rr, pz = z + Math.sin(a) * rr;
    emit(px, X.H(px, pz) + 0.15, pz, { n: 2, color: Math.random() < 0.3 ? 0xffd27a : 0xff5a1a, speed: 0.5, up: 2.6, life: 0.7, size: 0.34 * (1 - k * 0.5), grav: -2.5, drag: 1.2 }); }
    if (Math.random() < 0.25) emit(x, X.H(x, z) + 1.2, z, { n: 1, color: 0x3a3430, speed: 0.4, up: 2.2, ring: r * 0.5, life: 1.6, size: 0.5, grav: -1, drag: 0.6, jit: 0.05 }); }); }
// pedras/estacas que saem do chão, ficam e depois afundam (terra e gelo)
function spikes(x, z, r, n, mat, h, life, sharp) { const g = new THREE.Group(); const list = [];
  for (let i = 0; i < n; i++) { const a = i / n * 6.283 + Math.random() * 0.5, rr = r * (0.35 + Math.random() * 0.65), px = x + Math.cos(a) * rr, pz = z + Math.sin(a) * rr, hh = h * (0.5 + Math.random() * 0.9);
    const s = new THREE.Mesh(sharp ? new THREE.ConeGeometry(hh * 0.22, hh, 5) : new THREE.DodecahedronGeometry(hh * 0.45, 0), mat); s.castShadow = true; s.rotation.set((Math.random() - 0.5) * 0.7, Math.random() * 6, (Math.random() - 0.5) * 0.7); s.userData = { by: X.H(px, pz), hh, d: Math.random() * 0.15 }; s.position.set(px, s.userData.by - hh, pz); g.add(s); list.push(s); }
  push(g, life, (_, k, dt, t) => { for (const s of list) { const up = Math.min(1, Math.max(0, (t - s.userData.d) / 0.18)), down = k > 0.8 ? (k - 0.8) / 0.2 : 0; const e = up * (2 - up) * (1 - down); s.position.y = sharp ? s.userData.by - s.userData.hh / 2 + s.userData.hh * 0.9 * e : s.userData.by - s.userData.hh * 0.45 + s.userData.hh * 0.6 * e; } }); }
const rockM = new THREE.MeshStandardMaterial({ color: '#6a5a48', roughness: 0.95, flatShading: true }), iceM = new THREE.MeshStandardMaterial({ color: '#cfefff', roughness: 0.15, metalness: 0.1, transparent: true, opacity: 0.85, emissive: 0x3a8acc, emissiveIntensity: 0.5, flatShading: true });
function bolt(x, y, z, h = 16) { const pts = []; let px = x + (Math.random() - 0.5) * 3, pz = z + (Math.random() - 0.5) * 3; for (let i = 0; i <= 9; i++) { const k = i / 9; pts.push(new THREE.Vector3(px + (x - px) * k + (Math.random() - 0.5) * (1 - k) * 1.6, y + h * (1 - k), pz + (z - pz) * k + (Math.random() - 0.5) * (1 - k) * 1.6)); }
  const geo = new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts, false, 'catmullrom', 0), 18, 0.07, 4); push(new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: 0xeaf4ff, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false })), 0.28, (o, k) => { o.material.opacity = k < 0.3 ? 1 : (1 - k) * (Math.random() < 0.3 ? 0.3 : 1.2); }); }

// ---------- impacto por elemento ----------
export function elemImpact(el, x, z, r = 3, power = 1) {
  if (!X || !ELEM[el]) return; const y = X.H(x, z), E = ELEM[el], P = Math.min(2, power);
  if (el === 'fogo') { emit(x, y + 0.6, z, { n: 50 * P, color: E.c, speed: 7, up: 4, life: 0.8, size: 0.36 }); emit(x, y + 0.4, z, { n: 20, color: E.c2, speed: 3, up: 6, life: 0.5, size: 0.3 }); shock(x, y, z, E.c, r * 1.3, 0.5); decal('scorch', x, z, r * 0.9, 9, 1); groundFire(x, z, r * 0.7, 3.5 + P * 1.5); X.sfx('fire', 0.7); }
  else if (el === 'gelo') { spikes(x, z, r * 0.8, 7 + Math.round(4 * P), iceM, 1.5 + P * 0.6, 4.5, true); decal('frost', x, z, r, 7); emit(x, y + 0.5, z, { n: 40, color: E.c2, speed: 4, up: 2, life: 1.2, size: 0.2, grav: 2, drag: 2 }); emit(x, y + 1.5, z, { n: 14, color: E.c, speed: 1, up: 0.2, ring: r * 0.6, life: 2.2, size: 0.34, grav: 0.4, drag: 2 }); shock(x, y, z, E.c, r * 1.2, 0.6); X.sfx('ice', 0.7); }
  else if (el === 'agua') { emit(x, y + 0.2, z, { n: 60 * P, color: E.c, speed: 5, up: 8, life: 0.9, size: 0.2, grav: 18, spread: 0.5 }); emit(x, y + 0.2, z, { n: 30, color: E.c2, speed: 6, up: 1.5, ring: r * 0.3, life: 0.6, size: 0.16, grav: 9 }); shock(x, y, z, E.c, r * 1.3, 0.7); shock(x, y + 0.03, z, E.c2, r * 0.8, 1.0); decal('wet', x, z, r * 1.1, 7); X.sfx('magic', 0.5); }
  else if (el === 'vento') { const o = new THREE.Object3D(); push(o, 1.6, (_, k, dt, t) => { for (let i = 0; i < 5; i++) { const hgt = Math.random() * 5, a = t * 9 + i * 1.26 + hgt, rr = (0.4 + hgt * 0.32) * (r / 3); emit(x + Math.cos(a) * rr, y + hgt, z + Math.sin(a) * rr, { n: 1, color: Math.random() < 0.2 ? 0x9ac87a : E.c, speed: 0.3, up: 1.5, dir: [-Math.sin(a) * 5, 0, Math.cos(a) * 5], life: 0.45, size: 0.2, grav: 0, drag: 1 }); } }); shock(x, y, z, E.c, r * 1.4, 0.5); X.sfx('swing', 0.8); }
  else if (el === 'raio') { const n = 1 + Math.round(P * 1.5); for (let i = 0; i < n; i++) setTimeout(() => { const bx = x + (i ? (Math.random() - 0.5) * r : 0), bz = z + (i ? (Math.random() - 0.5) * r : 0), by = X.H(bx, bz); bolt(bx, by, bz); emit(bx, by + 0.3, bz, { n: 26, color: E.c2, speed: 8, up: 3, life: 0.3, size: 0.16, drag: 3 }); if (!i) { decal('scorch', bx, bz, r * 0.4, 5, 1); X.sfx('thunder', 0.5); } }, i * 110); shock(x, y, z, E.c, r, 0.35); }
  else if (el === 'terra') { spikes(x, z, r * 0.85, 6 + Math.round(4 * P), rockM, 1.2 + P * 0.5, 5, false); decal('crack', x, z, r * 1.1, 9); emit(x, y + 0.3, z, { n: 44, color: 0x8a7a6a, speed: 5, up: 5, life: 1.0, size: 0.26, grav: 14, jit: 0.4 }); emit(x, y + 0.4, z, { n: 16, color: 0xb8a890, speed: 2, up: 1, ring: r * 0.6, life: 1.6, size: 0.6, grav: -0.3, drag: 1.5, jit: 0.1 }); shock(x, y, z, E.c, r * 1.2, 0.5); X.shake(0.3 * P); X.sfx('boom', 0.6); }
  else { emit(x, y + 0.6, z, { n: 30 * P, color: E.c, speed: 4, up: el === 'luz' ? 5 : 2, life: 0.8, size: 0.22, grav: el === 'sombra' ? 3 : -1 }); shock(x, y, z, E.c, r * 1.2, 0.5); if (el === 'natureza') emit(x, y + 0.2, z, { n: 16, color: E.c2, speed: 1, up: 2.5, ring: r * 0.6, life: 1.5, size: 0.18, grav: -0.5 }); }
}
// ---------- meteoro: cai do céu, explode, racha o chão, deixa fogo e depois o terreno normaliza ----------
const metGeo = new THREE.IcosahedronGeometry(1, 1), metMat = new THREE.MeshStandardMaterial({ color: '#2a1810', emissive: 0xff5a10, emissiveIntensity: 2.4, roughness: 0.8, flatShading: true });
export function meteor(x, z, r = 5, onHit, size = 1) {
  const y = X.H(x, z), from = new THREE.Vector3(x - 16, y + 38, z - 9), to = new THREE.Vector3(x, y, z), m = new THREE.Mesh(metGeo, metMat); m.userData.shared = true; m.scale.setScalar(0.9 * size); m.position.copy(from);
  const warn = new THREE.Mesh(new THREE.RingGeometry(0.92, 1, 48), new THREE.MeshBasicMaterial({ color: 0xff5a1a, transparent: true, opacity: 0.7, side: THREE.DoubleSide, depthWrite: false, toneMapped: false })); warn.rotation.x = -Math.PI / 2; warn.position.set(x, y + 0.12, z); warn.scale.setScalar(r);
  push(warn, 0.62, (o, k) => { o.material.opacity = 0.4 + 0.4 * Math.sin(k * 30); o.scale.setScalar(r * (1.15 - 0.15 * k)); });
  push(m, 0.6, (o, k) => { const e = k * k; o.position.lerpVectors(from, to, e); o.rotation.x += 0.3; o.rotation.z += 0.2;
    emit(o.position.x, o.position.y, o.position.z, { n: 5, color: 0xff6a1a, speed: 1.2, up: 1, life: 0.6, size: 0.55 * size, grav: -1, drag: 1 }); emit(o.position.x, o.position.y + 0.5, o.position.z, { n: 2, color: 0x4a4038, speed: 0.6, up: 1.5, life: 1.3, size: 0.7 * size, grav: -1, drag: 0.6, jit: 0.05 }); },
  () => { // impacto
    emit(x, y + 0.8, z, { n: 90, color: 0xff6a1a, speed: 11, up: 6, life: 0.9, size: 0.42 }); emit(x, y + 0.5, z, { n: 40, color: 0xffe0a0, speed: 5, up: 9, life: 0.6, size: 0.36 }); emit(x, y + 0.3, z, { n: 50, color: 0x6a5a4a, speed: 9, up: 7, life: 1.3, size: 0.26, grav: 16, jit: 0.4 });
    emit(x, y + 1, z, { n: 26, color: 0x3a3430, speed: 2, up: 3.5, ring: r * 0.3, life: 2.4, size: 0.9, grav: -1.2, drag: 0.7, jit: 0.05 });
    shock(x, y, z, 0xff7a2a, r * 1.8, 0.6); shock(x, y + 0.05, z, 0xffffff, r * 1.1, 0.3); decal('scorch', x, z, r * 1.15, 12, 1); decal('crack', x, z, r * 1.4, 12);
    // borda da cratera: pedras levantadas em volta, que afundam depois
    const g = new THREE.Group(), rim = []; for (let i = 0; i < 14; i++) { const a = i / 14 * 6.283 + Math.random() * 0.3, rr = r * (0.75 + Math.random() * 0.25), px = x + Math.cos(a) * rr, pz = z + Math.sin(a) * rr, s = 0.5 + Math.random() * 0.8, k = new THREE.Mesh(metGeo, rockM); k.userData.shared = true; k.scale.set(s, s * 0.7, s); k.rotation.set(Math.random(), Math.random() * 6, Math.random()); k.userData.by = X.H(px, pz); k.userData.s = s; k.position.set(px, k.userData.by - s, pz); k.castShadow = true; g.add(k); rim.push(k); }
    const core = new THREE.Mesh(metGeo, metMat.clone()); core.userData.shared = true; core.scale.setScalar(0.7 * size); core.position.set(x, y + 0.1, z); g.add(core);
    push(g, 9, (_, k) => { for (const q of rim) q.position.y = q.userData.by - q.userData.s + q.userData.s * 1.1 * Math.min(1, k * 40) * (k > 0.8 ? 1 - (k - 0.8) / 0.2 : 1); core.material.emissiveIntensity = 2.4 * Math.max(0, 1 - k * 1.6); core.position.y = y + 0.1 - (k > 0.7 ? (k - 0.7) * 3 : 0); });
    groundFire(x, z, r * 0.9, 6); X.shake(0.9); X.sfx('boom', 1); X.sfx('fire', 0.8); onHit && onHit(); });
}
// ---------- energia saindo do corpo: rajada ao conjurar e aura contínua em combate ----------
export function castBurst(el, x, z, h = 1.8) { if (!X || !ELEM[el]) return; const y = X.H(x, z), E = ELEM[el];
  emit(x, y + 0.2, z, { n: 26, color: E.c, speed: 0.6, up: 5.5, ring: 0.55, life: 0.8, size: 0.24, grav: -2, drag: 1 }); emit(x, y + h * 0.6, z, { n: 14, color: E.c2, speed: 3.2, up: 0.6, life: 0.45, size: 0.18, drag: 3 }); shock(x, y, z, E.c, 2.2, 0.45);
  if (el === 'raio') for (let i = 0; i < 2; i++) { const a = Math.random() * 6.283; bolt(x + Math.cos(a) * 0.8, y, z + Math.sin(a) * 0.8, 3.2); }
  if (el === 'terra') emit(x, y + 0.1, z, { n: 12, color: 0x7a6a58, speed: 2.5, up: 3.5, ring: 0.8, life: 0.7, size: 0.22, grav: 14 }); }
let auraT = 0;
export function bodyAura(el, x, z, h, dt, k = 1) { if (!X || !ELEM[el] || k <= 0) return; auraT += dt; if (auraT < 0.09 / k) return; auraT = 0; const y = X.H(x, z), E = ELEM[el], a = Math.random() * 6.283, r = 0.35 + Math.random() * 0.3, px = x + Math.cos(a) * r, pz = z + Math.sin(a) * r;
  if (el === 'fogo') emit(px, y + Math.random() * h * 0.7, pz, { n: 1, color: Math.random() < 0.3 ? E.c2 : E.c, speed: 0.2, up: 2.2, life: 0.7, size: 0.2, grav: -2, drag: 1 }); // calor: brasas subindo
  else if (el === 'gelo') emit(px, y + h * (0.4 + Math.random() * 0.6), pz, { n: 1, color: E.c2, speed: 0.15, up: -0.5, life: 1.3, size: 0.16, grav: 0.8, drag: 2 }); // frio: névoa caindo
  else if (el === 'agua') emit(px, y + h * 0.9, pz, { n: 1, color: E.c, speed: 0.4, up: 0.8, life: 0.8, size: 0.14, grav: 8 });
  else if (el === 'vento') { const t = performance.now() / 160; emit(x + Math.cos(t) * 0.7, y + (t % 6) / 6 * h, z + Math.sin(t) * 0.7, { n: 1, color: E.c, speed: 0.1, up: 0.6, dir: [-Math.sin(t) * 2.5, 0, Math.cos(t) * 2.5], life: 0.5, size: 0.15, grav: 0 }); }
  else if (el === 'raio') { emit(px, y + Math.random() * h, pz, { n: 2, color: E.c2, speed: 2.5, up: 0.5, life: 0.16, size: 0.13, drag: 4 }); if (Math.random() < 0.06 * k) bolt(px, y + 0.2, pz, 1.6 + Math.random()); }
  else if (el === 'terra') emit(px, y + 0.1, pz, { n: 1, color: 0x9a8468, speed: 0.3, up: 1.6, life: 0.9, size: 0.15, grav: 3.5 });
  else emit(px, y + Math.random() * h * 0.8, pz, { n: 1, color: E.c, speed: 0.2, up: el === 'sombra' ? 0.6 : 1.6, life: 1, size: 0.17, grav: el === 'sombra' ? 0.5 : -1, drag: 1.5 }); }
