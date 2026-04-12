# TP LDAP — Partie 5 : Intégration Keycloak (OpenID)

> **Usage** : ce fichier est un **chapitre autonome** du rapport (copier-coller tel quel).  
> **Chapitre** : 5 / 7 — *Intégration Keycloak (OpenID)* (`INSTRUCTIONS.md`, même intitulé).  
> **Prérequis** : *Parties 1 à 4* — annuaire **LDAP** joignable (port **389**), **DIT** sous `ou=people` / `ou=groups`, comptes **`thomas`** / **`john`** utilisables pour un bind ; intégration Linux optionnelle pour le fond « système », mais Keycloak consomme surtout l’**API LDAP** du service **`ldap`**.  
> **Convention dépôt** : le service **Keycloak** est défini dans **`projet/docker-compose.yml`** (ports hôte **8090** → HTTP Keycloak, **9001** → port management ; voir section 3.1). L’URL LDAP **vue depuis le conteneur Keycloak** est **`ldap://ldap:389`** (réseau Compose par défaut).  
> **Chapitre précédent** : *Partie 4 — Intégration Linux (PAM / NSS)*.  
> **Chapitre suivant** : *Partie 6 — Réplication LDAP (RW / RO)* (`documentation/partie-06-replication.md`).

Ce document couvre la **fédération de l’annuaire LDAP avec Keycloak** (OpenID), comme demandé dans **`INSTRUCTIONS.md`** (section « Intégration Keycloak (OpenID) »). Il décrit **l’implémentation livrée dans le dépôt** : service Docker, realm et User Federation automatisés, groupe LDAP **`admin_keycloak`**, et tests **`test_05_keycloak.sh`**.

---

## 1. Ce que demandent les instructions

D’après `INSTRUCTIONS.md`, il faut :

1. **Déployer Keycloak** (conteneur Docker) ;
2. **Configurer un User Federation LDAP** dans Keycloak ;
3. **Tester** :
   - synchronisation des utilisateurs LDAP vers Keycloak ;
   - authentification OIDC via Keycloak avec des comptes LDAP ;
   - gestion des rôles **dans Keycloak** de manière séparée de l’annuaire.

Les instructions mentionnent aussi, dans la partie ACL, le groupe **`admin_keycloak`** pour la gestion des rôles Keycloak **« si applicable »** : il est **créé** dans `init_ldap.sh` avec **thomas** comme membre (rôle procédural : qui administre Keycloak côté organisation ; les droits fins restent dans la console Keycloak).

---

## 2. État du projet (implémenté)

| Élément | Statut |
|---------|--------|
| Service **Keycloak** dans `projet/docker-compose.yml` | Présent (`keycloak`, image `quay.io/keycloak/keycloak:26.2`) |
| **User Federation** LDAP | Créé par `projet/scripts/configure_keycloak_ldap.sh` (realm `tp-ldap`, bind `cn=admin,…`, `ou=people,…`) |
| **Tests** d’intégration Keycloak | `projet/test/test_05_keycloak.sh` (+ entrée dans `test_all_implemented.sh`) |
| **Groupe LDAP `admin_keycloak`** | Créé dans `init_ldap.sh` |

**Annuaire OpenLDAP** : inchangé pour Keycloak — écoute **389**, utilisateurs sous **`ou=people`**, attributs `uid`, `mail`, `userPassword`, etc.

---

## 3. Mise en œuvre dans le dépôt

### 3.1. Déploiement Keycloak

- Fichier **`projet/docker-compose.yml`** :
  - service **`ldap`** avec **healthcheck** (annuaire prêt avant Keycloak) ;
  - service **`keycloak`** : `start-dev`, compte bootstrap `KC_BOOTSTRAP_ADMIN_USERNAME` / `KC_BOOTSTRAP_ADMIN_PASSWORD` (démo : `admin` / `admin`) ;
  - publication **8090:8080** et **9001:9000** pour limiter les conflits avec un autre service sur le port 8080 de l’hôte.
- Démarrage : depuis **`projet/`** :

```bash
docker compose up -d
```

Console d’administration : **http://localhost:8090/admin/** (identifiants bootstrap ci-dessus).

### 3.2. User Federation (automatisation)

Le script **`projet/scripts/configure_keycloak_ldap.sh`** (idempotent) :

1. attend que Keycloak réponde (`KEYCLOAK_URL`, défaut **http://localhost:8090**) ;
2. obtient un jeton **admin-cli** sur le realm `master` ;
3. crée le realm **`tp-ldap`** s’il n’existe pas ;
4. crée le composant **LDAP** (`ldap://ldap:389`, bind lecture sur l’annuaire) s’il n’existe pas ;
5. déclenche une synchronisation complète (**triggerFullSync**).

Variables utiles (surcharge possible) : `KEYCLOAK_URL`, `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`, `KEYCLOAK_REALM`, `KEYCLOAK_LDAP_CONNECTION`, `LDAP_BIND_DN`, `LDAP_BIND_PW`, `LDAP_USERS_DN`.

Équivalent manuel dans la console : *User federation* → *Add provider* → *ldap*, avec les mêmes paramètres (connexion, bind, **Users DN** = `ou=people,dc=example,dc=org`).

### 3.3. Authentification et rôles

- **Login** : dans le realm `tp-ldap`, onglet *Users* : les comptes **importés** depuis LDAP apparaissent après sync ; connexion possible avec **thomas** / `thomas123` (mot de passe LDAP) sur le formulaire du realm.
- **Rôles Keycloak** : à créer dans le realm (rôles realm ou client) et à assigner aux utilisateurs **dans Keycloak uniquement** (pas de duplication dans LDAP), conformément à l’énoncé.

---

## 4. Vérifications (check-list)

```text
[x] (dans `projet/`) docker compose ps  →  ldap UP, keycloak UP
[x] Keycloak : LDAP provider « Test connection » OK (équivalent : script configure + tests)
[x] Keycloak : synchronisation utilisateurs → thomas / john visibles
[ ] Login OIDC (ou formulaire Keycloak) avec thomas / mot de passe LDAP — à montrer en démo / capture
[ ] Rôle Keycloak attribué à thomas, visible dans le token ou l’interface — manuel (console)
[x] Groupe admin_keycloak créé dans LDAP (tests objectifs 2 et 3)
```

Les tests automatisés couvrent la **stack Docker**, la **configuration API** et la **présence des utilisateurs** dans Keycloak après sync.

---

## 5. Synthèse de la partie 5

| Attendu | Réalisation |
|---------|-------------|
| Keycloak en Docker | `docker-compose.yml` + ports 8090 / 9001 |
| User Federation LDAP | `configure_keycloak_ldap.sh` |
| Tests sync + import utilisateurs | `test_05_keycloak.sh` |
| `admin_keycloak` | `init_ldap.sh` + tests DIT / rôles |

**Fin du chapitre 5 / 7** — La suite logique est la *Partie 6 — Réplication LDAP (RW / RO)* : second nœud OpenLDAP en lecture seule, syncrepl depuis le fournisseur. La *Partie 7 — Méta-annuaire* (`documentation/partie-07-meta-annuaire.md`) couvre le dernier grand objectif de **`INSTRUCTIONS.md`** (non encore implémenté dans le dépôt).

*Référence : `INSTRUCTIONS.md` — section « Intégration Keycloak (OpenID) ».*
