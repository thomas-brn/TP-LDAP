#!/usr/bin/env bash
# Objectif 5 - Intégration Keycloak (User Federation LDAP)
# Prérequis : depuis projet/, « docker compose up -d » (ldap + keycloak).
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/test_common.sh
source "$SCRIPT_DIR/lib/test_common.sh"

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8090}"
REALM="${KEYCLOAK_REALM:-tp-ldap}"

init_counters

verify_kc_user() {
  local u="$1"
  local T
  T=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=password" \
    --data-urlencode "client_id=admin-cli" \
    --data-urlencode "username=admin" \
    --data-urlencode "password=admin" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")
  curl -sf -H "Authorization: Bearer $T" \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=${u}&exact=true" \
    | python3 -c "import sys, json; x=json.load(sys.stdin); assert len(x)==1 and x[0].get('username')=='${u}'"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Objectif 5 : Intégration Keycloak (OpenID / User Federation LDAP)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_function "Conteneur Keycloak en cours d'exécution" \
  "docker ps --format '{{.Names}}' | grep -qx keycloak"

test_function "Keycloak répond (realm master)" \
  "curl -sf '${KEYCLOAK_URL}/realms/master' >/dev/null"

echo "▶︎ Configuration Keycloak (realm + LDAP) via scripts/configure_keycloak_ldap.sh"
echo "────────────────────────────────────────────────────────────"
if ! bash "$SCRIPT_DIR/../scripts/configure_keycloak_ldap.sh"; then
  echo -e "${RED}Échec de configure_keycloak_ldap.sh${NC}"
  exit 1
fi
echo ""

test_function "Utilisateur thomas présent dans Keycloak (import LDAP)" \
  "verify_kc_user thomas"

test_function "Utilisateur john présent dans Keycloak (import LDAP)" \
  "verify_kc_user john"

print_objectif_summary "Objectif 5 - résumé"

if [ "$FAILED_TESTS" -gt 0 ]; then
  exit 1
fi
exit 0
