#!/bin/bash
# pont.sh [sortie] — le banc du pont : un chenal, un tablier, vus de près.
cd "$(dirname "$0")/.."
sortie="${1:-/tmp/photo/banc_pont.png}"
mkdir -p "$(dirname "$sortie")" /tmp/pont
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/hpo timeout 240 xvfb-run -a -s "-screen 0 1400x900x24" ${GODOT:-godot} --path . \
	--rendering-driver opengl3 --resolution 1400x900 res://outils/pont.tscn \
	--sortie="$sortie" > /tmp/pont/log 2>&1
grep -iE "script error|error:" /tmp/pont/log | grep -viE "alsa|still in use|leaked|Pages" | head -5
