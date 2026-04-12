#!/usr/bin/env bash
# Objectif 2 — Conception de la structure DIT
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/test_common.sh
source "$SCRIPT_DIR/lib/test_common.sh"

init_counters

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Objectif 2 : Conception de la structure DIT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_function "Base DN existe" \
    "ldapsearch -x -H ldap://localhost:389 -b $BASE_DN -s base dn >/dev/null 2>&1"

test_function "OU people existe" \
    "ldapsearch -x -H ldap://localhost:389 -b ou=people,$BASE_DN -s base dn >/dev/null 2>&1"

test_function "OU groups existe" \
    "ldapsearch -x -H ldap://localhost:389 -b ou=groups,$BASE_DN -s base dn >/dev/null 2>&1"

test_function "Utilisateur thomas existe" \
    "ldapsearch -x -H ldap://localhost:389 -b ou=people,$BASE_DN '(uid=thomas)' dn >/dev/null 2>&1"

test_function "Utilisateur john existe" \
    "ldapsearch -x -H ldap://localhost:389 -b ou=people,$BASE_DN '(uid=john)' dn >/dev/null 2>&1"

test_function "Groupe admin_ldap existe" \
    "ldapsearch -x -H ldap://localhost:389 -b ou=groups,$BASE_DN '(cn=admin_ldap)' dn >/dev/null 2>&1"

test_function "Groupe developers existe" \
    "ldapsearch -x -H ldap://localhost:389 -b ou=groups,$BASE_DN '(cn=developers)' dn >/dev/null 2>&1"

test_function "Groupe admin_keycloak existe" \
    "ldapsearch -x -H ldap://localhost:389 -b ou=groups,$BASE_DN '(cn=admin_keycloak)' dn >/dev/null 2>&1"

print_objectif_summary "Objectif 2 — résumé"

if [ "$FAILED_TESTS" -gt 0 ]; then
    exit 1
fi
exit 0
