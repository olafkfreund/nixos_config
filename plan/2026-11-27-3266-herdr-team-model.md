---
status: draft
issue: 3266
spec: spec/2026-11-27-3266-herdr-team-model.md
coders:
  1: lead # two files; below the handoff threshold (Team policy)
  2: lead # tests for the same change
reviewers:
  - codex # plan review (one plan review)
  - agy # diff review by a provider other than the implementer's (Claude)
---

# Plan: herdr-team up --model/--effort per member

Decisions (approved spec): `up` in both backends takes `--model M` and
`--effort E`, validated against `^[A-Za-z0-9._-]+$`; review uses them in
place of `$review_model`/`$review_effort`; implement passes `-c model="M"` /
`-c model_reasoning_effort="E"` to `codex-implement`; agy-implement passes
`--model M` / `--effort E` to `agy-implement --acp`; the member record gains
`model` and `effort` (null when unset); the header usage line names them.

## Steps

1. `home/development/herdr-team.sh`.
   - Header line 3: `herdr-team up <task> review|implement|agy-implement [--step k] [--model m] [--effort e]`.
   - `up_tui` (~424-434) and `up_hc` (~678-688): add `model_opt` and
     `effort_opt` to the `local` lists (empty by default) and two `case`
     arms beside `--step`:
     `--model) [[ ${2:-} =~ ^[A-Za-z0-9._-]+$ ]] || usage; model_opt=$2; shift 2 ;;`
     and the same for `--effort`.
   - Argv (~502-507 and ~756-761): build `over=()`; when `model_opt` is set
     add `-c "model=\"$model_opt\""`, when `effort_opt` is set add
     `-c "model_reasoning_effort=\"$effort_opt\""`.
     - review: replace the two fixed `-c` values with
       `-c "model=\"${model_opt:-${review_model:?}}\"" -c "model_reasoning_effort=\"${effort_opt:-${review_effort:?}}\""`
       (same position, so the existing launch-line tests still match).
     - implement: `argv=(agent-env codex-implement [--no-daemon] "${over[@]}" -c "$notify" -c "$trust")`.
     - agy-implement: append `--model "$model_opt"` / `--effort "$effort_opt"`
       when set, after `--turns "$work/turns"`.
   - `rec=$(jq -n …)` (~509 and ~763): `--arg model "$model_opt" --arg effort "$effort_opt"`
     and in the object `model: ($model | select(. != "")), effort: ($effort | select(. != ""))`
     written so an empty value becomes `null` (e.g. `(if $model == "" then null else $model end)`).
   → verify: `shellcheck --exclude=SC2016` on the file; `bash -n`.

2. `home/development/herdr-team-test.sh`, using the file's existing
   `team up` helpers and its fake `codex` / `agy-implement` that log `$*` to
   `$TEST_STATE/launched`:
   - review with `--model x.y --effort low` → launch line contains
     `-c model="x.y" -c model_reasoning_effort="low"` in place of the defaults;
   - implement with `--model x` → line contains `-c model="x"` and no
     effort override;
   - agy-implement with `--effort high` → argv ends with `--effort high`;
   - `--model 'a b'` and `--model 'a;b'` → `up` exits with the usage error
     and starts nothing;
   - the member record in the team state shows the model (`jq`).
   → verify: `nix build --no-link .#nixosConfigurations.p620.config.system.build.toplevel`
   (herdr-team's checkPhase runs shellcheck and the test file).

3. Lead: `just test-host razer`; agy diff review; PR; merge; bus
   announcement; switch p620, then razer via p620; on p620 run
   `herdr-team up` help text check (`herdr-team up 2>&1 | head -1`).

## Tests

Both host builds (they run herdr-team-test.sh); the cases in step 2.

## Rollback

Revert the PR and switch again.
