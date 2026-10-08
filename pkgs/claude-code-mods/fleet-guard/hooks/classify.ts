// Visibility only: deploy, p510 and bus rules stay with the managed settings hooks
// in modules/programs/claude-code-managed.nix, which run before any mod.
export type Verdict = { kind: 'pass' } | { kind: 'deny'; reason: string }

// The double-quoted message of `git commit -m/-am/--message`.
const COMMIT_MSG = /git\s+(?:-C\s+\S+\s+)?commit\b[^|;]*?(?:\s-[a-z]*m|\s--message[=\s])\s*"([^"]*)/
// home-manager in command position (after a separator, not inside prose).
const HM_SWITCH = /(?:^|[;&|(\n])\s*(?:sudo\s+)?home-manager\b[^;&|\n]*\sswitch\b/

export function classify(cmd: string): Verdict {
  const msg = COMMIT_MSG.exec(cmd)?.[1]
  // A quoted heredoc ($(cat <<'EOF' ...)) expands nothing, so it is safe.
  if (msg !== undefined && !/^\$\(cat\s+<<-?\s*'/.test(msg) && /`|\$\(/.test(msg))
    return {
      kind: 'deny',
      reason: "backticks or $( inside a double-quoted commit message run as commands; use git commit -F - <<'MSG'",
    }
  if (HM_SWITCH.test(cmd))
    return { kind: 'deny', reason: 'Home Manager is a flake module here; never run home-manager switch' }
  return { kind: 'pass' }
}
