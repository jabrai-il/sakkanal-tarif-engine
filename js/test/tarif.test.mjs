// Vérifie la parité du moteur JS avec le moteur Dart via les vecteurs partagés.
// Usage : node test/tarif.test.mjs   (depuis js/)

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { detailCoutRecharge, estimerKwhPourMontant } from '../tarif.js';

const here = dirname(fileURLToPath(import.meta.url));
const vectorsPath = join(here, '..', '..', 'shared', 'tarif_test_vectors.json');
const { vectors, grille } = JSON.parse(readFileSync(vectorsPath, 'utf8'));

const EPS = 1e-6;
let failures = 0;

for (const [i, v] of vectors.entries()) {
  if (v.type === 'cout') {
    const got = detailCoutRecharge(v.categorie, {
      kwh: v.kwh,
      cumulAvant: v.cumulAvant,
      premiere: v.premiere,
      nbMoisRedevance: v.nbMoisRedevance,
      compteur: v.compteur,
    });
    for (const key of ['energie', 'taxeCommunale', 'redevance', 'tva', 'total']) {
      if (Math.abs(got[key] - v.attendu[key]) > EPS) {
        failures++;
        console.error(
          `FAIL #${i} cout ${v.categorie}/${v.compteur} kwh=${v.kwh} cumul=${v.cumulAvant} ` +
            `${key}: attendu ${v.attendu[key]}, obtenu ${got[key]}`,
        );
      }
    }
  } else if (v.type === 'montant') {
    const got = estimerKwhPourMontant(v.categorie, v.montant, v.cumulAvant, {
      premiere: v.premiere,
      compteur: v.compteur,
    });
    if (Math.abs(got - v.attendu.kwh) > EPS) {
      failures++;
      console.error(
        `FAIL #${i} montant ${v.categorie} ${v.montant}F cumul=${v.cumulAvant}: ` +
          `attendu ${v.attendu.kwh} kWh, obtenu ${got} kWh`,
      );
    }
  }
}

if (failures > 0) {
  console.error(`\n${failures} écart(s) Dart↔JS — parité rompue (${grille}).`);
  process.exit(1);
}
console.log(`OK — ${vectors.length} vecteurs, parité Dart↔JS confirmée (${grille}).`);
