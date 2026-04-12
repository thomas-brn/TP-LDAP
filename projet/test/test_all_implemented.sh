#!/usr/bin/env bash
# Lance tous les scripts de test des objectifs 1 à 7 du TP (ordre pédagogique).
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/test_common.sh
source "$SCRIPT_DIR/lib/test_common.sh"

TESTS=(
    "test_01_installation_deploiement.sh"
    "test_02_conception_dit.sh"
    "test_03_roles_acl.sh"
    "test_04_integration_linux.sh"
    "test_05_keycloak.sh"
    "test_06_replication.sh"
    "test_07_meta_annuaire.sh"
)

echo "════════════════════════════════════════════════════════════"
echo "🧪 Suite complète — TP LDAP (objectifs 1 à 7)"
echo "════════════════════════════════════════════════════════════"
echo ""

ANY_FAILED=0
declare -a LIGNES_RESUME=()

for t in "${TESTS[@]}"; do
    path="$SCRIPT_DIR/$t"
    if [ ! -f "$path" ]; then
        echo -e "${RED}Fichier manquant : $path${NC}"
        ANY_FAILED=1
        LIGNES_RESUME+=("$t : absent")
        continue
    fi
    echo "▶︎ Exécution de $t"
    echo "────────────────────────────────────────────────────────────"
    if bash "$path"; then
        LIGNES_RESUME+=("$t : OK")
    else
        LIGNES_RESUME+=("$t : échec")
        ANY_FAILED=1
    fi
    echo ""
done

echo "════════════════════════════════════════════════════════════"
echo "📋 Résumé global"
echo "════════════════════════════════════════════════════════════"
for ligne in "${LIGNES_RESUME[@]}"; do
    echo "  • $ligne"
done
echo ""

if [ "$ANY_FAILED" -eq 0 ]; then
    echo -e "${GREEN}✅ Tous les objectifs testés ont réussi.${NC}"
    exit 0
fi

echo -e "${RED}❌ Au moins un objectif a des tests en échec (voir détails ci-dessus).${NC}"
exit 1
