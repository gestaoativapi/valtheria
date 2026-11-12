// ===== Valtheria — pets, montarias, asas e voo =====
import * as THREE from './lib/three.module.min.js';
import { makeCreature } from './creatures.js';
import { emit } from './fx.js';

let X = null; // contexto do jogo: { scene, S, GD, WG, me(), toast, hurtMob, now }
export const COMP = { pet: null, mount: null, wings: null, petId: null, mountId: null, wingsId: null, riding: false };
export function initComp(ctx) { X = ctx; }
const key = () => 'vt_comp_' + X.S.c.id;
export function saveComp() { try { localStorage.setItem(key(), JSON.stringify({ pet: COMP.petId, mount: COMP.mountId, wings: COMP.wingsId, xp: COMP.xp || {}, tal: COMP.tal || {} })); } catch (_) {} }
// ----- evolução dos pets: ganham experiência a cada abate do dono; evoluem no nível 10 e no 20 -----
export const PET_MAX = 30, petXp = id => (COMP.xp || {})[id] || 0, petLevel = id => Math.min(PET_MAX, 1 + Math.floor(Math.sqrt(petXp(id) / 4))), petStage = id => { const l = petLevel(id); return l >= 20 ? 3 : l >= 10 ? 2 : 1; };
export const PET_ROLE = { atk: 'Ataque', heal: 'Cura', buff: 'Reforço' }, PET_STAGE = ['', 'Filhote', 'Jovem', 'Ancestral'];
// transformação: no estágio 2 e 3 o pet assume uma forma maior (e às vezes outro corpo); aprimoramento: 1 ponto por nível para Força, Vínculo ou Aura
export const petForm = id => { const d = def(id), st = petStage(id), e = d && d.evo && d.evo[st - 2]; return { name: (e && e.name) || (d && d.name), model: (e && e.model) || (d && d.model), len: (e && e.len) || (d ? d.len * (1 + (st - 1) * 0.22) : 1) }; };
export const petTal = id => Object.assign({ f: 0, v: 0, a: 0 }, (COMP.tal || {})[id]);
export const petPoints = id => { const t = petTal(id); return Math.max(0, petLevel(id) - 1 - t.f - t.v - t.a); };
export function petTalent(id, k) { if (!petPoints(id) || !['f', 'v', 'a'].includes(k)) return false; const t = petTal(id); if (t[k] >= 15) return false; t[k]++; COMP.tal = COMP.tal || {}; COMP.tal[id] = t; saveComp(); X.statsDirty && X.statsDirty(); return true; }
export const petInfo = id => { const d = def(id); if (!d || d.type !== 'pet') return null; const l = petLevel(id), nx = 4 * l * l, f = petForm(id); return { level: l, stage: petStage(id), stageName: PET_STAGE[petStage(id)], role: PET_ROLE[d.role || 'atk'], xp: petXp(id), next: l >= PET_MAX ? 0 : nx, name: f.name, points: petPoints(id), tal: petTal(id), nextForm: d.evo && d.evo[petStage(id) - 1] ? d.evo[petStage(id) - 1].name : null, nextAt: petStage(id) === 1 ? 10 : petStage(id) === 2 ? 20 : 0 }; };
function petScale() {} // o tamanho agora vem da forma (petForm)
export function petKill(boss) { const id = COMP.petId; if (!id || !COMP.pet) return; COMP.xp = COMP.xp || {}; const l0 = petLevel(id), s0 = petStage(id); COMP.xp[id] = petXp(id) + (boss ? 25 : 1); const l1 = petLevel(id), d = def(id);
  if (l1 > l0) { const P = COMP.pet, y = X.WG.height(P.x, P.z); emit(P.x, y + 0.5, P.z, { n: 26, color: 0x9affc8, speed: 2, up: 2.4, life: 0.8, size: 0.18 });
    if (petStage(id) > s0) { emit(P.x, y + 0.6, P.z, { n: 90, color: 0xffe08a, speed: 3.6, up: 4, life: 1.4, size: 0.3 }); X.toast(`✨ ${d.name} se transformou em ${petForm(id).name}!`, 'ok'); summonPet(id, true, true); } else X.toast(`${d.icon} ${d.name} subiu para o nível ${l1}`, 'ok'); X.statsDirty && X.statsDirty(); }
  saveComp(); }
export async function restoreComp() {
  let o = {}; try { o = JSON.parse(localStorage.getItem(key())) || {}; } catch (_) {}
  clearAll(); COMP.xp = o.xp || {}; COMP.tal = o.tal || {}; if (o.pet && X.S.inv[o.pet]) await summonPet(o.pet, true); if (o.wings && X.S.inv[o.wings]) setWings(o.wings, true); COMP.mountId = o.mount && X.S.inv[o.mount] ? o.mount : null;
}
function clearAll() { if (COMP.pet) X.scene.remove(COMP.pet.root); if (COMP.mount) X.scene.remove(COMP.mount.root); if (COMP.wings) COMP.wings.removeFromParent(); Object.assign(COMP, { pet: null, mount: null, wings: null, petId: null, wingsId: null, riding: false }); X.S.fly = false; X.S.alt = 0; }
const def = id => X.GD.ITEMS[id]?.comp;
// buffs passivos: pet sempre, asas equipadas, montaria só montado
export function compFx() { const o = {}; const add = (d, k2 = 1) => d && d.fx && Object.entries(d.fx).forEach(([k, v]) => o[k] = (o[k] || 0) + v * k2);
  if (COMP.petId) { const d = def(COMP.petId), st = petStage(COMP.petId); add(d, (d && d.role === 'buff' ? 1.5 : 1) * (1 + (st - 1) * 0.5) * (1 + petTal(COMP.petId).a * 0.04)); } if (COMP.wingsId) add(def(COMP.wingsId)); if (COMP.riding) add(def(COMP.mountId)); return o; }

// ---------- pets ----------
export async function summonPet(id, quiet, reform) {
  if (COMP.petId === id && !reform) { dismissPet(); return; }
  const keep = reform && COMP.pet ? { x: COMP.pet.x, z: COMP.pet.z } : null;
  dismissPet(); const d = def(id); if (!d) return; COMP.petId = id;
  const F = petForm(id), C = await makeCreature(F.model, { length: F.len, tint: d.tint, tintMix: 0.35, lift: d.hover, emissive: d.neon, ei: 0.4, keepMetal: !!d.neon }); if (COMP.petId !== id) return; if (COMP.pet) X.scene.remove(COMP.pet.root); if (d.neon) C.root.add(neonGlow(d.neon, d.len * 0.8, d.hover || 0));
  const me = X.me(); C.x = keep ? keep.x : me.x - 1.5; C.z = keep ? keep.z : me.z - 1.5; C.ry = 0; C.nextAtk = 0; C.nextAid = 0; X.scene.add(C.root); COMP.pet = C; petScale(); if (d.aura) C.root.add(neonGlow(d.aura, F.len * 0.7, d.hover || (d.flyer ? 0.2 : 0)));
  if (!quiet) { X.toast(`${d.icon} ${F.name} está com você`, 'ok'); emit(C.x, X.WG.height(C.x, C.z) + 0.5, C.z, { n: 30, color: 0xffe08a, speed: 2, up: 2, life: 0.8, size: 0.2 }); }
  saveComp();
}
export function dismissPet() { if (COMP.pet) X.scene.remove(COMP.pet.root); COMP.pet = null; COMP.petId = null; saveComp(); }

// brilho de neon sob veículos e drones (anel aditivo + disco)
function neonGlow(col, size, lift) { const g = new THREE.Group(), c = new THREE.Color(col);
  const disk = new THREE.Mesh(new THREE.CircleGeometry(size * 0.6, 24), new THREE.MeshBasicMaterial({ color: c, transparent: true, opacity: 0.35, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false })); disk.rotation.x = -Math.PI / 2; disk.position.y = 0.05; g.add(disk);
  const ring = new THREE.Mesh(new THREE.TorusGeometry(size * 0.45, 0.04, 6, 32), new THREE.MeshBasicMaterial({ color: c, toneMapped: false })); ring.rotation.x = -Math.PI / 2; ring.position.y = Math.max(0.15, lift * 0.6); g.add(ring); return g; }
// ---------- montarias ----------
export function setMount(id) { COMP.mountId = id; saveComp(); return toggleRide(true); }
export async function toggleRide(force) {
  const me = X.me(); if (!COMP.mountId) { X.toast('Você não escolheu uma montaria — use uma na bolsa', 'err'); return; }
  if (COMP.riding && !force) { dismount(); return; }
  if (X.S.dead) return; const d = def(COMP.mountId);
  if (!COMP.mount || COMP.mount.id !== COMP.mountId) { if (COMP.mount) X.scene.remove(COMP.mount.root); const C = await makeCreature(d.model, { length: d.len, tint: d.tint, tintMix: 0.3, ghost: d.ghost, lift: d.hover, emissive: d.neon, ei: 0.25, keepMetal: !!d.neon }); C.id = COMP.mountId; COMP.mount = C; if (d.hover) C.h += d.hover * 0.2; if (d.neon) C.root.add(neonGlow(d.neon, d.len, d.hover || 0));
    if (d.fly) C.root.add(C.wingGroup = buildWings(d.wings || '#ffffff', 1.6, C.h * 0.78, C.len * 0.08)); }
  X.scene.add(COMP.mount.root); COMP.riding = true; X.S.autoAtk = false;
  emit(me.x, X.WG.height(me.x, me.z) + 0.6, me.z, { n: 30, color: 0xd8c8a0, speed: 3, up: 1.4, life: 0.7, size: 0.3 });
  X.toast(`${d.icon} Montado em ${d.name}${d.fly ? ' — V para voar' : ''}`, 'ok'); saveComp();
}
export function dismount() { if (!COMP.riding) return; COMP.riding = false; if (COMP.mount) X.scene.remove(COMP.mount.root); if (X.S.fly && !COMP.wingsId) { X.S.fly = false; } }
export const saddle = () => COMP.riding && COMP.mount ? COMP.mount.h * (def(COMP.mountId)?.seat ?? 0.56) : 0;
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
  if (COMP.riding && COMP.mount) { const C = COMP.mount; { const dd = def(COMP.mountId) || {}, sz = (dd.seatZ ?? -0.13) * C.len, ry = me.root.rotation.y; C.root.position.set(me.x + Math.sin(ry) * sz, base + S.alt, me.z + Math.cos(ry) * sz); C.root.rotation.y = ry; }
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
    // histerese: só volta a andar quando o dono se afasta, e não ultrapassa o ponto de parada (sem tremer ao parar)
    if (!P.go && dist > (fighting || tg ? 1.4 : 2.6)) P.go = true; else if (P.go && dist < 0.35) P.go = false;
    const sp = !P.go ? 0 : dist > 6 ? speed * 1.15 : dist > 1.6 ? speed * 0.8 : Math.max(1.6, speed * 0.45); if (sp) { const stp = Math.min(sp * dt, dist); P.x += dx / dist * stp; P.z += dz / dist * stp; if (dist > 0.25) P.ry = Math.atan2(dx, dz); } else if (!moving && !fighting) P.ry = me.ry;
    const lv = petLevel(COMP.petId), role = d?.role || 'atk', TL = petTal(COMP.petId);
    if (fighting && t > P.nextAtk) { P.nextAtk = t + (role === 'atk' ? 1800 : 2600); P.play('attack', { once: true, fade: 0.08 }); P.atkUntil = t + 700; P.ry = Math.atan2(tg.x - P.x, tg.z - P.z); X.petHit(tg, (role === 'atk' ? 0.22 : 0.1) * (1 + lv * 0.04) * (1 + TL.f * 0.06)); }
    // ajuda automática: curandeiros recuperam a vida do dono; reforços recuperam mana
    if (t > (P.nextAid || 0) && !S.dead) { if (role === 'heal' && X.petHeal && X.petHeal('hp', (0.03 + lv * 0.0015) * (1 + TL.v * 0.06), 0.75)) { P.nextAid = t + 8000 * (1 - TL.v * 0.02); emit(P.x, WG.height(P.x, P.z) + 0.6, P.z, { n: 14, color: 0x7dff9a, speed: 1.4, up: 2, life: 0.7, size: 0.16 }); }
      else if (role === 'buff' && X.petHeal && X.petHeal('mp', (0.025 + lv * 0.001) * (1 + TL.v * 0.06), 0.6)) { P.nextAid = t + 9000 * (1 - TL.v * 0.02); emit(P.x, WG.height(P.x, P.z) + 0.6, P.z, { n: 14, color: 0x7ab8ff, speed: 1.4, up: 2, life: 0.7, size: 0.16 }); } else P.nextAid = t + 1000; }
    else if (!(P.atkUntil > t)) { const want = sp > 6 ? 'run' : sp ? 'walk' : (Math.sin(t / 4000) > 0.7 ? 'eat' : 'idle'); if (want !== P.want) { P.want = want; P.wantAt = t; } if (P.wcur !== want && (t - P.wantAt > 140 || !P.wcur)) { P.wcur = want; } P.play(P.wcur || want); }
    let a = P.root.rotation.y, dd = P.ry - a; dd = Math.atan2(Math.sin(dd), Math.cos(dd)); P.root.rotation.y = a + dd * Math.min(1, dt * 8);
    const py = WG.height(P.x, P.z) + (d?.flyer ? 1.4 + Math.sin(t / 300) * 0.15 : 0) + (S.fly && d?.flyer ? S.alt : 0); P.root.position.set(P.x, py, P.z); P.mixer.update(dt);
  }
}
function flap(g, t, fast) { const sp = fast ? 0.012 : 0.003, a = Math.sin(t * sp) * (fast ? 0.55 : 0.12); for (const w of g.children) { const s = w.userData.side; w.rotation.y = s * (0.5 + a); w.rotation.z = s * a * 0.4; } }
