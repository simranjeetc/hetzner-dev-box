# Real tfvars. COMMITTED (safe: public keys + config only, no secrets).
# Token is NOT here — supplied via TF_VAR_hcloud_token env var / GitHub Actions secret.
# Required by the dev-up/dev-down workflows (terraform auto-loads this file).

server_name = "personal-dev"
server_type = "cpx32" # 4vCPU/8GB AMD, ~€49/mo cap in sin. SWITCHABLE — sin offers CPX/CCX lines only:
                     # cpx22 = 2/4GB ~€26 (cheapest dev tier) | cpx32 = current | cpx42 = 8/16GB ~€93.
                     # Budget cx/cax types are EU-only (region move = data migration + latency; see README).
                     # Switch = edit here + dev-down/dev-up (/data, IP, tailnet identity persist).
location    = "sin"   # Singapore (closest to Bengaluru, ~50ms).

# Each device = its own keypair. PUBLIC keys only. Private keys never leave their device.
# Tablet key to be added later (the one pasted in chat was a PRIVATE key = compromised, do NOT use).
ssh_public_keys = {
  worklaptop    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGWDov6ZN3qEfp4AABqepGpCz3CwU3xRTdvJ7IP5HzkW hetzner-worklaptop-20260727"
  tablet        = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxWQq1FTu/ctPIK87I8P2As7+kjbV1pD7CFbe96ljIF hetzner-tablet-20260727"
  simran-mac    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINGFN29HB+lYimrZIjyr3wmJKFVcXzbBQj3BbOY2U0Ze hetzner-simran-mac-20260808"
}
