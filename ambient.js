// ===== Valtheria — vida ambiente: animais selvagens, pássaros, vaga-lumes e atmosfera dos locais especiais =====
import * as THREE from './three.module.min.js';
import { makeCreature } from './creatures.js';
import { emit } from './fx.js';

let X = null; const herd = []; let birds = null, nextSpawn = 0;
const SPECIES = { verde: [['a_deer', 1.5], ['a_fox', 0.95], ['a_stag', 1.7], ['a_alpaca', 1.6]], floresta: [['a_deer', 1.5], ['a_stag', 1.7], ['a_fox', 0.95]], outono: [['a_deer', 1.5], ['a_fox', 0.95]],
  savana: [['a_bull', 2.2], ['a_donkey', 1.7], ['a_alpaca', 1.6]], rocha: [['a_alpaca', 1.6], ['a_stag', 1.7]], gelo: [['a_stag', 1.8], ['a_husky', 1.0]], noite: [['a_fox', 0.95]], cinza: [['a_donkey', 1.7]] };
export function initAmbient(ctx) { X = ctx; birds = makeBirds(); X.scene.add(birds.group); }
export const AMB = { max: 6 };
// ---------- pássaros (bandos que planam em círculo, batendo asas) ----------
function makeBirds() {
  const group = new THREE.Group(), geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute([0, 0, 0.25, -0.9, 0, -0.1, 0, 0, -0.15, 0, 0, 0.25, 0, 0, -0.15, 0.9, 0, -0.1], 3)); geo.computeVertexNormals();
  const mat = new THREE.MeshBasicMaterial({ color: 0x2a2a30, side: THREE.DoubleSide });
  const list = []; for (let f = 0; f < 3; f++) for (let i = 0; i < 7; i++) { const m = new THREE.Mesh(geo.clone(), mat); m.userData = { f, i, ph: Math.random() * 6 }; group.add(m); list.push(m); }
  return { group, list, centers: [0, 1, 2].map(i => ({ a: i * 2.1, r: 40 + i * 15, h: 45 + i * 12, sp: 0.05 + i * 0.02 })) };
}
function updateBirds(dt, t, me, night) {
  birds.group.visible = !night; if (night) return;
  for (const m of birds.list) { const { f, i, ph } = m.userData, C = birds.centers[f]; C.a += C.sp * dt / 7; const a = C.a - i * 0.05, r = C.r + (i % 3) * 2.5;
    const x = me.x + Math.cos(a) * r + Math.sin(i) * 3, z = me.z + Math.sin(a) * r + Math.cos(i) * 3, y = X.WG.height(me.x, me.z) + C.h + Math.sin(t / 1300 + i) * 2;
    m.position.set(x, y, z); m.rotation.y = -a; const fl = Math.sin(t / 110 + ph) * 0.9, p = m.geometry.attributes.position; p.setY(1, fl); p.setY(5, fl); p.needsUpdate = true; }
}
// ---------- animais ----------
async function spawnAnimal(me, theme) {
  const list = SPECIES[theme]; if (!list) return; const [name, len] = list[Math.floor(Math.random() * list.length)];
  const a = Math.random() * Math.PI * 2, d = 45 + Math.random() * 35, x = me.x + Math.cos(a) * d, z = me.z + Math.sin(a) * d, h = X.WG.height(x, z);
  if (h < 1 || h > 60 || X.WG.region(x, z).safe) return;
  const A = { x, z, ry: Math.random() * 6, tx: x, tz: z, wait: 0, flee: 0, C: null }; herd.push(A);
  A.C = await makeCreature(name, { length: len * (0.85 + Math.random() * 0.3) }); X.scene.add(A.C.root);
}
export function updateAmbient(dt) {
  const me = X.me(); if (!me || !X.S.inGame) return; const t = performance.now(), night = X.isNight(), WG = X.WG;
  updateBirds(dt, t, me, night);
  const theme = X.theme(me.x, me.z);
  if (t > nextSpawn && herd.length < AMB.max) { nextSpawn = t + 2500; spawnAnimal(me, theme); }
  for (let i = herd.length - 1; i >= 0; i--) { const A = herd[i]; if (!A.C) continue; const C = A.C, dP = Math.hypot(A.x - me.x, A.z - me.z);
    if (dP > 140) { X.scene.remove(C.root); herd.splice(i, 1); continue; }
    if (dP < 11 && !A.flee) { A.flee = t + 4000; const k = 25 / Math.max(dP, 0.1); A.tx = A.x + (A.x - me.x) * k; A.tz = A.z + (A.z - me.z) * k; }
    if (A.flee && t > A.flee) A.flee = 0;
    const dx = A.tx - A.x, dz = A.tz - A.z, dd = Math.hypot(dx, dz);
    if (dd < 0.6) { if (!A.wait) A.wait = t + 3000 + Math.random() * 6000; if (t > A.wait) { A.wait = 0; A.tx = A.x + (Math.random() - 0.5) * 30; A.tz = A.z + (Math.random() - 0.5) * 30; } C.play(Math.random() < 0.002 ? 'idle' : (A.wait - t > 2500 ? 'eat' : 'idle')); }
    else { const sp = A.flee ? 9 : 1.6, nx = A.x + dx / dd * sp * dt, nz = A.z + dz / dd * sp * dt; if (WG.height(nx, nz) > 0.6) { A.x = nx; A.z = nz; } else { A.tx = A.x; A.tz = A.z; } A.ry = Math.atan2(dx, dz); C.play(A.flee ? 'run' : 'walk'); }
    let a = C.root.rotation.y, df = A.ry - a; df = Math.atan2(Math.sin(df), Math.cos(df)); C.root.rotation.y = a + df * Math.min(1, dt * 5);
    C.root.position.set(A.x, WG.height(A.x, A.z), A.z); if (dP < 90) C.mixer.update(dt);
  }
  // vaga-lumes à noite em florestas e pântanos; atmosfera dos locais especiais
  if (night && ['verde', 'floresta', 'outono', 'noite'].includes(theme) && Math.random() < 0.25) { const a = Math.random() * 6.28, r = 4 + Math.random() * 18, x = me.x + Math.cos(a) * r, z = me.z + Math.sin(a) * r;
    emit(x, WG.height(x, z) + 0.6 + Math.random() * 2, z, { n: 1, color: 0xd8ff6a, speed: 0.3, up: 0.2, life: 2.2, size: 0.14, grav: -0.05, drag: 0.3 }); }
  const L = X.nearPoi(me.x, me.z); if (L && L.amb && Math.random() < 0.6) { const a = Math.random() * 6.28, r = Math.random() * 28, x = L.x + Math.cos(a) * r, z = L.z + Math.sin(a) * r;
    emit(x, WG.height(x, z) + 0.3 + Math.random() * 3, z, { n: 1, color: new THREE.Color(L.amb.particles).getHex(), speed: 0.2, up: 0.4, life: 2.5, size: 0.18, grav: -0.08, drag: 0.4 }); }
}
