#!/bin/bash
# compiler.sh — charge tous les scripts du jeu, autoloads compris, et liste
# ceux que Godot refuse. C'est le filet entre deux parties : `--check-only`
# ne sait pas compiler un fichier qui parle à un autoload.
cd "$(dirname "$0")/.."
mkdir -p /tmp/compil
[ -z "$SANS_IMPORT" ] && timeout 300 ${GODOT:-godot} --headless --path . --import > /tmp/compil/import.log 2>&1
timeout 200 ${GODOT:-godot} --headless --path . res://outils/compiler.tscn > /tmp/compil/log 2>&1
grep -E "Parse Error|Compile Error|Failed to load script|REFUSÉ" /tmp/compil/log | sort -u | head -20
grep -E "^── " /tmp/compil/log
