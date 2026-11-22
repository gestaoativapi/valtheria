-- Habilidades do banco novo (1.193), uma linha por classe: classe|rank|tokens.
-- Token = sufixo + tipo + nível máximo; tipo a = ativa, A = ativa com livro, p = passiva, P = passiva com livro.
-- Os níveis de personagem e os custos (PH e aurum) saem das mesmas fórmulas de ferramentas/gerar_classes_v2.py
-- (conferido: soma de PH, aurum e níveis idêntica ao data/classes_v2.json).
with linhas as (select string_to_array(l, '|') p from unnest(string_to_array($d$hum_l|0|b1a9 b2a5 b3a5 b4p9 b5p9 raca1p16 raca2p16
hum_tq_1|1|s1a15 s2a3 s3a10 s4a5 s5p15 s6p15
hum_tq_2|2|s1a30 s2a10 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
hum_tq_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
hum_gr_1|1|s1a20 s2a15 s3a10 s4a5 s5p15 s6p15
hum_gr_2|2|s1a30 s2a20 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
hum_gr_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
hum_aq_1|1|s1a20 s2a15 s3a10 s4a5 s5p15 s6p15
hum_aq_2|2|s1a30 s2a30 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
hum_aq_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
hum_m|0|b1a9 b2a9 b3a5 b4p9 b5p9 raca1p16 raca2p16
hum_mg_1|1|s1a25 s2a15 s3a10 s4a10 s5p15 s6p15
hum_mg_2|2|s1a30 s2a30 s3a20 s4a10 s5a5 s6p30 s7P20 s8p20
hum_mg_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
hum_cu_1|1|s1a25 s2a15 s3a10 s4a3 s5p15 s6p15
hum_cu_2|2|s1a30 s2A10 s3a15 s4a5 s5a5 s6p30 s7p20 s8p20
hum_cu_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
hum_tq_2b|2|s1a30 s2a10 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
hum_tq_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
hum_gr_2b|2|s1a30 s2a20 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
hum_gr_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
hum_aq_2b|2|s1a30 s2a20 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
hum_aq_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
hum_mg_2b|2|s1A20 s2a20 s3a20 s4a10 s5a5 s6p30 s7P20 s8p20
hum_mg_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
hum_cu_2b|2|s1a15 s2a10 s3a20 s4a10 s5a15 s6p30 s7P20 s8p20
hum_cu_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
elf_l|0|b1a9 b2a5 b3a5 b4p9 b5p9 raca1p16 raca2p16
elf_aq_1|1|s1a20 s2a15 s3a10 s4a5 s5p15 s6p15
elf_aq_2|2|s1a30 s2a30 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
elf_aq_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
elf_tq_1|1|s1a15 s2a3 s3a10 s4a5 s5p15 s6p15
elf_tq_2|2|s1a30 s2a10 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
elf_tq_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
elf_ad_1|1|s1a20 s2a15 s3a5 s4a10 s5p15 s6p15
elf_ad_2|2|s1a30 s2a20 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
elf_ad_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
elf_m|0|b1a9 b2a9 b3a5 b4p9 b5p9 raca1p16 raca2p16
elf_cu_1|1|s1a25 s2a15 s3a10 s4a3 s5p15 s6p15
elf_cu_2|2|s1a30 s2A10 s3a15 s4a5 s5a5 s6p30 s7p20 s8p20
elf_cu_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
elf_mg_1|1|s1a25 s2a15 s3a10 s4a10 s5p15 s6p15
elf_mg_2|2|s1a30 s2a30 s3a20 s4a10 s5a5 s6p30 s7P20 s8p20
elf_mg_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
elf_aq_2b|2|s1a30 s2a30 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
elf_aq_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
elf_tq_2b|2|s1a30 s2a20 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
elf_tq_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
elf_ad_2b|2|s1a30 s2a20 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
elf_ad_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
elf_cu_2b|2|s1a30 s2A10 s3a15 s4a5 s5a5 s6p30 s7p20 s8p20
elf_cu_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
elf_mg_2b|2|s1A20 s2a20 s3a20 s4a10 s5a5 s6p30 s7P20 s8p20
elf_mg_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
de_l|0|b1a9 b2a5 b3a5 b4p9 b5p9 raca1p16 raca2p16
de_ad_1|1|s1a20 s2a15 s3a5 s4a10 s5p15 s6p15
de_ad_2|2|s1a30 s2a20 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
de_ad_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
de_tq_1|1|s1a15 s2a3 s3a10 s4a5 s5p15 s6p15
de_tq_2|2|s1a30 s2a10 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
de_tq_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
de_aq_1|1|s1a20 s2a15 s3a10 s4a5 s5p15 s6p15
de_aq_2|2|s1a30 s2a30 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
de_aq_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
de_m|0|b1a9 b2a9 b3a5 b4p9 b5p9 raca1p16 raca2p16
de_mg_1|1|s1a25 s2a15 s3a10 s4a10 s5p15 s6p15
de_mg_2|2|s1a30 s2a30 s3a20 s4a10 s5a5 s6p30 s7P20 s8p20
de_mg_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
de_xa_1|1|s1a20 s2a10 s3a10 s4a10 s5p15 s6p15
de_xa_2|2|s1a15 s2a10 s3a20 s4a10 s5a15 s6p30 s7P20 s8p20
de_xa_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
de_ad_2b|2|s1a30 s2a20 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
de_ad_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
de_tq_2b|2|s1a30 s2a10 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
de_tq_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
de_aq_2b|2|s1a30 s2a30 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
de_aq_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
de_mg_2b|2|s1a30 s2a30 s3a20 s4a10 s5a5 s6p30 s7P20 s8p20
de_mg_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
de_xa_2b|2|s1a30 s2A10 s3a15 s4a5 s5a5 s6p30 s7p20 s8p20
de_xa_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
orc_l|0|b1a9 b2a5 b3a5 b4p9 b5p9 raca1p16 raca2p16
orc_gr_1|1|s1a20 s2a15 s3a10 s4a5 s5p15 s6p15
orc_gr_2|2|s1a30 s2a20 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
orc_gr_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
orc_mo_1|1|s1a20 s2a15 s3a5 s4a10 s5p15 s6p15
orc_mo_2|2|s1a30 s2a30 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
orc_mo_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
orc_m|0|b1a9 b2a9 b3a5 b4p9 b5p9 raca1p16 raca2p16
orc_xa_1|1|s1a20 s2a10 s3a10 s4a10 s5p15 s6p15
orc_xa_2|2|s1a15 s2a10 s3a20 s4a10 s5a15 s6p30 s7P20 s8p20
orc_xa_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
orc_cu_1|1|s1a25 s2a15 s3a10 s4a3 s5p15 s6p15
orc_cu_2|2|s1a30 s2A10 s3a15 s4a5 s5a5 s6p30 s7p20 s8p20
orc_cu_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
orc_gr_2b|2|s1a30 s2a20 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
orc_gr_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
orc_mo_2b|2|s1a30 s2a30 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
orc_mo_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
orc_xa_2b|2|s1a15 s2a10 s3a20 s4a10 s5a15 s6p30 s7P20 s8p20
orc_xa_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
orc_cu_2b|2|s1A20 s2a20 s3a20 s4a10 s5a5 s6p30 s7P20 s8p20
orc_cu_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
dw_l|0|b1a9 b2a5 b3a5 b4p9 b5p9 raca1p16 raca2p16
dw_qe_1|1|s1a20 s2a15 s3a10 s4a5 s5p15 s6p15
dw_qe_2|2|s1a30 s2a20 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
dw_qe_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
dw_fo_1|1|s1a20 s2a15 s3p10 s4p10 s5p15 s6p15
dw_fo_2|2|s1a30 s2a15 s3P15 s4p15 s5a5 s6p30 s7p20 s8p15
dw_fo_3|3|s1A3 s2P5 s3A3 s4p5 s5p5
dw_co_1|1|s1a20 s2a15 s3p10 s4p10 s5p15 s6p15
dw_co_2|2|s1a30 s2a15 s3P15 s4p15 s5a5 s6p30 s7p20 s8p15
dw_co_3|3|s1A3 s2P5 s3A3 s4p5 s5p5
dw_qe_2b|2|s1a30 s2a20 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
dw_qe_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
dw_fo_2b|2|s1A20 s2a20 s3a20 s4a10 s5a5 s6p30 s7P20 s8p20
dw_fo_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
dw_co_2b|2|s1a30 s2a15 s3P15 s4p15 s5a5 s6p30 s7p20 s8p15
dw_co_3b|3|s1A3 s2P5 s3A3 s4p5 s5p5
bst_l|0|b1a9 b2a5 b3a5 b4p9 b5p9 raca1p16 raca2p16
bst_cs_1|1|s1a20 s2a15 s3a5 s4a10 s5p15 s6p15
bst_cs_2|2|s1a30 s2a30 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
bst_cs_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
bst_tq_1|1|s1a15 s2a3 s3a10 s4a5 s5p15 s6p15
bst_tq_2|2|s1a30 s2a10 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
bst_tq_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
bst_m|0|b1a9 b2a9 b3a5 b4p9 b5p9 raca1p16 raca2p16
bst_dr_1|1|s1a20 s2a10 s3a10 s4a10 s5p15 s6p15
bst_dr_2|2|s1a15 s2a10 s3a20 s4a10 s5a15 s6p30 s7P20 s8p20
bst_dr_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
bst_cu_1|1|s1a25 s2a15 s3a10 s4a3 s5p15 s6p15
bst_cu_2|2|s1a30 s2A10 s3a15 s4a5 s5a5 s6p30 s7p20 s8p20
bst_cu_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
bst_cs_2b|2|s1a30 s2a20 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
bst_cs_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
bst_tq_2b|2|s1a30 s2a20 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
bst_tq_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
bst_dr_2b|2|s1A20 s2a20 s3a20 s4a10 s5a5 s6p30 s7P20 s8p20
bst_dr_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
bst_cu_2b|2|s1a30 s2A10 s3a15 s4a5 s5a5 s6p30 s7p20 s8p20
bst_cu_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
drc_l|0|b1a9 b2a5 b3a5 b4p9 b5p9 raca1p16 raca2p16
drc_ln_1|1|s1a20 s2a15 s3a10 s4a5 s5p15 s6p15
drc_ln_2|2|s1a30 s2a20 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
drc_ln_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
drc_tq_1|1|s1a15 s2a3 s3a10 s4a5 s5p15 s6p15
drc_tq_2|2|s1a30 s2a10 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
drc_tq_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
drc_m|0|b1a9 b2a9 b3a5 b4p9 b5p9 raca1p16 raca2p16
drc_sp_1|1|s1a20 s2a10 s3a10 s4a10 s5p15 s6p15
drc_sp_2|2|s1a15 s2a10 s3a20 s4a10 s5a15 s6p30 s7P20 s8p20
drc_sp_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
drc_mg_1|1|s1a25 s2a15 s3a10 s4a10 s5p15 s6p15
drc_mg_2|2|s1a30 s2a30 s3a20 s4a10 s5a5 s6p30 s7P20 s8p20
drc_mg_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
drc_ln_2b|2|s1a30 s2a20 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
drc_ln_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
drc_tq_2b|2|s1a30 s2a10 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
drc_tq_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
drc_sp_2b|2|s1a15 s2a10 s3a20 s4a10 s5a15 s6p30 s7P20 s8p20
drc_sp_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
drc_mg_2b|2|s1a30 s2a30 s3a20 s4a10 s5a5 s6p30 s7P20 s8p20
drc_mg_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
gig_l|0|b1a9 b2a5 b3a5 b4p9 b5p9 raca1p16 raca2p16
gig_gg_1|1|s1a15 s2a3 s3a10 s4a5 s5p15 s6p15
gig_gg_2|2|s1a30 s2a10 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
gig_gg_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
gig_gr_1|1|s1a20 s2a15 s3a10 s4a5 s5p15 s6p15
gig_gr_2|2|s1a30 s2a20 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
gig_gr_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
gig_m|0|b1a9 b2a9 b3a5 b4p9 b5p9 raca1p16 raca2p16
gig_rn_1|1|s1a20 s2a10 s3a10 s4a10 s5p15 s6p15
gig_rn_2|2|s1a15 s2a10 s3a20 s4a10 s5a15 s6p30 s7P20 s8p20
gig_rn_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
gig_cu_1|1|s1a25 s2a15 s3a10 s4a3 s5p15 s6p15
gig_cu_2|2|s1a30 s2A10 s3a15 s4a5 s5a5 s6p30 s7p20 s8p20
gig_cu_3|3|s1A3 s2A3 s3A3 s4p5 s5p5
gig_gg_2b|2|s1a30 s2a10 s3a15 s4A10 s5a5 s6p30 s7p20 s8p20
gig_gg_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
gig_gr_2b|2|s1a30 s2a20 s3a20 s4A10 s5a5 s6p30 s7p20 s8p20
gig_gr_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
gig_rn_2b|2|s1a15 s2a10 s3a20 s4a10 s5a15 s6p30 s7P20 s8p20
gig_rn_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5
gig_cu_2b|2|s1a30 s2A10 s3a15 s4a5 s5a5 s6p30 s7p20 s8p20
gig_cu_3b|3|s1A3 s2A3 s3A3 s4p5 s5p5$d$, E'\n')) l where l <> ''),
toks as (select p[1] cid, p[2]::int r, t from linhas, unnest(string_to_array(p[3], ' ')) t),
sk as (select cid, r, m[1] kind, m[2]::int k, m[3] f, m[4]::int n from toks, regexp_match(t, '^([a-z]+)([0-9]+)([aApP])([0-9]+)$') m),
lim as (select *, case when kind = 'b' then 1 + (k - 1) * 3 when kind = 'raca' then 1 + (k - 1) * 4
                       else (array[1, 20, 40, 76])[r + 1] + least((k - 1) * 2, case when r < 3 then 12 else 3 end) end as l0,
                  case when kind = 'b' then 39 when kind = 'raca' then 80 else (array[0, 74, 79, 80])[r + 1] end as lf from sk)
insert into game.skills_v2 (id, class_id, nome, ativa, nivel_max, livro, rank, tabela)
select cid || '_' || kind || k, cid, null, f in ('a', 'A'), n, f in ('A', 'P'), r,
  (select jsonb_agg(jsonb_build_object('n', i + 1, 'lv', lv, 'ph', ph, 'au', round(ph * 0.6 / 10) * 10) order by i)
     from (select i, lv, round((35 * power(lv::float8, 1.55) * (1 + 0.15 * r) * (case when f in ('a', 'A') then 1.0 else 0.8 end))::numeric / 10) * 10 as ph
             from (select i, case when n <= 1 then l0 else least(lf, (case when x - floor(x) = 0.5 then floor(x) + (floor(x)::int % 2) else floor(x + 0.5) end)::int) end as lv
                     from generate_series(0, n - 1) i, lateral (select l0 + greatest(1.0, (lf - l0)::float8 / greatest(n - 1, 1)) * i as x) xx) a) b)
from lim
on conflict (id) do update set ativa = excluded.ativa, nivel_max = excluded.nivel_max, livro = excluded.livro, rank = excluded.rank, tabela = excluded.tabela;
