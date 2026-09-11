#!/bin/bash
# bord.sh [sortie] [--recul=N] — le banc de la corniche : tout ce qui borde le vide.
cd "$(dirname "$0")/.."
sortie="${1:-/tmp/photo/banc_bord.png}"; shift
mkdir -p "$(dirname "$sortie")" /tmp/bord
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/hbo timeout 240 xvfb-run -a -s "-screen 0 1400x900x24" ${GODOT:-godot} --path . \
	--rendering-driver opengl3 --resolution 1400x900 res://outils/bord.tscn \
	--sortie="$sortie" "$@" > /tmp/bord/log 2>&1
grep -iE "script error|refusé|error:" /tmp/bord/log | grep -viE "alsa|still in use|leaked|Pages" | head -5
