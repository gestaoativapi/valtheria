// ===== Valtheria — identidade visual: a Árvore dos Mil Mundos (cenário 3D da tela de entrada e da escolha de personagem) =====
import * as THREE from './lib/three.module.min.js';

export const TITLE = { on: false, g: null, t: 0, shot: -1, worlds: [], motes: null };
const WORLD_COL = ['#3af0ff', '#ff6a3a', '#7aff5a', '#c07aff', '#ffe36a', '#ff5ad8', '#8ad8ff', '#ff3a4a', '#5a8aff'];
const TREE = new THREE.Vector3(0, 0, -17); // a árvore fica atrás do pedestal do personagem (origem do grupo)
export function buildTitle(scene, origin) {
  const g = TITLE.g = new THREE.Group(); g.position.copy(origin); scene.add(g);
  const M = (c, o = {}) => new THREE.MeshStandardMaterial({ color: c, roughness: o.r ?? 0.9, metalness: o.m ?? 0, emissive: o.e ? new THREE.Color(o.e) : 0x000000, emissiveIntensity: o.ei ?? 1, flatShading: !!o.flat });
  const glow = (c, op = 1) => new THREE.MeshBasicMaterial({ color: c, transparent: op < 1, opacity: op, toneMapped: false, blending: op < 1 ? THREE.AdditiveBlending : THREE.NormalBlending, depthWrite: op >= 1 });
  const add = (o, x, y, z) => { o.position.set(x, y, z); g.add(o); return o; };
  // ilha flutuante
  const isl = add(new THREE.Mesh(new THREE.SphereGeometry(30, 28, 14, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2), M('#3a3040', { flat: true })), 0, -0.3, TREE.z + 4); isl.scale.set(1, 0.75, 1);
  const top = add(new THREE.Mesh(new THREE.CircleGeometry(30, 48), M('#2e4a3a')), 0, -0.28, TREE.z + 4); top.rotation.x = -Math.PI / 2; top.receiveShadow = true;
  // tronco torcido, raízes e galhos
  const bark = M('#4a3626', { r: 1 }), trunkPts = []; for (let i = 0; i <= 10; i++) { const k = i / 10; trunkPts.push(new THREE.Vector3(Math.sin(k * 2.6) * 1.2, k * 19, Math.cos(k * 2.1) * 0.9)); }
  const curve = new THREE.CatmullRomCurve3(trunkPts), tg = new THREE.TubeGeometry(curve, 30, 1, 10); { const p = tg.attributes.position, c = new THREE.Vector3(); for (let i = 0; i < p.count; i++) { const y = p.getY(i), k = Math.max(0, Math.min(1, y / 19)), cp = curve.getPoint(k), r = 2.9 * (1 - k) + 0.9; c.set(p.getX(i) - cp.x, 0, p.getZ(i) - cp.z).multiplyScalar(r); p.setX(i, cp.x + c.x); p.setZ(i, cp.z + c.z); } tg.computeVertexNormals(); }
  const trunk = add(new THREE.Mesh(tg, bark), TREE.x, 0, TREE.z); trunk.castShadow = true;
  for (let i = 0; i < 9; i++) { const a = i / 9 * 6.283 + 0.3, L = 7 + (i % 3) * 3, pts = [new THREE.Vector3(Math.cos(a) * 1.6, 2.4, Math.sin(a) * 1.6), new THREE.Vector3(Math.cos(a) * L * 0.5, 0.9, Math.sin(a) * L * 0.5), new THREE.Vector3(Math.cos(a + 0.3) * L, -0.5, Math.sin(a + 0.3) * L)];
    add(new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts), 10, 0.55 - (i % 3) * 0.1, 6), bark), TREE.x, 0, TREE.z).castShadow = true; }
  const leafA = M('#1f6a5a', { e: '#0a8a6a', ei: 0.55, flat: true }), leafB = M('#2a8a6a', { e: '#3affc8', ei: 0.4, flat: true }), leafG = M('#c8a03a', { e: '#ffc84a', ei: 0.7, flat: true });
  for (let i = 0; i < 26; i++) { const a = i * 2.39996, r = 3 + Math.sqrt(i) * 2.3, y = 19 + Math.sin(i * 1.7) * 3.2 + (i < 8 ? 3 : 0), s = 3.2 + (i % 4) * 0.9;
    const c = add(new THREE.Mesh(new THREE.IcosahedronGeometry(s, 1), i % 7 === 3 ? leafG : i % 2 ? leafA : leafB), TREE.x + Math.cos(a) * r, y, TREE.z + Math.sin(a) * r * 0.9); c.scale.y = 0.72; c.castShadow = true;
    if (i % 3 === 0 && i > 3) { const bp = [new THREE.Vector3(TREE.x + 1, 16, TREE.z), new THREE.Vector3(TREE.x + Math.cos(a) * r * 0.5, 18.5, TREE.z + Math.sin(a) * r * 0.45), new THREE.Vector3(TREE.x + Math.cos(a) * r, y - 1, TREE.z + Math.sin(a) * r * 0.9)]; g.add(new THREE.Mesh(new THREE.TubeGeometry(new THREE.CatmullRomCurve3(bp), 8, 0.32, 5), bark)); } }
  // coração da árvore e runas
  const heart = add(new THREE.Mesh(new THREE.IcosahedronGeometry(1.1, 2), glow('#bffff0')), TREE.x + 0.2, 6.5, TREE.z + 2.6); TITLE.heart = heart;
  const hl = new THREE.PointLight(0x7affd8, 260, 70); hl.position.copy(heart.position); g.add(hl); TITLE.light = hl;
  const warm = new THREE.PointLight(0xffc86a, 160, 60); warm.position.set(6, 5, 6); g.add(warm);
  for (let k = 0; k < 3; k++) { const r = add(new THREE.Mesh(new THREE.RingGeometry(5 + k * 3.4, 5.25 + k * 3.4, 72), glow(k === 1 ? '#f2c46d' : '#3affc8', 0.7)), TREE.x, 0.05 + k * 0.01, TREE.z); r.rotation.x = -Math.PI / 2; r.userData.spin = (k % 2 ? -1 : 1) * 0.12; (TITLE.rings = TITLE.rings || []).push(r); }
  // os Mil Mundos: orbes em órbita, cada um um pequeno mundo com anel
  for (let i = 0; i < 9; i++) { const w = new THREE.Group(), c = WORLD_COL[i], s = 0.7 + (i % 3) * 0.35; w.add(new THREE.Mesh(new THREE.IcosahedronGeometry(s, 2), M(c, { e: c, ei: 1.3, r: 0.4 })));
    const rg = new THREE.Mesh(new THREE.TorusGeometry(s * 1.6, 0.04, 6, 40), glow(c)); rg.rotation.x = 1.2 + i; w.add(rg); const h = new THREE.Mesh(new THREE.SphereGeometry(s * 2.2, 12, 8), glow(c, 0.12)); w.add(h);
    w.userData = { r: 11 + (i % 4) * 4.5, y: 9 + (i * 2.3) % 15, s: (i % 2 ? -1 : 1) * (0.1 + (i % 3) * 0.04), ph: i * 0.7 }; g.add(w); TITLE.worlds.push(w); }
  // ilhotas flutuantes com cristais
  for (let i = 0; i < 6; i++) { const a = i / 6 * 6.283 + 0.5, r = 36 + (i % 2) * 9, isl2 = new THREE.Group(), b = new THREE.Mesh(new THREE.ConeGeometry(3 + i % 3, 5, 7), M('#3a3040', { flat: true })); b.rotation.x = Math.PI; isl2.add(b);
    const t2 = new THREE.Mesh(new THREE.CylinderGeometry(3 + i % 3, 3 + i % 3, 0.4, 7), M('#2e4a3a')); t2.position.y = 2.6; isl2.add(t2); const cr = new THREE.Mesh(new THREE.OctahedronGeometry(0.9), glow(WORLD_COL[i])); cr.position.y = 4.2; cr.scale.y = 1.8; isl2.add(cr);
    isl2.position.set(TREE.x + Math.cos(a) * r, 4 + (i % 3) * 6, TREE.z + Math.sin(a) * r); isl2.userData = { y: isl2.position.y, ph: i }; g.add(isl2); (TITLE.isles = TITLE.isles || []).push(isl2); }
  // pólen de luz subindo e estrelas
  { const n = 420, p = new Float32Array(n * 3), c = new Float32Array(n * 3), col = new THREE.Color(); for (let i = 0; i < n; i++) { const a = Math.random() * 6.283, r = Math.random() * 30; p[i * 3] = TREE.x + Math.cos(a) * r; p[i * 3 + 1] = Math.random() * 32; p[i * 3 + 2] = TREE.z + Math.sin(a) * r; col.set(Math.random() < 0.3 ? '#f2c46d' : '#7affd8'); c[i * 3] = col.r; c[i * 3 + 1] = col.g; c[i * 3 + 2] = col.b; }
    const geo = new THREE.BufferGeometry(); geo.setAttribute('position', new THREE.BufferAttribute(p, 3)); geo.setAttribute('color', new THREE.BufferAttribute(c, 3));
    TITLE.motes = new THREE.Points(geo, new THREE.PointsMaterial({ size: 0.28, vertexColors: true, transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false })); g.add(TITLE.motes);
    const sn = 900, sp = new Float32Array(sn * 3); for (let i = 0; i < sn; i++) { const a = Math.random() * 6.283, e = Math.random() * 1.3 - 0.25, R = 260; sp[i * 3] = Math.cos(a) * Math.cos(e) * R; sp[i * 3 + 1] = Math.sin(e) * R; sp[i * 3 + 2] = Math.sin(a) * Math.cos(e) * R; }
    const sg = new THREE.BufferGeometry(); sg.setAttribute('position', new THREE.BufferAttribute(sp, 3)); const st = new THREE.Points(sg, new THREE.PointsMaterial({ color: 0xdfe8ff, size: 1.1, sizeAttenuation: false, transparent: true, opacity: 0.85, fog: false, toneMapped: false })); st.frustumCulled = false; g.add(st); }
  return g;
}
// três tomadas de câmera que se alternam (volta larga, raízes e coração, copa vista de cima)
const SHOTS = [{ dur: 13, f: (k, o) => { const a = -0.6 + k * 1.1; o.pos.set(Math.sin(a) * 44, 9 + k * 5, TREE.z + Math.cos(a) * 44); o.look.set(0, 12, TREE.z); } },
  { dur: 10, f: (k, o) => { const a = 0.9 - k * 0.8; o.pos.set(Math.sin(a) * 15, 3 + k * 2.5, TREE.z + Math.cos(a) * 15); o.look.set(0, 7 + k * 3, TREE.z); } },
  { dur: 11, f: (k, o) => { const a = 2.4 + k * 0.9; o.pos.set(Math.sin(a) * 30, 34 - k * 8, TREE.z + Math.cos(a) * 30); o.look.set(0, 17, TREE.z); } }];
const O = { pos: new THREE.Vector3(), look: new THREE.Vector3() };
export function updateTitle(dt, camera, cinematic, onCut) {
  const T = TITLE; if (!T.g) return; T.t += dt; const t = T.t;
  for (const w of T.worlds) { const u = w.userData, a = t * u.s + u.ph; w.position.set(TREE.x + Math.cos(a) * u.r, u.y + Math.sin(t * 0.5 + u.ph) * 1.2, TREE.z + Math.sin(a) * u.r); w.rotation.y = t * 0.4; }
  for (const r of T.rings) r.rotation.z = t * r.userData.spin; for (const i of T.isles) i.position.y = i.userData.y + Math.sin(t * 0.4 + i.userData.ph) * 0.9;
  T.heart.scale.setScalar(1 + Math.sin(t * 1.6) * 0.12); T.light.intensity = 220 + Math.sin(t * 1.6) * 70;
  { const p = T.motes.geometry.attributes.position; for (let i = 0; i < p.count; i++) { let y = p.getY(i) + dt * (0.5 + (i % 5) * 0.14); if (y > 32) y = 0; p.setY(i, y); } p.needsUpdate = true; }
  if (!cinematic) return;
  let acc = 0, total = SHOTS.reduce((s, x) => s + x.dur, 0), tt = t % total, idx = 0; for (; idx < SHOTS.length; idx++) { if (tt < acc + SHOTS[idx].dur) break; acc += SHOTS[idx].dur; }
  if (idx !== T.shot) { T.shot = idx; onCut && onCut(); }
  const k = (tt - acc) / SHOTS[idx].dur; SHOTS[idx].f(k * k * (3 - 2 * k) * 0.5 + k * 0.5, O);
  camera.position.copy(O.pos).add(T.g.position); O.look.add(T.g.position); camera.lookAt(O.look);
}
