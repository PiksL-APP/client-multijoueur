#!/usr/bin/env bash
# EST-CE QUE `sortie/` EST À JOUR ? — à lancer avant de committer.
#
# ⚠ LE PIÈGE QUE CE SCRIPT EXISTE POUR ATTRAPER. `sortie/` est l'export web,
# et il est VERSIONNÉ : Vercel le sert tel quel. Pousser les sources ne met donc
# rien à jour en ligne. C'est arrivé une fois, sur une journée entière de
# travail : tout était poussé, la page en ligne était toujours celle de la
# veille, et rien — ni git, ni Vercel, ni la page — ne le disait.
#
#     ./outils/verifier-export.sh
#
# Sort 1 si l'export est plus vieux qu'un fichier de source. Bon candidat pour
# un hook `pre-commit`.
set -uo pipefail
racine="$(cd "$(dirname "$0")/.." && pwd)"
cd "$racine"

paquet="sortie/index.pck"
if [ ! -f "$paquet" ]; then
  echo "sortie/index.pck absent — lancez ./outils/exporter.sh" >&2
  exit 1
fi

# La source la plus récente, hors sortie/ et hors dossiers de travail.
recent="$(find . -type f \( -name '*.gd' -o -name '*.tscn' -o -name '*.glb' \
  -o -name '*.png' -o -name '*.ttf' -o -name 'project.godot' \) \
  -not -path './sortie/*' -not -path './.godot/*' -not -path './.git/*' \
  -newer "$paquet" -print -quit 2>/dev/null)"

if [ -n "$recent" ]; then
  echo "⚠ L'EXPORT EST PÉRIMÉ. Au moins un fichier est plus récent que sortie/index.pck :"
  echo "    $recent"
  echo "  Relancez ./outils/exporter.sh avant de committer, sinon la page en"
  echo "  ligne restera celle du dernier export."
  exit 1
fi
echo "sortie/ est à jour (plus récent que toutes les sources)."
