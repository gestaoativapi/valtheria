// ===== Valtheria — clima por região: chuva com raios, neve, cinzas de vulcão e poeira da savana =====
import * as THREE from './three.module.min.js';

let X = null, rain, snow; const R = 38, H = 26;
export const WEATHER = { kind: 'limpo', amount: 0, max: 1, flash: 0 };
export function initWeather(ctx) {
  X = ctx;
  // chuva: riscos (segmentos de linha)
  const NR = 1800, rp = new Float32Array(NR * 6); for (let i = 0; i < NR; i++) { const x = (Math.random() - 0.5) * 2 * R, y = Math.random() * H, z = (Math.random() - 0.5) * 2 * R; rp.set([x, y, z, x + 0.05, y - 0.9, z], i * 6); }
  const rg = new THREE.BufferGeometry(); rg.setAttribute('position', new THREE.BufferAttribute(rp, 3).setUsage(THREE.DynamicDrawUsage));
  rain = new THREE.LineSegments(rg, new THREE.LineBasicMaterial({ color: 0xd8e8ff, transparent: true, opacity: 0, depthWrite: false })); rain.frustumCulled = false; rain.userData.n = NR; X.scene.add(rain);
  // neve, cinzas e poeira: pontos macios
  const NS = 1600, sp = new Float32Array(NS * 3), sd = new Float32Array(NS); for (let i = 0; i < NS; i++) { sp.set([(Math.random() - 0.5) * 2 * R, Math.random() * H, (Math.random() - 0.5) * 2 * R], i * 3); sd[i] = Math.random() * 6.28; }
  const sg = new THREE.BufferGeometry(); sg.setAttribute('position', new THREE.BufferAttribute(sp, 3).setUsage(THREE.DynamicDrawUsage));
  const c = document.createElement('canvas'); c.width = c.height = 32; const g = c.getContext('2d'), gr = g.createRadialGradient(16, 16, 0, 16, 16, 16); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.5, 'rgba(255,255,255,0.5)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.fillRect(0, 0, 32, 32);
  snow = new THREE.Points(sg, new THREE.PointsMaterial({ map: new THREE.CanvasTexture(c), size: 0.22, transparent: true, opacity: 0, depthWrite: false, color: 0xffffff })); snow.frustumCulled = false; snow.userData = { n: NS, seed: sd }; X.scene.add(snow);
}
// clima de cada região (com ciclos de tempo para a chuva ir e vir)
function want(theme, t) {
  const cyc = Math.sin(t / 240) * 0.5 + Math.sin(t / 97 + 1.3) * 0.5; // muda em poucos minutos
  if (theme === 'gelo') return ['neve', 0.55 + 0.45 * Math.max(0, cyc)];
  if (theme === 'vulcao' || theme === 'rubro') return ['cinzas', 0.7];
  if (theme === 'cinza') return ['cinzas', 0.35];
  if (theme === 'savana') return ['poeira', 0.4];
  if (theme === 'noite' || theme === 'sombra') return cyc > -0.1 ? ['chuva', 0.4 + 0.5 * Math.max(0, cyc)] : ['limpo', 0];
  if (['verde', 'floresta', 'outono', 'rocha'].includes(theme)) return cyc > 0.45 ? ['chuva', Math.min(1, (cyc - 0.45) * 3)] : ['limpo', 0];
  return ['limpo', 0];
}
export function updateWeather(dt, theme, safeTown) {
  const t = performance.now() / 1000, cam = X.camera.position, [k, a] = WEATHER.force || want(theme, t), target = a * WEATHER.max;
  if (k !== WEATHER.kind) { WEATHER.amount = Math.max(0, WEATHER.amount - dt * 0.6); if (WEATHER.amount <= 0.01) WEATHER.kind = k; }
  else WEATHER.amount += (target - WEATHER.amount) * Math.min(1, dt * 0.4);
  const A = WEATHER.amount, isRain = WEATHER.kind === 'chuva';
  rain.material.opacity = isRain ? 0.75 * A : 0; rain.visible = isRain && A > 0.02; snow.visible = !isRain && WEATHER.kind !== 'limpo' && A > 0.02;
  if (rain.visible) { rain.position.set(cam.x, cam.y - H * 0.6, cam.z); const p = rain.geometry.attributes.position.array, n = Math.floor(rain.userData.n * Math.min(1, A + 0.15)), v = 22 * dt;
    for (let i = 0; i < rain.userData.n; i++) { const o = i * 6; if (i >= n) { p[o + 1] = p[o + 4] = -999; continue; } p[o + 1] -= v; p[o + 4] -= v; p[o] += dt * 1.5; p[o + 3] += dt * 1.5;
      if (p[o + 4] < 0 || p[o + 1] < -900) { const x = (Math.random() - 0.5) * 2 * R, y = H + Math.random() * 4, z = (Math.random() - 0.5) * 2 * R; p[o] = x; p[o + 1] = y; p[o + 2] = z; p[o + 3] = x + 0.05; p[o + 4] = y - 0.9; p[o + 5] = z; } }
    rain.geometry.attributes.position.needsUpdate = true;
    // raios nas tempestades fortes
    if (A > 0.6 && Math.random() < dt * 0.06) { WEATHER.flash = 1; X.onThunder?.(); }
  }
  if (snow.visible) { const K = WEATHER.kind, M = snow.material; snow.position.set(cam.x, cam.y - H * 0.5, cam.z);
    M.color.set(K === 'neve' ? 0xffffff : K === 'cinzas' ? 0xff8a3a : 0xd8c090); M.size = K === 'neve' ? 0.24 : K === 'cinzas' ? 0.16 : 0.12; M.opacity = (K === 'neve' ? 0.9 : 0.75) * A; M.blending = K === 'cinzas' ? THREE.AdditiveBlending : THREE.NormalBlending;
    const p = snow.geometry.attributes.position.array, sd = snow.userData.seed, fall = K === 'neve' ? -1.6 : K === 'cinzas' ? 0.9 : 0.15, drift = K === 'poeira' ? 3 : 0.6;
    for (let i = 0; i < snow.userData.n; i++) { const o = i * 3; p[o] += (Math.sin(t * 0.7 + sd[i]) * 0.5 + drift * 0.5) * dt; p[o + 1] += fall * dt; p[o + 2] += Math.cos(t * 0.6 + sd[i]) * 0.5 * dt;
      if (p[o + 1] < 0) p[o + 1] += H; if (p[o + 1] > H) p[o + 1] -= H; if (p[o] > R) p[o] -= 2 * R; if (p[o] < -R) p[o] += 2 * R; }
    snow.geometry.attributes.position.needsUpdate = true; }
  WEATHER.flash = Math.max(0, WEATHER.flash - dt * 3);
  return { dim: isRain ? A * 0.3 : WEATHER.kind === 'neve' ? A * 0.08 : 0, flash: WEATHER.flash };
}
