// Vérifie que le moteur Dart reproduit les vecteurs partagés
// (shared/tarif_test_vectors.json), eux-mêmes générés par ce moteur :
// ce test protège contre toute régression du moteur de référence.
import 'dart:convert';
import 'dart:io';

import 'package:sakkanal_tarif_engine/tarif_model.dart';
import 'package:test/test.dart';

TarifWoyofal _tarif(String cat, String compteur) {
  final tc = compteur == 'mono' ? TypeCompteur.monophase : TypeCompteur.triphase;
  switch (cat) {
    case 'dpp':
      return TarifWoyofal.dpp(typeCompteur: tc);
    case 'dmp':
      return TarifWoyofal.dmp(typeCompteur: tc);
    case 'ppp':
      return TarifWoyofal.ppp(typeCompteur: tc);
    case 'pmp':
      return TarifWoyofal.pmp(typeCompteur: tc);
    default:
      throw ArgumentError(cat);
  }
}

void main() {
  final file = File('../shared/tarif_test_vectors.json');
  final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final vectors = (data['vectors'] as List).cast<Map<String, dynamic>>();

  test('44 vecteurs partagés', () {
    expect(vectors.length, 44);
  });

  for (final (i, v) in vectors.indexed) {
    final t = _tarif(v['categorie'] as String, v['compteur'] as String);
    if (v['type'] == 'cout') {
      test('#$i cout ${v['categorie']}/${v['compteur']} kwh=${v['kwh']} cumul=${v['cumulAvant']}', () {
        final b = t.detailCoutRecharge(
          kwh: (v['kwh'] as num).toDouble(),
          cumulAvant: (v['cumulAvant'] as num).toDouble(),
          premiere: v['premiere'] as bool,
          nbMoisRedevance: v['nbMoisRedevance'] as int,
        );
        final a = v['attendu'] as Map<String, dynamic>;
        expect(b.energie, closeTo((a['energie'] as num).toDouble(), 1e-6));
        expect(b.taxeCommunale, closeTo((a['taxeCommunale'] as num).toDouble(), 1e-6));
        expect(b.redevance, closeTo((a['redevance'] as num).toDouble(), 1e-6));
        expect(b.tva, closeTo((a['tva'] as num).toDouble(), 1e-6));
        expect(b.total, closeTo((a['total'] as num).toDouble(), 1e-6));
      });
    } else {
      test('#$i montant ${v['categorie']} montant=${v['montant']} cumul=${v['cumulAvant']}', () {
        final kwh = t.estimerKwhPourMontant(
          (v['montant'] as num).toDouble(),
          (v['cumulAvant'] as num).toDouble(),
          premiere: v['premiere'] as bool,
        );
        expect(kwh, closeTo(((v['attendu'] as Map)['kwh'] as num).toDouble(), 1e-6));
      });
    }
  }
}
