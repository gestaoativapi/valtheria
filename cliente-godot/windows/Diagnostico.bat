@echo off
cd /d "%~dp0"
echo Abrindo o jogo e gravando o registro em diagnostico.txt ...
Valtheria.console.exe --verbose > diagnostico.txt 2>&1
echo Pronto. Envie o arquivo diagnostico.txt que apareceu nesta pasta.
pause
