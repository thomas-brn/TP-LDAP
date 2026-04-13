# TP LDAP - OpenLDAP 2.6

## Objectifs

Ce TP a pour objectif de :

1. **Comprendre** l'architecture et le fonctionnement d'un annuaire LDAP
2. **Déployer** un serveur OpenLDAP 2.6 dans un environnement conteneurisé
3. **Concevoir** une structure d'annuaire (DIT) adaptée à un cas d'usage réel
4. **Implémenter** une gestion fine des droits via la discrétisation des rôles (ACL)
5. **Intégrer** LDAP avec des systèmes Linux pour l'authentification
6. **Fédérer** LDAP avec Keycloak pour la gestion d'identité
7. **Mettre en place** une architecture de réplication pour la haute disponibilité
8. **Créer** un méta-annuaire pour agréger plusieurs sources LDAP
<<<<<<< HEAD
9. **Tester** l'ensemble de l'infrastructure

---

## Contraintes techniques

Voici les contraintes :

| Élément          | Contrainte                |
| ---------------- | ------------------------- |
| Distribution     | Debian 12 (bookworm)      |
| Conteneurisation | Docker                    |
| Image de base    | `debian:bookworm-slim`    |
| Serveur LDAP     | OpenLDAP **2.6**          |
| Configuration    | Scripts Bash              |
| Entrypoint       | Boucle `sleep`            |
| Authentification | Linux (PAM/NSS), Keycloak |

**Documentation de référence :**
[OpenLDAP 2.6 Admin Guide](https://www.openldap.org/doc/admin26/guide.html)

---

## Installation et déploiement automatisé

Créer une infrastructure LDAP entièrement automatisée :

1. **Créer un Dockerfile** qui :
   - Partir de `debian:bookworm-slim`
   - Installer `slapd` et `ldap-utils`
   - Configurer OpenLDAP de manière non interactive
   - Exposer les ports nécessaires

2. **Créer un script d'initialisation** qui :
   - Configurer le serveur LDAP sans intervention manuelle
   - Créer la structure DIT de base
   - Importer les données initiales via fichiers LDIF

3. **Créer un docker-compose.yml** qui :
   - Lancer le service LDAP
   - Configurer les volumes persistants
   - Permettre le démarrage en une seule commande

   Dans ce dépôt, le fichier correspondant est **`projet/docker-compose.yml`** (exécuter les commandes Docker depuis **`projet/`**).

---

## Conception de la structure DIT

Concevoir et implémenter une structure d'annuaire (DIT) cohérente :

1. **Définir la base DN** (`dc=...`) adaptée au cas d'usage
2. **Créer les unités organisationnelles** nécessaires :
   - Une "OU" pour les utilisateurs (`ou=people`)
   - Une "OU" pour les groupes (`ou=groups`)
   - Éventuellement d'autres "OUs" selon les besoins

3. **Justifier les choix** dans le rapport :
   - Pourquoi cette structure ?
   - Comment elle répond aux besoins ?
   - Comment elle peut évoluer ?

---

## Discrétisation des rôles et ACL

Implémenter une gestion des droits basée sur la **discrétisation des rôles** :

1. **Créer des groupes LDAP** avec des rôles spécifiques :
   - `admin_ldap` : administration complète de l'annuaire
   - `admin_keycloak` : gestion des rôles Keycloak (si applicable)
   - Groupes fonctionnels selon les besoins

2. **Configurer les ACL** pour :
   - Donner des droits d'administration au groupe `admin_ldap`
   - Permettre aux utilisateurs de modifier leurs propres attributs
   - Protéger les attributs sensibles (`userPassword`)
   - Appliquer le principe du moindre privilège

3. **Ne pas utiliser** le compte `cn=admin` pour l'administration courante

---

## Intégration Linux (PAM/NSS)

Il faut configurer un système Linux pour utiliser LDAP comme source d'authentification :

1. **Configurer NSS** pour la résolution des utilisateurs et groupes
2. **Configurer PAM** pour l'authentification
3. **Tester** si :
   - Les utilisateurs LDAP sont visibles via `getent passwd`
   - Les groupes LDAP sont visibles via `getent group`
   - L'authentification fonctionne (`su`, `ssh`, etc.)

---

## Intégration Keycloak (OpenID)

Il faut configurer Keycloak pour utiliser LDAP comme fournisseur d'identité :

1. **Déployer Keycloak** (conteneur Docker)
2. **Configurer un User Federation** LDAP dans Keycloak
3. **Tester** si :
   - Les utilisateurs LDAP sont synchronisés dans Keycloak
   - L'authentification via Keycloak fonctionne avec les comptes LDAP
   - Les rôles peuvent être gérés séparément dans Keycloak

---

## Réplication LDAP (RW / RO)

Il faut mettre en place une architecture de réplication :

1. **Créer un serveur principal** (Read-Write)
2. **Créer un ou plusieurs serveurs secondaires** (Read-Only)
3. **Configurer la réplication** entre les serveurs
4. **Tester** si :
   - Les modifications sur le serveur principal sont propagées
   - Les serveurs secondaires sont en lecture seule
   - La synchronisation fonctionne correctement

---

## Fédération LDAP (Méta-annuaire)

Il faut créer un méta-annuaire pour agréger plusieurs sources LDAP :

1. **Créer plusieurs annuaires LDAP** distincts (simulant différentes entités)
2. **Configurer un méta-annuaire** qui :
   - Reconnaît les annuaires inférieurs
   - Centralise l'accès aux données
   - Permet d'interroger plusieurs sources

3. **Tester** si les requêtes sur le méta-annuaire retournent des données des différents LDAP

---

## Tests et validation

Il faut fournir des scripts de test pour chaque objectif :

1. **Tests LDAP de base** : Vérification de la connexion, structure DIT
2. **Tests ACL** : Validation des droits selon les groupes
3. **Tests intégration Linux** : Résolution et authentification
4. **Tests intégration Keycloak** : Synchronisation et authentification
5. **Tests réplication** : Propagation des modifications
6. **Tests méta-annuaire** : Agrégation des sources
