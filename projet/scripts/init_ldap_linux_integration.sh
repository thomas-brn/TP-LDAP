#!/usr/bin/env bash
# LDAP-Linux integration initialization script
# This script configures PAM, SSSD, and NSS for LDAP authentication

# Environment variables
BASE_DN=${LDAP_BASE_DN:-"dc=example,dc=org"}
DOMAIN=${LDAP_DOMAIN:-"example.org"}
ADMIN_PASS=${LDAP_ADMIN_PASSWORD:-"admin"}

if [ "${LDAP_SERVICE_ROLE:-provider}" = "consumer" ]; then
  echo "[init_ldap_linux] Ignoré sur réplica (LDAP_SERVICE_ROLE=consumer)."
  exit 0
fi

if [ "${LDAP_SERVICE_ROLE:-provider}" = "meta" ]; then
  echo "[init_ldap_linux] Ignoré sur méta-annuaire (LDAP_SERVICE_ROLE=meta)."
  exit 0
fi

echo "[init_ldap_linux] Début de la configuration de l'intégration LDAP-Linux..."

# Wait until slapd is ready
for i in {1..30}; do
  if ldapwhoami -H ldapi:/// -Y EXTERNAL >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# NSS (Name Service Switch) configuration
echo "[init_ldap_linux] Configuration de NSS..."
cat > /etc/nsswitch.conf <<EOF
# /etc/nsswitch.conf
# LDAP integration configuration

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

# libnss-ldap configuration
echo "[init_ldap_linux] Configuration de libnss-ldap..."
cat > /etc/ldap/ldap.conf <<EOF
# LDAP configuration for NSS
BASE $BASE_DN
URI ldap://localhost:389
TLS_REQCERT never
EOF

# PAM configuration for LDAP
echo "[init_ldap_linux] Configuration de PAM..."
cat > /etc/pam.d/common-auth <<EOF
# PAM configuration for LDAP authentication
auth    sufficient      pam_ldap.so
auth    sufficient      pam_unix.so nullok_secure use_first_pass
auth    required        pam_deny.so
EOF

cat > /etc/pam.d/common-account <<EOF
# PAM configuration for account management
account sufficient      pam_ldap.so
account sufficient      pam_unix.so
account required        pam_deny.so
EOF

cat > /etc/pam.d/common-password <<EOF
# PAM configuration for passwords
password        sufficient      pam_ldap.so
password        sufficient      pam_unix.so nullok obscure min=4 max=8 md5
password        required        pam_deny.so
EOF

cat > /etc/pam.d/common-session <<EOF
# PAM configuration for sessions
session required        pam_mkhomedir.so skel=/etc/skel umask=0022
session sufficient      pam_ldap.so
session sufficient      pam_unix.so
session required        pam_deny.so
EOF

# nslcd configuration (simpler and more reliable than SSSD in a container)
echo "[init_ldap_linux] Configuration de nslcd..."
cat > /etc/nslcd.conf <<EOF
# nslcd configuration for LDAP
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

# Permissions for nslcd
chmod 600 /etc/nslcd.conf
chown root:root /etc/nslcd.conf

# libpam-ldap configuration
echo "[init_ldap_linux] Configuration de libpam-ldap..."
cat > /etc/ldap.conf <<EOF
# Configuration for libpam-ldap
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

# Add POSIX attributes to LDAP users
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

# Convert groups from groupOfNames to posixGroup
echo "[init_ldap_linux] Conversion des groupes en posixGroup..."
# First check whether groups exist and already have members
# First remove existing members (if any)
cat > /tmp/convert_groups_to_posix.ldif <<EOF
dn: cn=admin_ldap,ou=groups,$BASE_DN
changetype: modify
delete: objectClass
objectClass: groupOfNames
-
delete: member
EOF

# Add members if they exist
if ldapsearch -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -b "cn=admin_ldap,ou=groups,$BASE_DN" "(member=*)" member 2>/dev/null | grep -q "member:"; then
    # Remove all existing members
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
    # If conversion fails, try a simpler approach: delete and recreate
    echo "[init_ldap_linux] Suppression et recréation des groupes en posixGroup..."
    # Delete existing groups
    ldapdelete -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" "cn=admin_ldap,ou=groups,$BASE_DN" 2>/dev/null || true
    ldapdelete -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" "cn=developers,ou=groups,$BASE_DN" 2>/dev/null || true
    sleep 1
    # Recreate groups as posixGroup
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

# Start services
echo "[init_ldap_linux] Démarrage des services..."
# Start nslcd
service nslcd restart || service nslcd start
# Wait for nslcd readiness
sleep 2
# Restart nscd to reload configuration and clear cache
service nscd restart || service nscd start
# Clear nscd cache to force LDAP re-read
nscd -i passwd 2>/dev/null || true
nscd -i group 2>/dev/null || true
sleep 1

# Integration check
echo "[init_ldap_linux] Test de l'intégration..."
echo "Test de résolution des utilisateurs:"
getent passwd thomas
getent passwd john

echo "Test de résolution des groupes:"
getent group admin_ldap
getent group developers

echo "[init_ldap_linux] Configuration de l'intégration LDAP-Linux terminée."

