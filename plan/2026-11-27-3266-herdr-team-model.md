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
them to `agy-implement --acp`; the member record gains `model` and `effort`
(null when unset); the header usage line names them.

Revised after the Codex plan review: no jq `select` (it empties the record);
agy values go as `--model=M` / `--effort=E` so a leading `-` stays a value;
the fakes record what the agy member receives; an hc override case.

## Steps

1. `home/development/herdr-team.sh`.
   - Header line 3: `herdr-team up <task> review|implement|agy-implement [--step k] [--model m] [--effort e]`.
   - `up_tui` (local list at line 421) and `up_hc` (line 673): add
     `model_opt='' effort_opt=''` to the local list and a separate
     `local -a over=()`; beside `--step`, one arm
     `--model | --effort)` that checks `${2:-}` against the regex (else
     `usage`), sets `model_opt` or `effort_opt`, and shifts 2.
   - Before each argv `case`: `over+=(-c "model=\"$model_opt\"")` when
     `model_opt` is set, `over+=(-c "model_reasoning_effort=\"$effort_opt\"")`
     when `effort_opt` is set.
     - review: the fixed values become
       `${model_opt:-${review_model:?}}` / `${effort_opt:-${review_effort:?}}`
       in the same position.
     - implement: `codex-implement [--no-daemon] "${over[@]}" -c "$notify" -c "$trust"`.
     - agy-implement: after `--turns "$work/turns"`, append
       `--model=$model_opt` / `--effort=$effort_opt` when set.
   - `rec=$(jq -n …)` (~509 and ~763): `--arg model "$model_opt" --arg effort "$effort_opt"`
     and `model: (if $model == "" then null else $model end)`, the same for
     `effort`, inside the object.
   → verify: `bash -n`; the build's shellcheck.

2. `home/development/herdr-team-test.sh`.
   - The fake `agy-implement` writes its arguments, one per line, to
     `$TEST_STATE/agy-args` before `shift`; the fake `agy` appends each
     `session/set_config_option` params object to `$TEST_STATE/agy-config`.
   - New block before "basic flow" (`ok model-overrides`): review with
     `--model x.y --effort low` (launch line has both overrides, no
     default, record holds them); implement with `--model x` (line has
     `codex-implement -c model="x" -c notify=`, no effort, record effort is
     an existing key with null); a default review member (both keys exist
     and are null); `--model 'a b'`, `'a;b'`, `''` and a bare `--effort`
     rejected through `team up` with nothing launched; agy-implement with
     `--model -preview --effort high` (args file has `--model=-preview` and
     `--effort=high`; the fake agy received `model=-preview` and
     `thought_level=high`).
   - At the end (`ok hc-model-overrides`): hc implement with
     `--model x --effort high` (line has `--no-daemon -c model="x" -c model_reasoning_effort="high" -c notify=`,
     record holds both).
   → verify: `nix build --no-link .#nixosConfigurations.p620.config.system.build.toplevel`
   (herdr-team's checkPhase runs shellcheck and the test file).

3. Lead: `just test-host razer`; agy diff review; PR; merge; bus
   announcement; switch p620, then razer via p620; check line 3 of the
   installed script names the flags (`grep -m1 'up <task>' "$(command -v herdr-team)"`).

## Tests

Both host builds (they run herdr-team-test.sh); the cases in step 2.

## Rollback

Revert the PR and switch again.
