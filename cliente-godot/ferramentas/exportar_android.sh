#!/bin/bash
# Exporta o APK de teste com texturas "lossy" (WebP com perda): download ~90 MB em vez de ~200 MB.
# O PC continua com texturas comprimidas na placa de vídeo (VRAM, S3TC/BPTC), que usam bem menos memória.
# uso: bash ferramentas/exportar_android.sh [/caminho/do/godot]
set -e
G=${1:-/home/claude/godot/Godot_v4.7.2-stable_linux.x86_64}
cd "$(dirname "$0")/.."
troca() { python3 - "$1" "$2" <<'PY'
import glob, sys
de, para = sys.argv[1], sys.argv[2]
for imp in glob.glob('**/*.import', recursive=True):
    s = open(imp).read()
    if 'importer="texture"' in s and 'compress/mode=' + de in s:
        open(imp, 'w').write(s.replace('compress/mode=' + de, 'compress/mode=' + para))
PY
}
troca 2 1
$G --headless --import --path . >/dev/null 2>&1
$G --headless --export-debug "Android" build/Valtheria-teste.apk >/dev/null 2>&1 || true
troca 1 2
$G --headless --import --path . >/dev/null 2>&1
ls -la build/Valtheria-teste.apk
