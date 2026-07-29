#!/usr/bin/env bash

set -e

HOSTS_FILE="inventory/production.yml"

# ==============================================================================
# Installation des dépendances si absentes
# ==============================================================================

install_yq() {
  echo "📦 yq n'est pas installé — installation en cours..."
  local ARCH
  case "$(uname -m)" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "❌ Architecture non supportée pour yq: $(uname -m)"; exit 1 ;;
  esac

  sudo wget -qO /usr/local/bin/yq \
    "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}"
  sudo chmod a+x /usr/local/bin/yq
  echo "✅ yq installé : $(yq --version)"
}

install_jq() {
  echo "📦 jq n'est pas installé — installation en cours..."
  sudo apt-get update -qq
  sudo apt-get install -y jq
  echo "✅ jq installé : $(jq --version)"
}

command -v yq >/dev/null 2>&1 || install_yq
command -v jq >/dev/null 2>&1 || install_jq

# ==============================================================================
# Lecture des infos Proxmox depuis hosts.yml
# ==============================================================================

PROXMOX_ENDPOINT=$(yq -r '.proxmox.endpoint' "$HOSTS_FILE")
PROXMOX_NODE=$(yq -r '.proxmox.node_name' "$HOSTS_FILE")
PROXMOX_TOKEN=$(yq -r '.proxmox.api_token' "$HOSTS_FILE")

# --- Vérifie si au moins un conteneur défini dans hosts.yml n'existe pas encore sur Proxmox ---
NEED_TERRAFORM=false

CONTAINER_IDS=$(yq -r '.containers[].vm_id' "$HOSTS_FILE")

for VM_ID in $CONTAINER_IDS; do
  echo "🔍 Vérification du conteneur VMID=$VM_ID sur Proxmox..."

  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --insecure \
    -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN}" \
    "${PROXMOX_ENDPOINT}api2/json/nodes/${PROXMOX_NODE}/lxc/${VM_ID}/status/current")

  if [ "$HTTP_STATUS" == "200" ]; then
    echo "   ✅ VMID=$VM_ID existe déjà — pas besoin de Terraform pour celui-ci."
  else
    echo "   ⚠️  VMID=$VM_ID introuvable (HTTP $HTTP_STATUS) — Terraform doit tourner."
    NEED_TERRAFORM=true
  fi
done

# ==============================================================================
# Étape 1 : Terraform, uniquement si nécessaire
# ==============================================================================

if [ "$NEED_TERRAFORM" == "true" ]; then
  echo "➡️ [1/2] Terraform : Création de la structure du/des conteneur(s) manquant(s)..."
  terraform apply -auto-approve
else
  echo "⏭️  [1/2] Terraform : ignoré, tous les conteneurs existent déjà sur Proxmox."
fi

# ==============================================================================
# Étape 2 : Ansible, toujours exécuté
# ==============================================================================

echo "➡️ [2/2] Ansible : Lancement du playbook..."
ansible-playbook -i inventory/production.yml playbook.yml \
  --extra-vars "terraform_ran=${NEED_TERRAFORM}"