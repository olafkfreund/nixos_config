---
status: approved
issue: 2265
author: olafkfreund
---

# Intent: A Brave Search key for the reference-engine demo that survives restarts

## Problem

The reference-engine demo (`scripts/demo.sh` in
synechron-case-reference-engine) reads its Brave Search key from
`/run/agenix/api-brave-search` when `BRAVE_API_KEY` isn't exported. This config
declares no such secret. The key has to be exported by hand in the shell that
starts the demo, so a restart from any other shell drops it without a warning:
the containers start with an empty key, and research fails with
"BRAVE_API_KEY is not set". Right now the key sits in plaintext in
`/tmp/brave.txt`.

## Proposed outcome

- `/run/agenix/api-brave-search` exists on the workstations, holds only the key,
  and is 0400 and owned by the user, like `api-gemini`.
- After `nixos-rebuild switch`, `scripts/demo.sh up` from any shell starts the
  demo with the key and research works. No change to the reference-engine repo.
- The plaintext `/tmp/brave.txt` can be deleted.

## Affected users and systems

- `secrets.nix`: a recipients entry.
- `secrets/api-brave-search.age`: new, encrypted.
- `modules/secrets/api-keys.nix`: the `age.secrets` declaration.
- p620 for certain; razer if it is a recipient (see open questions).
- The user: runs `nixos-rebuild switch`, which needs sudo.

## Constraints

- The repo is public. Only the encrypted `.age` file is committed. The key is
  never printed, logged, or written to the repo in plaintext.
- Readable only by the user (0400). No world-readable copy.
- Follow the existing `api-*` pattern. Don't add it to the system-wide
  environment unless the other keys already go there (see open questions).
- No rebuild or switch by me. The user runs it.

## Open questions

- **Recipients:** `allUsers ++ workstations` (p620 and razer, where the demo
  runs; my recommendation) or `allUsers ++ allHosts` like most `api-*` keys?
  p510 is a server and doesn't run the demo.
- **Shell variable:** should `load-api-keys` also export it as `BRAVE_API_KEY`
  in user shells, as it does for the other keys? I recommend no. `demo.sh`
  already reads the file, and keeping the key out of every shell environment
  means fewer processes can see it.

**Decided by the user, 2026-10-12 (approved with the recommendations):**
recipients are `allUsers ++ workstations`; no `BRAVE_API_KEY` export via
`load-api-keys`.
