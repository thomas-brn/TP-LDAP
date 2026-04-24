# Shared library for LDAP lab test scripts.
# Source it from the same parent directory: source "$SCRIPT_DIR/lib/test_common.sh"

BASE_DN="dc=example,dc=org"
ADMIN_PASS="admin"
THOMAS_PASS="thomas123"
JOHN_PASS="john123"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

init_counters() {
    TOTAL_TESTS=0
    PASSED_TESTS=0
    FAILED_TESTS=0
}

test_function() {
    local test_name="$1"
    local command="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Test $TOTAL_TESTS: $test_name ... "

    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASSÉ${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ ÉCHOUÉ${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

test_with_output() {
    local test_name="$1"
    local command="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo "Test $TOTAL_TESTS: $test_name"
    echo "  Commande: $command"
    if eval "$command" 2>&1; then
        echo -e "  ${GREEN}✅ PASSÉ${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    fi
    echo -e "  ${RED}❌ ÉCHOUÉ${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    return 1
}

print_objectif_summary() {
    local titre="$1"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$titre"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Total de tests : $TOTAL_TESTS"
    echo -e "${GREEN}Tests réussis : $PASSED_TESTS${NC}"
    if [ "$FAILED_TESTS" -gt 0 ]; then
        echo -e "${RED}Tests échoués : $FAILED_TESTS${NC}"
    else
        echo -e "${GREEN}Tests échoués : $FAILED_TESTS${NC}"
    fi
}
