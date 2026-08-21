# Configuration Proxmox (PVE)
variable "proxmox_endpoint" {
  type        = string
  description = "L'adresse API de votre serveur Proxmox (ex: https://192.168.1.100:8006/)"
}

variable "proxmox_ip" {
  type        = string
  description = "L'adresse IP de votre serveur Proxmox (ex: 192.168.1.10)"
}


variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "Le token d'API Proxmox (format: USER@PAM!TOKENID=SECRET)"
}

variable "proxmox_node_name" {
  type        = string
  description = "Le nom de votre nœud Proxmox hyperviseur"
}

variable "gateway" {
  type        = string
  description = "L'ip de la gateway du réseau"
}

variable "nodes" {
  type = map(object({
    vmid = number
    role = string
    cpu  = number
    ram  = number
    disk = number
    ip   = string
  }))
  default = {
    "cp-1" = {
      vmid = 2000
      role = "controlplane"
      cpu  = 2
      ram  = 4096
      disk = 10
      ip   = "dhcp"
    }
    "worker-1" = {
      vmid = 2001
      role = "worker"
      cpu  = 4
      ram  = 8192
      disk = 10
      ip   = "dhcp"
    }
  }
}