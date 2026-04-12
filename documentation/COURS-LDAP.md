# 📚 Cours LDAP et OpenLDAP

## Table des matières
1. [Introduction au LDAP](#introduction-au-ldap)
2. [Architecture LDAP](#architecture-ldap)
3. [Structure DIT (Directory Information Tree)](#structure-dit)
4. [ACL (Access Control Lists)](#acl)
5. [OpenLDAP](#openldap)
6. [Implémentation du projet](#implémentation-du-projet)
7. [Bonnes pratiques](#bonnes-pratiques)

## 📋 Documentation complémentaire

- **[Commandes LDAP pratiques](COMMANDES-LDAP.md)** - Guide des commandes essentielles

---

## Introduction au LDAP

### Qu'est-ce que LDAP ?

**LDAP** (Lightweight Directory Access Protocol) est un protocole de communication standardisé pour accéder et gérer des services d'annuaire. Il a été conçu comme une version allégée du protocole DAP (Directory Access Protocol) d'X.500.

### Caractéristiques principales

- **Protocole client-serveur** : Communication entre clients et serveurs d'annuaire
- **Modèle de données hiérarchique** : Structure en arbre (DIT)
- **Accès en lecture/écriture** : Opérations CRUD sur les données
- **Authentification** : Gestion des utilisateurs et des permissions
- **Standardisé** : RFC 4511, RFC 4512, RFC 4513

### Cas d'usage typiques

- **Authentification centralisée** : Login unique pour plusieurs services
- **Annuaire d'entreprise** : Gestion des employés, départements, groupes
- **Fédération d'identité** : Intégration avec d'autres systèmes (Keycloak, Active Directory)
- **Configuration réseau** : Stockage des paramètres de configuration

---

## Architecture LDAP

### Composants principaux

#### 1. **Serveur LDAP (DSA - Directory System Agent)**
- Stocke et gère les données de l'annuaire
- Traite les requêtes des clients
- Gère l'authentification et les autorisations

#### 2. **Client LDAP (DUA - Directory User Agent)**
- Interface utilisateur pour accéder à l'annuaire
- Outils en ligne de commande (`ldapsearch`, `ldapadd`, `ldapmodify`)
- Applications web ou desktop

#### 3. **Base de données d'annuaire**
- Stockage des entrées (entries)
- Indexation pour les recherches rapides
- Persistance des données

### Modèle de données LDAP

#### **Entrée (Entry)**
Une entrée représente un objet dans l'annuaire (utilisateur, groupe, organisation, etc.).

```
dn: uid=john,ou=people,dc=example,dc=org
objectClass: inetOrgPerson
cn: John Doe
sn: Doe
uid: john
mail: john@example.org
```

#### **Attribut (Attribute)**
Un attribut contient une information sur l'entrée.

- **Nom** : `cn` (common name)
- **Valeur** : `John Doe`
- **Type** : String, Binary, etc.

#### **Classe d'objet (Object Class)**
Définit les attributs obligatoires et optionnels d'une entrée.

- **Structural** : `inetOrgPerson` (structure principale)
- **Auxiliary** : `posixAccount` (ajoute des attributs POSIX)
- **Abstract** : `top` (classe de base)

---

## Structure DIT (Directory Information Tree)

### Définition

Le **DIT** est la structure hiérarchique de l'annuaire LDAP. C'est un arbre où chaque nœud représente une entrée et les relations parent-enfant définissent la hiérarchie.

### Composants du DIT

#### 1. **DN (Distinguished Name)**
Identifiant unique d'une entrée dans l'annuaire.

```
dn: uid=john,ou=people,dc=example,dc=org
```

**Composants :**
- **RDN** (Relative Distinguished Name) : `uid=john`
- **Parent DN** : `ou=people,dc=example,dc=org`

#### 2. **RDN (Relative Distinguished Name)**
Partie locale du DN qui identifie l'entrée dans son contexte parent.

```
RDN: uid=john
```

#### 3. **Base DN**
Racine de l'arbre DIT.

```
Base DN: dc=example,dc=org
```

### Exemple de DIT dans notre projet

```
dc=example,dc=org
├── ou=people,dc=example,dc=org
│   ├── uid=testuser,ou=people,dc=example,dc=org
│   └── uid=alice,ou=people,dc=example,dc=org (membre de admin_ldap)
├── ou=groups,dc=example,dc=org
│   └── cn=admin_ldap,ou=groups,dc=example,dc=org
└── ou=services,dc=example,dc=org (pour les étapes suivantes)
    └── cn=ldap,ou=services,dc=example,dc=org
```

#### **🎯 Rôle du DIT dans notre projet**

**1. Organisation logique**
- **`ou=people`** : Tous les utilisateurs (testuser, alice, etc.)
- **`ou=groups`** : Groupes de sécurité (admin_ldap)
- **`ou=services`** : Comptes de service (pour les étapes suivantes)

**2. Gestion des permissions**
- **Utilisateurs dans `ou=people`** : Droits de lecture/écriture sur leurs propres données
- **Membres de `admin_ldap`** : Droits de gestion complète
- **Séparation claire** entre utilisateurs et administrateurs

**3. Évolutivité**
- **Structure extensible** pour ajouter de nouveaux utilisateurs
- **Groupes modulaires** pour différents rôles
- **Préparation** pour l'intégration avec Linux, Keycloak, etc.

### Bonnes pratiques pour le DIT

#### 1. **Organisation logique**
- **ou=people** : Utilisateurs
- **ou=groups** : Groupes
- **ou=services** : Comptes de service
- **ou=computers** : Machines

#### 2. **Nommage cohérent**
- Utiliser des attributs appropriés (`uid` pour les utilisateurs, `cn` pour les groupes)
- Éviter les caractères spéciaux
- Respecter les conventions de l'organisation

#### 3. **Profondeur raisonnable**
- Éviter les DIT trop profonds (performance)
- Éviter les DIT trop plats (organisation)

---

## ACL (Access Control Lists)

### Définition

Les **ACL** définissent qui peut accéder à quoi dans l'annuaire LDAP. Elles contrôlent les permissions de lecture, écriture, suppression et recherche.

### Syntaxe des ACL

```
olcAccess: to <what> by <who> <access> [by <who> <access> ...]
```

#### Composants

- **to** : Ce qui est protégé
- **by** : Qui a accès
- **access** : Type d'accès

### Types d'accès

| Accès | Description |
|-------|-------------|
| `read` | Lecture des attributs |
| `write` | Modification des attributs |
| `add` | Ajout d'entrées |
| `delete` | Suppression d'entrées |
| `manage` | Tous les droits |
| `auth` | Authentification uniquement |
| `none` | Aucun accès |

### Exemples d'ACL dans notre projet

#### 1. **ACL de base (configure_acl.sh)**
```ldif
olcAccess: to * by dn.exact=cn=admin,dc=example,dc=org manage by * read
```
- **Admin** : Tous les droits (manage)
- **Autres** : Lecture seule

#### 2. **ACL pour discrétisation (admin_ldap)**
```ldif
olcAccess: to * by group.exact=cn=admin_ldap,ou=groups,dc=example,dc=org manage by self write by users read
```
- **Groupe admin_ldap** : Droits de gestion complète
- **Utilisateurs** : Modification de leurs propres données
- **Autres** : Lecture seule

#### 3. **ACL pour les mots de passe (sécurité)**
```ldif
olcAccess: to attrs=userPassword by group.exact=cn=admin_ldap,ou=groups,dc=example,dc=org write by self write by anonymous auth by * none
```
- **Groupe admin_ldap** : Peut modifier tous les mots de passe
- **Utilisateurs** : Peuvent changer leur propre mot de passe
- **Anonymes** : Peuvent s'authentifier
- **Autres** : Aucun accès aux mots de passe

#### 4. **ACL pour la base DN**
```ldif
olcAccess: to dn.base="" by * read
```
- **Tous** : Peuvent lire la base DN (dc=example,dc=org)

#### **🎯 Rôle des ACL dans notre projet**

**1. Sécurité granulaire**
- **Séparation des rôles** : Admin, groupe admin_ldap, utilisateurs
- **Protection des données sensibles** : Mots de passe, informations personnelles
- **Contrôle d'accès** : Qui peut faire quoi

**2. Discrétisation**
- **Remplacement du superutilisateur** : Plus de `cn=admin` unique
- **Gestion par groupes** : Plusieurs administrateurs possibles
- **Audit et traçabilité** : Qui a fait quoi

**3. Évolutivité**
- **ACL modulaires** : Facile d'ajouter de nouveaux rôles
- **Sécurité renforcée** : Protection contre les accès non autorisés
- **Préparation** pour l'intégration avec d'autres services

### Ordre des ACL

Les ACL sont évaluées **dans l'ordre** et la **première qui correspond** est appliquée.

```
olcAccess: {0}to * by * read
olcAccess: {1}to * by self write
olcAccess: {2}to * by * none
```

### Bonnes pratiques pour les ACL

#### 1. **Principe du moindre privilège**
- Donner le minimum de droits nécessaires
- Utiliser des groupes plutôt que des utilisateurs individuels

#### 2. **Séparation des responsabilités**
- ACL différentes pour les administrateurs et les utilisateurs
- Protection des attributs sensibles (mots de passe, certificats)

#### 3. **Test et validation**
- Tester les ACL avec différents utilisateurs
- Documenter les règles de sécurité

---

## OpenLDAP

### Présentation

**OpenLDAP** est l'implémentation open source de référence du protocole LDAP. Dans notre projet, OpenLDAP joue le rôle de **serveur d'annuaire central** qui stocke et gère toutes les informations d'identité.

### Rôle d'OpenLDAP dans notre projet

#### **🎯 Objectif principal**
OpenLDAP sert de **source de vérité unique** pour l'authentification et l'autorisation dans notre infrastructure. C'est le cœur de notre système d'identité.

#### **🔧 Fonctions concrètes dans le TP**

1. **Authentification centralisée**
   - Stockage des utilisateurs et mots de passe
   - Vérification des identifiants pour tous les services
   - Remplacement des fichiers `/etc/passwd` et `/etc/shadow`

2. **Gestion des groupes et permissions**
   - Définition des rôles (admin_ldap, utilisateurs)
   - Contrôle d'accès granulaire via ACL
   - Discrétisation des droits administratifs

3. **Intégration avec les services**
   - **Linux** : Authentification PAM/SSSD
   - **Keycloak** : Fédération d'identité
   - **Applications** : Authentification LDAP

4. **Réplication et haute disponibilité**
   - Synchronisation entre serveurs maître/esclave
   - Propagation des modifications
   - Équilibrage de charge

### Architecture OpenLDAP dans notre projet

```
┌─────────────────────────────────────────────────────────────┐
│                    NOTRE INFRASTRUCTURE                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   Linux    │    │  Keycloak   │    │Applications│      │
│  │ (PAM/SSSD) │    │             │    │            │      │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘      │
│         │                  │                  │             │
│         └──────────────────┼──────────────────┘             │
│                            │                               │
│  ┌─────────────────────────▼─────────────────────────┐      │
│  │              OPENLDAP SERVER                     │      │
│  │  ┌─────────────────────────────────────────────┐ │      │
│  │  │              slapd daemon                   │ │      │
│  │  │  • Authentification                         │ │      │
│  │  │  • Gestion des ACL                          │ │      │
│  │  │  • Traitement des requêtes                 │ │      │
│  │  └─────────────────────────────────────────────┘ │      │
│  │  ┌─────────────────────────────────────────────┐ │      │
│  │  │              Base MDB                      │ │      │
│  │  │  • Stockage des utilisateurs               │ │      │
│  │  │  • Structure DIT                           │ │      │
│  │  │  • Index pour les recherches               │ │      │
│  │  └─────────────────────────────────────────────┘ │      │
│  └─────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

### Composants OpenLDAP dans notre implémentation

#### 1. **slapd (Standalone LDAP Daemon)**
**Rôle dans le projet :**
- **Serveur principal** qui écoute sur le port 389 (LDAP) et 636 (LDAPS)
- **Gestionnaire d'authentification** pour tous nos services
- **Processeur de requêtes** pour les opérations CRUD sur l'annuaire

**Configuration dans notre Dockerfile :**
```dockerfile
# slapd est installé et configuré automatiquement
RUN apt-get install -y slapd ldap-utils
```

**Démarrage dans entrypoint.sh :**
```bash
# slapd démarre avec ldap:/// et ldapi:///
slapd -h "ldap:/// ldapi:///" -u openldap -g openldap -F /etc/ldap/slapd.d
```

#### 2. **Configuration cn=config**
**Rôle dans le projet :**
- **Configuration dynamique** de notre serveur LDAP
- **Gestion des bases de données** (mdb pour dc=example,dc=org)
- **Configuration des ACL** pour la sécurité

**Exemple de notre configuration :**
```
cn=config
├── olcDatabase={2}mdb,cn=config
│   ├── olcSuffix: dc=example,dc=org
│   ├── olcRootDN: cn=admin,dc=example,dc=org
│   └── olcAccess: to * by dn.exact=cn=admin,dc=example,dc=org manage
```

#### 3. **Backend MDB**
**Rôle dans le projet :**
- **Stockage des données** de notre annuaire
- **Performance optimisée** pour les opérations LDAP
- **Persistance** via les volumes Docker

**Configuration dans init_ldap.sh :**
```bash
# Création de la base mdb avec notre suffix
olcSuffix: dc=example,dc=org
olcRootDN: cn=admin,dc=example,dc=org
olcDbDirectory: /var/lib/ldap
```

### Intégration avec les autres composants du TP

#### **1. Authentification Linux (PAM/SSSD)**
```
Linux User Login → PAM → SSSD → OpenLDAP
```
- **PAM** : Module d'authentification Linux
- **SSSD** : Cache et synchronisation avec LDAP
- **OpenLDAP** : Source de vérité pour les utilisateurs

#### **2. Fédération Keycloak**
```
Keycloak → OpenLDAP (User Federation)
```
- **Keycloak** : Gestionnaire d'identité et d'accès
- **OpenLDAP** : Fournisseur d'identité externe
- **Synchronisation** : Import automatique des utilisateurs

#### **3. Réplication RW/RO**
```
Master OpenLDAP ←→ Slave OpenLDAP
```
- **Master** : Serveur en lecture/écriture
- **Slave** : Serveur en lecture seule
- **Réplication** : Synchronisation automatique des données

#### **4. Méta-annuaire**
```
Meta OpenLDAP → Multiple LDAP Servers
```
- **Méta-annuaire** : Agrégeur de plusieurs LDAP
- **Proxy** : Redirection des requêtes
- **Fédération** : Vue unifiée des annuaires

### Configuration OpenLDAP dans notre projet

#### **🔧 Comment OpenLDAP s'intègre dans notre architecture Docker**

**1. Installation et configuration automatique**
```dockerfile
# Dans notre Dockerfile
RUN apt-get install -y slapd ldap-utils
# OpenLDAP est installé avec une configuration de base
```

**2. Démarrage du service**
```bash
# Dans entrypoint.sh
slapd -h "ldap:/// ldapi:///" -u openldap -g openldap -F /etc/ldap/slapd.d
# slapd démarre et écoute sur les ports 389 et 636
```

**3. Initialisation de notre DIT**
```bash
# Dans init_ldap.sh
# Création de la base mdb avec notre suffix
olcSuffix: dc=example,dc=org
olcRootDN: cn=admin,dc=example,dc=org
```

**4. Configuration des ACL**
```bash
# Dans configure_acl.sh
# Application des règles de sécurité
olcAccess: to * by dn.exact=cn=admin,dc=example,dc=org manage
```

#### **🎯 Flux de données dans notre projet**

```
1. DÉMARRAGE
   Docker Container → entrypoint.sh → slapd daemon

2. INITIALISATION
   slapd → init_ldap.sh → Création DIT + Base MDB

3. CONFIGURATION
   configure_acl.sh → Configuration ACL → Sécurité

4. UTILISATION
   Client LDAP → slapd → Base MDB → Réponse
```

#### **📊 Rôles concrets d'OpenLDAP dans chaque étape du TP**

**Étape 1 : Installation et Structure** ✅
- **OpenLDAP** : Serveur de base avec DIT
- **Fonction** : Stockage des utilisateurs et groupes
- **Résultat** : Annuaire fonctionnel avec ACL

**Étape 2 : Authentification Linux** 🔄
- **OpenLDAP** : Source de vérité pour les utilisateurs Linux
- **Fonction** : Remplacement de /etc/passwd et /etc/shadow
- **Résultat** : Login Linux via LDAP

**Étape 3 : Fédération Keycloak** 🔄
- **OpenLDAP** : Fournisseur d'identité externe
- **Fonction** : Synchronisation des utilisateurs vers Keycloak
- **Résultat** : SSO (Single Sign-On) via Keycloak

**Étape 4 : Réplication RW/RO** 🔄
- **OpenLDAP** : Serveurs maître et esclave
- **Fonction** : Haute disponibilité et équilibrage
- **Résultat** : Infrastructure LDAP redondante

**Étape 5 : Méta-annuaire** 🔄
- **OpenLDAP** : Agrégeur de plusieurs LDAP
- **Fonction** : Vue unifiée des annuaires
- **Résultat** : Fédération d'annuaires multiples

---

## Implémentation du projet

### Architecture du projet

```
TP-LDAP/
├── projet/
│   ├── docker/
│   │   ├── Dockerfile          # Image Debian 12 + OpenLDAP 2.6
│   │   └── entrypoint.sh       # Script de démarrage avec loop
│   ├── scripts/
│   │   ├── init_ldap.sh        # Script d'initialisation DIT + ACL
│   │   └── init_ldap_linux_integration.sh  # PAM/NSS dans l'image
│   ├── test/
│   │   ├── lib/test_common.sh
│   │   ├── test_01_…sh … test_04_…sh
│   │   └── test_all_implemented.sh
│   └── docker-compose.yml       # Compose (contexte de build = ce dossier)
├── documentation/
├── reference/
└── README.md
```

### Composants techniques

#### 1. **Dockerfile**
```dockerfile
FROM debian:12-slim

# Installation OpenLDAP 2.6
RUN apt-get update && apt-get install -y slapd ldap-utils

# Configuration des volumes
VOLUME ["/var/lib/ldap", "/etc/ldap/slapd.d"]

# Point d'entrée
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
```

**Fonctionnalités :**
- Base Debian 12 slim
- OpenLDAP 2.6 et outils client
- Gestionnaire de processus `tini`
- Volumes persistants

#### 2. **Entrypoint**
```bash
#!/usr/bin/env bash
# Démarrage de slapd
slapd -h "ldap:/// ldapi:///" -u openldap -g openldap -F /etc/ldap/slapd.d

# Exécution des scripts d'init
for script in /container/init.d/*.sh; do
    bash "$script"
done

# Loop pour maintenir le conteneur
while true; do sleep 3600; done
```

**Fonctionnalités :**
- Démarrage de `slapd` avec ldap et ldapi
- Exécution automatique des scripts d'initialisation
- Loop pour maintenir le conteneur en vie

#### 3. **Script d'initialisation (init_ldap.sh)**

**Étapes d'initialisation :**

1. **Configuration de la base mdb**
```bash
# Suppression de la base par défaut
ldapmodify -H ldapi:/// -Y EXTERNAL <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: delete
EOF

# Création de la nouvelle base
ldapadd -H ldapi:/// -Y EXTERNAL -f /tmp/new-db.ldif
```

2. **Création du DIT**
```ldif
dn: dc=example,dc=org
objectClass: top
objectClass: dcObject
objectClass: organization
o: Example Org
dc: example

dn: ou=people,dc=example,dc=org
objectClass: top
objectClass: organizationalUnit
ou: people

dn: ou=groups,dc=example,dc=org
objectClass: top
objectClass: organizationalUnit
ou: groups

dn: cn=admin_ldap,ou=groups,dc=example,dc=org
objectClass: top
objectClass: groupOfNames
cn: admin_ldap
member: cn=dummy,dc=example,dc=org
```

#### 4. **Script de configuration ACL (configure_acl.sh)**

**Configuration des ACL :**

1. **ACL de base**
```ldif
dn: olcDatabase={2}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: to * by dn.exact=cn=admin,dc=example,dc=org manage by * read
```

2. **ACL avancées pour discrétisation**
```ldif
dn: olcDatabase={2}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: to attrs=userPassword by group.exact=cn=admin_ldap,ou=groups,dc=example,dc=org write by self write by anonymous auth by * none
olcAccess: to dn.base="" by * read
olcAccess: to * by group.exact=cn=admin_ldap,ou=groups,dc=example,dc=org manage by self write by users read by * none
```

### Fonctionnalités implémentées

#### 1. **Discrétisation des droits**
- Suppression du superutilisateur `cn=admin`
- Gestion des droits via le groupe `admin_ldap`
- ACL granulaires pour différents types d'utilisateurs

#### 2. **Structure DIT organisée**
- `ou=people` : Utilisateurs
- `ou=groups` : Groupes
- Groupe `admin_ldap` pour la gestion

#### 3. **Configuration automatisée**
- Scripts d'initialisation
- Configuration des ACL
- Gestion des erreurs

### Tests et validation

#### Commandes de test
```bash
# Test de base
ldapsearch -x -H ldap://localhost:389 -b dc=example,dc=org -s base dn

# Test d'authentification
ldapwhoami -x -D cn=admin,dc=example,dc=org -w admin

# Test de diagnostic
docker exec ldap bash -lc 'ldapwhoami -H ldapi:/// -Y EXTERNAL'
```

#### Résultats attendus
- Connexion LDAP fonctionnelle
- Authentification des utilisateurs
- ACL correctement appliquées
- Structure DIT accessible

---

## Bonnes pratiques

### Sécurité

#### 1. **Authentification**
- Utiliser des mots de passe forts
- Implémenter des politiques de mots de passe
- Utiliser TLS/SSL en production

#### 2. **ACL**
- Principe du moindre privilège
- Séparation des responsabilités
- Audit régulier des permissions

#### 3. **Monitoring**
- Logs des accès et modifications
- Surveillance des tentatives d'intrusion
- Alertes sur les anomalies

### Performance

#### 1. **Indexation**
```ldif
olcDbIndex: objectClass eq
olcDbIndex: cn,sn,uid eq
olcDbIndex: mail eq
```

#### 2. **Cache**
- Configuration du cache LDAP
- Optimisation des requêtes fréquentes

#### 3. **Réplication**
- Serveurs maître/esclave
- Synchronisation des données
- Équilibrage de charge

### Maintenance

#### 1. **Sauvegarde**
- Sauvegarde régulière de la base de données
- Sauvegarde de la configuration
- Plan de récupération

#### 2. **Mise à jour**
- Mise à jour des schémas
- Migration des données
- Tests en environnement de développement

#### 3. **Documentation**
- Documentation des ACL
- Procédures d'administration
- Formation des utilisateurs

---

## Conclusion

Ce cours a présenté les concepts fondamentaux de LDAP et OpenLDAP, ainsi que leur implémentation pratique dans notre projet. Les notions clés à retenir sont :

- **LDAP** : Protocole standardisé pour les annuaires
- **DIT** : Structure hiérarchique de l'annuaire
- **ACL** : Contrôle d'accès granulaire
- **OpenLDAP** : Implémentation open source de référence
- **Discrétisation** : Gestion des droits via des groupes

Le projet implémenté démontre une configuration LDAP complète avec :
- Serveur OpenLDAP 2.6 sur Debian 12
- Structure DIT organisée
- ACL de sécurité
- Scripts d'automatisation
- Tests de validation

Cette base solide permet d'aborder les étapes suivantes du TP : intégration Linux, fédération Keycloak, réplication et méta-annuaire.