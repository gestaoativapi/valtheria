// ===== Reinos de Aurora 3D — dados do jogo (cliente e gerador de SQL) =====
(function (root) {
  const GRADES = [
    { id: 'NG', lvl: 1, gp: 1, name: 'Sem Grau', color: '#bdbdbd' },
    { id: 'D', lvl: 20, gp: 2.2, name: 'Grau D', color: '#c8955a' },
    { id: 'C', lvl: 40, gp: 3.6, name: 'Grau C', color: '#d6dde6' },
    { id: 'B', lvl: 52, gp: 5.0, name: 'Grau B', color: '#5aa9ff' },
    { id: 'A', lvl: 61, gp: 6.6, name: 'Grau A', color: '#ff5a5a' },
    { id: 'S', lvl: 76, gp: 8.8, name: 'Grau S', color: '#d38cff' },
  ];
  const gradeForLevel = (L) => { let g = 0; GRADES.forEach((x, i) => { if (L >= x.lvl) g = i; }); return g; };
  const MAX_LEVEL = 80;
  const RANK_LVL = [1, 20, 40, 76];
  const RANK_MULT = [1, 1.1, 1.25, 1.45];
  const rankForLevel = (L) => (L >= 76 ? 3 : L >= 40 ? 2 : L >= 20 ? 1 : 0);
  const xpNeed = (L) => Math.round(50 * Math.pow(L, 2.4));
  const mobXp = (L) => Math.round(xpNeed(L) / (8 + 0.5 * L));
  const profLevel = (xp) => Math.floor(Math.sqrt((xp || 0) / 40));
  const profXpFor = (l) => 40 * l * l;
  const lf = (L) => Math.pow(1.05, L - 1);
  const dmgFormula = (atk, mult, def) => atk * mult * atk / (atk + def * 0.5);

  const RACES = {
    humano: { name: 'Humano', types: ['l', 'm'], hp: { l: 130, m: 95 }, mp: { l: 40, m: 100 }, patk: { l: 12, m: 6 }, matk: { l: 5, m: 13 }, pdef: 8, mdef: 8, spd: 1.0, h: 1.0, w: 1.0, skins: ['#f1c27d', '#e0ac69', '#c68642', '#8d5524'], desc: 'Equilibrados, versáteis em qualquer caminho.' },
    elfo: { name: 'Elfo', types: ['l', 'm'], hp: { l: 120, m: 90 }, mp: { l: 45, m: 110 }, patk: { l: 11, m: 6 }, matk: { l: 5, m: 14 }, pdef: 8, mdef: 10, spd: 1.08, h: 1.04, w: 0.92, skins: ['#fde3c8', '#f5d0b0', '#e8c39e'], desc: 'Ágeis e precisos, os mais rápidos do reino.' },
    sombrio: { name: 'Elfo Sombrio', types: ['l', 'm'], hp: { l: 115, m: 85 }, mp: { l: 42, m: 105 }, patk: { l: 14, m: 7 }, matk: { l: 5, m: 15 }, pdef: 7, mdef: 9, spd: 1.04, h: 1.03, w: 0.94, skins: ['#b7b5d6', '#9c99c4', '#8a86b8'], desc: 'Dano altíssimo, porém mais frágeis.' },
    orc: { name: 'Orc', types: ['l', 'm'], hp: { l: 155, m: 110 }, mp: { l: 38, m: 95 }, patk: { l: 14, m: 7 }, matk: { l: 4, m: 12 }, pdef: 9, mdef: 8, spd: 0.95, h: 1.12, w: 1.22, skins: ['#7ca05a', '#6b8f4e', '#8a9a6a'], desc: 'Vida e força brutas, resistência lendária.' },
    anao: { name: 'Anão', types: ['l'], hp: { l: 145 }, mp: { l: 45 }, patk: { l: 13 }, matk: { l: 4 }, pdef: 10, mdef: 9, spd: 0.92, h: 0.78, w: 1.18, skins: ['#f1c27d', '#e0ac69', '#d19a66'], desc: 'Mestres da coleta e da forja. Só seguem o caminho Lutador.' },
  };
  const TYPES = { l: 'Lutador', m: 'Místico' };
  const HAIR_COLORS = ['#2b1d14', '#6b4423', '#c89b4a', '#e8d8b0', '#b33a2a', '#1f3b73', '#e0e0e0', '#2d6b3a'];

  // ----- arquétipos e habilidades -----
  // tipos: hit, buff, heal, dash, leap, taunt, mana
  const S = (lvl, name, icon, o) => ({ lvl, name, icon, mp: 10, cd: 6, ...o });
  const ARCH = {
    tanque: { name: 'Tanque', weapon: 'espada', armor: 'pesada', atk: 'p', skills: [
      S(1, 'Golpe de Escudo', '🛡️', { type: 'hit', mult: 1.3, stun: 1.2, mp: 6, cd: 6 }),
      S(5, 'Provocar', '📣', { type: 'taunt', radius: 12, mp: 8, cd: 12 }),
      S(12, 'Muralha', '🧱', { type: 'buff', buff: { pdef: 0.6 }, dur: 12, mp: 12, cd: 30 }),
      S(20, 'Investida', '💨', { type: 'dash', mult: 1.2, range: 14, mp: 10, cd: 10 }),
      S(35, 'Golpe Sagrado', '✨', { type: 'hit', mult: 1.8, aoe: 4, mp: 18, cd: 10 }),
      S(52, 'Cura Divina', '💖', { type: 'heal', pct: 0.3, mp: 30, cd: 40 }),
      S(76, 'Égide Absoluta', '🌟', { type: 'buff', buff: { invuln: 1 }, dur: 5, mp: 50, cd: 120 }),
    ] },
    guerreiro: { name: 'Guerreiro', weapon: 'espadao', armor: 'pesada', atk: 'p', skills: [
      S(1, 'Golpe Poderoso', '⚔️', { type: 'hit', mult: 1.6, mp: 5, cd: 4 }),
      S(5, 'Giro Mortal', '🌀', { type: 'hit', mult: 1.2, aoe: 4, self: true, mp: 10, cd: 8 }),
      S(12, 'Fúria', '😡', { type: 'buff', buff: { patk: 0.3 }, dur: 15, mp: 12, cd: 35 }),
      S(20, 'Investida', '💨', { type: 'dash', mult: 1.2, range: 14, mp: 10, cd: 10 }),
      S(35, 'Golpe Esmagador', '🔨', { type: 'hit', mult: 2.4, mp: 20, cd: 10 }),
      S(52, 'Sede de Sangue', '🩸', { type: 'buff', buff: { lifesteal: 0.2 }, dur: 15, mp: 20, cd: 45 }),
      S(76, 'Ira do Titã', '☄️', { type: 'hit', mult: 4.0, aoe: 5, mp: 45, cd: 60 }),
    ] },
    arqueiro: { name: 'Arqueiro', weapon: 'arco', armor: 'leve', atk: 'p', skills: [
      S(1, 'Tiro Preciso', '🎯', { type: 'hit', mult: 1.6, mp: 5, cd: 4 }),
      S(5, 'Chuva de Flechas', '🌧️', { type: 'hit', mult: 1.1, aoe: 5, mp: 14, cd: 10 }),
      S(12, 'Olho de Águia', '🦅', { type: 'buff', buff: { crit: 0.25 }, dur: 20, mp: 12, cd: 40 }),
      S(20, 'Tiro Duplo', '🏹', { type: 'hit', mult: 2.0, mp: 10, cd: 6 }),
      S(35, 'Salto para Trás', '🦘', { type: 'leap', dist: 10, mp: 8, cd: 12 }),
      S(52, 'Flecha Perfurante', '💥', { type: 'hit', mult: 2.6, mp: 22, cd: 10 }),
      S(76, 'Flecha Estelar', '⭐', { type: 'hit', mult: 4.5, mp: 45, cd: 60 }),
    ] },
    adaga: { name: 'Adaga', weapon: 'adaga', armor: 'leve', atk: 'p', skills: [
      S(1, 'Apunhalar', '🗡️', { type: 'hit', mult: 1.8, mp: 6, cd: 5 }),
      S(5, 'Veneno', '🧪', { type: 'hit', mult: 0.6, dot: { mult: 1.5, dur: 8 }, mp: 10, cd: 10 }),
      S(12, 'Furtividade', '👤', { type: 'buff', buff: { speed: 0.4 }, dur: 10, mp: 10, cd: 30 }),
      S(20, 'Golpe Rápido', '⚡', { type: 'hit', mult: 1.3, mp: 4, cd: 2.5 }),
      S(35, 'Lâmina Sombria', '🌑', { type: 'hit', mult: 2.5, mp: 18, cd: 9 }),
      S(52, 'Evasão', '🌪️', { type: 'buff', buff: { dodge: 0.4 }, dur: 12, mp: 15, cd: 40 }),
      S(76, 'Execução', '💀', { type: 'hit', mult: 5.0, execute: true, mp: 40, cd: 45 }),
    ] },
    mago: { name: 'Mago', weapon: 'cajado', armor: 'robe', atk: 'm', skills: [
      S(1, 'Bola de Fogo', '🔥', { type: 'hit', mult: 1.8, mp: 10, cd: 3, fx: 'fire' }),
      S(5, 'Lança de Gelo', '❄️', { type: 'hit', mult: 1.5, slow: 0.4, mp: 10, cd: 5, fx: 'ice' }),
      S(12, 'Nova Arcana', '💫', { type: 'hit', mult: 1.4, aoe: 5, mp: 16, cd: 8, fx: 'arcane' }),
      S(20, 'Escudo Mágico', '🔮', { type: 'buff', buff: { pdef: 0.4, mdef: 0.4 }, dur: 20, mp: 20, cd: 40 }),
      S(35, 'Meteoro', '☄️', { type: 'hit', mult: 3.0, aoe: 6, mp: 30, cd: 12, fx: 'fire' }),
      S(52, 'Recarga de Mana', '💧', { type: 'mana', pct: 0.3, mp: 0, cd: 60 }),
      S(76, 'Cataclismo', '🌋', { type: 'hit', mult: 5.0, aoe: 8, mp: 60, cd: 60, fx: 'fire' }),
    ] },
    curandeiro: { name: 'Curandeiro', weapon: 'cajado', armor: 'robe', atk: 'm', skills: [
      S(1, 'Luz Sagrada', '☀️', { type: 'hit', mult: 1.5, mp: 8, cd: 3, fx: 'holy' }),
      S(5, 'Cura', '💚', { type: 'heal', pct: 0.35, mp: 15, cd: 6 }),
      S(12, 'Bênção', '🙏', { type: 'buff', buff: { patk: 0.2, matk: 0.2, pdef: 0.2 }, dur: 30, mp: 20, cd: 45 }),
      S(20, 'Regeneração', '🌿', { type: 'buff', buff: { hot: 0.04 }, dur: 10, mp: 18, cd: 20 }),
      S(35, 'Raio Divino', '⚡', { type: 'hit', mult: 2.4, mp: 20, cd: 8, fx: 'holy' }),
      S(52, 'Grande Cura', '💖', { type: 'heal', pct: 0.7, mp: 35, cd: 30 }),
      S(76, 'Julgamento', '⚖️', { type: 'hit', mult: 4.5, aoe: 5, mp: 55, cd: 60, fx: 'holy' }),
    ] },
    xama: { name: 'Xamã', weapon: 'cajado', armor: 'robe', atk: 'm', skills: [
      S(1, 'Raio Espiritual', '👻', { type: 'hit', mult: 1.6, mp: 8, cd: 3, fx: 'spirit' }),
      S(5, 'Maldição', '🕯️', { type: 'hit', mult: 0.5, dot: { mult: 2.0, dur: 10 }, mp: 12, cd: 10, fx: 'spirit' }),
      S(12, 'Totem de Guerra', '🗿', { type: 'buff', buff: { patk: 0.25, matk: 0.25 }, dur: 30, mp: 18, cd: 45 }),
      S(20, 'Drenar Vida', '🩸', { type: 'hit', mult: 1.6, drain: 0.5, mp: 14, cd: 8, fx: 'spirit' }),
      S(35, 'Tempestade', '⛈️', { type: 'hit', mult: 2.2, aoe: 6, mp: 26, cd: 12, fx: 'arcane' }),
      S(52, 'Grito Ancestral', '📯', { type: 'buff', buff: { speed: 0.3, hot: 0.02 }, dur: 15, mp: 20, cd: 40 }),
      S(76, 'Fúria Ancestral', '🔥', { type: 'hit', mult: 5.0, aoe: 7, mp: 55, cd: 60, fx: 'fire' }),
    ] },
    monge: { name: 'Monge', weapon: 'punhos', armor: 'leve', atk: 'p', skills: [
      S(1, 'Soco Relâmpago', '👊', { type: 'hit', mult: 1.4, mp: 4, cd: 2.5 }),
      S(5, 'Combo Triplo', '🥋', { type: 'hit', mult: 2.1, mp: 8, cd: 5 }),
      S(12, 'Foco', '🧘', { type: 'buff', buff: { atkspd: 0.3 }, dur: 20, mp: 12, cd: 40 }),
      S(20, 'Chute Giratório', '🦶', { type: 'hit', mult: 1.3, aoe: 4, self: true, mp: 12, cd: 8 }),
      S(35, 'Punho de Ferro', '✊', { type: 'hit', mult: 2.6, stun: 1, mp: 18, cd: 10 }),
      S(52, 'Meditação', '☯️', { type: 'heal', pct: 0.3, mp: 0, cd: 45 }),
      S(76, 'Explosão de Chi', '💥', { type: 'hit', mult: 4.5, aoe: 5, mp: 45, cd: 60 }),
    ] },
    artesao: { name: 'Artesão', weapon: 'martelo', armor: 'pesada', atk: 'p', skills: [
      S(1, 'Martelada', '🔨', { type: 'hit', mult: 1.6, mp: 5, cd: 4 }),
      S(5, 'Terremoto', '🌋', { type: 'hit', mult: 1.3, aoe: 5, self: true, mp: 12, cd: 9 }),
      S(12, 'Pele de Pedra', '🪨', { type: 'buff', buff: { pdef: 0.5 }, dur: 15, mp: 12, cd: 35 }),
      S(20, 'Golpe Pesado', '⚒️', { type: 'hit', mult: 2.3, stun: 1, mp: 16, cd: 10 }),
      S(35, 'Investida', '💨', { type: 'dash', mult: 1.2, range: 14, mp: 10, cd: 10 }),
      S(52, 'Grito do Clã', '📣', { type: 'buff', buff: { patk: 0.25 }, dur: 20, mp: 18, cd: 40 }),
      S(76, 'Fúria da Montanha', '⛰️', { type: 'hit', mult: 4.2, aoe: 6, mp: 45, cd: 60 }),
    ] },
  };

  // ----- árvore de classes: base (nv 1) → 2ª (nv 20) → 3ª (nv 40) → 4ª (nv 76) -----
  const CLASSES = {};
  const C = (id, name, race, type, rank, parent, arch, bonus) => { CLASSES[id] = { id, name, race, type, rank, parent, arch, bonus: bonus || null }; };
  const line = (race, type, parent, arch, names, prefix, bonus) => {
    let p = parent; names.forEach((n, i) => { const id = prefix + '_' + (i + 1); C(id, n, race, type, i + 1, p, arch, bonus); p = id; });
  };
  C('hum_l', 'Guerreiro Humano', 'humano', 'l', 0, null, 'guerreiro');
  line('humano', 'l', 'hum_l', 'tanque', ['Cavaleiro', 'Paladino da Aurora', 'Guardião Sagrado'], 'hum_tq');
  line('humano', 'l', 'hum_l', 'guerreiro', ['Combatente', 'Mestre de Armas', 'Senhor da Guerra'], 'hum_gr');
  line('humano', 'l', 'hum_l', 'arqueiro', ['Batedor', 'Caçador', 'Atirador Celeste'], 'hum_aq');
  C('hum_m', 'Aprendiz Arcano', 'humano', 'm', 0, null, 'mago');
  line('humano', 'm', 'hum_m', 'mago', ['Mago', 'Arquimago', 'Sábio do Fogo'], 'hum_mg');
  line('humano', 'm', 'hum_m', 'curandeiro', ['Clérigo', 'Bispo', 'Santo Curador'], 'hum_cu');
  C('elf_l', 'Guerreiro Élfico', 'elfo', 'l', 0, null, 'guerreiro');
  line('elfo', 'l', 'elf_l', 'tanque', ['Cavaleiro Élfico', 'Templário da Floresta', 'Guardião Ancestral'], 'elf_tq');
  line('elfo', 'l', 'elf_l', 'arqueiro', ['Arqueiro Élfico', 'Patrulheiro', 'Flecha Lunar'], 'elf_aq');
  line('elfo', 'l', 'elf_l', 'adaga', ['Andarilho', 'Lâmina do Vento', 'Espectro da Brisa'], 'elf_ad');
  C('elf_m', 'Místico Élfico', 'elfo', 'm', 0, null, 'mago');
  line('elfo', 'm', 'elf_m', 'mago', ['Feiticeiro Élfico', 'Mago das Águas', 'Mestre das Marés'], 'elf_mg');
  line('elfo', 'm', 'elf_m', 'curandeiro', ['Oráculo Élfico', 'Ancião da Floresta', 'Voz da Floresta'], 'elf_cu');
  C('de_l', 'Guerreiro Sombrio', 'sombrio', 'l', 0, null, 'guerreiro');
  line('sombrio', 'l', 'de_l', 'tanque', ['Cavaleiro Sombrio', 'Vingador', 'Guardião da Sombra'], 'de_tq');
  line('sombrio', 'l', 'de_l', 'adaga', ['Assassino', 'Lâmina Noturna', 'Fantasma'], 'de_ad');
  line('sombrio', 'l', 'de_l', 'arqueiro', ['Atirador Sombrio', 'Predador', 'Caçador do Vazio'], 'de_aq');
  C('de_m', 'Místico Sombrio', 'sombrio', 'm', 0, null, 'mago');
  line('sombrio', 'm', 'de_m', 'mago', ['Feiticeiro Sombrio', 'Necromante', 'Arauto do Vazio'], 'de_mg');
  line('sombrio', 'm', 'de_m', 'xama', ['Xamã Sombrio', 'Profeta Sombrio', 'Oráculo do Vazio'], 'de_xa');
  C('orc_l', 'Guerreiro Orc', 'orc', 'l', 0, null, 'guerreiro');
  line('orc', 'l', 'orc_l', 'guerreiro', ['Saqueador', 'Destruidor', 'Titã'], 'orc_gr');
  line('orc', 'l', 'orc_l', 'monge', ['Monge', 'Punho de Ferro', 'Mestre do Punho'], 'orc_mo');
  C('orc_m', 'Místico Orc', 'orc', 'm', 0, null, 'xama');
  line('orc', 'm', 'orc_m', 'xama', ['Xamã Orc', 'Senhor Tribal', 'Ancião Tribal'], 'orc_xa');
  line('orc', 'm', 'orc_m', 'curandeiro', ['Invocador Tribal', 'Bramido Sagrado', 'Voz dos Ancestrais'], 'orc_cu');
  C('dw_l', 'Guerreiro Anão', 'anao', 'l', 0, null, 'artesao');
  line('anao', 'l', 'dw_l', 'artesao', ['Coletor', 'Prospector', 'Mestre Minerador'], 'dw_co', 'coleta');
  line('anao', 'l', 'dw_l', 'artesao', ['Artífice', 'Forjador', 'Mestre Forjador'], 'dw_fo', 'forja');
  const baseClass = (race, type) => Object.values(CLASSES).find(c => c.race === race && c.type === type && c.rank === 0);
  const nextClasses = (cid) => Object.values(CLASSES).filter(c => c.parent === cid);

  // ----- itens -----
  const ITEMS = {}, RECIPES = {};
  const g = (i) => GRADES[i].id.toLowerCase();
  const RES = { madeira: ['Madeira', 'tabua', 'Tábua', '🪵', '🟫'], minerio: ['Minério', 'barra', 'Barra', '🪨', '🧱'], fibra: ['Fibra', 'tecido', 'Tecido', '🌿', '🧵'], pele: ['Pele', 'couro', 'Couro', '🐾', '🟤'] };
  const WEAPONS = {
    espada: { name: 'Espada e Escudo', icon: '🛡️', range: 2.6, spd: 1.0, inputs: { barra: 6, couro: 2 } },
    espadao: { name: 'Espadão', icon: '⚔️', range: 2.9, spd: 1.15, inputs: { barra: 9, couro: 2 } },
    arco: { name: 'Arco', icon: '🏹', range: 22, spd: 1.3, inputs: { tabua: 7, tecido: 2 } },
    adaga: { name: 'Adagas', icon: '🗡️', range: 2.3, spd: 0.75, inputs: { barra: 4, couro: 2 } },
    cajado: { name: 'Cajado', icon: '🪄', range: 18, spd: 1.4, magic: true, inputs: { tabua: 5, tecido: 3, barra: 1 } },
    punhos: { name: 'Punhos', icon: '🥊', range: 2.2, spd: 0.7, inputs: { barra: 4, couro: 3 } },
    martelo: { name: 'Martelo', icon: '🔨', range: 2.7, spd: 1.1, inputs: { barra: 7, tabua: 2 } },
  };
  const ARMORS = {
    pesada: { name: 'Armadura Pesada', icon: '🦾', inputs: { barra: 10, couro: 2 } },
    leve: { name: 'Armadura Leve', icon: '🦺', inputs: { couro: 9, tecido: 2 } },
    robe: { name: 'Túnica Mágica', icon: '👘', inputs: { tecido: 10, couro: 1 } },
  };
  const GRADE_NAMES = ['Rústico', 'de Bronze', 'de Aço', 'Azurita', 'Rubro', 'Celestial'];
  GRADES.forEach((G, i) => {
    for (const [k, r] of Object.entries(RES)) {
      ITEMS[`${k}_${g(i)}`] = { id: `${k}_${g(i)}`, name: `${r[0]} ${G.id}`, grade: i, type: 'raw', icon: r[3] };
      ITEMS[`${r[1]}_${g(i)}`] = { id: `${r[1]}_${g(i)}`, name: `${r[2]} ${G.id}`, grade: i, type: 'refined', icon: r[4] };
      const inp = { [`${k}_${g(i)}`]: i >= 3 ? 3 : 2 }; if (i > 0) inp[`${r[1]}_${g(i - 1)}`] = 1;
      RECIPES[`${r[1]}_${g(i)}`] = { id: `${r[1]}_${g(i)}`, out: `${r[1]}_${g(i)}`, qty: 1, station: 'refinaria', prof: 'refino', grade: i, inputs: inp, xp: 6 * (i + 1) };
    }
    const extra = i >= 5 ? { gema: 2, fragmento: 2 } : i >= 3 ? { gema: 1 } : {};
    for (const [k, w] of Object.entries(WEAPONS)) {
      const id = `${k}_${g(i)}`;
      ITEMS[id] = { id, name: `${w.name} ${GRADE_NAMES[i]}`, grade: i, type: 'weapon', slot: 'arma', kind: k, icon: w.icon,
        stats: w.magic ? { matk: Math.round(9 * G.gp * 10) / 10 } : { patk: Math.round(8 * G.gp * 10) / 10 } };
      const inp = {}; for (const [m, q] of Object.entries(w.inputs)) inp[`${m}_${g(i)}`] = q; Object.assign(inp, extra);
      RECIPES[id] = { id, out: id, qty: 1, station: 'forja', prof: 'forja', grade: i, inputs: inp, xp: 22 * (i + 1) };
    }
    for (const [k, a] of Object.entries(ARMORS)) {
      const id = `${k}_${g(i)}`, gp = G.gp;
      const st = k === 'pesada' ? { pdef: 10 * gp, mdef: 3 * gp, hp: 20 * gp } : k === 'leve' ? { pdef: 7 * gp, mdef: 4 * gp, spd: 0.05 } : { pdef: 4 * gp, mdef: 8 * gp, mp: 25 * gp, matkPct: 0.1 };
      ITEMS[id] = { id, name: `${a.name} ${GRADE_NAMES[i]}`, grade: i, type: 'armor', slot: 'armadura', kind: k, icon: a.icon, stats: st };
      const inp = {}; for (const [m, q] of Object.entries(a.inputs)) inp[`${m}_${g(i)}`] = q; Object.assign(inp, extra);
      RECIPES[id] = { id, out: id, qty: 1, station: 'forja', prof: 'forja', grade: i, inputs: inp, xp: 22 * (i + 1) };
    }
    const kid = `kit_${g(i)}`;
    ITEMS[kid] = { id: kid, name: `Kit de Coleta ${G.id}`, grade: i, type: 'tool', icon: '⛏️' };
    RECIPES[kid] = { id: kid, out: kid, qty: 1, station: 'forja', prof: 'forja', grade: i, inputs: { [`tabua_${g(i)}`]: 3, [`barra_${g(i)}`]: 3 }, xp: 15 * (i + 1) };
  });
  ITEMS.gema = { id: 'gema', name: 'Gema Arcana', grade: 3, type: 'special', icon: '💎' };
  ITEMS.fragmento = { id: 'fragmento', name: 'Fragmento Estelar', grade: 5, type: 'special', icon: '🌠' };
  ITEMS.pocao_hp = { id: 'pocao_hp', name: 'Poção de Vida', grade: 0, type: 'potion', icon: '🧪', stats: { hpPct: 0.3 } };
  ITEMS.pocao_hp2 = { id: 'pocao_hp2', name: 'Poção de Vida Maior', grade: 2, type: 'potion', icon: '❤️‍🩹', stats: { hpPct: 0.6 } };
  ITEMS.pocao_mp = { id: 'pocao_mp', name: 'Poção de Mana', grade: 1, type: 'potion', icon: '💧', stats: { mpPct: 0.4 } };
  ITEMS.retorno = { id: 'retorno', name: 'Pergaminho de Retorno', grade: 0, type: 'scroll', icon: '📜' };
  RECIPES.pocao_hp = { id: 'pocao_hp', out: 'pocao_hp', qty: 2, station: 'alquimia', prof: 'refino', grade: 0, inputs: { fibra_ng: 3 }, xp: 8 };
  RECIPES.pocao_mp = { id: 'pocao_mp', out: 'pocao_mp', qty: 2, station: 'alquimia', prof: 'refino', grade: 1, inputs: { fibra_d: 2, pele_ng: 1 }, xp: 14 };
  RECIPES.pocao_hp2 = { id: 'pocao_hp2', out: 'pocao_hp2', qty: 2, station: 'alquimia', prof: 'refino', grade: 2, inputs: { fibra_c: 3, tecido_d: 1 }, xp: 24 };
  RECIPES.retorno = { id: 'retorno', out: 'retorno', qty: 2, station: 'alquimia', prof: 'refino', grade: 0, inputs: { tecido_ng: 1, madeira_ng: 1 }, xp: 6 };
  // loja do NPC (compra com aurum)
  const SHOP = { pocao_hp: 25, pocao_mp: 60, retorno: 80, kit_ng: 150 };
  Object.keys(WEAPONS).forEach(k => SHOP[`${k}_ng`] = 300); Object.keys(ARMORS).forEach(k => SHOP[`${k}_ng`] = 350);
  const npcPrice = (it) => Math.round(({ raw: 3, refined: 9, tool: 40, potion: 6, scroll: 20, special: 400 }[it.type] || 120) * Math.pow(2.2, it.grade));

  // ----- cidades, regiões e teleporte -----
  const WORLD = { SIZE: 3000, SEED: 20261110 };
  const TOWNS = [
    { id: 'aurora', name: 'Vila Aurora', x: 1500, z: 2550, min: 1, max: 19, theme: 'verde', spots: [['Campos do Amanhecer', 200], ['Bosque dos Javalis', 330]] },
    { id: 'dourado', name: 'Forte Dourado', x: 650, z: 2050, min: 20, max: 39, theme: 'outono', spots: [['Planície dos Bandidos', 120], ['Ninho das Aranhas', 250]] },
    { id: 'pedra', name: 'Pedra Alta', x: 2350, z: 1950, min: 40, max: 51, theme: 'rocha', spots: [['Pedreira dos Golens', 60], ['Cripta Esquecida', 300]] },
    { id: 'sylvar', name: 'Sylvar', x: 1500, z: 1450, min: 52, max: 60, theme: 'floresta', spots: [['Coração da Mata', 20], ['Vale Espectral', 160]] },
    { id: 'rubra', name: 'Cidadela Rubra', x: 650, z: 800, min: 61, max: 75, theme: 'rubro', spots: [['Deserto Escarlate', 140], ['Fenda Demoníaca', 280]] },
    { id: 'celeste', name: 'Bastião Celeste', x: 2350, z: 650, min: 76, max: 80, theme: 'cinza', spots: [['Ninho dos Dragões', 100], ['Ruínas de Aeternum', 230]] },
  ];
  TOWNS.forEach((t, i) => { t.index = i; t.spotsPos = t.spots.map(([n, ang]) => ({ name: n, x: t.x + Math.cos(ang * Math.PI / 180) * 270, z: t.z + Math.sin(ang * Math.PI / 180) * 270, lvl: Math.round((t.min + t.max) / 2) })); });
  const SAFE_R = 70;
  const teleCost = (lvl) => 50 + lvl * 35;

  // ----- monstros -----
  const MOBS = [
    [{ id: 'javali', name: 'Javali Selvagem', model: 'quad', color: '#7a4a28', scale: 0.9, aggro: false }, { id: 'lobo', name: 'Lobo Cinzento', model: 'quad', color: '#8a8f99', scale: 0.85, aggro: true }, { id: 'rei_javali', name: 'Rei Javali', model: 'quad', color: '#4a2a14', scale: 2.2, boss: true }],
    [{ id: 'bandido', name: 'Orc Bandido', model: 'humanoid', color: '#5f8a3a', scale: 1.05, aggro: true }, { id: 'aranha', name: 'Aranha Gigante', model: 'spider', color: '#3a2a3a', scale: 1, aggro: true }, { id: 'rainha', name: 'Rainha Aracnídea', model: 'spider', color: '#5a1a4a', scale: 2.4, boss: true }],
    [{ id: 'golem', name: 'Golem de Pedra', model: 'golem', color: '#8a8478', scale: 1.1, aggro: false }, { id: 'esqueleto', name: 'Esqueleto Guerreiro', model: 'humanoid', color: '#e6e0cf', scale: 1, aggro: true }, { id: 'golem_anc', name: 'Golem Ancestral', model: 'golem', color: '#5a6a7a', scale: 2.3, boss: true }],
    [{ id: 'ent', name: 'Ent Corrompido', model: 'ent', color: '#4a6a2a', scale: 1.1, aggro: false }, { id: 'lobo_esp', name: 'Lobo Espectral', model: 'quad', color: '#7ab8ff', scale: 1, aggro: true, ghost: true }, { id: 'ent_mil', name: 'Ent Milenar', model: 'ent', color: '#2a4a1a', scale: 2.2, boss: true }],
    [{ id: 'demonio', name: 'Demônio Rubro', model: 'humanoid', color: '#b03030', scale: 1.15, aggro: true, horns: true }, { id: 'lagarto', name: 'Lagarto Guerreiro', model: 'quad', color: '#9aa040', scale: 1.1, aggro: true }, { id: 'senhor_dem', name: 'Senhor Demônio', model: 'humanoid', color: '#6a0a0a', scale: 2.4, boss: true, horns: true }],
    [{ id: 'dragonete', name: 'Dragonete', model: 'dragon', color: '#6a4a9a', scale: 1, aggro: true }, { id: 'caido', name: 'Cavaleiro Caído', model: 'humanoid', color: '#2a2a3a', scale: 1.1, aggro: true }, { id: 'dragao', name: 'Dragão Celeste', model: 'dragon', color: '#d0c070', scale: 2.8, boss: true }],
  ];
  // estatísticas esperadas de um jogador do nível L (balanceia os monstros)
  function expected(L) {
    const f = lf(L), gi = gradeForLevel(L), gp = GRADES[gi].gp, r = rankForLevel(L);
    return { atk: (12 + 8 * gp) * f * RANK_MULT[r], hp: 130 * f * (1 + 0.03 * r) + 20 * gp, def: (8 + 8 * gp) * f };
  }
  function mobStats(L, boss) {
    const e = expected(L);
    const hp = Math.round(e.atk * 0.82 * 7 * (boss ? 14 : 1));
    return { L, hp, atk: e.hp / 10 * (boss ? 1.8 : 1), def: e.def * 0.6, xp: mobXp(L) * (boss ? 12 : 1), speed: 4.2 };
  }

  // ----- atributos do personagem -----
  function charStats(c, buffs) {
    buffs = buffs || {};
    const R = RACES[c.race], t = c.type, L = c.level, f = lf(L), cl = CLASSES[c.class_id] || baseClass(c.race, c.type), rk = cl.rank;
    const eq = c.equipment || {}, w = ITEMS[eq.arma], a = ITEMS[eq.armadura];
    const ws = w ? w.stats : {}, as = a ? a.stats : {};
    const wk = w ? WEAPONS[w.kind] : { range: 2.2, spd: 0.9 };
    const B = (k) => 1 + (buffs[k] || 0);
    const s = {
      maxHp: Math.round((R.hp[t] * f * (1 + 0.03 * rk) + (as.hp || 0)) ),
      maxMp: Math.round(R.mp[t] * f * (1 + 0.02 * rk) + (as.mp || 0)),
      patk: (R.patk[t] + (ws.patk || 0)) * f * RANK_MULT[rk] * B('patk'),
      matk: (R.matk[t] + (ws.matk || 0)) * f * RANK_MULT[rk] * (1 + (as.matkPct || 0)) * B('matk'),
      pdef: (R.pdef + (as.pdef || 0)) * f * B('pdef'), mdef: (R.mdef + (as.mdef || 0)) * f * B('mdef'),
      speed: 6.2 * R.spd * (1 + (as.spd || 0)) * B('speed'),
      range: wk.range, atkInterval: wk.spd / B('atkspd'), magic: !!(w && WEAPONS[w.kind].magic) || (!w && t === 'm'),
      crit: (w && w.kind === 'adaga' ? 0.15 : 0.08) + (buffs.crit || 0), weaponKind: w ? w.kind : null, armorKind: a ? a.kind : null,
      arch: ARCH[cl.arch], cls: cl,
    };
    s.atk = s.magic ? s.matk : s.patk;
    return s;
  }

  const PROFS = { coleta: 'Coleta', refino: 'Refino', forja: 'Forja' };
  const api = { GRADES, gradeForLevel, MAX_LEVEL, RANK_LVL, RANK_MULT, rankForLevel, xpNeed, mobXp, profLevel, profXpFor, lf, dmgFormula,
    RACES, TYPES, HAIR_COLORS, ARCH, CLASSES, baseClass, nextClasses, ITEMS, RECIPES, RES, WEAPONS, ARMORS, SHOP, npcPrice,
    WORLD, TOWNS, SAFE_R, teleCost, MOBS, expected, mobStats, charStats, PROFS };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.GD = api;
})(typeof window !== 'undefined' ? window : globalThis);
