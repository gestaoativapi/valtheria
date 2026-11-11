// ===== Valtheria — cliente =====
import * as THREE from './three.module.min.js';
import { buildHumanoid, setGear, animHumanoid, playAttack, buildMob, animMob, buildNode, buildHouse, makeLabel, mat } from './models.js';
import { createSky, createWater, dayPhase, sunVectors, WIND, makeFire, updateFires, createGrass, layoutGrass, ROCK_GEOS, rockMat, TREE_KINDS, leafMat, treeTrunkMat } from './world3d.js';
import { buildTownArchitecture, buildLandmark, updateTownAnim } from './towns.js';
const GD = window.GD, WG = window.WG, QD = window.QD, CFG = window.GAME_CONFIG || {};
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const now = () => performance.now();

// ---------- dados globais do mundo ----------
const NODES = WG.genNodes().filter(WG.nodeVisible); window.NODES_BY_ID = {}; NODES.forEach(n => window.NODES_BY_ID[n.id] = n);
window.TELEPORTS = []; GD.TOWNS.forEach(t => { TELEPORTS.push({ id: 'town:' + t.id, name: t.name, x: t.x, z: t.z + 25, lvl: t.min, town: true }); t.spotsPos.forEach((s, i) => TELEPORTS.push({ id: `spot:${t.id}:${i}`, name: s.name, x: s.x, z: s.z, lvl: s.lvl })); });
TELEPORTS.forEach(t => t.cost = GD.teleCost(t.lvl));
const FAM = {}; GD.MOBS.forEach((g, gi) => g.forEach(f => { f.grade = gi; FAM[f.id] = f; })); GD.SPECIAL_BOSSES.forEach(f => { f.grade = Math.min(5, GD.gradeForLevel((GD.LANDMARKS.find(l => l.boss === f.id) || {}).lvl || 1)); FAM[f.id] = f; });
const NPC_TYPES = [
  ['portal', 'Guardião do Portal', '#4a7ab0'], ['classe', 'Mestre de Classes', '#a87a2a'], ['ferreiro', 'Ferreiro', '#6a4a3a'],
  ['refino', 'Refinador e Alquimista', '#3a7a4a'], ['mercador', 'Mercador', '#8a6a2a'], ['leilao', 'Casa de Leilões', '#6a3a8a'], ['arauto', 'Arauto do Eclipse', '#b03a3a'],
];

// ---------- estado ----------
let B = null;
const S = { acct: null, chars: [], selected: 0, c: null, inv: {}, dep: {}, hp: 1, mp: 1, buffs: {}, cds: {}, target: null, dest: null, gatherAt: null, npcAt: null,
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
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio, 2)); renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.05;
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(55, innerWidth / innerHeight, 0.3, 1200);
addEventListener('resize', () => { renderer.setSize(innerWidth, innerHeight); camera.aspect = innerWidth / innerHeight; camera.updateProjectionMatrix(); });
const hemi = new THREE.HemisphereLight(0xcfe3ff, 0x5a4a32, 1.15); scene.add(hemi);
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
};
const cA = new THREE.Color(), cB = new THREE.Color();
function terrainColor(x, z, h, out) {
  let d1 = 1e9, d2 = 1e9, t1 = null, t2 = null;
  for (const t of GD.TOWNS) { const d = Math.hypot(x - t.x, z - t.z); if (d < d1) { d2 = d1; t2 = t1; d1 = d; t1 = t; } else if (d < d2) { d2 = d; t2 = t; } }
  const th1 = THEMES[t1.theme], th2 = THEMES[t2.theme], n = WG.fbm(x / 30, z / 30, 5, 2);
  cA.set(th1.g[0]).lerp(cB.set(th1.g[1]), n);
  const k = clamp((d2 - d1) / 140, 0, 1);
  if (k < 1) { const o = new THREE.Color(th2.g[0]).lerp(cB.set(th2.g[1]), n); cA.lerp(o, 0.5 - 0.5 * k); }
  if (h > 32) cA.lerp(cB.set('#8a8478'), clamp((h - 32) / 12, 0, 1));
  if (h > 40) cA.lerp(cB.set('#f2f5f8'), clamp((h - 40) / 8, 0, 1));
  if (h < 2.2) cA.lerp(cB.set('#cdb880'), clamp((2.2 - h) / 1.5, 0, 1));
  const rd = WG.roadDist(x, z); if (rd < 6) cA.lerp(cB.set('#9a7a50'), clamp(1 - (rd - 3) / 3, 0, 1));
  if (d1 < 100) { const cob = WG.fbm(x / 4, z / 4, 9, 2); cA.lerp(cB.set(cob > 0.5 ? '#8a8270' : '#7a705e'), clamp((100 - d1) / 12, 0, 1) * (d1 < 30 ? 1 : 0.55 + 0.3 * WG.fbm(x / 18, z / 18, 3, 2))); }
  out.copy(cA);
}

// ----- terreno em blocos -----
const CH = 100, SEG = 25, chunks = new Map(), terrainMeshes = [];
const terrainMat = new THREE.MeshLambertMaterial({ vertexColors: true });
const trunkGeo = new THREE.CylinderGeometry(0.25, 0.4, 3, 6).translate(0, 1.5, 0);
const leafGeo = new THREE.IcosahedronGeometry(2.1, 0).translate(0, 4.2, 0), conGeo = new THREE.ConeGeometry(2, 6, 7).translate(0, 5.5, 0);
const trunkMat = mat('#5a3a20');
const nodeMeshes = new Map();
function buildChunk(cx, cz) {
  const geo = new THREE.PlaneGeometry(CH, CH, SEG, SEG); geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position, col = new Float32Array(pos.count * 3), c = new THREE.Color();
  const ox = cx * CH + CH / 2, oz = cz * CH + CH / 2;
  for (let i = 0; i < pos.count; i++) { const x = pos.getX(i) + ox, z = pos.getZ(i) + oz, h = WG.height(x, z); pos.setY(i, h); terrainColor(x, z, h, c); col[i * 3] = c.r; col[i * 3 + 1] = c.g; col[i * 3 + 2] = c.b; }
  geo.setAttribute('color', new THREE.BufferAttribute(col, 3)); geo.computeVertexNormals();
  const mesh = new THREE.Mesh(geo, terrainMat); mesh.position.set(ox, 0, oz); mesh.receiveShadow = true; mesh.userData.terrain = true;
  const group = new THREE.Group(); group.add(mesh);
  // árvores por bioma (com vento) e rochas
  const th = THEMES[WG.nearestTown(ox, oz).town.theme], rng = WG.mulberry32((cx * 7919) ^ (cz * 104729) ^ 77), byKind = {};
  for (let i = 0; i < th.trees; i++) {
    const x = cx * CH + rng() * CH, z = cz * CH + rng() * CH, h = WG.height(x, z), kind = th.kinds[Math.floor(rng() * th.kinds.length)];
    if (h < 1.8 || h > 42 || WG.nearestTown(x, z).dist < 115 || WG.nearestLandmark(x, z).dist < 60 || WG.roadDist(x, z) < 9) { rng(); rng(); continue; }
    (byKind[kind] = byKind[kind] || []).push([x, h, z, 0.7 + rng() * 0.8, rng() * 6]);
  }
  const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), sv = new THREE.Vector3(), pv = new THREE.Vector3(), up = new THREE.Vector3(0, 1, 0);
  for (const [kind, pts] of Object.entries(byKind)) {
    const K = TREE_KINDS[kind], tr = new THREE.InstancedMesh(K.trunk, treeTrunkMat(), pts.length), lf = K.leaf ? new THREE.InstancedMesh(K.leaf, leafMat(kind === 'gelo' ? '#2f5a3a' : th.leaf, kind === 'cristal' ? new THREE.Color(th.leaf).getHex() : 0), pts.length) : null;
    pts.forEach(([x, h, z, sc, r], i) => { q.setFromAxisAngle(up, r); sv.set(sc, sc, sc); pv.set(x, h - 0.2, z); m4.compose(pv, q, sv); tr.setMatrixAt(i, m4); lf && lf.setMatrixAt(i, m4); });
    tr.castShadow = true; group.add(tr); if (lf) { lf.castShadow = true; group.add(lf); }
    if (kind === 'gelo') { const sn = new THREE.InstancedMesh(TREE_KINDS.gelo.leaf, leafMat('#f4f8ff'), pts.length); pts.forEach(([x, h, z, sc, r], i) => { q.setFromAxisAngle(up, r); sv.set(sc * 1.04, sc * 0.55, sc * 1.04); pv.set(x, h + 2.4 * sc, z); m4.compose(pv, q, sv); sn.setMatrixAt(i, m4); }); group.add(sn); }
  }
  const nRocks = th.rocks + Math.round(Math.max(0, WG.height(ox, oz) - 20) / 3), rocks = [[], [], []];
  for (let i = 0; i < nRocks; i++) { const x = cx * CH + rng() * CH, z = cz * CH + rng() * CH, h = WG.height(x, z); if (h < 0.5 || WG.nearestTown(x, z).dist < 100 || WG.roadDist(x, z) < 7) continue; rocks[i % 3].push([x, h, z, 0.5 + rng() * rng() * 3.2, rng() * 6]); }
  rocks.forEach((pts, k) => { if (!pts.length) return; const rm = new THREE.InstancedMesh(ROCK_GEOS[k], rockMat, pts.length); pts.forEach(([x, h, z, sc, r], i) => { q.setFromAxisAngle(up, r); sv.set(sc * 1.3, sc, sc); pv.set(x, h - sc * 0.25, z); m4.compose(pv, q, sv); rm.setMatrixAt(i, m4); }); rm.castShadow = rm.receiveShadow = true; group.add(rm); });
  scene.add(group); terrainMeshes.push(mesh);
  // recursos coletáveis
  const nodes = NODES.filter(n => n.x >= cx * CH && n.x < cx * CH + CH && n.z >= cz * CH && n.z < cz * CH + CH);
  nodes.forEach(n => { const m = buildNode(n.type, n.grade); m.position.set(n.x, WG.height(n.x, n.z), n.z); m.userData = { kind: 'node', ref: n }; scene.add(m); nodeMeshes.set(n.id, m); refreshNode(n.id); });
  chunks.set(cx + ',' + cz, { group, mesh, nodes });
}
function dropChunk(key) { const c = chunks.get(key); scene.remove(c.group); c.mesh.geometry.dispose(); c.group.children.forEach(o => { if (o.isInstancedMesh) o.dispose(); }); const i = terrainMeshes.indexOf(c.mesh); if (i >= 0) terrainMeshes.splice(i, 1); c.nodes.forEach(n => { const m = nodeMeshes.get(n.id); if (m) { scene.remove(m); nodeMeshes.delete(n.id); } }); chunks.delete(key); }
function updateChunks(px, pz, all) {
  const R = 4, ccx = Math.floor(px / CH), ccz = Math.floor(pz / CH); let built = 0;
  const want = [];
  for (let dz = -R; dz <= R; dz++) for (let dx = -R; dx <= R; dx++) { const cx = ccx + dx, cz = ccz + dz; if (cx < 0 || cz < 0 || cx >= 30 || cz >= 30 || dx * dx + dz * dz > R * R + 1) continue; want.push([dx * dx + dz * dz, cx, cz]); }
  want.sort((a, b) => a[0] - b[0]);
  const keep = new Set(want.map(w => w[1] + ',' + w[2]));
  for (const k of [...chunks.keys()]) if (!keep.has(k)) dropChunk(k);
  for (const [, cx, cz] of want) { if (!chunks.has(cx + ',' + cz)) { buildChunk(cx, cz); if (!all && ++built >= 2) break; } }
}
function refreshNode(id) { const m = nodeMeshes.get(id); if (!m) return; const dep = (S.dep[id] || 0) > Date.now(); m.scale.set(1, dep ? 0.22 : 1, 1); m.children.forEach(ch => { if (ch.geometry && ch.geometry.type === 'RingGeometry') ch.visible = !dep; }); m.userData.dep = dep; }
const WATER = createWater(), water = WATER.mesh; water.position.y = WG.WATER; scene.add(water);
const GRASS = createGrass(14000); scene.add(GRASS.mesh);

// ----- cidades -----
const npcs = [], houses = [];
const townGroups = [];
const PLAZA = { humano: '#a8a08e', halfling: '#b8a878', anao: '#6a645a', elfo: '#e8e8e0', orc: '#8a6a4a', sylph: '#f0f4fa', beastman: '#a8885a', sombrio: '#3a3448', draconato: '#3a3232', nocturno: '#3a3640', gigante: '#d8e4ec' };
function townCtx(t) {
  const roadAngles = WG.ROADS.filter(([a, b]) => a === t || b === t).map(([a, b]) => { const o = a === t ? b : a; return Math.atan2(o.z - t.z, o.x - t.x); });
  return { t, roadAngles, H: (x, z) => WG.height(x, z), collide: (x, z, r) => houses.push({ x, z, r }),
    statue: (race, x, z, s, rot) => { const m = buildHumanoid({ race, gender: 'm', skinColor: '#8a8478', armor: 'pesada_c', weapon: 'martelo_c', look: { beard: 2 } }); m.root.scale.setScalar(s); m.root.position.set(x, WG.height(x, z) + 1.2, z); m.root.rotation.y = rot; const base = new THREE.Mesh(new THREE.CylinderGeometry(2.4, 2.8, 1.2, 12), mat('#6a645a')); base.position.set(x, WG.height(x, z) + 0.6, z); scene.add(m.root, base); houses.push({ x, z, r: 2.8 }); },
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
    g.add(buildTownArchitecture(townCtx(t)));
    scene.add(g); townGroups.push({ g, x: t.x, z: t.z });
    const races = [t.race, 'humano', t.race, 'elfo', t.race, 'anao', t.race];
    NPC_TYPES.forEach(([type, name, color], i) => {
      const a = i / NPC_TYPES.length * Math.PI * 2 + 0.3, x = t.x + Math.cos(a) * 17, z = t.z + Math.sin(a) * 17;
      const m = buildHumanoid({ race: races[i] || t.race, gender: i % 3 === 1 ? 'f' : 'm', hair: i % 6, hair_color: i, skin: 0, look: { eyes: i % 4, face: i % 4 }, armor: type === 'ferreiro' ? 'pesada_c' : 'robe_' + ['b', 'a', 'c', 'd', 'c', 's', 'a'][i], weapon: type === 'portal' ? 'cajado_b' : type === 'ferreiro' ? 'martelo_c' : null });
      m.root.position.set(x, y, z); m.root.rotation.y = Math.atan2(t.x - x, t.z - z); scene.add(m.root);
      const l = makeLabel(name, '#ffe36a', 28); l.position.set(0, 2.5 * (GD.RACES[races[i] || t.race]?.h || 1), 0); m.root.add(l);
      const npc = { type, name, town: t, x, z, model: m }; m.root.traverse(o => o.userData.pick = npc); npcs.push(npc);
      if (type === 'portal') { const ring = new THREE.Mesh(new THREE.TorusGeometry(2.2, 0.18, 8, 30), mat('#7ad0ff', { emissive: 0x3aa0ff, ei: 1.2 })); ring.position.set(x + Math.cos(a) * 4, y + 2.4, z + Math.sin(a) * 4); ring.rotation.y = -a; ring.userData.spin2 = true; scene.add(ring); npcs.push({ crystal: ring }); }
    });
  }
  for (const L of GD.LANDMARKS) { const g = buildLandmark(townCtx({ x: L.x, z: L.z, race: 'humano' }), L); scene.add(g); townGroups.push({ g, x: L.x, z: L.z });
    const lb = makeLabel((L.type === 'castelo' ? '🏰 ' : L.type === 'ruina' ? '🏛️ ' : '💀 ') + L.name, '#ffcf8a', 34); lb.position.set(L.x, WG.height(L.x, L.z) + 26, L.z); lb.scale.multiplyScalar(1.8); scene.add(lb); townGroups.push({ g: lb, x: L.x, z: L.z }); }
}
function updateTownVisibility() { if (!me) return; for (const t of townGroups) t.g.visible = Math.hypot(t.x - me.x, t.z - me.z) < 620; }

// ---------- personagem do jogador ----------
let me = null; const pickables = [];
const ring = (color) => { const m = new THREE.Mesh(new THREE.RingGeometry(0.9, 1.15, 28), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.85, depthWrite: false })); m.rotation.x = -Math.PI / 2; m.renderOrder = 5; return m; };
const selRing = ring(0xff4040); scene.add(selRing); selRing.visible = false;
const destRing = ring(0xffffff); scene.add(destRing); destRing.visible = false;
function stats() { const s = GD.charStats(S.c, buffVals()); return s; }
function buffVals() { const o = {}, t = now(); for (const [k, b] of Object.entries(S.buffs)) { if (b.until < t) { delete S.buffs[k]; continue; } for (const [s, v] of Object.entries(b.vals)) o[s] = (o[s] || 0) + v; } return o; }
function nameColor(c) { return c.gm ? '#ffcf4a' : c.karma ? '#ff4a4a' : c.flag ? '#d38cff' : '#ffffff'; }
function makeMe() {
  if (me) { scene.remove(me.root); }
  const c = S.c; me = buildHumanoid({ ...c, weapon: c.equipment.arma, armor: c.equipment.armadura, equip: c.equipment }); me.x = c.x; me.z = c.z; me.ry = 0;
  me.label = makeLabel(c.name, nameColor({ gm: S.c.is_gm, karma: S.c.karma, flag: false }), 30); me.label.position.y = 2.25 * GD.RACES[c.race].h; me.root.add(me.label);
  scene.add(me.root);
}
function relabelMe() { if (!me) return; me.root.remove(me.label); me.label = makeLabel(S.c.name, nameColor({ gm: S.c.is_gm, karma: S.c.karma, flag: S.flagUntil > Date.now() }), 30); me.label.position.y = 2.25 * GD.RACES[S.c.race].h; me.root.add(me.label); }

// ---------- câmera ----------
const cam = { yaw: 0, pitch: 0.38, dist: 12, drag: false, lx: 0, ly: 0 };
canvas.addEventListener('contextmenu', e => e.preventDefault());
canvas.addEventListener('mousedown', e => { if (e.button === 2 || e.button === 1 || (studio.visible && e.button === 0)) { cam.drag = true; cam.lx = e.clientX; cam.ly = e.clientY; } });
addEventListener('mouseup', () => cam.drag = false);
addEventListener('mousemove', e => { if (!cam.drag) return; if (studio.visible) { stu.yaw -= (e.clientX - cam.lx) * 0.01; stu.pitch = clamp(stu.pitch + (e.clientY - cam.ly) * 0.005, -0.4, 0.9); } else { cam.yaw -= (e.clientX - cam.lx) * 0.006; cam.pitch = clamp(cam.pitch + (e.clientY - cam.ly) * 0.005, -0.45, 1.4); } cam.lx = e.clientX; cam.ly = e.clientY; });
canvas.addEventListener('wheel', e => { if (studio.visible) stu.dist = clamp(stu.dist * (e.deltaY > 0 ? 1.1 : 0.9), 0.9, 6); else cam.dist = clamp(cam.dist * (e.deltaY > 0 ? 1.1 : 0.9), 1.1, 32); }, { passive: true });
const stu = { yaw: 0, pitch: 0.12, dist: 4.6 }; window.__stu = stu;
function updateCamera() {
  const rh = (GD.RACES[S.c.race]?.h || 1), close = clamp((5 - cam.dist) / 3.5, 0, 1); const ty = WG.height(me.x, me.z) + (1.7 + (1.62 * rh - 1.7) * close) * (close ? 1 : 1) + (rh - 1) * 0.6 * (1 - close);
  let cx = me.x + Math.sin(cam.yaw) * Math.cos(cam.pitch) * cam.dist, cz = me.z + Math.cos(cam.yaw) * Math.cos(cam.pitch) * cam.dist, cy = ty + Math.sin(cam.pitch) * cam.dist;
  cy = Math.max(cy, WG.height(cx, cz) + 0.25);
  camera.position.set(cx, cy, cz); camera.lookAt(me.x, ty, me.z); if (me.label) me.label.visible = cam.dist > 3;
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
canvas.addEventListener('mousedown', e => {
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
  if (p.ground) { S.dest = { x: p.ground.x, z: p.ground.z }; S.autoAtk = false; destRing.position.set(p.ground.x, p.ground.y + 0.1, p.ground.z); destRing.visible = true; destRing.scale.setScalar(1); }
});

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
  const bk = BAR_KEYS.indexOf(e.key); if (bk >= 0 && !e.ctrlKey) { e.preventDefault(); useSlot(bk); return; }
  if (e.code === 'Tab') { e.preventDefault(); nextTarget(); }
  if (e.code === 'Space' || e.code === 'KeyF') { e.preventDefault(); attackKey(); }
  const P = { KeyC: 'char', KeyI: 'bag', KeyK: 'skills', KeyL: 'quests', KeyM: 'map', KeyH: 'lore', KeyG: 'gm' }[e.code];
  if (P && (P !== 'gm' || S.c.is_gm)) { if (panelState.kind === P) closePanel(); else openPanel(P); }
});
addEventListener('keyup', e => keys[e.code] = false);
function nextTarget() { const list = S.mobs.filter(m => !m.dead && Math.hypot(m.x - me.x, m.z - me.z) < 40).sort((a, b) => Math.hypot(a.x - me.x, a.z - me.z) - Math.hypot(b.x - me.x, b.z - me.z)); if (!list.length) return; const i = S.target ? list.indexOf(S.target.ref) : -1; S.target = { kind: 'mob', ref: list[(i + 1) % list.length] }; }
function attackKey() { if (!S.target || S.target.kind !== 'mob' || S.target.ref.dead) nextTarget(); if (S.target && (S.target.kind === 'mob' || S.target.kind === 'player')) S.autoAtk = true; }

// ---------- combate ----------
function tgtPos(t) { return t.kind === 'mob' ? t.ref : t.kind === 'player' ? t.ref : null; }
function inSafe(x, z) { return WG.region(x, z).safe; }
function dmgVs(atk, mult, def, crit) { const c = Math.random() < crit; return { v: Math.max(1, Math.round(GD.dmgFormula(atk, mult, def) * (0.9 + Math.random() * 0.2) * (c ? 1.8 : 1))), crit: c }; }
function faceTo(x, z) { me.ry = Math.atan2(x - me.x, z - me.z); }
function basicAttack(st) {
  const t = S.target, p = tgtPos(t); faceTo(p.x, p.z);
  const kind = st.weaponKind === 'arco' ? 'bow' : st.magic ? 'cast' : 'melee'; playAttack(me, kind);
  hitTarget(t, 1, st, kind === 'bow' ? 'arrow' : kind === 'cast' ? 'magic' : null);
  B.sendFx({ k: kind === 'bow' ? 'arrow' : kind === 'cast' ? 'magic' : 'melee', x: me.x, z: me.z, tx: p.x, tz: p.z, id: S.c.id });
}
function hitTarget(t, mult, st, proj, sk) {
  const p = tgtPos(t); const rk = st.cls.rank; mult *= sk ? 1 + 0.1 * rk : 1;
  const apply = () => {
    if (t.kind === 'mob') {
      const m = t.ref; if (m.dead) return;
      const targets = sk && sk.aoe ? S.mobs.filter(o => !o.dead && Math.hypot(o.x - (sk.self ? me.x : m.x), o.z - (sk.self ? me.z : m.z)) < sk.aoe + 0.8) : [m];
      targets.forEach(o => {
        let mul = mult; if (sk && sk.execute && o.hp / o.maxHp < 0.3) mul *= 2;
        const d = dmgVs(st.atk, mul, o.st.def * (1 + debOf(o, 'def')), st.crit); hurtMob(o, d.v, d.crit);
        if (sk) { if (sk.stun) o.stunUntil = now() + sk.stun * 1000; if (sk.slow) o.slowUntil = now() + 4000; if (sk.dot) o.dots.push({ until: now() + sk.dot.dur * 1000, dps: GD.dmgFormula(st.atk, sk.dot.mult, o.st.def) / sk.dot.dur, next: now() + 1000 }); }
        const ls = (S.buffs.lifesteal ? 0.2 : 0) + (sk && sk.drain ? sk.drain : 0); if (ls) S.hp = Math.min(st.maxHp, S.hp + d.v * ls);
      });
    } else if (t.kind === 'player') {
      pvpHit(t.ref, mult);
    }
  };
  if (proj) projectile(me.x, me.z, p.x, p.z, proj, sk?.fx, apply); else apply();
}
async function pvpHit(o, mult) {
  if (inSafe(me.x, me.z) || inSafe(o.x, o.z)) { toast('PvP proibido dentro das cidades', 'err'); S.autoAtk = false; return; }
  const r = await safe(() => B.pvp(o.id, mult)); if (!r) { S.autoAtk = false; return; }
  floatText(o.x, WG.height(o.x, o.z) + 2.2, o.z, String(r.dmg), '#ffe36a');
  S.lastCombat = Date.now(); S.c.karma = r.karma; S.c.pvp = r.pvp; S.c.pk = r.pk_count; S.flagUntil = r.flag_until ? Date.parse(r.flag_until) : 0; relabelMe();
  if (r.killed) { toast(r.pk ? `Você cometeu PK contra ${o.n}! Karma: ${r.karma}` : `Você venceu ${o.n} em PvP!`, r.pk ? 'err' : 'ok'); S.target = null; S.autoAtk = false; }
}
function hurtMob(m, v, crit) {
  if (m.dead) return;
  if (m.returning) { floatText(m.x, WG.height(m.x, m.z) + 2.2 * m.fam.scale, m.z, 'Imune', '#9ab8ff'); return; }
  if (me && inSafe(me.x, me.z) && !S.gmKill) { if (!S.safeToast || Date.now() - S.safeToast > 3000) { S.safeToast = Date.now(); toast('Você não pode atacar monstros de dentro da cidade — saia da zona segura', 'err'); } S.autoAtk = false; return; } m.hp -= v; m.aggro = true; S.lastCombat = Date.now();
  floatText(m.x, WG.height(m.x, m.z) + 2.2 * m.fam.scale, m.z, (crit ? '💥' : '') + v, crit ? '#ff9a3a' : '#ffe36a');
  if (m.hp <= 0) killMob(m);
}
function killMob(m) {
  m.dead = true; m.model.anim.state = 'dead'; if (S.target && S.target.ref === m) { S.target = null; S.autoAtk = false; }
  setTimeout(() => { scene.remove(m.model.root); S.mobs = S.mobs.filter(x => x !== m); }, 2500);
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
  toast(`⭐ Nível ${L}!`, 'ok'); addChat({ kind: 'q', msg: `Você alcançou o nível ${L}!` });
  const r = new THREE.Mesh(new THREE.TorusGeometry(1, 0.08, 6, 30), new THREE.MeshBasicMaterial({ color: 0xffe36a, transparent: true })); r.rotation.x = Math.PI / 2; r.position.set(me.x, WG.height(me.x, me.z) + 0.2, me.z); scene.add(r);
  fx.push({ obj: r, t: 0, dur: 1.4, up: (o, k) => { o.position.y += 0.05; o.scale.setScalar(1 + k * 1.5); o.material.opacity = 1 - k; } });
  for (const lv of [20, 40, 76]) if (old < lv && L >= lv) addChat({ kind: 'q', msg: `Uma nova classe está disponível! Fale com o Mestre de Classes em qualquer cidade.` });
  const sk = stats().arch.skills.filter(s => s.lvl > old && s.lvl <= L); sk.forEach(s => toast(`Nova habilidade: ${s.icon} ${s.name}`, 'ok'));
  buildBar();
}
function hurtMe(v) {
  if (S.dead || S.buffs.invuln || S.god) return;
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
  if (S.mp < sk.mp) { toast('MP insuficiente', 'err'); return; }
  const needT = (['hit', 'dash'].includes(sk.type) || (sk.type === 'debuff' && !sk.aoe)) && !sk.self;
  let tg = S.target; if (needT && (!tg || !['mob', 'player'].includes(tg.kind) || tg.ref.dead)) { attackKey(); tg = S.target; }
  if (needT && !tg) { toast('Selecione um alvo', 'err'); return; }
  if (needT) { const p = tgtPos(tg), d = Math.hypot(p.x - me.x, p.z - me.z), rng = sk.type === 'dash' ? sk.range : st.range + 1.5; if (d > rng) { toast('Alvo fora de alcance', 'err'); S.dest = { x: p.x, z: p.z }; S.autoAtk = true; return; } faceTo(p.x, p.z); }
  S.mp -= sk.mp; S.cds[i] = t + sk.cd * 1000; S.autoAtk = needT || S.autoAtk;
  const kind = st.weaponKind === 'arco' ? 'bow' : st.magic ? 'cast' : 'melee'; playAttack(me, sk.type === 'hit' || sk.type === 'dash' ? kind : 'cast');
  floatText(me.x, WG.height(me.x, me.z) + 2.7, me.z, sk.icon + ' ' + sk.name, '#bfe8ff', 22);
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
  if (sk.type === 'buff') skillFx('buff', sk.fx, me);
  if (sk.type === 'heal' || sk.type === 'mana') skillFx('heal', sk.fx || 'holy', me);
  if (sk.cleanse) { Object.keys(S.buffs).forEach(k => { if (S.buffs[k].bad) delete S.buffs[k]; }); }
  if (sk.type === 'hit' && sk.stun && tg && tg.kind === 'mob') skillFx('stun', 'holy', tg.ref);
  if (sk.type === 'heal') { const v = Math.round(st.maxHp * sk.pct); S.hp = Math.min(st.maxHp, S.hp + v); floatText(me.x, WG.height(me.x, me.z) + 2.2, me.z, '+' + v, '#7dff7d'); }
  if (sk.type === 'mana') { S.mp = Math.min(st.maxMp, S.mp + st.maxMp * sk.pct); }
  if (sk.type === 'taunt') S.mobs.forEach(m => { if (!m.dead && Math.hypot(m.x - me.x, m.z - me.z) < sk.radius) m.aggro = true; });
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
  const n = kind === 'stun' ? 5 : 16;
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
  fx.push({ obj: o, t: 0, dur, up: (ob, k) => ob.position.set(x + (tx - x) * k, y0 + (y1 - y0) * k + Math.sin(k * Math.PI) * d * 0.04, z + (tz - z) * k), end: onHit });
}
function updateFx(dt) {
  for (let i = fx.length - 1; i >= 0; i--) { const f = fx[i]; f.t += dt; const k = Math.min(1, f.t / f.dur); f.up(f.obj, k); if (k >= 1) { scene.remove(f.obj); f.obj.geometry?.dispose?.(); if (f.obj.material?.map) f.obj.material.map.dispose(); f.end && f.end(); fx.splice(i, 1); } }
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
  for (const m of [...S.mobs]) if (!m.dead && Math.hypot(m.x - me.x, m.z - me.z) > 170) { scene.remove(m.model.root); S.mobs = S.mobs.filter(x => x !== m); }
  // chefes de missão
  for (const id of S.q.active) { const Q = QD.QUESTS[id]; if (Q.goal.type !== 'boss') continue; const t = GD.TOWNS.find(t => t.id === Q.goal.spot[0]), sp = t.spotsPos[Q.goal.spot[1]];
    if (Math.hypot(sp.x - me.x, sp.z - me.z) < 140 && !S.mobs.some(m => !m.dead && m.fam.id === Q.goal.fam)) spawnMob(FAM[Q.goal.fam], t.max + 2 > 80 ? 80 : t.max + 2, sp.x + 8, sp.z + 8); }
  // chefes especiais dos castelos, ruínas e covis (renascem a cada 10 min)
  S.lmCd = S.lmCd || {};
  for (const L of GD.LANDMARKS) { const d = Math.hypot(L.x - me.x, L.z - me.z); if (d > 140 || (S.lmCd[L.id] || 0) > Date.now() || S.mobs.some(m => !m.dead && m.fam.id === L.boss)) continue;
    const m = spawnMob(FAM[L.boss], L.lvl, L.x + 2, L.z + 2); m.landmark = L.id; addChat({ kind: 'sys', msg: `🏰 ${FAM[L.boss].name} guarda ${L.name}. Derrote-o para conseguir itens exclusivos!` }); S.lmCd[L.id] = Date.now() + 600000; }
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
    else if (m.returning) { tx = m.home.x; tz = m.home.z; spd *= 1.6; }
    else if (m.aggro) { if (dP > reach) { tx = me.x; tz = me.z; spd *= 1.25; } else if (t >= m.nextAtk) { m.nextAtk = t + 1500; m.model.anim.atk = now(); m.ry = Math.atan2(me.x - m.x, me.z - m.z); const d = dmgVs(m.st.atk * (1 + debOf(m, 'atk')), 1, st.pdef, 0.05); hurtMe(d.v); } }
    else { if (!m.wander || t > m.wanderT) { m.wanderT = t + 3000 + Math.random() * 4000; m.wander = Math.random() < 0.5 ? null : { x: m.home.x + (Math.random() - 0.5) * 30, z: m.home.z + (Math.random() - 0.5) * 30 }; } if (m.wander) { tx = m.wander.x; tz = m.wander.z; spd *= 0.35; } }
    let moving = false;
    if (tx != null) { const dx = tx - m.x, dz = tz - m.z, d = Math.hypot(dx, dz); if (d > 0.5) { const nx = m.x + dx / d * spd * dt, nz = m.z + dz / d * spd * dt; if (!blocked(nx, nz) && !inSafe(nx, nz)) { m.x = nx; m.z = nz; moving = true; } else if (m.returning) { m.x = m.home.x; m.z = m.home.z; } else m.wander = null; m.ry = Math.atan2(dx, dz); } }
    m.model.root.position.set(m.x, WG.height(m.x, m.z), m.z); m.model.root.rotation.y = m.ry;
    animMob(m.model, dt, moving);
  }
}

// ---------- movimento ----------
function blocked(x, z) { if (x < 20 || z < 20 || x > 2980 || z > 2980) return true; if (WG.height(x, z) < WG.WATER + 0.25) return true; for (const h of houses) if ((x - h.x) ** 2 + (z - h.z) ** 2 < h.r * h.r) return true; return false; }
function teleport(x, z) { me.x = x; me.z = z; S.dest = null; S.target = null; S.autoAtk = false; S.mobs.forEach(m => scene.remove(m.model.root)); S.mobs = []; updateChunks(x, z, true); saveNow(); }
function updateMe(dt) {
  const st = stats(); let vx = 0, vz = 0, moving = false;
  const typing = document.activeElement && document.activeElement.tagName === 'INPUT';
  if (!S.dead && !typing) {
    const f = (keys.KeyW || keys.ArrowUp ? 1 : 0) - (keys.KeyS || keys.ArrowDown ? 1 : 0), r = (keys.KeyD || keys.ArrowRight ? 1 : 0) - (keys.KeyA || keys.ArrowLeft ? 1 : 0);
    if (f || r) { const sy = Math.sin(cam.yaw), cy = Math.cos(cam.yaw); vx = -sy * f + cy * r; vz = -cy * f - sy * r; S.dest = null; S.gatherAt = null; S.npcAt = null; S.channel = null; S.autoAtk = false; }
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
  if (vx || vz) {
    const l = Math.hypot(vx, vz), sp = st.speed * dt, nx = me.x + vx / l * sp, nz = me.z + vz / l * sp;
    if (!blocked(nx, nz)) { me.x = nx; me.z = nz; moving = true; } else if (!blocked(nx, me.z)) { me.x = nx; moving = true; } else if (!blocked(me.x, nz)) { me.z = nz; moving = true; } else S.dest = null;
    me.ry = Math.atan2(vx, vz); S.channel = null;
  }
  me.anim.state = S.dead ? 'dead' : moving ? 'run' : 'idle';
  let a = me.root.rotation.y, d = me.ry - a; d = Math.atan2(Math.sin(d), Math.cos(d)); me.root.rotation.y = a + d * Math.min(1, dt * 10);
  me.root.position.set(me.x, WG.height(me.x, me.z), me.z); animHumanoid(me, dt);
  // coleta
  if (S.channel) { const p = (now() - S.channel.start) / (S.channel.end - S.channel.start); $('#cast').hidden = false; $('#cast i').style.width = Math.min(100, p * 100) + '%'; $('#cast span').textContent = 'Coletando…'; if (p >= 1) { const n = S.channel.node; S.channel = null; gather(n); } else if (Math.random() < 0.03) playAttack(me, 'melee'); }
  else $('#cast').hidden = true;
  // regeneração e buffs
  if (!S.dead) {
    const town = inSafe(me.x, me.z), out = Date.now() - S.lastCombat > 6000, bv = buffVals();
    S.hp = Math.min(st.maxHp, S.hp + st.maxHp * ((town ? 0.08 : out ? 0.02 : 0.004) + (bv.hot || 0)) * dt);
    S.mp = Math.min(st.maxMp, S.mp + st.maxMp * (town ? 0.06 : 0.012) * dt);
  }
  if (destRing.visible) destRing.scale.setScalar(0.6 + Math.sin(now() / 200) * 0.15);
  const t = S.target && S.target.ref; if (t && !t.dead && (S.target.kind !== 'npc' || t.x)) { const p = S.target.kind === 'npc' ? t : S.target.kind === 'node' ? t : t; selRing.visible = true; selRing.position.set(p.x, WG.height(p.x, p.z) + 0.08, p.z); selRing.material.color.set(S.target.kind === 'mob' ? 0xff4040 : S.target.kind === 'player' ? 0x40a0ff : 0xffe36a); const sc = S.target.kind === 'mob' ? t.fam.scale * 1.2 : 1; selRing.scale.setScalar(sc); } else selRing.visible = false;
  // zona
  const rg = WG.region(me.x, me.z), zk = rg.town.id + (rg.safe ? 's' : '');
  if (zk !== S.zoneKey) { S.zoneKey = zk; $('#zone').textContent = rg.safe ? `${rg.town.name} — zona segura` : `Arredores de ${rg.town.name} • Nv. ${rg.town.min}–${rg.town.max}`; const th = THEMES[rg.town.theme]; S.skyTo = th; if (rg.safe) questEvent('reach', rg.town.id); }
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
  const sig = [p.ra, p.ge, p.h, p.hc, p.sk, p.w, p.a, p.k, p.f, p.g, p.n, JSON.stringify(p.lk || {}), JSON.stringify(p.ex || {})].join('|');
  if (!o) { o = S.others[p.id] = { id: p.id, x: p.x, z: p.z, ry: p.r }; }
  if (o.sig !== sig) {
    if (o.model) scene.remove(o.model.root);
    o.model = buildHumanoid({ race: p.ra, gender: p.ge, hair: p.h, hair_color: p.hc, skin: p.sk, look: p.lk || undefined, weapon: p.w, armor: p.a, equip: p.ex || {} });
    const l = makeLabel(p.n, nameColor({ gm: p.g, karma: p.k, flag: p.f }), 30); l.position.y = 2.25 * (GD.RACES[p.ra]?.h || 1); o.model.root.add(l);
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
    const c = S.c; B.sendPos({ id: c.id, n: c.name, x: +me.x.toFixed(2), z: +me.z.toFixed(2), r: +me.root.rotation.y.toFixed(2), st, ra: c.race, ge: c.gender, h: c.hair, hc: c.hair_color, sk: c.skin, lk: c.look || null, c: c.class_id, l: c.level,
      w: c.equipment.arma || null, a: c.equipment.armadura || null, ex: { elmo: c.equipment.elmo, luvas: c.equipment.luvas, botas: c.equipment.botas, escudo: c.equipment.escudo }, k: (c.karma || 0) > 0, f: S.flagUntil > t, g: !!c.is_gm, hp: Math.round(100 * S.hp / stats().maxHp), atk: me.anim.atk >= 0 ? me.anim.kind : null });
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
    case 'ir': { if (!gm) return; const t = GD.TOWNS.find(t => t.id.startsWith((a[0] || '').toLowerCase()) || t.name.toLowerCase().includes((a[0] || '').toLowerCase())); if (t) teleport(t.x, t.z + 25); return; }
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
function loadQuests() { try { S.q = JSON.parse(localStorage.getItem(qKey())) || { active: [], prog: {} }; } catch (_) { S.q = { active: [], prog: {} }; } S.q.active = S.q.active.filter(id => !S.c.quests?.[id] && QD.QUESTS[id]); }
function saveQuests() { localStorage.setItem(qKey(), JSON.stringify(S.q)); renderTracker(); }
function questReady(Q) { const g = Q.goal, p = S.q.prog[Q.id] || 0; if (g.type === 'kill') return p >= g.n; if (g.type === 'boss' || g.type === 'reach') return p >= 1; if (g.type === 'turnin') return Object.entries(g.items).every(([k, v]) => (S.inv[k] || 0) >= v); return false; }
function questEvent(type, key) {
  let ch = false;
  for (const id of S.q.active) { const Q = QD.QUESTS[id], g = Q.goal;
    if (type === 'kill' && (g.type === 'kill' && g.fam === key || g.type === 'boss' && g.fam === key)) { const n = (S.q.prog[id] || 0) + 1; S.q.prog[id] = n; ch = true; if (questReady(Q)) { addChat({ kind: 'q', msg: `Missão "${Q.title}" pronta! Volte a um Arauto do Eclipse.` }); toast(`📜 ${Q.title}: objetivo concluído!`, 'ok'); } }
    if (type === 'reach' && g.type === 'reach' && g.town === key && !S.q.prog[id]) { S.q.prog[id] = 1; ch = true; addChat({ kind: 'q', msg: `Missão "${Q.title}" pronta! Fale com o Arauto daqui.` }); } }
  if (ch) saveQuests();
}
function renderTracker() {
  const el = $('#quest-track'); if (!S.q.active.length) { el.hidden = true; return; } el.hidden = false;
  el.innerHTML = S.q.active.map(id => { const Q = QD.QUESTS[id], g = Q.goal, p = S.q.prog[id] || 0; const txt = g.type === 'kill' ? `${FAM[g.fam].name}: ${Math.min(p, g.n)}/${g.n}` : g.type === 'boss' ? `Derrotar ${FAM[g.fam].name}${p ? ' ✔' : ''}` : g.type === 'reach' ? `Chegar a ${GD.TOWNS.find(t => t.id === g.town).name}${p ? ' ✔' : ''}` : 'Entregar: ' + Object.entries(g.items).map(([k, v]) => `${iname(k)} ${Math.min(S.inv[k] || 0, v)}/${v}`).join(', ');
    return `<div style="margin-bottom:5px"><b>${Q.main ? '★ ' : ''}${esc(Q.title)}</b><div class="small">${esc(txt)}${questReady(Q) ? ' — <span style="color:#9be37a">pronta</span>' : ''}</div></div>`; }).join('');
}

// ---------- painéis ----------
let panelState = {};
function openPanel(kind, o = {}) { panelState = { kind, ...o }; $('#panel').hidden = false; renderPanel(); }
function closePanel() { $('#panel').hidden = true; panelState = {}; }
$('#p-close').onclick = closePanel;
document.querySelectorAll('#menu button').forEach(b => b.onclick = () => panelState.kind === b.dataset.p ? closePanel() : openPanel(b.dataset.p));
function openNpc(n) {
  const map = { portal: 'teleport', classe: 'classe', ferreiro: 'craft', refino: 'craft', mercador: 'shop', leilao: 'market', arauto: 'arauto' };
  openPanel(map[n.type], { npc: n, station: n.type === 'ferreiro' ? 'forja' : n.type === 'refino' ? 'refinaria' : null, tab: 'buy' });
}
const nearNpc = (type) => S.c.is_gm || npcs.some(n => n.type === type && Math.hypot(n.x - me.x, n.z - me.z) < 8);
function slot(id, q, extra = '') { const it = IT(id); return `<div class="slot" data-id="${id}" ${extra} style="border-color:${gcol(it.grade)}88"><span class="g" style="color:${gcol(it.grade)}">${GD.GRADES[it.grade].id}</span>${q != null ? `<span class="q">${q}</span>` : ''}<div class="ic">${it.icon}</div><div class="nm">${esc(it.name)}</div></div>`; }
function itemDesc(id) {
  const it = IT(id), s = it.stats || {}, p = [];
  if (s.patk) p.push(`Ataque Físico +${s.patk}`); if (s.matk) p.push(`Ataque Mágico +${s.matk}`); if (s.pdef) p.push(`Def. Física +${Math.round(s.pdef)}`); if (s.mdef) p.push(`Def. Mágica +${Math.round(s.mdef)}`);
  if (s.hp && !s.hpPct) p.push(`Vida +${Math.round(s.hp)}`); if (s.mp) p.push(`Mana +${Math.round(s.mp)}`); if (s.spd) p.push(`Velocidade +${s.spd * 100}%`); if (s.matkPct) p.push(`Ataque Mágico +${s.matkPct * 100}%`);
  if (s.hpPct) p.push(`Recupera ${s.hpPct * 100}% da vida`); if (s.mpPct) p.push(`Recupera ${s.mpPct * 100}% da mana`);
  if (it.slot) p.push(`Requer nível ${GD.GRADES[it.grade].lvl}`); if (it.type === 'tool') p.push(`Permite coletar recursos até grau ${GD.GRADES[Math.min(5, it.grade + 1)].id}`);
  if (it.type === 'scroll') p.push('Teleporta para a cidade mais próxima'); if (it.type === 'raw') p.push('Refine no Refinador'); if (it.type === 'refined') p.push('Material de forja');
  return p.join(' • ');
}
function renderPanel() {
  const k = panelState.kind; if (!k) return; const body = $('#p-body'); body.onclick = null;
  const T = { char: 'Personagem', bag: 'Inventário', skills: 'Habilidades', quests: 'Diário de Missões', map: 'Mapa do Reino', lore: 'Crônicas de Valtheria', gm: 'Painel do GM', sys: 'Sistema', teleport: 'Guardião do Portal', classe: 'Mestre de Classes', craft: panelState.station === 'forja' ? 'Ferreiro' : 'Refinador e Alquimista', shop: 'Mercador', market: 'Casa de Leilões', arauto: 'Arauto do Eclipse' };
  $('#p-title').textContent = T[k] || k; body.innerHTML = '';
  ({ char: pChar, bag: pBag, skills: pSkills, quests: pQuests, map: pMap, lore: pLore, gm: pGm, sys: pSys, teleport: pTeleport, classe: pClasse, craft: pCraft, shop: pShop, market: pMarket, arauto: pArauto })[k](body);
}
function pChar(b) {
  const c = S.c, st = stats(), cl = st.cls, eq = c.equipment, P = c.profs || {};
  const es = (s, l) => eq[s] ? slot(eq[s], null, `data-slot="${s}"`) : `<div class="slot" data-slot="${s}"><div class="ic">▫️</div><div class="nm">${l}</div></div>`;
  b.innerHTML = `<div class="row"><div class="grow"><b style="font-size:16px">${esc(c.name)}</b><div class="small">${GD.RACES[c.race].name} • ${cl.name} (${['Classe base', '2ª classe', '3ª classe', '4ª classe'][cl.rank]}) • Nível ${c.level}</div></div></div>
  <div class="grid" style="grid-template-columns:repeat(4,90px);margin:8px 0">${es('elmo', 'Elmo')}${es('armadura', 'Armadura')}${es('arma', 'Arma')}${es('escudo', 'Escudo')}${es('luvas', 'Luvas')}${es('botas', 'Botas')}</div>
  <table><tr><td>Vida</td><td>${Math.round(S.hp)} / ${st.maxHp}</td><td>Mana</td><td>${Math.round(S.mp)} / ${st.maxMp}</td></tr>
  <tr><td>Ataque Físico</td><td>${Math.round(st.patk)}</td><td>Ataque Mágico</td><td>${Math.round(st.matk)}</td></tr>
  <tr><td>Defesa Física</td><td>${Math.round(st.pdef)}</td><td>Defesa Mágica</td><td>${Math.round(st.mdef)}</td></tr>
  <tr><td>Velocidade</td><td>${st.speed.toFixed(1)} m/s</td><td>Alcance</td><td>${st.range} m</td></tr>
  <tr><td>Crítico</td><td>${Math.round(st.crit * 100)}%</td><td>Aurum</td><td>${Number(c.aurum).toLocaleString('pt-BR')}</td></tr>
  <tr><td>PvP</td><td>${c.pvp || 0}</td><td>PK / Karma</td><td style="color:${c.karma ? '#f66' : ''}">${c.pk || 0} / ${c.karma || 0}</td></tr></table>
  <h4>Profissões</h4><table>${Object.entries(GD.PROFS).map(([k, n]) => { const l = GD.profLevel(P[k]); return `<tr><td>${n}</td><td>nível ${l}</td><td class="small">libera até grau ${GD.GRADES[Math.min(5, Math.floor(l / 4))].id}</td></tr>`; }).join('')}</table>`;
  b.onclick = async e => { const s = e.target.closest('[data-slot]'); if (!s || !eq[s.dataset.slot]) return; const r = await safe(() => B.unequip(s.dataset.slot), 'Desequipado'); if (r) { S.c.equipment = r; await refresh(); setGear(me, r.arma, r.armadura, r); renderPanel(); } };
}
function pBag(b) {
  const f = panelState.f || 'all', order = { weapon: 0, armor: 1, tool: 2, potion: 3, scroll: 4, special: 5, refined: 6, raw: 7 };
  const ids = Object.keys(S.inv).filter(i => IT(i)).filter(i => { const t = IT(i).type; return f === 'all' || f === t || (f === 'gear' && (t === 'weapon' || t === 'armor')) || (f === 'mat' && ['raw', 'refined', 'special'].includes(t)) || (f === 'use' && ['potion', 'scroll', 'tool'].includes(t)); })
    .sort((a, c) => order[IT(a).type] - order[IT(c).type] || IT(c).grade - IT(a).grade || a.localeCompare(c));
  b.innerHTML = `<div class="chips">${[['all', 'Tudo'], ['gear', 'Equipamentos'], ['mat', 'Materiais'], ['use', 'Consumíveis']].map(([k, l]) => `<button data-f="${k}" class="${k === f ? 'on' : ''}">${l}</button>`).join('')}</div>
    <div class="small">🪙 ${Number(S.c.aurum).toLocaleString('pt-BR')} aurum</div><div id="bdet"></div><div class="grid">${ids.map(i => slot(i, S.inv[i])).join('') || '<div class="small">Inventário vazio</div>'}</div>`;
  b.onclick = async e => {
    if (e.target.dataset.f) { panelState.f = e.target.dataset.f; return renderPanel(); }
    const a = e.target.dataset.a, id = panelState.sel;
    if (a === 'eq') { const r = await safe(() => B.equip(id), 'Equipado'); if (r) { S.c.equipment = r; await refresh(); setGear(me, r.arma, r.armadura, r); S.hp = Math.min(S.hp, stats().maxHp); buildBar(); renderPanel(); } return; }
    if (a === 'bar') { addToBar({ t: 'i', id }); return; }
    if (a === 'use') { const it = IT(id); if (it.type === 'scroll') { const r = await safe(() => B.useItem(id)); if (r) { S.inv[id]--; if (!S.inv[id]) delete S.inv[id]; toast('Retornando a ' + r.town, 'ok'); teleport(r.x, r.z); renderPanel(); } } else { await usePotion(id.startsWith('pocao_mp') ? 'mp' : 'hp'); renderPanel(); } return; }
    const s = e.target.closest('.slot'); if (!s) return; const sid = s.dataset.id; panelState.sel = sid; const it = IT(sid);
    $('#bdet').innerHTML = `<div class="row"><div style="font-size:28px">${it.icon}</div><div class="grow"><b style="color:${gcol(it.grade)}">${esc(it.name)}</b> x${S.inv[sid]}<div class="small">${itemDesc(sid)}</div></div>
      ${it.slot ? '<button class="btn" data-a="eq">Equipar</button>' : ''}${['potion', 'scroll'].includes(it.type) ? '<button class="btn" data-a="use">Usar</button>' : ''}${['potion', 'scroll'].includes(it.type) || it.slot ? '<button class="btn alt" data-a="bar">➕ Barra</button>' : ''}</div>`;
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
  ${['hit', 'buff', 'debuff', 'outros'].map(g => { const list = st.arch.skills.filter(s => g === 'outros' ? !['hit', 'buff', 'debuff'].includes(s.type) : s.type === g); if (!list.length) return ''; return `<h4>${{ hit: '⚔️ Ataques', buff: '✨ Buffs (melhoram seus atributos)', debuff: '☠️ Debuffs (enfraquecem o inimigo)', outros: '🔧 Suporte e movimento' }[g]}</h4>` + list.map(s => `<div class="row skrow" draggable="${S.c.level >= s.lvl}" data-sid="${esc(s.id)}" style="${S.c.level < s.lvl ? 'opacity:.45' : ''}"><div class="sk skill t-${s.type}" style="flex:none">${s.icon}</div><div class="grow"><b>${s.name}</b> <span class="small">nível ${s.lvl} • ${s.mp} MP • recarga ${s.cd}s</span>
  <div class="small">${skillDesc(s)}</div></div>${S.c.level >= s.lvl ? `<button class="btn alt" data-add="${esc(s.id)}">➕</button>` : ''}</div>`).join(''); }).join('')}
  <h4>Próximas classes</h4><div class="tree">${treeHtml(cl.id)}</div>`;
}
function skillDesc(s) { const p = []; if (s.type === 'hit') p.push(`Causa ${Math.round(s.mult * 100)}% de dano${s.aoe ? ` em área (${s.aoe} m)` : ''}`); if (s.stun) p.push(`atordoa ${s.stun}s`); if (s.slow) p.push('reduz a velocidade do alvo'); if (s.dot) p.push(`dano contínuo por ${s.dot.dur}s`); if (s.drain) p.push('rouba vida'); if (s.execute) p.push('dano dobrado em alvos com menos de 30% de vida');
  if (s.type === 'buff') p.push('Fortalece por ' + s.dur + 's: ' + Object.keys(s.buff).map(k => ({ pdef: 'defesa física', mdef: 'defesa mágica', patk: 'ataque físico', matk: 'ataque mágico', crit: 'crítico', speed: 'velocidade', lifesteal: 'roubo de vida', dodge: 'esquiva', atkspd: 'velocidade de ataque', invuln: 'invulnerabilidade', hot: 'regeneração' }[k])).join(', '));
  if (s.type === 'debuff') { p.push('Enfraquece ' + (s.aoe ? `os inimigos em ${s.aoe} m` : 'o alvo') + ` por ${s.dur}s: ` + Object.entries(s.deb).map(([k, v]) => `${{ atk: 'ataque', def: 'defesa', speed: 'velocidade' }[k]} ${Math.round(v * 100)}%`).join(', ')); if (s.hitMult) p.push(`e causa ${Math.round(s.hitMult * 100)}% de dano`); if (s.stun) p.push(`atordoa ${s.stun}s`); if (s.dot) p.push('com dano contínuo'); }
  if (s.cleanse) p.push('remove efeitos negativos');
  if (s.type === 'heal') p.push(`Cura ${s.pct * 100}% da vida`); if (s.type === 'mana') p.push(`Recupera ${s.pct * 100}% da mana`); if (s.type === 'dash') p.push(`Avança até o alvo (${s.range} m) e golpeia`); if (s.type === 'leap') p.push(`Salta ${s.dist} m para trás`); if (s.type === 'taunt') p.push('Atrai todos os monstros próximos');
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
  b.innerHTML = `<div class="small">"Os portais conectam as seis cidades e as terras de caça. Escolha seu destino."</div>${GD.TOWNS.map(t => `<h4>${esc(t.name)} <span class="small">Nv. ${t.min}–${t.max}</span></h4>` + TELEPORTS.filter(x => x.id === 'town:' + t.id || x.id.startsWith('spot:' + t.id + ':')).map(x => `<div class="row"><div class="grow">${x.town ? '🏰' : '⚔️'} ${esc(x.name)} <span class="small">(nv ${x.lvl})</span></div><span class="small">${gm ? 'grátis' : x.cost + ' aurum'}</span><button class="btn" data-d="${x.id}">Ir</button></div>`).join('')).join('')}`;
  b.onclick = async e => { const d = e.target.dataset.d; if (!d) return; const r = await safe(() => B.teleport(d)); if (!r) return; S.c.aurum -= r.cost; closePanel(); toast('Teleportado para ' + r.name, 'ok'); teleport(r.x, r.z); };
}
function pArauto(b) {
  const done = S.c.quests || {}, here = panelState.npc?.town?.id;
  const ready = S.q.active.filter(id => questReady(QD.QUESTS[id]));
  const avail = QD.LIST.filter(Q => !done[Q.id] && !S.q.active.includes(Q.id) && (!Q.prereq || done[Q.prereq]) && (Q.town === here || S.c.is_gm));
  b.innerHTML = `<div class="small">"O Eclipse cresce a cada noite, aventureiro. Que tarefa aceitará?"</div>
  ${ready.length ? '<h4>Prontas para entregar</h4>' + ready.map(id => `<div class="row"><div class="grow"><b>${esc(QD.QUESTS[id].title)}</b><div class="small">${rewardTxt(QD.QUESTS[id].reward)}</div></div><button class="btn" data-done="${id}">Concluir</button></div>`).join('') : ''}
  <h4>Missões disponíveis</h4>${avail.map(Q => { const ok = S.c.level >= Q.lvl; return `<div class="row"><div class="grow"><b>${Q.main ? '★ ' : ''}${esc(Q.title)}</b> <span class="small">nv ${Q.lvl}</span><div class="small">${esc(Q.text)}</div><div class="small" style="color:#c5f5b0">${rewardTxt(Q.reward)}</div></div><button class="btn" data-acc="${Q.id}" ${ok ? '' : 'disabled'}>Aceitar</button></div>`; }).join('') || '<div class="small">Nenhuma missão nova aqui por enquanto.</div>'}`;
  b.onclick = async e => { const a = e.target.dataset.acc, d = e.target.dataset.done;
    if (a) { S.q.active.push(a); S.q.prog[a] = 0; saveQuests(); toast('Missão aceita: ' + QD.QUESTS[a].title, 'ok'); renderPanel(); }
    if (d) { const r = await safe(() => B.questDone(d)); if (!r) return; S.c.quests = { ...(S.c.quests || {}), [d]: true }; S.q.active = S.q.active.filter(x => x !== d); saveQuests();
      toast(`📜 Missão concluída: ${QD.QUESTS[d].title}!`, 'ok'); addChat({ kind: 'q', msg: `Recompensa: ${rewardTxt(r.reward)}` }); const L = S.c.level; await refresh(); if (S.c.level > L) { S.c.level = L; levelUp(r.level); } renderPanel(); } };
}
const rewardTxt = (r) => [r.xp ? `${Number(r.xp).toLocaleString('pt-BR')} XP` : '', r.aurum ? `${Number(r.aurum).toLocaleString('pt-BR')} aurum` : '', ...Object.entries(r.items || {}).map(([k, v]) => `${v}x ${iname(k)}`)].filter(Boolean).join(' • ');
function pQuests(b) {
  b.innerHTML = `<h4>Ativas</h4>${S.q.active.map(id => { const Q = QD.QUESTS[id]; return `<div class="row"><div class="grow"><b>${Q.main ? '★ ' : ''}${esc(Q.title)}</b><div class="small">${esc(Q.text)}</div><div class="small" style="color:#c5f5b0">${rewardTxt(Q.reward)}</div></div><button class="btn red" data-ab="${id}">Abandonar</button></div>`; }).join('') || '<div class="small">Nenhuma. Visite o Arauto do Eclipse na praça de qualquer cidade.</div>'}
  <h4>Concluídas</h4><div class="small">${Object.keys(S.c.quests || {}).map(id => esc(QD.QUESTS[id]?.title)).join(' • ') || '—'}</div>`;
  b.onclick = e => { const id = e.target.dataset.ab; if (id && confirm('Abandonar a missão?')) { S.q.active = S.q.active.filter(x => x !== id); delete S.q.prog[id]; saveQuests(); renderPanel(); } };
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
  b.innerHTML = `<div class="row"><div class="grow">Sombras de alta qualidade</div><button class="btn alt" id="sh">${renderer.shadowMap.enabled ? 'Ligadas' : 'Desligadas'}</button></div>
  <div class="row"><div class="grow">Controles</div></div><div class="small">Clique esquerdo: andar / selecionar • clique de novo no alvo (ou duplo clique): atacar • Ctrl + clique: atacar jogador (PvP) • botão direito arrastando: girar câmera • roda: zoom • WASD: andar • 1–7 ou F1–F7: habilidades • Espaço/F: atacar • Tab: próximo alvo • 8/9: poções • Enter: chat • C, I, K, L, M, H: janelas</div>
  <button class="primary" id="tochars">Trocar de personagem</button><button class="link" id="lo">Sair da conta</button>`;
  b.onclick = async e => { if (e.target.id === 'sh') { renderer.shadowMap.enabled = !renderer.shadowMap.enabled; scene.traverse(o => { if (o.material) o.material.needsUpdate = true; }); renderPanel(); }
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
const BAR_N = 12, BAR_KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '='];
function barKey() { return 'vt_bar_' + S.c.id; }
function defaultBar() { const st = stats(), sk = st.arch.skills.filter(s => s.type !== 'buff' || s.lvl <= S.c.level).slice(0, 9).map(s => ({ t: 's', id: s.id })); while (sk.length < 10) sk.push(null); return [...sk.slice(0, 10), { t: 'i', id: 'pocao_hp' }, { t: 'i', id: 'pocao_mp' }]; }
function loadBar() { try { const b = JSON.parse(localStorage.getItem(barKey())); if (Array.isArray(b) && b.length === BAR_N) { S.bar = b; return; } } catch (_) {} S.bar = defaultBar(); }
function saveBar() { localStorage.setItem(barKey(), JSON.stringify(S.bar)); }
function skillIndex(id) { return stats().arch.skills.findIndex(s => s.id === id); }
function useSlot(n) { const e = S.bar[n]; if (!e) return; if (e.t === 's') { const i = skillIndex(e.id); if (i >= 0) castSkill(i); } else useBagItem(e.id); }
async function useBagItem(id) { const it = IT(id); if (!it) return; if (!S.inv[id]) { toast(`Sem ${it.name} na bolsa`, 'err'); return; }
  if (it.type === 'scroll') { const r = await safe(() => B.useItem(id)); if (r) { S.inv[id]--; if (!S.inv[id]) delete S.inv[id]; toast('Retornando a ' + r.town, 'ok'); teleport(r.x, r.z); } }
  else if (it.type === 'potion') await usePotion(id.startsWith('pocao_mp') ? 'mp' : 'hp', id);
  else if (it.slot) { const r = await safe(() => B.equip(id), 'Equipado'); if (r) { S.c.equipment = r; await refresh(); setGear(me, r.arma, r.armadura, r); } }
  buildBar(); }
function buildBar() {
  if (!S.bar) loadBar(); const st = stats();
  $('#bar').innerHTML = S.bar.map((e, n) => {
    let inner = '', title = 'Vazio — arraste uma habilidade (K) ou item da bolsa (I) para cá', cls = 'empty';
    if (e && e.t === 's') { const s = st.arch.skills.find(x => x.id === e.id); if (s) { inner = s.icon + '<div class="cd" hidden></div>'; title = `${s.name} • nível ${s.lvl} • ${s.mp} MP • ${s.cd}s`; cls = S.c.level < s.lvl ? 'off' : ''; } }
    else if (e && e.t === 'i') { const it = IT(e.id); if (it) { inner = (it.icon || '📦') + `<span class="n">${S.inv[e.id] || 0}</span>`; title = it.name; cls = S.inv[e.id] ? '' : 'off'; } }
    return `<div class="sk ${cls} ${e && e.t === 's' ? 'skill t-' + (st.arch.skills.find(x => x.id === e.id)?.type || '') : ''}" data-n="${n}" title="${esc(title)}" draggable="${!!e}"><span class="key">${BAR_KEYS[n]}</span>${inner}</div>`;
  }).join('');
  const bar = $('#bar');
  bar.onclick = e => { const k = e.target.closest('.sk'); if (k) useSlot(+k.dataset.n); };
  bar.oncontextmenu = e => { e.preventDefault(); const k = e.target.closest('.sk'); if (!k) return; S.bar[+k.dataset.n] = null; saveBar(); buildBar(); };
  bar.ondragstart = e => { const k = e.target.closest('.sk'); if (k) e.dataTransfer.setData('text/plain', JSON.stringify({ from: +k.dataset.n })); };
  bar.ondragover = e => e.preventDefault();
  bar.ondrop = e => { e.preventDefault(); const k = e.target.closest('.sk'); if (!k) return; let d; try { d = JSON.parse(e.dataTransfer.getData('text/plain')); } catch (_) { return; } const n = +k.dataset.n;
    if (d.from != null) { const tmp = S.bar[n]; S.bar[n] = S.bar[d.from]; S.bar[d.from] = tmp; } else if (d.t) S.bar[n] = { t: d.t, id: d.id }; saveBar(); buildBar(); };
}
function addToBar(entry) { let n = S.bar.findIndex(e => e && e.t === entry.t && e.id === entry.id); if (n >= 0) { toast('Já está na barra', 'err'); return; } n = S.bar.findIndex(e => !e); if (n < 0) { toast('Barra cheia — clique com o botão direito num atalho para liberar', 'err'); return; } S.bar[n] = entry; saveBar(); buildBar(); toast('Adicionado à barra (tecla ' + BAR_KEYS[n] + ')', 'ok'); }
function updateHud() {
  const c = S.c, st = stats(), need = GD.xpNeed(c.level);
  $('#st-name').innerHTML = `<span style="color:${nameColor({ gm: c.is_gm, karma: c.karma, flag: S.flagUntil > Date.now() })}">${c.is_gm ? '[GM] ' : ''}${esc(c.name)}</span> <span class="small">Nv. ${c.level}</span>`;
  $('#st-class').textContent = `${GD.RACES[c.race].name} • ${st.cls.name}`;
  $('#b-hp').style.width = Math.max(0, 100 * S.hp / st.maxHp) + '%'; $('#t-hp').textContent = `${Math.ceil(Math.max(0, S.hp))} / ${st.maxHp}`;
  $('#b-mp').style.width = 100 * S.mp / st.maxMp + '%'; $('#t-mp').textContent = `${Math.floor(S.mp)} / ${st.maxMp}`;
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
function showPreview(o) { if (preview) studio.remove(preview.root); preview = buildHumanoid(o); studio.add(preview.root); }
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
  if (blocked(me.x, me.z) || S.c.hp <= 0) { const t = WG.nearestTown(me.x, me.z).town; me.x = t.x; me.z = t.z + 25; }
  updateChunks(me.x, me.z, true); loadQuests(); renderTracker(); buildBar();
  show('#hud'); S.inGame = true; $('#btn-gm').hidden = !S.c.is_gm;
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
function grassOk(x, z) { const th = THEMES[WG.nearestTown(x, z).town.theme]; if (!th.grass) return false; const h = WG.height(x, z); return h > 1.6 && h < 34 && WG.nearestTown(x, z).dist > 31 && WG.roadDist(x, z) > 4.5 && !houses.some(o => Math.abs(o.x - x) < o.r && Math.abs(o.z - z) < o.r); }
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
  renderer.toneMappingExposure = 1.05 + day * 0.05;
  WIND.time.value = t; WIND.strength.value = 0.7 + Math.sin(t * 0.07) * 0.35 + Math.sin(t * 0.31) * 0.15;
  WATER.mat.uniforms.sunDir.value.copy(day > 0.05 ? sd : md); WATER.mat.uniforms.night.value = night; WATER.mat.uniforms.fogColor.value.copy(scene.fog.color); WATER.mat.uniforms.skyC.value.copy(skyMat.uniforms.bot.value).lerp(nightFog, night);
  updateFires(dt, t, night, camera.position); updateTownAnim(t);
}
// ---------- laço principal ----------
const clock = new THREE.Clock(); const skyTop = new THREE.Color(), skyBot = new THREE.Color(), fogC = new THREE.Color();
function loop() {
  requestAnimationFrame(loop);
  const dt = Math.min(0.05, clock.getDelta());
  if (S.inGame && me) {
    updateMe(dt); updateMobs(dt); updateOthers(dt); updateFx(dt); updateCamera(); updateChunks(me.x, me.z, false);
    updateEnvironment(dt); water.position.x = Math.round(me.x / 50) * 50; water.position.z = Math.round(me.z / 50) * 50; sky.position.copy(camera.position);
    if (!GRASS.center || Math.hypot(GRASS.center.x - me.x, GRASS.center.z - me.z) > 12) layoutGrass(GRASS, me.x, me.z, WG.height, grassOk, grassColor); updateTownVisibility();
    npcs.forEach(n => { if (n.crystal) { n.crystal.rotation.y += dt * (n.crystal.userData.spin2 ? 0.8 : 0.6); if (n.crystal.userData.spin) n.crystal.position.y = WG.TOWN_H + 6 + Math.sin(clock.elapsedTime * 1.5) * 0.4; } else if (n.model && Math.hypot(n.x - me.x, n.z - me.z) < 80) animHumanoid(n.model, dt); });
  } else if (studio.visible) {
    { const ph = preview ? (GD.RACES[preview.race]?.h || 1) : 1, close = clamp((3.2 - stu.dist) / 2.3, 0, 1), ty = -500 + 1.0 * ph + 0.62 * ph * close; camera.position.set(Math.sin(stu.yaw) * Math.cos(stu.pitch) * stu.dist + 0.35 * (1 - close), ty + Math.sin(stu.pitch) * stu.dist, Math.cos(stu.yaw) * Math.cos(stu.pitch) * stu.dist); camera.lookAt(0.35 * (1 - close), ty, 0); if (preview) animHumanoid(preview, dt); }
    sun.position.set(3, -490, 6); sun.target.position.set(0, -500, 0); sky.position.copy(camera.position);
  }
  renderer.render(scene, camera);
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
window.__game = { townGroups, houses, S, scene, camera, onPos: (p) => onPos(p), renderPanel: () => renderPanel(), teleport: (x, z) => teleport(x, z), spawnMob: (f, l, x, z) => spawnMob(FAM[f], l, x, z), get me() { return me; }, cam, command, openPanel, castSkill };
