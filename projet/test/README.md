# Test Scripts

Tests are split **by main lab objective**. They assume the compose containers are reachable: `ldap` on `localhost:389`, **`ldap-replica`** on `localhost:1389` (objective 6), **`ldap-acme`** on `localhost:2389` and **`ldap-meta`** on `localhost:3389` (objective 7), and for objective 5 **Keycloak** on `http://localhost:8090` (after `cd projet && docker compose up -d`).

## Shared Library

- **`lib/test_common.sh`** — variables (`BASE_DN`, test passwords), colors, and helper functions `test_function` / `test_with_output` (do not execute directly, only `source` it).

## One Script Per Objective

- `test_01_installation_deploiement.sh`: objective 1 — automated installation and deployment
- `test_02_conception_dit.sh`: objective 2 — DIT structure design
- `test_03_roles_acl.sh`: objective 3 — role discretization and ACLs
- `test_04_integration_linux.sh`: objective 4 — Linux integration (PAM/NSS)
- `test_05_keycloak.sh`: objective 5 — Keycloak integration (User Federation)
- `test_06_replication.sh`: objective 6 — LDAP replication (provider / RO replica)
- `test_07_meta_annuaire.sh`: objective 7 — LDAP federation (meta-directory)

**Usage** (from repository root):

```bash
./projet/test/test_02_conception_dit.sh
```

Or from `projet/test/`:

```bash
./test_03_roles_acl.sh
```

Each script prints a local summary and exits with `exit 0` or `exit 1`.

## Run the Full Suite

**`test_all_implemented.sh`** runs all seven scripts in order and prints a **global summary** (OK / failed per file).

```bash
./projet/test/test_all_implemented.sh
```
