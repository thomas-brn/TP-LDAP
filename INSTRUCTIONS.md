# LDAP Lab — OpenLDAP 2.6

## Objectives

This lab aims to:

<<<<<<< HEAD
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
=======
1. **Understand** LDAP directory architecture and behavior
2. **Deploy** an OpenLDAP 2.6 server in a containerized environment
3. **Design** a DIT (Directory Information Tree) adapted to a realistic use case
4. **Implement** fine-grained access control through role-based ACLs
5. **Integrate** LDAP with Linux systems for authentication
6. **Federate** LDAP with Keycloak for identity management
7. **Set up** a replication architecture for high availability
8. **Build** a meta-directory aggregating multiple LDAP sources
9. **Test** the entire infrastructure
>>>>>>> 7f0a3c9 (Update instructions and README for LDAP lab; translate objectives and constraints to English, enhance clarity, and improve consistency across documentation. Modify Docker and entrypoint scripts for better readability and maintainability. Adjust test scripts to reflect updated objectives and ensure proper integration with Keycloak and LDAP services.)

---

## Technical Constraints

Constraints:

| Item             | Constraint                |
| ---------------- | ------------------------- |
| Distribution     | Debian 12 (bookworm)      |
| Containerization | Docker                    |
| Base image       | `debian:bookworm-slim`    |
| LDAP server      | OpenLDAP **2.6**          |
| Configuration    | Bash scripts              |
| Entrypoint       | `sleep` loop              |
| Authentication   | Linux (PAM/NSS), Keycloak |

**Reference documentation:**
[OpenLDAP 2.6 Admin Guide](https://www.openldap.org/doc/admin26/guide.html)

---

## Automated Installation and Deployment

Create a fully automated LDAP infrastructure:

1. **Create a Dockerfile** that:
   - Uses `debian:bookworm-slim` as base image
   - Installs `slapd` and `ldap-utils`
   - Configures OpenLDAP non-interactively
   - Exposes required ports

2. **Create an initialization script** that:
   - Configures the LDAP server without manual intervention
   - Creates the base DIT structure
   - Imports initial data using LDIF files

3. **Create a `docker-compose.yml`** that:
   - Starts the LDAP service
   - Configures persistent volumes
   - Enables startup with a single command

   In this repository, the matching file is **`projet/docker-compose.yml`** (run Docker commands from **`projet/`**).

---

## DIT Structure Design

Design and implement a consistent directory structure (DIT):

1. **Define the base DN** (`dc=...`) for your use case
2. **Create required organizational units**:
   - One OU for users (`ou=people`)
   - One OU for groups (`ou=groups`)
   - Additional OUs if needed

3. **Justify your design choices** in your report:
   - Why this structure?
   - How does it meet requirements?
   - How can it evolve?

---

## Role Discretization and ACLs

Implement access control based on **role discretization**:

1. **Create LDAP groups** with specific roles:
   - `admin_ldap`: full directory administration
   - `admin_keycloak`: Keycloak role administration (if applicable)
   - Additional functional groups as needed

2. **Configure ACLs** to:
   - Grant admin rights to the `admin_ldap` group
   - Allow users to modify their own attributes
   - Protect sensitive attributes (`userPassword`)
   - Enforce the principle of least privilege

3. **Do not use** `cn=admin` for day-to-day administration

---

## Linux Integration (PAM/NSS)

Configure a Linux system to use LDAP as its authentication backend:

1. **Configure NSS** for user/group resolution
2. **Configure PAM** for authentication
3. **Test** that:
   - LDAP users are visible with `getent passwd`
   - LDAP groups are visible with `getent group`
   - Authentication works (`su`, `ssh`, etc.)

---

## Keycloak Integration (OpenID)

Configure Keycloak to use LDAP as an identity provider:

1. **Deploy Keycloak** (Docker container)
2. **Configure LDAP User Federation** in Keycloak
3. **Test** that:
   - LDAP users are synchronized in Keycloak
   - Keycloak authentication works with LDAP accounts
   - Roles can be managed separately in Keycloak

---

## LDAP Replication (RW / RO)

Set up a replication architecture:

1. **Create a primary server** (Read-Write)
2. **Create one or more secondary servers** (Read-Only)
3. **Configure replication** between servers
4. **Test** that:
   - Changes on the primary server are propagated
   - Secondary servers are read-only
   - Synchronization works correctly

---

## LDAP Federation (Meta-directory)

Build a meta-directory that aggregates multiple LDAP sources:

1. **Create multiple distinct LDAP directories** (simulating different entities)
2. **Configure a meta-directory** that:
   - Recognizes downstream directories
   - Centralizes access to data
   - Allows queries across multiple sources

3. **Test** that queries on the meta-directory return data from different LDAP sources

---

## Testing and Validation

Provide test scripts for each objective:

1. **Basic LDAP tests**: connection and DIT checks
2. **ACL tests**: rights validation by group
3. **Linux integration tests**: resolution and authentication
4. **Keycloak integration tests**: synchronization and authentication
5. **Replication tests**: change propagation
6. **Meta-directory tests**: source aggregation
