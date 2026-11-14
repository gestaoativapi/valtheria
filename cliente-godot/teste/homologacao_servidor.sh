#!/usr/bin/env bash
# D45 — testes de funcionamento e isolamento no PROJETO DE TESTES (nunca na produção).
# Uso: TESTE_URL=... TESTE_KEY=<chave pública anon> TESTE_REF=... bash teste/homologacao_servidor.sh
# Cria duas contas comuns descartáveis (senhas geradas aqui e nunca exibidas).
set -uo pipefail
PROD_REF="irpzdghikvoezfeodyiq"
: "${TESTE_URL:?falta TESTE_URL}" "${TESTE_KEY:?falta TESTE_KEY}" "${TESTE_REF:?falta TESTE_REF}"

falhas=0; total=0
ok()   { total=$((total+1)); echo "[OK]    $1"; }
erro() { total=$((total+1)); falhas=$((falhas+1)); echo "[FALHA] $1"; }
payload() { local p; p=$(echo "$1" | cut -d. -f2 | tr '_-' '/+'); while [ $(( ${#p} % 4 )) -ne 0 ]; do p="$p="; done; echo "$p" | base64 -d 2>/dev/null; }

# 0. Trava: nunca a produção; a chave tem que ser a pública (anon) do projeto de testes
case "$TESTE_URL" in *"$PROD_REF"*) echo "ERRO: endereço da produção"; exit 1;; esac
[ "$TESTE_URL" = "https://$TESTE_REF.supabase.co" ] && ok "endereço é o do projeto de testes ($TESTE_REF)" || { erro "endereço não confere com TESTE_REF"; exit 1; }
P=$(payload "$TESTE_KEY")
[ "$(echo "$P" | jq -r .role)" = "anon" ] && ok "chave é a pública (anon), não a service_role" || { erro "a chave não é anon"; exit 1; }
[ "$(echo "$P" | jq -r .ref)" = "$TESTE_REF" ] && ok "chave pertence ao projeto de testes" || { erro "chave de outro projeto"; exit 1; }

post() { # post <caminho> <json> [token] -> imprime "codigo corpo"
  local tok="${3:-$TESTE_KEY}"
  curl -sS -o /tmp/r.json -w '%{http_code}' -X POST "$TESTE_URL$1" -H "apikey: $TESTE_KEY" -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' -d "$2"
}
rnd=$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')
UA="ta_$rnd"; UB="tb_$rnd"
SA=$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20); SB=$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)

# 1. Cadastro (mesma função signup do jogo)
c=$(post /functions/v1/signup "{\"username\":\"$UA\",\"password\":\"$SA\"}"); [ "$c" = 200 ] && ok "cadastro da conta A" || erro "cadastro A ($c $(cat /tmp/r.json))"
c=$(post /functions/v1/signup "{\"username\":\"$UB\",\"password\":\"$SB\"}"); [ "$c" = 200 ] && ok "cadastro da conta B" || erro "cadastro B ($c $(cat /tmp/r.json))"
c=$(post /functions/v1/signup "{\"username\":\"$UA\",\"password\":\"$SA\"}"); [ "$c" = 409 ] && ok "cadastro repetido é recusado (409)" || erro "cadastro repetido ($c)"

# 2. Autenticação
c=$(post "/auth/v1/token?grant_type=password" "{\"email\":\"$UA@jogadores.reinosdeaurora.app\",\"password\":\"$SA\"}"); TA=$(jq -r '.access_token // empty' /tmp/r.json)
[ "$c" = 200 ] && [ -n "$TA" ] && ok "login da conta A" || erro "login A ($c)"
c=$(post "/auth/v1/token?grant_type=password" "{\"email\":\"$UB@jogadores.reinosdeaurora.app\",\"password\":\"$SB\"}"); TB=$(jq -r '.access_token // empty' /tmp/r.json)
[ "$c" = 200 ] && [ -n "$TB" ] && ok "login da conta B" || erro "login B ($c)"
c=$(post "/auth/v1/token?grant_type=password" "{\"email\":\"$UA@jogadores.reinosdeaurora.app\",\"password\":\"senha_errada_123\"}"); [ "$c" = 400 ] && ok "senha errada é recusada" || erro "senha errada ($c)"
payload "$TA" | jq -r .iss | grep -q "^https://$TESTE_REF.supabase.co/" && ok "sessão emitida pelo projeto de testes" || erro "sessão de outro projeto"

# 3. Criação de personagem
c=$(post /rest/v1/rpc/game_create_char2 "{\"p_name\":\"PA$rnd\",\"p_race\":\"humano\",\"p_type\":\"l\",\"p_gender\":\"m\",\"p_look\":{}}" "$TA"); CA=$(jq -r '. // empty' /tmp/r.json)
[ "$c" = 200 ] && [ -n "$CA" ] && ok "conta A cria personagem" || erro "criar personagem A ($c $(cat /tmp/r.json))"
c=$(post /rest/v1/rpc/game_create_char2 "{\"p_name\":\"PB$rnd\",\"p_race\":\"humano\",\"p_type\":\"l\",\"p_gender\":\"f\",\"p_look\":{}}" "$TB"); CB=$(jq -r '. // empty' /tmp/r.json)
[ "$c" = 200 ] && [ -n "$CB" ] && ok "conta B cria personagem" || erro "criar personagem B ($c $(cat /tmp/r.json))"
c=$(post /rest/v1/rpc/game_create_char2 "{\"p_name\":\"PX$rnd\",\"p_race\":\"humano\",\"p_type\":\"l\",\"p_gender\":\"m\",\"p_look\":{}}"); [ "$c" != 200 ] && ok "sem login não cria personagem ($c)" || erro "anônimo criou personagem"
c=$(post /rest/v1/rpc/game_state "{\"p_char\":\"$CA\"}" "$TA"); [ "$c" = 200 ] && [ "$(jq -r .char.name /tmp/r.json)" = "PA$rnd" ] && ok "conta A lê o próprio personagem" || erro "ler próprio personagem ($c)"

# 4. Isolamento entre as duas contas
c=$(post /rest/v1/rpc/game_chars '{}' "$TA"); n=$(jq '.chars|length' /tmp/r.json); tem_b=$(jq --arg b "$CB" '[.chars[].id]|index($b)' /tmp/r.json)
[ "$c" = 200 ] && [ "$n" = 1 ] && [ "$tem_b" = null ] && ok "lista da conta A tem só o personagem dela" || erro "lista da conta A ($c n=$n)"
c=$(post /rest/v1/rpc/game_state "{\"p_char\":\"$CB\"}" "$TA"); [ "$c" != 200 ] && ok "conta A não lê o personagem da conta B ($c)" || erro "A leu o personagem de B"
c=$(post /rest/v1/rpc/game_save2 "{\"p_char\":\"$CB\",\"p_x\":1500,\"p_z\":2578,\"p_hp\":100,\"p_mp\":100}" "$TA"); [ "$c" != 200 ] && ok "conta A não salva o personagem da conta B ($c)" || erro "A salvou o personagem de B"
c=$(post /rest/v1/rpc/game_delete_char "{\"p_char\":\"$CB\"}" "$TA"); [ "$c" != 200 ] && ok "conta A não apaga o personagem da conta B ($c)" || erro "A apagou o personagem de B"
c=$(post /rest/v1/rpc/game_state "{\"p_char\":\"$CB\"}" "$TB"); [ "$c" = 200 ] && ok "personagem da conta B continua intacto" || erro "personagem de B sumiu ($c)"
c=$(curl -sS -o /tmp/r.json -w '%{http_code}' "$TESTE_URL/rest/v1/characters?select=*" -H "apikey: $TESTE_KEY" -H "Authorization: Bearer $TA" -H 'Accept-Profile: game')
rows=$(jq 'if type=="array" then length else 0 end' /tmp/r.json 2>/dev/null || echo 0)
[ "$rows" = 0 ] && ok "tabelas do jogo não ficam expostas por leitura direta ($c)" || erro "leitura direta devolveu $rows linhas"

echo "Resultado: $((total-falhas))/$total aprovados"
[ "$falhas" = 0 ]
