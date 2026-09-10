import 'dart:math';

class CoutBreakdown {
  final double energie; // coût énergie HT (avant taxe communale)
  final double taxeCommunale; // taxe communale
  final double redevance; // redevance (si 1ère recharge)
  final double tva; // TVA (si seuil dépassé)

  const CoutBreakdown({
    required this.energie,
    required this.taxeCommunale,
    required this.redevance,
    required this.tva,
  });

  // Total arrondi au multiple de 5
  double get total => energie + taxeCommunale + redevance + tva;
}

// Catégories Woyofal (prépayé)
enum WoyofalCategorie { dpp, dmp, ppp, pmp }

// Ajout: type de compteur pour la redevance
enum TypeCompteur { monophase, triphase }

class TarifWoyofal {
  // Catégorie (par défaut: DPP)
  final WoyofalCategorie categorie;

  // Type de compteur (impact redevance 1ère recharge)
  final TypeCompteur typeCompteur;

  // Valeurs redevance selon compteur
  final double redevanceMonophase; // 429 F
  final double redevanceTriphase; // 1427 F

  // Tarifs énergie (FCFA/kWh)
  final double tarifT1; // 1re tranche
  final double tarifT2; // 2e tranche (sert aussi pour la 3e en Woyofal)

  // Paramètres de tranches et taxes
  final double limiteT1; // seuil haut de la 1re tranche (kWh cumulés/mois)
  final double seuilTVA; // au‑delà de ce cumul, TVA s’applique
  final double taxeCommunale; // 2,5%
  final double tva; // 18%

  // Getter redevance active
  double get redevanceActive => typeCompteur == TypeCompteur.monophase
      ? redevanceMonophase
      : redevanceTriphase;

  // Helper: arrondir à 0,1 kWh vers le bas (floor)
  static double _r1(double v) => (v * 10).floor() / 10.0;

  // Helper: arrondir à 0,1 kWh vers le haut (ceil) - comme SENELEC
  static double _r1Ceil(double v) => (v * 10).ceil() / 10.0;

  // Par défaut, DPP (Domestique Petite Puissance)
  const TarifWoyofal({
    this.categorie = WoyofalCategorie.dpp,
    this.typeCompteur = TypeCompteur.monophase,
    this.redevanceMonophase = 429,
    this.redevanceTriphase = 1427,
    this.tarifT1 = 82.00, // DPP T1 (Décret 2025-140, applicable 01/01/2026)
    this.tarifT2 = 136.49, // DPP T2
    this.limiteT1 = 150, // DPP: 0–150 kWh
    this.seuilTVA = 250, // DPP: au‑delà de 250 kWh
    this.taxeCommunale = 0.025,
    this.tva = 0.18,
  });

  // DPP: 0–150 kWh à 91,17 | 151–250 kWh à 136,49
  const TarifWoyofal.dpp({TypeCompteur typeCompteur = TypeCompteur.monophase})
      : this(
          categorie: WoyofalCategorie.dpp,
          typeCompteur: typeCompteur,
        );

  // DMP: 0–50 kWh à 111,23 | 51–300 kWh à 143,54
  const TarifWoyofal.dmp({TypeCompteur typeCompteur = TypeCompteur.monophase})
      : this(
          categorie: WoyofalCategorie.dmp,
          tarifT1: 111.23,
          tarifT2: 143.54,
          limiteT1: 50,
          seuilTVA: 300,
          typeCompteur: typeCompteur,
        );

  // PPP: 0–50 kWh à 147,43 | 51–500 kWh à 189,84 (Décret 2025-140)
  const TarifWoyofal.ppp({TypeCompteur typeCompteur = TypeCompteur.monophase})
      : this(
          categorie: WoyofalCategorie.ppp,
          tarifT1: 147.43,
          tarifT2: 189.84,
          limiteT1: 50,
          seuilTVA: 500,
          typeCompteur: typeCompteur,
        );

  // PMP: 0–100 kWh à 165,01 | 101–500 kWh à 191,01
  const TarifWoyofal.pmp({TypeCompteur typeCompteur = TypeCompteur.monophase})
      : this(
          categorie: WoyofalCategorie.pmp,
          tarifT1: 165.01,
          tarifT2: 191.01,
          limiteT1: 100,
          seuilTVA: 500,
          typeCompteur: typeCompteur,
        );

  String get libelleCategorie {
    switch (categorie) {
      case WoyofalCategorie.dpp:
        return 'Domestique Petite Puissance (DPP)';
      case WoyofalCategorie.dmp:
        return 'Domestique Moyenne Puissance (DMP)';
      case WoyofalCategorie.ppp:
        return 'Professionnel Petite Puissance (PPP)';
      case WoyofalCategorie.pmp:
        return 'Professionnel Moyenne Puissance (PMP)';
    }
  }

  // Calcul énergie: la 3e tranche (si existait) est valorisée au tarif T2 en Woyofal.
  double calculerCoutEnergie(double kwh, double cumulAvant) {
    // Arrondi UNE seule fois des entrées
    final k = _r1(max(0.0, kwh));
    double cumul = _r1(max(0.0, cumulAvant));
    double remaining = k;
    double cout = 0.0;

    // Tranche T1 (pas de ré‑arrondi interne)
    if (cumul < limiteT1 && remaining > 0) {
      final dispoT1 = limiteT1 - cumul; // valeur brute
      final kwhDansT1 = min(remaining, dispoT1);
      cout += kwhDansT1 * tarifT1;
      cumul += kwhDansT1;
      remaining -= kwhDansT1;
    }

    // Tranche T2
    if (remaining > 0) {
      cout += remaining * tarifT2;
    }

    return cout;
  }

  // Ajout: helper professionnel
  bool get isProfessionnel =>
      categorie == WoyofalCategorie.ppp || categorie == WoyofalCategorie.pmp;

  double calculerCoutRecharge({
    required double kwh,
    required double cumulAvant,
    bool premiere = false,
    int nbMoisRedevance = 1,
  }) {
    final breakdown = detailCoutRecharge(
      kwh: kwh,
      cumulAvant: cumulAvant,
      premiere: premiere,
      nbMoisRedevance: nbMoisRedevance,
    );
    // AJOUT: arrondi réglementaire par recharge
    return breakdown.total;
  }

  CoutBreakdown detailCoutRecharge({
    required double kwh,
    required double cumulAvant,
    bool premiere = false,
    bool redevanceDejaFacturee = false, // conservé pour compatibilité
    bool redevanceDejaTaxee = false, // conservé pour compatibilité
    int nbMoisRedevance =
        1, // nombre de mois de redevance à facturer (1 par défaut)
  }) {
    // Arrondi des entrées une seule fois
    final k = _r1(max(0.0, kwh));
    final cumulDebut = _r1(max(0.0, cumulAvant));
    final cumulApres = cumulDebut + k; // pas de ré‑arrondi

    final baseEnergie = calculerCoutEnergie(k, cumulDebut);
    final taxe = baseEnergie * taxeCommunale;

    // Redevance facturée seulement sur la 1ère recharge (montant)
    // Si plusieurs mois sans recharge, on facture tous les mois accumulés
    final rede = premiere ? (redevanceActive * nbMoisRedevance) : 0.0;

    double tvaPart = 0.0;

    if (k > 0) {
      if (isProfessionnel) {
        // Base TVA = énergie + taxe + redevance (professionnel: TVA toujours)
        final baseTVA = baseEnergie + taxe + redevanceActive;
        tvaPart = baseTVA * tva;
      } else {
        // Domestique: TVA si cumul après > seuilTVA
        if (cumulApres > seuilTVA) {
          // Portion de la recharge au‑dessus du seuil (sans ré‑arrondis multiples)
          final kwhAvantSeuil =
              cumulDebut >= seuilTVA ? 0.0 : (seuilTVA - cumulDebut);
          final kwhApresSeuil = max(0.0, k - kwhAvantSeuil);

          final coutApresSeuilBase = calculerCoutEnergie(
            kwhApresSeuil,
            seuilTVA,
          );
          final taxeCommApresSeuil = coutApresSeuilBase * taxeCommunale;

          // Règle Senelec: la redevance entre dans la base TVA à CHAQUE recharge post‑seuil
          final baseTVA =
              coutApresSeuilBase + taxeCommApresSeuil + redevanceActive;
          tvaPart = baseTVA * tva;
        }
      }
    }

    return CoutBreakdown(
      energie: baseEnergie,
      taxeCommunale: taxe,
      redevance: rede,
      tva: tvaPart,
    );
  }

  double estimerKwhPourMontant(
    double montant,
    double cumulAvant, {
    bool premiere = false,
    int nbMoisRedevance = 1,
    double precision = 0.1,
    double kwhMax = 2000,
  }) {
    // Recherche binaire pour trouver le kWh dont le coût est <= montant
    double lo = 0, hi = kwhMax, bestLow = 0;
    for (int i = 0; i < 80; i++) {
      final mid = _r1Ceil((lo + hi) / 2);
      final cout = calculerCoutRecharge(
        kwh: mid,
        cumulAvant: _r1Ceil(cumulAvant),
        premiere: premiere,
        nbMoisRedevance: nbMoisRedevance,
      );
      if (cout <= montant) {
        bestLow = mid;
        lo = _r1Ceil(mid + precision);
      } else {
        hi = _r1Ceil(mid - precision);
      }
      if ((hi - lo).abs() < precision) break;
    }

    // SENELEC arrondit vers le haut : on compare bestLow et bestLow + 0.1
    // et on choisit celui qui est le plus proche du montant demandé
    final coutLow = calculerCoutRecharge(
      kwh: bestLow,
      cumulAvant: _r1Ceil(cumulAvant),
      premiere: premiere,
      nbMoisRedevance: nbMoisRedevance,
    );

    final bestHigh = _r1Ceil(bestLow + precision);
    final coutHigh = calculerCoutRecharge(
      kwh: bestHigh,
      cumulAvant: _r1Ceil(cumulAvant),
      premiere: premiere,
      nbMoisRedevance: nbMoisRedevance,
    );

    // Écarts par rapport au montant demandé
    final ecartLow = (montant - coutLow).abs();
    final ecartHigh = (coutHigh - montant).abs();

    // SENELEC préfère le kWh supérieur si l'écart est plus petit ou égal
    // (arrondi vers le haut en cas d'égalité)
    final best = (ecartHigh <= ecartLow) ? bestHigh : bestLow;

    return double.parse(best.toStringAsFixed(1)); // 1 décimale
  }
}
