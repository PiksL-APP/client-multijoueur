@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
cd /d "%~dp0"

REM ============================================================================
REM  DOUBLE-CLIQUEZ CE FICHIER POUR METTRE LE JEU EN LIGNE.
REM
REM  Pourquoi il existe : `sortie/` est le jeu COMPILE, et c'est lui que Vercel
REM  sert. `git push` envoie le code source ; il ne refabrique pas `sortie/`.
REM  Pousser sans exporter laisse donc la page en ligne exactement comme avant,
REM  sans que rien ne le signale. Ce fichier fait l'export, et rien d'autre.
REM
REM  Il lui faut Godot 4.5. Il le cherche tout seul ; s'il ne le trouve pas, il
REM  dit ou le poser.
REM ============================================================================

echo.
echo   EXPORT WEB DE PIKS THEFT AUTO
echo   -----------------------------
echo.

REM --- Git Bash ---------------------------------------------------------------
set "BASH=C:\Program Files\Git\bin\bash.exe"
if not exist "%BASH%" set "BASH=C:\Program Files (x86)\Git\bin\bash.exe"
if not exist "%BASH%" (
  echo   Git Bash est introuvable.
  echo   Installez Git pour Windows, ou lancez a la main :
  echo       bash outils/exporter.sh
  echo.
  pause
  exit /b 1
)

REM --- Godot : on le cherche la ou il se trouve d'habitude ---------------------
REM  L'executable doit s'appeler godot.exe pour que le script bash le trouve ;
REM  s'il porte son nom de version, on en pose une copie renommee a cote.
set "GODOTDIR="
for %%D in (
  "%~dp0outils\godot"
  "%~dp0..\godot"
  "C:\Godot"
  "C:\Program Files\Godot"
  "%LOCALAPPDATA%\Godot"
  "%USERPROFILE%\Downloads"
  "%USERPROFILE%\Documents\Godot"
) do (
  if exist "%%~D\godot.exe" set "GODOTDIR=%%~D"
)

if not defined GODOTDIR (
  where godot.exe >nul 2>&1 && set "GODOTDIR=PATH"
)

if not defined GODOTDIR (
  echo   Godot introuvable.
  echo.
  echo   Le plus simple : creez le dossier
  echo       %~dp0outils\godot
  echo   et copiez-y votre Godot 4.5 en le renommant   godot.exe
  echo   ^(une copie renommee suffit, l'original reste ou il est^)
  echo.
  echo   Il faut aussi les modeles d'exportation 4.5 :
  echo   dans Godot, Editeur ^> Gerer les modeles d'exportation ^> Telecharger.
  echo.
  pause
  exit /b 1
)

if "%GODOTDIR%"=="PATH" (
  echo   Godot : trouve dans le PATH
  "%BASH%" -lc "cd \"$(pwd)\" && bash outils/exporter.sh"
) else (
  echo   Godot : %GODOTDIR%
  REM  On convertit C:\x\y en /c/x/y pour le PATH de Git Bash.
  set "G=%GODOTDIR%"
  set "G=!G:\=/!"
  set "G=!G:C:=/c!"
  set "G=!G:c:=/c!"
  set "G=!G:F:=/f!"
  set "G=!G:f:=/f!"
  set "G=!G:D:=/d!"
  set "G=!G:d:=/d!"
  "%BASH%" -lc "PATH=\"!G!:$PATH\" bash outils/exporter.sh"
)

set CODE=%ERRORLEVEL%
echo.
if not "%CODE%"=="0" (
  echo   L'EXPORT A ECHOUE ^(code %CODE%^). Le message ci-dessus dit pourquoi.
  echo.
  pause
  exit /b %CODE%
)

echo   -----------------------------------------------------------------
echo   Export termine. Il reste a pousser :
echo.
echo       git add -A ^&^& git commit -m "Export web" ^&^& git push
echo.
echo   ^(ou GitHub Desktop : les fichiers de sortie/ apparaissent modifies^)
echo   -----------------------------------------------------------------
echo.
pause
