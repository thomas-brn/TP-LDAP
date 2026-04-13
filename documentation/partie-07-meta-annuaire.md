# TP LDAP - Partie 7 : Fédération LDAP (méta-annuaire)

## 1. Ce que demandent les instructions

1. **Plusieurs annuaires LDAP** distincts (simulation d’entités différentes).
2. Un **méta-annuaire** qui reconnaît les annuaires « inférieurs », centralise l’accès et permet d’interroger **plusieurs sources**.
3. **Tests** : des requêtes sur le méta-annuaire renvoient des données issues des différents LDAP sous-jacents.

---

## 2. État du projet (implémenté)

| Élément                         | Statut                                                                                                                                                                                                 |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Annuaire principal **`ldap`**   | `dc=example,dc=org` (port **389**) - inchangé pour les parties 1–5                                                                                                                                     |
| Second annuaire **`ldap-acme`** | `dc=acme,dc=com` (port **2389**), même image et même logique de DIT que le premier (utilisateurs **thomas** / **john**, mots de passe de démo identiques)                                              |
| Méta-annuaire **`ldap-meta`**   | OpenLDAP **back-meta** + **back_ldap** ; suffixe **`o=federation`** ; sous-arbres virtuels **`ou=example-org,o=federation`** → `dc=example,dc=org`, **`ou=acme-corp,o=federation`** → `dc=acme,dc=com` |
| Tests automatisés               | `projet/test/test_07_meta_annuaire.sh` (+ entrée dans `test_all_implemented.sh`)                                                                                                                       |

**Remarque** : le binaire Debian **slapd** du conteneur est en **2.5.x** ; les concepts (meta, suffixmassage, `olcDbIDAssertBind`) correspondent à la famille OpenLDAP visée par le TP (**2.6** en cible pédagogique).

---

## 3. Mise en œuvre dans le dépôt

### 3.1. Rôle `meta` et scripts

- Dans **`init_ldap.sh`**, si **`LDAP_SERVICE_ROLE=meta`**, aucune base **mdb** locale ni DIT de démo n’est créé : le script délègue à **`init_meta_annuaire.sh`** puis se termine avec le code retour de ce script.
- **`init_meta_annuaire.sh`** : supprime la mdb par défaut, charge **`back_ldap.la`** (requis par **back_meta**), charge **`back_meta.la`**, ajoute la base **`olcDatabase=meta`** avec **`olcSuffix: o=federation`**, puis deux entrées **`olcMetaTargetConfig`** avec **`olcDbURI`** pointant vers un naming context **sous** `o=federation`, **`suffixmassage`** vers le suffixe réel, et **`olcDbIDAssertBind`** (compte **`cn=admin`** de chaque annuaire, mot de passe **`LDAP_ADMIN_PASSWORD`**) pour la lecture sur les backends (les ACL des annuaires n’autorisent pas l’anonyme en lecture générale).
- **`init_ldap_linux_integration.sh`**, **`init_replication_provider.sh`** : ignorés ou sans effet lorsque **`LDAP_SERVICE_ROLE=meta`**.

### 3.2. Docker Compose

- **`ldap-acme`** : build identique à **`ldap`**, variables **`LDAP_BASE_DN=dc=acme,dc=com`**, **`LDAP_DOMAIN=acme.com`**, publication **2389:389**, dépend du **`ldap`** sain (ordonnancement pédagogique).
- **`ldap-meta`** : **`LDAP_SERVICE_ROLE=meta`**, volumes dédiés, **3389:389**, **`depends_on`** **`ldap`** et **`ldap-acme`** en **healthy**.
- Les URI internes utilisées par le méta sont **`ldap://ldap:389`** et **`ldap://ldap-acme:389`** (noms de services Compose).

### 3.3. Vue côté client

- Bind d’administration sur le méta : **`cn=admin,o=federation`** / mot de passe **`admin`** (démo).
- Exemple : une recherche **`(uid=thomas)`** sous **`o=federation`** retourne **deux** entrées (chemins **`…ou=example-org,…`** et **`…ou=acme-corp,…`**), distinguables notamment par l’attribut **`mail`** (`thomas@example.org` vs `thomas@acme.com`).

---

## 4. Vérifications (check-list)

```text
[x] docker compose ps  →  ldap, ldap-acme, ldap-meta UP
[x] ldapsearch sur le méta sous o=federation  →  deux uid=thomas (sources distinctes)
[x] Scripts test_07_meta_annuaire.sh et suite test_all_implemented.sh
```
