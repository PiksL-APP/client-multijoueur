// Rend les SVG de _transfert/logos/ en PNG 256 × 256, fond transparent, via
// Chromium sans tête — le seul moteur SVG complet à portée, et il rend le
// filtre de tremblé (feTurbulence + feDisplacementMap) fidèlement.
//
//   node outils/logos_png.mjs
//
// Écrit : _transfert/logos/png/NN_cle.png  +  _transfert/logos/planche.png
import { chromium } from '/tmp/node_modules/playwright/index.mjs';
import { readdirSync, mkdirSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ici = dirname(fileURLToPath(import.meta.url));
const src = join(ici, '..', '_transfert', 'logos');
const out = join(src, 'png');
mkdirSync(out, { recursive: true });

const svgs = readdirSync(src).filter((f) => f.endsWith('.svg')).sort();
const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });
const p = await b.newPage({ viewport: { width: 256, height: 256 }, deviceScaleFactor: 1 });

// La police du texte : Archivo Black, servie en base64 pour ne dépendre
// d'aucun réseau — c'est celle des titres du kit.
const police = readFileSync(join(ici, '..', 'polices', 'ArchivoBlack.ttf')).toString('base64');

for (const f of svgs) {
  const svg = readFileSync(join(src, f), 'utf8');
  await p.setContent(
    `<style>@font-face{font-family:"Archivo Black";src:url(data:font/ttf;base64,${police})}
     html,body{margin:0;background:transparent}</style>${svg}`,
    { waitUntil: 'load' },
  );
  await p.evaluate(() => document.fonts.ready);
  await p.screenshot({ path: join(out, f.replace('.svg', '.png')), omitBackground: true });
}
console.log(`${svgs.length} PNG rendus dans ${out}`);

// La planche : les logos sur carton, dix par ligne, pour juger d'un coup d'œil.
// En data: URI — une page posée par setContent n'a pas le droit de lire file://.
const cases = svgs.map((f) => {
  const b64 = readFileSync(join(out, f.replace('.svg', '.png'))).toString('base64');
  return `<div class="c"><img src="data:image/png;base64,${b64}"><span>${f.slice(3, -4)}</span></div>`;
}).join('');
const planche = await b.newPage({ viewport: { width: 1400, height: 200 + Math.ceil(svgs.length / 10) * 150 } });
await planche.setContent(`<style>
  body{margin:0;background:#1a1420;display:grid;grid-template-columns:repeat(10,130px);gap:10px;padding:20px;font:12px monospace;color:#ccc}
  .c{display:flex;flex-direction:column;align-items:center;gap:4px}
  img{width:110px;height:110px;background:linear-gradient(150deg,#d9b184,#a97f56);border-radius:4px;border:2px solid rgba(0,0,0,.5)}
</style>${cases}`);
await planche.waitForTimeout(400);
await planche.screenshot({ path: join(src, 'planche.png'), fullPage: true });
console.log('planche : ' + join(src, 'planche.png'));
await b.close();
