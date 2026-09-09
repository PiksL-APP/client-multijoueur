#!/bin/bash
# carte.sh [quartier|ville] [sortie] [azimut] [inclinaison] [zoom]
# Photographie la ville dessinée (`jeux/carnage/quartiers.gd`). Le cadrage se
# CALCULE sur ce qui a été bâti : agrandir un quartier ne le fait pas sortir
# du cadre.
cd "$(dirname "$0")/.."
mkdir -p /tmp/carte
[ -z "$SANS_IMPORT" ] && timeout 300 ${GODOT:-godot} --headless --path . --import > /tmp/carte/import.log 2>&1
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/hc timeout 200 xvfb-run -a -s "-screen 0 1600x900x24" ${GODOT:-godot} --path . \
	--rendering-driver opengl3 --resolution 1600x900 res://outils/carte.tscn \
	--quartier="${1:-ville}" --sortie="${2:-/tmp/carte/${1:-ville}.png}" \
	--azimut="${3:-214}" --inclinaison="${4:-34}" --zoom="${5:-1}" > /tmp/carte/log 2>&1
grep -iE "script error|error:" /tmp/carte/log | grep -v "ALSA\|status <\|still in use" | head -10
grep -E "^cadré|^photo" /tmp/carte/log
