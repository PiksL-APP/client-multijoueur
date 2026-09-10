#!/bin/bash
# tableau.sh [sortie] [triche]
# Photographie les trois barres de respect du district et les cinq humeurs.
# Un second argument ajoute une incrustation : `triche` (le menu du code
# Konami) ou `roue` (la roue des stations de radio).
cd "$(dirname "$0")/.."
mkdir -p /tmp/tableau
[ -z "$SANS_IMPORT" ] && timeout 300 ${GODOT:-godot} --headless --path . --import > /tmp/tableau/import.log 2>&1
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/ht timeout 200 xvfb-run -a -s "-screen 0 1600x900x24" ${GODOT:-godot} --path . \
	--rendering-driver opengl3 --resolution 1600x900 res://outils/tableau.tscn \
	--sortie="${1:-/tmp/tableau/respect.png}" ${2:+--$2} > /tmp/tableau/log 2>&1
grep -iE "script error|error:" /tmp/tableau/log | grep -v "ALSA\|status <\|still in use" | head -10
grep -E "^photo" /tmp/tableau/log
