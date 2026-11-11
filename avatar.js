// ===== Valtheria — personagens 3D suaves (toon) com rosto, expressões e raças =====
import * as THREE from './three.module.min.js';
import { createCharacter, play as playClip, setOutfit, setPart, loadGLB } from './chars.js';
const GD = window.GD;

// ---------- materiais toon + contorno ----------
const grad = (() => { const d = new Uint8Array([90, 160, 225, 255]); const t = new THREE.DataTexture(d, 4, 1, THREE.RedFormat); t.minFilter = t.magFilter = THREE.NearestFilter; t.needsUpdate = true; return t; })();
const tcache = new Map();
export function toon(color, o = {}) {
  const k = 'T' + color + JSON.stringify(o);
  if (!tcache.has(k)) {
    const m = new THREE.MeshToonMaterial({ color, gradientMap: grad, emissive: o.emissive || 0, emissiveIntensity: o.ei ?? 1, transparent: !!o.opacity, opacity: o.opacity ?? 1, side: o.double ? THREE.DoubleSide : THREE.FrontSide });
    tcache.set(k, m);
  }
  return tcache.get(k);
}
const OUT = new THREE.MeshBasicMaterial({ color: 0x1a1210, side: THREE.BackSide });
OUT.onBeforeCompile = (sh) => { sh.vertexShader = sh.vertexShader.replace('#include <begin_vertex>', 'vec3 transformed = position + normal * 0.011;'); };
function ol(mesh) { // contorno estilo anime
  const o = new THREE.Mesh(mesh.geometry, OUT); o.raycast = () => {}; mesh.add(o); return mesh;
}
const M = (geo, m, line = true) => { const x = new THREE.Mesh(geo, m); x.castShadow = true; return line ? ol(x) : x; };
const at = (o, x, y, z) => { o.position.set(x, y, z); return o; };
const G = () => new THREE.Group();
const capsule = (r, len, m, seg = 10) => M(new THREE.CapsuleGeometry(r, len, 4, seg), m);
const ball = (r, m, w = 18, h = 14, line = true) => M(new THREE.SphereGeometry(r, w, h), m, line);
const lathe = (pts, m, seg = 20) => M(new THREE.LatheGeometry(pts.map(([x, y]) => new THREE.Vector2(x, y)), seg), m);
const cone = (r, h, m, s = 12) => M(new THREE.ConeGeometry(r, h, s), m);
const tube = (r1, r2, h, m, s = 12) => M(new THREE.CylinderGeometry(r1, r2, h, s), m);

// ---------- rosto desenhado (olhos, sobrancelhas, boca, cicatrizes) ----------
const faceCache = new Map();
function shade(hex, f) { const c = new THREE.Color(hex); c.multiplyScalar(f); return '#' + c.getHexString(); }
export function faceTexture(look, race, expr = 'neutral', blink = false) {
  const R = GD.RACES[race] || GD.RACES.humano, f = R.feat || {};
  const skin = look.skinCol || R.skins[look.skin || 0] || R.skins[0], eye = R.eyes[look.eye_color || 0] || R.eyes[0];
  const key = [race, look.skinCol, look.skin, look.eyes, look.eye_color, look.scar, look.gender, expr, blink, look.hair_color].join('|');
  if (faceCache.has(key)) return faceCache.get(key);
  const W = 512, H = 256, c = document.createElement('canvas'); c.width = W; c.height = H; const g = c.getContext('2d');
  g.fillStyle = skin; g.fillRect(0, 0, W, H);
  // leve sombreado de escamas / pelos
  if (f.snout || f.muzzle) { g.globalAlpha = 0.12; g.fillStyle = shade(skin, 0.6); for (let i = 0; i < 160; i++) { g.beginPath(); g.arc((i * 97) % W, (i * 53) % H, 5 + (i % 4), 0, 7); g.fill(); } g.globalAlpha = 1; }
  const cx = 128, ey = 122, fem = look.gender === 'f';
  const shape = look.eyes || 0; // 0 amendoado 1 redondo 2 felino 3 sereno
  const browCol = shade(GD.HAIR_COLORS[look.hair_color || 0] || '#333', 0.9);
  // bochechas
  if (expr === 'smile' || fem) { g.fillStyle = 'rgba(255,110,110,0.22)'; [-1, 1].forEach(s => { g.beginPath(); g.ellipse(cx + s * 30, ey + 22, 11, 6, 0, 0, 7); g.fill(); }); }
  const drawEye = (s) => {
    const x = cx + s * 22, y = ey;
    const ew = shape === 1 ? 14 : 15, eh = shape === 1 ? 13 : shape === 3 ? 7 : 11;
    let open = blink ? 0.08 : expr === 'angry' ? 0.75 : expr === 'smile' ? 0.55 : expr === 'hurt' ? 0.3 : expr === 'sad' ? 0.8 : 1;
    g.save(); g.translate(x, y); if (shape === 2) g.rotate(-s * 0.18);
    if (expr === 'smile' && !blink) { // olhos sorrindo (arco)
      g.strokeStyle = '#2a1a14'; g.lineWidth = 3; g.beginPath(); g.ellipse(0, 3, ew * 0.9, eh * 0.8, 0, Math.PI * 1.05, Math.PI * 1.95); g.stroke(); g.restore(); return;
    }
    g.beginPath(); g.ellipse(0, 0, ew, eh * open, 0, 0, 7); g.fillStyle = '#fbf8f4'; g.fill();
    g.save(); g.clip();
    g.fillStyle = eye; g.beginPath(); g.ellipse(0, 1, ew * 0.62, eh * 1.05, 0, 0, 7); g.fill();
    g.fillStyle = shade(eye, 0.45); g.beginPath(); g.ellipse(0, 1, f.snout || shape === 2 ? 1.6 : ew * 0.3, eh * 0.7, 0, 0, 7); g.fill();
    g.fillStyle = '#fff'; g.beginPath(); g.arc(-3, -3, 2.4, 0, 7); g.fill();
    g.restore();
    // cílios / pálpebra superior
    g.strokeStyle = '#1e1410'; g.lineWidth = fem ? 3.4 : 2.6; g.beginPath(); g.ellipse(0, 0, ew + 0.5, eh * open + 0.5, 0, Math.PI * 1.02, Math.PI * 1.98); g.stroke();
    if (fem && !blink) { g.beginPath(); g.moveTo(s * (ew + 1), -1); g.lineTo(s * (ew + 5), -4); g.stroke(); }
    g.restore();
  };
  drawEye(-1); drawEye(1);
  // sobrancelhas
  g.strokeStyle = browCol; g.lineWidth = fem ? 3 : 4.5; g.lineCap = 'round';
  [-1, 1].forEach(s => {
    const x = cx + s * 22, y = ey - 19; let inner = 0, outer = 0;
    if (expr === 'angry') { inner = 6; outer = -3; } else if (expr === 'sad' || expr === 'hurt') { inner = -5; outer = 3; } else if (expr === 'smile') { inner = -2; outer = -2; }
    if (f.brow) { inner += 2; }
    g.beginPath(); g.moveTo(x - s * 9, y + inner); g.quadraticCurveTo(x, y - 3 + (inner + outer) / 2, x + s * 11, y + outer); g.stroke();
  });
  // nariz (sombra)
  if (!f.snout && !f.muzzle) { g.strokeStyle = shade(skin, 0.72); g.lineWidth = 2; g.beginPath(); g.moveTo(cx + 1, ey + 10); g.quadraticCurveTo(cx + 4, ey + 20, cx - 2, ey + 22); g.stroke(); }
  // boca
  const my = ey + 36; g.lineWidth = 2.6; g.strokeStyle = '#6a2a2a'; g.fillStyle = '#7a2a32';
  g.beginPath();
  if (expr === 'smile') { g.moveTo(cx - 12, my - 2); g.quadraticCurveTo(cx, my + 11, cx + 12, my - 2); g.quadraticCurveTo(cx, my + 4, cx - 12, my - 2); g.fill(); g.stroke(); }
  else if (expr === 'sad') { g.moveTo(cx - 9, my + 4); g.quadraticCurveTo(cx, my - 4, cx + 9, my + 4); g.stroke(); }
  else if (expr === 'angry') { g.ellipse(cx, my + 1, 9, 4.5, 0, 0, 7); g.fill(); g.fillStyle = '#f4f0e8'; g.fillRect(cx - 7, my - 2, 14, 2.4); }
  else if (expr === 'hurt') { g.moveTo(cx - 9, my); g.lineTo(cx - 3, my - 3); g.lineTo(cx + 3, my + 1); g.lineTo(cx + 9, my - 2); g.stroke(); }
  else { g.moveTo(cx - 8, my); g.quadraticCurveTo(cx, my + 2.5, cx + 8, my); g.stroke(); }
  if (f.fangs) { g.fillStyle = '#fff'; [-1, 1].forEach(s => { g.beginPath(); g.moveTo(cx + s * 5, my); g.lineTo(cx + s * 7, my + 7); g.lineTo(cx + s * 9, my); g.fill(); }); }
  if (fem && expr !== 'angry') { g.fillStyle = 'rgba(190,60,80,0.35)'; g.beginPath(); g.ellipse(cx, my + 1, 8, 2.6, 0, 0, 7); g.fill(); }
  // cicatrizes
  const scar = look.scar || 0; g.strokeStyle = shade(skin, 0.55); g.lineWidth = 2.4;
  const stitch = (x1, y1, x2, y2) => { g.beginPath(); g.moveTo(x1, y1); g.lineTo(x2, y2); g.stroke(); const n = 4; for (let i = 1; i < n; i++) { const t = i / n, x = x1 + (x2 - x1) * t, y = y1 + (y2 - y1) * t; g.beginPath(); g.moveTo(x - 3, y - 2); g.lineTo(x + 3, y + 2); g.stroke(); } };
  if (scar === 1) stitch(cx + 24, ey + 8, cx + 40, ey + 28);
  if (scar === 2) stitch(cx - 22, ey - 24, cx - 16, ey + 20);
  if (scar === 3) stitch(cx - 14, ey + 4, cx + 14, ey + 18);
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 4;
  const mat = new THREE.MeshToonMaterial({ map: tex, gradientMap: grad });
  faceCache.set(key, mat); return mat;
}

// ---------- corpo ----------
const BASE_CLOTH = ['#e8e0cc', '#5a4a3a'];
export function buildHumanoid(o) {
  const race = GD.RACES[o.race] ? o.race : 'humano', R = GD.RACES[race], f = R.feat || {}, fem = o.gender === 'f';
  const look = { skin: o.skin || 0, hair: o.hair || 0, hair_color: o.hair_color || 0, ...(o.look || {}), gender: o.gender, skinCol: o.skinColor };
  const skinCol = o.skinColor || R.skins[look.skin] || R.skins[0];
  const skin = toon(skinCol), hairM = toon(GD.HAIR_COLORS[look.hair_color] || '#333');
  const H = R.h * (fem ? 0.95 : 1), Wd = R.w * (fem ? 0.88 : 1);
  const root = G(), body = G(); root.add(body); body.scale.set(Wd, H, Wd);
  const P = {};
  P.hips = at(G(), 0, 0.95, 0); body.add(P.hips);
  P.torso = G(); P.hips.add(P.torso);
  // tronco (perfil torneado)
  const chest = fem ? [[0, -0.02], [0.17, 0.0], [0.15, 0.12], [0.135, 0.22], [0.17, 0.36], [0.185, 0.44], [0.17, 0.52], [0.12, 0.6], [0.05, 0.64], [0, 0.645]]
    : [[0, -0.02], [0.17, 0.0], [0.16, 0.12], [0.165, 0.24], [0.2, 0.4], [0.215, 0.5], [0.2, 0.58], [0.13, 0.64], [0.05, 0.66], [0, 0.665]];
  P.chest = lathe(chest, skin); P.chest.scale.set(1, 1, 0.72); P.torso.add(P.chest);
  if (fem) [-1, 1].forEach(s => P.torso.add(at(ball(0.078, skin), s * 0.075, 0.42, 0.075)));
  P.neck = at(tube(0.05, 0.06, 0.14, skin), 0, 0.68, 0); P.torso.add(P.neck);
  // cabeça
  const hs = (f.headBig || 1) * (fem ? 0.97 : 1);
  P.head = at(G(), 0, 0.86, 0.0); P.torso.add(P.head); P.head.scale.setScalar(race === 'halfling' ? 1.1 : race === 'gigante' || race === 'orc' ? 0.94 : 0.98);
  const faceShape = [[1, 1.12, 1.02], [1.06, 1.06, 1.04], [1.02, 1.1, 1.0], [0.94, 1.16, 0.98]][look.face || 0];
  P.skull = new THREE.Mesh(new THREE.SphereGeometry(0.15 * hs, 40, 28), faceTexture(look, race)); P.skull.castShadow = true; ol(P.skull);
  P.skull.scale.set(...faceShape); P.head.add(P.skull);
  // queixo
  const jaw = at(ball(0.085 * hs, skin, 16, 12), 0, -0.07 * hs, 0.035); jaw.scale.set(faceShape[0] * (look.face === 2 ? 1.08 : 0.98), 0.7, 0.85); P.head.add(jaw);
  if (!f.snout && !f.muzzle) P.head.add(at(ball(0.013 * hs, toon(shade(skinCol, 0.96)), 10, 8, false), 0, -0.03 * hs, 0.158 * hs));
  // orelhas
  const ear = (s) => {
    if (f.ears === 'long') { const e = at(cone(0.04, 0.24, skin, 10), s * 0.15 * hs, 0.02, -0.02); e.rotation.z = -s * 1.2; e.rotation.x = -0.25; e.scale.z = 0.45; return e; }
    if (f.ears === 'small') { const e = at(cone(0.035, 0.11, skin, 10), s * 0.15 * hs, 0.02, -0.01); e.rotation.z = -s * 1.1; e.scale.z = 0.5; return e; }
    if (f.animalEars) { const e = at(cone(0.06, 0.14, skin, 10), s * 0.09 * hs, 0.17 * hs, -0.02); e.rotation.z = -s * 0.35; e.scale.z = 0.45; return e; }
    const e = at(ball(0.035, skin, 10, 8), s * 0.148 * hs, 0, -0.005); e.scale.set(0.45, 1, 0.8); return e;
  };
  const FEAT = []; const ft = (o) => { FEAT.push(o); return o; };
  if (!f.snout) { const eL = ear(-1), eR = ear(1); P.head.add(eL, eR); if (f.ears || f.animalEars) FEAT.push(eL, eR); }
  if (f.muzzle) { const mz = at(ball(0.075 * hs, toon(shade(skinCol, 1.12)), 16, 12), 0, -0.05 * hs, 0.12 * hs); mz.scale.set(1, 0.75, 1.1); P.head.add(ft(mz), ft(at(ball(0.025, toon('#222'), 10, 8), 0, -0.02 * hs, 0.2 * hs))); }
  if (f.snout) {
    const sn = at(capsule(0.05 * hs, 0.07, toon(skinCol)), 0, -0.065 * hs, 0.135 * hs); sn.rotation.x = Math.PI / 2; sn.scale.set(1.15, 1, 0.75); P.head.add(ft(sn));
    [-1, 1].forEach(s => { const h = at(cone(0.03, 0.22, toon('#e8dcc0'), 10), s * 0.08 * hs, 0.12 * hs, -0.1); h.rotation.x = -2.2; h.rotation.z = s * 0.25; P.head.add(ft(h)); });
    const crest = at(cone(0.05, 0.16, toon(shade(skinCol, 0.7)), 4), 0, 0.15 * hs, -0.06); crest.rotation.x = -0.9; P.head.add(ft(crest));
  }
  if (f.tusks) { const tm = toon('#f4eedc'); [-1, 1].forEach(s => { const t = at(cone(0.016, 0.07, tm, 8), s * 0.045, -0.085 * hs, 0.12 * hs); P.head.add(ft(t)); }); }
  if (f.horns && !f.snout) { /* reservado */ }
  // cabelo
  P.hair = G(); P.head.add(P.hair); buildHair(P.hair, look, hs, hairM, f, fem);
  // barba
  const beard = look.beard ?? (f.beard && !fem ? 2 : 0);
  if (!fem && beard > 0 && !f.snout) {
    const bm = toon(f.frost ? '#eef6ff' : GD.HAIR_COLORS[look.hair_color] || '#333');
    const b = at(ball(0.11 * hs, bm, 16, 12), 0, -0.1 * hs, 0.06); b.scale.set(1.05, beard === 2 ? 1.25 : 0.7, 0.75); P.head.add(b);
    if (beard === 2) { const bt = at(cone(0.07 * hs, 0.22, bm, 10), 0, -0.24 * hs, 0.08); bt.rotation.x = Math.PI; P.head.add(bt); }
  }
  // braços
  const arm = (side) => {
    const s = at(G(), side * 0.235, 0.56, 0); P.torso.add(s);
    s.add(at(ball(0.07, skin, 12, 10), 0, 0, 0));
    s.add(at(capsule(0.058, 0.2, skin), 0, -0.15, 0));
    const fa = at(G(), 0, -0.3, 0); s.add(fa);
    fa.add(at(capsule(0.05, 0.19, skin), 0, -0.13, 0));
    const hand = at(G(), 0, -0.29, 0); fa.add(hand); const hm = at(ball(0.05, skin, 12, 10), 0, 0, 0); hm.scale.set(0.85, 1.15, 0.7); hand.add(hm);
    return { s, fa, hand };
  };
  P.armL = arm(-1); P.armR = arm(1);
  const leg = (side) => {
    const l = at(G(), side * 0.095, 0, 0); P.hips.add(l);
    l.add(at(capsule(0.08, 0.3, skin), 0, -0.22, 0));
    const sh = at(G(), 0, -0.46, 0); l.add(sh);
    sh.add(at(capsule(0.062, 0.3, skin), 0, -0.2, 0));
    const ft = at(capsule(0.05, f.bigFeet ? 0.2 : 0.11, f.bigFeet ? skin : toon('#4a3424')), 0, -0.42, 0.06); ft.rotation.x = Math.PI / 2; if (f.bigFeet) ft.scale.set(1.3, 1, 1); sh.add(ft);
    return { l, sh };
  };
  P.legL = leg(-1); P.legR = leg(1);
  P.pelvis = at(ball(0.2, skin, 16, 12), 0, -0.02, 0); P.pelvis.scale.set(fem ? 1.08 : 1, 0.6, 0.75); P.hips.add(P.pelvis);
  // cauda e asas
  if (f.tail) {
    const tm = toon(f.tail === 'fur' ? shade(skinCol, 0.95) : shade(skinCol, 0.85));
    P.tail = at(G(), 0, 0.02, -0.14); P.hips.add(P.tail);
    let p = P.tail; for (let i = 0; i < 4; i++) { const r = (f.tail === 'fur' ? 0.055 : 0.07) * (1 - i * 0.18); const seg = at(G(), 0, 0, i ? -0.14 : 0); p.add(seg); seg.add(at(capsule(r, 0.1, tm, 8), 0, 0, -0.07)).children.at(-1).rotation.x = Math.PI / 2; seg.rotation.x = 0.35; p = seg; }
  }
  if (f.wings) {
    P.wings = at(G(), 0, 0.46, -0.12); P.torso.add(P.wings);
    const wm = toon('#d8f0ff', { opacity: 0.55, double: true, emissive: 0x6ab8ff, ei: 0.25 });
    [-1, 1].forEach(s => {
      const shp = new THREE.Shape(); shp.moveTo(0, 0); shp.bezierCurveTo(s * 0.25, 0.35, s * 0.55, 0.45, s * 0.62, 0.2); shp.bezierCurveTo(s * 0.5, 0.0, s * 0.4, -0.25, s * 0.18, -0.38); shp.lineTo(0, 0);
      const w = new THREE.Mesh(new THREE.ShapeGeometry(shp, 16), wm); w.rotation.y = -s * 0.5; P.wings.add(w);
    });
  }
  // roupa base (por baixo da armadura)
  const cloth = toon(BASE_CLOTH[0]), pants = toon(BASE_CLOTH[1]);
  P.base = G(); P.torso.add(P.base);
  const shirt = lathe(chest.map(([x, y]) => [x * 1.04 + (x ? 0.004 : 0), y]).filter(([, y]) => y < 0.6), cloth); shirt.scale.set(1, 1, 0.72); P.base.add(shirt);
  [P.legL, P.legR].forEach(L => { L.l.add(at(capsule(0.086, 0.3, pants), 0, -0.22, 0)); });
  if (P.tail) FEAT.push(P.tail); if (P.wings) FEAT.push(P.wings);
  const m = { root, body, P, o, look, race, FEAT, skinCol, H, Wd, gear: G(), anim: { state: 'idle', t: 0, atk: -1, kind: null, blink: 2 + Math.random() * 3, expr: 'neutral', exprUntil: 0 } };
  body.add(m.gear);
  m.setExpr = (e, ms = 1800) => setExpr(m, e, ms);
  m.enc = o.enc || 0; setGear(m, o.weapon, o.armor, o.equip);
  if (o.glb !== false && GLB.on) upgradeGLB(m);
  return m;
}

function buildHair(g, look, hs, hm, f, fem) {
  if (f.noHair) return;
  const st = look.hair || 0;
  const cap = at(ball(0.158 * hs, hm, 24, 16), 0, 0.025, -0.012); cap.scale.set(1.04, 0.92, 1.06);
  // corta a frente do capacete de cabelo para não cobrir o rosto
  const cut = new THREE.SphereGeometry(0.158 * hs, 24, 16, 0, Math.PI * 2, 0, Math.PI * 0.42); cap.geometry = cut; ol(cap);
  g.add(cap);
  const back = at(ball(0.15 * hs, hm, 20, 14), 0, 0.0, -0.035); back.scale.set(1.02, 1.0, 0.95); g.add(back);
  // franja
  for (let i = 0; i < 5; i++) { const fr = at(capsule(0.028, 0.07, hm, 8), (-0.08 + i * 0.04) * hs, 0.09 * hs, 0.12 * hs); fr.rotation.z = (i - 2) * 0.18; fr.rotation.x = 0.5; g.add(fr); }
  if (st === 1) for (let i = 0; i < 7; i++) { const sp = at(cone(0.04, 0.16, hm, 8), (-0.1 + (i % 4) * 0.065) * hs, 0.16 * hs, (i < 4 ? 0 : -0.07) * hs); sp.rotation.z = ((i % 4) - 1.5) * 0.3; sp.rotation.x = -0.3; g.add(sp); }
  if (st === 2 || (fem && st === 0)) { const l = at(capsule(0.13 * hs, 0.26, hm, 14), 0, -0.17, -0.07); l.scale.set(1.12, 1, 0.55); g.add(l); [-1, 1].forEach(s => { const sd = at(capsule(0.04, 0.2, hm, 8), s * 0.13 * hs, -0.12, 0.03); g.add(sd); }); }
  if (st === 3) { const t = at(G(), 0, 0.06, -0.15); g.add(t); t.add(at(ball(0.04, hm, 10, 8), 0, 0, 0)); const pt = at(capsule(0.05, 0.28, hm, 10), 0, -0.17, -0.05); pt.rotation.x = 0.25; t.add(pt); }
  if (st === 4) [-1, 1].forEach(s => { for (let i = 0; i < 4; i++) g.add(at(ball(0.04 - i * 0.004, hm, 10, 8), s * 0.12 * hs, -0.08 - i * 0.07, -0.02)); });
  if (st === 5) { g.add(at(ball(0.07 * hs, hm, 14, 10), 0, 0.14 * hs, -0.1)); }
}

export function setExpr_(m, e, ms = 1800) {
  m.anim.expr = e; m.anim.exprUntil = ms > 0 ? performance.now() + ms : 0;
  m.P.skull.material = faceTexture(m.look, m.race, e, false);
}

// ---------- equipamento que se adapta ao corpo ----------
const ARMOR_COL = {
  pesada: ['#7a7a7a', '#a87848', '#c4c9d0', '#3f6fb8', '#a82828', '#7a3ac8'],
  leve: ['#6b4a2a', '#8a5a2a', '#55663a', '#26476a', '#6a1a1a', '#33264f'],
  robe: ['#55558a', '#6a3a7a', '#2a5a7a', '#2a3a9a', '#8a1a2a', '#dcdcf5'],
};
const TRIM = ['#555', '#7a5a2a', '#9aa2ac', '#c9b26a', '#e8c25a', '#ffd86a'];
const GLOW = [0, 0, 0, 0x2a6aff, 0xff2a2a, 0xb04aff];
let _glowTex = null;
function glowTex() { if (_glowTex) return _glowTex; const c = document.createElement('canvas'); c.width = c.height = 64; const x = c.getContext('2d'), g = x.createRadialGradient(32, 32, 0, 32, 32, 32); g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(0.4, 'rgba(255,255,255,.35)'); g.addColorStop(1, 'rgba(255,255,255,0)'); x.fillStyle = g; x.fillRect(0, 0, 64, 64); _glowTex = new THREE.CanvasTexture(c); return _glowTex; }
const WGLB = { espada: ['w_sword', 'w_sword', 'w_sword_2', 'w_sword_big', 'w_sword_big', 'w_sword_golden'], espadao: ['w_claymore'], machado: ['w_axe', 'w_axe', 'w_axe_double'], lanca: ['w_spear'], adaga: ['w_dagger'], martelo: ['w_hammer_double'],
  escudo: ['w_shield_round', 'w_shield_round', 'w_shield_heater', 'w_shield_heater', 'w_shield_heater', 'w_shield_celtic_golden'] };
const WLEN = { espada: 1.0, espadao: 1.45, machado: 1.1, lanca: 2.4, adaga: 0.42, martelo: 1.05 };
const WMAT = new Map();
const KAURA = { espada: '#ffd75a', espadao: '#ff6a2a', machado: '#ff3a2a', lanca: '#7ad0ff', arco: '#7aff9a', adaga: '#c03aff', cajado: '#5a8aff', punhos: '#ffb03a', martelo: '#3ad8c8' };
function swapWeapon(m, holder, name, len, g, relic, shield) {
  if (name === 'w_sword_2') name = 'w_sword';
  loadGLB(name).then(gl => {
    if (!holder.parent || !m.gearParts.includes(holder)) return;
    const src = gl.scene.clone(true), b = new THREE.Box3().setFromObject(src), h = shield ? Math.max(b.max.y - b.min.y, b.max.x - b.min.x) : b.max.y - b.min.y, k = len / h;
    src.scale.setScalar(k); if (shield) { src.position.set(0, -(b.max.y + b.min.y) / 2 * k, 0.02); }
    const en = m.enc || 0, ecol = en >= 10 ? 0xffcf3a : en >= 7 ? 0xff3a3a : 0x3a8aff;
    src.traverse(o => { if (!o.isMesh) return; o.castShadow = true; const key = o.material.name + ':' + g + ':' + (shield ? 's' : m.weaponKind) + ':' + (shield ? 0 : en >= 4 ? ecol : 0) + (relic ? 'r' : '');
      if (!WMAT.has(key)) { const mt = o.material.clone(); mt.metalness = Math.min(mt.metalness, 0.6); mt.envMapIntensity = 1.2; const metal = /metal|steel|iron|blade|silver|gold/i.test(mt.name) || mt.metalness > 0.3;
        if (metal && g >= 2 && !shield) { mt.emissive = new THREE.Color(relic ? '#ffd75a' : KAURA[m.weaponKind] || GLOW[g]); mt.emissiveIntensity = 0.18 + g * 0.06; }
        if (metal && g >= 3 && shield) { mt.emissive = new THREE.Color(GLOW[g]); mt.emissiveIntensity = 0.35; }
        if (metal && !shield && en >= 4) { mt.emissive = new THREE.Color(ecol); mt.emissiveIntensity = 0.6 + (en % 3) * 0.2; }
        WMAT.set(key, mt); }
      o.material = WMAT.get(key); });
    [...holder.children].forEach(c => { if (!c.isSprite) holder.remove(c); }); holder.add(src);
    if (!shield) { const tip = new THREE.Object3D(); tip.position.y = len * 0.88; holder.add(tip); m.weaponTip = tip; }
  }).catch(() => {});
}
export function setGear(m, weaponId, armorId, equip) {
  const P = m.P, fem = m.o.gender === 'f'; equip = equip || m.o.equip || {}; m.o.equip = equip;
  (m.gearParts || []).forEach(x => x.parent && x.parent.remove(x)); m.gearParts = []; m.weaponTip = null;
  const add = (parent, obj) => { parent.add(obj); m.gearParts.push(obj); return obj; };
  const a = GD.ITEMS[armorId], w = GD.ITEMS[weaponId];
  if (P.base) P.base.visible = !a; if (P.hair) P.hair.visible = true;
  if (m.glb) glbOutfit(m, a, equip);
  if (a && !m.glbMode) {
    const g = a.grade, heavy = a.kind === 'pesada';
    const am = heavy ? toon(ARMOR_COL[a.kind][g], { metal: 0.6, rough: 0.35, emissive: GLOW[g], ei: g >= 3 ? 0.15 : 0 }) : toon(ARMOR_COL[a.kind][g], { emissive: GLOW[g], ei: g >= 3 ? 0.12 : 0 });
    const tm = toon(TRIM[g], { metal: 0.75, rough: 0.3 });
    const prof = (fem ? [[0, -0.03], [0.18, -0.01], [0.16, 0.12], [0.15, 0.22], [0.19, 0.36], [0.2, 0.45], [0.19, 0.53], [0.14, 0.6], [0.07, 0.64]]
      : [[0, -0.03], [0.18, -0.01], [0.17, 0.12], [0.18, 0.24], [0.22, 0.4], [0.23, 0.5], [0.22, 0.58], [0.15, 0.64], [0.07, 0.67]]).map(([x, y]) => [x * (heavy ? 1.1 : 1.05), y]);
    const ch = add(P.torso, lathe(prof, am)); ch.scale.set(1, 1, 0.76);
    add(P.torso, at(tube(0.2, 0.2, 0.05, tm, 20), 0, 0.03, 0)).scale.set(1, 1, 0.76);
    if (fem) [-1, 1].forEach(s => add(P.torso, at(ball(0.082, am), s * 0.075, 0.42, 0.08)));
    [P.armL, P.armR].forEach((A) => { add(A.s, at(capsule(0.066, 0.18, am), 0, -0.15, 0)); add(A.fa, at(capsule(0.06, 0.12, heavy ? tm : am), 0, -0.17, 0)); });
    [P.legL, P.legR].forEach(L => { add(L.l, at(capsule(0.093, 0.3, am), 0, -0.22, 0)); add(L.sh, at(capsule(0.072, 0.22, heavy ? tm : am), 0, -0.18, 0)); });
    [P.armL, P.armR].forEach(A => add(A.s, ball(0.078, am, 14, 10)));
    if (heavy) { [-1, 1].forEach(s => { const p = add(P.torso, at(ball(0.11, am), s * 0.25, 0.58, 0)); p.scale.set(1.15, 0.75, 1.1); add(P.torso, at(ball(0.04, tm), s * 0.25, 0.65, 0)); }); if (g >= 4) { const cape = add(P.torso, at(new THREE.Mesh(new THREE.PlaneGeometry(0.46, 0.85, 4, 6), toon(g === 5 ? '#4a1a7a' : '#7a1010', { double: true })), 0, 0.2, -0.17)); cape.rotation.x = 0.08; m.cape = cape; } }
    if (a.kind === 'robe') { add(P.hips, at(lathe([[0.2, 0.02], [0.22, -0.2], [0.28, -0.5], [0.33, -0.8], [0, -0.8]], am, 24), 0, 0, 0)).scale.set(1, 1, 0.85); add(P.torso, at(tube(0.125, 0.15, 0.03, tm, 20), 0, 0.63, 0)).scale.set(1, 1, 0.8); }
    if (a.kind === 'leve') { const st = add(P.torso, at(capsule(0.025, 0.55, tm, 6), 0.06, 0.3, 0.13)); st.rotation.z = 0.55; add(P.hips, at(tube(0.2, 0.22, 0.08, tm, 20), 0, 0.02, 0)).scale.set(1, 1, 0.8); }
  }
  if (w) {
    const g = w.grade, blade = toon(g >= 3 ? ['#fff', '#fff', '#fff', '#9fd0ff', '#ff9a9a', '#e2b8ff'][g] : '#d8dde3', { metal: 0.85, rough: 0.2, emissive: GLOW[g], ei: g >= 3 ? 0.6 : 0 });
    const wood = toon('#6b4423'), gold = toon(TRIM[g], { metal: 0.8, rough: 0.3 }), H = P.armR.hand, HL = P.armL.hand, k = w.kind;
    const bladeGeo = (L, wd) => { const s = new THREE.Shape(); s.moveTo(-wd / 2, 0); s.lineTo(wd / 2, 0); s.lineTo(wd / 2, L * 0.85); s.lineTo(0, L); s.lineTo(-wd / 2, L * 0.85); s.lineTo(-wd / 2, 0); return new THREE.ExtrudeGeometry(s, { depth: 0.012, bevelEnabled: true, bevelThickness: 0.006, bevelSize: 0.006, bevelSegments: 1 }); };
    if (k === 'espada' || k === 'espadao') {
      const L = k === 'espadao' ? 1.2 : 0.82, s = G();
      s.add(at(tube(0.022, 0.022, 0.18, wood, 8), 0, -0.02, 0), at(capsule(0.025, 0.2, gold, 8), 0, 0.08, 0)).children.at(-1).rotation.z = Math.PI / 2;
      s.add(at(ball(0.03, gold, 10, 8), 0, -0.12, 0)); const bl = at(new THREE.Mesh(bladeGeo(L, k === 'espadao' ? 0.1 : 0.07), blade), 0, 0.1, -0.009); bl.castShadow = true; s.add(bl);
      s.rotation.x = 2.0; add(H, s);

    } else if (k === 'lanca') {
      const s = G(); s.add(at(tube(0.022, 0.026, 2.3, wood, 8), 0, 0.35, 0)); const head = at(cone(0.06, 0.32, blade, 8), 0, 1.66, 0); s.add(head, at(tube(0.035, 0.035, 0.06, gold, 10), 0, 1.48, 0));
      s.rotation.x = 1.7; add(H, s);
    } else if (k === 'machado') {
      const s = G(); s.add(at(tube(0.026, 0.03, 1.05, wood, 8), 0, 0.3, 0));
      const ax = new THREE.Shape(); ax.moveTo(0, 0.12); ax.quadraticCurveTo(0.22, 0.2, 0.3, 0.02); ax.quadraticCurveTo(0.34, -0.14, 0.26, -0.26); ax.quadraticCurveTo(0.14, -0.12, 0, -0.1); ax.lineTo(0, 0.12);
      const bl = at(new THREE.Mesh(new THREE.ExtrudeGeometry(ax, { depth: 0.025, bevelEnabled: true, bevelThickness: 0.008, bevelSize: 0.008, bevelSegments: 1 }), blade), 0.02, 0.72, -0.012); bl.castShadow = true; s.add(bl);
      s.rotation.x = 2.0; add(H, s);
    } else if (k === 'adaga') {
      [H, HL].forEach(h => { const s = G(); s.add(at(tube(0.018, 0.018, 0.12, wood, 8), 0, 0, 0), at(new THREE.Mesh(bladeGeo(0.32, 0.05), blade), 0, 0.06, -0.008)); s.rotation.x = Math.PI / 2; add(h, s); });
    } else if (k === 'arco') {
      const b = new THREE.Mesh(new THREE.TorusGeometry(0.6, 0.025, 8, 24, Math.PI * 0.8), g >= 3 ? blade : wood); b.rotation.z = Math.PI / 2 + Math.PI * 0.1;
      const s = G(); s.add(b, at(new THREE.Mesh(new THREE.CylinderGeometry(0.003, 0.003, 1.1, 4), toon('#eee')), 0, 0, 0)); s.position.set(0, 0, 0.05); s.rotation.y = Math.PI / 2; add(HL, s); m.bow = s;
    } else if (k === 'cajado') {
      const s = G(); s.add(at(tube(0.026, 0.032, 1.7, wood, 8), 0, 0.3, 0));
      const orb = at(new THREE.Mesh(new THREE.IcosahedronGeometry(0.1, 2), new THREE.MeshStandardMaterial({ color: ['#88f', '#c6f', '#6cf', '#5af', '#f55', '#e6f'][g], emissive: [0x2222aa, 0x6622aa, 0x2288cc, 0x2a6aff, 0xff2a2a, 0xb04aff][g], emissiveIntensity: 0.9, roughness: 0.2 })), 0, 1.2, 0);
      s.add(orb, at(new THREE.Mesh(new THREE.TorusGeometry(0.12, 0.016, 8, 20), gold), 0, 1.2, 0)); add(H, s); m.orb = orb;
    } else if (k === 'punhos') {
      [H, HL].forEach(h => add(h, ball(0.075, toon(ARMOR_COL.pesada[g], { metal: 0.6, emissive: GLOW[g], ei: g >= 3 ? 0.4 : 0 }), 12, 10)));
    } else if (k === 'martelo') {
      const s = G(); s.add(at(tube(0.028, 0.028, 0.9, wood, 8), 0, 0.25, 0)); const hd = at(M(new THREE.CylinderGeometry(0.075, 0.075, 0.24, 12), blade), 0, 0.66, 0); hd.rotation.z = Math.PI / 2; s.add(hd); s.rotation.x = Math.PI / 2; add(H, s);
    }
    m.weaponKind = k;
    // troca a arma procedural pelo modelo 3D (Quaternius Medieval Weapons, CC0) quando carregar
    { const list = WGLB[k]; if (list) { const holder = m.gearParts.filter(x => x.parent === H || (k === 'adaga' && x.parent === HL)).filter(x => !x.isSprite); holder.forEach(hg => swapWeapon(m, hg, list[Math.min(g, list.length - 1)], WLEN[k], g, w.relic)); } }
    // brilho do encantamento: +4 a +6 azul, +7 a +9 vermelho, +10 dourado
    const en = m.enc || 0;
    if (en >= 4) { const col = new THREE.Color(en >= 10 ? '#ffcf3a' : en >= 7 ? '#ff3a3a' : '#3a8aff'), ei = 0.5 + (en % 3) * 0.25 + (en >= 10 ? 0.6 : 0);
      for (const part of m.gearParts) { if (part.parent !== H && part.parent !== HL) continue; part.traverse(o => { if (o.isMesh && o.material && o.material.emissive && !o.userData.outline) { o.material = o.material.clone(); o.material.emissive = col.clone(); o.material.emissiveIntensity = ei; } }); }
      const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex(), color: col, blending: THREE.AdditiveBlending, transparent: true, depthWrite: false, opacity: en >= 7 ? 0.85 : 0.55 })); sp.scale.setScalar(en >= 10 ? 0.9 : 0.6); sp.position.set(0, 0.35, 0); add(H, sp); m.encGlow = sp; }
  } else m.weaponKind = null;
  // peças extras: escudo, elmo, luvas e botas
  const E = (slot) => GD.ITEMS[equip[slot]];
  const sh = E('escudo');
  if (sh) { const g = sh.grade, sm = toon(sh.relic ? '#6a7a6a' : ARMOR_COL.pesada[g], { metal: 0.5 }), tm = toon(TRIM[g]);
    const kite = new THREE.Shape(); kite.moveTo(0, 0.32); kite.quadraticCurveTo(0.26, 0.3, 0.25, 0.05); kite.quadraticCurveTo(0.2, -0.22, 0, -0.38); kite.quadraticCurveTo(-0.2, -0.22, -0.25, 0.05); kite.quadraticCurveTo(-0.26, 0.3, 0, 0.32);
    const body = new THREE.Mesh(new THREE.ExtrudeGeometry(kite, { depth: 0.04, bevelEnabled: true, bevelThickness: 0.015, bevelSize: 0.015, bevelSegments: 2 }), sm); body.castShadow = true; ol(body);
    const em = at(ball(0.06, tm, 12, 8), 0, 0.04, 0.06); em.scale.z = 0.4; const grp = G(); grp.add(body, em); if (g >= 3) grp.add(at(ball(0.035, toon('#fff', { emissive: GLOW[g], ei: 1 }), 10, 8), 0, 0.04, 0.09));
    grp.rotation.y = -Math.PI / 2; add(P.armL.fa, at(grp, -0.09, -0.15, 0)); swapWeapon(m, grp, sh.relic ? 'w_shield_celtic_golden' : WGLB.escudo[Math.min(g, 5)], 0.78, g, sh.relic, true); }
  const hm = E('elmo');
  const glbHelm = m.glbMode && hm && (helmFor(m, hm) || (hm.kind === 'leve' && m.glb && m.glb.outfitKind === 'ranger'));
  if (hm && !glbHelm) { const g = hm.grade, kind = hm.kind;
    if (kind === 'pesada') { const hc = toon(hm.relic ? '#cfe8ff' : ARMOR_COL.pesada[g], { metal: 0.6 }); const dome = new THREE.Mesh(new THREE.SphereGeometry(0.168, 24, 16, 0, Math.PI * 2, 0, Math.PI * 0.55), hc); dome.castShadow = true; ol(dome); dome.position.y = 0.02; add(P.head, dome);
      add(P.head, at(capsule(0.012, 0.09, toon(TRIM[g]), 6), 0, -0.01, 0.165)); [-1, 1].forEach(s => add(P.head, at(ball(0.05, hc, 10, 8), s * 0.15, -0.04, 0)).scale.set(0.5, 1.2, 1));
      if (hm.relic) for (let i = 0; i < 5; i++) add(P.head, at(cone(0.02, 0.1, toon('#bfefff', { emissive: 0x6ac8ff, ei: 0.6 }), 6), Math.cos(i * 0.6 - 1.2) * 0.13, 0.15, Math.sin(i * 0.6 - 1.2) * 0.13 + 0.03));
      if (P.hair) P.hair.visible = false; }
    else if (kind === 'leve') { const hood = new THREE.Mesh(new THREE.SphereGeometry(0.18, 24, 16, Math.PI * 0.15, Math.PI * 1.7, 0, Math.PI * 0.7), toon(ARMOR_COL.leve[g], { double: true })); hood.rotation.y = Math.PI; hood.castShadow = true; hood.position.set(0, 0.02, -0.01); add(P.head, hood); if (P.hair) P.hair.visible = false; }
    else { const hat = G(); hat.add(at(tube(0.26, 0.26, 0.02, toon(ARMOR_COL.robe[g]), 24), 0, 0, 0), at(cone(0.13, 0.36, toon(ARMOR_COL.robe[g]), 16), 0, 0.18, -0.02)); hat.children[1].rotation.x = -0.25; hat.position.y = 0.13; add(P.head, hat); } }
  const gl = E('luvas');
  if (gl && !m.glbMode) { const gm = toon(gl.kind === 'pesada' ? ARMOR_COL.pesada[gl.grade] : gl.kind === 'leve' ? ARMOR_COL.leve[gl.grade] : ARMOR_COL.robe[gl.grade], gl.kind === 'pesada' ? { metal: 0.6 } : {});
    [P.armL, P.armR].forEach(A => { const h = at(ball(0.058, gm, 12, 10), 0, 0, 0); h.scale.set(0.9, 1.2, 0.8); add(A.hand, h); add(A.fa, at(tube(0.06, 0.055, 0.09, gm, 12), 0, -0.25, 0)); }); }
  const bt = E('botas');
  if (bt && !m.glbMode) { const bm = toon(bt.kind === 'pesada' ? ARMOR_COL.pesada[bt.grade] : bt.kind === 'leve' ? '#4a3424' : ARMOR_COL.robe[bt.grade], bt.kind === 'pesada' ? { metal: 0.6 } : {});
    [P.legL, P.legR].forEach(L => { add(L.sh, at(tube(0.075, 0.068, 0.24, bm, 12), 0, -0.32, 0)); const f = at(capsule(0.058, 0.13, bm), 0, -0.43, 0.065); f.rotation.x = Math.PI / 2; add(L.sh, f); }); }
}

// ---------- animação procedural humanizada ----------
// marcha com fase contínua: joelho dobra na fase de balanço, quadril sobe/desce e gira,
// ombros giram ao contrário do quadril, braços balançam opostos às pernas com cotovelo dobrando,
// cabeça estabiliza o olhar; parado: respiração, troca de peso e olhar ao redor.
export function animHumanoid(m, dt) {
  if (m.glb) return animGLB(m, dt);
  const A = m.anim, P = m.P; A.t += dt;
  const t = A.t, st = A.state, run = st === 'run';
  const k = (o, key, v, s = 10) => { o[key] += (v - o[key]) * Math.min(1, dt * s); };
  A.gw = (A.gw || 0) + ((run ? 1 : 0) - (A.gw || 0)) * Math.min(1, dt * 7); // peso da marcha (transição suave)
  const w = A.gw; if (run) A.ph = (A.ph || 0) + dt * 9.2;
  const ph = A.ph || 0, sL = Math.sin(ph), sR = Math.sin(ph + Math.PI), cL = Math.cos(ph), cR = Math.cos(ph + Math.PI);
  // ---- pernas
  let thL = sL * 0.62 * w, thR = sR * 0.62 * w;
  let knL = (Math.max(0, -cL) * 1.15 + 0.08) * w, knR = (Math.max(0, -cR) * 1.15 + 0.08) * w;
  // ---- parado: troca de peso entre as pernas
  const idle = 1 - w, sway = Math.sin(t * 0.55);
  knL += idle * (0.06 + Math.max(0, sway) * 0.12); knR += idle * (0.06 + Math.max(0, -sway) * 0.12);
  thL += idle * -Math.max(0, sway) * 0.05; thR += idle * -Math.max(0, -sway) * 0.05;
  // ---- braços opostos às pernas
  let alx = -sL * 0.55 * w, arx = -sR * 0.55 * w, alz = 0.07 + idle * (0.06 + Math.sin(t * 1.6) * 0.012), arz = -0.07 - idle * (0.06 + Math.sin(t * 1.6) * 0.012);
  let elL = -0.25 - Math.max(0, sL) * 0.65 * w - idle * 0.1, elR = -0.25 - Math.max(0, sR) * 0.65 * w - idle * 0.1;
  // ---- tronco, quadril e cabeça
  let bob = w * (0.035 * (1 - Math.abs(sL)) - 0.015) + idle * Math.sin(t * 1.6) * 0.004;
  let hipX = w * Math.sin(ph) * 0.018 + idle * sway * 0.018, hipRz = w * -sL * 0.04 + idle * sway * 0.03, hipRy = w * -sL * 0.12;
  let torY = w * sL * 0.16, torX = w * 0.13, torZ = -hipRz * 0.6;
  // olhar ao redor quando parado (alvo muda de tempos em tempos)
  if (!A.lookT || t > A.lookT) { A.lookT = t + 2.5 + Math.random() * 4; A.look = (Math.random() - 0.5) * 0.9; A.lookP = (Math.random() - 0.5) * 0.25; }
  let headY = -torY * 0.85 + idle * A.look, headX = -torX * 0.6 + idle * A.lookP;
  // ---- ataque: preparação → golpe com giro do corpo → recuperação
  if (A.atk >= 0) {
    const dur = A.kind === 'cast' ? 650 : 560, p = Math.min(1, (performance.now() - A.atk) / dur);
    const ease = (x) => x * x * (3 - 2 * x);
    if (A.kind === 'bow') {
      const draw = p < 0.6 ? ease(p / 0.6) : 1 - ease((p - 0.6) / 0.4) * 0.3;
      alx = -1.5; alz = 0.05; elL = -0.05; arx = -1.45; arz = 0.25 - draw * 0.55; elR = -1.6 * draw; torY = -0.45; headY = 0.4; thL = -0.15; thR = 0.12;
    } else if (A.kind === 'cast') {
      const up = Math.sin(p * Math.PI); alx = arx = -2.3 * up; alz = 0.35 * up; arz = -0.35 * up; elL = elR = -0.5 + up * 0.3; torX = -0.12 * up; headX = -0.3 * up; knL = knR = 0.15 * up;
    } else {
      const dual = m.weaponKind === 'adaga' || m.weaponKind === 'punhos';
      let sw, twist;
      if (p < 0.32) { const q = ease(p / 0.32); sw = -2.5 * q; twist = -0.45 * q; }            // prepara (arma para trás/cima)
      else if (p < 0.55) { const q = ease((p - 0.32) / 0.23); sw = -2.5 + 3.3 * q; twist = -0.45 + 0.85 * q; } // golpe rápido
      else { const q = ease((p - 0.55) / 0.45); sw = 0.8 * (1 - q); twist = 0.4 * (1 - q); }   // recupera
      arx = sw; elR = -0.3 - Math.max(0, -sw) * 0.35; arz = -0.15; torY = twist; headY = -twist * 0.6;
      const lunge = Math.sin(Math.min(1, p / 0.55) * Math.PI) * 0.6; thL = -0.35 * lunge; knL = 0.35 * lunge; thR = 0.25 * lunge; knR = 0.2 * lunge; bob -= 0.04 * lunge; torX = 0.18 * lunge;
      if (dual) { alx = p < 0.5 ? -1.2 * Math.sin(p * Math.PI * 2) : -1.6 * Math.sin((p - 0.5) * Math.PI * 2); elL = -0.6; }
      else alx = -0.35 * (1 - Math.abs(sw) / 2.5) - 0.2;
    }
    if (p >= 1) A.atk = -1;
  }
  // ---- aplica com suavização (sem estalos)
  k(P.legL.l.rotation, 'x', thL, 14); k(P.legR.l.rotation, 'x', thR, 14); k(P.legL.sh.rotation, 'x', knL, 14); k(P.legR.sh.rotation, 'x', knR, 14);
  k(P.armL.s.rotation, 'x', alx, 14); k(P.armR.s.rotation, 'x', arx, 16); k(P.armL.s.rotation, 'z', alz); k(P.armR.s.rotation, 'z', arz);
  k(P.armL.fa.rotation, 'x', elL, 12); k(P.armR.fa.rotation, 'x', elR, 12);
  k(P.torso.rotation, 'x', torX, 8); k(P.torso.rotation, 'y', torY, 12); k(P.torso.rotation, 'z', torZ, 8);
  k(P.hips.rotation, 'y', hipRy, 10); k(P.hips.rotation, 'z', hipRz, 8); k(P.hips.position, 'x', hipX, 8);
  k(P.head.rotation, 'y', headY, 4); k(P.head.rotation, 'x', headX, 4);
  P.hips.position.y = 0.95 + bob - (knL + knR) * 0.018;
  P.chest.scale.z = 0.72 * (1 + Math.sin(t * 1.6) * 0.018); // respiração
  if (P.tail) { P.tail.rotation.y = Math.sin(t * (run ? 8 : 2)) * 0.35; P.tail.rotation.x = run ? -0.2 : 0; }
  if (P.wings) { const s = Math.sin(t * (run ? 9 : 2.2)) * 0.25; P.wings.children[0].rotation.y = 0.5 + s; P.wings.children[1].rotation.y = -0.5 - s; }
  if (m.cape) m.cape.rotation.x = 0.08 + (run ? 0.5 + Math.sin(t * 9) * 0.05 : Math.sin(t * 1.5) * 0.04);
  // morte: joelhos cedem primeiro, depois o corpo tomba
  if (st === 'dead') { A.dt = (A.dt || 0) + dt; k(P.legL.sh.rotation, 'x', 1.2, 8); k(P.legR.sh.rotation, 'x', 1.0, 8); if (A.dt > 0.25) { k(m.root.rotation, 'x', -Math.PI / 2, 5); k(m.body.position, 'y', 0.25, 5); } }
  else { A.dt = 0; k(m.root.rotation, 'x', 0, 10); k(m.body.position, 'y', 0, 10); }
  if (m.orb) m.orb.material.emissiveIntensity = 0.7 + Math.sin(t * 4) * 0.3;
  // piscar e expressão
  const now = performance.now();
  if (A.exprUntil && now > A.exprUntil) { A.exprUntil = 0; A.expr = st === 'dead' ? 'hurt' : 'neutral'; P.skull.material = faceTexture(m.look, m.race, A.expr); }
  A.blink -= dt;
  if (A.blink < 0 && A.blink > -0.12) P.skull.material = faceTexture(m.look, m.race, A.expr, true);
  else if (A.blink <= -0.12) { A.blink = 2.5 + Math.random() * 3.5; P.skull.material = faceTexture(m.look, m.race, A.expr); }
}
export function playAttack(m, kind) { m.anim.atk = performance.now(); m.anim.kind = kind; if (m.setExpr && Math.random() < 0.6) m.setExpr('angry', 1200); }

export function setExpr(m, e, ms) { if (m.glb) return; return setExpr_(m, e, ms); }

// ================= modelos 3D realistas (GLB) =================
export const GLB = { on: true };
const HAIR_M = ['simpleparted', 'buzzed', 'long', 'slickback', 'bob', 'buzzed'], HAIR_F = ['long', 'buns', 'bob', 'buzzedfemale', 'simpleparted', 'buns'];
const OUTFIT_OF = { pesada: 'ranger', leve: 'ranger', robe: 'peasant' };
function outfitFor(m, a) { const fem = m.o.gender === 'f'; if (!a) return 'peasant'; if (fem) return OUTFIT_OF[a.kind]; return a.kind === 'pesada' ? 'knight' : a.kind === 'leve' ? 'ranger' : a.grade >= 4 ? 'noble' : 'wizard'; }
function helmFor(m, h) { if (!h) return null; if (h.relic) return 'helm_crown'; if (h.kind === 'pesada' && m.o.gender !== 'f') return 'helm_knight'; return null; }
const GRADE_TINT = ['#ffffff', '#e8dcc4', '#d6e2f0', '#cfe0ff', '#ffd2d2', '#f0dcff'], HEAVY_TINT = ['#b8c0c8', '#a8b4c0', '#c0c8d4', '#a8c4e8', '#e0b0b0', '#d8c8f0'];
const BASE_SKIN = new THREE.Color('#c49470');
export function upgradeGLB(m) {
  if (m.glb || m.glbPending) return; m.glbPending = true;
  const o = m.o, fem = o.gender === 'f', f = (GD.RACES[m.race] || {}).feat || {}, look = m.look;
  const bv = fem || f.snout ? 0 : (look.beard ?? (f.beard ? 2 : 0)), beard = bv === 2 ? 'hair_beard' : bv === 1 ? 'hair_moustache' : null;
  const a = GD.ITEMS[o.armor];
  createCharacter({ gender: fem ? 'f' : 'm', outfit: outfitFor(m, a), hair: f.noHair ? null : (fem ? HAIR_F : HAIR_M)[look.hair || 0] })
    .then(async C => { C.outfitKind = outfitFor(m, a); if (beard) await setPart(C, 'beard', beard); if (m.disposed) return; applyGLB(m, C); })
    .catch(e => { m.glbPending = false; console.warn('GLB', e); });
}
function ownMats(obj) { obj.traverse(o => { if (o.isMesh && o.material && !o.userData.ownMat) { o.material = o.material.clone(); o.userData.ownMat = 1; } }); }
function tintGLB(m) {
  const C = m.glb, sk = new THREE.Color(m.skinCol), hc = new THREE.Color(GD.HAIR_COLORS[m.look.hair_color] || '#333');
  const skinK = new THREE.Color(sk.r / BASE_SKIN.r, sk.g / BASE_SKIN.g, sk.b / BASE_SKIN.b);
  C.model.traverse(o => { if (!o.isMesh) return; const nm = (o.material.name || ''); ownMats(o);
    if (/Superhero|Regular/.test(nm)) o.material.color.copy(skinK);
    else if (/Hair/.test(nm)) o.material.color.copy(hc).multiplyScalar(1.6); });
}
async function glbOutfit(m, a, equip) {
  const C = m.glb, kind = outfitFor(m, a);
  if (C.outfitKind !== kind) { C.outfitKind = kind; await setOutfit(C, kind); ownMats(C.model); tintGLB(m); }
  const tint = new THREE.Color(a ? (a.kind === 'pesada' ? HEAVY_TINT : GRADE_TINT)[a.grade] : '#ffffff');
  for (const o of C.parts.outfit || []) { ownMats(o); if (/Ranger|Peasant/.test(o.material.name)) { o.material.color.copy(tint); if (!/Knight|Noble/.test(o.material.name)) o.material.metalness = a && a.kind === 'pesada' ? 0.25 : 0; o.material.envMapIntensity = a && a.kind === 'pesada' ? 1.2 : 0.6; } if (/Hood/.test(o.name)) o.visible = !!(equip && GD.ITEMS[equip.elmo] && GD.ITEMS[equip.elmo].kind === 'leve'); }
  const hItem = equip && GD.ITEMS[equip.elmo], helm = helmFor(m, hItem);
  if (C.helmName !== helm) { C.helmName = helm; await setPart(C, 'helm', helm); if (helm) { ownMats(C.model); if (hItem) for (const o of C.parts.helm) if (!hItem.relic) o.material.color.copy(new THREE.Color(HEAVY_TINT[hItem.grade])).lerp(new THREE.Color('#ffffff'), 0.4); } }
  const hidden = !!hItem && hItem.kind !== 'robe'; (C.parts.hair || []).forEach(h => h.visible = !hidden);
  // elmo de couro = capuz do próprio traje; os outros elmos continuam sendo peças à parte
}
function applyGLB(m, C) {
  const P = m.P; m.glbPending = false;
  const K = 1.98 / 1.81; C.root.scale.set(m.Wd * K, m.H * K, m.Wd * K); m.root.add(C.root);
  // proporções próprias de cada raça (escala de ossos; as animações não mexem em escala)
  const RB = { anao: { Head: 1.1, hand_l: 1.18, hand_r: 1.18, upperarm_l: 1.06, upperarm_r: 1.06 }, orc: { Head: 0.94, neck_01: 0.9, upperarm_l: 1.12, upperarm_r: 1.12, hand_l: 1.15, hand_r: 1.15, spine_03: 1.06 },
    halfling: { Head: 1.16, foot_l: 1.3, foot_r: 1.3 }, gigante: { hand_l: 1.25, hand_r: 1.25, upperarm_l: 1.1, upperarm_r: 1.1, spine_03: 1.08, Head: 0.92 }, elfo: { Head: 0.96, neck_01: 1.12 }, sombrio: { Head: 0.96, neck_01: 1.1 },
    sylph: { Head: 0.98, neck_01: 1.1, foot_l: 0.85, foot_r: 0.85 }, draconato: { neck_01: 1.18, Head: 1.04, hand_l: 1.15, hand_r: 1.15 }, beastman: { hand_l: 1.15, hand_r: 1.15, neck_01: 0.92, spine_03: 1.05 }, nocturno: { neck_01: 1.06 } }[m.race] || {};
  for (const [b, k] of Object.entries(RB)) if (C.bones[b]) C.bones[b].scale.multiplyScalar(k);
  playClip(C, 'Idle_Loop'); C.mixer.update(0); m.root.updateMatrixWorld(true);
  const sock = (proc, bname) => { const b = C.bones[bname], s = new THREE.Object3D(); b.add(s); b.updateWorldMatrix(true, false);
    const M = new THREE.Matrix4().copy(b.matrixWorld).invert().multiply(proc.matrixWorld); M.decompose(s.position, s.quaternion, s.scale); return s; };
  const wpos = (bname) => { const v = new THREE.Vector3(); C.bones[bname].getWorldPosition(v); return v; };
  const head = sock(P.head, 'Head'); { const v = wpos('Head'); v.y += 0.1 * m.H * K; C.bones.Head.worldToLocal(v); head.position.copy(v); head.scale.multiplyScalar(0.72); }
  const torso = sock(P.torso, 'spine_03'), hips = sock(P.hips, 'pelvis');
  const handR = sock(P.armR.hand, 'hand_r'), handL = sock(P.armL.hand, 'hand_l');
  // mão: eixo dos dedos = -Y, polegar = +Z (mesmo referencial das mãos procedurais, onde as armas foram desenhadas)
  const frame = (s, bname, side, scaleRef) => { const b = C.bones[bname], h = wpos('hand_' + side), fing = wpos('middle_01_' + side).sub(h).normalize(), th = wpos('index_01_' + side).sub(wpos('pinky_01_' + side));
    th.sub(fing.clone().multiplyScalar(th.dot(fing))).normalize(); const Y = fing.clone().negate(), Z = th, X = new THREE.Vector3().crossVectors(Y, Z).normalize();
    const qW = new THREE.Quaternion().setFromRotationMatrix(new THREE.Matrix4().makeBasis(X, Y, Z)), qB = new THREE.Quaternion(); b.getWorldQuaternion(qB);
    s.quaternion.copy(qB.invert().multiply(qW)); const sc = new THREE.Vector3(); scaleRef.getWorldScale(sc); const bs = new THREE.Vector3(); b.getWorldScale(bs); s.scale.set(sc.x / bs.x, sc.y / bs.y, sc.z / bs.z); };
  for (const [hs, side, proc] of [[handR, 'r', P.armR.hand], [handL, 'l', P.armL.hand]]) { frame(hs, 'hand_' + side, side, proc); const mid = C.bones['middle_01_' + side]; if (mid) hs.position.copy(mid.position).multiplyScalar(0.55); }
  const faL = sock(P.armL.fa, 'lowerarm_l'), faR = sock(P.armR.fa, 'lowerarm_r'); frame(faL, 'lowerarm_l', 'l', P.armL.fa); faL.position.set(0, 0, 0); const sL = sock(P.armL.s, 'upperarm_l'), sR = sock(P.armR.s, 'upperarm_r');
  for (const f of m.FEAT) { const par = f.parent; if (!par) continue; const target = par === P.head ? head : par === P.hips ? hips : torso; target.add(f); }
  m.body.visible = false;
  m.P = { ...P, head, skull: head, torso, hips, armR: { hand: handR, fa: faR, s: sR }, armL: { hand: handL, fa: faL, s: sL }, hair: null, base: null, legL: { l: hips, sh: hips }, legR: { l: hips, sh: hips } };
  m.glb = C; m.glbMode = true; ownMats(C.model); tintGLB(m);
  C.root.traverse(o => o.userData.pick = m.root.userData.pick || o.userData.pick);
  const eq = m.o.equip || {}; setGear(m, m.o.weapon || eq.arma, m.o.armor || eq.armadura, eq);
  m.anim.idleClip = m.o.idle || (!m.o.npc && { orc: 'Idle_FoldArms_Loop', gigante: 'Idle_FoldArms_Loop', anao: 'Idle_Shield_Loop', mago: null }[m.race]) || (m.o.npc ? (['Idle_Loop', 'Idle_FoldArms_Loop', 'Idle_Talking_Loop'][Math.floor(Math.random() * 3)]) : 'Idle_Loop');
  if (m.onGLB) m.onGLB(m);
}
const ATK_CLIPS = ['Sword_Regular_A', 'Sword_Regular_B', 'Sword_Regular_C', 'Sword_Attack'];
function animGLB(m, dt) {
  const A = m.anim, C = m.glb, t = performance.now();
  if (A.state === 'dead') { if (A.cur !== 'dead') { playClip(C, 'Death01', { once: true, fade: 0.15 }); A.cur = 'dead'; } }
  else if (A.atk >= 0 && A.atkSeen !== A.atk) {
    A.atkSeen = A.atk; const wk = m.weaponKind;
    const SK = A.kind === 'skill' ? ['Sword_Regular_Combo', 'Melee_Hook', 'Sword_Dash'].filter(n => C.clips ? true : true) : null;
    const clip = SK && wk && wk !== 'punhos' && wk !== 'cajado' && wk !== 'arco' ? SK[Math.floor(Math.random() * SK.length)] : A.kind === 'cast' || A.kind === 'skill' && wk === 'cajado' ? 'Spell_Simple_Shoot' : A.kind === 'bow' ? 'Spell_Simple_Shoot' : wk === 'punhos' || !wk ? (Math.random() < 0.5 ? 'Punch_Jab' : 'Punch_Cross') : ATK_CLIPS[Math.floor(Math.random() * ATK_CLIPS.length)];
    const act = playClip(C, clip, { once: true, fade: 0.08, speed: 1.35 }); A.cur = 'atk'; A.atkEnd = t + (act ? act.getClip().duration / 1.35 * 1000 - 120 : 500);
  }
  else if (A.cur === 'atk' && t < A.atkEnd) { /* golpe em andamento */ }
  else if (A.hitAt && t - A.hitAt < 60 && A.cur !== 'hit' && A.state !== 'climb') { A.hitAt = 0; if (playClip(C, Math.random() < 0.5 ? 'Hit_Chest' : 'Hit_Head', { once: true, fade: 0.06, speed: 1.4 })) { A.cur = 'hit'; A.atkEnd = t + 380; } }
  else if (A.cur === 'hit' && t < A.atkEnd) { }
  else { const want = A.state === 'mount' ? 'Sitting_Idle_Loop' : A.state === 'fly' ? (A.moving ? 'Swim_Fwd_Loop' : 'Swim_Idle_Loop') : A.state === 'climb' ? 'ClimbUp_1m' : A.state === 'swim' ? (A.moving ? 'Swim_Fwd_Loop' : 'Swim_Idle_Loop') : A.state === 'roll' ? 'Roll' : A.state === 'sprint' ? 'Sprint_Loop' : A.state === 'run' ? 'Jog_Fwd_Loop' : A.state === 'gather' ? 'Interact' : (A.idleClip || 'Idle_Loop'); if (A.cur !== want) { if (playClip(C, want, { fade: 0.22, once: want === 'Roll', speed: A.state === 'run' ? 1.15 * ({ halfling: 1.3, anao: 1.18, gigante: 0.85, orc: 0.95, sylph: 1.08 }[m.race] || 1) : A.state === 'climb' ? 0.8 : want === 'Roll' ? 1.3 : 1 })) A.cur = want; else if (A.cur !== 'Jog_Fwd_Loop' && A.state !== 'idle') { playClip(C, 'Jog_Fwd_Loop', { fade: 0.2 }); A.cur = 'Jog_Fwd_Loop'; } } }
  C.mixer.update(dt);
}
