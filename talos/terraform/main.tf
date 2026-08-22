resource "proxmox_virtual_environment_vm" "talos_nodes" {
  for_each  = var.nodes
  name      = each.key
  node_name = var.proxmox_node_name
  vm_id     = each.value.vmid

  boot_order = ["scsi0"]

  bios    = "ovmf"
  machine = "q35"

  cpu {
    type  = "host"
    cores = each.value.cpu
  }

  memory {
    dedicated = each.value.ram
    floating  = 0
  }

  scsi_hardware = "virtio-scsi-single"

  clone {
    vm_id = 9000
  }

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }

  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi0"
    size         = each.value.disk
    cache        = "writethrough"
    iothread     = true
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
    timeout = "15m"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }
  }
}