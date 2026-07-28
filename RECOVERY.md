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

### opencode version pinning / deliberate upgrade
The installed opencode version is **pinned**, not `latest`. cloud-init reads the
pin from `/data/opencode-config/OPENCODE_VERSION` (default **`1.18.6`**) and
installs exactly that on every rebuild, so the tool never drifts against the
persistent config on `/data`.

**Deliberate (staged/canary) upgrade — box is up on pinned `X`:**
1. Back up config: `git -C ~/.config/opencode commit -am "pre-upgrade backup"`
   (or otherwise snapshot `/data/opencode-config`).
2. Upgrade in place to the candidate `Y`:
   ```bash
   VERSION=<Y> curl -fsSL https://opencode.ai/install | bash
   ```
3. Smoke-test: `opencode --version`; open a session; confirm skills load and the
   `handoff-on-context` plugin loads without error.
4. **ONLY THEN** bump the pin so rebuilds match:
   ```bash
   echo "<Y>" > /data/opencode-config/OPENCODE_VERSION
   ```

**Break-glass — reinstall last-known-good if opencode is broken:**
```bash
VERSION=1.18.6 curl -fsSL https://opencode.ai/install | bash
```

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

## Emergency / Ad-hoc Access (no usual SSH key)

SSH to the box is **key-only** — `PasswordAuthentication no` (`cloud-init.yaml:43`)
and the `dev` user is **password-locked**, so password SSH is never an option.
Ports **22** and **8443** are open to the whole internet (`0.0.0.0/0`).

> ⚠️ **Do NOT use code-server (`:8443`) from an untrusted/borrowed machine.** It
> is **plain HTTP** (`cert:false`) with a reusable password — the password
> travels in **cleartext** and is exposed to keyloggers / saved browser creds.

**Keyless foot-in-the-door:** the **Hetzner Cloud Console** has a per-server
**"Console"** button (`console.hetzner.cloud` → select the dev server → **Console**)
= a keyless browser terminal. It needs only your Hetzner account login and works
from a phone. Use it to reach the dev shell when you have no key.

### Optional: Break-glass console password (dev)

By default the Hetzner web console `login:` prompt rejects **everything** —
both `root` and `dev` have **locked** passwords in `/etc/shadow` (`dev` via
cloud-init's `lock_passwd` default, `root` via the Ubuntu base image), because
the box is intentionally key-only. If you ever need a console-only password for
`dev` (this does **NOT** enable SSH password auth):

1. **Off-box**, generate a SHA-512 hash (enter your chosen password when prompted):
   ```bash
   openssl passwd -6
   ```
2. **On the box** (via SSH), persist the `chpasswd -e` line on `/data`:
   ```bash
   mkdir -p /data/console
   echo 'dev:$6$....hash....' > /data/console/console_passwd.hash
   chmod 600 /data/console/console_passwd.hash
   ```
3. It applies on the **next boot** (lives on `/data`, survives rebuilds, is
   **never committed**). Reboot or wait for the next `dev-up` to activate.

It's a **second factor** behind your Hetzner panel login, targets `dev` (which
has NOPASSWD sudo), leaves `root` locked, and **never weakens sshd**
(`PasswordAuthentication` stays `no`).

**To disable:** delete `/data/console/console_passwd.hash` and, if it's already
applied to a running box, run `passwd -l dev` to re-lock the account.

**Key rules:**
- **Always generate the keypair on the machine you will SSH _from_**, never on the box.
- The box's `~/.ssh/authorized_keys` is **regenerated fresh on every
  `dev-down`/`dev-up`** from the Hetzner-account keys defined in terraform. A key
  hand-added to the **live** box is **temporary** — **wiped on the next rebuild**
  and **not** persisted to `/data`.
- To make a key **permanent**, add it to the `ssh_public_keys` map in
  `terraform/terraform.tfvars` (map key = device name, value = the ed25519 public
  key), commit + push; a rebuild bakes it in. Current entries: `worklaptop`, `tablet`.
- To add a **temp** key you edit the **box's** `~/.ssh/authorized_keys` directly
  (via the browser Console) — **not** the Hetzner web UI "SSH Keys" page (those
  keys are injected only at server **creation**, not onto a running box).

### Runbook A — borrowed / untrusted laptop (temporary, leave nothing behind)

1. From your phone or any browser, log into `console.hetzner.cloud` → select the
   dev server → click **Console** (keyless browser terminal; use it to reach the
   dev shell).
2. On the borrowed laptop, generate a **throwaway** keypair:
   ```bash
   ssh-keygen -t ed25519 -f ~/throwaway -N ''
   ```
3. In the browser Console, append the throwaway **public** key to the box:
   ```bash
   echo 'ssh-ed25519 AAAA...throwaway' >> /home/dev/.ssh/authorized_keys
   ```
4. Do your real work over normal SSH from the borrowed laptop:
   ```bash
   ssh -i ~/throwaway dev@<IP>
   ```
5. **On exit — server-side revocation (the whole point):** remove that one line
   from `/home/dev/.ssh/authorized_keys` (edit the file and delete the throwaway
   line). The throwaway key is now **dead even if the borrowed laptop kept a
   copy**. Then also:
   ```bash
   rm -f ~/throwaway*        # on the borrowed laptop
   ```
   clear the browser session, and **rotate your Hetzner account password from your
   own machine** afterward.

> The temp key would be wiped by a rebuild anyway, but **revoke it explicitly**
> rather than relying on that.

### Runbook B — new permanent laptop (make a key stick across rebuilds)

1. On the new laptop, generate the key:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/hetzner_<name> -C hetzner-<name>-<date>
   ```
2. Add the **public** key to `terraform/terraform.tfvars` under `ssh_public_keys`, e.g.:
   ```hcl
   newlaptop = "ssh-ed25519 AAAA... hetzner-newlaptop-YYYYMMDD"
   ```
3. **Commit + push.** The next `dev-up` rebuild bakes the key in permanently.
4. If the box is currently **up** and you need access before a rebuild, bootstrap a
   **temporary** copy now via the browser Console so you can SSH immediately —
   **but still do the tfvars edit for permanence**:
   ```bash
   echo '<pubkey>' >> /home/dev/.ssh/authorized_keys
   ```
   (You can even make the tfvars edit from **inside the box** — it has a clone of
   this repo and can `git push` to trigger the rebuild.)
5. ⚠️ **Don't delete** the existing `worklaptop` / `tablet` keys until the new key
   is **proven working**.

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
