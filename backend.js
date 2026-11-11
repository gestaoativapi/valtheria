// ===== Servidor: Supabase (online) ou local (teste offline) =====
const EMAIL_DOMAIN = '@jogadores.reinosdeaurora.app';

class RemoteBackend {
  constructor(url, key) { this.online = true; this.sb = supabase.createClient(url, key, { realtime: { params: { eventsPerSecond: 15 } } }); this.cid = null; }
  async session() { const { data } = await this.sb.auth.getSession(); return data.session; }
  async login(u, p) { const { error } = await this.sb.auth.signInWithPassword({ email: u.trim().toLowerCase() + EMAIL_DOMAIN, password: p }); if (error) throw new Error(/Invalid login/i.test(error.message) ? 'Usuário ou senha incorretos' : error.message); }
  async signup(u, p) {
    const { error } = await this.sb.functions.invoke('signup', { body: { username: u, password: p } });
    if (error) { let m = 'Não foi possível criar a conta'; try { const j = await error.context.json(); if (j.error) m = j.error; } catch (_) {} throw new Error(m); }
    await this.login(u, p);
  }
  async logout() { await this.leave(); await this.sb.auth.signOut(); }
  async rpc(fn, a) { const { data, error } = await this.sb.rpc(fn, a || {}); if (error) throw new Error(/JWT/i.test(error.message) ? 'Sessão expirada, entre novamente' : error.message); return data; }
  chars() { return this.rpc('game_chars'); }
  createChar(o) { return this.rpc('game_create_char2', { p_name: o.name, p_race: o.race, p_type: o.type, p_gender: o.gender, p_look: o.look || {} }); }
  deleteChar(id) { return this.rpc('game_delete_char', { p_char: id }); }
  use(id) { this.cid = id; }
  c(o) { return { p_char: this.cid, ...o }; }
  state() { return this.rpc('game_state', this.c()); }
  save(x, z, hp, mp) { return this.rpc('game_save', this.c({ p_x: x, p_z: z, p_hp: hp, p_mp: mp })); }
  gather(n, x, z) { return this.rpc('game_gather', this.c({ p_node: n, p_x: x, p_z: z })); }
  craft(r, t) { return this.rpc('game_craft', this.c({ p_recipe: r, p_times: t })); }
  equip(i) { return this.rpc('game_equip', this.c({ p_item: i })); }
  unequip(s) { return this.rpc('game_unequip', this.c({ p_slot: s })); }
  useItem(i) { return this.rpc('game_use', this.c({ p_item: i })); }
  kill(l, boss, fam) { return this.rpc('game_kill2', this.c({ p_mob_level: l, p_boss: !!boss, p_fam: fam || '' })); }
  die(pvp) { return this.rpc('game_die', this.c({ p_pvp: !!pvp })); }
  classChange(k) { return this.rpc('game_class_change', this.c({ p_class: k })); }
  teleport(d) { return this.rpc('game_teleport', this.c({ p_dest: d })); }
  shopBuy(i, q) { return this.rpc('game_shop_buy', this.c({ p_item: i, p_qty: q })); }
  npcSell(i, q) { return this.rpc('game_npc_sell', this.c({ p_item: i, p_qty: q })); }
  marketList() { return this.rpc('game_market_list'); }
  marketSell(i, q, p) { return this.rpc('game_market_sell', this.c({ p_item: i, p_qty: q, p_price: p })); }
  marketBuy(o, q) { return this.rpc('game_market_buy', this.c({ p_order: o, p_qty: q })); }
  marketCancel(o) { return this.rpc('game_market_cancel', this.c({ p_order: o })); }
  chat(m) { return this.rpc('game_chat', this.c({ p_msg: m })); }
  chatRecent() { return this.rpc('game_chat_recent'); }
  pvp(t, m) { return this.rpc('game_pvp', this.c({ p_target: t, p_mult: m })); }
  questDone(q) { return this.rpc('game_quest_done', this.c({ p_quest: q })); }
  gm(cmd, a) { return this.rpc('game_gm', this.c({ p_cmd: cmd, p_args: a || {} })); }
  join(me, h) {
    this.world = this.sb.channel('mundo', { config: { broadcast: { self: false }, presence: { key: me.id } } });
    this.world.on('broadcast', { event: 'p' }, ({ payload }) => h.onPos(payload))
      .on('broadcast', { event: 'fx' }, ({ payload }) => h.onFx(payload))
      .on('presence', { event: 'sync' }, () => h.onPresence(this.world.presenceState()))
      .on('presence', { event: 'leave' }, ({ key }) => h.onLeave(key))
      .subscribe(async (s) => { if (s === 'SUBSCRIBED') await this.world.track({ name: me.name, gm: me.is_gm }); });
    this.db = this.sb.channel('db-' + me.id)
      .on('postgres_changes', { event: 'INSERT', schema: 'game', table: 'chat' }, ({ new: m }) => h.onChat(m))
      .on('postgres_changes', { event: '*', schema: 'game', table: 'node_state' }, (p) => h.onNode(p))
      .on('postgres_changes', { event: 'INSERT', schema: 'game', table: 'events', filter: 'target=eq.' + me.id }, ({ new: e }) => h.onEvent(e))
      .subscribe();
  }
  sendPos(p) { this.world && this.world.send({ type: 'broadcast', event: 'p', payload: p }); }
  sendFx(p) { this.world && this.world.send({ type: 'broadcast', event: 'fx', payload: p }); }
  async leave() { if (this.world) await this.sb.removeChannel(this.world); if (this.db) await this.sb.removeChannel(this.db); this.world = this.db = null; }
}

// ----- modo offline: mesmas regras, salvo no navegador -----
class LocalBackend {
  constructor() { this.online = false; this.k = 'rda3d_offline_v1'; this.d = JSON.parse(localStorage.getItem(this.k) || '{"chars":[],"dep":{},"market":[]}'); this.h = {}; }
  _s() { localStorage.setItem(this.k, JSON.stringify(this.d)); }
  E(m) { throw new Error(m); }
  get C() { return this.d.chars.find(c => c.id === this.cid); }
  async session() { return { offline: true }; }
  async login() {} async signup() {} async logout() {} async leave() {}
  async chars() { return { is_gm: true, username: 'offline', chars: structuredClone(this.d.chars) }; }
  async createChar(o) {
    if (this.d.chars.length >= 3) this.E('Limite de 3 personagens por conta');
    if (!/^[\p{L}0-9_]{3,16}$/u.test(o.name || '')) this.E('Nome: 3 a 16 letras ou números, sem espaços');
    if (this.d.chars.some(c => c.name.toLowerCase() === o.name.toLowerCase())) this.E('Esse nome já existe');
    const cl = GD.baseClass(o.race, o.type); if (!cl) this.E('Combinação inválida');
    const A = GD.ARCH[cl.arch], w = A.weapon + '_ng';
    const c = { id: 'L' + Date.now(), ...o, class_id: cl.id, level: 1, xp: 0, hp: 9999, mp: 9999, x: 1500, z: 2578, aurum: 300, karma: 0, pvp: 0, pk: 0, profs: {},
      equipment: { arma: w, armadura: A.armor + '_ng', ...(A.shield ? { escudo: 'escudo_ng' } : {}) }, inv: { pocao_hp: 8, retorno: 2 }, is_gm: true };
    this.d.chars.push(c); this._s(); return c.id;
  }
  async deleteChar(id) { this.d.chars = this.d.chars.filter(c => c.id !== id); this._s(); }
  use(id) { this.cid = id; }
  async state() { const c = this.C, now = Date.now(); for (const k in this.d.dep) if (this.d.dep[k] < now) delete this.d.dep[k]; const { inv, ...ch } = c; return structuredClone({ char: ch, inventory: inv, depleted: this.d.dep }); }
  async save(x, z, hp, mp) { Object.assign(this.C, { x, z, hp, mp }); this._s(); }
  _add(i, q) { const v = this.C.inv; v[i] = (v[i] || 0) + q; }
  _take(i, q) { const v = this.C.inv, h = v[i] || 0; if (h < q) this.E(`Faltam itens: ${GD.ITEMS[i].name} (tem ${h}, precisa ${q})`); if (h === q) delete v[i]; else v[i] = h - q; }
  _prof(k, x) { this.C.profs[k] = (this.C.profs[k] || 0) + x; }
  _safe() { return WG.region(this.C.x, this.C.z).safe; }
  async gather(id, x, z) {
    const n = NODES_BY_ID[id], c = this.C; if (!n) this.E('Recurso inexistente');
    if (Math.hypot(x - n.x, z - n.z) > 6) this.E('Chegue mais perto do recurso');
    if ((this.d.dep[id] || 0) > Date.now()) this.E('Recurso esgotado, renasce em breve');
    const lv = GD.profLevel(c.profs.coleta), req = n.grade * 4; if (lv < req) this.E(`Requer Coleta nível ${req} (você tem ${lv})`);
    if (n.grade > 0 && !Object.keys(c.inv).some(i => GD.ITEMS[i].type === 'tool' && GD.ITEMS[i].grade >= n.grade - 1)) this.E(`Precisa de Kit de Coleta ${GD.GRADES[n.grade - 1].id} ou melhor`);
    const cl = GD.CLASSES[c.class_id], q = 1 + Math.floor(Math.random() * 2) + (lv >= req + 3 ? 1 : 0) + (cl.bonus === 'coleta' ? 1 + cl.rank : 0);
    const it = `${n.type}_${GD.GRADES[n.grade].id.toLowerCase()}`; this._add(it, q); this._prof('coleta', 8 * (n.grade + 1));
    this.d.dep[id] = Date.now() + (50 + 12 * n.grade) * 1000; this._s();
    setTimeout(() => this.h.onNode && this.h.onNode({ eventType: 'UPDATE', new: { node_id: id, depleted_until: new Date(this.d.dep[id]).toISOString() } }), 0);
    return { item: it, qty: q, xp: 8 * (n.grade + 1) };
  }
  async craft(id, t) {
    const r = GD.RECIPES[id], c = this.C; if (!r) this.E('Receita inexistente');
    if (GD.profLevel(c.profs[r.prof]) < r.grade * 4) this.E(`Requer ${GD.PROFS[r.prof]} nível ${r.grade * 4}`);
    for (const [k, v] of Object.entries(r.inputs)) if ((c.inv[k] || 0) < v * t) this.E(`Faltam itens: ${GD.ITEMS[k].name} (tem ${c.inv[k] || 0}, precisa ${v * t})`);
    for (const [k, v] of Object.entries(r.inputs)) this._take(k, v * t);
    this._add(r.out, r.qty * t); this._prof(r.prof, r.xp * t); this._s(); return { item: r.out, qty: r.qty * t, bonus: 0, xp: r.xp * t };
  }
  async equip(i) { const it = GD.ITEMS[i], c = this.C; if (!it || !it.slot) this.E('Item não equipável'); const req = GD.GRADES[it.grade].lvl; if (c.level < req) this.E(`Equipamento de grau ${GD.GRADES[it.grade].id} exige nível ${req}`); this._take(i, 1); const o = c.equipment[it.slot]; if (o) this._add(o, 1); c.equipment[it.slot] = i; this._s(); return { ...c.equipment }; }
  async unequip(s) { const c = this.C, o = c.equipment[s]; if (!o) this.E('Nada equipado'); this._add(o, 1); delete c.equipment[s]; this._s(); return { ...c.equipment }; }
  async useItem(i) { const it = GD.ITEMS[i]; if (!it || !['potion', 'scroll'].includes(it.type)) this.E('Item não utilizável'); this._take(i, 1); if (it.type === 'scroll') { const t = WG.nearestTown(this.C.x, this.C.z).town; this.C.x = t.x; this.C.z = t.z + 25; this._s(); return { tp: true, x: t.x, z: t.z + 25, town: t.name }; } this._s(); return it.stats; }
  async kill(L, boss, fam) {
    const c = this.C; L = Math.max(1, Math.min(80, Math.min(L, c.level + 12)));
    let pen = 1; if (L < c.level - 5) pen = Math.max(0.1, 1 - (c.level - 5 - L) * 0.15);
    const gain = Math.round(GD.mobXp(L) * pen * (boss ? 12 : 1) * GD.RATE_XP); let au = L * 3 + Math.floor(Math.random() * L * 5); if (boss) au *= 10; au *= GD.RATE_AURUM;
    c.xp += gain; let ups = 0; while (c.level < 80 && c.xp >= GD.xpNeed(c.level)) { c.xp -= GD.xpNeed(c.level); c.level++; ups++; }
    c.aurum += au; c.karma = Math.max(0, c.karma - Math.max(5, L >> 1));
    const gid = GD.GRADES[GD.gradeForLevel(L)].id.toLowerCase(), drops = {};
    if (Math.random() < 0.75 || boss) { this._add('pele_' + gid, 1); drops['pele_' + gid] = 1; }
    if (Math.random() < 0.22) { const it = ['madeira', 'minerio', 'fibra'][Math.floor(Math.random() * 3)] + '_' + gid; this._add(it, 1); drops[it] = 1; }
    if (L >= 52 && (Math.random() < 0.07 || boss)) { this._add('gema', 1); drops.gema = 1; }
    if (L >= 76 && (Math.random() < 0.035 || boss)) { this._add('fragmento', 1); drops.fragmento = 1; }
    let unique = null; const sb = GD.SPECIAL_BOSSES.find(b => b.id === fam);
    if (sb) { for (const it of sb.drops) { if (GD.ITEMS[it].unique) { if (Math.random() < 0.35) { this._add(it, 1); drops[it] = 1; unique = it; } } else { this._add(it, 2); drops[it] = 2; } } }
    this._s(); return { xp: gain, level: c.level, xp_now: c.xp, aurum: au, drops, levelups: ups, unique };
  }
  async die(pvp) { const c = this.C; const lost = Math.min(c.xp, pvp ? 0 : Math.round(GD.xpNeed(c.level) * 0.04)); c.xp -= lost; const t = WG.nearestTown(c.x, c.z).town; c.x = t.x; c.z = t.z + 25; this._s(); return { x: c.x, z: c.z, town: t.name, xp_lost: lost }; }
  async classChange(k) { const c = this.C, n = GD.CLASSES[k]; if (!n || n.parent !== c.class_id) this.E('Essa classe não é compatível com a sua classe atual'); if (c.level < GD.RANK_LVL[n.rank]) this.E('Requer nível ' + GD.RANK_LVL[n.rank]); c.class_id = k; this._s(); return n.name; }
  async teleport(d) { const tp = TELEPORTS.find(t => t.id === d); this.C.x = tp.x; this.C.z = tp.z; this._s(); return { x: tp.x, z: tp.z, cost: 0, name: tp.name }; }
  async shopBuy(i, q) { const p = GD.SHOP[i] * q; if (this.C.aurum < p) this.E('Aurum insuficiente'); this.C.aurum -= p; this._add(i, q); this._s(); }
  async npcSell(i, q) { const v = GD.npcPrice(GD.ITEMS[i]) * q; this._take(i, q); this.C.aurum += v; this._s(); return v; }
  async marketList() { return this.d.market.map(o => ({ ...o, mine: true })); }
  async marketSell(i, q, p) { this._take(i, q); this.d.market.push({ id: Date.now(), seller: this.C.name, item: i, qty: q, price: p }); this._s(); }
  async marketBuy() { this.E('No modo offline só existem as suas ofertas'); }
  async marketCancel(o) { const k = this.d.market.findIndex(x => x.id === o); const m = this.d.market[k]; this._add(m.item, m.qty); this.d.market.splice(k, 1); this._s(); }
  async chat(m) { setTimeout(() => this.h.onChat({ name: this.C.name, is_gm: true, kind: 'chat', msg: m }), 0); }
  async chatRecent() { return [{ name: 'Sistema', is_gm: true, kind: 'sistema', msg: 'Modo offline: só você está no mundo. Comandos de GM liberados para teste.' }]; }
  async pvp() { this.E('PvP só funciona no servidor online'); }
  async questDone(id) {
    const c = this.C, Q = QD.QUESTS[id]; c.quests = c.quests || {};
    if (c.quests[id]) this.E('Missão já concluída'); if (c.level < Q.lvl) this.E('Requer nível ' + Q.lvl); if (Q.prereq && !c.quests[Q.prereq]) this.E('Conclua a missão anterior primeiro');
    if (Q.goal.type === 'turnin') { for (const [k, v] of Object.entries(Q.goal.items)) if ((c.inv[k] || 0) < v) this.E(`Faltam itens: ${GD.ITEMS[k].name}`); for (const [k, v] of Object.entries(Q.goal.items)) this._take(k, v); }
    c.xp += (Q.reward.xp || 0) * GD.RATE_XP; let ups = 0; while (c.level < 80 && c.xp >= GD.xpNeed(c.level)) { c.xp -= GD.xpNeed(c.level); c.level++; ups++; }
    c.aurum += (Q.reward.aurum || 0) * GD.RATE_AURUM; for (const [k, v] of Object.entries(Q.reward.items || {})) this._add(k, v); c.quests[id] = true; this._s();
    return { level: c.level, xp_now: c.xp, levelups: ups, reward: Q.reward };
  }
  async gm(cmd, a) {
    const c = this.C;
    if (cmd === 'give') { if (!GD.ITEMS[a.item]) this.E('Item inexistente: ' + a.item); this._add(a.item, +a.qtd || 1); this._s(); return 'Entregue'; }
    if (cmd === 'aurum') { c.aurum = Math.max(0, c.aurum + +a.qtd); this._s(); return 'Aurum ajustado'; }
    if (cmd === 'nivel') { c.level = Math.max(1, Math.min(80, +a.nivel)); c.xp = 0; this._s(); return 'Nível ' + c.level; }
    if (cmd === 'prof') { c.profs[a.prof] = GD.profXpFor(+a.nivel); this._s(); return 'Profissão ajustada'; }
    if (cmd === 'classe') { c.class_id = a.classe; this._s(); return 'Classe alterada'; }
    if (cmd === 'karma') { c.karma = +a.qtd; this._s(); return 'Karma ajustado'; }
    if (cmd === 'anuncio') { setTimeout(() => this.h.onChat({ name: c.name, is_gm: true, kind: 'anuncio', msg: a.msg }), 0); return 'Anunciado'; }
    if (cmd === 'reset_nos') { this.d.dep = {}; this._s(); return 'Recursos renasceram'; }
    this.E('Indisponível no modo offline');
  }
  join(me, h) { this.h = h; setTimeout(() => h.onPresence({ [me.id]: [{ name: me.name, gm: true }] }), 0); }
  sendPos() {} sendFx() {}
}
