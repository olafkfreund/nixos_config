---
status: approved
issue: 3147
spec: spec/2026-11-20-3147-login-intro-handoff.md
coders:
  1: lead   # two small edits in one nixarchy file pair, below the hand-off threshold
reviewers:
  - codex   # read of the nixarchy diff against this plan
  - agy     # independent read of the same diff
---

# Plan: start owed with `--prepare-intro` in nixarchy

## Approved decisions (from the spec)

- nixarchy's `owed` user unit (`modules/home.nix:1527-1546`) gets two
  changes:
  - `ExecStart` as below;

    ```nix
    ExecStart = "${pkgs.bash}/bin/bash -c 'exec ${owe}/bin/owed --prepare-intro \"$(${omarchyPath}/bin/omarchy-theme-bg-boot-intro --resolve-startup 2>/dev/null)\"'";
    ```

  - `KillMode = "mixed"`, with a comment citing upstream's
    `systemd/owed.service`.

  `Restart`, `RestartSec`, `Environment` and the `Unit`/`Install` fields
  are unchanged.
- `tests/options.nix` gets a new case next to `oweService` (`:941-944`).
  It matches the **complete** `ExecStart` against a full-string pattern and
  checks `KillMode == "mixed"`. Its "off" side is a home with owe off,
  where the unit doesn't exist.
- What this fixes: the lost intro, and the post-intro handback on the
  cover's path. It does not fix the 6.7 s shell IPC block, which stays the
  next change (spec verification step 6). The expected gap is about 7 s,
  against 11.3 s today.
- This repo moves only the nixarchy pin.

## Steps

1. **nixarchy edit** (lead), in a clone at
   `/home/olafkfreund/.config/nixarchy-3147`, branch
   `fix/3147-owed-prepare-intro`, from `main` `8b5ed7c`:
   - `modules/home.nix`: the `ExecStart` and `KillMode` above;
   - `tests/options.nix`: the new case.

   Verify: `nix eval` of the generated unit's `ExecStart` prints the
   expected string, and nixarchy's options check builds (its
   `checks.<system>.options` attribute, run with `nix build`).

   Traps:
   - In a Nix string, `\"` gives the inner double quotes, and `$(` is not
     an antiquotation.
   - Do not commit to nixarchy `main`.
2. **nixarchy PR** (lead): commit, push, and open a PR that links issue
   #3147 and this plan.
   - Reviews: Codex and agy on the diff, through `second-opinion`.
   - Merge once nixarchy CI passes. That includes `checks.coexist` as the
     smoke test.
3. **Pin bump here** (lead), in the worktree
   `/home/olafkfreund/.config/nixos-3147`: run `nix flake update nixarchy`,
   then check the lock moved only nixarchy and its own inputs. Run
   `just test-host p620` and `just test-host razer`. Then open the PR with
   intent, spec and plan, and merge it after CI.
4. **Deploy** (lead): with a bus post for each host, run
   `AGENT_BUS_ANNOUNCED=1 just quick-deploy p620` and
   `AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer`. p510 only with the
   owner's OK. Check:
   - `systemctl --user cat owed` on both hosts shows the new `ExecStart`
     and `KillMode`;
   - there are no failed units.
5. **Measure** (lead, after the owner's next p620 login): read the probe
   and the owed journal. Expect:
   - `login intro prepared` in the journal;
   - `intro playing` → `intro fading to still` spanning the clip's length;
   - a recorded gap from both bars mapped to the cover closed.

   Then stop and start `owed` once, and confirm that the wallpaper stays
   and no stray `owe-render` is left. Post the timeline on #3147. If the
   gap is above about 2 s, propose the IPC-block change as a spec revision.
   razer: a temporary copy of the probe for one login, then remove it.

## Tests

| Where | Command | Expected |
| --- | --- | --- |
| nixarchy | the options check, plus CI (`coexist`) | pass |
| nixarchy | `nix eval` of the `owed` `ExecStart` | the exact string above |
| this repo | `just test-host p620`, `just test-host razer` | build |
| p620, razer | `systemctl --user cat owed` | new `ExecStart`, `KillMode=mixed` |
| p620 login | probe + owed journal | `login intro prepared`, the intro plays, the gap recorded |

## Rollback

- Revert the nixarchy merge, or move this repo's nixarchy pin back, in a
  PR.
- Then, with a bus post for each host, run `just quick-deploy p620` and
  `just deploy-via-p620 razer`. owed goes back to plain startup at the
  next login.
