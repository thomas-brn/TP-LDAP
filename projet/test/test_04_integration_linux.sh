#!/usr/bin/env bash
# Objective 4 — Linux integration (PAM/NSS)
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/test_common.sh
source "$SCRIPT_DIR/lib/test_common.sh"

init_counters

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Objectif 4 : Intégration Linux (PAM/NSS)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_function "Résolution utilisateur thomas (NSS)" \
    "docker exec ldap bash -c 'getent passwd thomas' >/dev/null 2>&1"

test_function "Résolution utilisateur john (NSS)" \
    "docker exec ldap bash -c 'getent passwd john' >/dev/null 2>&1"

test_function "Résolution groupe admin_ldap (NSS)" \
    "docker exec ldap bash -c 'getent group admin_ldap' >/dev/null 2>&1"

test_function "Résolution groupe developers (NSS)" \
    "docker exec ldap bash -c 'getent group developers' >/dev/null 2>&1"

test_with_output "Attributs POSIX de thomas" \
    "docker exec ldap bash -c 'getent passwd thomas'"

test_with_output "Attributs POSIX de john" \
    "docker exec ldap bash -c 'getent passwd john'"

test_with_output "Groupe POSIX admin_ldap" \
    "docker exec ldap bash -c 'getent group admin_ldap'"

test_with_output "Groupe POSIX developers" \
    "docker exec ldap bash -c 'getent group developers'"

print_objectif_summary "Objectif 4 - résumé"

if [ "$FAILED_TESTS" -gt 0 ]; then
    exit 1
fi
exit 0
