class_name Version
extends RefCounted
## LA VERSION DU PAQUET, écrite par `outils/exporter.sh` AVANT l'export.
##
## ⚠ POURQUOI CE FICHIER EXISTE. `sortie/` est un artefact VERSIONNÉ : c'est lui
## que Vercel sert, tel quel. Pousser les sources ne met donc rien à jour en
## ligne — il faut avoir relancé `exporter.sh` avant de committer. C'est arrivé :
## une journée de travail poussée, et la page en ligne toujours à la veille,
## sans que rien ne le dise. Rien, dans le jeu, ne permettait de savoir QUEL
## commit on regardait.
##
## Maintenant si : le commit est gravé dans le paquet et l'éditeur l'affiche.
## Une page en ligne dit d'elle-même de quand elle date.
##
## Les valeurs ci-dessous sont celles d'un dépôt jamais exporté ; le script les
## remplace. Le fichier reste versionné pour que le projet compile sans lui.

const COMMIT := "sources"
const DATE := "non exporté"

static func etiquette() -> String:
	if COMMIT == "sources":
		return "sources (non exporté)"
	return "%s · %s" % [COMMIT, DATE]
