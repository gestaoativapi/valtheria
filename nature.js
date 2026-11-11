// ===== Valtheria — natureza e fauna 3D (modelos CC0 da Quaternius: Stylized Nature MegaKit e Animals) =====
// Árvores, arbustos, flores, samambaias e rochas em GLB perto do jogador; longe continuam as versões leves procedurais.
import * as THREE from './three.module.min.js';
import { GLTFLoader } from './GLTFLoader.js';
import { MeshoptDecoder } from './meshopt_decoder.module.js';
import { mergeGeometries } from './BufferGeometryUtils.js';
import { clone as skClone } from './SkeletonUtils.js';
import { windify } from './world3d.js';

const loader = new GLTFLoader(); loader.setMeshoptDecoder(MeshoptDecoder);
const path = n => n + '.glb';
export const NAT = { ready: false, parts: {} };
// variações por tipo de árvore procedural (acácia, cristal e gelo seguem procedurais)
export const TREE_GLB = {
  folhosa: ['n_commontree_1', 'n_commontree_2', 'n_commontree_3'],
  conifera: ['n_pine_1', 'n_pine_2', 'n_pine_3'],
  morta: ['n_deadtree_1', 'n_deadtree_2'],
  outono: ['n_commontree_1', 'n_twistedtree_1', 'n_commontree_2', 'n_twistedtree_2'],
};
const UNDER = ['n_bush_common', 'n_bush_common_flowers', 'n_fern_1', 'n_plant_1_big', 'n_flower_3_group', 'n_flower_4_group', 'n_mushroom_common'];
const ROCKS = ['n_rock_medium_1', 'n_rock_medium_2', 'n_rock_medium_3'];
const SCALE = { n_twistedtree_1: 0.5, n_twistedtree_2: 0.5, n_deadtree_1: 0.8, n_deadtree_2: 0.75 };
const ALL = [...new Set([...Object.values(TREE_GLB).flat(), ...UNDER, ...ROCKS])];

const MATS = new Map();
function natMat(src) {
  const name = src.name || 'm';
  if (MATS.has(name)) return MATS.get(name);
  const leafy = /leaf|leaves|flower|pine|fern/i.test(name);
  const m = new THREE.MeshLambertMaterial({ map: src.map || null, color: src.color ? src.color.clone() : 0xffffff, side: leafy ? THREE.DoubleSide : THREE.FrontSide,
    alphaTest: leafy && src.map ? 0.45 : 0, transparent: false });
  if (m.map) m.map.anisotropy = 4;
  if (/rock/i.test(name)) m.color.multiplyScalar(1.7); else if (leafy) m.color.multiplyScalar(1.12);
  if (leafy) { windify(m, 0.045, 2.2); const w = m.onBeforeCompile, key = m.customProgramCacheKey();
    // folhas de dois lados: não inverte a normal no verso (senão metade da copa fica preta)
    m.onBeforeCompile = (sh) => { w(sh); sh.fragmentShader = sh.fragmentShader.replace('#include <normal_fragment_begin>', '#include <normal_fragment_begin>\nnormal = normalize(vNormal); nonPerturbedNormal = normal;'); };
    m.customProgramCacheKey = () => key + 'leaf2'; }
  m.name = name; MATS.set(name, m); return m;
}
async function loadPart(n) {
  const g = await loader.loadAsync(path(n)); g.scene.updateMatrixWorld(true);
  const by = new Map();
  g.scene.traverse(o => {
    if (!o.isMesh) return;
    const mats = Array.isArray(o.material) ? o.material : [o.material];
    const geo = o.geometry.index ? o.geometry : o.geometry; const groups = geo.groups.length && mats.length > 1 ? geo.groups : [{ start: 0, count: Infinity, materialIndex: 0 }];
    for (const gr of groups) {
      let gg = geo.clone(); if (groups.length > 1) { const idx = geo.index.array.slice(gr.start, gr.start + gr.count); gg.setIndex(Array.from(idx)); }
      for (const k of Object.keys(gg.attributes)) if (!['position', 'normal', 'uv'].includes(k)) gg.deleteAttribute(k);
      gg.applyMatrix4(o.matrixWorld); const mt = natMat(mats[gr.materialIndex] || mats[0]);
      (by.get(mt) || by.set(mt, []).get(mt)).push(gg.index ? gg : gg);
    }
  });
  const s = SCALE[n] || 1;
  NAT.parts[n] = [...by.entries()].map(([mat, gs]) => {
    const geo = gs.length > 1 ? mergeGeometries(gs, false) : gs[0]; if (s !== 1) geo.scale(s, s, s);
    if (mat.side === THREE.DoubleSide) softNormals(geo);
    geo.computeBoundingSphere(); return { geo, mat }; });
}
// normais "esféricas" na folhagem: copa iluminada por igual, sem faces pretas
function softNormals(geo) {
  geo.computeBoundingBox(); const c = geo.boundingBox.getCenter(new THREE.Vector3()), P = geo.attributes.position, N = geo.attributes.normal, v = new THREE.Vector3(), n = new THREE.Vector3();
  for (let i = 0; i < P.count; i++) { v.fromBufferAttribute(P, i).sub(c).normalize(); n.fromBufferAttribute(N, i).multiplyScalar(0.25).addScaledVector(v, 0.75); n.y += 0.35; n.normalize(); N.setXYZ(i, n.x, n.y, n.z); }
  N.needsUpdate = true;
}
let loading = null;
export function loadNature() {
  if (!loading) loading = Promise.all(ALL.map(n => loadPart(n).catch(e => console.warn('natureza', n, e)))).then(() => { NAT.ready = true; });
  return loading;
}

// constrói os GLB de um bloco (chunk). d = { trees: {kind: [[x,h,z,sc,r]]}, rocks: [[...],[...],[...]], under: [[x,h,z,sc,r,k]], theme, rockTint }
const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), sv = new THREE.Vector3(), pv = new THREE.Vector3(), up = new THREE.Vector3(0, 1, 0), tc = new THREE.Color();
function addInst(group, name, pts, place, shadow, tint) {
  const parts = NAT.parts[name]; if (!parts || !pts.length) return;
  for (const { geo, mat } of parts) {
    const im = new THREE.InstancedMesh(geo, mat, pts.length);
    pts.forEach((p, i) => { place(p); m4.compose(pv, q, sv); im.setMatrixAt(i, m4); if (tint) im.setColorAt(i, tc.set(tint)); });
    im.castShadow = shadow; im.receiveShadow = true; im.computeBoundingSphere(); group.add(im);
  }
}
export function buildNatureChunk(d) {
  const group = new THREE.Group(), handled = new Set();
  for (const [kind, pts] of Object.entries(d.trees)) {
    const list = kind === 'folhosa' && d.theme === 'outono' ? TREE_GLB.outono : TREE_GLB[kind]; if (!list) continue;
    handled.add(kind);
    list.forEach((name, vi) => {
      const sub = pts.filter((p, i) => (i + Math.floor(p[0])) % list.length === vi);
      addInst(group, name, sub, ([x, h, z, sc, r]) => { q.setFromAxisAngle(up, r); sv.setScalar(sc * 1.05); pv.set(x, h - 0.15, z); }, true);
    });
  }
  d.rocks.forEach((pts, k) => addInst(group, ROCKS[k], pts, ([x, h, z, sc, r]) => { q.setFromAxisAngle(up, r); sv.set(sc * 0.9, sc * 0.75, sc * 0.9); pv.set(x, h - sc * 0.2, z); }, true, d.rockTint));
  const red = d.theme === 'outono';
  UNDER.forEach((name, k) => addInst(group, name, d.under.filter(p => (p[5] === 0 && !red ? 1 : p[5]) === k), ([x, h, z, sc, r]) => { q.setFromAxisAngle(up, r); sv.setScalar(sc); pv.set(x, h - 0.05, z); }, false));
  return { group, handled };
}
export function disposeNature(n) { n.group.children.forEach(o => o.dispose && o.dispose()); n.group.removeFromParent(); }

// ---------- lobo animado (Quaternius Animals, CC0) ----------
let WOLF = null;
export function loadWolf() { if (!WOLF) WOLF = loader.loadAsync(path('m_wolf')).then(g => { const b = new THREE.Box3().setFromObject(g.scene, true); g.h = b.max.y - b.min.y; g.len = b.max.z - b.min.z; return g; }); return WOLF; }
export async function attachWolf(R, fam) {
  const g = await loadWolf(); if (R.disposed) return;
  const w = skClone(g.scene), k = 1.55 / Math.max(g.len, 0.01); w.scale.setScalar(k);
  w.traverse(o => {
    if (!o.isMesh) return; o.castShadow = true; o.frustumCulled = false;
    const src = o.material, m = new THREE.MeshLambertMaterial({ color: src.color.clone() });
    if (fam.ghost) { m.color.lerp(new THREE.Color(fam.color), 0.6); m.emissive = new THREE.Color(0x2a5aaa); m.emissiveIntensity = 0.7; m.transparent = true; m.opacity = 0.7; }
    else if (/main/i.test(src.name)) m.color.lerp(new THREE.Color(fam.color), 0.35);
    o.material = m;
  });
  R.body.children.forEach(c => c.visible = false); R.legs = [];
  R.body.add(w); R.wolf = w; R.mixer = new THREE.AnimationMixer(w); R.clips = {};
  for (const c of g.animations) R.clips[c.name] = R.mixer.clipAction(c);
  R.cur = null; wolfPlay(R, 'Idle');
}
function wolfPlay(R, name, once) {
  const a = R.clips[name]; if (!a || R.cur === a) return;
  a.reset(); a.setLoop(once ? THREE.LoopOnce : THREE.LoopRepeat); a.clampWhenFinished = !!once; a.fadeIn(0.18).play();
  if (R.cur) R.cur.fadeOut(0.18); R.cur = a;
}
export function animWolf(R, dt, moving) {
  const A = R.anim;
  if (A.state === 'dead') wolfPlay(R, 'Death', true);
  else if (A.atk >= 0) { wolfPlay(R, 'Attack', true); if (performance.now() - A.atk > 650) A.atk = -1; }
  else wolfPlay(R, moving ? (R.fast ? 'Gallop' : 'Walk') : 'Idle');
  R.mixer.update(dt);
}
