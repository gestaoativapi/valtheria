// ===== Valtheria — falas e vozes dos NPCs e chefes (balão de fala + voz sintetizada do navegador) =====
import * as THREE from './lib/three.module.min.js';

export const VOICE = { on: true };
try { VOICE.on = localStorage.getItem('vt_voice') !== '0'; } catch (_) {}
export function setVoice(v) { VOICE.on = v; try { localStorage.setItem('vt_voice', v ? '1' : '0'); } catch (_) {} if (!v) speechSynthesis?.cancel(); }

const LINES = {
  portal: ['Os portais estão estáveis hoje, {n}. Para onde vamos?', 'Cuidado com as Anomalias do Vazio. O portal sente quando algo estranho desperta.', 'Uma moeda de aurum e o mundo inteiro se abre para você.'],
  classe: ['A lâmina obedece a quem treina, {n}. Volte quando estiver pronto para evoluir.', 'Cada caminho exige sangue compatível. Escolha com sabedoria.', 'Já pensou em qual será sua próxima classe?'],
  ferreiro: ['Ferro bom, martelo firme! Traga minério e eu forjo o que precisar.', 'Uma arma encantada brilha como estrela. Mas cuidado: acima de +3 o risco é seu.', 'Ouvi dizer que o Senhor da Cripta carrega uma lâmina que bebe sangue.'],
  refino: ['Refinar é paciência, {n}. Pedra bruta vira barra, couro vira armadura.', 'Poções frescas! Não vá para o pântano sem elas.', 'As plantas do Brejo das Almas têm propriedades estranhas…'],
  mercador: ['Bem-vindo, {n}! Tenho poções, montarias, pets e até asas para quem tem aurum.', 'Um bom cavalo encurta qualquer viagem. Dê uma olhada!', 'Asas de Luz! Voe acima das montanhas como um verdadeiro herói.'],
  leilao: ['O mercado nunca dorme. Compre barato, venda caro.', 'Itens de chefes valem uma fortuna aqui na casa de leilões.', 'Anuncie suas relíquias, {n}. Sempre há um comprador.'],
  arauto: ['O Eclipse se aproxima, {n}. O reino precisa de heróis.', 'Tenho novas missões para você. Aceite e eu guio seus passos.', 'Dizem que nas tumbas antigas os mortos ainda guardam seus tesouros.'],
};
const BOSS = { tumba: 'Quem ousa perturbar o sono dos mortos?', pantano: 'O lodo vai engolir seus ossos!', destrocos: 'Tudo aqui é meu! Até você!', estranho: 'O Vazio sussurra seu nome…', castelo: 'Ajoelhe-se diante do seu senhor!', ruina: 'Estas ruínas não pertencem aos vivos.', covil: 'Mais uma presa entrou no meu covil.' };
// timbre por raça e gênero
const PITCH = { humano: 1, elfo: 1.15, sombrio: 0.95, orc: 0.55, anao: 0.75, halfling: 1.45, beastman: 0.7, draconato: 0.6, sylph: 1.35, nocturno: 0.85, gigante: 0.5 };
let voices = []; const loadVoices = () => { voices = (globalThis.speechSynthesis?.getVoices() || []).filter(v => /^pt/i.test(v.lang)); }; if (globalThis.speechSynthesis) { loadVoices(); speechSynthesis.onvoiceschanged = loadVoices; }
export function speak(text, o = {}) {
  if (!VOICE.on || !globalThis.speechSynthesis) return;
  const u = new SpeechSynthesisUtterance(text); u.lang = 'pt-BR'; const fv = voices.filter(v => /female|mulher|luciana|francisca|maria/i.test(v.name)), mv = voices.filter(v => !fv.includes(v));
  u.voice = (o.gender === 'f' ? fv[0] || voices[0] : mv[0] || voices[0]) || null; u.pitch = Math.min(2, Math.max(0.1, (PITCH[o.race] || 1) * (o.gender === 'f' ? 1.25 : 1) * (o.boss ? 0.6 : 1))); u.rate = o.boss ? 0.85 : o.race === 'halfling' ? 1.15 : 1; u.volume = 0.9;
  speechSynthesis.cancel(); speechSynthesis.speak(u);
}
// balão de fala
function bubble(text) {
  const c = document.createElement('canvas'), g = c.getContext('2d'), W = 512; g.font = '26px Georgia, serif';
  const words = text.split(' '), lines = []; let cur = ''; for (const w of words) { const t = cur ? cur + ' ' + w : w; if (g.measureText(t).width > W - 40) { lines.push(cur); cur = w; } else cur = t; } lines.push(cur);
  c.width = W; c.height = 30 + lines.length * 32 + 20; g.font = '26px Georgia, serif';
  g.fillStyle = 'rgba(24,18,12,0.88)'; g.strokeStyle = '#c8a060'; g.lineWidth = 3; const r = 18, h = c.height - 16;
  g.beginPath(); g.roundRect ? g.roundRect(3, 3, W - 6, h, r) : g.rect(3, 3, W - 6, h); g.fill(); g.stroke();
  g.beginPath(); g.moveTo(W / 2 - 12, h + 2); g.lineTo(W / 2, c.height - 2); g.lineTo(W / 2 + 12, h + 2); g.fill();
  g.fillStyle = '#ffeec8'; g.textAlign = 'center'; lines.forEach((l, i) => g.fillText(l, W / 2, 40 + i * 32));
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; const sp = new THREE.Sprite(new THREE.SpriteMaterial({ map: t, transparent: true, depthTest: false }));
  sp.scale.set(3.6, 3.6 * c.height / W, 1); sp.renderOrder = 20; return sp;
}
const live = [];
export function say(obj3d, text, o = {}) {
  const b = bubble(text), ws = obj3d.getWorldScale(new THREE.Vector3()).y || 1; b.scale.divideScalar(ws); b.position.set(0, ((o.h || 2.6) + 0.8) / ws, 0); obj3d.add(b); live.push({ b, until: performance.now() + (o.ms || 4500) });
  speak(text, o);
}
export function npcLine(type, name) { const l = LINES[type] || ['Olá, viajante.']; return l[Math.floor(Math.random() * l.length)].replace('{n}', name); }
export const bossLine = type => BOSS[type] || 'Você não sairá daqui com vida!';
export function updateDialog() { const t = performance.now(); for (let i = live.length - 1; i >= 0; i--) { const d = live[i]; if (t > d.until) { d.b.removeFromParent(); d.b.material.map.dispose(); d.b.material.dispose(); live.splice(i, 1); } else if (d.until - t < 400) d.b.material.opacity = (d.until - t) / 400; } }
