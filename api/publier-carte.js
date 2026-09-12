// PUBLIER LA CARTE DEPUIS L'ÉDITEUR — en un bouton, sans passer par un poste.
//
// ⚠ POURQUOI CE FICHIER EXISTE. L'éditeur tourne dans le navigateur : il sait
// exporter `pikstown.gd`, mais un navigateur ne pousse pas dans Git. Il fallait
// copier le fichier, l'écraser dans le dépôt, commiter, pousser — quatre gestes
// pour un dessin, et le quatrième oublié une fois sur deux. Ici, l'éditeur
// envoie le fichier à cette fonction, qui le COMMITE SUR MAIN par l'API GitHub.
// Le push déclenche l'export web (`.github/workflows/exporter-web.yml`), et
// Vercel sert la nouvelle ville quelques minutes plus tard.
//
// CE QU'IL FAUT UNE FOIS, dans Vercel → Settings → Environment Variables :
//   GITHUB_TOKEN_CARTE   un jeton GitHub « fine-grained », limité à CE dépôt,
//                        permission Contents : Read and write. Rien d'autre.
//   CLE_PUBLICATION      une phrase de ton choix ; l'éditeur la demande une
//                        fois et la garde. Sans elle, la fonction refuse tout.
//   DEPOT_GITHUB         (facultatif) « propriétaire/dépôt », par défaut
//                        PiksL-APP/client-multijoueur.
//
// ⚠ CE QUE LA FONCTION NE SAIT PAS FAIRE, EXPRÈS. Elle n'écrit QU'UN fichier,
// `jeux/carnage/pikstown.gd`, et seulement s'il commence par
// `class_name PlanPikstown`. Une clé qui fuit ne permet donc que de redessiner
// la ville — jamais de toucher au code, aux clés, au workflow.

const FICHIER = "jeux/carnage/pikstown.gd";
const BRANCHE = "main";
const TAILLE_MAX = 900 * 1024; // l'API « contents » plafonne à 1 Mo

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
  const contenu = String(corps.contenu || "");
  const note = String(corps.note || "").slice(0, 120);

  if (!memeTexte(cle, cleAttendue)) {
    return res.status(401).json({ ok: false, erreur: "Clé de publication refusée." });
  }
  if (!contenu.startsWith("class_name PlanPikstown")) {
    return res.status(400).json({ ok: false, erreur: "Ce n'est pas un pikstown.gd (il doit commencer par class_name PlanPikstown)." });
  }
  if (Buffer.byteLength(contenu, "utf8") > TAILLE_MAX) {
    return res.status(413).json({ ok: false, erreur: "Fichier trop gros pour l'API GitHub (> 900 Ko)." });
  }
  if (!/const PLAN: Array\[String\] = \[/.test(contenu) || !/const RELIEF: Array\[String\] = \[/.test(contenu)) {
    return res.status(400).json({ ok: false, erreur: "PLAN ou RELIEF absent du fichier." });
  }

  const entetes = {
    Authorization: `Bearer ${jeton}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "pikstown-editeur",
    "Content-Type": "application/json",
  };
  const adresse = `https://api.github.com/repos/${depot}/contents/${FICHIER}`;

  // Le sha du fichier en place : l'API le demande pour écraser, et c'est ce
  // qui empêche d'écrire par-dessus un fichier qu'on n'a pas vu.
  let sha = undefined;
  const lecture = await fetch(`${adresse}?ref=${BRANCHE}`, { headers: entetes });
  if (lecture.status === 200) {
    sha = (await lecture.json()).sha;
  } else if (lecture.status !== 404) {
    return res.status(502).json({ ok: false, erreur: `GitHub ne rend pas le fichier (${lecture.status}).` });
  }

  const message = "Carte : " + (note || "publiée depuis l'éditeur")
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
    commit: String(commit.sha || "").slice(0, 7),
    adresse: commit.html_url || "",
    actions: `https://github.com/${depot}/actions`,
  });
};

function lireJson(texte) {
  try { return JSON.parse(texte); } catch (_e) { return {}; }
}

// Comparaison sans court-circuit : le temps de réponse ne dit rien de la clé.
function memeTexte(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
