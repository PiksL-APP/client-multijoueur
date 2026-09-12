#!/bin/bash
# photo_v2.sh <sortie> [args du banc...]
#   ./outils/photo_v2.sh /tmp/v.png --vue=oblique --vise=20,20 --recul=18 --heure=0.0
cd "$(dirname "$0")/.."
sortie="${1:-/tmp/ville2.png}"; shift
mkdir -p "$(dirname "$sortie")" /tmp/photo
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/hph timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" ${GODOT:-godot} --path . \
	--rendering-driver opengl3 --resolution 1920x1080 res://outils/photo_v2.tscn \
	--sortie="$sortie" "$@" > /tmp/photo/log 2>&1
grep -i "bati en\|photo \|carte \|script error\|SCRIPT ERROR" /tmp/photo/log | head -8
grep -i "error:\|warning:" /tmp/photo/log | grep -v "ALSA\|status <\|still in use\|resources still" | sort | uniq -c | sort -rn | head -12
