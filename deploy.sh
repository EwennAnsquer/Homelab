#!/usr/bin/env bash

set -e

RESTORE_DOCKER="false"

# Vérifie si l'un des arguments passés au script est --restore ou -r
for arg in "$@"; do
  if [ "$arg" == "--restore-docker" ]; then
    RESTORE_DOCKER="true"
  fi
done

echo "➡️ [1/2] Terraform : Création de la structure du/des conteneur(s) manquant(s)..."
terraform apply -auto-approve

echo "➡️ [2/2] Ansible : Lancement du playbook..."
ansible-playbook -i inventory/production.yml playbook.yml -e "restore_docker=$RESTORE_DOCKER"