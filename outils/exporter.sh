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

# LE KIT VA À CÔTÉ DE L'EXPORT, PAS DEDANS. C'est lui qui tient les menus dans
# le navigateur (`web/coque.html` le charge), mais il est exclu du paquet du
# moteur (`exclude_filter` du préréglage) : embarqué deux fois, il pèserait
# onze mégaoctets pour rien. Oublier cette copie, c'est une page qui charge
# sur du vide — d'où sa place ici, dans le script, et non dans une consigne.
rm -rf sortie/kit
cp -r web/kit sortie/kit
touch sortie/.gdignore
echo "Export dans $racine/sortie (kit compris)"
