#!/usr/bin/env bash
set -euo pipefail

# Entrypoint script for the LDAP container
# This script starts slapd and runs initialization scripts

echo "[entrypoint] Démarrage du conteneur LDAP..."

# Docker volumes mounted on /var/lib/ldap and /etc/ldap/slapd.d are empty
# and often owned by root: slapd (-u openldap) cannot access them.
chown -R openldap:openldap /var/lib/ldap /etc/ldap/slapd.d

# Initialize slapd configuration if needed
# This step creates the base cn=config structure
if [ ! -d "/etc/ldap/slapd.d" ] || [ -z "$(ls -A /etc/ldap/slapd.d || true)" ]; then
  echo "[entrypoint] Initialisation de la configuration slapd..."
  slaptest -F /etc/ldap/slapd.d -f /dev/null >/dev/null 2>&1 || true
  chown -R openldap:openldap /etc/ldap/slapd.d
fi

# Check whether slapd is already running
if pgrep slapd >/dev/null 2>&1; then
    echo "[entrypoint] slapd déjà en cours d'exécution"
else
    # Start slapd in the background.
    # slapd daemonizes (forks): the shell PID ($!) dies immediately, so we check
    # service liveness with pgrep slapd, not kill -0 $!.
    echo "[entrypoint] Lancement de slapd..."
    slapd -h "ldap:/// ldapi:///" -u openldap -g openldap -F /etc/ldap/slapd.d &
fi

# Wait until slapd is listening (slapd process + ldapi socket + LDAP TCP).
echo "[entrypoint] Attente du socket ldapi et du port LDAP 389..."
ready=0
for i in {1..60}; do
  if ! pgrep slapd >/dev/null 2>&1; then
    echo "[entrypoint] ERREUR: aucun processus slapd. Vérifiez les droits sur /etc/ldap/slapd.d et /var/lib/ldap (propriétaire openldap)."
    exit 1
  fi
  if { [ -S /var/run/slapd/ldapi ] || [ -S /run/slapd/ldapi ]; } && bash -c ":>/dev/tcp/127.0.0.1/389" 2>/dev/null; then
    echo "[entrypoint] slapd prêt (ldapi + port 389)"
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" != 1 ]; then
  echo "[entrypoint] ERREUR: slapd ne semble pas joignable après 60 s."
  exit 1
fi

# Run initialization scripts
# These scripts configure the database, create the DIT, and configure ACLs
if [ -d "/container/init.d" ]; then
  echo "[entrypoint] Exécution des scripts d'initialisation..."
  for name in init_ldap.sh init_ldap_linux_integration.sh init_replication_provider.sh init_replication_consumer.sh; do
    script="/container/init.d/$name"
    [ -e "$script" ] || continue
    echo "[entrypoint] Exécution: $script"
    if bash "$script"; then
      echo "[entrypoint] Terminé OK: $script"
    else
      rc=$?
      echo "[entrypoint] AVERTISSEMENT: $script a retourné le code $rc (poursuite du démarrage)"
    fi
  done
  echo "[entrypoint] Scripts d'initialisation terminés"
  touch /container/.ldap-init-complete
fi

# Graceful shutdown: docker stop sends SIGTERM to PID 1
# Avoid looped "sleep infinity": shutdown can stay stuck in "Stopping" for a long time
_shutdown() {
  echo "[entrypoint] Arrêt demandé (SIGTERM/SIGINT)..."
  pkill -u openldap -TERM slapd 2>/dev/null || pkill -TERM slapd 2>/dev/null || true
  local i
  for i in $(seq 1 40); do
    pgrep slapd >/dev/null 2>&1 || break
    sleep 0.25
  done
  pkill -u openldap -KILL slapd 2>/dev/null || pkill -KILL slapd 2>/dev/null || true
  exit 0
}
trap _shutdown TERM INT

echo "[entrypoint] Conteneur prêt (docker stop pour arrêter)..."
tail -f /dev/null &
wait $!