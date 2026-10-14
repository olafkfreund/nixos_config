# Antigravity global standards

## Model by stage

- Intent, spec, plan and revisions: `agy --model gemini-3.1-pro-high`.
- Implementation of an approved `plan/`: run `agy-implement` (Gemini 4 Argon
  Medium, write access, guarded; it may run headless when Claude hands it a
  step). Do not commit; report changed files and plan deviations.
- Review: `agy --mode plan --model gemini-3.1-pro-high`.
- At every gate's "stop for review", name the next stage's model and command.
