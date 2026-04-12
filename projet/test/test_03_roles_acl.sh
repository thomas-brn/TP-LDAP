#!/usr/bin/env bash
# Objectif 3 — Discrétisation des rôles et ACL
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/test_common.sh
source "$SCRIPT_DIR/lib/test_common.sh"

init_counters

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Objectif 3 : Discrétisation des rôles et ACL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_function "Authentification admin (rootDN)" \
    "ldapwhoami -x -H ldap://localhost:389 -D cn=admin,$BASE_DN -w $ADMIN_PASS >/dev/null 2>&1"

test_function "Authentification thomas" \
    "ldapwhoami -x -H ldap://localhost:389 -D uid=thomas,ou=people,$BASE_DN -w $THOMAS_PASS >/dev/null 2>&1"

test_function "Authentification john" \
    "ldapwhoami -x -H ldap://localhost:389 -D uid=john,ou=people,$BASE_DN -w $JOHN_PASS >/dev/null 2>&1"

test_function "Thomas est membre de admin_ldap" \
    "ldapsearch -x -H ldap://localhost:389 -b ou=groups,$BASE_DN '(cn=admin_ldap)' memberUid 2>/dev/null | grep -q 'memberUid: thomas' || ldapsearch -x -H ldap://localhost:389 -b ou=groups,$BASE_DN '(cn=admin_ldap)' member 2>/dev/null | grep -q 'uid=thomas'"

test_function "John est membre de developers" \
    "ldapsearch -x -H ldap://localhost:389 -b ou=groups,$BASE_DN '(cn=developers)' memberUid 2>/dev/null | grep -q 'memberUid: john' || ldapsearch -x -H ldap://localhost:389 -b ou=groups,$BASE_DN '(cn=developers)' member 2>/dev/null | grep -q 'uid=john'"

test_function "Thomas est membre de admin_keycloak" \
    "ldapsearch -x -H ldap://localhost:389 -b ou=groups,$BASE_DN '(cn=admin_keycloak)' memberUid 2>/dev/null | grep -q 'memberUid: thomas' || ldapsearch -x -H ldap://localhost:389 -b ou=groups,$BASE_DN '(cn=admin_keycloak)' member 2>/dev/null | grep -q 'uid=thomas'"

test_with_output "Thomas peut lire l'annuaire" \
    "ldapsearch -x -H ldap://localhost:389 -D uid=thomas,ou=people,$BASE_DN -w $THOMAS_PASS -b $BASE_DN -s base dn"

test_with_output "John peut lire l'annuaire" \
    "ldapsearch -x -H ldap://localhost:389 -D uid=john,ou=people,$BASE_DN -w $JOHN_PASS -b $BASE_DN -s base dn"

print_objectif_summary "Objectif 3 — résumé"

if [ "$FAILED_TESTS" -gt 0 ]; then
    exit 1
fi
exit 0
