# TP LDAP — Partie 4 : Intégration Linux (PAM / NSS)

> **Usage** : ce fichier est un **chapitre autonome** du rapport (copier-coller tel quel).  
> **Chapitre** : 4 / 5 — *Intégration Linux (PAM/NSS)* (`INSTRUCTIONS.md`, même intitulé).  
> **Prérequis** : *Parties 1 à 3* — annuaire joignable, **DIT** et **ACL** en place ; le script **`projet/scripts/init_ldap_linux_integration.sh`** est exécuté **après** `init_ldap.sh` dans le conteneur (fichier **`20-init_ldap_linux_integration.sh`** dans `/container/init.d/`).  
> **Convention dépôt** : tests `getent` depuis l’hôte avec `docker exec ldap …` ; couverture automatisée dans **`projet/test/test_04_integration_linux.sh`**, et suite complète via **`projet/test/test_all_implemented.sh`**.  
> **Chapitre précédent** : *Partie 3 — Discrétisation des rôles et ACL*.  
> **Chapitre suivant** : *Partie 5 — Intégration Keycloak (OpenID)* (`documentation/partie-05-keycloak.md`).

Ce document décrit la **mise en relation d’un système Linux** (ici : le **même conteneur** que celui qui exécute `slapd`) avec l’annuaire LDAP pour la **résolution des noms** (NSS) et l’**authentification** (PAM). Il correspond à la section « Intégration Linux (PAM/NSS) » de **`INSTRUCTIONS.md`**. Démarche : partir des objectifs de test (`getent`, puis login), configurer **NSS**, **PAM**, le démon de liaison (**nslcd**), puis **vérifier** à chaque étape.

---

## 1. Objectif fonctionnel

Les instructions demandent :

1. **NSS** : résolution des utilisateurs et des groupes depuis LDAP ;
2. **PAM** : authentification contre LDAP ;
3. **Tests** : `getent passwd`, `getent group`, et idéalement `su`, `ssh`, etc.

Dans le projet, la configuration est appliquée par le script **`projet/scripts/init_ldap_linux_integration.sh`**, exécuté **après** `init_ldap.sh` grâce à l’ordre numérique des fichiers dans `/container/init.d/`.

---

## 2. Prérequis côté annuaire : comptes POSIX

Les modules NSS LDAP attendent en général des **`posixAccount`** / **`posixGroup`** (et souvent **`shadowAccount`** pour la couche shadow).

**Problème initial :** les utilisateurs créés dans `init_ldap.sh` sont des **`inetOrgPerson`** sans `uidNumber` / `gidNumber`.

**Solution dans le projet :** le script d’intégration Linux :

1. **ajoute** les objectClasses et attributs POSIX aux utilisateurs `thomas` et `john` ;
2. **convertit** (ou recrée en secours) les groupes `admin_ldap` et `developers` en **`posixGroup`** avec `memberUid` et `gidNumber`.

Sans cette étape, `getent passwd thomas` échouerait malgré un LDAP « correct » pour l’application purement annuaire.

**NOTA :** la conversion `groupOfNames` → `posixGroup` est sensible à l’ordre des opérations LDAP ; le script prévoit une branche de secours (suppression / recréation) si la modification échoue.

---

## 3. Configuration NSS

Le fichier **`/etc/nsswitch.conf`** est réécrit pour interroger **`files`** puis **`ldap`** pour `passwd`, `group` et `shadow`.

Les clients (`libnss-ldap`, **nslcd**) s’appuient sur **`/etc/ldap/ldap.conf`** (URI, BASE) pointant vers **`ldap://localhost:389`** et le suffixe `$BASE_DN`.

---

## 4. Configuration PAM

Les fichiers PAM « communs » (`common-auth`, `common-account`, `common-password`, `common-session`) sont adaptés pour chaîner **`pam_ldap.so`** avec **`pam_unix.so`**, et pour créer le répertoire personnel au besoin (`pam_mkhomedir`).

**NOTA :** dans un conteneur minimal, l’expérience de login peut différer d’une station Debian complète ; l’important pour le TP est de montrer la **chaîne PAM** et sa cohérence avec NSS.

---

## 5. nslcd et cache

Le projet privilégie **nslcd** (avec **`/etc/nslcd.conf`**) pour la résolution NSS → LDAP, avec un **bind** service account sur **`cn=admin`** et des filtres sur `posixAccount` / `posixGroup`.

**nscd** est relancé et le cache invalidé pour forcer la relecture après changement.

---

## 6. Vérifications

Comme demandé dans les instructions, on valide d’abord la **résolution** :

```bash
docker exec ldap getent passwd thomas
docker exec ldap getent passwd john
docker exec ldap getent group admin_ldap
docker exec ldap getent group developers
```

Le script **`projet/test/test_04_integration_linux.sh`** automatise ces contrôles depuis l’hôte (via `docker exec`) ; la suite **`test_all_implemented.sh`** inclut aussi les objectifs 1 à 3.

Pour l’**authentification** (`su`, `ssh`), le comportement dépend du shell, des droits et du fait que `sshd` soit correctement configuré dans l’image. **À prévoir pour finaliser** : un test manuel `docker exec -it ldap su - thomas` ou une connexion SSH depuis l’hôte si le port est publié et sécurisé pour la démo.

---

## 7. Synthèse de la partie 4

| Attendu | Réalisation |
|---------|-------------|
| NSS (passwd / group) | Oui |
| PAM (auth) | Oui |
| `getent passwd` / `getent group` | Oui (+ tests script) |
| `su` / `ssh` | À valider / documenter selon votre environnement |

**Pistes de finalisation** : remplacer le bind **`cn=admin`** dans `nslcd.conf` par un **compte dédié** en lecture seule (alignement avec la *Partie 3*) ; conserver des traces (`journalctl`, logs nslcd) pour la documentation ; joindre une preuve de **`su`** ou de session réussie si le rendu l’exige.

---

**Fin du chapitre 4 / 5** — La suite logique est la *Partie 5 — Intégration Keycloak (OpenID)* : réutilisation du même annuaire comme fournisseur d’identité pour un IdP séparé.

*Référence : `INSTRUCTIONS.md` — section « Intégration Linux (PAM/NSS) ».*
