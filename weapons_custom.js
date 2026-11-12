// ===== Valtheria — armas lendárias modeladas em código (sem arquivos externos) =====
// Cada função devolve um THREE.Group apontando para +Y, com a mão na origem e um Object3D "tip" na ponta.
import * as THREE from './lib/three.module.min.js';

function espadaHarmonia() {
  const group = new THREE.Group(); group.name = 'Espada_Celestial_da_Harmonia';
  const blade = new THREE.MeshStandardMaterial({ name: 'blade', color: 0xdceaf5, metalness: 0.95, roughness: 0.19 }), gold = new THREE.MeshStandardMaterial({ name: 'gold', color: 0xd9a441, metalness: 0.9, roughness: 0.23 });
  const grip = new THREE.MeshStandardMaterial({ name: 'grip', color: 0x102b42, metalness: 0.25, roughness: 0.7 }), gem = new THREE.MeshStandardMaterial({ name: 'gem', color: 0x16cfff, emissive: 0x087bff, emissiveIntensity: 1.8, metalness: 0.35, roughness: 0.15 });
  const add = (geometry, material, name, x, y, z) => { const mesh = new THREE.Mesh(geometry, material); mesh.name = name; mesh.position.set(x, y, z); mesh.castShadow = true; group.add(mesh); return mesh; };
  const shape = new THREE.Shape(); shape.moveTo(-0.065, 0.20); shape.lineTo(0.065, 0.20); shape.lineTo(0.072, 0.48); shape.lineTo(0.058, 0.66); shape.lineTo(0.025, 0.79); shape.lineTo(0, 0.85); shape.lineTo(-0.025, 0.79); shape.lineTo(-0.058, 0.66); shape.lineTo(-0.072, 0.48); shape.closePath();
  add(new THREE.ExtrudeGeometry(shape, { depth: 0.035, bevelEnabled: true, bevelSegments: 1, steps: 1, bevelSize: 0.008, bevelThickness: 0.006 }), blade, 'Lamina_Celestial', 0, 0, -0.0175);
  const spine = new THREE.Shape(); spine.moveTo(-0.009, 0.23); spine.lineTo(0.009, 0.23); spine.lineTo(0.007, 0.67); spine.lineTo(0, 0.79); spine.lineTo(-0.007, 0.67); spine.closePath();
  add(new THREE.ExtrudeGeometry(spine, { depth: 0.012, bevelEnabled: false }), gold, 'Nervura_Dourada', 0, 0, 0.012);
  add(new THREE.BoxGeometry(0.27, 0.055, 0.075), gold, 'Guarda_Esquerda', -0.15, 0.19, 0).rotation.z = -0.32; add(new THREE.BoxGeometry(0.27, 0.055, 0.075), gold, 'Guarda_Direita', 0.15, 0.19, 0).rotation.z = 0.32;
  add(new THREE.OctahedronGeometry(0.065, 0), gold, 'Nucleo_Guarda', 0, 0.19, 0.055); add(new THREE.OctahedronGeometry(0.055, 1), gem, 'Cristal_Guarda', 0, 0.19, 0.105);
  add(new THREE.CylinderGeometry(0.043, 0.052, 0.30, 8), grip, 'Punho_Azul', 0, 0.015, 0);
  for (const y of [-0.125, -0.065, 0.065, 0.145]) add(new THREE.CylinderGeometry(0.056, 0.056, 0.018, 10), gold, 'Anel_Ornamental', 0, y, 0);
  add(new THREE.OctahedronGeometry(0.075, 0), gold, 'Pomo_Dourado', 0, -0.145, 0); add(new THREE.OctahedronGeometry(0.035, 1), gem, 'Cristal_Pomo', 0, -0.145, 0.055);
  for (const side of [-1, 1]) add(new THREE.OctahedronGeometry(0.035, 0), gem, 'Cristal_Lateral', side * 0.16, 0.22, 0.055).rotation.z = side * 0.3;
  // acabamento seguindo a arte: veio de energia azul na lâmina, dentes no fio e guarda em meia-lua
  const core = new THREE.Shape(); core.moveTo(-0.022, 0.25); core.lineTo(0.022, 0.25); core.lineTo(0.03, 0.47); core.lineTo(0.016, 0.66); core.lineTo(0, 0.75); core.lineTo(-0.016, 0.66); core.lineTo(-0.03, 0.47); core.closePath();
  const glowM = new THREE.MeshStandardMaterial({ name: 'gem', color: 0x0a4a9a, emissive: 0x1a9aff, emissiveIntensity: 1.5, metalness: 0.3, roughness: 0.2 });
  for (const zz of [0.0185, -0.0265]) add(new THREE.ExtrudeGeometry(core, { depth: 0.008, bevelEnabled: false }), glowM, 'Veio_de_Energia', 0, 0, zz);
  for (const side of [-1, 1]) { for (let i = 0; i < 4; i++) { const t = add(new THREE.ConeGeometry(0.022, 0.07, 4), blade, 'Dente', side * (0.078 - i * 0.004), 0.3 + i * 0.105, 0); t.rotation.z = -side * 1.15; t.scale.z = 0.5; }
    const horn = add(new THREE.TorusGeometry(0.11, 0.018, 6, 14, 1.9), gold, 'Meia_Lua', side * 0.2, 0.25, 0); horn.rotation.z = side > 0 ? -0.5 : Math.PI - 1.4; horn.scale.z = 1.6;
    add(new THREE.ConeGeometry(0.02, 0.09, 5), gold, 'Ponta_Guarda', side * 0.29, 0.13, 0).rotation.z = side * 2.4; }
  add(new THREE.OctahedronGeometry(0.03, 0), gem, 'Cristal_Lamina', 0, 0.3, 0.03).scale.set(1, 1.8, 0.6);
  const tip = new THREE.Object3D(); tip.name = 'tip'; tip.position.set(0, 0.85, 0); group.add(tip);
  return group;
}
const BUILD = { W001: espadaHarmonia }, PROTO = {};
// devolve uma cópia pronta para a mão (geometrias e materiais são compartilhados entre as cópias)
export function customWeapon(id) { if (!BUILD[id]) return null; if (!PROTO[id]) PROTO[id] = BUILD[id](); return PROTO[id].clone(true); }
