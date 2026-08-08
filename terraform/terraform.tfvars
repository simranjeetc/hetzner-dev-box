# Real tfvars. GITIGNORED. Token is NOT here — supplied via TF_VAR_hcloud_token env var.
# See sourced from ../../.hetzner-api-token at apply time.

server_name = "personal-dev"
server_type = "cpx32" # 4vCPU/8GB AMD (cx Intel line sold out everywhere). ~€0.093/hr, €58/mo cap.
location    = "sin"   # Singapore (closest to Bengaluru, ~50ms). cpx42=16GB heavy builds.

# Each device = its own keypair. PUBLIC keys only. Private keys never leave their device.
# Tablet key to be added later (the one pasted in chat was a PRIVATE key = compromised, do NOT use).
ssh_public_keys = {
  worklaptop    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGWDov6ZN3qEfp4AABqepGpCz3CwU3xRTdvJ7IP5HzkW hetzner-worklaptop-20260727"
  tablet        = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxWQq1FTu/ctPIK87I8P2As7+kjbV1pD7CFbe96ljIF hetzner-tablet-20260727"
  chandanlaptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOIHUhAaWnvnFa4JnLlptMbTYDO4AKLSVQKIVT88/bnt hetzner-chandanlaptop-20260729"
  simran-mac    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINGFN29HB+lYimrZIjyr3wmJKFVcXzbBQj3BbOY2U0Ze hetzner-simran-mac-20260808"
}
