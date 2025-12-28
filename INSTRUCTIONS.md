# TP LDAP — OpenLDAP 2.6

## Objectifs pédagogiques

Ce TP a pour objectif de vous permettre de :

1. **Comprendre** l'architecture et le fonctionnement d'un annuaire LDAP
2. **Déployer** un serveur OpenLDAP 2.6 dans un environnement conteneurisé
3. **Concevoir** une structure d'annuaire (DIT) adaptée à un cas d'usage réel
4. **Implémenter** une gestion fine des droits via la discrétisation des rôles (ACL)
5. **Intégrer** LDAP avec des systèmes Linux pour l'authentification
6. **Fédérer** LDAP avec Keycloak pour la gestion d'identité
7. **Mettre en place** une architecture de réplication pour la haute disponibilité
8. **Créer** un méta-annuaire pour agréger plusieurs sources LDAP
9. **Documenter** et **tester** l'ensemble de l'infrastructure

### Compétences visées

À l'issue de ce TP, vous serez capable de :

- Configurer et administrer un serveur OpenLDAP
- Concevoir et implémenter des ACL complexes
- Intégrer LDAP dans un écosystème d'authentification
- Mettre en place des architectures LDAP distribuées
- Documenter et justifier vos choix techniques

---

## Contraintes techniques

Vous devez respecter les contraintes suivantes :

| Élément          | Contrainte                | Justification attendue |
| ---------------- | ------------------------- | ---------------------- |
| Distribution     | Debian 12 (bookworm)      | Stabilité et support   |
| Conteneurisation | Docker                    | Reproducibilité        |
| Image de base    | `debian:bookworm-slim`    | Légèreté               |
| Serveur LDAP     | OpenLDAP **2.6**          | Version moderne        |
| Configuration    | Scripts Bash              | Automatisation         |
| Entrypoint       | Boucle `sleep`            | Persistance conteneur  |
| Authentification | Linux (PAM/NSS), Keycloak | Intégration complète   |
| Dépôt            | GitHub                    | Versionnement          |
| Rapport          | LaTeX                     | Documentation formelle |

**Documentation de référence :**
[OpenLDAP 2.6 Admin Guide](https://www.openldap.org/doc/admin26/guide.html)

---

## Instructions générales

### Structure du projet

Votre dépôt doit contenir :

- Un `Dockerfile` pour construire l'image du serveur LDAP
- Un `docker-compose.yml` pour orchestrer les services
- Des scripts d'initialisation et de configuration
- Des fichiers LDIF pour la structure de données
- Des scripts de test pour valider chaque fonctionnalité
- Un rapport LaTeX documentant vos choix et résultats

---

## Installation et déploiement automatisé

Vous devez créer une infrastructure LDAP entièrement automatisée :

1. **Créer un Dockerfile** qui :
   - Part de `debian:bookworm-slim`
   - Installe `slapd` et `ldap-utils`
   - Configure OpenLDAP de manière non interactive
   - Expose les ports nécessaires

2. **Créer un script d'initialisation** qui :
   - Configure le serveur LDAP sans intervention manuelle
   - Crée la structure DIT de base
   - Importe les données initiales via fichiers LDIF

3. **Créer un docker-compose.yml** qui :
   - Lance le service LDAP
   - Configure les volumes persistants
   - Permet le démarrage en un seul commande

---

## Conception de la structure DIT

Vous devez concevoir et implémenter une structure d'annuaire (DIT) cohérente :

1. **Définir la base DN** (`dc=...`) adaptée à votre cas d'usage
2. **Créer les unités organisationnelles** nécessaires :
   - Une OU pour les utilisateurs (`ou=people`)
   - Une OU pour les groupes (`ou=groups`)
   - Éventuellement d'autres OUs selon vos besoins

3. **Justifier vos choix** dans le rapport :
   - Pourquoi cette structure ?
   - Comment elle répond aux besoins ?
   - Comment elle peut évoluer ?

---

## Discrétisation des rôles et ACL

Vous devez implémenter une gestion des droits basée sur la **discrétisation des rôles** :

1. **Créer des groupes LDAP** avec des rôles spécifiques :
   - `admin_ldap` : administration complète de l'annuaire
   - `admin_keycloak` : gestion des rôles Keycloak (si applicable)
   - Groupes fonctionnels selon vos besoins

2. **Configurer les ACL** pour :
   - Donner des droits d'administration au groupe `admin_ldap`
   - Permettre aux utilisateurs de modifier leurs propres attributs
   - Protéger les attributs sensibles (`userPassword`)
   - Appliquer le principe du moindre privilège

3. **Ne pas utiliser** le compte `cn=admin` pour l'administration courante

---

## Intégration Linux (PAM/NSS)

Vous devez configurer un système Linux pour utiliser LDAP comme source d'authentification :

1. **Configurer NSS** pour la résolution des utilisateurs et groupes
2. **Configurer PAM** pour l'authentification
3. **Tester** que :
   - Les utilisateurs LDAP sont visibles via `getent passwd`
   - Les groupes LDAP sont visibles via `getent group`
   - L'authentification fonctionne (`su`, `ssh`, etc.)

---

## Intégration Keycloak (OpenID)

Vous devez configurer Keycloak pour utiliser LDAP comme fournisseur d'identité :

1. **Déployer Keycloak** (conteneur Docker)
2. **Configurer un User Federation** LDAP dans Keycloak
3. **Tester** que :
   - Les utilisateurs LDAP sont synchronisés dans Keycloak
   - L'authentification via Keycloak fonctionne avec les comptes LDAP
   - Les rôles peuvent être gérés séparément dans Keycloak

---

## Réplication LDAP (RW / RO)

Vous devez mettre en place une architecture de réplication :

1. **Créer un serveur principal** (Read-Write)
2. **Créer un ou plusieurs serveurs secondaires** (Read-Only)
3. **Configurer la réplication** entre les serveurs
4. **Tester** que :
   - Les modifications sur le serveur principal sont propagées
   - Les serveurs secondaires sont en lecture seule
   - La synchronisation fonctionne correctement

---

## Fédération LDAP (Méta-annuaire)

Vous devez créer un méta-annuaire pour agréger plusieurs sources LDAP :

1. **Créer plusieurs annuaires LDAP** distincts (simulant différentes entités)
2. **Configurer un méta-annuaire** qui :
   - Reconnaît les annuaires inférieurs
   - Centralise l'accès aux données
   - Permet d'interroger plusieurs sources

3. **Tester** que les requêtes sur le méta-annuaire retournent des données des différents LDAP

---

## Tests et validation

### Scripts de test requis

Vous devez fournir des scripts de test pour chaque objectif :

1. **Tests LDAP de base** : Vérification de la connexion, structure DIT
2. **Tests ACL** : Validation des droits selon les groupes
3. **Tests intégration Linux** : Résolution et authentification
4. **Tests intégration Keycloak** : Synchronisation et authentification
5. **Tests réplication** : Propagation des modifications
6. **Tests méta-annuaire** : Agrégation des sources
