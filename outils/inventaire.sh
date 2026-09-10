#!/bin/bash
# inventaire.sh — bâtit Pikstown et dit quels modèles du kit ne sont JAMAIS posés.
cd "$(dirname "$0")/.."
mkdir -p /tmp/inventaire
timeout 900 ${GODOT:-godot} --headless --path . --script res://outils/inventaire.gd 2>&1 \
	| grep -v "^ *at:\|still in use\|WARNING" | tee /tmp/inventaire/liste.txt
