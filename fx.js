// ===== Valtheria — efeitos visuais leves (um único sistema de partículas + golpes em arco) =====
import * as THREE from './three.module.min.js';

const N = 1800;
let pts, geo, P, V, C, SZ, L, LMAX, G, D, head = 0, scene;
export function initFX(sc) {
  scene = sc; geo = new THREE.BufferGeometry();
  P = new Float32Array(N * 3); C = new Float32Array(N * 3); SZ = new Float32Array(N); L = new Float32Array(N);
  V = new Float32Array(N * 3); LMAX = new Float32Array(N); G = new Float32Array(N); D = new Float32Array(N);
  geo.setAttribute('position', new THREE.BufferAttribute(P, 3).setUsage(THREE.DynamicDrawUsage));
  geo.setAttribute('color', new THREE.BufferAttribute(C, 3).setUsage(THREE.DynamicDrawUsage));
  geo.setAttribute('size', new THREE.BufferAttribute(SZ, 1).setUsage(THREE.DynamicDrawUsage));
  geo.setAttribute('life', new THREE.BufferAttribute(L, 1).setUsage(THREE.DynamicDrawUsage));
  const mat = new THREE.ShaderMaterial({
    uniforms: { scale: { value: innerHeight / 2 } }, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, vertexColors: true,
    vertexShader: `attribute float size; attribute float life; varying vec3 vC; varying float vL;
      void main(){ vC = color; vL = life; vec4 mv = modelViewMatrix * vec4(position,1.0); gl_PointSize = life > 0.0 ? size * 300.0 / -mv.z : 0.0; gl_Position = projectionMatrix * mv; }`,
    fragmentShader: `varying vec3 vC; varying float vL; void main(){ if (vL <= 0.0) discard; vec2 d = gl_PointCoord - 0.5; float r = dot(d,d)*4.0; if (r > 1.0) discard;
      float a = (1.0 - r) * (1.0 - r) * clamp(vL * 3.0, 0.0, 1.0); gl_FragColor = vec4(vC * (1.0 + (1.0 - r) * 1.2) * a, a); }`,
  });
  pts = new THREE.Points(geo, mat); pts.frustumCulled = false; pts.renderOrder = 5; scene.add(pts);
}
const tc = new THREE.Color();
// emite partículas: o = { n, color, speed, up, spread, life, size, grav, drag, ring, rise }
export function emit(x, y, z, o = {}) {
  if (!pts) return; const n = o.n || 12; tc.set(o.color ?? 0xffffff);
  for (let i = 0; i < n; i++) {
    const k = head; head = (head + 1) % N;
    const a = Math.random() * Math.PI * 2, e = (Math.random() - 0.3) * (o.spread ?? 1.2), sp = (o.speed ?? 4) * (0.4 + Math.random() * 0.8);
    const r = o.ring ? o.ring * (0.8 + Math.random() * 0.4) : 0;
    P[k * 3] = x + Math.cos(a) * r; P[k * 3 + 1] = y + (o.yJit ? Math.random() * o.yJit : 0); P[k * 3 + 2] = z + Math.sin(a) * r;
    V[k * 3] = Math.cos(a) * Math.cos(e) * sp; V[k * 3 + 1] = (o.up ?? 2) * (0.5 + Math.random()) + Math.sin(e) * sp * 0.5; V[k * 3 + 2] = Math.sin(a) * Math.cos(e) * sp;
    if (o.dir) { V[k * 3] += o.dir[0]; V[k * 3 + 1] += o.dir[1]; V[k * 3 + 2] += o.dir[2]; }
    const jit = o.jit ?? 0.15; C[k * 3] = Math.min(1.5, tc.r * (1 + (Math.random() - 0.5) * jit)); C[k * 3 + 1] = tc.g * (1 + (Math.random() - 0.5) * jit); C[k * 3 + 2] = tc.b * (1 + (Math.random() - 0.5) * jit);
    SZ[k] = (o.size ?? 0.18) * (0.6 + Math.random() * 0.8); LMAX[k] = L[k] = (o.life ?? 0.7) * (0.6 + Math.random() * 0.8); G[k] = o.grav ?? 6; D[k] = o.drag ?? 1.5;
  }
}
// ---- golpes em arco (meia-lua luminosa que varre) ----
const slashTex = (() => { const c = document.createElement('canvas'); c.width = 128; c.height = 8; const g = c.getContext('2d'), gr = g.createLinearGradient(0, 0, 128, 0);
  gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(0.75, 'rgba(255,255,255,0.7)'); gr.addColorStop(1, 'rgba(255,255,255,1)'); g.fillStyle = gr; g.fillRect(0, 0, 128, 8); const t = new THREE.CanvasTexture(c); return t; })();
const slashGeo = (() => { const g = new THREE.RingGeometry(0.75, 1.15, 24, 1, 0, Math.PI * 1.1); const uv = g.attributes.uv, pa = g.attributes.position;
  for (let i = 0; i < pa.count; i++) { const a = Math.atan2(pa.getY(i), pa.getX(i)); uv.setXY(i, Math.max(0, a) / (Math.PI * 1.1), 0.5); } return g; })();
const live = [];
export function slash(x, y, z, ry, color, big) {
  const m = new THREE.Mesh(slashGeo, new THREE.MeshBasicMaterial({ map: slashTex, color, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  m.position.set(x, y, z); m.rotation.order = 'YXZ'; m.rotation.y = ry; m.rotation.x = (Math.random() - 0.5) * 1.2; m.rotation.z = Math.random() * 0.6 - 0.3;
  const s = big ? 1.9 : 1.35; m.scale.setScalar(s); scene.add(m); live.push({ o: m, t: 0, dur: 0.24, s, kind: 'slash' });
}
// anel de choque no chão
const ringGeo = new THREE.RingGeometry(0.85, 1, 40);
export function shock(x, y, z, color, radius = 3, dur = 0.5) {
  const m = new THREE.Mesh(ringGeo, new THREE.MeshBasicMaterial({ color, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  m.rotation.x = -Math.PI / 2; m.position.set(x, y + 0.15, z); scene.add(m); live.push({ o: m, t: 0, dur, s: radius, kind: 'ring' });
}
// coluna de luz (subir de nível, buffs fortes)
const beamGeo = new THREE.CylinderGeometry(0.9, 1.2, 8, 20, 1, true); beamGeo.translate(0, 4, 0);
export function beam(x, y, z, color, dur = 1.4) {
  const m = new THREE.Mesh(beamGeo, new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.5, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  m.position.set(x, y, z); scene.add(m); live.push({ o: m, t: 0, dur, s: 1, kind: 'beam' });
  emit(x, y + 0.3, z, { n: 60, color, speed: 0.6, up: 5, ring: 1, life: 1.4, size: 0.22, grav: -1, drag: 0.4 });
}
export function updateFX(dt, camera) {
  if (!pts) return;
  for (let k = 0; k < N; k++) {
    if (L[k] <= 0) continue; L[k] -= dt / LMAX[k] * 0.999; if (L[k] <= 0) { L[k] = 0; continue; }
    const d = Math.exp(-D[k] * dt); V[k * 3] *= d; V[k * 3 + 2] *= d; V[k * 3 + 1] = V[k * 3 + 1] * d - G[k] * dt;
    P[k * 3] += V[k * 3] * dt; P[k * 3 + 1] += V[k * 3 + 1] * dt; P[k * 3 + 2] += V[k * 3 + 2] * dt;
  }
  geo.attributes.position.needsUpdate = geo.attributes.life.needsUpdate = geo.attributes.color.needsUpdate = geo.attributes.size.needsUpdate = true;
  for (let i = live.length - 1; i >= 0; i--) {
    const f = live[i]; f.t += dt; const k = Math.min(1, f.t / f.dur), o = f.o;
    if (f.kind === 'slash') { o.material.opacity = 1 - k * k; o.rotation.z += dt * 9; o.scale.setScalar(f.s * (1 + k * 0.35)); }
    else if (f.kind === 'ring') { o.scale.setScalar(0.3 + f.s * k); o.material.opacity = 1 - k; }
    else if (f.kind === 'beam') { o.material.opacity = 0.5 * Math.sin(k * Math.PI); o.scale.set(1 - k * 0.6, 1, 1 - k * 0.6); }
    if (k >= 1) { scene.remove(o); o.material.dispose(); live.splice(i, 1); }
  }
}
