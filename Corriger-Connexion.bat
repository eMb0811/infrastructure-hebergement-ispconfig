@echo off
:: ==============================================================================
:: TP3 - Script automatique pour corriger la résolution des sites web sur Windows
:: Demande l'élévation Administrateur et ajoute elhadji.sn & universite.sn au fichier hosts
:: ==============================================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Demande d'autorisation Administrateur...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

echo ====================================================================
echo  ACTIVATION DE LA RESOLUTION DES SITES DU TP3 (ISPConfig 3)
echo ====================================================================

set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
set "IP=192.168.126.110"

:: Nettoyer les anciennes entrées si existantes
findstr /v "elhadji.sn universite.sn" "%HOSTS_FILE%" > "%TEMP%\hosts_clean.tmp"
copy /y "%TEMP%\hosts_clean.tmp" "%HOSTS_FILE%" >nul
del "%TEMP%\hosts_clean.tmp" >nul

:: Ajouter les nouvelles entrées vers l'IP du serveur ISPConfig
echo. >> "%HOSTS_FILE%"
echo # TP3 Administration Reseaux (ISPConfig 3) >> "%HOSTS_FILE%"
echo %IP% elhadji.sn www.elhadji.sn mail.elhadji.sn webmail.elhadji.sn >> "%HOSTS_FILE%"
echo %IP% universite.sn www.universite.sn mail.universite.sn webmail.universite.sn >> "%HOSTS_FILE%"
echo %IP% test.sn www.test.sn mail.test.sn >> "%HOSTS_FILE%"

echo [OK] Entrees ajoutees avec succes dans %HOSTS_FILE% :
echo   - http://elhadji.sn/bienvenue.html
echo   - http://test.sn/
echo   - http://universite.sn/
echo.

ipconfig /flushdns >nul
echo [OK] Cache DNS Windows vide. Vos sites sont desormais accessibles !
echo ====================================================================
timeout /t 5
