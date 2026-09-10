#!/usr/bin/env python3
"""Vérifie la parité du moteur Python avec les vecteurs partagés (shared/tarif_test_vectors.json)."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tarif_woyofal import TarifWoyofal, TypeCompteur  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
VECTORS = os.path.join(HERE, "..", "shared", "tarif_test_vectors.json")
EPS = 1e-6

KEYS = {"energie": "energie", "taxeCommunale": "taxe_communale", "redevance": "redevance", "tva": "tva", "total": "total"}


def tarif_for(cat: str, compteur: str) -> TarifWoyofal:
    tc = TypeCompteur.MONOPHASE if compteur == "mono" else TypeCompteur.TRIPHASE
    return getattr(TarifWoyofal, cat)(tc)


def main() -> int:
    with open(VECTORS, encoding="utf-8") as f:
        data = json.load(f)
    vectors = data["vectors"]
    failures = 0
    for i, v in enumerate(vectors):
        t = tarif_for(v["categorie"], v["compteur"])
        if v["type"] == "cout":
            b = t.detail_cout_recharge(v["kwh"], v["cumulAvant"], v["premiere"], v["nbMoisRedevance"])
            for jkey, pkey in KEYS.items():
                got = getattr(b, pkey)
                if abs(got - v["attendu"][jkey]) > EPS:
                    failures += 1
                    print(f"FAIL #{i} cout {v['categorie']}/{v['compteur']} kwh={v['kwh']} "
                          f"cumul={v['cumulAvant']} {jkey}: attendu {v['attendu'][jkey]}, obtenu {got}")
        elif v["type"] == "montant":
            got = t.estimer_kwh_pour_montant(v["montant"], v["cumulAvant"], v["premiere"])
            if abs(got - v["attendu"]["kwh"]) > EPS:
                failures += 1
                print(f"FAIL #{i} montant {v['categorie']} montant={v['montant']} "
                      f"cumul={v['cumulAvant']}: attendu {v['attendu']['kwh']}, obtenu {got}")
        else:
            failures += 1
            print(f"FAIL #{i} type inconnu {v['type']}")
    print(f"{len(vectors)} vecteurs, {failures} échec(s) -- grille {data['grille']}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
