#!/usr/bin/env bash
# Objective 6 — LDAP replication (RW provider / RO replica)
# Prerequisite: run "docker compose up -d" in projet/ (ldap + ldap-replica).
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/test_common.sh
source "$SCRIPT_DIR/lib/test_common.sh"

PROVIDER_URI="ldap://localhost:389"
REPLICA_URI="ldap://localhost:1389"
TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT

init_counters

wait_replica_has_thomas() {
  local i
  for i in $(seq 1 100); do
    if ldapsearch -x -H "$REPLICA_URI" -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" \
      -b "ou=people,$BASE_DN" "(uid=thomas)" dn 2>/dev/null | grep -q "^dn: uid=thomas"; then
      return 0
    fi
    sleep 2
  done
  return 1
}

provider_set_thomas_description() {
  local marker="$1"
  cat >"$TMPD/thomas-desc.ldif" <<EOF
dn: uid=thomas,ou=people,$BASE_DN
changetype: modify
replace: description
description: $marker
EOF
  ldapmodify -x -H "$PROVIDER_URI" -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -f "$TMPD/thomas-desc.ldif"
}

replica_has_thomas_description() {
  local marker="$1"
  ldapsearch -x -H "$REPLICA_URI" -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" \
    -b "uid=thomas,ou=people,$BASE_DN" -LLL description 2>/dev/null | grep -qF "description: $marker"
}

replica_write_john_should_fail() {
  cat >"$TMPD/john-fail.ldif" <<EOF
dn: uid=john,ou=people,$BASE_DN
changetype: modify
replace: description
description: should-fail-on-readonly-replica
EOF
  if ldapmodify -x -H "$REPLICA_URI" -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -f "$TMPD/john-fail.ldif" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Objectif 6 : Réplication LDAP (RW / RO)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_function "Conteneur ldap-replica en cours d'exécution" \
  "docker ps --format '{{.Names}}' | grep -qx ldap-replica"

test_function "Fournisseur LDAP joignable sur 389" \
  "ldapsearch -x -H $PROVIDER_URI -D cn=admin,$BASE_DN -w $ADMIN_PASS -b $BASE_DN -s base dn >/dev/null 2>&1"

# Before sync, suffix may be absent: only verify slapd responds (root DSE).
test_function "Réplica LDAP répond sur 1389 (root DSE)" \
  "ldapsearch -x -H $REPLICA_URI -b '' -s base namingContexts >/dev/null 2>&1"

echo "▶︎ Attente de la synchronisation syncrepl (uid=thomas sur le réplica)…"
echo "────────────────────────────────────────────────────────────"
if ! wait_replica_has_thomas; then
  echo -e "${RED}Timeout : le réplica n’a pas reçu uid=thomas.${NC}"
  exit 1
fi
echo -e "${GREEN}Synchronisation détectée.${NC}"
echo ""

MARKER="tp-replication-$(date +%s)-$$"

test_function "Écriture sur le fournisseur (attribut description sur thomas)" \
  "provider_set_thomas_description '$MARKER'"

# Propagation can take a few seconds after write
sleep 3

test_function "Modification propagée sur le réplica (même valeur description)" \
  "replica_has_thomas_description '$MARKER'"

test_function "Réplica : écriture refusée (ldapmodify sur john)" \
  "replica_write_john_should_fail"

cat >"$TMPD/del-desc.ldif" <<EOF
dn: uid=thomas,ou=people,$BASE_DN
changetype: modify
delete: description
EOF
ldapmodify -x -H "$PROVIDER_URI" -D "cn=admin,$BASE_DN" -w "$ADMIN_PASS" -f "$TMPD/del-desc.ldif" >/dev/null 2>&1 || true

print_objectif_summary "Objectif 6 - résumé"

if [ "$FAILED_TESTS" -gt 0 ]; then
  exit 1
fi
exit 0
