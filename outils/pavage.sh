#!/bin/bash
# pavage.sh [tuiles séparées par des virgules] [sortie]
# Photographie les tuiles du kit de routes AU-DESSUS DE L'EAU : tout bleu qui
# apparaît dans un carré est un trou dans le plancher de la tuile.
cd "$(dirname "$0")/.."
mkdir -p /tmp/pavage
[ -z "$SANS_IMPORT" ] && timeout 300 ${GODOT:-godot} --headless --path . --import > /tmp/pavage/import.log 2>&1
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/hp timeout 180 xvfb-run -a -s "-screen 0 1600x1200x24" ${GODOT:-godot} --path . \
	--rendering-driver opengl3 --resolution 1600x1200 res://outils/pavage.tscn \
	${1:+--tuiles="$1"} --sortie="${2:-/tmp/pavage/planche.png}" > /tmp/pavage/log 2>&1
grep -i "script error\|error:\|SCRIPT ERROR" /tmp/pavage/log | grep -v "ALSA\|status <\|still in use" | head -10
