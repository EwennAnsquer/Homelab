#!/usr/bin/env bash

set -e

RESTORE_DOCKER="false"

export TF_VAR_proxmox_api_token=$(ansible-vault view /root/work/Homelab/inventory/group_vars/all/vault.yml --vault-password-file .vault_pass | grep 'proxmox_api_token' | awk '{print $2}' | tr -d '"')

# Vérifie si l'un des arguments passés au script est --restore ou -r
for arg in "$@"; do
  if [ "$arg" == "--restore-docker" ]; then
    RESTORE_DOCKER="true"
  fi
done

echo "➡️ [1/2] Terraform : Création de la structure du/des conteneur(s) manquant(s)..."
terraform apply -auto-approve

echo "➡️ [2/2] Ansible : Lancement du playbook..."
ansible-playbook playbook.yml \
  -i inventory/production.yml \
  --vault-password-file .vault_pass \
  -e "restore_docker=$RESTORE_DOCKER"