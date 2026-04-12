#!/usr/bin/env bash
# Objectif 1 — Installation et déploiement automatisé
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/test_common.sh
source "$SCRIPT_DIR/lib/test_common.sh"

init_counters

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Objectif 1 : Installation et déploiement automatisé"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_function "Conteneur LDAP en cours d'exécution" \
    "docker ps | grep -q ldap"

test_function "slapd répond sur le port 389" \
    "ldapsearch -x -H ldap://localhost:389 -b $BASE_DN -s base dn >/dev/null 2>&1"

test_function "Connexion ldapi fonctionne" \
    "docker exec ldap bash -c 'ldapwhoami -H ldapi:/// -Y EXTERNAL' >/dev/null 2>&1"

print_objectif_summary "Objectif 1 — résumé"

if [ "$FAILED_TESTS" -gt 0 ]; then
    exit 1
fi
exit 0
