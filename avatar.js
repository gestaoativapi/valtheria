// ===== Valtheria — personagens 3D suaves (toon) com rosto, expressões e raças =====
import * as THREE from './lib/three.module.min.js';
import { customWeapon } from './weapons_custom.js';
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
const OUT = new THREE.MeshBasicMaterial({ color: 0x241a16, side: THREE.BackSide, transparent: true, opacity: 0.7 });
OUT.onBeforeCompile = (sh) => { sh.vertexShader = sh.vertexShader.replace('#include <begin_vertex>', 'vec3 transformed = position + normal * 0.0065;'); };
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
// peça afilada entre dois pontos (chifres, espinhos, dentes): garante simetria ao espelhar o grupo
function spike(a, b, r0, r1, mat, seg = 7) { const A = new THREE.Vector3(...a), B = new THREE.Vector3(...b), d = B.clone().sub(A), len = d.length(); const m = M(new THREE.CylinderGeometry(r1, r0, len, seg), mat); m.position.copy(A).addScaledVector(d, 0.5); m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), d.normalize()); return m; }
function hornArc(g, p0, p1, p2, r0, mat, n = 6) { const P = t => [0, 1, 2].map(k => (1 - t) * (1 - t) * p0[k] + 2 * (1 - t) * t * p1[k] + t * t * p2[k]); for (let i = 0; i < n; i++) { const t0 = i / n, t1 = (i + 1) / n; g.add(spike(P(t0), P(t1), r0 * (1 - t0 * 0.92), r0 * (1 - t1 * 0.92), mat)); if (i < n - 1) { const j = M(new THREE.SphereGeometry(r0 * (1 - t1 * 0.92), 7, 5), mat); j.position.set(...P(t1)); g.add(j); } } }
// cabeça de dragão: crânio baixo, focinho largo e rombudo, mandíbula clara com presas, sobrancelha em crista que vira chifre curvo,
// barbatanas na bochecha e crista dorsal. Tudo montado de um lado só e espelhado, para ficar simétrico.
function dragonHead(head, col, eyeCol, hs, fem, ft, type = 0) {
  const k = hs * 1.12, sc = toon(col), lite = toon('#' + new THREE.Color(col).lerp(new THREE.Color('#e6d3a8'), 0.72).getHexString()), dark = toon(shade(col, 0.5)), mid = toon(shade(col, 0.75)), horn = toon('#cdbf9f'), hornD = toon('#7d7260'), blk = toon('#120e0c'), wht = toon('#f4ecdc'), eye = toon(eyeCol, { emissive: new THREE.Color(eyeCol).getHex(), ei: 0.9 });
  const H = new THREE.Group(); H.scale.setScalar(k); H.position.set(0, -0.05 * k, 0.012 * k); head.add(ft(H));
  const put = (g, m, x, y, z, sx = 1, sy = 1, sz = 1, rx = 0, ry = 0, rz = 0) => { m.position.set(x, y, z); m.scale.set(sx, sy, sz); m.rotation.set(rx, ry, rz); g.add(m); return m; };
  put(H, ball(0.178, sc, 18, 14), 0, 0.1, 0.005, 0.98, 1.0, 1.14); put(H, ball(0.13, sc, 14, 10), 0, 0.085, 0.09, 1.05, 0.95, 1); // crânio e testa
  put(H, ball(0.105, sc, 14, 10), 0, -0.15, -0.035, 1.12, 0.95, 1.08); put(H, ball(0.085, lite, 12, 8), 0, -0.155, 0.03, 0.95, 0.9, 0.7); // pescoço e papo
  // focinho: tronco de cone largo, achatado, com ponta rombuda
  const LZ = type === 3 ? 1.32 : 1;
  const sn = new THREE.Group(); sn.position.set(0, 0.0, 0.1); sn.rotation.x = 0.1; sn.scale.z = LZ; H.add(sn);
  sn.add(spike([0, -0.012, 0.275], [0, -0.06, 0.292], 0.026, 0.002, sc, 6)); // bico em gancho
  for (let i = 0; i < 4; i++) { const pl = M(new THREE.SphereGeometry(0.03 - i * 0.003, 8, 6), mid); pl.position.set(0, 0.058 - i * 0.006, 0.03 + i * 0.058); pl.scale.set(1.25, 0.4, 1.1); sn.add(pl); } // placas do dorso
  put(sn, M(new THREE.CylinderGeometry(0.052, 0.105, 0.25, 10), sc), 0, 0, 0.125, 1, 1, 0.68, Math.PI / 2); put(sn, ball(0.054, sc, 12, 10), 0, 0.0, 0.25, 1, 0.68, 0.9);
  put(sn, ball(0.045, mid, 10, 8), 0, 0.04, 0.12, 0.9, 0.5, 2.2); // dorso do focinho
  for (let i = 0; i < 3; i++) put(sn, cone(0.016, 0.035, dark, 4), 0, 0.066 - i * 0.004, 0.06 + i * 0.055, 0.6, 1, 1, -0.5);
  for (const sx of [-1, 1]) put(sn, ball(0.013, blk, 8, 6), sx * 0.024, 0.03, 0.262, 1, 0.6, 1.4); // narinas
  // mandíbula entreaberta, mais clara
  const jw = new THREE.Group(); jw.position.set(0, -0.055, 0.07); jw.rotation.x = 0.2; jw.scale.z = LZ; H.add(jw);
  put(jw, M(new THREE.CylinderGeometry(0.042, 0.092, 0.24, 10), lite), 0, 0, 0.12, 1, 1, 0.4, Math.PI / 2); put(jw, ball(0.044, lite, 10, 8), 0, 0, 0.24, 1, 0.42, 0.9);
  const side = new THREE.Group(); // lado direito; o esquerdo é o espelho
  for (let i = 0; i < 7; i++) { const z = 0.14 + i * 0.033, x = 0.088 - i * 0.0075; side.add(spike([x, -0.028 - i * 0.004, z], [x, -0.06 - i * 0.004, z + 0.004], 0.008, 0.001, wht, 5)); } // dentes de cima
  side.add(spike([0.04, -0.05, 0.345], [0.042, -0.095, 0.35], 0.011, 0.001, wht, 6)); // presa
  for (let i = 0; i < 4; i++) { const z = 0.16 + i * 0.045, x = 0.075 - i * 0.008; side.add(spike([x, -0.075 - i * 0.012, z], [x, -0.05 - i * 0.012, z + 0.002], 0.007, 0.001, wht, 5)); } // dentes de baixo
  put(side, ball(0.075, sc, 12, 10), 0.095, -0.03, 0.03, 0.75, 0.95, 1.1); // articulação da mandíbula
  put(side, ball(0.04, eye, 12, 10), 0.118, 0.07, 0.15, 0.6, 0.72, 0.9, 0, 0.5, 0); put(side, ball(0.022, blk, 8, 6), 0.134, 0.07, 0.166, 0.22, 0.95, 0.5, 0, 0.5, 0); // olho e pupila em fenda
  put(side, ball(0.055, dark, 10, 8), 0.112, 0.122, 0.13, 0.75, 0.42, 1.7, -0.25, 0.4, 0.25); // sobrancelha
  const hr = fem ? 0.032 : 0.04; put(side, ball(0.05, hornD, 8, 6), 0.088, 0.135, -0.025, 1, 0.8, 1);
  if (type === 0) { hornArc(side, [0.085, 0.13, -0.02], [0.22, 0.36, -0.3], [0.2, 0.06, -0.4], hr, horn, 9); hornArc(side, [0.2, 0.06, -0.4], [0.2, -0.04, -0.36], [0.2, -0.02, -0.26], hr * 0.3, horn, 3); hornArc(side, [0.12, 0.02, -0.06], [0.2, 0.04, -0.14], [0.19, 0.1, -0.24], 0.02, horn, 4); } // chifre recurvado
  else if (type === 1) { hornArc(side, [0.085, 0.13, -0.02], [0.17, 0.26, -0.12], [0.12, 0.3, -0.3], hr * 0.85, horn, 6); for (let i = 0; i < 4; i++) side.add(spike([0.05 + i * 0.022, 0.19 - i * 0.03, -0.05 - i * 0.02], [0.07 + i * 0.04, 0.27 - i * 0.045, -0.2 - i * 0.03], 0.02, 0.002, horn, 6)); } // coroa de chifres
  else if (type === 2) { hornArc(side, [0.085, 0.13, -0.02], [0.14, 0.2, -0.2], [0.12, 0.26, -0.44], hr * 0.8, horn, 6); for (let i = 0; i < 5; i++) side.add(spike([0.06 + i * 0.018, 0.14 - i * 0.008, 0.13 - i * 0.04], [0.1 + i * 0.03, 0.22 - i * 0.004, 0.04 - i * 0.07], 0.016, 0.002, horn, 5)); } // sobrancelha de espinhos
  else { hornArc(side, [0.085, 0.13, -0.02], [0.13, 0.2, -0.22], [0.1, 0.2, -0.5], hr * 0.9, horn, 6); hornArc(side, [0.12, 0.02, -0.06], [0.19, 0.0, -0.18], [0.16, 0.0, -0.36], 0.024, horn, 4); for (let i = 0; i < 3; i++) side.add(spike([0.02 + i * 0.02, -0.1, 0.16 - i * 0.05], [0.025 + i * 0.022, -0.16, 0.13 - i * 0.05], 0.012, 0.001, horn, 5)); } // chifres retos e barbela
  for (let i = 0; i < 4; i++) { const y = -0.02 - i * 0.04, fin = spike([0.125, y, -0.01 - i * 0.012], [0.2 - i * 0.012, y - 0.03, -0.09 - i * 0.012], 0.024, 0.002, dark, 4); fin.scale.z = 0.35; side.add(fin); } // barbatana da bochecha
  const mir = side.clone(true); mir.scale.x = -1; H.add(side, mir);
  for (let i = 0; i < 7; i++) { const a = 0.35 + i * 0.3, r = 0.155; const sp = spike([0, 0.035 + Math.cos(a) * r * 0.9, -0.005 - Math.sin(a) * r * 1.1], [0, 0.035 + Math.cos(a) * (r + 0.075 - i * 0.004) * 0.9, -0.005 - Math.sin(a) * (r + 0.075) * 1.1 - 0.03], 0.02, 0.002, dark, 4); sp.scale.x = 0.45; H.add(sp); } // crista
  H.add(spike([0, -0.085, 0.22], [0, -0.14, 0.2], 0.013, 0.001, horn, 5)); // espinho do queixo
}
// cabeça de fera (leão, tigre, lobo ou crocodilo): crânio que cobre a cabeça humana, focinho, orelhas, olhos e pelagem
function beastHead(head, kind, col, eyeCol, hs, fem, ft) {
  hs *= 1.12; // a cabeça de fera envolve a cabeça humana (que é encolhida no esqueleto)
  const fur = toon(col), lite = toon(shade(col, 1.28)), dark = toon(shade(col, 0.55)), blk = toon('#1c1614'), wht = toon('#f2ead8'), eye = toon(eyeCol, { emissive: new THREE.Color(eyeCol).getHex(), ei: 0.25 });
  const add = (m, x, y, z, sx = 1, sy = 1, sz = 1) => { at(m, x * hs, (y - 0.05) * hs, (z + 0.012) * hs); m.scale.set(sx, sy, sz); head.add(ft(m)); return m; };
  const croc = kind === 'crocodilo', wolf = kind === 'lobo';
  add(ball(0.166 * hs, fur, 18, 14), 0, croc ? 0.05 : 0.07, croc ? 0.01 : 0.005, 1.0, croc ? 0.9 : 1.0, croc ? 1.18 : 1.14); // crânio
  add(ball(0.1 * hs, fur, 14, 10), 0, -0.15, -0.03, 1.15, 0.9, 1.1); // pescoço peludo
  const eyes = (y, z, x, r) => [-1, 1].forEach(s => { add(ball(r * hs, eye, 10, 8), s * x, y, z, 1, 0.8, 0.6); const p = add(ball(r * 0.5 * hs, blk, 8, 6), s * x, y, z + r * 0.5, croc ? 0.35 : 0.7, 1, 0.5); const br = add(capsule(0.012 * hs, 0.05 * hs, dark, 6), s * x, y + r * 1.15, z + 0.004); br.rotation.z = Math.PI / 2 - s * 0.35; });
  if (croc) {
    add(capsule(0.062 * hs, 0.2 * hs, fur, 10), 0, -0.01, 0.2, 1.15, 0.62, 1).rotation.x = Math.PI / 2; // focinho de cima
    add(capsule(0.055 * hs, 0.19 * hs, lite, 10), 0, -0.062, 0.18, 1.1, 0.42, 1).rotation.x = Math.PI / 2; // mandíbula
    for (const s of [-1, 1]) { add(ball(0.03 * hs, fur, 8, 6), s * 0.04, 0.03, 0.34, 1, 0.7, 1); add(ball(0.05 * hs, fur, 10, 8), s * 0.078, 0.165, 0.1); // narinas e arcos dos olhos
      for (let i = 0; i < 6; i++) { const t = add(cone(0.009 * hs, 0.028 * hs, wht, 5), s * (0.062 - i * 0.002), -0.045, 0.13 + i * 0.038); t.rotation.x = Math.PI; } }
    for (let i = 0; i < 5; i++) add(cone(0.022 * hs, 0.05 * hs, dark, 5), 0, 0.17 - i * 0.012, -0.03 - i * 0.045).rotation.x = -0.5 - i * 0.25; // crista dorsal
    eyes(0.165, 0.14, 0.08, 0.028);
  } else {
    const k = hs, H = new THREE.Group(); H.scale.setScalar(k); H.position.set(0, -0.05 * k, 0.012 * k); head.add(ft(H));
    const put = (g, m, x, y, z, sx = 1, sy = 1, sz = 1, rx = 0, ry = 0, rz = 0) => { m.position.set(x, y, z); m.scale.set(sx, sy, sz); m.rotation.set(rx, ry, rz); g.add(m); return m; };
    const pale = toon(kind === 'lobo' ? shade(col, 1.35) : '#f0e6d2'), nose = toon(kind === 'lobo' ? '#16110f' : '#3a2420'), lion = kind === 'leao', tiger = kind === 'tigre';
    const ml = wolf ? 0.21 : 0.115, mr0 = wolf ? 0.078 : 0.098, mr1 = wolf ? 0.04 : 0.07, my = -0.03;
    put(H, ball(0.11, fur, 14, 10), 0, 0.02, 0.07, wolf ? 0.95 : 1.15, 0.85, 1); // ponte do nariz
    put(H, M(new THREE.CylinderGeometry(mr1, mr0, ml, 10), fur), 0, my, 0.1 + ml / 2, 1, 1, wolf ? 0.72 : 0.8, Math.PI / 2); // focinho
    put(H, ball(mr1 * 1.02, pale, 12, 10), 0, my - 0.012, 0.1 + ml, 1.05, 0.78, 0.75); // ponta clara
    put(H, M(new THREE.CylinderGeometry(mr1 * 0.8, mr0 * 0.8, ml * 0.9, 10), pale), 0, my - 0.052, 0.09 + ml / 2, 1, 1, 0.4, Math.PI / 2 + 0.12); // queixo
    put(H, M(new THREE.ConeGeometry(0.034, 0.04, 3), nose), 0, my + 0.022, 0.1 + ml + mr1 * 0.62, 1.15, 1, 0.7, Math.PI * 0.9, 0, 0); put(H, M(new THREE.BoxGeometry(0.006, 0.03, 0.01), nose), 0, my - 0.012, 0.1 + ml + mr1 * 0.74); // nariz e sulco
    const side = new THREE.Group();
    put(side, ball(mr1 * 0.74, pale, 12, 10), mr1 * 0.5, my - 0.02, 0.1 + ml - 0.004, 1.05, 0.82, 0.9); // almofada do bigode
    for (let i = 0; i < 3; i++) side.add(spike([mr1 * 0.8, my - 0.02 + (i - 1) * 0.012, 0.1 + ml], [mr1 * 0.8 + 0.1, my - 0.01 + (i - 1) * 0.03, 0.08 + ml], 0.0022, 0.0005, wht, 4)); // bigodes
    side.add(spike([mr1 * 0.45, my - 0.04, 0.1 + ml + 0.005], [mr1 * 0.47, my - 0.085, 0.1 + ml + 0.008], 0.011, 0.001, wht, 6)); // presa
    put(side, ball(0.036, blk, 10, 8), 0.078, 0.07, 0.172, 1.25, 0.72, 0.6, 0, 0.4, 0.3); put(side, ball(0.029, eye, 10, 8), 0.08, 0.07, 0.183, 1.1, 0.62, 0.6, 0, 0.4, 0.3); put(side, ball(0.013, blk, 8, 6), 0.084, 0.07, 0.198, wolf ? 0.9 : 0.45, 1, 0.5); // olho amendoado
    put(side, ball(0.05, fur, 10, 8), 0.078, 0.115, 0.165, 1.15, 0.42, 1.1, -0.2, 0.4, 0.3); // sobrancelha
    put(side, ball(0.085, fur, 12, 10), 0.105, -0.045, 0.02, 0.8, 1, 1); // bochecha
    if (wolf) { side.add(spike([0.085, 0.14, -0.02], [0.12, 0.33, -0.04], 0.062, 0.004, fur, 5)); const inn = spike([0.09, 0.16, 0.0], [0.118, 0.3, -0.025], 0.04, 0.003, toon('#b98a7c'), 5); inn.scale.z = 0.5; side.add(inn);
      for (let i = 0; i < 5; i++) side.add(spike([0.12, -0.0 - i * 0.03, -0.0], [0.2 - i * 0.012, -0.05 - i * 0.045, -0.07], 0.034, 0.002, i % 2 ? lite : fur, 5)); } // orelha em pé e colar de pelo
    else { put(side, ball(0.058, fur, 12, 10), 0.115, 0.175, -0.03, 1, 1.05, 0.5, 0, -0.3, 0); put(side, ball(0.036, toon(lion ? shade(col, 0.6) : '#2a1c16'), 10, 8), 0.115, 0.175, -0.012, 1, 1, 0.4, 0, -0.3, 0); // orelha redonda
      if (tiger) { for (let i = 0; i < 4; i++) side.add(spike([0.13, -0.02 - i * 0.03, 0.02], [0.2 - i * 0.01, -0.06 - i * 0.04, -0.03], 0.03, 0.002, i % 2 ? pale : fur, 5)); // suíças
        for (const [a, b] of [[[0.03, 0.15, 0.1], [0.045, 0.19, 0.03]], [[0.07, 0.14, 0.085], [0.1, 0.17, 0.01]], [[0.125, 0.06, 0.07], [0.16, 0.07, -0.02]], [[0.13, 0.01, 0.06], [0.165, 0.0, -0.03]], [[0.11, 0.115, 0.06], [0.15, 0.13, -0.03]]]) { const st = spike(a, b, 0.012, 0.002, blk, 4); st.scale.z = 0.4; side.add(st); } } }
    const mir = side.clone(true); mir.scale.x = -1; H.add(side, mir);
    if (tiger) { const st = spike([0, 0.16, 0.1], [0, 0.2, 0.02], 0.012, 0.002, blk, 4); st.scale.z = 0.4; H.add(st); }
    if (lion && !fem) { for (let r = 0; r < 3; r++) for (let i = 0; i < 18; i++) { const a = (i + r * 0.5) / 18 * Math.PI * 2, R = 0.13 + r * 0.02, L = 0.14 + r * 0.035, z0 = 0.0 - r * 0.07; H.add(spike([Math.sin(a) * R, 0.03 + Math.cos(a) * R, z0], [Math.sin(a) * (R + L), 0.0 + Math.cos(a) * (R + L) - 0.03, z0 - 0.09], 0.05, 0.004, r === 1 ? dark : toon(shade(col, 0.68)), 5)); }
      put(H, ball(0.19, dark, 12, 10), 0, 0.0, -0.1, 1.15, 1.2, 0.9); } // juba em mechas
    else if (lion) put(H, ball(0.1, lite, 10, 8), 0, -0.17, 0.04, 1.2, 0.8, 0.7);
  }
}
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
  const beast = race === 'beastman' ? ['leao', 'tigre', 'lobo', 'crocodilo'][(look.face || 0) % 4] : null;
  let skinCol = o.skinColor || R.skins[look.skin] || R.skins[0];
  if (beast === 'crocodilo') skinCol = '#' + new THREE.Color(skinCol).lerp(new THREE.Color('#5f7040'), 0.7).getHexString(); else if (beast === 'tigre') skinCol = '#' + new THREE.Color(skinCol).lerp(new THREE.Color('#d8842e'), 0.6).getHexString();
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
  if (!f.snout && !beast) { const eL = ear(-1), eR = ear(1); P.head.add(eL, eR); if (f.ears || f.animalEars) FEAT.push(eL, eR); }
  if (beast) beastHead(P.head, beast, skinCol, GD.RACES[race].eyes[look.eye_color] || '#e8b83a', hs, fem, ft);
  else if (f.muzzle) { const mz = at(ball(0.075 * hs, toon(shade(skinCol, 1.12)), 16, 12), 0, -0.05 * hs, 0.12 * hs); mz.scale.set(1, 0.75, 1.1); P.head.add(ft(mz), ft(at(ball(0.025, toon('#222'), 10, 8), 0, -0.02 * hs, 0.2 * hs))); }
  if (race === 'draconato') dragonHead(P.head, skinCol, GD.RACES[race].eyes[look.eye_color] || '#ffcc33', hs, fem, ft, (look.face || 0) % 4);
  else if (f.snout) {
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
  if (race === 'draconato') { const dk = toon(shade(skinCol, 0.55)); for (let i = 0; i < 5; i++) { const sp = at(cone(0.03, 0.1 - i * 0.008, dk, 4), 0, 0.62 - i * 0.11, -0.135 - Math.sin(i / 4 * Math.PI) * 0.02); sp.rotation.x = -1.25; sp.scale.x = 0.5; P.torso.add(ft(sp)); }
    for (const sd of [-1, 1]) for (let i = 0; i < 2; i++) { const sp = at(cone(0.028, 0.09, dk, 4), sd * (0.2 + i * 0.045), 0.64 - i * 0.02, -0.02); sp.rotation.z = -sd * (0.5 + i * 0.5); sp.scale.z = 0.6; P.torso.add(ft(sp)); }
    if (P.tail) { while (P.tail.children.length) P.tail.remove(P.tail.children[0]); const sm = toon(skinCol), cr = toon('#' + new THREE.Color(skinCol).lerp(new THREE.Color('#e6d3a8'), 0.72).getHexString()); let p = P.tail;
      for (let i = 0; i < 8; i++) { const r = 0.085 * Math.pow(0.78, i) + 0.008, L = 0.15 - i * 0.006, seg = at(G(), 0, 0, i ? -(0.15 - (i - 1) * 0.006) : 0); seg.rotation.x = i === 0 ? 0.75 : i < 3 ? -0.05 : -0.26; p.add(seg);
        const c = at(capsule(r, L, sm, 8), 0, 0, -L / 2); c.rotation.x = Math.PI / 2; seg.add(c); const u = at(capsule(r * 0.8, L, cr, 8), 0, -r * 0.3, -L / 2); u.rotation.x = Math.PI / 2; seg.add(u);
        if (i < 7) { const sp = at(cone(r * 0.4, r * 1.3, dk, 4), 0, r * 1.05, -L / 2); sp.rotation.x = -0.5; sp.scale.x = 0.5; seg.add(sp); } p = seg; } } }
  if (beast && P.tail) { if (beast === 'crocodilo') P.tail.scale.set(1.7, 1.4, 1.15); else if (beast === 'leao') { let p = P.tail; while (p.children.find(c => c.isGroup)) p = p.children.find(c => c.isGroup); p.add(at(ball(0.06, toon(shade(skinCol, 0.5)), 8, 6), 0, 0, -0.14)); P.tail.scale.set(0.6, 0.6, 1.25); } else if (beast === 'tigre') P.tail.scale.set(0.7, 0.7, 1.3); }
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
const WGLB = { duplas: ['w_sword', 'w_sword', 'w_sword_2', 'w_sword_big', 'w_sword_big', 'w_sword_golden'], punhal: ['w_dagger'], espada: ['w_sword', 'w_sword', 'w_sword_2', 'w_sword_big', 'w_sword_big', 'w_sword_golden'], espadao: ['w_claymore'], machado: ['w_axe', 'w_axe', 'w_axe_double'], lanca: ['w_spear'], adaga: ['w_dagger'], martelo: ['w_hammer_double'],
  escudo: ['w_shield_round', 'w_shield_round', 'w_shield_heater', 'w_shield_heater', 'w_shield_heater', 'w_shield_celtic_golden'] };
const WLEN = { duplas: 1.0, punhal: 0.46, espada: 1.0, espadao: 1.45, machado: 1.1, lanca: 2.4, adaga: 0.42, martelo: 1.05 };
const WMAT = new Map();
const KAURA = { espada: '#ffd75a', espadao: '#ff6a2a', machado: '#ff3a2a', lanca: '#7ad0ff', arco: '#7aff9a', adaga: '#c03aff', cajado: '#5a8aff', punhos: '#ffb03a', martelo: '#3ad8c8' };
function swapWeapon(m, holder, name, len, g, relic, shield, neon) {
  if (name === 'w_sword_2') name = 'w_sword';
  loadGLB(name).then(gl => {
    if (!holder.parent || !m.gearParts.includes(holder)) return;
    const src = gl.scene.clone(true), b = new THREE.Box3().setFromObject(src), h = shield ? Math.max(b.max.y - b.min.y, b.max.x - b.min.x) : b.max.y - b.min.y, k = len / h;
    src.scale.setScalar(k); if (shield) { src.position.set(0, -(b.max.y + b.min.y) / 2 * k, 0.02); }
    const en = m.enc || 0, ET = GD.ENC_TIER(en), ecol = ET ? new THREE.Color(ET.c).getHex() : 0x3a8aff;
    src.traverse(o => { if (!o.isMesh) return; o.castShadow = true; const key = o.material.name + ':' + g + ':' + (shield ? 's' : m.weaponKind) + ':' + (shield ? 0 : en >= 4 ? ecol : 0) + (relic ? 'r' : '') + (neon || '');
      if (!WMAT.has(key)) { const mt = o.material.clone(); mt.metalness = Math.min(mt.metalness, 0.6); mt.envMapIntensity = 1.2; const metal = /metal|steel|iron|blade|silver|gold/i.test(mt.name) || mt.metalness > 0.3;
        if (metal && g >= 2 && !shield) { mt.emissive = new THREE.Color(relic ? '#ffd75a' : KAURA[m.weaponKind] || GLOW[g]); mt.emissiveIntensity = 0.18 + g * 0.06; }
        if (metal && g >= 3 && shield) { mt.emissive = new THREE.Color(GLOW[g]); mt.emissiveIntensity = 0.08; }
        if (neon && !shield) { if (metal) { mt.color = new THREE.Color('#d8f8ff'); mt.emissive = new THREE.Color(neon); mt.emissiveIntensity = 1.6; mt.metalness = 0.3; mt.roughness = 0.15; } else { mt.color = new THREE.Color('#1a1e2a'); mt.metalness = 0.8; mt.roughness = 0.3; mt.emissive = new THREE.Color(neon); mt.emissiveIntensity = 0.12; } }
        if (metal && !shield && ET) { mt.emissive = new THREE.Color(ecol); mt.emissiveIntensity = 0.5 + ET.k * 0.4 + (en % 3) * 0.15; }
        WMAT.set(key, mt); }
      o.material = WMAT.get(key); });
    [...holder.children].forEach(c => { if (!c.isSprite) holder.remove(c); }); holder.add(src);
    if (!shield) { const tip = new THREE.Object3D(); tip.position.y = len * 0.88; holder.add(tip); m.weaponTip = tip; }
  }).catch(() => {});
}
export function setGear(m, weaponId, armorId, equip) {
  const P = m.P, fem = m.o.gender === 'f'; equip = equip || m.o.equip || {}; m.o.equip = equip;
  (m.gearParts || []).forEach(x => x.parent && x.parent.remove(x)); m.gearParts = []; m.weaponTip = null; m.arrowInHand = null;
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
      // aljava nas costas e a flecha que aparece na mão ao puxar
      { const qv = G(); qv.add(tube(0.05, 0.04, 0.5, toon('#5a3a20'), 10)); for (let i = 0; i < 4; i++) { qv.add(at(tube(0.006, 0.006, 0.26, toon('#d8c8a0'), 4), (i % 2 - 0.5) * 0.04, 0.34, (i > 1 ? 1 : -1) * 0.02), at(cone(0.016, 0.05, toon(['#c83a3a', '#e8e8e8'][i % 2]), 4), (i % 2 - 0.5) * 0.04, 0.46, (i > 1 ? 1 : -1) * 0.02)); } qv.rotation.z = -0.5; add(P.torso, at(qv, 0.07, 0.36, -0.2));
        const ar = G(); ar.add(at(tube(0.006, 0.006, 0.7, toon('#d8c8a0'), 4), 0, 0.3, 0), at(cone(0.02, 0.07, blade, 4), 0, 0.68, 0)); ar.visible = false; add(H, ar); m.arrowInHand = ar; }
    } else if (k === 'cajado') {
      const s = G(); s.add(at(tube(0.026, 0.032, 1.7, wood, 8), 0, 0.3, 0));
      const orb = at(new THREE.Mesh(new THREE.IcosahedronGeometry(0.1, 2), new THREE.MeshStandardMaterial({ color: ['#88f', '#c6f', '#6cf', '#5af', '#f55', '#e6f'][g], emissive: [0x2222aa, 0x6622aa, 0x2288cc, 0x2a6aff, 0xff2a2a, 0xb04aff][g], emissiveIntensity: 0.9, roughness: 0.2 })), 0, 1.2, 0);
      s.add(orb, at(new THREE.Mesh(new THREE.TorusGeometry(0.12, 0.016, 8, 20), gold), 0, 1.2, 0)); add(H, s); m.orb = orb;
    } else if (k === 'cetro') { // cetro de uma mão: haste curta com cristal — deixa a outra mão livre para a égide
      const s = G(); s.add(at(tube(0.02, 0.026, 0.62, gold, 8), 0, 0.22, 0)); const orb = at(new THREE.Mesh(new THREE.OctahedronGeometry(0.085, 0), new THREE.MeshStandardMaterial({ color: ['#88f', '#c6f', '#6cf', '#5af', '#f55', '#e6f'][g], emissive: [0x2222aa, 0x6622aa, 0x2288cc, 0x2a6aff, 0xff2a2a, 0xb04aff][g], emissiveIntensity: 1.4, roughness: 0.15 })), 0, 0.64, 0); orb.scale.y = 1.5;
      s.add(orb, at(new THREE.Mesh(new THREE.TorusGeometry(0.07, 0.012, 6, 16), gold), 0, 0.52, 0)); s.children.at(-1).rotation.x = Math.PI / 2; s.rotation.x = 1.9; add(H, s); m.orb = orb;
    } else if (k === 'punhal') {
      const s = G(); s.add(at(tube(0.018, 0.018, 0.12, wood, 8), 0, 0, 0), at(new THREE.Mesh(bladeGeo(0.36, 0.055), blade), 0, 0.06, -0.008)); s.rotation.x = Math.PI / 2; add(H, s);
    } else if (k === 'duplas') {
      [H, HL].forEach(h => { const s = G(); s.add(at(tube(0.022, 0.022, 0.18, wood, 8), 0, -0.02, 0), at(ball(0.03, gold, 10, 8), 0, -0.12, 0)); const bl = at(new THREE.Mesh(bladeGeo(0.8, 0.065), blade), 0, 0.1, -0.009); bl.castShadow = true; s.add(bl); s.rotation.x = 2.0; add(h, s); });
    } else if (k === 'garras') {
      [H, HL].forEach(h => { const s = G(); s.add(at(ball(0.07, toon(ARMOR_COL.pesada[g], { metal: 0.6 }), 10, 8), 0, 0, 0)); for (let i = -1; i <= 1; i++) { const c = at(new THREE.Mesh(bladeGeo(0.3, 0.03), blade), i * 0.035, -0.02, 0.05); c.rotation.x = Math.PI / 2 + 0.25; c.rotation.z = i * 0.12; s.add(c); } add(h, s); });
    } else if (k === 'punhos') {
      [H, HL].forEach(h => add(h, ball(0.075, toon(ARMOR_COL.pesada[g], { metal: 0.6, emissive: GLOW[g], ei: g >= 3 ? 0.4 : 0 }), 12, 10)));
    } else if (k === 'martelo') {
      const s = G(); s.add(at(tube(0.028, 0.028, 0.9, wood, 8), 0, 0.25, 0)); const hd = at(M(new THREE.CylinderGeometry(0.075, 0.075, 0.24, 12), blade), 0, 0.66, 0); hd.rotation.z = Math.PI / 2; s.add(hd); s.rotation.x = Math.PI / 2; add(H, s);
    }
    m.weaponKind = k;
    // troca a arma procedural pelo modelo 3D (Quaternius Medieval Weapons, CC0) quando carregar
    // arma lendária modelada em código: entra no lugar da versão comum
    const cw = w.model && customWeapon(w.model);
    if (cw) { const holder = m.gearParts.filter(x => x.parent === H && !x.isSprite); holder.forEach((hg, i) => { const o = i ? customWeapon(w.model) : cw; [...hg.children].forEach(c => hg.remove(c)); hg.add(o); const tp = o.getObjectByName('tip'); if (tp && !i) m.weaponTip = tp; }); }
    else { const list = WGLB[k]; if (list) { const holder = m.gearParts.filter(x => x.parent === H || ((k === 'adaga' || k === 'duplas') && x.parent === HL)).filter(x => !x.isSprite); holder.forEach(hg => swapWeapon(m, hg, list[Math.min(g, list.length - 1)], WLEN[k], g, w.relic, false, w.neon)); } }
    if (w.neon) { const nc = new THREE.Color(w.neon), sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex(), color: nc, blending: THREE.AdditiveBlending, transparent: true, depthWrite: false, opacity: 0.7 })); sp.material.opacity = 0.45; sp.scale.setScalar(0.5); sp.position.set(0, (WLEN[k] || 1) * 0.6, 0); add(H, sp); }
    // brilho do encantamento: +4 azul, +7 carmesim, +10 dourado, +13 abissal, +16 celestial — cada nível mais forte
    const en = m.enc || 0, T = GD.ENC_TIER(en);
    if (T) { const col = new THREE.Color(T.c), ei = 0.45 + T.k * 0.35 + (en % 3) * 0.12;
      for (const part of m.gearParts) { if (part.parent !== H && part.parent !== HL) continue; part.traverse(o => { if (o.isMesh && o.material && o.material.emissive && !o.userData.outline && !['gold', 'grip', 'gem'].includes(o.material.name)) { o.material = o.material.clone(); o.material.emissive = col.clone(); o.material.emissiveIntensity = o.material.name === 'blade' ? ei * 0.35 : ei; } }); }
      const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex(), color: col, blending: THREE.AdditiveBlending, transparent: true, depthWrite: false, opacity: Math.min(0.85, 0.4 + T.k * 0.09) })); sp.scale.setScalar(0.42 + T.k * 0.08 + (en % 3) * 0.03); sp.position.set(0, 0.35, 0); add(H, sp); m.encGlow = sp;
      if (T.k >= 3) { const sp2 = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex(), color: new THREE.Color(T.c2), blending: THREE.AdditiveBlending, transparent: true, depthWrite: false, opacity: 0.6 })); sp2.scale.setScalar(0.35 + T.k * 0.12); sp2.position.set(0, (WLEN[k] || 1) * 0.6, 0); add(H, sp2); m.encGlow2 = sp2; } }
  } else m.weaponKind = null;
  // peças extras: escudo, elmo, luvas e botas
  const E = (slot) => GD.ITEMS[equip[slot]];
  // set lendário: cristais nos ombros, peito, elmo e joelhos, frisos de prata e gema no cinto — tudo preso aos ossos, na escala do corpo
  { const sIt = ['armadura', 'elmo', 'luvas', 'botas'].map(E).filter(it => it && it.set), S0 = sIt[0] && GD.LEGEND_SETS[sIt[0].set]; if (S0) { const C = S0.cores;
    const cry = new THREE.MeshStandardMaterial({ color: C.cristal || '#5a3cff', emissive: C.brilho, emissiveIntensity: 0.3, roughness: 0.12, metalness: 0.1, flatShading: true, transparent: true, opacity: 0.92 }), silver = new THREE.MeshStandardMaterial({ color: C.detalhe, metalness: 1, roughness: 0.36 }), plate = new THREE.MeshStandardMaterial({ color: C.principal, metalness: 0.9, roughness: 0.42 });
    const shard = (h, r) => M(new THREE.ConeGeometry(r, h, 5), cry, false), cluster = (n, h, spread) => { const g = G(); for (let i = 0; i < n; i++) { const k = i - (n - 1) / 2, c = shard(h * (1 - Math.abs(k) * 0.22), h * 0.2); c.position.set(k * spread, h * 0.45 * (1 - Math.abs(k) * 0.2), 0); c.rotation.z = -k * 0.32; g.add(c); } return g; };
    const W = m.glbMode && m.WS && m.WS.chest ? m.WS : null, DS = THREE.DoubleSide; plate.side = DS; silver.side = DS;
    const dark = new THREE.MeshStandardMaterial({ color: C.sombra || '#10142c', metalness: 0.5, roughness: 0.6, side: DS });
    // placa curva (arco de cilindro) com frisos de prata em cima e embaixo
    const arc = (rt, rb, h, ang, mat = plate) => M(new THREE.CylinderGeometry(rt, rb, h, 14, 1, true, -ang, ang * 2), mat, false);
    const rimmed = (rt, rb, h, ang) => { const g = G(); g.add(arc(rt, rb, h, ang)); const a = arc(rt * 1.03, rt * 1.03, h * 0.09, ang, silver); a.position.y = h / 2; const b = arc(rb * 1.03, rb * 1.03, h * 0.09, ang, silver); b.position.y = -h / 2; g.add(a, b); return g; };
    const dome = (r, mat = plate) => M(new THREE.SphereGeometry(r, 16, 10, 0, Math.PI * 2, 0, Math.PI * 0.52), mat, false);
    if (W) {
      if (E('armadura')?.set) {
        // ombreiras em três lâminas sobrepostas, com friso e cristais
        [[W.shL, 1], [W.shR, -1]].forEach(([so, sd]) => { const g = G(); [[0.115, 0.03, 0.0, 1], [0.1, -0.035, 0.02, 0.92], [0.088, -0.09, 0.03, 0.85]].forEach(([r, y, x, k]) => { const d = dome(r); d.scale.set(1.05, 0.62, 1.1 * k); d.position.set(sd * x, y, 0); d.rotation.z = -sd * 0.42; const rm = M(new THREE.TorusGeometry(r * 0.985, 0.008, 6, 24), silver, false); rm.rotation.set(Math.PI / 2, 0, 0); rm.scale.set(1.05, 1.1 * k, 1); rm.position.set(sd * x, y - 0.004, 0); const h = G(); h.add(d); rm.rotation.y = 0; const rr = G(); rr.add(rm); rr.rotation.z = -sd * 0.42; rr.position.set(0, 0, 0); g.add(d, rr); });
          const cl = cluster(3, 0.15, 0.04); cl.position.set(sd * 0.01, 0.07, -0.01); cl.rotation.z = -sd * 0.5; g.add(cl); g.position.set(sd * 0.035, 0.035, 0); add(so, g); });
        // peitoral: placa bombeada, gola, divisas de prata e cristais no centro
        { const g = G(), cp = M(new THREE.SphereGeometry(0.2, 20, 12, -Math.PI * 0.5, Math.PI, Math.PI * 0.2, Math.PI * 0.56), plate, false); cp.rotation.y = Math.PI / 2 * 0 ; cp.scale.set(1.0, 1.02, 0.72); cp.rotation.y = -Math.PI / 2 + Math.PI / 2; g.add(cp);
          const bk = M(new THREE.SphereGeometry(0.2, 20, 12, Math.PI * 0.5, Math.PI, Math.PI * 0.2, Math.PI * 0.56), plate, false); bk.scale.set(1.0, 1.02, 0.62); g.add(bk);
          const col = M(new THREE.TorusGeometry(0.085, 0.016, 8, 24), silver, false); col.rotation.x = Math.PI / 2; col.position.set(0, 0.165, 0); col.scale.set(1.15, 1, 1); g.add(col);
          [-1, 1].forEach(sd => { const v = M(new THREE.BoxGeometry(0.15, 0.014, 0.012), silver, false); v.position.set(sd * 0.065, 0.02, 0.137); v.rotation.z = sd * 0.62; v.rotation.y = sd * 0.35; g.add(v); const v2 = M(new THREE.BoxGeometry(0.12, 0.012, 0.012), silver, false); v2.position.set(sd * 0.06, -0.07, 0.13); v2.rotation.z = sd * 0.5; v2.rotation.y = sd * 0.35; g.add(v2);
            const dm = M(new THREE.OctahedronGeometry(0.022, 0), cry, false); dm.scale.set(1, 1.3, 0.4); dm.position.set(sd * 0.11, 0.09, 0.115); g.add(dm); });
          const cc = cluster(3, 0.085, 0.03); cc.position.set(0, 0.03, 0.148); cc.rotation.x = 0.12; g.add(cc); g.position.set(0, 0.0, 0.005); add(W.chest, g); }
        // cinto com gema e saiote de placas (frente, lados e costas)
        { const g = G(), belt = M(new THREE.TorusGeometry(0.155, 0.02, 8, 28), silver, false); belt.rotation.x = Math.PI / 2; belt.scale.set(1.08, 0.82, 1.4); belt.position.y = 0.075; g.add(belt);
          const bg = M(new THREE.OctahedronGeometry(0.034, 0), cry, false); bg.scale.set(1, 1.25, 0.45); bg.position.set(0, 0.075, 0.135); const bs = M(new THREE.OctahedronGeometry(0.048, 0), silver, false); bs.scale.set(1, 1.25, 0.3); bs.position.set(0, 0.075, 0.126); g.add(bg, bs);
          [[0, 0.13, 0.2, 0.11], [1.15, 0.125, 0.17, 0.13], [-1.15, 0.125, 0.17, 0.13], [Math.PI, 0.13, 0.17, 0.14]].forEach(([a, r, h, w]) => { const t = rimmed(r, r * 1.08, h, w / r * 0.5 + 0.25); t.rotation.y = a; t.position.y = 0.06 - h / 2; t.scale.set(1.12, 1, 0.88); g.add(t); });
          add(W.pelvis, g); }
        // coxotes
        [[W.thL, 1], [W.thR, -1]].forEach(([so]) => { if (!so) return; const t = rimmed(0.094, 0.078, 0.27, 1.7); t.position.set(0, -0.26, 0.008); add(so, t); });
      }
      if (E('luvas')?.set) [W.faL, W.faR].forEach(so => { if (!so) return; const cf = G(); cf.add(M(new THREE.CylinderGeometry(0.058, 0.046, 0.15, 14, 1, true), plate, false)); const r1 = M(new THREE.TorusGeometry(0.059, 0.008, 6, 22), silver, false); r1.rotation.x = Math.PI / 2; r1.position.y = 0.075; const r2 = M(new THREE.TorusGeometry(0.047, 0.007, 6, 22), silver, false); r2.rotation.x = Math.PI / 2; r2.position.y = -0.075;
        const hc = cluster(3, 0.055, 0.018); hc.position.set(0, -0.03, 0.05); hc.rotation.x = 0.3; cf.add(r1, r2, hc); cf.position.set(0, -0.14, 0.01); cf.rotation.x = -0.12; add(so, cf); });
      if (E('botas')?.set) [[W.caL, W.ftL], [W.caR, W.ftR]].forEach(([ca, ft]) => { if (!ca) return;
        const kn = G(), kd = dome(0.062); kd.rotation.x = Math.PI / 2; kd.scale.set(1, 0.8, 1.15); const kr = M(new THREE.TorusGeometry(0.062, 0.007, 6, 20), silver, false); const ks = shard(0.07, 0.016); ks.position.set(0, 0.05, 0.03); kn.add(kd, kr, ks); kn.position.set(0, 0.0, 0.045); add(ca, kn);
        const gr = rimmed(0.07, 0.056, 0.3, 1.5); gr.position.set(0, -0.22, 0.006); add(ca, gr); const rdg = M(new THREE.BoxGeometry(0.012, 0.28, 0.012), silver, false); rdg.position.set(0, -0.22, 0.068); add(ca, rdg); const gc = cluster(3, 0.075, 0.022); gc.position.set(0, -0.17, 0.07); gc.rotation.x = 0.1; add(ca, gc);
        if (ft) { const toe = dome(0.058); toe.scale.set(1, 0.75, 1.55); toe.position.set(0, -0.065, 0.085); const st = M(new THREE.TorusGeometry(0.056, 0.008, 6, 18, Math.PI), silver, false); st.position.set(0, -0.055, 0.03); add(ft, toe); add(ft, st); } });
    } else if (E('armadura')?.set) { [-1, 1].forEach(sd => { const cl = add(P.torso, at(cluster(3, 0.17, 0.045), sd * 0.25, 0.62, -0.01)); cl.rotation.z = -sd * 0.45; }); add(P.torso, at(cluster(3, 0.1, 0.035), 0, 0.4, 0.175)); }
    if (E('elmo')?.set) { const cr = add(P.head, at(cluster(5, 0.2, 0.028), 0, 0.14, 0.02)); cr.rotation.y = Math.PI / 2; add(P.head, at(M(new THREE.TorusGeometry(0.172, 0.009, 6, 28), silver, false), 0, 0.06, 0)).rotation.x = Math.PI / 2; }
    m.legendSet = sIt.length >= 4 ? S0 : null; } else m.legendSet = null; }
  // traje futurista (Era Neon): faixas de luz no peito, cinto, braços e pernas; visor holográfico
  { const nItems = ['armadura', 'elmo', 'luvas', 'botas'].map(E).filter(it => it && it.neon); if (nItems.length) { const nc = nItems[0].neon, gm = new THREE.MeshBasicMaterial({ color: nc, toneMapped: false }), gm2 = new THREE.MeshBasicMaterial({ color: '#ff3ad8', toneMapped: false });
    if (E('armadura')?.neon) { add(P.torso, at(M(new THREE.TorusGeometry(0.2, 0.02, 6, 28), gm, false), 0, 0.44, 0)).scale.set(1.05, 0.78, 1); add(P.torso, at(M(new THREE.TorusGeometry(0.2, 0.024, 6, 28), gm2, false), 0, 0.05, 0)).scale.set(1.1, 0.8, 1);
      add(P.torso, at(M(new THREE.TorusGeometry(0.21, 0.016, 6, 28), gm, false), 0, 0.25, 0)).scale.set(1.08, 0.78, 1); [-1, 1].forEach(sd => { add(P.torso, at(M(new THREE.SphereGeometry(0.03, 10, 8), gm, false), sd * 0.2, 0.56, 0.06)); const st = add(P.torso, at(M(new THREE.BoxGeometry(0.022, 0.36, 0.022), gm, false), sd * 0.07, 0.3, 0.16)); st.rotation.z = sd * 0.12; });
      [P.armL, P.armR].forEach(A => add(A.s, at(M(new THREE.TorusGeometry(0.072, 0.016, 6, 20), gm, false), 0, -0.14, 0)).rotation.x = Math.PI / 2); }
    if (E('luvas')?.neon) [P.armL, P.armR].forEach(A => add(A.fa, at(M(new THREE.TorusGeometry(0.06, 0.016, 6, 20), gm, false), 0, -0.2, 0)).rotation.x = Math.PI / 2);
    if (E('botas')?.neon && !m.glbMode) [P.legL, P.legR].forEach(L => add(L.sh, at(M(new THREE.TorusGeometry(0.075, 0.01, 6, 20), gm, false), 0, -0.28, 0)).rotation.x = Math.PI / 2);
    if (E('botas')?.neon && m.glbMode) [-1, 1].forEach(sd => { const r = add(P.hips, at(M(new THREE.TorusGeometry(0.1, 0.012, 6, 20), gm2, false), sd * 0.1, -0.12, 0)); r.rotation.x = Math.PI / 2; });
    if (E('elmo')?.neon) { const vis = add(P.head, at(M(new THREE.CylinderGeometry(0.175, 0.17, 0.07, 28, 1, true, -1.15, 2.3), new THREE.MeshBasicMaterial({ color: nc, transparent: true, opacity: 0.75, side: THREE.DoubleSide, toneMapped: false, blending: THREE.AdditiveBlending, depthWrite: false }), false), 0, 0.03, 0.01)); vis.userData.neonVisor = 1;
      add(P.head, at(M(new THREE.TorusGeometry(0.175, 0.008, 6, 30), gm, false), 0, 0.075, 0)).rotation.x = Math.PI / 2; [-1, 1].forEach(sd => add(P.head, at(M(new THREE.SphereGeometry(0.022, 8, 6), gm2, false), sd * 0.17, 0.03, -0.02))); } } }
  const sh = E('escudo');
  if (sh && sh.kind === 'egide') { // escudo mágico: disco de energia com runas, flutuando no antebraço
    const g = sh.grade, col = ['#8888ff', '#c66aff', '#66ccff', '#5aaaff', '#ff5a5a', '#e66aff'][g], grp = G();
    const disk = new THREE.Mesh(new THREE.CircleGeometry(0.3, 28), new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.28, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }));
    const rim = new THREE.Mesh(new THREE.TorusGeometry(0.3, 0.012, 6, 36), new THREE.MeshBasicMaterial({ color: col, toneMapped: false })), in2 = new THREE.Mesh(new THREE.TorusGeometry(0.18, 0.008, 6, 6), new THREE.MeshBasicMaterial({ color: '#ffffff', toneMapped: false })), core = new THREE.Mesh(new THREE.OctahedronGeometry(0.045), new THREE.MeshBasicMaterial({ color: '#ffffff', toneMapped: false }));
    grp.add(disk, rim, in2, core); grp.rotation.y = -Math.PI / 2; add(P.armL.fa, at(grp, -0.16, -0.16, 0)); m.egide = in2; }
  else if (sh) { const g = sh.grade, sm = toon(sh.relic ? '#6a7a6a' : ARMOR_COL.pesada[g], { metal: 0.5 }), tm = toon(TRIM[g]);
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
export function playAttack(m, kind) { m.anim.atk = performance.now(); m.anim.atkAt = m.anim.atk; m.anim.kind = kind; if (m.setExpr && Math.random() < 0.6) m.setExpr('angry', 1200); }

export function setExpr(m, e, ms) { if (m.glb) return; return setExpr_(m, e, ms); }

// ================= modelos 3D realistas (GLB) =================
export const GLB = { on: true };
const HAIR_M = ['simpleparted', 'buzzed', 'long', 'slickback', 'bob', 'buzzed'], HAIR_F = ['long', 'buns', 'bob', 'buzzedfemale', 'simpleparted', 'buns'];
const OUTFIT_OF = { pesada: 'ranger', leve: 'ranger', robe: 'peasant' };
function outfitFor(m, a) { const fem = m.o.gender === 'f'; if (!a) return 'peasant'; if (fem) return OUTFIT_OF[a.kind]; return a.kind === 'pesada' ? 'knight' : a.kind === 'leve' ? 'ranger' : a.grade >= 4 ? 'noble' : 'wizard'; }
function helmFor(m, h) { if (!h) return null; if (h.set) return 'helm_knight'; if (h.relic) return 'helm_crown'; if (h.kind === 'pesada' && m.o.gender !== 'f') return 'helm_knight'; return null; }
const GRADE_TINT = ['#ffffff', '#e8dcc4', '#d6e2f0', '#cfe0ff', '#ffd2d2', '#f0dcff'], HEAVY_TINT = ['#b8c0c8', '#a8b4c0', '#c0c8d4', '#a8c4e8', '#e0b0b0', '#d8c8f0'];
const BASE_SKIN = new THREE.Color('#c49470'), RACE_BODY = { draconato: 'dragonita' }, BODY_SKIN = { dragonita: new THREE.Color('#b0602c') };
export function upgradeGLB(m) {
  if (m.glb || m.glbPending) return; m.glbPending = true;
  const o = m.o, fem = o.gender === 'f', f = (GD.RACES[m.race] || {}).feat || {}, look = m.look;
  const bv = fem || f.snout ? 0 : (look.beard ?? (f.beard ? 2 : 0)), beard = bv === 2 ? 'hair_beard' : bv === 1 ? 'hair_moustache' : null;
  const a = GD.ITEMS[o.armor];
  const body = RACE_BODY[m.race]; // raças com corpo próprio (modelo 3D inteiro, sem roupa humana por cima)
  createCharacter(body ? { gender: 'm', body } : { gender: fem ? 'f' : 'm', outfit: outfitFor(m, a), hair: f.noHair ? null : (fem ? HAIR_F : HAIR_M)[look.hair || 0] })
    .then(async C => { C.outfitKind = outfitFor(m, a); if (beard && !body) await setPart(C, 'beard', beard); if (m.disposed) return; applyGLB(m, C); })
    .catch(e => { m.glbPending = false; console.warn('GLB', e); });
}
// padrão procedural sobre a pele: 1 escamas, 2 listras, 3 pelagem
function skinPattern(mat, kind, sk) {
  mat.roughness = kind === 1 ? 0.5 : 0.9; mat.metalness = kind === 1 ? 0.15 : 0;
  mat.onBeforeCompile = sh => { sh.fragmentShader = sh.fragmentShader.replace('#include <map_fragment>', `#include <map_fragment>
    #ifdef USE_MAP
    { vec2 uvp = vMapUv; float lum0 = dot(diffuseColor.rgb, vec3(0.3333)); diffuseColor.rgb = vec3(${sk.r.toFixed(3)}, ${sk.g.toFixed(3)}, ${sk.b.toFixed(3)}) * (0.62 + lum0 * 0.75); ${kind === 1 ? `vec2 q = uvp * vec2(64.0, 76.0); q.x += step(1.0, mod(q.y, 2.0)) * 0.5; vec2 f = fract(q) - vec2(0.5, 0.42); float d = length(f * vec2(1.0, 1.3)); diffuseColor.rgb *= mix(0.5, 1.12, smoothstep(0.52, 0.26, d)) * (0.9 + 0.2 * fract(sin(dot(floor(q), vec2(12.9898, 78.233))) * 43758.5453));`
      : kind === 2 ? `float w = sin(uvp.y * 150.0 + sin(uvp.x * 37.0) * 2.6 + sin(uvp.x * 9.0) * 3.0); float st = smoothstep(0.55, 0.8, w); diffuseColor.rgb = mix(diffuseColor.rgb, diffuseColor.rgb * 0.12, st);`
      : `float n = fract(sin(dot(floor(uvp * vec2(420.0, 90.0)), vec2(12.9898, 78.233))) * 43758.5453); diffuseColor.rgb *= 0.82 + 0.3 * n;`} }
    #endif`); };
  mat.customProgramCacheKey = () => 'skinpat' + kind + sk.getHexString(); mat.needsUpdate = true;
}
function ownMats(obj) { obj.traverse(o => { if (o.isMesh && o.material && !o.userData.ownMat) { o.material = o.material.clone(); o.userData.ownMat = 1; } }); }
function tintGLB(m) {
  const C = m.glb, sk = new THREE.Color(m.skinCol), hc = new THREE.Color(GD.HAIR_COLORS[m.look.hair_color] || '#333');
  const skinK = new THREE.Color(sk.r / BASE_SKIN.r, sk.g / BASE_SKIN.g, sk.b / BASE_SKIN.b);
  C.model.traverse(o => { if (!o.isMesh) return; const nm = (o.material.name || ''); ownMats(o);
    if (/Superhero|Regular/.test(nm)) { o.material.color.copy(skinK); const pat = m.race === 'draconato' ? 1 : m.race === 'beastman' ? ({ crocodilo: 1, tigre: 2 }[['leao', 'tigre', 'lobo', 'crocodilo'][(m.look.face || 0) % 4]] || 3) : 0; if (pat) { o.material.color.set('#ffffff'); skinPattern(o.material, pat, sk); } }
    else if (/Hair/.test(nm)) o.material.color.copy(hc).multiplyScalar(1.6);
    else if (C.customBody && /Dragonita/.test(nm)) { const b0 = BODY_SKIN[C.customBody]; o.material.color.setRGB(Math.min(1.6, sk.r / b0.r), Math.min(1.6, sk.g / b0.g), Math.min(1.6, sk.b / b0.b)).lerp(new THREE.Color('#ffffff'), 0.25); } });
}
async function glbOutfit(m, a, equip) {
  const C = m.glb, kind = outfitFor(m, a);
  if (C.customBody) return; // corpo próprio: ainda não veste as roupas feitas para o corpo humano
  if (C.outfitKind !== kind) { C.outfitKind = kind; await setOutfit(C, kind); ownMats(C.model); tintGLB(m); }
  const tint = new THREE.Color(a ? (a.set ? '#6a86ff' : a.neon ? '#8a96b8' : (a.kind === 'pesada' ? HEAVY_TINT : GRADE_TINT)[a.grade]) : '#ffffff');
  // set lendário: o desenho original da armadura vira máscara — partes claras (frisos, rebites, bordas) ficam em prata e o resto em azul do set
  if (a && a.set) { const S0 = GD.LEGEND_SETS[a.set], cA = new THREE.Color(S0.cores.principal).multiplyScalar(0.62), cB = new THREE.Color(S0.cores.principal).multiplyScalar(1.05); for (const o of C.parts.outfit || []) { ownMats(o); const mt = o.material; if (/Superhero|Regular|Hair|Eye/.test(mt.name)) continue;
      if (mt.userData.map0) { mt.map = mt.userData.map0; mt.userData.map0 = null; } mt.color.set('#ffffff'); mt.metalness = 0.85; mt.roughness = 0.45; mt.envMapIntensity = 1.1; mt.userData.legset = a.set;
      mt.onBeforeCompile = sh => { sh.uniforms.uSetA = { value: cA }; sh.uniforms.uSetB = { value: cB }; sh.fragmentShader = 'uniform vec3 uSetA; uniform vec3 uSetB;\n' + sh.fragmentShader.replace('#include <map_fragment>', '#ifdef USE_MAP\n vec4 tx = texture2D( map, vMapUv ); float lum = dot( tx.rgb, vec3( 0.299, 0.587, 0.114 ) );\n diffuseColor.rgb = mix( uSetA * ( 0.7 + 1.6 * lum ), uSetB, smoothstep( 0.3, 0.55, lum ) );\n#else\n diffuseColor.rgb = uSetA;\n#endif'); };
      mt.customProgramCacheKey = () => 'legset:' + a.set; mt.needsUpdate = true; if (/Hood/.test(o.name)) o.visible = false; } }
  else for (const o of C.parts.outfit || []) { const mt = o.material; if (mt && mt.userData && mt.userData.legset) { mt.userData.legset = null; mt.onBeforeCompile = () => {}; mt.customProgramCacheKey = () => ''; mt.metalness = 0; mt.roughness = 1; mt.needsUpdate = true; } }
  for (const o of C.parts.outfit || []) { if (a && a.set) break; ownMats(o); if (/Ranger|Peasant/.test(o.material.name)) { o.material.color.copy(tint); if (!/Knight|Noble/.test(o.material.name)) o.material.metalness = a && a.kind === 'pesada' ? 0.25 : 0; o.material.envMapIntensity = a && a.kind === 'pesada' ? 1.2 : 0.6; } if (/Hood/.test(o.name)) o.visible = !!(equip && GD.ITEMS[equip.elmo] && GD.ITEMS[equip.elmo].kind === 'leve' && !GD.ITEMS[equip.elmo].neon); }
  const hItem = equip && GD.ITEMS[equip.elmo], helm = helmFor(m, hItem);
  if (C.helmName !== helm) { C.helmName = helm; await setPart(C, 'helm', helm); if (helm) { ownMats(C.model); if (hItem) for (const o of C.parts.helm) if (hItem.set) { o.material.color.set(new THREE.Color(GD.LEGEND_SETS[hItem.set].cores.principal).multiplyScalar(1.05)); o.material.metalness = 0.8; o.material.roughness = 0.42; } else if (!hItem.relic) o.material.color.copy(new THREE.Color(HEAVY_TINT[hItem.grade])).lerp(new THREE.Color('#ffffff'), 0.4); } }
  const hidden = !!hItem && hItem.kind !== 'robe' && !hItem.neon; (C.parts.hair || []).forEach(h => h.visible = !hidden);
  // elmo de couro = capuz do próprio traje; os outros elmos continuam sendo peças à parte
}
function applyGLB(m, C) {
  const P = m.P; m.glbPending = false;
  if (C.customBody) { for (const f of m.FEAT) f.removeFromParent(); m.FEAT.length = 0; }
  const K = 1.98 / 1.81; C.root.scale.set(m.Wd * K, m.H * K, m.Wd * K); m.root.add(C.root);
  // proporções próprias de cada raça (escala de ossos; as animações não mexem em escala)
  const RB = { anao: { Head: 1.1, hand_l: 1.18, hand_r: 1.18, upperarm_l: 1.06, upperarm_r: 1.06 }, orc: { Head: 0.94, neck_01: 0.9, upperarm_l: 1.12, upperarm_r: 1.12, hand_l: 1.15, hand_r: 1.15, spine_03: 1.06 },
    halfling: { Head: 1.16, foot_l: 1.3, foot_r: 1.3 }, gigante: { hand_l: 1.25, hand_r: 1.25, upperarm_l: 1.1, upperarm_r: 1.1, spine_03: 1.08, Head: 0.92 }, elfo: { Head: 0.96, neck_01: 1.12 }, sombrio: { Head: 0.96, neck_01: 1.1 },
    sylph: { Head: 0.98, neck_01: 1.1, foot_l: 0.85, foot_r: 0.85 }, draconato: { neck_01: 1.22, Head: 0.8, hand_l: 1.28, hand_r: 1.28, spine_03: 1.06, foot_l: 1.12, foot_r: 1.12 }, beastman: { hand_l: 1.15, hand_r: 1.15, neck_01: 0.92, spine_03: 1.05, Head: 0.8 }, nocturno: { neck_01: 1.06 } }[C.customBody ? '' : m.race] || {};
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
  { const rq = new THREE.Quaternion(), rs = new THREE.Vector3(); m.root.getWorldQuaternion(rq); m.root.getWorldScale(rs);
    const ws = bn => { const b = C.bones[bn]; if (!b) return null; const o = new THREE.Object3D(), q = new THREE.Quaternion(), sc = new THREE.Vector3(); b.add(o); b.getWorldQuaternion(q); b.getWorldScale(sc); o.quaternion.copy(q.invert().multiply(rq)); o.scale.setScalar(m.H * rs.y / ((sc.x + sc.y + sc.z) / 3)); return o; };
    m.WS = { chest: ws('spine_03'), pelvis: ws('pelvis'), shL: ws('upperarm_l'), shR: ws('upperarm_r'), thL: ws('thigh_l'), thR: ws('thigh_r'), faL: ws('lowerarm_l'), faR: ws('lowerarm_r'), caL: ws('calf_l'), caR: ws('calf_r'), ftL: ws('foot_l'), ftR: ws('foot_r') }; }
  if (!C.customBody && (m.race === 'draconato' || m.race === 'beastman')) { // garras nas pontas dos dedos e nos pés
    const cm = toon(m.race === 'draconato' ? '#2a2420' : '#3a3028');
    for (const sd of ['l', 'r']) { for (const fg of ['thumb', 'index', 'middle', 'ring', 'pinky']) { const b = C.bones[fg + '_03_' + sd] || C.bones[fg + '_02_' + sd]; if (!b) continue; const d = b.position.clone(), len = d.length() || 0.03; d.normalize(); const cl = new THREE.Mesh(new THREE.ConeGeometry(len * 0.32, len * 1.5, 5), cm); cl.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), d); cl.position.copy(d).multiplyScalar(len * 1.25); cl.castShadow = true; b.add(cl); }
    } }
  for (const f of m.FEAT) { const par = f.parent; if (!par) continue; const target = par === P.head ? head : par === P.hips ? hips : torso; target.add(f); if (target === head && RB.Head && RB.Head < 1) { f.scale.multiplyScalar(1 / RB.Head); f.position.multiplyScalar(1 / RB.Head); } } // a cabeça humana encolhe por baixo da cabeça de fera
  m.body.visible = false;
  m.P = { ...P, head, skull: head, torso, hips, armR: { hand: handR, fa: faR, s: sR }, armL: { hand: handL, fa: faL, s: sL }, hair: null, base: null, legL: { l: hips, sh: hips }, legR: { l: hips, sh: hips } };
  m.glb = C; m.glbMode = true; ownMats(C.model); tintGLB(m);
  C.root.traverse(o => o.userData.pick = m.root.userData.pick || o.userData.pick);
  const eq = m.o.equip || {}; setGear(m, m.o.weapon || eq.arma, m.o.armor || eq.armadura, eq);
  m.anim.idleClip = m.o.idle || (!m.o.npc && { orc: 'Idle_FoldArms_Loop', gigante: 'Idle_FoldArms_Loop', anao: 'Idle_Shield_Loop', mago: null }[m.race]) || (m.o.npc ? (['Idle_Loop', 'Idle_FoldArms_Loop', 'Idle_Talking_Loop'][Math.floor(Math.random() * 3)]) : 'Idle_Loop');
  if (m.onGLB) m.onGLB(m);
}
const RACE_STYLE = { humano: { clips: ['Sword_Regular_A', 'Sword_Regular_B', 'Sword_Regular_C', 'Sword_Attack'], spd: 1, ready: 'Sword_Idle' }, elfo: { clips: ['Sword_Regular_A', 'Sword_Regular_B', 'Sword_Dash'], spd: 1.18, ready: 'Sword_Idle' }, sombrio: { clips: ['Sword_Regular_B', 'Sword_Dash', 'Sword_Regular_C'], spd: 1.2, ready: 'Crouch_Idle_Loop' },
  sylph: { clips: ['Sword_Regular_A', 'Sword_Dash'], spd: 1.22, ready: 'Sword_Idle' }, halfling: { clips: ['Sword_Regular_A', 'Sword_Regular_C'], spd: 1.15, ready: 'Crouch_Idle_Loop' }, anao: { clips: ['Sword_Regular_C', 'Sword_Attack', 'Melee_Hook'], spd: 0.95, ready: 'Idle_Shield_Loop' },
  orc: { clips: ['Sword_Attack', 'Melee_Hook', 'Sword_Regular_C'], spd: 0.88, ready: 'Idle_FoldArms_Loop' }, gigante: { clips: ['Sword_Attack', 'Melee_Hook'], spd: 0.8, ready: 'Idle_FoldArms_Loop' }, beastman: { clips: ['Melee_Hook', 'Sword_Attack', 'Sword_Regular_B'], spd: 1.02, ready: 'Crouch_Idle_Loop' },
  draconato: { clips: ['Sword_Attack', 'Sword_Regular_Combo', 'Sword_Regular_C'], spd: 0.92, ready: 'Sword_Idle' }, nocturno: { clips: ['Sword_Regular_B', 'Sword_Regular_Combo', 'Sword_Dash'], spd: 1.08, ready: 'Sword_Idle' } };
const ATK_CLIPS = ['Sword_Regular_A', 'Sword_Regular_B', 'Sword_Regular_C', 'Sword_Attack'];
function animGLB(m, dt) {
  const A = m.anim, C = m.glb, t = performance.now();
  if (A.state === 'dead') { if (A.cur !== 'dead') { playClip(C, 'Death01', { once: true, fade: 0.15 }); A.cur = 'dead'; } }
  else if (A.atk >= 0 && A.atkSeen !== A.atk) {
    A.atkSeen = A.atk; const wk = m.weaponKind;
    const SK = A.kind === 'skill' ? ['Sword_Regular_Combo', 'Melee_Hook', 'Sword_Dash'].filter(n => C.clips ? true : true) : null;
    // expressão corporal por raça e por pegada: brutos golpeiam de cima e devagar, elfos cortam rápido, anões batem curto; pares de armas alternam as mãos
    const RS = RACE_STYLE[m.race] || RACE_STYLE.humano, dual = wk === 'adaga' || wk === 'duplas' || wk === 'garras', magicW = wk === 'cajado' || wk === 'cetro'; A.dualN = (A.dualN || 0) + 1;
    let clip = A.kind === 'cast' || magicW ? 'Spell_Simple_Shoot' : A.kind === 'bow' ? 'Spell_Simple_Shoot' : wk === 'punhos' || !wk ? (Math.random() < 0.5 ? 'Punch_Jab' : 'Punch_Cross')
      : wk === 'garras' ? ['Punch_Jab', 'Punch_Cross', 'Melee_Hook'][A.dualN % 3] : dual ? (A.kind === 'skill' ? 'Sword_Regular_Combo' : ['Sword_Regular_A', 'Punch_Cross', 'Sword_Regular_B', 'Melee_Hook'][A.dualN % 4])
      : A.kind === 'skill' ? ['Sword_Regular_Combo', 'Melee_Hook', 'Sword_Dash'][Math.floor(Math.random() * 3)] : RS.clips[Math.floor(Math.random() * RS.clips.length)];
    const aspd = (dual ? 1.25 : 1) * RS.spd;
    if (wk === 'arco' && C.clips && CLIP_OK(C, 'OverhandThrow')) { // arqueiro: leva a mão à aljava, pega a flecha, puxa e solta
      playClip(C, 'OverhandThrow', { once: true, fade: 0.06, speed: 2.3 }); A.cur = 'atk'; A.bowT = t + 300; A.atkEnd = t + 900; if (m.arrowInHand) m.arrowInHand.visible = true; }
    else { const act = playClip(C, clip, { once: true, fade: 0.08, speed: 1.35 * aspd }); A.cur = 'atk'; A.atkEnd = t + (act ? act.getClip().duration / (1.35 * aspd) * 1000 - 120 : 500); A.readyUntil = t + 5000; }
  }
  else if (A.cur === 'atk' && t < A.atkEnd) { if (A.bowT && t >= A.bowT) { A.bowT = 0; const act = playClip(C, 'Spell_Simple_Shoot', { once: true, fade: 0.12, speed: 1.6 }); A.atkEnd = t + (act ? act.getClip().duration / 1.6 * 1000 - 100 : 400); if (m.arrowInHand) m.arrowInHand.visible = false; } }
  else if (A.hitAt && t - A.hitAt < 60 && A.cur !== 'hit' && A.state !== 'climb') { A.hitAt = 0; if (playClip(C, Math.random() < 0.5 ? 'Hit_Chest' : 'Hit_Head', { once: true, fade: 0.06, speed: 1.4 })) { A.cur = 'hit'; A.atkEnd = t + 380; } }
  else if (A.cur === 'hit' && t < A.atkEnd) { }
  else { const want = A.state === 'mount' ? 'Sitting_Idle_Loop' : A.state === 'fly' ? (A.moving ? 'Swim_Fwd_Loop' : 'Swim_Idle_Loop') : A.state === 'climb' ? 'ClimbUp_1m' : A.state === 'swim' ? (A.moving ? 'Swim_Fwd_Loop' : 'Swim_Idle_Loop') : A.state === 'roll' ? 'Roll' : A.state === 'sprint' ? 'Sprint_Loop' : A.state === 'run' ? (A.walk ? 'Walk_Loop' : 'Jog_Fwd_Loop') : A.state === 'gather' ? 'Interact' : (A.readyUntil > t && m.weaponKind ? (m.weaponKind === 'cajado' || m.weaponKind === 'cetro' ? 'Spell_Simple_Idle_Loop' : (m.o.equip || {}).escudo ? 'Idle_Shield_Loop' : (RACE_STYLE[m.race] || RACE_STYLE.humano).ready) : (A.idleClip || 'Idle_Loop')); if (A.cur !== want) { if (playClip(C, want, { fade: 0.22, once: want === 'Roll', speed: A.state === 'run' ? 1.15 * ({ halfling: 1.3, anao: 1.18, gigante: 0.85, orc: 0.95, sylph: 1.08 }[m.race] || 1) : A.state === 'climb' ? 0.8 : want === 'Roll' ? 1.3 : 1 })) A.cur = want; else if (A.cur !== 'Jog_Fwd_Loop' && A.state !== 'idle') { playClip(C, 'Jog_Fwd_Loop', { fade: 0.2 }); A.cur = 'Jog_Fwd_Loop'; } } }
  C.mixer.update(dt);
  if (A.state === 'mount') rideLegs(m, C);
  // pegada de duas mãos: durante o golpe, a mão esquerda vai até o cabo da arma (cajado, espadão, lança, martelo)
  { const two = m.weaponKind && m.weaponTip && GD.TWO_HAND_GRIP.includes(m.weaponKind), want = two && A.cur === 'atk' && t < A.atkEnd ? 1 : 0; A.ikW = (A.ikW || 0) + (want - (A.ikW || 0)) * Math.min(1, dt * 14); if (two && A.ikW > 0.03) twoHandIK(m, C, A.ikW); }
}
const CLIP_OK = () => true;
const _a = new THREE.Vector3(), _b = new THREE.Vector3(), _c = new THREE.Vector3(), _tg = new THREE.Vector3(), _p1 = new THREE.Vector3(), _v1 = new THREE.Vector3(), _v2 = new THREE.Vector3(), _n = new THREE.Vector3(), _q = new THREE.Quaternion(), _pq = new THREE.Quaternion(), _bq = new THREE.Quaternion(), _qU = new THREE.Quaternion(), _qF = new THREE.Quaternion();
const GRIP_F = { cajado: 0.3, lanca: 0.3, espadao: 0.17, martelo: 0.32 };
function rotWorld(bone, q) { bone.parent.getWorldQuaternion(_pq); bone.getWorldQuaternion(_bq); _bq.premultiply(q); bone.quaternion.copy(_pq.invert().multiply(_bq)); bone.updateWorldMatrix(false, true); }
// pose de montaria: abre e desce as coxas para abraçar o dorso do animal e dobra as canelas para trás
const RD_rq = new THREE.Quaternion(), RD_pq = new THREE.Quaternion(), RD_bq = new THREE.Quaternion(), RD_R = new THREE.Quaternion(), RD_ax = new THREE.Vector3();
function rotW(b, rootQ, ax, ay, az, ang) { b.parent.updateWorldMatrix(true, false); b.parent.getWorldQuaternion(RD_pq); RD_bq.copy(RD_pq).multiply(b.quaternion); RD_ax.set(ax, ay, az).applyQuaternion(rootQ).normalize(); RD_R.setFromAxisAngle(RD_ax, ang); b.quaternion.copy(RD_pq.invert().multiply(RD_R).multiply(RD_bq)); }
const RD_a = new THREE.Vector3(), RD_b = new THREE.Vector3(), RD_d = new THREE.Vector3();
// aponta o osso (na direção do filho) para uma direção dada no espaço do personagem
function aimBone(b, child, rootQ, dx, dy, dz) { b.updateWorldMatrix(true, false); child.updateWorldMatrix(true, false); b.getWorldPosition(RD_a); child.getWorldPosition(RD_b); RD_b.sub(RD_a).normalize(); RD_d.set(dx, dy, dz).normalize().applyQuaternion(rootQ);
  RD_R.setFromUnitVectors(RD_b, RD_d); b.parent.getWorldQuaternion(RD_pq); RD_bq.copy(RD_pq).multiply(b.quaternion); b.quaternion.copy(RD_pq.invert().multiply(RD_R).multiply(RD_bq)); }
function rideLegs(m, C) { const B = C.bones, R = m.ride || {}, w = R.wide ?? 0.42; m.root.getWorldQuaternion(RD_rq);
  for (const sd of ['l', 'r']) { const th = B['thigh_' + sd], ca = B['calf_' + sd], ft = B['foot_' + sd]; if (!th || !ca || !ft) continue;
    th.getWorldPosition(RD_a); m.root.worldToLocal(RD_a); const s = RD_a.x >= 0 ? 1 : -1;
    aimBone(th, ca, RD_rq, s * w, -0.72, 0.52); aimBone(ca, ft, RD_rq, s * w * 0.15, -0.9, -0.42); const toe = B['ball_' + sd]; if (toe) aimBone(ft, toe, RD_rq, s * 0.12, -0.25, 0.95); } }
function twoHandIK(m, C, w) {
  const U = C.bones.upperarm_l, F = C.bones.lowerarm_l, H = C.bones.hand_l, hold = m.weaponTip.parent; if (!U || !F || !H || !hold) return;
  m.root.updateWorldMatrix(true, true); hold.getWorldPosition(_tg); m.weaponTip.getWorldPosition(_p1); _p1.sub(_tg); if (_p1.lengthSq() < 0.01) return; _tg.addScaledVector(_p1, GRIP_F[m.weaponKind] || 0.25);
  _qU.copy(U.quaternion); _qF.copy(F.quaternion);
  U.getWorldPosition(_a); F.getWorldPosition(_b); H.getWorldPosition(_c);
  const l1 = _a.distanceTo(_b), l2 = _b.distanceTo(_c); let d = Math.min(_a.distanceTo(_tg), (l1 + l2) * 0.985); d = Math.max(d, Math.abs(l1 - l2) + 0.01);
  _v1.copy(_a).sub(_b).normalize(); _v2.copy(_c).sub(_b).normalize(); const th0 = Math.acos(Math.max(-1, Math.min(1, _v1.dot(_v2)))), th1 = Math.acos(Math.max(-1, Math.min(1, (l1 * l1 + l2 * l2 - d * d) / (2 * l1 * l2))));
  _n.crossVectors(_v1, _v2); if (_n.lengthSq() < 1e-6) _n.set(0, 0, 1); _n.normalize(); _q.setFromAxisAngle(_n, th1 - th0); rotWorld(F, _q);
  H.getWorldPosition(_c); _v1.copy(_c).sub(_a).normalize(); _v2.copy(_tg).sub(_a).normalize(); _q.setFromUnitVectors(_v1, _v2); rotWorld(U, _q);
  if (w < 1) { U.quaternion.copy(_qU.slerp(U.quaternion, w)); F.quaternion.copy(_qF.slerp(F.quaternion, w)); }
}
