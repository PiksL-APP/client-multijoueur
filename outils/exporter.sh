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

# ⚠ DIRE CE QUI MANQUE, PAS « command not found ». Le script tombait sur un
# message du shell qui ne nommait ni Godot, ni la version attendue, ni la marche
# à suivre — et sous Git Bash sur Windows, c'est l'échec le plus probable des
# deux : l'exécutable ne s'appelle pas `godot` et n'est pas dans le PATH.
if ! command -v godot >/dev/null 2>&1; then
  cat >&2 <<'AIDE'
`godot` introuvable dans le PATH.

  Linux / macOS : mettez le binaire (ou un lien) nommé `godot` dans le PATH.
  Windows (Git Bash) : l'exécutable doit s'appeler `godot.exe` et être dans un
  dossier du PATH. Le plus court, sans rien installer, depuis le dépôt :

      PATH="/c/chemin/vers/le/dossier/de/godot:$PATH" bash outils/exporter.sh

  (le fichier doit y être nommé `godot.exe` — une copie renommée suffit)
AIDE
  exit 1
fi

version="$(godot --version 2>/dev/null | head -1)"
case "$version" in
  4.5*) ;;
  *) echo "⚠ Godot $version — le projet est en 4.5. L'export peut échouer ou mentir." >&2 ;;
esac

# ⚠ LA VERSION SE GRAVE AVANT L'EXPORT, pas après : elle doit entrer dans le
# paquet. `sortie/` est versionné et servi tel quel par Vercel — pousser les
# sources sans réexporter laisse la page en ligne à la veille, et rien ne le
# disait. Le commit gravé ici s'affiche dans l'éditeur : une page en ligne dit
# maintenant d'elle-même de quand elle date.
commit="$(git rev-parse --short HEAD 2>/dev/null || echo inconnu)"
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  commit="$commit+"        # le « + » dit : exporté avec des modifications non commitées
fi
{
  echo "class_name Version"
  echo "extends RefCounted"
  echo "## ÉCRIT PAR outils/exporter.sh — ne pas modifier à la main."
  echo ""
  echo "const COMMIT := \"$commit\""
  echo "const DATE := \"$(date '+%d/%m/%Y %H:%M')\""
  echo ""
  echo "static func etiquette() -> String:"
  echo "	if COMMIT == \"sources\":"
  echo "		return \"sources (non exporté)\""
  echo "	return \"%s · %s\" % [COMMIT, DATE]"
} > commun/version.gd
echo "version gravée : $commit"

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
echo "Export dans $racine/sortie (kit compris) — version $commit"
echo
echo "⚠ sortie/ est VERSIONNÉ : c'est lui que Vercel sert. Il reste à faire"
echo "   git add -A && git commit && git push"
