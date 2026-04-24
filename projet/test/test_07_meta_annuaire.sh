#!/usr/bin/env bash
# Objective 7 — LDAP federation (back-meta meta-directory)
# Prerequisite: run "docker compose up -d" in projet/ (ldap, ldap-acme, ldap-meta).
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/test_common.sh
source "$SCRIPT_DIR/lib/test_common.sh"

META_URI="ldap://localhost:3389"
META_SUFFIX="o=federation"
META_BIND="cn=admin,o=federation"
META_PASS="$ADMIN_PASS"

init_counters

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Objectif 7 : Fédération LDAP (méta-annuaire)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_function "Conteneur ldap-meta en cours d'exécution" \
  "docker ps --format '{{.Names}}' | grep -qx ldap-meta"

test_function "Conteneur ldap-acme en cours d'exécution" \
  "docker ps --format '{{.Names}}' | grep -qx ldap-acme"

test_function "Méta-annuaire joignable sur le port 3389" \
  "ldapsearch -x -H $META_URI -D $META_BIND -w $META_PASS -b '' -s base namingContexts >/dev/null 2>&1"

test_function "Contexte de nommage o=federation annoncé par le méta" \
  "ldapsearch -x -H $META_URI -D $META_BIND -w $META_PASS -b '' -s base namingContexts 2>/dev/null | grep -qF 'namingContexts: $META_SUFFIX'"

test_function "Sous-arbre example.org via méta (mail thomas@example.org)" \
  "ldapsearch -x -H $META_URI -D $META_BIND -w $META_PASS -b ou=people,ou=example-org,$META_SUFFIX -s sub '(uid=thomas)' mail 2>/dev/null | grep -qF 'thomas@example.org'"

test_function "Sous-arbre acme via méta (mail thomas@acme.com)" \
  "ldapsearch -x -H $META_URI -D $META_BIND -w $META_PASS -b ou=people,ou=acme-corp,$META_SUFFIX -s sub '(uid=thomas)' mail 2>/dev/null | grep -qF 'thomas@acme.com'"

test_function "Une requête sous o=federation retourne les deux sources (uid=thomas)" \
  "test \$(ldapsearch -x -H $META_URI -D $META_BIND -w $META_PASS -b $META_SUFFIX -s sub '(uid=thomas)' dn 2>/dev/null | grep -c '^dn: uid=thomas') -eq 2"

print_objectif_summary "Objectif 7 — résumé"

if [ "$FAILED_TESTS" -gt 0 ]; then
  exit 1
fi
exit 0
