---
status: approved
issue: 2265
spec: spec/2026-10-12-2265-brave-search-secret.md
---

# Plan: A Brave Search key for the reference-engine demo that survives restarts

Approved decisions, carried over from the spec:

- A new agenix secret, `api-brave-search`, holding the 31-character key alone
  with no `NAME=` and no newline.
- Recipients are `allUsers ++ workstations` (p620 and razer).
- It is declared only behind a new option, `secrets.apiKeys.braveSearch`, off
  by default, because p510 also enables `secrets.apiKeys` and can't decrypt it.
  The option is on for p620 and razer.
- The file is 0400 and owned by `username`, with group `users`.
- It is not exported by `load-api-keys` or as an environment variable.
- The key is never printed, and nothing in plaintext is committed. The repo is
  public.
- The user runs `nixos-rebuild switch`. The reference-engine repo doesn't
  change: `demo.sh` already reads `/run/agenix/api-brave-search`.

Who does what:

- I do step 1, because it handles the key.
- The `coder` agent (Sonnet) does steps 2-4. They are Nix edits across 3 files,
  and with the `.age` file the change touches 5 files.

## Steps

1. **`secrets/api-brave-search.age` (new, done by me).**
   - Write the value after the first `=` of `/tmp/brave.txt` with
     `printf '%s'` to a 0600 file in the session scratchpad.
   - Run `EDITOR="cp <that file>" agenix -e secrets/api-brave-search.age` from
     the repo root, after step 2 has added the recipients line. agenix reads
     the recipients from `secrets.nix`.
   - Delete the scratchpad file.
   - Verify with `agenix -d secrets/api-brave-search.age | wc -c`, which should
     print `31`.
   - Traps: never `cat` or echo the key. `agenix -e` needs the `secrets.nix`
     entry to exist first, so run this step after step 2.

2. **`secrets.nix`, after line 71 (`api-linkedin-cookie`).** Add:

   ```nix
   # Brave Search key for the reference-engine demo (scripts/demo.sh reads /run/agenix/api-brave-search).
   "secrets/api-brave-search.age".publicKeys = allUsers ++ workstations;
   ```

   - Verify with `nix-instantiate --parse secrets.nix >/dev/null`.
   - Traps: markdownlint and nixpkgs-fmt run on commit and push. Keep lines
     within 120 characters.

3. **`modules/secrets/api-keys.nix`.**
   - **Options, after `enableUserEnvironment` (ends at line 29):**
     `braveSearch = mkEnableOption "the Brave Search key for the reference-engine demo (/run/agenix/api-brave-search)";`
   - **`age.secrets`:** before the final `;` at line 219 (after the `gogcli`
     `optionalAttrs` block), add, in the file's own merge style:

     ```nix
     # Brave Search key: workstations only (p510 is not a recipient), read from
     # /run/agenix by the reference-engine demo; never exported (#2265).
     // lib.optionalAttrs cfg.braveSearch {
       api-brave-search = {
         file = ../../secrets/api-brave-search.age;
         mode = "0400";
         owner = username;
         group = "users";
       };
     }
     ```

   - Don't touch `load-api-keys` or the zsh, bash or environment sections.
   - Verify that `nix-instantiate --parse modules/secrets/api-keys.nix` passes.
   - Traps:
     - The spec's `mkIf` is written as `optionalAttrs` to match the file's
       existing `//` pattern. A plain attrset value can't hold an unmerged
       `mkIf` here.
     - Format with `nixpkgs-fmt`.

4. **`hosts/p620/configuration.nix` line 538 and `hosts/razer/configuration.nix`
   line 439.** Add `braveSearch = true;` inside each host's existing
   `secrets.apiKeys = { ... };` block. Leave p510 unchanged.
   - Verify by evaluating each host. On p620 and razer,
     `nix eval .#nixosConfigurations.<h>.config.age.secrets --apply 'builtins.hasAttr "api-brave-search"'`
     should print `true`, and on p510 `false`.
   - Traps: evaluation is fine. Never run `nixos-rebuild`, `switch` or
     `deploy`. Building is allowed, switching is not.

## Tests

- Step 4's `nix eval` checks: true on p620 and razer, false on p510.
- `just test-host p620` builds the p620 toplevel (no switch).
- Step 1's `agenix -d ... | wc -c` prints `31`.
- After the user runs `sudo nixos-rebuild switch --flake .#p620`:
  - `stat -c '%a %U' /run/agenix/api-brave-search` prints `400 olafkfreund`;
  - from a fresh shell with no exported key, run
    `scripts/demo.sh down && scripts/demo.sh up`. The worker's `BRAVE_API_KEY`
    presence check shows 1, and research works;
  - then delete `/tmp/brave.txt`.

## Rollback

Revert the merge commit and switch again. `/run/agenix/api-brave-search`
disappears, and the demo goes back to needing an exported key.

## Deviations

- Step 1: `agenix -e` reads stdin instead of running `$EDITOR` when stdin is
  not a terminal, so the key went in as `agenix -e secrets/api-brave-search.age < <0600 temp file>`.
  The temp file was deleted at once. Checks: 3 recipient stanzas, and the
  decrypted length is 31.
