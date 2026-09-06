extends Node
## Les clés d'accès à Supabase.
##
## Elles vivent dans `config.cfg`, hors dépôt (règle Piks-l : aucun secret dans
## un fichier suivi). La clé publiable est de toute façon destinée au client,
## mais la garder hors du dépôt évite qu'une rotation oblige à réécrire
## l'historique. Le fichier est écrit au moment de l'export, à partir de
## `config.exemple.cfg`.

var url: String = ""
var cle_publique: String = ""
var version: String = "0.1.0"

func _ready() -> void:
	var fichier := ConfigFile.new()
	if fichier.load("res://config.cfg") != OK:
		push_error("config.cfg absent : copiez config.exemple.cfg et renseignez les clés.")
		return
	url = String(fichier.get_value("supabase", "url", "")).rstrip("/")
	cle_publique = String(fichier.get_value("supabase", "cle_publique", ""))
	version = String(fichier.get_value("jeu", "version", "0.1.0"))

func est_configure() -> bool:
	return url != "" and cle_publique != ""

## URL du socket temps réel. Le `vsn=1.0.0` n'est pas décoratif : sans lui le
## serveur répond dans un format d'enveloppe différent (tableau positionnel).
func url_temps_reel() -> String:
	var base := url.replace("https://", "wss://").replace("http://", "ws://")
	return "%s/realtime/v1/websocket?apikey=%s&vsn=1.0.0" % [base, cle_publique]

func url_rest(chemin: String) -> String:
	return "%s/rest/v1/%s" % [url, chemin]

func entetes_rest() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + cle_publique,
		"Authorization: Bearer " + cle_publique,
		"Content-Type: application/json",
	])
