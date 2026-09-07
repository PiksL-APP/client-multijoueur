extends Node
## Dépôt des scores et lecture des classements, en REST sur Supabase.
##
## Le dépôt passe par une fonction SQL et non par un INSERT direct : les tables
## n'accordent que la lecture à la clé publique. La fonction rejette les scores
## invraisemblables au regard de la durée de la manche. Ça ne rend pas la triche
## impossible — sans serveur autoritaire, rien ne le rend impossible — mais ça
## borne les dégâts à des valeurs qu'un bon joueur pourrait atteindre.

signal depot_termine(reussi: bool, message: String)
signal classement_recu(jeu: String, lignes: Array)
signal carnet_recu(lignes: Array)

## Toutes les lignes de score d'un joueur, les plus récentes d'abord : de
## quoi tenir son carnet (meilleurs scores, nombre de parties).
func demander_carnet(joueur_id: String) -> void:
	if not Config.est_configure():
		carnet_recu.emit([])
		return
	var requete := HTTPRequest.new()
	add_child(requete)
	requete.request_completed.connect(func(_r, code_http, _h, corps):
		requete.queue_free()
		var lignes: Array = []
		if code_http == 200:
			var analyse = JSON.parse_string(corps.get_string_from_utf8())
			if typeof(analyse) == TYPE_ARRAY:
				lignes = analyse
		carnet_recu.emit(lignes)
	)
	var chemin := "jeu_scores?select=jeu,score,cree_le&joueur_id=eq.%s&order=cree_le.desc&limit=300" % joueur_id.uri_encode()
	requete.request(Config.url_rest(chemin), Config.entetes_rest(), HTTPClient.METHOD_GET)

func deposer(jeu: String, code: String, duree_s: int, resultats: Array) -> void:
	if not Config.est_configure():
		depot_termine.emit(false, "clés absentes")
		return
	var requete := HTTPRequest.new()
	add_child(requete)
	requete.request_completed.connect(func(_r, code_http, _h, corps):
		requete.queue_free()
		var reussi: bool = code_http >= 200 and code_http < 300
		var message := ""
		if not reussi:
			message = String(corps.get_string_from_utf8()).substr(0, 200)
			push_warning("Dépôt de score refusé (%d) : %s" % [code_http, message])
		depot_termine.emit(reussi, message)
	)
	var corps := JSON.stringify({
		"p_jeu": jeu,
		"p_code": code,
		"p_duree_s": duree_s,
		"p_resultats": resultats,
	})
	requete.request(Config.url_rest("rpc/jeu_deposer_partie"), Config.entetes_rest(), HTTPClient.METHOD_POST, corps)

## Les meilleurs scores d'un jeu. Un joueur peut apparaître plusieurs fois côté
## base ; on ne garde que sa meilleure ligne à l'affichage.
func demander_classement(jeu: String, limite: int = 10) -> void:
	if not Config.est_configure():
		classement_recu.emit(jeu, [])
		return
	var requete := HTTPRequest.new()
	add_child(requete)
	requete.request_completed.connect(func(_r, code_http, _h, corps):
		requete.queue_free()
		var lignes: Array = []
		if code_http == 200:
			var analyse = JSON.parse_string(corps.get_string_from_utf8())
			if typeof(analyse) == TYPE_ARRAY:
				var vus := {}
				for ligne in analyse:
					if typeof(ligne) != TYPE_DICTIONARY:
						continue
					var id := String(ligne.get("joueur_id", ""))
					if vus.has(id):
						continue
					vus[id] = true
					lignes.append(ligne)
					if lignes.size() >= limite:
						break
		classement_recu.emit(jeu, lignes)
	)
	var chemin := "jeu_scores?select=joueur_id,pseudo,score,cree_le&jeu=eq.%s&order=score.desc&limit=%d" % [jeu, limite * 4]
	requete.request(Config.url_rest(chemin), Config.entetes_rest(), HTTPClient.METHOD_GET)
