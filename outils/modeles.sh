#!/bin/bash
# modeles.sh — réécrit commun/modeles_du_kit.gd depuis le contenu de modeles/.
cd "$(dirname "$0")/.."
timeout 300 ${GODOT:-godot} --headless --path . --script res://outils/modeles.gd 2>&1 \
	| grep -v "^ *at:\|still in use\|WARNING\|leaked\|Pages in use"
