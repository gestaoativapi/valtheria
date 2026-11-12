// ===== Valtheria — sons gerados no navegador (Web Audio, sem arquivos e sem custo): golpes, magias, explosões, chuva e trilha ambiente =====
let ctx = null, master = null, musicG = null, rainN = null; export const SFX = { on: true, music: true, vol: 0.6 };
try { const o = JSON.parse(localStorage.getItem('vt_sfx') || '{}'); Object.assign(SFX, o); } catch (_) {}
export const saveSfx = () => { try { localStorage.setItem('vt_sfx', JSON.stringify({ on: SFX.on, music: SFX.music, vol: SFX.vol })); } catch (_) {} if (master) master.gain.value = SFX.on ? SFX.vol : 0; if (musicG) musicG.gain.value = SFX.music ? 0.12 : 0; };
function init() {
  if (ctx) return true; const AC = globalThis.AudioContext || globalThis.webkitAudioContext; if (!AC) return false;
  ctx = new AC(); master = ctx.createGain(); master.gain.value = SFX.on ? SFX.vol : 0; const comp = ctx.createDynamicsCompressor(); master.connect(comp); comp.connect(ctx.destination);
  musicG = ctx.createGain(); musicG.gain.value = SFX.music ? 0.12 : 0; musicG.connect(master); startMusic(); return true;
}
addEventListener('pointerdown', () => { init(); ctx?.state === 'suspended' && ctx.resume(); }, { once: false, passive: true });
addEventListener('keydown', () => { init(); ctx?.state === 'suspended' && ctx.resume(); }, { passive: true });
const noiseBuf = () => { const b = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate), d = b.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1; return b; };
let NB = null;
function noise(dur, f0, f1, q, vol, type = 'bandpass', at = 0) { const t = ctx.currentTime + at, s = ctx.createBufferSource(); s.buffer = NB || (NB = noiseBuf()); const f = ctx.createBiquadFilter(); f.type = type; f.Q.value = q;
  f.frequency.setValueAtTime(f0, t); f.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t + dur); const g = ctx.createGain(); g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
  s.connect(f); f.connect(g); g.connect(master); s.start(t, Math.random() * 0.5); s.stop(t + dur + 0.05); }
function tone(dur, f0, f1, vol, type = 'sine', at = 0) { const t = ctx.currentTime + at, o = ctx.createOscillator(), g = ctx.createGain(); o.type = type; o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t + dur);
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + 0.01); g.gain.exponentialRampToValueAtTime(0.0001, t + dur); o.connect(g); g.connect(master); o.start(t); o.stop(t + dur + 0.05); }
// tipos de som
export function play(kind, k = 1) {
  if (!SFX.on || !init() || ctx.state !== 'running') return; const r = 0.9 + Math.random() * 0.2;
  switch (kind) {
    case 'swing': noise(0.18, 2400 * r, 600, 1.2, 0.25 * k); break;
    case 'hit': noise(0.12, 1800 * r, 300, 0.9, 0.5 * k); tone(0.12, 160 * r, 60, 0.35 * k, 'triangle'); break;
    case 'crit': noise(0.25, 3000, 200, 0.7, 0.7 * k); tone(0.3, 220, 50, 0.5 * k, 'sawtooth'); tone(0.2, 1200, 2400, 0.12 * k, 'sine', 0.02); break;
    case 'metal': tone(0.4, 1800 * r, 1700, 0.12 * k, 'triangle'); tone(0.3, 2700 * r, 2600, 0.08 * k, 'sine'); noise(0.08, 4000, 2000, 2, 0.2 * k); break;
    case 'magic': tone(0.5, 400 * r, 1400, 0.18 * k, 'sine'); tone(0.5, 600 * r, 2100, 0.1 * k, 'triangle', 0.03); noise(0.4, 6000, 1500, 3, 0.12 * k, 'bandpass'); break;
    case 'fire': noise(0.7, 800, 120, 0.6, 0.6 * k, 'lowpass'); tone(0.5, 90, 40, 0.4 * k, 'sawtooth'); break;
    case 'ice': for (let i = 0; i < 5; i++) tone(0.25, 2000 + i * 400 * r, 2500 + i * 300, 0.06 * k, 'sine', i * 0.04); noise(0.3, 7000, 3000, 4, 0.1 * k); break;
    case 'thunder': noise(1.6, 400, 40, 0.5, 0.9 * k, 'lowpass'); noise(0.2, 3000, 800, 1, 0.5 * k); break;
    case 'boom': noise(0.9, 600, 40, 0.6, 0.9 * k, 'lowpass'); tone(0.6, 80, 30, 0.7 * k, 'sine'); break;
    case 'heal': [523, 659, 784, 1047].forEach((f, i) => tone(0.5, f, f * 1.01, 0.08 * k, 'sine', i * 0.07)); break;
    case 'buff': [392, 523, 659].forEach((f, i) => tone(0.6, f, f * 1.5, 0.08 * k, 'triangle', i * 0.05)); break;
    case 'levelup': [523, 659, 784, 1047, 1319].forEach((f, i) => { tone(0.7, f, f, 0.12, 'triangle', i * 0.1); tone(0.7, f * 2, f * 2, 0.04, 'sine', i * 0.1); }); break;
    case 'enchant': [880, 1175, 1568, 2093].forEach((f, i) => tone(0.6, f, f * 1.02, 0.08 * k, 'sine', i * 0.08)); noise(0.6, 8000, 3000, 5, 0.06); break;
    case 'fail': tone(0.6, 300, 80, 0.25, 'sawtooth'); noise(0.4, 1200, 200, 1, 0.3); break;
    case 'step': noise(0.06, 900 * r, 300, 1, 0.05 * k); break;
    case 'dodge': noise(0.25, 1500, 500, 0.8, 0.25); break;
    case 'click': tone(0.05, 1200, 900, 0.05, 'square'); break;
    case 'death': tone(0.8, 300, 60, 0.25 * k, 'sawtooth'); noise(0.5, 900, 100, 0.7, 0.25 * k); break;
    case 'coin': tone(0.12, 1568, 1568, 0.08, 'square'); tone(0.2, 2093, 2093, 0.07, 'square', 0.07); break;
  }
}
// chuva contínua (ruído filtrado com volume pelo clima)
export function rain(amount) {
  if (!ctx || ctx.state !== 'running') return;
  if (!rainN) { const s = ctx.createBufferSource(); s.buffer = NB || (NB = noiseBuf()); s.loop = true; const f = ctx.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = 1200; const g = ctx.createGain(); g.gain.value = 0; s.connect(f); f.connect(g); g.connect(master); s.start(); rainN = g; }
  rainN.gain.value += (amount * 0.12 - rainN.gain.value) * 0.05;
}
// trilha ambiente: acordes lentos em modo dórico, gerados ao vivo; ficam mais tensos em combate
const MODES = { calma: [[50, 57, 62, 65], [48, 55, 60, 64], [53, 60, 65, 69], [55, 62, 67, 70]], combate: [[45, 52, 57, 60], [43, 50, 55, 58], [46, 53, 58, 62], [44, 51, 56, 59]] };
let mood = 'calma', step = 0;
export const setMood = (m) => { mood = m; };
function startMusic() {
  const mtof = n => 440 * Math.pow(2, (n - 69) / 12);
  const chord = () => { if (!ctx) return; const ch = MODES[mood][step++ % 4], t = ctx.currentTime, dur = mood === 'combate' ? 3.2 : 6;
    ch.forEach((n, i) => { const o = ctx.createOscillator(), g = ctx.createGain(), f = ctx.createBiquadFilter(); o.type = i === 0 ? 'triangle' : 'sine'; o.frequency.value = mtof(n) * (i === 0 ? 0.5 : 1); o.detune.value = (Math.random() - 0.5) * 8;
      f.type = 'lowpass'; f.frequency.value = 1400; g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.25, t + dur * 0.35); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      o.connect(f); f.connect(g); g.connect(musicG); o.start(t); o.stop(t + dur + 0.1); });
    if (mood === 'combate') for (let b = 0; b < 4; b++) { const tt = t + b * 0.8; const o = ctx.createOscillator(), g = ctx.createGain(); o.frequency.setValueAtTime(110, tt); o.frequency.exponentialRampToValueAtTime(45, tt + 0.25); g.gain.setValueAtTime(0.5, tt); g.gain.exponentialRampToValueAtTime(0.001, tt + 0.3); o.connect(g); g.connect(musicG); o.start(tt); o.stop(tt + 0.35); }
    setTimeout(chord, dur * 1000 * 0.8); };
  chord();
}
