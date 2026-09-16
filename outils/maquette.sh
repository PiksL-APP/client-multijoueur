#!/bin/bash
# maquette.sh <sortie.png> [--oblique=28 --pente=0.72 --recul=0.82]
cd "$(dirname "$0")/.."
sortie="${1:-/tmp/aurones-3d.png}"; shift
mkdir -p "$(dirname "$sortie")" /tmp/maquette
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/hmq timeout 1200 xvfb-run -a -s "-screen 0 2560x1440x24" ${GODOT:-godot} --path . \
	--rendering-driver opengl3 --resolution 2560x1440 res://outils/maquette.tscn \
	--sortie="$sortie" "$@" > /tmp/maquette/log 2>&1
grep -iE "terrain |maquette |script error|SCRIPT ERROR|ERROR:" /tmp/maquette/log | head -12
