// PUBLIER UNE TUILE DU PAYS DEPUIS L'ÉDITEUR — en un bouton, sans passer par
// un poste.
//
// ⚠ POURQUOI CE FICHIER EXISTE. L'éditeur tourne dans le navigateur : il sait
// enregistrer une tuile (Ctrl+S, dans le stockage du navigateur) et l'exporter
// (un téléchargement), mais un navigateur ne pousse pas dans Git. Il fallait
// déposer le fichier dans `cartes/`, commiter, pousser — et le dernier geste
// oublié une fois sur deux. Ici, l'éditeur envoie la tuile à cette fonction,
// qui la COMMITE SUR MAIN par l'API GitHub. Le push déclenche l'export web
// (`.github/workflows/exporter-web.yml`), et Vercel sert le pays retouché
// quelques minutes plus tard.
//
// (Jusqu'au 19/09 elle publiait `pikstown.gd`, le dessin ASCII de l'ancienne
// ville. Le jeu ne tourne plus que sur l'Archipel : elle publie ses tuiles.)
//
// CE QU'IL FAUT UNE FOIS, dans Vercel → Settings → Environment Variables :
//   GITHUB_TOKEN_CARTE   un jeton GitHub « fine-grained », limité à CE dépôt,
//                        permission Contents : Read and write. Rien d'autre.
//   CLE_PUBLICATION      une phrase de ton choix ; l'éditeur la demande une
//                        fois et la garde. Sans elle, la fonction refuse tout.
//   DEPOT_GITHUB         (facultatif) « propriétaire/dépôt », par défaut
//                        PiksL-APP/client-multijoueur.
//
// ⚠ CE QUE LA FONCTION NE SAIT PAS FAIRE, EXPRÈS. Elle n'écrit QUE dans
// `cartes/`, QUE des fichiers nommés `pays-<kx>-<ky>.json` ou
// `temoin-<nom>.json`, et QUE du JSON qui a la forme d'une Ville2 (une
// taille, des lots, des routes). Une clé qui fuit ne permet donc que de
// redessiner une tuile — jamais de toucher au code, aux clés, au workflow.
//
// ⚠ LA TUILE ARRIVE COMPRESSÉE. Une tuile de 200 cases fait trois mégaoctets
// de JSON ; le corps d'une requête Vercel plafonne à 4,5 Mo, et l'API GitHub
// veut du base64 (+33 %). L'éditeur envoie donc le JSON gzippé puis encodé en
// base64 (`contenu_gz`) : dix fois moins. On décompresse ici, on vérifie, et
// on renvoie le JSON clair à GitHub.

const zlib = require("zlib");

const BRANCHE = "main";
const NOM_TUILE = /^(pays-\d{1,2}-\d{1,2}|temoin-[a-z0-9-]{1,40})$/;
const TAILLE_MAX = 40 * 1024 * 1024; // le JSON clair, une fois décompressé

module.exports = async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ ok: false, erreur: "POST attendu" });

  const jeton = process.env.GITHUB_TOKEN_CARTE || "";
  const cleAttendue = process.env.CLE_PUBLICATION || "";
  const depot = process.env.DEPOT_GITHUB || "PiksL-APP/client-multijoueur";
  if (!jeton || !cleAttendue) {
    return res.status(503).json({ ok: false, erreur: "Publication non configurée : GITHUB_TOKEN_CARTE et CLE_PUBLICATION manquent sur Vercel." });
  }

  const corps = typeof req.body === "string" ? lireJson(req.body) : (req.body || {});
  const cle = String(corps.cle || "");
  const nom = String(corps.nom || "");
  const note = String(corps.note || "").slice(0, 120);

  if (!memeTexte(cle, cleAttendue)) {
    return res.status(401).json({ ok: false, erreur: "Clé de publication refusée." });
  }
  if (!NOM_TUILE.test(nom)) {
    return res.status(400).json({ ok: false, erreur: "Nom de tuile refusé (attendu : pays-<kx>-<ky> ou temoin-<nom>)." });
  }

  // Le contenu : gzippé en base64 de préférence, en clair sinon.
  let contenu = "";
  try {
    if (corps.contenu_gz) {
      contenu = zlib.gunzipSync(Buffer.from(String(corps.contenu_gz), "base64")).toString("utf8");
    } else {
      contenu = String(corps.contenu || "");
    }
  } catch (_e) {
    return res.status(400).json({ ok: false, erreur: "Contenu illisible (gzip attendu)." });
  }
  if (Buffer.byteLength(contenu, "utf8") > TAILLE_MAX) {
    return res.status(413).json({ ok: false, erreur: "Tuile trop grosse (> 40 Mo)." });
  }
  const ville = lireJson(contenu);
  if (!ville || !Array.isArray(ville.taille) || !Array.isArray(ville.lots) || !Array.isArray(ville.routes)) {
    return res.status(400).json({ ok: false, erreur: "Ce n'est pas une tuile (il faut taille, lots et routes)." });
  }

  const fichier = `cartes/${nom}.json`;
  const entetes = {
    Authorization: `Bearer ${jeton}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "piks-editeur",
    "Content-Type": "application/json",
  };
  const adresse = `https://api.github.com/repos/${depot}/contents/${fichier}`;

  // Le sha du fichier en place : l'API le demande pour écraser, et c'est ce
  // qui empêche d'écrire par-dessus un fichier qu'on n'a pas vu.
  let sha = undefined;
  const lecture = await fetch(`${adresse}?ref=${BRANCHE}`, { headers: entetes });
  if (lecture.status === 200) {
    sha = (await lecture.json()).sha;
  } else if (lecture.status !== 404) {
    return res.status(502).json({ ok: false, erreur: `GitHub ne rend pas le fichier (${lecture.status}).` });
  }

  const message = `Tuile ${nom} : ` + (note || "publiée depuis l'éditeur")
    + "\n\nCommit fait par l'éditeur de carte (api/publier-carte.js) ; l'export web suit.";
  const ecriture = await fetch(adresse, {
    method: "PUT",
    headers: entetes,
    body: JSON.stringify({
      message,
      content: Buffer.from(contenu, "utf8").toString("base64"),
      sha,
      branch: BRANCHE,
      committer: { name: "Éditeur de carte", email: "app@piks-l.com" },
    }),
  });
  const reponse = await ecriture.json().catch(() => ({}));
  if (ecriture.status !== 200 && ecriture.status !== 201) {
    const detail = reponse && reponse.message ? reponse.message : `HTTP ${ecriture.status}`;
    return res.status(502).json({ ok: false, erreur: `GitHub refuse le commit : ${detail}` });
  }
  const commit = reponse.commit || {};
  return res.status(200).json({
    ok: true,
    fichier,
    commit: String(commit.sha || "").slice(0, 7),
    adresse: commit.html_url || "",
    actions: `https://github.com/${depot}/actions`,
  });
};

function lireJson(texte) {
  try { return JSON.parse(texte); } catch (_e) { return null; }
}

// Comparaison sans court-circuit : le temps de réponse ne dit rien de la clé.
function memeTexte(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
