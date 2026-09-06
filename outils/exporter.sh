#!/usr/bin/env bash
# Réexport du jeu en HTML5. Attend `godot` (4.5) dans le PATH et les modèles
# d'export de la même version installés.
#
# Le `config.cfg` doit exister à la racine : il porte les clés Supabase et il
# est hors dépôt. Sans lui, le jeu se lance mais reste hors ligne.
set -euo pipefail
racine="$(cd "$(dirname "$0")/.." && pwd)"
cd "$racine"

if [ ! -f config.cfg ]; then
  echo "config.cfg manquant — copiez config.exemple.cfg et renseignez les clés." >&2
  exit 1
fi

godot --headless --path . --import
godot --headless --path . --export-release "Web" sortie/index.html
echo "Export dans $racine/sortie"
