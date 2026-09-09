#!/bin/bash
# vitrine.sh <intérieur> [sortie] [azimut] [inclinaison] [pantin]
#
# Le cinquième argument (n'importe quoi de non vide) pose le PERSONNAGE du jeu
# à l'entrée. C'est la seule façon de juger une ÉCHELLE : un appartement est
# beau tout seul, et rien ne dit qu'on y tient debout tant qu'on n'a mis
# personne dedans.
#   ./outils/vitrine.sh taudis "" 0 72 pantin   -> l'angle de la caméra du jeu
# Photographie un intérieur de repaire. Le rendu se REGARDE : c'est la seule
# façon de voir qu'un canapé traverse un mur.
cd "$(dirname "$0")/.."
mkdir -p /tmp/vitrine
[ -z "$SANS_IMPORT" ] && timeout 300 ${GODOT:-godot} --headless --path . --import > /tmp/vitrine/import.log 2>&1
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/hv timeout 100 xvfb-run -a -s "-screen 0 1600x900x24" ${GODOT:-godot} --path . \
	--rendering-driver opengl3 --resolution 1600x900 res://outils/vitrine.tscn \
	--interieur="$1" --sortie="${2:-/tmp/vitrine/$1.png}" \
	--azimut="${3:-34}" --inclinaison="${4:-52}" ${5:+--pantin} > /tmp/vitrine/log 2>&1
grep -i "script error\|error:\|SCRIPT ERROR" /tmp/vitrine/log | grep -v "ALSA\|status <\|still in use" | head -10
