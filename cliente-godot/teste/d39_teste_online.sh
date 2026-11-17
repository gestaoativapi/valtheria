#!/usr/bin/env bash
# D39 — teste online da Fase 1 no PROJETO DE TESTES (nunca na produção).
# Uso: TESTE_URL=... TESTE_KEY=<chave pública anon> TESTE_REF=... bash teste/d39_teste_online.sh [pasta_evidencias]
# Cria uma conta comum descartável (senha gerada aqui, nunca exibida) e um personagem sem GM.
# Saída: linhas [OK]/[FALHA]/[INFO] e um JSON por passo em <pasta_evidencias>.
set -uo pipefail
PROD_REF="irpzdghikvoezfeodyiq"
: "${TESTE_URL:?falta TESTE_URL}" "${TESTE_KEY:?falta TESTE_KEY}" "${TESTE_REF:?falta TESTE_REF}"
EV="${1:-d39_evidencias}"; mkdir -p "$EV"
falhas=0; total=0; passo=0
ok()   { total=$((total+1)); echo "[OK]    $1"; }
erro() { total=$((total+1)); falhas=$((falhas+1)); echo "[FALHA] $1"; }
info() { echo "[INFO]  $1"; }
payload() { local p; p=$(echo "$1" | cut -d. -f2 | tr '_-' '/+'); while [ $(( ${#p} % 4 )) -ne 0 ]; do p="$p="; done; echo "$p" | base64 -d 2>/dev/null; }

# 0. Trava: nunca a produção; só a chave pública (anon) do projeto de testes
case "$TESTE_URL" in *"$PROD_REF"*) echo "ERRO: endereço da produção"; exit 1;; esac
[ "$TESTE_URL" = "https://$TESTE_REF.supabase.co" ] || { echo "ERRO: endereço não confere com TESTE_REF"; exit 1; }
P=$(payload "$TESTE_KEY")
[ "$(echo "$P" | jq -r .role)" = "anon" ] || { echo "ERRO: a chave não é a pública (anon)"; exit 1; }
[ "$(echo "$P" | jq -r .ref)" = "$TESTE_REF" ] || { echo "ERRO: chave de outro projeto"; exit 1; }
ok "trava: projeto de testes $TESTE_REF, chave anon"

TOK=""
rpc() { # rpc <nome> <json> -> código; corpo em /tmp/r.json e cópia em evidências
  passo=$((passo+1))
  local c; c=$(curl -sS -o /tmp/r.json -w '%{http_code}' -X POST "$TESTE_URL/rest/v1/rpc/$1" -H "apikey: $TESTE_KEY" -H "Authorization: Bearer ${TOK:-$TESTE_KEY}" -H 'Content-Type: application/json' -d "$2")
  jq -n --arg f "$1" --argjson a "$2" --arg c "$c" --rawfile r /tmp/r.json '{passo:'"$passo"',funcao:$f,args:$a,codigo:$c,resposta:$r}' > "$EV/$(printf %03d $passo)_$1.json"
  echo "$c"
}
login() {
  local c; c=$(curl -sS -o /tmp/r.json -w '%{http_code}' -X POST "$TESTE_URL/auth/v1/token?grant_type=password" -H "apikey: $TESTE_KEY" -H 'Content-Type: application/json' -d "{\"email\":\"$U@jogadores.reinosdeaurora.app\",\"password\":\"$S\"}")
  TOK=$(jq -r '.access_token // empty' /tmp/r.json); [ "$c" = 200 ] && [ -n "$TOK" ]
}
estado() { rpc game_state "{\"p_char\":\"$CH\"}" >/dev/null; jq -c '{lvl:(.char.level // .char.lvl), xp:.char.xp, adena:(.char.adena // .char.gold // .char.money), x:.char.x, z:.char.z, inv:(.inventory // .inv // [] | length)}' /tmp/r.json; }
recusa() { # recusa <descrição> <nome> <json>: espera erro ou ok:false
  local c; c=$(rpc "$2" "$3")
  # recusa = erro HTTP, ou resposta 200 com "ok": false, ou com "recusado" (o servidor não aplica nada)
  local rec; rec=$(jq -r 'if type=="object" then ((has("ok") and .ok==false) or has("recusado"))|tostring else "false" end' /tmp/r.json 2>/dev/null)
  if [ "$c" != 200 ] || [ "$rec" = "true" ]; then ok "$1 recusado ($c $(jq -rc '.message // .recusado // .motivo // empty' /tmp/r.json 2>/dev/null))"; else erro "$1 foi ACEITO: $(head -c 200 /tmp/r.json)"; fi
}

# 1. Conta descartável e personagem novo sem GM
rnd=$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n'); U="d39_$rnd"
S=$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)
c=$(curl -sS -o /tmp/r.json -w '%{http_code}' -X POST "$TESTE_URL/functions/v1/signup" -H "apikey: $TESTE_KEY" -H "Authorization: Bearer $TESTE_KEY" -H 'Content-Type: application/json' -d "{\"username\":\"$U\",\"password\":\"$S\"}")
[ "$c" = 200 ] && ok "conta descartável $U criada" || { erro "cadastro ($c)"; exit 1; }
login && ok "login" || { erro "login"; exit 1; }
payload "$TOK" | jq -r .iss | grep -q "^https://$TESTE_REF.supabase.co/" && ok "sessão emitida pelo projeto de testes" || { erro "sessão de outro projeto"; exit 1; }
c=$(rpc game_create_char2 "{\"p_name\":\"D$rnd\",\"p_race\":\"humano\",\"p_type\":\"l\",\"p_gender\":\"m\",\"p_look\":{}}"); CH=$(jq -r '. // empty' /tmp/r.json)
[ "$c" = 200 ] && [ -n "$CH" ] && ok "personagem criado" || { erro "criar personagem ($c)"; exit 1; }
rpc game_state "{\"p_char\":\"$CH\"}" >/dev/null
[ "$(jq -r '.char.is_gm // false' /tmp/r.json)" != "true" ] && ok "personagem sem GM" || erro "personagem veio com GM"
E0=$(estado); info "estado inicial: $E0"; info "campos do personagem: $(jq -c '.char|keys' /tmp/r.json)"

# 2. Movimento legítimo até a pradaria e abate válido
c=$(rpc game_save2 "{\"p_char\":\"$CH\",\"p_x\":1250,\"p_z\":2250,\"p_hp\":100,\"p_mp\":100}"); info "primeiro salvamento de posição ($c $(head -c 120 /tmp/r.json))"
sleep 6
c=$(rpc game_kill4 "{\"p_char\":\"$CH\",\"p_fam\":\"lobo\",\"p_x\":1255,\"p_z\":2252}")
[ "$c" = 200 ] && ok "abate válido de lobo aceito" || erro "abate válido recusado ($c $(head -c 200 /tmp/r.json))"
E1=$(estado); info "depois do abate: $E1"
[ "$(echo "$E1" | jq .xp)" != "$(echo "$E0" | jq .xp)" ] || [ "$(echo "$E1" | jq .lvl)" != "$(echo "$E0" | jq .lvl)" ] && ok "experiência calculada pelo servidor mudou" || erro "experiência não mudou após abate válido"

# 3. Tentativas de trapaça (todas devem ser recusadas)
sleep 6
recusa "abate longe da posição" game_kill4 "{\"p_char\":\"$CH\",\"p_fam\":\"lobo\",\"p_x\":2800,\"p_z\":400}"
recusa "monstro fora da região (dragão na pradaria)" game_kill4 "{\"p_char\":\"$CH\",\"p_fam\":\"dragao\",\"p_x\":1255,\"p_z\":2252}"
recusa "chefe sem ponto de caça" game_kill4 "{\"p_char\":\"$CH\",\"p_fam\":\"rei_javali\",\"p_x\":1255,\"p_z\":2252}"
recusa "monstro inexistente" game_kill4 "{\"p_char\":\"$CH\",\"p_fam\":\"xp_infinito\",\"p_x\":1255,\"p_z\":2252}"
recusa "teleporte" game_save2 "{\"p_char\":\"$CH\",\"p_x\":2900,\"p_z\":300,\"p_hp\":100,\"p_mp\":100}"
rpc game_save2 "{\"p_char\":\"$CH\",\"p_x\":1252,\"p_z\":2251,\"p_hp\":999999,\"p_mp\":999999}" >/dev/null
H=$(rpc game_state "{\"p_char\":\"$CH\"}" >/dev/null; jq -r '.char.hp' /tmp/r.json)
[ "$(echo "$H < 999999" | bc 2>/dev/null || echo 1)" = 1 ] && ok "HP falso limitado pelo servidor (hp=$H)" || erro "HP falso aceito (hp=$H)"
rpc game_quest_accept "{\"p_char\":\"$CH\",\"p_quest\":\"m01\"}" >/dev/null
recusa "missão concluída sem abates" game_quest_done2 "{\"p_char\":\"$CH\",\"p_quest\":\"m01\"}"
c=$(curl -sS -o /tmp/r.json -w '%{http_code}' -X PATCH "$TESTE_URL/rest/v1/characters?id=eq.$CH" -H "apikey: $TESTE_KEY" -H "Authorization: Bearer $TOK" -H 'Content-Profile: game' -H 'Content-Type: application/json' -H 'Prefer: return=representation' -d '{"xp":99999999,"gold":99999999}')
rows=$(jq 'if type=="array" then length else 0 end' /tmp/r.json 2>/dev/null || echo 0)
[ "$rows" = 0 ] && ok "escrita direta na tabela de personagens bloqueada ($c)" || erro "escrita direta alterou $rows linha(s)"
c=$(rpc game_kill3 "{\"p_char\":\"$CH\",\"p_lvl\":80,\"p_boss\":true,\"p_fam\":\"dragao\"}")
[ "$c" != 200 ] && ok "função interna de recompensa não pode ser chamada direto ($c)" || erro "função interna game_kill3 aceitou chamada direta do cliente (vulnerabilidade)"

# 4. Pedidos repetidos rápidos (sem espera entre eles)
sleep 6; aceitos=0; XA=$(estado | jq .xp)
for i in 1 2 3 4 5; do
  c=$(rpc game_kill4 "{\"p_char\":\"$CH\",\"p_fam\":\"lobo\",\"p_x\":1255,\"p_z\":2252}")
  r=$(jq -rc 'if type=="object" then (.recusado // (if has("xp") or has("gain") then "ganhou" else (keys|join(",")) end)) else . end' /tmp/r.json 2>/dev/null)
  info "abate rápido $i: $c $r ($(date +%s.%N | cut -c1-14))"
  [ "$c" = 200 ] && [ "$(jq -r 'if type=="object" then has("recusado")|tostring else "false" end' /tmp/r.json)" = "false" ] && aceitos=$((aceitos+1))
done
XB=$(estado | jq .xp); info "experiência antes/depois da rajada: $XA -> $XB"
[ "$aceitos" -le 1 ] && ok "5 abates seguidos: $aceitos aplicado(s)" || erro "5 abates seguidos: $aceitos aplicados (limite de ritmo ausente)"

# 5. Chefe no ponto certo e repetição
sleep 14
rpc game_save2 "{\"p_char\":\"$CH\",\"p_x\":1246,\"p_z\":2450,\"p_hp\":100,\"p_mp\":100}" >/dev/null; sleep 6
c=$(rpc game_kill4 "{\"p_char\":\"$CH\",\"p_fam\":\"rei_javali\",\"p_x\":1246,\"p_z\":2458,\"p_spot\":\"aurora:Campos do Amanhecer\"}")
[ "$c" = 200 ] && ok "chefe no ponto de caça aceito (drops: $(jq -c '.drops // [] | length' /tmp/r.json))" || erro "chefe no ponto recusado ($c $(head -c 200 /tmp/r.json))"
sleep 6
recusa "chefe repetido antes de voltar" game_kill4 "{\"p_char\":\"$CH\",\"p_fam\":\"rei_javali\",\"p_x\":1246,\"p_z\":2458,\"p_spot\":\"aurora:Campos do Amanhecer\"}"

# 6. Salvar, sair e voltar após 10 s e 60 s (sessão nova)
EA=$(estado); info "antes de sair: $EA"
for espera in 10 60; do
  TOK=""; sleep "$espera"
  login && ok "nova sessão após $espera s" || erro "login após $espera s"
  EB=$(estado)
  [ "$EB" = "$EA" ] && ok "após $espera s: personagem, inventário e posição iguais" || erro "após $espera s mudou: $EA -> $EB"
done

echo "Resultado: $((total-falhas))/$total aprovados"
echo "{\"aprovados\":$((total-falhas)),\"total\":$total,\"conta\":\"$U\",\"personagem\":\"$CH\"}" > "$EV/resumo.json"
[ "$falhas" = 0 ]
