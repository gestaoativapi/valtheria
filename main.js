// ===== Valtheria — cliente =====
import * as THREE from './lib/three.module.min.js';
import { buildHumanoid, setGear, animHumanoid, playAttack, upgradeGLB, buildMob, animMob, buildNode, buildHouse, makeLabel, mat } from './models.js';
import { updateWaterDepth, createSky, createWater, dayPhase, sunVectors, WIND, makeFire, updateFires, initLightPool, createGrass, layoutGrass, ROCK_GEOS, rockMat, TREE_KINDS, leafMat, treeTrunkMat } from './world3d.js';
import { buildTownArchitecture, buildLandmark, updateTownAnim, stoneify } from './towns.js';
import { buildNeon, buildPortal, updateNeon } from './neon.js';
import { ELEM, elemOf, isMeteor, classElem, initElements, updateElements, elemImpact, meteor, castBurst, bodyAura } from './elements.js';
import { initUI, initBars, toggleEquip, renderEquip, updateEquip, equipOpen, closeEquip } from './ui.js';
import { buildWings } from './companions.js';
import { RoomEnvironment } from './lib/RoomEnvironment.js';
import { NAT, loadNature, buildNatureChunk, disposeNature } from './nature.js';
import { initFX, emit, slash, shock, beam, updateFX, updateTrail, crater } from './fx.js';
import { initAmbient, updateAmbient, AMB } from './ambient.js';
import { POST, initPost, setPostQuality, resizePost, renderPost, postHurt, postFlash } from './post.js';
import { WEATHER, initWeather, updateWeather } from './weather.js';
import { SFX, play as sfx, rain as sfxRain, setMood, saveSfx } from './sfx.js';
import { icon3d, onIconsReady, KIND_AURA } from './icons.js';
import { say, npcLine, bossLine, updateDialog, VOICE, setVoice } from './dialog.js';
import { COMP, initComp, restoreComp, compFx, summonPet, setMount, toggleRide, dismount, setWings, toggleFly, updateComp, saddle, mountSpeed, canFly } from './companions.js';
const GD = window.GD, WG = window.WG, QD = window.QD, CFG = window.GAME_CONFIG || {};
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const now = () => performance.now();

// ---------- dados globais do mundo ----------
const NODES = WG.genNodes().filter(WG.nodeVisible); window.NODES_BY_ID = {}; NODES.forEach(n => window.NODES_BY_ID[n.id] = n);
window.TELEPORTS = []; GD.TOWNS.forEach(t => { TELEPORTS.push({ id: 'town:' + t.id, name: t.name, x: t.x, z: t.z + 25, lvl: t.min, town: true }); t.spotsPos.forEach((s, i) => TELEPORTS.push({ id: `spot:${t.id}:${i}`, name: s.name, x: s.x, z: s.z, lvl: s.lvl })); });
GD.LANDMARKS.forEach(L => TELEPORTS.push({ id: 'lm:' + L.id, name: L.name, x: L.x, z: L.z + 40, lvl: L.lvl, lm: true }));
TELEPORTS.forEach(t => t.cost = GD.teleCost(t.lvl));
const FAM = {}; GD.MOBS.forEach((g, gi) => g.forEach(f => { f.grade = gi; FAM[f.id] = f; })); GD.NEON_MOBS.forEach(f => { FAM[f.id] = f; }); GD.SPECIAL_BOSSES.forEach(f => { f.grade = Math.min(5, GD.gradeForLevel((GD.LANDMARKS.find(l => l.boss === f.id) || {}).lvl || 1)); FAM[f.id] = f; });
const NPC_TYPES = [
  ['portal', 'Guardião do Portal', '#4a7ab0'], ['classe', 'Mestre de Classes', '#a87a2a'], ['ferreiro', 'Ferreiro', '#6a4a3a'],
  ['refino', 'Refinador e Alquimista', '#3a7a4a'], ['mercador', 'Mercador', '#8a6a2a'], ['leilao', 'Casa de Leilões', '#6a3a8a'], ['arauto', 'Arauto do Eclipse', '#b03a3a'],
];

// ---------- estado ----------
let B = null;
const S = { sta: 100, acct: null, chars: [], selected: 0, c: null, inv: {}, dep: {}, hp: 1, mp: 1, buffs: {}, cds: {}, target: null, dest: null, gatherAt: null, npcAt: null,
  others: {}, presence: {}, mobs: [], mobSeq: 0, killQ: [], killBusy: false, dead: false, lastCombat: 0, nextAtk: 0, flagUntil: 0, potCd: 0, q: { active: [], prog: {} }, inGame: false, mode: 'login' };

// ---------- interface ----------
function toast(m, k = '') { const d = document.createElement('div'); d.className = 'toast ' + k; d.textContent = m; $('#toasts').appendChild(d); setTimeout(() => d.remove(), 3200); while ($('#toasts').children.length > 6) $('#toasts').firstChild.remove(); }
async function safe(fn, ok) { try { const r = await fn(); if (ok) toast(typeof ok === 'function' ? ok(r) : ok, 'ok'); return r; } catch (e) { toast(e.message || String(e), 'err'); return undefined; } }
const IT = (id) => GD.ITEMS[id];
const icon = (id) => IT(id)?.icon || '❔';
const iname = (id) => IT(id)?.name || id;
const gcol = (g) => GD.GRADES[g]?.color || '#ccc';
function show(id) { ['#login', '#select', '#create', '#hud', '#loading'].forEach(s => $(s).hidden = s !== id); S.mode = id.slice(1); }

// ---------- renderização ----------
const canvas = $('#view');
const IS_MOBILE = matchMedia('(pointer: coarse)').matches || navigator.maxTouchPoints > 1;
const renderer = new THREE.WebGLRenderer({ canvas, antialias: !IS_MOBILE, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2)); renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.05;
const scene = new THREE.Scene(); initFX(scene); initElements({ scene, H: (x, z) => WG.height(x, z), shake: k => shake(k), sfx: (k, v) => sfx(k, v) });
const _tipV = new THREE.Vector3();
const fxBurst = (x, y, z, color, n = 12, size = 0.2) => emit(x, y, z, { n, color, size, speed: 3, up: 1.5, life: 0.6 });
const camera = new THREE.PerspectiveCamera(55, innerWidth / innerHeight, 0.3, 1200);
addEventListener('resize', () => { renderer.setSize(innerWidth, innerHeight); resizePost(); camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix(); });
const hemi = new THREE.HemisphereLight(0xcfe3ff, 0x5a4a32, 1.15); scene.add(hemi);
initLightPool(scene, IS_MOBILE ? 2 : 4);
{ const pm = new THREE.PMREMGenerator(renderer); scene.environment = pm.fromScene(new RoomEnvironment(), 0.04).texture; scene.environmentIntensity = 0.55; pm.dispose(); }
const sun = new THREE.DirectionalLight(0xfff0d0, 2.4); sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -45, right: 45, top: 45, bottom: -45, near: 1, far: 260 }); sun.shadow.bias = -0.0006; scene.add(sun, sun.target);
scene.fog = new THREE.Fog(0xb8cde0, 140, 420);
const SKY = createSky(), skyMat = SKY.mat, sky = SKY.mesh; scene.add(sky);
const ENV = { night: 0, day: 1, eclipse: 0 };
const THEMES = {
  verde: { g: ['#5d9a3c', '#4a8a32'], top: 0x3a74c4, bot: 0xd8e6f0, fog: 0xb8cde0, leaf: '#4f9a3a', trees: 26, kinds: ['folhosa', 'folhosa', 'conifera'], grass: '#5a9a3a', rocks: 4 },
  outono: { g: ['#9c8a3a', '#86702c'], top: 0x4a74b4, bot: 0xf0dcb0, fog: 0xd8c8a8, leaf: '#c8782a', trees: 22, kinds: ['folhosa'], grass: '#a8963a', rocks: 4 },
  rocha: { g: ['#7a8558', '#8a8576'], top: 0x5a7aa4, bot: 0xd0d4d8, fog: 0xb8bcc4, leaf: '#3f6a3a', trees: 10, kinds: ['conifera'], grass: '#6a7a48', rocks: 14 },
  floresta: { g: ['#2f6a2f', '#2a5a28'], top: 0x2a5a6a, bot: 0xa8d0b0, fog: 0x88b098, leaf: '#1f5a2a', trees: 60, kinds: ['conifera', 'folhosa'], grass: '#2f6a2f', rocks: 5 },
  rubro: { g: ['#b06a3e', '#c48452'], top: 0x8a3a2a, bot: 0xf0b890, fog: 0xd89a78, leaf: '#6a4a2a', trees: 5, kinds: ['acacia', 'morta'], grass: null, rocks: 10 },
  cinza: { g: ['#55536a', '#625a6e'], top: 0x1a0a2a, bot: 0x6a4a7a, fog: 0x4a3a5a, leaf: '#8a6aff', trees: 12, kinds: ['cristal', 'morta'], grass: '#5a5070', rocks: 8, eclipse: 1 },
  savana: { g: ['#b8a050', '#a08a40'], top: 0x4a80c8, bot: 0xf0e0b8, fog: 0xe0d0a8, leaf: '#6a8a2a', trees: 8, kinds: ['acacia'], grass: '#c8b050', rocks: 5 },
  sombra: { g: ['#3a3448', '#2e2a3a'], top: 0x1a1430, bot: 0x5a4a6a, fog: 0x3a3048, leaf: '#9a5aff', trees: 14, kinds: ['cristal', 'morta'], grass: '#3a3450', rocks: 10 },
  vulcao: { g: ['#3a3030', '#4a3a32'], top: 0x5a2a1a, bot: 0xd88a5a, fog: 0x8a5a4a, leaf: '#4a3a2a', trees: 4, kinds: ['morta'], grass: null, rocks: 16 },
  noite: { g: ['#3a4a3a', '#2e3a30'], top: 0x1a1a3a, bot: 0x5a4a6a, fog: 0x3a3a4a, leaf: '#2a3a2a', trees: 20, kinds: ['morta', 'conifera'], grass: '#2e3a2e', rocks: 6 },
  gelo: { g: ['#e8f0f4', '#d8e4ec'], top: 0x6a9ac8, bot: 0xe8f4ff, fog: 0xd8e8f4, leaf: '#e8f4ff', trees: 16, kinds: ['gelo'], grass: null, rocks: 8 },
  neon: { g: ['#2a2a3a', '#22222e'], top: 0x0a0428, bot: 0x8a2a9a, fog: 0x2a1250, leaf: '#3af0ff', trees: 0, kinds: ['folhosa'], grass: null, rocks: 0 },
};
for (const k in THEMES) THEMES[k].key = k;
const cA = new THREE.Color(), cB = new THREE.Color();
function terrainColor(x, z, h, out, W) {
  let d1 = 1e9, d2 = 1e9, t1 = null, t2 = null;
  for (const t of GD.TOWNS) { const d = Math.hypot(x - t.x, z - t.z); if (d < d1) { d2 = d1; t2 = t1; d1 = d; t1 = t; } else if (d < d2) { d2 = d; t2 = t; } }
  const th1 = THEMES[t1.theme], th2 = THEMES[t2.theme], n = WG.fbm(x / 30, z / 30, 5, 2);
  cA.set(th1.g[0]).lerp(cB.set(th1.g[1]), n);
  const k = clamp((d2 - d1) / 140, 0, 1);
  if (k < 1) { const o = new THREE.Color(th2.g[0]).lerp(cB.set(th2.g[1]), n); cA.lerp(o, 0.5 - 0.5 * k); }
  // sub-biomas: dunas de deserto, brejos lamacentos, campos floridos, tundra gelada e terras queimadas
  const sb = subBiome(x, z, h, t1.theme, d1);
  if (sb.k > 0) cA.lerp(cB.set(sb.col), sb.k * (0.75 + 0.25 * n));
  if (h > 32) cA.lerp(cB.set('#8a8478'), clamp((h - 32) / 12, 0, 1));
  if (h > 40) cA.lerp(cB.set('#f2f5f8'), clamp((h - 40) / 8, 0, 1));
  if (h < 2.2) cA.lerp(cB.set('#cdb880'), clamp((2.2 - h) / 1.5, 0, 1));
  const rd = WG.roadDist(x, z); if (rd < 6) cA.lerp(cB.set('#9a7a50'), clamp(1 - (rd - 3) / 3, 0, 1));
  if (d1 < 100) { const cob = WG.fbm(x / 4, z / 4, 9, 2); cA.lerp(cB.set(cob > 0.5 ? '#8a8270' : '#7a705e'), clamp((100 - d1) / 12, 0, 1) * (d1 < 30 ? 1 : 0.55 + 0.3 * WG.fbm(x / 18, z / 18, 3, 2))); }
  out.copy(cA);
  if (W) { // pesos de material: rocha, estrada/terra, areia, calçamento
    W[0] = clamp((h - 30) / 10, 0, 1) * (h > 40 ? 0.4 : 1); W[1] = rd < 6 ? clamp(1 - (rd - 3) / 3, 0, 1) : 0; W[2] = h < 2.2 ? clamp((2.2 - h) / 1.5, 0, 1) : 0;
    W[3] = d1 < 40 ? clamp((40 - d1) / 8, 0, 1) : 0; if (sb.name === 'deserto') W[2] = Math.max(W[2], sb.k); if (sb.name === 'brejo' || sb.name === 'queimada') W[1] = Math.max(W[1], sb.k * 0.7); }
}
function subBiome(x, z, h, theme, dTown) {
  if (dTown < 120 || h > 34) return { k: 0 };
  const m = WG.fbm(x / 260, z / 260, 77, 3), k = (a, b) => clamp((m - a) / (b - a), 0, 1);
  if (theme === 'savana' || theme === 'rubro') { const v = k(0.5, 0.62); if (v) return { name: 'deserto', k: v, col: '#d8bc84' }; }
  if (['verde', 'floresta', 'noite', 'sombra', 'outono'].includes(theme) && h < 4.5 && h > 0.3) { const v = k(0.42, 0.55) * clamp((4.5 - h) / 2, 0, 1); if (v) return { name: 'brejo', k: v, col: '#3e4a2a' }; }
  if (theme === 'verde' || theme === 'outono') { const v = k(0.6, 0.7); if (v) return { name: 'campo florido', k: v * 0.6, col: theme === 'outono' ? '#c8843a' : '#8ac84a' }; }
  if (theme === 'rocha' || theme === 'cinza') { const v = k(0.58, 0.68); if (v) return { name: 'tundra', k: v, col: '#c8d0d4' }; }
  if (theme === 'vulcao' || theme === 'sombra') { const v = k(0.55, 0.65); if (v) return { name: 'queimada', k: v, col: '#2a2420' }; }
  return { k: 0 };
}

// ----- terreno em blocos -----
const CH = 100, SEG = 25, chunks = new Map(), terrainMeshes = [];
const terrainMat = new THREE.MeshLambertMaterial({ vertexColors: true });
// texturas reais do chão (CC0): grama, terra, rocha e calçamento, misturadas por bioma, inclinação e altura
const TEXU = { tGrass: { value: null }, tDirt: { value: null }, tRock: { value: null }, tStone: { value: null }, uTex: { value: 0 } };
{ const L = new THREE.TextureLoader(); let n = 0; for (const [k, f] of [['tGrass', 't_grass'], ['tDirt', 't_dirt'], ['tRock', 't_rock'], ['tStone', 't_stone']]) L.load('assets/world/' + f + '.webp', t => { t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4; TEXU[k].value = t; if (++n === 4) TEXU.uTex.value = 1; }); }
terrainMat.onBeforeCompile = (sh) => {
  Object.assign(sh.uniforms, TEXU);
  sh.vertexShader = sh.vertexShader.replace('#include <common>', '#include <common>\nattribute vec4 mats; varying vec4 vMats; varying vec3 vWp; varying vec3 vWn;')
    .replace('#include <begin_vertex>', '#include <begin_vertex>\nvMats = mats; vWp = (modelMatrix * vec4(position, 1.0)).xyz; vWn = normal;');
  sh.fragmentShader = sh.fragmentShader.replace('#include <common>', '#include <common>\nuniform sampler2D tGrass, tDirt, tRock, tStone; uniform float uTex; varying vec4 vMats; varying vec3 vWp; varying vec3 vWn;')
    .replace('#include <color_fragment>', `#include <color_fragment>
      if (uTex > 0.5) {
        vec2 uv = vWp.xz / 6.0;
        float far = clamp(length(vWp - cameraPosition) / 140.0, 0.0, 1.0);
        vec3 gT = texture2D(tGrass, uv).rgb, gM = textureLod(tGrass, vec2(0.5), 12.0).rgb;
        float gl = dot(gT, vec3(0.3, 0.55, 0.15)) / max(dot(gM, vec3(0.3, 0.55, 0.15)), 0.01);
        vec3 col = diffuseColor.rgb * mix(clamp(gl, 0.55, 1.6), 1.0, far * 0.6);
        float slope = 1.0 - clamp((normalize(vWn).y - 0.62) / 0.22, 0.0, 1.0);
        vec3 rk = texture2D(tRock, uv * 0.7).rgb * 1.45, dt = texture2D(tDirt, uv * 1.3).rgb, st = texture2D(tStone, uv * 1.6).rgb;
        col = mix(col, dt * (0.85 + 0.3 * diffuseColor.r), vMats.y * 0.85);
        col = mix(col, mix(dt, vec3(0.80, 0.70, 0.48), 0.6) * (0.9 + 0.2 * gl), vMats.z);
        col = mix(col, st * vec3(0.95, 0.92, 0.88), vMats.w * 0.75);
        col = mix(col, rk * mix(vec3(1.0), diffuseColor.rgb * 2.0, 0.25), clamp(max(vMats.x, slope), 0.0, 1.0));
        float snow = clamp((vWp.y - 72.0 - sin(vWp.x * 0.031) * 7.0 - cos(vWp.z * 0.027) * 7.0) / 9.0, 0.0, 1.0) * (1.0 - slope * 0.7);
        col = mix(col, vec3(0.93, 0.95, 0.98) * (0.9 + 0.1 * dot(rk, vec3(0.33))), snow);
        diffuseColor.rgb = col;
      }`);
};
const trunkGeo = new THREE.CylinderGeometry(0.25, 0.4, 3, 6).translate(0, 1.5, 0);
const leafGeo = new THREE.IcosahedronGeometry(2.1, 0).translate(0, 4.2, 0), conGeo = new THREE.ConeGeometry(2, 6, 7).translate(0, 5.5, 0);
const trunkMat = mat('#5a3a20');
const nodeMeshes = new Map();
function buildChunk(cx, cz) {
  const geo = new THREE.PlaneGeometry(CH, CH, SEG, SEG); geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position, col = new Float32Array(pos.count * 3), mats = new Float32Array(pos.count * 4), W = [0, 0, 0, 0], c = new THREE.Color();
  const ox = cx * CH + CH / 2, oz = cz * CH + CH / 2;
  for (let i = 0; i < pos.count; i++) { const x = pos.getX(i) + ox, z = pos.getZ(i) + oz, h = WG.height(x, z); pos.setY(i, h); terrainColor(x, z, h, c, W); col[i * 3] = c.r; col[i * 3 + 1] = c.g; col[i * 3 + 2] = c.b; mats.set(W, i * 4); }
  geo.setAttribute('color', new THREE.BufferAttribute(col, 3)); geo.setAttribute('mats', new THREE.BufferAttribute(mats, 4)); geo.computeVertexNormals();
  const mesh = new THREE.Mesh(geo, terrainMat); mesh.position.set(ox, 0, oz); mesh.receiveShadow = true; mesh.userData.terrain = true;
  const group = new THREE.Group(); group.add(mesh);
  // árvores por bioma (com vento) e rochas
  const th = THEMES[WG.nearestTown(ox, oz).town.theme], rng = WG.mulberry32((cx * 7919) ^ (cz * 104729) ^ 77), byKind = {};
  for (let i = 0; i < th.trees; i++) {
    const x = cx * CH + rng() * CH, z = cz * CH + rng() * CH, h = WG.height(x, z), kind = th.kinds[Math.floor(rng() * th.kinds.length)];
    if (h < 1.8 || h > 42 || WG.nearestTown(x, z).dist < 115 || WG.nearestLandmark(x, z).dist < 60 || WG.inNeon(x, z, 30) || WG.roadDist(x, z) < 9) { rng(); rng(); continue; }
    (byKind[kind] = byKind[kind] || []).push([x, h, z, 0.7 + rng() * 0.8, rng() * 6]);
  }
  const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), sv = new THREE.Vector3(), pv = new THREE.Vector3(), up = new THREE.Vector3(0, 1, 0);
  for (const [kind, pts] of Object.entries(byKind)) {
    const K = TREE_KINDS[kind], tr = new THREE.InstancedMesh(K.trunk, treeTrunkMat(), pts.length), lf = K.leaf ? new THREE.InstancedMesh(K.leaf, leafMat(kind === 'gelo' ? '#2f5a3a' : th.leaf, kind === 'cristal' ? new THREE.Color(th.leaf).getHex() : 0), pts.length) : null;
    pts.forEach(([x, h, z, sc, r], i) => { q.setFromAxisAngle(up, r); sv.set(sc, sc, sc); pv.set(x, h - 0.2, z); m4.compose(pv, q, sv); tr.setMatrixAt(i, m4); lf && lf.setMatrixAt(i, m4); });
    tr.castShadow = true; tr.userData.pk = kind; group.add(tr); if (lf) { lf.castShadow = true; lf.userData.pk = kind; group.add(lf); }
    if (kind === 'gelo') { const sn = new THREE.InstancedMesh(TREE_KINDS.gelo.leaf, leafMat('#f4f8ff'), pts.length); pts.forEach(([x, h, z, sc, r], i) => { q.setFromAxisAngle(up, r); sv.set(sc * 1.04, sc * 0.55, sc * 1.04); pv.set(x, h + 2.4 * sc, z); m4.compose(pv, q, sv); sn.setMatrixAt(i, m4); }); group.add(sn); }
  }
  const nRocks = th.rocks + Math.round(Math.max(0, WG.height(ox, oz) - 20) / 3), rocks = [[], [], []], hiRocks = [[], [], []];
  for (let i = 0; i < nRocks; i++) { const x = cx * CH + rng() * CH, z = cz * CH + rng() * CH, h = WG.height(x, z); if (h < 0.5 || WG.nearestTown(x, z).dist < 100 || WG.inNeon(x, z, 20) || WG.roadDist(x, z) < 7) continue; (h > 24 ? hiRocks : rocks)[i % 3].push([x, h, z, 0.5 + rng() * rng() * 3.2, rng() * 6]); }
  rocks.forEach((pts, k) => { if (!pts.length) return; const rm = new THREE.InstancedMesh(ROCK_GEOS[k], rockMat, pts.length); pts.forEach(([x, h, z, sc, r], i) => { q.setFromAxisAngle(up, r); sv.set(sc * 1.3, sc, sc); pv.set(x, h - sc * 0.25, z); m4.compose(pv, q, sv); rm.userData.pk = 'rock'; rm.setMatrixAt(i, m4); }); rm.castShadow = rm.receiveShadow = true; group.add(rm); });
  hiRocks.forEach((pts, k) => { if (!pts.length) return; const rm = new THREE.InstancedMesh(ROCK_GEOS[k], rockMat, pts.length); pts.forEach(([x, h, z, sc, r], i) => { q.setFromAxisAngle(up, r); sv.set(sc * 1.3, sc, sc); pv.set(x, h - sc * 0.25, z); m4.compose(pv, q, sv); rm.setMatrixAt(i, m4); }); rm.castShadow = rm.receiveShadow = true; group.add(rm); });
  scene.add(group); terrainMeshes.push(mesh);
  // recursos coletáveis
  const nodes = NODES.filter(n => n.x >= cx * CH && n.x < cx * CH + CH && n.z >= cz * CH && n.z < cz * CH + CH);
  nodes.forEach(n => { const m = buildNode(n.type, n.grade); m.position.set(n.x, WG.height(n.x, n.z), n.z); m.userData = { kind: 'node', ref: n }; scene.add(m); nodeMeshes.set(n.id, m); refreshNode(n.id); });
  // vegetação rasteira (só para os modelos GLB de perto): arbustos, samambaias, flores e cogumelos
  const under = [], r2 = WG.mulberry32((cx * 3571) ^ (cz * 7643) ^ 913), nU = { verde: 40, floresta: 70, outono: 34, noite: 22, rocha: 14, savana: 22, sombra: 6, gelo: 26, cristal: 10, vulcao: 6 }[th.key] || 0;
  for (let i = 0; i < nU; i++) { const x = cx * CH + r2() * CH, z = cz * CH + r2() * CH, h = WG.height(x, z), roll = r2(), sc = 0.7 + r2() * 0.6, r = r2() * 6;
    if (h < 2 || h > 34 || WG.nearestTown(x, z).dist < 105 || WG.nearestLandmark(x, z).dist < 40 || WG.inNeon(x, z, 20) || WG.roadDist(x, z) < 6) continue;
    const k = th.key === 'noite' || th.key === 'sombra' ? (roll < 0.6 ? 2 : 6) : th.key === 'rocha' || th.key === 'savana' ? (roll < 0.5 ? 0 : 2) : roll < 0.28 ? 0 : roll < 0.4 ? 1 : roll < 0.62 ? 2 : roll < 0.74 ? 3 : roll < 0.84 ? 4 : roll < 0.94 ? 5 : 6;
    const sbb = subBiome(x, z, h, th.key, 999); if (sbb.name === 'deserto' && r2() < 0.7) continue; under.push([x, h, z, sc, r, k, sbb.name]); }
  // colisão: troncos e rochas grandes deste pedaço
  const cols = []; for (const pts of Object.values(byKind)) for (const [x, , z, sc] of pts) cols.push(x, z, 0.45 * sc);
  for (const pts of [...rocks, ...hiRocks]) for (const [x, , z, sc] of pts) if (sc > 1.1) cols.push(x, z, sc * 0.8);
  chunks.set(cx + ',' + cz, { cols, group, mesh, nodes, cx, cz, nat: null, natData: { trees: byKind, rocks, under, theme: th.key, rockTint: ROCK_TINT[th.key] || '#ffffff' } });
}
function dropChunk(key) { const c = chunks.get(key); if (c.nat) disposeNature(c.nat); scene.remove(c.group); c.mesh.geometry.dispose(); c.group.children.forEach(o => { if (o.isInstancedMesh) o.dispose(); }); const i = terrainMeshes.indexOf(c.mesh); if (i >= 0) terrainMeshes.splice(i, 1); c.nodes.forEach(n => { const m = nodeMeshes.get(n.id); if (m) { scene.remove(m); nodeMeshes.delete(n.id); } }); chunks.delete(key); }
let CHUNK_R = 4;
function updateChunks(px, pz, all) {
  const R = CHUNK_R, ccx = Math.floor(px / CH), ccz = Math.floor(pz / CH); let built = 0;
  const want = [];
  for (let dz = -R; dz <= R; dz++) for (let dx = -R; dx <= R; dx++) { const cx = ccx + dx, cz = ccz + dz; if (cx < 0 || cz < 0 || cx >= 30 || cz >= 30 || dx * dx + dz * dz > R * R + 1) continue; want.push([dx * dx + dz * dz, cx, cz]); }
  want.sort((a, b) => a[0] - b[0]);
  const keep = new Set(want.map(w => w[1] + ',' + w[2]));
  for (const k of [...chunks.keys()]) if (!keep.has(k)) dropChunk(k);
  for (const [, cx, cz] of want) { if (!chunks.has(cx + ',' + cz)) { buildChunk(cx, cz); if (!all && ++built >= 1) break; } }
  // modelos GLB de natureza nos blocos próximos (um por quadro para não engasgar)
  if (!NAT.ready) return; let up = 0;
  for (const c of chunks.values()) {
    const near = Math.max(Math.abs(c.cx - ccx), Math.abs(c.cz - ccz)) <= NAT_R;
    if (near && !c.nat && (all || up++ < 1)) { c.nat = buildNatureChunk(c.natData); c.group.add(c.nat.group); c.group.children.forEach(o => { if (o.userData.pk && c.nat.handled.has(o.userData.pk)) o.visible = false; }); }
    else if (!near && c.nat && Math.max(Math.abs(c.cx - ccx), Math.abs(c.cz - ccz)) > NAT_R + 1) { disposeNature(c.nat); c.nat = null; c.group.children.forEach(o => { if (o.userData.pk) o.visible = true; }); }
  }
}
let NAT_R = 1;
const ROCK_TINT = { vulcao: '#6a5650', rubro: '#d0a080', gelo: '#e8f0ff', cinza: '#9a90b0', sombra: '#8a80a0', noite: '#9aa0a8' };
loadNature();
function refreshNode(id) { const m = nodeMeshes.get(id); if (!m) return; const dep = (S.dep[id] || 0) > Date.now(); m.scale.set(1, dep ? 0.22 : 1, 1); m.children.forEach(ch => { if (ch.geometry && ch.geometry.type === 'RingGeometry') ch.visible = !dep; }); m.userData.dep = dep; }
const WATER = createWater(), water = WATER.mesh; water.position.y = WG.WATER; scene.add(water);
initPost(renderer, scene, camera); initWeather({ scene, camera, onThunder: () => { postFlash(1.4); setTimeout(() => sfx('thunder', 1), 400 + Math.random() * 900); } });
const CAMFX = { shake: 0 }; const TIME = { stopUntil: 0, slowUntil: 0 };
const hitStop = (ms = 60) => { TIME.stopUntil = performance.now() + ms; }; const slowMo = (ms = 1200) => { TIME.slowUntil = performance.now() + ms; }; const shake = (k) => { CAMFX.shake = Math.min(1, CAMFX.shake + k); };
const GRASS = createGrass(14000); scene.add(GRASS.mesh);
// ---------- qualidade gráfica (automática por FPS) ----------
const QUAL = { alta: { name: 'Alta', pr: 1.5, sh: 2048, shOn: true, soft: true, grass: 14000, R: 4, far: 1200 }, media: { name: 'Média', pr: 1, sh: 1024, shOn: true, soft: false, grass: 6000, R: 3, far: 900 }, baixa: { name: 'Baixa', pr: 0.75, sh: 512, shOn: false, soft: false, grass: 1500, R: 3, far: 650 } };
const QORDER = ['alta', 'media', 'baixa'];
const PERF = { mode: localStorage.getItem('vt_qual') || 'auto', cur: null, frames: 0, acc: 0, fps: 60, since: 0 };
function applyQuality(n) {
  const q = QUAL[n]; if (!q) return; PERF.cur = n; renderer.setPixelRatio(Math.min(devicePixelRatio, q.pr)); renderer.setSize(innerWidth, innerHeight);
  const was = renderer.shadowMap.enabled, wasSoft = renderer.shadowMap.type; renderer.shadowMap.enabled = q.shOn; renderer.shadowMap.type = q.soft ? THREE.PCFSoftShadowMap : THREE.PCFShadowMap;
  sun.shadow.mapSize.set(q.sh, q.sh); if (sun.shadow.map) { sun.shadow.map.dispose(); sun.shadow.map = null; }
  if (was !== q.shOn || wasSoft !== renderer.shadowMap.type) scene.traverse(o => { if (o.material) [].concat(o.material).forEach(m => m.needsUpdate = true); });
  GRASS.limit = q.grass; GRASS.center = null; CHUNK_R = q.R; NAT_R = n === 'baixa' ? -1 : 1; AMB.max = n === 'baixa' ? 0 : n === 'media' ? 4 : 7; camera.far = q.far; camera.updateProjectionMatrix(); PERF.since = performance.now(); setPostQuality(n); WEATHER.max = n === 'baixa' ? 0.4 : 1;
}
applyQuality(PERF.mode !== 'auto' ? PERF.mode : IS_MOBILE ? 'media' : 'alta');
function perfTick(dt) {
  const tn = performance.now(); if (!PERF.t0) PERF.t0 = tn; PERF.frames++; const el = (tn - PERF.t0) / 1000; if (el < 4) return; PERF.fps = PERF.frames / el; PERF.frames = 0; PERF.t0 = tn;
  if (PERF.mode !== 'auto' || !S.inGame || document.hidden || performance.now() - PERF.since < 8000) return;
  const i = QORDER.indexOf(PERF.cur); if (PERF.fps < 30 && i < QORDER.length - 1) { applyQuality(QORDER[i + 1]); toast(`Qualidade ajustada para ${QUAL[PERF.cur].name} (${Math.round(PERF.fps)} FPS)`, 'ok'); }
}

// ----- cidades -----
const npcs = [], houses = [];
const townGroups = [];
const PLAZA = { humano: '#a8a08e', halfling: '#b8a878', anao: '#6a645a', elfo: '#e8e8e0', orc: '#8a6a4a', sylph: '#f0f4fa', beastman: '#a8885a', sombrio: '#3a3448', draconato: '#3a3232', nocturno: '#3a3640', gigante: '#d8e4ec' };
const CASTLE_G = {}; const PORTALS = []; // portais dimensionais: entrar no anel teleporta
async function portalTick() {
  if (!me || S.dead || S.portalBusy || (S.portalCd || 0) > Date.now()) return;
  for (const P of PORTALS) { if (Math.hypot(P.x - me.x, P.z - me.z) > 2.6) continue; S.portalBusy = true; S.portalCd = Date.now() + 6000;
    if (P.dest === 'lm:era_neon' && S.c.level < 52) toast('⚠️ A Era Neon é perigosa: monstros de nível 54 a 62', 'err');
    emit(me.x, WG.height(me.x, me.z) + 1.5, me.z, { n: 60, color: new THREE.Color(P.col).getHex(), speed: 5, up: 3, life: 0.9, size: 0.3 }); sfx('magic'); postFlash && postFlash(0.6);
    const r = await safe(() => B.teleport(P.dest)); S.portalBusy = false; if (!r) return; toast(`🌀 Você atravessou a fenda: ${r.name}`, 'ok'); teleport(r.x, r.z); return; }
}
function townCtx(t) {
  const roadAngles = WG.ROADS.filter(([a, b]) => a === t || b === t).map(([a, b]) => { const o = a === t ? b : a; return Math.atan2(o.z - t.z, o.x - t.x); });
  return { t, roadAngles, H: (x, z) => WG.height(x, z), collide: (x, z, r) => houses.push({ x, z, r }), collideBox: (x, z, hw, hd, rot, gate) => houses.push({ x, z, hw, hd, c: Math.cos(rot), s: Math.sin(rot), br: Math.hypot(hw, hd), r: Math.max(hw, hd), gate }),
    npc: (type, name, x, z, rot, o = {}) => { const m = buildHumanoid({ glb: false, npc: true, race: o.race || 'humano', gender: o.gender || 'm', hair: 1, hair_color: 2, skin: 1, look: { beard: o.beard }, armor: o.armor, weapon: o.weapon, idle: o.idle, equip: o.helm ? { elmo: o.helm } : null });
      m.root.position.set(x, WG.height(x, z), z); m.root.rotation.y = rot; scene.add(m.root); const l = makeLabel(name, type === 'guarda' ? '#c8d8e8' : '#ffe36a', 26); l.position.set(0, 2.5, 0); m.root.add(l);
      const npc = { type, name, town: t, x, z, model: m, castle: o.castle }; m.root.traverse(q => q.userData.pick = npc); npcs.push(npc); },
    pickable: (obj, npc) => { npc.town = t; obj.traverse(q => q.userData.pick = npc); npcs.push(npc); },
    statue: (race, x, z, s, rot) => { const m = buildHumanoid({ glb: false, race, gender: 'm', skinColor: '#8a8478', armor: 'pesada_c', weapon: 'martelo_c', look: { beard: 2 } }); m.root.scale.setScalar(s); m.root.position.set(x, WG.height(x, z) + 1.2, z); m.root.rotation.y = rot; const base = new THREE.Mesh(new THREE.CylinderGeometry(2.4, 2.8, 1.2, 12), mat('#6a645a')); base.position.set(x, WG.height(x, z) + 0.6, z); scene.add(m.root, base); houses.push({ x, z, r: 2.8 }); },
    dragonStatue: (x, z, s, rot) => { const R = buildMob({ ...FAM.dragao, color: '#2a2626', boss: false, ghost: false }); R.root.scale.setScalar(s); R.root.position.set(x, WG.height(x, z), z); R.root.rotation.y = rot; scene.add(R.root); houses.push({ x, z, r: 4 }); } };
}
function buildTowns() {
  for (const t of GD.TOWNS) {
    const y = WG.TOWN_H, g = new THREE.Group();
    const plaza = new THREE.Mesh(new THREE.CylinderGeometry(28, 28, 0.3, 48), mat(PLAZA[t.race] || '#a8a08e', { rough: 0.95 })); plaza.position.set(t.x, y + 0.05, t.z); plaza.receiveShadow = true; g.add(plaza);
    const ring2 = new THREE.Mesh(new THREE.TorusGeometry(28, 0.35, 6, 64), mat('#5a544c')); ring2.rotation.x = Math.PI / 2; ring2.position.set(t.x, y + 0.2, t.z); g.add(ring2);
    const crystal = new THREE.Mesh(new THREE.OctahedronGeometry(1.6, 0), mat('#bfe8ff', { emissive: t.theme === 'cinza' ? 0x8a3aff : 0x3a9aff, ei: 0.9, metal: 0.3, rough: 0.1 }));
    crystal.position.set(t.x, y + 6, t.z); crystal.userData.spin = true; g.add(crystal); npcs.push({ crystal });
    const base = new THREE.Mesh(new THREE.CylinderGeometry(3, 4, 2.5, 12), mat('#7a7468')); base.position.set(t.x, y + 1.25, t.z); base.castShadow = base.receiveShadow = true; g.add(base);
    const lbl = makeLabel(t.name, '#ffe9b0', 40); lbl.position.set(t.x, y + 10, t.z); lbl.scale.multiplyScalar(2.2); g.add(lbl);
    g.add(buildTownArchitecture(townCtx(t))); stoneify(g);
    scene.add(g); townGroups.push({ g, x: t.x, z: t.z });
    const races = [t.race, 'humano', t.race, 'elfo', t.race, 'anao', t.race];
    NPC_TYPES.forEach(([type, name, color], i) => {
      const a = i / NPC_TYPES.length * Math.PI * 2 + 0.3, x = t.x + Math.cos(a) * 17, z = t.z + Math.sin(a) * 17;
      // cada NPC com traje, arma, gesto e postura do seu ofício
      const ROLE = { portal: { armor: 'robe_b', weapon: 'cajado_b', idle: 'Spell_Simple_Idle_Loop' }, classe: { armor: 'pesada_a', weapon: 'espadao_a', idle: 'Sword_Idle', gender: 'm', beard: 2 },
        ferreiro: { armor: 'pesada_c', weapon: 'martelo_c', idle: 'Idle_FoldArms_Loop', gender: 'm', beard: 2 }, refino: { armor: null, weapon: null, idle: 'Idle_Lantern_Loop' },
        mercador: { armor: 'robe_s', weapon: null, idle: 'Idle_Talking_Loop', beard: 1 }, leilao: { armor: 'robe_a', weapon: null, idle: 'Idle_Talking_Loop', gender: 'f' }, arauto: { armor: 'robe_s', weapon: 'espada_a', helm: 'elmo_inverno', idle: 'Idle_Torch_Loop', gender: 'm' } }[type];
      const m = buildHumanoid({ glb: false, npc: true, race: races[i] || t.race, gender: ROLE.gender || (i % 3 === 1 ? 'f' : 'm'), hair: i % 6, hair_color: i, skin: 0, look: { eyes: i % 4, face: i % 4, beard: ROLE.beard }, armor: ROLE.armor, weapon: ROLE.weapon, idle: ROLE.idle, equip: ROLE.helm ? { elmo: ROLE.helm } : null });
      m.root.position.set(x, y, z); m.root.rotation.y = Math.atan2(t.x - x, t.z - z); scene.add(m.root);
      const l = makeLabel(name, '#ffe36a', 28); l.position.set(0, 2.5 * (GD.RACES[races[i] || t.race]?.h || 1), 0); m.root.add(l);
      const npc = { type, name, town: t, x, z, model: m }; m.root.traverse(o => o.userData.pick = npc); npcs.push(npc);
      if (type === 'portal') { const ring = new THREE.Mesh(new THREE.TorusGeometry(2.2, 0.18, 8, 30), mat('#7ad0ff', { emissive: 0x3aa0ff, ei: 1.2 })); ring.position.set(x + Math.cos(a) * 4, y + 2.4, z + Math.sin(a) * 4); ring.rotation.y = -a; ring.userData.spin2 = true; scene.add(ring); npcs.push({ crystal: ring }); }
    });
  }
  for (const L of GD.LANDMARKS) { const neon = L.type === 'neon', g = neon ? buildNeon(townCtx({ x: L.x, z: L.z, race: 'humano' }), L, GD.NEON) : stoneify(buildLandmark(townCtx({ x: L.x, z: L.z, race: 'humano' }), L)); scene.add(g); townGroups.push({ g, x: L.x, z: L.z, far: neon ? 1500 : 0 }); if (L.type === 'castelo') CASTLE_G[L.id] = g;
    if (neon && g.userData.backPortal) PORTALS.push({ ...g.userData.backPortal, dest: 'portal:aurora', name: 'Vila Aurora', col: '#ffb03a' });
    const lb = makeLabel(({ castelo: '🏰 ', ruina: '🏛️ ', tumba: '⚰️ ', pantano: '🐸 ', destrocos: '🛒 ', estranho: '🔮 ', neon: '🌆 ' }[L.type] || '💀 ') + L.name, neon ? '#7af8ff' : '#ffcf8a', 34); lb.position.set(L.x, WG.height(L.x, L.z) + (neon ? 32 : 26), L.z + (neon ? 30 : 0)); lb.scale.multiplyScalar(1.8); scene.add(lb); townGroups.push({ g: lb, x: L.x, z: L.z }); }
  // portal dimensional em Vila Aurora → Era Neon
  { const P = GD.NEON.portal, T0 = GD.TOWNS[0], p = buildPortal('#3af0ff', 'Portal • Era Neon'); p.position.set(P.x, WG.height(P.x, P.z), P.z); p.rotation.y = Math.atan2(T0.x - P.x, T0.z - P.z); scene.add(p); townGroups.push({ g: p, x: P.x, z: P.z });
    const lb = makeLabel('🌀 Portal Dimensional • Era Neon (nv 52+)', '#7af8ff', 30); lb.position.set(P.x, WG.height(P.x, P.z) + 7.6, P.z); lb.scale.multiplyScalar(1.3); scene.add(lb); townGroups.push({ g: lb, x: P.x, z: P.z });
    PORTALS.push({ x: P.x, z: P.z, dest: 'lm:era_neon', name: 'Era Neon', col: '#3af0ff' }); }
}
function updateTownVisibility() { if (!me) return; for (const t of townGroups) t.g.visible = Math.hypot(t.x - me.x, t.z - me.z) < (t.far || 620); }

// ---------- personagem do jogador ----------
let me = null; const pickables = [];
const ring = (color) => { const m = new THREE.Mesh(new THREE.RingGeometry(0.9, 1.15, 28), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.85, depthWrite: false })); m.rotation.x = -Math.PI / 2; m.renderOrder = 5; return m; };
const selRing = ring(0xff4040); scene.add(selRing); selRing.visible = false;
const destRing = ring(0xffffff); scene.add(destRing); destRing.visible = false;
function stats() { const s = GD.charStats(S.c, buffVals()), cf = compFx();
  { const k = myClan(); if (k) { const b = GD.CLAN.bonus(k.level) + (ownCastle() ? GD.CLAN.castleBonus : 0); s.maxHp = Math.round(s.maxHp * (1 + b)); s.patk *= 1 + b; s.matk *= 1 + b; s.atk = s.magic ? s.matk : s.patk; s.clanBonus = b; } }
  if (Object.keys(cf).length) { s.fx = { ...s.fx }; for (const [k, v] of Object.entries(cf)) s.fx[k] = (s.fx[k] || 0) + v;
    if (cf.crit) s.crit += cf.crit; if (cf.atkspd) s.atkInterval /= 1 + cf.atkspd; if (cf.matkPct) { s.matk *= 1 + cf.matkPct; } if (cf.hpPct) s.maxHp = Math.round(s.maxHp * (1 + cf.hpPct)); if (cf.speed) s.speed *= 1 + cf.speed; if (cf.pdefPct) s.pdef *= 1 + cf.pdefPct; s.atk = s.magic ? s.matk : s.patk; }
  return s; }
function buffVals() { const o = {}, t = now(); for (const [k, b] of Object.entries(S.buffs)) { if (b.until < t) { delete S.buffs[k]; continue; } for (const [s, v] of Object.entries(b.vals)) o[s] = (o[s] || 0) + v; } return o; }
// ---------- clã: estado e identificação ----------
const myClan = () => S.clanInfo && S.clanInfo.clan || null;
const ownCastle = () => { const k = myClan(); return !!k && (S.clanInfo.castles || []).some(c => c.owner === k.id); };
const clanTag = () => { const k = myClan(); return k ? [k.tag, k.name, k.level, k.level >= 3 && k.flag && k.flag.e || ''] : null; };
const flagOf = cl => cl && cl[3] ? cl[3] + ' ' : '';
function clanLabel(cl, h) { if (!cl) return null; const l = makeLabel(`‹ ${GD.CLAN.title(cl[2])} ${cl[1]} ›`, GD.CLAN.color(cl[2]), 20); l.position.y = 2.25 * h + 0.3; return l; }
function castleOpen(id) { const ci = S.clanInfo; if (!ci || !ci.castles) return true; const ca = ci.castles.find(c => c.id === id); if (!ca || !ca.owner) return true; if (ci.siege && ci.siege.open) return true; if (S.c && S.c.is_gm) return true; return !!ci.clan && ci.clan.id === ca.owner; }
async function loadClan(quiet) { try { S.clanInfo = await B.clan('info'); } catch (e) { if (!quiet) toast(e.message, 'err'); return; } afterClan(); }
function afterClan() { relabelMe(); S.posForce = 1; for (const ca of (S.clanInfo.castles || [])) { const g = CASTLE_G[ca.id]; if (!g) continue; const col = ca.owner ? (ca.owner_flag && ca.owner_flag.c) || GD.CLAN.color(ca.owner_level || 1) : null;
    if (col) [...(g.userData.flags || []), ...(g.userData.banners || [])].forEach(m => { m.material = m.material.clone(); m.material.color.set(col); }); }
  if (panelState.kind === 'clan') renderPanel(); }
async function clanDo(fn, args, ok) { const r = await safe(() => B.clan(fn, args), ok); if (!r) return false; S.clanInfo = r; await refresh(); afterClan(); updateHud(); return true; }
function nameColor(c) { return c.gm ? '#ffcf4a' : c.karma ? '#ff4a4a' : c.flag ? '#d38cff' : '#ffffff'; }
function makeMe() {
  if (me) { scene.remove(me.root); }
  const c = S.c; me = buildHumanoid({ ...c, weapon: c.equipment.arma, armor: c.equipment.armadura, equip: c.equipment, enc: encOf(c) }); me.x = c.x; me.z = c.z; me.ry = 0;
  me.label = makeLabel(c.name, nameColor({ gm: S.c.is_gm, karma: S.c.karma, flag: false }), 30); me.label.position.y = 2.15 * GD.RACES[c.race].h; me.root.add(me.label);
  scene.add(me.root);
}
function relabelMe() { if (!me) return; me.root.remove(me.label); if (me.clanLabel) me.root.remove(me.clanLabel); me.clanLabel = clanLabel(clanTag(), GD.RACES[S.c.race].h); if (me.clanLabel) me.root.add(me.clanLabel); me.label = makeLabel(flagOf(clanTag()) + S.c.name, nameColor({ gm: S.c.is_gm, karma: S.c.karma, flag: S.flagUntil > Date.now() }), 30); me.label.position.y = 2.25 * GD.RACES[S.c.race].h; me.root.add(me.label); }

// ---------- câmera ----------
const cam = { yaw: 0, pitch: 0.38, dist: 12, drag: false, lx: 0, ly: 0 };
canvas.addEventListener('contextmenu', e => e.preventDefault());
canvas.addEventListener('mousedown', e => { if (e.button === 2 || e.button === 1 || (studio.visible && e.button === 0)) { cam.drag = true; cam.lx = e.clientX; cam.ly = e.clientY; } });
addEventListener('mouseup', () => cam.drag = false);
addEventListener('mousemove', e => { if (!cam.drag) return; if (studio.visible) { stu.yaw -= (e.clientX - cam.lx) * 0.01; stu.pitch = clamp(stu.pitch + (e.clientY - cam.ly) * 0.005, -0.4, 0.9); } else { cam.yaw -= (e.clientX - cam.lx) * 0.006; cam.pitch = clamp(cam.pitch + (e.clientY - cam.ly) * 0.005, -0.45, 1.4); } cam.lx = e.clientX; cam.ly = e.clientY; });
canvas.addEventListener('wheel', e => { if (studio.visible) stu.dist = clamp(stu.dist * (e.deltaY > 0 ? 1.1 : 0.9), 0.9, 6); else cam.dist = clamp(cam.dist * (e.deltaY > 0 ? 1.1 : 0.9), 1.1, 32); }, { passive: true });
const stu = { yaw: 0, pitch: 0.12, dist: 4.6 }; window.__stu = stu;
const _ray = new THREE.Raycaster(), _cTo = new THREE.Vector3(), _cFrom = new THREE.Vector3();
function updateCamera() {
  const rh = (GD.RACES[S.c.race]?.h || 1), close = clamp((5 - cam.dist) / 3.5, 0, 1); const ty = WG.height(me.x, me.z) + (S.alt || 0) + saddle() + (1.7 + (1.62 * rh - 1.7) * close) * (close ? 1 : 1) + (rh - 1) * 0.6 * (1 - close);
  let cx = me.x + Math.sin(cam.yaw) * Math.cos(cam.pitch) * cam.dist, cz = me.z + Math.cos(cam.yaw) * Math.cos(cam.pitch) * cam.dist, cy = ty + Math.sin(cam.pitch) * cam.dist;
  cy = Math.max(cy, WG.height(cx, cz) + 0.25, WG.WATER + 0.6);
  // câmera não atravessa prédios: aproxima quando há parede entre ela e o personagem
  if ((CAMFX.n = (CAMFX.n || 0) + 1) % 2 === 0) { CAMFX.hit = 1; const near = townGroups.filter(t => t.g.visible && t.g.isGroup && Math.hypot(t.x - me.x, t.z - me.z) < 160).map(t => t.g);
    if (near.length) { _cTo.set(cx - me.x, cy - ty, cz - me.z); const D = _cTo.length(); _cTo.normalize(); _ray.set(_cFrom.set(me.x, ty, me.z), _cTo); _ray.far = D; _ray.camera = camera; const h = _ray.intersectObjects(near, true).find(i => i.object.isMesh && !i.object.isSprite && i.distance > 0.6);
      if (h) CAMFX.hit = Math.max(0.15, (h.distance - 0.4) / D); } }
  CAMFX.k = (CAMFX.k ?? 1) + ((CAMFX.hit ?? 1) - (CAMFX.k ?? 1)) * 0.25; if (CAMFX.k < 0.999) { cx = me.x + (cx - me.x) * CAMFX.k; cy = ty + (cy - ty) * CAMFX.k; cz = me.z + (cz - me.z) * CAMFX.k; }
  if (CAMFX.shake > 0.01) { const a = CAMFX.shake * CAMFX.shake * 0.35, tt = performance.now() / 30; cx += Math.sin(tt * 1.7) * a; cy += Math.sin(tt * 2.3) * a; cz += Math.cos(tt * 1.9) * a; CAMFX.shake *= 0.88; }
  camera.position.set(cx, cy, cz); camera.lookAt(me.x, ty, me.z); if (me.label) me.label.visible = cam.dist > 5.5;
}

// ---------- clique: mover, selecionar, interagir ----------
const ray = new THREE.Raycaster(), mouse = new THREE.Vector2();
function pickAt(e) {
  mouse.set(e.clientX / innerWidth * 2 - 1, -(e.clientY / innerHeight) * 2 + 1); ray.setFromCamera(mouse, camera);
  const objs = [];
  S.mobs.forEach(m => { if (!m.dead) objs.push(m.model.root); });
  Object.values(S.others).forEach(o => o.model && objs.push(o.model.root));
  npcs.forEach(n => n.model && objs.push(n.model.root));
  nodeMeshes.forEach(m => objs.push(m));
  const hits = ray.intersectObjects(objs, true);
  for (const h of hits) { let o = h.object; while (o && !o.userData.pick && !o.userData.kind) o = o.parent; if (o) return o.userData.pick || { kind: o.userData.kind, ref: o.userData.ref }; }
  const th = ray.intersectObjects(terrainMeshes, false); if (th[0]) return { ground: th[0].point };
  return null;
}
canvas.addEventListener('mousedown', e => { if (TOUCH && e.sourceCapabilities?.firesTouchEvents) return; onPick(e); });
function onPick(e) {
  if (e.button !== 0 || !S.inGame || S.dead) return;
  const p = pickAt(e); if (!p) return;
  S.gatherAt = null; S.npcAt = null; S.channel = null;
  if (p.kind === 'mob' || p.kind === 'player') {
    if (S.target && S.target.ref === p.ref) { S.autoAtk = true; if (p.kind === 'player' && !e.ctrlKey && !(p.ref.k || p.ref.f)) { S.autoAtk = false; toast('Use Ctrl + clique para atacar um jogador (PvP)'); } }
    else { S.target = p; S.autoAtk = p.kind === 'mob' && e.detail >= 2; if (p.kind === 'player' && e.ctrlKey) S.autoAtk = true; }
    S.dest = null; return;
  }
  if (p.type) { S.target = { kind: 'npc', ref: p }; S.npcAt = p; S.dest = { x: p.x, z: p.z }; S.autoAtk = false; return; }
  if (p.kind === 'node') { const n = p.ref; S.target = { kind: 'node', ref: n }; S.autoAtk = false; if ((S.dep[n.id] || 0) > Date.now()) { toast('Recurso esgotado, renasce em breve', 'err'); return; } S.gatherAt = n; S.dest = { x: n.x, z: n.z }; return; }
  if (p.ground) { if (S.guide) stopGuide('Guia automático cancelado'); S.dest = { x: p.ground.x, z: p.ground.z }; S.autoAtk = false; destRing.position.set(p.ground.x, p.ground.y + 0.1, p.ground.z); destRing.visible = true; destRing.scale.setScalar(1); }
}
// ---------- toque (celular/tablet) ----------
const TOUCH = matchMedia('(pointer: coarse)').matches || navigator.maxTouchPoints > 1;
if (TOUCH) document.body.classList.add('touch');
{ const T = { pts: new Map(), moved: false, t0: 0, pinch: 0 };
  canvas.addEventListener('touchstart', e => { e.preventDefault(); for (const t of e.changedTouches) T.pts.set(t.identifier, { x: t.clientX, y: t.clientY, sx: t.clientX, sy: t.clientY }); if (T.pts.size === 1) { T.moved = false; T.t0 = performance.now(); } if (T.pts.size === 2) { const [a, b] = [...T.pts.values()]; T.pinch = Math.hypot(a.x - b.x, a.y - b.y); T.moved = true; } }, { passive: false });
  canvas.addEventListener('touchmove', e => { e.preventDefault();
    for (const t of e.changedTouches) { const p = T.pts.get(t.identifier); if (!p) continue; const dx = t.clientX - p.x, dy = t.clientY - p.y; p.x = t.clientX; p.y = t.clientY;
      if (T.pts.size === 1) { if (Math.hypot(p.x - p.sx, p.y - p.sy) > 10) T.moved = true; if (T.moved) { if (studio.visible) { stu.yaw -= dx * 0.012; stu.pitch = clamp(stu.pitch + dy * 0.006, -0.4, 0.9); } else { cam.yaw -= dx * 0.008; cam.pitch = clamp(cam.pitch + dy * 0.006, -0.45, 1.4); } } } }
    if (T.pts.size === 2) { const [a, b] = [...T.pts.values()], d = Math.hypot(a.x - b.x, a.y - b.y); if (T.pinch) { const k = T.pinch / d; if (studio.visible) stu.dist = clamp(stu.dist * k, 0.9, 6); else cam.dist = clamp(cam.dist * k, 1.1, 32); } T.pinch = d; } }, { passive: false });
  canvas.addEventListener('touchend', e => { e.preventDefault(); for (const t of e.changedTouches) { const p = T.pts.get(t.identifier); T.pts.delete(t.identifier); if (p && !T.moved && T.pts.size === 0 && performance.now() - T.t0 < 350) onPick({ button: 0, clientX: t.clientX, clientY: t.clientY, detail: 1, ctrlKey: false }); } if (T.pts.size < 2) T.pinch = 0; }, { passive: false });
  canvas.addEventListener('touchcancel', () => { T.pts.clear(); T.pinch = 0; });
  // joystick virtual
  const joy = document.createElement('div'); joy.id = 'joy'; joy.innerHTML = '<i></i>'; $('#hud').appendChild(joy); const knob = joy.firstChild; let jid = null;
  const jset = (t) => { const r = joy.getBoundingClientRect(), cx = r.left + r.width / 2, cy = r.top + r.height / 2; let dx = (t.clientX - cx) / (r.width / 2), dy = (t.clientY - cy) / (r.height / 2); const l = Math.hypot(dx, dy); if (l > 1) { dx /= l; dy /= l; } S.joy = l < 0.15 ? null : { x: dx, y: dy }; knob.style.transform = `translate(${dx * 38}px,${dy * 38}px)`; };
  joy.addEventListener('touchstart', e => { e.preventDefault(); const t = e.changedTouches[0]; jid = t.identifier; jset(t); }, { passive: false });
  joy.addEventListener('touchmove', e => { e.preventDefault(); for (const t of e.changedTouches) if (t.identifier === jid) jset(t); }, { passive: false });
  const jend = e => { for (const t of e.changedTouches) if (t.identifier === jid) { jid = null; S.joy = null; knob.style.transform = ''; } }; joy.addEventListener('touchend', jend); joy.addEventListener('touchcancel', jend);
  // botões de ação
  const act = document.createElement('div'); act.id = 'actbtns'; act.innerHTML = '<button data-k="atk" title="Atacar">⚔️</button><button data-k="tgt" title="Próximo alvo">🎯</button><button data-k="guide" title="Guia automático">🧭</button><button data-k="ride" title="Montar">🐎</button><button data-k="fly" title="Voar">🪽</button><button data-k="up" title="Subir">⬆️</button><button data-k="down" title="Descer">⬇️</button><button data-k="dodge" title="Esquivar">🌀</button><button data-k="chat" title="Chat">💬</button>'; $('#hud').appendChild(act);
  act.addEventListener('touchstart', e => { e.stopPropagation(); const k = e.target.closest('button')?.dataset.k; if (k === 'up') S.flyUp = true; if (k === 'down') S.flyDown = true; }, { passive: true });
  const flyEnd = () => { S.flyUp = S.flyDown = false; }; act.addEventListener('touchend', flyEnd); act.addEventListener('touchcancel', flyEnd);
  act.onclick = e => { const k = e.target.closest('button')?.dataset.k; if (!k) return;
    if (k === 'atk') attackKey(); if (k === 'tgt') nextTarget();
    if (k === 'guide') { if (S.guide) stopGuide('Guia automático desligado'); else { const id = S.q.active.find(id => !qDone(id)); if (id) startGuide(id); else toast('Aceite uma missão no Arauto do Eclipse', 'err'); } }
    if (k === 'chat') document.body.classList.toggle('chat-open'); if (k === 'ride') toggleRide(); if (k === 'fly') toggleFly(); if (k === 'dodge') dodge(); };
}

// ---------- teclado ----------
const keys = {};
addEventListener('keydown', e => {
  const typing = document.activeElement && document.activeElement.tagName === 'INPUT';
  if (!S.inGame) return;
  if (e.key === 'Enter') { if (typing) return; e.preventDefault(); $('#chat-in').focus(); return; }
  if (e.key === 'Escape') { if (typing) { document.activeElement.blur(); return; } if (!$('#panel').hidden) closePanel(); else if (S.target) S.target = null; else openPanel('sys'); return; }
  if (typing) return;
  keys[e.code] = true;
  const fk = /^F([1-9]|1[0-2])$/.exec(e.key); if (fk) { e.preventDefault(); useSlot(+fk[1] - 1); return; }
  if (e.key === '0') { usePotion('hp'); return; } if (e.key === '-') { usePotion('mp'); return; } if (e.code === 'Backquote') { S.barPage = (S.barPage + 1) % BAR_PAGES; buildBar(); return; }
  if (panelState.kind && NPC_KEYS(e.key)) { e.preventDefault(); return; }
  const bk = BAR_KEYS.indexOf(e.key); if (bk >= 0 && !e.ctrlKey) { e.preventDefault(); useSlot(e.shiftKey ? bk : bk); return; }
  if (e.code === 'Tab') { e.preventDefault(); nextTarget(); }
  if (e.code === 'KeyQ') dodge();
  if (e.code === 'KeyR') toggleRide(); if (e.code === 'KeyV') toggleFly(); if (e.code === 'KeyU') toggleEquip(EQX);
  if (S.fly && e.code === 'Space') { e.preventDefault(); return; }
  if (e.code === 'Space' || e.code === 'KeyF') { e.preventDefault(); attackKey(); }
  const P = { KeyY: 'clan', KeyC: 'char', KeyI: 'bag', KeyK: 'skills', KeyL: 'quests', KeyM: 'map', KeyH: 'lore', KeyJ: 'codex', KeyG: 'gm' }[e.code];
  if (P && (P !== 'gm' || S.c.is_gm)) { if (panelState.kind === P) closePanel(); else openPanel(P); }
});
addEventListener('keyup', e => keys[e.code] = false);
function nextTarget() { const list = S.mobs.filter(m => !m.dead && Math.hypot(m.x - me.x, m.z - me.z) < 40).sort((a, b) => Math.hypot(a.x - me.x, a.z - me.z) - Math.hypot(b.x - me.x, b.z - me.z)); if (!list.length) return; const i = S.target ? list.indexOf(S.target.ref) : -1; S.target = { kind: 'mob', ref: list[(i + 1) % list.length] }; }
function attackKey() { if (!S.target || S.target.kind !== 'mob' || S.target.ref.dead) nextTarget(); if (S.target && (S.target.kind === 'mob' || S.target.kind === 'player')) S.autoAtk = true; }

// ---------- combate ----------
function tgtPos(t) { return t.kind === 'mob' ? t.ref : t.kind === 'player' ? t.ref : null; }
function inSafe(x, z) { return WG.region(x, z).safe; }
function dmgVs(atk, mult, def, crit, cd = 1.8) { const c = Math.random() < crit; return { v: Math.max(1, Math.round(GD.dmgFormula(atk, mult, def) * (0.9 + Math.random() * 0.2) * (c ? cd : 1))), crit: c }; }
function faceTo(x, z) { me.ry = Math.atan2(x - me.x, z - me.z); }
function basicAttack(st) {
  sfx(st.magic ? 'magic' : 'swing', 0.6);
  if (COMP.riding) dismount();
  const t = S.target, p = tgtPos(t); faceTo(p.x, p.z);
  const kind = st.weaponKind === 'arco' ? 'bow' : st.magic ? 'cast' : 'melee'; playAttack(me, kind);
  hitTarget(t, 1, st, kind === 'bow' ? 'arrow' : kind === 'cast' ? 'magic' : null);
  B.sendFx({ k: kind === 'bow' ? 'arrow' : kind === 'cast' ? 'magic' : 'melee', x: me.x, z: me.z, tx: p.x, tz: p.z, id: S.c.id });
}
function hitTarget(t, mult, st, proj, sk) {
  const p = tgtPos(t); const rk = st.cls.rank; mult *= sk ? 1 + 0.1 * rk : 1; if (sk && elemOf(sk) === GD.RACE_ELEM[S.c.race]) mult *= 1.05;
  const apply = () => {
    if (t.kind === 'mob') {
      const m = t.ref; if (m.dead) return;
      const targets = sk && sk.aoe ? S.mobs.filter(o => !o.dead && Math.hypot(o.x - (sk.self ? me.x : m.x), o.z - (sk.self ? me.z : m.z)) < sk.aoe + 0.8) : [m];
      targets.forEach(o => {
        let mul = mult; if (sk && sk.execute && o.hp / o.maxHp < 0.3) mul *= 2;
        const F = st.fx || {}; if (o.frozenUntil > now()) mul *= 1.4;
        const d = dmgVs(st.atk, mul, o.st.def * (1 + debOf(o, 'def')), st.crit, st.critDmg); hurtMob(o, d.v, d.crit); hitFx(o, st, d.crit, sk);
        // efeitos especiais da arma
        if (!o.dead || o.hp > -1e9) {
          if (F.pFire && Math.random() < F.pFire) { const fy = WG.height(o.x, o.z) + 1; emit(o.x, fy, o.z, { n: 40, color: 0xff6a1a, speed: 6, up: 3, life: 0.7, size: 0.3 }); shock(o.x, fy - 1, o.z, 0xff7a2a, 3.5); floatText(o.x, fy + 1.6, o.z, '🔥 Chama', '#ff9a4a', 22);
            S.mobs.filter(q => !q.dead && Math.hypot(q.x - o.x, q.z - o.z) < 3.5).forEach(q => hurtMob(q, Math.round(GD.dmgFormula(st.atk, 0.6, q.st.def)), false)); }
          if (F.pFrost && Math.random() < F.pFrost && !o.dead) { o.frozenUntil = now() + 3000; o.slowUntil = now() + 3000; emit(o.x, WG.height(o.x, o.z) + 1, o.z, { n: 30, color: 0x9ae0ff, speed: 3, up: 1, life: 0.9, size: 0.22, grav: 2 }); floatText(o.x, WG.height(o.x, o.z) + 2.6, o.z, '❄️ Congelado', '#9ae0ff', 22); }
          if (F.pStun && Math.random() < F.pStun && !o.dead) { o.stunUntil = now() + 1500; const fy = WG.height(o.x, o.z); lightning(o.x, fy, o.z); skillFx('stun', 'holy', o); }
          if (F.pBleed && Math.random() < F.pBleed && !o.dead) { o.dots.push({ until: now() + 5000, dps: GD.dmgFormula(st.atk, 0.9, o.st.def) / 5, next: now() + 1000 }); emit(o.x, WG.height(o.x, o.z) + 1.2, o.z, { n: 14, color: 0xc01020, speed: 2, up: 1, life: 0.8, size: 0.14, grav: 8 }); }
        }
        if (sk) { if (sk.stun) o.stunUntil = now() + sk.stun * 1000; if (sk.slow) o.slowUntil = now() + 4000; if (sk.dot) o.dots.push({ until: now() + sk.dot.dur * 1000, dps: GD.dmgFormula(st.atk, sk.dot.mult, o.st.def) / sk.dot.dur, next: now() + 1000 }); }
        const ls = (S.buffs.lifesteal ? 0.2 : 0) + (sk && sk.drain ? sk.drain : 0) + ((st.fx || {}).lifesteal || 0); if (ls) S.hp = Math.min(st.maxHp, S.hp + d.v * ls);
      });
    } else if (t.kind === 'player') {
      pvpHit(t.ref, mult);
    }
  };
  const el = elemOf(sk), fxApply = () => { apply(); if (el && sk && t.kind === 'mob' && (sk.aoe || (sk.mult || 0) >= 1.6)) { const c = sk.self ? me : p; elemImpact(el, c.x, c.z, sk.aoe || 2, (sk.mult || 1) / 2); } };
  if (isMeteor(sk)) meteor(sk.self ? me.x : p.x, sk.self ? me.z : p.z, sk.aoe || 5, apply);
  else if (proj) projectile(me.x, me.z, p.x, p.z, proj, sk?.fx, fxApply); else fxApply();
}
// elemento do personagem: o que domina a classe; se não houver, o da raça
function myElem() { const st = stats(); const k = S.c.class_id + ':' + S.c.race; if (S.elemKey !== k) { S.elemKey = k; S.elem = classElem(st.arch.skills, GD.RACE_ELEM[S.c.race]); } return S.elem; }
async function pvpHit(o, mult) {
  if (inSafe(me.x, me.z) || inSafe(o.x, o.z)) { toast('PvP proibido dentro das cidades', 'err'); S.autoAtk = false; return; }
  const r = await safe(() => B.pvp(o.id, mult)); if (!r) { S.autoAtk = false; return; }
  floatText(o.x, WG.height(o.x, o.z) + 2.2, o.z, String(r.dmg), '#ffe36a');
  S.lastCombat = Date.now(); S.c.karma = r.karma; S.c.pvp = r.pvp; S.c.pk = r.pk_count; S.flagUntil = r.flag_until ? Date.parse(r.flag_until) : 0; relabelMe();
  if (r.killed) { toast(r.pk ? `Você cometeu PK contra ${o.n}! Karma: ${r.karma}` : `Você venceu ${o.n} em PvP!`, r.pk ? 'err' : 'ok'); S.target = null; S.autoAtk = false; }
}
const WCOL = { fire: 0xff7a2a, ice: 0x9ae0ff, holy: 0xffe36a, spirit: 0xb08aff, arcane: 0xc07aff };
function hitFx(o, st, crit, sk) {
  sfx(crit ? 'crit' : st.magic ? 'magic' : 'hit', 0.8); if (sk && sk.fx === 'fire') sfx('fire', 0.6); if (sk && sk.fx === 'ice') sfx('ice', 0.7);
  const y = WG.height(o.x, o.z) + 1.1 * (o.fam ? o.fam.scale : 1), col = sk && WCOL[sk.fx] || (st.magic ? 0x8ab0ff : crit ? 0xffa040 : 0xfff0c0);
  emit(o.x, y, o.z, { n: crit ? 26 : 12, color: col, speed: crit ? 7 : 4.5, up: 1.5, life: 0.35, size: crit ? 0.2 : 0.14, grav: 10, drag: 3 });
  if (!st.magic && st.range < 5) slash(o.x, y, o.z, Math.atan2(o.x - me.x, o.z - me.z) + Math.PI / 2, crit ? 0xffb050 : (GD.ENC_TIER(me.enc || 0) ? new THREE.Color(GD.ENC_TIER(me.enc).c).getHex() : 0xffffff), crit || !!sk);
  if (crit) { shock(o.x, y - 1, o.z, 0xffa040, 2.2, 0.35); shake(0.35); postFlash(0.25); hitStop(70); }
  if (sk && (sk.mult || 0) >= 2.5) { if (!elemOf(sk)) crater(o.x, y - 1.1, o.z, col, 2.5); shake(0.5); hitStop(90); }
}
function lightning(x, y, z) {
  sfx('thunder', 0.4);
  const pts = []; let px = x + (Math.random() - 0.5) * 2, pz = z + (Math.random() - 0.5) * 2; for (let i = 0; i <= 8; i++) { const k = i / 8; pts.push(new THREE.Vector3(px + (x - px) * k + (Math.random() - 0.5) * 0.8, y + 14 * (1 - k), pz + (z - pz) * k + (Math.random() - 0.5) * 0.8)); }
  const l = new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), new THREE.LineBasicMaterial({ color: 0xcfe8ff, transparent: true, blending: THREE.AdditiveBlending })); scene.add(l);
  fx.push({ obj: l, t: 0, dur: 0.3, up: (o, k) => { o.material.opacity = 1 - k; } }); emit(x, y + 0.3, z, { n: 30, color: 0xbfe0ff, speed: 6, up: 2, life: 0.4, size: 0.18 }); shock(x, y, z, 0xbfe0ff, 3, 0.4);
}
function hurtMob(m, v, crit) { S.auraAt = Date.now();
  if (m.dead) return;
  if (m.returning) { floatText(m.x, WG.height(m.x, m.z) + 2.2 * m.fam.scale, m.z, 'Imune', '#9ab8ff'); return; }
  if (me && inSafe(me.x, me.z) && !S.gmKill) { if (!S.safeToast || Date.now() - S.safeToast > 3000) { S.safeToast = Date.now(); toast('Você não pode atacar monstros de dentro da cidade — saia da zona segura', 'err'); } S.autoAtk = false; return; } m.hp -= v; m.aggro = true; S.lastCombat = Date.now();
  floatText(m.x, WG.height(m.x, m.z) + 2.2 * m.fam.scale, m.z, (crit ? '💥' : '') + v, crit ? '#ff9a3a' : '#ffe36a');
  if (m.hp <= 0) killMob(m);
}
function freeMob(m) { m.model.disposed = true; scene.remove(m.model.root); m.model.root.traverse(o => { if (o.isSprite && o.material) { o.material.map?.dispose(); o.material.dispose(); } }); }
function killMob(m) {
  m.dead = true; m.model.anim.state = 'dead'; { const y = WG.height(m.x, m.z); emit(m.x, y + 0.8 * m.fam.scale, m.z, { n: m.fam.boss ? 80 : 26, color: m.fam.boss ? 0xffc040 : 0x8a7aff, speed: 2.2, up: 3, life: 1.2, size: 0.2, grav: -1.5, drag: 1 }); sfx('death', m.fam.boss ? 1 : 0.5); if (m.fam.boss) { sfx('boom'); shock(m.x, y, m.z, 0xffc040, 10, 1); beam(m.x, y, m.z, 0xffc040, 2); slowMo(1400); postFlash(1); shake(0.8); } } if (S.target && S.target.ref === m) { S.target = null; S.autoAtk = false; }
  setTimeout(() => { freeMob(m); S.mobs = S.mobs.filter(x => x !== m); }, 2500);
  S.killQ.push({ L: m.L, boss: !!m.fam.boss || !!m.champion, fam: m.fam.id });
}
async function processKills() {
  if (S.killBusy || !S.killQ.length) return; S.killBusy = true; const k = S.killQ.shift();
  try {
    const r = await B.kill(k.L, k.boss, k.fam);
    S.c.xp = r.xp_now; S.c.aurum = +S.c.aurum + r.aurum; S.c.karma = Math.max(0, (S.c.karma || 0) - Math.max(5, k.L >> 1));
    for (const [i, q] of Object.entries(r.drops || {})) S.inv[i] = (S.inv[i] || 0) + q;
    const dr = Object.keys(r.drops || {}).map(i => icon(i) + ' ' + iname(i)).join(', ');
    toast(`+${r.xp.toLocaleString('pt-BR')} XP • +${Number(r.aurum).toLocaleString('pt-BR')} aurum${dr ? ' • ' + dr : ''}`, 'ok'); if (r.unique) addChat({ kind: 'sys', msg: `✨ ITEM EXCLUSIVO: ${icon(r.unique)} ${iname(r.unique)}!` });
    if (r.level > S.c.level) levelUp(r.level);
    questEvent('kill', k.fam);
    if (panelState.kind === 'bag') renderPanel();
  } catch (e) { if (/Aguarde/.test(e.message)) S.killQ.unshift(k); else toast(e.message, 'err'); }
  S.killBusy = false;
}
function levelUp(L) {
  if (me && me.setExpr) me.setExpr('smile', 4000);
  const old = S.c.level; S.c.level = L; const st = stats(); S.hp = st.maxHp; S.mp = st.maxMp;
  toast(`⭐ Nível ${L}!`, 'ok'); beam(me.x, WG.height(me.x, me.z), me.z, 0xffd84a, 1.8); postFlash(1.2); shake(0.4); sfx('levelup'); shock(me.x, WG.height(me.x, me.z), me.z, 0xffe36a, 6, 0.9); addChat({ kind: 'q', msg: `Você alcançou o nível ${L}!` });
  const r = new THREE.Mesh(new THREE.TorusGeometry(1, 0.08, 6, 30), new THREE.MeshBasicMaterial({ color: 0xffe36a, transparent: true })); r.rotation.x = Math.PI / 2; r.position.set(me.x, WG.height(me.x, me.z) + 0.2, me.z); scene.add(r);
  fx.push({ obj: r, t: 0, dur: 1.4, up: (o, k) => { o.position.y += 0.05; o.scale.setScalar(1 + k * 1.5); o.material.opacity = 1 - k; } });
  for (const lv of [20, 40, 76]) if (old < lv && L >= lv) addChat({ kind: 'q', msg: `Uma nova classe está disponível! Fale com o Mestre de Classes em qualquer cidade.` });
  const sk = stats().arch.skills.filter(s => s.lvl > old && s.lvl <= L); sk.forEach(s => toast(`Nova habilidade: ${s.icon} ${s.name}`, 'ok'));
  buildBar();
}
// ----- aura de poder: anel de runas no chão, partículas que sobem e brilho pulsante da arma -----
const runeTex = (() => { const c = document.createElement('canvas'); c.width = c.height = 256; const g = c.getContext('2d'); g.translate(128, 128); g.strokeStyle = '#fff'; g.fillStyle = '#fff';
  g.lineWidth = 4; g.beginPath(); g.arc(0, 0, 120, 0, 7); g.stroke(); g.lineWidth = 2; g.beginPath(); g.arc(0, 0, 96, 0, 7); g.stroke(); g.font = '22px serif'; g.textAlign = 'center';
  for (let i = 0; i < 16; i++) { g.save(); g.rotate(i / 16 * Math.PI * 2); g.fillText('ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊ'[i], 0, -102); g.restore(); }
  for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2, b = a + Math.PI * 2 / 3; g.beginPath(); g.moveTo(Math.cos(a) * 90, Math.sin(a) * 90); g.lineTo(Math.cos(b) * 90, Math.sin(b) * 90); g.stroke(); }
  const t = new THREE.CanvasTexture(c); return t; })();
const POWER = { ring: null, k: 0 };
function powerLevel() {
  const eq = S.c.equipment || {}, en = S.c.enchant || {}, w = GD.ITEMS[eq.arma], ET = GD.ENC_TIER(en[eq.arma] || 0);
  let armorEnc = 0, armorGrade = 0, n = 0; for (const sl of ['armadura', 'elmo', 'luvas', 'botas']) { const it = GD.ITEMS[eq[sl]]; if (it) { armorEnc += en[eq[sl]] || 0; armorGrade += it.grade; n++; } }
  const armorK = n === 4 ? Math.max(0, Math.floor((armorEnc / 4 - 3) / 3) + 1, armorGrade / 4 >= 5 ? 2 : armorGrade / 4 >= 4 ? 1 : 0) : 0;
  return { k: Math.max(ET ? ET.k : 0, w?.relic ? 2 : 0, Math.min(5, armorK)), T: ET, relic: w?.relic, w };
}
function updatePower(dt) {
  if (S.dead || !me) return; const P = powerLevel(), t = performance.now() / 1000, gy = WG.height(me.x, me.z) + (S.alt || 0) + saddle();
  const col = new THREE.Color(P.T ? P.T.c : P.w?.neon || (P.relic ? '#ffd75a' : '#9ad0ff'));
  if (P.k >= 2) { if (!POWER.ring) { POWER.ring = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ map: runeTex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })); POWER.ring.rotation.x = -Math.PI / 2; POWER.ring.renderOrder = 4; scene.add(POWER.ring); }
    const r = POWER.ring; r.visible = true; r.material.color.copy(col); r.material.opacity = 0.35 + 0.15 * Math.sin(t * 2) + P.k * 0.06; r.scale.setScalar(1.6 + P.k * 0.35); r.rotation.z = t * (0.3 + P.k * 0.1); r.position.set(me.x, gy + 0.06, me.z); }
  else if (POWER.ring) POWER.ring.visible = false;
  // partículas: sobem em espiral; quanto maior o poder, mais e maiores
  if (P.k >= 1 && Math.random() < 0.15 + P.k * 0.15) { const a = t * 3 + Math.random() * 6.28, r = 0.45 + Math.random() * 0.3;
    emit(me.x + Math.cos(a) * r, gy + 0.2 + Math.random() * 0.6, me.z + Math.sin(a) * r, { n: 1, color: (Math.random() < 0.5 || !P.T ? col : new THREE.Color(P.T.c2)).getHex(), speed: 0.3, up: 1.2 + P.k * 0.3, life: 1 + P.k * 0.15, size: 0.09 + P.k * 0.025, grav: -0.6, drag: 0.8 }); }
  if (P.k >= 5 && Math.random() < 0.3) emit(me.x, gy + 2.6, me.z, { n: 1, color: 0xffffff, speed: 1.4, up: 0.2, life: 0.6, size: 0.18, grav: 1.5 });
  // brilho da arma pulsando
  if (me.encGlow) { const base = me.encGlow.userData.s || (me.encGlow.userData.s = me.encGlow.scale.x); me.encGlow.scale.setScalar(base * (1 + 0.18 * Math.sin(t * (3 + P.k)))); }
  if (me.encGlow2) me.encGlow2.material.rotation = t * 2;
  // rastro luminoso da arma durante o golpe (cor da classe ou do encantamento)
  const tip = me.weaponTip; if (tip && tip.parent) { const base = tip.parent.getWorldPosition(_trB), tp = tip.getWorldPosition(_trT), act = performance.now() - (me.anim.atkAt || 0) < 420;
    const tc = P.T ? P.T.c : P.w ? (P.w.neon || (P.relic ? '#ffd75a' : KIND_AURA[P.w.kind]) || '#ffffff') : '#ffffff'; updateTrail(base, tp, act && !COMP.riding, tc, 0.6 + P.k * 0.2); }
}
const _trB = new THREE.Vector3(), _trT = new THREE.Vector3();
function dodge() {
  if (S.dead || S.roll || S.sta < 25) { if (S.sta < 25) toast('Fôlego insuficiente para esquivar', 'err'); return; }
  const f = (keys.KeyW ? 1 : 0) - (keys.KeyS ? 1 : 0) - (S.joy ? S.joy.y : 0), r = (keys.KeyD ? 1 : 0) - (keys.KeyA ? 1 : 0) + (S.joy ? S.joy.x : 0);
  let vx, vz; if (f || r) { const sy = Math.sin(cam.yaw), cy = Math.cos(cam.yaw); vx = -sy * f + cy * r; vz = -cy * f - sy * r; } else { vx = Math.sin(me.ry); vz = Math.cos(me.ry); }
  const l = Math.hypot(vx, vz); sfx('dodge'); S.sta -= 25; S.roll = { vx: vx / l, vz: vz / l, end: now() + 520 }; S.dest = null; S.autoAtk = false; me.ry = Math.atan2(vx, vz);
  fxBurst(me.x, WG.height(me.x, me.z) + 0.2, me.z, 0xd8c8a0, 10, 0.5);
}
function hurtMe(v) {
  if (S.dead || S.buffs.invuln || S.god) return;
  if (S.fly && S.alt > 5) return;
  if (S.roll && now() < S.roll.end) { floatText(me.x, WG.height(me.x, me.z) + 2.4, me.z, 'Esquivou!', '#9fd0ff'); return; }
  const F = stats().fx || {}; if (F.dodge && Math.random() < F.dodge) { floatText(me.x, WG.height(me.x, me.z) + 2.4, me.z, 'Esquiva', '#9fd0ff'); return; }
  if (F.dmgRed) v = Math.max(1, Math.round(v * (1 - F.dmgRed)));
  { const sh = S.buffs.shield; if (sh && sh.until > now() && sh.absorb > 0) { const a = Math.min(sh.absorb, v); sh.absorb -= a; v -= a; emit(me.x, WG.height(me.x, me.z) + 1.2, me.z, { n: 8, color: 0x9ad0ff, speed: 3, up: 1, life: 0.4, size: 0.2 }); if (sh.absorb <= 0) delete S.buffs.shield; if (v <= 0) { floatText(me.x, WG.height(me.x, me.z) + 2.4, me.z, 'Absorvido', '#9ad0ff'); return; } } }
  emit(me.x, WG.height(me.x, me.z) + 1.2, me.z, { n: 8, color: 0xff3030, speed: 2.5, up: 1, life: 0.5, size: 0.14, grav: 9 });
  if (me.anim) me.anim.hitAt = performance.now(); postHurt(Math.min(1, v / Math.max(1, stats().maxHp) * 8)); shake(0.25);
  if (S.buffs.dodge && Math.random() < 0.4) { floatText(me.x, WG.height(me.x, me.z) + 2.4, me.z, 'Esquiva', '#9fd0ff'); return; }
  S.hp -= v; S.lastCombat = Date.now(); if (me.setExpr && me.anim.expr !== 'angry') me.setExpr(S.hp < stats().maxHp * 0.3 ? 'sad' : 'hurt', 900); floatText(me.x, WG.height(me.x, me.z) + 2.4, me.z, '-' + v, '#ff5a5a');
  if (S.hp <= 0) die(false);
}
function die(pvp, by) {
  if (S.dead) return; S.dead = true; S.hp = 0; S.autoAtk = false; S.target = null; S.dest = null; me.anim.state = 'dead';
  $('#dead-msg').textContent = pvp ? `Derrotado por ${by || 'outro jogador'}.` : 'Você perderá um pouco de experiência.'; $('#dead').hidden = false; S.deadPvp = pvp;
  S.mobs.forEach(m => m.aggro = false);
}
$('#btn-revive').onclick = async () => {
  const r = await safe(() => B.die(S.deadPvp)); if (!r) return;
  $('#dead').hidden = true; S.dead = false; const st = stats(); S.hp = st.maxHp * 0.7; S.mp = st.maxMp * 0.7; me.anim.state = 'idle';
  if (r.xp_lost) { S.c.xp = Math.max(0, S.c.xp - r.xp_lost); toast(`Você perdeu ${r.xp_lost.toLocaleString('pt-BR')} XP`, 'err'); }
  if (r.dropped) { toast(`Seu Karma fez você perder: ${iname(r.dropped)}`, 'err'); await refresh(); }
  teleport(r.x, r.z);
};

// ---------- habilidades ----------
function castSkill(i) {
  if (S.dead) return; const st = stats(), sk = st.arch.skills[i]; if (!sk) return;
  if (S.c.level < sk.lvl) { toast(`${sk.name} libera no nível ${sk.lvl}`, 'err'); return; }
  const t = now(); if ((S.cds[i] || 0) > t) return;
  const mpc = Math.round(sk.mp * (1 - ((st.fx || {}).mpCost || 0)));
  if (S.mp < mpc) { toast('MP insuficiente', 'err'); return; }
  const needT = (['hit', 'dash', 'blink', 'chain'].includes(sk.type) || (sk.type === 'debuff' && !sk.aoe)) && !sk.self;
  let tg = S.target; if (needT && (!tg || !['mob', 'player'].includes(tg.kind) || tg.ref.dead)) { attackKey(); tg = S.target; }
  if (needT && !tg) { toast('Selecione um alvo', 'err'); return; }
  if (needT) { const p = tgtPos(tg), d = Math.hypot(p.x - me.x, p.z - me.z), rng = sk.type === 'dash' || sk.type === 'blink' ? (sk.range || 14) : sk.type === 'chain' ? 18 : st.range + 1.5; if (d > rng) { toast('Alvo fora de alcance', 'err'); S.dest = { x: p.x, z: p.z }; S.autoAtk = true; return; } faceTo(p.x, p.z); }
  if (COMP.riding) dismount(); S.mp -= mpc; S.cds[i] = t + sk.cd * 1000; S.autoAtk = needT || S.autoAtk;
  const kind = st.weaponKind === 'arco' ? 'bow' : st.magic ? 'cast' : 'melee'; playAttack(me, ['hit', 'dash', 'blink', 'multi'].includes(sk.type) ? kind : 'cast'); if ((sk.type === 'hit' || sk.type === 'dash') && kind === 'melee') me.anim.kind = 'skill';
  floatText(me.x, WG.height(me.x, me.z) + 2.7, me.z, sk.icon + ' ' + sk.name, '#bfe8ff', 22); S.auraAt = Date.now(); castBurst(elemOf(sk) || myElem(), me.x, me.z, 1.8 * (GD.RACES[S.c.race]?.h || 1));
  if (sk.type === 'hit') { if (sk.self) hitTarget({ kind: 'mob', ref: nearestMob() || { x: me.x, z: me.z, dead: true } }, sk.mult, st, null, sk); else hitTarget(tg, sk.mult, st, st.range > 5 ? (st.magic ? 'magic' : 'arrow') : null, sk); aoeFx(sk, tg); }
  if (sk.type === 'dash') { const p = tgtPos(tg), d = Math.hypot(p.x - me.x, p.z - me.z), k = Math.max(0, (d - 1.8) / d); me.x += (p.x - me.x) * k; me.z += (p.z - me.z) * k; hitTarget(tg, sk.mult, st, null, sk); }
  if (sk.type === 'leap') { const p = tg ? tgtPos(tg) : null; const a = p ? Math.atan2(me.x - p.x, me.z - p.z) : me.ry + Math.PI; const nx = me.x + Math.sin(a) * sk.dist, nz = me.z + Math.cos(a) * sk.dist; if (!blocked(nx, nz)) { me.x = nx; me.z = nz; } }
  if (sk.type === 'buff') { S.buffs[sk.name] = { until: t + sk.dur * 1000, vals: sk.buff, icon: sk.icon }; if (sk.buff.invuln) S.buffs.invuln = S.buffs[sk.name]; if (sk.buff.lifesteal) S.buffs.lifesteal = S.buffs[sk.name]; if (sk.buff.dodge) S.buffs.dodge = S.buffs[sk.name]; }
  if (sk.type === 'debuff') {
    const center = sk.self ? me : (tg ? tgtPos(tg) : me);
    const list = sk.aoe ? S.mobs.filter(o => !o.dead && Math.hypot(o.x - center.x, o.z - center.z) < sk.aoe + 0.8) : (tg && tg.kind === 'mob' ? [tg.ref] : []);
    list.forEach(o => { o.deb = { until: t + sk.dur * 1000, vals: sk.deb, icon: sk.icon }; o.aggro = true; if (sk.stun) o.stunUntil = t + sk.stun * 1000; if (sk.deb.speed) o.slowUntil = t + sk.dur * 1000; if (sk.dot) o.dots.push({ until: t + sk.dot.dur * 1000, dps: GD.dmgFormula(st.atk, sk.dot.mult, o.st.def) / sk.dot.dur, next: t + 1000 }); skillFx('debuff', sk.fx, o); });
    if (sk.hitMult && tg) hitTarget(tg, sk.hitMult, st, st.range > 5 ? (st.magic ? 'magic' : 'arrow') : null, sk);
    if (!list.length && tg && tg.kind === 'player') hitTarget(tg, sk.hitMult || 0.6, st, null, sk);
  }
  if (sk.type === 'buff' || sk.type === 'shield') sfx('buff'); if (sk.type === 'heal') sfx('heal');
  if (sk.type === 'buff') skillFx('buff', sk.fx, me);
  if (sk.type === 'heal' || sk.type === 'mana') skillFx('heal', sk.fx || 'holy', me);
  if (sk.cleanse) { Object.keys(S.buffs).forEach(k => { if (S.buffs[k].bad) delete S.buffs[k]; }); }
  if (sk.type === 'hit' && sk.stun && tg && tg.kind === 'mob') skillFx('stun', 'holy', tg.ref);
  if (sk.type === 'heal') { const v = Math.round(st.maxHp * sk.pct); S.hp = Math.min(st.maxHp, S.hp + v); floatText(me.x, WG.height(me.x, me.z) + 2.2, me.z, '+' + v, '#7dff7d'); }
  if (sk.type === 'mana') { S.mp = Math.min(st.maxMp, S.mp + st.maxMp * sk.pct); }
  if (sk.type === 'taunt') S.mobs.forEach(m => { if (!m.dead && Math.hypot(m.x - me.x, m.z - me.z) < sk.radius) m.aggro = true; });
  // ----- tipos novos -----
  if (sk.type === 'shield') { S.buffs.shield = { until: t + sk.dur * 1000, absorb: Math.round(st.maxHp * sk.pct), icon: sk.icon, vals: {} }; skillFx('buff', 'ice', me); shock(me.x, WG.height(me.x, me.z), me.z, 0x9ad0ff, 3, 0.6); }
  if (sk.type === 'trap') placeTrap(sk, st);
  if (sk.type === 'zone') castZone(sk, st, tg);
  if (sk.type === 'multi') { const ts = S.mobs.filter(o => !o.dead && Math.hypot(o.x - me.x, o.z - me.z) < st.range + 6).sort((a, b) => Math.hypot(a.x - me.x, a.z - me.z) - Math.hypot(b.x - me.x, b.z - me.z)).slice(0, sk.n || 3);
    ts.forEach((o, k) => setTimeout(() => { if (!o.dead) { hitTarget({ kind: 'mob', ref: o }, sk.mult, st, st.range > 5 ? (st.magic ? 'magic' : 'arrow') : null, sk); applyStatus(o, sk, st); } }, k * 90)); }
  if (sk.type === 'chain') { let cur = tg && tg.kind === 'mob' ? tg.ref : nearestMob(), hit = []; for (let k = 0; k < (sk.n || 4) && cur; k++) { hit.push(cur); const c = cur; setTimeout(() => { if (!c.dead) { hurtMob(c, Math.round(GD.dmgFormula(st.atk, sk.mult * Math.pow(0.85, hit.indexOf(c)), c.st.def)), false); lightning(c.x, WG.height(c.x, c.z), c.z); applyStatus(c, sk, st); } }, k * 120);
      cur = S.mobs.filter(o => !o.dead && !hit.includes(o) && Math.hypot(o.x - c.x, o.z - c.z) < 9).sort((a, b) => Math.hypot(a.x - c.x, a.z - c.z) - Math.hypot(b.x - c.x, b.z - c.z))[0]; } }
  if (sk.type === 'blink' && tg) { const p = tgtPos(tg), a = Math.atan2(p.x - me.x, p.z - me.z); emit(me.x, WG.height(me.x, me.z) + 1, me.z, { n: 30, color: 0x8a2aff, speed: 3, up: 1, life: 0.5, size: 0.25 }); me.x = p.x + Math.sin(a) * 1.4; me.z = p.z + Math.cos(a) * 1.4; faceTo(p.x, p.z); hitTarget(tg, sk.mult, st, null, sk); emit(me.x, WG.height(me.x, me.z) + 1, me.z, { n: 30, color: 0x8a2aff, speed: 3, up: 1, life: 0.5, size: 0.25 }); }
  // estados extras (raiz, confusão, medo, empurrão, sangramento) em golpes e debuffs com alvo
  if (['hit', 'dash', 'debuff'].includes(sk.type) && tg && tg.kind === 'mob' && !tg.ref.dead && !sk.aoe) applyStatus(tg.ref, sk, st);
  if (['hit', 'debuff'].includes(sk.type) && sk.aoe) S.mobs.filter(o => !o.dead && Math.hypot(o.x - (sk.self || !tg ? me.x : tgtPos(tg).x), o.z - (sk.self || !tg ? me.z : tgtPos(tg).z)) < sk.aoe + 0.8).forEach(o => applyStatus(o, sk, st));
}
// efeitos de controle: duram menos em chefes (equilíbrio)
function applyStatus(o, sk, st) {
  const t = now(), k = o.fam.boss ? 0.4 : 1, y = WG.height(o.x, o.z) + 2 * o.fam.scale;
  if (sk.root) { o.rootUntil = t + sk.root * 1000 * k; floatText(o.x, y, o.z, '🌿 Preso', '#8aff8a', 20); emit(o.x, y - 1.8 * o.fam.scale, o.z, { n: 16, color: 0x5aaa3a, speed: 1, up: 2, ring: 0.7, life: 0.8, size: 0.18 }); }
  if (sk.confuse) { o.confUntil = t + sk.confuse * 1000 * k; floatText(o.x, y, o.z, '💫 Confuso', '#ff9aff', 20); }
  if (sk.fear) { o.fearUntil = t + sk.fear * 1000 * k; floatText(o.x, y, o.z, '😱 Medo', '#c8a0ff', 20); }
  if (sk.knock) { const a = Math.atan2(o.x - me.x, o.z - me.z), d = sk.knock * k, nx = o.x + Math.sin(a) * d, nz = o.z + Math.cos(a) * d; if (!blocked(nx, nz)) { o.x = nx; o.z = nz; } shock(o.x, WG.height(o.x, o.z), o.z, 0xffffff, 2, 0.3); }
  if (sk.bleed) { o.dots.push({ until: t + 6000, dps: GD.dmgFormula(st.atk, sk.bleed, o.st.def) / 6, next: t + 1000 }); floatText(o.x, y, o.z, '🩸 Sangrando', '#ff5050', 20); }
  if (sk.poison) { o.dots.push({ until: t + 8000, dps: GD.dmgFormula(st.atk, sk.poison, o.st.def) / 8, next: t + 1000 }); floatText(o.x, y, o.z, '☠️ Envenenado', '#9aff5a', 20); }
  if (sk.slowFx) { o.slowUntil = t + sk.slowFx * 1000; floatText(o.x, y, o.z, '🐌 Lento', '#9ad8ff', 20); }
}
// armadilhas: ficam no chão e disparam quando um monstro pisa
const TRAPS = [];
function placeTrap(sk, st) {
  sfx('metal', 0.6);
  if (TRAPS.length >= 3) { const o = TRAPS.shift(); scene.remove(o.mesh); }
  const y = WG.height(me.x, me.z), col = FX_COL[sk.fx] || 0xffaa3a, mesh = new THREE.Mesh(new THREE.PlaneGeometry(2.4, 2.4), new THREE.MeshBasicMaterial({ map: runeTex, color: col, transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false }));
  mesh.rotation.x = -Math.PI / 2; mesh.position.set(me.x, y + 0.08, me.z); scene.add(mesh); TRAPS.push({ mesh, x: me.x, z: me.z, sk, st, until: now() + (sk.life || 30) * 1000 });
  emit(me.x, y + 0.2, me.z, { n: 20, color: col, speed: 2, up: 0.5, life: 0.6, size: 0.2 });
}
function updateTraps() {
  const t = now(); for (let i = TRAPS.length - 1; i >= 0; i--) { const T = TRAPS[i]; T.mesh.rotation.z += 0.02; T.mesh.material.opacity = 0.55 + 0.3 * Math.sin(t / 200);
    const m = S.mobs.find(o => !o.dead && Math.hypot(o.x - T.x, o.z - T.z) < 1.6 + 0.4 * o.fam.scale);
    if (m || t > T.until) { if (m) { sfx('boom', 0.8); const y = WG.height(T.x, T.z), sk = T.sk, col = FX_COL[sk.fx] || 0xffaa3a; emit(T.x, y + 0.5, T.z, { n: 60, color: col, speed: 7, up: 4, life: 0.8, size: 0.3 }); shock(T.x, y, T.z, col, sk.aoe || 3, 0.5); shake(0.3);
        S.mobs.filter(o => !o.dead && Math.hypot(o.x - T.x, o.z - T.z) < (sk.aoe || 3)).forEach(o => { hurtMob(o, Math.round(GD.dmgFormula(T.st.atk, sk.mult || 1.5, o.st.def)), false); o.aggro = true; applyStatus(o, sk, T.st); }); }
      scene.remove(T.mesh); T.mesh.material.dispose(); TRAPS.splice(i, 1); } }
}
// zonas: chuva de flechas, meteoros, nevasca — dano em pulsos numa área
function castZone(sk, st, tg) {
  const p = tg && tg.ref && !tg.ref.dead ? tgtPos(tg) : { x: me.x + Math.sin(me.ry) * 6, z: me.z + Math.cos(me.ry) * 6 }, col = FX_COL[sk.fx] || 0xffffff, R = sk.aoe || 5, y = WG.height(p.x, p.z);
  shock(p.x, y, p.z, col, R, 0.8); let n = 0; const ticks = sk.ticks || 4; sfx(sk.fx === 'ice' ? 'ice' : sk.fx === 'fire' ? 'fire' : 'magic');
  const iv = setInterval(() => { if (++n > ticks) { clearInterval(iv); return; }
    for (let k = 0; k < 6; k++) { const a = Math.random() * 6.28, r = Math.random() * R; emit(p.x + Math.cos(a) * r, y + 9, p.z + Math.sin(a) * r, { n: 4, color: col, speed: 0.5, up: -14, life: 0.6, size: 0.3, grav: 20 }); }
    const zel = elemOf(sk), za = Math.random() * 6.28, zr = Math.random() * R * 0.6, zx = p.x + Math.cos(za) * zr, zz = p.z + Math.sin(za) * zr; if (isMeteor(sk)) meteor(zx, zz, R * 0.55, null, 0.7); else if (zel) setTimeout(() => elemImpact(zel, zx, zz, R * 0.6, 0.8), 260);
    setTimeout(() => { emit(p.x, y + 0.4, p.z, { n: 24, color: col, speed: 5, up: 2, ring: R * 0.5, life: 0.5, size: 0.25 }); if (sk.fx === 'fire') shake(0.15);
      S.mobs.filter(o => !o.dead && Math.hypot(o.x - p.x, o.z - p.z) < R + 0.5).forEach(o => { hurtMob(o, Math.round(GD.dmgFormula(st.atk, sk.mult / ticks * 1.6, o.st.def)), false); o.aggro = true; if (n === 1) applyStatus(o, sk, st); }); }, 280);
  }, 600);
}
function nearestMob() { let b = null, bd = 1e9; S.mobs.forEach(m => { if (m.dead) return; const d = Math.hypot(m.x - me.x, m.z - me.z); if (d < bd) { bd = d; b = m; } }); return b; }
function aoeFx(sk, tg) { if (!sk.aoe) return; const p = sk.self || !tg ? me : tgtPos(tg); const col = { fire: 0xff6a1a, ice: 0x8ad8ff, holy: 0xffe36a, spirit: 0x9a6aff, arcane: 0xc07aff }[sk.fx] || 0xffffff; const s = new THREE.Mesh(new THREE.SphereGeometry(1, 16, 10), new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.5, depthWrite: false })); s.position.set(p.x, WG.height(p.x, p.z) + 0.5, p.z); scene.add(s); fx.push({ obj: s, t: 0, dur: 0.5, up: (o, k) => { o.scale.setScalar(0.5 + k * sk.aoe); o.material.opacity = 0.5 * (1 - k); } }); }
async function usePotion(kind, want) {
  if (S.dead || now() < S.potCd) return;
  const id = want && S.inv[want] ? want : kind === 'hp' ? (S.inv.pocao_hp2 ? 'pocao_hp2' : S.inv.pocao_hp ? 'pocao_hp' : null) : (S.inv.pocao_mp ? 'pocao_mp' : null);
  if (!id) { toast(kind === 'hp' ? 'Sem poções de vida' : 'Sem poções de mana', 'err'); return; }
  S.potCd = now() + 2500; const r = await safe(() => B.useItem(id)); if (!r) return;
  S.inv[id]--; if (!S.inv[id]) delete S.inv[id]; const st = stats();
  if (r.hpPct) { S.hp = Math.min(st.maxHp, S.hp + st.maxHp * r.hpPct); floatText(me.x, WG.height(me.x, me.z) + 2.2, me.z, '+' + Math.round(st.maxHp * r.hpPct), '#7dff7d'); }
  if (r.mpPct) S.mp = Math.min(st.maxMp, S.mp + st.maxMp * r.mpPct);
}

// ---------- efeitos ----------
const fx = [];
function debOf(m, k) { return m.deb && m.deb.until > now() ? (m.deb.vals[k] || 0) : 0; }
const FX_COL = { fire: 0xff6a1a, ice: 0x8ad8ff, holy: 0xffe36a, spirit: 0x9a6aff, arcane: 0xc07aff, dark: 0x8a2aff, poison: 0x7aff3a, nature: 0x5aff7a, wind: 0xbfffe8, blood: 0xff2a3a, earth: 0xc8a060 };
const sparkTex = (() => { const c = document.createElement('canvas'); c.width = c.height = 32; const g = c.getContext('2d'); const gr = g.createRadialGradient(16, 16, 0, 16, 16, 16); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.3, 'rgba(255,255,255,0.6)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.fillRect(0, 0, 32, 32); return new THREE.CanvasTexture(c); })();
// efeitos por função: buff = coluna de luz subindo + anel; debuff = espiral escura descendo; cura = brilhos verdes/dourados; atordoar = estrelas girando
function skillFx(kind, f, who) {
  const col = new THREE.Color(FX_COL[f] || (kind === 'debuff' ? 0x8a2aff : kind === 'heal' ? 0x7dff7d : 0xffe36a)), x = who.x, z = who.z, y = WG.height(x, z);
  const ringM = new THREE.Mesh(new THREE.RingGeometry(0.6, 0.9, 32), new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.8, side: THREE.DoubleSide, blending: THREE.AdditiveBlending, depthWrite: false }));
  ringM.rotation.x = -Math.PI / 2; ringM.position.set(x, y + (kind === 'debuff' ? 2.2 : 0.1), z); scene.add(ringM);
  fx.push({ obj: ringM, t: 0, dur: 0.9, up: (o, k) => { const s = kind === 'debuff' ? 1.6 - k : 0.6 + k * 1.6; o.scale.setScalar(s); o.position.y = y + (kind === 'debuff' ? 2.2 - k * 2 : 0.1 + k * 0.3); o.material.opacity = 0.8 * (1 - k); } });
  emit(x, y + 0.4, z, { n: kind === 'stun' ? 8 : 28, color: col.getHex(), speed: 1.2, up: kind === 'debuff' ? -0.5 : 3.5, ring: 0.8, life: 1.1, size: 0.2, grav: kind === 'debuff' ? 2 : -0.5, drag: 0.8 });
  if (kind === 'buff') shock(x, y, z, col.getHex(), 2.6, 0.6);
  const n = kind === 'stun' ? 5 : 10;
  for (let i = 0; i < n; i++) {
    const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: sparkTex, color: col, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true })); const a0 = i / n * Math.PI * 2, r0 = 0.5 + Math.random() * 0.4;
    sp.scale.setScalar(kind === 'stun' ? 0.35 : 0.28); scene.add(sp);
    fx.push({ obj: sp, t: 0, dur: kind === 'stun' ? 1.6 : 1.0 + Math.random() * 0.4, up: (o, k) => {
      if (kind === 'stun') { const a = a0 + k * 12; o.position.set(x + Math.cos(a) * 0.5, y + 2.3, z + Math.sin(a) * 0.5); }
      else if (kind === 'debuff') { const a = a0 - k * 9, r = r0 * (1 - k * 0.6); o.position.set(x + Math.cos(a) * r, y + 2.4 - k * 2.2, z + Math.sin(a) * r); }
      else { const a = a0 + k * 6; o.position.set(x + Math.cos(a) * r0, y + 0.2 + k * 2.6, z + Math.sin(a) * r0); }
      o.material.opacity = 1 - k; } });
  }
}
function floatText(x, y, z, txt, color, size = 34) { const l = makeLabel(txt, color, size); l.position.set(x + (Math.random() - 0.5) * 0.6, y, z); scene.add(l); fx.push({ obj: l, t: 0, dur: 1.1, up: (o, k) => { o.position.y += 0.025; o.material.opacity = 1 - k * k; } }); }
function projectile(x, z, tx, tz, kind, f, onHit) {
  const y0 = WG.height(x, z) + 1.4, y1 = WG.height(tx, tz) + 1.2;
  const col = { fire: 0xff6a1a, ice: 0x8ad8ff, holy: 0xffe36a, spirit: 0x9a6aff, arcane: 0xc07aff }[f] || (kind === 'magic' ? 0x8ab0ff : 0xffffff);
  const o = kind === 'arrow' ? new THREE.Mesh(new THREE.CylinderGeometry(0.02, 0.02, 0.9, 4), new THREE.MeshBasicMaterial({ color: 0xe8d8a0 })) : new THREE.Mesh(new THREE.IcosahedronGeometry(0.25, 1), new THREE.MeshBasicMaterial({ color: col }));
  if (kind === 'arrow') { o.rotation.order = 'YXZ'; o.rotation.y = Math.atan2(tx - x, tz - z); o.rotation.x = Math.PI / 2; }
  scene.add(o); const d = Math.hypot(tx - x, tz - z), dur = Math.max(0.12, d / (kind === 'arrow' ? 45 : 28));
  fx.push({ obj: o, t: 0, dur, up: (ob, k) => { ob.position.set(x + (tx - x) * k, y0 + (y1 - y0) * k + Math.sin(k * Math.PI) * d * 0.04, z + (tz - z) * k); if (kind !== 'arrow') emit(ob.position.x, ob.position.y, ob.position.z, { n: 2, color: col, speed: 0.4, up: 0.2, life: 0.35, size: 0.22, grav: 0 }); },
    end: () => { if (kind !== 'arrow') emit(tx, y1, tz, { n: 18, color: col, speed: 4, up: 1.5, life: 0.5, size: 0.2 }); onHit && onHit(); } });
}
function updateFx(dt) {
  for (let i = fx.length - 1; i >= 0; i--) { const f = fx[i]; f.t += dt; const k = Math.min(1, f.t / f.dur); f.up(f.obj, k); if (k >= 1) { scene.remove(f.obj); f.obj.geometry?.dispose?.(); if (f.obj.material?.map && f.obj.material.map !== sparkTex) f.obj.material.map.dispose(); f.obj.material?.dispose?.(); f.end && f.end(); fx.splice(i, 1); } }
}

// ---------- monstros (simulados por jogador) ----------
function spawnMob(fam, L, x, z) {
  const R = buildMob(fam), st = GD.mobStats(L, fam.boss);
  const m = { id: ++S.mobSeq, kind: 'mob', fam, L, st, hp: st.hp, maxHp: st.hp, x, z, ry: Math.random() * 6, home: { x, z }, model: R, aggro: false, nextAtk: 0, stunUntil: 0, slowUntil: 0, dots: [], wander: null, wanderT: 0, dead: false };
  const diff = L - S.c.level, col = diff >= 5 ? '#ff5050' : diff >= 2 ? '#ffd050' : diff >= -2 ? '#ffffff' : diff >= -5 ? '#7fd0ff' : '#6fa86f';
  const lb = makeLabel(`${fam.boss ? '👑 ' : ''}${fam.name} Nv.${L}`, col, fam.boss ? 34 : 26); lb.position.y = (fam.model === 'golem' ? 3 : fam.model === 'ent' ? 4.4 : fam.model === 'dragon' ? 2.8 : 2.1) + 0.2; lb.scale.multiplyScalar(1 / fam.scale); R.root.add(lb);
  R.root.position.set(x, WG.height(x, z), z); R.root.traverse(o => o.userData.pick = { kind: 'mob', ref: m }); scene.add(R.root); S.mobs.push(m);
  if (fam.boss) { addChat({ kind: 'sys', msg: `⚠ ${fam.name} (Nv. ${L}) surgiu por perto!` }); }
  return m;
}
function makeChampion(m) { m.champion = true; m.maxHp = m.hp = Math.round(m.hp * 3); m.st = { ...m.st, atk: m.st.atk * 1.4, def: m.st.def * 1.3 }; m.model.root.scale.multiplyScalar(1.25);
  const lb = makeLabel(`⭐ Campeão ${m.fam.name} Nv.${m.L}`, '#ffcf3a', 28); lb.position.y = 2.6; m.model.root.add(lb); }
function spawner() {
  if (!me || S.dead) return;
  for (const m of [...S.mobs]) if (!m.dead && Math.hypot(m.x - me.x, m.z - me.z) > 170) { freeMob(m); S.mobs = S.mobs.filter(x => x !== m); }
  // chefes de missão
  for (const id of S.q.active) { const Q = QD.QUESTS[id]; if (Q.goal.type !== 'boss' || !Q.goal.spot) continue; const t = GD.TOWNS.find(t => t.id === Q.goal.spot[0]), sp = t.spotsPos[Q.goal.spot[1]];
    if (Math.hypot(sp.x - me.x, sp.z - me.z) < 140 && !S.mobs.some(m => !m.dead && m.fam.id === Q.goal.fam)) spawnMob(FAM[Q.goal.fam], t.max + 2 > 80 ? 80 : t.max + 2, sp.x + 8, sp.z + 8); }
  // chefes especiais dos castelos, ruínas e covis (renascem a cada 10 min)
  S.lmCd = S.lmCd || {};
  for (const L of GD.LANDMARKS) { const d = Math.hypot(L.x - me.x, L.z - me.z); if (d > 140 || (S.lmCd[L.id] || 0) > Date.now() || S.mobs.some(m => !m.dead && m.fam.id === L.boss)) continue;
    const m = spawnMob(FAM[L.boss], L.lvl, L.x + 2, L.z + 2); m.landmark = L.id; setTimeout(() => say(m.model.root, bossLine(L.type), { boss: true, race: 'orc', h: 3 * (FAM[L.boss].scale || 1) }), 600); addChat({ kind: 'sys', msg: `🏰 ${FAM[L.boss].name} guarda ${L.name}. Derrote-o para conseguir itens exclusivos!` }); S.lmCd[L.id] = Date.now() + 600000; }
  if (WG.inNeon(me.x, me.z, 30)) { neonSpawner(); return; }
  const rg = WG.region(me.x, me.z); if (rg.dist < GD.SAFE_R + 20) return;
  // população variável: mais monstros à noite, perto de locais especiais e em níveis altos
  const cap = Math.round((9 + S.c.level / 10 + ENV.night * 5 + (WG.nearestLandmark(me.x, me.z).dist < 160 ? 4 : 0)) * (0.85 + 0.3 * Math.sin(Date.now() / 90000)));
  if (S.mobs.filter(m => !m.dead && !m.fam.boss).length >= cap) return;
  for (let k = 0; k < 8; k++) {
    const a = Math.random() * Math.PI * 2, d = 35 + Math.random() * 55, x = me.x + Math.cos(a) * d, z = me.z + Math.sin(a) * d;
    const r = WG.region(x, z); if (r.dist < GD.SAFE_R + 25 || blocked(x, z) || WG.height(x, z) < 1) continue;
    const fams = GD.MOBS[r.grade], boss = Math.random() < 0.004 + ENV.night * 0.003; const fam = boss ? fams[2] : fams[Math.random() < 0.5 ? 0 : 1];
    const pack = boss ? 1 : 1 + Math.floor(Math.random() * (ENV.night > 0.5 ? 3.2 : 2.4));
    for (let i = 0; i < pack; i++) { const m = spawnMob(fam, clamp(r.level + Math.round(Math.random() * 2 - 1) + (boss ? 2 : 0), 1, 80), x + i * 2.2, z + (i % 2) * 2);
      if (!boss && Math.random() < 0.03) makeChampion(m); }
    break;
  }
}
function neonSpawner() {
  const N = GD.NEON, cap = 10 + Math.round(S.c.level / 12); if (S.mobs.filter(m => !m.dead && !m.fam.boss).length >= cap) return;
  for (let k = 0; k < 8; k++) { const a = Math.random() * Math.PI * 2, d = 30 + Math.random() * 45, x = me.x + Math.cos(a) * d, z = me.z + Math.sin(a) * d;
    if (!WG.inNeon(x, z, -8) || Math.hypot(x - N.hub.x, z - N.hub.z) < N.hub.r + 12 || Math.hypot(x - N.x, z - N.z) < 18 || blocked(x, z)) continue;
    const pool = GD.NEON_MOBS.filter(f => !f.elite), elite = Math.random() < 0.06, fam = elite ? FAM.colosso : pool[Math.floor(Math.random() * pool.length)];
    const pack = elite ? 1 : 1 + Math.floor(Math.random() * 2.6);
    for (let i = 0; i < pack; i++) { const m = spawnMob(fam, clamp(56 + Math.round(Math.random() * 4 - 2) + (elite ? 4 : 0), 1, 80), x + i * 2.4, z + (i % 2) * 2.2); if (!elite && Math.random() < 0.05) makeChampion(m); }
    break; }
}
function updateMobs(dt) {
  const t = now(), st = me ? stats() : null, inTown = me && inSafe(me.x, me.z);
  for (const m of S.mobs) {
    if (m.dead) { animMob(m.model, dt, false); continue; }
    for (const d of m.dots) if (t >= d.next && t < d.until) { d.next += 1000; hurtMob(m, Math.max(1, Math.round(d.dps)), false); if (m.dead) break; }
    m.dots = m.dots.filter(d => d.until > t); if (m.dead) continue;
    const dP = Math.hypot(me.x - m.x, me.z - m.z), dH = Math.hypot(m.home.x - m.x, m.home.z - m.z);
    if (!m.aggro && m.fam.aggro && dP < 13 && !S.dead && !inTown && Math.abs(m.L - S.c.level) < 15) m.aggro = true;
    if (m.aggro && (S.dead || inTown || dH > 70)) { m.aggro = false; m.returning = true; }
    if (m.returning) { m.hp = Math.min(m.maxHp, m.hp + m.maxHp * 0.25 * dt); if (dH < 3) { m.returning = false; m.hp = m.maxHp; m.wander = null; } }
    let tx = null, tz = null, spd = m.st.speed * (t < m.slowUntil ? 0.55 : 1) * (1 + Math.max(-0.9, debOf(m, 'speed'))) * (m.fam.boss ? 0.9 : 1);
    const reach = 1.6 * m.fam.scale + 0.6;
    if (t < m.stunUntil) { /* atordoado */ }
    else if (t < (m.fearUntil || 0)) { tx = m.x + (m.x - me.x); tz = m.z + (m.z - me.z); spd *= 1.1; }
    else if (t < (m.confUntil || 0)) { if (!m.wander || t > m.wanderT) { m.wanderT = t + 900; m.wander = { x: m.x + (Math.random() - 0.5) * 10, z: m.z + (Math.random() - 0.5) * 10 }; } tx = m.wander.x; tz = m.wander.z; spd *= 0.6; }
    else if (t < (m.rootUntil || 0) && dP > reach) { /* enraizado: não anda, mas ataca se estiver perto */ }
    else if (m.returning) { tx = m.home.x; tz = m.home.z; spd *= 1.6; }
    else if (m.aggro) { if (dP > reach) { tx = me.x; tz = me.z; spd *= 1.25; } else if (t >= m.nextAtk) { m.nextAtk = t + 1500; m.model.anim.atk = now(); m.ry = Math.atan2(me.x - m.x, me.z - m.z); const d = dmgVs(m.st.atk * (1 + debOf(m, 'atk')), 1, st.pdef, 0.05); hurtMe(d.v); } }
    else { if (!m.wander || t > m.wanderT) { m.wanderT = t + 3000 + Math.random() * 4000; m.wander = Math.random() < 0.5 ? null : { x: m.home.x + (Math.random() - 0.5) * 30, z: m.home.z + (Math.random() - 0.5) * 30 }; } if (m.wander) { tx = m.wander.x; tz = m.wander.z; spd *= 0.35; } }
    let moving = false;
    if (tx != null) { const dx = tx - m.x, dz = tz - m.z, d = Math.hypot(dx, dz); if (d > 0.5) { const nx = m.x + dx / d * spd * dt, nz = m.z + dz / d * spd * dt; if (!blocked(nx, nz) && !inSafe(nx, nz)) { m.x = nx; m.z = nz; moving = true; } else if (m.returning) { m.x = m.home.x; m.z = m.home.z; } else m.wander = null; m.ry = Math.atan2(dx, dz); } }
    m.model.root.position.set(m.x, WG.height(m.x, m.z), m.z); m.model.root.rotation.y = m.ry;
    m.model.fast = m.aggro || m.returning; animMob(m.model, dt, moving);
  }
}

// ---------- movimento ----------
// preso dentro de um objeto (ex.: chegou por teleporte): deixa sair andando
function stuckIn(x, z) { return WG.height(x, z) > WG.WATER + 0.25 && blocked(x, z); }
function blocked(x, z, fly) { if (x < 20 || z < 20 || x > 2980 || z > 2980) return true; if (!fly && WG.height(x, z) < WG.WATER + 0.25) return true;
  if (fly && S.alt > 9) return false; // voando alto passa por cima
  for (const h of houses) { const dx = x - h.x, dz = z - h.z; if (h.gate && castleOpen(h.gate)) continue; if (h.hw) { if (Math.abs(dx) > h.br || Math.abs(dz) > h.br) continue; const lx = dx * h.c + dz * h.s, lz = -dx * h.s + dz * h.c; if (Math.abs(lx) < h.hw && Math.abs(lz) < h.hd) return true; } else if (dx * dx + dz * dz < h.r * h.r) return true; }
  const c = chunks.get(Math.floor(x / CH) + ',' + Math.floor(z / CH)); if (c && c.cols) { const a = c.cols; for (let k = 0; k < a.length; k += 3) { const dx = x - a[k], dz = z - a[k + 1]; if (dx * dx + dz * dz < a[k + 2] * a[k + 2]) return true; } }
  return false; }
function teleport(x, z) { me.x = x; me.z = z; S.dest = null; S.target = null; S.autoAtk = false; S.mobs.forEach(freeMob); S.mobs = []; updateChunks(x, z, true); saveNow(); }
function updateMe(dt) {
  const st = stats(); let vx = 0, vz = 0, moving = false;
  const typing = document.activeElement && document.activeElement.tagName === 'INPUT';
  if (!S.dead && !typing) {
    const f = (keys.KeyW || keys.ArrowUp ? 1 : 0) - (keys.KeyS || keys.ArrowDown ? 1 : 0) - (S.joy ? S.joy.y : 0), r = (keys.KeyD || keys.ArrowRight ? 1 : 0) - (keys.KeyA || keys.ArrowLeft ? 1 : 0) + (S.joy ? S.joy.x : 0);
    if (f || r) { if (S.guide) stopGuide('Guia automático cancelado'); const sy = Math.sin(cam.yaw), cy = Math.cos(cam.yaw); vx = -sy * f + cy * r; vz = -cy * f - sy * r; S.dest = null; S.gatherAt = null; S.npcAt = null; S.channel = null; S.autoAtk = false; }
  }
  if (!vx && !vz && !S.dead) {
    const t = S.target;
    if (S.autoAtk && t && (t.kind === 'mob' || t.kind === 'player') && !t.ref.dead) {
      const p = tgtPos(t), d = Math.hypot(p.x - me.x, p.z - me.z), rr = st.range + (t.kind === 'mob' ? 0.8 * t.ref.fam.scale : 0.4);
      if (d > rr) S.dest = { x: p.x, z: p.z }; else { S.dest = null; faceTo(p.x, p.z); if (now() >= S.nextAtk) { S.nextAtk = now() + st.atkInterval * 1000; basicAttack(st); } }
    }
    if (S.gatherAt && Math.hypot(S.gatherAt.x - me.x, S.gatherAt.z - me.z) < 3.2) { S.dest = null; S.channel = { node: S.gatherAt, start: now(), end: now() + 2000 }; S.gatherAt = null; playAttack(me, 'melee'); }
    if (S.npcAt && Math.hypot(S.npcAt.x - me.x, S.npcAt.z - me.z) < 4) { S.dest = null; const n = S.npcAt; S.npcAt = null; faceTo(n.x, n.z); openNpc(n); }
    if (S.dest) { const dx = S.dest.x - me.x, dz = S.dest.z - me.z, d = Math.hypot(dx, dz); const stop = S.npcAt ? 3.5 : S.gatherAt ? 2.6 : 0.3; if (d < stop) { S.dest = null; destRing.visible = false; } else { vx = dx / d; vz = dz / d; } }
  }
  // fôlego: corrida (Shift), esquiva (Q) e escalada automática em encostas íngremes
  const sprint = (keys.ShiftLeft || keys.ShiftRight || S.sprintBtn) && (vx || vz) && S.sta > 5 && !S.dead;
  let climbing = false, mode = 'run';
  if (S.roll && now() < S.roll.end) { vx = S.roll.vx; vz = S.roll.vz; }
  if (vx || vz) {
    const l = Math.hypot(vx, vz), h0 = WG.height(me.x, me.z);
    let sp = st.speed * dt * (S.roll && now() < S.roll.end ? 2.6 : sprint ? 1.45 : 1) * mountSpeed() * (S.fly ? (COMP.riding ? 1.15 : 1.7) : 1);
    const px = me.x + vx / l * sp, pz = me.z + vz / l * sp, grade = (WG.height(px, pz) - h0) / Math.max(sp, 1e-4);
    if (S.fly) { /* voando: sem obstáculo de terreno */ }
    else if (grade > 0.95 && COMP.riding) { sp = 0; if (now() - (S.staWarn || 0) > 2500) { S.staWarn = now(); toast('A montaria não escala paredes — desmonte (R) para escalar', 'err'); } }
    else if (grade > 0.95) { // parede: escala com fôlego
      if (S.sta > 0) { climbing = true; sp *= 0.42; S.sta = Math.max(0, S.sta - 13 * dt); if (!S.climbTip) { S.climbTip = 1; toast('⛰️ Escalando! O fôlego (barra verde) acaba rápido — pare em platôs para recuperar.'); } }
      else { sp = 0; if (now() - (S.staWarn || 0) > 2500) { S.staWarn = now(); toast('Sem fôlego para escalar — espere recuperar', 'err'); } }
    } else if (grade > 0.45) sp *= 0.72;
    const nx = me.x + vx / l * sp, nz = me.z + vz / l * sp;
    if (sp > 0 && S.fly) { if (!blocked(nx, nz, true) || blocked(me.x, me.z, true)) { me.x = nx; me.z = nz; moving = true; } }
    else if (sp > 0) { if (!blocked(nx, nz) || (stuckIn(me.x, me.z) && !stuckIn(nx, nz) || stuckIn(me.x, me.z) && WG.height(nx, nz) > 0.3)) { me.x = nx; me.z = nz; moving = true; } else if (!blocked(nx, me.z)) { me.x = nx; moving = true; } else if (!blocked(me.x, nz)) { me.z = nz; moving = true; } else S.dest = null; }
    me.ry = Math.atan2(vx, vz); S.channel = null;
    if (sprint && moving && !climbing) { S.sta = Math.max(0, S.sta - 11 * dt); mode = 'sprint'; }
    if (climbing) mode = 'climb';
    if (moving && (mode === 'sprint' || climbing) && Math.random() < 0.35) emit(me.x, WG.height(me.x, me.z) + 0.1, me.z, { n: 2, color: climbing ? 0x9a9080 : 0xc8b890, speed: 1, up: 0.8, life: 0.6, size: 0.25, grav: 1, jit: 0.3 });
  }
  // aura mística da arma: cada estilo de classe tem sua cor e partículas na ponta da arma (grau C em diante)
  { const w = GD.ITEMS[S.c.equipment?.arma], tip = me.weaponTip || me.orb; if (w && tip && !S.dead && (w.grade >= 2 || w.relic) && Math.random() < 0.12 + w.grade * 0.06) { const p = tip.getWorldPosition(_tipV);
      emit(p.x, p.y, p.z, { n: 1, color: new THREE.Color(w.neon || (w.relic ? '#ffd75a' : KIND_AURA[w.kind]) || '#ffffff').getHex(), speed: 0.25, up: 0.5, life: 0.7, size: 0.1 + w.grade * 0.015, grav: -0.3, drag: 1 }); } }
  // aura dos equipamentos: encantamento (+4 a +16) e armaduras poderosas dão sensação de poder
  updatePower(dt);
  if (!climbing && !sprint) S.sta = Math.min(100, S.sta + (moving ? 14 : 24) * dt);
  if (S.roll && now() < S.roll.end) mode = 'roll'; else if (S.roll) S.roll = null;
  me.anim.state = S.dead ? 'dead' : COMP.riding ? 'mount' : S.fly ? 'fly' : moving || mode === 'roll' ? mode : 'idle'; me.anim.moving = moving;
  updateComp(dt, moving, st.speed * mountSpeed());
  let a = me.root.rotation.y, d = me.ry - a; d = Math.atan2(Math.sin(d), Math.cos(d)); me.root.rotation.y = a + d * Math.min(1, dt * 10);
  me.root.position.set(me.x, (S.fly ? Math.max(WG.height(me.x, me.z), WG.WATER + 0.5) : WG.height(me.x, me.z)) + (S.alt || 0) + saddle(), me.z); animHumanoid(me, dt);
  // coleta
  if (S.channel) { const p = (now() - S.channel.start) / (S.channel.end - S.channel.start); $('#cast').hidden = false; $('#cast i').style.width = Math.min(100, p * 100) + '%'; $('#cast span').textContent = 'Coletando…'; if (p >= 1) { const n = S.channel.node; S.channel = null; gather(n); } else if (Math.random() < 0.03) playAttack(me, 'melee'); }
  else $('#cast').hidden = true;
  // regeneração e buffs
  if (!S.dead) {
    const town = inSafe(me.x, me.z), out = Date.now() - S.lastCombat > 6000, bv = buffVals();
    S.hp = Math.min(st.maxHp, S.hp + st.maxHp * ((town ? 0.08 : out ? 0.02 : 0.004) + (bv.hot || 0)) * dt);
    S.mp = Math.min(st.maxMp, S.mp + st.maxMp * (town ? 0.06 : 0.012) * (1 + ((st.fx || {}).mpRegen || 0)) * dt);
  }
  if (destRing.visible) destRing.scale.setScalar(0.6 + Math.sin(now() / 200) * 0.15);
  const t = S.target && S.target.ref; if (t && !t.dead && (S.target.kind !== 'npc' || t.x)) { const p = S.target.kind === 'npc' ? t : S.target.kind === 'node' ? t : t; selRing.visible = true; selRing.position.set(p.x, WG.height(p.x, p.z) + 0.08, p.z); selRing.material.color.set(S.target.kind === 'mob' ? 0xff4040 : S.target.kind === 'player' ? 0x40a0ff : 0xffe36a); const sc = S.target.kind === 'mob' ? t.fam.scale * 1.2 : 1; selRing.scale.setScalar(sc); } else selRing.visible = false;
  // zona
  const rg = WG.region(me.x, me.z), zk = rg.town.id + (rg.safe ? 's' : '');
  const neonZ = WG.inNeon(me.x, me.z, 10), zk2 = neonZ ? 'neon' + (rg.hub ? 's' : '') : zk;
  if (zk2 !== S.zoneKey) { S.zoneKey = zk2;
    if (neonZ) { $('#zone').textContent = rg.hub ? 'Posto Neon — zona segura' : 'Era Neon • Distrito Ômega • Nv. 54–62'; S.skyTo = THEMES.neon; if (!S.neonSeen) { S.neonSeen = 1; addChat({ kind: 'sys', msg: '🌆 Você chegou à Era Neon: um distrito do futuro que atravessou uma fenda no tempo. Cuidado com as máquinas — e com o Mecha Ômega no reator.' }); } }
    else { $('#zone').textContent = rg.safe ? `${rg.town.name} — zona segura` : `Arredores de ${rg.town.name} • Nv. ${rg.town.min}–${rg.town.max}`; const th = THEMES[rg.town.theme]; S.skyTo = th; if (rg.safe) questEvent('reach', rg.town.id); } }
  portalTick();
}
async function gather(n) {
  const r = await safe(() => B.gather(n.id, me.x, me.z)); if (!r) return;
  S.inv[r.item] = (S.inv[r.item] || 0) + r.qty; S.c.profs.coleta = (S.c.profs.coleta || 0) + r.xp; S.dep[n.id] = Date.now() + (50 + 12 * n.grade) * 1000; refreshNode(n.id);
  floatText(n.x, WG.height(n.x, n.z) + 2.5, n.z, `+${r.qty} ${iname(r.item)}`, '#c5f5b0', 28); toast(`${icon(r.item)} +${r.qty} ${iname(r.item)} • +${r.xp} XP de Coleta`, 'ok');
  if (panelState.kind === 'bag') renderPanel();
}

// ---------- outros jogadores ----------
function onPos(p) {
  if (!p || !S.c || p.id === S.c.id) return;
  let o = S.others[p.id];
  const sig = [(p.cl || []).join('~'), p.ra, p.ge, p.h, p.hc, p.sk, p.w, p.a, p.k, p.f, p.g, p.n, JSON.stringify(p.lk || {}), JSON.stringify(p.ex || {}), p.en || 0].join('|');
  if (!o) { o = S.others[p.id] = { id: p.id, x: p.x, z: p.z, ry: p.r }; }
  if (o.sig !== sig) {
    if (o.model) scene.remove(o.model.root);
    o.model = buildHumanoid({ race: p.ra, gender: p.ge, hair: p.h, hair_color: p.hc, skin: p.sk, look: p.lk || undefined, weapon: p.w, armor: p.a, equip: p.ex || {}, enc: p.en || 0 });
    const l = makeLabel(flagOf(p.cl) + p.n, nameColor({ gm: p.g, karma: p.k, flag: p.f }), 30); l.position.y = 2.25 * (GD.RACES[p.ra]?.h || 1); o.model.root.add(l); { const cl2 = clanLabel(p.cl, GD.RACES[p.ra]?.h || 1); if (cl2) o.model.root.add(cl2); }
    const sub = makeLabel(`${GD.CLASSES[p.c]?.name || ''} Nv.${p.l}`, '#bcd', 20); sub.position.y = 2.0 * (GD.RACES[p.ra]?.h || 1); o.model.root.add(sub);
    o.model.root.traverse(x => x.userData.pick = { kind: 'player', ref: o }); scene.add(o.model.root); o.sig = sig;
  }
  Object.assign(o, { tx: p.x, tz: p.z, tr: p.r, st: p.st, n: p.n, k: p.k, f: p.f, l: p.l, seen: Date.now(), hpPct: p.hp });
  if (p.atk && o.model) playAttack(o.model, p.atk);
}
function updateOthers(dt) {
  for (const o of Object.values(S.others)) {
    if (Date.now() - o.seen > 15000) { if (o.model) scene.remove(o.model.root); delete S.others[o.id]; continue; }
    const k = Math.min(1, dt * 9); o.x += (o.tx - o.x) * k; o.z += (o.tz - o.z) * k; if (Math.hypot(o.tx - o.x, o.tz - o.z) > 40) { o.x = o.tx; o.z = o.tz; }
    o.model.root.position.set(o.x, WG.height(o.x, o.z), o.z); o.model.root.rotation.y = o.tr || 0; o.model.anim.state = o.st || 'idle'; animHumanoid(o.model, dt);
  }
}
let lastSent = { x: 0, z: 0, t: 0, st: '' };
function netTick() {
  if (!S.inGame) return; const t = Date.now(), st = me.anim.state;
  if (Math.hypot(me.x - lastSent.x, me.z - lastSent.z) > 0.05 || st !== lastSent.st || t - lastSent.t > 2000 || me.anim.atk >= 0) {
    const c = S.c; B.sendPos({ id: c.id, n: c.name, x: +me.x.toFixed(2), z: +me.z.toFixed(2), r: +me.root.rotation.y.toFixed(2), st, ra: c.race, ge: c.gender, h: c.hair, hc: c.hair_color, sk: c.skin, lk: c.look || null, c: c.class_id, l: c.level, cl: clanTag(),
      w: c.equipment.arma || null, a: c.equipment.armadura || null, ex: { elmo: c.equipment.elmo, luvas: c.equipment.luvas, botas: c.equipment.botas, escudo: c.equipment.escudo }, en: encOf(c), k: (c.karma || 0) > 0, f: S.flagUntil > t, g: !!c.is_gm, hp: Math.round(100 * S.hp / stats().maxHp), atk: me.anim.atk >= 0 ? me.anim.kind : null });
    lastSent = { x: me.x, z: me.z, t, st };
  }
}
function remoteFx(p) { if (!p || !me || Math.hypot(p.x - me.x, p.z - me.z) > 120 || p.k === 'melee') return; projectile(p.x, p.z, p.tx, p.tz, p.k, null, null); }
async function saveNow() { if (!S.inGame || S.saving) return; S.saving = true; try { await B.save(me.x, me.z, Math.max(0, S.hp), S.mp); } catch (_) {} S.saving = false; }
function onEvent(e) {
  if (e.kind === 'hit') { S.hp = Math.min(S.hp, e.data.hp); S.lastCombat = Date.now(); floatText(me.x, WG.height(me.x, me.z) + 2.4, me.z, '-' + e.data.dmg, '#ff5a5a'); if (!S.target) { const o = S.others[e.data.by_id]; if (o) S.target = { kind: 'player', ref: o }; } toast(`${e.data.by} está atacando você!`, 'err'); }
  if (e.kind === 'killed') { die(true, e.data.by); }
  if (e.kind === 'kick') { alert('Você foi desconectado por um GM.'); B.logout().then(() => location.reload()); }
  if (e.kind === 'tp') { teleport(+e.data.x, +e.data.z); toast('Um GM teleportou você', 'ok'); }
}

// ---------- chat ----------
function addChat(m) {
  const d = document.createElement('div');
  if (m.kind === 'anuncio') { d.className = 'an'; d.textContent = '📢 ' + m.name + ': ' + m.msg; }
  else if (m.kind === 'sistema' || m.kind === 'sys') { d.className = 'sys'; d.textContent = '• ' + m.msg; }
  else if (m.kind === 'q') { d.className = 'q'; d.textContent = '✦ ' + m.msg; }
  else { d.className = m.is_gm ? 'gm' : ''; d.innerHTML = `<b>${m.is_gm ? '[GM] ' : ''}${esc(m.name)}:</b> ${esc(m.msg)}`; }
  const log = $('#chat-log'); log.appendChild(d); while (log.children.length > 80) log.firstChild.remove(); log.scrollTop = log.scrollHeight;
}
function onChat(m) { addChat(m); if (m.kind === 'anuncio') { const a = $('#announce'); a.textContent = '📢 ' + m.msg; a.hidden = false; clearTimeout(a._t); a._t = setTimeout(() => a.hidden = true, 8000); } }
$('#chat-form').addEventListener('submit', async e => { e.preventDefault(); const v = $('#chat-in').value.trim(); $('#chat-in').value = ''; $('#chat-in').blur(); if (!v) return; if (v.startsWith('/')) return command(v); await safe(() => B.chat(v)); });
async function command(line) {
  const [c, ...a] = line.slice(1).split(/\s+/), cmd = c.toLowerCase(), gm = S.c.is_gm, say = r => r && addChat({ kind: 'sys', msg: r });
  const G = async (k, args) => { if (!gm) return toast('Apenas GM', 'err'); say(await safe(() => B.gm(k, args))); await refresh(); };
  switch (cmd) {
    case 'ajuda': addChat({ kind: 'sys', msg: 'Comandos: /onde, /online' + (gm ? ' | GM: /give item qtd [jogador], /aurum qtd [jogador], /nivel n [jogador], /prof coleta|refino|forja n, /tp x z, /ir cidade, /puxar jogador, /kick j, /ban j, /desban j, /karma n [j], /anuncio texto, /reset, /vel, /deus, /spawn chefe|familia nivel, /matar (alvo), /matartodos [raio] (com recompensa), /limpar [raio] (remove sem recompensa)' : '') }); break;
    case 'onde': say(`Posição ${Math.round(me.x)}, ${Math.round(me.z)} — ${$('#zone').textContent}`); break;
    case 'online': say('Online: ' + Object.values(S.presence).map(p => p[0]?.name).join(', ')); break;
    case 'give': return G('give', { item: a[0], qtd: +a[1] || 1, alvo: a[2] });
    case 'aurum': return G('aurum', { qtd: +a[0] || 0, alvo: a[1] });
    case 'nivel': await G('nivel', { nivel: +a[0], alvo: a[1] }); if (!a[1]) { S.hp = stats().maxHp; buildBar(); } return;
    case 'prof': return G('prof', { prof: a[0], nivel: +a[1], alvo: a[2] });
    case 'karma': return G('karma', { qtd: +a[0], alvo: a[1] });
    case 'kick': case 'ban': case 'desban': case 'info': return G(cmd, { alvo: a[0] });
    case 'puxar': return G('puxar', { alvo: a[0], x: me.x + 2, z: me.z });
    case 'anuncio': return G('anuncio', { msg: a.join(' ') });
    case 'reset': await G('reset_nos', {}); S.dep = {}; nodeMeshes.forEach((m, id) => refreshNode(id)); return;
    case 'tp': if (!gm) return; teleport(+a[0], +a[1]); return;
    case 'ir': { if (!gm) return; const t = GD.TOWNS.find(t => t.id.startsWith((a[0] || '').toLowerCase()) || t.name.toLowerCase().includes((a[0] || '').toLowerCase())); if (t) teleport(t.x, t.z + 25); else { const L = GD.LANDMARKS.find(L => L.id.startsWith((a[0] || '').toLowerCase()) || L.name.toLowerCase().includes((a[0] || '').toLowerCase())); if (L) teleport(L.x, L.z + 40); else toast('Destino não encontrado', 'err'); } return; }
    case 'vel': if (gm) { S.buffs.gmspeed = S.buffs.gmspeed ? (delete S.buffs.gmspeed, undefined) : { until: 9e15, vals: { speed: 2 } }; if (!S.buffs.gmspeed) delete S.buffs.gmspeed; toast('Velocidade GM ' + (S.buffs.gmspeed ? 'ligada' : 'desligada'), 'ok'); } return;
    case 'deus': if (gm) { S.god = !S.god; toast('Invencível ' + (S.god ? 'ligado' : 'desligado'), 'ok'); } return;
    case 'matar': { if (!gm) return; const t = S.target; if (!t || t.kind !== 'mob' || t.ref.dead) return toast('Selecione um monstro (clique nele) e use /matar', 'err'); t.ref.returning = false; S.gmKill = true; hurtMob(t.ref, t.ref.hp + 1, false); S.gmKill = false; toast('Monstro eliminado', 'ok'); return; }
    case 'matartodos': case 'limpar': { if (!gm) return; const r = clamp(+a[0] || 40, 5, 300); let n = 0; S.mobs.filter(m => !m.dead && Math.hypot(m.x - me.x, m.z - me.z) <= r).forEach(m => { m.returning = false; S.gmKill = true; if (cmd === 'limpar') { m.dead = true; scene.remove(m.model.root); S.mobs = S.mobs.filter(x => x !== m); if (S.target && S.target.ref === m) S.target = null; } else hurtMob(m, m.hp + 1, false); S.gmKill = false; n++; }); toast(n + (cmd === 'limpar' ? ' monstro(s) removido(s)' : ' monstro(s) eliminado(s)') + ' num raio de ' + r + ' m', 'ok'); return; }
    case 'spawn': { if (!gm) return; const f = FAM[a[0]] || Object.values(FAM).find(f => f.name.toLowerCase().includes((a[0] || '').toLowerCase())); if (!f) return toast('Família desconhecida', 'err'); spawnMob(f, clamp(+a[1] || S.c.level, 1, 80), me.x + 6, me.z + 6); return; }
    default: toast('Comando desconhecido — /ajuda', 'err');
  }
}

// ---------- missões ----------
function qKey() { return 'rda3d_q_' + S.c.id; }
function encTargets(it) { const eq = S.c.equipment || {}; return Object.entries(eq).filter(([sl, iid]) => IT(iid) && IT(iid).grade === it.grade && (it.enc === 'arma' ? sl === 'arma' : sl !== 'arma')); }
async function doEnchant(slot) {
  const iid = S.c.equipment[slot], n = (S.c.enchant || {})[iid] || 0, ch = GD.enchantChance(n);
  if (n >= GD.ENCHANT_SAFE && !confirm(`Encantar ${IT(iid).name} de +${n} para +${n + 1}?\nChance de sucesso: ${Math.round(ch * 100)}%. Se falhar, o item volta para +0.`)) return;
  const r = await safe(() => B.enchant(slot)); if (!r) return;
  S.c.enchant = { ...(S.c.enchant || {}), [iid]: r.level }; await refresh();
  if (r.ok) { const ET = GD.ENC_TIER(r.level); toast(`✨ Sucesso! ${IT(iid).name} agora é +${r.level}${ET ? ' — brilho ' + ET.name : ''}`, 'ok'); fxRing(me.x, me.z, ET ? ET.c : '#3a8aff'); sfx('enchant'); if (ET) { beam(me.x, WG.height(me.x, me.z), me.z, new THREE.Color(ET.c).getHex(), 1.2 + ET.k * 0.3); postFlash(0.3 + ET.k * 0.15); } } else { sfx('fail'); shake(0.3); } if (!r.ok) toast(`💥 O encantamento falhou. ${IT(iid).name} voltou para +0`, 'err');
  if (slot === 'arma') { me.enc = encOf(S.c); setGear(me, S.c.equipment.arma, S.c.equipment.armadura, S.c.equipment); }
  renderPanel(); buildBar();
}
function fxRing(x, z, col) { const r = new THREE.Mesh(new THREE.TorusGeometry(0.8, 0.08, 8, 32), new THREE.MeshBasicMaterial({ color: col, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })); r.rotation.x = -Math.PI / 2; r.position.set(x, WG.height(x, z) + 0.2, z); scene.add(r); fx.push({ obj: r, t: 0, dur: 1, up: (o, k) => { o.scale.setScalar(1 + k * 2.5); o.position.y += 0.03; o.material.opacity = 1 - k; } }); }
function encOf(c) { return (c.enchant || {})[c.equipment?.arma] || 0; }
const todayStr = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Fortaleza' }).format(new Date());
function qDone(id) { const Q = QD.QUESTS[id], v = S.c.quests?.[id]; return Q?.kind === 'diaria' ? v === todayStr() : !!v; }
function loadQuests() { try { S.q = JSON.parse(localStorage.getItem(qKey())) || { active: [], prog: {} }; } catch (_) { S.q = { active: [], prog: {} }; } S.q.active = S.q.active.filter(id => QD.QUESTS[id] && !qDone(id)); }
function saveQuests() { localStorage.setItem(qKey(), JSON.stringify(S.q)); renderTracker(); }
function questReady(Q) { const g = Q.goal, p = S.q.prog[Q.id] || 0; if (g.type === 'kill') return p >= g.n; if (g.type === 'boss' || g.type === 'reach') return p >= 1; if (g.type === 'turnin') return Object.entries(g.items).every(([k, v]) => (S.inv[k] || 0) >= v); return false; }
function questEvent(type, key) {
  let ch = false;
  for (const id of S.q.active) { const Q = QD.QUESTS[id], g = Q.goal;
    if (type === 'kill' && (g.type === 'kill' && g.fam === key || g.type === 'boss' && g.fam === key)) { const n = (S.q.prog[id] || 0) + 1; S.q.prog[id] = n; ch = true; if (questReady(Q)) { addChat({ kind: 'q', msg: `Missão "${Q.title}" pronta! Volte a um Arauto do Eclipse.` }); toast(`📜 ${Q.title}: objetivo concluído!`, 'ok'); } }
    if (type === 'reach' && g.type === 'reach' && g.town === key && !S.q.prog[id]) { S.q.prog[id] = 1; ch = true; addChat({ kind: 'q', msg: `Missão "${Q.title}" pronta! Fale com o Arauto daqui.` }); } }
  if (ch) saveQuests();
}
const qTag = (Q) => Q.main ? '★ ' : Q.kind === 'diaria' ? '🔁 ' : Q.kind === 'lenda' ? '👑 ' : '';
$('#quest-track').addEventListener('click', e => { const b = e.target.closest('[data-guide]'); if (!b) return; const id = b.dataset.guide; if (S.guide?.id === id) stopGuide('Guia automático desligado'); else startGuide(id); });
function renderTracker() {
  const el = $('#quest-track'); if (!S.q.active.length) { el.hidden = true; return; } el.hidden = false;
  el.innerHTML = S.q.active.map(id => { const Q = QD.QUESTS[id], g = Q.goal, p = S.q.prog[id] || 0; const txt = g.type === 'kill' ? `${FAM[g.fam].name}: ${Math.min(p, g.n)}/${g.n}` : g.type === 'boss' ? `Derrotar ${FAM[g.fam].name}${p ? ' ✔' : ''}` : g.type === 'reach' ? `Chegar a ${GD.TOWNS.find(t => t.id === g.town).name}${p ? ' ✔' : ''}` : 'Entregar: ' + Object.entries(g.items).map(([k, v]) => `${iname(k)} ${Math.min(S.inv[k] || 0, v)}/${v}`).join(', ');
    const on = S.guide?.id === id;
    return `<div style="margin-bottom:6px"><button class="gbtn${on ? ' on' : ''}" data-guide="${id}" title="${on ? 'Parar guia automático' : 'Guia automático'}">${on ? '⏹' : '🧭'}</button><b>${qTag(Q)}${esc(Q.title)}</b><div class="small">${esc(txt)}${questReady(Q) ? ' — <span style="color:#9be37a">pronta</span>' : ''}${on && S.guide.plan ? `<br><span style="color:#8ad0ff">🧭 ${esc(S.guide.plan.label || '')}</span>` : ''}</div></div>`; }).join('') + '<div class="small" style="opacity:.7">🧭 = guia automático (WASD cancela)</div>';
}

// ---------- guia automático ----------
const FAM_BAND = {}; GD.MOBS.forEach((fs, g) => fs.forEach(f => FAM_BAND[f.id] = g));
function startGuide(id) { if (!QD.QUESTS[id]) return; S.guide = { id, t: 0, last: { x: me.x, z: me.z }, lastT: now(), detour: null, tp: 0 }; toast('🧭 Guia automático: ' + QD.QUESTS[id].title + ' — WASD cancela', 'ok'); renderTracker(); }
function stopGuide(msg) { if (!S.guide) return; S.guide = null; S.dest = null; S.autoAtk = false; destRing.visible = false; if (msg) toast(msg); renderTracker(); }
function huntPlan(fam) {
  const b = FAM_BAND[fam] ?? GD.gradeForLevel(S.c.level), rg = WG.region(me.x, me.z);
  if (!rg.safe && rg.grade === b) return { x: me.x, z: me.z, here: true, hunt: fam, area: 90, label: 'Caçando ' + FAM[fam].name };
  const t = GD.CORE_TOWNS[b], sp = t.spotsPos[0]; return { x: sp.x, z: sp.z, hunt: fam, area: 70, label: 'Indo caçar ' + FAM[fam].name + ' em ' + sp.name };
}
function guidePlan(Q) {
  const g = Q.goal;
  if (questReady(Q)) { const n = npcs.filter(n => n.type === 'arauto').sort((a, b) => Math.hypot(a.x - me.x, a.z - me.z) - Math.hypot(b.x - me.x, b.z - me.z))[0]; return { x: n.x, z: n.z, npc: n, label: 'Entregar ao Arauto em ' + n.town.name }; }
  if (g.type === 'reach') { const t = GD.TOWNS.find(t => t.id === g.town); return { x: t.x, z: t.z + 22, arrive: 12, label: 'Viajando para ' + t.name }; }
  if (g.type === 'boss') { if (g.lm) { const L = GD.LANDMARKS.find(L => L.id === g.lm); return { x: L.x, z: L.z + 12, hunt: g.fam, area: 70, label: 'Rumo a ' + L.name }; } const t = GD.TOWNS.find(t => t.id === g.spot[0]), sp = t.spotsPos[g.spot[1]]; return { x: sp.x, z: sp.z, hunt: g.fam, area: 60, label: 'Rumo a ' + sp.name }; }
  if (g.type === 'kill') return huntPlan(g.fam);
  if (g.type === 'turnin') {
    const miss = Object.entries(g.items).find(([k, v]) => (S.inv[k] || 0) < v); if (!miss) return { x: me.x, z: me.z, label: 'Pronta' };
    const it = IT(miss[0]); if (it.type === 'trophy') { const p = huntPlan(it.fam); p.label += ` (${it.name})`; return p; }
    if (it.type === 'raw') { const res = miss[0].replace(/_[a-z]+$/, ''), t = GD.CORE_TOWNS[it.grade], sp = t.spotsPos[0], rg = WG.region(me.x, me.z); const here = !rg.safe && rg.grade === it.grade; return { x: here ? me.x : sp.x, z: here ? me.z : sp.z, here, gather: { type: res, grade: it.grade }, area: 90, label: 'Coletando ' + it.name }; }
    const t = WG.nearestTown(me.x, me.z).town; return { x: t.x, z: t.z + 18, arrive: 10, info: `Produza ${it.name} no Ferreiro ou na Refinaria (precisa de ${miss[1]}).`, label: 'Produzir ' + it.name };
  }
  return { x: me.x, z: me.z, label: '' };
}
function guideMove(x, z) {
  const G = S.guide, d = Math.hypot(x - me.x, z - me.z), t = now();
  if (G.detour && t < G.detour.until) { S.dest = { x: G.detour.x, z: G.detour.z }; return; }
  if (t - G.lastT > 2000) { const moved = Math.hypot(me.x - G.last.x, me.z - G.last.z); G.last = { x: me.x, z: me.z }; G.lastT = t;
    if (moved < 1.5 && d > 6) { const a = Math.atan2(x - me.x, z - me.z) + (Math.random() < 0.5 ? 1 : -1) * (0.9 + Math.random() * 0.9); G.detour = { x: me.x + Math.sin(a) * 22, z: me.z + Math.cos(a) * 22, until: t + 2500 }; S.dest = { x: G.detour.x, z: G.detour.z }; return; } }
  // atravessa as muralhas pelos portões (estradas)
  const tw = WG.nearestTown(me.x, me.z).town, ctx = townCtx(tw), dm = Math.hypot(me.x - tw.x, me.z - tw.z), dt2 = Math.hypot(x - tw.x, z - tw.z);
  if (ctx.roadAngles.length && ((dm < 100 && dt2 > 100) || (dm > 96 && dm < 140 && dt2 < 96))) {
    const ref = dm < 100 ? Math.atan2(z - tw.z, x - tw.x) : Math.atan2(me.z - tw.z, me.x - tw.x);
    const a = ctx.roadAngles.reduce((b, r) => Math.abs(Math.atan2(Math.sin(r - ref), Math.cos(r - ref))) < Math.abs(Math.atan2(Math.sin(b - ref), Math.cos(b - ref))) ? r : b);
    const inG = { x: tw.x + Math.cos(a) * 80, z: tw.z + Math.sin(a) * 80 }, outG = { x: tw.x + Math.cos(a) * 112, z: tw.z + Math.sin(a) * 112 };
    const first = dm < 100 ? (Math.hypot(me.x - inG.x, me.z - inG.z) > 4 && Math.hypot(me.x - tw.x, me.z - tw.z) < 78 ? inG : outG) : (Math.hypot(me.x - outG.x, me.z - outG.z) > 4 && dm > 100 ? outG : inG);
    S.dest = first; return;
  }
  const k = Math.min(1, 45 / Math.max(d, 1)); S.dest = { x: me.x + (x - me.x) * k, z: me.z + (z - me.z) * k };
}
async function guideTeleport(P) {
  const G = S.guide; if (G.tp > now() || !inSafe(me.x, me.z)) return false; G.tp = now() + 15000;
  const d0 = Math.hypot(P.x - me.x, P.z - me.z); const best = TELEPORTS.map(t => ({ t, d: Math.hypot(P.x - t.x, P.z - t.z) })).sort((a, b) => a.d - b.d)[0];
  if (!best || best.d > d0 - 300 || (!S.c.is_gm && S.c.aurum < best.t.cost)) return false;
  const r = await safe(() => B.teleport(best.t.id)); if (!r) return false; S.c.aurum -= r.cost; toast(`🧭 Teleporte para ${r.name}${r.cost ? ' (' + r.cost + ' aurum)' : ''}`, 'ok'); teleport(r.x, r.z); return true;
}
function guideTick() {
  const G = S.guide; if (!G || S.dead || !me) return; const Q = QD.QUESTS[G.id];
  if (!Q || !S.q.active.includes(G.id)) return stopGuide();
  const P = guidePlan(Q), prevLabel = G.plan?.label; G.plan = P; if (prevLabel !== P.label) renderTracker();
  const st = stats(), t = now();
  if (S.hp < st.maxHp * 0.4 && (S.inv.pocao_hp || S.inv.pocao_hp2) && t > (G.potT || 0)) { G.potT = t + 2500; usePotion('hp'); }
  if (S.mp < st.maxMp * 0.2 && S.inv.pocao_mp && t > (G.mpT || 0)) { G.mpT = t + 4000; usePotion('mp'); }
  // defesa: se algo me ataca, luta
  const att = S.mobs.find(m => !m.dead && m.aggro && !m.returning && Math.hypot(m.x - me.x, m.z - me.z) < 7);
  if (att && (!S.target || S.target.ref !== att || !S.autoAtk) && !inSafe(me.x, me.z)) { S.target = { kind: 'mob', ref: att }; S.autoAtk = true; S.dest = null; return; }
  if (S.autoAtk && S.target?.kind === 'mob' && !S.target.ref.dead) { guideSkill(st); return; }
  const dist = Math.hypot(P.x - me.x, P.z - me.z);
  if (P.npc) { if (dist < 4.5) { stopGuide(); faceTo(P.npc.x, P.npc.z); openNpc(P.npc); } else { if (dist > 450) guideTeleport(P); S.npcAt = P.npc; guideMove(P.x, P.z); } return; }
  if (P.hunt || P.gather) {
    if (P.here || dist < P.area) {
      if (P.hunt) { const m = S.mobs.filter(m => !m.dead && !m.returning && m.fam.id === P.hunt && Math.hypot(m.x - me.x, m.z - me.z) < 75).sort((a, b) => Math.hypot(a.x - me.x, a.z - me.z) - Math.hypot(b.x - me.x, b.z - me.z))[0];
        if (m) { S.target = { kind: 'mob', ref: m }; S.autoAtk = true; S.dest = null; return; } }
      if (P.gather) { if (S.channel || S.gatherAt) return; let best = null, bd = 1e9; for (const [, mesh] of nodeMeshes) { const n = mesh.userData.ref; if (n.type !== P.gather.type || n.grade !== P.gather.grade || (S.dep[n.id] || 0) > Date.now()) continue; const d = Math.hypot(n.x - me.x, n.z - me.z); if (d < bd) { bd = d; best = n; } }
        if (best && bd < 90) { S.gatherAt = best; S.target = { kind: 'node', ref: best }; S.dest = { x: best.x, z: best.z }; return; } }
      if (!G.roam || Math.hypot(G.roam.x - me.x, G.roam.z - me.z) < 3 || t > G.roam.until) { let x, z, k = 0; do { const a = Math.random() * 6.283, r = 15 + Math.random() * 40; x = (P.here ? me.x : P.x) + Math.cos(a) * r; z = (P.here ? me.z : P.z) + Math.sin(a) * r; } while ((blocked(x, z) || inSafe(x, z)) && ++k < 12); G.roam = { x, z, until: t + 8000 }; }
      S.dest = { x: G.roam.x, z: G.roam.z }; return;
    }
  }
  if (P.info && dist < (P.arrive || 10)) { addChat({ kind: 'q', msg: '🧭 ' + P.info }); stopGuide(); return; }
  if (P.arrive && dist < P.arrive) { S.dest = null; return; }
  if (dist > 450) guideTeleport(P);
  guideMove(P.x, P.z);
}
function guideSkill(st) {
  const t = now(); if (t < (S.guide.skT || 0)) return; S.guide.skT = t + 900;
  const p = tgtPos(S.target), d = Math.hypot(p.x - me.x, p.z - me.z); if (d > st.range + 1.2) return;
  const sk = st.arch.skills; for (const e of (S.bar || [])) { if (!e || e.t !== 's') continue; const i = skillIndex(e.id), k = sk[i]; if (i < 0 || !k || S.c.level < k.lvl || (S.cds[i] || 0) > t || S.mp < k.mp + st.maxMp * 0.15) continue; if (!['hit', 'aoe', 'debuff'].includes(k.type)) continue; castSkill(i); return; }
}

// ---------- painéis ----------
let panelState = {};
function openPanel(kind, o = {}) { panelState = { kind, ...o }; $('#panel').hidden = false; renderPanel(); }
function closePanel() { $('#panel').hidden = true; panelState = {}; }
$('#p-close').onclick = closePanel;
document.querySelectorAll('#menu button').forEach(b => b.onclick = () => { if ($('#menu').dataset.dragged && Date.now() - $('#menu').dataset.dragged < 250) return; b.dataset.p === 'equip' ? toggleEquip(EQX) : panelState.kind === b.dataset.p ? closePanel() : openPanel(b.dataset.p); });
function npcSay(n) { if (!n.model) return; n.greet = Date.now(); const o = n.model.o || {}; say(n.model.root, npcLine(n.type, S.c.name), { race: o.race, gender: o.gender, h: 2.5 * (GD.RACES[o.race]?.h || 1) }); }
// ----- habitantes: aldeões que passeiam, conversam e vivem nas cidades -----
const VIL = { list: [], town: null, max: 8 };
const VIL_LINES = ['Bom dia, viajante!', 'Dizem que há uma tumba assombrada ao sul…', 'O pão está caro esta semana.', 'Cuidado com os lobos depois das muralhas.', 'Você viu o Arauto? Ele procurava heróis.', 'Meu filho quer ser cavaleiro como você!',
  'A colheita foi boa este ano.', 'Ouvi um rugido vindo das montanhas.', 'Que armadura bonita! Foi o ferreiro daqui?', 'Os portais brilham mais à noite.', 'Hoje tem festa na praça!', 'Já pensou em comprar um cavalo? Viaja-se bem mais rápido.'];
function updateVillagers(dt) {
  const nt = WG.nearestTown(me.x, me.z), T = nt.town, near = nt.dist < 170 && PERF.cur !== 'baixa';
  if (!near || VIL.town !== T.id) { VIL.list.forEach(v => scene.remove(v.m.root)); VIL.list = []; VIL.town = near ? T.id : null; if (!near) return; }
  const max = PERF.cur === 'alta' ? 12 : 7;
  if (VIL.list.length < max && Math.random() < 0.25) {
    const a = Math.random() * 6.28, r = 12 + Math.random() * 40, x = T.x + Math.cos(a) * r, z = T.z + Math.sin(a) * r; if (blocked(x, z)) return;
    const races = [T.race, T.race, 'humano', 'elfo', 'anao', 'halfling', 'orc'], race = races[Math.floor(Math.random() * races.length)], g = Math.random() < 0.5 ? 'f' : 'm';
    const m = buildHumanoid({ npc: true, race: GD.RACES[race] ? race : 'humano', gender: g, hair: Math.floor(Math.random() * 6), hair_color: Math.floor(Math.random() * 8), skin: Math.floor(Math.random() * 3), look: { eyes: 0, face: Math.floor(Math.random() * 4), beard: g === 'm' && Math.random() < 0.4 ? 1 + (Math.random() < 0.5 ? 1 : 0) : 0 }, armor: Math.random() < 0.3 ? 'leve_ng' : null, weapon: null, idle: ['Idle_Loop', 'Idle_Talking_Loop', 'Idle_FoldArms_Loop'][Math.floor(Math.random() * 3)] });
    m.root.position.set(x, WG.height(x, z), z); scene.add(m.root); VIL.list.push({ m, x, z, ry: Math.random() * 6, tx: x, tz: z, wait: 0, T, lab: null });
  }
  const t = performance.now();
  for (const v of VIL.list) { const dx = v.tx - v.x, dz = v.tz - v.z, d = Math.hypot(dx, dz);
    if (d < 0.5) { if (!v.wait) v.wait = t + 2000 + Math.random() * 7000; if (t > v.wait) { v.wait = 0; const a = Math.random() * 6.28, r = 10 + Math.random() * 45; v.tx = T.x + Math.cos(a) * r; v.tz = T.z + Math.sin(a) * r; } v.m.anim.state = 'idle'; }
    else { const sp = 1.4 * dt, nx = v.x + dx / d * sp, nz = v.z + dz / d * sp; if (!blocked(nx, nz)) { v.x = nx; v.z = nz; } else { v.tx = v.x; v.tz = v.z; } v.ry = Math.atan2(dx, dz); v.m.anim.state = 'run'; v.m.anim.walk = true; }
    let a = v.m.root.rotation.y, df = v.ry - a; df = Math.atan2(Math.sin(df), Math.cos(df)); v.m.root.rotation.y = a + df * Math.min(1, dt * 5);
    v.m.root.position.set(v.x, WG.height(v.x, v.z), v.z); if (Math.hypot(v.x - me.x, v.z - me.z) < 70) animHumanoid(v.m, dt);
    if (Math.hypot(v.x - me.x, v.z - me.z) < 5 && t - (v.said || 0) > 60000 && Math.random() < 0.01) { v.said = t; const o = v.m.o || {}; say(v.m.root, VIL_LINES[Math.floor(Math.random() * VIL_LINES.length)], { race: o.race, gender: o.gender, h: 2.4 }); }
  }
}
function greetNpcs() { if (!me || S.dead) return; const t = Date.now(); for (const n of npcs) { if (!n.model || !n.type) continue; const d = Math.hypot(n.x - me.x, n.z - me.z); if (d < 7 && t - (n.greet || 0) > 90000) { npcSay(n); break; } } }
function openNpc(n) {
  if (Date.now() - (n.greet || 0) > 8000) npcSay(n);
  if (n.type === 'guarda') return;
  const map = { portal: 'teleport', classe: 'classe', ferreiro: 'craft', refino: 'craft', mercador: 'shop', leilao: 'market', arauto: 'arauto', senescal: 'clan', trono: 'clan' }; if (map[n.type] === 'clan') { openPanel('clan', { tab: 'guerra', castle: n.castle }); return; }
  openPanel(map[n.type], { npc: n, station: n.type === 'ferreiro' ? 'forja' : n.type === 'refino' ? 'refinaria' : null, tab: 'buy' });
}
const nearNpc = (type) => S.c.is_gm || npcs.some(n => n.type === type && Math.hypot(n.x - me.x, n.z - me.z) < 8);
function slot(id, q, extra = '') { const it = IT(id); return `<div class="slot" data-id="${id}" ${extra} style="border-color:${gcol(it.grade)}88"><span class="g" style="color:${gcol(it.grade)}">${GD.GRADES[it.grade].id}</span>${q != null ? `<span class="q">${q}</span>` : ''}<div class="ic">${icImg(it)}</div><div class="nm">${esc(it.name)}</div></div>`; }
function icImg(it, big) { const u = icon3d(it); return u ? `<img src="${u}" class="ic3d${big ? ' big' : ''}" alt="">` : it.icon; }
onIconsReady(() => { if (panelState.kind && !document.activeElement?.matches('input')) renderPanel(); });
function itemDesc(id) {
  const it = IT(id), s = it.stats || {}, p = [];
  if (s.patk) p.push(`Ataque Físico +${s.patk}`); if (s.matk) p.push(`Ataque Mágico +${s.matk}`); if (s.pdef) p.push(`Def. Física +${Math.round(s.pdef)}`); if (s.mdef) p.push(`Def. Mágica +${Math.round(s.mdef)}`);
  if (s.hp && !s.hpPct) p.push(`Vida +${Math.round(s.hp)}`); if (s.mp) p.push(`Mana +${Math.round(s.mp)}`); if (s.spd) p.push(`Velocidade +${s.spd * 100}%`); if (s.matkPct) p.push(`Ataque Mágico +${s.matkPct * 100}%`);
  if (s.hpPct) p.push(`Recupera ${s.hpPct * 100}% da vida`); if (s.mpPct) p.push(`Recupera ${s.mpPct * 100}% da mana`);
  if (it.slot) p.push(`Requer nível ${GD.GRADES[it.grade].lvl}`); if (it.type === 'tool') p.push(`Permite coletar recursos até grau ${GD.GRADES[Math.min(5, it.grade + 1)].id}`);
  if (it.type === 'enchant') p.push(`Encanta ${it.enc === 'arma' ? 'a arma' : 'uma peça de armadura'} de ${GD.GRADES[it.grade].name}: +5%/+4% por nível • seguro até +${GD.ENCHANT_SAFE}, máximo +${GD.ENCHANT_MAX}`); if (it.type === 'trophy') p.push('Troféu de caça: entregue em missões ou venda ao Mercador');
  if (it.slot && (S.c.enchant || {})[id]) p.push(`Encantado +${S.c.enchant[id]}`);
  if (it.slot === 'arma') GD.weaponSA(id, (S.c.enchant || {})[id]).forEach(e => p.push(`${e.icon} ${e.name}: ${e.desc}`));
  if (it.slot && ['armadura', 'elmo', 'luvas', 'botas'].includes(it.slot) && it.grade) p.push(`Conjunto ${it.kind}: 2 peças e 4 peças do mesmo grau ativam bônus`);
  if (it.comp) { const c = it.comp; p.push(it.type === 'mount' ? `Montaria: velocidade x${c.speed}${c.fly ? ' • VOA (V)' : ''} • R monta/desmonta` : it.type === 'pet' ? `Pet: segue e ajuda no combate${c.flyer ? ' • voa' : ''}` : 'Asas: permitem voar (V) • Espaço sobe, X desce'); if (c.fx) p.push(Object.entries(c.fx).map(([k, v]) => `+${Math.round(v * 100)}% ${({ crit: 'crítico', hpPct: 'vida', speed: 'velocidade', mpRegen: 'regeneração de mana', lifesteal: 'roubo de vida', atkspd: 'vel. de ataque', matkPct: 'ataque mágico', pdefPct: 'defesa física', mpCost: 'economia de mana' })[k] || k}`).join(', ')); p.push(`Requer nível ${c.lvl}`); }
  if (it.type === 'scroll') p.push('Teleporta para a cidade mais próxima'); if (it.type === 'raw') p.push('Refine no Refinador'); if (it.type === 'refined') p.push('Material de forja');
  return p.join(' • ');
}
function renderPanel() {
  const k = panelState.kind; if (!k) return; const body = $('#p-body'); body.onclick = null;
  const T = { clan: 'Clã / Legião', codex: 'Compêndio de Valtheria', char: 'Personagem', bag: 'Inventário', skills: 'Habilidades', quests: 'Diário de Missões', map: 'Mapa do Reino', lore: 'Crônicas de Valtheria', gm: 'Painel do GM', sys: 'Sistema', teleport: 'Guardião do Portal', classe: 'Mestre de Classes', craft: panelState.station === 'forja' ? 'Ferreiro' : 'Refinador e Alquimista', shop: 'Mercador', market: 'Casa de Leilões', arauto: 'Arauto do Eclipse' };
  { const G = [['char', 'skills', 'quests'], ['bag', 'codex'], ['map', 'lore']].find(g => g.includes(k)), ic = { char: '🧝 Personagem', skills: '📘 Habilidades', quests: '📜 Missões', bag: '🎒 Bolsa', codex: '📚 Compêndio', map: '🗺️ Mapa', lore: '📖 História' };
    let tb = $('#p-tabs'); if (!tb) { tb = document.createElement('div'); tb.id = 'p-tabs'; body.parentNode.insertBefore(tb, body); tb.onclick = e => { const b = e.target.closest('[data-tab]'); if (b) b.dataset.tab === 'equip' ? toggleEquip(EQX) : openPanel(b.dataset.tab); }; }
    tb.hidden = !G; if (G) tb.innerHTML = G.map(t => `<button data-tab="${t}" class="${t === k ? 'on' : ''}">${ic[t]}</button>`).join('') + (G[0] === 'char' || G[0] === 'bag' ? '<button data-tab="equip">🛡️ Equipamento (U)</button>' : ''); }
  $('#p-title').textContent = T[k] || k; body.innerHTML = '';
  ({ clan: pClan, codex: pCodex, char: pChar, bag: pBag, skills: pSkills, quests: pQuests, map: pMap, lore: pLore, gm: pGm, sys: pSys, teleport: pTeleport, classe: pClasse, craft: pCraft, shop: pShop, market: pMarket, arauto: pArauto })[k](body);
  numberPanel();
}
// painéis de NPC: as 9 primeiras ações ganham número e respondem às teclas 1 a 9
const NPC_PANELS = ['teleport', 'classe', 'craft', 'shop', 'market', 'arauto'];
function numberPanel() { document.body.classList.toggle('npc-open', NPC_PANELS.includes(panelState.kind)); if (!NPC_PANELS.includes(panelState.kind)) return; let n = 0;
  $('#p-body').querySelectorAll('button.btn:not(.alt), button[data-tp], button[data-buy], button[data-craft], [data-act]').forEach(b => { if (n >= 9 || b.offsetParent === null || b.querySelector('.nk')) return; n++; b.dataset.num = n; b.insertAdjacentHTML('afterbegin', `<span class="nk">${n}</span>`); }); }
function NPC_KEYS(key) { if (!NPC_PANELS.includes(panelState.kind) || !/^[1-9]$/.test(key)) return false; const b = $('#p-body').querySelector(`[data-num="${key}"]`); if (b) b.click(); return !!b; }
// ---------- painel do clã ----------
function pClan(b) {
  const ci = S.clanInfo; if (!ci) { b.innerHTML = '<div class="small">Carregando…</div>'; loadClan(); return; }
  const k = ci.clan, tab = panelState.tab || 'geral', C = GD.CLAN, fmt = n => Number(n || 0).toLocaleString('pt-BR'), inm = id => (IT(id) ? IT(id).icon + ' ' + IT(id).name : id);
  const tabs = `<div class="ctabs">${[['geral', '🏰 Visão geral'], ['membros', '👥 Membros'], ['evolucao', '📈 Evolução'], ['guerra', '⚔️ Guerra e castelos']].map(([t, n]) => `<button data-ct="${t}" class="${t === tab ? 'on' : ''}">${n}</button>`).join('')}</div>`;
  const castles = () => { const near = GD.LANDMARKS.find(L => GD.CASTLES.includes(L.id) && Math.hypot(L.x - me.x, L.z - me.z) < 30), nx = ci.siege && ci.siege.next ? new Date(ci.siege.next) : null;
    return `<div class="cbox ${ci.siege?.open ? 'war' : ''}"><b>${ci.siege?.open ? '⚔️ A GUERRA DE CASTELOS ESTÁ ABERTA!' : '🕊️ Tempo de paz'}</b><div class="small">A guerra acontece no primeiro fim de semana de cada mês (sábado e domingo), das 16h às 22h.${nx ? ' Próxima: <b>' + nx.toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long' }) + ' às 16h</b>.' : ''} Durante a guerra os portões ficam abertos: o líder ou vice de um clã nível 4+ que chegar ao trono toma o castelo.</div></div>` +
      ci.castles.map(ca => `<div class="row"><div class="grow"><b>🏰 ${esc(ca.name)}</b><div class="small">${ca.owner ? `Domínio de <b style="color:${C.color(ca.owner_level || 1)}">${ca.owner_flag?.e || ''} ${esc(ca.owner_name)} [${esc(ca.owner_tag)}]</b>` : 'Sem dono — ocupado por monstros'}</div></div>${near && near.id === ca.id && k && ['lider', 'vice'].includes(k.my_rank) && (!ca.owner || ca.owner !== k.id) ? `<button class="btn red" data-cap="${ca.id}">👑 Tomar o trono</button>` : `<button class="btn" data-go="${ca.id}">Ver no mapa</button>`}</div>`).join('') +
      `<div class="small" style="margin-top:6px">Quem domina um castelo: +3% de vida e ataque para todo o clã, portões fechados para os outros, bandeiras com a cor do clã, e o Armeiro, o Tesoureiro e o Senescal do castelo à disposição.</div>`; };
  if (!k) {
    b.innerHTML = `<div class="cbox"><b>Você ainda não tem clã</b><div class="small">Fundar custa 5.000 de aurum e exige nível 10. O clã evolui do nível 1 ao 10, ganha cor no nome, bandeira, bônus e pode conquistar castelos.</div>
      <div class="row" style="margin-top:6px"><input id="cl-name" maxlength="20" placeholder="Nome do clã" style="flex:2"><input id="cl-tag" maxlength="4" placeholder="SIGLA" style="width:70px;text-transform:uppercase"><button class="btn primary" id="cl-create">Fundar</button></div></div>
      ${ci.invites.length ? '<h4>Convites recebidos</h4>' + ci.invites.map(i => `<div class="row"><div class="grow"><b style="color:${C.color(i.level)}">${esc(i.name)} [${esc(i.tag)}]</b> <span class="small">nível ${i.level} • convite de ${esc(i.by || '')}</span></div><button class="btn primary" data-acc="${i.clan_id}">Entrar</button><button class="btn" data-rej="${i.clan_id}">Recusar</button></div>`).join('') : ''}
      <h4>Maiores clãs</h4>${ci.top.length ? ci.top.map((t, i) => `<div class="row"><div class="grow">${i + 1}º <b style="color:${C.color(t.level)}">${t.level >= 3 && t.flag?.e || ''} ${esc(t.name)} [${esc(t.tag)}]</b></div><span class="small">nível ${t.level} • ${t.n} membros • ${fmt(t.points)} pts</span></div>`).join('') : '<div class="small">Nenhum clã fundado ainda. Seja o primeiro!</div>'}
      <h4>Castelos</h4>${castles()}`;
  } else {
    const col = C.color(k.level), lead = k.my_rank === 'lider', off = ['lider', 'vice'].includes(k.my_rank), R = C.ranks;
    let h = tabs + `<div class="chead"><div class="cflag" style="border-color:${col}">${k.level >= 3 && k.flag?.e || '🏳️'}</div><div class="grow"><b style="color:${col};font-size:17px">${esc(k.name)} [${esc(k.tag)}]</b><div class="small">${C.title(k.level)} • nível ${k.level} • ${k.members.length}/${C.cap(k.level)} membros • seu cargo: ${R[k.my_rank][1]} ${R[k.my_rank][0]}</div><div class="small">⭐ ${fmt(k.points)} pontos de caça • 🪙 tesouro ${fmt(k.bank)} • 💎 ${k.items.gema || 0} gemas • 🔷 ${k.items.fragmento || 0} fragmentos</div></div></div>`;
    if (tab === 'geral') h += `<div class="cbox"><b>Bônus ativo:</b> +${((stats().clanBonus || 0) * 100).toFixed(1)}% de vida e ataque${ownCastle() ? ' (inclui +3% do castelo)' : ''}<div class="small">${C.perks[k.level]}</div></div>
      <h4>Mural</h4><div class="small">${esc(k.notice) || '— sem recado —'}</div>${off ? `<div class="row"><input id="cl-notice" maxlength="200" placeholder="Novo recado do mural" class="grow"><button class="btn" id="cl-setnotice">Publicar</button></div>` : ''}
      <h4>Doar ao tesouro</h4><div class="row"><input id="cl-au" type="number" min="1" placeholder="aurum" style="width:110px"><button class="btn" id="cl-don">🪙 Doar aurum</button><button class="btn" data-di="gema">💎 Doar 1 gema (${S.inv.gema || 0})</button><button class="btn" data-di="fragmento">🔷 Doar 1 fragmento (${S.inv.fragmento || 0})</button></div><div class="small">Caçar dá pontos ao clã: 1 por monstro e 25 por chefe.</div>
      <h4>Bandeira ${k.level < 3 ? '<span class="small">(liberada no nível 3)</span>' : ''}</h4>${k.level >= 3 && lead ? `<div class="cflags">${C.flags.map(f => `<button data-flag="${f}" class="${k.flag?.e === f ? 'on' : ''}">${f}</button>`).join('')}</div><div class="row small">Cor das bandeiras do castelo: ${['#c83a3a', '#3a7ac8', '#3aa85a', '#c8a03a', '#8a3ac8', '#e8e8e8', '#2a2a2a'].map(c2 => `<button data-fcol="${c2}" style="background:${c2};width:22px;height:22px;border:2px solid ${k.flag?.c === c2 ? '#fff' : '#0000'};border-radius:3px"></button>`).join(' ')}</div>` : `<div class="small">${k.level >= 3 ? 'Só o líder escolhe a bandeira. Ela aparece ao lado do nome de todos os membros.' : 'No nível 3 o líder escolhe um símbolo que aparece ao lado do nome de todos os membros.'}</div>`}
      <div class="row" style="margin-top:10px"><button class="btn red" id="cl-leave">${lead && k.members.length === 1 ? 'Dissolver o clã' : 'Sair do clã'}</button></div>`;
    else if (tab === 'membros') h += (['lider', 'vice', 'general'].includes(k.my_rank) ? `<div class="row"><input id="cl-inv" maxlength="20" placeholder="Nome do personagem para convidar" class="grow"><button class="btn primary" id="cl-invite">Convidar</button></div>${k.pending.length ? `<div class="small">Convites pendentes: ${k.pending.map(esc).join(', ')}</div>` : ''}` : '') +
      k.members.map(m => `<div class="row"><div class="grow">${R[m.rank][1]} <b>${esc(m.name)}</b> <span class="small">${R[m.rank][0]} • ${GD.CLASSES[m.class_id]?.name || ''} nv ${m.level} • contribuição ${fmt(m.contrib)}</span></div>${lead && m.rank !== 'lider' ? `<select data-rank="${m.id}">${['vice', 'general', 'tesoureiro', 'capitao', 'membro', 'recruta'].map(r => `<option value="${r}" ${r === m.rank ? 'selected' : ''}>${R[r][0]}</option>`).join('')}</select><button class="btn" data-lead="${m.id}" title="Passar a liderança">👑</button>` : ''}${off && m.rank !== 'lider' && m.id !== S.c.id ? `<button class="btn red" data-kick="${m.id}">✕</button>` : ''}</div>`).join('') +
      `<h4>Cargos</h4>${Object.values(R).map(r => `<div class="small">${r[1]} <b>${r[0]}</b> — ${r[2]}</div>`).join('')}`;
    else if (tab === 'evolucao') { const rq = k.req || C.req[k.level + 1], bar = (v, n) => `<div class="cprog"><i style="width:${Math.min(100, 100 * v / n)}%"></i><span>${fmt(v)} / ${fmt(n)}</span></div>`;
      h += rq ? `<div class="cbox"><b>Para o nível ${k.level + 1} — ${C.title(k.level + 1)}</b> <span class="small">${rq.items ? 'missão de caça + itens' : 'missão de caça'}</span>
        <div class="small">⭐ Pontos de caça</div>${bar(k.points, rq.points)}<div class="small">👥 Membros</div>${bar(k.members.length, rq.members)}<div class="small">🪙 Tesouro (é gasto ao evoluir)</div>${bar(k.bank, rq.aurum)}
        ${Object.entries(rq.items || {}).map(([i, n]) => `<div class="small">${inm(i)} doados (são gastos)</div>${bar(k.items[i] || 0, n)}`).join('')}
        ${off ? '<button class="btn primary" id="cl-up" style="margin-top:6px">Evoluir o clã</button>' : '<div class="small">Só o líder ou o vice evoluem o clã.</div>'}</div>` : '<div class="cbox"><b>Nível máximo alcançado!</b></div>';
      h += '<h4>O que cada nível libera</h4>' + Object.entries(C.perks).map(([l, t]) => `<div class="small" style="opacity:${+l <= k.level ? 1 : 0.6}"><b style="color:${C.color(+l)}">Nv ${l} ${C.title(+l)}</b> — ${t}${C.req[l] ? ` <i>(${fmt(C.req[l].points)} pts, ${C.req[l].members} membros, ${fmt(C.req[l].aurum)} aurum${C.req[l].items ? ', ' + Object.entries(C.req[l].items).map(([i, n]) => n + ' ' + (IT(i)?.name || i)).join(', ') : ''})</i>` : ''}</div>`).join(''); }
    else h += castles();
    b.innerHTML = h;
  }
  const v = id => (b.querySelector(id)?.value || '').trim();
  b.onchange = e => { const r = e.target.dataset.rank; if (r) clanDo('manage', { p_target: r, p_action: 'rank', p_rank: e.target.value }, 'Cargo alterado'); };
  b.onclick = async e => { const t = e.target.closest('button'); if (!t) return; const d = t.dataset;
    if (d.ct) { panelState.tab = d.ct; renderPanel(); } else if (t.id === 'cl-create') clanDo('create', { p_name: v('#cl-name'), p_tag: v('#cl-tag') }, 'Clã fundado!');
    else if (d.acc) clanDo('answer', { p_clan: d.acc, p_accept: true }, 'Bem-vindo ao clã!'); else if (d.rej) clanDo('answer', { p_clan: d.rej, p_accept: false });
    else if (t.id === 'cl-invite') clanDo('invite', { p_name: v('#cl-inv') }, 'Convite enviado'); else if (d.kick) { if (confirm('Remover este membro do clã?')) clanDo('manage', { p_target: d.kick, p_action: 'kick' }, 'Membro removido'); }
    else if (d.lead) { if (confirm('Passar a liderança do clã para este membro?')) clanDo('manage', { p_target: d.lead, p_action: 'leader' }, 'Liderança transferida'); }
    else if (t.id === 'cl-don') { const n = Math.floor(+v('#cl-au')); if (n > 0) clanDo('donate', { p_aurum: n }, 'Doação feita'); } else if (d.di) clanDo('donate', { p_aurum: 0, p_item: d.di, p_qty: 1 }, 'Doação feita');
    else if (t.id === 'cl-up') { if (await clanDo('levelup', {}, 'O clã evoluiu!')) { sfx('levelup'); postFlash(0.6); } } else if (d.flag) clanDo('set', { p_flag: { e: d.flag, c: myClan().flag?.c || '#c83a3a' } }, 'Bandeira definida'); else if (d.fcol) clanDo('set', { p_flag: { e: myClan().flag?.e || '⚔️', c: d.fcol } }, 'Cor definida');
    else if (t.id === 'cl-setnotice') clanDo('set', { p_notice: v('#cl-notice') }, 'Recado publicado'); else if (t.id === 'cl-leave') { if (confirm('Tem certeza?')) clanDo('leave', {}, 'Você saiu do clã'); }
    else if (d.cap) { await saveNow(); if (await clanDo('capture', { p_castle: d.cap }, '👑 Castelo conquistado!')) { sfx('levelup'); postFlash(0.8); shake(0.5); } }
    else if (d.go) { const L = GD.LANDMARKS.find(L => L.id === d.go); toast(`🏰 ${L.name} fica em (${L.x}, ${L.z}) — use o Guardião do Portal de uma cidade`); } };
}
function pChar(b) {
  const c = S.c, st = stats(), cl = st.cls, eq = c.equipment, P = c.profs || {};
  const es = (s, l) => eq[s] ? slot(eq[s], (c.enchant || {})[eq[s]] ? '+' + c.enchant[eq[s]] : null, `data-slot="${s}"`) : `<div class="slot" data-slot="${s}"><div class="ic">▫️</div><div class="nm">${l}</div></div>`;
  b.innerHTML = `<div class="row"><div class="grow"><b style="font-size:16px">${esc(c.name)}</b><div class="small">${GD.RACES[c.race].name} • ${cl.name} (${['Classe base', '2ª classe', '3ª classe', '4ª classe'][cl.rank]}) • Nível ${c.level}</div></div></div>
  <div class="grid" style="grid-template-columns:repeat(4,90px);margin:8px 0">${es('elmo', 'Elmo')}${es('armadura', 'Armadura')}${es('arma', 'Arma')}${es('escudo', 'Escudo')}${es('luvas', 'Luvas')}${es('botas', 'Botas')}</div>
  <table><tr><td>Vida</td><td>${Math.round(S.hp)} / ${st.maxHp}</td><td>Mana</td><td>${Math.round(S.mp)} / ${st.maxMp}</td></tr>
  <tr><td>Ataque Físico</td><td>${Math.round(st.patk)}</td><td>Ataque Mágico</td><td>${Math.round(st.matk)}</td></tr>
  <tr><td>Defesa Física</td><td>${Math.round(st.pdef)}</td><td>Defesa Mágica</td><td>${Math.round(st.mdef)}</td></tr>
  <tr><td>Velocidade</td><td>${st.speed.toFixed(1)} m/s</td><td>Alcance</td><td>${st.range} m</td></tr>
  <tr><td>Crítico</td><td>${Math.round(st.crit * 100)}%</td><td>Aurum</td><td>${Number(c.aurum).toLocaleString('pt-BR')}</td></tr>
  <tr><td>PvP</td><td>${c.pvp || 0}</td><td>PK / Karma</td><td style="color:${c.karma ? '#f66' : ''}">${c.pk || 0} / ${c.karma || 0}</td></tr></table>
  <h4>Efeitos dos equipamentos</h4>${st.effects.length ? st.effects.map(e => `<div class="small">${e.icon} <b>${esc(e.name)}</b> — ${esc(e.desc)}</div>`).join('') : '<div class="small">Nenhum. Armas de grau D ou maior têm habilidades especiais, e 2 ou 4 peças do mesmo conjunto dão bônus.</div>'}
  <h4>Profissões</h4><table>${Object.entries(GD.PROFS).map(([k, n]) => { const l = GD.profLevel(P[k]); return `<tr><td>${n}</td><td>nível ${l}</td><td class="small">libera até grau ${GD.GRADES[Math.min(5, Math.floor(l / 4))].id}</td></tr>`; }).join('')}</table>`;
  b.onclick = async e => { const s = e.target.closest('[data-slot]'); if (!s || !eq[s.dataset.slot]) return; const r = await safe(() => B.unequip(s.dataset.slot), 'Desequipado'); if (r) { S.c.equipment = r; await refresh(); (me.enc = encOf(S.c), setGear(me, r.arma, r.armadura, r)); renderPanel(); } };
}
function itemSource(id) {
  const it = IT(id); const src = [];
  if (GD.RECIPES[id]) src.push(GD.RECIPES[id].station === 'forja' ? '⚒️ Forja' : GD.RECIPES[id].station === 'alquimia' ? '⚗️ Alquimia' : '🔥 Refinaria');
  if (GD.SHOP[id] != null) src.push('🛒 Mercador');
  if (it.type === 'raw') src.push('⛏️ Coleta'); if (it.type === 'trophy') src.push('⚔️ Drop de monstros'); if (it.type === 'enchant' || it.type === 'scroll') src.push('⚔️ Drop raro');
  if (it.relic || it.unique) src.push('👑 Chefe lendário'); return src.join(' • ') || '—';
}
function pCodex(b) {
  const tab = panelState.tab2 || 'itens', q = (panelState.q || '').toLowerCase(), g = panelState.cg ?? 'all', sl = panelState.cs || 'all';
  const tabs = [['itens', '🎒 Itens'], ['skills', '📘 Habilidades'], ['buffs', '✨ Buffs e efeitos'], ['comp', '🐎 Montarias e pets'], ['locais', '⚰️ Locais e chefes'], ['mobs', '🐺 Monstros']];
  let h = `<div class="chips">${tabs.map(([k, l]) => `<button data-t="${k}" class="${k === tab ? 'on' : ''}">${l}</button>`).join('')}</div>`;
  if (tab === 'itens') {
    h += `<input id="cx-q" placeholder="Buscar item…" value="${esc(panelState.q || '')}" style="width:100%;margin:4px 0">
    <div class="chips"><button data-g="all" class="${g === 'all' ? 'on' : ''}">Todos</button>${GD.GRADES.map((G, i) => `<button data-g="${i}" class="${String(i) === String(g) ? 'on' : ''}" style="color:${G.color}">${G.id}</button>`).join('')}</div>
    <div class="chips">${[['all', 'Tudo'], ['arma', 'Armas'], ['armadura', 'Armaduras'], ['elmo', 'Elmos'], ['luvas', 'Luvas'], ['botas', 'Botas'], ['escudo', 'Escudos'], ['mat', 'Materiais'], ['use', 'Consumíveis']].map(([k, l]) => `<button data-s="${k}" class="${k === sl ? 'on' : ''}">${l}</button>`).join('')}</div>`;
    const list = Object.values(GD.ITEMS).filter(it => (g === 'all' || it.grade === +g) && (sl === 'all' || it.slot === sl || (sl === 'mat' && ['raw', 'refined', 'special', 'trophy'].includes(it.type)) || (sl === 'use' && ['potion', 'scroll', 'enchant'].includes(it.type))) && (!q || it.name.toLowerCase().includes(q)))
      .sort((a, c) => a.grade - c.grade || (a.slot || 'z').localeCompare(c.slot || 'z') || a.name.localeCompare(c.name));
    h += `<div class="small">${list.length} itens</div>` + list.slice(0, 120).map(it => `<div class="row" style="border-bottom:1px solid #ffffff14;padding:4px 0"><div style="font-size:22px;width:44px">${icImg(it)}</div><div class="grow"><b style="color:${gcol(it.grade)}">${esc(it.name)}</b> <span class="small">${GD.GRADES[it.grade].id}${it.relic ? ' • Relíquia' : ''}</span><div class="small">${itemDesc(it.id) || ''}</div><div class="small" style="opacity:.75">Origem: ${itemSource(it.id)}${S.inv[it.id] ? ` • você tem ${S.inv[it.id]}` : ''}</div></div></div>`).join('');
  }
  if (tab === 'skills') {
    h += Object.entries(GD.ARCH).map(([k, A]) => `<h4>${esc(A.name)} <span class="small">(${A.weapon}${A.shield ? ' + escudo' : ''}, armadura ${A.armor})</span></h4>` + A.skills.map(s => `<div class="row" style="padding:3px 0"><div style="font-size:20px;width:28px">${s.icon}</div><div class="grow"><b>${esc(s.name)}</b> <span class="small">nv ${s.lvl} • ${s.mp} MP • recarga ${s.cd}s</span><div class="small">${skillDesc(s)}</div></div></div>`).join('')).join('');
    h += '<h4>Classes que usam cada estilo</h4><div class="small">' + Object.values(GD.CLASSES).map(c => `${esc(c.name)} (${esc(GD.ARCH[c.arch]?.name || '')})`).join(' • ') + '</div>';
  }
  if (tab === 'buffs') {
    h += '<h4>Habilidades especiais das armas</h4><div class="small">Toda arma de grau D ou maior tem uma; relíquias têm duas, 50% mais fortes. Encantar acima de +3 aumenta o efeito em 10% por nível.</div>';
    h += Object.entries(GD.SA).map(([k, a]) => `<div class="row"><div style="font-size:20px;width:28px">${a.icon}</div><div class="grow"><b>${a.name}</b><div class="small">${a.d(a.v)} (valor do grau D; cresce com o grau) • aparece em: ${Object.entries(GD.SA_BY).filter(([w, l]) => l.includes(k)).map(([w]) => w).join(', ')}</div></div></div>`).join('');
    h += '<h4>Bônus de conjunto (armadura, elmo, luvas e botas)</h4>' + Object.entries(GD.SETS).map(([k, S2]) => `<div class="row"><div style="font-size:20px;width:28px">${S2.icon}</div><div class="grow"><b>${S2.name}</b><div class="small">2 peças: ${Object.keys(S2.two).join(', ')} • 4 peças: ${Object.keys(S2.four).join(', ')} — mesmo tipo e mesmo grau (maior grau, bônus maior)</div></div></div>`).join('');
    h += '<h4>Buffs das habilidades</h4>' + Object.values(GD.ARCH).flatMap(A => A.skills.filter(s => s.type === 'buff' || s.type === 'debuff').map(s => `<div class="small">${s.icon} <b>${esc(s.name)}</b> (${esc(A.name)}) — ${skillDesc(s)}</div>`)).join('');
    h += '<h4>Movimento</h4><div class="small">💨 Correr: Shift (gasta fôlego) • 🌀 Esquivar: Q (25 de fôlego, invulnerável no rolamento) • ⛰️ Escalar: ande contra encostas íngremes; o fôlego cai rápido, recupere em platôs.</div>';
  }
  if (tab === 'comp') {
    h += '<div class="small">Compre no Mercador (ou consiga com chefes) e use pela bolsa. R monta e desmonta • V voa (com asas ou montaria voadora) • Espaço sobe, X desce. O pet segue você e ajuda no combate.</div>';
    for (const [ty, tl] of [['mount', 'Montarias'], ['pet', 'Pets'], ['wings', 'Asas']]) h += `<h4>${tl}</h4>` + Object.entries(GD.COMP).filter(([, c]) => c.type === ty).map(([id, c]) => `<div class="row"><div style="font-size:22px;width:30px">${c.icon}</div><div class="grow"><b style="color:${gcol(IT(id).grade)}">${esc(c.name)}</b> <span class="small">nv ${c.lvl}${c.price ? ' • ' + c.price.toLocaleString('pt-BR') + ' aurum' : ' • só com chefes'}${S.inv[id] ? ' • ✔ você tem' : ''}</span><div class="small">${itemDesc(id)}</div></div></div>`).join('');
  }
  if (tab === 'locais') {
    h += '<div class="small">Locais únicos espalhados pelo mundo. Cada um tem um chefe que aparece quando você chega perto e deixa itens próprios (arma relíquia com dois efeitos, pets, asas e montarias raras).</div>';
    h += GD.LANDMARKS.map(L => { const f = FAM[L.boss]; const dr = (GD.POI_DROPS[L.boss] || (f && f.drops) || []).map(i => IT(i) ? `${IT(i).icon} ${esc(IT(i).name)}` : '').filter(Boolean).join(', '); return `<div class="row"><div class="grow"><b>${{ castelo: '🏰', ruina: '🏛️', covil: '💀', tumba: '⚰️', pantano: '🐸', destrocos: '🛒', estranho: '🔮', neon: '🌆' }[L.type] || '📍'} ${esc(L.name)}</b> <span class="small">nv ${L.lvl} • (${L.x}, ${L.z})</span><div class="small">Chefe: ${esc(f ? f.name : '?')} — ${dr}</div></div></div>`; }).join('');
  }
  if (tab === 'mobs') {
    h += GD.MOBS.map((fs, gi) => `<h4 style="color:${GD.GRADES[gi].color}">${GD.GRADES[gi].name}</h4>` + fs.map(f => `<div class="small">${f.boss ? '👑' : f.aggro ? '⚔️' : '🐾'} <b>${esc(f.name)}</b>${f.boss ? ' — chefe' : f.aggro ? ' — agressivo' : ' — passivo'}${GD.TROPHY[f.id] ? ` • troféu: ${GD.TROPHY[f.id][1]} ${esc(GD.TROPHY[f.id][0])}` : ''}</div>`).join('')).join('');
  }
  b.innerHTML = h;
  const qi = $('#cx-q'); if (qi) { qi.oninput = () => { panelState.q = qi.value; const pos = qi.selectionStart; renderPanel(); const n = $('#cx-q'); n.focus(); n.setSelectionRange(pos, pos); }; }
  b.onclick = e => { const d = e.target.dataset; if (d.t) { panelState.tab2 = d.t; renderPanel(); } else if (d.g) { panelState.cg = d.g; renderPanel(); } else if (d.s) { panelState.cs = d.s; renderPanel(); } };
}
function pBag(b) {
  const f = panelState.f || 'all', order = { weapon: 0, armor: 1, enchant: 2, tool: 3, potion: 4, scroll: 5, special: 6, trophy: 7, refined: 8, raw: 9 };
  const ids = Object.keys(S.inv).filter(i => IT(i)).filter(i => { const t = IT(i).type; return f === 'all' || f === t || (f === 'gear' && (t === 'weapon' || t === 'armor')) || (f === 'mat' && ['raw', 'refined', 'special', 'trophy'].includes(t)) || (f === 'use' && ['potion', 'scroll', 'tool', 'enchant'].includes(t)); })
    .sort((a, c) => order[IT(a).type] - order[IT(c).type] || IT(c).grade - IT(a).grade || a.localeCompare(c));
  b.innerHTML = `<div class="chips">${[['all', 'Tudo'], ['gear', 'Equipamentos'], ['mat', 'Materiais'], ['use', 'Consumíveis']].map(([k, l]) => `<button data-f="${k}" class="${k === f ? 'on' : ''}">${l}</button>`).join('')}</div>
    <div class="small">🪙 ${Number(S.c.aurum).toLocaleString('pt-BR')} aurum</div><div id="bdet"></div><div class="grid">${ids.map(i => slot(i, S.inv[i])).join('') || '<div class="small">Inventário vazio</div>'}</div>`;
  b.onclick = async e => {
    if (e.target.dataset.f) { panelState.f = e.target.dataset.f; return renderPanel(); }
    const a = e.target.dataset.a, id = panelState.sel;
    if (a === 'eq') { const r = await equipItem(id); if (r) { S.c.equipment = r; await refresh(); (me.enc = encOf(S.c), setGear(me, r.arma, r.armadura, r)); S.hp = Math.min(S.hp, stats().maxHp); buildBar(); renderPanel(); } return; }
    if (a === 'bar') { addToBar({ t: 'i', id }); return; }
    const enc = e.target.dataset.enc; if (enc) { await doEnchant(enc); return; }
    if (a === 'use' && IT(id).comp) { const it = IT(id); if (S.c.level < it.comp.lvl) return toast(`Requer nível ${it.comp.lvl}`, 'err'); if (it.type === 'pet') await summonPet(id); else if (it.type === 'mount') await setMount(id); else setWings(id); renderPanel(); return; }
    if (a === 'use') { const it = IT(id); if (it.type === 'scroll') { const r = await safe(() => B.useItem(id)); if (r) { S.inv[id]--; if (!S.inv[id]) delete S.inv[id]; toast('Retornando a ' + r.town, 'ok'); teleport(r.x, r.z); renderPanel(); } } else { await usePotion(id.startsWith('pocao_mp') ? 'mp' : 'hp'); renderPanel(); } return; }
    const s = e.target.closest('.slot'); if (!s) return; const sid = s.dataset.id; panelState.sel = sid; const it = IT(sid);
    $('#bdet').innerHTML = `<div class="row"><div style="font-size:28px">${icImg(it, true)}</div><div class="grow"><b style="color:${gcol(it.grade)}">${esc(it.name)}</b> x${S.inv[sid]}<div class="small">${itemDesc(sid)}</div></div>
      ${it.slot ? '<button class="btn" data-a="eq">Equipar</button>' : ''}${it.type === 'enchant' ? encTargets(it).map(([sl, iid]) => `<button class="btn" data-enc="${sl}">✨ ${esc(IT(iid).name)} +${(S.c.enchant || {})[iid] || 0}</button>`).join('') || '<span class="small">Equipe um item do mesmo grau para encantar</span>' : ''}${['potion', 'scroll', 'pet', 'mount', 'wings'].includes(it.type) ? `<button class="btn" data-a="use">${it.comp ? (it.type === 'pet' ? (COMP.petId === sid ? 'Guardar pet' : 'Chamar pet') : it.type === 'mount' ? 'Montar' : (COMP.wingsId === sid ? 'Guardar asas' : 'Equipar asas')) : 'Usar'}</button>` : ''}${['potion', 'scroll', 'pet', 'mount', 'wings'].includes(it.type) || it.slot ? '<button class="btn alt" data-a="bar">➕ Barra</button>' : ''}</div>`;
  };
  b.ondragstart = e => { const s = e.target.closest('.slot'); if (s && s.dataset.id) e.dataTransfer.setData('text/plain', JSON.stringify({ t: 'i', id: s.dataset.id })); };
  b.querySelectorAll('.slot[data-id]').forEach(el => el.draggable = true);
}
function pSkillsBind(b) {
  b.ondragstart = e => { const r = e.target.closest('[data-sid]'); if (r) e.dataTransfer.setData('text/plain', JSON.stringify({ t: 's', id: r.dataset.sid })); };
  b.onclick = e => { const t = e.target.closest('[data-add]'); if (t) addToBar({ t: 's', id: t.dataset.add }); };
}
function pSkills(b) { pSkillsBody(b); pSkillsBind(b); }
function pSkillsBody(b) {
  const st = stats(), cl = st.cls; const chain = []; let x = cl; while (x) { chain.unshift(x); x = GD.CLASSES[x.parent]; }
  b.innerHTML = `<div class="small">Caminho: ${chain.map(c => esc(c.name)).join(' → ')} • Estilo: ${st.arch.name} (bônus de poder ${Math.round(cl.rank * 10)}% nas habilidades)</div>
  <div class="small">Arraste a habilidade para a barra (ou clique em ➕). Clique com o botão direito num atalho da barra para remover. Itens da bolsa (poções, pergaminhos, equipamentos) também podem ir para a barra.</div>
  <div class="small">Teclas 1–9 usam a barra • \` troca a página da barra (3 páginas) • 0 e - são poções.</div>
  ${[['atk', '⚔️ Ataque', s => ['hit', 'dash', 'multi', 'chain', 'blink'].includes(s.type)], ['def', '🛡️ Defesa e cura', s => ['shield', 'heal', 'mana'].includes(s.type) || (s.type === 'buff' && (s.buff.pdef || s.buff.mdef || s.buff.invuln || s.buff.hot))], ['buff', '✨ Buffs', s => s.type === 'buff' && !(s.buff.pdef || s.buff.mdef || s.buff.invuln || s.buff.hot)],
     ['ctl', '☠️ Debuffs e controle', s => s.type === 'debuff' || s.type === 'taunt'], ['area', '☄️ Área', s => s.type === 'zone'], ['trap', '🪤 Armadilhas', s => s.type === 'trap'], ['mov', '💨 Movimento', s => ['leap'].includes(s.type)]].map(([g, t, f]) => { const list = st.arch.skills.filter(f); if (!list.length) return '';
    return `<h4>${t}</h4><div class="skgrid">` + list.map(s => `<div class="skc ${S.c.level < s.lvl ? 'off' : ''}" draggable="${S.c.level >= s.lvl}" data-sid="${esc(s.id)}" title="${esc(s.name + ' — ' + skillDesc(s))}"><div class="ico">${s.icon}</div><div class="nm">${esc(s.name)}</div><div class="mt">nv ${s.lvl} • ${s.mp} MP • ${s.cd}s</div>${S.c.level >= s.lvl ? `<button class="add" data-add="${esc(s.id)}">＋</button>` : '🔒'}</div>`).join('') + '</div>'; }).join('')}
  <h4>Próximas classes</h4><div class="tree">${treeHtml(cl.id)}</div>`;
}
function skillDesc(s) { const p = []; if (s.type === 'hit') p.push(`Causa ${Math.round(s.mult * 100)}% de dano${s.aoe ? ` em área (${s.aoe} m)` : ''}`); if (s.stun) p.push(`atordoa ${s.stun}s`); if (s.slow) p.push('reduz a velocidade do alvo'); if (s.dot) p.push(`dano contínuo por ${s.dot.dur}s`); if (s.drain) p.push('rouba vida'); if (s.execute) p.push('dano dobrado em alvos com menos de 30% de vida');
  if (s.type === 'buff') p.push('Fortalece por ' + s.dur + 's: ' + Object.keys(s.buff).map(k => ({ pdef: 'defesa física', mdef: 'defesa mágica', patk: 'ataque físico', matk: 'ataque mágico', crit: 'crítico', speed: 'velocidade', lifesteal: 'roubo de vida', dodge: 'esquiva', atkspd: 'velocidade de ataque', invuln: 'invulnerabilidade', hot: 'regeneração' }[k])).join(', '));
  if (s.type === 'debuff') { p.push('Enfraquece ' + (s.aoe ? `os inimigos em ${s.aoe} m` : 'o alvo') + ` por ${s.dur}s: ` + Object.entries(s.deb).map(([k, v]) => `${{ atk: 'ataque', def: 'defesa', speed: 'velocidade' }[k]} ${Math.round(v * 100)}%`).join(', ')); if (s.hitMult) p.push(`e causa ${Math.round(s.hitMult * 100)}% de dano`); if (s.stun) p.push(`atordoa ${s.stun}s`); if (s.dot) p.push('com dano contínuo'); }
  if (s.cleanse) p.push('remove efeitos negativos');
  if (s.type === 'heal') p.push(`Cura ${s.pct * 100}% da vida`); if (s.type === 'mana') p.push(`Recupera ${s.pct * 100}% da mana`); if (s.type === 'dash') p.push(`Avança até o alvo (${s.range} m) e golpeia`); if (s.type === 'leap') p.push(`Salta ${s.dist} m para trás`); if (s.type === 'taunt') p.push('Atrai todos os monstros próximos');
  if (s.type === 'shield') p.push(`Escudo que absorve ${Math.round(s.pct * 100)}% da vida máxima em dano por ${s.dur}s`);
  if (s.type === 'trap') p.push(`Armadilha no chão: ao ser pisada, causa ${Math.round((s.mult || 1) * 100)}% de dano em ${s.aoe || 3} m`);
  if (s.type === 'zone') p.push(`Área de ${s.aoe} m com ${s.ticks} pulsos (${Math.round(s.mult * 100)}% de dano total)`);
  if (s.type === 'multi') p.push(`Atinge até ${s.n} inimigos com ${Math.round(s.mult * 100)}% de dano`);
  if (s.type === 'chain') p.push(`Salta entre até ${s.n} inimigos (${Math.round(s.mult * 100)}% no primeiro)`);
  if (s.type === 'blink') p.push(`Teleporta para as costas do alvo e golpeia com ${Math.round(s.mult * 100)}%`);
  if (s.root) p.push(`prende por ${s.root}s`); if (s.confuse) p.push(`confunde por ${s.confuse}s`); if (s.fear) p.push(`causa medo por ${s.fear}s`); if (s.knock) p.push(`empurra ${s.knock} m`); if (s.bleed) p.push('causa sangramento'); if (s.poison) p.push('envenena'); if (s.slowFx) p.push(`deixa lento por ${s.slowFx}s`);
  return p.join(', '); }
function treeHtml(id) { const kids = GD.nextClasses(id); if (!kids.length) return '<div class="small">Você alcançou o ápice do seu caminho.</div>'; const rec = (cid, d) => GD.nextClasses(cid).map(c => `<div class="t${d}">↳ ${esc(c.name)} <span class="small">(nv ${GD.RANK_LVL[c.rank]} • ${GD.ARCH[c.arch].name}${c.bonus ? ' • bônus de ' + c.bonus : ''})</span></div>${rec(c.id, d + 1)}`).join(''); return rec(id, 2); }
function pClasse(b) {
  const cl = GD.CLASSES[S.c.class_id], next = GD.nextClasses(cl.id);
  b.innerHTML = `<p class="small">"Cada caminho exige sangue compatível. Escolha com sabedoria — não há volta."</p><div class="small">Classe atual: <b>${esc(cl.name)}</b> • nível ${S.c.level}</div>
  ${next.map(c => { const req = GD.RANK_LVL[c.rank], ok = S.c.level >= req; return `<div class="row"><div class="grow"><b>${esc(c.name)}</b> <span class="small">(${GD.ARCH[c.arch].name}${c.bonus ? ' • bônus de ' + c.bonus : ''})</span><div class="small">Requer nível ${req} • arma ideal: ${GD.WEAPONS[GD.ARCH[c.arch].weapon].name}, armadura ${GD.ARMORS[GD.ARCH[c.arch].armor].name}</div></div><button class="btn" data-c="${c.id}" ${ok ? '' : 'disabled'}>Tornar-me</button></div>`; }).join('') || '<div class="small">Você já está na classe final.</div>'}`;
  b.onclick = async e => { const id = e.target.dataset.c; if (!id || !confirm('Confirmar troca para ' + GD.CLASSES[id].name + '?')) return; const r = await safe(() => B.classChange(id), n => 'Agora você é ' + n + '!'); if (r) { S.c.class_id = id; buildBar(); renderPanel(); } };
}
function pCraft(b) {
  const st = panelState.station || 'refinaria', near = nearNpc(st === 'forja' ? 'ferreiro' : 'refino'), stations = st === 'forja' ? ['forja'] : ['refinaria', 'alquimia'];
  const sub = panelState.sub || stations[0], g = panelState.g ?? Math.min(5, Math.floor(GD.profLevel(S.c.profs[sub === 'forja' ? 'forja' : 'refino']) / 4));
  b.innerHTML = `${stations.length > 1 ? `<div class="chips">${stations.map(s => `<button data-s="${s}" class="${s === sub ? 'on' : ''}">${s === 'refinaria' ? 'Refinaria' : 'Alquimia'}</button>`).join('')}</div>` : ''}
  <div class="chips">${GD.GRADES.map((G, i) => `<button data-g="${i}" class="${i === g ? 'on' : ''}">${G.id}</button>`).join('')}</div>${near ? '' : '<div class="toast err" style="animation:none">Fale com o NPC na cidade para fabricar.</div>'}<div id="rl"></div>`;
  const rs = Object.values(GD.RECIPES).filter(r => r.station === sub && (sub === 'alquimia' || r.grade === g));
  $('#rl').innerHTML = rs.map(r => { const lv = GD.profLevel(S.c.profs[r.prof]), ok = lv >= r.grade * 4; let max = 50;
    const need = Object.entries(r.inputs).map(([i, q]) => { const h = S.inv[i] || 0; max = Math.min(max, Math.floor(h / q)); return `<span class="${h >= q ? 'ok' : 'no'}">${icon(i)} ${esc(iname(i))} ${h}/${q}</span>`; }).join(' · ');
    const dis = !near || !ok || max < 1 ? 'disabled' : '';
    return `<div class="row"><div style="font-size:24px">${icon(r.out)}</div><div class="grow"><b style="color:${gcol(r.grade)}">${esc(iname(r.out))}${r.qty > 1 ? ' x' + r.qty : ''}</b><div class="need">${need}</div><div class="small">${ok ? '' : `<span style="color:#f88">Requer ${GD.PROFS[r.prof]} ${r.grade * 4}</span> • `}+${r.xp} XP ${itemDesc(r.out) ? '• ' + itemDesc(r.out) : ''}</div></div>
    <button class="btn" data-r="${r.id}" data-n="1" ${dis}>Fazer</button><button class="btn alt" data-r="${r.id}" data-n="${max}" ${dis}>×${Math.max(max, 0)}</button></div>`; }).join('');
  b.onclick = async e => { const t = e.target; if (t.dataset.s) { panelState.sub = t.dataset.s; return renderPanel(); } if (t.dataset.g) { panelState.g = +t.dataset.g; return renderPanel(); }
    if (t.dataset.r && !t.disabled) { t.disabled = true; const r = await safe(() => B.craft(t.dataset.r, +t.dataset.n), x => `Fabricado: ${x.qty}x ${iname(x.item)}${x.bonus ? ` (+${x.bonus} bônus de Forjador!)` : ''}`); if (r) await refresh(); renderPanel(); } };
}
function pShop(b) {
  const tab = panelState.tab || 'buy', near = nearNpc('mercador');
  b.innerHTML = `<div class="chips"><button data-t="buy" class="${tab === 'buy' ? 'on' : ''}">Comprar</button><button data-t="sell" class="${tab === 'sell' ? 'on' : ''}">Vender</button></div><div class="small">🪙 ${Number(S.c.aurum).toLocaleString('pt-BR')} aurum</div><div id="sl"></div>`;
  $('#sl').innerHTML = tab === 'buy' ? Object.entries(GD.SHOP).map(([i, p]) => `<div class="row"><div style="font-size:22px">${icon(i)}</div><div class="grow">${esc(iname(i))}<div class="small">${p} aurum • ${itemDesc(i)}</div></div><input type="number" value="1" min="1" style="width:50px" data-q="${i}"><button class="btn" data-b="${i}" ${near ? '' : 'disabled'}>Comprar</button></div>`).join('')
    : Object.keys(S.inv).filter(i => IT(i)).map(i => `<div class="row"><div style="font-size:22px">${icon(i)}</div><div class="grow">${esc(iname(i))} x${S.inv[i]}<div class="small">${GD.npcPrice(IT(i))} aurum cada</div></div><button class="btn alt" data-s="${i}" data-n="1" ${near ? '' : 'disabled'}>1</button><button class="btn" data-s="${i}" data-n="${S.inv[i]}" ${near ? '' : 'disabled'}>Todos</button></div>`).join('');
  b.onclick = async e => { const t = e.target; if (t.dataset.t) { panelState.tab = t.dataset.t; return renderPanel(); }
    if (t.dataset.b) { const q = +b.querySelector(`[data-q="${t.dataset.b}"]`).value || 1; if (await safe(() => B.shopBuy(t.dataset.b, q), 'Compra concluída') !== undefined) { await refresh(); renderPanel(); } }
    if (t.dataset.s) { if (await safe(() => B.npcSell(t.dataset.s, +t.dataset.n), v => `+${v} aurum`) !== undefined) { await refresh(); renderPanel(); } } };
}
async function pMarket(b) {
  const tab = panelState.mt || 'comprar', near = nearNpc('leilao');
  b.innerHTML = `<div class="chips">${[['comprar', 'Comprar'], ['vender', 'Anunciar'], ['minhas', 'Minhas ofertas']].map(([k, l]) => `<button data-t="${k}" class="${k === tab ? 'on' : ''}">${l}</button>`).join('')}</div><div class="small">Taxa de 4% sobre a venda • 🪙 ${Number(S.c.aurum).toLocaleString('pt-BR')}</div><div id="ml">Carregando…</div>`;
  b.onclick = async e => { const t = e.target; if (t.dataset.t) { panelState.mt = t.dataset.t; return renderPanel(); }
    if (t.dataset.c) { if (await safe(() => B.marketCancel(+t.dataset.c), 'Oferta cancelada') !== undefined) { await refresh(); renderPanel(); } }
    if (t.dataset.b) { const q = +b.querySelector(`[data-q="${t.dataset.b}"]`).value; if (await safe(() => B.marketBuy(+t.dataset.b, q), 'Compra concluída') !== undefined) { await refresh(); renderPanel(); } }
    if (t.id === 'mgo') { if (await safe(() => B.marketSell($('#ms').value, +$('#mq').value, +$('#mp').value), 'Oferta anunciada') !== undefined) { await refresh(); panelState.mt = 'minhas'; renderPanel(); } } };
  if (tab === 'vender') { const ids = Object.keys(S.inv).filter(i => IT(i)); $('#ml').innerHTML = `<div class="field"><select id="ms">${ids.map(i => `<option value="${i}">${esc(iname(i))} (${S.inv[i]})</option>`).join('')}</select></div><div class="field"><input id="mq" type="number" value="1" min="1"><input id="mp" type="number" value="100" min="1" placeholder="preço cada"></div><button class="btn" id="mgo" ${near ? '' : 'disabled'}>Anunciar</button>`; return; }
  const list = await safe(() => B.marketList()); if (!list || panelState.kind !== 'market') return;
  const rows = list.filter(o => tab === 'minhas' ? o.mine : !o.mine);
  $('#ml').innerHTML = rows.map(o => `<div class="row"><div style="font-size:22px">${icon(o.item)}</div><div class="grow"><b style="color:${gcol(IT(o.item)?.grade)}">${esc(iname(o.item))}</b> x${o.qty}<div class="small">🪙 ${o.price} cada • ${esc(o.seller)}</div></div>${tab === 'minhas' ? `<button class="btn red" data-c="${o.id}">Cancelar</button>` : `<input type="number" value="1" min="1" max="${o.qty}" style="width:50px" data-q="${o.id}"><button class="btn" data-b="${o.id}" ${near ? '' : 'disabled'}>Comprar</button>`}</div>`).join('') || '<div class="small">Nenhuma oferta.</div>';
}
function pTeleport(b) {
  const gm = S.c.is_gm;
  b.innerHTML = `<div class="small">"Os portais conectam as onze cidades, as terras de caça e os locais lendários. Escolha seu destino."</div>${GD.TOWNS.map(t => `<h4>${esc(t.name)} <span class="small">Nv. ${t.min}–${t.max}</span></h4>` + TELEPORTS.filter(x => x.id === 'town:' + t.id || x.id.startsWith('spot:' + t.id + ':')).map(x => `<div class="row"><div class="grow">${x.town ? '🏰' : '⚔️'} ${esc(x.name)} <span class="small">(nv ${x.lvl})</span></div><span class="small">${gm ? 'grátis' : x.cost + ' aurum'}</span><button class="btn" data-d="${x.id}">Ir</button></div>`).join('')).join('')}<h4>⚔️ Locais especiais (chefes e drops exclusivos)</h4>${TELEPORTS.filter(x => x.lm).sort((a, b) => a.lvl - b.lvl).map(x => `<div class="row"><div class="grow">🏯 ${esc(x.name)} <span class="small">(nv ${x.lvl})</span></div><span class="small">${gm ? 'grátis' : x.cost + ' aurum'}</span><button class="btn" data-d="${x.id}">Ir</button></div>`).join('')}`;
  b.onclick = async e => { const d = e.target.dataset.d; if (!d) return; const r = await safe(() => B.teleport(d)); if (!r) return; S.c.aurum -= r.cost; closePanel(); toast('Teleportado para ' + r.name, 'ok'); teleport(r.x, r.z); };
}
function pArauto(b) {
  const here = panelState.npc?.town?.id, gm = S.c.is_gm, band = GD.gradeForLevel(S.c.level);
  const ready = S.q.active.filter(id => questReady(QD.QUESTS[id]));
  const okQ = Q => !qDone(Q.id) && !S.q.active.includes(Q.id) && (!Q.prereq || S.c.quests?.[Q.prereq]);
  const groups = [
    ['★ História', QD.LIST.filter(Q => Q.main && okQ(Q) && (Q.town === here || gm))],
    ['📜 Secundárias desta cidade', QD.LIST.filter(Q => Q.kind === 'secundaria' && okQ(Q) && (Q.town === here || gm))],
    ['🔁 Diárias (renovam à meia-noite)', QD.LIST.filter(Q => Q.kind === 'diaria' && okQ(Q) && Q.band === band)],
    ['👑 Lendas — chefes dos locais especiais', QD.LIST.filter(Q => Q.kind === 'lenda' && okQ(Q) && S.c.level >= Q.lvl - 8)],
  ];
  const row = Q => { const ok = S.c.level >= Q.lvl; return `<div class="row"><div class="grow"><b>${qTag(Q)}${esc(Q.title)}</b> <span class="small">nv ${Q.lvl}</span><div class="small">${esc(Q.text)}</div><div class="small" style="color:#c5f5b0">${rewardTxt(Q.reward)}</div></div><button class="btn" data-acc="${Q.id}" ${ok ? '' : 'disabled'}>Aceitar</button><button class="btn alt" data-accg="${Q.id}" ${ok ? '' : 'disabled'} title="Aceitar e ligar o guia automático">🧭</button></div>`; };
  b.innerHTML = `<div class="small">"O Eclipse cresce a cada noite, aventureiro. Que tarefa aceitará?"</div>
  ${ready.length ? '<h4>Prontas para entregar</h4>' + ready.map(id => `<div class="row"><div class="grow"><b>${qTag(QD.QUESTS[id])}${esc(QD.QUESTS[id].title)}</b><div class="small">${rewardTxt(QD.QUESTS[id].reward)}</div></div><button class="btn" data-done="${id}">Concluir</button></div>`).join('') : ''}
  ${groups.map(([t, l]) => l.length ? `<h4>${t}</h4>` + l.map(row).join('') : '').join('') || '<div class="small">Nenhuma missão nova aqui por enquanto.</div>'}`;
  b.onclick = async e => { const a = e.target.dataset.acc || e.target.dataset.accg, d = e.target.dataset.done;
    if (a) { if (!S.q.active.includes(a)) { S.q.active.push(a); S.q.prog[a] = 0; saveQuests(); } toast('Missão aceita: ' + QD.QUESTS[a].title, 'ok'); if (e.target.dataset.accg) { closePanel(); startGuide(a); } else renderPanel(); }
    if (d) { const r = await safe(() => B.questDone(d)); if (!r) return; const Qd = QD.QUESTS[d]; S.c.quests = { ...(S.c.quests || {}), [d]: Qd.kind === 'diaria' ? todayStr() : true }; S.q.active = S.q.active.filter(x => x !== d); delete S.q.prog[d]; if (S.guide?.id === d) stopGuide(); saveQuests();
      toast(`📜 Missão concluída: ${Qd.title}!`, 'ok'); addChat({ kind: 'q', msg: `Recompensa: ${rewardTxt(r.reward)}` }); const L = S.c.level; await refresh(); if (S.c.level > L) { S.c.level = L; levelUp(r.level); } renderPanel(); } };
}
const rewardTxt = (r) => [r.xp ? `${Number(r.xp * GD.RATE_XP).toLocaleString('pt-BR')} XP` : '', r.aurum ? `${Number(r.aurum * GD.RATE_AURUM).toLocaleString('pt-BR')} aurum` : '', ...Object.entries(r.items || {}).map(([k, v]) => `${v}x ${iname(k)}`)].filter(Boolean).join(' • ');
function pQuests(b) {
  b.innerHTML = `<h4>Ativas</h4>${S.q.active.map(id => { const Q = QD.QUESTS[id]; return `<div class="row"><div class="grow"><b>${Q.main ? '★ ' : ''}${esc(Q.title)}</b><div class="small">${esc(Q.text)}</div><div class="small" style="color:#c5f5b0">${rewardTxt(Q.reward)}</div></div><button class="btn alt" data-gd="${id}">${S.guide?.id === id ? '⏹ Parar' : '🧭 Guiar'}</button><button class="btn red" data-ab="${id}">Abandonar</button></div>`; }).join('') || '<div class="small">Nenhuma. Visite o Arauto do Eclipse na praça de qualquer cidade.</div>'}
  <h4>Concluídas</h4><div class="small">${Object.keys(S.c.quests || {}).filter(id => QD.QUESTS[id] && QD.QUESTS[id].kind !== 'diaria').map(id => esc(QD.QUESTS[id].title)).join(' • ') || '—'}</div>`;
  b.onclick = e => { const g = e.target.dataset.gd; if (g) { if (S.guide?.id === g) stopGuide('Guia automático desligado'); else { closePanel(); startGuide(g); } return; } const id = e.target.dataset.ab; if (id && S.guide?.id === id) stopGuide(); if (id && confirm('Abandonar a missão?')) { S.q.active = S.q.active.filter(x => x !== id); delete S.q.prog[id]; saveQuests(); renderPanel(); } };
}
function pMap(b) {
  b.innerHTML = '<canvas id="bigmap" width="480" height="480" style="width:100%;border:1px solid #5a4630"></canvas><div class="small">Clique em uma cidade no mapa (GM) ou use o Guardião do Portal para viajar. 🟡 você • 🏰 cidades • ⚔️ terras de caça</div>';
  const c = $('#bigmap'), x = c.getContext('2d'), s = 480 / 3000; x.drawImage(mmBase, 0, 0, 480, 480);
  x.font = 'bold 11px Segoe UI'; x.textAlign = 'center';
  GD.TOWNS.forEach(t => { x.fillStyle = '#fff'; x.strokeStyle = '#000'; x.lineWidth = 3; x.strokeText('🏰 ' + t.name, t.x * s, t.z * s - 6); x.fillText('🏰 ' + t.name, t.x * s, t.z * s - 6); x.fillStyle = '#ffe36a'; x.strokeText(`Nv ${t.min}-${t.max}`, t.x * s, t.z * s + 8); x.fillText(`Nv ${t.min}-${t.max}`, t.x * s, t.z * s + 8);
    t.spotsPos.forEach(p => { x.fillStyle = '#ffb0a0'; x.strokeText('⚔ ' + p.name, p.x * s, p.z * s); x.fillText('⚔ ' + p.name, p.x * s, p.z * s); }); });
  x.fillStyle = '#ffe36a'; x.beginPath(); x.arc(me.x * s, me.z * s, 5, 0, 7); x.fill(); x.stroke();
  c.onclick = e => { if (!S.c.is_gm) return; const r = c.getBoundingClientRect(), wx = (e.clientX - r.left) / r.width * 3000, wz = (e.clientY - r.top) / r.height * 3000; if (!blocked(wx, wz)) { teleport(wx, wz); closePanel(); } };
}
function pLore(b) { b.innerHTML = `<div class="lore"><div class="logo small">${QD.LORE.title}</div>${QD.LORE.chapters.map(([h, t]) => `<h4>${h}</h4><p>${t}</p>`).join('')}</div>`; }
function pSys(b) {
  b.innerHTML = `<div class="row"><div class="grow">Qualidade gráfica <span class="small">(${Math.round(PERF.fps)} FPS agora • em uso: ${QUAL[PERF.cur].name})</span></div></div><div class="chips">${[['auto', 'Automática'], ['alta', 'Alta'], ['media', 'Média'], ['baixa', 'Baixa (celular fraco)']].map(([k, l]) => `<button data-q="${k}" class="${PERF.mode === k ? 'on' : ''}">${l}</button>`).join('')}</div>
  <div class="row"><div class="grow">Efeitos sonoros</div><button class="btn alt" id="sfxon">${SFX.on ? 'Ligados' : 'Desligados'}</button></div>
  <div class="row"><div class="grow">Música ambiente</div><button class="btn alt" id="muson">${SFX.music ? 'Ligada' : 'Desligada'}</button></div>
  <div class="row"><div class="grow">Vozes dos NPCs</div><button class="btn alt" id="vz">${VOICE.on ? 'Ligadas' : 'Desligadas'}</button></div>
  <div class="row"><div class="grow">Sombras</div><button class="btn alt" id="sh">${renderer.shadowMap.enabled ? 'Ligadas' : 'Desligadas'}</button></div>
  <div class="row"><div class="grow">Controles</div></div><div class="small">Clique esquerdo: andar / selecionar • clique de novo no alvo (ou duplo clique): atacar • Ctrl + clique: atacar jogador (PvP) • botão direito arrastando: girar câmera • roda: zoom • WASD: andar • Shift: correr • Q: esquivar • R: montar • V: voar (Espaço sobe, X desce) • J: compêndio • 1–7 ou F1–F7: habilidades • Espaço/F: atacar • Tab: próximo alvo • 8/9: poções • Enter: chat • C, I, K, L, M, H: janelas</div>
  <button class="primary" id="tochars">Trocar de personagem</button><button class="link" id="lo">Sair da conta</button>`;
  b.onclick = async e => { const qm = e.target.dataset.q; if (qm) { PERF.mode = qm; localStorage.setItem('vt_qual', qm); if (qm !== 'auto') applyQuality(qm); renderPanel(); return; } if (e.target.id === 'sh') { renderer.shadowMap.enabled = !renderer.shadowMap.enabled; scene.traverse(o => { if (o.material) o.material.needsUpdate = true; }); renderPanel(); }
    if (e.target.id === 'vz') { setVoice(!VOICE.on); renderPanel(); return; }
    if (e.target.id === 'sfxon') { SFX.on = !SFX.on; saveSfx(); renderPanel(); return; } if (e.target.id === 'muson') { SFX.music = !SFX.music; saveSfx(); renderPanel(); return; }
    if (e.target.id === 'tochars') { await saveNow(); location.reload(); } if (e.target.id === 'lo') { await saveNow(); await B.logout(); location.reload(); } };
}
function pGm(b) {
  if (!S.c.is_gm) return; const pl = Object.entries(S.presence).map(([id, p]) => ({ id, name: p[0]?.name, gm: p[0]?.gm })).filter(p => p.name);
  b.innerHTML = `<h4>Online (${pl.length})</h4>${pl.map(p => `<div class="row"><div class="grow">${p.gm ? '👑 ' : ''}${esc(p.name)}</div>${p.id === S.c.id ? '<span class="small">você</span>' : ['ir', 'puxar', 'info', 'kick', 'ban'].map(k => `<button class="btn ${k === 'kick' || k === 'ban' ? 'red' : 'alt'}" data-g="${k}" data-n="${esc(p.name)}" data-id="${p.id}">${k}</button>`).join('')}</div>`).join('')}
  <h4>Dar item</h4><div class="field"><select id="gi">${Object.values(GD.ITEMS).map(i => `<option value="${i.id}">[${GD.GRADES[i.grade].id}] ${esc(i.name)}</option>`).join('')}</select><input id="gq" type="number" value="10" style="max-width:70px"><input id="ga" placeholder="Jogador (vazio = você)"></div><button class="btn" id="gib">Entregar</button>
  <h4>Nível / Profissões / Aurum</h4><div class="field"><input id="gl" type="number" value="20" style="max-width:70px"><button class="btn" id="glb">Definir nível</button><select id="gp"><option value="coleta">Coleta</option><option value="refino">Refino</option><option value="forja">Forja</option></select><input id="gpl" type="number" value="20" style="max-width:60px"><button class="btn" id="gpb">Profissão</button></div>
  <div class="field"><input id="gau" type="number" value="100000"><button class="btn" id="gaub">Dar aurum</button></div>
  <h4>Teleporte rápido</h4><div class="chips">${GD.TOWNS.map(t => `<button data-tp="${t.id}">${esc(t.name)}</button>`).join('')}</div>
  <h4>Ferramentas</h4><div class="field"><button class="btn alt" id="gv">Velocidade x3</button><button class="btn alt" id="gd">Invencível: ${S.god ? 'ON' : 'OFF'}</button><button class="btn alt" id="gr">Renascer recursos</button><button class="btn alt" id="gk">Kit de teste</button></div>
  <div class="chips">${GD.MOBS.map(g => g[2]).map(f => `<button data-sp="${f.id}">👑 ${esc(f.name)}</button>`).join('')}</div>
  <h4>Anúncio global</h4><div class="field"><input id="gan" placeholder="Mensagem para todos"><button class="btn" id="ganb">Anunciar</button></div>
  <h4>Promover GM</h4><div class="field"><input id="ggm" placeholder="Nome do personagem"><button class="btn" id="ggmb">Tornar GM</button><button class="btn red" id="ggmr">Remover</button></div>`;
  b.onclick = async e => { const t = e.target, say = r => r && toast(r, 'ok');
    if (t.dataset.g) { if (t.dataset.g === 'ir') { const o = S.others[t.dataset.id]; if (o) { teleport(o.x + 2, o.z); closePanel(); } else toast('Sem posição desse jogador ainda', 'err'); } else if (t.dataset.g === 'puxar') say(await safe(() => B.gm('puxar', { alvo: t.dataset.n, x: me.x + 2, z: me.z }))); else { const r = await safe(() => B.gm(t.dataset.g, { alvo: t.dataset.n })); if (r) addChat({ kind: 'sys', msg: r }); } }
    if (t.id === 'gib') { say(await safe(() => B.gm('give', { item: $('#gi').value, qtd: +$('#gq').value || 1, alvo: $('#ga').value.trim() || undefined }))); await refresh(); }
    if (t.id === 'glb') { say(await safe(() => B.gm('nivel', { nivel: +$('#gl').value }))); await refresh(); S.hp = stats().maxHp; buildBar(); }
    if (t.id === 'gpb') { say(await safe(() => B.gm('prof', { prof: $('#gp').value, nivel: +$('#gpl').value }))); await refresh(); }
    if (t.id === 'gaub') { say(await safe(() => B.gm('aurum', { qtd: +$('#gau').value }))); await refresh(); }
    if (t.dataset.tp) { const tw = GD.TOWNS.find(x => x.id === t.dataset.tp); teleport(tw.x, tw.z + 25); closePanel(); }
    if (t.id === 'gv') command('/vel'); if (t.id === 'gd') { S.god = !S.god; renderPanel(); }
    if (t.id === 'gr') command('/reset');
    if (t.id === 'gk') { for (const g of ['ng', 'd', 'c']) for (const r of ['madeira', 'minerio', 'fibra', 'pele']) await B.gm('give', { item: `${r}_${g}`, qtd: 40 }); await B.gm('give', { item: 'gema', qtd: 5 }); await B.gm('aurum', { qtd: 50000 }); await refresh(); toast('Kit de teste entregue', 'ok'); }
    if (t.dataset.sp) { spawnMob(FAM[t.dataset.sp], Math.max(S.c.level, FAM[t.dataset.sp].grade ? GD.TOWNS[FAM[t.dataset.sp].grade].max : 19), me.x + 8, me.z + 8); closePanel(); }
    if (t.id === 'ganb') await safe(() => B.gm('anuncio', { msg: $('#gan').value }), 'Anunciado');
    if (t.id === 'ggmb' || t.id === 'ggmr') say(await safe(() => B.gm('setgm', { alvo: $('#ggm').value.trim(), on: t.id === 'ggmb' })));
  };
}

// ---------- barra de habilidades e HUD ----------
// ----- barra de atalhos (estilo Lineage II): 12 espaços para habilidades e itens da bolsa -----
const BAR_N = 9, BAR_PAGES = 3, BAR_KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
function barKey() { return 'vt_bar_' + S.c.id; }
function defaultBar() { const st = stats(), sk = st.arch.skills.slice().sort((a, b) => a.lvl - b.lvl).map(s => ({ t: 's', id: s.id })); const out = []; for (let i = 0; i < BAR_N * BAR_PAGES; i++) out.push(sk[i] || null); return out; }
function loadBar() { S.barPage = 0; try { const b = JSON.parse(localStorage.getItem(barKey())); if (Array.isArray(b) && b.length === BAR_N * BAR_PAGES) { S.barAll = b; return; } if (Array.isArray(b)) { const d = defaultBar(); b.filter(e => e && e.t === 's').slice(0, 9).forEach((e, i) => d[i] = e); S.barAll = d; return; } } catch (_) {} S.barAll = defaultBar(); }
Object.defineProperty(S, 'bar', { get() { if (!S.barAll) return null; const o = S.barPage * BAR_N; return new Proxy(S.barAll, { get: (a, k) => k === 'length' ? BAR_N : typeof k === 'string' && /^\d+$/.test(k) ? a[o + +k] : k === 'map' || k === 'findIndex' || k === 'some' || k === 'filter' || k === 'forEach' ? (f) => a.slice(o, o + BAR_N)[k](f) : a[k], set: (a, k, v) => { if (/^\d+$/.test(k)) a[o + +k] = v; return true; } }); }, set(v) { S.barAll = v; }, configurable: true });
function saveBar() { localStorage.setItem(barKey(), JSON.stringify(S.barAll)); }
function skillIndex(id) { return stats().arch.skills.findIndex(s => s.id === id); }
function useSlot(n) { const e = S.bar[n]; if (!e) return; if (e.t === 's') { const i = skillIndex(e.id); if (i >= 0) castSkill(i); } else useBagItem(e.id); }
// equipar com a regra de pegada: arma de duas mãos (ou par de armas) não aceita escudo
async function equipItem(id) { const it = IT(id), eq = S.c.equipment || {}, w = IT(eq.arma);
  if (it.slot === 'escudo' && w && GD.TWO_HANDED.includes(w.kind)) { toast(`${w.name} ocupa as duas mãos — troque por uma arma de uma mão (espada ou machado) para usar escudo`, 'err'); return null; }
  let r = await safe(() => B.equip(id), 'Equipado'); if (!r) return null;
  if (it.slot === 'arma' && GD.TWO_HANDED.includes(it.kind) && r.escudo) { const r2 = await safe(() => B.unequip('escudo')); if (r2) { r = r2; toast('🛡️ Escudo guardado: esta arma usa as duas mãos'); } }
  return r; }
async function useBagItem(id) { const it = IT(id); if (!it) return; if (!S.inv[id]) { toast(`Sem ${it.name} na bolsa`, 'err'); return; }
  if (it.type === 'scroll') { const r = await safe(() => B.useItem(id)); if (r) { S.inv[id]--; if (!S.inv[id]) delete S.inv[id]; toast('Retornando a ' + r.town, 'ok'); teleport(r.x, r.z); } }
  else if (it.type === 'potion') await usePotion(id.startsWith('pocao_mp') ? 'mp' : 'hp', id);
  else if (it.slot) { const r = await equipItem(id); if (r) { S.c.equipment = r; await refresh(); (me.enc = encOf(S.c), setGear(me, r.arma, r.armadura, r)); } }
  buildBar(); }
function buildBar() {
  buildBar2();
  if (!S.barAll) loadBar(); const st = stats();
  $('#bar').innerHTML = `<div class="bpage" title="Página da barra (tecla ao lado do 1, ou clique)"><button data-pg="-1">▲</button><b>${S.barPage + 1}</b><button data-pg="1">▼</button></div>` + S.bar.map((e, n) => {
    let inner = '', title = 'Vazio — arraste uma habilidade (K) ou item da bolsa (I) para cá', cls = 'empty';
    if (e && e.t === 's') { const s = st.arch.skills.find(x => x.id === e.id); if (s) { inner = s.icon + '<div class="cd" hidden></div>'; title = `${s.name} • nível ${s.lvl} • ${s.mp} MP • ${s.cd}s`; cls = S.c.level < s.lvl ? 'off' : ''; } }
    else if (e && e.t === 'i') { const it = IT(e.id); if (it) { inner = (it.icon || '📦') + `<span class="n">${S.inv[e.id] || 0}</span>`; title = it.name; cls = S.inv[e.id] ? '' : 'off'; } }
    return `<div class="sk ${cls} ${e && e.t === 's' ? 'skill t-' + (st.arch.skills.find(x => x.id === e.id)?.type || '') : ''}" data-n="${n}" title="${esc(title)}" draggable="${!!e}"><span class="key">${BAR_KEYS[n]}</span>${inner}</div>`;
  }).join('') + `<div class="sk pot" data-pot="hp" title="Poção de vida (0)"><span class="key">0</span>🧪<span class="n">${(S.inv.pocao_hp || 0) + (S.inv.pocao_hp2 || 0)}</span></div><div class="sk pot" data-pot="mp" title="Poção de mana (-)"><span class="key">-</span>💧<span class="n">${S.inv.pocao_mp || 0}</span></div>`;
  const bar = $('#bar');
  bar.onclick = e => { const pg = e.target.closest('[data-pg]'); if (pg) { S.barPage = (S.barPage + +pg.dataset.pg + BAR_PAGES) % BAR_PAGES; buildBar(); return; } const k = e.target.closest('.sk'); if (!k) return; if (k.dataset.pot) { usePotion(k.dataset.pot); return; } useSlot(+k.dataset.n); };
  bar.oncontextmenu = e => { e.preventDefault(); const k = e.target.closest('.sk'); if (!k) return; S.bar[+k.dataset.n] = null; saveBar(); buildBar(); };
  bar.ondragstart = e => { const k = e.target.closest('.sk'); if (k) e.dataTransfer.setData('text/plain', JSON.stringify({ from: +k.dataset.n })); };
  bar.ondragover = e => e.preventDefault();
  bar.ondrop = e => { e.preventDefault(); const k = e.target.closest('.sk'); if (!k) return; let d; try { d = JSON.parse(e.dataTransfer.getData('text/plain')); } catch (_) { return; } const n = +k.dataset.n;
    if (d.from != null) { const tmp = S.bar[n]; S.bar[n] = S.bar[d.from]; S.bar[d.from] = tmp; } else if (d.t) S.bar[n] = { t: d.t, id: d.id }; saveBar(); buildBar(); };
}
// ---------- barra extra (9 atalhos só de clique) ----------
function loadBar2() { try { const b = JSON.parse(localStorage.getItem(barKey() + '_x')); S.bar2 = Array.isArray(b) && b.length === 9 ? b : Array(9).fill(null); } catch (_) { S.bar2 = Array(9).fill(null); } }
function buildBar2() { const el = $('#bar2'); if (!el) return; if (!S.bar2 || S.bar2Key !== barKey()) { S.bar2Key = barKey(); loadBar2(); } const st = stats();
  el.innerHTML = S.bar2.map((e, n) => { let inner = '', title = 'Atalho extra (só clique) — arraste uma habilidade (K) ou item (I) para cá', cls = 'empty';
    if (e && e.t === 's') { const s = st.arch.skills.find(x => x.id === e.id); if (s) { inner = s.icon; title = s.name; cls = S.c.level < s.lvl ? 'off' : ''; } } else if (e && e.t === 'i') { const it = IT(e.id); if (it) { inner = (it.icon || '📦') + `<span class="n">${S.inv[e.id] || 0}</span>`; title = it.name; cls = S.inv[e.id] ? '' : 'off'; } }
    return `<div class="sk ${cls}" data-n="${n}" title="${esc(title)}">${inner}</div>`; }).join('');
  el.onclick = e => { const k = e.target.closest('.sk'); if (!k) return; const en = S.bar2[+k.dataset.n]; if (!en) return; if (en.t === 's') { const i = skillIndex(en.id); if (i >= 0) castSkill(i); } else useBagItem(en.id); };
  el.oncontextmenu = e => { e.preventDefault(); const k = e.target.closest('.sk'); if (!k) return; S.bar2[+k.dataset.n] = null; localStorage.setItem(barKey() + '_x', JSON.stringify(S.bar2)); buildBar2(); };
  el.ondragover = e => e.preventDefault();
  el.ondrop = e => { e.preventDefault(); const k = e.target.closest('.sk'); if (!k) return; let d; try { d = JSON.parse(e.dataTransfer.getData('text/plain')); } catch (_) { return; } const n = +k.dataset.n; if (d.from != null) S.bar2[n] = S.bar[d.from]; else if (d.t) S.bar2[n] = { t: d.t, id: d.id }; localStorage.setItem(barKey() + '_x', JSON.stringify(S.bar2)); buildBar2(); }; }
// ---------- aba de equipamento com boneco 3D ----------
const EQX = { esc,
  data() { const c = S.c, eq = c.equipment || {}, st = stats(), slots = {}, locked = {};
    for (const k of ['elmo', 'armadura', 'luvas', 'botas', 'arma', 'escudo']) { const it = IT(eq[k]); if (it) slots[k] = { id: it.id, name: it.name, html: icImg(it, true), enc: (c.enchant || {})[it.id], desc: itemDesc(it.id) }; }
    const cmp = (k, id) => { const it = IT(id); if (it) slots[k] = { id, name: it.name, html: it.icon, desc: itemDesc(id) }; }; cmp('asas', COMP.wingsId); cmp('montaria', COMP.mountId); cmp('pet', COMP.petId);
    const w = IT(eq.arma); if (w && GD.TWO_HANDED.includes(w.kind)) locked.escudo = 'Bloqueado: a arma atual usa as duas mãos';
    for (const k of ['colar', 'anel1', 'anel2', 'brinco', 'capa', 'reliquia']) locked[k] = 'Acessório especial — conquistado em chefes e eventos (em breve)'; locked.insignia = 'Insígnia do clã — chega com o sistema de clãs';
    const el = myElem(), E = ELEM[el], re = ELEM[GD.RACE_ELEM[c.race]];
    return { slots, locked, sig: JSON.stringify([eq, COMP.wingsId, c.enchant && c.enchant[eq.arma], c.race]),
      stats: `<b>${esc(c.name)}</b> • Nv. ${c.level}<br>⚔️ ${Math.round(st.patk)} &nbsp;🔮 ${Math.round(st.matk)} &nbsp;🛡️ ${Math.round(st.pdef)} &nbsp;✨ ${Math.round(st.mdef)}<br>${E ? `${E.icon} Elemento da classe: <b>${E.name}</b>` : ''}${re ? ` • ${re.icon} Afinidade da raça: <b>${re.name}</b>` : ''}<br>${w ? (GD.TWO_HAND_GRIP.includes(w.kind) ? '🤲 Pegada de duas mãos' : GD.TWO_HANDED.includes(w.kind) ? '⚔️ Uma arma em cada mão' : '✋ Uma mão — pode usar escudo') : '👊 Desarmado'}`,
      foot: `<button class="btn" data-act="bag">🎒 Abrir bolsa</button> ${COMP.wingsId ? `<button class="btn" data-act="fly">🪽 ${S.fly ? 'Pousar' : 'Voar'} (V)</button>` : '<span class="small">Equipe asas (use-as na bolsa) para voar</span>'} ${COMP.mountId ? '<button class="btn" data-act="ride">🐎 Montar (R)</button>' : ''}` }; },
  async onSlot(k) { const eq = S.c.equipment || {};
    if (['elmo', 'armadura', 'luvas', 'botas', 'arma', 'escudo'].includes(k)) { if (!eq[k]) { openPanel('bag'); return; } const r = await safe(() => B.unequip(k), 'Desequipado'); if (r) { S.c.equipment = r; await refresh(); me.enc = encOf(S.c); setGear(me, r.arma, r.armadura, r); buildBar(); renderEquip(); } }
    else if (k === 'asas') { COMP.wingsId ? setWings(COMP.wingsId) : openPanel('bag'); renderEquip(); } else if (k === 'montaria') { COMP.mountId ? toggleRide() : openPanel('bag'); } else if (k === 'pet') { COMP.petId ? summonPet(COMP.petId) : openPanel('bag'); renderEquip(); }
    else toast('Este espaço será liberado com acessórios de chefes, eventos e do clã', 'err'); },
  onAct(a) { if (a === 'bag') openPanel('bag'); else if (a === 'fly') { toggleFly(); renderEquip(); } else if (a === 'ride') toggleRide(); },
  makeDoll() { const c = S.c, d = buildHumanoid({ ...c, glb: true, weapon: c.equipment.arma, armor: c.equipment.armadura, equip: c.equipment, enc: encOf(c) }); upgradeGLB(d); d.height = 1.8 * (GD.RACES[c.race]?.h || 1);
    if (COMP.wingsId) { const wd = IT(COMP.wingsId)?.comp, h = GD.RACES[c.race]?.h || 1; if (wd) d.root.add(buildWings(wd.color, 0.9 * h, 1.32 * h, -0.16)); } return d; },
  animDoll(d, dt) { animHumanoid(d, dt); } };
let eqSig = '';
function equipWatch() { if (!equipOpen()) return; const s = JSON.stringify([S.c.equipment, COMP.wingsId, COMP.mountId, COMP.petId, S.fly, S.c.enchant]); if (s !== eqSig) { eqSig = s; renderEquip(); } }
function addToBar(entry) { let n = S.bar.findIndex(e => e && e.t === entry.t && e.id === entry.id); if (n >= 0) { toast('Já está na barra', 'err'); return; } n = S.bar.findIndex(e => !e); if (n < 0) { toast('Barra cheia — clique com o botão direito num atalho para liberar', 'err'); return; } S.bar[n] = entry; saveBar(); buildBar(); toast('Adicionado à barra (tecla ' + BAR_KEYS[n] + ')', 'ok'); }
function updateHud() {
  const c = S.c, st = stats(), need = GD.xpNeed(c.level);
  $('#st-name').innerHTML = `<span style="color:${nameColor({ gm: c.is_gm, karma: c.karma, flag: S.flagUntil > Date.now() })}">${c.is_gm ? '[GM] ' : ''}${esc(c.name)}</span> <span class="small">Nv. ${c.level}</span>`;
  $('#st-class').textContent = `${GD.RACES[c.race].name} • ${st.cls.name}`;
  $('#b-hp').style.width = Math.max(0, 100 * S.hp / st.maxHp) + '%'; $('#t-hp').textContent = `${Math.ceil(Math.max(0, S.hp))} / ${st.maxHp}`;
  $('#b-st').style.width = (S.sta ?? 100) + '%'; $('#b-mp').style.width = 100 * S.mp / st.maxMp + '%'; $('#t-mp').textContent = `${Math.floor(S.mp)} / ${st.maxMp}`;
  $('#b-xp').style.width = c.level >= 80 ? '100%' : Math.min(100, 100 * c.xp / need) + '%'; $('#t-xp').textContent = c.level >= 80 ? 'NÍVEL MÁXIMO' : `${(100 * c.xp / need).toFixed(2)}%`;
  const bv = Object.entries(S.buffs).filter(([k]) => !['invuln', 'lifesteal', 'dodge', 'gmspeed'].includes(k)).map(([k, b]) => `${b.icon || '✨'}${Math.ceil((b.until - now()) / 1000)}s`).join(' ');
  $('#st-extra').innerHTML = `🪙 ${Number(c.aurum).toLocaleString('pt-BR')}${c.karma ? ` • <span style="color:#f66">Karma ${c.karma}</span>` : ''}${S.flagUntil > Date.now() ? ' • <span style="color:#d38cff">PvP</span>' : ''} ${bv}`;
  const t = S.target; $('#target').hidden = !t || t.ref.dead;
  if (t && !t.ref.dead) { if (t.kind === 'mob') { $('#tg-name').innerHTML = `${t.ref.fam.boss ? '👑 ' : ''}${esc(t.ref.fam.name)} <span class="small">Nv. ${t.ref.L}</span>`; $('#tg-hp').style.width = 100 * t.ref.hp / t.ref.maxHp + '%'; $('#tg-act').innerHTML = ''; }
    else if (t.kind === 'player') { $('#tg-name').innerHTML = `${esc(t.ref.n)} <span class="small">Nv. ${t.ref.l}${t.ref.k ? ' • Karma' : ''}${t.ref.f ? ' • PvP' : ''}</span>`; $('#tg-hp').style.width = (t.ref.hpPct ?? 100) + '%'; $('#tg-act').innerHTML = '<button class="btn red" id="tg-atk">Atacar (Ctrl+clique)</button>'; $('#tg-atk').onclick = () => S.autoAtk = true; }
    else if (t.kind === 'npc') { $('#tg-name').textContent = t.ref.name; $('#tg-hp').style.width = '100%'; $('#tg-act').innerHTML = ''; }
    else if (t.kind === 'node') { $('#tg-name').innerHTML = `${{ madeira: 'Árvore', minerio: 'Veio de Minério', fibra: 'Algodoeiro' }[t.ref.type]} <span class="small">grau ${GD.GRADES[t.ref.grade].id}</span>`; $('#tg-hp').style.width = '100%'; $('#tg-act').innerHTML = ''; } }
  const tt = now(); document.querySelectorAll('#bar .sk.skill').forEach(el => { const e = S.bar[+el.dataset.n]; if (!e) return; const i = skillIndex(e.id); if (i < 0) return; const cd = (S.cds[i] || 0) - tt, d = el.querySelector('.cd'); if (!d) return; d.hidden = cd <= 0; if (cd > 0) d.textContent = Math.ceil(cd / 1000); el.classList.toggle('off', S.c.level < st.arch.skills[i].lvl || S.mp < st.arch.skills[i].mp); });
  document.querySelectorAll('#bar .sk .n').forEach(el => { const e = S.bar[+el.parentNode.dataset.n]; if (e) el.textContent = S.inv[e.id] || 0; });
  $('#n-hp') && ($('#n-hp').textContent = (S.inv.pocao_hp || 0) + (S.inv.pocao_hp2 || 0)); $('#n-mp') && ($('#n-mp').textContent = S.inv.pocao_mp || 0);
  $('#coords').textContent = `${Math.round(me.x)}, ${Math.round(me.z)}`;
}
let mmBase = null;
function buildMinimapBase() {
  const N = 300, cv = document.createElement('canvas'); cv.width = cv.height = N; const x = cv.getContext('2d'), im = x.createImageData(N, N), c = new THREE.Color();
  for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) { const wx = (i + 0.5) * 10, wz = (j + 0.5) * 10, h = WG.height(wx, wz); if (h < WG.WATER + 0.3) c.set('#2a5a90'); else terrainColor(wx, wz, h, c); const k = (j * N + i) * 4; im.data[k] = c.r * 255; im.data[k + 1] = c.g * 255; im.data[k + 2] = c.b * 255; im.data[k + 3] = 255; }
  x.putImageData(im, 0, 0); mmBase = cv;
}
function drawMinimap() {
  const cv = $('#minimap'), x = cv.getContext('2d'), R = 250, s = 180 / (2 * R);
  x.save(); x.clearRect(0, 0, 180, 180); x.beginPath(); x.arc(90, 90, 90, 0, 7); x.clip();
  x.drawImage(mmBase, (me.x - R) / 10, (me.z - R) / 10, 2 * R / 10, 2 * R / 10, 0, 0, 180, 180);
  const P = (wx, wz) => [90 + (wx - me.x) * s, 90 + (wz - me.z) * s];
  S.mobs.forEach(m => { if (m.dead) return; const [a, b] = P(m.x, m.z); x.fillStyle = m.fam.boss ? '#ff00ff' : '#ff4040'; x.fillRect(a - 1.5, b - 1.5, 3, 3); });
  Object.values(S.others).forEach(o => { const [a, b] = P(o.x, o.z); x.fillStyle = o.k ? '#ff3030' : '#40c0ff'; x.beginPath(); x.arc(a, b, 3, 0, 7); x.fill(); });
  GD.TOWNS.forEach(t => { const [a, b] = P(t.x, t.z); x.fillStyle = '#ffe36a'; x.font = 'bold 10px Segoe UI'; x.textAlign = 'center'; x.fillText('🏰', a, b + 4); });
  x.translate(90, 90); x.rotate(-cam.yaw + Math.PI); x.fillStyle = '#fff'; x.beginPath(); x.moveTo(0, -7); x.lineTo(5, 5); x.lineTo(0, 2); x.lineTo(-5, 5); x.fill(); x.restore();
  x.strokeStyle = '#5a4630'; x.lineWidth = 2; x.beginPath(); x.arc(90, 90, 89, 0, 7); x.stroke();
}

// ---------- telas: entrada, seleção e criação ----------
let mode = 'entrar';
document.querySelectorAll('.tabs button').forEach(b => b.onclick = () => { mode = b.dataset.tab; document.querySelectorAll('.tabs button').forEach(x => x.classList.toggle('on', x === b)); $('#btn-go').textContent = mode === 'criar' ? 'Criar conta' : 'Entrar'; });
$('#btn-go').onclick = async () => {
  if (!B || !B.online) { $('#login-msg').textContent = 'Servidor online ainda não configurado — use o modo offline.'; return; }
  $('#btn-go').disabled = true; $('#login-msg').textContent = '…';
  try { if (mode === 'criar') await B.signup($('#f-user').value, $('#f-pass').value); else await B.login($('#f-user').value, $('#f-pass').value); await toSelect(); } catch (e) { $('#login-msg').textContent = e.message; }
  $('#btn-go').disabled = false;
};
$('#f-pass').addEventListener('keydown', e => { if (e.key === 'Enter') $('#btn-go').click(); });
$('#btn-offline').onclick = async () => { B = new LocalBackend(); await toSelect(); };
// estúdio 3D para seleção/criação
const studio = new THREE.Group(); scene.add(studio); studio.visible = false;
let preview = null;
function setupStudio() {
  studio.clear(); const g = new THREE.Mesh(new THREE.CylinderGeometry(3, 3.3, 0.4, 40), mat('#3a3040', { metal: 0.3, rough: 0.5 })); g.position.y = -0.2; g.receiveShadow = true; studio.add(g);
  const r = new THREE.Mesh(new THREE.TorusGeometry(3.05, 0.05, 6, 60), mat('#f2c46d', { emissive: 0xb08020, ei: 0.8 })); r.rotation.x = Math.PI / 2; studio.add(r);
  studio.position.set(0, -500, 0);
}
function showPreview(o) { if (preview) { studio.remove(preview.root); preview.disposed = true; } preview = buildHumanoid(o); studio.add(preview.root); }
async function toSelect() {
  show('#loading'); $('#loading').hidden = false;
  const d = await B.chars(); S.acct = d; S.chars = d.chars; show('#select'); S.selected = 0; setupStudio(); studio.visible = true; renderSelect();
}
function renderSelect() {
  $('#char-list').innerHTML = S.chars.map((c, i) => `<div class="cslot ${i === S.selected ? 'on' : ''}" data-i="${i}"><div style="font-size:26px">${c.type === 'm' ? '🔮' : '⚔️'}</div><div class="grow"><b>${esc(c.name)}</b><div class="small">${GD.RACES[c.race].name} • ${GD.CLASSES[c.class_id]?.name} • Nv. ${c.level}</div></div></div>`).join('') || '<div class="small">Nenhum personagem ainda. Crie o seu!</div>';
  $('#btn-new').hidden = S.chars.length >= 3;
  const c = S.chars[S.selected];
  if (c) { showPreview({ ...c, weapon: c.equipment.arma, armor: c.equipment.armadura, equip: c.equipment }); $('#char-info').innerHTML = `<div class="logo small">${esc(c.name)}</div><div class="small">${GD.RACES[c.race].name} • ${GD.TYPES[c.type]} • ${GD.CLASSES[c.class_id]?.name} • Nível ${c.level}</div><button class="primary" id="btn-play">Entrar no mundo</button><button class="link" id="btn-del">Excluir personagem</button>`;
    $('#btn-play').onclick = () => enterWorld(c.id); $('#btn-del').onclick = async () => { if (prompt(`Digite o nome "${c.name}" para excluir:`) !== c.name) return; await safe(() => B.deleteChar(c.id), 'Personagem excluído'); toSelect(); }; }
  else { if (preview) studio.remove(preview.root); preview = null; $('#char-info').innerHTML = `<div class="lore"><div class="logo small">${QD.LORE.title}</div><p>${QD.LORE.chapters[3][1]}</p></div>`; }
  $('#char-list').onclick = e => { const s = e.target.closest('.cslot'); if (s) { S.selected = +s.dataset.i; renderSelect(); } };
}
$('#btn-logout').onclick = async () => { await B.logout(); location.reload(); };
const CO = { race: 'humano', type: 'l', gender: 'm', hair: 0, hair_color: 0, skin: 0, face: 0, eyes: 0, eye_color: 0, scar: 0, beard: 0 };
const lookOf = (o) => ({ face: o.face, eyes: o.eyes, eye_color: o.eye_color, scar: o.scar, beard: o.beard, hair: o.hair, hair_color: o.hair_color, skin: o.skin });
$('#btn-new').onclick = () => { show('#create'); renderCreate(); };
$('#btn-cancel').onclick = () => { show('#select'); renderSelect(); };
function chips(el, opts, key) { $(el).innerHTML = opts.map(([v, l, st]) => `<button data-v="${v}" class="${CO[key] == v ? 'on' : ''}" ${st ? `style="${st}"` : ''}>${l}</button>`).join(''); $(el).onclick = e => { const v = e.target.dataset.v; if (v == null) return; CO[key] = isNaN(+v) ? v : +v; if (key === 'race' && !GD.RACES[CO.race].types.includes(CO.type)) CO.type = 'l'; if (key === 'race' || key === 'gender') { if (key === 'race') { CO.skin = 0; CO.eye_color = 0; } CO.beard = GD.RACES[CO.race].feat.beard && CO.gender === 'm' ? 2 : 0; } if (key === 'expr') { preview && preview.setExpr(v, 0); return; } renderCreate(); }; }
function renderCreate() {
  const R = GD.RACES[CO.race];
  chips('#c-race', Object.entries(GD.RACES).map(([k, r]) => [k, r.name]), 'race'); $('#c-race-desc').textContent = R.desc;
  chips('#c-type', R.types.map(t => [t, GD.TYPES[t]]), 'type'); chips('#c-gender', [['m', 'Masculino'], ['f', 'Feminino']], 'gender');
  chips('#c-hair', GD.HAIR_STYLES.map((n, i) => [i, n]), 'hair');
  chips('#c-face', GD.FACES.map((n, i) => [i, n]), 'face'); chips('#c-eyes', GD.EYE_SHAPES.map((n, i) => [i, n]), 'eyes');
  chips('#c-ecol', R.eyes.map((c, i) => [i, '&nbsp;&nbsp;', `background:${c};min-width:26px`]), 'eye_color'); chips('#c-scar', GD.SCARS.map((n, i) => [i, n]), 'scar');
  $('#c-beard-wrap').hidden = CO.gender === 'f' || !!R.feat.snout; chips('#c-beard', GD.BEARDS.map((n, i) => [i, n]), 'beard');
  chips('#c-expr', Object.entries(GD.EXPRESSIONS), 'expr');
  chips('#c-hcol', GD.HAIR_COLORS.map((c, i) => [i, '&nbsp;&nbsp;', `background:${c};min-width:26px`]), 'hair_color');
  chips('#c-skin', R.skins.map((c, i) => [i, '&nbsp;&nbsp;', `background:${c};min-width:26px`]), 'skin');
  const base = GD.baseClass(CO.race, CO.type), arch = GD.ARCH[base.arch];
  showPreview({ ...CO, look: lookOf(CO), weapon: arch.weapon + '_ng', armor: arch.armor + '_ng', equip: arch.shield ? { escudo: 'escudo_ng' } : {} });
  const ex = Object.values(GD.CLASSES).filter(c => c.race === CO.race && c.excl && c.rank === 1).map(c => c.name); $('#c-race-desc').innerHTML = esc(R.desc) + (ex.length ? `<br><b>Classes exclusivas:</b> ${ex.map(esc).join(' e ')}` : '');
  const rec = (id, d) => GD.nextClasses(id).map(c => `<div class="t${d}">↳ ${esc(c.name)} <span class="small">(nv ${GD.RANK_LVL[c.rank]} • ${GD.ARCH[c.arch].name}${c.bonus ? ' • bônus de ' + c.bonus : ''})</span></div>${rec(c.id, d + 1)}`).join('');
  $('#class-tree').innerHTML = `<div class="logo small">Árvore de classes</div><div class="tree"><div class="t1"><b>${esc(base.name)}</b> <span class="small">(classe base • ${arch.name})</span></div>${rec(base.id, 2)}</div><p class="small">As trocas de classe acontecem nos níveis 20, 40 e 76, com o Mestre de Classes. Só aparecem os caminhos compatíveis com a sua raça e tipo.</p>`;
}
$('#btn-create').onclick = async () => {
  $('#create-msg').textContent = '';
  try { await B.createChar({ ...CO, look: lookOf(CO), name: $('#c-name').value.trim() }); const d = await B.chars(); S.chars = d.chars; S.selected = S.chars.length - 1; show('#select'); renderSelect(); }
  catch (e) { $('#create-msg').textContent = e.message; }
};

async function refresh() {
  const st = await B.state(); const keepLvl = S.c ? S.c.level : null;
  S.c = { ...st.char, x: me ? me.x : st.char.x, z: me ? me.z : st.char.z }; S.inv = st.inventory || {}; S.dep = {}; for (const [k, v] of Object.entries(st.depleted || {})) S.dep[k] = +v;
  if (keepLvl && S.c.level !== keepLvl && me) { const L = S.c.level; S.c.level = keepLvl; levelUp(L); }
  renderTracker();
}
async function enterWorld(id) {
  show('#loading'); $('#loading-msg').textContent = 'Entrando em Valtheria…'; B.use(id);
  await new Promise(r => setTimeout(r, 30));
  const st = await B.state(); S.c = st.char; S.inv = st.inventory || {}; for (const [k, v] of Object.entries(st.depleted || {})) S.dep[k] = +v;
  studio.visible = false; if (!npcs.length) buildTowns(); if (!mmBase) buildMinimapBase();
  S.bar = null; makeMe(); const s = stats(); S.hp = S.c.hp > 0 && S.c.hp <= s.maxHp ? S.c.hp : s.maxHp; S.mp = S.c.mp > 0 && S.c.mp <= s.maxMp ? S.c.mp : s.maxMp;
  if (me.x < 20 || me.z < 20 || me.x > 2980 || me.z > 2980 || WG.height(me.x, me.z) < WG.WATER + 0.25 || S.c.hp <= 0) { const t = WG.nearestTown(me.x, me.z).town; me.x = t.x; me.z = t.z + 25; }
  updateChunks(me.x, me.z, true); loadQuests(); renderTracker(); buildBar(); S.fly = false; S.alt = 0; restoreComp();
  show('#hud'); S.inGame = true; loadClan(true); if (!S.uiInit) { S.uiInit = 1; initUI(); initBars(); buildBar(); } $('#btn-gm').hidden = !S.c.is_gm;
  B.join({ id: S.c.id, name: S.c.name, is_gm: S.c.is_gm }, { onPos, onLeave: id => { const o = S.others[id]; if (o) { o.model && scene.remove(o.model.root); delete S.others[id]; } }, onPresence: p => S.presence = p, onChat, onNode, onEvent, onFx: remoteFx });
  $('#chat-log').innerHTML = ''; (await safe(() => B.chatRecent()) || []).forEach(addChat);
  addChat({ kind: 'q', msg: `Bem-vindo(a) a Aurora, ${S.c.name}. Fale com o Arauto do Eclipse na praça para começar sua jornada (H abre a história).` });
  setInterval(netTick, 110); setInterval(saveNow, 2500); setInterval(spawner, 1000); setInterval(processKills, 350); setInterval(() => { updateHud(); }, 120); setInterval(drawMinimap, 250);
  addEventListener('beforeunload', () => saveNow());
}
function onNode(p) { if (p.eventType === 'DELETE') { const id = p.old?.node_id; if (id) { delete S.dep[id]; refreshNode(id); } } else if (p.new) { S.dep[p.new.node_id] = Date.parse(p.new.depleted_until); refreshNode(p.new.node_id); } }
setInterval(() => { if (!S.inGame) return; const t = Date.now(); for (const [id, v] of Object.entries(S.dep)) if (v < t) { delete S.dep[id]; refreshNode(+id); } }, 2000);


// ---------- ambiente: ciclo dia/noite, sol, lua, vento, fogo ----------
const fogBase = new THREE.Color(), nightFog = new THREE.Color('#1c2640'), sunWarm = new THREE.Color('#ffb070'), sunHigh = new THREE.Color('#fff2d8'), moonC = new THREE.Color('#8aa4ff'), hemiDay = new THREE.Color(0xcfe3ff), hemiNight = new THREE.Color(0x6a7ab0), tmpC = new THREE.Color();
function grassOk(x, z) { if (WG.inNeon(x, z, 6)) return false; { const NL = WG.nearestLandmark(x, z); if (NL.lm && NL.lm.type === 'castelo' && Math.abs(x - NL.lm.x) < 40 && Math.abs(z - NL.lm.z) < 40) return false; } const th = THEMES[WG.nearestTown(x, z).town.theme]; if (!th.grass) return false; const h = WG.height(x, z); return h > 1.6 && h < 34 && WG.nearestTown(x, z).dist > 31 && WG.roadDist(x, z) > 4.5 && !houses.some(o => Math.abs(o.x - x) < o.r && Math.abs(o.z - z) < o.r); }
function grassColor(x, z, out) { const th = THEMES[WG.nearestTown(x, z).town.theme]; out.set(th.grass || '#5a9a3a'); }
function updateEnvironment(dt) {
  const t = clock.elapsedTime, ph = dayPhase(), { sun: sd, moon: md } = sunVectors(ph);
  const day = THREE.MathUtils.smoothstep(sd.y, -0.12, 0.18), night = 1 - day; ENV.day = day; ENV.night = night;
  const th = S.skyTo || THEMES.verde, k = Math.min(1, dt * 1.5);
  skyMat.uniforms.top.value.lerp(skyTop.set(th.top), k); skyMat.uniforms.bot.value.lerp(skyBot.set(th.bot), k);
  ENV.eclipse += ((th.eclipse || 0) - ENV.eclipse) * k;
  Object.assign(skyMat.uniforms, {}); skyMat.uniforms.sunDir.value.copy(sd); skyMat.uniforms.moonDir.value.copy(md); skyMat.uniforms.night.value = night; skyMat.uniforms.time.value = t; skyMat.uniforms.eclipse.value = ENV.eclipse;
  const L = day > 0.05 ? sd : md; sun.position.set(me.x + L.x * 150, Math.max(20, L.y * 150), me.z + L.z * 150); sun.target.position.set(me.x, 0, me.z);
  if (day > 0.05) { sun.color.copy(sunWarm).lerp(sunHigh, THREE.MathUtils.clamp(sd.y * 2.2, 0, 1)); sun.intensity = 2.7 * day * (0.45 + 0.55 * THREE.MathUtils.clamp(sd.y * 2, 0, 1)); }
  else { sun.color.copy(moonC); sun.intensity = 0.55 + 0.6 * THREE.MathUtils.clamp(md.y * 3, 0, 1); }
  hemi.color.copy(hemiNight).lerp(hemiDay, day); hemi.intensity = (0.95 + 0.3 * day) * (th.eclipse ? 0.75 : 1);
  scene.fog.color.lerp(fogC.set(th.fog), k); fogBase.copy(scene.fog.color); scene.fog.color.copy(fogBase).lerp(nightFog, night * 0.6);
  { const wz = updateWeather(dt, (WG.nearestTown(me.x, me.z).town.theme), false); ENV.wdim = wz.dim; sfxRain(WEATHER.kind === 'chuva' ? WEATHER.amount : 0); sun.intensity *= 1 - wz.dim * 1.6; hemi.intensity *= 1 - wz.dim * 0.5 - (-wz.flash * 1.5);
    scene.fog.near = 140 * (1 - wz.dim * 1.2); scene.fog.far = 420 * (1 - wz.dim * 0.9); if (wz.dim) scene.fog.color.lerp(fogC.set(0x6a7480), wz.dim * 1.5); }
  renderer.toneMappingExposure = 1.05 + day * 0.05;
  WIND.time.value = t; WIND.strength.value = 0.7 + Math.sin(t * 0.07) * 0.35 + Math.sin(t * 0.31) * 0.15;
  updateWaterDepth(WG, WATER.mat, me.x, me.z, PERF.cur === 'baixa' ? 2 : 6); WATER.mat.uniforms.fogNear.value = scene.fog.near; WATER.mat.uniforms.fogFar.value = scene.fog.far; WATER.mat.uniforms.sunDir.value.copy(day > 0.05 ? sd : md); WATER.mat.uniforms.night.value = night; WATER.mat.uniforms.fogColor.value.copy(scene.fog.color); WATER.mat.uniforms.skyC.value.copy(skyMat.uniforms.bot.value).lerp(nightFog, night);
  // Era Neon: crepúsculo eterno roxo, neblina colorida e reflexos fortes
  { const nk = WG.inNeon(me.x, me.z, 60) ? 1 : 0; ENV.neon = (ENV.neon || 0) + (nk - (ENV.neon || 0)) * Math.min(1, dt * 0.8);
    if (ENV.neon > 0.01) { const k2 = ENV.neon; sun.intensity *= 1 - 0.62 * k2; sun.color.lerp(neonSun, 0.5 * k2); hemi.color.lerp(neonHemi, 0.6 * k2); hemi.groundColor && hemi.groundColor.lerp(neonGround, 0.6 * k2); hemi.intensity *= 1 - 0.2 * k2;
      scene.fog.color.lerp(neonFog, 0.85 * k2); scene.fog.near = scene.fog.near * (1 - 0.4 * k2); scene.fog.far = scene.fog.far * (1 + 0.6 * k2); renderer.toneMappingExposure = 1.05 + 0.1 * k2; } }
  updateFires(dt, t, night, camera.position); updateTownAnim(t); updateNeon(t, camera);
}
const neonSun = new THREE.Color('#ff7ad8'), neonHemi = new THREE.Color('#5a6aff'), neonGround = new THREE.Color('#3a0a4a'), neonFog = new THREE.Color('#2a1250');
// ---------- laço principal ----------
const clock = new THREE.Clock(); const skyTop = new THREE.Color(), skyBot = new THREE.Color(), fogC = new THREE.Color();
function loop() {
  requestAnimationFrame(loop);
  const tnow = performance.now(); const dt = Math.min(0.05, clock.getDelta()) * (tnow < TIME.stopUntil ? 0.06 : tnow < TIME.slowUntil ? 0.35 : 1);
  if (S.inGame && me) {
    perfTick(dt); if (S.guide && (S.guideT = (S.guideT || 0) + dt) > 0.25) { S.guideT = 0; guideTick(); }
    updateMe(dt); updateMobs(dt); updateOthers(dt); updateFx(dt); updateFX(dt); updateElements(dt); updateEquip(dt); equipWatch(); if (!S.dead && Date.now() - Math.max(S.lastCombat || 0, S.auraAt || 0) < 5000) bodyAura(myElem(), me.x, me.z, 1.8 * (GD.RACES[S.c.race]?.h || 1) + (S.alt || 0), dt, PERF.cur === 'baixa' ? 0.5 : 1); updateAmbient(dt); updateDialog(); greetNpcs(); updateTraps(); setMood(S.mobs.some(m => m.aggro && !m.dead) ? 'combate' : 'calma'); if (S.inGame && me) updateVillagers(dt); updateCamera(); updateChunks(me.x, me.z, false);
    updateEnvironment(dt); water.position.x = Math.round(me.x / 50) * 50; water.position.z = Math.round(me.z / 50) * 50; sky.position.copy(camera.position);
    if (!GRASS.center || Math.hypot(GRASS.center.x - me.x, GRASS.center.z - me.z) > 12) layoutGrass(GRASS, me.x, me.z, WG.height, grassOk, grassColor); updateTownVisibility();
    if ((S.npcGlbT = (S.npcGlbT || 0) + dt) > 1) { S.npcGlbT = 0; if (PERF.cur !== 'baixa') { let k = 0; for (const n of npcs) if (n.model && !n.model.glb && !n.model.glbPending && Math.hypot(n.x - me.x, n.z - me.z) < 55 && k++ < 3) upgradeGLB(n.model); } }
    npcs.forEach(n => { if (n.crystal) { n.crystal.rotation.y += dt * (n.crystal.userData.spin2 ? 0.8 : 0.6); if (n.crystal.userData.spin) n.crystal.position.y = WG.TOWN_H + 6 + Math.sin(clock.elapsedTime * 1.5) * 0.4; } else if (n.model && Math.hypot(n.x - me.x, n.z - me.z) < 80) animHumanoid(n.model, dt); });
  } else if (studio.visible) {
    { const ph = preview ? (GD.RACES[preview.race]?.h || 1) : 1, close = clamp((3.2 - stu.dist) / 2.3, 0, 1), ty = -500 + 1.0 * ph + 0.62 * ph * close; camera.position.set(Math.sin(stu.yaw) * Math.cos(stu.pitch) * stu.dist + 0.35 * (1 - close), ty + Math.sin(stu.pitch) * stu.dist, Math.cos(stu.yaw) * Math.cos(stu.pitch) * stu.dist); camera.lookAt(0.35 * (1 - close), ty, 0); if (preview) animHumanoid(preview, dt); }
    sun.position.set(3, -490, 6); sun.target.position.set(0, -500, 0); sky.position.copy(camera.position);
  }
  if (POST.on && S.inGame && me) { const st = stats(), r = S.hp / st.maxHp, L = GD.LANDMARKS.find(L => L.poi && Math.hypot(L.x - me.x, L.z - me.z) < 75);
    renderPost(dt, { lowHp: !S.dead && r < 0.3 ? (0.3 - r) / 0.3 : 0, night: ENV.night, tint: WG.inNeon(me.x, me.z, 20) ? '#b8a0ff' : L ? { tumba: '#a8ffc0', pantano: '#b8d890', destrocos: '#ffc890', estranho: '#c8a0ff' }[L.type] : null }); }
  else if (POST.on) renderPost(dt, { lowHp: 0, night: 0, tint: null }); else renderer.render(scene, camera);
}
loop();

// ---------- inicialização ----------
(async function boot() {
  if (CFG.supabaseUrl && CFG.supabaseKey) {
    B = new RemoteBackend(CFG.supabaseUrl, CFG.supabaseKey);
    if (await B.session()) { try { await toSelect(); return; } catch (e) { $('#login-msg').textContent = e.message; await B.sb.auth.signOut(); show('#login'); } }
  } else $('#login-msg').textContent = 'Servidor online em configuração — use o modo offline para testar.';
  show('#login');
})();
function petHit(tg, mult) { if (tg.dead) return; const st = stats(), d = dmgVs(st.atk, mult, tg.st.def, st.crit, st.critDmg); hurtMob(tg, d.v, d.crit); emit(tg.x, WG.height(tg.x, tg.z) + 0.8, tg.z, { n: 10, color: 0xffe08a, speed: 3, up: 1, life: 0.35, size: 0.14, grav: 8 }); }
initComp({ scene, S, GD, WG, me: () => me, toast, petHit, now, keys });
const POI_AMB = { tumba: { particles: '#aaffbb' }, pantano: { particles: '#c8ff7a' }, destrocos: { particles: '#ffaa5a' }, estranho: { particles: '#c89aff' } };
initAmbient({ scene, S, WG, me: () => me, isNight: () => { const p = dayPhase(); return p < 0.23 || p > 0.79; }, theme: (x, z) => WG.nearestTown(x, z).town.theme,
  nearPoi: (x, z) => { const L = GD.LANDMARKS.find(L => L.poi && Math.hypot(L.x - x, L.z - z) < 70); return L ? { x: L.x, z: L.z, amb: POI_AMB[L.type] } : null; } });
window.__game = { get B() { return B; }, clanDo, loadClan, get clanInfo() { return S.clanInfo; }, meteor, elemImpact, castBurst, blocked, playAttack, openEquip: () => toggleEquip(EQX), VIL, stats, WEATHER, POST, COMP, summonPet, setMount, setWings, toggleFly, toggleRide, townGroups, houses, S, scene, camera, onPos: (p) => onPos(p), renderPanel: () => renderPanel(), teleport: (x, z) => teleport(x, z), spawnMob: (f, l, x, z) => spawnMob(FAM[f], l, x, z), get me() { return me; }, cam, command, openPanel, castSkill, keys, refreshGear: () => { me.enc = encOf(S.c); setGear(me, S.c.equipment.arma, S.c.equipment.armadura, S.c.equipment); buildBar(); }, attackKey: () => attackKey(), dodge, startGuide, stopGuide, PERF, applyQuality, saveQuests };
