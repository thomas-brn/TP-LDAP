# TP LDAP — Partie 5 : Intégration Keycloak (OpenID)

> **Usage** : ce fichier est un **chapitre autonome** du rapport (copier-coller tel quel).  
> **Chapitre** : 5 / 5 — *Intégration Keycloak (OpenID)* (`INSTRUCTIONS.md`, même intitulé).  
> **Prérequis** : *Parties 1 à 4* — annuaire **LDAP** joignable (port **389**), **DIT** sous `ou=people` / `ou=groups`, comptes **`thomas`** / **`john`** utilisables pour un bind ; intégration Linux optionnelle pour le fond « système », mais Keycloak consomme surtout l’**API LDAP** du service **`ldap`**.  
> **Convention dépôt** : aujourd’hui **aucun** service Keycloak dans **`projet/docker-compose.yml`** ; ce chapitre décrit l’**état cible** et les **travaux restants**. Pour l’URL LDAP vue depuis un futur conteneur Keycloak : typiquement **`ldap://ldap:389`** sur un réseau Docker commun avec le service `ldap`.  
> **Chapitre précédent** : *Partie 4 — Intégration Linux (PAM / NSS)*.  
> **Chapitre suivant** : aucun (fin de la série 1–5).

Ce document couvre la **fédération de l’annuaire LDAP avec Keycloak** (OpenID), comme demandé dans **`INSTRUCTIONS.md`** (section « Intégration Keycloak (OpenID) »). Il explique **l’état actuel du dépôt** : cette brique est **décrite par le sujet** mais **pas encore livrée** dans le dépôt (pas de service Keycloak dans Compose). Les sections suivantes décrivent **ce qui est déjà prêt côté LDAP**, **ce qu’il reste à implémenter**, et **comment valider** une fois Keycloak ajouté. La documentation produite par le projet **Keycloak** (site officiel) complète les détails d’administration de l’IdP.

---

## 1. Ce que demandent les instructions

D’après `INSTRUCTIONS.md`, il faut :

1. **Déployer Keycloak** (conteneur Docker) ;
2. **Configurer un User Federation LDAP** dans Keycloak ;
3. **Tester** :
   - synchronisation des utilisateurs LDAP vers Keycloak ;
   - authentification OIDC via Keycloak avec des comptes LDAP ;
   - gestion des rôles **dans Keycloak** de manière séparée de l’annuaire.

Les instructions mentionnent aussi, dans la partie ACL, le groupe **`admin_keycloak`** pour la gestion des rôles Keycloak **« si applicable »** : il devient applicable **dès lors que** Keycloak est en place.

---

## 2. État du projet au moment de la rédaction

| Élément | Statut |
|---------|--------|
| Service **Keycloak** dans `projet/docker-compose.yml` | Absent |
| **User Federation** LDAP | Non configuré |
| **Tests** d’intégration Keycloak | Non présents dans la suite `projet/test/test_*.sh` |
| **Groupe LDAP `admin_keycloak`** | Non créé dans `init_ldap.sh` |

En revanche, **l’annuaire OpenLDAP** déployé par le projet est déjà exploitable comme **fournisseur d’identité** classique :

- écoute **LDAP** sur le port **389** ;
- utilisateurs sous **`ou=people`** avec attributs adaptés au bind (mot de passe, DN stables) ;
- schéma et données **cohérents** pour une importation type « LDAP federation » (Keycloak interroge l’annuaire, mappe `uid`, `mail`, etc.).

**NOTA :** pour que Keycloak (conteneur séparé) joigne LDAP, il faudra soit un **réseau Docker commun**, soit exposer correctement le hostname résolu par Keycloak (`ldap` comme nom de service compose, ou IP du conteneur).

---

## 3. Plan de mise en œuvre (implémentation à réaliser)

### 3.1. Déploiement Keycloak

- Ajouter un **service** `keycloak` dans `projet/docker-compose.yml` (image officielle Quarkus-based, variables `KEYCLOAK_ADMIN`, `KEYCLOAK_ADMIN_PASSWORD`, etc.).
- Placer Keycloak sur le **même réseau** compose que `ldap` pour utiliser `ldap://ldap:389` comme URL côté fédération.

### 3.2. User Federation

Dans la console d’administration Keycloak :

- créer un **realm** (ou utiliser `master` en démo seulement) ;
- ajouter un fournisseur **LDAP** ;
- renseigner : **bind DN** (souvent `cn=admin,dc=example,dc=org` en démo — à remplacer par un compte **dédié** si vous durcissez l’annuaire), **bind credential**, **users DN** (`ou=people,...`), filtres éventuels ;
- lancer une **synchronisation** (import ou periodic sync selon les options).

### 3.3. Authentification et rôles

- Tester un **login** sur une **client application** ou via l’interface compte avec un utilisateur **purement LDAP** (`thomas` / `john`).
- Créer des **rôles realm** ou **client roles** dans Keycloak et les attribuer **sans** les dupliquer dans LDAP (comme demandé : rôles gérés **séparément** dans Keycloak).
- Si vous suivez l’énoncé strict : créer le groupe **`admin_keycloak`** dans LDAP et documenter à quoi il sert côté procédure (qui administre Keycloak), même si l’application fine des droits se fait surtout dans la console Keycloak.

---

## 4. Vérifications prévues (check-list)

À cocher lors de la validation du TP ; conserver captures d’écran ou sorties terminal pour la preuve :

```text
[ ] (dans `projet/`) docker compose ps  →  ldap UP, keycloak UP
[ ] Keycloak : LDAP provider « Test connection » OK
[ ] Keycloak : synchronisation utilisateurs → thomas / john visibles
[ ] Login OIDC (ou formulaire Keycloak) avec thomas / mot de passe LDAP
[ ] Rôle Keycloak attribué à thomas, visible dans le token ou l’interface
[ ] (Optionnel) Groupe admin_keycloak créé et décrit dans la doc
```

---

## 5. Synthèse de la partie 5

| Attendu | Réalisation actuelle |
|---------|----------------------|
| Keycloak en Docker | À faire |
| User Federation LDAP | À faire |
| Tests sync + auth + rôles | À faire |
| `admin_keycloak` | À faire avec Keycloak |

**Ce qui est déjà « prêt » pour enchaîner** : annuaire LDAP opérationnel, schéma utilisateur, mots de passe, structure `people` / `groups`, réseau Docker à étendre.

---

**Fin du chapitre 5 / 5** — Fin de la série « parties 1 à 5 » alignée sur **`INSTRUCTIONS.md`** (jusqu’à Keycloak inclus). Les sujets **réplication** et **méta-annuaire** figurent plus loin dans les mêmes instructions et peuvent constituer des chapitres supplémentaires hors de cette série.

*Référence : `INSTRUCTIONS.md` — section « Intégration Keycloak (OpenID) ». À mettre à jour après ajout du service Keycloak et des tests associés.*
