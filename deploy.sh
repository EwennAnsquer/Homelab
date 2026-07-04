#!/usr/bin/env bash

set -e

echo "➡️ [1/2] Terraform : Création de la structure du conteneur..."
terraform apply -auto-approve

echo "➡️ [2/2] Ansible : Restauration PBS, démarrage et découverte de l'IP DHCP..."
ansible-playbook -i hosts.yml playbook.yml

rm -rf hosts.yml