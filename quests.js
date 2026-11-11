// ===== Reinos de Aurora — enredo e missões =====
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
  const side = (id, town, lvl, title, text, goal, reward) => q({ id, town, lvl, title, text, goal, reward });
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

  const QUESTS = {}; Q.forEach(x => QUESTS[x.id] = x);
  const api = { LORE, QUESTS, LIST: Q };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.QD = api;
})(typeof window !== 'undefined' ? window : globalThis);
