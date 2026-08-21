terraform apply -var-file="terraform.tfvars.json" -var-file="secrets.tfvars" --auto-approve

ansible-playbook bootstrap-talos.yml

mkdir -p ~/.kube
cp "$(pwd)/kubeconfig" ~/.kube/config

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Erreur : La variable GITHUB_TOKEN n'est pas définie. Exporte-la avec : export GITHUB_TOKEN=..."
  exit 1
else
  ansible-playbook deploy-fluxcd.yml
fi