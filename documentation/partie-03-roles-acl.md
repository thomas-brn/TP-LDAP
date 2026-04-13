# TP LDAP - Partie 3 : Discrétisation des rôles et ACL

## 1. Groupes et rôles

Les instructions prévoient notamment :

- un groupe **`admin_ldap`** pour l’administration de l’annuaire ;
- des **groupes fonctionnels** selon les besoins ;
- éventuellement **`admin_keycloak`** (traité en partie 5, car lié à Keycloak).

**Dans le projet :**

| Groupe       | DN typique                         | Rôle                                       |
| ------------ | ---------------------------------- | ------------------------------------------ |
| `admin_ldap` | `cn=admin_ldap,ou=groups,$BASE_DN` | Délégation d’administration (ACL `manage`) |
| `developers` | `cn=developers,ou=groups,$BASE_DN` | Groupe fonctionnel exemple                 |

Les membres sont **`uid=thomas`** (admin LDAP) et **`uid=john`** (développeur). Lors de la création initiale, les groupes sont des **`groupOfNames`** avec la contrainte de membre obligatoire ; le script remplace ensuite le membre factice par l’utilisateur réel.

---

## 2. Compte `cn=admin` : distinction importante

Le serveur dispose toujours du **`olcRootDN`** `cn=admin,$BASE_DN` pour la base MDB : c’est le compte **racine LDAP** de la base, distinct des entrées utilisateur.

Les instructions demandent de **ne pas utiliser** `cn=admin` pour l’**administration courante** au profit des rôles. **État du projet :**

- les scripts d’initialisation et, plus loin, **nslcd** utilisent encore **`cn=admin`** pour des opérations techniques ;
- la délégation à **`admin_ldap`** est bien **configurée en ACL** pour que les membres du groupe puissent gérer l’annuaire.

**NOTA :** une entrée **`cn=admin`** sous le suffixe données (confondue avec le RootDN) est peu probable ; le script contient une garde pour tenter de supprimer une telle entrée si elle existait. Le **RootDN** `cn=admin,$BASE_DN` reste nécessaire pour certaines opérations tant que vous ne basculez pas entièrement sur une autre stratégie (compte dédié + ACL uniquement, etc.).

---

## 3. Séquence des ACL (configuration dynamique)

Les règles d’accès sont portées par l’entrée **`olcDatabase={1}mdb,cn=config`**. Elles sont ajoutées par **`ldapmodify -Y EXTERNAL -H ldapi:///`** : depuis le conteneur, le processus d’init s’exécute en conditions permettant d’administrer **`cn=config`** sans mot de passe **RootDN** (mécanisme SASL **EXTERNAL** sur la socket locale).

### 3.1. ACL dites « de base »

Un premier fichier LDIF ajoute une règle du type :

- **`cn=admin`** : droits **`manage`** sur l’ensemble ;
- autres sujets : **`read`** large.

Cela assure un accès de secours pour la phase d’installation ; **du point de vue « moindre privilège »**, c’est discutable et pourra faire l’objet d’un durcissement ultérieur.

### 3.2. ACL « avancées » et groupe `admin_ldap`

Un second ajout définit notamment :

1. Sur **`userPassword`** : écriture pour le groupe **`admin_ldap`**, pour **soi-même** (`self`), authentification anonyme pour le bind, refus pour le reste ;
2. Sur la **racine DSE** `dn.base=""` : lecture pour tous ;
3. Sur **le reste** : **`manage`** pour **`admin_ldap`**, écriture **`self`**, lecture **`users`**, etc.

Schéma d’intention (reformulation pédagogique) : _« Seuls les administrateurs de l’annuaire (groupe) gèrent tout le contenu ; les utilisateurs authentifiés peuvent lire selon la règle ; chacun peut toucher à ce qui le concerne directement (`self`) sur les attributs concernés. »_

---

## 4. Validation manuelle recommandée (refus puis succès)

Pour **valider** le principe du moindre privilège (un compte sans rôle ne doit pas pouvoir tout faire ; un membre de **`admin_ldap`** peut administrer selon les règles), vous pouvez :

1. Vous connecter en **`john`** et tenter un **`ldapadd`** d’un utilisateur test sous `ou=people` : selon les ACL finales, l’opération peut être refusée (comportement attendu pour un non-admin).
2. Répéter avec **`thomas`** (membre de `admin_ldap`) : l’opération peut réussir.

Exemple de commande (adapter mots de passe et DN) :

```bash
# En thomas (membre admin_ldap)
ldapadd -x -H ldap://localhost:389 \
  -D "uid=thomas,ou=people,dc=example,dc=org" -w thomas123 \
  -f /chemin/vers/entree-test.ldif
```

**NOTE :** l’**ordre** et l’**empilement** des directives **`olcAccess`** en OpenLDAP sont déterminants. Avant toute modification manuelle : **lister** les règles actuelles (`ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config`), puis **ajouter** ou **remplacer** avec précaution pour éviter de se couper l’accès.
