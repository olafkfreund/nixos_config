---
name: dns
description: >-
  Manage DNS records for the user's GoDaddy-registered domains. Add/upsert,
  delete, list, look up specific records, verify a stored record matches
  an expected value, and check public DNS resolution via dig. Triggers on
  `/dns`, requests to add/change/check A, AAAA, CNAME, MX, TXT, NS, SRV
  records on the user's domains, debugging DNS propagation, or auditing
  what's set at GoDaddy vs what's resolving in the wild.
version: 0.1.0
category: infrastructure
tags: [dns, godaddy, domains, cli]
recommended_skills: []
platforms:
  - claude-code
---

# dns — GoDaddy DNS management from the CLI

A thin Bash wrapper around the GoDaddy Production REST API
(`https://api.godaddy.com/v1/domains`). Decrypts the API credentials from
agenix at invocation time — never stores them on disk, never echoes them.

## When to use this

- User asks to add / change / remove a DNS record
- User asks "what's set on `<domain>`"
- User asks why a record isn't resolving (propagation check)
- User asks for a list of their domains
- User invokes `/dns ...`

## When NOT to use

- The domain isn't at GoDaddy → use the right registrar's tool
- Bulk migration of dozens+ of records → consider Terraform with the
  `n3integration/godaddy` provider instead

## The script

Path: `~/.claude/skills/dns/scripts/dns.sh` (symlinked from this skill's
home-manager source). Available on every host that enables the developer
profile (p620, razer, p510).

Invoke directly — it's marked executable. Or via `bash` if PATH issues:
`bash ~/.claude/skills/dns/scripts/dns.sh ...`.

The script handles auth (sso-key header), HTTP error detection, JSON
parsing, and credential decryption.

## Subcommands

| Command | Purpose |
|---|---|
| `dns domains` | All domains in the account (table) |
| `dns list <domain>` | All records for a domain (table) |
| `dns list <domain> json` | All records as raw JSON |
| `dns get <domain> <type> <name>` | One record set |
| `dns add <domain> <name> <type> <value> [ttl]` | Upsert (replaces same name+type) |
| `dns rm <domain> <name> <type>` | Delete all records of name+type |
| `dns verify <domain> <name> <type> <expected>` | Compare to expected value |
| `dns check <fqdn> [<type>]` | Resolve via dig (1.1.1.1 + 8.8.8.8) |
| `dns help` | Show usage |

## Operating principles

1. **Confirm before destructive operations.** Before `add` or `rm`,
   summarise the intended change and wait for explicit "yes" — unless
   the user already pre-approved.
2. **Verify after change.** After `add` / `rm`, run `verify` to confirm
   GoDaddy stored it, then `check` to see public propagation. GoDaddy
   internal change is near-instant; worldwide propagation typically
   5–15 min.
3. **Apex records use name `@`.** A record on `example.com` itself →
   `name=@`. Subdomain `www.example.com` → `name=www`, `domain=example.com`.
4. **Default TTL is 3600.** For records that may change soon, use 600.
   Don't go below 600 — GoDaddy may reject.
5. **`add` is upsert + replace.** If multiple records share the same
   name+type (e.g., two MX records at different priorities), `dns add`
   replaces ALL of them with only the one you supply. To preserve
   siblings: `dns list` first, craft a multi-record JSON, then use a
   manual `curl` PUT. The script doesn't append-add today.
6. **No history / undo.** GoDaddy doesn't version DNS edits via this API.
   Before `rm`, prefer `dns get` first and offer to dump it to a file so
   the user can restore by hand if needed.

## Common error patterns

| Symptom | Cause | Fix |
|---|---|---|
| `HTTP 400 UNABLE_TO_AUTHENTICATE` | Key created in OTE sandbox, not Production | Recreate at developer.godaddy.com/keys with Production selected |
| `HTTP 401` / `403` | Credentials wrong or account not on paid API tier | Verify by `curl -H "Authorization: sso-key K:S" https://api.godaddy.com/v1/domains` |
| `HTTP 404` | Domain not in this account | `dns domains` to see the real list |
| `HTTP 422` | Invalid record format (e.g. CNAME value missing trailing `.`) | Show the user the response body; usually self-explanatory |
| `failed to decrypt` | SSH key mismatch or wrong recipient | Check `secrets.nix` lists `allUsers` for `api-godaddy.age` |

## Examples

```bash
# What domains do I own?
dns domains

# What's currently set on freundcloud.com?
dns list freundcloud.com

# Point home.example.com at a new server
dns add example.com home A 192.0.2.42 600
dns verify example.com home A 192.0.2.42
dns check home.example.com A

# Remove a stale CNAME
dns rm example.com old CNAME

# Inspect a single record set as raw JSON
dns get example.com MX @
```
