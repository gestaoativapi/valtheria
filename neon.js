// ===== Valtheria — Era Neon: distrito futurista que atravessou uma fenda no tempo =====
// Modelos: Quaternius Ultimate Space Kit, Cyberpunk Game Kit e Ultimate Spaceships (CC0). Prédios altos, letreiros e chão são procedurais.
import * as THREE from './lib/three.module.min.js';
import { GLTFLoader } from './lib/GLTFLoader.js';
import { MeshoptDecoder } from './lib/meshopt_decoder.module.js';

const gl = new GLTFLoader(); gl.setMeshoptDecoder(MeshoptDecoder); const CACHE = new Map();
const load = n => { if (!CACHE.has(n)) CACHE.set(n, gl.loadAsync('assets/world/' + n + '.glb').then(g => { const b = new THREE.Box3().setFromObject(g.scene); g.scene.userData.size = b.getSize(new THREE.Vector3()); g.scene.userData.minY = b.min.y; return g.scene; })); return CACHE.get(n); };
const ANIM = []; // { kind, o, ... }
export const NEON_COL = ['#3af0ff', '#ff3ad8', '#ffe03a', '#7aff5a', '#a05aff', '#ff6a3a'];
const rnd = (s => () => (s = (s * 16807) % 2147483647) / 2147483647)(20991);

// modelo GLB ajustado a uma altura (ou largura) alvo, com emissivo nas partes de luz
function glbFit(name, size, { by = 'h', rot = 0, glow = null, metal = true } = {}) {
  const g = new THREE.Group();
  load(name).then(src => { const o = src.clone(true), s = src.userData.size, k = size / (by === 'h' ? s.y : Math.max(s.x, s.z)); o.scale.setScalar(k); o.position.y = -src.userData.minY * k; o.rotation.y = rot;
    o.traverse(m => { if (!m.isMesh) return; m.castShadow = m.receiveShadow = true; if (!m.geometry.attributes.normal) m.geometry.computeVertexNormals(); const sm = m.material; m.material = sm.isMeshBasicMaterial ? new THREE.MeshStandardMaterial({ name: sm.name, map: sm.map, color: sm.color }) : sm.clone(); if (metal) { m.material.metalness = Math.max(m.material.metalness, 0.35); m.material.roughness = Math.min(m.material.roughness, 0.55); }
      if (/light|eye|glow|emis/i.test(m.material.name)) { m.material.emissive = new THREE.Color(glow || '#bff8ff'); m.material.emissiveIntensity = 2.2; }
      else if (glow) { m.material.emissive = new THREE.Color(glow); m.material.emissiveIntensity = 0.12; } });
    g.add(o); }).catch(() => {});
  return g;
}
const mats = new Map();
const M = (c, o = {}) => { const k = c + JSON.stringify(o); if (!mats.has(k)) mats.set(k, new THREE.MeshStandardMaterial({ color: c, roughness: o.rough ?? 0.4, metalness: o.metal ?? 0.6, emissive: o.em ? new THREE.Color(o.em) : 0, emissiveIntensity: o.ei ?? 1, transparent: !!o.op, opacity: o.op ?? 1, side: o.ds ? THREE.DoubleSide : THREE.FrontSide, depthWrite: o.op ? false : true, blending: o.add ? THREE.AdditiveBlending : THREE.NormalBlending, map: o.map || null, emissiveMap: o.emap || null })); return mats.get(k); };
const glow = c => new THREE.MeshBasicMaterial({ color: c, toneMapped: false });
const add = c => new THREE.MeshBasicMaterial({ color: c, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, toneMapped: false });
const box = (w, h, d, m) => { const o = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m); o.castShadow = o.receiveShadow = true; return o; };

// ---------- texturas procedurais ----------
function gridTex() { const c = document.createElement('canvas'); c.width = c.height = 256; const g = c.getContext('2d');
  g.fillStyle = '#0b0d16'; g.fillRect(0, 0, 256, 256); for (let i = 0; i < 900; i++) { g.fillStyle = `rgba(${40 + Math.random() * 30},${40 + Math.random() * 30},${60 + Math.random() * 40},0.35)`; g.fillRect(Math.random() * 256, Math.random() * 256, 2, 2); }
  g.strokeStyle = '#1af0ff'; g.lineWidth = 3; g.strokeRect(1.5, 1.5, 253, 253); g.strokeStyle = 'rgba(26,240,255,0.25)'; g.lineWidth = 1; g.beginPath(); g.moveTo(128, 0); g.lineTo(128, 256); g.moveTo(0, 128); g.lineTo(256, 128); g.stroke();
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; return t; }
function windowTex(seed, hue) { const c = document.createElement('canvas'); c.width = 128; c.height = 256; const g = c.getContext('2d'), r = (s => () => (s = (s * 16807) % 2147483647) / 2147483647)(seed + 7);
  g.fillStyle = '#06070c'; g.fillRect(0, 0, 128, 256);
  for (let y = 4; y < 256; y += 9) for (let x = 4; x < 128; x += 8) { const v = r(); if (v < 0.42) continue; g.fillStyle = v > 0.93 ? NEON_COL[(seed + x) % NEON_COL.length] : v > 0.7 ? hue : `rgba(255,236,190,${0.25 + r() * 0.5})`; g.fillRect(x, y, 5, 5); }
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; return t; }
function signTex(text, col, sub) { const c = document.createElement('canvas'); c.width = 512; c.height = 160; const g = c.getContext('2d');
  g.fillStyle = 'rgba(4,2,12,0.55)'; g.fillRect(0, 0, 512, 160); g.strokeStyle = col; g.lineWidth = 6; g.shadowColor = col; g.shadowBlur = 24; g.strokeRect(8, 8, 496, 144);
  g.font = 'bold 74px system-ui,Segoe UI,sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillStyle = '#ffffff'; g.fillText(text, 256, sub ? 66 : 82); g.shadowBlur = 40; g.fillStyle = col; g.fillText(text, 256, sub ? 66 : 82);
  if (sub) { g.shadowBlur = 10; g.font = '600 30px system-ui,Segoe UI,sans-serif'; g.fillStyle = '#e8f8ff'; g.fillText(sub, 256, 124); }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t; }
function swirlTex(col) { const c = document.createElement('canvas'); c.width = c.height = 256; const g = c.getContext('2d'), gr = g.createRadialGradient(128, 128, 8, 128, 128, 128);
  gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.25, col); gr.addColorStop(0.75, 'rgba(20,0,60,0.6)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, 256, 256);
  g.globalCompositeOperation = 'lighter'; g.strokeStyle = 'rgba(255,255,255,0.35)'; g.lineWidth = 5; for (let i = 0; i < 6; i++) { g.beginPath(); for (let a = 0; a < 5; a += 0.05) { const r = 10 + a * 22; g.lineTo(128 + Math.cos(a + i * 1.047) * r, 128 + Math.sin(a + i * 1.047) * r); } g.stroke(); }
  return new THREE.CanvasTexture(c); }

const SIGNS = [['NEO-AURORA', '#3af0ff', 'distrito Ω'], ['FORJA QUÂNTICA', '#ffb03a', 'lâminas de plasma'], ['ARCANO 2099', '#a05aff', 'magia + código'], ['ÉTER GELADO', '#7aff5a', 'refresca a alma'], ['VALTHERIA ∞', '#ff3ad8', ''], ['ZONA Ω', '#ff4a3a', 'acesso restrito'], ['HOTEL ÓRBITA', '#ffe03a', 'vagas'], ['DRONES & CIA', '#3af0ff', 'conserto rápido']];

// ---------- portal dimensional (Vila Aurora ⇄ Era Neon) ----------
export function buildPortal(col = '#3af0ff', label = 'Portal Dimensional') {
  const g = new THREE.Group();
  const base = box(7, 0.5, 3, M('#1a1e2a', { metal: 0.8, rough: 0.3 })); base.position.y = 0.25; g.add(base);
  [-1, 1].forEach(s => { const p = box(0.7, 6.4, 0.9, M('#20263a', { metal: 0.85, rough: 0.25 })); p.position.set(s * 2.9, 3.4, 0); g.add(p); const st = new THREE.Mesh(new THREE.BoxGeometry(0.12, 5.8, 0.95), glow(col)); st.position.set(s * 2.55, 3.4, 0); g.add(st); });
  const ring = new THREE.Mesh(new THREE.TorusGeometry(2.4, 0.16, 10, 48), glow(col)); ring.position.y = 3.5; g.add(ring);
  const disk = new THREE.Mesh(new THREE.CircleGeometry(2.3, 40), new THREE.MeshBasicMaterial({ map: swirlTex(col), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, toneMapped: false })); disk.position.y = 3.5; g.add(disk);
  const halo = new THREE.Mesh(new THREE.CircleGeometry(3.4, 40), add(col)); halo.material.opacity = 0.18; halo.position.y = 3.5; g.add(halo);
  ANIM.push({ kind: 'portal', disk, ring, halo }); g.userData.portal = true; g.userData.label = label; return g;
}

// ---------- prédio alto procedural com janelas, faixas de neon e antena ----------
function tower(x, z, y0, w, d, h, seed) {
  const g = new THREE.Group(), hue = NEON_COL[seed % NEON_COL.length], tex = windowTex(seed, hue); tex.repeat.set(Math.max(1, Math.round(w / 6)), Math.max(1, Math.round(h / 18)));
  const glass = new THREE.MeshStandardMaterial({ color: '#141a28', roughness: 0.22, metalness: 0.85, emissive: '#ffffff', emissiveMap: tex, emissiveIntensity: 1.15, map: tex });
  const b = box(w, h, d, glass); b.position.y = h / 2; g.add(b);
  const capM = M('#1c2232', { metal: 0.9, rough: 0.3 }); const cap = box(w + 0.6, 0.8, d + 0.6, capM); cap.position.y = h + 0.4; g.add(cap);
  for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) { const e = new THREE.Mesh(new THREE.BoxGeometry(0.22, h, 0.22), glow(hue)); e.position.set(sx * (w / 2 + 0.02), h / 2, sz * (d / 2 + 0.02)); g.add(e); }
  for (let k = 1; k <= 3; k++) { const band = new THREE.Mesh(new THREE.BoxGeometry(w + 0.1, 0.18, d + 0.1), glow(k % 2 ? hue : '#ffffff')); band.position.y = h * k / 4; g.add(band); }
  if (seed % 3 !== 0) { const set = 1 + (seed % 2), w2 = w * 0.6, h2 = h * 0.25, b2 = box(w2, h2, d * 0.6, glass); b2.position.y = h + h2 / 2 + 0.8; g.add(b2); for (const s of [-1, 1]) { const e = new THREE.Mesh(new THREE.BoxGeometry(0.18, h2, 0.18), glow(hue)); e.position.set(s * w2 / 2, h + h2 / 2 + 0.8, d * 0.3); g.add(e); } }
  const top = h + (seed % 3 !== 0 ? h * 0.25 + 0.8 : 0.8), ant = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.16, 7, 6), capM); ant.position.y = top + 3.5; g.add(ant);
  const blink = new THREE.Mesh(new THREE.SphereGeometry(0.35, 8, 6), glow('#ff2a2a')); blink.position.y = top + 7.1; g.add(blink); ANIM.push({ kind: 'blink', o: blink, ph: seed });
  if (seed % 2 === 0) { const [txt, col, sub] = SIGNS[seed % SIGNS.length], sp = new THREE.Mesh(new THREE.PlaneGeometry(w * 0.95, w * 0.3), new THREE.MeshBasicMaterial({ map: signTex(txt, col, sub), transparent: true, toneMapped: false, side: THREE.DoubleSide }));
    sp.position.set(0, h * (0.55 + (seed % 3) * 0.1), d / 2 + 0.25); g.add(sp); ANIM.push({ kind: 'flicker', o: sp, ph: seed * 1.7 }); }
  g.position.set(x, y0 - 0.3, z); g.rotation.y = Math.round(Math.atan2(x, z) / (Math.PI / 2)) * Math.PI / 2; return g;
}

// ---------- distrito completo ----------
export function buildNeon(ctx, L, N) {
  const g = new THREE.Group(), x0 = L.x, z0 = L.z, y0 = ctx.H(x0, z0);
  // chão: asfalto escuro com grade de luz
  const gt = gridTex(); gt.repeat.set(26, 26);
  const floor = new THREE.Mesh(new THREE.CircleGeometry(N.r - 2, 72), new THREE.MeshStandardMaterial({ map: gt, emissiveMap: gt, emissive: '#ffffff', emissiveIntensity: 0.4, roughness: 0.3, metalness: 0.55 }));
  floor.rotation.x = -Math.PI / 2; floor.position.set(x0, y0 + 0.06, z0); floor.receiveShadow = true; g.add(floor);
  const rim = new THREE.Mesh(new THREE.RingGeometry(N.r - 2.6, N.r - 1.6, 96), glow('#ff3ad8')); rim.rotation.x = -Math.PI / 2; rim.position.set(x0, y0 + 0.09, z0); g.add(rim);
  // avenidas em cruz com faixas de luz
  for (const [ax, az] of [[1, 0], [0, 1]]) { const len = (N.r - 4) * 2, road = new THREE.Mesh(new THREE.PlaneGeometry(ax ? len : 14, az ? len : 14), M('#07080d', { metal: 0.3, rough: 0.5 }));
    road.rotation.x = -Math.PI / 2; road.position.set(x0, y0 + 0.08, z0); road.receiveShadow = true; g.add(road);
    for (const s of [-1, 1]) { const ln = new THREE.Mesh(new THREE.PlaneGeometry(ax ? len : 0.35, az ? len : 0.35), glow(s > 0 ? '#3af0ff' : '#ff3ad8')); ln.rotation.x = -Math.PI / 2; ln.position.set(x0 + (az ? s * 6.6 : 0), y0 + 0.1, z0 + (ax ? s * 6.6 : 0)); g.add(ln); }
    for (let k = -N.r + 10; k < N.r - 10; k += 9) { const dash = new THREE.Mesh(new THREE.PlaneGeometry(ax ? 3.2 : 0.25, az ? 3.2 : 0.25), glow('#ffe03a')); dash.rotation.x = -Math.PI / 2; dash.position.set(x0 + (ax ? k : 0), y0 + 0.1, z0 + (az ? k : 0)); g.add(dash); } }
  // arranha-céus em anel (deixando avenidas, praça central e posto seguro livres)
  let seed = 3;
  for (let ring = 0; ring < 3; ring++) { const R = 46 + ring * 26, n = 10 + ring * 4;
    for (let i = 0; i < n; i++) { const a = i / n * Math.PI * 2 + ring * 0.21, x = x0 + Math.cos(a) * R, z = z0 + Math.sin(a) * R;
      if (Math.abs(x - x0) < 15 || Math.abs(z - z0) < 15) continue; if (Math.hypot(x - N.hub.x, z - N.hub.z) < N.hub.r + 14) continue;
      seed++; const w = 9 + (seed * 7 % 6), d = 9 + (seed * 5 % 5), h = 24 + ring * 14 + (seed * 13 % 22);
      if ((i + ring) % 4 === 1 && ring < 2) { // casas e cúpulas do kit espacial no lugar de alguns prédios
        const nm = ['n_house_cylinder', 'n_geodesicdome', 'n_building_l', 'n_base_large', 'n_house_long'][seed % 5]; const o = glbFit(nm, 15, { by: 'w', rot: -a, glow: NEON_COL[seed % 6] }); o.position.set(x, y0 - 0.1, z); g.add(o);
        const rf = glbFit(['n_roof_radar', 'n_roof_antenna'][seed % 2], 5, { glow: '#3af0ff' }); rf.position.set(x + 2, y0 + 9.5, z); g.add(rf); ctx.collide(x, z, 7.5); continue; }
      g.add(tower(x, z, y0, w, d, h, seed)); ctx.collide(x, z, Math.max(w, d) * 0.62); } }
  // postes de luz ao longo das avenidas
  for (let k = -N.r + 16; k < N.r - 12; k += 18) { if (Math.abs(k) < 26) continue;
    for (const s of [-1, 1]) { [[x0 + k, z0 + s * 9.5, s > 0 ? Math.PI : 0], [x0 + s * 9.5, z0 + k, s > 0 ? -Math.PI / 2 : Math.PI / 2]].forEach(([px, pz, r]) => { if (Math.hypot(px - N.hub.x, pz - N.hub.z) < N.hub.r) return; const lp = glbFit('n_light_street_1', 6.5, { rot: r, glow: '#bff8ff' }); lp.position.set(px, y0, pz); g.add(lp); ctx.collide(px, pz, 0.45);
      const halo = new THREE.Mesh(new THREE.CircleGeometry(3.2, 20), add('#3af0ff')); halo.material.opacity = 0.16; halo.rotation.x = -Math.PI / 2; halo.position.set(px, y0 + 0.12, pz); g.add(halo); }); } }
  // árvores bioluminescentes em canteiros
  for (let i = 0; i < 26; i++) { const a = i * 2.399, r = 22 + (i * 17 % 90); const x = x0 + Math.cos(a) * r, z = z0 + Math.sin(a) * r; if (Math.abs(x - x0) < 12 || Math.abs(z - z0) < 12 || r > N.r - 10) continue;
    const t = glbFit(['n_tree_light_1', 'n_tree_light_2', 'n_tree_spiral_1', 'n_tree_floating_1'][i % 4], 5 + (i % 3) * 1.5, { glow: NEON_COL[i % 6], metal: false }); t.position.set(x, y0, z); g.add(t);
    const pl = new THREE.Mesh(new THREE.TorusGeometry(1.6, 0.12, 6, 24), glow(NEON_COL[i % 6])); pl.rotation.x = -Math.PI / 2; pl.position.set(x, y0 + 0.2, z); g.add(pl); }
  // praça do reator (arena do chefe): plataforma, anéis e feixe de luz até o céu
  { const plat = new THREE.Mesh(new THREE.CylinderGeometry(15, 16, 0.6, 48), M('#141826', { metal: 0.9, rough: 0.25 })); plat.position.set(x0, y0 + 0.3, z0); plat.receiveShadow = true; g.add(plat);
    for (let k = 0; k < 3; k++) { const r = new THREE.Mesh(new THREE.RingGeometry(5 + k * 4.2, 5.4 + k * 4.2, 64), glow(k === 1 ? '#ff3ad8' : '#3af0ff')); r.rotation.x = -Math.PI / 2; r.position.set(x0, y0 + 0.62, z0); g.add(r); ANIM.push({ kind: 'spinZ', o: r, s: (k % 2 ? -1 : 1) * 0.2 }); }
    const core = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 1.2, 6, 20), glow('#bff8ff')); core.position.set(x0, y0 + 3.6, z0 - 10); g.add(core);
    const beam = new THREE.Mesh(new THREE.CylinderGeometry(1.1, 2.4, 260, 20, 1, true), add('#3af0ff')); beam.material.opacity = 0.22; beam.position.set(x0, y0 + 133, z0 - 10); g.add(beam); ANIM.push({ kind: 'pulse', o: beam, base: 0.22 });
    for (let i = 0; i < 4; i++) { const pyl = glbFit('n_turret_teleporter', 4, { glow: '#ff3ad8' }); pyl.position.set(x0 + Math.cos(i * 1.571 + 0.785) * 13, y0 + 0.6, z0 + Math.sin(i * 1.571 + 0.785) * 13); g.add(pyl); }
    const rings = new THREE.Group(); rings.position.set(x0, y0 + 10, z0 - 10); for (let k = 0; k < 3; k++) { const t = new THREE.Mesh(new THREE.TorusGeometry(3 + k * 1.3, 0.1, 6, 40), glow(NEON_COL[k])); t.rotation.x = k * 0.9; rings.add(t); } g.add(rings); ANIM.push({ kind: 'gyro', o: rings });
    const bs = new THREE.Mesh(new THREE.PlaneGeometry(22, 6.5), new THREE.MeshBasicMaterial({ map: signTex('REATOR Ω', '#3af0ff', 'perigo: Mecha Ômega ativo'), transparent: true, toneMapped: false, side: THREE.DoubleSide })); bs.position.set(x0, y0 + 19, z0 - 10); g.add(bs); ANIM.push({ kind: 'face', o: bs }); }
  // posto seguro (zona segura com portal de volta)
  { const h = N.hub, hy = ctx.H(h.x, h.z), pad = new THREE.Mesh(new THREE.CylinderGeometry(h.r, h.r + 0.6, 0.4, 48), M('#1a2030', { metal: 0.8, rough: 0.3 })); pad.position.set(h.x, hy + 0.2, h.z); pad.receiveShadow = true; g.add(pad);
    const edge = new THREE.Mesh(new THREE.TorusGeometry(h.r, 0.14, 6, 80), glow('#7aff5a')); edge.rotation.x = -Math.PI / 2; edge.position.set(h.x, hy + 0.45, h.z); g.add(edge);
    const dome = new THREE.Mesh(new THREE.SphereGeometry(h.r, 40, 14, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshBasicMaterial({ color: '#7aff5a', transparent: true, opacity: 0.05, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, wireframe: false, toneMapped: false })); dome.position.set(h.x, hy, h.z); g.add(dome);
    const hex = new THREE.Mesh(new THREE.SphereGeometry(h.r + 0.05, 24, 8, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshBasicMaterial({ color: '#7aff5a', wireframe: true, transparent: true, opacity: 0.12, toneMapped: false })); hex.position.copy(dome.position); g.add(hex);
    const p = buildPortal('#ffb03a', 'Portal para Vila Aurora'); p.position.set(h.x, hy + 0.4, h.z + 10); p.rotation.y = Math.PI; g.add(p); g.userData.backPortal = { x: h.x, z: h.z + 10 };
    const sh = glbFit('n_spaceship_finnthefrog', 13, { by: 'w', rot: 0.6, glow: '#3af0ff' }); sh.position.set(h.x - 13, hy + 0.4, h.z - 2); g.add(sh);
    [['n_computer_large', 2.6, 9, -6], ['n_ac_stacked', 3, -10, 8], ['n_solarpanel_ground', 2.2, 11, 6], ['n_rover_1', 2.2, 6, 12]].forEach(([n, s, dx, dz]) => { const o = glbFit(n, s, { glow: '#3af0ff' }); o.position.set(h.x + dx, hy + 0.4, h.z + dz); o.rotation.y = dx; g.add(o); });
    const st = new THREE.Mesh(new THREE.PlaneGeometry(14, 4.4), new THREE.MeshBasicMaterial({ map: signTex('POSTO NEON', '#7aff5a', 'zona segura • portal'), transparent: true, toneMapped: false, side: THREE.DoubleSide })); st.scale.setScalar(0.7); st.position.set(h.x, hy + 15, h.z + h.r + 2); st.rotation.y = Math.PI; g.add(st); }
  // nave estacionada numa plataforma de pouso
  { const px = x0 + 70, pz = z0 - 70, pad = new THREE.Mesh(new THREE.CylinderGeometry(11, 11, 0.5, 6), M('#1a1e2a', { metal: 0.9, rough: 0.3 })); pad.position.set(px, y0 + 0.25, pz); g.add(pad);
    const h = new THREE.Mesh(new THREE.RingGeometry(9.6, 10.2, 6), glow('#ffe03a')); h.rotation.x = -Math.PI / 2; h.position.set(px, y0 + 0.52, pz); g.add(h);
    const ship = glbFit('n_striker', 18, { by: 'w', rot: 2.3, glow: '#ff3ad8' }); ship.position.set(px, y0 + 0.5, pz); g.add(ship); ctx.collide(px, pz, 8); }
  // céu: planetas gigantes e naves em órbita, carros voadores entre os prédios
  { const p1 = glbFit('n_planet_3', 120, { metal: false, glow: '#5a2aff' }); p1.position.set(x0 - 380, y0 + 260, z0 - 700); g.add(p1); ANIM.push({ kind: 'spinY', o: p1, s: 0.01 });
    const p2 = glbFit('n_planet_7', 50, { metal: false, glow: '#ff3ad8' }); p2.position.set(x0 + 420, y0 + 180, z0 - 520); g.add(p2); ANIM.push({ kind: 'spinY', o: p2, s: -0.02 });
    for (let i = 0; i < 2; i++) { const sh = glbFit(i ? 'n_spaceship_finnthefrog' : 'n_striker', i ? 10 : 14, { by: 'w', glow: '#3af0ff' }); g.add(sh); ANIM.push({ kind: 'orbit', o: sh, cx: x0, cz: z0, y: y0 + 70 + i * 25, r: 150 + i * 60, s: (i ? -1 : 1) * (0.05 + i * 0.02), ph: i * 2 }); }
    for (let i = 0; i < 18; i++) { const car = new THREE.Group(), cm = M('#20283a', { metal: 0.9, rough: 0.25 }); car.add(box(1.6, 0.6, 3.2, cm)); const tl = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.15, 0.1), glow('#ff2a3a')); tl.position.set(0, 0, -1.62); car.add(tl); const hl = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.15, 0.1), glow('#fff6d0')); hl.position.set(0, 0, 1.62); car.add(hl);
      const und = new THREE.Mesh(new THREE.PlaneGeometry(1.6, 3), glow(NEON_COL[i % 6])); und.rotation.x = Math.PI / 2; und.position.y = -0.32; car.add(und); g.add(car);
      ANIM.push({ kind: 'lane', o: car, cx: x0, cz: z0, r: 30 + (i % 6) * 15, y: y0 + 16 + (i % 5) * 7, s: (i % 2 ? 1 : -1) * (0.12 + (i % 4) * 0.03), ph: i * 1.3 }); } }
  // letreiros holográficos soltos sobre as avenidas
  for (let i = 0; i < 6; i++) { const [txt, col, sub] = SIGNS[(i + 2) % SIGNS.length], s = new THREE.Mesh(new THREE.PlaneGeometry(12, 3.8), new THREE.MeshBasicMaterial({ map: signTex(txt, col, sub), transparent: true, toneMapped: false, side: THREE.DoubleSide, opacity: 0.9 }));
    const along = (i % 2 ? 1 : -1) * (36 + (i >> 1) * 28); s.position.set(i < 3 ? x0 + along : x0 + 0.01, y0 + 11 + (i % 3) * 2, i < 3 ? z0 + 0.01 : z0 + along); s.rotation.y = i < 3 ? Math.PI / 2 : 0; g.add(s); ANIM.push({ kind: 'flicker', o: s, ph: i * 3.1 }); }
  g.userData.ambient = { fog: '#2a1048', particles: '#3af0ff' };
  return g;
}

const _v = new THREE.Vector3();
export function updateNeon(t, camera) {
  for (const a of ANIM) {
    if (a.kind === 'portal') { a.disk.rotation.z = -t * 1.6; a.ring.scale.setScalar(1 + Math.sin(t * 3) * 0.03); a.halo.material.opacity = 0.14 + Math.sin(t * 2) * 0.06; }
    else if (a.kind === 'blink') a.o.visible = Math.sin(t * 2.4 + a.ph) > 0.2;
    else if (a.kind === 'flicker') { const f = Math.sin(t * 17 + a.ph) * Math.sin(t * 3.1 + a.ph); a.o.material.opacity = f > 0.97 ? 0.25 : 0.92; }
    else if (a.kind === 'spinY') a.o.rotation.y = t * a.s;
    else if (a.kind === 'spinZ') a.o.rotation.z = t * a.s;
    else if (a.kind === 'pulse') a.o.material.opacity = a.base + Math.sin(t * 2.2) * 0.07;
    else if (a.kind === 'gyro') { a.o.children.forEach((c, i) => { c.rotation.y = t * (0.6 + i * 0.3); c.rotation.x += 0.002 * (i + 1); }); a.o.position.y += Math.sin(t * 1.3) * 0.005; }
    else if (a.kind === 'face' && camera) { a.o.lookAt(camera.position.x, a.o.position.y, camera.position.z); }
    else if (a.kind === 'orbit' || a.kind === 'lane') { const ang = t * a.s + a.ph, x = a.cx + Math.cos(ang) * a.r, z = a.cz + Math.sin(ang) * a.r;
      a.o.position.set(x, a.y + Math.sin(t * 0.7 + a.ph) * (a.kind === 'orbit' ? 6 : 1.2), z); a.o.rotation.y = Math.atan2(-Math.sin(ang) * Math.sign(a.s), Math.cos(ang) * Math.sign(a.s)) + (a.kind === 'orbit' ? Math.PI / 2 : 0); }
  }
}
