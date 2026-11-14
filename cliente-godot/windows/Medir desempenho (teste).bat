@echo off
cd /d "%~dp0"
echo Medindo o desempenho (cerca de 12 minutos). Nao mexa no computador.
Valtheria.console.exe -- --benchmark > benchmark.txt 2>&1
echo Pronto. Envie o arquivo benchmark.txt desta pasta.
pause
