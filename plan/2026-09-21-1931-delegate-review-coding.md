---
status: approved
issue: 1931
spec: spec/2026-09-21-1931-delegate-review-coding.md
---

# Plan: Use Codex, Ollama and agy for real review and coding

## Approved decisions carried over

Self-contained. Do not reopen the intent or spec to implement this.

1. **`second-opinion` is the single entry point.** New paths go inside it, not
   into sibling skills.
2. **No zen/PAL MCP, no new dependency.** Consensus is a local shell path.
   `planner` is deliberately not implemented — the intent/spec/plan gates are
   the planning mechanism and a competing planner is unwanted.
3. **Revert the `claude-code-mcp.nix` description**; the real change is the
   `ollama_code` docstring in `pkgs/ollama-mcp/server.py`.
4. **Keep the existing `codex exec` prose path.** `review` needs a diff; a
   design question with nothing committed still needs `exec`. Both stay.
5. **agy stays in `--mode plan`.** `accept-edits` exists and stays unused.
6. **No path edits files or writes a commit.** These models advise.
7. **Subscription login only** — the `env -u` guards and
   `forced_login_method=chatgpt` are never removed (#1831).
8. **No decrypted secret reaches a model.** `/run/agenix/*` contents, tokens,
   passwords, private keys. Encrypted `*.age` files are fine.
9. **p510 is not built or deployed.**

## Verified before this plan was written

- **Read-only enforcement works.** `codex review -c sandbox_mode="read-only"
  --uncommitted` was run against a tree with an uncommitted probe file. It
  reviewed the change and left the tree byte-identical — same
  `git status --porcelain`, same md5sum. The spec's blocking risk is retired;
  change 2 is adopted.
- `codex review --base HEAD~2` returns findings with file:line, and ran its
  own `nix-instantiate --parse` checks unprompted.
- `agy --agent nix-check` runs this repo's agent definitions and returned a
  correct answer.
- The live `ollama_code` tool description is the `server.py` docstring
  verbatim, confirmed by loading the tool schema.

## Steps

1. `home/development/claude-code-skills/second-opinion/SKILL.md`: add a
   **routing rule** table near the top, before the backend sections — diff or
   branch → Codex `review`; our own agent definition → agy `--agent`; no diff
   to point at → existing prose path; "what do both think" → consensus. State
   the non-goal explicitly: this skill routes review and drafting only, and no
   path edits files or writes a commit.
   → verify by reading the file top to bottom in one sitting

2. Same file: add the **Codex `review` path**:

   ```bash
   timeout 900 env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE \
     codex review -c forced_login_method=chatgpt -c sandbox_mode="read-only" \
     --base "$base" > "$work/codex-review.md"
   ```

   Document all three selectors (`--base <BRANCH>`, `--uncommitted`,
   `--commit <SHA>`) and both gotchas: `--base` **cannot** be combined with a
   custom `[PROMPT]` (exits with an explicit conflict error), and `review`
   does **not** accept `-s`, `--ephemeral`, `--skip-git-repo-check`, `-C` or
   `-o` — read-only comes from `-c sandbox_mode="read-only"`, which is
   verified working and must never be dropped.
   → verify by running the documented command and diffing `git status` before
   and after

3. Same file: add the **agy `--agent` path**:

   ```bash
   timeout 900 env -u GEMINI_API_KEY -u GEMINI_API_KEY_FILE -u GOOGLE_API_KEY \
     agy --agent "$agent" --mode plan --output-format json \
     --print-timeout 10m -p "$(cat "$prompt")" > "$work/agy.json"
   ```

   Note that `agy agents` lists the available names, that `-p` must come last,
   and that the ~100 KB single-argument cap still applies to this path.
   Record the trial caveat: agy's reasoning was correct while its file
   citations pointed at a directory that does not exist, so its output is
   verified before use like any other.
   → verify by running it with a real agent name, and with a bogus one

4. Same file: add the **consensus path** — ask both CLIs the same question one
   at a time, then report agreement, disagreement, and what each could not
   verify. Require the disagreement to be reported explicitly; the existing
   "Agreement between models is not proof" line is what this operationalises.
   → verify by running it on a question where the two are likely to differ

5. `pkgs/ollama-mcp/server.py`: extend the `ollama_code` docstring to name the
   `-cloud` suffix convention and `gpt-oss:120b-cloud`. This is the text the
   model actually receives.
   → verify by loading the live tool schema after a rebuild and MCP restart —
   **not** by reading the file

6. `home/development/claude-code-mcp.nix`: revert the `ollama-code`
   `description` to its pre-#1930 wording.
   → verify by `git show` against the merge base, exact string match

## Tests

```bash
just check-syntax
just test-host p620
```

Expected: both succeed.

Read-only regression, the one guard that must never silently lapse:

```bash
printf '# probe\n' > SANDBOX_PROBE.md
git status --porcelain | sort > /tmp/before.txt
timeout 900 env -u OPENAI_API_KEY -u OPENAI_API_KEY_FILE \
  codex review -c forced_login_method=chatgpt -c sandbox_mode="read-only" \
  --uncommitted > /dev/null
git status --porcelain | sort > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt && echo "READ-ONLY OK"
rm -f SANDBOX_PROBE.md
```

Expected: `READ-ONLY OK`, tree byte-identical.

`agy --agent` with a bogus name must **fail loudly**, not silently fall back
to the default agent. If it falls back silently, the skill must say so.

**Result: it falls back silently.** `--agent definitely-not-an-agent`
answered normally and exited 0, with no error and no warning. The
contingency applies: `SKILL.md` records that a mistyped agent name yields a
generic answer indistinguishable from a specialist one, and instructs
copying the name from `agy agents` rather than typing it.

After a rebuild and an MCP server restart, load the `ollama_code` tool and
confirm its description contains the cloud-model text. Reading `server.py` is
not sufficient — verifying the edit rather than the effect is what produced
the two inert changes in #1928.

**Result: the docstring does not reach the model, and step 5 is incomplete.**
The switch on p620 succeeded and the new package built
(`q2xvxnz8…-ollama-mcp`), but the live MCP registration is not the one this
repo writes. It lives in `~/.claude.json` and points at
`~/.local/state/nix/gcroots/ollama-mcp/bin/ollama-mcp`, a gcroot symlink that
still resolves to the previous build (`xnxnbxx7…-ollama-mcp`). No file in this
repo manages that gcroot — `grep -rIln gcroots --include='*.nix'` returns
nothing — so it was created outside Nix, presumably by a `claude mcp add`.

This is the same root cause as #1928's second defect, one layer deeper: on an
existing install, **neither the tool description nor the server binary tracks
the Nix config**, because the only thing the config writes is the seed file
(#398) and the live registration is elsewhere. The `server.py` change is
correct and built; it simply cannot reach a server whose path is pinned
outside Nix.

Deliberately not fixed here: repointing or Nix-managing that gcroot is a
change to how MCP servers are registered on this machine, which is outside
this plan's approved scope. Tracked as follow-up.

p510: not built, not deployed, not asked.

## Rollback

All six steps are independent.

- Steps 1–4 are edits to one Markdown skill file: revert the commit. The skill
  is documentation the model reads, so a revert takes effect at the next
  session with no rebuild.
- Steps 5–6 are declarative: revert and rebuild. Step 5 additionally needs the
  MCP server restarted to pick up the old docstring.

Nothing here touches a secret, a systemd unit, a service or a host other than
through a normal rebuild. The only new runtime behaviour is that
`second-opinion` can invoke `codex review`, which is verified read-only; if
that guard were ever found not to hold, step 2 is reverted on its own and the
rest stands.
