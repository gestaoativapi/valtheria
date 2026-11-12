// ===== Valtheria — criaturas animadas em GLB (Quaternius Animals e Easy Enemies, CC0) =====
// Usado por monstros, pets, montarias e fauna ambiente.
import * as THREE from './lib/three.module.min.js';
import { GLTFLoader } from './lib/GLTFLoader.js';
import { MeshoptDecoder } from './lib/meshopt_decoder.module.js';
import { clone as skClone } from './lib/SkeletonUtils.js';

const loader = new GLTFLoader(); loader.setMeshoptDecoder(MeshoptDecoder);
const CACHE = new Map();
export function loadCreature(name) {
  if (!CACHE.has(name)) CACHE.set(name, loader.loadAsync('assets/world/' + name + '.glb').then(g => {
    const b = new THREE.Box3().setFromObject(g.scene, true); g.size = b.getSize(new THREE.Vector3()); g.minY = b.min.y; return g; }));
  return CACHE.get(name);
}
// nomes de animação equivalentes entre os pacotes
const ALIAS = { idle: ['Idle', 'Flying', 'Idle_2', 'Flying_Idle'], walk: ['Walk', 'Flying', 'Fast_Flying', 'Flying_Idle'], run: ['Gallop', 'Run', 'Walk', 'Flying', 'Fast_Flying'], attack: ['Attack', 'Attack_Headbutt', 'Attack_Kick', 'Punch', 'Headbutt', 'Shoot', 'Shoot_Big', 'SwordSlash', 'Weapon', 'Kick'], death: ['Death', 'Dead'], eat: ['Eating', 'Idle_Headlow', 'Idle_2_HeadLow', 'Idle'], hit: ['Idle_HitReact_Left', 'Idle_HitReact_Right', 'HitReact', 'HitRecieve_1'], jump: ['Gallop_Jump', 'Jump'] };
// o = { length (m, maior medida horizontal) | height, tint, tintMix, ghost, emissive }
export async function makeCreature(name, o = {}) {
  const g = await loadCreature(name), root = new THREE.Group(), obj = skClone(g.scene);
  const horiz = Math.max(g.size.x, g.size.z), k = o.height ? o.height / g.size.y : (o.length || 1.5) / horiz;
  obj.scale.setScalar(k); obj.position.y = -g.minY * k + (o.lift || 0); root.add(obj);
  obj.traverse(m => {
    if (!m.isMesh) return; m.castShadow = true; m.frustumCulled = false; if (!m.geometry.attributes.normal) m.geometry.computeVertexNormals();
    const mats = Array.isArray(m.material) ? m.material : [m.material];
    const nm = mats.map(src => { const t = src.isMeshBasicMaterial ? new THREE.MeshStandardMaterial({ name: src.name, map: src.map, color: src.color, transparent: src.transparent, alphaTest: src.alphaTest, side: src.side }) : src.clone(); t.metalness = 0; t.roughness = Math.max(0.6, t.roughness ?? 1);
      if (o.tint) t.color.lerp(new THREE.Color(o.tint), o.tintMix ?? 0.45);
      if (o.ghost) { t.transparent = true; t.opacity = 0.72; t.emissive = new THREE.Color(o.ghost); t.emissiveIntensity = 0.6; }
      else if (o.emissive) { t.emissive = new THREE.Color(o.emissive); t.emissiveIntensity = o.ei ?? 0.35; }
      if (o.keepMetal && t.isMeshStandardMaterial) { t.roughness = 0.42; }
      return t; });
    m.material = Array.isArray(m.material) ? nm : nm[0];
  });
  const mixer = new THREE.AnimationMixer(obj), clips = {};
  for (const c of g.animations) clips[c.name] = c;
  const C = { root, obj, mixer, clips, cur: null, curName: '', scale: k, h: g.size.y * k, len: horiz * k, lift: o.lift || 0, baseY: obj.position.y };
  C.play = (want, opt = {}) => {
    const list = [want, ...(ALIAS[want] || [])]; let clip = null; for (const n of list) if (clips[n]) { clip = clips[n]; break; }
    if (!clip || (C.curName === clip.name && !opt.once)) return;
    const a = mixer.clipAction(clip); a.reset(); a.setLoop(opt.once ? THREE.LoopOnce : THREE.LoopRepeat); a.clampWhenFinished = !!opt.once; a.timeScale = opt.speed || 1;
    a.fadeIn(opt.fade ?? 0.2).play(); if (C.cur && C.cur !== a) C.cur.fadeOut(opt.fade ?? 0.2); C.cur = a; C.curName = clip.name;
  };
  C.play('idle'); return C;
}
// ---------- monstros: família → modelo ----------
export const MOB_GLB = {
  lobo: { m: 'm_wolf', len: 1.55, tint: null }, lobo_esp: { m: 'm_wolf', len: 1.7, ghost: 0x2a5aaa },
  javali: { m: 'a_bull', len: 1.5, tint: '#4a2e1a', tintMix: 0.6 }, rei_javali: { m: 'a_bull', len: 1.7, tint: '#2a1a10', tintMix: 0.7 },
  aranha: { m: 'e_spider', len: 1.6, tint: '#3a2a3a', tintMix: 0.3 }, rainha: { m: 'e_spider', len: 1.7, tint: '#6a1a8a', tintMix: 0.55, emissive: 0x3a0a4a },
  lagarto: { m: 'e_snake', len: 2.4, tint: '#4a6a2a', tintMix: 0.4 },
  // Era Neon (Quaternius Ultimate Space Kit, Cyberpunk Game Kit e Animated Mech Pack — CC0)
  drone_sent: { m: 'x_drone', len: 1.3, emissive: 0x1ac8ff, ei: 0.5, lift: 1.4, keepMetal: true }, vigia: { m: 'x_flyer', len: 1.5, emissive: 0xff2ad0, ei: 0.45, lift: 1.8, keepMetal: true },
  plasmoide: { m: 'x_glub', len: 1.3, tint: '#5aff7a', tintMix: 0.35, emissive: 0x2aff5a, ei: 0.55, lift: 0.9 }, andarilho: { m: 'x_walker', len: 1.5, emissive: 0x2a8aff, ei: 0.3, keepMetal: true },
  mecha_batedor: { m: 'x_mech', len: 2.4, emissive: 0xffa02a, ei: 0.25, keepMetal: true }, colosso: { m: 'x_brute', len: 3.6, tint: '#4a2a8a', tintMix: 0.35, emissive: 0x8a3aff, ei: 0.35, keepMetal: true },
  mecha_omega: { m: 'x_leela', len: 3.4, emissive: 0x3af0ff, ei: 0.35, keepMetal: true },
  // dragões e répteis (Quaternius Animated Dinosaur Pack, CC0) e golens
  dragonete: { m: 'z_raptor', len: 2.3, tint: '#6a4a9a', tintMix: 0.6, emissive: 0x3a1a7a, ei: 0.25 }, dragao: { m: 'z_trex', len: 2.6, tint: '#d0b060', tintMix: 0.55, emissive: 0x7a4a10, ei: 0.3 },
  wyrm_gelo: { m: 'z_trex', len: 2.6, tint: '#9ad0f0', tintMix: 0.7, emissive: 0x2a6a9a, ei: 0.35 }, hidra: { m: 'z_apato', len: 3.2, tint: '#3a7a4a', tintMix: 0.6, emissive: 0x0a3a1a, ei: 0.2 },
  golem: { m: 'x_brute', len: 2.2, tint: '#8a8478', tintMix: 0.85 }, golem_anc: { m: 'x_brute', len: 2.3, tint: '#5a6a7a', tintMix: 0.85, emissive: 0x2a5a8a, ei: 0.25 }, guardiao_ruinas: { m: 'x_brute', len: 2.3, tint: '#6a7a6a', tintMix: 0.85, emissive: 0x2a6a3a, ei: 0.25 },
  sapo_g: { m: 'e_frog', len: 1.8, tint: '#2a4a1a', tintMix: 0.45, emissive: 0x1a3a0a }, rato_g: { m: 'e_rat', len: 1.9, tint: '#4a3a2a', tintMix: 0.4 }, vespa_g: { m: 'e_wasp', len: 1.8, tint: '#3a1a6a', tintMix: 0.5, emissive: 0x5a2aaa },
};
export async function attachMobGLB(R, fam, def) {
  const C = await makeCreature(def.m, { length: def.len, tint: def.tint || (def.ghost ? null : null), tintMix: def.tintMix, ghost: def.ghost, emissive: def.emissive, ei: def.ei, lift: def.lift, keepMetal: def.keepMetal });
  if (R.disposed) return;
  R.body.children.forEach(c => c.visible = false); R.legs = [];
  R.body.add(C.root); R.glbC = C; R.glbH = C.h;
}
export function animMobGLB(R, dt, moving) {
  const C = R.glbC, A = R.anim;
  if (A.state === 'dead') C.play('death', { once: true });
  else if (A.atk >= 0) { if (!R.atkPlayed || R.atkPlayed !== A.atk) { R.atkPlayed = A.atk; C.play('attack', { once: true, fade: 0.08 }); R.atkEnd = performance.now() + 700; } if (performance.now() > R.atkEnd) A.atk = -1; }
  else C.play(moving ? (R.fast ? 'run' : 'walk') : 'idle');
  if (C.lift && A.state !== 'dead') C.obj.position.y = C.baseY + Math.sin(performance.now() / 380 + R.root.id) * 0.22; else if (C.lift) C.obj.position.y += (C.baseY - C.lift - C.obj.position.y) * Math.min(1, dt * 3);
  C.mixer.update(dt);
}
