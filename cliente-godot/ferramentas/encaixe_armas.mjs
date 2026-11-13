// Encaixe das armas: deixa cada modelo (vindo do Meshy) pronto para a mão do personagem.
// - origem no ponto onde a mão principal fecha (armas.json: "at", medido a partir da ponta do cabo)
// - cabo para -Z e lâmina/cabeça para +Z, em metros, para um personagem de 1,80 m
// - malha reduzida e texturas de 512 px, para não pesar no jogo
//
// Uso:
//   cd cliente-godot/ferramentas && npm install
//   node encaixe_armas.mjs <pasta com arma_<id>.glb> [pasta de saída = ../assets/armas]
//   (o id é o do item: espada_ng, espadao_c, escudo_b, lend_espada_harmonia ...)
//
// Regra de orientação: as imagens pedem a arma de pé, ponta para cima e cabo para baixo,
// e o Meshy mantém o "para cima" em +Y. Então o cabo é a ponta de baixo do eixo mais longo.
// Se o eixo mais longo não for o vertical, usa a ponta mais fina como cabo.
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { flatten, clearNodeTransform, transformMesh, weld, simplify, prune, dedup, textureCompress } from '@gltf-transform/functions';
import { MeshoptSimplifier, MeshoptDecoder } from 'meshoptimizer';
import { mat4 } from 'gl-matrix';
import sharp from 'sharp';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const ARMAS = JSON.parse(fs.readFileSync(path.join(AQUI, 'armas.json'), 'utf8'));
const [, , entrada, saidaArg] = process.argv;
if (!entrada) { console.log('uso: node encaixe_armas.mjs <pasta-ou-arquivo.glb> [saida]'); process.exit(1); }
const saida = saidaArg || path.join(AQUI, '..', 'assets', 'armas');
fs.mkdirSync(saida, { recursive: true });
await MeshoptSimplifier.ready; await MeshoptDecoder.ready;
const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.decoder': MeshoptDecoder });

const TRIS = { padrao: 6000, escudo: 4000, egide: 4000 };

function kindOf(id) {
  if (id.startsWith('lend_')) return 'espada';
  return id.split('_')[0];
}

function positions(doc) {
  const out = [];
  for (const mesh of doc.getRoot().listMeshes())
    for (const p of mesh.listPrimitives()) {
      const a = p.getAttribute('POSITION'), v = [0, 0, 0];
      for (let i = 0; i < a.getCount(); i++) out.push(a.getElement(i, v).slice());
    }
  return out;
}

// largura média da peça perto de cada ponta do eixo (para descobrir qual é o cabo)
function endWidth(pts, axis, lo, hi, fromLow) {
  const cut = fromLow ? lo + (hi - lo) * 0.1 : hi - (hi - lo) * 0.1;
  const sel = pts.filter(p => (fromLow ? p[axis] <= cut : p[axis] >= cut));
  if (!sel.length) return 0;
  const o = [0, 1, 2].filter(k => k !== axis);
  const c = o.map(k => sel.reduce((s, p) => s + p[k], 0) / sel.length);
  return sel.reduce((s, p) => s + Math.hypot(p[o[0]] - c[0], p[o[1]] - c[1]), 0) / sel.length;
}

async function fit(file) {
  const id = path.basename(file, '.glb').replace(/^arma_/, '');
  const kind = kindOf(id);
  const spec = ARMAS[kind];
  if (!spec) { console.log('  pulei', id, '(tipo desconhecido)'); return; }
  const doc = await io.read(file);
  await doc.transform(flatten(), dedup());
  for (const n of doc.getRoot().listNodes()) if (n.getMesh()) clearNodeTransform(n);
  await doc.transform(weld());
  const tris = doc.getRoot().listMeshes().flatMap(m => m.listPrimitives()).reduce((s, p) => s + (p.getIndices()?.getCount() || 0) / 3, 0);
  const alvo = TRIS[kind] || TRIS.padrao;
  if (tris > alvo * 1.2) await doc.transform(simplify({ simplifier: MeshoptSimplifier, ratio: alvo / tris, error: 0.01 }));

  const pts = positions(doc);
  const lo = [0, 1, 2].map(k => Math.min(...pts.map(p => p[k])));
  const hi = [0, 1, 2].map(k => Math.max(...pts.map(p => p[k])));
  const size = hi.map((h, k) => h - lo[k]);
  const center = hi.map((h, k) => (h + lo[k]) / 2);
  const axis = size.indexOf(Math.max(...size));
  const k = spec.len / size[axis];

  let m = mat4.create();
  if (spec.shield) {
    // escudo: só centraliza e acerta a altura; o jogo vira o escudo para fora do braço
    mat4.scale(m, m, [k, k, k]);
    mat4.translate(m, m, center.map(v => -v));
  } else {
    let handleLow;
    if (axis === 1) handleLow = true;
    else handleLow = endWidth(pts, axis, lo[axis], hi[axis], true) <= endWidth(pts, axis, lo[axis], hi[axis], false);
    const dir = handleLow ? 1 : -1;
    const handle = handleLow ? lo[axis] : hi[axis];
    const at = spec.at < 0 ? spec.len / 2 : spec.at;
    const grip = center.slice();
    grip[axis] = handle + dir * at / k;
    // gira o eixo da arma para +Z (cabo para -Z)
    const from = [0, 0, 0]; from[axis] = dir;
    const rot = mat4.create();
    if (axis === 0) mat4.fromYRotation(rot, -dir * Math.PI / 2);
    else if (axis === 1) mat4.fromXRotation(rot, dir * Math.PI / 2);
    else if (dir < 0) mat4.fromYRotation(rot, Math.PI);
    mat4.scale(m, m, [k, k, k]);
    mat4.multiply(m, m, rot);
    mat4.translate(m, m, grip.map(v => -v));
  }
  for (const mesh of doc.getRoot().listMeshes()) transformMesh(mesh, m);
  await doc.transform(textureCompress({ encoder: sharp, targetFormat: 'png', resize: [512, 512] }), prune());
  const out = path.join(saida, id + '.glb');
  await io.write(out, doc);
  const after = positions(doc);
  const zlo = Math.min(...after.map(p => p[2])), zhi = Math.max(...after.map(p => p[2]));
  console.log(`  ${id}: ${Math.round(tris)} → ${Math.round(Math.min(tris, alvo))} triângulos, cabo ${(-zlo).toFixed(2)} m atrás da mão, ponta ${zhi.toFixed(2)} m à frente`);
}

const files = fs.statSync(entrada).isDirectory()
  ? fs.readdirSync(entrada).filter(f => f.endsWith('.glb')).map(f => path.join(entrada, f))
  : [entrada];
console.log(`Encaixando ${files.length} arma(s) em ${saida}`);
for (const f of files) {
  try { await fit(f); } catch (e) { console.log('  erro em', path.basename(f), e.message); }
}
