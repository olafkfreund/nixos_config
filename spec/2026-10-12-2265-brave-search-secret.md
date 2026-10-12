---
status: approved
issue: 2265
intent: intent/2026-10-12-2265-brave-search-secret.md
---

# Spec: A Brave Search key for the reference-engine demo that survives restarts

## Design

This carries over the user's decisions of 2026-10-12, recorded in the intent:
the recipients are `allUsers ++ workstations` (p620 and razer), and the key is
not exported as `BRAVE_API_KEY` by `load-api-keys`.

1. **`secrets/api-brave-search.age`, new.** The key alone, with no `NAME=` and
   no newline, encrypted with
   `EDITOR="cp <key-only temp file>" agenix -e secrets/api-brave-search.age`,
   so the recipients come from `secrets.nix`. The temp file lives in the
   session scratchpad with mode 0600 and is deleted right after. The key is
   never printed.
2. **`secrets.nix`.** One line next to the other workstation keys (line 70ff),
   with a one-line comment saying what reads it:
   `"secrets/api-brave-search.age".publicKeys = allUsers ++ workstations;`
3. **`modules/secrets/api-keys.nix`.**
   - A new option, off by default:
     `secrets.apiKeys.braveSearch = mkEnableOption "the Brave Search key for the reference-engine demo"`.
   - In `age.secrets`, `api-brave-search = mkIf cfg.braveSearch { ... }` with
     `file = ../../secrets/api-brave-search.age`, `mode = "0400"`,
     `owner = username` and `group = "users"`.
   - It isn't added to `load-api-keys` or the environment variables.
   - It must be gated: p510 also enables `secrets.apiKeys`, and an undeclared
     recipient can't decrypt the file, so an unconditional declaration would
     make p510's activation fail on this secret.
4. **`hosts/p620/configuration.nix` and `hosts/razer/configuration.nix`.**
   `braveSearch = true;` in each host's existing `secrets.apiKeys` block (p620
   line 538, razer line 439).

`demo.sh` already reads `/run/agenix/api-brave-search` when `BRAVE_API_KEY`
isn't exported, so the reference-engine repo doesn't change.

## Alternatives rejected

- **`allUsers ++ allHosts` without an option:** p510 doesn't run the demo, and
  you chose workstations only.
- **Gate on `config.networking.hostName`:** a host list hard-coded in a shared
  module. Every other workstation-only key is gated by an option
  (`mcp-servers.nix:327`).
- **Declare it in `hosts/p620/configuration.nix` only:** razer could decrypt
  the key but would never get `/run/agenix/api-brave-search`, so the demo there
  would start without it.
- **Export `BRAVE_API_KEY` in every shell:** you declined this. Fewer processes
  can read the key when they don't need it.

## Risks

- **A key with a trailing newline:** Brave would reject it with an auth error.
  The plan writes the key with `printf '%s'` and checks the decrypted length
  (31) without printing it.
- **The rebuild:** `nixos-rebuild switch` on p620 needs sudo, so the user runs
  it. If evaluation fails, nothing switches.
- **razer:** it gets the secret on its next rebuild. Nothing changes until then.

## Verification

- `nix flake check` or `just check`, whichever the repo uses, plus an
  evaluation of p620, razer and p510 (`nix eval .#nixosConfigurations.<h>.config.system.build.toplevel.drvPath`).
  All three must evaluate, and `config.age.secrets ? api-brave-search` must be
  true on p620 and razer and false on p510.
- `agenix -d secrets/api-brave-search.age | wc -c` returns 31. This decrypts
  with the user's key and prints only the count.
- After the user's switch:
  - `/run/agenix/api-brave-search` is 0400 and owned by olafkfreund;
  - after `scripts/demo.sh down && scripts/demo.sh up` from a fresh shell with
    no exported key, the worker has a non-empty `BRAVE_API_KEY` (presence
    check only), and research works;
  - `/tmp/brave.txt` can then be deleted.
