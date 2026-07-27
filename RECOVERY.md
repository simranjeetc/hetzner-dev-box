# RECOVERY.md — break-glass runbook (tablet-only)

**Primary recovery runbook for the Hetzner dev box.** Reachable from any
browser/tablet when the laptop is gone. Everything here is doable with
**only**: GitHub web + Hetzner Cloud console + code-server/herdr on the box.
**No second laptop required.**

---

## 3-tier recovery model

| Tier | What | Survives |
|------|------|----------|
| **Tier 1** | This repo (GitHub) — the runbook + IaC (`terraform/`, `cloud-init.yaml`) | Forever (GitHub) |
| **Tier 2** | The `/data` volume — gh token, GitHub SSH key `/data/ssh/id_ed25519_github`, herdr/code-server/opencode config | Survives every rebuild (delete-protected) |
| **Tier 3** | **OFF-box password manager on the tablet** — the true break-glass creds that exist NOWHERE else recoverable | Only if you saved them |

Tiers 1 and 2 are automatic. **Tier 3 is on you** — see the checklist below.
If the laptop dies and Tier 3 is empty, you are locked out.

---

## Tier 3 checklist — SAVE TO A PASSWORD MANAGER BEFORE THE LAPTOP LEAVES

- [ ] **Hetzner Cloud console** login + **2FA recovery codes**
- [ ] **HCP Terraform** (Terraform Cloud) login
- [ ] **GitHub** login + **2FA recovery codes**
- [ ] **`HCLOUD_TOKEN`** value (raw string)
- [ ] **`TF_API_TOKEN`** value (raw string)
- [ ] **Hetzner volume ID `106470959`** + its region

> ⚠️ **The two tokens are the danger.** `HCLOUD_TOKEN` and `TF_API_TOKEN`
> currently exist ONLY as:
> 1. files on the laptop — `labs/.hetzner-api-token`, `labs/.tf-api-token`, and
> 2. **write-only** GitHub Actions secrets (you CANNOT read them back out of GitHub).
>
> If the laptop dies, they are **UNRECOVERABLE** unless copied to the password
> manager **now**. Do it before the laptop leaves.

---

## Normal operations (from the tablet)

All control is via **GitHub → Actions tab**.

### Bring the box up / down
1. GitHub → **Actions** tab.
2. Select the **`dev-up`** (or **`dev-down`**) workflow.
3. **Run workflow** → confirm.

### Get the new IP
- Open the finished **`dev-up`** job → **job summary** shows the box IP.
  (IP changes each rebuild.)

### Reach the box
- **code-server:** open `https://<ip>:8443` in the tablet browser (accept the
  self-signed cert; password lives in `/data/code-server/config/config.yaml`,
  preserved across rebuilds).
- **SSH app:** Termius / JuiceSSH / Blink → `dev@<ip>`.
- code-server is **on-demand**: `systemctl --user start code-server` after SSH in.

### Volume-preservation guarantee
- **`dev-down` NEVER destroys `/data`.** It is protected by Terraform
  `prevent_destroy` + Hetzner `delete_protection`. Volume id **`106470959`**.

---

## Failure playbooks

### `dev-up` fails
1. Open the failed job → read **Actions logs**.
2. Fix the obvious cause (expired token → see below), then **re-run** the workflow.

### Box unreachable but Actions is green
- cloud-init is still provisioning — **wait a few minutes**.
- Clear the stale host key from your SSH app: `ssh-keygen -R <ip>`.
- Re-try SSH.
- Once in, check:
  ```bash
  cat /var/log/cloud-init-output.log      # full provisioning log
  ls -l ~/.provision-complete             # marker = provisioning finished
  ```

### cloud-init half-provisioned / degraded
- SSH in and inspect the log, focusing on non-fatal warnings:
  ```bash
  grep WARN: /var/log/cloud-init-output.log
  ```
  (dotfiles clone + `setup.sh` are **non-fatal** and log `WARN:` on failure.)
- Re-run the dotfiles setup manually:
  ```bash
  bash ~/dotfiles/setup.sh
  ```

### GitHub secret expired / rotated
- GitHub → **Settings → Secrets and variables → Actions**.
- Re-set **`HCLOUD_TOKEN`** and/or **`TF_API_TOKEN`**.
- **Requires the Tier-3 token copies** (you cannot read the old ones back).

### Worst case — `/data` volume lost
Full rebuild from scratch:
1. Provision a fresh `/data` (cloud-init formats + mounts a new volume).
2. The box generates a **new** GitHub SSH key at `/data/ssh/id_ed25519_github`
   on first boot.
3. Add its **PUBLIC** half to GitHub:
   ```bash
   cat /data/ssh/id_ed25519_github.pub
   ```
   GitHub → **Settings → SSH and GPG keys → New SSH key** (needs GitHub login
   from Tier 3).
4. Re-run **`dev-up`**.
5. opencode + dotfiles re-provision **automatically** from the dotfiles repo.

---

## Dictation from the tablet

- Use **Gboard mic** and **download the on-device language pack** for
  offline / continuous dictation.
- Dictate into **code-server-in-browser** or an SSH app (Termius / JuiceSSH / Blink).
- Best use: **natural-language opencode prompting** — describe intent, let the
  agent write the exact shell commands.
- Raw shell symbols (`--ref`, pipes `|`, slashes `/`) are fiddly by voice — let
  opencode type those for you.

---

## Vendor portability note

The setup is **mostly portable** (cloud-init + dotfiles). To move off Hetzner,
change these Hetzner-specific bits:

- The `/data` device glob in `cloud-init.yaml`:
  `/dev/disk/by-id/scsi-0HC_Volume_*` → new vendor's stable device path.
- The entire **`terraform/`** provider + resources (`hcloud_*` → new vendor
  equivalents).
- The **HCP backend** org/workspace.
- The image slug **`ubuntu-24.04`**.
