---
status: draft
issue: 3266
intent: intent/2026-11-27-3266-herdr-team-model.md
---

# Spec: herdr-team up --model/--effort per member

## Design

In `home/development/herdr-team.sh`, both `up_tui` and `up_hc` parse two
more options next to `--step`: `--model M` and `--effort E`, each validated
against `^[A-Za-z0-9._-]+$` (else `usage`). They change the member's argv:

- `review`: the model and effort `-c` values (today fixed to
  `$review_model` / `$review_effort`) use the given values when set.
- `implement`: `codex-implement` gets `-c model="M"` and/or
  `-c model_reasoning_effort="E"` when set (its `-p implement` profile
  supplies the defaults otherwise).
- `agy-implement`: `agy-implement --acp` gets `--model M` and/or
  `--effort E` when set (it drops its own default when either is given,
  and passes them on to `agy-acp-member`).

The member record (`rec`) gains `model` and `effort` (null when not given).
The header usage line documents the flags. `herdr-team-test.sh` covers: a
review member with `--model x.y --effort low` (launch line), an implement
member with `--model x` (launch line), an agy-implement member with
`--effort high` (argv), and a rejected value with a space or `;`.

## Alternatives rejected

- A per-task config file: more state for a rarely used override.
- Environment variables: invisible in `status` and easy to leak into the
  wrong member.

## Risks

- A model id the provider does not know fails at member start, as a
  mistyped `-m` would today.

## Verification

- `nix build` of p620 (herdr-team's checkPhase runs the test file).
- `just test-host razer`.
