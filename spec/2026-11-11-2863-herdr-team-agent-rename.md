---
status: approved
issue: 2863
intent: intent/2026-11-11-2863-herdr-team-agent-rename.md
---

# Spec: herdr-team names Codex members with valid herdr agent names

Approved intent decisions: keep the rename, with a mapped name; a rename
failure stays fatal and carries herdr's message.

Facts checked live on p620 (herdr 0.9.5) while writing this spec:

- A rename to `2863-review` fails with `invalid_agent_name` on stderr.
- A successful rename leaves `.agent` (`claude`/`codex`) unchanged, so
  `same_pane` (line 237) still matches.
- **Names must be unique.** A second agent renamed to a name already in use
  fails with `agent_name_taken`. (Tested on two of my own panes; both names
  were cleared afterwards.)

## Design

### 1. `agent_name` helper in `home/development/herdr-team.sh`

Next to `task_ok` (line 60):

```bash
# herdr agent names: ^[a-z][a-z0-9_-]{0,31}$; shorten the task, never the role
agent_name() {
  local t
  t=$(printf '%s' "$1" | LC_ALL=C tr 'A-Z' 'a-z' | LC_ALL=C tr -c 'a-z0-9_-' '-')
  [[ $t == [a-z]* ]] || t=t$t
  printf '%s-%s' "${t:0:$((31 - ${#2}))}" "$2"
}
```

- `LC_ALL=C tr` keeps it byte-wise: it lowercases ASCII and turns any other
  byte into `-`. `task_ok`'s `[A-Za-z0-9]` ranges depend on the locale and
  may accept letters like `é` in a UTF-8 shell (agy), and `${1,,}` maps `I`
  to `ı` under `tr_TR`. After `tr`, only ASCII `[a-z0-9_-]` is left, so the
  `[a-z]*` test is safe in any locale.
- Add a `t` when it doesn't start with a letter: `2863` → `t2863-review`.
- The task part is cut to `31 - len(role)` characters, then `-<role>` is
  added. So the result is at most 32 characters, and the role is never cut.
  Only `review` (6) and `implement` (9) reach this code (agy keeps
  `pane rename`).

### 2. The Codex rename (line 579), with one retry on a taken name

```bash
local err name
name=$(agent_name "$task" "$role")
if ! err=$(h agent rename "$pane" "$name" 2>&1 >/dev/null); then
  [[ $err == *agent_name_taken* ]] || fail "agent rename failed${err:+: ${err//$'\n'/ }}"
  name=$(agent_name "$task" "$role-${gen:0:4}")
  err=$(h agent rename "$pane" "$name" 2>&1 >/dev/null) || fail "agent rename failed${err:+: ${err//$'\n'/ }}"
fi
```

Only the exit status decides whether the rename failed; stderr only adds
the reason.

- herdr's stderr (its error JSON) goes into the `fail` reason. stdout (the
  success JSON) is still dropped. ShellCheck 0.11 does not flag
  `2>&1 >/dev/null` (checked).
- **Taken names** come from tasks that map to the same name (`2863` and
  `t2863`, `Foo` and `foo`, long shared prefixes), or from two sessions
  running the same task. On `agent_name_taken`, it retries once with the
  first four hex digits of the team's random `gen` (line 402) added to the
  role: `t2863-review-3fa1`. That leaves 17 characters for the task. A
  second failure is fatal.
- Any other failure is fatal at once, so `up`'s EXIT trap tears the member
  down as before.
- `err` and `name` are declared with the function's other locals (a
  separate `local` keeps the exit status).

### 3. Unchanged

- The agy `pane rename` (line 577) keeps `"$task-$role"`: pane labels
  accepted `2853-agy-implement`, and the intent leaves agy alone.
- The tab label, scope names, state files and relay headers keep the plain
  task name.

### 4. Tests in `home/development/herdr-team-test.sh`

The fake `herdr`'s `agent rename` (line 109):

- runs its name check under `LC_ALL=C`: a name that doesn't match
  `^[a-z][a-z0-9_-]{0,31}$` prints herdr's `invalid_agent_name` JSON to
  stderr and exits 1;
- with `$TEST_STATE/taken-agent-rename`, fails the first rename with
  `agent_name_taken` on stderr (then removes the flag);
- with `$TEST_STATE/bad-agent-rename`, fails every rename with a fixed error
  JSON on stderr.

The logging line (line 45) and the existing `fail-agent-rename` case (line
819, empty stderr, still tears down) stay as they are.

New cases:

- `team up 2863 review` succeeds, and the log has
  `agent rename <pane> t2863-review`.
- `team up PR-2863 review` logs `pr-2863-review` (uppercase).
- A 40-character task with role `implement` logs a 32-character name that
  ends in `-implement`.
- `taken-agent-rename`: `up` succeeds, the log has two renames, and the
  second is `t2863-review-<4 hex>`.
- `bad-agent-rename`: `up` fails, `reason` contains the fixed error text, and
  nothing is left over (`no_leftovers`).

The existing tests use `t1`, `t2`, `a` and `b`, which map to themselves, and
no existing log check reads a Codex rename, so they are unaffected.

## Alternatives rejected

- **Tighten `task_ok`:** the intent keeps issue-number task names.
- **Drop the rename:** members would show only as `codex`; rejected at the
  intent gate.
- **Warn and continue on a rename failure:** rejected at the intent gate.
- **Always add the `gen` suffix:** unique, but every label gets four hex
  digits for a collision that is rare.
- **Map the agy pane label too:** not needed, and outside the intent.

## Risks

- **herdr might later tighten the pane label rule** in the same way. That is
  out of scope. The agy rename's output is still swallowed, so it would fail
  with the old bare message; the fake shows how to copy the rule.
- **Two retries colliding** would need the same task, role and first four
  `gen` hex digits at once (1 in 65,536). It fails visibly with herdr's
  message.

## Verification

1. **Build:** `herdr-team`'s `checkPhase` runs `shellcheck` and
   `herdr-team-test.sh`. A `nix build` of the package passes (wiring:
   `home/development/agent-run.nix`), then `just test-host p620` and
   `just test-host razer`.
2. **Unit:** the new cases pass. Against the old line 579, the `2863`,
   uppercase and `taken` cases fail, which shows they catch the bug.
3. **Live, p620, after deploy:**
   - In this worktree, `herdr-team up 2863 review` returns `ok: true`.
   - `herdr agent list` shows the member named `t2863-review`, with
     `agent: "codex"`.
   - `herdr-team ask 2863 review <prompt>` returns `ok: true`, then
     `herdr-team down 2863`.
4. **Live collision:** with `2863`'s member up, `herdr-team up t2863 review`
   in a second worktree returns `ok: true`, and its member is named
   `t2863-review-<4 hex>`. Then `down` both.

## Review notes

Reviewed read-only by Codex (gpt-6.1-sol) and agy (model not reported).
Both confirmed:

- the helper's length and prefix logic;
- that the separate `local` keeps the exit status;
- that existing tests are unaffected.

They added:

- the uniqueness question, which led to the live test and the retry;
- an explicit failure injection for the message test;
- the uppercase case;
- the locale problem and `LC_ALL=C` (agy);
- the empty-stderr reason (agy);
- the role-length correction (agy).

agy's SC2069 warning was checked and does not apply to ShellCheck 0.11.
Advice only, not approval.
