# 🔗 Intégration LDAP-Linux - Guide Complet

## 🎯 Objectif

Ce document explique comment intégrer votre serveur LDAP avec le système d'authentification Linux, permettant aux utilisateurs LDAP de se connecter directement sur le système.

## 📋 Vue d'ensemble

L'intégration LDAP-Linux permet de :
- **Authentifier** les utilisateurs LDAP sur le système Linux
- **Résoudre** les utilisateurs et groupes depuis LDAP
- **Gérer** les permissions basées sur les groupes LDAP
- **Centraliser** la gestion des identités

## 🏗️ Architecture de l'intégration

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │    │   PAM Module    │    │   LDAP Server   │
│   (login, ssh)  │◄──►│   (libpam-ldap) │◄──►│   (OpenLDAP)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   SSSD Service  │
                       │   (Cache + Auth)│
                       └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   NSS Module    │
                       │   (libnss-ldap) │
                       └─────────────────┘
```

## 🔧 Composants techniques

### 1. **PAM (Pluggable Authentication Modules)**
- **Rôle** : Gère l'authentification des utilisateurs
- **Configuration** : `/etc/pam.d/`
- **Modules** : `libpam-ldap`

### 2. **SSSD (System Security Services Daemon)**
- **Rôle** : Cache et synchronisation avec LDAP
- **Configuration** : `/etc/sssd/sssd.conf`
- **Avantages** : Performance, offline support

### 3. **NSS (Name Service Switch)**
- **Rôle** : Résolution des utilisateurs et groupes
- **Configuration** : `/etc/nsswitch.conf`
- **Modules** : `libnss-ldap`

## 🚀 Installation et configuration

### Prérequis
- Serveur LDAP fonctionnel (OpenLDAP 2.6)
- Utilisateurs avec attributs POSIX
- Groupes avec attributs POSIX

### Paquets requis
```bash
# Paquets pour l'intégration LDAP-Linux
libpam-ldap      # Module PAM pour LDAP
libnss-ldap      # Module NSS pour LDAP
sssd-ldap        # Service SSSD pour LDAP
nscd             # Cache des services de noms
sudo             # Pour les tests d'authentification
openssh-server   # Serveur SSH pour les tests
```

## 📝 Configuration détaillée

### 1. Configuration de NSS

**Fichier** : `/etc/nsswitch.conf`

```bash
# Configuration pour l'intégration LDAP
passwd:         files ldap
group:          files ldap
shadow:         files ldap
gshadow:        files

hosts:          files dns
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       ldap
```

**Explication** :
- `files ldap` : Cherche d'abord dans les fichiers locaux, puis dans LDAP
- `ldap` : Utilise uniquement LDAP pour les netgroups

### 2. Configuration de PAM

#### Authentification (`/etc/pam.d/common-auth`)
```bash
auth    sufficient      pam_ldap.so
auth    sufficient      pam_unix.so nullok_secure use_first_pass
auth    required        pam_deny.so
```

#### Gestion des comptes (`/etc/pam.d/common-account`)
```bash
account sufficient      pam_ldap.so
account sufficient      pam_unix.so
account required        pam_deny.so
```

#### Mots de passe (`/etc/pam.d/common-password`)
```bash
password        sufficient      pam_ldap.so
password        sufficient      pam_unix.so nullok obscure min=4 max=8 md5
password        required        pam_deny.so
```

#### Sessions (`/etc/pam.d/common-session`)
```bash
session required        pam_mkhomedir.so skel=/etc/skel umask=0022
session sufficient      pam_ldap.so
session sufficient      pam_unix.so
session required        pam_deny.so
```

### 3. Configuration de SSSD

**Fichier** : `/etc/sssd/sssd.conf`

```ini
[sssd]
config_file_version = 2
services = nss, pam
domains = example.org

[nss]
filter_users = root,ldap,named,avahi,haldaemon,dbus,radiusd,news,nscd

[pam]

[domain/example.org]
id_provider = ldap
auth_provider = ldap
chpass_provider = ldap
ldap_uri = ldap://localhost:389
ldap_search_base = dc=example,dc=org
ldap_user_search_base = ou=people,dc=example,dc=org
ldap_group_search_base = ou=groups,dc=example,dc=org
ldap_user_object_class = inetOrgPerson
ldap_group_object_class = groupOfNames
ldap_user_name = uid
ldap_group_name = cn
ldap_user_member_of = memberOf
ldap_group_member = member
ldap_tls_reqcert = never
cache_credentials = true
enumerate = true
```

### 4. Configuration de libpam-ldap

**Fichier** : `/etc/ldap.conf`

```bash
# Configuration pour libpam-ldap
base dc=example,dc=org
uri ldap://localhost:389
ldap_version 3
rootbinddn cn=admin,dc=example,dc=org
binddn cn=admin,dc=example,dc=org
bindpw admin
pam_password crypt
nss_base_passwd ou=people,dc=example,dc=org
nss_base_shadow ou=people,dc=example,dc=org
nss_base_group ou=groups,dc=example,dc=org
nss_map_objectclass posixAccount user
nss_map_objectclass shadowAccount user
nss_map_objectclass posixGroup group
nss_map_attribute uid sAMAccountName
nss_map_attribute homeDirectory unixHomeDirectory
nss_map_attribute shadowLastChange pwdLastSet
pam_login_attribute uid
pam_member_attribute member
pam_filter objectclass=inetOrgPerson
pam_password exop
```

### 5. Configuration de nslcd (IMPORTANT !)

**Fichier** : `/etc/nslcd.conf`

```bash
# Configuration nslcd pour LDAP
uri ldap://localhost:389
base dc=example,dc=org
ldap_version 3
binddn cn=admin,dc=example,dc=org
bindpw admin
filter passwd (objectClass=posixAccount)
filter group (objectClass=posixGroup)
filter shadow (objectClass=shadowAccount)
map passwd homeDirectory homeDirectory
map passwd uidNumber uidNumber
map passwd gidNumber gidNumber
map passwd loginShell loginShell
map passwd gecos gecos
```

**⚠️ IMPORTANT** : La configuration nslcd est cruciale pour la résolution NSS. Sans cette configuration correcte, `getent passwd` ne fonctionnera pas.

## 👥 Préparation des utilisateurs LDAP

### Attributs POSIX requis

Les utilisateurs LDAP doivent avoir les attributs POSIX suivants :

```ldif
dn: uid=thomas,ou=people,dc=example,dc=org
objectClass: top
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: Thomas
sn: Thomas
uid: thomas
uidNumber: 1001
gidNumber: 1001
homeDirectory: /home/thomas
loginShell: /bin/bash
gecos: Thomas Thomas
mail: thomas@example.org
userPassword: {SSHA}hashedpassword
```

### Attributs POSIX pour les groupes

```ldif
dn: cn=admin_ldap,ou=groups,dc=example,dc=org
objectClass: top
objectClass: groupOfNames
objectClass: posixGroup
cn: admin_ldap
gidNumber: 1001
member: uid=thomas,ou=people,dc=example,dc=org
```

## 🧪 Tests et validation

### 1. Test de résolution des utilisateurs

```bash
# Vérifier la résolution des utilisateurs LDAP
getent passwd thomas
getent passwd john

# Résultat attendu :
# thomas:x:1001:1001:Thomas Thomas:/home/thomas:/bin/bash
# john:x:1002:1002:John John:/home/john:/bin/bash
```

### 2. Test de résolution des groupes

```bash
# Vérifier la résolution des groupes LDAP
getent group admin_ldap
getent group developers

# Résultat attendu :
# admin_ldap:x:1001:thomas
# developers:x:1002:john
```

### 3. Test d'authentification

```bash
# Test d'authentification avec su
su - thomas
# Entrer le mot de passe : thomas123

# Test d'authentification SSH
ssh thomas@localhost
# Entrer le mot de passe : thomas123
```

### 4. Test des permissions

```bash
# Vérifier les groupes d'un utilisateur
id thomas
# Résultat attendu : uid=1001(thomas) gid=1001(admin_ldap) groups=1001(admin_ldap)

# Tester l'accès aux fichiers
ls -la /home/thomas
# Le répertoire home doit être créé automatiquement
```

## 🔍 Diagnostic et dépannage

### 1. Problèmes courants et solutions

#### Problème : "Address already in use" (erreur 98)
**Cause** : Le port LDAP est déjà utilisé par un autre processus slapd.
**Solution** :
```bash
# Vérifier les processus slapd
ps aux | grep slapd

# Arrêter les processus en conflit
pkill slapd

# Redémarrer le service
service slapd restart
```

#### Problème : "thomas non trouvé" avec getent passwd
**Cause** : Configuration nslcd incorrecte ou service non démarré.
**Solution** :
```bash
# Vérifier la configuration nslcd
cat /etc/nslcd.conf | grep base

# Redémarrer nslcd
service nslcd restart

# Tester la résolution
getent passwd thomas
```

#### Problème : "Object class violation" lors de l'ajout d'attributs POSIX
**Cause** : Tentative d'ajout d'object classes déjà présentes.
**Solution** :
```bash
# Vérifier les object classes existantes
ldapsearch -x -H ldap://localhost:389 -b "uid=thomas,ou=people,dc=example,dc=org" objectClass

# Ajouter seulement les attributs manquants
ldapmodify -x -H ldap://localhost:389 -D "cn=admin,dc=example,dc=org" -w admin <<EOF
dn: uid=thomas,ou=people,dc=example,dc=org
changetype: modify
add: uidNumber
uidNumber: 1001
EOF
```

### 2. Vérification des services

```bash
# Vérifier le statut de SSSD
systemctl status sssd

# Vérifier les logs SSSD
tail -f /var/log/sssd/sssd.log

# Vérifier le statut de NSCD
systemctl status nscd

# Vérifier le statut de nslcd
systemctl status nslcd
```

### 2. Tests de connectivité LDAP

```bash
# Test de connexion LDAP
ldapwhoami -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin

# Test de recherche d'utilisateur
ldapsearch -x -H ldap://localhost:389 -b ou=people,dc=example,dc=org "(uid=thomas)"

# Test de recherche de groupe
ldapsearch -x -H ldap://localhost:389 -b ou=groups,dc=example,dc=org "(cn=admin_ldap)"
```

### 3. Diagnostic PAM

```bash
# Test d'authentification avec debug
pam-auth-update --package

# Vérifier la configuration PAM
pam-auth-update --list
```

### 4. Script de diagnostic complet

```bash
#!/bin/bash
# diagnostic_ldap_linux.sh

echo "=== Diagnostic de l'intégration LDAP-Linux ==="

echo "1. Test de résolution des utilisateurs :"
getent passwd thomas
getent passwd john

echo "2. Test de résolution des groupes :"
getent group admin_ldap
getent group developers

echo "3. Test de connectivité LDAP :"
ldapwhoami -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin

echo "4. Test des attributs POSIX :"
ldapsearch -x -H ldap://localhost:389 -b ou=people,dc=example,dc=org "(uid=thomas)" uidNumber gidNumber homeDirectory

echo "5. Test des groupes POSIX :"
ldapsearch -x -H ldap://localhost:389 -b ou=groups,dc=example,dc=org "(cn=admin_ldap)" gidNumber member

echo "=== Diagnostic terminé ==="
```

## 🚀 Utilisation dans Docker

### Construction de l'image

```bash
# À exécuter depuis le répertoire projet/ du dépôt (ou : docker compose -f projet/docker-compose.yml … depuis la racine)
cd projet

# Construire l'image avec l'intégration LDAP-Linux
docker compose build

# Lancer le conteneur
docker compose up -d

# Vérifier les logs d'initialisation
docker logs -f ldap
```

### Tests dans le conteneur

```bash
# Accéder au conteneur
docker exec -it ldap bash

# Tester la résolution des utilisateurs
getent passwd thomas
getent passwd john

# Tester l'authentification
su - thomas
# Mot de passe : thomas123

# Tester SSH
ssh thomas@localhost
# Mot de passe : thomas123
```

## 📚 Commandes utiles

### Gestion des utilisateurs

```bash
# Lister tous les utilisateurs (locaux + LDAP)
getent passwd

# Rechercher un utilisateur spécifique
getent passwd thomas

# Lister les groupes d'un utilisateur
groups thomas

# Vérifier l'ID d'un utilisateur
id thomas
```

### Gestion des groupes

```bash
# Lister tous les groupes (locaux + LDAP)
getent group

# Rechercher un groupe spécifique
getent group admin_ldap

# Lister les membres d'un groupe
getent group developers
```

### Cache et synchronisation

```bash
# Vider le cache NSCD
nscd -i passwd
nscd -i group

# Redémarrer SSSD
systemctl restart sssd

# Vérifier le cache SSSD
sssctl user-checks thomas
sssctl group-checks admin_ldap
```

## 🔒 Sécurité

### Bonnes pratiques

1. **Chiffrement des mots de passe** : Utiliser des algorithmes sécurisés (SSHA, PBKDF2)
2. **TLS/SSL** : Activer le chiffrement des communications LDAP
3. **Permissions** : Limiter les accès selon le principe du moindre privilège
4. **Audit** : Surveiller les tentatives d'authentification

### Configuration sécurisée

```bash
# Configuration TLS pour LDAP
ldap_uri = ldaps://localhost:636
ldap_tls_reqcert = demand
ldap_tls_cacert = /etc/ssl/certs/ca-certificates.crt
```

## 🎯 Cas d'usage avancés

### 1. Authentification SSH avec clés

```bash
# Ajouter une clé SSH à un utilisateur LDAP
ldapmodify -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin <<EOF
dn: uid=thomas,ou=people,dc=example,dc=org
changetype: modify
add: sshPublicKey
sshPublicKey: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC...
EOF
```

### 2. Gestion des sudoers

```bash
# Configuration sudo pour les groupes LDAP
echo "%admin_ldap ALL=(ALL) ALL" >> /etc/sudoers.d/ldap
```

### 3. Synchronisation des mots de passe

```bash
# Changer le mot de passe d'un utilisateur LDAP
ldappasswd -x -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -w admin -s newpassword "uid=thomas,ou=people,dc=example,dc=org"
```

## 📖 Ressources supplémentaires

- [OpenLDAP Administration Guide](https://www.openldap.org/doc/admin26/)
- [PAM Configuration Guide](https://wiki.ubuntu.com/PAMConfig)
- [SSSD Documentation](https://sssd.io/docs/)
- [NSS Configuration](https://man7.org/linux/man-pages/man5/nsswitch.conf.5.html)

## 🎉 Conclusion

L'intégration LDAP-Linux permet de centraliser la gestion des identités et d'authentifier les utilisateurs LDAP directement sur le système Linux. Cette configuration offre :

- **Centralisation** : Gestion unique des utilisateurs dans LDAP
- **Sécurité** : Authentification centralisée et contrôlée
- **Flexibilité** : Support des groupes et permissions
- **Performance** : Cache local avec SSSD

Cette intégration est essentielle pour les environnements d'entreprise où la gestion centralisée des identités est cruciale.
