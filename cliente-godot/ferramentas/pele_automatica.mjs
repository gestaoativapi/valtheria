// Pele automática para modelos em pose T (Meshy) usando o esqueleto do jogo. uso: node sk5.mjs <anao_m|anao_f>
import { NodeIO, Document } from '@gltf-transform/core'; import { ALL_EXTENSIONS } from '@gltf-transform/extensions'; import { weld, simplify } from '@gltf-transform/functions';
import { MeshoptDecoder, MeshoptSimplifier } from 'meshoptimizer'; import { mat4, quat, vec3 } from 'gl-matrix'; import sharp from 'sharp'; await MeshoptDecoder.ready; await MeshoptSimplifier.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.decoder': MeshoptDecoder });
const CFG = {
  anao_m: { src: '/home/claude/meshy/b.glb', height: 1.30, y0: -0.655, top: 0.65, tris: 30000,
    spine: { pelvis: [-0.14, 0], spine_01: [-0.03, 0], spine_02: [0.08, 0], spine_03: [0.19, 0], neck_01: [0.33, 0.01], Head: [0.40, 0.02] }, headTop: [0.58, 0.02], rTorso: 0.32, rHead: 0.22, rNeck: 0.12,
    arm: { z: -0.05, clav: [0.06, 0.29], upper: [0.30, 0.29], lower: [0.52, 0.28], hand: [0.70, 0.27], tip: [0.94, 0.26], r: [0.14, 0.12, 0.10, 0.10] },
    leg: { thigh: [0.15, -0.22, 0], calf: [0.17, -0.42, 0], foot: [0.20, -0.58, -0.02], ball: [0.20, -0.63, 0.10], tip: [0.20, -0.64, 0.22], r: [0.14, 0.12, 0.11, 0.10] }, hip: [0.15, -0.20, 0.22], shoulder: [0.2, 0.27, 0.2],
    extra: [['Head', [0, 0.36, 0.15], [0, 0.26, 0.2], 0.11]] },
  anao_f: { src: '/home/claude/meshy/a.glb', height: 1.22, y0: -0.69, top: 0.69, tris: 34000,
    spine: { pelvis: [-0.12, 0], spine_01: [-0.02, 0], spine_02: [0.08, 0], spine_03: [0.17, 0], neck_01: [0.28, 0], Head: [0.34, 0.01] }, headTop: [0.52, 0.01], rTorso: 0.24, rHead: 0.25, rNeck: 0.1,
    arm: { z: -0.04, clav: [0.06, 0.25], upper: [0.27, 0.24], lower: [0.50, 0.235], hand: [0.74, 0.225], tip: [0.94, 0.22], r: [0.12, 0.10, 0.08, 0.08] },
    leg: { thigh: [0.13, -0.16, 0], calf: [0.17, -0.40, 0], foot: [0.20, -0.60, -0.03], ball: [0.20, -0.66, 0.08], tip: [0.20, -0.67, 0.2], r: [0.12, 0.11, 0.11, 0.10] }, hip: [0.14, -0.17, 0.2], shoulder: [0.17, 0.22, 0.16],
    extra: [['Head', [-0.2, 0.58, 0], [0.2, 0.58, 0], 0.13], ['Head', [0.15, 0.46, 0], [0.15, 0.33, 0], 0.06], ['Head', [-0.15, 0.46, 0], [-0.15, 0.33, 0], 0.06]] },
};
const key = process.argv[2], C = CFG[key], ITER = +(process.argv[3] || 8);
const base = await io.read('/home/claude/mmo3d/web/assets/chars/base_male.glb'), src = await io.read(C.src);
await src.transform(weld());
{ const t = src.getRoot().listMeshes()[0].listPrimitives()[0].getIndices().getCount() / 3; if (t > C.tris * 1.2) await src.transform(simplify({ simplifier: MeshoptSimplifier, ratio: C.tris / t, error: 0.01 })); }
const bskin = base.getRoot().listSkins().sort((a, b) => b.listJoints().length - a.listJoints().length)[0], joints = bskin.listJoints(), names = joints.map(j => j.getName()), idx = Object.fromEntries(names.map((n, i) => [n, i]));
const S = C.height / (C.top - C.y0), T = (x, y, z) => [x * S, (y - C.y0) * S, z * S];
const sprim = src.getRoot().listMeshes()[0].listPrimitives()[0], SP = sprim.getAttribute('POSITION'), n = SP.getCount(), pos = new Float32Array(n * 3), v = [0, 0, 0];
for (let i = 0; i < n; i++) { SP.getElement(i, v); pos.set(T(v[0], v[1], v[2]), i * 3); }
const ind = Uint32Array.from(sprim.getIndices().getArray()); console.log(key, 'vertices', n, 'triangulos', ind.length / 3, 'escala', S.toFixed(3));
const J = { root: T(0, C.y0, 0) }; for (const [k, [y, z]] of Object.entries(C.spine)) J[k] = T(0, y, z);
for (const [sf, sd] of [['l', 1], ['r', -1]]) { const a = C.arm, l = C.leg, A = p => T(sd * p[0], p[1], a.z), L = p => T(sd * p[0], p[1], p[2]);
  Object.assign(J, { ['clavicle_' + sf]: A(a.clav), ['upperarm_' + sf]: A(a.upper), ['lowerarm_' + sf]: A(a.lower), ['hand_' + sf]: A(a.hand), ['thigh_' + sf]: L(l.thigh), ['calf_' + sf]: L(l.calf), ['foot_' + sf]: L(l.foot), ['ball_' + sf]: L(l.ball) }); }
const restW = joints.map(j => mat4.clone(j.getWorldMatrix())), restP = restW.map(m => [m[12], m[13], m[14]]), restQ = restW.map(m => { const q = quat.create(); mat4.getRotation(q, m); return quat.normalize(q, q); });
const parent = joints.map(j => idx[j.getParentNode()?.getName()] ?? -1), mainChild = { pelvis: 'spine_01', spine_01: 'spine_02', spine_02: 'spine_03', spine_03: 'neck_01', neck_01: 'Head' };
for (const sf of ['l', 'r']) Object.assign(mainChild, { ['clavicle_' + sf]: 'upperarm_' + sf, ['upperarm_' + sf]: 'lowerarm_' + sf, ['lowerarm_' + sf]: 'hand_' + sf, ['thigh_' + sf]: 'calf_' + sf, ['calf_' + sf]: 'foot_' + sf, ['foot_' + sf]: 'ball_' + sf });
const handK = (C.arm.tip[0] - C.arm.hand[0]) * S / 0.19;
const bindQ = [], bindP = [], delta = [];
for (let i = 0; i < joints.length; i++) { const nm = names[i], p = parent[i], pd = p >= 0 ? delta[p] : quat.create(); let dq = quat.clone(pd);
  if (mainChild[nm] && J[nm] && J[mainChild[nm]]) { const c = idx[mainChild[nm]], a = vec3.sub([], restP[c], restP[i]), b = vec3.sub([], J[mainChild[nm]], J[nm]); vec3.normalize(a, a); vec3.normalize(b, b); dq = quat.rotationTo(quat.create(), a, b); }
  delta[i] = dq; bindQ[i] = quat.normalize(quat.create(), quat.multiply(quat.create(), dq, restQ[i]));
  if (J[nm]) bindP[i] = J[nm]; else { const off = vec3.sub([], restP[i], restP[p]); vec3.transformQuat(off, off, delta[p]); if (/hand_|index|middle|ring|pinky|thumb/.test(names[p])) vec3.scale(off, off, handK); bindP[i] = vec3.add([], bindP[p], off); } }
const bindW = joints.map((_, i) => mat4.fromRotationTranslation(mat4.create(), bindQ[i], bindP[i])), ibm = new Float32Array(joints.length * 16); bindW.forEach((m, i) => ibm.set(mat4.invert(mat4.create(), m), i * 16));
const seg = [], addS = (b, a, c, r) => seg.push({ b: idx[b], a, c, r: r * S }), sp = C.spine, P3 = (y, z) => T(0, y, z);
addS('pelvis', J.pelvis, J.spine_01, C.rTorso); addS('pelvis', T(-C.hip[0], C.hip[1], 0), T(C.hip[0], C.hip[1], 0), C.hip[2]); addS('spine_01', J.spine_01, J.spine_02, C.rTorso); addS('spine_02', J.spine_02, J.spine_03, C.rTorso);
addS('spine_03', J.spine_03, P3((sp.spine_03[0] + sp.neck_01[0]) / 2, 0), C.rTorso); addS('spine_03', T(-C.shoulder[0], C.shoulder[1], 0), T(C.shoulder[0], C.shoulder[1], 0), C.shoulder[2]);
addS('neck_01', J.neck_01, J.Head, C.rNeck); addS('Head', J.Head, P3(...C.headTop), C.rHead);
for (const [b, a, c, r] of C.extra) addS(b, T(...a), T(...c), r);
for (const [sf, sd] of [['l', 1], ['r', -1]]) { const j = k => J[k + '_' + sf], a = C.arm, l = C.leg; addS('clavicle_' + sf, j('clavicle'), j('upperarm'), a.r[0] * 0.8); addS('upperarm_' + sf, j('upperarm'), j('lowerarm'), a.r[1]); addS('lowerarm_' + sf, j('lowerarm'), j('hand'), a.r[2]); addS('hand_' + sf, j('hand'), T(sd * a.tip[0], a.tip[1], a.z), a.r[3]);
  addS('thigh_' + sf, j('thigh'), j('calf'), l.r[0]); addS('calf_' + sf, j('calf'), j('foot'), l.r[1]); addS('foot_' + sf, j('foot'), j('ball'), l.r[2]); addS('ball_' + sf, j('ball'), T(sd * l.tip[0], l.tip[1], l.tip[2]), l.r[3]); }
const dseg = (p, a, c) => { const ab = vec3.sub([], c, a), ap = vec3.sub([], p, a), t = Math.max(0, Math.min(1, vec3.dot(ap, ab) / (vec3.dot(ab, ab) || 1))); return vec3.dist(p, vec3.scaleAndAdd([], a, ab, t)); };
const label = new Int32Array(n); for (let i = 0; i < n; i++) { const p = [pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2]]; let best = 1e9, bb = 0; for (const s of seg) { const d = dseg(p, s.a, s.c) / s.r; if (d < best) { best = d; bb = s.b; } } label[i] = bb; }
const rep = new Int32Array(n), seen = new Map(); for (let i = 0; i < n; i++) { const k = Math.round(pos[i * 3] * 5000) + ',' + Math.round(pos[i * 3 + 1] * 5000) + ',' + Math.round(pos[i * 3 + 2] * 5000); if (!seen.has(k)) seen.set(k, i); rep[i] = seen.get(k); }
const adj = Array.from({ length: n }, () => new Set()); for (let i = 0; i < ind.length; i += 3) { const [a, b, c] = [rep[ind[i]], rep[ind[i + 1]], rep[ind[i + 2]]]; adj[a].add(b).add(c); adj[b].add(a).add(c); adj[c].add(a).add(b); }
for (let i = 0; i < n; i++) label[i] = label[rep[i]];
let W = Array.from({ length: n }, (_, i) => new Map([[label[i], 1]]));
for (let it = 0; it < ITER; it++) { const N = []; for (let i = 0; i < n; i++) { if (rep[i] !== i || !adj[i].size) { N.push(W[i]); continue; } const m = new Map(W[i]); for (const j of adj[i]) for (const [b, w] of W[j]) m.set(b, (m.get(b) || 0) + w / adj[i].size); let s = 0; for (const w of m.values()) s += w; for (const [b, w] of m) m.set(b, w / s); N.push(m); } W = N; }
for (let i = 0; i < n; i++) if (rep[i] !== i) W[i] = W[rep[i]];
const JN = new Uint8Array(n * 4), WT = new Float32Array(n * 4); for (let i = 0; i < n; i++) { const top = [...W[i]].sort((a, b) => b[1] - a[1]).slice(0, 4); const s = top.reduce((a, b) => a + b[1], 0); top.forEach(([b, w], k) => { JN[i * 4 + k] = b; WT[i * 4 + k] = w / s; }); }
const doc = new Document(), buf = doc.createBuffer(), scene = doc.createScene(key), nodes = [];
for (let i = 0; i < joints.length; i++) { const p = parent[i], lp = p >= 0 ? vec3.transformQuat([], vec3.sub([], bindP[i], bindP[p]), quat.invert(quat.create(), bindQ[p])) : bindP[i]; const lq = p >= 0 ? quat.multiply(quat.create(), quat.invert(quat.create(), restQ[p]), restQ[i]) : restQ[i];
  nodes[i] = doc.createNode(names[i]).setTranslation(lp).setRotation(Array.from(quat.normalize(lq, lq))); }
for (let i = 0; i < joints.length; i++) (parent[i] >= 0 ? nodes[parent[i]] : scene).addChild(nodes[i]);
const skin = doc.createSkin(key).setInverseBindMatrices(doc.createAccessor().setType('MAT4').setArray(ibm).setBuffer(buf)); nodes.forEach(nd => skin.addJoint(nd)); skin.setSkeleton(nodes[0]);
const smat = sprim.getMaterial(), mat = doc.createMaterial('MI_' + key).setRoughnessFactor(0.82).setMetallicFactor(0).setDoubleSided(false);
const cpTex = async (t, nm) => t ? doc.createTexture(nm).setImage(new Uint8Array(await sharp(t.getImage()).resize(1024, 1024).jpeg({ quality: 88 }).toBuffer())).setMimeType('image/jpeg') : null;
mat.setBaseColorTexture(await cpTex(smat.getBaseColorTexture(), key + '_cor')); mat.setNormalTexture(await cpTex(smat.getNormalTexture(), key + '_normal'));
const acc = (type, arr) => doc.createAccessor().setType(type).setArray(arr).setBuffer(buf);
const prim = doc.createPrimitive().setAttribute('POSITION', acc('VEC3', pos)).setAttribute('NORMAL', acc('VEC3', Float32Array.from(sprim.getAttribute('NORMAL').getArray()))).setAttribute('TEXCOORD_0', acc('VEC2', Float32Array.from(sprim.getAttribute('TEXCOORD_0').getArray()))).setAttribute('JOINTS_0', acc('VEC4', JN)).setAttribute('WEIGHTS_0', acc('VEC4', WT)).setIndices(acc('SCALAR', ind)).setMaterial(mat);
scene.addChild(doc.createNode('Corpo_' + key).setMesh(doc.createMesh('Corpo_' + key).addPrimitive(prim)).setSkin(skin));
await io.write(`/home/claude/valtheria/cliente-godot/assets/chars/body_${key}.glb`, doc); const cnt = {}; for (const l of label) cnt[names[l]] = (cnt[names[l]] || 0) + 1; console.log(JSON.stringify(cnt)); console.log('pelvis', J.pelvis.map(x => +x.toFixed(3)), 'mao', J.hand_l.map(x => +x.toFixed(3)));
