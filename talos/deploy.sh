#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"
TFVARS_PATH="${ROOT_DIR}/terraform/terraform.tfvars.json"

# 1. Application de Terraform dans son dossier
terraform -chdir=$ROOT_DIR/terraform apply \
  -var-file="terraform.tfvars.json" \
  -var-file="secrets.tfvars" \
  --auto-approve

# 2. Bootstrap Talos via Ansible
ansible-playbook $ROOT_DIR/ansible/bootstrap-talos.yml \
  -e "tfvars_path=${ROOT_DIR}/terraform/terraform.tfvars.json"

# 3. Copie du kubeconfig généré à la racine
mkdir -p ~/.kube
cp "$ROOT_DIR/kubeconfig" ~/.kube/config

# 4. Bootstrap FluxCD
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Erreur : La variable GITHUB_TOKEN n'est pas définie." >&2
  exit 1
else
  ansible-playbook "$ROOT_DIR/ansible/deploy-fluxcd.yml" \
    -e "@${ROOT_DIR}/ansible/vars-fluxcd.yml"
fi