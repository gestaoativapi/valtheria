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
echo "== Resultado: $falhas falha(s)"
[ "$falhas" -eq 0 ]
