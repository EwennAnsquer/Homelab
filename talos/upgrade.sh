#!/usr/bin/env bash
set -euo pipefail

JSON_FILE="$1"
TALOSCONFIG="$2"

# 1. Vérification des prérequis
if ! command -v jq &> /dev/null; then
    echo "Erreur : 'jq' est requis mais non installé." >&2
    exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
    echo "Erreur : Le fichier $JSON_FILE est introuvable." >&2
    exit 1
fi

# 2. Saisie de l'URL par l'utilisateur
read -rp "Entrez l'URL complète de la nouvelle Installer Image (factory.talos.dev) : " INSTALLER_IMAGE

if [ -z "$INSTALLER_IMAGE" ]; then
    echo "Erreur : L'URL ne peut pas être vide." >&2
    exit 1
fi

# Récupération de l'IP du Control Plane pour l'option --endpoints
ENDPOINT_IP=$(jq -r '.nodes[] | select(.role == "controlplane") | .ip' "$JSON_FILE" | head -n 1)

echo -e "\n=========================================="
echo " Endpoint du cluster : $ENDPOINT_IP"
echo " Image cible         : $INSTALLER_IMAGE"
echo -e "==========================================\n"

# Fonction d'upgrade d'un nœud
upgrade_node() {
    local node_name="$1"
    local node_ip="$2"
    local node_role="$3"

    echo "---> Traitement du nœud : $node_name ($node_role) - IP : $node_ip"
    
    talosctl upgrade \
        --nodes "$node_ip" \
        --endpoints "$ENDPOINT_IP" \
        --image "$INSTALLER_IMAGE" \
        --talosconfig "$TALOSCONFIG"

    echo "Attente de la fin du redémarrage de $node_name..."
    
    # Attente active que l'API Talos du nœud réponde à nouveau
    until talosctl version --nodes "$node_ip" --endpoints "$ENDPOINT_IP" --talosconfig "$TALOSCONFIG" &> /dev/null; do
        sleep 5
    done

    echo -e "✔ $node_name est de nouveau en ligne !\n"
    sleep 10 # Pause de sécurité pour laisser le temps au nœud de stabiliser ses pods
}

# 3. Étape 1 : Upgrade des Control Planes
echo "=== ÉTAPE 1 : Upgrade du Control Plane ==="
jq -c '.nodes | to_entries[] | select(.value.role == "controlplane")' "$JSON_FILE" | while read -r entry; do
    name=$(echo "$entry" | jq -r '.key')
    ip=$(echo "$entry" | jq -r '.value.ip')
    role=$(echo "$entry" | jq -r '.value.role')
    
    upgrade_node "$name" "$ip" "$role"
done

# 4. Étape 2 : Upgrade des Workers
echo "=== ÉTAPE 2 : Upgrade des Workers ==="
jq -c '.nodes | to_entries[] | select(.value.role != "controlplane")' "$JSON_FILE" | while read -r entry; do
    name=$(echo "$entry" | jq -r '.key')
    ip=$(echo "$entry" | jq -r '.value.ip')
    role=$(echo "$entry" | jq -r '.value.role')
    
    upgrade_node "$name" "$ip" "$role"
done

echo "🎉 Mise à jour de tous les nœuds terminée avec succès !"