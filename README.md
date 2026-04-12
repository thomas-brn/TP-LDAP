# TP LDAP – OpenLDAP 2.6 sur Debian 12 (Docker)

## Objectif du TP

Ce projet implémente un serveur LDAP OpenLDAP 2.6 avec les fonctionnalités suivantes :

- **Discrétisation** : Gestion des droits via un groupe `admin_ldap` au lieu du superutilisateur `cn=admin`
- **Intégration Linux** : Authentification PAM/NSS
- **Fédération Keycloak** : service Keycloak dans `projet/docker-compose.yml`, script `projet/scripts/configure_keycloak_ldap.sh`, tests `projet/test/test_05_keycloak.sh`
- **Réplication RW/RO** : service `ldap` (fournisseur) + `ldap-replica` sur le port **1389**, syncrepl + réplica en lecture seule ; tests `projet/test/test_06_replication.sh`
- **Méta-annuaire** : services **`ldap-acme`** (port **2389**) et **`ldap-meta`** (port **3389**, suffixe **`o=federation`**) dans `projet/docker-compose.yml`, script `projet/scripts/init_meta_annuaire.sh`, tests `projet/test/test_07_meta_annuaire.sh`

Les instructions à l'origine de ce TP sont disponibles dans le fichier [INSTRUCTIONS.md](./INSTRUCTIONS.md)

## Prérequis (machine hôte)

- **Docker** et **Docker Compose** (plugin `docker compose`).
- **Ports libres** : **389** (LDAP fournisseur), **1389** (LDAP réplica), **2389** (second annuaire Acme), **3389** (méta-annuaire), **8090** et **9001** (Keycloak ; si 8090 est pris, définir `KEYCLOAK_URL` avant les tests ou adapter les ports dans `projet/docker-compose.yml`).
- Pour les **tests automatisés** et les commandes **`ldapsearch` / `ldapwhoami`** ci-dessous : clients LDAP sur l’hôte (souvent le paquet **`ldap-utils`** sur Debian/Ubuntu, ou **`openldap-clients`** sur Fedora/RHEL).
- Pour **Keycloak** (`test_05_keycloak.sh`, script de configuration) : **`curl`** et **`python3`** sur l’hôte.

Sans `ldap-utils` (ou équivalent), le démarrage Docker fonctionne encore, mais `./projet/test/test_01_*.sh` et les tests manuels LDAP depuis la machine hôte échoueront.

## Démarrage rapide

Les fichiers Docker et les scripts d’automatisation sont dans **`projet/`** (compose, Dockerfile, scripts d’init). Les tests restent dans **`projet/test/`** et se lancent depuis la racine du dépôt avec `./projet/test/…`.

**Option A — depuis `projet/`** (recommandé) :

```bash
cd projet
docker compose up -d --build
docker ps
docker logs -f ldap
```

**Option B — depuis la racine du dépôt** (même contexte de build : `projet/`) :

```bash
docker compose -f projet/docker-compose.yml up -d --build
docker logs -f ldap
```

La configuration **OpenLDAP** (DIT, ACL, utilisateurs de démo) est appliquée **dans le conteneur** au premier démarrage. **Keycloak** démarre vide : pour créer le realm `tp-ldap` et la fédération LDAP, exécuter une fois (depuis la racine du dépôt) :

```bash
bash projet/scripts/configure_keycloak_ldap.sh
```

(C’est aussi fait automatiquement lors de l’exécution de `./projet/test/test_05_keycloak.sh` ou de la suite complète ci-dessous.) Au premier lancement, attendre **environ 30 à 60 secondes** que Keycloak réponde sur **http://localhost:8090** avant le script ou les tests Keycloak.

## Tests

### Scripts de test

```bash
# Toute la suite (objectifs 1 à 7 ; suppose « docker compose up » déjà lancé dans projet/)

./projet/test/test_all_implemented.sh

# Un seul objectif, par exemple le DIT
./projet/test/test_02_conception_dit.sh
```

### Tests manuels

```bash
# Test de connexion LDAP
ldapsearch -x -H ldap://localhost:389 -b dc=example,dc=org -s base dn

# Test d'authentification
ldapwhoami -x -D cn=admin,dc=example,dc=org -w admin
ldapwhoami -x -D uid=thomas,ou=people,dc=example,dc=org -w thomas123

# Test de résolution NSS (dans le conteneur)
docker exec ldap bash -c "getent passwd thomas"
docker exec ldap bash -c "getent group admin_ldap"
```

### Keycloak (fédération LDAP)

Après `docker compose up -d` dans `projet/` et une courte attente pour le démarrage de Keycloak :

- **Configuration automatique** : `./projet/test/test_05_keycloak.sh` (ou la suite complète).
- **Console d’administration** : [http://localhost:8090/admin/](http://localhost:8090/admin/) — compte bootstrap par défaut : `admin` / `admin` (voir `projet/docker-compose.yml`).
- **Realm applicatif** : `tp-ldap` ; utilisateurs de test synchronisés depuis LDAP : **thomas** / `thomas123`, **john** / `john123`.

### Réplication (lecture seule sur le réplica)

- **Fournisseur** : `ldap://localhost:389` (écritures).
- **Réplica** : `ldap://localhost:1389` (syncrepl depuis `ldap` ; `olcReadOnly` refuse les modifications client).
- **Vérification** : `./projet/test/test_06_replication.sh` (attente automatique de la synchro).

### Méta-annuaire (agrégation)

- **Second annuaire** : `ldap://localhost:2389`, base `dc=acme,dc=com` (même DIT de démo que l’annuaire principal).
- **Méta-annuaire** : `ldap://localhost:3389`, suffixe virtuel `o=federation` ; sous-arbres `ou=example-org,o=federation` et `ou=acme-corp,o=federation`.
- **Exemple** : `ldapsearch -x -H ldap://localhost:3389 -D cn=admin,o=federation -w admin -b o=federation -s sub '(uid=thomas)' dn mail`
- **Vérification** : `./projet/test/test_07_meta_annuaire.sh`.

## Structure DIT

```text
dc=example,dc=org
├── ou=people,dc=example,dc=org
│   ├── uid=thomas (membre de admin_ldap)
│   └── uid=john (membre de developers)
└── ou=groups,dc=example,dc=org
    ├── cn=admin_ldap (posixGroup, gidNumber: 1001)
    ├── cn=developers (posixGroup, gidNumber: 1002)
    └── cn=admin_keycloak (groupOfNames ; thomas membre — rôle procédural Keycloak)
```

## Structure du projet

```text
TP-LDAP/
├── projet/              # Docker, scripts d’init ; compose ici (contexte de build = ce dossier)
│   ├── .dockerignore    # Limite le contexte envoyé au build (exclut test/)
│   ├── docker/
│   ├── scripts/
│   ├── test/
│   └── docker-compose.yml
├── documentation/     # Parties du rapport (partie-01 … partie-07) + guides
├── reference/           # PDF et pages HTML de lecture (hors doc de construction)
├── README.md
└── INSTRUCTIONS.md
```

## Reset et nettoyage

### Reset complet (supprimer toutes les données)

```bash
cd projet
# Arrêter, supprimer les volumes et reconstruire
docker compose down -v
docker compose up -d --build
```

### Nettoyage complet (supprimer tout)

```bash
cd projet
# Supprimer conteneurs, volumes, images et réseaux
docker compose down -v --rmi local
```

### Si un conteneur reste bloqué (unhealthy, dépendances)

```bash
cd projet
docker compose down --remove-orphans -v
docker container prune -f
docker network prune -f
docker compose up -d --build
```

## Dépannage

```bash
cd projet

# Voir les logs
docker logs -f ldap

# Redémarrer le conteneur
docker compose restart ldap

# Accès au conteneur en mode interactif
docker exec -it ldap bash
```

### Conteneur bloqué en « Created » ou conflit de nom `ldap`

Après un arrêt brutal, Docker peut laisser un conteneur orphelin qui réserve encore le nom `ldap`. Dans ce cas :

```bash
docker rm -f ldap 2>/dev/null || true
cd projet && docker compose down -v --remove-orphans
docker compose up -d --build
```

Si `docker compose down` reste bloqué sur « Stopping », forcer : `docker rm -f ldap` puis relancer `docker compose down`.
