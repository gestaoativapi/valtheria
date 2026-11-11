// ===== Valtheria — criaturas animadas em GLB (Quaternius Animals e Easy Enemies, CC0) =====
// Usado por monstros, pets, montarias e fauna ambiente.
import * as THREE from './three.module.min.js';
import { GLTFLoader } from './GLTFLoader.js';
import { MeshoptDecoder } from './meshopt_decoder.module.js';
import { clone as skClone } from './SkeletonUtils.js';

const loader = new GLTFLoader(); loader.setMeshoptDecoder(MeshoptDecoder);
const CACHE = new Map();
export function loadCreature(name) {
  if (!CACHE.has(name)) CACHE.set(name, loader.loadAsync(name + '.glb').then(g => {
    const b = new THREE.Box3().setFromObject(g.scene, true); g.size = b.getSize(new THREE.Vector3()); g.minY = b.min.y; return g; }));
  return CACHE.get(name);
}
// nomes de animação equivalentes entre os pacotes
const ALIAS = { idle: ['Idle', 'Flying', 'Idle_2'], walk: ['Walk', 'Flying'], run: ['Gallop', 'Run', 'Walk', 'Flying'], attack: ['Attack', 'Attack_Headbutt', 'Attack_Kick'], death: ['Death'], eat: ['Eating', 'Idle_Headlow', 'Idle_2_HeadLow', 'Idle'], hit: ['Idle_HitReact_Left', 'Idle_HitReact_Right'], jump: ['Gallop_Jump', 'Jump'] };
// o = { length (m, maior medida horizontal) | height, tint, tintMix, ghost, emissive }
export async function makeCreature(name, o = {}) {
  const g = await loadCreature(name), root = new THREE.Group(), obj = skClone(g.scene);
  const horiz = Math.max(g.size.x, g.size.z), k = o.height ? o.height / g.size.y : (o.length || 1.5) / horiz;
  obj.scale.setScalar(k); obj.position.y = -g.minY * k; root.add(obj);
  obj.traverse(m => {
    if (!m.isMesh) return; m.castShadow = true; m.frustumCulled = false;
    const mats = Array.isArray(m.material) ? m.material : [m.material];
    const nm = mats.map(src => { const t = src.clone(); t.metalness = 0; t.roughness = Math.max(0.6, t.roughness ?? 1);
      if (o.tint) t.color.lerp(new THREE.Color(o.tint), o.tintMix ?? 0.45);
      if (o.ghost) { t.transparent = true; t.opacity = 0.72; t.emissive = new THREE.Color(o.ghost); t.emissiveIntensity = 0.6; }
      else if (o.emissive) { t.emissive = new THREE.Color(o.emissive); t.emissiveIntensity = 0.35; }
      return t; });
    m.material = Array.isArray(m.material) ? nm : nm[0];
  });
  const mixer = new THREE.AnimationMixer(obj), clips = {};
  for (const c of g.animations) clips[c.name] = c;
  const C = { root, obj, mixer, clips, cur: null, curName: '', scale: k, h: g.size.y * k, len: horiz * k };
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
  sapo_g: { m: 'e_frog', len: 1.8, tint: '#2a4a1a', tintMix: 0.45, emissive: 0x1a3a0a }, rato_g: { m: 'e_rat', len: 1.9, tint: '#4a3a2a', tintMix: 0.4 }, vespa_g: { m: 'e_wasp', len: 1.8, tint: '#3a1a6a', tintMix: 0.5, emissive: 0x5a2aaa },
};
export async function attachMobGLB(R, fam, def) {
  const C = await makeCreature(def.m, { length: def.len, tint: def.tint || (def.ghost ? null : null), tintMix: def.tintMix, ghost: def.ghost, emissive: def.emissive });
  if (R.disposed) return;
  R.body.children.forEach(c => c.visible = false); R.legs = [];
  R.body.add(C.root); R.glbC = C; R.glbH = C.h;
}
export function animMobGLB(R, dt, moving) {
  const C = R.glbC, A = R.anim;
  if (A.state === 'dead') C.play('death', { once: true });
  else if (A.atk >= 0) { if (!R.atkPlayed || R.atkPlayed !== A.atk) { R.atkPlayed = A.atk; C.play('attack', { once: true, fade: 0.08 }); R.atkEnd = performance.now() + 700; } if (performance.now() > R.atkEnd) A.atk = -1; }
  else C.play(moving ? (R.fast ? 'run' : 'walk') : 'idle');
  C.mixer.update(dt);
}
