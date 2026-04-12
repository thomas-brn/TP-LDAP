#!/usr/bin/env bash
# Méta-annuaire OpenLDAP (back-meta) : agrège plusieurs annuaires via suffixmassage.
# Invoqué depuis init_ldap.sh lorsque LDAP_SERVICE_ROLE=meta.
set -euo pipefail

ADMIN_PASS=${LDAP_ADMIN_PASSWORD:-admin}
META_SUFFIX=${LDAP_META_SUFFIX:-o=federation}
META_ROOT_DN="cn=admin,${META_SUFFIX}"

EX_URI=${LDAP_META_EXAMPLE_URI:-ldap://ldap:389}
EX_REAL=${LDAP_META_EXAMPLE_SUFFIX:-dc=example,dc=org}
EX_VIRT=${LDAP_META_EXAMPLE_VIRTUAL:-ou=example-org,o=federation}

AC_URI=${LDAP_META_ACME_URI:-ldap://ldap-acme:389}
AC_REAL=${LDAP_META_ACME_SUFFIX:-dc=acme,dc=com}
AC_VIRT=${LDAP_META_ACME_VIRTUAL:-ou=acme-corp,o=federation}

export LDAPTLS_REQCERT=never

for _ in $(seq 1 30); do
  if ldapwhoami -H ldapi:/// -Y EXTERNAL >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "[init_meta] Suppression de la base mdb par défaut..."
ldapmodify -H ldapi:/// -Y EXTERNAL <<'EOF' || true
dn: olcDatabase={1}mdb,cn=config
changetype: delete
EOF

echo "[init_meta] Purge des fichiers mdb et redémarrage de slapd..."
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

if ! ldapsearch -H ldapi:/// -Y EXTERNAL -b cn=module{0},cn=config -s base -LLL olcModuleLoad 2>/dev/null | grep -qF back_ldap; then
  echo "[init_meta] Chargement des modules back_ldap (requis par back_meta) puis back_meta..."
  ldapmodify -H ldapi:/// -Y EXTERNAL <<'EOF' || true
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: back_ldap.la
-
add: olcModuleLoad
olcModuleLoad: back_meta.la
EOF
fi

HASH=$(slappasswd -s "$ADMIN_PASS")
echo "[init_meta] Création de la base meta (suffix=$META_SUFFIX)..."
ldapadd -H ldapi:/// -Y EXTERNAL <<EOF
dn: olcDatabase=meta,cn=config
objectClass: olcDatabaseConfig
objectClass: olcMetaConfig
olcDatabase: meta
olcSuffix: $META_SUFFIX
olcRootDN: $META_ROOT_DN
olcRootPW: $HASH
olcDbOnErr: continue
olcDbCancel: abandon
olcDbTFSupport: no
olcAccess: to * by dn.exact=$META_ROOT_DN manage by * read
EOF

META_DB_DN=$(ldapsearch -H ldapi:/// -Y EXTERNAL -b cn=config -s one -LLL '(olcDatabase=meta)' dn 2>/dev/null | sed -n 's/^dn: //p' | head -1)
if [ -z "$META_DB_DN" ]; then
  echo "[init_meta] ERREUR : entrée olcDatabase meta introuvable dans cn=config."
  exit 1
fi

# Le namingContext dans olcDbURI doit être un sous-arbre du suffixe meta (olcSuffix), pas le suffixe réel du backend.
echo "[init_meta] Cible meta : $EX_VIRT → $EX_URI + suffixmassage → $EX_REAL"
ldapadd -H ldapi:/// -Y EXTERNAL <<EOF
dn: olcMetaSub={0}example,$META_DB_DN
objectClass: olcConfig
objectClass: olcMetaTargetConfig
olcMetaSub: {0}example
olcDbURI: $EX_URI/$EX_VIRT
olcDbRewrite: {0}suffixmassage "$EX_VIRT" "$EX_REAL"
olcDbIDAssertBind: bindmethod=simple binddn="cn=admin,$EX_REAL" credentials=$ADMIN_PASS
olcDbChaseReferrals: FALSE
EOF

echo "[init_meta] Cible meta : $AC_VIRT → $AC_URI + suffixmassage → $AC_REAL"
ldapadd -H ldapi:/// -Y EXTERNAL <<EOF
dn: olcMetaSub={1}acme,$META_DB_DN
objectClass: olcConfig
objectClass: olcMetaTargetConfig
olcMetaSub: {1}acme
olcDbURI: $AC_URI/$AC_VIRT
olcDbRewrite: {0}suffixmassage "$AC_VIRT" "$AC_REAL"
olcDbIDAssertBind: bindmethod=simple binddn="cn=admin,$AC_REAL" credentials=$ADMIN_PASS
olcDbChaseReferrals: FALSE
EOF

echo "[init_meta] Méta-annuaire configuré ($META_SUFFIX)."
exit 0
