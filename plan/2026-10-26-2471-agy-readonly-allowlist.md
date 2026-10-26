---
status: approved
issue: 2471
spec: spec/2026-10-26-2471-agy-readonly-allowlist.md
---

# Plan: declarative agy read-only allow-list, and second-opinion handles empty and timed-out results

Two files change and there are two edit steps, which is below the coder
handoff threshold, so Claude implements this directly.

Approved decisions:

- A Home Manager activation step merges a read-only allow-list into
  `~/.gemini/antigravity-cli/settings.json`.
  - The merge: `allow = unique((existing // []) + want - remove)`, where
    `remove = ["command(find)"]`. It's a union, so hand-added entries stay.
    Every other key stays as it is.
  - Missing file → seed it. Invalid JSON → leave it alone and print a
    message. Write only when the file changes (`cmp -s`), via
    `mktemp` + `$DRY_RUN_CMD mv`.
  - The `want` list: git diff/log/show/status/rev-parse/ls-files, grep, rg,
    ls, cat, head, tail, wc, `sed -n`.
- The second-opinion skill counts a non-`SUCCESS` status, an empty or
  whitespace `.response`, or a `--print-timeout` hit as "not obtained", and
  tells callers to name the files to read.

## Steps

1. `home/development/antigravity-config.nix`:
   - **`let` block (25–251):** add `readOnlyAllow` and `readOnlyRemove`
     next to `sharedMcpFile` (about line 90). Serialise them for jq with
     `builtins.toJSON` in the script, as `--argjson` values.
   - **`config`:** after `antigravityMcpSync` (about line 343), add
     `home.activation.antigravityReadOnlyAllow = lib.hm.dag.entryAfter [ "writeBoundary" ] ''…''`.
     Implement the three cases from the decisions above. Write
     `mkdir -p "${geminiDir}/antigravity-cli"` before seeding.

   Check: `just check-syntax`, then statix and deadnix on the file.

   Traps:
   - Never end a publish with `> "$file"` under `$DRY_RUN_CMD`, because
     the redirection runs even on a dry run.
   - Use `${pkgs.jq}` and `${pkgs.diffutils}/bin/cmp`, not PATH.
   - Keep comments minimal (memory: minimal comments).

2. `home/development/claude-code-skills/second-opinion/SKILL.md`:
   - **Lines 133 and 158:** replace `jq -r '.status, .response' "$work/agy.json"`
     with the gate:

     ```bash
     jq -e '.status == "SUCCESS" and (.response // "" | test("\\S"))' "$work/agy.json" >/dev/null \
       && jq -r .response "$work/agy.json" || echo "agy: review not obtained"
     ```

   - **Line 60 list, item 2:** add a sentence. For agy, name the files or the
     diff to read; agy otherwise rereads the repo and can run out the
     10-minute print timeout.
   - **Line 64, item 3:** add the clause *"Read only the files named above."*
   - **`## Failures` (line 201):** add a bullet. A `status` other than
     `SUCCESS`, an empty or whitespace `.response`, or a `--print-timeout`
     hit means not obtained, even with exit 0.

   Check: `markdownlint` on the file. The pre-push hook lints whole files.

   Traps: the skill is a nix-store-linked managed skill, so it only reaches
   hosts after a rebuild.

## Tests

1. **Merge-logic fixtures:** run in the scratchpad, with the jq expression
   copied from the built activation script.
   - missing → seeded with 14 entries;
   - `{"model":"x","permissions":{"allow":["command(find)","command(foo)"]}}`
     → `find` gone, `foo` kept, `model` kept;
   - a second run → no write (mtime is the same);
   - `not json` → untouched.
2. **Gate:** the gate exits non-zero on `{"status":"SUCCESS","response":" "}`
   and passes on `{"status":"SUCCESS","response":"ok"}`.
3. **Build:** `just test-host p620` and `just test-host razer` (razer via
   p620) both build.
4. **After deploy, on p620:** announce on the agent bus first. Then check
   that `jq .permissions.allow ~/.gemini/antigravity-cli/settings.json`
   doesn't contain `command(find)`, and that
   `agy --mode plan --output-format json --print-timeout 2m -p "run git status and report it"`
   returns the `git status` output.

p510 isn't built or deployed. The file syncs to it anyway.

## Rollback

Revert the PR. The activation only adds entries, so a revert leaves the
merged list in place. To restore the `find` rule, add it by hand.
