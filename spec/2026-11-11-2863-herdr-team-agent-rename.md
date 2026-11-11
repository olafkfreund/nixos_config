---
status: draft
issue: 2863
intent: intent/2026-11-11-2863-herdr-team-agent-rename.md
---

# Spec: herdr-team names Codex members with valid herdr agent names

Approved intent decisions: keep the rename, with a mapped name; a rename
failure stays fatal and carries herdr's message.

## Design

### 1. `agent_name` helper in `home/development/herdr-team.sh`

Next to `task_ok` (line 60):

```bash
# herdr agent names: ^[a-z][a-z0-9_-]{0,31}$; shorten the task, never the role
agent_name() {
  local t=${1,,}
  [[ $t == [a-z]* ]] || t=t$t
  printf '%s-%s' "${t:0:$((31 - ${#2}))}" "$2"
}
```

- `task_ok` already limits the task to `[A-Za-z0-9_-]` with an
  alphanumeric first character, so lowercasing leaves only `[a-z0-9_-]`. No
  character replacement is needed.
- A `t` prefix when the task doesn't start with a letter: `2863` →
  `t2863-review`.
- The task part is cut to `31 - len(role)` characters, then `-<role>` is
  added, so the result is at most 32 characters and the role is never cut.
  The longest role, `agy-implement` (13), leaves 18 characters for the task.
- Two different long tasks that share their first 18 characters would get
  the same label. Nothing reads the name back, so that only matters if herdr
  requires unique names; Verification 4 checks it.

### 2. The Codex rename (line 579)

```bash
local err
err=$(h agent rename "$pane" "$(agent_name "$task" "$role")" 2>&1 >/dev/null) \
  || fail "agent rename failed: ${err//$'\n'/ }"
```

- herdr's stderr (its error JSON) is kept and goes into the `fail` reason.
  stdout (the success JSON) is still dropped.
- It stays fatal, so `up`'s EXIT trap tears the member down as before.
- `err` is declared with the function's other locals.

### 3. Unchanged

- The agy `pane rename` (line 577) keeps `"$task-$role"`: pane labels
  accepted `2853-agy-implement`, and the intent leaves agy alone.
- The tab label, scope names, state files and relay headers keep the plain
  task name.

### 4. Tests in `home/development/herdr-team-test.sh`

- The fake `herdr`'s `agent rename` (line 109) enforces herdr's rule:
  a name that doesn't match `^[a-z][a-z0-9_-]{0,31}$` prints herdr's
  `invalid_agent_name` JSON to stderr and exits 1.
- New cases:
  - `team up 2863 review` succeeds, and the log has
    `agent rename <pane> t2863-review`.
  - A 40-character task with role `implement` gives a 32-character name that
    ends in `-implement`.
  - The existing `fail-agent-rename` case (line 819) is unchanged, and still
    tears down. A new case checks that a rejected name puts herdr's message
    in `reason`.
- The existing `t1` cases still produce `t1-review` (a valid name keeps its
  form apart from lowercasing).

## Alternatives rejected

- **Tighten `task_ok`:** the intent keeps issue-number task names.
- **Drop the rename:** members would show only as `codex`; rejected at the
  intent gate.
- **Warn and continue on a rename failure:** rejected at the intent gate.
- **Map the agy pane label too:** not needed, and outside the intent.

## Risks

- **herdr might later tighten the pane label rule** in the same way. That
  is out of scope; the agy rename's output is still swallowed, so it would
  fail with the old bare message. The new fake makes the rule easy to copy
  if it happens.
- **Duplicate names**, if herdr requires them to be unique (Verification 4).

## Verification

1. **Build:** `herdr-team`'s `checkPhase` runs `shellcheck` and
   `herdr-team-test.sh`. `nix build` of the package (as wired in
   `home/development/agent-run.nix`) passes, then `just test-host p620`.
2. **Unit:** the new test cases above pass. The current suite fails against
   the stricter fake before the fix, which shows the test catches the bug.
3. **Live, p620, after deploy:** in a fresh worktree,
   `herdr-team up 2863 review` returns `ok: true`. `herdr agent list` shows
   the member named `t2863-review` with `agent: "codex"`. A
   `herdr-team ask 2863 review <prompt>` returns `ok: true`, then
   `herdr-team down 2863`. Already checked live: a successful rename leaves
   `.agent` unchanged, so `same_pane` still matches.
4. **Uniqueness:** with that member up, `herdr-team up` a second task that
   maps to the same name (`aaaaaaaaaaaaaaaaaaaaaaaaa1` and `aaaaaaaaaaaaaaaaaaaaaaaaa2`,
   role `review`, both → `aaaaaaaaaaaaaaaaaaaaaaaaa-review`). Record herdr's
   answer, then `down` both. If herdr rejects it,
   the spec needs a deviation (for example a short hash), not a silent
   collision.

## Review notes

(pending)
