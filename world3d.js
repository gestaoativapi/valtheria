// ===== Valtheria — ambiente realista: céu com ciclo dia/noite, sol, lua, estrelas, nuvens,
// água com ondas, vento nas árvores e na grama, fogo e fumaça, rochas e árvores por bioma =====
import * as THREE from './three.module.min.js';

export const WIND = { time: { value: 0 }, strength: { value: 1 } };
const DAY_SECONDS = 1800; // um dia de Valtheria = 30 min reais (igual para todos os jogadores)

// ---------- utilidades ----------
export function mergeGeos(list) {
  const pos = [], nor = [], col = [];
  for (const { g, m, c } of list) {
    const geo = (g.index ? g.toNonIndexed() : g.clone()); if (m) geo.applyMatrix4(m); geo.computeVertexNormals();
    pos.push(...geo.attributes.position.array); nor.push(...geo.attributes.normal.array);
    const cc = new THREE.Color(c || '#ffffff'); for (let i = 0; i < geo.attributes.position.count; i++) col.push(cc.r, cc.g, cc.b);
  }
  const out = new THREE.BufferGeometry();
  out.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); out.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3)); out.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
  return out;
}
const M4 = (x = 0, y = 0, z = 0, sx = 1, sy = 1, sz = 1, ry = 0, rx = 0, rz = 0) => new THREE.Matrix4().compose(new THREE.Vector3(x, y, z), new THREE.Quaternion().setFromEuler(new THREE.Euler(rx, ry, rz)), new THREE.Vector3(sx, sy, sz));
export { M4 };

// vento: balança vértices conforme a altura (árvores instanciadas e grama)
export function windify(material, amp = 0.12, minY = 1.5) {
  material.onBeforeCompile = (sh) => {
    sh.uniforms.uWindT = WIND.time; sh.uniforms.uWindS = WIND.strength;
    sh.vertexShader = 'uniform float uWindT; uniform float uWindS;\n' + sh.vertexShader.replace('#include <begin_vertex>', `#include <begin_vertex>
      vec3 wp0 = vec3(0.);
      #ifdef USE_INSTANCING
        wp0 = instanceMatrix[3].xyz;
      #endif
      float hk = max(0., position.y - ${minY.toFixed(2)});
      float sw = sin(uWindT * 1.7 + wp0.x * 0.13 + wp0.z * 0.11) + 0.45 * sin(uWindT * 3.9 + wp0.x * 0.7 + position.y);
      transformed.x += sw * ${amp.toFixed(3)} * hk * uWindS; transformed.z += cos(uWindT * 1.3 + wp0.z * 0.17) * ${(amp * 0.6).toFixed(3)} * hk * uWindS;`);
  };
  material.customProgramCacheKey = () => 'wind' + amp + minY;
  return material;
}

// ---------- céu ----------
export function createSky() {
  const mat = new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: { top: { value: new THREE.Color(0x3a74c4) }, bot: { value: new THREE.Color(0xd8e6f0) }, sunDir: { value: new THREE.Vector3(0, 1, 0) }, moonDir: { value: new THREE.Vector3(0, -1, 0) }, night: { value: 0 }, time: { value: 0 }, eclipse: { value: 0 } },
    vertexShader: 'varying vec3 v; void main(){ v = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.); }',
    fragmentShader: `uniform vec3 top; uniform vec3 bot; uniform vec3 sunDir; uniform vec3 moonDir; uniform float night; uniform float time; uniform float eclipse; varying vec3 v;
      float h21(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
      float n2(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.-2.*f); return mix(mix(h21(i),h21(i+vec2(1,0)),f.x), mix(h21(i+vec2(0,1)),h21(i+vec2(1,1)),f.x), f.y); }
      float fbm(vec2 p){ float s=0., a=.5; for(int i=0;i<5;i++){ s+=a*n2(p); p*=2.02; a*=.5; } return s; }
      void main(){
        float h = clamp(v.y*1.3+.12, 0., 1.);
        vec3 day = mix(bot, top, h);
        vec3 nightC = mix(vec3(.03,.05,.11), vec3(.005,.01,.035), h);
        float sunH = sunDir.y, dusk = smoothstep(.35, 0., abs(sunH)) ;
        vec3 c = mix(day, nightC, night);
        float sd = max(dot(v, sunDir), 0.);
        c += vec3(1.,.45,.15) * pow(sd, 6.) * dusk * .9 * (1.-h*.6);           // brilho do pôr do sol
        c += vec3(1.,.9,.7) * pow(sd, 400.) * 2. * (1.-night);                    // halo
        c += vec3(1.,.96,.85) * smoothstep(.9988,.9993,sd) * 3. * step(-.05, sunH); // disco do sol
        float md = dot(v, moonDir);
        float moon = smoothstep(.9990,.9994,md);
        vec3 moonC = mix(vec3(.95,.95,1.), vec3(.6,.15,.25), eclipse);
        c = mix(c, moonC * (.8 + .2*n2(v.xz*900.)), moon * (.25 + .75*night));
        c += moonC * pow(max(md,0.), 300.) * .35 * night;
        // estrelas
        vec2 sp = v.xz / (v.y + 1.2) * 180.; float st = step(.9965, h21(floor(sp))) * (.6 + .4*sin(time*3. + h21(floor(sp))*40.));
        c += vec3(st) * night * smoothstep(0., .25, v.y);
        // nuvens
        vec2 cp = v.xz / max(v.y, .06) * .9 + vec2(time*.012, time*.004);
        float cl = smoothstep(.48, .78, fbm(cp*1.3)) * smoothstep(0., .25, v.y);
        vec3 cloudC = mix(vec3(1.,1.,1.)*(.85+.15*h), vec3(.12,.14,.2), night); cloudC = mix(cloudC, vec3(1.,.6,.4), dusk*.6*(1.-night));
        c = mix(c, cloudC, cl * .85);
        gl_FragColor = vec4(c, 1.);
      }`,
  });
  const mesh = new THREE.Mesh(new THREE.SphereGeometry(900, 32, 16), mat); mesh.renderOrder = -10;
  return { mesh, mat };
}

// ---------- ciclo dia/noite ----------
export function dayPhase() { if (globalThis.__phase != null) return globalThis.__phase; return ((Date.now() / 1000) % DAY_SECONDS) / DAY_SECONDS; } // 0=meia-noite, .25=amanhecer, .5=meio-dia
export function sunVectors(t) {
  const a = (t - 0.25) * Math.PI * 2; // sobe às 6h
  const sun = new THREE.Vector3(Math.cos(a) * 0.85, Math.sin(a), 0.35).normalize();
  const moon = sun.clone().multiplyScalar(-1); moon.z = -0.3; moon.normalize();
  return { sun, moon };
}

// ---------- água ----------
// mapa de profundidade para a água (alturas do terreno numa janela de 1024 m em volta do jogador; calculado aos poucos)
const DR = 128; export const DEPTH = { data: new Uint8Array(DR * DR), tex: null, cx: null, cz: null, row: 0, pending: null };
DEPTH.tex = new THREE.DataTexture(DEPTH.data, DR, DR, THREE.RedFormat, THREE.UnsignedByteType); DEPTH.tex.magFilter = DEPTH.tex.minFilter = THREE.LinearFilter; DEPTH.tex.needsUpdate = true;
export function updateWaterDepth(WG, mat, x, z, rows = 6) {
  const cx = Math.round(x / 256) * 256, cz = Math.round(z / 256) * 256, S = 1024;
  if (!DEPTH.pending && (cx !== DEPTH.cx || cz !== DEPTH.cz)) { DEPTH.pending = { cx, cz, buf: new Uint8Array(DR * DR) }; DEPTH.row = 0; }
  const P = DEPTH.pending; if (!P) return;
  for (let r = 0; r < rows && DEPTH.row < DR; r++, DEPTH.row++) { const j = DEPTH.row, wz = P.cz - S / 2 + (j + 0.5) / DR * S; for (let i = 0; i < DR; i++) P.buf[j * DR + i] = Math.max(0, Math.min(255, Math.round((WG.height(P.cx - S / 2 + (i + 0.5) / DR * S, wz) + 20) / 40 * 255))); }
  if (DEPTH.row >= DR) { DEPTH.data.set(P.buf); DEPTH.tex.needsUpdate = true; DEPTH.cx = P.cx; DEPTH.cz = P.cz; mat.uniforms.hBox.value.set(P.cx - S / 2, P.cz - S / 2, S); mat.uniforms.hOn.value = 1; DEPTH.pending = null; }
}
export function createWater() {
  const geo = new THREE.PlaneGeometry(1400, 1400, 220, 220); geo.rotateX(-Math.PI / 2);
  const mat = new THREE.ShaderMaterial({
    transparent: true, depthWrite: false,
    uniforms: { time: WIND.time, sunDir: { value: new THREE.Vector3(0, 1, 0) }, night: { value: 0 }, deep: { value: new THREE.Color(0x0e3a5a) }, shallow: { value: new THREE.Color(0x2a8aa8) },
      skyC: { value: new THREE.Color(0xa8c8e8) }, fogColor: { value: new THREE.Color() }, fogNear: { value: 140 }, fogFar: { value: 420 }, hMap: { value: DEPTH.tex }, hBox: { value: new THREE.Vector3(-1e5, -1e5, 1) }, hOn: { value: 0 } },
    vertexShader: `uniform float time; varying vec3 wp; varying vec3 nrm; varying float crest;
      vec3 wave(vec2 p, vec2 d, float a, float l, float s){ float k=6.2831/l; float f=k*(dot(d,p)-s*time); return vec3(a*sin(f), a*k*cos(f)*d.x, a*k*cos(f)*d.y); }
      void main(){
        vec4 w = modelMatrix * vec4(position,1.); vec2 p = w.xz;
        vec3 A = wave(p, normalize(vec2(1.,.3)), .22, 18., 2.2), B = wave(p, normalize(vec2(-.4,1.)), .14, 9., 1.6), C = wave(p, normalize(vec2(.7,-.6)), .06, 4., 1.1);
        w.y += A.x + B.x + C.x; crest = A.x + B.x * 1.2;
        nrm = normalize(vec3(-(A.y+B.y+C.y), 1., -(A.z+B.z+C.z)));
        wp = w.xyz; gl_Position = projectionMatrix * viewMatrix * w; }`,
    fragmentShader: `uniform vec3 sunDir; uniform float night; uniform vec3 deep; uniform vec3 shallow; uniform vec3 skyC; uniform vec3 fogColor; uniform float fogNear; uniform float fogFar; uniform float time; uniform sampler2D hMap; uniform vec3 hBox; uniform float hOn; varying vec3 wp; varying vec3 nrm; varying float crest;
      float h21(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
      void main(){
        vec3 V = normalize(cameraPosition - wp);
        vec3 N = normalize(nrm + vec3(sin(wp.x*1.7+time*2.)*.04, 0., cos(wp.z*1.9-time*1.7)*.04));
        float fres = pow(1. - max(dot(N, V), 0.), 4.);
        // profundidade (mapa de alturas do terreno ao redor): água rasa turquesa e espuma na margem
        vec2 huv = (wp.xz - hBox.xy) / hBox.z; float depth = 6.;
        if (hOn > .5 && huv.x > 0. && huv.y > 0. && huv.x < 1. && huv.y < 1.) depth = max(0., -(texture2D(hMap, huv).r * 40. - 20.));
        float sh = smoothstep(7., 0.4, depth);
        vec3 col = mix(mix(shallow, deep, .55), vec3(.18,.62,.64), sh * .8);
        float fn = h21(floor(wp.xz * 2.3 + vec2(time * .7, time * .4))) * .5 + h21(floor(wp.xz * 1.1 - time * .5)) * .5;
        float foam = smoothstep(1.4, .1, depth) * smoothstep(.35, .8, fn + sin(depth * 6. - time * 2.5) * .25) + smoothstep(.28, .42, crest) * .35;
        col = mix(col, skyC, fres * .75);
        vec3 L = sunDir.y > 0. ? sunDir : vec3(-sunDir.x, -sunDir.y, -sunDir.z);
        vec3 H = normalize(L + V); float spec = pow(max(dot(N, H), 0.), 220.) * (sunDir.y > 0. ? 2.2 : .5);
        col += mix(vec3(1.,.92,.75), vec3(.6,.7,1.), night) * spec;
        col += vec3(.9) * smoothstep(.9, 1., h21(floor(wp.xz*.8)+floor(time*2.))) * .06 * (1.-night); // cintilado
        col = mix(col, vec3(.95,.97,1.), clamp(foam, 0., 1.) * .85);
        col *= mix(1., .28, night);
        float d = length(cameraPosition - wp); float f = smoothstep(fogNear, fogFar, d);
        gl_FragColor = vec4(mix(col, fogColor, f), mix(mix(.86, .62, sh * (1. - foam)), 1., f));
      }`,
  });
  const mesh = new THREE.Mesh(geo, mat); mesh.renderOrder = 2; mesh.frustumCulled = false;
  return { mesh, mat };
}

// ---------- fogo e fumaça (partículas) ----------
function radialTex(inner, outer) {
  const c = document.createElement('canvas'); c.width = c.height = 64; const g = c.getContext('2d');
  const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32); gr.addColorStop(0, inner); gr.addColorStop(0.4, outer); gr.addColorStop(1, 'rgba(0,0,0,0)');
  g.fillStyle = gr; g.fillRect(0, 0, 64, 64); const t = new THREE.CanvasTexture(c); return t;
}
const FIRE_TEX = radialTex('rgba(255,250,220,1)', 'rgba(255,140,40,0.6)');
const SMOKE_TEX = radialTex('rgba(120,120,120,0.55)', 'rgba(90,90,90,0.25)');
const fireMats = {};
function fireMat(color) { if (!fireMats[color]) fireMats[color] = new THREE.SpriteMaterial({ map: FIRE_TEX, color, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true }); return fireMats[color]; }
const smokeMat = new THREE.SpriteMaterial({ map: SMOKE_TEX, depthWrite: false, transparent: true, opacity: 0.5 });
export const FIRES = [];
export function makeFire(x, y, z, scale = 1, color = '#ffffff', light = false, smoke = false) {
  const g = new THREE.Group(); g.position.set(x, y, z);
  const parts = [];
  for (let i = 0; i < 9; i++) { const s = new THREE.Sprite(fireMat(color)); s.userData.ph = Math.random(); s.userData.sp = 0.8 + Math.random() * 0.6; g.add(s); parts.push(s); }
  const smk = []; if (smoke) for (let i = 0; i < 6; i++) { const s = new THREE.Sprite(smokeMat); s.userData.ph = i / 6; g.add(s); smk.push(s); }
  // a luz real vem de um conjunto FIXO de luzes (LIGHT_POOL): o número de luzes nunca muda, então nenhum shader é recompilado (evita travadas)
  const pl = light ? { color: new THREE.Color(color).lerp(new THREE.Color('#ff8a3a'), 0.6), dist: 18 * scale, y: 0.8 * scale } : null;
  const f = { g, parts, smk, pl, scale }; FIRES.push(f); return g;
}
export function makeSmoke(x, y, z, scale = 1) { const g = new THREE.Group(); g.position.set(x, y, z); const smk = []; for (let i = 0; i < 7; i++) { const s = new THREE.Sprite(smokeMat); s.userData.ph = i / 7; g.add(s); smk.push(s); } FIRES.push({ g, parts: [], smk, pl: null, scale }); return g; }
export function updateFires(dt, t, night, camPos) {
  for (const f of FIRES) {
    if (!f.g.parent) continue;
    if (!f.wp) { f.g.updateWorldMatrix(true, false); f.wp = new THREE.Vector3().setFromMatrixPosition(f.g.matrixWorld); }
    const near = f.wp.distanceToSquared(camPos) < 260 * 260; f.g.visible = near; if (!near) continue;
    const S = f.scale;
    for (const s of f.parts) { const p = (t * s.userData.sp + s.userData.ph) % 1; s.position.set(Math.sin(s.userData.ph * 40 + t * 3) * 0.12 * S, p * 1.3 * S, Math.cos(s.userData.ph * 30 + t * 2.5) * 0.12 * S); const k = (1 - p); s.scale.setScalar((0.35 + 0.65 * k) * 0.9 * S); s.material.opacity = k; }
    for (const s of f.smk) { const p = (t * 0.18 + s.userData.ph) % 1; s.position.set(Math.sin(t * 0.7 + s.userData.ph * 9) * 0.6 * S * p + p * 0.8 * S, 1.2 * S + p * 5 * S, Math.cos(t * 0.5 + s.userData.ph * 7) * 0.4 * S * p); s.scale.setScalar((0.6 + p * 2.6) * S); }
  }
  // distribui as luzes do conjunto fixo para as fogueiras mais próximas da câmera
  if (!LIGHT_POOL.length) return;
  const cand = []; for (const f of FIRES) { if (!f.pl || !f.g.parent || !f.g.visible || !f.wp) continue; const d = f.wp.distanceToSquared(camPos); if (d < 150 * 150) cand.push([d, f]); }
  cand.sort((a, b) => a[0] - b[0]);
  for (let i = 0; i < LIGHT_POOL.length; i++) { const L = LIGHT_POOL[i], c = cand[i];
    if (!c) { L.intensity = 0; continue; } const f = c[1]; L.position.copy(f.wp); L.position.y += f.pl.y; L.color.copy(f.pl.color); L.distance = f.pl.dist;
    L.intensity = (0.4 + night * 2.6) * f.scale * (0.85 + Math.sin(t * 13 + i) * 0.08 + Math.sin(t * 7.3) * 0.07); }
}
export const LIGHT_POOL = [];
export function initLightPool(scene, n) { while (LIGHT_POOL.length) scene.remove(LIGHT_POOL.pop()); for (let i = 0; i < n; i++) { const L = new THREE.PointLight(0xffaa66, 0, 18, 1.6); L.castShadow = false; scene.add(L); LIGHT_POOL.push(L); } }

// ---------- grama com vento (em volta do jogador) ----------
export function createGrass(count = 9000) {
  const blade = new THREE.BufferGeometry();
  // duas lâminas cruzadas, finas; normais para cima = iluminação suave dos dois lados
  const P = [], w = 0.035, h = 0.42;
  for (const r of [0, Math.PI / 2]) { const c = Math.cos(r), s = Math.sin(r); const T = [-w * c, 0, -w * s, w * c, 0, w * s, 0.03, h, 0.02]; P.push(...T, T[0], T[1], T[2], T[6], T[7], T[8], T[3], T[4], T[5]); }
  blade.setAttribute('position', new THREE.Float32BufferAttribute(P, 3));
  blade.setAttribute('normal', new THREE.Float32BufferAttribute(new Array(P.length / 3).fill(0).flatMap(() => [0, 1, 0]), 3));
  const mat = windify(new THREE.MeshLambertMaterial({ side: THREE.FrontSide, vertexColors: false }), 0.5, 0.0);
  const mesh = new THREE.InstancedMesh(blade, mat, count); mesh.frustumCulled = false; mesh.receiveShadow = false;
  mesh.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(count * 3), 3);
  return { mesh, center: null, count };
}
export function layoutGrass(G, px, pz, heightFn, okFn, colorFn) {
  const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), s = new THREE.Vector3(), p = new THREE.Vector3(), col = new THREE.Color(), e = new THREE.Euler();
  let n = 0; const R = 38;
  let seed = (Math.floor(px) * 73856093) ^ (Math.floor(pz) * 19349663);
  const rnd = () => { seed = (seed * 1664525 + 1013904223) | 0; return ((seed >>> 0) % 100000) / 100000; };
  const lim = Math.min(G.count, G.limit ?? G.count); for (let i = 0; i < lim * 2 && n < lim; i++) {
    const x = px + (rnd() * 2 - 1) * R, z = pz + (rnd() * 2 - 1) * R;
    if (!okFn(x, z)) continue;
    const h = heightFn(x, z); e.set((rnd() - 0.5) * 0.3, rnd() * 6.28, (rnd() - 0.5) * 0.3); q.setFromEuler(e);
    const sc = 0.7 + rnd() * 0.8; s.set(sc, sc * (0.6 + rnd() * 0.9), sc); p.set(x, h - 0.03, z); m4.compose(p, q, s); G.mesh.setMatrixAt(n, m4);
    colorFn(x, z, col); col.offsetHSL(0, 0, (rnd() - 0.4) * 0.12); G.mesh.instanceColor.setXYZ(n, col.r, col.g, col.b); n++;
  }
  G.mesh.count = n; G.mesh.instanceMatrix.needsUpdate = true; G.mesh.instanceColor.needsUpdate = true; G.center = { x: px, z: pz };
}

// ---------- rochas e árvores ----------
function rockGeometry(seed) {
  const g = new THREE.IcosahedronGeometry(1, 1); const p = g.attributes.position;
  for (let i = 0; i < p.count; i++) { const x = p.getX(i), y = p.getY(i), z = p.getZ(i); const n = 0.75 + 0.35 * Math.abs(Math.sin(x * 3.1 + seed) * Math.cos(z * 2.7 + seed * 2) + Math.sin(y * 4.3)); p.setXYZ(i, x * n, y * n * 0.7, z * n); }
  g.computeVertexNormals(); return g;
}
export const ROCK_GEOS = [rockGeometry(1), rockGeometry(2.3), rockGeometry(4.1)];
export const rockMat = new THREE.MeshStandardMaterial({ color: 0x8a8478, roughness: 0.95, flatShading: false });

// árvores por bioma (copa em várias esferas, coníferas em camadas, acácia, árvore morta, palmeira de cristal)
function treeKinds() {
  const trunk = (h = 3, r = 0.3) => new THREE.CylinderGeometry(r * 0.75, r, h, 7).translate(0, h / 2, 0);
  const k = {};
  k.folhosa = { trunk: trunk(3.2, 0.32), leaf: mergeGeos([{ g: new THREE.IcosahedronGeometry(1.9, 2), m: M4(0, 4.6, 0) }, { g: new THREE.IcosahedronGeometry(1.4, 2), m: M4(1.1, 4.0, 0.4) }, { g: new THREE.IcosahedronGeometry(1.5, 2), m: M4(-1.0, 4.2, -0.5) }, { g: new THREE.IcosahedronGeometry(1.2, 2), m: M4(0.2, 5.8, 0.3) }]) };
  k.conifera = { trunk: trunk(2.2, 0.28), leaf: mergeGeos([{ g: new THREE.ConeGeometry(2.3, 3.2, 9), m: M4(0, 3.4, 0) }, { g: new THREE.ConeGeometry(1.8, 2.8, 9), m: M4(0, 5.0, 0) }, { g: new THREE.ConeGeometry(1.2, 2.4, 9), m: M4(0, 6.5, 0) }]) };
  k.acacia = { trunk: trunk(3.6, 0.25), leaf: mergeGeos([{ g: new THREE.SphereGeometry(2.8, 14, 8), m: M4(0, 4.3, 0, 1, 0.28, 1) }, { g: new THREE.SphereGeometry(1.8, 12, 8), m: M4(1.4, 4.0, 0.6, 1, 0.3, 1) }]) };
  k.morta = { trunk: mergeGeos([{ g: trunk(3.5, 0.3) }, { g: new THREE.CylinderGeometry(0.06, 0.14, 1.8, 5), m: M4(0.5, 3.0, 0, 1, 1, 1, 0, 0, -0.9) }, { g: new THREE.CylinderGeometry(0.06, 0.12, 1.5, 5), m: M4(-0.45, 2.5, 0.2, 1, 1, 1, 0, 0.2, 0.9) }]), leaf: null };
  k.cristal = { trunk: trunk(2.0, 0.2), leaf: mergeGeos([{ g: new THREE.OctahedronGeometry(1.2, 0), m: M4(0, 3.2, 0, 0.7, 1.6, 0.7) }, { g: new THREE.OctahedronGeometry(0.7, 0), m: M4(0.8, 2.6, 0.2, 0.6, 1.3, 0.6, 0, 0, -0.4) }]) };
  k.gelo = { trunk: trunk(2.2, 0.28), leaf: mergeGeos([{ g: new THREE.ConeGeometry(2.1, 3.0, 9), m: M4(0, 3.2, 0) }, { g: new THREE.ConeGeometry(1.5, 2.6, 9), m: M4(0, 4.8, 0) }, { g: new THREE.ConeGeometry(0.9, 2.0, 9), m: M4(0, 6.2, 0) }]) };
  return k;
}
export const TREE_KINDS = treeKinds();
const trunkMat = windify(new THREE.MeshStandardMaterial({ color: 0x5a3a22, roughness: 0.9 }), 0.03, 1.0);
const leafMats = {};
export function leafMat(color, emissive = 0) { const k = color + emissive; if (!leafMats[k]) leafMats[k] = windify(new THREE.MeshStandardMaterial({ color, roughness: 0.85, vertexColors: false, emissive, emissiveIntensity: emissive ? 0.5 : 0 }), 0.06, 2.2); return leafMats[k]; }
export function treeTrunkMat() { return trunkMat; }
