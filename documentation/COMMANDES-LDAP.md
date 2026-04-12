# 🔧 Commandes LDAP pratiques

## Table des matières
1. [Introduction](#introduction)
2. [Commandes de base](#commandes-de-base)
3. [Recherche et consultation](#recherche-et-consultation)
4. [Gestion des groupes](#gestion-des-groupes)
5. [Gestion des permissions](#gestion-des-permissions)
6. [Filtres de recherche](#filtres-de-recherche)
7. [Format LDIF](#format-ldif)
8. [Scripts d'automatisation](#scripts-dautomatisation)
9. [Bonnes pratiques](#bonnes-pratiques)

---

## Introduction

Ce guide présente les **commandes LDAP essentielles** pour administrer un serveur OpenLDAP. Ces outils sont indispensables pour :

- **Administrer** l'annuaire LDAP
- **Tester** la configuration
- **Déboguer** les problèmes
- **Automatiser** les tâches via scripts

### Configuration de base

Pour ce guide, nous utilisons la configuration suivante :
- **Serveur** : `ldap://localhost:389`
- **Base DN** : `dc=example,dc=org`
- **Admin** : `cn=admin,dc=example,dc=org`
- **Mot de passe** : `admin`

---

## Commandes de base

### 1. **ldapsearch** - Recherche dans l'annuaire

**Rôle :** Rechercher et lire des entrées dans l'annuaire LDAP.

**Syntaxe de base :**
```bash
ldapsearch [options] [filtre] [attributs]
```

**Options principales :**
- `-H <URI>` : URI du serveur LDAP
- `-D <binddn>` : DN pour l'authentification
- `-w <password>` : Mot de passe
- `-x` : Authentification simple (sans SASL)
- `-b <base>` : Base de recherche
- `-s <scope>` : Portée (base, one, sub)

**Exemples pratiques :**

```bash
# Recherche de base - lister la racine
ldapsearch -x -H ldap://localhost:389 -b dc=example,dc=org -s base dn

# Recherche de tous les utilisateurs
ldapsearch -x -H ldap://localhost:389 -b ou=people,dc=example,dc=org "(objectClass=inetOrgPerson)"

# Recherche avec authentification
ldapsearch -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin -b dc=example,dc=org

# Recherche d'un utilisateur spécifique
ldapsearch -x -H ldap://localhost:389 -b dc=example,dc=org "(uid=testuser)"

# Recherche avec attributs spécifiques
ldapsearch -x -H ldap://localhost:389 -b dc=example,dc=org "(objectClass=groupOfNames)" cn member
```

### 2. **ldapadd** - Ajout d'entrées

**Rôle :** Ajouter de nouvelles entrées dans l'annuaire.

**Syntaxe :**
```bash
ldapadd [options] -f <fichier.ldif>
```

**Exemples :**

```bash
# Ajout d'un utilisateur
ldapadd -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin -f user.ldif

# Ajout d'un groupe
ldapadd -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin -f group.ldif

# Ajout via stdin
echo "dn: uid=newuser,ou=people,dc=example,dc=org
objectClass: inetOrgPerson
cn: New User
sn: User
uid: newuser" | ldapadd -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin
```

### 3. **ldapmodify** - Modification d'entrées

**Rôle :** Modifier des entrées existantes dans l'annuaire.

**Syntaxe :**
```bash
ldapmodify [options] -f <fichier.ldif>
```

**Exemples :**

```bash
# Modification d'un attribut
ldapmodify -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin <<EOF
dn: uid=testuser,ou=people,dc=example,dc=org
changetype: modify
replace: mail
mail: newemail@example.org
EOF

# Ajout d'un attribut
ldapmodify -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin <<EOF
dn: uid=testuser,ou=people,dc=example,dc=org
changetype: modify
add: telephoneNumber
telephoneNumber: +33123456789
EOF

# Suppression d'un attribut
ldapmodify -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin <<EOF
dn: uid=testuser,ou=people,dc=example,dc=org
changetype: modify
delete: telephoneNumber
EOF
```

### 4. **ldapdelete** - Suppression d'entrées

**Rôle :** Supprimer des entrées de l'annuaire.

**Syntaxe :**
```bash
ldapdelete [options] <dn>
```

**Exemples :**

```bash
# Suppression d'un utilisateur
ldapdelete -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin "uid=testuser,ou=people,dc=example,dc=org"

# Suppression d'un groupe
ldapdelete -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin "cn=testgroup,ou=groups,dc=example,dc=org"
```

### 5. **ldapwhoami** - Test d'authentification

**Rôle :** Tester l'authentification et vérifier l'identité.

**Syntaxe :**
```bash
ldapwhoami [options]
```

**Exemples :**

```bash
# Test d'authentification simple
ldapwhoami -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin

# Test d'authentification anonyme
ldapwhoami -x -H ldap://localhost:389

# Test avec authentification SASL
ldapwhoami -H ldapi:/// -Y EXTERNAL
```

### 6. **ldappasswd** - Changement de mot de passe

**Rôle :** Modifier les mots de passe des utilisateurs.

**Syntaxe :**
```bash
ldappasswd [options] <dn>
```

**Exemples :**

```bash
# Changement de mot de passe (interactif)
ldappasswd -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin -S "uid=testuser,ou=people,dc=example,dc=org"

# Changement de mot de passe (non-interactif)
ldappasswd -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin -s newpassword "uid=testuser,ou=people,dc=example,dc=org"

# Un utilisateur change son propre mot de passe
ldappasswd -x -H ldap://localhost:389 -D "uid=testuser,ou=people,dc=example,dc=org" -w oldpassword -s newpassword
```

---

## Recherche et consultation

### Commandes de diagnostic

```bash
# Test de connexion de base
ldapwhoami -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin

# Test de la base DN
ldapsearch -x -H ldap://localhost:389 -b dc=example,dc=org -s base dn

# Lister toute la structure
ldapsearch -x -H ldap://localhost:389 -b dc=example,dc=org -s sub dn

# Comptage des entrées
ldapsearch -x -H ldap://localhost:389 -b dc=example,dc=org "(objectClass=*)" dn | grep -c "^dn:"
```

### Recherche d'utilisateurs

```bash
# Tous les utilisateurs
ldapsearch -x -H ldap://localhost:389 -b ou=people,dc=example,dc=org "(objectClass=inetOrgPerson)"

# Utilisateurs avec email
ldapsearch -x -H ldap://localhost:389 -b ou=people,dc=example,dc=org "(&(objectClass=inetOrgPerson)(mail=*))"

# Recherche par nom
ldapsearch -x -H ldap://localhost:389 -b ou=people,dc=example,dc=org "(cn=*john*)"

# Recherche par UID
ldapsearch -x -H ldap://localhost:389 -b ou=people,dc=example,dc=org "(uid=testuser)"
```

---

## Gestion des groupes

### Voir tous les groupes

```bash
# Lister tous les groupes
ldapsearch -x -H ldap://localhost:389 -b ou=groups,dc=example,dc=org "(objectClass=groupOfNames)"

# Lister les groupes avec leurs membres
ldapsearch -x -H ldap://localhost:389 -b ou=groups,dc=example,dc=org "(objectClass=groupOfNames)" cn member

# Lister seulement les noms des groupes
ldapsearch -x -H ldap://localhost:389 -b ou=groups,dc=example,dc=org "(objectClass=groupOfNames)" cn

# Compter le nombre de groupes
ldapsearch -x -H ldap://localhost:389 -b ou=groups,dc=example,dc=org "(objectClass=groupOfNames)" dn | grep -c "^dn:"
```

### Gestion des membres de groupes

```bash
# Voir les membres d'un groupe spécifique
ldapsearch -x -H ldap://localhost:389 -b "cn=admin_ldap,ou=groups,dc=example,dc=org" "(objectClass=groupOfNames)" member

# Voir les groupes d'un utilisateur
ldapsearch -x -H ldap://localhost:389 -b ou=groups,dc=example,dc=org "(&(objectClass=groupOfNames)(member=uid=testuser,ou=people,dc=example,dc=org))"

# Ajouter un membre à un groupe
ldapmodify -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin <<EOF
dn: cn=admin_ldap,ou=groups,dc=example,dc=org
changetype: modify
add: member
member: uid=newuser,ou=people,dc=example,dc=org
EOF

# Supprimer un membre d'un groupe
ldapmodify -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin <<EOF
dn: cn=admin_ldap,ou=groups,dc=example,dc=org
changetype: modify
delete: member
member: uid=olduser,ou=people,dc=example,dc=org
EOF
```

### Création et suppression de groupes

```bash
# Créer un nouveau groupe
ldapadd -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin <<EOF
dn: cn=developers,ou=groups,dc=example,dc=org
objectClass: top
objectClass: groupOfNames
cn: developers
member: cn=dummy,dc=example,dc=org
EOF

# Supprimer un groupe
ldapdelete -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin "cn=developers,ou=groups,dc=example,dc=org"
```

---

## Gestion des permissions

### Voir les ACL (Access Control Lists)

```bash
# Voir toutes les ACL de la base de données
ldapsearch -x -H ldapi:/// -Y EXTERNAL -b "olcDatabase={2}mdb,cn=config" "(objectClass=olcDatabaseConfig)" olcAccess

# Voir les ACL spécifiques
ldapsearch -x -H ldapi:/// -Y EXTERNAL -b "olcDatabase={2}mdb,cn=config" "(objectClass=olcDatabaseConfig)" olcAccess -LLL

# Lister toutes les ACL du serveur
ldapsearch -x -H ldapi:/// -Y EXTERNAL -b "cn=config" "(objectClass=olcAccess)" olcAccess
```

### Voir les permissions d'un utilisateur

```bash
# Tester les permissions de lecture
ldapsearch -x -H ldap://localhost:389 -D "uid=testuser,ou=people,dc=example,dc=org" -w testuser -b dc=example,dc=org -s base dn

# Tester les permissions d'écriture (modification de son propre profil)
ldapmodify -x -H ldap://localhost:389 -D "uid=testuser,ou=people,dc=example,dc=org" -w testuser <<EOF
dn: uid=testuser,ou=people,dc=example,dc=org
changetype: modify
replace: description
description: Test de permission
EOF

# Voir les permissions d'un groupe
ldapsearch -x -H ldap://localhost:389 -D "uid=alice,ou=people,dc=example,dc=org" -w alice -b dc=example,dc=org -s base dn
```

### Diagnostic des permissions

```bash
# Script de diagnostic des permissions
#!/bin/bash
echo "=== Diagnostic des permissions LDAP ==="

# Test de connexion admin
echo "1. Test admin..."
ldapwhoami -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin

# Test de connexion utilisateur
echo "2. Test utilisateur..."
ldapwhoami -x -H ldap://localhost:389 -D "uid=testuser,ou=people,dc=example,dc=org" -w testuser

# Test de lecture pour utilisateur
echo "3. Test lecture utilisateur..."
ldapsearch -x -H ldap://localhost:389 -D "uid=testuser,ou=people,dc=example,dc=org" -w testuser -b dc=example,dc=org -s base dn

# Test de lecture pour admin
echo "4. Test lecture admin..."
ldapsearch -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin -b dc=example,dc=org -s base dn

echo "=== Diagnostic terminé ==="
```

### Voir la configuration des ACL

```bash
# Voir la configuration complète des ACL
ldapsearch -x -H ldapi:/// -Y EXTERNAL -b "olcDatabase={2}mdb,cn=config" "(objectClass=olcDatabaseConfig)" olcAccess -LLL

# Voir les ACL par numéro d'ordre
ldapsearch -x -H ldapi:/// -Y EXTERNAL -b "olcDatabase={2}mdb,cn=config" "(objectClass=olcDatabaseConfig)" olcAccess | grep "olcAccess:"

# Voir les ACL pour les mots de passe
ldapsearch -x -H ldapi:/// -Y EXTERNAL -b "olcDatabase={2}mdb,cn=config" "(objectClass=olcDatabaseConfig)" olcAccess | grep -A5 -B5 "userPassword"
```

---

## Filtres de recherche

### Syntaxe des filtres

```bash
(attribut=opérateur:valeur)
```

### Opérateurs principaux

| Opérateur | Description | Exemple |
|-----------|-------------|---------|
| `=` | Égalité exacte | `(uid=testuser)` |
| `~=` | Approximation | `(cn~=john)` |
| `>=` | Supérieur ou égal | `(uidNumber>=1000)` |
| `<=` | Inférieur ou égal | `(uidNumber<=2000)` |
| `=*` | Présence d'attribut | `(mail=*)` |
| `!` | Négation | `(!(objectClass=groupOfNames))` |

### Opérateurs logiques

```bash
# ET logique
(&(objectClass=inetOrgPerson)(uid=testuser))

# OU logique
(|(objectClass=inetOrgPerson)(objectClass=groupOfNames))

# Combinaison complexe
(&(objectClass=inetOrgPerson)(|(cn=*john*)(cn=*jane*)))
```

### Exemples de filtres pratiques

```bash
# Tous les utilisateurs
"(objectClass=inetOrgPerson)"

# Utilisateurs avec email
"(&(objectClass=inetOrgPerson)(mail=*))"

# Groupes contenant un utilisateur
"(&(objectClass=groupOfNames)(member=uid=testuser,ou=people,dc=example,dc=org))"

# Recherche par nom (approximation)
"(cn~=john)"

# Utilisateurs sans email
"(&(objectClass=inetOrgPerson)(!(mail=*)))"
```

---

## Format LDIF

### Structure d'une entrée LDIF

```ldif
dn: <distinguished-name>
attribut1: valeur1
attribut2: valeur2
attribut3: valeur3
```

### Exemples d'entrées LDIF

**Utilisateur :**
```ldif
dn: uid=john,ou=people,dc=example,dc=org
objectClass: top
objectClass: inetOrgPerson
cn: John Doe
sn: Doe
uid: john
mail: john@example.org
userPassword: {SSHA}hashedpassword
```

**Groupe :**
```ldif
dn: cn=developers,ou=groups,dc=example,dc=org
objectClass: top
objectClass: groupOfNames
cn: developers
member: uid=john,ou=people,dc=example,dc=org
member: uid=jane,ou=people,dc=example,dc=org
```

**Modification :**
```ldif
dn: uid=john,ou=people,dc=example,dc=org
changetype: modify
replace: mail
mail: john.new@example.org
-
add: telephoneNumber
telephoneNumber: +33123456789
```

---

## Scripts d'automatisation

### Script de création d'utilisateur

```bash
#!/bin/bash
# create_user.sh

USERNAME=$1
FULLNAME=$2
EMAIL=$3

if [ -z "$USERNAME" ] || [ -z "$FULLNAME" ] || [ -z "$EMAIL" ]; then
    echo "Usage: $0 <username> <fullname> <email>"
    exit 1
fi

# Création de l'entrée utilisateur
cat <<EOF | ldapadd -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin
dn: uid=$USERNAME,ou=people,dc=example,dc=org
objectClass: top
objectClass: inetOrgPerson
cn: $FULLNAME
sn: ${FULLNAME%% *}
uid: $USERNAME
mail: $EMAIL
userPassword: {SSHA}$(slappasswd -s defaultpassword)
EOF

echo "Utilisateur $USERNAME créé avec succès"
```

### Script de diagnostic complet

```bash
#!/bin/bash
# ldap_diagnostics.sh

echo "=== Diagnostic LDAP complet ==="

# Test de connexion
echo "1. Test de connexion..."
ldapwhoami -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin

# Test de la base
echo "2. Test de la base DN..."
ldapsearch -x -H ldap://localhost:389 -b dc=example,dc=org -s base dn

# Comptage des entrées
echo "3. Comptage des utilisateurs..."
ldapsearch -x -H ldap://localhost:389 -b ou=people,dc=example,dc=org "(objectClass=inetOrgPerson)" dn | grep -c "^dn:"

echo "4. Comptage des groupes..."
ldapsearch -x -H ldap://localhost:389 -b ou=groups,dc=example,dc=org "(objectClass=groupOfNames)" dn | grep -c "^dn:"

# Test des permissions
echo "5. Test des permissions utilisateur..."
ldapwhoami -x -H ldap://localhost:389 -D "uid=testuser,ou=people,dc=example,dc=org" -w testuser

echo "=== Diagnostic terminé ==="
```

### Script de gestion des groupes

```bash
#!/bin/bash
# manage_groups.sh

ACTION=$1
GROUP=$2
USER=$3

case $ACTION in
    "list")
        echo "=== Liste des groupes ==="
        ldapsearch -x -H ldap://localhost:389 -b ou=groups,dc=example,dc=org "(objectClass=groupOfNames)" cn member
        ;;
    "add-member")
        if [ -z "$GROUP" ] || [ -z "$USER" ]; then
            echo "Usage: $0 add-member <group> <user>"
            exit 1
        fi
        ldapmodify -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin <<EOF
dn: cn=$GROUP,ou=groups,dc=example,dc=org
changetype: modify
add: member
member: uid=$USER,ou=people,dc=example,dc=org
EOF
        echo "Utilisateur $USER ajouté au groupe $GROUP"
        ;;
    "remove-member")
        if [ -z "$GROUP" ] || [ -z "$USER" ]; then
            echo "Usage: $0 remove-member <group> <user>"
            exit 1
        fi
        ldapmodify -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin <<EOF
dn: cn=$GROUP,ou=groups,dc=example,dc=org
changetype: modify
delete: member
member: uid=$USER,ou=people,dc=example,dc=org
EOF
        echo "Utilisateur $USER retiré du groupe $GROUP"
        ;;
    *)
        echo "Usage: $0 {list|add-member|remove-member} [group] [user]"
        exit 1
        ;;
esac
```

---

## Bonnes pratiques

### Sécurité

- Utiliser TLS/SSL en production (`ldaps://`)
- Éviter les mots de passe en clair dans les scripts
- Utiliser des variables d'environnement pour les credentials
- Limiter les permissions selon le principe du moindre privilège

### Performance

- Limiter les résultats avec `-z` (limite)
- Utiliser des filtres spécifiques
- Indexer les attributs recherchés
- Éviter les recherches trop larges

### Débogage

- Utiliser `-v` pour plus de verbosité
- Tester avec `ldapwhoami` avant les opérations
- Vérifier les logs du serveur
- Utiliser des scripts de diagnostic

### Scripts

- Valider les paramètres d'entrée
- Gérer les erreurs
- Documenter les scripts
- Utiliser des fonctions réutilisables

---

## Conclusion

Ce guide couvre les commandes LDAP essentielles pour administrer un serveur OpenLDAP. Les commandes présentées permettent de :

- **Gérer** les utilisateurs et groupes
- **Diagnostiquer** les problèmes
- **Automatiser** les tâches d'administration
- **Sécuriser** l'accès à l'annuaire

Ces outils sont indispensables pour une administration efficace de l'annuaire LDAP dans le cadre du projet TP-LDAP.
