@echo off
setlocal
title Balatro Strategic Copilot - installation
if not exist "%~dp0outils\installer_copilot.ps1" goto pas_extrait
if not exist "%~dp0BalatroStrategicCopilot\BalatroStrategicCopilot.json" if not exist "%~dp0..\BalatroStrategicCopilot\BalatroStrategicCopilot.json" goto pas_extrait
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0outils\installer_copilot.ps1" %*
echo.
pause
exit /b

:pas_extrait
echo.
echo   Les fichiers du paquet sont introuvables a cote de ce programme.
echo   Il faut d'abord extraire TOUTE l'archive :
echo     clic droit sur BalatroStrategicCopilot-x.y.z.zip, puis "Extraire tout..."
echo   puis double-cliquer sur INSTALLER_COPILOT.bat dans le dossier extrait.
echo.
pause
exit /b 1
