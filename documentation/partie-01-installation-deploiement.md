# TP LDAP - Partie 1 : Installation et déploiement automatisé

## 1. Recherche de la cible à déployer

Les instructions imposent :

- une base **Debian 12** (image `debian:bookworm-slim` / équivalent `debian:12-slim`) ;
- le serveur **OpenLDAP 2.6** via le paquet `slapd` ;
- les outils clients **`ldap-utils`** ;
- la **conteneurisation Docker** et des **scripts Bash** pour l’automatisation.

Dans le projet, l’équivalent d’une machine Debian dédiée est une **image Docker** construite à partir de **`projet/docker/Dockerfile`**. Pour vérifier la cible logicielle (versions, paquets, ports), on lit ce fichier ainsi que **`projet/docker-compose.yml`** : c’est la source de vérité du déploiement automatisé.

---

## 2. Construction de l’image

L’image part de **`debian:12-slim`**, installe `slapd`, `ldap-utils`, et des dépendances utiles pour la suite du TP (PAM/NSS, `tini`, etc.). Les ports **389** (LDAP) et **636** (LDAPS) sont exposés.

**NOTA :** le mot de passe administrateur de l’annuaire n’est pas figé dans l’image : il est fourni au runtime via la variable d’environnement `LDAP_ADMIN_PASSWORD` (voir compose).

Extrait de principe (lecture du dépôt, pas une copie exhaustive) :

```dockerfile
FROM debian:12-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       slapd ldap-utils …
EXPOSE 389 636
```

---

## 3. Comportement au démarrage du conteneur

Le serveur doit écouter en **LDAP** et exposer une socket **`ldapi`** pour l’administration locale. Le script **`projet/docker/entrypoint.sh`** enchaîne les actions suivantes :

1. garantit l’existence de **`cn=config`** (configuration dynamique sous `/etc/ldap/slapd.d`) si le volume est vide ;
2. démarre **`slapd`** en arrière-plan avec **`ldap:///`** et **`ldapi:///`**, sous l’utilisateur système **`openldap`** ;
3. attend la présence du **socket `ldapi`** (chemin typique `/run/slapd/ldapi`), nécessaire pour les commandes `ldapmodify -Y EXTERNAL` utilisées plus loin ;
4. exécute **dans un ordre fixe** les scripts dans `/container/init.d/` : `init_ldap.sh`, `init_ldap_linux_integration.sh`, `init_replication_provider.sh`, `init_replication_consumer.sh` (définis dans `entrypoint.sh`).

Une fois ces étapes passées, **`slapd`** tourne en arrière-plan : la configuration est **persistée** sous **`cn=config`** et les opérations d’administration locale passent par **`ldapi:///`** avec **SASL EXTERNAL** (voir les scripts dans `projet/scripts/`).

---

## 4. Non-interactivité et maintien du conteneur

Les instructions demandent une configuration **sans intervention manuelle** et un entrypoint basé sur une boucle **`sleep`**.

- L’**installation des paquets** en image évite les invites debconf au premier lancement.
- La **création du suffixe et du DIT** est déléguée à **`projet/scripts/init_ldap.sh`** (voir partie 2 et 3).
- La **boucle infinie** `while true; do sleep infinity; done` maintient le processus principal du conteneur après les init, ce qui est l’équivalent fonctionnel demandé.

---

## 5. Orchestration : un seul `docker compose up`

Le fichier **`projet/docker-compose.yml`** définit le service **`ldap`** :

- **build** avec contexte le répertoire **`projet/`** et `dockerfile: docker/Dockerfile` ;
- **variables d’environnement** : `LDAP_ORGANISATION`, `LDAP_DOMAIN`, `LDAP_BASE_DN`, `LDAP_ADMIN_PASSWORD`, `LDAP_TLS` ;
- **volumes nommés** pour `/var/lib/ldap` et `/etc/ldap/slapd.d` (persistance).

**Vérification côté hôte** (service joignable et suffixe répondant) :

```bash
# Soit depuis projet/ :
cd projet && docker compose up -d --build

# Soit depuis la racine du dépôt (le contexte de build reste projet/) :
# docker compose -f projet/docker-compose.yml up -d --build

docker ps | grep ldap
ldapsearch -x -H ldap://localhost:389 -b "${LDAP_BASE_DN:-dc=example,dc=org}" -s base dn
```

(adaptez `LDAP_BASE_DN` à la valeur définie dans **`projet/docker-compose.yml`**, par défaut `dc=example,dc=org`.)
