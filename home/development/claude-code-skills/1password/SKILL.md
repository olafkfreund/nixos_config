---
name: 1password
description: >-
  Read, write and inject secrets with the 1Password CLI (`op`). Look up
  logins/API keys/SSH keys, resolve `op://` secret references, run a command
  with secrets as env vars (`op run`), fill config templates (`op inject`),
  and create/edit items. Triggers on `/1password`, "get my <service> API key",
  "what's the password for X", "put this secret in 1Password", "run this with
  the <service> credentials", or any mention of `op`, `op://`, or 1Password.
version: 0.1.0
category: security
tags: [1password, op, secrets, credentials, cli]
recommended_skills: []
platforms:
  - claude-code
---

# 1password — secrets from the terminal with `op`

`op` 2.x, installed system-wide by `security.onepassword.enable` (see
`modules/programs/1password.nix`). Binary is `/run/wrappers/bin/op`.
Available on **p620** and **razer**.

Account: `my.1password.com` / `olaf@freundcloud.com`. One vault, **`Personal`**
(~950 items, overwhelmingly Logins plus a dozen API credentials) — so `--vault
Personal` is always the right scope and there is no vault to choose between.

## The one rule

**Never print a secret value into the conversation.** `op read` output lands
in the transcript, which is stored and synced. Pipe it, don't echo it:

```bash
op read op://Personal/GitHub/token | gh auth login --with-token   # good
op run --env-file .env -- ./deploy.sh                            # good
echo "token is $(op read op://Personal/GitHub/token)"             # NEVER
```

If the user genuinely needs to *see* a value, put it on the clipboard instead:

```bash
op read op://Personal/GitHub/token | wl-copy
```

...and tell them it's on the clipboard. Only fall back to printing if they
explicitly ask for the value on screen after being told it will be logged.

## Preflight: can `op` actually reach the vault?

```bash
op vault list
```

Prints the vault table → good, proceed.

### Do NOT use `op whoami` as the readiness check

On this setup it is a **false negative**. The desktop app integration is on
(`developers.cliSharedLockState.enabled`), so `op` authenticates by delegating
each request to the running app over native messaging and never writes a local
session record. `op whoami` looks for that record, doesn't find one, and prints:

```text
[ERROR] account is not signed in
```

...while `op vault list`, `op read` and everything else work perfectly. Verified
on p620: `whoami` fails and `op read op://Personal/<id>/password` returns the
secret in the same shell. `op signin` likewise exits 0 without doing anything,
because there is nothing to do.

If you see the whoami error, **ignore it and run the real command.** Only treat
1Password as unavailable when `op vault list` itself fails.

### When it genuinely is locked

`op vault list` errors or hangs → the desktop app is locked. You can't fix that;
unlocking needs a biometric/system-auth prompt on the user's screen. Ask them to
unlock the 1Password app, then retry once. Don't retry in a loop.

Auto-lock is set to 60 minutes, and the app starts `--silent` at login, so a
fresh boot with nobody having opened the app is the usual cause.

## Reading secrets

`op read` takes a **secret reference**: `op://<vault>/<item>/<field>`, or
`op://<vault>/<item>/<section>/<field>` when the field lives in a section.

```bash
op read op://Personal/AWS/access_key_id
op read "op://Personal/db/one-time password?attribute=otp"     # TOTP
op read --out-file ./key.pem op://Personal/server/private_key  # to a file
op read "op://Personal/ssh key/private key?ssh-format=openssh"
```

Vault and item names with spaces need quoting; IDs work anywhere a name does
and are faster (no search).

## Finding what to read

Discovery is safe to print — names and metadata aren't secrets.

```bash
op vault list
op item list --vault Personal
op item list --categories Login --vault Personal --format json
op item get GitHub --format json | jq '.fields[].label'   # field names only
op item get GitHub --fields label=username               # non-secret field
```

`op item get <name>` without `--fields` prints the whole item **including
concealed fields** — avoid it; list the field labels with `jq` instead, then
`op read` the one you need.

## Injecting secrets into things

Prefer these over reading a value and passing it around.

**Env vars for one process** — `.env` holds references, not secrets, so it's
safe to commit:

```bash
# .env
AWS_ACCESS_KEY_ID=op://Personal/AWS/access_key_id
AWS_SECRET_ACCESS_KEY=op://Personal/AWS/secret_access_key

op run --env-file .env -- terraform apply
```

**Config file from a template**:

```bash
# config.yml.tpl
db_password: {{ op://Personal/db/password }}

op inject -i config.yml.tpl -o config.yml
```

`op inject` writes a real secret to disk. Delete the output when done, and
never let it land in the repo — check `.gitignore` first.

**Third-party CLI auth** — shell plugins replace stored credentials entirely:

```bash
op plugin list          # what's supported
op plugin init gh       # configure one
op plugin inspect       # what's already configured
```

## Writing secrets

```bash
op item create --category login --title "Some Service" \
  --vault Personal username=olaf 'password=...'

op item edit "Some Service" --vault Personal 'password=...'
op item delete "Some Service" --vault Personal --archive
```

Never pass a secret as a literal on the command line in a way that reaches the
transcript — have the user run the create/edit themselves with `! op item ...`,
or read the value from a file. Prefer `--generate-password` when creating:

```bash
op item create --category login --title X --vault Personal \
  --generate-password='32,letters,digits,symbols' username=olaf
```

Destructive ops (`item delete`, `vault delete`, `item move`) always get
confirmed with the user first.

## `op` vs agenix in this repo

They don't overlap — don't migrate between them:

- **agenix** = machine secrets consumed by NixOS services at runtime
  (`passwordFile` paths, `scripts/manage-secrets.sh`). Declarative, no human
  in the loop, survives a headless boot.
- **1Password** = human/interactive secrets — API tokens you paste into a
  shell, logins, recovery codes. Needs an unlocked desktop app, so it can
  never be a boot-time dependency.

If a *service* needs the secret, it goes in agenix. If *you* need it at a
prompt, it's in 1Password.

## Notes

- `--format json` on any command for parseable output; pipe through `jq`.
- `--account` / `OP_ACCOUNT` selects the account if more than one is added.
- Service accounts (`OP_SERVICE_ACCOUNT_TOKEN`) are the headless path — no
  desktop app needed, but scoped to specific vaults. Not currently set up here.
- p510 also has `security.onepassword.enable`, which drags the Electron GUI
  into a headless server's closure. Cosmetic, but worth cleaning up sometime.
