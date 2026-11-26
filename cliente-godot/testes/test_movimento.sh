#!/usr/bin/env bash
# Movimentação (26/11): o pé não pode patinar e nenhuma arma pode passar a atravessar o corpo mais do que já atravessa.
# 1) teste/medir_escorrega.gd: andar, ronda, correr e disparar nos 12 corpos; falha se algum passar de 12 cm/passo.
# 2) teste/medir_atravessa.gd: 12 corpos x 9 armas (mesmo roteiro dos vídeos); compara com testes/base_atravessa.json
#    e falha se alguma fase piorar mais de 8 pontos percentuais. --gravar grava a base atual (depois de conferir as imagens).
# Uso (dentro de cliente-godot): bash testes/test_movimento.sh <godot> [--gravar]
set -u
G="${1:-godot}"
GRAVAR="${2:-}"
TMP=$(mktemp -d)
ok=1
out=$(timeout 300 "$G" --headless --path . --fixed-fps 60 -s teste/medir_escorrega.gd -- --saida="$TMP/escorrega.json" 2>&1)
echo "$out" | grep -E "^PIOR"
echo "$out" | grep -q "RESULTADO: PASSOU" || { echo "FALHOU: pé patinando"; ok=0; }
CORPOS="humano:m humano:f elfo:m elfo:f sombrio:m sombrio:f orc:m orc:f anao:m anao:f gigante:m gigante:f"
for arma in espada_ng:escudo_ng espada_ng: espadao_ng: lanca_ng: martelo_ng: machado_ng: cajado_ng: arco_ng: adaga_ng:; do
  a=${arma%%:*}; e=${arma#*:}
  L=""; for c in $CORPOS; do L="$L,$c:$a:pesada_ng:$e"; done
  timeout 300 "$G" --headless --path . --fixed-fps 30 -s teste/medir_atravessa.gd -- --lista="${L#,}" --saida="$TMP/atr_${a}_${e}.json" >/dev/null 2>&1 \
    || { echo "FALHOU: medição $a $e"; ok=0; }
done
python3 - "$TMP" "$GRAVAR" <<'P' || ok=0
import json, glob, os, sys
tmp, gravar = sys.argv[1], sys.argv[2]
atual = {}
for f in sorted(glob.glob(os.path.join(tmp, "atr_*.json"))):
    for nome, v in json.load(open(f)).items():
        for fase, e in v["fases"].items():
            for tipo, x in e.items():
                atual["%s|%s|%s" % (nome, fase, tipo)] = x["pct"]
base_f = "testes/base_atravessa.json"
if gravar == "--gravar" or not os.path.exists(base_f):
    json.dump(atual, open(base_f, "w"), indent=0, sort_keys=True)
    print("base gravada: %d medidas" % len(atual))
    sys.exit(0)
base = json.load(open(base_f))
piores = []
for k, p in atual.items():
    b = base.get(k, 0.0)
    if p > b + 8.0:
        piores.append((p - b, k, b, p))
piores.sort(reverse=True)
for d, k, b, p in piores[:10]:
    print("piorou: %s  %.0f%% -> %.0f%%" % (k, b, p))
melhores = sum(1 for k, b in base.items() if atual.get(k, 0.0) < b - 8.0)
print("armas: %d medidas, %d pioraram, %d melhoraram" % (len(atual), len(piores), melhores))
sys.exit(1 if piores else 0)
P
rm -rf "$TMP"
if [ $ok -eq 1 ]; then echo "RESULTADO: PASSOU"; else echo "RESULTADO: FALHOU"; fi
