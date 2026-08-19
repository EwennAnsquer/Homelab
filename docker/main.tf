terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.60.0"
    }
  }
}

variable "proxmox_api_token" {
  type        = string
  description = "Token d'API Proxmox déchiffré depuis Ansible Vault"
  sensitive   = true # Masque la valeur dans les logs d'exécution
}

provider "proxmox" {
  # Remplace par l'IP de ton Proxmox
  endpoint = local.cfg.proxmox.endpoint
  
  # Remplace par ton Token d'API Proxmox
  api_token = var.proxmox_api_token
  
  # Indispensable pour les certificats auto-signés
  insecure  = true 

  # Configuration SSH requise pour la manipulation des disques de VM
  ssh {
    username    = "root"
    private_key = file("~/.ssh/ansible")
  }
}

locals {
  cfg = yamldecode(file("${path.module}/inventory/group_vars/all/vars.yml"))
  
  # On transforme la liste des conteneurs en une map indexée par hostname pour le for_each
  lxc_map = { for c in local.cfg.containers : c.hostname => c }

  vm_map = { for v in local.cfg.virtual_machines : v.hostname => v }
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

output "docker_container_status" {
  description = "Statut de la ressource conteneur docker"
  value       = proxmox_virtual_environment_container.container_debian_13["docker"].id
}

resource "proxmox_virtual_environment_download_file" "vm_image" {

  for_each = local.vm_map

  content_type            = "iso"
  datastore_id            = "local"
  node_name               = local.cfg.proxmox.node_name
  url                     = each.value.url
  file_name               = each.value.filename
  decompression_algorithm = "zst"
  overwrite               = false
}

resource "proxmox_virtual_environment_vm" "homeassistant" {

  for_each = local.vm_map

  name        = each.value.hostname
  node_name   = local.cfg.proxmox.node_name
  vm_id       = each.value.vm_id

  bios = each.value.bios

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = "local-lvm"
    file_id      = proxmox_virtual_environment_download_file.vm_image[each.key].id
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = each.value.disk_size
  }

  network_device {
    model  = each.value.network_interface_model
    bridge = each.value.network_interface_bridge
    mac_address = each.value.mac_address
  }

  operating_system {
    type = each.value.operating_system
  }

  agent {
    enabled = true
  }

  usb {
    mapping = "sonoff-matter-over-thread-key"
  }

  boot_order = ["scsi0"]
}