# VALTHERIA — Pipeline de Produção 3D

Este documento diz **como** cada tipo de asset é produzido. Os números de triângulos, texturas e nomes estão no `VALTHERIA_PADRAO_TECNICO_ASSETS.md`. A ordem e o prazo estão no `VALTHERIA_PLANO_PROTOTIPOS.md`.

---

## 1. Ferramentas e fontes avaliadas

Regra: **um asset só é livre se a licença estiver escrita na fonte e conferida.** Estar disponível para download não basta.

| Ferramenta / fonte | Finalidade | Vantagens | Limitações | Licença | Custo / créditos | Uso comercial | Atribuição |
|---|---|---|---|---|---|---|---|
| **Blender** (5.x) | Modelagem, UV, pesos, ajuste, exportação glTF, render de prancha | Completo; já instalado no ambiente (bpy 5.3) | Exige trabalho manual para escultura e pintura | GPL (o programa); o que você cria é seu | Gratuito | Sim | Não |
| **Godot 4.7.2** | Motor; importação, LOD automático, compressão, medição | Já é o motor do jogo; gera LOD na importação | Sem oclusão automática: precisa de `OccluderInstance3D` | MIT | Gratuito | Sim | Aviso de licença do motor |
| **MPFB2** | Gerar corpos humanos com proporção real e pesos | Corpos e rostos variados por parâmetros; já ligado ao esqueleto do jogo na V2 | Base humana: raças não humanas precisam de modelagem extra (orelhas, presas, focinho) | Código GPL (usado só como ferramenta, fora do jogo); saídas sem reivindicação | Gratuito | Sim | Não |
| **MakeHuman system assets** | Peles, olhos, sobrancelhas, cílios, cabelos, roupas base | **CC0 conferido em todos os 94 itens** (página e arquivos) | Roupas modernas; precisam ser repintadas ou remodeladas para fantasia | CC0 | Gratuito | Sim | Não (registramos por boa prática) |
| **Quaternius** | Personagens, animações, criaturas, cenário (já no jogo) | CC0; mesmo esqueleto de 65 ossos | Estilo mais simples que a direção atual | CC0 | Gratuito | Sim | Não |
| **Poly Haven** | Texturas PBR, HDRIs, alguns modelos | Qualidade alta, CC0 | Texturas realistas: precisam de ajuste de cor para o estilo | CC0 | Gratuito | Sim | Não |
| **ambientCG** | Texturas PBR de repetição | CC0, grande variedade (pedra, madeira, telha, solo) | Igual ao Poly Haven | CC0 | Gratuito | Sim | Não |
| **Fontes CC BY 4.0** (ex.: modelos avulsos de repositórios) | Peças específicas | Variedade | **Atribuição obrigatória** em cada uso; conferir autor e versão da licença item a item | CC BY 4.0 | Gratuito | Sim | **Sim** |
| **Meshy** | Gerar malha + textura a partir de imagem de conceito | Rápido para formas orgânicas (criaturas, cabeças de raça, armas ornamentadas) | Malha densa e irregular; precisa de redução, UV e ligação ao esqueleto (já feito nos anões) | Plano grátis: **CC BY 4.0**; planos pagos: privado | Grátis: 100 créditos/mês. Pago a partir de US$ 20/mês (Pro, 1.000 créditos). Imagem→3D: 20–25 créditos; textura IA: 10 créditos | Sim (grátis com atribuição) | Grátis: sim; pago: não |
| **Geração de imagem por IA** (conceito 2D) | Pranchas de conceito, referência de cor | Rápido para explorar opções | Só referência: nunca vai para o jogo como modelo; não pedir "no estilo de" obras | Conforme a ferramenta | Conforme a ferramenta | Sim, se a ferramenta permitir | Conforme a ferramenta |
| **Instant Meshes** | Retopologia automática (malha de quadrados) | Bom para limpar malha do Meshy | Resultado precisa de ajuste | BSD | Gratuito | Sim | Não |
| **Remesh/Decimate do Blender + otimizador do Godot** | Redução de triângulos e LOD | Já disponíveis | Pode deformar rostos se exagerar | — | Gratuito | Sim | Não |
| **Rigify** (dentro do Blender) | Rig de criatura própria (quadrúpede, aranha, dragão) | Gera controles de animação | Exportar para o jogo exige "achatar" o rig | GPL (ferramenta) | Gratuito | Sim | Não |
| **Mixamo** (Adobe) | Animações humanas prontas | Muitas animações de combate | Esqueleto diferente: exige redirecionamento (retarget) para os 65 ossos; termos da Adobe proíbem redistribuir os arquivos brutos | Termos próprios da Adobe | Gratuito com conta Adobe | Sim, dentro do jogo | Não |
| **Material Maker** | Texturas procedurais (pedra, madeira, metal gasto) | Gera variações sem repetir foto | Curva de aprendizado | MIT | Gratuito | Sim | Não |
| **Krita** | Pintura de texturas e retoque | Pintura à mão do estilo "pintado" | Manual | GPL (programa) | Gratuito | Sim | Não |

**Conclusão de custo:** tudo o que é necessário para os protótipos pode ser feito **sem gasto**, com Blender, MPFB2, MakeHuman CC0, Quaternius CC0, Poly Haven/ambientCG CC0 e trabalho próprio. O Meshy só se justifica onde a forma orgânica é complexa e o tempo de modelagem manual seria grande: cabeças de raça (homem-fera, orc), criaturas e guardiões. Mesmo nesses casos, o plano grátis gera saída CC BY 4.0. Isso é aceitável, como já acontece nos anões, mas exige atribuição.

**Orçamento Meshy, só para análise (nada será usado sem autorização):**

| Uso | Gerações estimadas, contando retrabalho | Créditos | Cabe no plano grátis (100/mês)? |
|---|---|---|---|
| 1 criatura comum (protótipo 6) | 2 imagem→3D + 1 textura | 50–60 | Sim |
| 1 monstro grande (protótipo 7) | 2–3 imagem→3D + 1 textura | 50–85 | Sim, num mês sem outro uso |
| 1 guardião (protótipo 8) | 3 imagem→3D + 2 texturas | 80–95 | No limite |
| Cabeças de 3 raças (homem-fera, orc, elfo) | 3–6 imagem→3D | 60–150 | Exige 2 meses ou o plano Pro |

---

## 2. Pipeline de personagem (validado em parte na V2)

| Etapa | O que se faz | Ferramenta | Situação |
|---|---|---|---|
| 1. Anatomia e proporções | Corpo por parâmetros (gênero, idade, músculo, peso, proporção) e altura-alvo (1,80 / 1,68 m) | MPFB2 | **Feito** (V2) |
| 2. Cabeça e rosto | Variações de formato por parâmetros do MPFB (queixo, nariz, olhos, maçãs) → 4 rostos por gênero, que alimentam o `look.face` que o servidor já guarda | MPFB2 | A fazer |
| 3. Tons de pele | Peles CC0 (jovem, meia-idade, idoso; vários tons) + tinta por raça (a paleta de pele de cada raça já está no `world.json`) | MakeHuman CC0 + shader de tinta | Feito em parte (prova de 14/11) |
| 4. Olhos | Malha low-poly + 9 cores CC0 → escolha do jogador | MakeHuman CC0 | Feito em parte |
| 5. Sobrancelhas | 12 formatos CC0, tingidos com a cor do cabelo (como hoje) | MakeHuman CC0 | Feito em parte |
| 6. Cabelos | 9 cabelos CC0 + os 8 atuais; trancados e coques novos para anões e orcs (modelagem própria) | MakeHuman CC0 + Blender | Feito em parte |
| 7. Texturas | Base CC0 **repintada** para o estilo "pintado": mais contraste de forma, menos detalhe fotográfico; normal + cor 1024² | Krita, Blender | A fazer |
| 8. Roupas | Malhas CC0 (camisa, calça, sapato) **remodeladas e repintadas**: túnica, calça, botas, cinto, capa em linho, lã e couro, na cor da cultura (até 25% da roupa, regra do Guia V1) | Blender + Krita | A fazer (as atuais são modernas) |
| 9. Armaduras | 4 peças por conjunto (peito, braços, pernas, cabeça) sobre o mesmo corpo; graus por material (ferro → aço → bronze → prata → ouro envelhecido → platina) | Blender (modelagem própria); Meshy opcional para ornamentos | A fazer |
| 10. Acessórios | Cinto, bolsa, capa, ombreira, joias de grau | Blender | A fazer |
| 11. Rig e pesos | Corpo e peças ligados aos 65 ossos (`ligar_esqueleto.py`); peças recebem pesos do corpo por transferência | Python + Blender | Corpo feito; peças a fazer (o script precisa aceitar várias malhas e texturas) |
| 12. Compatibilidade com animações | Medição de deformação nas 28 animações (`deformacao.py`), comparando com o corpo atual | Python | Feito para o corpo nu; a fazer com roupa |
| 13. Integração no Godot | Branch de teste: o personagem V3 montado pelo mesmo `character.gd`, atrás de uma opção de teste. **Sem substituir** os arquivos oficiais | Godot | A fazer |
| 14. Testes visuais e técnicos | Prancha frente/lado/costas; 28 animações; benchmark de 20 e 40 personagens no notebook | Godot + notebook | Benchmark pronto (D42), falta a rodada no notebook |

### 2.1 Raças: ordem de produção

Não produzir as 8 ao mesmo tempo. A ordem valida a tecnologia primeiro e a identidade depois:

| Ordem | Raça | Por quê |
|---|---|---|
| 1 | **Humano (m/f)** | Base de proporção; valida pele, rosto, cabelo, roupa, armadura e animação de uma vez |
| 2 | **Elfo e Elfo Negro** | Mesmo corpo com ajuste de proporção + **orelhas** e rosto mais fino: valida "variação de raça sobre a base" com pouco custo |
| 3 | **Orc** | Valida peça facial própria (presas, mandíbula) e corpo mais largo sobre o mesmo esqueleto |
| 4 | **Homem-Fera** | O mais difícil: cabeça de animal, pelagem, cauda. Exige modelagem própria ou Meshy |
| 5 | **Gigante** | Escala grande: valida armaduras em tamanho maior |
| 6 | **Anão e Dragonita** | Já têm modelo próprio (Meshy); migram por último, quando o padrão de roupa trocável estiver definido |

---

## 3. Pipeline de equipamento

1. Conceito em 2D (prancha frente/lado + medidas em metros), feito à mão ou por IA só como referência.
2. Modelagem no Blender com o pivô na ponta do cabo e o comprimento real da tabela `GRIP`.
3. UV e textura 512²: metal pela paleta oficial; couro e madeira pelos orgânicos.
4. **Graus por variação, não por modelo novo:** o mesmo modelo recebe material e ornamento por grau. NG, D e C mudam o material; B, A e S somam ornamento (malha extra); R ganha brilho de runa.
5. Teste de encaixe nas 2 mãos, nas costas e na cintura, nas 8 raças e nos 2 gêneros.
6. Teste com as animações de arma (Sword_Attack, Sword_Regular_A/B/C, Sword_Block, Shield_*).

---

## 4. Pipeline de criatura

1. Ficha: anatomia, silhueta, escala, região, comportamento, efeito especial.
2. Conceito 2D com silhueta legível a 30 m.
3. Modelo: Quaternius (CC0) quando existir base adequada; modelagem própria ou Meshy quando não existir.
4. Rig próprio por família (Rigify) e animações mínimas: parado, andar, correr, atacar 1 e 2, receber golpe, morrer.
5. **Variação regional sem modelo novo:** cor, textura de detalhe (musgo, gelo, brasa), acessórios (chifres, placas) e escala.
6. Chefe = família + peças exclusivas + 1–2 animações exclusivas + efeito próprio.

---

## 5. Pipeline de ambiente

1. **Módulos em grade de 2 m** (paredes, cantos, portas, janelas, telhados, escadas, muralhas), para que `cidade.gd` troque as caixas por módulos **sem mudar o desenho das cidades**.
2. Kit por cultura: mesmos módulos com materiais e ornamentos diferentes (humano: pedra clara e telha; élfico: madeira clara e folha; anão: pedra escura e metal; orc: madeira bruta e couro).
3. Texturas de repetição compartilhadas (CC0), com variação por tinta de vértice e decalques (sujeira, musgo) para não parecer repetido.
4. Vegetação: 3 tamanhos por espécie, LOD e impostor; dispersão pelo `splat` e pela região, como hoje.
5. Iluminação por região: cor do sol, névoa e céu já vêm de `atmos.gd`; criar perfis por região.
6. Oclusão: `OccluderInstance3D` nas muralhas e prédios grandes (ganho estimado no doc 09: −20% de triângulos nas cidades).
