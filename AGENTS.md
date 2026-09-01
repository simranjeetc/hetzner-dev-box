# AGENTS.md — signpost for agents & humans

**This repo = infrastructure-as-code for a personal Hetzner Cloud dev box.**
Server: `cpx32` (4 vCPU / 8 GB AMD), location `sin` (Singapore, ~50ms from Bengaluru).
Provisioned via Terraform + cloud-init. Controlled from a tablet via GitHub Actions.

---

## What lives here

| File | Purpose |
|------|---------|
| `terraform/main.tf` | Server, firewall, SSH keys, persistent 50GB `/data` volume (delete-protected). |
| `terraform/terraform.tfvars` | Server config + **public** SSH keys only. No secrets. Committed. |
| `terraform/terraform.tfvars.example` | Template. |
| `terraform/.terraform.lock.hcl` | Provider version lock. Committed. |
| `cloud-init.yaml` | First-boot provisioning: toolchain + applies dotfiles. |
| `README.md` | Operator runbook (tablet workflow). |
| `gap-dev-setup.md` | Living tracker doc for the overall setup. |

---

## Related repos

- **Dotfiles (PRIVATE):** `simranjeetc/dotfiles`
  Clone with: `gh repo clone simranjeetc/dotfiles`
  `cloud-init.yaml` pulls and applies these on first boot. **Do NOT clone into this repo.**

---

## How it runs

- **TF token:** `export TF_VAR_hcloud_token=...` (Hetzner Cloud API token). Never committed.
- **State backend:** HCP Terraform (Terraform Cloud) free tier. State never lives in this repo.
- **Control plane:** GitHub Actions `dev-up` / `dev-down` workflows (`workflow_dispatch`),
  triggered from the tablet.
- **Tailnet access:** Tailscale (`--ssh`) joins the box to a private WireGuard
  overlay; node identity persists on `/data` so rebuilds rejoin silently. The
  opencode web UI is served at `https://personal-dev.<tailnet>.ts.net/` via
  `tailscale serve` (proxying the always-on `opencode-serve` systemd --user
  unit, bound to 127.0.0.1). Phone: Tailscale app + Safari. No public exposure.
- **Persistent storage:** Hetzner volume `personal-dev-data` mounted at `/data`.
  Holds repos, uncommitted work, dotfiles, gh token, GitHub SSH key, herdr state.
  Toolchains stay on the ephemeral server SSD.

---

## Where each secret lives

| Secret | Home |
|--------|------|
| Hetzner API token | Bitwarden → injected as a GitHub Actions secret (`TF_VAR_hcloud_token`) |
| Terraform state | HCP Terraform (remote backend) |
| `gh` auth token | `/data` volume (persistent, survives destroy/rebuild) |
| GitHub SSH key | `/data` volume |
| Dotfiles | Private repo `simranjeetc/dotfiles` |

**Never** commit: `.hetzner-api-token`, `*.tfstate*`, `*.pem`, private keys.
`terraform.tfvars` is safe to commit — it holds only public keys + config.

---

## Guardrails for agents

- Do NOT run `terraform apply` / `destroy` without explicit human go-ahead.
- Do NOT commit secrets — check `git status` before every push.
- The live box is stateful; treat `/data` and the volume as sacred (delete-protected).

---

## Storage layout & install intent (for agents operating ON the box)

**`/data` is the ONLY persistent volume** — it survives every `dev-down` / `dev-up`
rebuild. The **OS disk is EPHEMERAL** and is wiped on every rebuild.

**Tool binaries live on the OS disk on purpose and self-reinstall each rebuild**
(opencode, Claude Code, herdr, code-server, nvim, node/nvm, uv, ripgrep, fzf, lazygit, etc.).
Only these are version-pinned in `cloud-init.yaml`: **Go 1.23.4**, **Java 21.0.5-tem**,
**nvm v0.40.1**, **opencode** (exact version), **Claude Code** (release channel, default
`stable`). Everything else tracks latest.

### What persists (on `/data`, symlinked from `$HOME`)

| Item | Path |
|------|------|
| gh auth token | `/data/gh-config` (via `GH_CONFIG_DIR`) |
| Tailscale node identity (stable 100.x IP, `tailscale serve` config) | `/data/tailscale-state` — box rejoins the tailnet on every rebuild, no re-auth |
| Claude Code config/credentials/sessions | `/data/claude-config` (via `CLAUDE_CONFIG_DIR`) — `CLAUDE.md`/`agents/`/`scripts/` are dotfiles-sourced (version history in `simranjeetc/dotfiles`, under `claude/`); edit there, not the persisted copy only |
| GitHub SSH key | `/data/ssh/id_ed25519_github` |
| herdr config | `~/.config/herdr` → `/data/herdr-config` |
| code-server config | `~/.config/code-server` → `/data/code-server/config` |
| code-server share | `~/.local/share/code-server` → `/data/code-server/share` |
| opencode config | `~/.config/opencode` → `/data/opencode-config` |
| repos + uncommitted work | put them under a `/data`-backed path |

### Install guidance for agents

- Anything whose **DATA must survive a rebuild belongs on `/data`**: clone repos
  under a `/data`-backed path, and put any persistent state there.
- Do NOT rely on `~/` or `/var/lib` (outside `/data`) for durable data — it is wiped.
- **Docker images/containers/volumes do NOT persist** — the data-root is the default
  `/var/lib/docker` on the ephemeral disk. Treat containers as disposable, rebuild
  from Dockerfiles, and keep durable data on `/data`.
