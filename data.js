// ===== Valtheria: A Árvore dos Mil Mundos — dados do jogo (cliente e gerador de SQL) =====
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
  const RATE_XP = 50, RATE_AURUM = 50, RATE_DROP = 3; // taxas do servidor (x50)
  const mobXp = (L) => Math.round(xpNeed(L) / (8 + 0.5 * L));
  const profLevel = (xp) => Math.floor(Math.sqrt((xp || 0) / 40));
  const profXpFor = (l) => 40 * l * l;
  const lf = (L) => Math.pow(1.05, L - 1);
  const dmgFormula = (atk, mult, def) => atk * mult * atk / (atk + def * 0.5);

  // ----- raças de Valtheria (masculino e feminino) -----
  // look: face 0-3, eyes 0-3, eye_color, hair 0-5, hair_color 0-9, skin, scar 0-3, beard 0-2
  const RACES = {
    humano: { name: 'Humanos', types: ['l', 'm'], hp: { l: 130, m: 95 }, mp: { l: 40, m: 100 }, patk: { l: 12, m: 6 }, matk: { l: 5, m: 13 }, pdef: 8, mdef: 8, spd: 1.0, h: 1.0, w: 1.0,
      skins: ['#f6d2b4', '#e8b993', '#c98e66', '#9a6440', '#6b4128'], eyes: ['#5a3a22', '#3a6a8a', '#4a7a4a', '#7a6a5a', '#2a2a2a', '#8a6a2a'], feat: {}, excl: ['Templário', 'Arcanista'],
      desc: 'Versáteis e ambiciosos, fundaram os grandes reinos de Valtheria.' },
    elfo: { name: 'Elfos Brancos', types: ['l', 'm'], hp: { l: 120, m: 90 }, mp: { l: 45, m: 110 }, patk: { l: 11, m: 6 }, matk: { l: 5, m: 14 }, pdef: 8, mdef: 10, spd: 1.08, h: 1.05, w: 0.9,
      skins: ['#fbe6d4', '#f3d6bd', '#ead0b8', '#d9b99c'], eyes: ['#3a9a6a', '#4a8ac8', '#8ab8d8', '#b89a4a', '#7a5ab8', '#2a6a4a'], feat: { ears: 'long' }, excl: ['Guardião Arqueiro', 'Cantor de Runas'],
      desc: 'Guardiões das florestas antigas, mestres do arco e das runas de luz.' },
    sombrio: { name: 'Elfos Negros', types: ['l', 'm'], hp: { l: 115, m: 85 }, mp: { l: 42, m: 105 }, patk: { l: 14, m: 7 }, matk: { l: 5, m: 15 }, pdef: 7, mdef: 9, spd: 1.04, h: 1.03, w: 0.92,
      skins: ['#a9a6c9', '#8c88b5', '#6e6a9a', '#54507a'], eyes: ['#e83a5a', '#c84ae8', '#f0a03a', '#e8e8f0', '#4ae8c8', '#ff6a2a'], feat: { ears: 'long' }, excl: ['Lâmina das Sombras', 'Feiticeiro do Abismo'],
      desc: 'Exilados das cidades subterrâneas. Dano altíssimo, porém mais frágeis.' },
    orc: { name: 'Orcs e Goblins', types: ['l', 'm'], hp: { l: 155, m: 110 }, mp: { l: 38, m: 95 }, patk: { l: 14, m: 7 }, matk: { l: 4, m: 12 }, pdef: 9, mdef: 8, spd: 0.95, h: 1.12, w: 1.22,
      skins: ['#8aae62', '#6f9450', '#9aa86a', '#5f7a48', '#a08a6a'], eyes: ['#e8c83a', '#c83a2a', '#3a2a1a', '#8ac83a', '#e87a2a', '#6a4a2a'], feat: { tusks: 1, brow: 1 }, excl: ['Berserker de Sangue', 'Xamã Tribal'],
      desc: 'Clãs das estepes rubras. Vida e força brutas, resistência lendária.' },
    anao: { name: 'Anões', types: ['l'], hp: { l: 145 }, mp: { l: 45 }, patk: { l: 13 }, matk: { l: 4 }, pdef: 10, mdef: 9, spd: 0.92, h: 0.78, w: 1.2,
      skins: ['#f3cba5', '#e2b088', '#c99268', '#9a6a48'], eyes: ['#5a3a22', '#3a5a7a', '#6a6a6a', '#2a2a2a', '#7a5a2a', '#3a6a4a'], feat: { beard: 1, headBig: 1.1 }, excl: ['Forjador de Runas', 'Quebra-Escudos'],
      desc: 'Senhores das montanhas, das minas e da forja rúnica.' },
    halfling: { name: 'Halflings', types: ['l', 'm'], hp: { l: 110, m: 85 }, mp: { l: 45, m: 100 }, patk: { l: 12, m: 6 }, matk: { l: 5, m: 13 }, pdef: 8, mdef: 9, spd: 1.06, h: 0.64, w: 0.95,
      skins: ['#f6d2b4', '#ebbd98', '#d2a27a', '#a8784e'], eyes: ['#5a3a22', '#4a7a4a', '#3a6a8a', '#8a6a3a', '#2a2a2a', '#6a8a3a'], feat: { headBig: 1.18, bigFeet: 1, ears: 'small' }, excl: ['Ladino Andarilho', 'Alquimista'],
      desc: 'Pequenos, sortudos e espertos. Mestres da coleta e das poções.' },
    beastman: { name: 'Beastmen', types: ['l', 'm'], hp: { l: 140, m: 100 }, mp: { l: 38, m: 98 }, patk: { l: 14, m: 6 }, matk: { l: 4, m: 13 }, pdef: 9, mdef: 8, spd: 1.07, h: 1.08, w: 1.08,
      skins: ['#a8784a', '#7a5a3a', '#c8a070', '#8a8a8a', '#e8e0d0'], eyes: ['#e8b83a', '#8ac83a', '#e86a2a', '#4ab8e8', '#c83a3a', '#2a2a2a'], feat: { muzzle: 1, animalEars: 1, tail: 'fur' }, excl: ['Caçador Selvagem', 'Druida da Fera'],
      desc: 'Povos-fera das matas profundas: lobos, leões e ursos que andam como homens.' },
    draconato: { name: 'Draconatos', types: ['l', 'm'], hp: { l: 145, m: 105 }, mp: { l: 40, m: 100 }, patk: { l: 13, m: 6 }, matk: { l: 5, m: 14 }, pdef: 10, mdef: 9, spd: 0.98, h: 1.1, w: 1.12,
      skins: ['#b8483a', '#c8943a', '#4a8a5a', '#3a6aa8', '#7a7a8a'], eyes: ['#ffcc33', '#ff7a2a', '#7ae8ff', '#c8ff4a', '#ff4a4a', '#e8e8e8'], feat: { snout: 1, horns: 1, tail: 'scale', noHair: 1 }, excl: ['Lanceiro Dracônico', 'Sacerdote do Sopro'],
      desc: 'Filhos do sangue dos dragões antigos, guerreiros de escamas e fogo.' },
    sylph: { name: 'Sylphs', types: ['l', 'm'], hp: { l: 105, m: 82 }, mp: { l: 50, m: 118 }, patk: { l: 12, m: 6 }, matk: { l: 6, m: 15 }, pdef: 7, mdef: 10, spd: 1.12, h: 0.96, w: 0.86,
      skins: ['#fdeee6', '#f3e2f0', '#e2eef8', '#f0f0dc'], eyes: ['#4ac8e8', '#c88ae8', '#8ae8b8', '#e8a8c8', '#e8e8ff', '#5a8ae8'], feat: { wings: 1, ears: 'small' }, excl: ['Dançarina do Vento', 'Oráculo Estelar'],
      desc: 'Espíritos do vento em forma humana, leves e velozes como a brisa.' },
    nocturno: { name: 'Nocturnos', types: ['l', 'm'], hp: { l: 125, m: 92 }, mp: { l: 44, m: 108 }, patk: { l: 13, m: 7 }, matk: { l: 5, m: 15 }, pdef: 8, mdef: 9, spd: 1.03, h: 1.03, w: 0.95,
      skins: ['#f4ece8', '#e8dcdc', '#dcd4e0', '#cfc6c6'], eyes: ['#d81a2a', '#a81a4a', '#e8a81a', '#8a1ad8', '#ff4a4a', '#c8c8d8'], feat: { fangs: 1, ears: 'small' }, excl: ['Cavaleiro de Sangue', 'Ilusionista'],
      desc: 'A nobreza vampírica da Noite Eterna. Elegantes, letais e amaldiçoados.' },
    gigante: { name: 'Gigantes de Gelo', types: ['l', 'm'], hp: { l: 175, m: 120 }, mp: { l: 36, m: 92 }, patk: { l: 15, m: 6 }, matk: { l: 4, m: 13 }, pdef: 11, mdef: 9, spd: 0.9, h: 1.42, w: 1.38,
      skins: ['#c8dcec', '#a8c4dc', '#8aaccc', '#dce8f0'], eyes: ['#7ad8ff', '#e8f8ff', '#3a8ac8', '#8ae8e8', '#c8c8ff', '#4a6a8a'], feat: { beard: 1, frost: 1 }, excl: ['Guardião Glacial', 'Runista do Inverno'],
      desc: 'Colossos dos picos congelados do norte. Resistência e força sem igual.' },
  };
  const TYPES = { l: 'Lutador', m: 'Místico' };
  const HAIR_COLORS = ['#2b1d14', '#6b4423', '#c89b4a', '#efe0b8', '#b33a2a', '#1f3b73', '#e8e8ee', '#2d6b3a', '#d86aa8', '#7a4ac8'];
  const HAIR_STYLES = ['Curto', 'Espetado', 'Longo', 'Rabo de cavalo', 'Tranças', 'Coque'];
  const FACES = ['Oval', 'Redondo', 'Angular', 'Fino'];
  const EYE_SHAPES = ['Amendoado', 'Redondo', 'Felino', 'Sereno'];
  const SCARS = ['Nenhuma', 'Bochecha', 'Olho', 'Nariz'];
  const BEARDS = ['Sem barba', 'Curta', 'Longa'];
  const EXPRESSIONS = { neutral: 'Neutro', smile: 'Sorriso', sad: 'Tristeza', angry: 'Raiva', hurt: 'Dor' };
  // ----- arquétipos e habilidades -----
  // tipos: hit, buff, heal, dash, leap, taunt, mana
  const S = (lvl, name, icon, o) => ({ lvl, name, icon, mp: 10, cd: 6, ...o });
  const ARCH = {
    tanque: { name: 'Tanque', weapon: 'espada', shield: true, armor: 'pesada', atk: 'p', skills: [
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

  // ----- buffs (melhoram atributos) e debuffs (enfraquecem o alvo) por estilo de classe -----
  // debuff: deb = { atk: -0.25 (ataque do alvo), def: -0.3 (defesa do alvo), speed: -0.5 }
  const EXTRA = {
    tanque: [S(8, 'Grito Intimidador', '😤', { type: 'debuff', deb: { atk: -0.25 }, dur: 12, aoe: 8, self: true, mp: 12, cd: 20, fx: 'dark' }), S(28, 'Juramento Sagrado', '⚜️', { type: 'buff', buff: { mdef: 0.4, hot: 0.02 }, dur: 25, mp: 18, cd: 45, fx: 'holy' }), S(44, 'Correntes da Justiça', '⛓️', { type: 'debuff', deb: { speed: -0.5, def: -0.15 }, dur: 10, mp: 14, cd: 16, fx: 'holy' })],
    guerreiro: [S(8, 'Brado de Batalha', '📯', { type: 'buff', buff: { patk: 0.2, crit: 0.1 }, dur: 25, mp: 14, cd: 45, fx: 'fire' }), S(28, 'Quebra-Armadura', '💢', { type: 'debuff', deb: { def: -0.3 }, dur: 12, mp: 12, cd: 14, fx: 'dark', hitMult: 1.2 }), S(44, 'Pele de Aço', '🛡️', { type: 'buff', buff: { pdef: 0.45 }, dur: 15, mp: 16, cd: 40 })],
    arqueiro: [S(8, 'Flecha Paralisante', '🕸️', { type: 'debuff', deb: { speed: -0.6 }, dur: 6, mp: 10, cd: 12, fx: 'ice', hitMult: 1.1 }), S(28, 'Vento Veloz', '🍃', { type: 'buff', buff: { speed: 0.35, atkspd: 0.2 }, dur: 20, mp: 14, cd: 45, fx: 'wind' }), S(44, 'Marca do Caçador', '🎯', { type: 'debuff', deb: { def: -0.25 }, dur: 15, mp: 14, cd: 20, fx: 'dark' })],
    adaga: [S(8, 'Corte Sangrento', '🩸', { type: 'hit', mult: 1.1, dot: { mult: 1.8, dur: 8 }, mp: 10, cd: 9, fx: 'blood' }), S(28, 'Lâmina Enfraquecedora', '🥀', { type: 'debuff', deb: { atk: -0.3 }, dur: 12, mp: 12, cd: 18, fx: 'dark', hitMult: 1.0 }), S(44, 'Instinto Assassino', '👁️', { type: 'buff', buff: { crit: 0.3, patk: 0.15 }, dur: 15, mp: 18, cd: 50, fx: 'dark' })],
    mago: [S(8, 'Aura Arcana', '🌀', { type: 'buff', buff: { matk: 0.25 }, dur: 30, mp: 16, cd: 50, fx: 'arcane' }), S(28, 'Maldição da Fraqueza', '☠️', { type: 'debuff', deb: { def: -0.3, atk: -0.15 }, dur: 15, mp: 18, cd: 20, fx: 'dark' }), S(44, 'Prisão de Gelo', '🧊', { type: 'debuff', deb: { speed: -0.85 }, stun: 2, dur: 5, mp: 20, cd: 22, fx: 'ice' })],
    curandeiro: [S(8, 'Escudo Sagrado', '🔆', { type: 'buff', buff: { pdef: 0.3, mdef: 0.3 }, dur: 30, mp: 16, cd: 50, fx: 'holy' }), S(28, 'Purificação', '🕊️', { type: 'heal', pct: 0.25, cleanse: true, mp: 18, cd: 15, fx: 'holy' }), S(44, 'Silêncio Divino', '🤐', { type: 'debuff', deb: { atk: -0.35 }, dur: 10, mp: 16, cd: 22, fx: 'holy' })],
    xama: [S(8, 'Espírito do Lobo', '🐺', { type: 'buff', buff: { speed: 0.3, patk: 0.15, matk: 0.15 }, dur: 30, mp: 16, cd: 50, fx: 'spirit' }), S(28, 'Praga', '🦠', { type: 'debuff', deb: { def: -0.25 }, dot: { mult: 1.6, dur: 10 }, aoe: 5, dur: 12, mp: 22, cd: 18, fx: 'poison' }), S(44, 'Totem da Vida', '🌳', { type: 'buff', buff: { hot: 0.04 }, dur: 20, mp: 20, cd: 45, fx: 'nature' })],
    monge: [S(8, 'Postura do Tigre', '🐯', { type: 'buff', buff: { atkspd: 0.3, patk: 0.1 }, dur: 25, mp: 12, cd: 45, fx: 'fire' }), S(28, 'Golpe Atordoante', '💫', { type: 'hit', mult: 1.5, stun: 2, mp: 14, cd: 14 }), S(44, 'Pontos Vitais', '🎯', { type: 'debuff', deb: { def: -0.35 }, dur: 12, mp: 14, cd: 20, fx: 'dark', hitMult: 1.0 })],
    artesao: [S(8, 'Runa de Proteção', '🔷', { type: 'buff', buff: { pdef: 0.35, mdef: 0.15 }, dur: 30, mp: 14, cd: 50, fx: 'arcane' }), S(28, 'Martelo Sísmico', '🌋', { type: 'hit', mult: 1.4, aoe: 5, self: true, slow: 0.4, mp: 16, cd: 12, fx: 'earth' }), S(44, 'Runa da Ruína', '♨️', { type: 'debuff', deb: { def: -0.3, atk: -0.15 }, dur: 14, mp: 16, cd: 22, fx: 'dark' })],
  };
  for (const [k, list] of Object.entries(EXTRA)) { ARCH[k].skills.push(...list); ARCH[k].skills.sort((a, b) => a.lvl - b.lvl); ARCH[k].skills.forEach((sk, i) => sk.id = k + ':' + sk.name); }

  // ----- árvore de classes: base (nv 1) → 2ª (nv 20) → 3ª (nv 40) → 4ª (nv 76) -----
  const CLASSES = {};
  const C = (id, name, race, type, rank, parent, arch, bonus, excl) => { CLASSES[id] = { id, name, race, type, rank, parent, arch, bonus: bonus || null, excl: !!excl }; };
  const line = (race, type, parent, arch, names, prefix, bonus, excl) => {
    let p = parent; names.forEach((n, i) => { const id = prefix + '_' + (i + 1); C(id, n, race, type, i + 1, p, arch, bonus, excl); p = id; });
  };
  // Humanos — exclusivas: Templário, Arcanista
  C('hum_l', 'Escudeiro', 'humano', 'l', 0, null, 'guerreiro');
  line('humano', 'l', 'hum_l', 'tanque', ['Templário', 'Paladino da Aurora', 'Grão-Templário'], 'hum_tq', null, true);
  line('humano', 'l', 'hum_l', 'guerreiro', ['Combatente', 'Mestre de Armas', 'Senhor da Guerra'], 'hum_gr');
  line('humano', 'l', 'hum_l', 'arqueiro', ['Batedor', 'Caçador', 'Atirador Celeste'], 'hum_aq');
  C('hum_m', 'Aprendiz Arcano', 'humano', 'm', 0, null, 'mago');
  line('humano', 'm', 'hum_m', 'mago', ['Arcanista', 'Arquimago', 'Sábio Arcano'], 'hum_mg', null, true);
  line('humano', 'm', 'hum_m', 'curandeiro', ['Clérigo', 'Bispo', 'Santo Curador'], 'hum_cu');
  // Elfos Brancos — Guardião Arqueiro, Cantor de Runas
  C('elf_l', 'Sentinela Élfico', 'elfo', 'l', 0, null, 'guerreiro');
  line('elfo', 'l', 'elf_l', 'arqueiro', ['Guardião Arqueiro', 'Patrulheiro Lunar', 'Flecha de Prata'], 'elf_aq', null, true);
  line('elfo', 'l', 'elf_l', 'tanque', ['Cavaleiro Élfico', 'Templário da Floresta', 'Guardião Ancestral'], 'elf_tq');
  line('elfo', 'l', 'elf_l', 'adaga', ['Andarilho', 'Lâmina do Vento', 'Espectro da Brisa'], 'elf_ad');
  C('elf_m', 'Místico Élfico', 'elfo', 'm', 0, null, 'mago');
  line('elfo', 'm', 'elf_m', 'curandeiro', ['Cantor de Runas', 'Bardo Rúnico', 'Voz das Runas'], 'elf_cu', null, true);
  line('elfo', 'm', 'elf_m', 'mago', ['Feiticeiro Élfico', 'Mago das Águas', 'Mestre das Marés'], 'elf_mg');
  // Elfos Negros — Lâmina das Sombras, Feiticeiro do Abismo
  C('de_l', 'Guerreiro Sombrio', 'sombrio', 'l', 0, null, 'guerreiro');
  line('sombrio', 'l', 'de_l', 'adaga', ['Lâmina das Sombras', 'Assassino da Noite', 'Fantasma do Abismo'], 'de_ad', null, true);
  line('sombrio', 'l', 'de_l', 'tanque', ['Cavaleiro Sombrio', 'Vingador', 'Guardião da Sombra'], 'de_tq');
  line('sombrio', 'l', 'de_l', 'arqueiro', ['Atirador Sombrio', 'Predador', 'Caçador do Vazio'], 'de_aq');
  C('de_m', 'Místico Sombrio', 'sombrio', 'm', 0, null, 'mago');
  line('sombrio', 'm', 'de_m', 'mago', ['Feiticeiro do Abismo', 'Necromante', 'Arauto do Vazio'], 'de_mg', null, true);
  line('sombrio', 'm', 'de_m', 'xama', ['Xamã Sombrio', 'Profeta Sombrio', 'Oráculo do Vazio'], 'de_xa');
  // Orcs e Goblins — Berserker de Sangue, Xamã Tribal
  C('orc_l', 'Guerreiro Orc', 'orc', 'l', 0, null, 'guerreiro');
  line('orc', 'l', 'orc_l', 'guerreiro', ['Berserker de Sangue', 'Destruidor', 'Titã Rubro'], 'orc_gr', null, true);
  line('orc', 'l', 'orc_l', 'monge', ['Monge', 'Punho de Ferro', 'Mestre do Punho'], 'orc_mo');
  C('orc_m', 'Místico Orc', 'orc', 'm', 0, null, 'xama');
  line('orc', 'm', 'orc_m', 'xama', ['Xamã Tribal', 'Senhor Tribal', 'Ancião Tribal'], 'orc_xa', null, true);
  line('orc', 'm', 'orc_m', 'curandeiro', ['Invocador Tribal', 'Bramido Sagrado', 'Voz dos Ancestrais'], 'orc_cu');
  // Anões — Quebra-Escudos, Forjador de Runas
  C('dw_l', 'Guerreiro Anão', 'anao', 'l', 0, null, 'artesao');
  line('anao', 'l', 'dw_l', 'guerreiro', ['Quebra-Escudos', 'Martelo de Guerra', 'Senhor da Montanha'], 'dw_qe', null, true);
  line('anao', 'l', 'dw_l', 'artesao', ['Forjador de Runas', 'Mestre Rúnico', 'Grão-Forjador'], 'dw_fo', 'forja', true);
  line('anao', 'l', 'dw_l', 'artesao', ['Coletor', 'Prospector', 'Mestre Minerador'], 'dw_co', 'coleta');
  // Halflings — Ladino Andarilho, Alquimista
  C('hal_l', 'Andarilho das Colinas', 'halfling', 'l', 0, null, 'adaga');
  line('halfling', 'l', 'hal_l', 'adaga', ['Ladino Andarilho', 'Mão Leve', 'Sombra das Colinas'], 'hal_ld', 'coleta', true);
  line('halfling', 'l', 'hal_l', 'arqueiro', ['Atirador de Funda', 'Caçador das Colinas', 'Olho de Falcão'], 'hal_aq');
  C('hal_m', 'Aprendiz de Ervas', 'halfling', 'm', 0, null, 'curandeiro');
  line('halfling', 'm', 'hal_m', 'curandeiro', ['Alquimista', 'Mestre das Poções', 'Grão-Alquimista'], 'hal_al', null, true);
  line('halfling', 'm', 'hal_m', 'mago', ['Ilusionista das Colinas', 'Mago do Lar', 'Arquimago Pequeno'], 'hal_mg');
  // Beastmen — Caçador Selvagem, Druida da Fera
  C('bst_l', 'Instinto Selvagem', 'beastman', 'l', 0, null, 'monge');
  line('beastman', 'l', 'bst_l', 'monge', ['Caçador Selvagem', 'Garra Alfa', 'Rei da Matilha'], 'bst_cs', null, true);
  line('beastman', 'l', 'bst_l', 'tanque', ['Pele de Ferro', 'Guardião da Matilha', 'Colosso Selvagem'], 'bst_tq');
  C('bst_m', 'Vidente da Tribo', 'beastman', 'm', 0, null, 'xama');
  line('beastman', 'm', 'bst_m', 'xama', ['Druida da Fera', 'Espírito Uivante', 'Arquidruida'], 'bst_dr', null, true);
  line('beastman', 'm', 'bst_m', 'curandeiro', ['Curandeiro Tribal', 'Guardião dos Ritos', 'Voz da Lua'], 'bst_cu');
  // Draconatos — Lanceiro Dracônico, Sacerdote do Sopro
  C('drc_l', 'Cria do Dragão', 'draconato', 'l', 0, null, 'guerreiro');
  line('draconato', 'l', 'drc_l', 'guerreiro', ['Lanceiro Dracônico', 'Cavaleiro Escamado', 'Dragão Lanceiro'], 'drc_ln', null, true);
  line('draconato', 'l', 'drc_l', 'tanque', ['Escama de Ferro', 'Baluarte Dracônico', 'Muralha Ancestral'], 'drc_tq');
  C('drc_m', 'Acólito da Chama', 'draconato', 'm', 0, null, 'xama');
  line('draconato', 'm', 'drc_m', 'xama', ['Sacerdote do Sopro', 'Arauto das Chamas', 'Sopro Primordial'], 'drc_sp', null, true);
  line('draconato', 'm', 'drc_m', 'mago', ['Piromante', 'Mago do Magma', 'Senhor do Inferno'], 'drc_mg');
  // Sylphs — Dançarina do Vento, Oráculo Estelar
  C('syl_l', 'Brisa Errante', 'sylph', 'l', 0, null, 'adaga');
  line('sylph', 'l', 'syl_l', 'adaga', ['Dançarina do Vento', 'Lâmina da Brisa', 'Tempestade Viva'], 'syl_dv', null, true);
  line('sylph', 'l', 'syl_l', 'arqueiro', ['Flecha Alada', 'Caçadora Celeste', 'Asa de Prata'], 'syl_aq');
  C('syl_m', 'Sopro Místico', 'sylph', 'm', 0, null, 'mago');
  line('sylph', 'm', 'syl_m', 'mago', ['Oráculo Estelar', 'Vidente Astral', 'Voz das Estrelas'], 'syl_or', null, true);
  line('sylph', 'm', 'syl_m', 'curandeiro', ['Curandeira do Vento', 'Sopro Vital', 'Aurora Viva'], 'syl_cu');
  // Nocturnos — Cavaleiro de Sangue, Ilusionista
  C('noc_l', 'Cria da Noite', 'nocturno', 'l', 0, null, 'guerreiro');
  line('nocturno', 'l', 'noc_l', 'tanque', ['Cavaleiro de Sangue', 'Lorde Carmesim', 'Senhor da Noite Eterna'], 'noc_cs', null, true);
  line('nocturno', 'l', 'noc_l', 'adaga', ['Caçador Noturno', 'Presa Silenciosa', 'Sombra Carmesim'], 'noc_ad');
  C('noc_m', 'Herdeiro do Véu', 'nocturno', 'm', 0, null, 'mago');
  line('nocturno', 'm', 'noc_m', 'mago', ['Ilusionista', 'Mestre dos Véus', 'Arquiteto de Pesadelos'], 'noc_il', null, true);
  line('nocturno', 'm', 'noc_m', 'xama', ['Sangromante', 'Senhor das Veias', 'Coração Sombrio'], 'noc_xa');
  // Gigantes de Gelo — Guardião Glacial, Runista do Inverno
  C('gig_l', 'Filho do Gelo', 'gigante', 'l', 0, null, 'guerreiro');
  line('gigante', 'l', 'gig_l', 'tanque', ['Guardião Glacial', 'Muralha de Gelo', 'Colosso do Inverno'], 'gig_gg', null, true);
  line('gigante', 'l', 'gig_l', 'guerreiro', ['Quebra-Geleiras', 'Avalanche', 'Fúria do Norte'], 'gig_gr');
  C('gig_m', 'Vidente do Gelo', 'gigante', 'm', 0, null, 'xama');
  line('gigante', 'm', 'gig_m', 'xama', ['Runista do Inverno', 'Senhor da Nevasca', 'Arauto do Gelo Eterno'], 'gig_rn', null, true);
  line('gigante', 'm', 'gig_m', 'curandeiro', ['Guardião da Aurora Boreal', 'Luz do Norte', 'Coração Glacial'], 'gig_cu');
  const baseClass = (race, type) => Object.values(CLASSES).find(c => c.race === race && c.type === type && c.rank === 0);
  const nextClasses = (cid) => Object.values(CLASSES).filter(c => c.parent === cid);

  // ----- itens -----
  const ITEMS = {}, RECIPES = {};
  const g = (i) => GRADES[i].id.toLowerCase();
  const RES = { madeira: ['Madeira', 'tabua', 'Tábua', '🪵', '🟫'], minerio: ['Minério', 'barra', 'Barra', '🪨', '🧱'], fibra: ['Fibra', 'tecido', 'Tecido', '🌿', '🧵'], pele: ['Pele', 'couro', 'Couro', '🐾', '🟤'] };
  const WEAPONS = {
    espada: { name: 'Espada', icon: '🗡️', range: 2.6, spd: 1.0, inputs: { barra: 6, couro: 2 } },
    lanca: { name: 'Lança', icon: '🔱', range: 3.4, spd: 1.15, inputs: { barra: 5, tabua: 4 } },
    machado: { name: 'Machado de Guerra', icon: '🪓', range: 2.8, spd: 1.2, inputs: { barra: 8, tabua: 2 } },
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
  // peças extras de equipamento (slot, nome por tipo de armadura, fração dos atributos)
  const PARTS = {
    elmo: { slot: 'elmo', names: { pesada: 'Elmo', leve: 'Capuz', robe: 'Chapéu Arcano' }, icon: '⛑️', f: 0.25, inputs: { pesada: { barra: 4 }, leve: { couro: 4 }, robe: { tecido: 4 } } },
    luvas: { slot: 'luvas', names: { pesada: 'Manoplas', leve: 'Luvas de Couro', robe: 'Luvas de Seda' }, icon: '🧤', f: 0.15, inputs: { pesada: { barra: 3 }, leve: { couro: 3 }, robe: { tecido: 3 } } },
    botas: { slot: 'botas', names: { pesada: 'Grevas', leve: 'Botas de Couro', robe: 'Sandálias Arcanas' }, icon: '🥾', f: 0.15, inputs: { pesada: { barra: 3 }, leve: { couro: 3 }, robe: { tecido: 3 } } },
  };
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
    for (const [p, P] of Object.entries(PARTS)) for (const k of Object.keys(ARMORS)) {
      const id = `${p}_${k}_${g(i)}`, gp = G.gp, f = P.f;
      const st = k === 'pesada' ? { pdef: 10 * gp * f, mdef: 3 * gp * f, hp: 20 * gp * f } : k === 'leve' ? { pdef: 7 * gp * f, mdef: 4 * gp * f } : { pdef: 4 * gp * f, mdef: 8 * gp * f, mp: 25 * gp * f };
      if (p === 'luvas') { if (k === 'robe') st.matk = 1.5 * gp; else st.patk = 1.2 * gp; }
      if (p === 'botas') st.spd = k === 'leve' ? 0.04 : 0.02;
      for (const x in st) st[x] = Math.round(st[x] * 10) / 10;
      ITEMS[id] = { id, name: `${P.names[k]} ${GRADE_NAMES[i]}`, grade: i, type: 'armor', slot: P.slot, kind: k, part: p, icon: P.icon, stats: st };
      const inp = {}; for (const [m, q] of Object.entries(P.inputs[k])) inp[`${m}_${g(i)}`] = q; if (i >= 3) inp.gema = 1;
      RECIPES[id] = { id, out: id, qty: 1, station: 'forja', prof: 'forja', grade: i, inputs: inp, xp: 12 * (i + 1) };
    }
    { const id = `escudo_${g(i)}`; ITEMS[id] = { id, name: `Escudo ${GRADE_NAMES[i]}`, grade: i, type: 'armor', slot: 'escudo', kind: 'escudo', icon: '🛡️', stats: { pdef: Math.round(6 * G.gp * 10) / 10, mdef: Math.round(2 * G.gp * 10) / 10, hp: Math.round(10 * G.gp) } };
      const inp = { [`barra_${g(i)}`]: 5, [`tabua_${g(i)}`]: 2 }; if (i >= 3) inp.gema = 1; RECIPES[id] = { id, out: id, qty: 1, station: 'forja', prof: 'forja', grade: i, inputs: inp, xp: 16 * (i + 1) }; }
    const kid = `kit_${g(i)}`;
    ITEMS[kid] = { id: kid, name: `Kit de Coleta ${G.id}`, grade: i, type: 'tool', icon: '⛏️' };
    RECIPES[kid] = { id: kid, out: kid, qty: 1, station: 'forja', prof: 'forja', grade: i, inputs: { [`tabua_${g(i)}`]: 3, [`barra_${g(i)}`]: 3 }, xp: 15 * (i + 1) };
  });
  // itens únicos (só caem de chefes especiais) — Grau R (Relíquia)
  const R_ = (id, name, base, slot, kind, stats, icon) => { ITEMS[id] = { id, name, grade: base, type: slot === 'arma' ? 'weapon' : 'armor', slot, kind, icon, stats, unique: true, relic: true }; };
  R_('arco_corvo', 'Arco do Rei Corvo', 1, 'arma', 'arco', { patk: 26, crit: 0.05 }, '🏹');
  R_('escudo_ruinas', 'Escudo das Ruínas Antigas', 1, 'escudo', 'escudo', { pdef: 22, mdef: 10, hp: 60 }, '🛡️');
  R_('machado_grak', 'Machado de Grak', 2, 'arma', 'machado', { patk: 44 }, '🪓');
  R_('cajado_lich', 'Cajado do Rei Lich', 3, 'arma', 'cajado', { matk: 66 }, '🪄');
  R_('adaga_lua', 'Adagas da Lua Partida', 3, 'arma', 'adaga', { patk: 60, crit: 0.08 }, '🗡️');
  R_('lanca_hidra', 'Lança da Hidra', 4, 'arma', 'lanca', { patk: 80 }, '🔱');
  R_('espada_carmesim', 'Espada Carmesim do Conde', 5, 'arma', 'espada', { patk: 104, lifesteal: 0.05 }, '⚔️');
  R_('elmo_inverno', 'Coroa do Inverno', 5, 'elmo', 'pesada', { pdef: 40, mdef: 30, hp: 120 }, '👑');
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
  Object.keys(PARTS).forEach(p => Object.keys(ARMORS).forEach(k => SHOP[`${p}_${k}_ng`] = 120)); SHOP.escudo_ng = 200;
  const npcPrice = (it) => Math.round(({ raw: 3, refined: 9, tool: 40, potion: 6, scroll: 20, special: 400 }[it.type] || 120) * Math.pow(2.2, it.grade));

  // ----- cidades, regiões e teleporte -----
  const WORLD = { SIZE: 3000, SEED: 20261110 };
  // band = faixa de nível/região (0..5). As 6 primeiras são as capitais das faixas; as demais são cidades de raça.
  const TOWNS = [
    { id: 'aurora', name: 'Vila Aurora', race: 'humano', x: 1500, z: 2550, min: 1, max: 19, theme: 'verde', spots: [['Campos do Amanhecer', 200], ['Bosque dos Javalis', 330]] },
    { id: 'dourado', name: 'Vale Dourado', race: 'halfling', x: 650, z: 2050, min: 20, max: 39, theme: 'outono', spots: [['Planície dos Bandidos', 120], ['Ninho das Aranhas', 250]] },
    { id: 'pedra', name: 'Pedra Alta', race: 'anao', x: 2350, z: 1950, min: 40, max: 51, theme: 'rocha', spots: [['Pedreira dos Golens', 60], ['Cripta Esquecida', 300]] },
    { id: 'sylvar', name: 'Sylvar', race: 'elfo', x: 1500, z: 1450, min: 52, max: 60, theme: 'floresta', spots: [['Coração da Mata', 20], ['Vale Espectral', 160]] },
    { id: 'rubra', name: 'Cidadela Rubra', race: 'orc', x: 650, z: 800, min: 61, max: 75, theme: 'rubro', spots: [['Deserto Escarlate', 140], ['Fenda Demoníaca', 280]] },
    { id: 'celeste', name: 'Bastião Celeste', race: 'sylph', x: 2350, z: 650, min: 76, max: 80, theme: 'cinza', spots: [['Ninho dos Dragões', 100], ['Ruínas de Aeternum', 230]] },
    { id: 'presas', name: 'Clã das Presas', race: 'beastman', x: 1000, z: 1500, band: 1, min: 20, max: 39, theme: 'savana', spots: [] },
    { id: 'umbraval', name: 'Umbraval', race: 'sombrio', x: 2150, z: 1300, band: 3, min: 52, max: 60, theme: 'sombra', spots: [] },
    { id: 'pico', name: 'Pico do Dragão', race: 'draconato', x: 1450, z: 420, band: 4, min: 61, max: 75, theme: 'vulcao', spots: [] },
    { id: 'noctis', name: 'Castelo Noctis', race: 'nocturno', x: 2720, z: 1150, band: 5, min: 76, max: 80, theme: 'noite', spots: [] },
    { id: 'glacial', name: 'Fortaleza Glacial', race: 'gigante', x: 330, z: 330, band: 5, min: 76, max: 80, theme: 'gelo', spots: [] },
  ];
  TOWNS.forEach((t, i) => { t.index = i; if (t.band == null) t.band = i; t.spotsPos = t.spots.map(([n, ang]) => ({ name: n, x: t.x + Math.cos(ang * Math.PI / 180) * 270, z: t.z + Math.sin(ang * Math.PI / 180) * 270, lvl: Math.round((t.min + t.max) / 2) })); });
  const CORE_TOWNS = TOWNS.slice(0, 6);
  // locais especiais: castelos, ruínas e covis com chefes e drops exclusivos
  const LANDMARKS = [
    { id: 'castelo_corvos', name: 'Castelo dos Corvos', type: 'castelo', x: 1180, z: 2250, lvl: 18, boss: 'rei_corvo' },
    { id: 'ruinas_velhas', name: 'Ruínas de Vel\'Anor', type: 'ruina', x: 1880, z: 2330, lvl: 15, boss: 'guardiao_ruinas' },
    { id: 'forte_bandido', name: 'Forte dos Saqueadores', type: 'castelo', x: 420, z: 1750, lvl: 35, boss: 'chefe_saqueador' },
    { id: 'cripta_reis', name: 'Cripta dos Reis', type: 'ruina', x: 2620, z: 2250, lvl: 50, boss: 'rei_lich' },
    { id: 'templo_lua', name: 'Templo da Lua Partida', type: 'ruina', x: 1800, z: 1180, lvl: 59, boss: 'sacerdotisa_lua' },
    { id: 'covil_hidra', name: 'Pântano da Hidra', type: 'covil', x: 950, z: 1150, lvl: 70, boss: 'hidra' },
    { id: 'castelo_sangue', name: 'Castelo do Sangue Eterno', type: 'castelo', x: 2650, z: 820, lvl: 80, boss: 'conde_carmesim' },
    { id: 'trono_gelo', name: 'Trono do Inverno', type: 'covil', x: 520, z: 520, lvl: 80, boss: 'wyrm_gelo' },
  ];
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
  // chefes especiais dos locais (drops exclusivos)
  const SPECIAL_BOSSES = [
    { id: 'rei_corvo', name: 'Rei Corvo', model: 'humanoid', color: '#2a2a3a', scale: 2.0, boss: true, special: true, horns: false, drops: ['arco_corvo', 'gema'] },
    { id: 'guardiao_ruinas', name: 'Guardião das Ruínas', model: 'golem', color: '#6a7a6a', scale: 2.4, boss: true, special: true, drops: ['escudo_ruinas', 'gema'] },
    { id: 'chefe_saqueador', name: 'Grak, o Saqueador', model: 'humanoid', color: '#5f8a3a', scale: 2.1, boss: true, special: true, drops: ['machado_grak', 'gema'] },
    { id: 'rei_lich', name: 'Rei Lich Morthas', model: 'humanoid', color: '#d8d2c0', scale: 2.3, boss: true, special: true, drops: ['cajado_lich', 'gema', 'fragmento'] },
    { id: 'sacerdotisa_lua', name: 'Sacerdotisa da Lua Partida', model: 'humanoid', color: '#8a8ac8', scale: 2.0, boss: true, special: true, drops: ['adaga_lua', 'gema', 'fragmento'] },
    { id: 'hidra', name: 'Hidra do Pântano', model: 'dragon', color: '#3a7a4a', scale: 2.8, boss: true, special: true, drops: ['lanca_hidra', 'fragmento'] },
    { id: 'conde_carmesim', name: 'Conde Carmesim', model: 'humanoid', color: '#6a0a1a', scale: 2.4, boss: true, special: true, horns: true, drops: ['espada_carmesim', 'fragmento'] },
    { id: 'wyrm_gelo', name: 'Wyrm do Inverno', model: 'dragon', color: '#9ad0f0', scale: 3.0, boss: true, special: true, drops: ['elmo_inverno', 'fragmento'] },
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
    const ws = w ? w.stats : {}, as = {};
    for (const [slot, id] of Object.entries(eq)) { if (slot === 'arma' || !ITEMS[id]) continue; for (const [k, v] of Object.entries(ITEMS[id].stats || {})) as[k] = (as[k] || 0) + v; }
    const wk = w ? WEAPONS[w.kind] : { range: 2.2, spd: 0.9 };
    const B = (k) => 1 + (buffs[k] || 0);
    const s = {
      maxHp: Math.round((R.hp[t] * f * (1 + 0.03 * rk) + (as.hp || 0)) ),
      maxMp: Math.round(R.mp[t] * f * (1 + 0.02 * rk) + (as.mp || 0)),
      patk: (R.patk[t] + (ws.patk || 0) + (as.patk || 0)) * f * RANK_MULT[rk] * B('patk'),
      matk: (R.matk[t] + (ws.matk || 0) + (as.matk || 0)) * f * RANK_MULT[rk] * (1 + (as.matkPct || 0)) * B('matk'),
      pdef: (R.pdef + (as.pdef || 0)) * f * B('pdef'), mdef: (R.mdef + (as.mdef || 0)) * f * B('mdef'),
      speed: 6.2 * R.spd * (1 + (as.spd || 0)) * B('speed'),
      range: wk.range, atkInterval: wk.spd / B('atkspd'), magic: !!(w && WEAPONS[w.kind].magic) || (!w && t === 'm'),
      crit: (w && w.kind === 'adaga' ? 0.15 : 0.08) + (ws.crit || 0) + (buffs.crit || 0), weaponKind: w ? w.kind : null, armorKind: a ? a.kind : null,
      arch: ARCH[cl.arch], cls: cl,
    };
    s.atk = s.magic ? s.matk : s.patk;
    return s;
  }

  const PROFS = { coleta: 'Coleta', refino: 'Refino', forja: 'Forja' };
  const api = { GRADES, gradeForLevel, MAX_LEVEL, RANK_LVL, RANK_MULT, rankForLevel, xpNeed, mobXp, profLevel, profXpFor, lf, dmgFormula,
    RACES, TYPES, HAIR_COLORS, HAIR_STYLES, FACES, EYE_SHAPES, SCARS, BEARDS, EXPRESSIONS, ARCH, CLASSES, baseClass, nextClasses, ITEMS, RECIPES, RES, WEAPONS, ARMORS, SHOP, npcPrice,
    WORLD, TOWNS, CORE_TOWNS, LANDMARKS, SPECIAL_BOSSES, PARTS, RATE_XP, RATE_AURUM, RATE_DROP, SAFE_R, teleCost, MOBS, expected, mobStats, charStats, PROFS };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.GD = api;
})(typeof window !== 'undefined' ? window : globalThis);
