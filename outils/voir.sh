#!/bin/bash
# voir.sh nom1,nom2 [ecart] [sortie]
cd "$(dirname "$0")/.."
[ -z "$SANS_IMPORT" ] && timeout 300 ${GODOT:-godot} --headless --path . --import > /tmp/import.log 2>&1
export LIBGL_ALWAYS_SOFTWARE=1
HOME=/tmp/hv timeout 60 xvfb-run -a -s "-screen 0 1280x720x24" ${GODOT:-godot} --path . --rendering-driver opengl3 --resolution 1280x720 res://outils/visionneuse.tscn --voir=$1 --ecart=${2:-8} --sortie=${3:-/tmp/t2d/voxel.png} > /tmp/t2d/log 2>&1
grep -i "script error\|error:" /tmp/t2d/log | grep -v "ALSA\|status <\|still in use" | head -5
