#!/usr/bin/env bash

# 1. Vérifier si le nombre d'arguments est exactement égal à 1
if [ "$#" -ne 1 ]; then
  echo "❌ Erreur : Mauvaise utilisation du script."
  echo "Usage   : $0 <chemin_du_fichier_config.yml>"
  echo "Exemple : $0 config.yml"
  exit 1
fi

CONFIG_FILE="$1"

# 2. Vérifier si le fichier fourni existe réellement
if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Erreur : Le fichier de configuration '$CONFIG_FILE' n'existe pas."
  exit 1
fi

# On vérifie si yq est installé pour lire proprement le YAML, sinon on utilise un fallback grep
if command -v yq >/dev/null 2>&1; then
  # On extrait toutes les adresses IP configurées qui ne sont pas "dhcp"
  STATIC_IPS=$(yq '.containers[].address' "$CONFIG_FILE" | grep -v 'dhcp' | cut -d'/' -f1 || true)
else
  # Fallback simple avec grep si yq n'est pas installé
  STATIC_IPS=$(grep -E 'address:' "$CONFIG_FILE" | grep -v 'dhcp' | awk -F'"' '{print $2}' | cut -d'/' -f1 || true)
fi

# Si on a trouvé des IPs statiques, on les teste
if [ -n "$STATIC_IPS" ]; then
  for ip in $STATIC_IPS; do
    echo "Checking $ip..."
    # On envoie 1 seul ping avec un timeout de 1 seconde
    if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
      echo "❌ ERREUR CRITIQUE : L'adresse IP static [$ip] répond déjà au ping sur ton réseau !"
      echo "⚠️ Déploiement annulé pour éviter un conflit d'IP. Change l'IP dans $CONFIG_FILE."
      exit 1
    fi
  done
  echo "✅ Aucune IP statique configurée n'est actuellement active sur le réseau."
else
  echo "ℹ️ Tous les conteneurs sont configurés en DHCP (ou aucune IP statique trouvée). Pas de risque de conflit."
fi