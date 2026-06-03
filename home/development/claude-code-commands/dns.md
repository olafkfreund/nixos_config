---
description: Manage GoDaddy DNS records — list, add, remove, verify, check propagation
argument-hint: <subcommand> [args...]
---

# /dns — GoDaddy DNS management

Use the `dns` skill (`~/.claude/skills/dns/`) to handle this request:

$ARGUMENTS

If `$ARGUMENTS` is empty, show available subcommands by running:

```bash
~/.claude/skills/dns/scripts/dns.sh help
```

## Required workflow

For read-only operations (`domains`, `list`, `get`, `verify`, `check`):

- Just run the script and report the output.

For destructive operations (`add`, `rm`):

1. Run a read-only command first (`dns list` or `dns get`) to show the
   current state.
2. Summarise the intended change to the user in plain language
   (e.g. "Set A record `home.example.com` from `1.2.3.4` to `5.6.7.8`,
   TTL 600").
3. Wait for explicit confirmation ("yes" / "go") before any `dns add`
   or `dns rm`.
4. After the change, run `dns verify` to confirm GoDaddy stored it,
   then `dns check` to show whether it's resolving publicly yet.

The script self-decrypts the GoDaddy API secret via agenix from
`~/.config/nixos/secrets/api-godaddy.age`. If decryption fails, the
error message tells the user where to look — do not try to work around
it by asking for credentials.
