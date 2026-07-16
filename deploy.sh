#!/usr/bin/env bash

set -e

CONFIG_FILE="config.yml"

echo "🔍 [0/2] Vérification des conflits d'adresses IP..."
/bin/bash check_if_ips_are_available.sh $CONFIG_FILE

echo "➡️ [1/2] Terraform : Création de la structure du conteneur..."
terraform apply -auto-approve

echo "➡️ [2/2] Ansible : Restauration PBS, démarrage et découverte de l'IP DHCP..."
ansible-playbook -i hosts.yml playbook.yml

rm -rf hosts.yml