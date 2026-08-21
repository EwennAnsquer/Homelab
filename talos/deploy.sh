#!/usr/bin/env bash
set -euo pipefail

# 1. Application de Terraform dans son dossier
terraform -chdir=./terraform apply \
  -var-file="terraform.tfvars.json" \
  -var-file="secrets.tfvars" \
  --auto-approve

# 2. Bootstrap Talos via Ansible
ansible-playbook ./ansible/bootstrap-talos.yml

# 3. Copie du kubeconfig généré à la racine
mkdir -p ~/.kube
cp "$(pwd)/kubeconfig" ~/.kube/config

# 4. Bootstrap FluxCD
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Erreur : La variable GITHUB_TOKEN n'est pas définie." >&2
  exit 1
else
  ansible-playbook ./ansible/deploy-fluxcd.yml
fi