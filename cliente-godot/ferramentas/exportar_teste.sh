#!/usr/bin/env bash
# Gera o executável "Valtheria TESTES" (Windows) apontando para o projeto de TESTES (valtheria-testes).
# Trabalha numa cópia do projeto: o código do jogo oficial não é alterado.
# Uso (dentro de cliente-godot): TESTE_ANON_KEY=<chave pública anon do projeto de testes> bash ferramentas/exportar_teste.sh
# Nunca usar a service_role nem outra credencial privilegiada: só a chave pública (anon).
set -euo pipefail
G="${G:-/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64}"
REF="mxhhqxvrryvqcsvokyla"
PROD="irpzdghikvoezfeodyiq"
KEY="${TESTE_ANON_KEY:?defina TESTE_ANON_KEY}"
# a chave precisa ser do projeto de testes e de papel anon
payload=$(python3 -c 'import sys,base64,json;p=sys.argv[1].split(".")[1];print(json.dumps(json.loads(base64.urlsafe_b64decode(p+"="*(-len(p)%4))),separators=(",",":")))' "$KEY")
echo "$payload" | grep -q "\"ref\":\"$REF\"" || { echo "chave não é do projeto de testes"; exit 1; }
echo "$payload" | grep -q '"role":"anon"' || { echo "chave não é pública (anon)"; exit 1; }
DEST=/tmp/valtheria_testes
rm -rf "$DEST"; mkdir -p "$DEST"
tar --exclude=./build --exclude=./.git -cf - . | tar -xf - -C "$DEST"
cd "$DEST"
python3 - "$REF" "$KEY" <<'E'
import sys, re
ref, key = sys.argv[1], sys.argv[2]
p = 'scripts/net.gd'; s = open(p, encoding='utf-8').read()
s = re.sub(r'const URL := "[^"]*"', f'const URL := "https://{ref}.supabase.co"', s, 1)
s = re.sub(r'const KEY := "[^"]*"', f'const KEY := "{key}"', s, 1)
s = s.replace('const AMBIENTE := "producao"', 'const AMBIENTE := "testes"', 1)
open(p, 'w', encoding='utf-8').write(s)
p = 'export_presets.cfg'; s = open(p, encoding='utf-8').read()
s = s.replace('application/product_name="Valtheria"', 'application/product_name="Valtheria TESTES"', 1)
open(p, 'w', encoding='utf-8').write(s)
p = 'project.godot'; s = open(p, encoding='utf-8').read()
s = s.replace('config/name="Valtheria"', 'config/name="Valtheria TESTES"', 1)
open(p, 'w', encoding='utf-8').write(s)
E
grep -E "^const (URL|KEY) :=" scripts/net.gd | grep -q "$PROD\|ImlycHpkZ2hpa3ZvZXpmZW9keWlx" && { echo "ERRO: a cópia de teste ainda aponta para a produção"; exit 1; }
grep -q 'AMBIENTE := "testes"' scripts/net.gd || { echo "ERRO: ambiente não trocado"; exit 1; }
mkdir -p build
"$G" --headless --path . --import >/dev/null 2>&1 || true
"$G" --headless --path . --export-release "Windows Desktop" build/Valtheria-TESTES.exe
echo "gerado: $DEST/build/Valtheria-TESTES.exe"
