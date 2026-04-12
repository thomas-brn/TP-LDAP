#!/usr/bin/env bash
# Script d'initialisation de l'intégration LDAP-Linux
# Ce script configure PAM, SSSD et NSS pour l'authentification LDAP

# Variables d'environnement
BASE_DN=${LDAP_BASE_DN:-"dc=example,dc=org"}
DOMAIN=${LDAP_DOMAIN:-"example.org"}
ADMIN_PASS=${LDAP_ADMIN_PASSWORD:-"admin"}

if [ "${LDAP_SERVICE_ROLE:-provider}" = "consumer" ]; then
  echo "[init_ldap_linux] Ignoré sur réplica (LDAP_SERVICE_ROLE=consumer)."
  exit 0
fi

<<<<<<< HEAD
if [ "${LDAP_SERVICE_ROLE:-provider}" = "meta" ]; then
  echo "[init_ldap_linux] Ignoré sur méta-annuaire (LDAP_SERVICE_ROLE=meta)."
  exit 0
fi

=======
>>>>>>> a9ae0b6 (keycloak et replication)
echo "[init_ldap_linux] Début de la configuration de l'intégration LDAP-Linux..."

# Attendre que slapd soit prêt
for i in {1..30}; do
  if ldapwhoami -H ldapi:/// -Y EXTERNAL >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# Configuration de NSS (Name Service Switch)
echo "[init_ldap_linux] Configuration de NSS..."
cat > /etc/nsswitch.conf <<EOF
# /etc/nsswitch.conf
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
EOF

# Configuration de libnss-ldap
echo "[init_ldap_linux] Configuration de libnss-ldap..."
cat > /etc/ldap/ldap.conf <<EOF
# Configuration LDAP pour NSS
BASE $BASE_DN
URI ldap://localhost:389
TLS_REQCERT never
EOF

# Configuration de PAM pour LDAP
echo "[init_ldap_linux] Configuration de PAM..."
cat > /etc/pam.d/common-auth <<EOF
# Configuration PAM pour l'authentification LDAP
auth    sufficient      pam_ldap.so
auth    sufficient      pam_unix.so nullok_secure use_first_pass
auth    required        pam_deny.so
EOF

cat > /etc/pam.d/common-account <<EOF
# Configuration PAM pour la gestion des comptes
account sufficient      pam_ldap.so
account sufficient      pam_unix.so
account required        pam_deny.so
EOF

cat > /etc/pam.d/common-password <<EOF
# Configuration PAM pour les mots de passe
password        sufficient      pam_ldap.so
password        sufficient      pam_unix.so nullok obscure min=4 max=8 md5
password        required        pam_deny.so
EOF

cat > /etc/pam.d/common-session <<EOF
# Configuration PAM pour les sessions
session required        pam_mkhomedir.so skel=/etc/skel umask=0022
session sufficient      pam_ldap.so
session sufficient      pam_unix.so
session required        pam_deny.so
EOF

# Configuration de nslcd (plus simple et fiable que SSSD dans un conteneur)
echo "[init_ldap_linux] Configuration de nslcd..."
cat > /etc/nslcd.conf <<EOF
# Configuration nslcd pour LDAP
uri ldap://localhost:389
base $BASE_DN
ldap_version 3
binddn cn=admin,$BASE_DN
bindpw $ADMIN_PASS
filter passwd (objectClass=posixAccount)
filter group (objectClass=posixGroup)
filter shadow (objectClass=shadowAccount)
map passwd homeDirectory homeDirectory
map passwd uidNumber uidNumber
map passwd gidNumber gidNumber
map passwd loginShell loginShell
map passwd gecos gecos
map group gidNumber gidNumber
map group memberUid memberUid
EOF

# Permissions pour nslcd
chmod 600 /etc/nslcd.conf
chown root:root /etc/nslcd.conf

# Configuration de libpam-ldap
echo "[init_ldap_linux] Configuration de libpam-ldap..."
cat > /etc/ldap.conf <<EOF
# Configuration pour libpam-ldap
base $BASE_DN
uri ldap://localhost:389
ldap_version 3
rootbinddn cn=admin,$BASE_DN
binddn cn=admin,$BASE_DN
bindpw $ADMIN_PASS
pam_password crypt
nss_base_passwd ou=people,$BASE_DN
nss_base_shadow ou=people,$BASE_DN
nss_base_group ou=groups,$BASE_DN
nss_map_objectclass posixAccount user
nss_map_objectclass shadowAccount user
nss_map_objectclass posixGroup group
nss_map_attribute uid sAMAccountName
nss_map_attribute homeDirectory unixHomeDirectory
nss_map_attribute shadowLastChange pwdLastSet
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
EOF

# Ajout des attributs POSIX aux utilisateurs LDAP
echo "[init_ldap_linux] Ajout des attributs POSIX aux utilisateurs..."
cat > /tmp/add_posix_attrs.ldif <<EOF
dn: uid=thomas,ou=people,$BASE_DN
changetype: modify
add: objectClass
objectClass: posixAccount
objectClass: shadowAccount
-
add: uidNumber
uidNumber: 1001
-
add: gidNumber
gidNumber: 1001
-
add: homeDirectory
homeDirectory: /home/thomas
-
add: loginShell
loginShell: /bin/bash
-
add: gecos
gecos: Thomas Thomas

dn: uid=john,ou=people,$BASE_DN
changetype: modify
add: objectClass
objectClass: posixAccount
objectClass: shadowAccount
-
add: uidNumber
uidNumber: 1002
-
add: gidNumber
gidNumber: 1002
-
add: homeDirectory
homeDirectory: /home/john
-
add: loginShell
loginShell: /bin/bash
-
add: gecos
gecos: John John
EOF

ldapmodify -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -f /tmp/add_posix_attrs.ldif || echo "[init_ldap_linux] Erreur lors de l'ajout des attributs POSIX"

# Conversion des groupes de groupOfNames à posixGroup
echo "[init_ldap_linux] Conversion des groupes en posixGroup..."
# Vérifier d'abord si les groupes existent et ont des membres
# Supprimer d'abord les membres existants (s'ils existent)
cat > /tmp/convert_groups_to_posix.ldif <<EOF
dn: cn=admin_ldap,ou=groups,$BASE_DN
changetype: modify
delete: objectClass
objectClass: groupOfNames
-
delete: member
EOF

# Ajouter les membres s'ils existent
if ldapsearch -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -b "cn=admin_ldap,ou=groups,$BASE_DN" "(member=*)" member 2>/dev/null | grep -q "member:"; then
    # Supprimer tous les membres existants
    ldapsearch -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -b "cn=admin_ldap,ou=groups,$BASE_DN" "(member=*)" member 2>/dev/null | grep "^member:" | sed 's/^member: /delete: member\nmember: /' >> /tmp/convert_groups_to_posix.ldif
fi

cat >> /tmp/convert_groups_to_posix.ldif <<EOF
-
add: objectClass
objectClass: posixGroup
-
add: gidNumber
gidNumber: 1001
-
add: memberUid
memberUid: thomas

dn: cn=developers,ou=groups,$BASE_DN
changetype: modify
delete: objectClass
objectClass: groupOfNames
-
delete: member
EOF

if ldapsearch -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -b "cn=developers,ou=groups,$BASE_DN" "(member=*)" member 2>/dev/null | grep -q "member:"; then
    ldapsearch -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -b "cn=developers,ou=groups,$BASE_DN" "(member=*)" member 2>/dev/null | grep "^member:" | sed 's/^member: /delete: member\nmember: /' >> /tmp/convert_groups_to_posix.ldif
fi

cat >> /tmp/convert_groups_to_posix.ldif <<EOF
-
add: objectClass
objectClass: posixGroup
-
add: gidNumber
gidNumber: 1002
-
add: memberUid
memberUid: john
EOF

ldapmodify -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -f /tmp/convert_groups_to_posix.ldif 2>&1 || {
    echo "[init_ldap_linux] Tentative de conversion des groupes..."
    # Si la conversion échoue, essayer une approche plus simple : supprimer et recréer
    echo "[init_ldap_linux] Suppression et recréation des groupes en posixGroup..."
    # Supprimer les groupes existants
    ldapdelete -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" "cn=admin_ldap,ou=groups,$BASE_DN" 2>/dev/null || true
    ldapdelete -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" "cn=developers,ou=groups,$BASE_DN" 2>/dev/null || true
    sleep 1
    # Recréer les groupes en posixGroup
    cat > /tmp/recreate_posix_groups.ldif <<EOF
dn: cn=admin_ldap,ou=groups,$BASE_DN
objectClass: top
objectClass: posixGroup
cn: admin_ldap
gidNumber: 1001
memberUid: thomas

dn: cn=developers,ou=groups,$BASE_DN
objectClass: top
objectClass: posixGroup
cn: developers
gidNumber: 1002
memberUid: john
EOF
    ldapadd -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -f /tmp/recreate_posix_groups.ldif 2>&1 && echo "[init_ldap_linux] Groupes recréés en posixGroup" || echo "[init_ldap_linux] Erreur lors de la recréation des groupes"
}

# Démarrage des services
echo "[init_ldap_linux] Démarrage des services..."
# Démarrer nslcd
service nslcd restart || service nslcd start
# Attendre que nslcd soit prêt
sleep 2
# Redémarrer nscd pour recharger la configuration et vider le cache
service nscd restart || service nscd start
# Vider le cache nscd pour forcer la relecture depuis LDAP
nscd -i passwd 2>/dev/null || true
nscd -i group 2>/dev/null || true
sleep 1

# Test de l'intégration
echo "[init_ldap_linux] Test de l'intégration..."
echo "Test de résolution des utilisateurs:"
getent passwd thomas
getent passwd john

echo "Test de résolution des groupes:"
getent group admin_ldap
getent group developers

echo "[init_ldap_linux] Configuration de l'intégration LDAP-Linux terminée."

