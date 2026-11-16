# VALTHERIA — A ÁRVORE DOS MIL MUNDOS
# PROJETO VISUAL MESTRE E DIRETRIZES DE GAMEPLAY

**Versão:** 1.0  
**Documento:** Direção Artística, Mundo, Personagens, Equipamentos, Interface e Jogabilidade  
**Cliente principal:** Godot 4.7.2  
**Linguagem:** GDScript  
**Backend:** Supabase  
**Cliente de referência:** Three.js r170  
**Estilo visual oficial:** Fantasia semi-realista  
**Câmera oficial:** Terceira pessoa  
**Estratégia:** Evolução integral e incremental do projeto existente

---

# 1. VISÃO GERAL

## 1.1. Conceito

Valtheria — A Árvore dos Mil Mundos é um MMORPG de fantasia com universo próprio, exploração de mundo aberto, personagens personalizáveis, diferentes raças, classes, equipamentos, combate, missões, cidades, masmorras e narrativa progressiva.

O objetivo visual é construir um universo fantástico imersivo, com identidade própria e qualidade artística consistente.

O jogador deverá sentir que está explorando um mundo vivo, com regiões distintas, civilizações, criaturas, mistérios e acontecimentos que se relacionam com a história principal.

## 1.2. Direção visual oficial

A direção artística será:

**SEMI-REALISTA FANTÁSTICA.**

Características:

- Personagens com anatomia estilizada e proporções coerentes.
- Rosto e expressões bem definidos.
- Armaduras com detalhes de materiais e acabamento.
- Armas com silhuetas marcantes.
- Cenários ricos em vegetação e elementos arquitetônicos.
- Iluminação cinematográfica.
- Texturas detalhadas, sem excesso de ruído visual.
- Efeitos mágicos elegantes e legíveis.
- Cores e atmosferas próprias de cada região.

Evitar:
- Aparência excessivamente infantil.
- Estilo cartunesco exagerado.
- Personagens com proporções inconsistentes.
- Equipamentos genéricos e repetitivos.
- Excesso de partículas.
- Ambientes vazios.
- Mistura de estilos artísticos incompatíveis.

## 1.3. Referência de qualidade

Buscar a qualidade visual de MMORPGs modernos de fantasia, mas sem copiar personagens, mapas, equipamentos, interfaces, marcas ou elementos protegidos de outros jogos.

Toda criação deve possuir identidade original do Valtheria.

---

# 2. REGRAS DE PRODUÇÃO E PRESERVAÇÃO

Estas regras prevalecem sobre qualquer instrução de implementação visual que possa comprometer o projeto existente.

1. Não reconstruir o jogo do zero.
2. Não apagar sistemas funcionais.
3. Não substituir modelos ou cenas sem verificar dependências.
4. Não criar recursos duplicados.
5. Não alterar a arquitetura principal sem justificativa técnica.
6. Preservar Godot 4.7.2 e GDScript como base do cliente principal.
7. Preservar o Supabase como backend.
8. Preservar o cliente Three.js r170 como referência.
9. Implementar melhorias de maneira incremental.
10. Documentar cada alteração.
11. Fazer testes antes de declarar qualquer etapa concluída.
12. Criar backups ou pontos de restauração antes de alterações estruturais.
13. Não utilizar recursos visuais fictícios como se já estivessem implementados.
14. Não substituir recursos existentes por imagens estáticas quando o objetivo for um recurso 3D funcional.
15. Não considerar uma imagem conceitual como modelo pronto para produção.

Antes de cada etapa, verificar o estado real do projeto.

---

# 3. MAPA-MÚNDI E GEOGRAFIA DE VALTHERIA

## 3.1. Objetivo

Desenvolver um mundo conectado, visualmente rico e geograficamente coerente.

O mapa deve apresentar:

- Continentes ou grandes massas territoriais.
- Regiões naturais.
- Cidades.
- Vilas.
- Castelos.
- Fortificações.
- Ruínas.
- Florestas.
- Montanhas.
- Rios.
- Lagos.
- Oceanos ou mares, quando previstos.
- Cavernas.
- Masmorras.
- Áreas especiais.
- Pontos relacionados à narrativa.

## 3.2. Auditoria do mapa atual

Antes de modificar a geografia, identificar:

- Dimensões reais do mundo.
- Quantidade de regiões.
- Quantidade de cidades.
- Coordenadas e posições.
- Estradas e conexões.
- Sistemas de navegação.
- Áreas carregadas dinamicamente.
- Limites do mapa.
- Recursos de terreno e vegetação.
- Pontos de interesse.

O diagnóstico anterior mencionou um mundo aproximado de 3 × 3 km e 15 cidades nativas. Esses dados são referências históricas e precisam ser confirmados na versão atual.

Não ampliar ou reduzir o mundo sem avaliar as consequências técnicas.

## 3.3. Organização territorial

Criar um catálogo oficial com:

| Identificação | Descrição |
|---|---|
| Região | Nome da região |
| Bioma | Característica natural |
| Cidade principal | Centro político ou econômico |
| Localidades | Vilas e assentamentos |
| Pontos de interesse | Locais de exploração |
| Criaturas | Fauna e monstros |
| Nível recomendado | Progressão sugerida |
| Missões | Conteúdos relacionados |
| Fragmento | Relação com a narrativa, quando aplicável |

## 3.4. Biomas

Planejar e auditar a presença dos seguintes ambientes:

### Florestas
- Árvores de diferentes tamanhos.
- Vegetação rasteira.
- Flores.
- Cogumelos.
- Raízes.
- Rochas.
- Pequenos animais.
- Iluminação filtrada.
- Áreas abertas e fechadas.

### Florestas mágicas
- Árvores antigas.
- Vegetação luminosa.
- Partículas discretas.
- Ruínas.
- Elementos relacionados ao Véu.
- Fontes de energia mágica.

### Montanhas
- Grandes formações rochosas.
- Penhascos.
- Trilhas.
- Passagens.
- Cavernas.
- Vegetação de altitude.
- Neve, quando aplicável.

### Regiões desérticas
- Dunas.
- Rochas.
- Ruínas antigas.
- Vegetação adaptada.
- Estruturas de civilizações antigas.
- Ambientes de exploração.

### Regiões geladas
- Neve.
- Gelo.
- Montanhas.
- Cavernas congeladas.
- Lagos.
- Estruturas antigas.
- Criaturas regionais.

### Regiões vulcânicas
- Rochas escuras.
- Formações vulcânicas.
- Iluminação quente.
- Ambientes perigosos.
- Cavernas e estruturas subterrâneas.

Os biomas acima são diretrizes de expansão artística. Não devem ser tratados como regiões já existentes sem confirmação.

## 3.5. Mapa ilustrado

Produzir uma representação visual do mapa de Valtheria em duas versões:

**Mapa de exploração:**
- Visão superior.
- Regiões identificadas.
- Cidades.
- Estradas.
- Pontos de interesse.
- Ícones.
- Áreas descobertas e não descobertas.

**Mapa artístico:**
- Representação ilustrada do mundo.
- Relevo.
- Montanhas.
- Florestas.
- Mares.
- Cidades.
- Elementos históricos.

Não utilizar o mapa artístico como substituto do mapa técnico de coordenadas do jogo.

## 3.6. Entregas

- Mapa-múndi.
- Mapa regional.
- Mapa das cidades.
- Catálogo dos biomas.
- Catálogo de pontos de interesse.
- Documento de conexão entre as regiões.
- Especificação técnica de implementação.

---

# 4. CIDADES E ARQUITETURA

## 4.1. Identidade das cidades

Cada cidade deve possuir personalidade própria.

Não utilizar o mesmo modelo arquitetônico repetidamente.

Cada localidade deve apresentar:

- Construções características.
- Materiais próprios.
- Ruas e caminhos.
- Áreas públicas.
- Comércio.
- NPCs.
- Elementos culturais.
- Vegetação.
- Iluminação.
- Sons ambientais.
- Pontos de interesse.

## 4.2. Categorias arquitetônicas

Desenvolver padrões para:

- Cidades humanas.
- Cidades élficas.
- Assentamentos anões.
- Fortalezas militares.
- Vilas comerciais.
- Vilas rurais.
- Ruínas antigas.
- Estruturas mágicas.
- Castelos.
- Postos avançados.

A relação entre cada arquitetura e as raças deve respeitar a história oficial.

## 4.3. Construções

Criar biblioteca modular de:

- Paredes.
- Telhados.
- Portas.
- Janelas.
- Escadas.
- Colunas.
- Muros.
- Pontes.
- Torres.
- Mobiliário.
- Elementos decorativos.

Os módulos devem permitir reutilização sem produzir cidades visualmente idênticas.

## 4.4. Elementos interativos

Quando compatível com os sistemas existentes:

- Portas.
- Baús.
- Bancadas.
- Estações de fabricação.
- NPCs.
- Pontos de coleta.
- Elevadores.
- Portais.
- Elementos de missão.

---

# 5. PERSONAGENS E RAÇAS

## 5.1. Objetivo

Criar personagens visualmente marcantes, com identidade própria e compatibilidade com equipamentos, animações e sistemas de progressão.

## 5.2. Auditoria

Catalogar as raças existentes, seus modelos, esqueletos, materiais, animações e recursos de personalização.

Não inventar uma lista definitiva de raças sem consultar os arquivos e a documentação narrativa.

## 5.3. Padrão de modelagem

Cada personagem deve apresentar:

- Anatomia coerente.
- Silhueta reconhecível.
- Rosto detalhado.
- Cabelos.
- Olhos.
- Vestimentas.
- Materiais.
- Texturas.
- Mãos e pés compatíveis com equipamentos.
- Esqueleto adequado para animações.
- Compatibilidade com armaduras.

## 5.4. Personalização

Avaliar a possibilidade de personalizar:

- Rosto.
- Cabelo.
- Cor dos cabelos.
- Olhos.
- Detalhes faciais.
- Vestimentas.
- Equipamentos.
- Acessórios.

A personalização deve respeitar os limites e as características de cada raça.

## 5.5. Animações

Definir padrão para:

- Idle.
- Caminhada.
- Corrida.
- Salto.
- Queda.
- Ataque básico.
- Ataques especiais.
- Defesa.
- Esquiva.
- Uso de habilidades.
- Interações.
- Coleta.
- Morte e retorno ao jogo.

As animações precisam ser compatíveis com o esqueleto e os estados reais do personagem.

## 5.6. Ficha de cada raça

Criar uma ficha individual contendo:

1. Nome.
2. História.
3. Origem.
4. Características.
5. Aparência.
6. Silhueta.
7. Altura relativa.
8. Proporções.
9. Animações.
10. Compatibilidade com equipamentos.
11. Classes disponíveis, conforme regras oficiais.

---

# 6. CLASSES E IDENTIDADE DE COMBATE

## 6.1. Objetivo

Estabelecer identidade visual e funcional para as classes.

Cada classe deve ser reconhecida pelo estilo de combate, equipamentos, animações e habilidades.

## 6.2. Elementos da classe

Documentar:

- Nome.
- Função.
- Estilo de combate.
- Armas.
- Armaduras.
- Atributos.
- Habilidades.
- Animações.
- Efeitos visuais.
- Progressão.
- Pontos fortes.
- Limitações.

## 6.3. Identidade visual

Exemplos de direções visuais, a validar com as classes existentes:

- Guerreiro: armaduras resistentes, armas de impacto e movimentos firmes.
- Mago: vestimentas arcanas, cajados e efeitos mágicos.
- Arqueiro: armaduras leves, arcos e movimentação ágil.
- Paladino: proteção, símbolos de luz e armas de combate.
- Assassino: equipamentos leves e silhueta discreta.
- Druida: materiais naturais, elementos orgânicos e magia da natureza.

Não adicionar classes somente por variedade. Avaliar primeiro a compatibilidade com o sistema de combate e progressão.

---

# 7. ARMAS, ARMADURAS E EQUIPAMENTOS

## 7.1. Identidade artística

Os equipamentos devem parecer produzidos por artesãos de um mundo de fantasia, com materiais, formas e detalhes coerentes.

Evitar modelos genéricos com simples alterações de cor.

## 7.2. Armas

Catalogar as categorias existentes e avaliar:

- Espadas.
- Espadas longas.
- Adagas.
- Machados.
- Martelos.
- Lanças.
- Arcos.
- Cajados.
- Escudos.
- Armas especiais.

As categorias são referências de design, não uma ordem para implementar todas.

## 7.3. Armaduras

Desenvolver padrões para:

- Capacetes.
- Peitorais.
- Ombreiras.
- Luvas.
- Braçadeiras.
- Calças.
- Botas.
- Escudos.
- Capas.
- Acessórios.

## 7.4. Materiais

Criar biblioteca visual para:

- Ferro.
- Aço.
- Prata.
- Ouro.
- Madeira.
- Couro.
- Pedra.
- Cristais.
- Materiais mágicos.
- Tecidos.
- Materiais raros.

## 7.5. Raridades

Definir uma hierarquia visual e funcional compatível com o sistema existente.

Cada nível de raridade poderá possuir:

- Cor de identificação.
- Acabamento.
- Ornamentação.
- Efeitos discretos.
- Ícone.
- Características de obtenção.

Não criar progressão econômica ou atributos sem avaliar o balanceamento existente.

## 7.6. Padrão dos modelos 3D

Cada item deve possuir:

- Modelo.
- Materiais.
- Texturas.
- Escala.
- Pivô correto.
- Orientação.
- Compatibilidade com o personagem.
- Ícone.
- Nome.
- Identificação interna.
- Integração com inventário.

## 7.7. Ícones

Criar ícones individuais, preferencialmente em PNG com fundo transparente quando apropriado.

Padrão recomendado:

- Item centralizado.
- Silhueta bem definida.
- Iluminação consistente.
- Sem texto.
- Sem logotipo.
- Sem moldura obrigatória.
- Leitura clara em tamanho reduzido.

O modelo 3D e o ícone devem representar o mesmo item.

---

# 8. MONSTROS, CRIATURAS E GUARDIÕES

## 8.1. Objetivo

Criar uma fauna fantástica coerente com as regiões e a narrativa.

## 8.2. Classificação

Organizar as criaturas em:

- Criaturas comuns.
- Criaturas regionais.
- Criaturas agressivas.
- Criaturas raras.
- Criaturas mágicas.
- Criaturas de masmorra.
- Chefes.
- Guardiões narrativos.

## 8.3. Ficha de criatura

Cada criatura deve possuir:

1. Nome.
2. Classificação.
3. Região.
4. História.
5. Modelo.
6. Silhueta.
7. Texturas.
8. Animações.
9. Comportamento.
10. Habilidades.
11. Nível ou dificuldade.
12. Recompensas.
13. Relação com missões.

## 8.4. Os seis fragmentos e guardiões

A narrativa prevê seis fragmentos e seus guardiões.

Cada guardião deverá possuir uma identidade visual exclusiva, com:

- Modelo 3D próprio.
- Silhueta monumental.
- Materiais específicos.
- Animações.
- Efeitos.
- Ambiente de encontro.
- Identidade sonora.
- Relação com o fragmento.
- Elementos narrativos.

Não definir antecipadamente a natureza ou os poderes dos seis guardiões sem conferir a bíblia narrativa.

---

# 9. CÂMERA E JOGABILIDADE

## 9.1. Câmera oficial

A câmera principal será em terceira pessoa.

O personagem deverá permanecer visível durante a exploração e o combate.

A câmera deve proporcionar:

- Visibilidade do personagem.
- Visão suficiente do ambiente.
- Controle de rotação.
- Distância ajustável, se compatível.
- Transições suaves.
- Controle de colisão.
- Boa leitura de combate.
- Compatibilidade com ambientes fechados e abertos.

## 9.2. Controles

Auditar os controles atuais antes de estabelecer um novo padrão.

Planejar suporte para:

- Teclado e mouse.
- Movimentação.
- Câmera.
- Seleção de alvo.
- Ataque.
- Habilidades.
- Interação.
- Inventário.
- Mapa.
- Menus.

Avaliar suporte a controle físico sem comprometer a experiência principal.

## 9.3. Exploração

A exploração deve envolver:

- Caminhos.
- Descobertas.
- Cidades.
- NPCs.
- Ruínas.
- Pontos secretos.
- Coleta.
- Missões.
- Criaturas.
- Ambientes interativos.

## 9.4. Combate

O combate deve possuir:

- Resposta imediata.
- Animações coerentes.
- Feedback visual.
- Feedback sonoro.
- Efeitos de impacto.
- Indicação de habilidades.
- Leitura clara dos alvos.
- Sincronização multiplayer.

As operações críticas devem ser validadas pelo servidor.

## 9.5. MMORPG

Auditar e planejar a integração de:

- Jogadores simultâneos.
- Grupos.
- Guildas.
- Comércio.
- Inventário.
- Missões.
- Progressão.
- Combate.
- Chefes.
- Eventos.
- Comunicação.
- Sincronização.

Não declarar suporte multiplayer como concluído apenas porque existem elementos visuais ou interfaces para isso.

---

# 10. INTERFACE E HUD

## 10.1. Identidade visual

A interface deve combinar:

- Fantasia medieval.
- Elementos ornamentais discretos.
- Materiais escuros.
- Detalhes metálicos.
- Tipografia legível.
- Ícones originais.
- Hierarquia visual clara.

Evitar excesso de elementos decorativos.

## 10.2. HUD principal

Planejar:

- Retrato do personagem.
- Nome.
- Nível.
- Barra de vida.
- Barra de energia ou recurso correspondente.
- Experiência.
- Habilidades.
- Atalhos.
- Minimapa.
- Indicadores de grupo.
- Missões.
- Mensagens.
- Informações contextuais.

Os elementos devem ser configuráveis e adaptáveis à resolução.

## 10.3. Inventário

Especificar:

- Grade de itens.
- Equipamentos.
- Categorias.
- Quantidades.
- Peso ou capacidade, se aplicável.
- Comparação de atributos.
- Informações de raridade.
- Ações disponíveis.
- Filtros e pesquisa.

## 10.4. Outras interfaces

Desenvolver especificações para:

- Criação de personagem.
- Seleção de personagem.
- Mapa-múndi.
- Mapa regional.
- Missões.
- Habilidades.
- Personagem e atributos.
- Comércio.
- Fabricação.
- Grupo.
- Guilda.
- Configurações.
- Login.
- Carregamento.

## 10.5. Consistência

Todas as telas devem utilizar uma biblioteca de componentes comum.

Botões, fontes, ícones, painéis, margens, cores e estados devem seguir um sistema visual unificado.

---

# 11. MAGIAS, VFX E ANIMAÇÕES

## 11.1. Direção artística

Os efeitos mágicos devem ser marcantes e elegantes.

Não podem comprometer a visibilidade dos jogadores ou a leitura do combate.

## 11.2. Categorias

Planejar:

- Magias ofensivas.
- Magias defensivas.
- Cura.
- Invocação.
- Efeitos elementais.
- Portais.
- Efeitos ambientais.
- Habilidades especiais.
- Efeitos de chefes.
- Efeitos narrativos.

## 11.3. Componentes

Cada efeito deverá possuir especificação de:

- Cor.
- Intensidade.
- Duração.
- Forma.
- Partículas.
- Animação.
- Som.
- Distância de visualização.
- Impacto no desempenho.

## 11.4. Animação e integração

Os efeitos devem estar conectados aos estados e eventos reais das habilidades.

Não utilizar apenas animações decorativas que não correspondam à mecânica executada.

---

# 12. ILUMINAÇÃO, CLIMA E AMBIENTAÇÃO

## 12.1. Iluminação

Desenvolver padrões para:

- Dia.
- Noite.
- Amanhecer.
- Entardecer.
- Ambientes internos.
- Ambientes subterrâneos.
- Áreas mágicas.
- Regiões especiais.

## 12.2. Atmosfera

Avaliar:

- Neblina.
- Sombras.
- Reflexos.
- Água.
- Vento.
- Vegetação.
- Partículas ambientais.
- Sons naturais.
- Variações de luz.

## 12.3. Coerência regional

Cada bioma deverá possuir atmosfera própria, sem que todas as regiões utilizem a mesma configuração de iluminação e ambiente.

---

# 13. DIRETRIZES TÉCNICAS PARA GODOT 4.7.2

## 13.1. Produção

A implementação visual deve respeitar a estrutura do projeto atual.

Auditar cenas, scripts, materiais, shaders, modelos e dependências antes de alterar qualquer recurso.

## 13.2. Modelos 3D

Avaliar:

- Formato dos arquivos.
- Escala.
- Orientação.
- Pivôs.
- Esqueleto.
- Animações.
- Materiais.
- Texturas.
- Colisões.
- Níveis de detalhe.

Utilizar formatos e configurações compatíveis com o pipeline real do projeto.

## 13.3. Recursos visuais

Organizar os recursos por categorias e identificadores consistentes.

Exemplo de organização conceitual:

```text
assets/
  characters/
    races/
    classes/
    animations/
  equipment/
    weapons/
    armor/
    accessories/
    icons/
  environments/
    biomes/
    cities/
    vegetation/
    props/
  creatures/
    common/
    elite/
    bosses/
    guardians/
  effects/
    magic/
    combat/
    environment/
  interface/
    hud/
    inventory/
    icons/
    menus/
  audio/
    ambient/
    combat/
    music/
```

Esta é uma sugestão de organização. Adaptar à estrutura existente, sem duplicar pastas ou mover recursos indiscriminadamente.

## 13.4. Shaders e materiais

Utilizar materiais coerentes e reutilizáveis.

Evitar criar materiais únicos sem necessidade.

Verificar compatibilidade, desempenho e qualidade de renderização no ambiente real do projeto.

## 13.5. Otimização

Avaliar:

- LOD.
- Frustum Culling.
- Occlusion Culling.
- Instanciação.
- Carregamento por regiões.
- Texturas.
- Sombras.
- Partículas.
- Memória.
- Processamento de scripts.

Não aplicar otimizações indiscriminadamente. Medir antes e depois.

---

# 14. PADRÃO DE PRODUÇÃO DE IMAGENS CONCEITUAIS

As imagens conceituais devem servir como referência para a produção.

## 14.1. Padrão visual

- Estilo semi-realista.
- Fantasia de alta qualidade.
- Materiais detalhados.
- Iluminação cinematográfica.
- Composição profissional.
- Identidade original.
- Coerência com a mitologia.
- Sem marcas de terceiros.

## 14.2. Tipos de imagens

Produzir separadamente:

1. Mapa-múndi.
2. Mapas regionais.
3. Cidades.
4. Biomas.
5. Personagens.
6. Raças.
7. Classes.
8. Armas.
9. Armaduras.
10. Criaturas.
11. Guardiões.
12. Magias.
13. Gameplay.
14. Interface.
15. Inventário.

## 14.3. Fichas de personagem

Para cada personagem importante, buscar:

- Vista frontal.
- Vista traseira.
- Vista lateral.
- Close do rosto.
- Equipamentos.
- Paleta de cores.
- Referência de materiais.

## 14.4. Fichas de equipamento

Para cada item:

- Vista principal.
- Detalhes.
- Materiais.
- Escala.
- Paleta de cores.
- Ícone.
- Versão equipada no personagem.

## 14.5. Fichas de ambiente

Para cada região:

- Visão panorâmica.
- Visão de exploração.
- Elementos arquitetônicos.
- Vegetação.
- Iluminação.
- Pontos de interesse.

---

# 15. PADRÃO DE QUALIDADE

Cada recurso visual deverá ser avaliado considerando:

| Critério | Avaliação |
|---|---|
| Identidade | Pertence ao universo de Valtheria? |
| Coerência | Combina com a região e a narrativa? |
| Qualidade | Apresenta acabamento adequado? |
| Integração | Funciona com os sistemas existentes? |
| Desempenho | É adequado ao ambiente de execução? |
| Consistência | Mantém o padrão visual do projeto? |
| Reutilização | Pode ser utilizado de maneira eficiente? |

Não considerar um recurso pronto apenas porque sua imagem conceitual foi aprovada.

---

# 16. ROADMAP DE PRODUÇÃO

A execução deverá ser incremental.

## FASE 0 — AUDITORIA

- Analisar o projeto.
- Catalogar recursos.
- Conferir sistemas.
- Mapear dependências.
- Identificar pendências.
- Identificar incompatibilidades.

**Resultado:** relatório técnico sem alterações destrutivas.

## FASE 1 — IDENTIDADE VISUAL

- Definir paleta de cores.
- Definir materiais.
- Definir padrões de modelagem.
- Definir padrões de iluminação.
- Definir identidade da interface.

**Resultado:** guia de identidade visual.

## FASE 2 — MUNDO E MAPA

- Mapear regiões.
- Catalogar cidades.
- Definir biomas.
- Organizar pontos de interesse.
- Especificar melhorias.

**Resultado:** documentação geográfica e ambiental.

## FASE 3 — PERSONAGENS E CRIATURAS

- Catalogar raças.
- Definir padrões de modelos.
- Revisar animações.
- Documentar criaturas.
- Documentar guardiões.

**Resultado:** catálogo de personagens e criaturas.

## FASE 4 — EQUIPAMENTOS

- Catalogar armas.
- Catalogar armaduras.
- Revisar ícones.
- Revisar materiais.
- Definir padrões de raridade.

**Resultado:** catálogo de equipamentos.

## FASE 5 — GAMEPLAY

- Revisar câmera.
- Revisar movimentação.
- Revisar combate.
- Revisar habilidades.
- Revisar integração multiplayer.

**Resultado:** especificação de gameplay.

## FASE 6 — INTERFACE

- HUD.
- Inventário.
- Mapa.
- Habilidades.
- Menus.
- Telas de personagem.

**Resultado:** guia de interface.

## FASE 7 — EFEITOS E AMBIENTAÇÃO

- Iluminação.
- Magias.
- Partículas.
- Animações.
- Sons.
- Atmosfera.

**Resultado:** biblioteca de efeitos.

## FASE 8 — INTEGRAÇÃO E OTIMIZAÇÃO

- Integrar recursos.
- Testar cenas.
- Validar animações.
- Medir desempenho.
- Corrigir problemas.
- Executar testes de regressão.

**Resultado:** relatório de integração.

---

# 17. PADRÃO DE EXECUÇÃO NO CLAUDE

Para cada tarefa, apresentar:

1. Objetivo.
2. Diagnóstico atual.
3. Recursos existentes.
4. Recursos necessários.
5. Arquivos envolvidos.
6. Dependências.
7. Proposta visual.
8. Proposta técnica.
9. Plano de implementação.
10. Critérios de aceitação.
11. Testes.
12. Resultado.

Classificar cada item como:

- EXISTENTE.
- EXISTENTE COM PENDÊNCIAS.
- NÃO IMPLEMENTADO.
- PROPOSTA.
- BLOQUEADO.
- CONCLUÍDO E VALIDADO.

Não confundir proposta com funcionalidade existente.

---

# 18. INSTRUÇÕES PARA PRODUÇÃO DE CONTEÚDO VISUAL

Quando solicitado a criar um novo recurso, seguir este fluxo:

**ETAPA A — ANÁLISE**

Verificar se o recurso já existe.

**ETAPA B — REFERÊNCIA**

Definir sua identidade visual e função no jogo.

**ETAPA C — ESPECIFICAÇÃO**

Informar dimensões, proporções, materiais, cores, animações e integração.

**ETAPA D — PRODUÇÃO**

Criar o recurso com o pipeline adequado.

**ETAPA E — INTEGRAÇÃO**

Integrar ao Godot e aos sistemas correspondentes.

**ETAPA F — VALIDAÇÃO**

Verificar funcionamento, qualidade e desempenho.

**ETAPA G — DOCUMENTAÇÃO**

Registrar arquivos, alterações e resultados.

---

# 19. PROMPT MESTRE DE EXECUÇÃO

Você está trabalhando no desenvolvimento de Valtheria — A Árvore dos Mil Mundos.

Este documento representa a direção visual e de gameplay oficial do projeto.

Sua missão é evoluir o jogo existente para atingir a qualidade e a identidade estabelecidas neste manual.

A direção visual oficial é fantasia semi-realista, com câmera em terceira pessoa.

A prioridade é o desenvolvimento completo e integrado do universo, abrangendo mundo, personagens, equipamentos, criaturas, combate, interface e ambientação.

Regras obrigatórias:

1. Leia este documento integralmente.
2. Consulte as Diretrizes Gerais do Projeto.
3. Consulte a Bíblia Narrativa.
4. Analise os arquivos existentes.
5. Não reconstruir o projeto.
6. Não apagar sistemas funcionais.
7. Não inventar informações sobre o estado atual.
8. Não criar dependências desnecessárias.
9. Não implementar grandes alterações sem diagnóstico.
10. Preservar a arquitetura Godot 4.7.2, GDScript e Supabase.
11. Preservar o cliente Three.js r170 como referência.
12. Trabalhar por etapas.
13. Validar os resultados.
14. Documentar todas as alterações.

## Primeira atividade

Realizar uma auditoria visual e técnica do projeto atual.

Apresentar:

- Recursos visuais existentes.
- Modelos de personagens.
- Modelos de criaturas.
- Armas e armaduras.
- Mapas e ambientes.
- Cenas e materiais.
- Animações.
- Interface.
- Efeitos.
- Problemas visuais.
- Problemas técnicos.
- Recursos que podem ser reaproveitados.
- Melhorias recomendadas.

Não realizar alterações nesta primeira atividade.

Após apresentar o diagnóstico, propor uma ordem de execução que respeite as dependências técnicas e a estrutura atual.

---

# 20. RESULTADO FINAL PRETENDIDO

O Valtheria deverá possuir:

- Um universo visualmente coerente.
- Um mapa rico e explorável.
- Cidades com identidade.
- Biomas distintos.
- Raças e personagens marcantes.
- Classes com estilos próprios.
- Armas e armaduras originais.
- Criaturas e guardiões memoráveis.
- Combate responsivo.
- Jogabilidade em terceira pessoa.
- Interface intuitiva.
- Efeitos visuais de qualidade.
- Multiplayer integrado.
- Sistemas persistentes e seguros.
- Desempenho adequado.

**PRINCÍPIO CENTRAL:**

Valtheria não deve ser apenas um conjunto de cenários, personagens e funcionalidades. Deve ser um mundo de fantasia integrado, com identidade própria, narrativa consistente e experiência de jogo coerente.

Cada recurso novo deve contribuir para esse universo.