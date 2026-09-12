#!/bin/bash
# echelle.sh <sortie> [--modeles=a,b,c] [--famille=nature] [--combien=24]
#   La planche de contrôle : des modèles posés comme la palette les pose,
#   devant une voiture et une silhouette de joueur, sur un damier d'un mètre.
cd "$(dirname "$0")/.."
sortie="${1:-/tmp/regle.png}"; shift
mkdir -p "$(dirname "$sortie")" /tmp/regle
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/hre timeout 600 xvfb-run -a -s "-screen 0 1920x1080x24" ${GODOT:-godot} --path . \
	--rendering-driver opengl3 --resolution 1920x1080 res://outils/echelle.tscn \
	--sortie="$sortie" "$@" > /tmp/regle/log 2>&1
grep -i "posé à l'échelle\|planche \|script error\|SCRIPT ERROR" /tmp/regle/log | head -40
