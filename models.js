// ===== Modelos 3D procedurais (sem arte externa) =====
import * as THREE from './lib/three.module.min.js';
const GD = window.GD;

const matCache = new Map();
export function mat(color, o = {}) {
  const key = color + JSON.stringify(o);
  if (!matCache.has(key)) matCache.set(key, new THREE.MeshStandardMaterial({ color, roughness: o.rough ?? 0.75, metalness: o.metal ?? 0.05, flatShading: !!o.flat,
    emissive: o.emissive || 0x000000, emissiveIntensity: o.ei ?? 1, transparent: !!o.opacity, opacity: o.opacity ?? 1 }));
  return matCache.get(key);
}
const box = (w, h, d, m) => new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m);
const sph = (r, m, d = 1) => new THREE.Mesh(new THREE.IcosahedronGeometry(r, d), m);
const cyl = (rt, rb, h, m, s = 8) => new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, s), m);
const cone = (r, h, m, s = 8) => new THREE.Mesh(new THREE.ConeGeometry(r, h, s), m);
const blob = (w, h, d, m) => { const x = new THREE.Mesh(new THREE.SphereGeometry(0.5, 20, 14), m); x.scale.set(w * 1.15, h * 1.12, d * 1.15); return x; };
const bsph = (r, m) => new THREE.Mesh(new THREE.SphereGeometry(r, 20, 14), m);
const grp = (...c) => { const g = new THREE.Group(); c.forEach(x => g.add(x)); return g; };
const at = (o, x, y, z) => { o.position.set(x, y, z); return o; };

export { buildHumanoid, setGear, animHumanoid, playAttack, setExpr, toon, upgradeGLB, GLB } from './avatar.js';
import { buildHumanoid, animHumanoid, playAttack, GLB } from './avatar.js';
import { MOB_GLB, attachMobGLB, animMobGLB } from './creatures.js';

// ---------- monstros ----------
export function buildMob(fam) {
  const c = fam.color, m = mat(c, { opacity: fam.ghost ? 0.6 : 0, emissive: fam.ghost ? 0x2a5aaa : 0, ei: 0.6 });
  const dk = mat(new THREE.Color(c).multiplyScalar(0.6).getStyle());
  const root = new THREE.Group(), body = new THREE.Group(); root.add(body);
  const R = { root, body, legs: [], kind: fam.model, anim: { t: Math.random() * 10, state: 'idle', atk: -1 } };
  if (fam.model === 'humanoid') {
    const h = buildHumanoid({ race: fam.id === 'bandido' ? 'orc' : 'humano', skinColor: c, gender: 'm', hair: 0, hair_color: 0,
      weapon: fam.skel ? 'espadao_b' : fam.id === 'esqueleto' || fam.id === 'caido' ? 'espadao_c' : fam.id === 'bandido' ? 'martelo_ng' : 'espadao_a', armor: fam.skel ? 'pesada_a' : fam.id === 'caido' ? 'pesada_s' : fam.id === 'bandido' ? 'leve_ng' : null, equip: fam.skel ? { elmo: 'elmo_pesada_a' } : null });
    body.add(h.root); R.h = h;
    if (fam.horns) { const hm = mat('#2a1a1a'); [-1, 1].forEach(s => { const k = at(cone(0.05, 0.25, hm, 5), s * 0.1, 0.2, 0); k.rotation.z = -s * 0.5; h.P.head.add(k); }); }
    if (fam.id === 'esqueleto') h.P.skull.material = mat('#f0ead8');
  } else if (fam.model === 'quad') {
    body.add(at(blob(0.6, 0.55, 1.2, m), 0, 0.75, 0));
    const head = at(blob(0.4, 0.38, 0.45, m), 0, 0.95, 0.75); body.add(head); R.head = head;
    head.add(at(blob(0.05, 0.05, 0.02, mat('#ffcc33', { emissive: 0xaa6600 })), -0.12, 0.06, 0.23), at(blob(0.05, 0.05, 0.02, mat('#ffcc33', { emissive: 0xaa6600 })), 0.12, 0.06, 0.23));
    if (fam.id === 'javali' || fam.id === 'rei_javali') head.add(at(cone(0.04, 0.18, mat('#f0ead0'), 4), -0.15, -0.12, 0.25), at(cone(0.04, 0.18, mat('#f0ead0'), 4), 0.15, -0.12, 0.25));
    else head.add(at(cone(0.07, 0.18, dk, 4), -0.12, 0.25, -0.05), at(cone(0.07, 0.18, dk, 4), 0.12, 0.25, -0.05));
    if (fam.id === 'lagarto') { const tl = at(cone(0.18, 1.2, m, 6), 0, 0.7, -1.1); tl.rotation.x = -Math.PI / 2 - 0.2; body.add(tl); }
    else { const tl = at(blob(0.08, 0.08, 0.4, dk), 0, 0.9, -0.75); tl.rotation.x = 0.6; body.add(tl); }
    [[-0.22, 0.4], [0.22, 0.4], [-0.22, -0.4], [0.22, -0.4]].forEach(([x, z]) => { const l = at(new THREE.Group(), x, 0.55, z); l.add(at(blob(0.15, 0.55, 0.15, dk), 0, -0.27, 0)); body.add(l); R.legs.push(l); });
  } else if (fam.model === 'spider') {
    body.add(at(bsph(0.45, m, 1), 0, 0.7, -0.45), at(bsph(0.3, m, 1), 0, 0.6, 0.25));
    body.add(at(bsph(0.05, mat('#f22', { emissive: 0xaa0000 }), 0), -0.1, 0.68, 0.53), at(bsph(0.05, mat('#f22', { emissive: 0xaa0000 }), 0), 0.1, 0.68, 0.53));
    for (let i = 0; i < 8; i++) { const s = i < 4 ? -1 : 1, k = i % 4; const l = at(new THREE.Group(), s * 0.2, 0.62, 0.35 - k * 0.22); const seg = at(blob(0.7, 0.06, 0.06, dk), s * 0.35, 0.1, 0); seg.rotation.z = s * 0.5; l.add(seg); const seg2 = at(blob(0.06, 0.6, 0.06, dk), s * 0.68, -0.15, 0); l.add(seg2); l.rotation.y = s * (k - 1.5) * 0.3; body.add(l); R.legs.push(l); }
  } else if (fam.model === 'golem') {
    body.add(at(blob(1.1, 1.0, 0.7, m), 0, 1.6, 0), at(blob(0.5, 0.4, 0.45, m), 0, 2.3, 0.05));
    body.add(at(blob(0.12, 0.06, 0.02, mat('#6cf', { emissive: 0x2a8aff })), 0, 2.32, 0.28));
    [-1, 1].forEach(s => { const a = at(new THREE.Group(), s * 0.7, 2.0, 0); a.add(at(blob(0.35, 1.1, 0.35, dk), 0, -0.5, 0)); body.add(a); R.legs.push(a); });
    [-1, 1].forEach(s => { const l = at(new THREE.Group(), s * 0.3, 1.1, 0); l.add(at(blob(0.38, 1.1, 0.38, dk), 0, -0.55, 0)); body.add(l); R.legs.push(l); });
  } else if (fam.model === 'ent') {
    body.add(at(cyl(0.35, 0.5, 2.2, mat('#5a3a1e'), 7), 0, 1.4, 0), at(bsph(1.1, m, 1), 0, 3.0, 0));
    body.add(at(blob(0.1, 0.1, 0.02, mat('#ff0', { emissive: 0xaaaa00 })), -0.15, 2.0, 0.36), at(blob(0.1, 0.1, 0.02, mat('#ff0', { emissive: 0xaaaa00 })), 0.15, 2.0, 0.36));
    [-1, 1].forEach(s => { const a = at(new THREE.Group(), s * 0.4, 2.0, 0); const b = at(cyl(0.08, 0.12, 1.4, mat('#5a3a1e'), 5), s * 0.5, -0.4, 0); b.rotation.z = s * 0.8; a.add(b); body.add(a); R.legs.push(a); });
  } else if (fam.model === 'dragon') {
    body.add(at(blob(0.9, 0.8, 1.8, m), 0, 1.1, 0));
    const neck = at(blob(0.35, 0.35, 0.9, m), 0, 1.6, 1.1); neck.rotation.x = -0.6; body.add(neck);
    const head = at(blob(0.45, 0.35, 0.65, m), 0, 2.0, 1.6); body.add(head); R.head = head;
    head.add(at(cone(0.06, 0.3, dk, 4), -0.15, 0.25, -0.2), at(cone(0.06, 0.3, dk, 4), 0.15, 0.25, -0.2));
    const tl = at(cone(0.3, 1.8, m, 6), 0, 1.0, -1.7); tl.rotation.x = -Math.PI / 2; body.add(tl);
    const wingM = mat(new THREE.Color(c).multiplyScalar(0.7).getStyle(), { opacity: 0.9 });
    [-1, 1].forEach(s => { const wg = new THREE.Group(); wg.position.set(s * 0.4, 1.5, 0.2); const sh = new THREE.Shape(); sh.moveTo(0, 0); sh.lineTo(s * 2.2, 0.6); sh.lineTo(s * 1.8, -0.6); sh.lineTo(s * 0.6, -0.9); const me = new THREE.Mesh(new THREE.ShapeGeometry(sh), wingM); me.material.side = THREE.DoubleSide; me.rotation.x = -Math.PI / 2; wg.add(me); body.add(wg); (R.wings = R.wings || []).push(wg); });
    [[-0.35, 0.6], [0.35, 0.6], [-0.35, -0.6], [0.35, -0.6]].forEach(([x, z]) => { const l = at(new THREE.Group(), x, 0.8, z); l.add(at(blob(0.22, 0.8, 0.22, dk), 0, -0.4, 0)); body.add(l); R.legs.push(l); });
  }
  root.scale.setScalar(fam.scale || 1);
  root.traverse(x => { if (x.isMesh) x.castShadow = true; });
  const gdef = MOB_GLB[fam.glb || fam.id]; if (gdef && GLB.on && !fam.noGlb) attachMobGLB(R, fam, gdef).catch(e => console.warn('modelo', fam.id, e));
  return R;
}
export function animMob(R, dt, moving) {
  const A = R.anim; A.t += dt; const t = A.t;
  if (R.glbC) { animMobGLB(R, dt, moving); return; }
  if (R.h) { R.h.anim.state = A.state === 'dead' ? 'dead' : moving ? 'run' : 'idle'; if (A.atk >= 0 && R.h.anim.atk < 0) { playAttack(R.h, 'melee'); A.atk = -1; } animHumanoid(R.h, dt); return; }
  const sp = moving ? 9 : 0;
  R.legs.forEach((l, i) => { const ph = i % 2 ? 0 : Math.PI; l.rotation.x = moving ? Math.sin(t * sp + ph) * 0.6 : l.rotation.x * 0.9; });
  if (R.wings) R.wings.forEach((w, i) => w.rotation.z = Math.sin(t * 5) * 0.5 * (i ? -1 : 1));
  if (A.atk >= 0) { const p = Math.min(1, (performance.now() - A.atk) / 400); R.body.position.z = Math.sin(p * Math.PI) * 0.35; R.body.rotation.x = Math.sin(p * Math.PI) * 0.15; if (p >= 1) { A.atk = -1; R.body.position.z = 0; R.body.rotation.x = 0; } }
  if (A.state === 'dead') { R.root.rotation.z += (Math.PI / 2 - R.root.rotation.z) * Math.min(1, dt * 6); }
}

// ---------- cenário ----------
export function buildNode(type, grade) {
  const g = new THREE.Group(), gc = GD.GRADES[grade].color, glow = mat(gc, { emissive: new THREE.Color(gc).getHex(), ei: 0.5 });
  if (type === 'madeira') {
    g.add(at(cyl(0.22, 0.32, 2.4, mat('#6b4423'), 7), 0, 1.2, 0));
    const leaf = mat(['#6dbb4a', '#a8802a', '#5a7a5a', '#2f6a3a', '#7a4a3a', '#5a5a7a'][grade]);
    g.add(at(sph(1.2, leaf, 1), 0, 3.0, 0), at(sph(0.9, leaf, 1), 0.6, 2.6, 0.3), at(sph(0.8, leaf, 1), -0.6, 2.7, -0.2));
  } else if (type === 'minerio') {
    const r = at(sph(0.9, mat('#77736c'), 0), 0, 0.5, 0); r.scale.set(1.3, 0.8, 1.1); g.add(r);
    for (let i = 0; i < 4; i++) { const c = at(cone(0.12, 0.6, glow, 5), Math.cos(i * 1.7) * 0.6, 0.8, Math.sin(i * 1.7) * 0.5); c.rotation.set(Math.cos(i) * 0.6, 0, Math.sin(i) * 0.6); g.add(c); }
  } else {
    const b = at(sph(0.75, mat('#3c7a2c'), 1), 0, 0.5, 0); b.scale.set(1.2, 0.75, 1.2); g.add(b);
    for (let i = 0; i < 7; i++) g.add(at(sph(0.12, glow, 0), Math.cos(i * 0.9) * 0.6, 0.85 + (i % 2) * 0.1, Math.sin(i * 0.9) * 0.6));
  }
  g.add(at(new THREE.Mesh(new THREE.RingGeometry(1.0, 1.25, 20), mat(gc, { emissive: new THREE.Color(gc).getHex(), ei: 0.6, opacity: 0.55 })), 0, 0.06, 0)).children.at(-1).rotation.x = -Math.PI / 2;
  g.traverse(x => { if (x.isMesh) x.castShadow = true; });
  return g;
}
export function buildHouse(roof, scale = 1) {
  const g = new THREE.Group();
  g.add(at(box(6, 4, 5, mat('#d8c8a8')), 0, 2, 0), at(box(6.2, 0.5, 5.2, mat('#6b4a2a')), 0, 0.25, 0));
  const r = at(cone(5, 3, mat(roof), 4), 0, 5.5, 0); r.rotation.y = Math.PI / 4; r.scale.set(1.05, 1, 0.9); g.add(r);
  g.add(at(box(1.2, 2, 0.1, mat('#5a3a1a')), 0, 1, 2.55), at(box(0.9, 0.9, 0.1, mat('#9ad0ff', { emissive: 0x335577, ei: 0.4 })), -1.8, 2.3, 2.55), at(box(0.9, 0.9, 0.1, mat('#9ad0ff', { emissive: 0x335577, ei: 0.4 })), 1.8, 2.3, 2.55));
  g.scale.setScalar(scale); g.traverse(x => { if (x.isMesh) { x.castShadow = true; x.receiveShadow = true; } });
  return g;
}
export function makeLabel(text, color = '#fff', size = 30, bg = null) {
  const c = document.createElement('canvas'), ctx = c.getContext('2d'); ctx.font = `bold ${size}px system-ui,Segoe UI,sans-serif`;
  const w = Math.ceil(ctx.measureText(text).width) + 16; c.width = w; c.height = size + 14;
  ctx.font = `bold ${size}px system-ui,Segoe UI,sans-serif`; if (bg) { ctx.fillStyle = bg; ctx.fillRect(0, 0, w, c.height); }
  ctx.textBaseline = 'middle'; ctx.lineWidth = 6; ctx.strokeStyle = 'rgba(0,0,0,.85)'; ctx.strokeText(text, 8, c.height / 2); ctx.fillStyle = color; ctx.fillText(text, 8, c.height / 2);
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace; tex.minFilter = THREE.LinearFilter;
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, depthTest: false, transparent: true })); s.renderOrder = 999;
  s.scale.set(w / 100, c.height / 100, 1); s.userData.w = w; return s;
}
