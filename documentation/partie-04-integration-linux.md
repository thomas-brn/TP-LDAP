# TP LDAP - Partie 4 : Intégration Linux (PAM / NSS)

## 1. Objectif fonctionnel

Les instructions demandent :

1. **NSS** : résolution des utilisateurs et des groupes depuis LDAP ;
2. **PAM** : authentification contre LDAP ;
3. **Tests** : `getent passwd`, `getent group`, et idéalement `su`, `ssh`, etc.

Dans le projet, la configuration est appliquée par **`projet/scripts/init_ldap_linux_integration.sh`**, lancé **après** `init_ldap.sh` (ordre défini dans `entrypoint.sh`).

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

Le script **`projet/test/test_04_integration_linux.sh`** automatise ces contrôles depuis l’hôte (via `docker exec`) ; la suite **`test_all_implemented.sh`** enchaîne les objectifs **1 à 6** (ordre pédagogique du dépôt).

Pour l’**authentification** (`su`, `ssh`), le comportement dépend du shell, des droits et du fait que `sshd` soit correctement configuré dans l’image. **À prévoir pour finaliser** : un test manuel `docker exec -it ldap su - thomas` ou une connexion SSH depuis l’hôte si le port est publié et sécurisé pour la démo.
