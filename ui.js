// ===== Valtheria — interface: quadros móveis, compactar/ocultar, barra extra e aba de equipamento com boneco 3D =====
import * as THREE from './lib/three.module.min.js';

const LS = 'vt_ui_v1';
let ST = {}; try { ST = JSON.parse(localStorage.getItem(LS)) || {}; } catch (_) {}
const save = () => { try { localStorage.setItem(LS, JSON.stringify(ST)); } catch (_) {} };
const TOUCH = () => document.body.classList.contains('touch');
let zTop = 40;

// aplica posição salva (em px, presa à tela)
function applyPos(el, key) {
  const s = ST[key]; if (!s || s.x == null) return;
  const w = el.offsetWidth || 100, h = el.offsetHeight || 40, x = Math.max(-w + 60, Math.min(innerWidth - 60, s.x)), y = Math.max(0, Math.min(innerHeight - 30, s.y));
  Object.assign(el.style, { left: x + 'px', top: y + 'px', right: 'auto', bottom: 'auto', transform: 'none' });
}
// torna um quadro arrastável pelo "handle"; guarda a posição
export function movable(el, key, handle, opt = {}) {
  if (!el || el.dataset.mv) return; el.dataset.mv = key; handle = handle || el; handle.style.cursor = 'move'; handle.style.touchAction = 'none';
  handle.addEventListener('pointerdown', e => {
    if (e.button !== 0 || e.target.closest('button,input,select,a,.sk,.slot,[data-nodrag]') && e.target !== handle) return; if (opt.alt && !e.altKey && !document.body.classList.contains('ui-edit')) return;
    const r = el.getBoundingClientRect(), ox = e.clientX - r.left, oy = e.clientY - r.top; let moved = false; el.style.zIndex = ++zTop;
    const mv = ev => { if (!moved && Math.hypot(ev.clientX - e.clientX, ev.clientY - e.clientY) < 5) return; moved = true; ST[key] = { ...(ST[key] || {}), x: ev.clientX - ox, y: ev.clientY - oy }; applyPos(el, key); ev.preventDefault(); };
    const up = () => { removeEventListener('pointermove', mv); removeEventListener('pointerup', up); if (moved) { save(); el.dataset.dragged = Date.now(); } };
    addEventListener('pointermove', mv); addEventListener('pointerup', up);
  });
  applyPos(el, key); addEventListener('resize', () => applyPos(el, key));
}
// botões de compactar (▁) e ocultar (👁) num quadro; os ocultos vão para a "doca" e voltam com um clique
const DOCK = new Map();
function dock() { let d = document.getElementById('ui-dock'); if (!d) { d = document.createElement('div'); d.id = 'ui-dock'; document.getElementById('hud').appendChild(d); } return d; }
function renderDock() { const d = dock(); d.innerHTML = [...DOCK.entries()].filter(([k]) => ST[k]?.hid).map(([k, o]) => `<button data-k="${k}" title="Mostrar ${o.name}">${o.icon}</button>`).join('') + `<button data-edit="1" title="Organizar a tela: arraste qualquer quadro. Clique de novo para travar.">${document.body.classList.contains('ui-edit') ? '🔓' : '🔒'}</button><button data-reset="1" title="Voltar tudo para o lugar original">↺</button>`;
  d.onclick = e => { const b = e.target.closest('button'); if (!b) return; if (b.dataset.k) { ST[b.dataset.k].hid = false; save(); refresh(b.dataset.k); } else if (b.dataset.edit) document.body.classList.toggle('ui-edit'); else if (b.dataset.reset) { ST = {}; save(); location.reload(); } renderDock(); }; }
function refresh(key) { const o = DOCK.get(key); if (!o) return; const s = ST[key] || {}; o.el.classList.toggle('ui-hid', !!s.hid); o.el.classList.toggle('ui-min', !!s.min); renderDock(); }
export function hudWindow(el, key, name, icon, { handle, alt = true, min = true } = {}) {
  if (!el) return; DOCK.set(key, { el, name, icon }); movable(el, key, handle, { alt });
  const c = document.createElement('div'); c.className = 'ui-ctl'; c.innerHTML = (min ? '<button data-a="min" title="Compactar / expandir">▁</button>' : '') + '<button data-a="hid" title="Ocultar (volta pela doca no canto)">✕</button>';
  c.onclick = e => { const a = e.target.dataset.a; if (!a) return; e.stopPropagation(); ST[key] = { ...(ST[key] || {}), [a]: !(ST[key] || {})[a] }; save(); refresh(key); }; el.appendChild(c); refresh(key);
}
export function initUI(X) {
  if (TOUCH()) return; // no celular a tela é fixa
  const $ = s => document.querySelector(s);
  hudWindow($('#status'), 'status', 'Status', '❤️'); hudWindow($('#mm-wrap'), 'map', 'Minimapa', '🧭'); hudWindow($('#chat'), 'chat', 'Conversa', '💬'); hudWindow($('#quest-track'), 'quest', 'Missões', '📜');
  movable($('#target'), 'target', null, { alt: true }); movable($('#menu'), 'menu', null, { alt: true });
  // quadro principal: arrasta pelo título, compacta com ▁
  const p = $('#panel'), head = p.querySelector('.phead'); movable(p, 'panel', head);
  const mb = document.createElement('button'); mb.textContent = '▁'; mb.title = 'Compactar / expandir'; mb.onclick = () => p.classList.toggle('ui-min'); head.insertBefore(mb, head.lastElementChild);
  renderDock();
}
// ---------- barra de habilidades: móvel, vira na vertical, e barra extra clicável ----------
export function initBars(X) {
  const bar = document.getElementById('bar'); if (TOUCH()) return;
  const grip = document.createElement('div'); grip.id = 'bar-grip'; grip.innerHTML = '<span title="Arraste para mover a barra">⠿</span><button data-a="rot" title="Virar a barra (horizontal / vertical)">⟳</button><button data-a="x" title="Mostrar / esconder a barra extra (9 atalhos só de clique)">＋</button>';
  const wrap = document.createElement('div'); wrap.id = 'bar-wrap'; bar.parentNode.insertBefore(wrap, bar); wrap.appendChild(grip); wrap.appendChild(bar);
  const b2 = document.createElement('div'); b2.id = 'bar2'; document.getElementById('hud').appendChild(b2);
  const g2 = document.createElement('div'); g2.id = 'bar2-wrap'; b2.parentNode.insertBefore(g2, b2); const h2 = document.createElement('div'); h2.className = 'bar2-grip'; h2.textContent = '⠿'; h2.title = 'Arraste para mover'; g2.appendChild(h2); g2.appendChild(b2);
  movable(wrap, 'bar', grip.firstChild); movable(g2, 'bar2', h2);
  const apply = () => { wrap.classList.toggle('vert', !!ST.bar?.vert); g2.classList.toggle('vert', !!ST.bar?.vert); g2.hidden = !!ST.bar2?.off; };
  grip.onclick = e => { const a = e.target.dataset.a; if (a === 'rot') { ST.bar = { ...(ST.bar || {}), vert: !ST.bar?.vert }; } else if (a === 'x') { ST.bar2 = { ...(ST.bar2 || {}), off: !ST.bar2?.off }; } else return; save(); apply(); };
  apply();
}

// ---------- aba de equipamento com o personagem em 3D ----------
const EQ = { open: false, win: null, r: null, scene: null, cam: null, doll: null, yaw: 0.3, sig: '', t: 0 };
export function equipOpen() { return EQ.open; }
export function toggleEquip(X) { EQ.open ? closeEquip() : openEquip(X); }
export function closeEquip() { if (!EQ.win) return; EQ.win.hidden = true; EQ.open = false; }
function openEquip(X) {
  EQ.X = X;
  if (!EQ.win) {
    const w = EQ.win = document.createElement('div'); w.id = 'equip'; w.className = 'win';
    w.innerHTML = `<div class="phead"><span>Equipamento</span><span><button data-a="min" title="Compactar">▁</button><button data-a="close">✕</button></span></div>
      <div class="eq-body"><div class="eq-col" id="eq-l"></div><div class="eq-view"><canvas id="eq-cv" width="260" height="380"></canvas><div class="small eq-hint">arraste para girar</div><div id="eq-stats" class="small"></div></div><div class="eq-col" id="eq-r"></div></div>
      <div class="eq-acc" id="eq-acc"></div><div class="eq-foot" id="eq-foot"></div>`;
    document.body.appendChild(w); movable(w, 'equip', w.querySelector('.phead'));
    w.querySelector('.phead').onclick = e => { const a = e.target.dataset.a; if (a === 'close') closeEquip(); else if (a === 'min') w.classList.toggle('ui-min'); };
    const cv = w.querySelector('#eq-cv'); EQ.r = new THREE.WebGLRenderer({ canvas: cv, antialias: true, alpha: true }); EQ.r.setPixelRatio(Math.min(2, devicePixelRatio)); EQ.r.outputColorSpace = THREE.SRGBColorSpace; EQ.r.toneMapping = THREE.ACESFilmicToneMapping; EQ.r.toneMappingExposure = 1.15;
    EQ.scene = new THREE.Scene(); EQ.cam = new THREE.PerspectiveCamera(32, 260 / 380, 0.1, 50);
    EQ.scene.add(new THREE.HemisphereLight(0xcfe0ff, 0x3a2a20, 1.5)); const k = new THREE.DirectionalLight(0xfff0d8, 2.6); k.position.set(2, 4, 3); EQ.scene.add(k); const rim = new THREE.DirectionalLight(0x7ab0ff, 1.4); rim.position.set(-3, 2, -3); EQ.scene.add(rim);
    const ped = new THREE.Mesh(new THREE.CylinderGeometry(0.75, 0.85, 0.12, 40), new THREE.MeshStandardMaterial({ color: '#2a2230', metalness: 0.4, roughness: 0.5 })); ped.position.y = -0.06; EQ.scene.add(ped);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(0.78, 0.015, 6, 60), new THREE.MeshBasicMaterial({ color: '#f2c46d' })); ring.rotation.x = Math.PI / 2; EQ.scene.add(ring);
    let drag = null; cv.addEventListener('pointerdown', e => { drag = e.clientX; cv.setPointerCapture(e.pointerId); }); cv.addEventListener('pointermove', e => { if (drag == null) return; EQ.yaw += (e.clientX - drag) * 0.012; drag = e.clientX; }); cv.addEventListener('pointerup', () => drag = null);
    w.addEventListener('click', e => { const s = e.target.closest('[data-eq]'); if (s) X.onSlot(s.dataset.eq, s.dataset.id || ''); const b = e.target.closest('[data-act]'); if (b) X.onAct(b.dataset.act); });
  }
  EQ.win.hidden = false; EQ.open = true; EQ.sig = ''; renderEquip();
}
const SLOTS_L = [['elmo', 'Elmo', '⛑️'], ['armadura', 'Armadura', '🦺'], ['luvas', 'Luvas', '🧤'], ['botas', 'Botas', '🥾']], SLOTS_R = [['arma', 'Arma', '⚔️'], ['escudo', 'Escudo / 2ª mão', '🛡️'], ['asas', 'Asas', '🪽'], ['montaria', 'Montaria', '🐎']];
const ACC = [['colar', 'Colar', '📿'], ['anel1', 'Anel', '💍'], ['anel2', 'Anel', '💍'], ['brinco', 'Brinco', '✨'], ['capa', 'Capa', '🧣'], ['pet', 'Pet', '🐾'], ['reliquia', 'Relíquia', '🏺'], ['insignia', 'Insígnia do clã', '🚩']];
export function renderEquip() {
  if (!EQ.open) return; const X = EQ.X, d = X.data(), $ = s => EQ.win.querySelector(s);
  const cell = ([k, label, ic]) => { const it = d.slots[k]; return `<div class="eq-slot ${it ? 'has' : ''} ${d.locked[k] ? 'lock' : ''}" data-eq="${k}" data-id="${it ? it.id : ''}" title="${it ? X.esc(it.name) + (it.desc ? ' — ' + X.esc(it.desc) : '') + ' (clique para tirar)' : d.locked[k] || label}"><div class="ic">${it ? it.html : ic}</div><div class="nm">${it ? X.esc(it.name) + (it.enc ? ' <b>+' + it.enc + '</b>' : '') : label}</div></div>`; };
  $('#eq-l').innerHTML = SLOTS_L.map(cell).join(''); $('#eq-r').innerHTML = SLOTS_R.map(cell).join(''); $('#eq-acc').innerHTML = ACC.map(cell).join('');
  $('#eq-stats').innerHTML = d.stats; $('#eq-foot').innerHTML = d.foot;
  const sig = d.sig; if (sig !== EQ.sig) { EQ.sig = sig; if (EQ.doll) { EQ.scene.remove(EQ.doll.root); EQ.doll.disposed = true; } EQ.doll = X.makeDoll(); EQ.scene.add(EQ.doll.root); }
}
export function updateEquip(dt) {
  if (!EQ.open || EQ.win.classList.contains('ui-min') || !EQ.doll) return; EQ.t += dt; if (EQ.t < 1 / 30) return; const d = EQ.t; EQ.t = 0;
  const h = EQ.doll.height || 1.8; EQ.doll.root.rotation.y = EQ.yaw; EQ.X.animDoll(EQ.doll, d);
  EQ.cam.position.set(0, h * 0.55, h * 2.35 + 0.6); EQ.cam.lookAt(0, h * 0.52, 0); EQ.r.render(EQ.scene, EQ.cam);
}
