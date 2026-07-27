# Gap Survival & Long-Term Dev Setup — Living Doc

**Owner:** Simranjeet
**Context:** Handing back work laptop in ~3-4 days. 10-15 day gap before next job. No personal laptop (by choice — idle-waste). Hands-on principal architect + developer. Have Android tablet + Bluetooth keyboard + mouse (already paired).

**Strategy:** Tablet = thin client. Cloud VM (Hetzner) = real dev power. Destroy/snapshot VM when idle → zero idle-waste. Keep env portable via dotfiles → device-independent forever.

**Budget:** <$50 for the gap. Long-term ~€0.50/mo idle.

---

## Decisions (locked)

- [x] No personal laptop. Cloud VM instead.
- [x] Client device: existing Android tablet + BT keyboard + mouse.
- [x] Provider: **Hetzner Cloud** (cheapest real Linux box).
- [x] VM size: **cpx32 (8GB RAM, 4 vCPU AMD)**. NOTE: cheap Intel `cx` line was SOLD OUT everywhere at build time; `cpx` (AMD) is the available 8GB tier. Bump to cpx42 (16GB) for heavy builds.
- [x] Access: SSH from tablet (Termius) + optional browser IDE (code-server).
- [x] Region: **Singapore** (closest to Bengaluru; ~40-60ms). Helsinki cpx32 was ~28% cheaper cap but ~130ms; over a destroy-when-idle gap the € difference is ~€2, so latency won.

## LIVE BOX (current) — ✅ LIVE & VERIFIED
- **Server:** `personal-dev` — cpx32 (4 vCPU / 8GB AMD), image `ubuntu-24.04`, Hetzner Cloud **Singapore (sin)**. Hetzner server id `155698245`.
- **IP:** `5.223.93.164`
- **User:** `dev` (non-root, sudo, docker group)
- **Connect:** `ssh -i ~/.ssh/hetzner_worklaptop dev@5.223.93.164`
- **Toolchains verified (login shell):** Java 21.0.5 LTS, Maven 3.9.16, Gradle 9.6.1, Node 24.18.0 / npm 11.16.0, uv (Python) 0.11.32, Go 1.23.4, Docker 29.6.2, opencode 1.18.6.
- **Hardening applied:** ufw (OpenSSH + 8443), `PasswordAuthentication no`, fail2ban, firewall ports **22 + 8443** open.
- **Build proof:** cloned Apache Commons Lang + ran a full **online** Maven build in ~25s (exit 0), peak memory only ~623Mi of 7.6Gi — 8GB confirmed ample.
- **Cost:** ~€0.093/hr. Destroy-when-idle model → ~€6-10 for the gap.
- **Terraform:** `cloud-dev/terraform/`; token in gitignored `.hetzner-api-token`, loaded via `export TF_VAR_hcloud_token="$(cat ~/codebase/simranjeetc/labs/.hetzner-api-token | tr -d '[:space:]')"`. `terraform fmt` + `validate` pass.
- [x] Toolchains: Java, Node/JS, Python, Go, Docker.
- [x] Latency note: if Singapore feels laggy for interactive IDE, prefer terminal+opencode over GUI; or consider a India-region provider (DigitalOcean Bangalore) as alternative — see Notes.
- [x] Long-term: keep VM as personal cloud dev box; snapshot when idle (~€0.50/mo).

> **Provisioning note:** This box was provisioned **manually** because the original cloud-init aborted at the SDKMAN `source` line (a `set -u` unbound-variable bug). The cloud-init IaC has since been **FIXED** — dropped `-u`, added `set +u` guards, a PATH-to-rc loop, and a global `/etc/profile.d/00-dev-toolchains.sh` drop — so future clean rebuilds provision unattended.

---

## Task Tracker

### Phase 0 — Pre-migration (DO on work laptop, next 3 days) — ⏳ PENDING
- [ ] Push ALL personal repos to GitHub (nothing stranded on work machine)
- [ ] Create `dotfiles` repo (shell config, git config, opencode config, aliases)
- [ ] List tools/toolchain you use (languages, versions, CLIs) → for VM setup script
- [ ] Note which API keys/tokens you need (regenerate on VM — do NOT copy company secrets)
- [ ] Install **Termius** on tablet; test one SSH connection works
- [ ] Confirm GitHub SSH/PAT access from a non-work context

> **NOTE:** Provisioning + hardening + toolchain install are now fully automated via IaC
> in `cloud-dev/` (Terraform + cloud-init). Phases 2-3 below happen automatically on `terraform apply`.
> See `cloud-dev/README.md` for the runbook.

### Phase 1 — Hetzner account + SSH keys
- [x] Work-laptop keypair generated (`~/.ssh/hetzner_worklaptop`) — ACTIVE on VM
- [ ] Tablet keypair generated in Termius (Ed25519, fresh public-only key) + public key added to VM
- [x] Create Hetzner Cloud account + project `personal-dev`
- [x] Generate Hetzner API token (Read & Write)
- [x] Fill `cloud-dev/terraform/terraform.tfvars` (token + work-laptop public key)

### Phase 2 — Provision VM (AUTOMATED via Terraform) — ✅ DONE (manual this round)
- [x] `terraform plan` → review
- [x] `terraform apply` → server + firewall + SSH keys created (this box was completed manually; see LIVE BOX provisioning note)
- [x] First SSH login, verify access (`ssh dev@5.223.93.164`)
- [x] Hardening automated in cloud-init (non-root `dev` user, ufw, disable password auth, fail2ban)

### Phase 3 — VM dev environment (AUTOMATED via cloud-init) — ✅ DONE
- [x] Base: git, curl, build-essential, zsh
- [x] opencode
- [x] Java 21 (SDKMAN) + Maven + Gradle
- [x] Node LTS (nvm), Python (uv), Go 1.23, Docker
- [x] Verify `/home/dev/.provision-complete` marker after first boot
- [x] Clone repos, test a Java build (Apache Commons Lang, full online Maven build ~25s, exit 0)
- [x] Install Java toolchain (SDKMAN → JDK + Maven/Gradle)
- [x] Install other stacks as needed (Node/Python/Go)
- [ ] Clone dotfiles, apply config
- [ ] Clone personal/open-source repos, test a build

### Phase 4 — Tablet client polish — ⏳ PENDING
- [ ] Termius profile saved (host, key, user)
- [ ] (Optional) Install code-server on VM for browser IDE
- [ ] Test full loop: tablet → SSH → opencode → build → runs OK

### Phase 5 — Long-term / idle workflow — ⏳ PENDING
- [ ] Take VM snapshot before next job starts
- [ ] Destroy running VM (stop paying compute) OR power off
- [ ] Keep snapshot only (~€0.50/mo)
- [ ] Document "boot from snapshot" steps for future gaps

---

## Hetzner Setup Guide (Phase 1-2 detail)

### Account
1. Go to https://www.hetzner.com/cloud → Sign up
2. Verify email + identity (may ask ID for first account — normal, anti-fraud)
3. Add payment method
4. Open **Hetzner Cloud Console** → create a **Project** (e.g. "personal-dev")

### SSH key (do this before creating server)
On tablet (Termius can generate) or any machine:
```
ssh-keygen -t ed25519 -C "personal-dev" -f ~/.ssh/hetzner_dev
```
- Keep private key safe (Termius stores it). Copy **public** key (`hetzner_dev.pub`).
- In Hetzner Console → Project → Security → SSH Keys → Add → paste public key.

### Create server
- Console → Add Server
- **Location:** nearest to you (lower latency)
- **Image:** Ubuntu 24.04
- **Type:** Shared vCPU → **CX32** (8GB / 4 vCPU)
- **SSH key:** select the one added above
- **Name:** personal-dev
- Create → note the **public IPv4**

### First login (from Termius on tablet)
```
ssh root@<PUBLIC_IP> -i ~/.ssh/hetzner_dev
```

### Quick hardening
```
adduser dev && usermod -aG sudo dev
rsync --archive --chown=dev:dev ~/.ssh /home/dev
ufw allow OpenSSH && ufw enable
# edit /etc/ssh/sshd_config: PasswordAuthentication no
systemctl restart ssh
```

---

## Multi-Device SSH Key Strategy (IMPORTANT)

Access from multiple devices over time (work laptop now → tablet → future new laptop).
**Rule: each device gets its OWN keypair. Private key never leaves its device. All public keys added to VM.**

| Device | Keypair name | Private key on | Status |
|--------|-------------|----------------|--------|
| Work laptop | `hetzner_worklaptop` | work laptop (TEMP) | [x] ACTIVE on VM |
| Tablet (Termius) | `hetzner_tablet` | tablet | [ ] pending (fresh public-only key to generate in Termius + add to VM) |
| Future new laptop | `hetzner_newlaptop` | new laptop | [ ] future |

- **Tablet key = the anchor** (always-present device). Generate it before laptop goes back.
- **⚠️ Remove work-laptop public key from VM before handing laptop back.**
- Losing/retiring a device = just delete its one public key. Others unaffected.

### Work-laptop PUBLIC key (safe to paste to Hetzner)
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGWDov6ZN3qEfp4AABqepGpCz3CwU3xRTdvJ7IP5HzkW hetzner-worklaptop-20260727
```

## Notes / Open Questions
- Add ALL device public keys to server at creation (Hetzner supports multiple).
- Tablet keypair: generate in Termius → Keychain → paste its public key into Hetzner too.
- (to fill as we go)

---

*Living doc — update checkboxes and notes as tasks complete.*
