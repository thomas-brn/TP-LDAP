# LDAP Lab - OpenLDAP 2.6 on Debian 12 (Docker)

## Lab Goal

This project implements an OpenLDAP 2.6 server with the following features:

- **Role discretization**: access control through an `admin_ldap` group instead of the `cn=admin` superuser
- **Linux integration**: PAM/NSS authentication
- **Keycloak federation**: Keycloak service in `projet/docker-compose.yml`, script `projet/scripts/configure_keycloak_ldap.sh`, tests `projet/test/test_05_keycloak.sh`
- **RW/RO replication**: `ldap` service (provider) + `ldap-replica` on port **1389**, syncrepl + read-only replica; tests `projet/test/test_06_replication.sh`
- **Meta-directory**: **`ldap-acme`** (port **2389**) and **`ldap-meta`** (port **3389**, suffix **`o=federation`**) services in `projet/docker-compose.yml`, script `projet/scripts/init_meta_annuaire.sh`, tests `projet/test/test_07_meta_annuaire.sh`

The original lab instructions are available in [INSTRUCTIONS.md](./INSTRUCTIONS.md).

## Prerequisites (host machine)

- **Docker** and **Docker Compose** (`docker compose` plugin).
- **Free ports**: **389** (LDAP provider), **1389** (LDAP replica), **2389** (second Acme directory), **3389** (meta-directory), **8090** and **9001** (Keycloak; if 8090 is already used, define `KEYCLOAK_URL` before tests or adjust ports in `projet/docker-compose.yml`).
- For **automated tests** and **`ldapsearch` / `ldapwhoami`** commands below: LDAP clients installed on host (typically **`ldap-utils`** on Debian/Ubuntu, or **`openldap-clients`** on Fedora/RHEL).
- For **Keycloak** (`test_05_keycloak.sh`, configuration script): **`curl`** and **`python3`** installed on host.

Without `ldap-utils` (or equivalent), Docker startup still works, but `./projet/test/test_01_*.sh` and manual LDAP tests from host will fail.

## Quick Start

Docker files and automation scripts are in **`projet/`** (`docker-compose.yml`, Dockerfile, init scripts). Tests remain in **`projet/test/`** and are run from repository root with `./projet/test/...`.

**Option A - from `projet/`** (recommended):

```bash
cd projet
docker compose up -d --build
docker ps
docker logs -f ldap
```

**Option B - from repository root** (same build context: `projet/`):

```bash
docker compose -f projet/docker-compose.yml up -d --build
docker logs -f ldap
```

**OpenLDAP** configuration (DIT, ACLs, demo users) is applied **inside the container** at first startup. **Keycloak** starts empty: to create realm `tp-ldap` and LDAP federation, run once (from repository root):

```bash
bash projet/scripts/configure_keycloak_ldap.sh
```

(This is also done automatically when running `./projet/test/test_05_keycloak.sh` or the full suite below.) On first launch, wait **about 30 to 60 seconds** until Keycloak responds on **[http://localhost:8090](http://localhost:8090)** before running script/tests.

## Tests

### Test scripts

```bash
# Full suite (objectives 1 to 7; assumes "docker compose up" already running in projet/)
./projet/test/test_all_implemented.sh

# Single objective, e.g. DIT
./projet/test/test_02_conception_dit.sh
```

### Manual tests

```bash
# LDAP connectivity test
ldapsearch -x -H ldap://localhost:389 -b dc=example,dc=org -s base dn

# Authentication test
ldapwhoami -x -D cn=admin,dc=example,dc=org -w admin
ldapwhoami -x -D uid=thomas,ou=people,dc=example,dc=org -w thomas123

# NSS resolution test (inside container)
docker exec ldap bash -c "getent passwd thomas"
docker exec ldap bash -c "getent group admin_ldap"
```

### Keycloak (LDAP federation)

After `docker compose up -d` in `projet/` and a short wait for Keycloak startup:

- **Automatic configuration**: `./projet/test/test_05_keycloak.sh` (or full suite).
- **Admin console**: [http://localhost:8090/admin/](http://localhost:8090/admin/) - default bootstrap account: `admin` / `admin` (see `projet/docker-compose.yml`).
- **Application realm**: `tp-ldap`; test users synchronized from LDAP: **thomas** / `thomas123`, **john** / `john123`.

### Replication (read-only replica)

- **Provider**: `ldap://localhost:389` (writes).
- **Replica**: `ldap://localhost:1389` (syncrepl from `ldap`; `olcReadOnly` rejects client updates).
- **Verification**: `./projet/test/test_06_replication.sh` (automatic sync wait).

### Meta-directory (aggregation)

- **Second directory**: `ldap://localhost:2389`, base `dc=acme,dc=com` (same demo DIT as main directory).
- **Meta-directory**: `ldap://localhost:3389`, virtual suffix `o=federation`; subtrees `ou=example-org,o=federation` and `ou=acme-corp,o=federation`.
- **Example**: `ldapsearch -x -H ldap://localhost:3389 -D cn=admin,o=federation -w admin -b o=federation -s sub '(uid=thomas)' dn mail`
- **Verification**: `./projet/test/test_07_meta_annuaire.sh`.

## DIT Structure

```text
dc=example,dc=org
├── ou=people,dc=example,dc=org
│   ├── uid=thomas (member of admin_ldap)
│   └── uid=john (member of developers)
└── ou=groups,dc=example,dc=org
    ├── cn=admin_ldap (posixGroup, gidNumber: 1001)
    ├── cn=developers (posixGroup, gidNumber: 1002)
    └── cn=admin_keycloak (groupOfNames; thomas member - procedural Keycloak role)
```

## Project Structure

```text
TP-LDAP/
├── projet/              # Docker, init scripts; compose file is here (build context = this folder)
│   ├── .dockerignore    # Limits build context sent to Docker (excludes test/)
│   ├── docker/
│   ├── scripts/
│   ├── test/
│   └── docker-compose.yml
├── documentation/     # Parties du rapport (partie-01 … partie-07) + guides
├── reference/           # PDF et pages HTML de lecture (hors doc de construction)
├── README.md
└── INSTRUCTIONS.md
```

## Reset and Cleanup

### Full reset (delete all data)

```bash
cd projet
# Stop, remove volumes, and rebuild
docker compose down -v
docker compose up -d --build
```

### Full cleanup (remove everything)

```bash
cd projet
# Remove containers, volumes, images, and networks
docker compose down -v --rmi local
```

### If a container gets stuck (unhealthy, dependencies)

```bash
cd projet
docker compose down --remove-orphans -v
docker container prune -f
docker network prune -f
docker compose up -d --build
```

## Troubleshooting

```bash
cd projet

# View logs
docker logs -f ldap

# Restart container
docker compose restart ldap

# Interactive shell in container
docker exec -it ldap bash
```

### Container stuck in "Created" or `ldap` name conflict

After an abrupt shutdown, Docker can leave an orphan container still reserving name `ldap`. In that case:

```bash
docker rm -f ldap 2>/dev/null || true
cd projet && docker compose down -v --remove-orphans
docker compose up -d --build
```

If `docker compose down` stays stuck in "Stopping", force it with `docker rm -f ldap` then run `docker compose down` again.
