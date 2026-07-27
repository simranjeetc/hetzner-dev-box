##############################################
# Personal Cloud Dev Box — Hetzner (default)
# Provider-swappable via IaC. See README.
##############################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
  cloud {
    organization = "hetzner-dev-simran"
    workspaces {
      name = "hetzner-box-simran-workspace"
    }
  }
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token (from Console > Security > API Tokens, Read/Write)"
  type        = string
  sensitive   = true
}

variable "server_name" {
  type    = string
  default = "personal-dev"
}

variable "server_type" {
  description = "CX32 = 8GB/4vCPU (Java-capable). CX42 = 16GB/8vCPU for heavy builds."
  type        = string
  default     = "cx32"
}

variable "location" {
  description = "sin = Singapore (closest to Bengaluru). Others: nbg1, fsn1, hel1, ash, hil."
  type        = string
  default     = "sin"
}

variable "image" {
  type    = string
  default = "ubuntu-24.04"
}

# Paths to PUBLIC keys for each device. Add/remove devices here.
variable "ssh_public_keys" {
  description = "Map of device-name => public key string. Each device keeps its own private key."
  type        = map(string)
}

provider "hcloud" {
  token = var.hcloud_token
}

# Register each device's public key
resource "hcloud_ssh_key" "keys" {
  for_each   = var.ssh_public_keys
  name       = each.key
  public_key = each.value
}

# Firewall: SSH + optional code-server (8443) restricted later if desired
resource "hcloud_firewall" "dev_fw" {
  name = "${var.server_name}-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  # code-server (browser IDE) over HTTPS — comment out if unused
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "8443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "dev" {
  name         = var.server_name
  server_type  = var.server_type
  image        = var.image
  location     = var.location
  ssh_keys     = [for k in hcloud_ssh_key.keys : k.name]
  firewall_ids = [hcloud_firewall.dev_fw.id]

  # Attach the reserved Primary IPv4 so the public IP is stable across rebuilds.
  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.dev.id
  }

  # cloud-init: installs full toolchain on first boot
  user_data = file("${path.module}/../cloud-init.yaml")

  labels = {
    purpose = "personal-dev"
    managed = "terraform"
  }

  # Tablet key was installed on the live box manually (non-destructive).
  # Suppress in-place drift-triggered replacement of the running server.
  # Creation still bakes in the full key set via ssh_keys/user_data, so a
  # fresh rebuild (destroy+apply) will still receive all device keys.
  lifecycle {
    ignore_changes = [ssh_keys, user_data]
  }
}

# Persistent DATA volume (Option A: pure data at /data, NOT /home/dev).
# Holds repos, uncommitted work, dotfiles, gh token, GitHub SSH key, herdr state.
# Toolchains stay on the ephemeral server SSD.
resource "hcloud_volume" "data" {
  name              = "personal-dev-data"
  size              = 50
  location          = var.location
  format            = "ext4"
  delete_protection = true

  labels = {
    purpose = "personal-dev"
    managed = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Reserved Primary IPv4: owned independently of the server so the box's
# public IP is STABLE across dev-down/dev-up rebuilds. auto_delete = false
# keeps the IP alive when the server is destroyed on dev-down.
resource "hcloud_primary_ip" "dev" {
  name        = "personal-dev-ip"
  type        = "ipv4"
  location    = var.location # Singapore ("sin"); provider now uses location, not datacenter
  auto_delete = false        # CRUCIAL: do NOT release the IP when the server is destroyed on dev-down

  delete_protection = true # API-side guard (same pattern as the volume)

  labels = {
    purpose = "personal-dev"
    managed = "terraform"
  }

  lifecycle {
    prevent_destroy = true # terraform-side guard (same pattern as the volume)
  }
}

# Attach the volume to the running server WITHOUT recreating it.
# automount = false: we mount manually to control the mount point (/data).
resource "hcloud_volume_attachment" "data" {
  volume_id = hcloud_volume.data.id
  server_id = hcloud_server.dev.id
  automount = false
}

output "server_ip" {
  value = hcloud_primary_ip.dev.ip_address
}

output "data_volume_id" {
  value = hcloud_volume.data.id
}

output "data_volume_device" {
  value = hcloud_volume.data.linux_device
}

output "ssh_command" {
  value = "ssh dev@${hcloud_primary_ip.dev.ip_address}"
}
