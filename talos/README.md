# Procédure de déploiement et mise à jour de Talos Linux (avec Longhorn)

Ce guide détaille la procédure pour générer une image système Talos Linux personnalisée (compatible avec Longhorn) sur **factory.talos.dev**, ainsi que la méthode pour installer ou mettre à jour un cluster existant sur Proxmox.

---

## 1. Génération de l'image sur Talos Image Factory

Longhorn nécessite des utilitaires système (`iscsiadm`, `blkid`, support NFS) non inclus par défaut dans l'OS immuable de Talos. L'image doit donc être générée avec des extensions système spécifiques.

1. Rendez-vous sur [factory.talos.dev](https://factory.talos.dev/).
2. Sélectionnez la version de Talos (ex: `v1.7.0` ou plus récente) et l'architecture (`amd64`).
3. Cochez les **4 extensions système** obligatoires :
   - `siderolabs/iscsi-tools` : Gestion des volumes iSCSI (résout l'erreur `iscsiadm`).
   - `siderolabs/util-linux-tools` : Outils de manipulation de fichiers/disques (`blkid`, etc.).
   - `siderolabs/nfs-utils` : Support des volumes partageables RWX et sauvegardes NFS.
   - `siderolabs/qemu-guest-agent` : Intégration pour hyperviseur Proxmox/KVM.

---

## 2. Choix de la méthode : Upgrade d'un cluster ou Création du Template Proxmox

### Option A : Pour mettre à jour un cluster existant (Upgrade à chaud)

1. Sur `factory.talos.dev`, récupérez l'URL située sous la section **Mise à niveau de Talos Linux** :
   factory.talos.dev/nocloud-installer-secureboot/<SCHEMATIC_ID>:v1.x.x

2. Exécutez le script de mise à jour avec vos fichiers de configuration en arguments :
   ./upgrade.sh ./terraform/terraform.tfvars.json ./talos-config/talosconfig

3. Entrez l'URL d'installation lorsque le script vous la demande. Le script appliquera la mise à jour nœud par nœud (Control Plane puis Workers) sans coupure de service.

---

### Option B : Création / Mise à jour du Template Proxmox pour Terraform

Pour provisionner de nouveaux nœuds via Terraform, les VMs sont clonées depuis un template modèle (VM ID `9000`). Ce template est généré à partir de l'image **Image disque SecureBoot (`.raw.xz`)**.

La création et le remplacement du template Proxmox sont automatisés via le playbook Ansible `create-talos-template.yml`. Le playbook lit directement l'endpoint Proxmox dans votre fichier `terraform.tfvars.json`.

#### Exécution du playbook Ansible :

1. Lancez le playbook depuis votre machine locale :
   ansible-playbook -i "localhost," create-talos-template.yml

2. Lorsque le prompt apparaît, collez l'URL de l'image disque `.raw.xz` générée sur `factory.talos.dev` (ex: `https://factory.talos.dev/image/<SCHEMATIC_ID>/v1.x.x/nocloud-amd64-secureboot.raw.xz`).

3. Le playbook se charge automatiquement de :
   - Lire `terraform.tfvars.json` pour cibler le bon hyperviseur Proxmox.
   - Télécharger et décompresser l'image dans `/tmp`.
   - Supprimer l'ancien template `9000` s'il existe déjà.
   - Créer la nouvelle VM modèle (Q35, OVMF/UEFI, VirtIO, Cloud-Init, Agent QEMU).
   - Importer le disque et convertir la VM en Template (`qm template 9000`).
   - Nettoyer les fichiers temporaires.

---

## 3. Vérification post-installation / upgrade

Vérifiez que le service iSCSI fonctionne correctement sur un worker :

talosctl services -n <IP_WORKER> --endpoints <IP_CONTROL_PLANE> --talosconfig ./talos-config/talosconfig | grep iscsi

Le service `iscsid` doit afficher l'état **OK / Running**. Tous les pods dans le namespace `longhorn` doivent être au statut **Running**.