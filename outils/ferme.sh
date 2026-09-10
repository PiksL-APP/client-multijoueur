#!/bin/bash
# ferme.sh [sortie]
# Photographie les six fonctions de `Terrain` dont dépend l'écran de la ferme.
cd "$(dirname "$0")/.."
mkdir -p /tmp/ferme
[ -z "$SANS_IMPORT" ] && timeout 300 ${GODOT:-godot} --headless --path . --import > /tmp/ferme/import.log 2>&1
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/hf timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" ${GODOT:-godot} --path . \
	--rendering-driver opengl3 --resolution 1280x720 res://outils/ferme.tscn \
	--sortie="${1:-/tmp/ferme/banc.png}" > /tmp/ferme/log 2>&1
grep -iE "script error|error:" /tmp/ferme/log | grep -v "ALSA\|still in use\|leaked" | head -5
grep -E "^photo|^dernier" /tmp/ferme/log
