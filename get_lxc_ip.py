#!/usr/bin/env python3
import subprocess
import re
import time
import yaml
import sys

def get_proxmox_ct_ip(vmid):
    try:
        # Interrogation de Proxmox via SSH pour ce VMID particulier
        cmd = f"ssh -i ~/.ssh/id_25519_ansible -o StrictHostKeyChecking=no root@192.168.1.100 'pct exec {vmid} -- ip -4 addr show eth0'"
        result = subprocess.check_output(cmd, shell=True, text=True)
        
        match = re.search(r'inet\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', result)
        if match:
            return match.group(1)
    except Exception as e:
        print(f"Erreur pour le CT {vmid} : {e}")
    return None

if __name__ == "__main__":
    # 1. Charger le fichier config.yml complet
    with open("config.yml", "r") as f:
        config = yaml.safe_load(f)
    
    # Laisser 8 secondes globales pour que les conteneurs démarrent
    print("[Python] Attente du démarrage des conteneurs (DHCP)...")
    time.sleep(8)
    
    # 2. Construire la structure de l'inventaire Ansible
    inventory = {
        "all": {
            "hosts": {}
        }
    }
    
    # 3. Boucler sur chaque conteneur défini dans le YAML
    for ct in config.get("containers", []):
        hostname = ct["hostname"]
        vmid = ct["vm_id"]
        
        print(f"[Python] Récupération de l'IP pour {hostname} (ID: {vmid})...")
        ip = get_proxmox_ct_ip(vmid)
        
        if ip:
            # On ajoute la machine à l'inventaire
            inventory["all"]["hosts"][hostname] = {
                "ansible_host": ip,
                "ansible_user": "root",
                "ansible_ssh_private_key_file": "~/.ssh/id_25519_ansible",
                "ansible_ssh_common_args": "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
            }
        else:
            print(f"⚠️ Impossible de récupérer l'IP pour {hostname}")
            
    # 4. Écrire le fichier hosts.yml final
    with open("hosts.yml", "w") as f:
        yaml.dump(inventory, f, default_flow_style=False)
        
    print("[Python] Fichier hosts.yml mis à jour avec TOUTES les IPs !")