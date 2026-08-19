terraform apply -var-file="terraform.tfvars.json" -var-file="secrets.tfvars" --auto-approve

ansible-playbook bootstrap-talos.yml

export KUBECONFIG=$(pwd)/kubeconfig