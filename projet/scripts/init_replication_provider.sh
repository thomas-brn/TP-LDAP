#!/usr/bin/env bash
# Replication provider: syncprov overlay + olcServerID (OpenLDAP 2.6).
set -uo pipefail

if [ "${LDAP_SERVICE_ROLE:-provider}" = "consumer" ]; then
  exit 0
fi

if [ "${LDAP_SERVICE_ROLE:-provider}" = "meta" ]; then
  exit 0
fi

for _ in $(seq 1 30); do
  if ldapwhoami -H ldapi:/// -Y EXTERNAL >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ldapsearch -H ldapi:/// -Y EXTERNAL -b cn=config -s sub -LLL '(objectClass=olcSyncProvConfig)' dn 2>/dev/null | grep -q '^dn:'; then
  echo "[init_replication_provider] Overlay syncprov déjà présent."
else
  echo "[init_replication_provider] Chargement module syncprov.la sur cn=module{0}..."
  ldapmodify -H ldapi:/// -Y EXTERNAL <<'EOF' 2>/dev/null || true
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: syncprov.la
EOF
  echo "[init_replication_provider] Ajout overlay syncprov sur mdb {1}..."
  ldapadd -H ldapi:/// -Y EXTERNAL <<'EOF'
dn: olcOverlay=syncprov,olcDatabase={1}mdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov
EOF
fi

if ldapsearch -H ldapi:/// -Y EXTERNAL -b cn=config -s base -LLL olcServerID 2>/dev/null | grep -q "^olcServerID: 1"; then
  echo "[init_replication_provider] olcServerID=1 déjà présent."
else
  echo "[init_replication_provider] Ajout olcServerID=1..."
  ldapmodify -H ldapi:/// -Y EXTERNAL <<'EOF' 2>/dev/null || true
dn: cn=config
changetype: modify
add: olcServerID
olcServerID: 1
EOF
fi

echo "[init_replication_provider] entryUUID index (recommended for syncrepl)..."
ldapmodify -H ldapi:/// -Y EXTERNAL <<'EOF' 2>/dev/null || true
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: entryUUID eq
EOF

echo "[init_replication_provider] Terminé."
