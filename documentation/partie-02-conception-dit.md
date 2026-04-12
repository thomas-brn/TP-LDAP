# TP LDAP — Partie 2 : Conception de la structure DIT

> **Usage** : ce fichier est un **chapitre autonome** du rapport (copier-coller tel quel).  
> **Chapitre** : 2 / 5 — *Conception de la structure DIT* (`INSTRUCTIONS.md`, même intitulé).  
> **Prérequis** : *Partie 1 — Installation et déploiement automatisé* : conteneur `ldap` démarré, `slapd` et scripts `init.d` exécutés (notamment **`projet/scripts/init_ldap.sh`** copié en `10-init_ldap.sh`).  
> **Convention dépôt** : suffixe piloté par **`LDAP_BASE_DN`** (ex. `dc=example,dc=org`) ; comptes exemple **`thomas`** / **`john`** sous **`ou=people`** ; groupes sous **`ou=groups`**.  
> **Chapitre précédent** : *Partie 1 — Installation et déploiement automatisé*.  
> **Chapitre suivant** : *Partie 3 — Discrétisation des rôles et ACL* (`documentation/partie-03-roles-acl.md`).

Ce document décrit **comment l’annuaire est structuré** dans le projet : choix du suffixe (base DN), unités organisationnelles, et peuplement minimal. Il complète la section « Conception de la structure DIT » de **`INSTRUCTIONS.md`**. Logique suivie : après reconfiguration de la base MDB, le suffixe existe en configuration mais le **contenu** du DIT est créé par **LDIF** et commandes **`ldapadd`** / **`ldapmodify`**.

---

## 1. Contexte : pourquoi le DIT n’existe pas « tout seul »

La **déclaration du suffixe** dans `cn=config` (`olcSuffix`, base MDB) ne crée **ni** l’entrée racine du contexte utilisateur **ni** l’arborescence sous-jacente : il faut un **LDIF d’amorçage** (racine `dc=…`, OU, etc.) pour matérialiser le DIT sous ce suffixe.

Dans le projet, cette étape est intégrée au script **`projet/scripts/init_ldap.sh`**, après suppression de la base MDB par défaut et création d’une nouvelle base pointant vers le suffixe voulu.

---

## 2. Choix du base DN

Les instructions demandent de **définir un base DN** (`dc=...`) adapté au cas d’usage.

**Paramétrage** : les variables d’environnement suivantes pilotent la construction du DIT :

- `LDAP_BASE_DN` — suffixe de l’annuaire (ex. `dc=example,dc=org` dans `projet/docker-compose.yml`) ;
- `LDAP_ORGANISATION` — attribut `o` de l’organisation ;
- `LDAP_DOMAIN` — sert notamment au mail et à dériver le premier segment `dc` (partie avant le premier `.` du domaine).

**NOTA :** dans le script `init_ldap.sh`, des valeurs par défaut internes (`dc=polytech,dc=fr`, etc.) ne s’appliquent **que** si les variables ne sont pas définies ; avec Docker Compose, ce sont les valeurs du fichier compose qui priment.

---

## 3. Arborescence retenue

Conformément aux instructions, on trouve au minimum :

| Entrée | Rôle |
|--------|------|
| Racine `$BASE_DN` | `dcObject`, `organization`, `top` — ancrage du domaine |
| `ou=people,$BASE_DN` | Utilisateurs (personnes) |
| `ou=groups,$BASE_DN` | Groupes |

Le projet ajoute en outre des **comptes exemple** (`uid=thomas`, `uid=john`) et des **groupes** (`cn=admin_ldap`, `cn=developers`) pour les parties « rôles / ACL » et « intégration Linux ».

**NOTA :** on peut aussi modéliser des **OU dédiées** (par exemple `ou=roles`, `ou=admin`) pour séparer encore mieux les types d’entrées. Ce dépôt regroupe les groupes d’administration et fonctionnels sous **`ou=groups`**, ce qui respecte l’exigence d’une OU pour les groupes dans **`INSTRUCTIONS.md`** et reste simple pour NSS/PAM.

---

## 4. Peuplement : principe du LDIF unique puis affinages

Le script génère un fichier **`/tmp/dit.ldif`** contenant, dans l’ordre :

1. la **racine** du domaine ;
2. les **OU** `people` et `groups` ;
3. les **groupes** en `groupOfNames` avec un membre factice `cn=dummy,$BASE_DN` (astuce classique : `groupOfNames` impose au moins un `member`) ;
4. les **utilisateurs** `inetOrgPerson` avec `userPassword` haché via `slappasswd`.

L’application se fait par **`ldapadd`** en liaison simple sur **`cn=admin,$BASE_DN`**, **si** la recherche en base du suffixe échoue encore (idempotence partielle : ne pas recréer le DIT s’il existe déjà).

Ensuite, des **`ldapmodify`** retirent le membre `dummy` et ajoutent les vrais membres (`thomas` dans `admin_ldap`, `john` dans `developers`).

Exemple de lecture conceptuelle du LDIF racine (schéma, les valeurs suivent vos variables) :

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
```

---

## 5. Vérifications

Avec **`ldapsearch`**, on contrôle que le suffixe et les OU répondent :

```bash
ldapsearch -x -H ldap://localhost:389 \
  -D "cn=admin,dc=example,dc=org" -w "$LDAP_ADMIN_PASSWORD" \
  -b "dc=example,dc=org" -s base dn

ldapsearch -x -H ldap://localhost:389 \
  -D "cn=admin,dc=example,dc=org" -w "$LDAP_ADMIN_PASSWORD" \
  -b "ou=people,dc=example,dc=org" -s one dn
```

Un résultat **« No such object »** sur le suffixe avant peuplement est attendu ; après exécution des scripts d’init, les entrées doivent apparaître.

---

## 6. Justification de la structure (exigence du TP)

**`INSTRUCTIONS.md`** demande de **justifier** la structure (besoins, évolution). Pistes de contenu, cohérentes avec ce dépôt :

- **Séparation** `people` / `groups` : habituelle, compatible clients LDAP et intégration POSIX.
- **Suffixe** : aligné sur un domaine logique (`example.org` en démo, à remplacer par votre entité).
- **Évolution** : possibilité d’ajouter `ou=services`, `ou=roles`, ou des sous-OU par site sans changer le suffixe.

---

## 7. Synthèse de la partie 2

| Attendu | Réalisation |
|---------|-------------|
| Base DN défini | Oui (env + compose) |
| `ou=people`, `ou=groups` | Oui |
| Données initiales via LDIF | Oui (générés dans `init_ldap.sh`) |
| Justification écrite | À produire dans la synthèse du TP (texte séparé ou section README selon les consignes de rendu) |

**Pistes de finalisation** : joindre un extrait d’export réel (`ldapsearch -LLL …`) pour audit ; ajouter des OU supplémentaires si un cahier des charges ou une extension du scénario l’exige.

---

**Fin du chapitre 2 / 5** — La suite logique est la *Partie 3 — Discrétisation des rôles et ACL* : groupes fonctionnels, délégation et règles `olcAccess` sur la base décrite ici.

*Référence : `INSTRUCTIONS.md` — section « Conception de la structure DIT ».*
