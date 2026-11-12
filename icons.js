// ===== Valtheria — ícones 3D dos equipamentos (renderizados do próprio modelo, com cor do grau e aura da classe) =====
import * as THREE from './lib/three.module.min.js';
import { loadGLB } from './chars.js';

const SIZE = 128, CACHE = new Map(), PENDING = new Set(); let R = null, scene, cam, onReady = null;
const GRADE_COL = ['#9a9a9a', '#c8955a', '#d6dde6', '#5aa9ff', '#ff5a5a', '#d38cff'];
// aura mística por tipo de arma (estilo da classe que usa)
export const KIND_AURA = { espada: '#ffd75a', espadao: '#ff6a2a', machado: '#ff3a2a', lanca: '#7ad0ff', arco: '#7aff9a', adaga: '#c03aff', cajado: '#5a8aff', punhos: '#ffb03a', martelo: '#3ad8c8', escudo: '#ffe8a0' };
const MODEL = { espada: ['w_sword', 'w_sword', 'w_sword', 'w_sword_big', 'w_sword_big', 'w_sword_golden'], espadao: ['w_claymore'], machado: ['w_axe', 'w_axe', 'w_axe_double'], lanca: ['w_spear'], adaga: ['w_dagger'], martelo: ['w_hammer_double'], arco: ['w_bow_wooden', 'w_bow_wooden', 'w_bow_wooden', 'w_bow_golden'], escudo: ['w_shield_round', 'w_shield_round', 'w_shield_heater', 'w_shield_heater', 'w_shield_heater', 'w_shield_celtic_golden'] };
const GLOW = [0, 0, 0, 0x2a6aff, 0xff2a2a, 0xb04aff];
function init() {
  const c = document.createElement('canvas'); c.width = c.height = SIZE;
  R = new THREE.WebGLRenderer({ canvas: c, alpha: true, antialias: true, preserveDrawingBuffer: true }); R.setSize(SIZE, SIZE, false); R.outputColorSpace = THREE.SRGBColorSpace; R.toneMapping = THREE.ACESFilmicToneMapping;
  scene = new THREE.Scene(); cam = new THREE.PerspectiveCamera(30, 1, 0.1, 100);
  scene.add(new THREE.HemisphereLight(0xffffff, 0x404060, 1.6)); const d = new THREE.DirectionalLight(0xffffff, 2.2); d.position.set(2, 3, 4); scene.add(d); const rim = new THREE.DirectionalLight(0x9ac0ff, 1.4); rim.position.set(-3, 1, -2); scene.add(rim);
}
function staff(g, relic) { const grp = new THREE.Group(); const wood = new THREE.MeshStandardMaterial({ color: relic ? '#3a2a4a' : '#6b4423', roughness: 0.7 });
  const sh = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.05, 1.7, 8), wood); grp.add(sh);
  const orb = new THREE.Mesh(new THREE.IcosahedronGeometry(0.13, 2), new THREE.MeshStandardMaterial({ color: ['#88f', '#c6f', '#6cf', '#5af', '#f55', '#e6f'][g], emissive: [0x2222aa, 0x6622aa, 0x2288cc, 0x2a6aff, 0xff2a2a, 0xb04aff][g], emissiveIntensity: 1.2, roughness: 0.2 }));
  orb.position.y = 0.95; grp.add(orb); const ring = new THREE.Mesh(new THREE.TorusGeometry(0.17, 0.02, 8, 24), new THREE.MeshStandardMaterial({ color: '#d8b04a', metalness: 0.8, roughness: 0.3 })); ring.position.y = 0.95; grp.add(ring);
  for (let i = 0; i < 3; i++) { const p = new THREE.Mesh(new THREE.ConeGeometry(0.03, 0.22, 5), ring.material); p.position.set(Math.cos(i * 2.1) * 0.15, 1.08, Math.sin(i * 2.1) * 0.15); p.rotation.z = Math.cos(i * 2.1) * -0.4; grp.add(p); }
  return grp; }
function frame(ctx, it, main) {
  const g = it.grade, gc = GRADE_COL[g], aura = KIND_AURA[it.kind] || '#ffffff';
  const bg = ctx.createRadialGradient(SIZE / 2, SIZE / 2, 4, SIZE / 2, SIZE / 2, SIZE * 0.7); bg.addColorStop(0, aura + '66'); bg.addColorStop(0.55, '#1a1410'); bg.addColorStop(1, '#0a0806');
  ctx.fillStyle = bg; ctx.fillRect(0, 0, SIZE, SIZE);
  if (it.relic || g >= 3) { ctx.save(); ctx.translate(SIZE / 2, SIZE / 2); ctx.strokeStyle = aura + 'aa'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.arc(0, 0, SIZE * 0.4, 0, Math.PI * 2); ctx.stroke();
    ctx.font = '11px serif'; ctx.fillStyle = aura; for (let i = 0; i < 12; i++) { ctx.rotate(Math.PI / 6); ctx.fillText('ᚱᚢᚾᛖᛋᚨ'[i % 6], -3, -SIZE * 0.43); } ctx.restore(); }
  if (main) ctx.drawImage(main, 0, 0);
  ctx.strokeStyle = gc; ctx.lineWidth = it.relic ? 5 : 3; ctx.strokeRect(2, 2, SIZE - 4, SIZE - 4);
  if (it.relic) { ctx.strokeStyle = '#ffd75a'; ctx.lineWidth = 1; ctx.strokeRect(7, 7, SIZE - 14, SIZE - 14); }
}
async function render(it) {
  if (!R) init();
  const k = it.slot === 'escudo' ? 'escudo' : it.kind, list = MODEL[k];
  let obj;
  if (k === 'cajado') obj = staff(it.grade, it.relic);
  else if (list) { const gl = await loadGLB(it.relic && k === 'espada' ? 'w_sword_golden' : it.relic && k === 'arco' ? 'w_bow_golden' : list[Math.min(it.grade, list.length - 1)]); obj = gl.scene.clone(true);
    obj.traverse(o => { if (o.isMesh) { o.material = o.material.clone(); if (it.grade >= 3 || it.relic) { o.material.emissive = new THREE.Color(it.relic ? KIND_AURA[k] : GLOW[it.grade]); o.material.emissiveIntensity = 0.35; } } }); }
  else return null;
  const g = new THREE.Group(); g.add(obj); scene.add(g);
  const b = new THREE.Box3().setFromObject(obj), c = b.getCenter(new THREE.Vector3()), s = b.getSize(new THREE.Vector3()); obj.position.sub(c);
  g.rotation.z = k === 'escudo' ? 0 : -Math.PI / 4; g.rotation.y = k === 'escudo' ? 0.4 : 0.35;
  const r = Math.max(s.x, s.y, s.z) * 0.62; cam.position.set(0, 0, r / Math.tan(15 * Math.PI / 180)); cam.lookAt(0, 0, 0);
  R.setClearColor(0x000000, 0); R.render(scene, cam); scene.remove(g);
  const out = document.createElement('canvas'); out.width = out.height = SIZE; frame(out.getContext('2d'), it, R.domElement);
  return out.toDataURL('image/png');
}
// devolve <img> se pronto; se não, agenda e devolve null
export function icon3d(it, cb) {
  if (!it || !(it.slot === 'arma' || it.slot === 'escudo')) return null;
  if (CACHE.has(it.id)) return CACHE.get(it.id);
  if (!PENDING.has(it.id)) { PENDING.add(it.id); render(it).then(u => { CACHE.set(it.id, u); if (u) (cb || onReady)?.(); }).catch(() => CACHE.set(it.id, null)); }
  return null;
}
export function onIconsReady(f) { let t = null; onReady = () => { clearTimeout(t); t = setTimeout(f, 120); }; }
