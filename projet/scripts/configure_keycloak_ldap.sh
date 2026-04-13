#!/usr/bin/env bash
# Configure Keycloak : realm + User Federation LDAP (API d'administration).
# À lancer depuis la machine hôte une fois « docker compose up -d » (Keycloak joindra ldap:389).
set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8090}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
REALM="${KEYCLOAK_REALM:-tp-ldap}"
LDAP_CONNECTION_URL="${KEYCLOAK_LDAP_CONNECTION:-ldap://ldap:389}"
LDAP_BIND_DN="${LDAP_BIND_DN:-cn=admin,dc=example,dc=org}"
LDAP_BIND_PW="${LDAP_BIND_PW:-admin}"
LDAP_USERS_DN="${LDAP_USERS_DN:-ou=people,dc=example,dc=org}"

echo "[configure_keycloak_ldap] Attente de Keycloak (${KEYCLOAK_URL})..."
ready=0
for _ in $(seq 1 90); do
  if curl -sf "${KEYCLOAK_URL}/realms/master" >/dev/null; then
    ready=1
    break
  fi
  sleep 2
done
if [ "$ready" != 1 ]; then
  echo "[configure_keycloak_ldap] ERREUR : Keycloak ne répond pas à temps."
  exit 1
fi

echo "[configure_keycloak_ldap] Obtention du jeton admin-cli..."
TOKEN_JSON=$(curl -sS -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=password" \
  --data-urlencode "client_id=admin-cli" \
  --data-urlencode "username=${KEYCLOAK_ADMIN}" \
  --data-urlencode "password=${KEYCLOAK_ADMIN_PASSWORD}")

TOKEN=$(printf '%s' "$TOKEN_JSON" | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || true)
if [ -z "$TOKEN" ]; then
  echo "[configure_keycloak_ldap] ERREUR : impossible d'obtenir access_token. Réponse :"
  printf '%s\n' "$TOKEN_JSON"
  exit 1
fi

AUTH_HDR=(curl -sS -H "Authorization: Bearer ${TOKEN}")
REALM_CODE=$("${AUTH_HDR[@]}" -o /dev/null -w "%{http_code}" "${KEYCLOAK_URL}/admin/realms/${REALM}")

if [ "$REALM_CODE" != "200" ]; then
  echo "[configure_keycloak_ldap] Création du realm « ${REALM} » (HTTP realm=${REALM_CODE})..."
  HTTP_CREATE=$("${AUTH_HDR[@]}" -o /dev/null -w "%{http_code}" -X POST "${KEYCLOAK_URL}/admin/realms" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "import json; print(json.dumps({'realm':'${REALM}','enabled':True,'displayName':'TP LDAP','registrationAllowed':False,'loginWithEmailAllowed':True,'duplicateEmailsAllowed':False}))")")
  if [ "$HTTP_CREATE" != "201" ]; then
    echo "[configure_keycloak_ldap] ERREUR : création realm HTTP ${HTTP_CREATE}"
    exit 1
  fi
else
  echo "[configure_keycloak_ldap] Realm « ${REALM} » déjà présent."
fi

EXISTING_ID=$("${AUTH_HDR[@]}" "${KEYCLOAK_URL}/admin/realms/${REALM}/components?type=org.keycloak.storage.UserStorageProvider" | python3 -c "
import sys, json
try:
    for c in json.load(sys.stdin):
        if c.get('providerId') == 'ldap':
            print(c.get('id', '') or '')
            break
except json.JSONDecodeError:
    pass
")

if [ -n "$EXISTING_ID" ]; then
  echo "[configure_keycloak_ldap] Fournisseur LDAP déjà configuré (id=${EXISTING_ID})."
  STORAGE_ID="$EXISTING_ID"
else
  echo "[configure_keycloak_ldap] Création du composant User Federation LDAP..."
  REALM_INTERNAL_ID=$("${AUTH_HDR[@]}" "${KEYCLOAK_URL}/admin/realms/${REALM}" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")

  export _KC_REALM_INTERNAL_ID="$REALM_INTERNAL_ID"
  export _KC_LDAP_URL="$LDAP_CONNECTION_URL"
  export _KC_LDAP_BIND_DN="$LDAP_BIND_DN"
  export _KC_LDAP_BIND_PW="$LDAP_BIND_PW"
  export _KC_LDAP_USERS_DN="$LDAP_USERS_DN"
  BODY=$(python3 <<'PY'
import json, os
print(json.dumps({
  "name": "ldap",
  "providerId": "ldap",
  "providerType": "org.keycloak.storage.UserStorageProvider",
  "parentId": os.environ["_KC_REALM_INTERNAL_ID"],
  "config": {
    "enabled": ["true"],
    "priority": ["0"],
    "importEnabled": ["true"],
    "editMode": ["READ_ONLY"],
    "syncRegistrations": ["false"],
    "vendor": ["other"],
    "usernameLDAPAttribute": ["uid"],
    "rdnLDAPAttribute": ["uid"],
    "uuidLDAPAttribute": ["entryUUID"],
    "userObjectClasses": ["inetOrgPerson, organizationalPerson"],
    "connectionUrl": [os.environ["_KC_LDAP_URL"]],
    "bindDn": [os.environ["_KC_LDAP_BIND_DN"]],
    "bindCredential": [os.environ["_KC_LDAP_BIND_PW"]],
    "usersDn": [os.environ["_KC_LDAP_USERS_DN"]],
    "authType": ["simple"],
    "searchScope": ["2"],
    "pagination": ["true"],
    "connectionPooling": ["true"],
    "startTls": ["false"],
  },
}))
PY
)
  unset _KC_REALM_INTERNAL_ID _KC_LDAP_URL _KC_LDAP_BIND_DN _KC_LDAP_BIND_PW _KC_LDAP_USERS_DN
  CREATE_OUT=$(mktemp)
  HTTP_CODE=$(curl -sS -o "$CREATE_OUT" -w "%{http_code}" -X POST \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/components" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$BODY")
  if [ "$HTTP_CODE" != "201" ]; then
    echo "[configure_keycloak_ldap] ERREUR création LDAP provider (HTTP ${HTTP_CODE}) :"
    cat "$CREATE_OUT"
    rm -f "$CREATE_OUT"
    exit 1
  fi
  rm -f "$CREATE_OUT"
  STORAGE_ID=$("${AUTH_HDR[@]}" "${KEYCLOAK_URL}/admin/realms/${REALM}/components?type=org.keycloak.storage.UserStorageProvider" | python3 -c "
import sys, json
for c in json.load(sys.stdin):
    if c.get('providerId') == 'ldap':
        print(c['id'])
        break
")
  if [ -z "$STORAGE_ID" ]; then
    echo "[configure_keycloak_ldap] ERREUR : id du stockage LDAP introuvable après création."
    exit 1
  fi
fi

echo "[configure_keycloak_ldap] Synchronisation complète des utilisateurs LDAP..."
SYNC_CODE=$(curl -sS -o /dev/null -w "%{http_code}" -X POST \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/user-storage/${STORAGE_ID}/sync?action=triggerFullSync" \
  -H "Authorization: Bearer ${TOKEN}")
if [ "$SYNC_CODE" != "204" ] && [ "$SYNC_CODE" != "200" ]; then
  echo "[configure_keycloak_ldap] AVERTISSEMENT : sync HTTP ${SYNC_CODE} (souvent acceptable si déjà synchronisé)."
fi

echo "[configure_keycloak_ldap] Terminé. Console : ${KEYCLOAK_URL}/admin/ - realm « ${REALM} »."
