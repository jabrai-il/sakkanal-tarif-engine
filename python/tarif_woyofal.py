#!/usr/bin/env python3
"""
Moteur tarifaire Woyofal (Senelec, Sénégal) -- port Python de référence.

Grille CRSE applicable au 01/01/2026 (décision n° 2025-140 du 26/12/2025).
Logique identique à dart/lib/tarif_model.dart (source de vérité) ; la parité
est vérifiée par shared/tarif_test_vectors.json (voir test_vectors.py).
"""

from dataclasses import dataclass
from enum import Enum
import math


class WoyofalCategorie(Enum):
    DPP = "dpp"
    DMP = "dmp"
    PPP = "ppp"
    PMP = "pmp"


class TypeCompteur(Enum):
    MONOPHASE = "monophase"
    TRIPHASE = "triphase"


@dataclass
class CoutBreakdown:
    energie: float
    taxe_communale: float
    redevance: float
    tva: float
    
    @property
    def total(self) -> float:
        return self.energie + self.taxe_communale + self.redevance + self.tva


def _r1(v: float) -> float:
    """Arrondi à 0.1 kWh vers le bas (floor) - identique à Dart"""
    return math.floor(v * 10) / 10.0


def _r1_ceil(v: float) -> float:
    """Arrondi à 0.1 kWh vers le haut (ceil) - identique à Dart"""
    return math.ceil(v * 10) / 10.0


def arrondi_5fcfa(v: float) -> float:
    """Arrondi au multiple de 5 FCFA le plus proche"""
    return round(v / 5) * 5.0


class TarifWoyofal:
    """
    Classe identique à TarifWoyofal de tarif_model.dart
    """
    
    def __init__(
        self,
        categorie: WoyofalCategorie = WoyofalCategorie.DPP,
        type_compteur: TypeCompteur = TypeCompteur.MONOPHASE,
        redevance_monophase: float = 429,
        redevance_triphase: float = 1427,
        tarif_t1: float = 82.00,  # DPP T1 (Décret 2025-140)
        tarif_t2: float = 136.49,  # DPP T2
        limite_t1: float = 150,  # DPP: 0-150 kWh
        seuil_tva: float = 250,  # DPP: au-delà de 250 kWh
        taxe_communale: float = 0.025,
        tva: float = 0.18,
    ):
        self.categorie = categorie
        self.type_compteur = type_compteur
        self.redevance_monophase = redevance_monophase
        self.redevance_triphase = redevance_triphase
        self.tarif_t1 = tarif_t1
        self.tarif_t2 = tarif_t2
        self.limite_t1 = limite_t1
        self.seuil_tva = seuil_tva
        self.taxe_communale = taxe_communale
        self.tva = tva
    
    @classmethod
    def dpp(cls, type_compteur: TypeCompteur = TypeCompteur.MONOPHASE):
        return cls(
            categorie=WoyofalCategorie.DPP,
            type_compteur=type_compteur,
            tarif_t1=82.00,
            tarif_t2=136.49,
            limite_t1=150,
            seuil_tva=250,
        )
    
    @classmethod
    def dmp(cls, type_compteur: TypeCompteur = TypeCompteur.MONOPHASE):
        return cls(
            categorie=WoyofalCategorie.DMP,
            type_compteur=type_compteur,
            tarif_t1=111.23,
            tarif_t2=143.54,
            limite_t1=50,
            seuil_tva=300,
        )
    
    @classmethod
    def ppp(cls, type_compteur: TypeCompteur = TypeCompteur.MONOPHASE):
        return cls(
            categorie=WoyofalCategorie.PPP,
            type_compteur=type_compteur,
            tarif_t1=147.43,
            tarif_t2=189.84,
            limite_t1=50,
            seuil_tva=500,
        )
    
    @classmethod
    def pmp(cls, type_compteur: TypeCompteur = TypeCompteur.MONOPHASE):
        return cls(
            categorie=WoyofalCategorie.PMP,
            type_compteur=type_compteur,
            tarif_t1=165.01,
            tarif_t2=191.01,
            limite_t1=100,
            seuil_tva=500,
        )
    
    @property
    def redevance_active(self) -> float:
        if self.type_compteur == TypeCompteur.MONOPHASE:
            return self.redevance_monophase
        return self.redevance_triphase
    
    @property
    def is_professionnel(self) -> bool:
        return self.categorie in (WoyofalCategorie.PPP, WoyofalCategorie.PMP)
    
    def calculer_cout_energie(self, kwh: float, cumul_avant: float) -> float:
        """Identique à calculerCoutEnergie de Dart"""
        k = _r1(max(0.0, kwh))
        cumul = _r1(max(0.0, cumul_avant))
        remaining = k
        cout = 0.0
        
        # Tranche T1
        if cumul < self.limite_t1 and remaining > 0:
            dispo_t1 = self.limite_t1 - cumul
            kwh_dans_t1 = min(remaining, dispo_t1)
            cout += kwh_dans_t1 * self.tarif_t1
            cumul += kwh_dans_t1
            remaining -= kwh_dans_t1
        
        # Tranche T2
        if remaining > 0:
            cout += remaining * self.tarif_t2
        
        return cout
    
    def detail_cout_recharge(
        self,
        kwh: float,
        cumul_avant: float,
        premiere: bool = False,
        nb_mois_redevance: int = 1,
    ) -> CoutBreakdown:
        """Identique à detailCoutRecharge de Dart"""
        k = _r1(max(0.0, kwh))
        cumul_debut = _r1(max(0.0, cumul_avant))
        cumul_apres = cumul_debut + k  # pas de ré-arrondi
        
        base_energie = self.calculer_cout_energie(k, cumul_debut)
        taxe = base_energie * self.taxe_communale
        
        # Redevance facturée seulement sur la 1ère recharge
        rede = self.redevance_active * nb_mois_redevance if premiere else 0.0
        
        tva_part = 0.0
        
        if k > 0:
            if self.is_professionnel:
                # Base TVA = énergie + taxe + redevance (professionnel: TVA toujours)
                base_tva = base_energie + taxe + self.redevance_active
                tva_part = base_tva * self.tva
            else:
                # Domestique: TVA si cumul après > seuilTVA
                if cumul_apres > self.seuil_tva:
                    # Portion de la recharge au-dessus du seuil
                    kwh_avant_seuil = 0.0 if cumul_debut >= self.seuil_tva else (self.seuil_tva - cumul_debut)
                    kwh_apres_seuil = max(0.0, k - kwh_avant_seuil)
                    
                    cout_apres_seuil_base = self.calculer_cout_energie(kwh_apres_seuil, self.seuil_tva)
                    taxe_comm_apres_seuil = cout_apres_seuil_base * self.taxe_communale
                    
                    # Règle Senelec: la redevance entre dans la base TVA à CHAQUE recharge post-seuil
                    base_tva = cout_apres_seuil_base + taxe_comm_apres_seuil + self.redevance_active
                    tva_part = base_tva * self.tva
        
        return CoutBreakdown(
            energie=base_energie,
            taxe_communale=taxe,
            redevance=rede,
            tva=tva_part,
        )
    
    def calculer_cout_recharge(
        self,
        kwh: float,
        cumul_avant: float,
        premiere: bool = False,
        nb_mois_redevance: int = 1,
    ) -> float:
        """Identique à calculerCoutRecharge de Dart"""
        breakdown = self.detail_cout_recharge(
            kwh=kwh,
            cumul_avant=cumul_avant,
            premiere=premiere,
            nb_mois_redevance=nb_mois_redevance,
        )
        return breakdown.total

    def estimer_kwh_pour_montant(
        self,
        montant: float,
        cumul_avant: float,
        premiere: bool = False,
        nb_mois_redevance: int = 1,
        precision: float = 0.1,
        kwh_max: float = 2000.0,
    ) -> float:
        """Identique à estimerKwhPourMontant de Dart (recherche binaire, arrondi Senelec)."""
        lo, hi, best_low = 0.0, kwh_max, 0.0
        cumul = _r1_ceil(cumul_avant)
        for _ in range(80):
            mid = _r1_ceil((lo + hi) / 2)
            cout = self.calculer_cout_recharge(mid, cumul, premiere, nb_mois_redevance)
            if cout <= montant:
                best_low = mid
                lo = _r1_ceil(mid + precision)
            else:
                hi = _r1_ceil(mid - precision)
            if abs(hi - lo) < precision:
                break
        cout_low = self.calculer_cout_recharge(best_low, cumul, premiere, nb_mois_redevance)
        best_high = _r1_ceil(best_low + precision)
        cout_high = self.calculer_cout_recharge(best_high, cumul, premiere, nb_mois_redevance)
        ecart_low = abs(montant - cout_low)
        ecart_high = abs(cout_high - montant)
        best = best_high if ecart_high <= ecart_low else best_low
        return round(best, 1)
