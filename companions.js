// ===== Valtheria — pets, montarias, asas e voo =====
import * as THREE from './three.module.min.js';
import { makeCreature } from './creatures.js';
import { emit } from './fx.js';

let X = null; // contexto do jogo: { scene, S, GD, WG, me(), toast, hurtMob, now }
export const COMP = { pet: null, mount: null, wings: null, petId: null, mountId: null, wingsId: null, riding: false };
export function initComp(ctx) { X = ctx; }
const key = () => 'vt_comp_' + X.S.c.id;
export function saveComp() { try { localStorage.setItem(key(), JSON.stringify({ pet: COMP.petId, mount: COMP.mountId, wings: COMP.wingsId })); } catch (_) {} }
export async function restoreComp() {
  let o = {}; try { o = JSON.parse(localStorage.getItem(key())) || {}; } catch (_) {}
  clearAll(); if (o.pet && X.S.inv[o.pet]) await summonPet(o.pet, true); if (o.wings && X.S.inv[o.wings]) setWings(o.wings, true); COMP.mountId = o.mount && X.S.inv[o.mount] ? o.mount : null;
}
function clearAll() { if (COMP.pet) X.scene.remove(COMP.pet.root); if (COMP.mount) X.scene.remove(COMP.mount.root); if (COMP.wings) COMP.wings.removeFromParent(); Object.assign(COMP, { pet: null, mount: null, wings: null, petId: null, wingsId: null, riding: false }); X.S.fly = false; X.S.alt = 0; }
const def = id => X.GD.ITEMS[id]?.comp;
// buffs passivos: pet sempre, asas equipadas, montaria só montado
export function compFx() { const o = {}; const add = d => d && d.fx && Object.entries(d.fx).forEach(([k, v]) => o[k] = (o[k] || 0) + v);
  if (COMP.petId) add(def(COMP.petId)); if (COMP.wingsId) add(def(COMP.wingsId)); if (COMP.riding) add(def(COMP.mountId)); return o; }

// ---------- pets ----------
export async function summonPet(id, quiet) {
  if (COMP.petId === id) { dismissPet(); return; }
  dismissPet(); const d = def(id); if (!d) return; COMP.petId = id;
  const C = await makeCreature(d.model, { length: d.len, tint: d.tint, tintMix: 0.35 }); if (COMP.petId !== id) return;
  const me = X.me(); C.x = me.x - 1.5; C.z = me.z - 1.5; C.ry = 0; C.nextAtk = 0; X.scene.add(C.root); COMP.pet = C;
  if (!quiet) { X.toast(`${d.icon} ${d.name} está com você`, 'ok'); emit(C.x, X.WG.height(C.x, C.z) + 0.5, C.z, { n: 30, color: 0xffe08a, speed: 2, up: 2, life: 0.8, size: 0.2 }); }
  saveComp();
}
export function dismissPet() { if (COMP.pet) X.scene.remove(COMP.pet.root); COMP.pet = null; COMP.petId = null; saveComp(); }

// ---------- montarias ----------
export function setMount(id) { COMP.mountId = id; saveComp(); return toggleRide(true); }
export async function toggleRide(force) {
  const me = X.me(); if (!COMP.mountId) { X.toast('Você não escolheu uma montaria — use uma na bolsa', 'err'); return; }
  if (COMP.riding && !force) { dismount(); return; }
  if (X.S.dead) return; const d = def(COMP.mountId);
  if (!COMP.mount || COMP.mount.id !== COMP.mountId) { if (COMP.mount) X.scene.remove(COMP.mount.root); const C = await makeCreature(d.model, { length: d.len, tint: d.tint, tintMix: 0.3, ghost: d.ghost }); C.id = COMP.mountId; COMP.mount = C;
    if (d.fly) C.root.add(C.wingGroup = buildWings(d.wings || '#ffffff', 1.6, C.h * 0.78, C.len * 0.08)); }
  X.scene.add(COMP.mount.root); COMP.riding = true; X.S.autoAtk = false;
  emit(me.x, X.WG.height(me.x, me.z) + 0.6, me.z, { n: 30, color: 0xd8c8a0, speed: 3, up: 1.4, life: 0.7, size: 0.3 });
  X.toast(`${d.icon} Montado em ${d.name}${d.fly ? ' — V para voar' : ''}`, 'ok'); saveComp();
}
export function dismount() { if (!COMP.riding) return; COMP.riding = false; if (COMP.mount) X.scene.remove(COMP.mount.root); if (X.S.fly && !COMP.wingsId) { X.S.fly = false; } }
export const saddle = () => COMP.riding && COMP.mount ? COMP.mount.h * 0.62 : 0;
export const mountSpeed = () => COMP.riding ? (def(COMP.mountId)?.speed || 1) : 1;

// ---------- asas ----------
// asa procedural: penas em leque com brilho nas pontas; color = cor principal
const wingTex = (() => { const c = document.createElement('canvas'); c.width = 64; c.height = 256; const g = c.getContext('2d'), gr = g.createLinearGradient(0, 0, 0, 256);
  gr.addColorStop(0, 'rgba(255,255,255,0.15)'); gr.addColorStop(0.55, 'rgba(255,255,255,0.85)'); gr.addColorStop(1, 'rgba(255,255,255,1)'); g.fillStyle = gr;
  g.beginPath(); g.moveTo(32, 0); g.quadraticCurveTo(62, 120, 40, 256); g.lineTo(24, 256); g.quadraticCurveTo(2, 120, 32, 0); g.fill(); g.strokeStyle = 'rgba(255,255,255,0.9)'; g.lineWidth = 2; g.beginPath(); g.moveTo(32, 6); g.lineTo(32, 250); g.stroke();
  const t = new THREE.CanvasTexture(c); return t; })();
export function buildWings(color, size = 1, y = 1.35, z = -0.18) {
  const grp = new THREE.Group(); grp.position.set(0, y, z); const col = new THREE.Color(color);
  const mat = new THREE.MeshBasicMaterial({ map: wingTex, color: col, transparent: true, side: THREE.DoubleSide, depthWrite: false, blending: THREE.AdditiveBlending, opacity: 0.95 });
  const solid = new THREE.MeshStandardMaterial({ map: wingTex, color: col.clone().multiplyScalar(0.8), transparent: true, alphaTest: 0.35, side: THREE.DoubleSide, roughness: 0.5, emissive: col, emissiveIntensity: 0.35 });
  for (const s of [-1, 1]) {
    const wing = new THREE.Group(); wing.userData.side = s;
    for (let i = 0; i < 7; i++) { const L = (0.55 + i * 0.13) * size, f = new THREE.Mesh(new THREE.PlaneGeometry(0.24 * size, L), i % 2 ? mat : solid);
      f.geometry.translate(0, L / 2, 0); f.position.set(s * (0.05 + i * 0.07) * size, 0, 0); f.rotation.z = -s * (0.25 + i * 0.2); f.rotation.y = s * 0.15; wing.add(f); }
    wing.rotation.y = s * 0.5; grp.add(wing);
  }
  grp.userData.col = col.getHex(); return grp;
}
export function setWings(id, quiet) {
  const me = X.me(); if (COMP.wings) COMP.wings.removeFromParent();
  if (COMP.wingsId === id && !quiet) { COMP.wings = null; COMP.wingsId = null; if (X.S.fly && !(COMP.riding && def(COMP.mountId)?.fly)) X.S.fly = false; X.toast('Asas guardadas'); saveComp(); return; }
  const d = def(id); if (!d) return; COMP.wingsId = id; const h = X.GD.RACES[X.S.c.race]?.h || 1;
  COMP.wings = buildWings(d.color, 0.9 * h, 1.32 * h, -0.16); me.root.add(COMP.wings);
  if (!quiet) X.toast(`${d.icon} ${d.name} equipadas — V para voar`, 'ok'); saveComp();
}
export const canFly = () => !!COMP.wingsId || (COMP.riding && def(COMP.mountId)?.fly);
export function toggleFly() {
  const S = X.S; if (!canFly()) { X.toast('Para voar, equipe asas ou monte uma montaria voadora', 'err'); return; }
  S.fly = !S.fly; if (S.fly) { S.alt = Math.max(S.alt || 0, 2.5); X.toast('🪽 Voando — Espaço sobe, X desce, V pousa', 'ok'); } else X.toast('Pousando…');
}

// ---------- atualização ----------
export function updateComp(dt, moving, speed) {
  const S = X.S, me = X.me(), WG = X.WG, t = X.now();
  // voo: altura
  if (S.fly) { const up = (X.keys.Space ? 1 : 0) - (X.keys.KeyX ? 1 : 0) + (S.flyUp ? 1 : 0) - (S.flyDown ? 1 : 0); S.alt = Math.min(180, Math.max(0, S.alt + up * 9 * dt)); if (S.alt <= 0.05 && up < 0) S.fly = false; }
  else if (S.alt > 0) S.alt = Math.max(0, S.alt - 14 * dt);
  const gy = WG.height(me.x, me.z), base = Math.max(gy, S.fly ? WG.WATER + 0.5 : gy);
  // montaria
  if (COMP.riding && COMP.mount) { const C = COMP.mount; C.root.position.set(me.x, base + S.alt, me.z); C.root.rotation.y = me.root.rotation.y;
    C.play(S.fly ? 'run' : moving ? (speed > 9 ? 'run' : 'walk') : 'idle', { speed: S.fly ? 0.6 : 1 }); C.mixer.update(dt);
    if (C.wingGroup) flap(C.wingGroup, t, S.fly || moving); }
  // asas
  if (COMP.wings) { flap(COMP.wings, t, S.fly); if (S.fly && Math.random() < 0.5) { const w = COMP.wings.getWorldPosition(new THREE.Vector3()); emit(w.x + (Math.random() - 0.5), w.y, w.z + (Math.random() - 0.5), { n: 1, color: COMP.wings.userData.col, speed: 0.3, up: -0.5, life: 0.9, size: 0.16, grav: 0.5 }); } }
  // pet: segue o dono e ajuda no combate
  const P = COMP.pet; if (P) {
    const d = def(COMP.petId); let tx = me.x - Math.sin(me.ry + 0.7) * 1.8, tz = me.z - Math.cos(me.ry + 0.7) * 1.8, fighting = false;
    const tg = S.target && S.target.kind === 'mob' && !S.target.ref.dead && S.autoAtk ? S.target.ref : null;
    if (tg && Math.hypot(tg.x - me.x, tg.z - me.z) < 14) { tx = tg.x + 1.2; tz = tg.z + 1.2; fighting = Math.hypot(tg.x - P.x, tg.z - P.z) < 2.4; }
    const dx = tx - P.x, dz = tz - P.z, dist = Math.hypot(dx, dz);
    if (dist > 30) { P.x = tx; P.z = tz; }
    const sp = dist > 6 ? speed * 1.15 : dist > 1.2 ? speed * 0.7 : 0; if (sp) { P.x += dx / dist * sp * dt; P.z += dz / dist * sp * dt; P.ry = Math.atan2(dx, dz); }
    if (fighting && t > P.nextAtk) { P.nextAtk = t + 2200; P.play('attack', { once: true, fade: 0.08 }); P.atkUntil = t + 700; P.ry = Math.atan2(tg.x - P.x, tg.z - P.z); X.petHit(tg, 0.18); }
    else if (!(P.atkUntil > t)) P.play(sp > 6 ? 'run' : sp ? 'walk' : (Math.sin(t / 4000) > 0.7 ? 'eat' : 'idle'));
    let a = P.root.rotation.y, dd = P.ry - a; dd = Math.atan2(Math.sin(dd), Math.cos(dd)); P.root.rotation.y = a + dd * Math.min(1, dt * 8);
    const py = WG.height(P.x, P.z) + (d?.flyer ? 1.4 + Math.sin(t / 300) * 0.15 : 0) + (S.fly && d?.flyer ? S.alt : 0); P.root.position.set(P.x, py, P.z); P.mixer.update(dt);
  }
}
function flap(g, t, fast) { const sp = fast ? 0.012 : 0.003, a = Math.sin(t * sp) * (fast ? 0.55 : 0.12); for (const w of g.children) { const s = w.userData.side; w.rotation.y = s * (0.5 + a); w.rotation.z = s * a * 0.4; } }
