-- Classes do banco novo (185): id|nome|rank|pai|raça|arquétipo|elemento|nível|caminho
insert into game.classes_v2 (id, nome, rank, pai, raca, arquetipo, elemento, nivel, caminho)
select p[1], p[2], p[3]::int, nullif(p[4], ''), p[5], p[6], p[7], p[8]::int, p[9]
from (select string_to_array(l, '|') p from unnest(string_to_array($d$hum_l|Escudeiro|0||humano|guerreiro|luz|1|A
hum_tq_1|Templário|1|hum_l|humano|tanque|luz|20|A
hum_tq_2|Paladino da Aurora|2|hum_tq_1|humano|tanque|luz|40|A
hum_tq_3|Grão-Templário|3|hum_tq_2|humano|tanque|luz|76|A
hum_gr_1|Combatente|1|hum_l|humano|guerreiro|luz|20|A
hum_gr_2|Mestre de Armas|2|hum_gr_1|humano|guerreiro|luz|40|A
hum_gr_3|Senhor da Guerra|3|hum_gr_2|humano|guerreiro|luz|76|A
hum_aq_1|Batedor|1|hum_l|humano|arqueiro|luz|20|A
hum_aq_2|Caçador|2|hum_aq_1|humano|arqueiro|luz|40|A
hum_aq_3|Atirador Celeste|3|hum_aq_2|humano|arqueiro|luz|76|A
hum_m|Aprendiz Arcano|0||humano|mago|luz|1|A
hum_mg_1|Arcanista|1|hum_m|humano|mago|luz|20|A
hum_mg_2|Arquimago|2|hum_mg_1|humano|mago|luz|40|A
hum_mg_3|Sábio Arcano|3|hum_mg_2|humano|mago|luz|76|A
hum_cu_1|Clérigo|1|hum_m|humano|curandeiro|luz|20|A
hum_cu_2|Bispo|2|hum_cu_1|humano|curandeiro|luz|40|A
hum_cu_3|Santo Curador|3|hum_cu_2|humano|curandeiro|luz|76|A
hum_tq_2b|Cavaleiro do Eclipse|2|hum_tq_1|humano|tanque|sombra|40|B
hum_tq_3b|Vingador do Eclipse|3|hum_tq_2b|humano|tanque|sombra|76|B
hum_gr_2b|Gladiador|2|hum_gr_1|humano|guerreiro|fogo|40|B
hum_gr_3b|Duelista Lendário|3|hum_gr_2b|humano|guerreiro|fogo|76|B
hum_aq_2b|Caçador de Tesouros|2|hum_aq_1|humano|adaga|vento|40|B
hum_aq_3b|Aventureiro das Fendas|3|hum_aq_2b|humano|adaga|vento|76|B
hum_mg_2b|Invocador do Véu|2|hum_mg_1|humano|invocador|raio|40|B
hum_mg_3b|Senhor do Véu|3|hum_mg_2b|humano|invocador|raio|76|B
hum_cu_2b|Profeta de Lúmen|2|hum_cu_1|humano|xama|luz|40|B
hum_cu_3b|Hierofante de Lúmen|3|hum_cu_2b|humano|xama|luz|76|B
elf_l|Sentinela Élfico|0||elfo|guerreiro|vento|1|A
elf_aq_1|Guardião Arqueiro|1|elf_l|elfo|arqueiro|vento|20|A
elf_aq_2|Patrulheiro Lunar|2|elf_aq_1|elfo|arqueiro|vento|40|A
elf_aq_3|Flecha de Prata|3|elf_aq_2|elfo|arqueiro|vento|76|A
elf_tq_1|Cavaleiro Élfico|1|elf_l|elfo|tanque|vento|20|A
elf_tq_2|Templário da Floresta|2|elf_tq_1|elfo|tanque|vento|40|A
elf_tq_3|Guardião Ancestral|3|elf_tq_2|elfo|tanque|vento|76|A
elf_ad_1|Andarilho|1|elf_l|elfo|adaga|vento|20|A
elf_ad_2|Lâmina do Vento|2|elf_ad_1|elfo|adaga|vento|40|A
elf_ad_3|Espectro da Brisa|3|elf_ad_2|elfo|adaga|vento|76|A
elf_m|Místico Élfico|0||elfo|mago|vento|1|A
elf_cu_1|Cantor de Runas|1|elf_m|elfo|curandeiro|vento|20|A
elf_cu_2|Bardo Rúnico|2|elf_cu_1|elfo|curandeiro|vento|40|A
elf_cu_3|Voz das Runas|3|elf_cu_2|elfo|curandeiro|vento|76|A
elf_mg_1|Feiticeiro Élfico|1|elf_m|elfo|mago|vento|20|A
elf_mg_2|Mago das Águas|2|elf_mg_1|elfo|mago|vento|40|A
elf_mg_3|Mestre das Marés|3|elf_mg_2|elfo|mago|vento|76|A
elf_aq_2b|Batedor dos Ventos|2|elf_aq_1|elfo|arqueiro|agua|40|B
elf_aq_3b|Sentinela do Luar|3|elf_aq_2b|elfo|arqueiro|agua|76|B
elf_tq_2b|Cantor de Espadas|2|elf_tq_1|elfo|guerreiro|agua|40|B
elf_tq_3b|Musa das Lâminas|3|elf_tq_2b|elfo|guerreiro|agua|76|B
elf_ad_2b|Corredor das Planícies|2|elf_ad_1|elfo|adaga|agua|40|B
elf_ad_3b|Cavaleiro do Vento|3|elf_ad_2b|elfo|adaga|agua|76|B
elf_cu_2b|Guardião da Seiva|2|elf_cu_1|elfo|curandeiro|agua|40|B
elf_cu_3b|Coração da Árvore|3|elf_cu_2b|elfo|curandeiro|agua|76|B
elf_mg_2b|Invocador Elemental|2|elf_mg_1|elfo|invocador|agua|40|B
elf_mg_3b|Mestre dos Elementos|3|elf_mg_2b|elfo|invocador|agua|76|B
de_l|Guerreiro Sombrio|0||sombrio|guerreiro|sombra|1|A
de_ad_1|Lâmina das Sombras|1|de_l|sombrio|adaga|sombra|20|A
de_ad_2|Assassino da Noite|2|de_ad_1|sombrio|adaga|sombra|40|A
de_ad_3|Fantasma do Abismo|3|de_ad_2|sombrio|adaga|sombra|76|A
de_tq_1|Cavaleiro Sombrio|1|de_l|sombrio|tanque|sombra|20|A
de_tq_2|Vingador|2|de_tq_1|sombrio|tanque|sombra|40|A
de_tq_3|Guardião da Sombra|3|de_tq_2|sombrio|tanque|sombra|76|A
de_aq_1|Atirador Sombrio|1|de_l|sombrio|arqueiro|sombra|20|A
de_aq_2|Predador|2|de_aq_1|sombrio|arqueiro|sombra|40|A
de_aq_3|Caçador do Vazio|3|de_aq_2|sombrio|arqueiro|sombra|76|A
de_m|Místico Sombrio|0||sombrio|mago|sombra|1|A
de_mg_1|Feiticeiro do Abismo|1|de_m|sombrio|mago|sombra|20|A
de_mg_2|Necromante|2|de_mg_1|sombrio|mago|sombra|40|A
de_mg_3|Arauto do Vazio|3|de_mg_2|sombrio|mago|sombra|76|A
de_xa_1|Xamã Sombrio|1|de_m|sombrio|xama|sombra|20|A
de_xa_2|Profeta Sombrio|2|de_xa_1|sombrio|xama|sombra|40|A
de_xa_3|Oráculo do Vazio|3|de_xa_2|sombrio|xama|sombra|76|A
de_ad_2b|Dançarino da Lua Negra|2|de_ad_1|sombrio|guerreiro|raio|40|B
de_ad_3b|Espectro de Nyx|3|de_ad_2b|sombrio|guerreiro|raio|76|B
de_tq_2b|Cavaleiro do Abismo|2|de_tq_1|sombrio|tanque|raio|40|B
de_tq_3b|Templário de Nyx|3|de_tq_2b|sombrio|tanque|raio|76|B
de_aq_2b|Batedor Fantasma|2|de_aq_1|sombrio|arqueiro|vento|40|B
de_aq_3b|Sentinela Fantasma|3|de_aq_2b|sombrio|arqueiro|vento|76|B
de_mg_2b|Cantor da Penumbra|2|de_mg_1|sombrio|mago|vento|40|B
de_mg_3b|Tempestade Negra|3|de_mg_2b|sombrio|mago|vento|76|B
de_xa_2b|Ancião Sombrio|2|de_xa_1|sombrio|curandeiro|sombra|40|B
de_xa_3b|Coração de Nyx|3|de_xa_2b|sombrio|curandeiro|sombra|76|B
orc_l|Guerreiro Orc|0||orc|guerreiro|fogo|1|A
orc_gr_1|Berserker de Sangue|1|orc_l|orc|guerreiro|fogo|20|A
orc_gr_2|Destruidor|2|orc_gr_1|orc|guerreiro|fogo|40|A
orc_gr_3|Titã Rubro|3|orc_gr_2|orc|guerreiro|fogo|76|A
orc_mo_1|Monge|1|orc_l|orc|monge|fogo|20|A
orc_mo_2|Punho de Ferro|2|orc_mo_1|orc|monge|fogo|40|A
orc_mo_3|Mestre do Punho|3|orc_mo_2|orc|monge|fogo|76|A
orc_m|Místico Orc|0||orc|xama|fogo|1|A
orc_xa_1|Xamã Tribal|1|orc_m|orc|xama|fogo|20|A
orc_xa_2|Senhor Tribal|2|orc_xa_1|orc|xama|fogo|40|A
orc_xa_3|Ancião Tribal|3|orc_xa_2|orc|xama|fogo|76|A
orc_cu_1|Invocador Tribal|1|orc_m|orc|curandeiro|fogo|20|A
orc_cu_2|Bramido Sagrado|2|orc_cu_1|orc|curandeiro|fogo|40|A
orc_cu_3|Voz dos Ancestrais|3|orc_cu_2|orc|curandeiro|fogo|76|A
orc_gr_2b|Senhor dos Clãs|2|orc_gr_1|orc|guerreiro|terra|40|B
orc_gr_3b|Rei da Horda|3|orc_gr_2b|orc|guerreiro|terra|76|B
orc_mo_2b|Punho Ardente|2|orc_mo_1|orc|monge|fogo|40|B
orc_mo_3b|Avatar da Brasa|3|orc_mo_2b|orc|monge|fogo|76|B
orc_xa_2b|Uivador de Guerra|2|orc_xa_1|orc|xama|fogo|40|B
orc_xa_3b|Clamor da Guerra|3|orc_xa_2b|orc|xama|fogo|76|B
orc_cu_2b|Chamador de Espíritos|2|orc_cu_1|orc|invocador|sombra|40|B
orc_cu_3b|Domador de Almas|3|orc_cu_2b|orc|invocador|sombra|76|B
dw_l|Guerreiro Anão|0||anao|artesao|terra|1|A
dw_qe_1|Quebra-Escudos|1|dw_l|anao|guerreiro|terra|20|A
dw_qe_2|Martelo de Guerra|2|dw_qe_1|anao|guerreiro|terra|40|A
dw_qe_3|Senhor da Montanha|3|dw_qe_2|anao|guerreiro|terra|76|A
dw_fo_1|Forjador de Runas|1|dw_l|anao|artesao|terra|20|A
dw_fo_2|Mestre Rúnico|2|dw_fo_1|anao|artesao|terra|40|A
dw_fo_3|Grão-Forjador|3|dw_fo_2|anao|artesao|terra|76|A
dw_co_1|Coletor|1|dw_l|anao|artesao|terra|20|A
dw_co_2|Prospector|2|dw_co_1|anao|artesao|terra|40|A
dw_co_3|Mestre Minerador|3|dw_co_2|anao|artesao|terra|76|A
dw_qe_2b|Caçador de Recompensas|2|dw_qe_1|anao|adaga|terra|40|B
dw_qe_3b|Buscador de Fortuna|3|dw_qe_2b|anao|adaga|terra|76|B
dw_fo_2b|Engenheiro de Guerra|2|dw_fo_1|anao|invocador|raio|40|B
dw_fo_3b|Mestre dos Autômatos|3|dw_fo_2b|anao|invocador|raio|76|B
dw_co_2b|Explorador das Profundezas|2|dw_co_1|anao|artesao|fogo|40|B
dw_co_3b|Senhor das Galerias|3|dw_co_2b|anao|artesao|fogo|76|B
bst_l|Instinto Selvagem|0||beastman|monge|terra|1|A
bst_cs_1|Caçador Selvagem|1|bst_l|beastman|monge|terra|20|A
bst_cs_2|Garra Alfa|2|bst_cs_1|beastman|monge|terra|40|A
bst_cs_3|Rei da Matilha|3|bst_cs_2|beastman|monge|terra|76|A
bst_tq_1|Pele de Ferro|1|bst_l|beastman|tanque|terra|20|A
bst_tq_2|Guardião da Matilha|2|bst_tq_1|beastman|tanque|terra|40|A
bst_tq_3|Colosso Selvagem|3|bst_tq_2|beastman|tanque|terra|76|A
bst_m|Vidente da Tribo|0||beastman|xama|terra|1|A
bst_dr_1|Druida da Fera|1|bst_m|beastman|xama|terra|20|A
bst_dr_2|Espírito Uivante|2|bst_dr_1|beastman|xama|terra|40|A
bst_dr_3|Arquidruida|3|bst_dr_2|beastman|xama|terra|76|A
bst_cu_1|Curandeiro Tribal|1|bst_m|beastman|curandeiro|terra|20|A
bst_cu_2|Guardião dos Ritos|2|bst_cu_1|beastman|curandeiro|terra|40|A
bst_cu_3|Voz da Lua|3|bst_cu_2|beastman|curandeiro|terra|76|A
bst_cs_2b|Presa Furtiva|2|bst_cs_1|beastman|adaga|vento|40|B
bst_cs_3b|Sombra da Matilha|3|bst_cs_2b|beastman|adaga|vento|76|B
bst_tq_2b|Fúria Bestial|2|bst_tq_1|beastman|guerreiro|fogo|40|B
bst_tq_3b|Besta Primordial|3|bst_tq_2b|beastman|guerreiro|fogo|76|B
bst_dr_2b|Domador de Feras|2|bst_dr_1|beastman|invocador|terra|40|B
bst_dr_3b|Senhor das Feras|3|bst_dr_2b|beastman|invocador|terra|76|B
bst_cu_2b|Xamã da Lua Cheia|2|bst_cu_1|beastman|curandeiro|luz|40|B
bst_cu_3b|Olho dos Dois Luares|3|bst_cu_2b|beastman|curandeiro|luz|76|B
drc_l|Cria do Dragão|0||draconato|guerreiro|fogo|1|A
drc_ln_1|Lanceiro Dracônico|1|drc_l|draconato|guerreiro|fogo|20|A
drc_ln_2|Cavaleiro Escamado|2|drc_ln_1|draconato|guerreiro|fogo|40|A
drc_ln_3|Dragão Lanceiro|3|drc_ln_2|draconato|guerreiro|fogo|76|A
drc_tq_1|Escama de Ferro|1|drc_l|draconato|tanque|fogo|20|A
drc_tq_2|Baluarte Dracônico|2|drc_tq_1|draconato|tanque|fogo|40|A
drc_tq_3|Muralha Ancestral|3|drc_tq_2|draconato|tanque|fogo|76|A
drc_m|Acólito da Chama|0||draconato|xama|fogo|1|A
drc_sp_1|Sacerdote do Sopro|1|drc_m|draconato|xama|fogo|20|A
drc_sp_2|Arauto das Chamas|2|drc_sp_1|draconato|xama|fogo|40|A
drc_sp_3|Sopro Primordial|3|drc_sp_2|draconato|xama|fogo|76|A
drc_mg_1|Piromante|1|drc_m|draconato|mago|fogo|20|A
drc_mg_2|Mago do Magma|2|drc_mg_1|draconato|mago|fogo|40|A
drc_mg_3|Senhor do Inferno|3|drc_mg_2|draconato|mago|fogo|76|A
drc_ln_2b|Lâmina Escamada|2|drc_ln_1|draconato|guerreiro|raio|40|B
drc_ln_3b|Asa de Guerra|3|drc_ln_2b|draconato|guerreiro|raio|76|B
drc_tq_2b|Guardião do Ninho|2|drc_tq_1|draconato|tanque|terra|40|B
drc_tq_3b|Escudo do Primeiro Dragão|3|drc_tq_2b|draconato|tanque|terra|76|B
drc_sp_2b|Sacerdote da Tempestade|2|drc_sp_1|draconato|xama|raio|40|B
drc_sp_3b|Sopro do Trovão|3|drc_sp_2b|draconato|xama|raio|76|B
drc_mg_2b|Mago do Relâmpago|2|drc_mg_1|draconato|mago|raio|40|B
drc_mg_3b|Senhor dos Céus Rubros|3|drc_mg_2b|draconato|mago|raio|76|B
gig_l|Filho do Gelo|0||gigante|guerreiro|gelo|1|A
gig_gg_1|Guardião Glacial|1|gig_l|gigante|tanque|gelo|20|A
gig_gg_2|Muralha de Gelo|2|gig_gg_1|gigante|tanque|gelo|40|A
gig_gg_3|Colosso do Inverno|3|gig_gg_2|gigante|tanque|gelo|76|A
gig_gr_1|Quebra-Geleiras|1|gig_l|gigante|guerreiro|gelo|20|A
gig_gr_2|Avalanche|2|gig_gr_1|gigante|guerreiro|gelo|40|A
gig_gr_3|Fúria do Norte|3|gig_gr_2|gigante|guerreiro|gelo|76|A
gig_m|Vidente do Gelo|0||gigante|xama|gelo|1|A
gig_rn_1|Runista do Inverno|1|gig_m|gigante|xama|gelo|20|A
gig_rn_2|Senhor da Nevasca|2|gig_rn_1|gigante|xama|gelo|40|A
gig_rn_3|Arauto do Gelo Eterno|3|gig_rn_2|gigante|xama|gelo|76|A
gig_cu_1|Guardião da Aurora Boreal|1|gig_m|gigante|curandeiro|gelo|20|A
gig_cu_2|Luz do Norte|2|gig_cu_1|gigante|curandeiro|gelo|40|A
gig_cu_3|Coração Glacial|3|gig_cu_2|gigante|curandeiro|gelo|76|A
gig_gg_2b|Escudo da Nevasca|2|gig_gg_1|gigante|tanque|agua|40|B
gig_gg_3b|Bastião Polar|3|gig_gg_2b|gigante|tanque|agua|76|B
gig_gr_2b|Lanceiro Glacial|2|gig_gr_1|gigante|guerreiro|vento|40|B
gig_gr_3b|Ponta do Inverno|3|gig_gr_2b|gigante|guerreiro|vento|76|B
gig_rn_2b|Tecelão de Runas|2|gig_rn_1|gigante|xama|raio|40|B
gig_rn_3b|Mestre das Runas Frias|3|gig_rn_2b|gigante|xama|raio|76|B
gig_cu_2b|Cantor da Aurora|2|gig_cu_1|gigante|curandeiro|luz|40|B
gig_cu_3b|Voz da Aurora Eterna|3|gig_cu_2b|gigante|curandeiro|luz|76|B
$d$, E'\n')) l where l <> '') s
on conflict (id) do update set nome = excluded.nome, rank = excluded.rank, pai = excluded.pai, raca = excluded.raca, arquetipo = excluded.arquetipo, elemento = excluded.elemento, nivel = excluded.nivel, caminho = excluded.caminho;
-- a coluna characters.class_id aponta para game.classes: os caminhos B entram lá também
insert into game.classes (id, name, race, type, rank, parent, arch, bonus)
select v.id, v.nome, v.raca, case when (game.cadeia_v2(v.id))[1] like '%\_l' then 'l' else 'm' end, v.rank, v.pai, v.arquetipo, null
from game.classes_v2 v where not exists (select 1 from game.classes c where c.id = v.id) order by v.rank;
