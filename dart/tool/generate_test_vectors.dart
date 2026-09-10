// Génère shared/tarif_test_vectors.json à la racine du monorepo.
// Source de vérité : lib/models/tarif_model.dart (grille CRSE 2026, décision n°2025-140).
// Ces vecteurs sont consommés par les tests Dart, JS (js/) et Python
// pour garantir la parité des trois moteurs.
//
// Usage : dart run tool/generate_test_vectors.dart   (depuis dart/)

import 'dart:convert';
import 'dart:io';

import 'package:sakkanal_tarif_engine/tarif_model.dart';

TarifWoyofal _tarif(String cat, TypeCompteur compteur) {
  switch (cat) {
    case 'dpp':
      return TarifWoyofal.dpp(typeCompteur: compteur);
    case 'dmp':
      return TarifWoyofal.dmp(typeCompteur: compteur);
    case 'ppp':
      return TarifWoyofal.ppp(typeCompteur: compteur);
    case 'pmp':
      return TarifWoyofal.pmp(typeCompteur: compteur);
    default:
      throw ArgumentError(cat);
  }
}

void main() {
  final vectors = <Map<String, dynamic>>[];

  // Cas de coût : (catégorie, kWh, cumulAvant, première recharge, nb mois redevance)
  final costCases = <List<dynamic>>[
    // DPP — tout en T1
    ['dpp', 50.0, 0.0, true, 1],
    ['dpp', 100.0, 0.0, false, 1],
    // DPP — franchissement T1 → T2
    ['dpp', 100.0, 100.0, false, 1],
    ['dpp', 200.0, 0.0, true, 1],
    // DPP — franchissement du seuil TVA (250) en cours de recharge
    ['dpp', 100.0, 200.0, false, 1],
    ['dpp', 300.0, 0.0, true, 1],
    // DPP — entièrement post-seuil
    ['dpp', 50.0, 300.0, false, 1],
    // DPP — redevance multi-mois (rattrapage)
    ['dpp', 100.0, 0.0, true, 3],
    // DPP — arrondi 0,1 kWh
    ['dpp', 33.7, 0.0, false, 1],
    ['dpp', 149.95, 0.0, false, 1],
    // DMP — T1 courte (50), TVA à 300
    ['dmp', 40.0, 0.0, true, 1],
    ['dmp', 100.0, 0.0, false, 1],
    ['dmp', 100.0, 250.0, false, 1],
    // PPP — TVA dès le 1er kWh (professionnel)
    ['ppp', 40.0, 0.0, true, 1],
    ['ppp', 200.0, 0.0, false, 1],
    // PMP
    ['pmp', 150.0, 0.0, true, 1],
    ['pmp', 400.0, 100.0, false, 1],
  ];

  for (final c in costCases) {
    for (final compteur in [TypeCompteur.monophase, TypeCompteur.triphase]) {
      final t = _tarif(c[0] as String, compteur);
      final b = t.detailCoutRecharge(
        kwh: c[1] as double,
        cumulAvant: c[2] as double,
        premiere: c[3] as bool,
        nbMoisRedevance: c[4] as int,
      );
      vectors.add({
        'type': 'cout',
        'categorie': c[0],
        'compteur': compteur == TypeCompteur.monophase ? 'mono' : 'tri',
        'kwh': c[1],
        'cumulAvant': c[2],
        'premiere': c[3],
        'nbMoisRedevance': c[4],
        'attendu': {
          'energie': b.energie,
          'taxeCommunale': b.taxeCommunale,
          'redevance': b.redevance,
          'tva': b.tva,
          'total': b.total,
        },
      });
    }
  }

  // Cas montant → kWh (le sens du simulateur public)
  final amountCases = <List<dynamic>>[
    ['dpp', 500.0, 0.0, false],
    ['dpp', 1000.0, 0.0, false],
    ['dpp', 2500.0, 0.0, true],
    ['dpp', 5000.0, 0.0, false],
    ['dpp', 5000.0, 140.0, false],
    ['dpp', 10000.0, 0.0, false],
    ['dpp', 10000.0, 240.0, false],
    ['dmp', 5000.0, 0.0, false],
    ['ppp', 5000.0, 0.0, false],
    ['pmp', 10000.0, 0.0, false],
  ];

  for (final c in amountCases) {
    final t = _tarif(c[0] as String, TypeCompteur.monophase);
    final kwh = t.estimerKwhPourMontant(
      c[1] as double,
      c[2] as double,
      premiere: c[3] as bool,
    );
    vectors.add({
      'type': 'montant',
      'categorie': c[0],
      'compteur': 'mono',
      'montant': c[1],
      'cumulAvant': c[2],
      'premiere': c[3],
      'attendu': {'kwh': kwh},
    });
  }

  final out = const JsonEncoder.withIndent('  ').convert({
    'source': 'dart/lib/tarif_model.dart',
    'grille': 'CRSE 01/01/2026 (décision n°2025-140)',
    'genere_par': 'tool/generate_test_vectors.dart',
    'vectors': vectors,
  });

  final file = File('../shared/tarif_test_vectors.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('$out\n');
  stdout.writeln('${vectors.length} vecteurs écrits dans ${file.path}');
}
