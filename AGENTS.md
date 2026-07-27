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
