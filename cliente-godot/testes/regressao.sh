#!/usr/bin/env bash
# Testes de regressão do cliente nativo (Fase 1, A6).
# Uso: testes/regressao.sh <caminho do Godot>   (rode dentro de cliente-godot)
# Falha (código 1) se algum script não compilar ou se o jogo registrar "SCRIPT ERROR" ao entrar no mundo.
set -u
G="${1:-godot}"
falhas=0
"$G" --headless --path . --import >/dev/null 2>&1 || true
echo "== 1. Sintaxe dos scripts"
for f in scripts/*.gd; do
  out=$("$G" --headless --path . --check-only --script "$f" 2>&1)
  if echo "$out" | grep -qE "SCRIPT ERROR|Parse Error|Compile Error"; then
    echo "FALHOU: $f"; echo "$out" | grep -E "ERROR|Error" | head -5; falhas=$((falhas+1))
  else
    echo "ok: $f"
  fi
done
echo "== 2. Entrada no mundo em pontos fixos (modo offline)"
for p in "1500,1985" "1500,2550" "1500,1450" "2150,1300" "2290,2800" "1250,2250"; do
  out=$(timeout 240 "$G" --headless --path . --quit-after 300 -- --play --at=$p 2>&1)
  if echo "$out" | grep -q "SCRIPT ERROR"; then
    echo "FALHOU em $p"; echo "$out" | grep -A2 "SCRIPT ERROR" | head -8; falhas=$((falhas+1))
  else
    echo "ok: $p"
  fi
done
echo "== 3. Reconexão do tempo real"
if timeout 120 "$G" --headless --path . --script testes/test_reconexao.gd 2>&1 | grep -q "RESULTADO: PASSOU"; then echo "ok: reconexão"; else echo "FALHOU: reconexão"; falhas=$((falhas+1)); fi
echo "== 4. Física do mundo aberto (colisão, encosta, portas, nascimento)"
if timeout 500 "$G" --headless --path . --script testes/test_fisica_mundo.gd 2>&1 | grep -q "RESULTADO: PASSOU"; then echo "ok: física do mundo"; else echo "FALHOU: física do mundo"; falhas=$((falhas+1)); fi
echo "== 5. Pés no chão (todas as raças, plano, encosta e cidade)"
if timeout 600 "$G" --headless --path . --script testes/test_pes.gd 2>&1 | grep -q "RESULTADO: PASSOU"; then echo "ok: pés no chão"; else echo "FALHOU: pés no chão"; falhas=$((falhas+1)); fi
if timeout 400 "$G" --headless --path . --script testes/test_zonas.gd 2>&1 | grep -q "RESULTADO: PASSOU"; then echo "ok: zonas de paz e batalha"; else echo "FALHOU: zonas de paz e batalha"; falhas=$((falhas+1)); fi
echo "== 6. Queda simulada (D39, só no executável de teste)"
if timeout 60 "$G" --headless --path . --script testes/test_queda_simulada.gd 2>&1 | grep -q "RESULTADO: PASSOU"; then echo "ok: queda simulada"; else echo "FALHOU: queda simulada"; falhas=$((falhas+1)); fi
echo "== 7. Grupo (convite, aceite, fala, expulsão, liderança)"
if timeout 60 "$G" --headless --path . --script testes/test_grupo.gd 2>&1 | grep -q "RESULTADO: PASSOU"; then echo "ok: grupo"; else echo "FALHOU: grupo"; falhas=$((falhas+1)); fi
echo "== Resultado: $falhas falha(s)"
[ "$falhas" -eq 0 ]
