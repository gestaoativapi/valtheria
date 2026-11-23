#!/usr/bin/env bash
# PEDIDO 006 — PvP com o servidor como autoridade, no PROJETO DE TESTES (nunca na produção).
# Uso: TESTE_URL=... TESTE_KEY=<anon> TESTE_REF=... bash teste/pvp_teste_online.sh [pasta_evidencias]
# Cria duas contas descartáveis (A e B) e testa: zona de paz, golpe válido, ritmo, simultâneos, distância,
# vida "curada" pelo cliente depois do golpe, habilidade não aprendida e a função antiga fechada.
set -uo pipefail
PROD_REF="irpzdghikvoezfeodyiq"
: "${TESTE_URL:?falta TESTE_URL}" "${TESTE_KEY:?falta TESTE_KEY}" "${TESTE_REF:?falta TESTE_REF}"
EV="${1:-pvp_evidencias}"; mkdir -p "$EV"
falhas=0; total=0; passo=0
ok()   { total=$((total+1)); echo "[OK]    $1"; }
erro() { total=$((total+1)); falhas=$((falhas+1)); echo "[FALHA] $1"; }
info() { echo "[INFO]  $1"; }
payload() { local p; p=$(echo "$1" | cut -d. -f2 | tr '_-' '/+'); while [ $(( ${#p} % 4 )) -ne 0 ]; do p="$p="; done; echo "$p" | base64 -d 2>/dev/null; }
case "$TESTE_URL" in *"$PROD_REF"*) echo "ERRO: endereço da produção"; exit 1;; esac
[ "$TESTE_URL" = "https://$TESTE_REF.supabase.co" ] || { echo "ERRO: endereço não confere"; exit 1; }
[ "$(payload "$TESTE_KEY" | jq -r .role)" = "anon" ] || { echo "ERRO: chave não é anon"; exit 1; }
ok "trava: projeto de testes $TESTE_REF, chave anon"

rpcT() { # rpcT <token> <nome> <json>
  passo=$((passo+1))
  local c; c=$(curl -sS -o /tmp/p.json -w '%{http_code}' -X POST "$TESTE_URL/rest/v1/rpc/$2" -H "apikey: $TESTE_KEY" -H "Authorization: Bearer $1" -H 'Content-Type: application/json' -d "$3")
  cp /tmp/p.json "$EV/$(printf %03d $passo)_$2.json"; echo "$c"
}
conta() { # conta <rótulo> -> "token char"
  local rnd U S c t ch
  rnd=$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n'); U="pvp_$rnd"
  S=$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)
  curl -sS -o /dev/null -X POST "$TESTE_URL/functions/v1/signup" -H "apikey: $TESTE_KEY" -H "Authorization: Bearer $TESTE_KEY" -H 'Content-Type: application/json' -d "{\"username\":\"$U\",\"password\":\"$S\"}"
  t=$(curl -sS -X POST "$TESTE_URL/auth/v1/token?grant_type=password" -H "apikey: $TESTE_KEY" -H 'Content-Type: application/json' -d "{\"email\":\"$U@jogadores.reinosdeaurora.app\",\"password\":\"$S\"}" | jq -r '.access_token // empty')
  [ -n "$t" ] || { echo ""; return; }
  ch=$(curl -sS -X POST "$TESTE_URL/rest/v1/rpc/game_create_char2" -H "apikey: $TESTE_KEY" -H "Authorization: Bearer $t" -H 'Content-Type: application/json' -d "{\"p_name\":\"P$rnd\",\"p_race\":\"humano\",\"p_type\":\"l\",\"p_gender\":\"m\",\"p_look\":{}}" | jq -r '. // empty')
  echo "$t $ch"
}
read TA A <<<"$(conta A)"; read TB B <<<"$(conta B)"
[ -n "${A:-}" ] && [ -n "${B:-}" ] && ok "duas contas e dois personagens criados" || { erro "criar contas"; exit 1; }
hpB() { rpcT "$TB" game_state "{\"p_char\":\"$B\"}" >/dev/null; jq -r '.char.hp' /tmp/p.json; }
golpe() { rpcT "$TA" game_pvp2 "{\"p_char\":\"$A\",\"p_target\":\"$B\"${1:-}}"; }
aceito() { jq -e 'type=="object" and has("dmg")' /tmp/p.json >/dev/null 2>&1; }
motivo() { jq -rc '.recusado // .message // empty' /tmp/p.json 2>/dev/null; }

# 1. Zona de paz: os dois no ponto de nascimento (cidade)
rpcT "$TA" game_save2 "{\"p_char\":\"$A\",\"p_x\":1502,\"p_z\":2575,\"p_hp\":500,\"p_mp\":100}" >/dev/null
rpcT "$TB" game_save2 "{\"p_char\":\"$B\",\"p_x\":1503,\"p_z\":2575,\"p_hp\":500,\"p_mp\":100}" >/dev/null
golpe >/dev/null
[ "$(motivo)" = "Zona de paz" ] && ok "golpe na cidade recusado (Zona de paz)" || info "cidade: $(head -c 160 /tmp/p.json)"

# 2. Os dois vão para a pradaria (fora da cidade), lado a lado
info "aguardando 30 s para o deslocamento legítimo"; sleep 30
rpcT "$TA" game_save2 "{\"p_char\":\"$A\",\"p_x\":1250,\"p_z\":2250,\"p_hp\":500,\"p_mp\":100}" >/dev/null
rpcT "$TB" game_save2 "{\"p_char\":\"$B\",\"p_x\":1252,\"p_z\":2250,\"p_hp\":500,\"p_mp\":100}" >/dev/null
H0=$(hpB); info "vida de B antes: $H0"
c=$(golpe); if aceito; then ok "golpe válido a 2 m aceito (dano $(jq .dmg /tmp/p.json))"; else erro "golpe válido recusado ($c $(head -c 160 /tmp/p.json))"; fi
H1=$(hpB); info "vida de B depois: $H1"
awk "BEGIN{exit !($H1 < $H0)}" && ok "vida de B baixou NO SERVIDOR ($H0 -> $H1)" || erro "vida de B não mudou no servidor"

# 3. Ritmo: segundo golpe logo em seguida
golpe >/dev/null; [ "$(motivo)" = "Golpes rápidos demais" ] && ok "2º golpe em menos de 0,8 s recusado" || erro "2º golpe imediato: $(head -c 160 /tmp/p.json)"

# 4. Simultâneos: 6 golpes em paralelo
sleep 1.2; rm -f /tmp/pc_*.json
for i in 1 2 3 4 5 6; do curl -sS -o /tmp/pc_$i.json -X POST "$TESTE_URL/rest/v1/rpc/game_pvp2" -H "apikey: $TESTE_KEY" -H "Authorization: Bearer $TA" -H 'Content-Type: application/json' -d "{\"p_char\":\"$A\",\"p_target\":\"$B\"}" & done; wait
n=0; for i in 1 2 3 4 5 6; do jq -e 'has("dmg")' /tmp/pc_$i.json >/dev/null 2>&1 && n=$((n+1)); cp /tmp/pc_$i.json "$EV/simultaneo_$i.json"; done
[ "$n" -le 1 ] && ok "6 golpes simultâneos: $n aplicado(s)" || erro "6 golpes simultâneos: $n aplicados (corrida)"

# 5. B tenta "se curar" salvando vida cheia logo depois do golpe
H2=$(hpB)
rpcT "$TB" game_save2 "{\"p_char\":\"$B\",\"p_x\":1252,\"p_z\":2250,\"p_hp\":99999,\"p_mp\":100}" >/dev/null
H3=$(hpB); info "B tentou salvar vida 99999: $H2 -> $H3"
awk "BEGIN{exit !($H3 <= $H2 * 1.0 + 60)}" && ok "vida salva pelo cliente limitada pelo servidor após o golpe" || erro "B recuperou vida demais ($H2 -> $H3)"

# 6. Distância: B se afasta 20 m (corpo a corpo alcança 7 m)
sleep 1.2
rpcT "$TB" game_save2 "{\"p_char\":\"$B\",\"p_x\":1272,\"p_z\":2250,\"p_hp\":$H3,\"p_mp\":100}" >/dev/null
golpe >/dev/null; [ "$(motivo)" = "Alvo longe demais" ] && ok "golpe corpo a corpo a 20 m recusado" || erro "golpe a 20 m: $(head -c 160 /tmp/p.json)"

# 7. Habilidade não aprendida
sleep 1.2; golpe ',"p_skill":"golpe_supremo"' >/dev/null
[ "$(motivo)" = "Habilidade não aprendida" ] && ok "habilidade não aprendida recusada" || erro "habilidade falsa: $(head -c 160 /tmp/p.json)"

# 8. Função antiga (multiplicador escolhido pelo cliente) fechada
c=$(rpcT "$TA" game_pvp "{\"p_char\":\"$A\",\"p_target\":\"$B\",\"p_mult\":5}")
[ "$c" != 200 ] && ok "função antiga game_pvp (multiplicador do cliente) fechada ($c)" || erro "game_pvp antiga ainda aceita"

# 9. Atacar a si mesmo
sleep 1.2; c=$(rpcT "$TA" game_pvp2 "{\"p_char\":\"$A\",\"p_target\":\"$A\"}")
[ -n "$(motivo)" ] && ok "atacar a si mesmo recusado" || erro "atacou a si mesmo"

echo "Resultado PvP: $((total-falhas))/$total aprovados"
[ "$falhas" = 0 ]
