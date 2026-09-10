#!/bin/bash
# chez_soi.sh <intérieur> [sortie] [nuit]
#   nuit : 0 plein jour, 1 pleine nuit, 0,85 par défaut (l'heure bleue).
#   ⚠ Sans elle, le banc photographie l'heure qu'il est VRAIMENT : le cycle
#   jour/nuit tourne en quinze minutes et deux photos d'affilée ne se
#   comparent plus.
# L'appartement tel que CARNAGE le montrera : ambiance du jeu, caméra du jeu,
# cadrage du jeu. La vitrine juge la décoration ; celui-ci juge la LISIBILITÉ.
cd "$(dirname "$0")/.."
mkdir -p /tmp/chez_soi
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/hv timeout 200 xvfb-run -a -s "-screen 0 1280x760x24" ${GODOT:-godot} --path . \
	--rendering-driver opengl3 --resolution 1280x760 res://outils/chez_soi.tscn \
	--interieur="$1" --sortie="${2:-/tmp/chez_soi/$1.png}" --nuit="${3:-0.85}" > /tmp/chez_soi/log 2>&1
grep -i "script error\|chez soi\|^photo" /tmp/chez_soi/log | head -5
