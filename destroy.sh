#!/usr/bin/env bash

set -e

# Chemin vers ton fichier de configuration globale
CONFIG_FILE="config.yml"

# Vérification que le fichier de config existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Erreur : Le fichier $CONFIG_FILE est introuvable."
    exit 1
fi

STORAGE_PBS=$(yq '.proxmox.storage_pbs' "$CONFIG_FILE" | tr -d '"' | xargs)
PROXMOX_IP=$(yq '.proxmox.ip' "$CONFIG_FILE" | tr -d '"' | xargs)
ANSIBLE_SSH_PRIVATE_KEY_FILE=$(yq '.ansible.ansible_ssh_private_key_file' "$CONFIG_FILE" | tr -d '"' | xargs)

# Remplacement du tilde (~) en chemin absolu si présent dans la clé SSH
ANSIBLE_SSH_PRIVATE_KEY_FILE="${ANSIBLE_SSH_PRIVATE_KEY_FILE/#\~/$HOME}"

# Vérification du paramètre
if [ -z "$1" ]; then
    echo "❌ Erreur : Vous devez spécifier l'ID de la VM ou du Container (ex: ./destroy.sh 901)"
    exit 1
fi

VM_ID=$1

echo "🔍 Analyse de l'ID $VM_ID sur Proxmox..."

# Connexion SSH pour détecter le type (VM ou LXC)
if ssh -i "$ANSIBLE_SSH_PRIVATE_KEY_FILE" -o StrictHostKeyChecking=no root@$PROXMOX_IP "pct status $VM_ID" >/dev/null 2>&1; then
    TYPE="ct"
    HOSTNAME=$(ssh -i "$ANSIBLE_SSH_PRIVATE_KEY_FILE" -o StrictHostKeyChecking=no root@$PROXMOX_IP "pct config $VM_ID" | grep "hostname:" | awk '{print $2}')
    echo "ℹ️ ID $VM_ID identifié comme un Conteneur (LXC) nommé [$HOSTNAME]."
elif ssh -i "$ANSIBLE_SSH_PRIVATE_KEY_FILE" -o StrictHostKeyChecking=no root@$PROXMOX_IP "qm status $VM_ID" >/dev/null 2>&1; then
    TYPE="qemu"
    # Récupération propre du hostname pour une VM
    HOSTNAME=$(ssh -i "$ANSIBLE_SSH_PRIVATE_KEY_FILE" -o StrictHostKeyChecking=no root@$PROXMOX_IP "qm config $VM_ID" | grep "name:" | awk '{print $2}')
    echo "ℹ️ ID $VM_ID identifié comme une Machine Virtuelle (VM) nommée [$HOSTNAME]."
else
    echo "❌ Erreur : L'ID $VM_ID n'existe pas ou n'est pas accessible sur Proxmox."
    exit 1
fi

# Préparation de la note de backup
COMMENT="Destruction Automatique - Hostname: $HOSTNAME"
CMD_BACKUP="vzdump $VM_ID --storage $STORAGE_PBS --mode snapshot --notes \"$COMMENT\""

# 1. ÉTAPE DE BACKUP
echo "➡️ [1/2] Lancement de la sauvegarde de l'élément $VM_ID ($HOSTNAME) sur le PBS..."
if ssh -i "$ANSIBLE_SSH_PRIVATE_KEY_FILE" -o StrictHostKeyChecking=no root@$PROXMOX_IP "$CMD_BACKUP"; then
    echo "✅ Sauvegarde réussie avec succès !"
else
    echo "❌ Erreur lors de la sauvegarde. Par sécurité, arrêt du script."
    exit 1
fi

# 2. ÉTAPE TERRAFORM
echo "➡️ [2/2] Recherche de la ressource correspondante dans l'état Terraform..."

TF_TARGET=""
# On récupère d'abord la liste des ressources filtrées pour éviter d'imbriquer un pipeline complexe
RESOURCES=$(terraform state list | grep -E "(container|virtual_environment_vm)" || true)

for res in $RESOURCES; do
    if terraform state show "$res" 2>/dev/null | grep -q "vm_id\s*=\s*$VM_ID"; then
        TF_TARGET="$res"
        break
    fi
done

if [ -z "$TF_TARGET" ]; then
    echo "⚠️ Attention : L'ID $VM_ID existe sur Proxmox mais n'a pas été trouvé dans le State Terraform."
    echo "Le conteneur a peut-être été créé manuellement. Destruction Terraform impossible."
    exit 1
fi

echo "🔥 Ressource Terraform trouvée : $TF_TARGET"
echo "⚠️ Destruction de la ressource via Terraform..."

# Exécution du destroy ciblé
terraform destroy -target="$TF_TARGET" -auto-approve

if [ $? -eq 0 ]; then
    echo "🎉 Opération terminée ! L'élément $VM_ID ($HOSTNAME) a été sauvegardé puis détruit proprement via Terraform."
else
    echo "❌ Échec de la commande terraform destroy."
    exit 1
fi