# Roteiro de produção — madrugada 24→25/11/2026 (autorizado por Robson às 23:57)
Trabalho livre seguindo esta linha, sem pedir autorização. Marcar [x] ao terminar cada item e anotar o resultado.

## Regras fixas (não mudam)
- Só na branch base-teste; não modificar main; sem merge e sem publicação.
- Não alterar o Supabase de produção; não acessar dados de jogadores.
- Sem Meshy, Mixamo ou serviço pago; sem consumir créditos pagos.
- Não modificar o esqueleto oficial de 65 ossos nem as 28 animações oficiais.
- Não excluir arquivos oficiais nem do PC (o que sair vai para _PARA_EXCLUIR_Valtheria_antigos).
- Cada etapa: medir (medir_atravessa / estúdio), corrigir, regressão (testes/regressao.sh) antes do commit.
- Assets só gratuitos com uso comercial; nada copiado de outros jogos.

## Linha de produção
1. [ ] Pegada — resíduos: escudo x cabeça do gigante no golpe; lança correndo em combate (coxa); duas espadas
       apontando à frente (elfa/orc); arco em guarda tocando o tronco (anão/orc/gigante).
2. [ ] Postura de cada raça (parado, andando, correndo, guarda): medir ângulos de tronco/cabeça/braços em todas as
       raças e gêneros; corrigir quem tomba ou fica rígido; manter o caráter de cada raça (orc pesado, elfo ereto,
       anão firme, gigante lento, fera curvada, draconato altivo, sombrio inclinado, humano neutro).
3. [ ] Correções gráficas: sola/bota clara nos corpos próprios; enquadramento dos estúdios para o gigante;
       emendas de textura; fotos do jogo (cidade, campo, combate) procurando falhas visuais e corrigindo.
4. [ ] Corpos novos (quando a cota grátis do Hunyuan voltar): giganta, elfo/elfa branca, elfo/elfa negra,
       humano/humana — `ferramentas/racas/nova_raca.py`; conferir juntas, mãos, armas e vídeo.
5. [ ] Entrega da manhã: regressão, exe + exe de testes + APK na pasta Downloads\Valtheria-base-teste-40 com
       SHA-256 e QR; v39 para _PARA_EXCLUIR_Valtheria_antigos; vídeos de antes/depois; resumo curto para Robson.

## Diário
