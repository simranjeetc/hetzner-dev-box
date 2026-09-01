# hetzner-dev-box

Infrastructure-as-code for a personal **Hetzner Cloud** dev box.
Server: `cpx32` (4 vCPU / 8 GB AMD), Singapore (`sin`). Terraform + cloud-init.
See [`AGENTS.md`](./AGENTS.md) for the moving parts and where each secret lives.

---

## Operating from a tablet (runbook stub)

Day-to-day control is done from a tablet — no laptop required.

| Action | How |
|--------|-----|
| **dev-up** | GitHub → **Actions → dev-up → Run workflow**. Runs `terraform apply`. Server IP is printed to the run summary. |
| **dev-down** | GitHub → **Actions → dev-down → Run workflow**. Destroys **compute only** (server + firewall + keys). Compute billing stops. `/data` volume persists (delete-protected). |
| **SSH in** | Termius → `dev@<ip>`, using the tablet's SSH key. |
| **Get the IP** | Read it straight off the **dev-up** run summary (`server_ip`). The public IP may change on rebuild. |

> ⚠️ Hetzner bills hourly. A **powered-off** server still bills — only `dev-down` (destroy) stops compute charges.
> Persistent work lives on the `/data` volume and survives destroy/rebuild.

Secrets: Hetzner token → Bitwarden → GitHub Actions secret (`TF_VAR_hcloud_token`).
TF state → HCP Terraform. `gh` token + GitHub SSH key → `/data` volume. Dotfiles → private repo `simranjeetc/dotfiles`.

---

## What you get on the box
- Ubuntu 24.04, non-root `dev` user, hardened SSH, ufw + fail2ban
- Java 21 (SDKMAN) + Maven + Gradle
- Node LTS (nvm)
- Python (uv)
- Go 1.23
- Docker + compose
- opencode
- Claude Code
- Tailscale (private tailnet — see Mobile access below)

## Mobile access (phone/tablet, via Tailscale)
The box joins a private WireGuard tailnet; its identity lives on `/data`, so it
rejoins automatically after every `dev-down`/`dev-up` (one-time auth only, done
at first join).

| Access | How |
|--------|-----|
| **opencode web UI** | Install **Tailscale** app → sign in (same account as the box) → enable VPN → open `https://personal-dev.<tailnet>.ts.net/` in Safari |
| **SSH from phone** | Any SSH client → `dev@personal-dev` (Tailscale SSH — no key needed), or `ssh dev@<tailscale-ip>` |

The web UI runs via the always-on `opencode-serve` systemd --user unit (bound
to `127.0.0.1:4096`), proxied to tailnet-HTTPS by `tailscale serve`. Nothing is
exposed on the public internet.

## Cost
- **cpx32** (4vCPU/8GB): **€0.093/hr**, **€58/mo cap** running 24/7
- 10-15 day gap destroyed-when-idle: **~€8-10** (only active-use hours)
- Snapshot billing: **~€0.0119/GB/month** → a few-GB image ≈ cents/month

> ⚠️ A merely stopped (powered-off) server STILL BILLS. Only **destroying** the resource stops compute charges.

## Machine types — switch anytime
The only switch to flip is `server_type` in `terraform/terraform.tfvars`. Changing it =
`dev-down` → edit → `dev-up`. `/data`, the reserved IP, and the Tailscale identity all
persist through the rebuild, so switching costs ~10 min of provisioning and nothing else.
Note: a rebuild reprices the server at Hetzner's current rates.

| Type | vCPU/RAM | ~€/mo (sin) | Use for |
|------|----------|-------------|---------|
| `cx23` / `cax11` | 2/4GB | ~€7–8 | Python/Node dev — JVM/Gradle builds are painful on 4GB |
| `cx33` / `cax21` | 4/8GB | ~€12–14 | + Java builds, parallel toolchains |
| `cpx32` **(current)** | 4/8GB | ~€55–58 | AMD + 160GB NVMe headroom |
| `cpx42` | 8/16GB | ~€95+ | Heavy builds — temporary upsize, then switch back |

ARM caveat (`cax*`): Java/Python/Node are fine on ARM; check that herdr/opencode and any
prebuilt binaries ship ARM64 before switching. Intel CX line availability in `sin` varies —
if `cx23`/`cx33` is sold out, `cax11`/`cax21` is the fallback.
A 2GB swapfile is provisioned by cloud-init on every rebuild (cushion for the 4GB tiers).

---

## Prerequisites
- Terraform >= 1.5 (`brew install terraform`)
- Hetzner account + project + **API token** (Console > Security > API Tokens > Read & Write)
- One SSH keypair **per device** (private key stays on device)

## Multi-device keys
Each device gets its own keypair. All PUBLIC keys go in `ssh_public_keys` (`terraform/terraform.tfvars`).
Remove a device = delete its line + `terraform apply`. Revokes access instantly.

---

## Local (manual) Terraform — advanced / break-glass
Normal flow is via GitHub Actions. To run locally:
```bash
cd terraform
export TF_VAR_hcloud_token=...        # Hetzner Cloud API token (never committed)
terraform init
terraform plan
terraform apply
```
Output prints `server_ip` and `ssh_command`. First boot runs cloud-init (~5-10 min).

Check provisioning finished:
```bash
ssh dev@<server_ip> 'ls -la ~/.provision-complete && tail -n 20 /var/log/provision.log'
```

Dotfiles (`simranjeetc/dotfiles`) are **auto-applied** by cloud-init: clone → oh-my-zsh
(unattended) → `setup.sh` → JetBrainsMono Nerd Font → default shell `zsh`. All idempotent,
so a rebuilt box comes up fully configured with no manual dotfiles step.

---

## Idle / Cost-Control
Prefer the `dev-down` GitHub Action. A powered-off server still bills — only `terraform destroy`
(what `dev-down` runs) stops compute charges. The `/data` volume is delete-protected and persists.

### Before you destroy (checklist)
- [ ] Commit & push **all repos** on the box to GitHub
- [ ] Confirm **dotfiles pushed** (nothing config-only-on-box)
- [ ] Note anything that exists **only on the box** and not on `/data`

---

## Provider swap (zero lock-in)
Want lower latency from Bengaluru (~5-15ms)? Switch to DigitalOcean Bangalore:
1. Add DO provider block + `digitalocean_droplet` resource (mirrors `hcloud_server`)
2. Reuse the SAME `cloud-init.yaml` (provider-agnostic)
3. `terraform apply`

The config layer (cloud-init) never changes; only the provisioning layer swaps.

---

## Files
- `terraform/main.tf` — infra (server, firewall, keys, `/data` volume)
- `terraform/terraform.tfvars` — server config + **public** keys only (safe to commit)
- `terraform/terraform.tfvars.example` — template
- `terraform/.terraform.lock.hcl` — provider lock (committed)
- `cloud-init.yaml` — box configuration (toolchain install + dotfiles)
- `gap-dev-setup.md` — living tracker doc
- `.gitignore` — keeps secrets/state out of git

## Security notes
- `terraform.tfvars` holds only public keys + config → safe to commit
- `*.tfstate` lives in HCP Terraform, never committed
- SSH: password auth disabled, key-only
- Remove work-laptop key before returning a company laptop
