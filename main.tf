terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.60.0"
    }
  }
}

provider "proxmox" {
  # Remplace par l'IP de ton Proxmox
  endpoint = local.cfg.proxmox.endpoint
  
  # Remplace par ton Token d'API Proxmox
  api_token = local.cfg.proxmox.api_token
  
  # Indispensable pour les certificats auto-signés
  insecure  = true 
}

locals {
  cfg = yamldecode(file("${path.module}/config.yml"))
  
  # On transforme la liste des conteneurs en une map indexée par hostname pour le for_each
  lxc_map = { for c in local.cfg.containers : c.hostname => c }
}

# CRÉATION DU CONTENEUR LXC DEBIAN 13
resource "proxmox_virtual_environment_container" "container_debian_13" {

  for_each = local.lxc_map

  # Nom de ton nœud Proxmox ("proxmox")
  node_name = local.cfg.proxmox.node_name
  
  # L'ID que tu veux attribuer au conteneur (ex: 901)
  vm_id = each.value.vm_id    
  
  # Conteneur non-privilégié (sécurisé)
  unprivileged = true

  start_on_boot = true

  started = false

  tags = each.value.tags

  # Utilisation de ton template Debian 13
  operating_system {
    template_file_id = each.value.template
    type             = each.value.type
  }

  # Configuration du réseau et du système au démarrage
  initialization {
    hostname = each.value.hostname

    ip_config {
      ipv4 {
        address = each.value.address
        gateway = each.value.gateway
      }
    }

    dns {
      # Adresse IP de ton serveur AdGuard Home
      servers = [each.value.dns_server]
    }

    user_account {
      # Clé SSH publique pour qu'Ansible puisse s'y connecter
      keys     = each.value.keys
    }
  }

  # Ressources de la machine
  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
    swap = each.value.memory
  }

  disk {
    datastore_id = each.value.datastore_id
    size         = each.value.disk_size
  }

  features {
    nesting = each.value.nesting
  }

  network_interface {
    name   = each.value.network_interface_name
    bridge = each.value.network_interface_bridge
  }
}