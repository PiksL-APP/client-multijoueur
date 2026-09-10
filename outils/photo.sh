#!/bin/bash
# photo.sh <sortie> [args du banc...]
#   ./outils/photo.sh /tmp/v.png --vise=52,31 --recul=22 --oblique=50 --pente=0.22
# Photographie Pikstown. Sans --oblique, c'est la vue verticale d'ensemble.
cd "$(dirname "$0")/.."
sortie="${1:-/tmp/pikstown.png}"; shift
mkdir -p "$(dirname "$sortie")" /tmp/photo
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/hph timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" ${GODOT:-godot} --path . \
	--rendering-driver opengl3 --resolution 1920x1080 res://outils/photo_pikstown.tscn \
	--sortie="$sortie" "$@" > /tmp/photo/log 2>&1
grep -i "bati en\|photo \|script error\|SCRIPT ERROR" /tmp/photo/log | head -6
grep -i "error:" /tmp/photo/log | grep -v "ALSA\|status <\|still in use\|resources still" | head -6
