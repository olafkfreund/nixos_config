# Antigravity global standards

## Model by stage

- Intent, spec, plan and revisions: `agy --model <name>`; the available models come from `agy models`.
- Implementation of an approved `plan/`: run `agy-implement` (Gemini 4 Argon
  Medium, write access, guarded; it may run headless when Claude hands it a
  step). Do not commit; report changed files and plan deviations.
- Review: `agy --mode plan`, with a model from `agy models`.
- At every gate's "stop for review", name the next stage's model and command.
