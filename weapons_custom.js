// ===== Valtheria — armas lendárias modeladas em código (sem arquivos externos) =====
// Cada função devolve um THREE.Group apontando para +Y, com a mão na origem e um Object3D "tip" na ponta.
import * as THREE from './lib/three.module.min.js';

// Espada Celestial da Harmonia — refeita com proporções reais: lâmina fina (1,2 cm) com fio serrilhado, canal azul com veio de energia,
// filete dourado, guarda em asas de meia-lua, cabo estreito trançado e pomo com gema. Medidas em metros; total ≈ 1,12 m.
function espadaHarmonia() {
  const group = new THREE.Group(); group.name = 'Espada_Celestial_da_Harmonia';
  const steel = new THREE.MeshStandardMaterial({ name: 'blade', color: 0xd5dde6, metalness: 1, roughness: 0.2 });
  const gold = new THREE.MeshStandardMaterial({ name: 'gold', color: 0xb9954e, metalness: 1, roughness: 0.34 });
  const grip = new THREE.MeshStandardMaterial({ name: 'grip', color: 0x2a1e16, metalness: 0.1, roughness: 0.75 });
  const chan = new THREE.MeshStandardMaterial({ name: 'gem', color: 0x3a3d44, metalness: 0.9, roughness: 0.4, emissive: 0x000000, emissiveIntensity: 0 });
  const glow = new THREE.MeshStandardMaterial({ name: 'gem', color: 0xe8d9b0, emissive: 0xd8b060, emissiveIntensity: 0.7, metalness: 0, roughness: 0.3 });
  const gem = new THREE.MeshStandardMaterial({ name: 'gem', color: 0xa8bad6, emissive: 0x8fa8d8, emissiveIntensity: 0.35, metalness: 0.2, roughness: 0.08, flatShading: true });
  const add = (geo, mat, x = 0, y = 0, z = 0) => { const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.castShadow = true; group.add(m); return m; };
  const ext = (shape, depth, bevel = 0) => { const g = new THREE.ExtrudeGeometry(shape, { depth, steps: 1, bevelEnabled: bevel > 0, bevelThickness: bevel, bevelSize: bevel, bevelSegments: 1, curveSegments: 10 }); g.translate(0, 0, -depth / 2); return g; };
  const Y0 = 0.135, Y1 = 1.0, half = y => { const k = (y - Y0) / (Y1 - Y0); return k < 0.68 ? 0.036 + 0.012 * Math.sin(k / 0.68 * Math.PI * 0.5) : 0.048 * Math.pow(1 - (k - 0.68) / 0.32, 0.8); };
  // lâmina: metade direita com 6 dentes em gancho, espelhada
  { const N = 6, seg = (0.74 - Y0) / N, R = [[0.03, Y0]]; for (let i = 0; i < N; i++) { const a = Y0 + i * seg, b = a + seg; R.push([half(a) - 0.004, a + seg * 0.12], [half(b) + 0.009, b - seg * 0.06], [half(b) - 0.006, b]); }
    R.push([half(0.82), 0.82], [half(0.9) * 0.9, 0.9], [0, Y1]); const sh = new THREE.Shape(); sh.moveTo(0, Y0); R.forEach(([x, y]) => sh.lineTo(x, y)); [...R].reverse().slice(1).forEach(([x, y]) => sh.lineTo(-x, y)); sh.closePath();
    add(ext(sh, 0.003, 0.0045), steel); }
  // canal azul, filete dourado e veio de energia (nas duas faces)
  const lens = (w, a, b, tipK = 0.2) => { const s = new THREE.Shape(), m = a + (b - a) * 0.55; s.moveTo(0, a); s.quadraticCurveTo(w * 1.1, a + (b - a) * 0.12, w, m); s.quadraticCurveTo(w * 0.7, b - (b - a) * tipK, 0, b); s.quadraticCurveTo(-w * 0.7, b - (b - a) * tipK, -w, m); s.quadraticCurveTo(-w * 1.1, a + (b - a) * 0.12, 0, a); return s; };
  for (const f of [1, -1]) { add(ext(lens(0.03, 0.17, 0.9), 0.002), gold, 0, 0, f * 0.0068); add(ext(lens(0.0245, 0.185, 0.875), 0.002), chan, 0, 0, f * 0.0082); add(ext(lens(0.0035, 0.2, 0.86, 0.05), 0.0015), glow, 0, 0, f * 0.0094);
    for (const [gy, gs] of [[0.245, 0.02], [0.8, 0.014]]) { const d = add(new THREE.OctahedronGeometry(gs, 0), gem, 0, gy, f * 0.011); d.scale.set(0.8, 1.9, 0.3); const r = add(new THREE.OctahedronGeometry(gs * 1.35, 0), gold, 0, gy, f * 0.0088); r.scale.set(0.8, 1.9, 0.12); } }
  // guarda: núcleo em losango com gema e duas asas em meia-lua (uma sobe, outra desce)
  { const wing = new THREE.Shape(); wing.moveTo(0.012, 0.0); wing.quadraticCurveTo(0.09, -0.012, 0.145, 0.075); wing.quadraticCurveTo(0.118, 0.03, 0.075, 0.03); wing.quadraticCurveTo(0.04, 0.03, 0.012, 0.045); wing.closePath();
    const low = new THREE.Shape(); low.moveTo(0.012, 0.012); low.quadraticCurveTo(0.07, 0.0, 0.118, -0.058); low.quadraticCurveTo(0.075, -0.03, 0.05, -0.024); low.quadraticCurveTo(0.03, -0.018, 0.012, -0.022); low.closePath();
    const hook = new THREE.Shape(); hook.moveTo(0.03, 0.04); hook.quadraticCurveTo(0.062, 0.06, 0.058, 0.105); hook.quadraticCurveTo(0.046, 0.075, 0.024, 0.066); hook.closePath();
    for (const sx of [1, -1]) { for (const [sp, th, dy] of [[wing, 0.012, 0.105], [low, 0.01, 0.105], [hook, 0.007, 0.1]]) { const m = add(ext(sp, th, 0.0025), gold, 0, dy, 0); m.scale.x = sx; } add(new THREE.SphereGeometry(0.0065, 8, 6), glow, sx * 0.082, 0.132, 0.008); }
    const core = add(new THREE.OctahedronGeometry(0.034, 0), gold, 0, 0.118, 0); core.scale.set(1, 1.35, 0.5); for (const f of [1, -1]) { const g = add(new THREE.OctahedronGeometry(0.02, 0), gem, 0, 0.118, f * 0.013); g.scale.set(0.9, 1.5, 0.4); } }
  // cabo trançado, anéis e pomo
  add(new THREE.CylinderGeometry(0.0155, 0.017, 0.185, 12), grip, 0, 0.0, 0);
  for (let i = 0; i < 9; i++) { const r = add(new THREE.TorusGeometry(0.0165, 0.0028, 5, 14), grip, 0, -0.078 + i * 0.0185, 0); r.rotation.x = Math.PI / 2 + (i % 2 ? 0.42 : -0.42); }
  for (const y of [0.088, -0.03, -0.09]) add(new THREE.CylinderGeometry(0.0205, 0.0205, 0.012, 14), gold, 0, y, 0);
  { const p = add(new THREE.OctahedronGeometry(0.03, 0), gold, 0, -0.128, 0); p.scale.set(1, 1.3, 0.6); for (const f of [1, -1]) { const g = add(new THREE.OctahedronGeometry(0.015, 0), gem, 0, -0.128, f * 0.014); g.scale.set(0.9, 1.5, 0.4); }
    add(new THREE.ConeGeometry(0.009, 0.04, 6), gold, 0, -0.178, 0).rotation.x = Math.PI; for (const sx of [1, -1]) add(new THREE.ConeGeometry(0.007, 0.03, 5), gold, sx * 0.03, -0.14, 0).rotation.z = sx * 2.2; }
  const tip = new THREE.Object3D(); tip.name = 'tip'; tip.position.set(0, Y1, 0); group.add(tip);
  group.scale.setScalar(0.9); // 1,06 m no total: espada de uma mão
  return group;
}
const BUILD = { W001: espadaHarmonia }, PROTO = {};
// devolve uma cópia pronta para a mão (geometrias e materiais são compartilhados entre as cópias)
export function customWeapon(id) { if (!BUILD[id]) return null; if (!PROTO[id]) PROTO[id] = BUILD[id](); return PROTO[id].clone(true); }
