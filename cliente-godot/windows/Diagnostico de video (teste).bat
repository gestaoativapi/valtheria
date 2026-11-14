@echo off
cd /d "%~dp0"
Valtheria.console.exe -- --diagnostico-video > diagnostico_video.txt 2>&1
echo Pronto. Envie o arquivo diagnostico_video.txt desta pasta.
pause
