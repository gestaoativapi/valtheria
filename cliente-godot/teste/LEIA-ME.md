# Ambiente de testes (D43)

O executável de TESTE é gerado pelo GitHub (workflow "Testes do cliente nativo", trabalho "versao-de-teste") a partir desta ramificação.
Ele só é gerado se existir `teste/ambiente_teste.env` com:

    TESTE_URL=https://<ref-do-projeto-de-testes>.supabase.co
    TESTE_KEY=<chave pública anon do projeto de testes>

A chave anon é pública (a mesma que qualquer jogador recebe); nunca colocar aqui a chave service_role.
O build é bloqueado se o endereço ou a chave forem os da produção, e o próprio jogo se recusa a abrir se isso acontecer.
