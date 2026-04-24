#!/usr/bin/env bash
# LDAP initialization script
# This script configures the mdb database, creates the DIT, and configures ACLs

# Disable stop-on-error to allow continuation
set -uo pipefail

# Expected environment variables:
# - LDAP_BASE_DN
# - LDAP_ORGANISATION
# - LDAP_DOMAIN
# - LDAP_ADMIN_PASSWORD (used for the database rootDN)
# - LDAP_SERVICE_ROLE: provider (default) = full DIT; consumer = mdb + ACL only, data via syncrepl

BASE_DN=${LDAP_BASE_DN:-"dc=polytech,dc=fr"}
ROLE=${LDAP_SERVICE_ROLE:-provider}
ORG=${LDAP_ORGANISATION:-"Polytech"}
DOMAIN=${LDAP_DOMAIN:-"polytech.fr"}
ADMIN_PASS=${LDAP_ADMIN_PASSWORD:-"admin123"}

export LDAPTLS_REQCERT=never # avoid requiring a certificate for local connections

# Wait for slapd to respond (ldapi)
for i in {1..30}; do
  if ldapwhoami -H ldapi:/// -Y EXTERNAL >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if [ "$ROLE" = "meta" ]; then
  echo "[init_ldap] Rôle meta : méta-annuaire (pas de DIT mdb local)."
  bash /container/init_meta_annuaire.sh
  exit $?
fi

# Remove default mdb database and create a new one
echo "[init_ldap] Suppression de la base mdb par défaut..."
ldapmodify -H ldapi:/// -Y EXTERNAL <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: delete
EOF
echo "[init_ldap] Base mdb par défaut supprimée"

# Files under /var/lib/ldap otherwise keep the old suffix (e.g. dc=nodomain) while
# cn=config already points to LDAP_BASE_DN, causing inconsistent syncrepl/slapcat behavior.
echo "[init_ldap] Purge des fichiers mdb et redémarrage de slapd..."
pkill -u openldap -TERM slapd 2>/dev/null || pkill -TERM slapd 2>/dev/null || true
for _ in $(seq 1 40); do
  pgrep slapd >/dev/null 2>&1 || break
  sleep 0.25
done
pkill -u openldap -KILL slapd 2>/dev/null || pkill -KILL slapd 2>/dev/null || true
find /var/lib/ldap -mindepth 1 -delete 2>/dev/null || true
chown openldap:openldap /var/lib/ldap
slapd -h "ldap:/// ldapi:///" -u openldap -g openldap -F /etc/ldap/slapd.d &
for _ in $(seq 1 60); do
  if ldapwhoami -H ldapi:/// -Y EXTERNAL >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# Create a new mdb database with the correct configuration
echo "[init_ldap] Création de la base mdb pour suffix=$BASE_DN..."
HASH=$(slappasswd -s "$ADMIN_PASS")
cat > /tmp/new-db.ldif <<EOF
dn: olcDatabase=mdb,cn=config
objectClass: olcDatabaseConfig
objectClass: olcMdbConfig
olcDatabase: mdb
olcSuffix: $BASE_DN
olcRootDN: cn=admin,$BASE_DN
olcRootPW: $HASH
olcDbDirectory: /var/lib/ldap
olcDbIndex: objectClass eq
olcDbIndex: cn,sn,uid eq
olcDbMaxSize: 1073741824
EOF
ldapadd -H ldapi:/// -Y EXTERNAL -f /tmp/new-db.ldif
echo "[init_ldap] Base mdb créée avec suffix=$BASE_DN"

if [ "$ROLE" = "consumer" ]; then
  echo "[init_ldap] Rôle consumer : pas de création locale du DIT (réplication depuis le fournisseur)."
else
# DIT: base + ou=people + ou=groups + admin_ldap/developers groups + thomas/john users
cat > /tmp/dit.ldif <<EOF
version: 1

dn: $BASE_DN
objectClass: top
objectClass: dcObject
objectClass: organization
o: $ORG
dc: ${DOMAIN%%.*}

dn: ou=people,$BASE_DN
objectClass: top
objectClass: organizationalUnit
ou: people

dn: ou=groups,$BASE_DN
objectClass: top
objectClass: organizationalUnit
ou: groups

dn: cn=admin_ldap,ou=groups,$BASE_DN
objectClass: top
objectClass: groupOfNames
cn: admin_ldap
member: cn=dummy,$BASE_DN

dn: cn=developers,ou=groups,$BASE_DN
objectClass: top
objectClass: groupOfNames
cn: developers
member: cn=dummy,$BASE_DN

dn: cn=admin_keycloak,ou=groups,$BASE_DN
objectClass: top
objectClass: groupOfNames
cn: admin_keycloak
member: cn=dummy,$BASE_DN

dn: uid=thomas,ou=people,$BASE_DN
objectClass: top
objectClass: inetOrgPerson
cn: Thomas
sn: Thomas
uid: thomas
mail: thomas@$DOMAIN
userPassword: $(slappasswd -s thomas123)

dn: uid=john,ou=people,$BASE_DN
objectClass: top
objectClass: inetOrgPerson
cn: John
sn: John
uid: john
mail: john@$DOMAIN
userPassword: $(slappasswd -s john123)
EOF

# Add structure if missing (simple bind with rootDN)
echo "[init_ldap] Vérification de l'existence du DIT..."
if ! ldapsearch -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -b "$BASE_DN" -s base dn >/dev/null 2>&1; then
  echo "[init_ldap] Création DIT de base..."
  ldapadd -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -f /tmp/dit.ldif || echo "[init_ldap] Erreur lors de la création du DIT"
  echo "[init_ldap] DIT créé"
else
  echo "[init_ldap] DIT déjà présent"
fi
echo "[init_ldap] Étape DIT terminée"

# Add thomas to admin_ldap and john to developers
echo "[init_ldap] Ajout de thomas au groupe admin_ldap..."
cat > /tmp/add-thomas-to-admin.ldif <<EOF
dn: cn=admin_ldap,ou=groups,$BASE_DN
changetype: modify
delete: member
member: cn=dummy,$BASE_DN
-
add: member
member: uid=thomas,ou=people,$BASE_DN
EOF
ldapmodify -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -f /tmp/add-thomas-to-admin.ldif || echo "[init_ldap] Erreur lors de l'ajout de thomas au groupe admin_ldap"
echo "[init_ldap] Thomas ajouté au groupe admin_ldap"

echo "[init_ldap] Ajout de john au groupe developers..."
cat > /tmp/add-john-to-developers.ldif <<EOF
dn: cn=developers,ou=groups,$BASE_DN
changetype: modify
delete: member
member: cn=dummy,$BASE_DN
-
add: member
member: uid=john,ou=people,$BASE_DN
EOF
ldapmodify -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -f /tmp/add-john-to-developers.ldif || echo "[init_ldap] Erreur lors de l'ajout de john au groupe developers"
echo "[init_ldap] John ajouté au groupe developers"

echo "[init_ldap] Ajout de thomas au groupe admin_keycloak..."
cat > /tmp/add-thomas-to-admin-keycloak.ldif <<EOF
dn: cn=admin_keycloak,ou=groups,$BASE_DN
changetype: modify
delete: member
member: cn=dummy,$BASE_DN
-
add: member
member: uid=thomas,ou=people,$BASE_DN
EOF
ldapmodify -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -f /tmp/add-thomas-to-admin-keycloak.ldif || echo "[init_ldap] Erreur lors de l'ajout de thomas au groupe admin_keycloak"
echo "[init_ldap] Thomas ajouté au groupe admin_keycloak"

# Attempt to remove a potential cn=admin entry (unlikely to exist)
if ldapsearch -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -b "$BASE_DN" "(cn=admin)" dn | grep -q "^dn: cn=admin,$BASE_DN$"; then
  echo "[init_ldap] Suppression cn=admin pour discrétisation..."
  cat > /tmp/delete-admin.ldif <<EOF
version: 1

dn: cn=admin,$BASE_DN
changetype: delete
EOF
  ldapmodify -x -H ldap:/// -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -f /tmp/delete-admin.ldif || echo "[init_ldap] Erreur lors de la suppression de cn=admin"
fi

fi # end provider role block (DIT)

# Configure baseline ACLs to allow access
echo "[init_ldap] Configuration des ACL de base..."
cat > /tmp/acl-basic.ldif <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: to * by dn.exact=cn=admin,$BASE_DN manage by * read
EOF
ldapmodify -H ldapi:/// -Y EXTERNAL -f /tmp/acl-basic.ldif || echo "[init_ldap] Erreur lors de la configuration des ACL de base"

# Configure advanced ACLs for the admin_ldap group
echo "[init_ldap] Configuration des ACL avancées pour admin_ldap..."
cat > /tmp/acl-advanced.ldif <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: to attrs=userPassword by group.exact=cn=admin_ldap,ou=groups,$BASE_DN write by self write by anonymous auth by * none
olcAccess: to dn.base="" by * read
olcAccess: to * by group.exact=cn=admin_ldap,ou=groups,$BASE_DN manage by self write by users read by * none
EOF
ldapmodify -H ldapi:/// -Y EXTERNAL -f /tmp/acl-advanced.ldif || echo "[init_ldap] Erreur lors de la configuration des ACL avancées"

echo "[init_ldap] Structure DIT et ACL configurées."