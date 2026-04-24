#!/usr/bin/env bash
# Read-only replica: olcSyncrepl + olcReadOnly (client writes are denied, replication is not).
set -uo pipefail

if [ "${LDAP_SERVICE_ROLE:-provider}" != "consumer" ]; then
  exit 0
fi

BASE_DN=${LDAP_BASE_DN:-dc=example,dc=org}
ADMIN_PASS=${LDAP_ADMIN_PASSWORD:-admin}
PROVIDER_URI=${LDAP_REPLICATION_PROVIDER_URI:-ldap://ldap:389}

for _ in $(seq 1 30); do
  if ldapwhoami -H ldapi:/// -Y EXTERNAL >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "[init_replication_consumer] Attente du fournisseur ${PROVIDER_URI}..."
ready=0
for _ in $(seq 1 90); do
  if ldapsearch -x -H "$PROVIDER_URI" -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -b "$BASE_DN" -s base dn >/dev/null 2>&1 \
    && ldapsearch -x -H "$PROVIDER_URI" -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -b "ou=people,$BASE_DN" -s base dn >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
if [ "$ready" != 1 ]; then
  echo "[init_replication_consumer] AVERTISSEMENT : fournisseur peu joignable ; syncrepl pourrait échouer au démarrage."
fi

if ! ldapsearch -H ldapi:/// -Y EXTERNAL -b cn=config -s base -LLL olcServerID 2>/dev/null | grep -q "^olcServerID: 2"; then
  echo "[init_replication_consumer] olcServerID=2 sur cn=config..."
  ldapmodify -H ldapi:/// -Y EXTERNAL <<'EOF' 2>/dev/null || true
dn: cn=config
changetype: modify
add: olcServerID
olcServerID: 2
EOF
fi

if ldapsearch -H ldapi:/// -Y EXTERNAL -b olcDatabase={1}mdb,cn=config -s base -LLL olcSyncrepl 2>/dev/null | grep -q "^olcSyncrepl:"; then
  echo "[init_replication_consumer] olcSyncrepl déjà configuré."
  exit 0
fi

echo "[init_replication_consumer] Configuration olcSyncrepl + olcReadOnly..."
ldapmodify -H ldapi:/// -Y EXTERNAL <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcReadOnly
olcReadOnly: TRUE
-
add: olcSyncrepl
olcSyncrepl: rid=001 provider=${PROVIDER_URI} bindmethod=simple binddn="cn=admin,${BASE_DN}" credentials=${ADMIN_PASS} searchbase="${BASE_DN}" type=refreshAndPersist retry="60 +" timeout=1 schemachecking=off scope=sub
EOF

echo "[init_replication_consumer] Terminé."
