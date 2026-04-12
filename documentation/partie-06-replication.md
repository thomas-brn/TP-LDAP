# TP LDAP — Partie 6 : Réplication LDAP (RW / RO)

> **Usage** : ce fichier est un **chapitre autonome** du rapport (copier-coller tel quel).  
> **Chapitre** : 6 / 7 — *Réplication LDAP (RW / RO)* (`INSTRUCTIONS.md`, même intitulé).  
> **Prérequis** : *Parties 1 à 5* — annuaire **fournisseur** opérationnel sur le port **389**, **DIT** et **ACL** en place ; **Keycloak** utilise le service **`ldap`** (fournisseur), pas le réplica.  
> **Convention dépôt** : second service **`ldap-replica`** dans **`projet/docker-compose.yml`** (port hôte **1389** → LDAP **389** interne) ; scripts **`30-init_replication_provider.sh`** et **`35-init_replication_consumer.sh`** dans `/container/init.d/` ; tests **`projet/test/test_06_replication.sh`**.  
> **Chapitre précédent** : *Partie 5 — Intégration Keycloak (OpenID)* (`documentation/partie-05-keycloak.md`).  
> **Chapitre suivant** : *Partie 7 — Fédération LDAP (méta-annuaire)* (`documentation/partie-07-meta-annuaire.md`) — *non implémentée dans le dépôt à ce stade*.

Ce document décrit la **réplication OpenLDAP 2.6** entre un **serveur principal en lecture-écriture** (fournisseur) et un **réplica en lecture seule**, conformément à **`INSTRUCTIONS.md`** (section « Réplication LDAP (RW / RO) »). Mécanisme retenu : **syncrepl** en **refreshAndPersist**, overlay **syncprov** côté fournisseur, **`olcReadOnly: TRUE`** sur la base MDB du réplica pour refuser les écritures **clients** (la synchro interne reste autorisée).

---

## 1. Objectifs de l’énoncé

1. **Serveur principal** (read-write) : toutes les modifications LDAP s’effectuent ici.  
2. **Serveur secondaire** (read-only) : copie à jour des données ; pas de modification applicative via LDAP client.  
3. **Réplication** : propagation des changements du principal vers le secondaire.  
4. **Tests** : modifications visibles sur le réplica ; tentatives d’écriture sur le réplica refusées ; cohérence globale.

---

## 2. Architecture dans le dépôt

| Rôle | Service Compose | Port hôte | Rôle applicatif |
|------|-----------------|-----------|-----------------|
| Fournisseur | `ldap` | **389** | RW, syncprov, `olcServerID: 1` |
| Réplica | `ldap-replica` | **1389** | RO (`olcReadOnly`), syncrepl vers `ldap://ldap:389` |

- **Même image Docker** que le fournisseur ; le comportement est discriminé par la variable d’environnement **`LDAP_SERVICE_ROLE`** : `provider` (défaut) ou **`consumer`**.  
- **Réseau** : les deux conteneurs partagent le réseau Compose ; le réplica joint le fournisseur sous le nom DNS **`ldap`**.  
- **Ordre de démarrage** : `ldap-replica` dépend de **`ldap` en état `healthy`**. Le healthcheck du fournisseur exige notamment la présence de l’overlay **syncprov** (détecté via `(objectClass=olcSyncProvConfig)` sous `cn=config`), afin d’éviter de démarrer le réplica avant que la réplication soit possible.

---

## 3. Scripts et initialisation

### 3.1. Fichier « init terminée » et healthchecks

Après exécution de **tous** les scripts `/container/init.d/*.sh`, l’**entrypoint** crée **`/container/.ldap-init-complete`**. Les healthchecks s’appuient sur ce fichier pour ne pas tester un annuaire **en cours** de construction (DIT ou syncprov encore absents).

### 3.2. Fournisseur (`LDAP_SERVICE_ROLE` absent ou `provider`)

1. **`10-init_ldap.sh`** — Création MDB, DIT, ACL (voir parties 2 et 3). Après suppression/recréation de la base en cn=config, une **purge des fichiers** sous `/var/lib/ldap` et un **redémarrage de slapd** évitent un décalage entre suffixe configuré (`dc=example,dc=org`) et contenu résiduel (ex. `dc=nodomain`).  
2. **`20-init_ldap_linux_integration.sh`** — NSS/PAM dans le conteneur fournisseur.  
3. **`30-init_replication_provider.sh`** — Chargement du module **`syncprov.la`** sur **`cn=module{0},cn=config`** (requis sous Debian pour la classe **`olcSyncProvConfig`**), ajout de l’overlay syncprov sur **`olcDatabase={1}mdb`**, **`olcServerID: 1`**, index **`entryUUID`**.  

> **Note** : dans cn=config, le RDN de l’overlay est typiquement **`olcOverlay={0}syncprov,...`** et non `olcOverlay=syncprov,...` : les vérifications automatisées utilisent une recherche par **`objectClass=olcSyncProvConfig`**, pas un DN littéral `syncprov`.

### 3.3. Réplica (`LDAP_SERVICE_ROLE=consumer`)

1. **`10-init_ldap.sh`** — Même création de MDB, **ACL** alignées sur le fournisseur, **sans** import local du DIT (données attendues via syncrepl).  
2. **`20-init_ldap_linux_integration.sh`** — **Ignoré** (sortie immédiate) : pas de double configuration NSS sur le réplica pour ce TP.  
3. **`30-init_replication_provider.sh`** — Aucune action (sortie si rôle consumer).  
4. **`35-init_replication_consumer.sh`** — Attente du fournisseur **`LDAP_REPLICATION_PROVIDER_URI`** (défaut `ldap://ldap:389`), **`olcServerID: 2`**, **`olcReadOnly: TRUE`**, **`olcSyncrepl`** (bind `cn=admin`, `searchbase` = suffixe, `type=refreshAndPersist`).

Variables utiles côté réplica : **`LDAP_REPLICATION_PROVIDER_URI`**, **`LDAP_BASE_DN`**, **`LDAP_ADMIN_PASSWORD`** (mot de passe du bind de réplication — en démo identique au rootDN).

---

## 4. Vérifications et tests

| Vérification | Moyen dans le dépôt |
|--------------|------------------------|
| Conteneurs `ldap` et `ldap-replica` actifs | `docker compose ps` |
| Données présentes sur le réplica | `ldapsearch -H ldap://localhost:1389 ... '(uid=thomas)'` après synchro |
| Propagation d’une modification | Script de test : attribut `description` sur `uid=thomas` côté **389**, relecture sur **1389** |
| Lecture seule sur le réplica | `ldapmodify` sur **1389** → échec attendu |

Suite automatisée : **`./projet/test/test_06_replication.sh`** (incluse dans **`test_all_implemented.sh`**).

---

## 5. Dépannage (rappel)

- Conteneur **`ldap` unhealthy** : souvent healthcheck trop tôt ou overlay syncprov introuvable ; vérifier les logs `docker logs ldap` et la présence d’une entrée **`olcSyncProvConfig`** sous `cn=config`.  
- Réplica vide après démarrage : s’assurer que le fournisseur était **healthy** avant le réplica ; en cas de doute : `docker compose down --remove-orphans -v`, puis `docker compose up -d --build` (voir README racine, section nettoyage).  
- **Ne pas** confondre le test LDAP sur le suffixe **avant** synchro : sur un réplica, la root DSE peut annoncer `namingContexts` alors que les entrées ne sont pas encore importées — les tests attendent explicitement **`uid=thomas`**.

---

## 6. Synthèse

| Attendu | Réalisation |
|---------|-------------|
| Principal RW | `ldap` : `389` |
| Secondaire RO | `ldap-replica` : `olcReadOnly` + `1389` |
| Réplication | syncprov + syncrepl |
| Tests | `test_06_replication.sh` |

**Fin du chapitre 6 / 7** — La suite logique du sujet est la *Partie 7 — Méta-annuaire* (`documentation/partie-07-meta-annuaire.md`), décrite pour l’instant comme **travaux restants** dans le dépôt.

*Référence : `INSTRUCTIONS.md` — section « Réplication LDAP (RW / RO) ».*
