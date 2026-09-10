/**
 * Moteur tarifaire Woyofal — port JavaScript de
 * dart/lib/tarif_model.dart (source de vérité).
 *
 * Grille CRSE applicable au 01/01/2026 (décision n°2025-140).
 * La parité avec le moteur Dart est garantie par les vecteurs partagés
 * shared/tarif_test_vectors.json (voir test/tarif.test.mjs).
 *
 * NE PAS modifier une constante ici sans passer par le moteur Dart
 * et régénérer les vecteurs (cd dart && dart run tool/generate_test_vectors.dart).
 */

// Arrondi à 0,1 kWh vers le bas (floor) — comme Dart _r1
const r1 = (v) => Math.floor(v * 10) / 10;
// Arrondi à 0,1 kWh vers le haut (ceil) — comme SENELEC / Dart _r1Ceil
const r1Ceil = (v) => Math.ceil(v * 10) / 10;

export const CATEGORIES = {
  dpp: {
    label: 'Maison — petit compteur (DPP)',
    tarifT1: 82.0,
    tarifT2: 136.49,
    limiteT1: 150,
    seuilTVA: 250,
    professionnel: false,
  },
  dmp: {
    label: 'Maison — compteur moyen (DMP)',
    tarifT1: 111.23,
    tarifT2: 143.54,
    limiteT1: 50,
    seuilTVA: 300,
    professionnel: false,
  },
  ppp: {
    label: 'Boutique / activité — petit compteur (PPP)',
    tarifT1: 147.43,
    tarifT2: 189.84,
    limiteT1: 50,
    seuilTVA: 500,
    professionnel: true,
  },
  pmp: {
    label: 'Boutique / activité — compteur moyen (PMP)',
    tarifT1: 165.01,
    tarifT2: 191.01,
    limiteT1: 100,
    seuilTVA: 500,
    professionnel: true,
  },
};

export const REDEVANCE = { mono: 429, tri: 1427 };
export const TAXE_COMMUNALE = 0.025;
export const TVA = 0.18;

/**
 * Coût énergie HT pour `kwh` rechargés avec `cumulAvant` déjà consommés ce mois.
 * En Woyofal il n'y a pas de 3e tranche : au-delà de T1, tout est au tarif T2.
 */
export function calculerCoutEnergie(cat, kwh, cumulAvant) {
  const c = CATEGORIES[cat];
  const k = r1(Math.max(0, kwh));
  let cumul = r1(Math.max(0, cumulAvant));
  let remaining = k;
  let cout = 0;

  if (cumul < c.limiteT1 && remaining > 0) {
    const dispoT1 = c.limiteT1 - cumul;
    const kwhDansT1 = Math.min(remaining, dispoT1);
    cout += kwhDansT1 * c.tarifT1;
    cumul += kwhDansT1;
    remaining -= kwhDansT1;
  }
  if (remaining > 0) {
    cout += remaining * c.tarifT2;
  }
  return cout;
}

/**
 * Détail complet d'une recharge : énergie, taxe communale, redevance, TVA.
 * Réplique exacte de TarifWoyofal.detailCoutRecharge.
 */
export function detailCoutRecharge(
  cat,
  { kwh, cumulAvant, premiere = false, nbMoisRedevance = 1, compteur = 'mono' },
) {
  const c = CATEGORIES[cat];
  const redevanceActive = REDEVANCE[compteur];

  const k = r1(Math.max(0, kwh));
  const cumulDebut = r1(Math.max(0, cumulAvant));
  const cumulApres = cumulDebut + k;

  const energie = calculerCoutEnergie(cat, k, cumulDebut);
  const taxeCommunale = energie * TAXE_COMMUNALE;
  const redevance = premiere ? redevanceActive * nbMoisRedevance : 0;

  let tva = 0;
  if (k > 0) {
    if (c.professionnel) {
      // Professionnel : TVA toujours, base = énergie + taxe + redevance
      tva = (energie + taxeCommunale + redevanceActive) * TVA;
    } else if (cumulApres > c.seuilTVA) {
      // Domestique : TVA sur la portion au-delà du seuil mensuel
      const kwhAvantSeuil =
        cumulDebut >= c.seuilTVA ? 0 : c.seuilTVA - cumulDebut;
      const kwhApresSeuil = Math.max(0, k - kwhAvantSeuil);
      const coutApresSeuil = calculerCoutEnergie(cat, kwhApresSeuil, c.seuilTVA);
      const taxeApresSeuil = coutApresSeuil * TAXE_COMMUNALE;
      // Règle Senelec : la redevance entre dans la base TVA à chaque recharge post-seuil
      tva = (coutApresSeuil + taxeApresSeuil + redevanceActive) * TVA;
    }
  }

  return {
    energie,
    taxeCommunale,
    redevance,
    tva,
    total: energie + taxeCommunale + redevance + tva,
  };
}

/**
 * Montant (FCFA) → kWh crédités. Réplique exacte de estimerKwhPourMontant
 * (recherche binaire + arrondi SENELEC vers le haut).
 */
export function estimerKwhPourMontant(
  cat,
  montant,
  cumulAvant,
  { premiere = false, nbMoisRedevance = 1, precision = 0.1, kwhMax = 2000, compteur = 'mono' } = {},
) {
  const cout = (kwh) =>
    detailCoutRecharge(cat, {
      kwh,
      cumulAvant: r1Ceil(cumulAvant),
      premiere,
      nbMoisRedevance,
      compteur,
    }).total;

  let lo = 0;
  let hi = kwhMax;
  let bestLow = 0;
  for (let i = 0; i < 80; i++) {
    const mid = r1Ceil((lo + hi) / 2);
    if (cout(mid) <= montant) {
      bestLow = mid;
      lo = r1Ceil(mid + precision);
    } else {
      hi = r1Ceil(mid - precision);
    }
    if (Math.abs(hi - lo) < precision) break;
  }

  const coutLow = cout(bestLow);
  const bestHigh = r1Ceil(bestLow + precision);
  const coutHigh = cout(bestHigh);

  const ecartLow = Math.abs(montant - coutLow);
  const ecartHigh = Math.abs(coutHigh - montant);

  const best = ecartHigh <= ecartLow ? bestHigh : bestLow;
  return Math.round(best * 10) / 10;
}
