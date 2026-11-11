// ===== Valtheria — enredo e missões =====
(function (root) {
  const LORE = {
    title: 'A Era do Eclipse',
    chapters: [
      ['Prólogo — As Duas Luas', 'Há mil anos, os Reinos de Aurora eram guardados por duas luas: Lúmen, a lua de prata que dava vida às florestas, e Nyx, a lua de ônix que guardava os sonhos dos mortos. Entre elas girava a Coroa Celeste, um anel de cristal forjado pelos primeiros anões e abençoado pelos elfos, que mantinha as duas luas em equilíbrio.'],
      ['A Quebra da Coroa', 'Na noite que os cronistas chamam de Grande Silêncio, Malachar — um arquimago humano que buscava a imortalidade — tentou aprisionar o poder de Nyx. A Coroa Celeste se partiu em seis fragmentos que caíram em cantos distantes do continente. Desde então, a cada século, Nyx cobre Lúmen num eclipse cada vez mais longo, e as criaturas do mundo enlouquecem sob sua sombra.'],
      ['Os Seis Guardiões Corrompidos', 'Cada fragmento da Coroa foi engolido por uma criatura, que cresceu além de qualquer medida: o Rei Javali, nos campos de Aurora; a Rainha Aracnídea, sob o Forte Dourado; o Golem Ancestral, nas pedreiras de Pedra Alta; o Ent Milenar, no coração de Sylvar; o Senhor Demônio, nas fendas da Cidadela Rubra; e o Dragão Celeste, que dorme sobre as Ruínas de Aeternum, o último bastião antes do céu.'],
      ['O Chamado', 'O Eclipse final se aproxima. Humanos, elfos, elfos sombrios, orcs e anões — povos que guerrearam por séculos — juraram trégua na Vila Aurora. O Arauto do Eclipse convoca aventureiros de todas as raças: reunam os seis fragmentos, restaurem a Coroa Celeste e impeçam que Nyx devore Lúmen para sempre.'],
      ['Os Caminhos', 'Todo aventureiro nasce como Lutador ou Místico de sua raça. Aos níveis 20, 40 e 76, os Mestres de Classe das cidades revelam novos caminhos — mas cada raça só pode trilhar as artes compatíveis com seu sangue. Os anões, guardiões da forja original, são os únicos capazes de recriar a Coroa — e por isso seus Coletores e Artífices são cobiçados por todas as guildas.'],
      ['A Lei da Trégua', 'Dentro das muralhas das seis cidades, nenhuma arma pode ser erguida contra outro aventureiro. Fora delas, o duelo é permitido — mas quem derrama o sangue de um inocente carrega o Karma: seu nome arde em vermelho, os guardas se recusam a protegê-lo, e a morte pode lhe arrancar os próprios tesouros.'],
    ],
  };

  // tipos: kill (fam, n), boss (fam), reach (town), turnin (itens entregues ao servidor)
  const Q = [];
  const q = (o) => Q.push(o);
  // ----- linha principal -----
  q({ id: 'm01', main: true, town: 'aurora', lvl: 1, title: 'O Despertar', text: 'O Arauto pede que você prove seu valor afastando os javalis enlouquecidos dos campos.', goal: { type: 'kill', fam: 'javali', n: 5 }, reward: { xp: 120, aurum: 150, items: { pocao_hp: 5 } } });
  q({ id: 'm02', main: true, town: 'aurora', lvl: 5, prereq: 'm01', title: 'Sombras nos Campos', text: 'Lobos cinzentos caçam sob a luz de Nyx. Reduza a matilha antes que ataquem a vila.', goal: { type: 'kill', fam: 'lobo', n: 8 }, reward: { xp: 2500, aurum: 400, items: { kit_ng: 1 } } });
  q({ id: 'm03', main: true, town: 'aurora', lvl: 12, prereq: 'm02', title: 'O Rei dos Javalis', text: 'O primeiro fragmento da Coroa brilha no lombo de um javali colossal no Bosque dos Javalis. Derrote-o — de preferência em grupo.', goal: { type: 'boss', fam: 'rei_javali', spot: ['aurora', 1] }, reward: { xp: 30000, aurum: 2500, items: { retorno: 3, pocao_hp: 10 } } });
  q({ id: 'm04', main: true, town: 'aurora', lvl: 18, prereq: 'm03', title: 'Rumo ao Forte Dourado', text: 'Leve o fragmento ao Forte Dourado, a oeste. O caminho de terra liga as cidades — ou pague o Guardião do Portal.', goal: { type: 'reach', town: 'dourado' }, reward: { xp: 20000, aurum: 1500 } });
  q({ id: 'm05', main: true, town: 'dourado', lvl: 22, prereq: 'm04', title: 'Bandidos da Planície', text: 'Orcs renegados saqueiam as caravanas. Eles servem a algo que vive sob a terra.', goal: { type: 'kill', fam: 'bandido', n: 12 }, reward: { xp: 90000, aurum: 3000, items: { pocao_mp: 10 } } });
  q({ id: 'm06', main: true, town: 'dourado', lvl: 32, prereq: 'm05', title: 'A Rainha Aracnídea', text: 'No Ninho das Aranhas, a Rainha guarda o segundo fragmento entre ovos e teias.', goal: { type: 'boss', fam: 'rainha', spot: ['dourado', 1] }, reward: { xp: 400000, aurum: 9000, items: { kit_d: 1 } } });
  q({ id: 'm07', main: true, town: 'dourado', lvl: 40, prereq: 'm06', title: 'As Pedras que Andam', text: 'Viaje até Pedra Alta e descubra por que os golens despertaram.', goal: { type: 'kill', fam: 'golem', n: 10 }, reward: { xp: 600000, aurum: 9000 } });
  q({ id: 'm08', main: true, town: 'pedra', lvl: 48, prereq: 'm07', title: 'O Golem Ancestral', text: 'O guardião de pedra mais antigo do mundo carrega o terceiro fragmento no peito.', goal: { type: 'boss', fam: 'golem_anc', spot: ['pedra', 0] }, reward: { xp: 2000000, aurum: 20000, items: { gema: 2 } } });
  q({ id: 'm09', main: true, town: 'pedra', lvl: 52, prereq: 'm08', title: 'Sylvar em Chamas', text: 'Lobos espectrais rondam a floresta élfica. Os anciãos de Sylvar pedem ajuda.', goal: { type: 'kill', fam: 'lobo_esp', n: 12 }, reward: { xp: 1500000, aurum: 20000 } });
  q({ id: 'm10', main: true, town: 'sylvar', lvl: 58, prereq: 'm09', title: 'O Ent Milenar', text: 'A árvore mais velha do mundo apodreceu por dentro. Liberte-a e recupere o quarto fragmento.', goal: { type: 'boss', fam: 'ent_mil', spot: ['sylvar', 0] }, reward: { xp: 5000000, aurum: 40000, items: { gema: 3 } } });
  q({ id: 'm11', main: true, town: 'sylvar', lvl: 61, prereq: 'm10', title: 'A Cidadela Rubra', text: 'Demônios atravessam as fendas do deserto. Contenha a invasão.', goal: { type: 'kill', fam: 'demonio', n: 15 }, reward: { xp: 4000000, aurum: 40000 } });
  q({ id: 'm12', main: true, town: 'rubra', lvl: 72, prereq: 'm11', title: 'O Senhor Demônio', text: 'Na Fenda Demoníaca, o Senhor Demônio usa o quinto fragmento para manter o portal aberto.', goal: { type: 'boss', fam: 'senhor_dem', spot: ['rubra', 1] }, reward: { xp: 12000000, aurum: 90000, items: { gema: 4, fragmento: 1 } } });
  q({ id: 'm13', main: true, town: 'rubra', lvl: 76, prereq: 'm12', title: 'O Eclipse', text: 'Os Cavaleiros Caídos, antigos heróis de Malachar, protegem o caminho para o céu.', goal: { type: 'kill', fam: 'caido', n: 15 }, reward: { xp: 10000000, aurum: 90000, items: { fragmento: 1 } } });
  q({ id: 'm14', main: true, town: 'celeste', lvl: 80, prereq: 'm13', title: 'O Dragão Celeste', text: 'O último fragmento pulsa no coração do Dragão Celeste. Reúna os mais fortes do reino. Restaure a Coroa.', goal: { type: 'boss', fam: 'dragao', spot: ['celeste', 1] }, reward: { xp: 30000000, aurum: 500000, items: { fragmento: 4, gema: 6 } } });
  // ----- secundárias (entregas verificadas pelo servidor) -----
  const side = (id, town, lvl, title, text, goal, reward) => q({ id, kind: 'secundaria', town, lvl, title, text, goal, reward });
  side('s_aur1', 'aurora', 1, 'Lenha para o Inverno', 'O ferreiro da vila precisa de madeira para as fornalhas.', { type: 'turnin', items: { madeira_ng: 10 } }, { xp: 400, aurum: 250, items: { pocao_hp: 5 } });
  side('s_aur2', 'aurora', 4, 'A Primeira Forja', 'Refine minério na Refinaria e entregue barras ao ferreiro.', { type: 'turnin', items: { barra_ng: 5 } }, { xp: 1500, aurum: 400, items: { kit_ng: 1 } });
  side('s_dou1', 'dourado', 20, 'Couro para os Guardas', 'A guarnição do Forte precisa de couro curtido.', { type: 'turnin', items: { couro_d: 8 } }, { xp: 60000, aurum: 2500 });
  side('s_dou2', 'dourado', 26, 'Caça às Aranhas', 'Peles de aranha valem ouro para os alquimistas.', { type: 'kill', fam: 'aranha', n: 15 }, { xp: 120000, aurum: 3500, items: { pocao_mp: 8 } });
  side('s_ped1', 'pedra', 40, 'Aço para a Muralha', 'Pedra Alta reforça suas muralhas.', { type: 'turnin', items: { barra_c: 10 } }, { xp: 500000, aurum: 9000 });
  side('s_ped2', 'pedra', 44, 'A Cripta Esquecida', 'Esqueletos saem da cripta todas as noites.', { type: 'kill', fam: 'esqueleto', n: 15 }, { xp: 700000, aurum: 10000, items: { pocao_hp2: 10 } });
  side('s_syl1', 'sylvar', 52, 'Tecidos Élficos', 'As tecelãs de Sylvar perderam seus teares.', { type: 'turnin', items: { tecido_b: 10 } }, { xp: 1500000, aurum: 25000, items: { gema: 1 } });
  side('s_syl2', 'sylvar', 55, 'Raízes Podres', 'Ents corrompidos sufocam as árvores jovens.', { type: 'kill', fam: 'ent', n: 10 }, { xp: 1800000, aurum: 25000 });
  side('s_rub1', 'rubra', 61, 'Escamas Rubras', 'Couro de lagarto é a melhor proteção contra o fogo.', { type: 'turnin', items: { couro_a: 10 } }, { xp: 3000000, aurum: 50000, items: { gema: 2 } });
  side('s_rub2', 'rubra', 66, 'Lagartos do Deserto', 'Os lagartos guerreiros atacam as patrulhas.', { type: 'kill', fam: 'lagarto', n: 15 }, { xp: 3500000, aurum: 50000 });
  side('s_cel1', 'celeste', 76, 'A Liga Celestial', 'Os mestres forjadores precisam de barras S para as armas finais.', { type: 'turnin', items: { barra_s: 5, fragmento: 1 } }, { xp: 8000000, aurum: 150000, items: { gema: 3 } });
  side('s_cel2', 'celeste', 78, 'Ninho dos Dragões', 'Dragonetes protegem o caminho até o Dragão Celeste.', { type: 'kill', fam: 'dragonete', n: 20 }, { xp: 9000000, aurum: 150000, items: { fragmento: 1 } });

  // ----- secundárias das cidades novas e troféus -----
  side('s_aur3', 'aurora', 6, 'Presas para o Curtidor', 'O curtidor da vila paga bem por presas de javali.', { type: 'turnin', items: { tr_javali: 8 } }, { xp: 3000, aurum: 600, items: { enc_arm_ng: 1 } });
  side('s_dou3', 'dourado', 24, 'Insígnias Roubadas', 'Os bandidos usam insígnias para se reconhecer. Traga-as ao xerife.', { type: 'turnin', items: { tr_bandido: 10 } }, { xp: 90000, aurum: 3000, items: { enc_arma_d: 1 } });
  side('s_pre1', 'presas', 22, 'Prova do Caçador', 'O Clã das Presas só respeita quem traz troféus. Mostre sua força.', { type: 'turnin', items: { tr_aranha: 12 } }, { xp: 110000, aurum: 3500, items: { enc_arm_d: 2 } });
  side('s_pre2', 'presas', 30, 'A Grande Caçada', 'A matilha precisa de carne para o inverno. Ajude na caçada dos bandidos da estrada.', { type: 'kill', fam: 'bandido', n: 25 }, { xp: 200000, aurum: 5000, items: { pocao_hp2: 10 } });
  side('s_ped3', 'pedra', 46, 'Núcleos para a Forja Rúnica', 'Os mestres rúnicos gravam runas em núcleos de golem.', { type: 'turnin', items: { tr_golem: 12 } }, { xp: 800000, aurum: 12000, items: { enc_arma_c: 1 } });
  side('s_umb1', 'umbraval', 53, 'Ecos na Escuridão', 'Lobos espectrais rondam as pontes de obsidiana.', { type: 'kill', fam: 'lobo_esp', n: 20 }, { xp: 1700000, aurum: 26000, items: { enc_arm_b: 1 } });
  side('s_umb2', 'umbraval', 56, 'Seiva para os Venenos', 'As alquimistas sombrias destilam venenos da seiva corrompida.', { type: 'turnin', items: { tr_ent: 12 } }, { xp: 1900000, aurum: 30000, items: { enc_arma_b: 1 } });
  side('s_pic1', 'pico', 62, 'Escamas para os Escudos', 'Os ferreiros draconatos reforçam escudos com escamas de lagarto.', { type: 'turnin', items: { tr_lagarto: 12 } }, { xp: 3200000, aurum: 55000, items: { enc_arm_a: 2 } });
  side('s_pic2', 'pico', 68, 'Chifres do Abismo', 'O Pico do Dragão paga por cada demônio abatido.', { type: 'kill', fam: 'demonio', n: 25 }, { xp: 4000000, aurum: 60000, items: { enc_arma_a: 1 } });
  side('s_noc1', 'noctis', 76, 'Selos dos Caídos', 'Os nocturnos querem destruir os selos dos antigos cavaleiros.', { type: 'turnin', items: { tr_caido: 12 } }, { xp: 9000000, aurum: 160000, items: { enc_arma_s: 1 } });
  side('s_gla1', 'glacial', 77, 'Escamas do Céu', 'Os gigantes forjam armaduras com escamas de dragonete.', { type: 'turnin', items: { tr_dragonete: 12 } }, { xp: 9500000, aurum: 160000, items: { enc_arm_s: 2 } });
  // ----- lendas: chefes dos locais especiais (aceitas em qualquer cidade) -----
  const legend = (id, lvl, title, text, fam, lm, reward) => q({ id, kind: 'lenda', town: '*', lvl, title, text, goal: { type: 'boss', fam, lm }, reward });
  legend('l_corvo', 15, 'Lenda: o Rei Corvo', 'Um rei amaldiçoado governa o Castelo dos Corvos. Derrote-o e talvez ganhe seu arco.', 'rei_corvo', 'castelo_corvos', { xp: 25000, aurum: 3000, items: { enc_arma_ng: 2 } });
  legend('l_ruinas', 14, 'Lenda: o Guardião das Ruínas', 'Nas ruínas de Vel\'Anor, um colosso de pedra protege um escudo antigo.', 'guardiao_ruinas', 'ruinas_velhas', { xp: 22000, aurum: 3000, items: { enc_arm_ng: 2 } });
  legend('l_grak', 32, 'Lenda: Grak, o Saqueador', 'O líder dos saqueadores ergueu um forte na estrada do oeste.', 'chefe_saqueador', 'forte_bandido', { xp: 300000, aurum: 9000, items: { enc_arma_d: 2 } });
  legend('l_lich', 48, 'Lenda: o Rei Lich', 'Morthas desperta na Cripta dos Reis a cada lua nova.', 'rei_lich', 'cripta_reis', { xp: 1200000, aurum: 20000, items: { enc_arma_c: 2 } });
  legend('l_lua', 57, 'Lenda: a Sacerdotisa da Lua', 'No Templo da Lua Partida, uma sacerdotisa canta para Nyx.', 'sacerdotisa_lua', 'templo_lua', { xp: 2500000, aurum: 40000, items: { enc_arma_b: 2 } });
  legend('l_hidra', 68, 'Lenda: a Hidra do Pântano', 'Três cabeças, um pântano inteiro de veneno.', 'hidra', 'covil_hidra', { xp: 6000000, aurum: 90000, items: { enc_arma_a: 2 } });
  legend('l_conde', 78, 'Lenda: o Conde Carmesim', 'O senhor do Castelo do Sangue Eterno nunca perdeu um duelo.', 'conde_carmesim', 'castelo_sangue', { xp: 15000000, aurum: 250000, items: { enc_arma_s: 2 } });
  legend('l_wyrm', 78, 'Lenda: o Wyrm do Inverno', 'No Trono do Inverno dorme a criatura mais fria do mundo.', 'wyrm_gelo', 'trono_gelo', { xp: 15000000, aurum: 250000, items: { enc_arm_s: 3 } });
  // ----- diárias (renovam à meia-noite; aceitas em qualquer Arauto) -----
  const BANDS = [['aurora', 1, 'NG', ['javali', 'lobo', 'rei_javali']], ['dourado', 20, 'D', ['bandido', 'aranha', 'rainha']], ['pedra', 40, 'C', ['golem', 'esqueleto', 'golem_anc']], ['sylvar', 52, 'B', ['ent', 'lobo_esp', 'ent_mil']], ['rubra', 61, 'A', ['demonio', 'lagarto', 'senhor_dem']], ['celeste', 76, 'S', ['dragonete', 'caido', 'dragao']]];
  const need = (L) => Math.round(50 * Math.pow(L, 2.4));
  BANDS.forEach(([town, L, G, f], b) => { const g = G.toLowerCase(), base = need(L + 4) / 50;
    q({ id: `d${b}_caca`, kind: 'diaria', town: '*', band: b, lvl: L, title: `Diária: Caçada (${G})`, text: 'O conselho paga por cada fera abatida perto das estradas.', goal: { type: 'kill', fam: f[1], n: 30, daily: true }, reward: { xp: Math.round(base * 0.35), aurum: 200 * (b + 1), items: { [`enc_arm_${g}`]: 1, pocao_hp: 5 } } });
    q({ id: `d${b}_trofeu`, kind: 'diaria', town: '*', band: b, lvl: L, title: `Diária: Encomenda do Mercador (${G})`, text: 'Um mercador viajante procura troféus de caça.', goal: { type: 'turnin', items: { [`tr_${f[0]}`]: 10 }, daily: true }, reward: { xp: Math.round(base * 0.25), aurum: 400 * (b + 1), items: { [`enc_arma_${g}`]: 1 } } });
    q({ id: `d${b}_chefe`, kind: 'diaria', town: '*', band: b, lvl: L + 4, title: `Diária: Ameaça do Dia (${G})`, text: 'Um chefe voltou a aparecer na região. Reúna aliados e derrote-o.', goal: { type: 'boss', fam: f[2], spot: [town, 1], daily: true }, reward: { xp: Math.round(base * 0.6), aurum: 800 * (b + 1), items: { [`enc_arma_${g}`]: 1, [`enc_arm_${g}`]: 2 } } });
  });
  const QUESTS = {}; Q.forEach(x => QUESTS[x.id] = x);
  const api = { LORE, QUESTS, LIST: Q };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.QD = api;
})(typeof window !== 'undefined' ? window : globalThis);
