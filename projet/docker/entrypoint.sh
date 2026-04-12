#!/usr/bin/env bash
set -euo pipefail

# Script d'entrée pour le conteneur LDAP
# Ce script démarre slapd et exécute les scripts d'initialisation

echo "[entrypoint] Démarrage du conteneur LDAP..."

# Les volumes Docker montés sur /var/lib/ldap et /etc/ldap/slapd.d sont vides
# et souvent propriété de root : slapd (-u openldap) ne peut pas y accéder.
chown -R openldap:openldap /var/lib/ldap /etc/ldap/slapd.d

# Initialisation de la configuration slapd si nécessaire
# Cette étape crée la structure de base cn=config
if [ ! -d "/etc/ldap/slapd.d" ] || [ -z "$(ls -A /etc/ldap/slapd.d || true)" ]; then
  echo "[entrypoint] Initialisation de la configuration slapd..."
  slaptest -F /etc/ldap/slapd.d -f /dev/null >/dev/null 2>&1 || true
  chown -R openldap:openldap /etc/ldap/slapd.d
fi

# Vérifier si slapd est déjà en cours d'exécution
if pgrep slapd >/dev/null 2>&1; then
    echo "[entrypoint] slapd déjà en cours d'exécution"
else
    # Démarrage du serveur slapd en arrière-plan.
    # slapd se daemonise (fork) : le PID du shell ($!) meurt tout de suite, on vérifie la vie du
    # service avec pgrep slapd, pas avec kill -0 $!.
    echo "[entrypoint] Lancement de slapd..."
    slapd -h "ldap:/// ldapi:///" -u openldap -g openldap -F /etc/ldap/slapd.d &
fi

# Attendre que slapd écoute (processus slapd + socket ldapi + LDAP TCP).
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

# Exécution des scripts d'initialisation
# Ces scripts configurent la base de données, créent le DIT et configurent les ACL
if [ -d "/container/init.d" ]; then
  echo "[entrypoint] Exécution des scripts d'initialisation..."
  for script in /container/init.d/*.sh; do
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

# Arrêt propre : docker stop envoie SIGTERM à PID 1
# Éviter « sleep infinity » en boucle : l'arrêt peut rester bloqué très longtemps en « Stopping »
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