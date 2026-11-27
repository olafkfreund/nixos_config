# Antigravity global standards

## Model by stage

Models per role are in the Team policy table below.

- Intent, spec, plan and revisions: `agy --model <manager row id>`.
- Implementation of an approved `plan/`: run `agy-implement` (worker row, write
  access, guarded; it may run headless when Claude hands it a step). Do not
  commit; report changed files and plan deviations.
- Review: `agy --mode plan --model <reviewer row id>`.
- At every gate's "stop for review", name the next stage's model and command.
