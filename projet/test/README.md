# Scripts de test

<<<<<<< HEAD
Les tests sont découpés **par objectif principal du TP**. Ils supposent les conteneurs du compose joignables : `ldap` sur `localhost:389`, **ldap-replica** sur `localhost:1389` (objectif 6), **ldap-acme** sur `localhost:2389` et **ldap-meta** sur `localhost:3389` (objectif 7), et pour l’objectif 5 **Keycloak** sur `http://localhost:8090` (après `cd projet && docker compose up -d`).
=======
Les tests sont découpés **par objectif principal du TP**. Ils supposent les conteneurs du compose joignables : `ldap` sur `localhost:389`, **ldap-replica** sur `localhost:1389` (objectif 6), et pour l’objectif 5 **Keycloak** sur `http://localhost:8090` (après `cd projet && docker compose up -d`).
>>>>>>> a9ae0b6 (keycloak et replication)

## Bibliothèque partagée

- **`lib/test_common.sh`** — variables (`BASE_DN`, mots de passe de test), couleurs, helpers `test_function` / `test_with_output` (à ne pas exécuter seul : uniquement `source`).

## Un script par objectif

| Script                                | Objectif                                   |
| ------------------------------------- | ------------------------------------------ |
| `test_01_installation_deploiement.sh` | 1 — Installation et déploiement automatisé |
| `test_02_conception_dit.sh`           | 2 — Conception de la structure DIT         |
| `test_03_roles_acl.sh`                | 3 — Discrétisation des rôles et ACL        |
| `test_04_integration_linux.sh`        | 4 — Intégration Linux (PAM/NSS)            |
| `test_05_keycloak.sh`                 | 5 — Intégration Keycloak (User Federation) |
| `test_06_replication.sh`              | 6 — Réplication LDAP (fournisseur / réplica RO) |
<<<<<<< HEAD
| `test_07_meta_annuaire.sh`            | 7 — Fédération LDAP (méta-annuaire)            |
=======
>>>>>>> a9ae0b6 (keycloak et replication)

**Usage** (depuis la racine du dépôt) :

```bash
./projet/test/test_02_conception_dit.sh
```

Ou depuis `projet/test/` :

```bash
./test_03_roles_acl.sh
```

Chaque script affiche un résumé local et se termine par `exit 0` ou `exit 1`.

## Lancer toute la suite

<<<<<<< HEAD
**`test_all_implemented.sh`** enchaîne les sept scripts dans l’ordre et affiche un **résumé global** (OK / échec par fichier).
=======
**`test_all_implemented.sh`** enchaîne les six scripts dans l’ordre et affiche un **résumé global** (OK / échec par fichier).
>>>>>>> a9ae0b6 (keycloak et replication)

```bash
./projet/test/test_all_implemented.sh
```
<<<<<<< HEAD
=======

## Tests à ajouter

Pour les objectifs non encore couverts (**méta-annuaire**, partie 7 du rapport), ajouter un nouveau `test_*.sh` et le référencer dans `test_all_implemented.sh` si vous souhaitez l’enchaîner avec la suite actuelle.

**Documentation du rapport** : les chapitres détaillés par thème sont dans `documentation/partie-0*.md` (voir le tableau en fin de [README.md](../../README.md) à la racine du dépôt).
>>>>>>> a9ae0b6 (keycloak et replication)
