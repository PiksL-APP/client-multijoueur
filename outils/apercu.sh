#!/bin/bash
# apercu.sh [code] [sortie] [ou] [hauteur] [nuit]
#   ou : "port" (cherche un mouillage) ou "x,y" en tuiles.
# Un morceau de la ville PROCÉDURALE et ses huit voisins, sous l'ambiance du
# jeu. La ville n'avait aucun banc : on ne la voyait qu'en jouant, donc
# seulement là où le hasard d'une manche menait.
cd "$(dirname "$0")/.."
mkdir -p /tmp/apercu
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/hv timeout 300 xvfb-run -a -s "-screen 0 1280x760x24" ${GODOT:-godot} --path . \
	--rendering-driver opengl3 --resolution 1280x760 res://outils/apercu.tscn \
	--code="${1:-APERCU}" --sortie="${2:-/tmp/apercu/ville.png}" --ou="${3:-port}" \
	--hauteur="${4:-420}" --nuit="${5:-0.35}" > /tmp/apercu/log 2>&1
grep -ia "script error\|aperçu\|^photo" /tmp/apercu/log | head -5
