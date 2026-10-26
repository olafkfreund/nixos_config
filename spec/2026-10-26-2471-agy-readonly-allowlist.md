---
status: draft
issue: 2471
intent: intent/2026-10-26-2471-agy-readonly-allowlist.md
---

# Spec: declarative agy read-only allow-list, and second-opinion handles empty and timed-out results

## Design

### 1. Allow-list activation (`home/development/antigravity-config.nix`)

Add `home.activation.antigravityReadOnlyAllow` after `writeBoundary`, written in
the same style as `antigravityCoderGuardHook` and `antigravityMcpSync`. The
list it manages is a Nix list in a `let` binding:

```nix
readOnlyAllow = map (c: "command(${c})") [
  "git diff" "git log" "git show" "git status" "git rev-parse" "git ls-files"
  "grep" "rg" "ls" "cat" "head" "tail" "wc" "sed -n"
];
readOnlyRemove = [ "command(find)" ];   # can -delete / -exec (intent decision 1)
```

The script runs against `~/.gemini/antigravity-cli/settings.json`:

- **The file is missing:** seed it with `{"permissions":{"allow": readOnlyAllow}}`.
- **The file is a JSON object:** compute
  `.permissions.allow = (((.permissions.allow // []) + $want) - $remove | unique)`.
  This is a union, so hand-added entries stay (decision 2), and the one
  listed unsafe entry is dropped. Every other key (`model`, `statusLine`, …)
  is left as it is.
- **The file isn't valid JSON:** leave it alone and print a message, as the MCP
  sync does.
- **Write only if the result differs** (`cmp -s`). `~/.gemini` syncs across
  p620, razer and p510. An activation that rewrites an unchanged file on
  every host makes Syncthing conflict copies.
- **Publish the file** by writing to `mktemp`, then `$DRY_RUN_CMD mv`, the
  same pattern the hooks seeding uses, so a dry run writes nothing.

`unique` sorts the list. agy doesn't depend on the order of rules, and a
sorted list is stable, so the `cmp` check stays quiet after the first run.

### 2. Skill (`home/development/claude-code-skills/second-opinion/SKILL.md`)

- **Both agy blocks** (plain and `--agent`): replace
  `jq -r '.status, .response'` with a gate:

  ```bash
  jq -e '.status == "SUCCESS" and (.response // "" | test("\\S"))' "$work/agy.json" >/dev/null \
    && jq -r .response "$work/agy.json" || echo "agy: review not obtained"
  ```

- **Failures section:** add a bullet. A `status` other than `SUCCESS`, an empty or
  whitespace `.response`, or a run that hits `--print-timeout` means **not
  obtained**, even when the exit code is 0.
- **Prompt section, item 2:** for agy, name the files or the diff to read and
  tell it not to explore beyond them. This is what prevents the 586 s,
  408k-token reread. Item 3's standard instruction gets one clause: *"Read
  only the files named above."*

## Alternatives rejected

- **A nix-store symlink for `settings.json`:** agy writes to this file, and
  `~/.gemini` syncs through Syncthing (memory: syncthing-managed dirs).
- **Replace `permissions.allow` outright:** rejected by intent decision 2.
- **A shadow `HOME` with its own settings for review runs:** #2296 replaced
  that approach, and it would split agy's login state.
- **`--dangerously-skip-permissions` for reviews:** it drops the permission
  layer, and AGENTS.md forbids it outside `agy-implement`.

## Risks

- **Two hosts activating at once:** the `cmp` check means only a real change
  writes. A conflict needs both hosts to change the file in the same sync
  window, and then Syncthing keeps a `*sync-conflict*` copy, which the
  stignore drops.
- **agy renames the settings path or rule syntax** in a future version: the
  merge keeps writing and agy ignores it, so we're back to today's soft-deny.
  Nothing breaks, and the runtime check below would catch it.
- **`sed -n` can still write with `w`.** The intent accepted that.

## Verification

1. **Format:** `just check-syntax`, plus statix/deadnix on the module.
2. **Build:** `just test-host p620` and `just test-host razer` build.
3. **Merge logic:** run the activation's jq against fixture files in a
   scratch dir:
   - missing → seeded;
   - existing with `command(find)` plus a hand entry → find gone, hand entry
     kept, other keys intact;
   - unchanged → no write (mtime is the same);
   - invalid JSON → untouched.
4. **After deploy, on p620:** `jq .permissions` shows the list without `find`,
   and `agy --mode plan --output-format json -p "run git status and report
   it"` returns the output instead of a soft-deny.
5. **Skill gate:** run the `jq -e` gate against
   `{"status":"SUCCESS","response":""}` and expect it to fail, then a real
   response and expect it to pass.
