# Homelab

Bienvenue dans le dépôt de mon Homelab. Ce projet regroupe les configurations, scripts d'automatisation et définitions d'infrastructure permettant de gérer l'ensemble des services auto-hébergés.

L'ensemble de l'infrastructure tourne sous Proxmox VE (sur un serveur dédié Dell OptiPlex).

## Structure du Dépôt

Le projet est découpé par architectures ou environnements distincts :

- **docker/** : Infrastructure Homelab actuelle (Docker / Docker Compose)
- **talos/** : Nouvelle infrastructure Kubernetes sous Talos Linux
  - **ansible/** : Playbooks de déploiement, bootstrap et FluxCD
  - **terraform/** : Provisioning des VMs sur Proxmox
  - **charts/** : Helm charts et manifests Kubernetes
- **README.md**

### 1. docker/ (Actuel)
Contient l'architecture en production basée sur Docker Compose. Tous les services du homelab y sont exécutés sous forme de conteneurs autonomes sur une VM ou machine dédiée.

### 2. talos/ (Migration en cours)
Contient la nouvelle architecture basée sur un cluster Kubernetes (Talos Linux) provisionné de manière déclarative :
- **Terraform** : Création dynamique des nœuds (Control Plane & Workers) sur Proxmox.
- **Ansible** : Automatisation du bootstrap du cluster et du déploiement de FluxCD.
- **FluxCD** : Gestion du cluster en GitOps.

## Informations Pratiques & Prérequis

- **Hyperviseur** : Proxmox VE
- **CLI requises localement** : `terraform`, `ansible`, `talosctl`, `kubectl`, `flux`, `jq`

## Déploiement Rapide (Talos)

Pour provisionner et bootstrapper l'environnement Talos depuis la racine :

```bash
cd talos
./deploy.sh