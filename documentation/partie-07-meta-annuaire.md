# TP LDAP — Partie 7 : Fédération LDAP (méta-annuaire)

> **Usage** : ce fichier est un **chapitre autonome** du rapport (copier-coller tel quel).  
> **Chapitre** : 7 / 7 — *Fédération LDAP (méta-annuaire)* (`INSTRUCTIONS.md`, même intitulé).  
> **Prérequis** : *Parties 1 à 6* — maîtrise d’au moins un annuaire OpenLDAP déployé ; la **réplication** (partie 6) illustre déjà deux instances distinctes.  
> **Convention dépôt** : **non livré** dans ce dépôt à ce stade — pas de service méta-annuaire dans **`projet/docker-compose.yml`**, pas de script `test_07_*.sh`.  
> **Chapitre précédent** : *Partie 6 — Réplication LDAP (RW / RO)* (`documentation/partie-06-replication.md`).  
> **Chapitre suivant** : aucun (fin de la série 1–7 alignée sur les grands objectifs de **`INSTRUCTIONS.md`**).

Ce document fixe **l’état cible** et les **travaux restants** pour la section « Fédération LDAP (Méta-annuaire) » de **`INSTRUCTIONS.md`**. Il sert de trame pour le rapport ou les itérations futures du projet, sur le modèle des parties 1 à 6.

---

## 1. Ce que demandent les instructions

1. **Plusieurs annuaires LDAP** distincts (simulation d’entités différentes).  
2. Un **méta-annuaire** qui :  
   - reconnaît les annuaires « inférieurs » ;  
   - centralise l’accès ;  
   - permet d’interroger **plusieurs sources**.  
3. **Tests** : requêtes sur le méta-annuaire renvoient des données issues des différents LDAP sous-jacents.

---

## 2. État du dépôt

| Élément | Statut |
|---------|--------|
| Plusieurs services LDAP « entités » | Non (hors combinaison fournisseur + réplica, qui n’est pas un méta-annuaire) |
| Méta-annuaire (ex. `meta`, `back-meta`, proxy) | Non configuré |
| Tests automatisés méta-annuaire | Absents |

---

## 3. Pistes de mise en œuvre (hors livrable actuel)

- **OpenLDAP** : backend **meta** (ou architecture **syncrepl** / **subordinate** selon objectifs pédagogiques) ; consulter l’[OpenLDAP Admin Guide](https://www.openldap.org/doc/admin26/guide.html) pour la version 2.6.  
- **Compose** : ajouter des services `ldap-a`, `ldap-b`, puis un nœud **`ldap-meta`** avec `slapd` configuré pour agréger des `suffixmassage` / `uri` vers les backends.  
- **Sécurité** : comptes de lecture dédiés sur chaque sous-annuaire, moindre privilège.  
- **Validation** : script `test_07_meta_annuaire.sh` (à créer) : `ldapsearch` sur le suffixe du méta et vérification de la présence d’entrées provenant de deux arbres sources.

---

## 4. Synthèse

| Attendu | Réalisation actuelle |
|---------|----------------------|
| Méta-annuaire opérationnel | À faire |
| Tests d’agrégation | À faire |

**Fin du chapitre 7 / 7** — Série des parties **1 à 7** : les parties **1 à 6** sont implémentées et documentées dans le dépôt ; la **partie 7** reste **à implémenter** pour couvrir intégralement la section correspondante de **`INSTRUCTIONS.md`**.

*Référence : `INSTRUCTIONS.md` — section « Fédération LDAP (Méta-annuaire) ».*
