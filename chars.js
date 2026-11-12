// ===== Valtheria — personagens 3D (modelos CC0 da Quaternius: Universal Base Characters,
// Modular Character Outfits - Fantasy, Universal Animation Library 1 e 2, Fantasy Props MegaKit) =====
import * as THREE from './lib/three.module.min.js';
import { GLTFLoader } from './lib/GLTFLoader.js';
import { clone as skClone } from './lib/SkeletonUtils.js';
import { MeshoptDecoder } from './lib/meshopt_decoder.module.js';

const loader = new GLTFLoader(); loader.setMeshoptDecoder(MeshoptDecoder);
const CACHE = new Map();
export function loadGLB(name) { if (!CACHE.has(name)) CACHE.set(name, loader.loadAsync('assets/chars/' + name + '.glb')); return CACHE.get(name); }
let CLIPS = null;
export async function loadClips() {
  if (CLIPS) return CLIPS;
  const [a, b] = await Promise.all([loadGLB('anims_a'), loadGLB('anims_b')]);
  CLIPS = {}; for (const c of [...a.animations, ...b.animations]) CLIPS[c.name] = c;
  // animações extras (escalar, nadar, rolar, combos) chegam depois, sem atrasar a entrada no jogo
  Promise.all([loadGLB('anims_c'), loadGLB('anims_d')]).then(([c, d]) => { for (const x of [...c.animations, ...d.animations]) CLIPS[x.name] = x; }).catch(() => {});
  return CLIPS;
}
export async function preload(list) { await Promise.all([loadClips(), ...list.map(loadGLB)]); }

// liga as malhas de um GLB (roupa, cabelo) ao esqueleto do corpo-base
function attachSkinned(root, bones, src) {
  const sc = skClone(src.scene); const meshes = [];
  sc.traverse(o => { if (o.isSkinnedMesh) meshes.push(o); });
  for (const m of meshes) {
    const sk = new THREE.Skeleton(m.skeleton.bones.map(b => bones[b.name] || b), m.skeleton.boneInverses);
    m.removeFromParent(); root.add(m); m.bind(sk, m.bindMatrix); m.frustumCulled = false; m.castShadow = true;
  }
  return meshes;
}
export async function createCharacter(o = {}) {
  const g = o.gender === 'f' ? 'female' : 'male';
  const base = await loadGLB('base_' + g), clips = await loadClips();
  const root = new THREE.Group(); const model = skClone(base.scene); root.add(model);
  const bones = {}; model.traverse(x => { if (x.isBone) bones[x.name] = x; if (x.isMesh) { x.castShadow = true; x.frustumCulled = false; } });
  const C = { root, model, bones, parts: {}, mixer: new THREE.AnimationMixer(model), actions: {}, cur: null, gender: g };
  for (const [n, clip] of Object.entries(clips)) C.actions[n] = C.mixer.clipAction(clip);
  if (o.body) { // corpo próprio da raça (ex.: dragonita): troca a malha humana e ajusta o comprimento dos ossos
    const src = await loadGLB('body_' + o.body); model.traverse(x => { if (x.isSkinnedMesh) x.visible = false; });
    src.scene.traverse(x => { if (x.isBone && bones[x.name]) bones[x.name].position.copy(x.position); });
    C.parts.body = attachSkinned(model, bones, src); C.customBody = o.body; return C; }
  if (o.outfit) await setOutfit(C, o.outfit);
  if (o.hair) await setPart(C, 'hair', 'hair_' + o.hair);
  return C;
}
export async function setPart(C, slot, name) {
  (C.parts[slot] || []).forEach(m => m.removeFromParent()); C.parts[slot] = [];
  if (!name) return; const src = await loadGLB(name); C.parts[slot] = attachSkinned(C.model, C.bones, src);
}
export async function setOutfit(C, kind) { await setPart(C, 'outfit', kind ? `outfit_${C.gender}_${kind}` : null); maskBody(C, kind); }
// esconde a pele do corpo-base que fica por baixo da roupa (evita a pele "furar" o tecido)
const MASKS = new Map();
function bodyMeshes(C) { const out = []; C.model.traverse(o => { if (o.isSkinnedMesh && !Object.values(C.parts).some(p => p.includes(o))) out.push(o); }); return out; }
function maskBody(C, kind) {
  const body = bodyMeshes(C).sort((a, b) => b.geometry.attributes.position.count - a.geometry.attributes.position.count)[0]; if (!body) return;
  if (!body.userData.fullIndex) body.userData.fullIndex = body.geometry.index;
  const key = C.gender + ':' + kind;
  if (!kind) { body.geometry = body.userData.fullGeo || body.geometry; return; }
  if (!MASKS.has(key)) {
    C.model.updateMatrixWorld(true); const v = new THREE.Vector3(), CELL = 0.04, grid = new Map(), k3 = (x, y, z) => x + ',' + y + ',' + z;
    for (const m of C.parts.outfit) { m.skeleton.update(); const pa = m.geometry.attributes.position; for (let i = 0; i < pa.count; i++) { m.getVertexPosition(i, v); v.applyMatrix4(m.matrixWorld); const k = k3(Math.floor(v.x / CELL), Math.floor(v.y / CELL), Math.floor(v.z / CELL)); let a = grid.get(k); if (!a) grid.set(k, a = []); a.push(v.x, v.y, v.z); } }
    body.skeleton.update(); const g = body.geometry, pa = g.attributes.position, sk = g.attributes.skinIndex, sw = g.attributes.skinWeight, headIdx = body.skeleton.bones.findIndex(b => b.name === 'Head'), neckIdx = body.skeleton.bones.findIndex(b => b.name === 'neck_01');
    const cov = new Uint8Array(pa.count), TH = 0.065 * 0.065;
    for (let i = 0; i < pa.count; i++) {
      let bi = 0, bw = -1; for (let j = 0; j < 4; j++) { const w = sw.getComponent(i, j); if (w > bw) { bw = w; bi = sk.getComponent(i, j); } } if (bi === headIdx || bi === neckIdx) continue;
      body.getVertexPosition(i, v); v.applyMatrix4(body.matrixWorld); const cx = Math.floor(v.x / CELL), cy = Math.floor(v.y / CELL), cz = Math.floor(v.z / CELL);
      search: for (let dx = -2; dx <= 2; dx++) for (let dy = -2; dy <= 2; dy++) for (let dz = -2; dz <= 2; dz++) { const a = grid.get(k3(cx + dx, cy + dy, cz + dz)); if (!a) continue; for (let q = 0; q < a.length; q += 3) { const ex = a[q] - v.x, ey = a[q + 1] - v.y, ez = a[q + 2] - v.z; if (ex * ex + ey * ey + ez * ez < TH) { cov[i] = 1; break search; } } }
    }
    const src = body.userData.fullIndex.array, keep = []; for (let t = 0; t < src.length; t += 3) if (!(cov[src[t]] && cov[src[t + 1]] && cov[src[t + 2]])) keep.push(src[t], src[t + 1], src[t + 2]);
    const ng = g.clone(); ng.setIndex(keep); MASKS.set(key, ng);
  }
  if (!body.userData.fullGeo) body.userData.fullGeo = body.geometry;
  body.geometry = MASKS.get(key);
}
export function play(C, name, { fade = 0.2, once = false, speed = 1 } = {}) {
  let a = C.actions[name]; if (!a && CLIPS && CLIPS[name]) a = C.actions[name] = C.mixer.clipAction(CLIPS[name]);
  if (!a || C.cur === a && !once) return a;
  a.reset(); a.setEffectiveTimeScale(speed); a.setLoop(once ? THREE.LoopOnce : THREE.LoopRepeat); a.clampWhenFinished = once;
  if (C.cur && C.cur !== a) a.crossFadeFrom(C.cur, fade, true); a.play(); C.cur = a; return a;
}
