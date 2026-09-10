# sakkanal-tarif-engine

Moteur tarifaire **Woyofal** (électricité prépayée Senelec, Sénégal) en trois implémentations alignées au franc près : **Dart** (source de vérité), **JavaScript** et **Python**. La parité des trois moteurs est garantie par un jeu commun de **44 vecteurs de test** couvrant les franchissements de tranche, le seuil de TVA, la redevance multi-mois et les règles d'arrondi.

Ce dépôt accompagne l'article :

> Seck, D. (2026). *Tarification par blocs et réinitialisation calendaire dans l'électricité prépayée : défauts structurels et réforme à budget constant. Le cas du système Woyofal au Sénégal.* Working paper, version 1.0. DOI : à attribuer (Zenodo).

Le moteur Dart est celui de l'application mobile [Sakkanal](https://sakkanal.app) ; le moteur JavaScript est celui du simulateur web public.

*English summary below.*

## Grille tarifaire implémentée

Grille CRSE applicable au 1er janvier 2026 (décision n° 2025-140 du 26 décembre 2025). Catégories prépayées :

| Catégorie | Tranche 1 | Tranche 2 | Limite T1 | Seuil TVA |
|---|---|---|---|---|
| DPP (domestique petite puissance) | 82,00 F/kWh | 136,49 F/kWh | 150 kWh | 250 kWh |
| DMP (domestique moyenne puissance) | 111,23 | 143,54 | 50 kWh | 300 kWh |
| PPP (professionnel petite puissance) | 147,43 | 189,84 | 50 kWh | TVA dès le 1er kWh |
| PMP (professionnel moyenne puissance) | 165,01 | 191,01 | 100 kWh | TVA dès le 1er kWh |

Règles communes : taxe communale 2,5 % sur l'énergie ; TVA 18 % sur la portion post-seuil (énergie + taxe communale + redevance) ; redevance 429 F (monophasé) ou 1 427 F (triphasé) sur la première recharge du mois, multipliée par le nombre de mois sans recharge ; le cumul de tranche se réinitialise chaque mois calendaire. Les kWh sont arrondis une seule fois à 0,1 kWh (vers le haut côté crédit, comme Senelec). Voir les commentaires de `dart/lib/tarif_model.dart` pour le détail.

## Structure

```
dart/      package Dart pur (sans Flutter) : lib/tarif_model.dart, test/, tool/generate_test_vectors.dart
js/        module ES : tarif.js, test/tarif.test.mjs
python/    tarif_woyofal.py, test_vectors.py
shared/    tarif_test_vectors.json (44 vecteurs, générés par le moteur Dart)
models/    analyse_recettes_alternative.xlsx : modèle de recettes des quatre composantes de la réforme (A à D)
```

## Lancer les tests

```bash
cd dart && dart pub get && dart test          # moteur de référence
cd js && node test/tarif.test.mjs             # parité JS
python3 python/test_vectors.py                # parité Python
```

Toute modification de la grille se fait **dans le moteur Dart uniquement**, puis `cd dart && dart run tool/generate_test_vectors.dart` régénère les vecteurs ; les ports JS et Python doivent ensuite repasser.

## API (identique dans les trois langages)

- `detailCoutRecharge(kwh, cumulAvant, premiere, nbMoisRedevance)` : décomposition énergie / taxe communale / redevance / TVA / total d'une recharge de `kwh` sachant `cumulAvant` kWh déjà achetés dans le mois.
- `estimerKwhPourMontant(montant, cumulAvant, premiere)` : kWh crédités pour un montant donné (sens du reçu Woyofal), recherche binaire avec arrondi Senelec.
- `calculerCoutEnergie(kwh, cumulAvant)` : coût énergie hors taxes.

Exemple (Python) :

```python
from tarif_woyofal import TarifWoyofal
t = TarifWoyofal.dpp()
t.detail_cout_recharge(100, 200)      # 100 kWh après 200 kWh dans le mois : TVA sur la portion > 250
t.estimer_kwh_pour_montant(5000, 0)   # kWh pour un billet de 5 000 F en début de mois
```

## Reproduire les chiffres de l'article

| Résultat de l'article | Où le vérifier |
|---|---|
| Pénalité TVA par recharge post-seuil, 77,22 F | vecteurs `cout` DPP `cumulAvant ≥ 250`, poste `tva` |
| Arbitrage calendaire, jusqu'à 8 378 F | `models/…xlsx`, feuille `A_Arbitrage` |
| Équivalence F(x) = 136,49·x − 8 173,5 au-delà de 150 kWh | feuilles `Paramètres` et `C_Ciblage` |
| Tarif social 24 F/kWh à budget constant (α = 0,5) | feuille `C_Ciblage` |
| Bi-horaire Boiteux–Steiner | feuille `D_BiHoraire` |

## Licences

Code (Dart, JavaScript, Python) : licence MIT. Vecteurs de test et classeur de modélisation : Creative Commons Attribution 4.0 (CC BY 4.0). Les paramètres tarifaires sont ceux publiés par la CRSE et n'appartiennent à personne.

## Citer

Voir `CITATION.cff`. Le DOI Zenodo est celui de la version archivée ; le dépôt GitHub est la version vivante.

---

## English summary

Reference implementation of Senegal's **Woyofal** prepaid electricity tariff (Senelec) in Dart, JavaScript and Python, aligned to the franc with the official CRSE schedule in force since 1 January 2026, and cross-checked by 44 shared test vectors. Companion code for the working paper *Increasing Block Tariffs and Calendar Reset in Prepaid Electricity: Structural Flaws and a Budget-Neutral Reform. The Case of the Woyofal System in Senegal* (Seck, 2026). Run `dart test`, `node test/tarif.test.mjs` and `python3 python/test_vectors.py` to verify parity. The spreadsheet in `models/` reproduces the revenue analysis of the four reform components. Code under MIT; data and spreadsheet under CC BY 4.0.
